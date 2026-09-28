begin;
-- Effective-dated managerial assumptions, not operational transactions.
create table public.direction_profitability_master (
  id integer primary key check(id=1), revision integer not null check(revision>0),
  config jsonb not null check(jsonb_typeof(config)='object'),
  updated_at timestamptz not null default now(), updated_by uuid references auth.users(id)
);
create table public.direction_profitability_master_history (
  revision integer primary key, config jsonb not null,
  created_at timestamptz not null default now(), created_by uuid references auth.users(id)
);
alter table public.direction_profitability_master enable row level security;
alter table public.direction_profitability_master_history enable row level security;
grant select on public.direction_profitability_master,public.direction_profitability_master_history to authenticated;
create policy profitability_master_read on public.direction_profitability_master for select to authenticated using(public.direction_program_can_manage());
create policy profitability_master_history_read on public.direction_profitability_master_history for select to authenticated using(public.direction_program_can_manage());

create function public.direction_profitability_identity_keys(d jsonb) returns text[] language sql immutable set search_path=public as $$
  select array_remove(array[
    case when coalesce(d->>'compras_supplier_id','')<>'' then 'compras:'||(d->>'compras_supplier_id') end,
    case when coalesce(d->>'mayoreo_customer_id','')<>'' then 'ventas:'||(d->>'mayoreo_customer_id') end,
    case when coalesce(d->>'menudeo_counterparty_id','')<>'' then 'men:'||(d->>'menudeo_counterparty_id') end,
    case when coalesce(d->>'hr_company_identifier','')<>'' then 'payroll:'||translate(upper(regexp_replace(btrim(d->>'hr_company_identifier'),'\s+',' ','g')),'ÁÉÍÓÚÜ','AEIOUU') end
  ],null) || coalesce((select array_agg('expense:'||translate(upper(regexp_replace(btrim(v),'\s+',' ','g')),'ÁÉÍÓÚÜ','AEIOUU')) from unnest(string_to_array(coalesce(d->>'aliases',''),';')) v where btrim(v)<>''),'{}'::text[])
$$;

create function public.direction_validate_profitability_master(c jsonb) returns void language plpgsql set search_path=public as $$
declare r jsonb; d jsonb; other jsonb; k text; kind text; scope text; other_scope text; scopes text[]:='{}'; ids text[]:='{}'; required text[]; numeric_keys text[]; numeric_value jsonb; first_day date; last_day date;
begin
  if c is null or jsonb_typeof(c)<>'object' or jsonb_typeof(c->'rules') is distinct from 'array' or octet_length(c::text)>4000000 or (select count(*) from jsonb_object_keys(c))<>1 then raise exception 'Maestro inválido'; end if;
  for r in select value from jsonb_array_elements(c->'rules') loop
    kind:=r->>'kind'; d:=r->'data';
    if coalesce(r->>'id','')='' or r->>'id'=any(ids) or coalesce(btrim(r->>'note'),'')='' or jsonb_typeof(d) is distinct from 'object'
      or coalesce(kind,'') not in ('identity','vehicle','labor','process','recovery','activity','coverage')
      or coalesce(r->>'valid_from','') !~ '^\d{4}-\d{2}-\d{2}$' then raise exception 'Parámetro incompleto'; end if;
    ids:=array_append(ids,r->>'id');
    first_day:=(r->>'valid_from')::date; last_day:=coalesce(nullif(r->>'valid_to','')::date,'9999-12-31');
    if last_day<first_day then raise exception 'Vigencia inválida'; end if;
    required:=case kind
      when 'identity' then array['site','company_group'] when 'vehicle' then array['unit']
      when 'labor' then array['company','role','basis'] when 'process' then array['company','material','process','kg_basis']
      when 'recovery' then array['company','material'] when 'activity' then array['company','measure','subject']
      else array['company','block'] end;
    foreach k in array required loop
      if jsonb_typeof(d->k) is distinct from 'string' or btrim(d->>k)='' then raise exception 'Falta %',k; end if;
    end loop;
    numeric_keys:=case kind
      when 'vehicle' then array['fuel_cost_per_km','maintenance_cost_per_km','fixed_cost_per_service','optional_cost_per_hour','hours_per_service']
      when 'labor' then array['labor_cost_per_hour','labor_cost_per_day','period_labor_cost','working_days','workers','hours_per_service']
      when 'process' then array['cost_per_kg'] when 'activity' then array['quantity'] else '{}'::text[] end;
    foreach k in array numeric_keys loop
      numeric_value:=d->k;
      if numeric_value is not null and numeric_value<>'null'::jsonb and (jsonb_typeof(numeric_value)<>'number' or (numeric_value#>>'{}')::numeric not between 0 and 1000000000000) then raise exception 'Importe o cantidad inválidos'; end if;
    end loop;
    case kind
      when 'identity' then
        if (d->>'site') !~ '^site:.+' then raise exception 'La identidad debe terminar en una planta'; end if;
        scope:='identity|'||(d->>'site');
      when 'vehicle' then
        if not exists(select 1 from unnest(numeric_keys) n where jsonb_typeof(d->n)='number') then raise exception 'Falta tarifa'; end if;
        if jsonb_typeof(d->'optional_cost_per_hour')='number' and jsonb_typeof(d->'hours_per_service') is distinct from 'number' then raise exception 'Faltan horas por servicio'; end if;
        scope:='vehicle|'||(d->>'unit');
      when 'labor' then
        if d->>'basis' not in ('hour','day','dedicated')
          or d->>'basis'='hour' and jsonb_typeof(d->'labor_cost_per_hour') is distinct from 'number'
          or d->>'basis'='day' and jsonb_typeof(d->'labor_cost_per_day') is distinct from 'number'
          or d->>'basis'='dedicated' and (jsonb_typeof(d->'period_labor_cost') is distinct from 'number' or coalesce((d->>'working_days')::numeric,0)<=0)
          or d->>'basis'<>'hour' and (coalesce((d->>'workers')::numeric,0)<=0 or coalesce(d->>'week_days','') not in ('5','6','7')) then raise exception 'Base laboral incompleta'; end if;
        scope:='labor|'||(d->>'company')||'|'||(d->>'role');
      when 'process' then
        if jsonb_typeof(d->'cost_per_kg') is distinct from 'number' or d->>'kg_basis' not in ('received','activity') then raise exception 'Base física de proceso inválida'; end if;
        scope:='process|'||(d->>'company')||'|'||(d->>'material')||'|'||(d->>'process');
      when 'recovery' then
        perform public.direction_validate_profitability_config(jsonb_build_object('identities','{}'::jsonb,'recipes',jsonb_build_object('master',d),'costs','{}'::jsonb,'companies','{}'::jsonb,'excluded_purchases','{}'::jsonb));
        scope:='recovery|'||(d->>'company')||'|'||(d->>'material');
      when 'activity' then
        if jsonb_typeof(d->'quantity') is distinct from 'number' or d->>'measure' not in ('hours','kg') or first_day<>last_day then raise exception 'La actividad requiere un solo día'; end if;
        scope:='activity|'||(d->>'company')||'|'||(d->>'measure')||'|'||(d->>'subject');
      else
        if d->>'block' not in ('income','fuel','transport','payroll','process','maintenance','other','overhead') then raise exception 'Bloque inválido'; end if;
        scope:='coverage|'||(d->>'company')||'|'||(d->>'block');
    end case;
    -- Compare only already visited rules, using their precomputed scopes.
    for k in 1..coalesce(array_length(scopes,1),0) loop
      other:=c->'rules'->(k::integer-1); other_scope:=scopes[k::integer];
      if first_day<=coalesce(nullif(other->>'valid_to','')::date,'9999-12-31') and (other->>'valid_from')::date<=last_day and
        (scope=other_scope or kind='identity' and other->>'kind'='identity' and public.direction_profitability_identity_keys(d) && public.direction_profitability_identity_keys(other->'data')) then
        raise exception 'Vigencias superpuestas o alias asignado a dos plantas';
      end if;
    end loop;
    scopes:=array_append(scopes,scope);
  end loop;
end $$;

create function public.direction_save_profitability_master(p_expected_revision integer,p_config jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare previous integer; saved public.direction_profitability_master;
begin
  if not coalesce(public.direction_program_can_manage(),false) then raise exception 'Sin permiso' using errcode='42501'; end if;
  if p_expected_revision is null or p_expected_revision<0 then raise exception 'Versión inválida'; end if;
  perform public.direction_validate_profitability_master(p_config);
  perform pg_advisory_xact_lock(hashtextextended('direction-profitability-master',0));
  select revision into previous from public.direction_profitability_master where id=1 for update;
  if coalesce(previous,0)<>p_expected_revision then raise exception 'Los parámetros cambiaron en otra sesión. Cancela y vuelve a abrir la edición.' using errcode='PT409'; end if;
  insert into public.direction_profitability_master(id,revision,config,updated_by) values(1,p_expected_revision+1,p_config,auth.uid())
    on conflict(id) do update set revision=excluded.revision,config=excluded.config,updated_at=now(),updated_by=excluded.updated_by returning * into saved;
  insert into public.direction_profitability_master_history(revision,config,created_by) values(saved.revision,saved.config,auth.uid());
  return to_jsonb(saved);
end $$;

-- Extend the existing review validator without altering historical JSON.
alter function public.direction_validate_profitability_config(jsonb) rename to direction_validate_profitability_config_v1;
create function public.direction_validate_profitability_config(p_config jsonb) returns void language plpgsql set search_path=public as $$
declare r jsonb;
begin
  perform public.direction_validate_profitability_config_v1(p_config);
  for r in select value from jsonb_each(p_config->'costs') loop
    if (r ? 'coverage_start') <> (r ? 'coverage_end') then raise exception 'Cobertura incompleta'; end if;
    if r ? 'coverage_start' and (jsonb_typeof(r->'coverage_start') is distinct from 'string' or jsonb_typeof(r->'coverage_end') is distinct from 'string' or (r->>'coverage_end')::date not between (r->>'coverage_start')::date and (r->>'coverage_start')::date+365) then raise exception 'Cobertura inválida'; end if;
    if r ? 'includes_maintenance' and (jsonb_typeof(r->'includes_maintenance') is distinct from 'boolean' or r->>'includes_maintenance'='true' and r->>'kind'<>'transport') then raise exception 'Mantenimiento incluido solo en transporte'; end if;
    if r ? 'coverage_vehicle' and jsonb_typeof(r->'coverage_vehicle') is distinct from 'string' then raise exception 'Unidad de cobertura inválida'; end if;
  end loop;
end $$;

create or replace function public.direction_save_profitability_snapshot(p_start date,p_end date,p_expected_revision integer,p_payload jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare saved_config jsonb; old_revision integer; result uuid; master_config jsonb; master_revision integer; r jsonb;
begin
  if not coalesce(public.direction_program_can_manage(),false) then raise exception 'Sin permiso' using errcode='42501'; end if;
  if p_start is null or p_end is null or p_end not between p_start and p_start+365 or p_expected_revision is null or p_expected_revision<0 then raise exception 'Periodo o versión inválida'; end if;
  perform pg_advisory_xact_lock(hashtextextended('direction-profitability-master',0));
  perform pg_advisory_xact_lock(hashtextextended('direction-profitability:'||p_start::text||':'||p_end::text,0));
  select revision,config into old_revision,saved_config from public.direction_profitability_reviews where period_start=p_start and period_end=p_end;
  if coalesce(old_revision,0)<>p_expected_revision then raise exception 'El corte cambió en otra sesión' using errcode='PT409'; end if;
  if saved_config is null then saved_config:='{"identities":{},"recipes":{},"costs":{},"companies":{},"excluded_purchases":{}}'; end if;
  if p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>20000000
    or p_payload->'config' is distinct from saved_config
    or p_payload->>'start' is distinct from p_start::text or p_payload->>'end' is distinct from p_end::text
    or p_payload->'review_revision' is distinct from to_jsonb(p_expected_revision)
    or coalesce(p_payload->>'engine_version','') not in ('1','2')
    or coalesce(p_payload->>'evidence_signature','') !~ '^[0-9a-f]{64}$'
    or jsonb_typeof(p_payload->'companies') is distinct from 'array' then raise exception 'Corte inconsistente con las reglas guardadas'; end if;
  if p_payload->>'engine_version'='2' then
    select revision,config into master_revision,master_config from public.direction_profitability_master where id=1;
    if p_payload->'master_revision' is distinct from to_jsonb(coalesce(master_revision,0)) or p_payload->'master_config' is distinct from coalesce(master_config,'{"rules":[]}'::jsonb) then raise exception 'Los parámetros cambiaron; consulta de nuevo antes de guardar' using errcode='PT409'; end if;
    for r in select value from jsonb_array_elements(coalesce(p_payload->'shared_cost_review_evidence','[]'::jsonb)) loop
      if not exists(select 1 from public.direction_profitability_reviews v where v.period_start=(r->>'period_start')::date and v.period_end=(r->>'period_end')::date and v.revision=(r->>'revision')::integer and v.config->'costs'=r->'costs') then raise exception 'La conciliación compartida cambió' using errcode='PT409'; end if;
    end loop;
  end if;
  insert into public.direction_profitability_snapshots(period_start,period_end,review_revision,payload,created_by) values(p_start,p_end,p_expected_revision,p_payload,auth.uid()) returning id into result;
  return result;
end $$;
revoke all on function public.direction_profitability_identity_keys(jsonb),public.direction_validate_profitability_master(jsonb),public.direction_validate_profitability_config(jsonb),public.direction_validate_profitability_config_v1(jsonb) from public,anon,authenticated;
revoke all on function public.direction_save_profitability_master(integer,jsonb) from public,anon;
grant execute on function public.direction_save_profitability_master(integer,jsonb) to authenticated;
commit;
