begin;

create table public.direction_operating_programs (
  id uuid primary key,
  week_start date not null check (extract(isodow from week_start) = 1),
  version integer not null check (version > 0),
  status text not null default 'draft' check (status in ('draft','approved','executing')),
  is_operational boolean not null default false,
  conditions jsonb not null,
  shipments jsonb not null,
  created_by uuid not null default auth.uid(),
  created_at timestamptz not null default now(),
  approved_by uuid,
  approved_at timestamptz,
  execution_started_at timestamptz,
  unique (week_start, version)
);
create unique index direction_operating_one_current
  on public.direction_operating_programs(week_start) where is_operational;

create table public.direction_operating_program_lines (
  program_id uuid not null references public.direction_operating_programs(id),
  day_index integer not null check (day_index between 0 and 4),
  shift text not null check (shift in ('DAY','NIGHT')),
  material_code text not null check (material_code in ('PACA_NACIONAL','PACA_LIMPIA','PACA_AMERICANA')),
  quantity integer not null check (quantity between 0 and 1000000),
  primary key (program_id, day_index, shift, material_code)
);

alter table public.direction_operating_programs enable row level security;
alter table public.direction_operating_program_lines enable row level security;
grant select on public.direction_operating_programs, public.direction_operating_program_lines to authenticated;

create function public.direction_program_can_manage() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where user_id = auth.uid()
    and is_active = true and role in ('admin','direccion','ops_manager'));
$$;
create policy direction_program_read on public.direction_operating_programs
  for select to authenticated using (public.direction_program_can_manage());
create policy direction_program_lines_read on public.direction_operating_program_lines
  for select to authenticated using (public.direction_program_can_manage());

create function public.direction_program_source(p_week date) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', id::text, 'date', ship_date::text, 'destination', client_name,
    'material', planning_material_code, 'quantity', planned_units, 'priority', priority
  ) order by id), '[]'::jsonb)
  from public.direction_shipment_plans
  where ship_date between p_week and p_week + 4 and status = 'confirmado'
    and quantity_unit = 'PACAS'
    and planning_material_code in ('PACA_NACIONAL','PACA_LIMPIA','PACA_AMERICANA');
$$;

create function public.direction_program_payload(p_id uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select to_jsonb(p) || jsonb_build_object('lines', coalesce((
    select jsonb_agg(to_jsonb(l) - 'program_id' order by day_index, shift, material_code)
    from public.direction_operating_program_lines l where l.program_id = p.id
  ), '[]'::jsonb)) from public.direction_operating_programs p where p.id = p_id;
$$;

create function public.direction_program_check_machinery(p_week date, p_conditions jsonb)
returns void language plpgsql stable security definer set search_path = public as $$
declare d integer; loss integer;
begin
  for d in 0..4 loop
    select ceil((least(100,coalesce(sum(impact_percent) filter(where machine_key in ('c1','ambas')),0)) +
      least(100,coalesce(sum(impact_percent) filter(where machine_key in ('c2','ambas')),0)))::numeric/2)
      into loss from public.direction_production_capacity_impacts
      where is_active and start_date <= p_week+d and end_date >= p_week+d;
    if (p_conditions->'days'->d->>'loss_percent')::integer is distinct from loss then
      raise exception 'Las afectaciones de maquinaria cambiaron. Genera un nuevo borrador.' using errcode='PT409';
    end if;
  end loop;
end;
$$;

create function public.direction_save_operating_program(
  p_id uuid, p_week date, p_expected_version integer,
  p_conditions jsonb, p_shipments jsonb, p_lines jsonb
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_latest integer; v_capacity integer; v_share integer;
  v_day jsonb; v_material text; v_existing public.direction_operating_programs;
begin
  if not public.direction_program_can_manage() then raise exception 'Sin permiso para programar' using errcode='42501'; end if;
  if extract(isodow from p_week) <> 1 then raise exception 'La semana debe iniciar en lunes'; end if;
  perform pg_advisory_xact_lock(hashtextextended('direction-program:' || p_week::text, 0));
  select * into v_existing from public.direction_operating_programs where id = p_id;
  if found then
    if v_existing.week_start <> p_week or v_existing.conditions <> p_conditions or v_existing.shipments <> p_shipments
      or jsonb_array_length(p_lines) is distinct from 30
      or not ((public.direction_program_payload(p_id)->'lines') @> p_lines
        and p_lines @> (public.direction_program_payload(p_id)->'lines'))
      then raise exception 'Identificador de versión ya utilizado' using errcode='PT409'; end if;
    return public.direction_program_payload(p_id);
  end if;
  select coalesce(max(version),0) into v_latest from public.direction_operating_programs where week_start = p_week;
  if v_latest <> p_expected_version then raise exception 'La semana cambió. Reabre el historial antes de guardar.' using errcode='PT409'; end if;
  if public.direction_program_source(p_week) <> p_shipments then
    raise exception 'Los embarques confirmados cambiaron. Actualiza los embarques del borrador.' using errcode='PT409';
  end if;
  v_capacity := (p_conditions->>'daily_capacity')::integer;
  v_share := (p_conditions->>'day_share')::integer;
  if v_capacity is null or v_capacity not between 1 and 10000 or v_share is null or v_share not between 0 and 100
    or jsonb_typeof(p_conditions->'days') is distinct from 'array'
    or jsonb_array_length(p_conditions->'days') <> 5 then raise exception 'Condiciones inválidas'; end if;
  foreach v_material in array array['PACA_NACIONAL','PACA_LIMPIA','PACA_AMERICANA'] loop
    if (p_conditions->'yard'->>v_material)::integer is null or (p_conditions->'yard'->>v_material)::integer < 0
      then raise exception 'Patio inicial inválido'; end if;
  end loop;
  for v_day in select value from jsonb_array_elements(p_conditions->'days') loop
    if jsonb_typeof(v_day->'working') is distinct from 'boolean'
      or jsonb_typeof(v_day->'day_available') is distinct from 'boolean'
      or jsonb_typeof(v_day->'night_available') is distinct from 'boolean'
      or (v_day->>'loss_percent')::integer is null
      or (v_day->>'loss_percent')::integer not between 0 and 100 then raise exception 'Día inválido'; end if;
  end loop;
  perform public.direction_program_check_machinery(p_week, p_conditions);
  if jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) <> 30 then raise exception 'Se requieren 30 celdas de producción'; end if;
  insert into public.direction_operating_programs(id,week_start,version,conditions,shipments)
    values(p_id,p_week,v_latest+1,p_conditions,p_shipments);
  insert into public.direction_operating_program_lines(program_id,day_index,shift,material_code,quantity)
    select p_id,x.day_index,x.shift,x.material_code,x.quantity
    from jsonb_to_recordset(p_lines) as x(day_index integer,shift text,material_code text,quantity integer);
  return public.direction_program_payload(p_id);
end;
$$;

create function public.direction_approve_operating_program(p_id uuid, p_execute boolean default false)
returns jsonb language plpgsql security definer set search_path = public as $$
declare p public.direction_operating_programs; d integer; s text; m text;
  c jsonb; cap integer; day_cap integer; slot_cap integer; amount integer;
  produced integer; demand integer; v_week date;
begin
  if not public.direction_program_can_manage() then raise exception 'Sin permiso para aprobar' using errcode='42501'; end if;
  select week_start into v_week from public.direction_operating_programs where id = p_id;
  if not found then raise exception 'Programa inexistente'; end if;
  perform pg_advisory_xact_lock(hashtextextended('direction-program:' || v_week::text,0));
  select * into p from public.direction_operating_programs where id = p_id for update;
  if p_execute then
    if p.status not in ('approved','executing') or not p.is_operational then raise exception 'Solo puede ejecutarse la versión operativa aprobada'; end if;
    update public.direction_operating_programs set status='executing', execution_started_at=coalesce(execution_started_at,now()) where id=p_id;
    return public.direction_program_payload(p_id);
  end if;
  if p.status <> 'draft' then raise exception 'Esta versión ya está fijada'; end if;
  if public.direction_program_source(p.week_start) <> p.shipments then
    raise exception 'Los embarques cambiaron. Genera un nuevo borrador.' using errcode='PT409';
  end if;
  if jsonb_array_length(p.shipments) = 0 then raise exception 'No hay embarques confirmados para aprobar'; end if;
  perform public.direction_program_check_machinery(p.week_start, p.conditions);
  for d in 0..4 loop
    c := p.conditions->'days'->d;
    cap := floor((p.conditions->>'daily_capacity')::numeric * (100-(c->>'loss_percent')::numeric)/100);
    day_cap := round(cap * (p.conditions->>'day_share')::numeric/100);
    foreach s in array array['DAY','NIGHT'] loop
      slot_cap := case when not (c->>'working')::boolean then 0
        when s='DAY' and (c->>'day_available')::boolean then day_cap
        when s='NIGHT' and (c->>'night_available')::boolean then cap-day_cap else 0 end;
      select coalesce(sum(quantity),0) into amount from public.direction_operating_program_lines
        where program_id=p_id and day_index=d and shift=s;
      if amount > slot_cap then raise exception 'Producción excede capacidad o usa un turno bloqueado: día %, turno %',d+1,s; end if;
    end loop;
    foreach m in array array['PACA_NACIONAL','PACA_LIMPIA','PACA_AMERICANA'] loop
      select coalesce(sum(quantity),0) into produced from public.direction_operating_program_lines
        where program_id=p_id and material_code=m and (day_index<d or (day_index=d and shift='DAY'));
      select coalesce(sum((value->>'quantity')::integer),0) into demand
        from jsonb_array_elements(p.shipments) where value->>'material'=m and (value->>'date')::date<=p.week_start+d;
      if produced + (p.conditions->'yard'->>m)::integer < demand then
        raise exception 'Faltante de % para el día %',m,p.week_start+d; end if;
    end loop;
  end loop;
  update public.direction_operating_programs set is_operational=false where week_start=p.week_start and is_operational;
  update public.direction_operating_programs set status='approved',is_operational=true,
    approved_by=auth.uid(),approved_at=now() where id=p_id;
  return public.direction_program_payload(p_id);
end;
$$;

revoke all on function public.direction_program_source(date), public.direction_program_payload(uuid),
  public.direction_program_check_machinery(date,jsonb) from public, anon, authenticated;
revoke all on function public.direction_program_can_manage(),
  public.direction_save_operating_program(uuid,date,integer,jsonb,jsonb,jsonb),
  public.direction_approve_operating_program(uuid,boolean) from public, anon;
grant execute on function public.direction_program_can_manage(),
  public.direction_save_operating_program(uuid,date,integer,jsonb,jsonb,jsonb),
  public.direction_approve_operating_program(uuid,boolean) to authenticated;

comment on table public.direction_operating_programs is 'Versiones inmutables del programa de lunes a viernes. La aprobación fija una sola versión operativa por semana.';
commit;
