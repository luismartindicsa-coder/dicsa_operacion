begin;

create function public.direction_execution_client(p_name text) returns text
language sql immutable set search_path=public as $$
  select case n
    when 'CUENTA EL PALOMAR' then 'EL PALOMAR'
    when 'QUERETANIA' then 'QUERETANA'
    when 'DESPERDICIOS QUERETANA' then 'QUERETANA'
    when 'BIOPAPEL' then 'BIO PAPEL'
    when 'MENDIETA' then 'RICARDO MENDIETA'
    else n end
  from (select btrim(regexp_replace(translate(upper(btrim(coalesce(p_name,''))),
    'ÁÉÍÓÚÜÑ','AEIOUUN'),'[^A-Z0-9]+',' ','g')) n) x;
$$;

create table public.direction_execution_actuals (
  id uuid primary key default gen_random_uuid(),
  kind text not null check(kind in ('shipment','production')),
  op_date date not null,
  material_code text not null,
  client_name text not null default '',
  shift text not null default '',
  quantity integer not null check(quantity between 0 and 10000000),
  load_quantities jsonb not null default '[]',
  observed_quantity integer check(observed_quantity between 0 and 10000000),
  planned_quantity integer check(planned_quantity between 0 and 10000000),
  planned_snapshot jsonb not null default '[]',
  program_id uuid references public.direction_operating_programs(id),
  notes text not null default '',
  active boolean not null default true,
  revision integer not null default 1,
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(kind,op_date,material_code,client_name,shift)
);
create index direction_execution_actuals_date_idx on public.direction_execution_actuals(op_date,kind);
create table public.direction_execution_actual_revisions (
  actual_id uuid not null references public.direction_execution_actuals(id),
  revision integer not null,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  primary key(actual_id,revision)
);
alter table public.direction_execution_actuals enable row level security;
alter table public.direction_execution_actual_revisions enable row level security;
grant select on public.direction_execution_actuals,public.direction_execution_actual_revisions to authenticated;
create policy direction_execution_read on public.direction_execution_actuals for select to authenticated
  using(public.direction_program_can_manage());
create policy direction_execution_history_read on public.direction_execution_actual_revisions for select to authenticated
  using(public.direction_program_can_manage());

create function public.direction_save_execution_actual(
  p_kind text,p_date date,p_material text,p_client text,p_shift text,
  p_quantity integer,p_loads jsonb,p_observed integer,p_notes text,
  p_expected_revision integer,p_program_id uuid default null,p_clear boolean default false
) returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.direction_execution_actuals; v_client text; v_shift text;
  v_planned integer; v_snapshot jsonb; v_program uuid; v_week date;
begin
  if not public.direction_program_can_manage() then raise exception 'Sin permiso para confirmar resultados' using errcode='42501'; end if;
  if p_kind is null or p_kind not in ('shipment','production') or p_date is null
    or p_date > (now() at time zone 'America/Mexico_City')::date or p_date < date '2000-01-01'
    or p_quantity is null or p_quantity not between 0 and 10000000
    or p_expected_revision is null or p_expected_revision < 0
    or p_observed is not null and p_observed not between 0 and 10000000
    or p_notes is null or length(p_notes)>4000 or p_clear is null then
    raise exception 'Fecha, cantidad o revisión de resultado inválida'; end if;
  if p_material is null or p_material not in ('PACA_NACIONAL','PACA_AMERICANA','PACA_LIMPIA','PACA_BASURA','CAPLE','CHATARRA','METAL','PAPEL','PLASTICO','MADERA') then
    raise exception 'Material inválido'; end if;
  v_week := date_trunc('week',p_date)::date;
  v_client := case when p_kind='shipment' then public.direction_execution_client(p_client) else '' end;
  v_shift := case when p_kind='production' then p_shift else '' end;
  if p_kind='production' and (p_material not in ('PACA_NACIONAL','PACA_AMERICANA','PACA_LIMPIA')
    or v_shift is null or v_shift not in ('DAY','NIGHT') or extract(isodow from p_date)>5) then
    raise exception 'La producción requiere material de cartón y turno de lunes a viernes'; end if;
  if p_kind='shipment' and (v_client='' or length(v_client)>250 or extract(isodow from p_date)>6) then
    raise exception 'El embarque requiere destino y fecha de lunes a sábado'; end if;
  if jsonb_typeof(p_loads) is distinct from 'array' or jsonb_array_length(p_loads)>1000 then
    raise exception 'Desglose de embarques inválido'; end if;
  if exists(select 1 from jsonb_array_elements(p_loads) x
    where jsonb_typeof(x) is distinct from 'number' or x::text !~ '^[0-9]+$'
      or x::text::numeric not between 1 and 10000000) then raise exception 'Cantidades por embarque inválidas'; end if;
  if p_kind='production' and jsonb_array_length(p_loads)<>0
    or p_kind='shipment' and (select coalesce(sum(x::text::numeric),0) from jsonb_array_elements(p_loads) x)<>p_quantity then
    raise exception 'El desglose no coincide con el total real'; end if;
  perform pg_advisory_xact_lock(hashtextextended('direction-actual:'||p_kind||':'||p_date::text||':'||p_material||':'||v_client||':'||v_shift,0));
  select * into r from public.direction_execution_actuals
    where kind=p_kind and op_date=p_date and material_code=p_material and client_name=v_client and shift=v_shift for update;
  if coalesce(r.revision,0)<>p_expected_revision then raise exception 'El resultado cambió en otra sesión. Revisa la lectura actual.' using errcode='PT409'; end if;
  if r.id is null and p_clear then raise exception 'No hay confirmación para restablecer'; end if;
  if r.id is null then
    if p_kind='production' and p_program_id is not null then
      select id into v_program from public.direction_operating_programs where id=p_program_id and week_start=v_week;
      if not found then raise exception 'La referencia de programa no corresponde a esta semana'; end if;
      select quantity,to_jsonb(l) into v_planned,v_snapshot from public.direction_operating_program_lines l
        where program_id=v_program and day_index=p_date-v_week and shift=v_shift and material_code=p_material;
      if not found then raise exception 'La celda no existe en el programa'; end if;
    elsif p_kind='shipment' then
      select sum(planned_units),coalesce(jsonb_agg(to_jsonb(s) order by id),'[]') into v_planned,v_snapshot
        from public.direction_shipment_plans s where ship_date=p_date and planning_material_code=p_material
          and status<>'cancelado' and public.direction_execution_client(client_name)=v_client;
    end if;
    insert into public.direction_execution_actuals(kind,op_date,material_code,client_name,shift,quantity,load_quantities,
      observed_quantity,planned_quantity,planned_snapshot,program_id,notes,updated_by)
    values(p_kind,p_date,p_material,v_client,v_shift,p_quantity,p_loads,p_observed,v_planned,coalesce(v_snapshot,'[]'),v_program,btrim(p_notes),auth.uid()) returning * into r;
  else
    update public.direction_execution_actuals set quantity=p_quantity,load_quantities=p_loads,
      observed_quantity=p_observed,notes=btrim(p_notes),active=not p_clear,revision=revision+1,
      updated_at=now(),updated_by=auth.uid() where id=r.id returning * into r;
  end if;
  insert into public.direction_execution_actual_revisions(actual_id,revision,payload) values(r.id,r.revision,to_jsonb(r));
  return to_jsonb(r);
end;
$$;
revoke all on function public.direction_save_execution_actual(text,date,text,text,text,integer,jsonb,integer,text,integer,uuid,boolean) from public,anon;
grant execute on function public.direction_save_execution_actual(text,date,text,text,text,integer,jsonb,integer,text,integer,uuid,boolean) to authenticated;
comment on table public.direction_execution_actuals is 'Resultados confirmados por Dirección; conservan la referencia planeada y reemplazan, sin sumar, el dato equivalente de Operación para el aprendizaje histórico.';
commit;
