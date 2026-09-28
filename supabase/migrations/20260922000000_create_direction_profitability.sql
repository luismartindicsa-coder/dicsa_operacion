begin;
-- Analysis settings and immutable cuts. The operational ledgers remain read-only.
create table public.direction_profitability_reviews (
  period_start date not null,
  period_end date not null,
  revision integer not null check (revision > 0),
  config jsonb not null check (jsonb_typeof(config)='object'),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id),
  primary key(period_start, period_end),
  check (period_end between period_start and period_start+365)
);
create table public.direction_profitability_snapshots (
  id uuid primary key default gen_random_uuid(),
  period_start date not null,
  period_end date not null,
  review_revision integer not null check (review_revision >= 0),
  payload jsonb not null check (jsonb_typeof(payload)='object'),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  check (period_end between period_start and period_start+365)
);
create index direction_profitability_snapshot_period on public.direction_profitability_snapshots(period_start,period_end,created_at desc);
alter table public.direction_profitability_reviews enable row level security;
alter table public.direction_profitability_snapshots enable row level security;
grant select on public.direction_profitability_reviews, public.direction_profitability_snapshots to authenticated;
create policy profitability_review_read on public.direction_profitability_reviews for select to authenticated using (public.direction_program_can_manage());
create policy profitability_snapshot_read on public.direction_profitability_snapshots for select to authenticated using (public.direction_program_can_manage());

create function public.direction_validate_profitability_config(p_config jsonb)
returns void language plpgsql set search_path=public as $$
declare k text; v jsonb; item jsonb; share jsonb; total numeric; cursor_key text; visited text[];
begin
  if p_config is null or jsonb_typeof(p_config)<>'object' or octet_length(p_config::text)>4000000
    or not (p_config ?& array['identities','recipes','costs','companies','excluded_purchases'])
    or exists(select 1 from jsonb_each(p_config) e where e.key not in ('identities','recipes','costs','companies','excluded_purchases')) then
    raise exception 'Configuración inválida';
  end if;
  for k,v in select key,value from jsonb_each(p_config) loop
    if jsonb_typeof(v)<>'object' then raise exception 'Se esperaba un catálogo de reglas'; end if;
  end loop;
  for k,v in select key,value from jsonb_each(p_config->'identities') loop
    if k='' or jsonb_typeof(v)<>'string' or btrim(v#>>'{}')='' then raise exception 'Identidad inválida'; end if;
    cursor_key:=k; visited:='{}';
    while (p_config->'identities') ? cursor_key loop
      if cursor_key=any(visited) then raise exception 'Equivalencia circular'; end if;
      visited:=array_append(visited,cursor_key);
      cursor_key:=p_config->'identities'->>cursor_key;
    end loop;
  end loop;
  for k,v in select key,value from jsonb_each(p_config->'recipes') loop
    if k='' or jsonb_typeof(v)<>'object' or jsonb_typeof(v->'outputs') is distinct from 'array'
      or jsonb_typeof(v->'note') is distinct from 'string' or btrim(v->>'note')='' then raise exception 'Rendimiento sin fundamento'; end if;
    total:=0; visited:='{}';
    for item in select value from jsonb_array_elements(v->'outputs') loop
      if jsonb_typeof(item->'benchmark') is distinct from 'string' or btrim(item->>'benchmark')=''
        or (item->>'benchmark')=any(visited) or jsonb_typeof(item->'yield') is distinct from 'number'
        or (item->>'yield')::numeric not between 0.000000001 and 1 then raise exception 'Salida de material inválida'; end if;
      visited:=array_append(visited,item->>'benchmark'); total:=total+(item->>'yield')::numeric;
    end loop;
    if total <= 0 or total > 1.000001 then raise exception 'Rendimiento total fuera de 0–100%%'; end if;
  end loop;
  for k,v in select key,value from jsonb_each(p_config->'costs') loop
    if k='' or jsonb_typeof(v)<>'object' or coalesce(v->>'treatment','') not in ('pending','include','exclude','duplicate')
      or coalesce(v->>'kind','') not in ('fuel','payroll','transport','process','maintenance','other','overhead') then raise exception 'Tratamiento inválido'; end if;
    if v->>'treatment'='pending' then continue; end if;
    if jsonb_typeof(v->'note') is distinct from 'string' or btrim(v->>'note')=''
      or coalesce(v->>'source_signature','') !~ '^[0-9a-f]{64}$'
      or jsonb_typeof(v->'estimated') is distinct from 'boolean' then raise exception 'Costo sin evidencia'; end if;
    if v->>'treatment'='duplicate' and (coalesce(v->>'duplicate_of','')='' or v->>'duplicate_of'=k) then raise exception 'Costo vinculado inválido'; end if;
    if v->>'treatment'='include' then
      if jsonb_typeof(v->'shares') is distinct from 'object' then raise exception 'Falta reparto'; end if;
      total:=0;
      for cursor_key,share in select key,value from jsonb_each(v->'shares') loop
        if cursor_key='' or jsonb_typeof(share)<>'number' or (share#>>'{}')::numeric<=0 then raise exception 'Reparto inválido'; end if;
        total:=total+(share#>>'{}')::numeric;
      end loop;
      if abs(total-1)>0.000001 then raise exception 'El reparto debe sumar 100%%'; end if;
      if v->'amount' is not null and v->'amount'<>'null'::jsonb and
        (jsonb_typeof(v->'amount')<>'number' or (v->>'amount')::numeric not between 0 and 1000000000000) then raise exception 'Importe inválido'; end if;
    end if;
  end loop;
  for k,v in select key,value from jsonb_each(p_config->'companies') loop
    if jsonb_typeof(v)<>'object' or coalesce(v->>'evidence_signature','') !~ '^[0-9a-f]{64}$'
      or jsonb_typeof(v->'note') is distinct from 'string' then raise exception 'Revisión sin referencia'; end if;
    foreach cursor_key in array array['identity','labor','fuel','process','expenses','tax_basis'] loop
      if jsonb_typeof(v->cursor_key) is distinct from 'boolean' then raise exception 'Revisión inválida'; end if;
    end loop;
  end loop;
  for k,v in select key,value from jsonb_each(p_config->'excluded_purchases') loop
    if coalesce(v->>'signature','') !~ '^[0-9a-f]{64}$' or jsonb_typeof(v->'note') is distinct from 'string' or btrim(v->>'note')='' then raise exception 'Exclusión sin fundamento'; end if;
  end loop;
end $$;

create function public.direction_save_profitability_review(p_start date,p_end date,p_expected_revision integer,p_config jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare old_revision integer; saved public.direction_profitability_reviews;
begin
  if not coalesce(public.direction_program_can_manage(),false) then raise exception 'Sin permiso' using errcode='42501'; end if;
  if p_start is null or p_end is null or p_end not between p_start and p_start+365 or p_expected_revision is null or p_expected_revision<0 then raise exception 'Periodo o versión inválida'; end if;
  perform public.direction_validate_profitability_config(p_config);
  perform pg_advisory_xact_lock(hashtextextended('direction-profitability:'||p_start::text||':'||p_end::text,0));
  select revision into old_revision from public.direction_profitability_reviews where period_start=p_start and period_end=p_end for update;
  if coalesce(old_revision,0)<>p_expected_revision then
    raise exception 'El corte cambió en otra sesión. Cancela la edición y vuelve a abrirla con la versión actualizada.' using errcode='PT409';
  end if;
  insert into public.direction_profitability_reviews(period_start,period_end,revision,config,updated_by)
    values(p_start,p_end,p_expected_revision+1,p_config,auth.uid())
    on conflict(period_start,period_end) do update set revision=excluded.revision,config=excluded.config,updated_at=now(),updated_by=excluded.updated_by returning * into saved;
  return to_jsonb(saved);
end $$;

create function public.direction_save_profitability_snapshot(p_start date,p_end date,p_expected_revision integer,p_payload jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare saved_config jsonb; old_revision integer; result uuid;
begin
  if not coalesce(public.direction_program_can_manage(),false) then raise exception 'Sin permiso' using errcode='42501'; end if;
  if p_start is null or p_end is null or p_end not between p_start and p_start+365 or p_expected_revision is null or p_expected_revision<0 then raise exception 'Periodo o versión inválida'; end if;
  perform pg_advisory_xact_lock(hashtextextended('direction-profitability:'||p_start::text||':'||p_end::text,0));
  select revision,config into old_revision,saved_config from public.direction_profitability_reviews where period_start=p_start and period_end=p_end;
  if coalesce(old_revision,0)<>p_expected_revision then raise exception 'El corte cambió en otra sesión' using errcode='PT409'; end if;
  if saved_config is null then saved_config:='{"identities":{},"recipes":{},"costs":{},"companies":{},"excluded_purchases":{}}'; end if;
  if p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>20000000
    or p_payload->'config' is distinct from saved_config
    or p_payload->>'start' is distinct from p_start::text or p_payload->>'end' is distinct from p_end::text
    or p_payload->'review_revision' is distinct from to_jsonb(p_expected_revision)
    or p_payload->'engine_version' is distinct from '1'::jsonb
    or coalesce(p_payload->>'evidence_signature','') !~ '^[0-9a-f]{64}$'
    or jsonb_typeof(p_payload->'companies') is distinct from 'array' then raise exception 'Corte inconsistente con las reglas guardadas'; end if;
  insert into public.direction_profitability_snapshots(period_start,period_end,review_revision,payload,created_by)
    values(p_start,p_end,p_expected_revision,p_payload,auth.uid()) returning id into result;
  return result;
end $$;
revoke all on function public.direction_validate_profitability_config(jsonb) from public, anon, authenticated;
revoke all on function public.direction_save_profitability_review(date,date,integer,jsonb) from public, anon;
revoke all on function public.direction_save_profitability_snapshot(date,date,integer,jsonb) from public, anon;
grant execute on function public.direction_save_profitability_review(date,date,integer,jsonb) to authenticated;
grant execute on function public.direction_save_profitability_snapshot(date,date,integer,jsonb) to authenticated;
commit;
