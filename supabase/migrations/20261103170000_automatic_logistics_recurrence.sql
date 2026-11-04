begin;

alter table public.logistics_fixed_services
  alter column scheduled_time drop not null,
  add column series_id uuid,
  add column effective_from date not null default (now() at time zone 'America/Mexico_City')::date,
  add column effective_until date,
  add column visits_per_day integer not null default 1 check (visits_per_day between 1 and 20);
update public.logistics_fixed_services set series_id=id;
alter table public.logistics_fixed_services alter column series_id set not null,
  alter column series_id set default gen_random_uuid();
create unique index logistics_recurrence_current_revision
  on public.logistics_fixed_services(series_id) where effective_until is null;

alter table public.services
  add column recurrence_date date,
  add column recurrence_visit integer,
  add column recurrence_exception boolean not null default false,
  add column recurrence_auto_cancelled boolean not null default false;

-- A removed or rescheduled visit keeps its original slot. Refresh cannot recreate it.
create table public.logistics_recurrence_occurrences (
  series_id uuid not null,
  occurrence_date date not null,
  visit_number integer not null check (visit_number between 1 and 20),
  service_id uuid unique references public.services(id) on delete set null,
  primary key (series_id, occurrence_date, visit_number)
);
alter table public.logistics_recurrence_occurrences enable row level security;
grant select, insert, update on public.logistics_recurrence_occurrences to authenticated;
create policy logistics_recurrence_authenticated on public.logistics_recurrence_occurrences
  for all to authenticated using (true) with check (true);

create function public.logistics_mark_service_exception() returns trigger
language plpgsql set search_path=public,pg_temp as $$
begin
  if old.recurrence_date is not null
    and coalesce(current_setting('dicsa.recurrence_sync',true),'') <> 'on'
    and new is distinct from old then
    new.recurrence_exception := true;
    new.recurrence_auto_cancelled := false;
  end if;
  return new;
end $$;
create trigger services_recurrence_exception before update on public.services
for each row execute function public.logistics_mark_service_exception();

create function public.sync_logistics_recurring_services() returns jsonb
language plpgsql set search_path=public,pg_temp as $$
declare
  today date := (now() at time zone 'America/Mexico_City')::date;
  r record;
  sid uuid;
  claimed boolean;
  added integer := 0;
  previous_setting text := coalesce(current_setting('dicsa.recurrence_sync',true),'');
begin
  perform pg_advisory_xact_lock(20261103,1700);
  perform set_config('dicsa.recurrence_sync','on',true);
  -- Pause or changed days/quantity cancel only untouched planned visits.
  update services s set status='cancelado', recurrence_auto_cancelled=true
  from logistics_recurrence_occurrences o
  where o.service_id=s.id and o.occurrence_date>=today
    and not s.recurrence_exception and s.status='programado'
    and not exists (
      select 1 from logistics_fixed_services f
      where f.series_id=o.series_id and f.is_active
        and o.occurrence_date>=f.effective_from
        and (f.effective_until is null or o.occurrence_date<=f.effective_until)
        and f.weekdays @> to_jsonb(extract(isodow from o.occurrence_date)::int)
        and o.visit_number<=f.visits_per_day
    );
  for r in
    select f.*, d::date as visit_date, n as visit_number,
      v.id as vehicle, e.id as driver
    from logistics_fixed_services f
    cross join generate_series(today::timestamp,(today+6)::timestamp,interval '1 day') d
    cross join lateral generate_series(1,f.visits_per_day) n
    join sites c on c.id=f.site_id and c.is_active
    left join logistics_vehicle_profiles vp on vp.vehicle_id=f.default_vehicle_id
    left join vehicles v on v.id=f.default_vehicle_id and v.status='activo'
      and coalesce(vp.planning_status,'ACTIVO')<>'NO_PROGRAMAR'
    left join employees e on e.id=coalesce(f.default_driver_employee_id,
      case when v.id is not null then vp.assigned_driver_employee_id end)
      and e.is_driver and e.is_active
    where f.is_active and d::date>=f.effective_from
      and (f.effective_until is null or d::date<=f.effective_until)
      and f.weekdays @> to_jsonb(extract(isodow from d)::int)
    order by d,f.site_name,n
  loop
    insert into logistics_recurrence_occurrences(series_id,occurrence_date,visit_number)
      values(r.series_id,r.visit_date,r.visit_number) on conflict do nothing;
    claimed := found;
    select service_id into sid from logistics_recurrence_occurrences
      where series_id=r.series_id and occurrence_date=r.visit_date and visit_number=r.visit_number;
    if claimed then
      insert into services(service_date,due_date,scheduled_time,direction,status,planning_kind,
        fixed_service_id,client_id,client_name,material_type,material_id,
        driver_employee_id,vehicle_id,area,notes,recurrence_date,recurrence_visit)
      values(r.visit_date,r.visit_date,r.scheduled_time,r.movement,'programado','FIJO',
        r.id,r.site_id,r.site_name,coalesce(nullif(r.material_name,''),'SIN_MATERIAL'),null,
        r.driver,r.vehicle,'LOGISTICA',r.notes,r.visit_date,r.visit_number) returning id into sid;
      update logistics_recurrence_occurrences set service_id=sid
        where series_id=r.series_id and occurrence_date=r.visit_date and visit_number=r.visit_number;
      added := added+1;
    elsif sid is not null then
      update services set fixed_service_id=r.id,scheduled_time=r.scheduled_time,
        direction=r.movement,client_id=r.site_id,client_name=r.site_name,
        material_type=coalesce(nullif(r.material_name,''),'SIN_MATERIAL'),material_id=null,
        driver_employee_id=r.driver,vehicle_id=r.vehicle,notes=r.notes,
        status='programado',recurrence_auto_cancelled=false
      where id=sid and not recurrence_exception
        and (status='programado' or recurrence_auto_cancelled)
        and (fixed_service_id,scheduled_time,direction,client_id,client_name,material_type,
          driver_employee_id,vehicle_id,notes,recurrence_auto_cancelled)
          is distinct from (r.id,r.scheduled_time,r.movement,r.site_id,r.site_name,
          coalesce(nullif(r.material_name,''),'SIN_MATERIAL'),r.driver,r.vehicle,r.notes,false);
    end if;
  end loop;
  perform set_config('dicsa.recurrence_sync',previous_setting,true);
  return jsonb_build_object('inserted',added,'from',today,'through',today+6);
end $$;

-- Revision boundaries preserve past visits; edits only alter untouched future slots.
create function public.save_logistics_recurrence(p_record jsonb,p_from date default null)
returns jsonb language plpgsql set search_path=public,pg_temp as $$
declare
  today date := (now() at time zone 'America/Mexico_City')::date;
  starts date := coalesce(p_from,today);
  old_row logistics_fixed_services;
  new_row logistics_fixed_services;
  series uuid := gen_random_uuid();
  company_name text;
  material_label text;
begin
  perform pg_advisory_xact_lock(20261103,1700);
  if starts<today then raise exception 'La programación solo puede cambiar desde hoy en adelante'; end if;
  if nullif(p_record->>'id','') is not null then
    select * into strict old_row from logistics_fixed_services where id=(p_record->>'id')::uuid for update;
    if old_row.effective_until is not null then raise exception 'La programación cambió; vuelve a abrirla'; end if;
    if starts<old_row.effective_from then raise exception 'La fecha antecede a esta programación'; end if;
    series := old_row.series_id;
    update logistics_fixed_services set effective_until=starts-1 where id=old_row.id;
  end if;
  if jsonb_typeof(p_record->'weekdays')<>'array' or jsonb_array_length(p_record->'weekdays')=0
    or exists(select 1 from jsonb_array_elements_text(p_record->'weekdays') x where x::int not between 1 and 7)
    then raise exception 'Selecciona los días de la semana'; end if;
  select name into strict company_name from sites where id=(p_record->>'site_id')::uuid and is_active;
  if nullif(p_record->>'material_id','') is not null then
    select name into strict material_label from material_commercial_catalog_v2 where id=(p_record->>'material_id')::uuid;
  else material_label:=coalesce(nullif(p_record->>'material_name',''),'SIN_MATERIAL'); end if;
  insert into logistics_fixed_services(series_id,effective_from,site_id,site_name,material_id,
    material_name,movement,scheduled_time,weekdays,default_driver_employee_id,
    default_vehicle_id,is_active,notes,visits_per_day)
  values(series,starts,(p_record->>'site_id')::uuid,company_name,nullif(p_record->>'material_id','')::uuid,
    material_label,coalesce(p_record->>'movement','recoleccion'),nullif(p_record->>'scheduled_time','')::time,
    p_record->'weekdays',nullif(p_record->>'default_driver_employee_id','')::uuid,
    nullif(p_record->>'default_vehicle_id','')::uuid,coalesce((p_record->>'is_active')::boolean,true),
    nullif(p_record->>'notes',''),coalesce((p_record->>'visits_per_day')::int,1)) returning * into new_row;
  perform sync_logistics_recurring_services();
  return to_jsonb(new_row);
end $$;

create function public.change_logistics_recurrence_from_visit(p_service_id uuid,p_patch jsonb)
returns void language plpgsql set search_path=public,pg_temp as $$
declare s services; f logistics_fixed_services; current_f logistics_fixed_services; data jsonb;
begin
  perform pg_advisory_xact_lock(20261103,1700);
  select * into strict s from services where id=p_service_id for update;
  if s.recurrence_date is null or s.status<>'programado'
    or s.recurrence_date<(now() at time zone 'America/Mexico_City')::date then
    raise exception 'Solo se modifica la programación de visitas futuras pendientes'; end if;
  if exists(select 1 from jsonb_object_keys(p_patch) k where k not in
    ('client_id','client_name','material_type','scheduled_time','direction','driver_employee_id','vehicle_id','notes'))
    then raise exception 'Este cambio solo puede aplicarse a la visita'; end if;
  select * into strict f from logistics_fixed_services where id=s.fixed_service_id;
  select * into strict current_f from logistics_fixed_services where series_id=f.series_id and effective_until is null;
  data:=to_jsonb(current_f);
  if p_patch ? 'client_id' then data:=data||jsonb_build_object('site_id',p_patch->'client_id'); end if;
  if p_patch ? 'material_type' then data:=data||jsonb_build_object('material_name',p_patch->'material_type','material_id',null); end if;
  if p_patch ? 'scheduled_time' then data:=data||jsonb_build_object('scheduled_time',p_patch->'scheduled_time'); end if;
  if p_patch ? 'direction' then data:=data||jsonb_build_object('movement',p_patch->'direction'); end if;
  if p_patch ? 'driver_employee_id' then data:=data||jsonb_build_object('default_driver_employee_id',p_patch->'driver_employee_id'); end if;
  if p_patch ? 'vehicle_id' then data:=data||jsonb_build_object('default_vehicle_id',p_patch->'vehicle_id'); end if;
  if p_patch ? 'notes' then data:=data||jsonb_build_object('notes',p_patch->'notes'); end if;
  perform save_logistics_recurrence(data,s.recurrence_date);
  -- The chosen visit also receives the edit if it was already an exception.
  update services set
    client_id=case when p_patch ? 'client_id' then (p_patch->>'client_id')::uuid else client_id end,
    client_name=case when p_patch ? 'client_id' then (select name from sites where id=(p_patch->>'client_id')::uuid) else client_name end,
    material_type=case when p_patch ? 'material_type' then p_patch->>'material_type' else material_type end,
    scheduled_time=case when p_patch ? 'scheduled_time' then (p_patch->>'scheduled_time')::time else scheduled_time end,
    direction=case when p_patch ? 'direction' then p_patch->>'direction' else direction end,
    driver_employee_id=case when p_patch ? 'driver_employee_id' then (p_patch->>'driver_employee_id')::uuid else driver_employee_id end,
    vehicle_id=case when p_patch ? 'vehicle_id' then (p_patch->>'vehicle_id')::uuid else vehicle_id end,
    notes=case when p_patch ? 'notes' then p_patch->>'notes' else notes end
  where id=p_service_id;
end $$;

revoke all on function public.sync_logistics_recurring_services() from public;
revoke all on function public.save_logistics_recurrence(jsonb,date) from public;
revoke all on function public.change_logistics_recurrence_from_visit(uuid,jsonb) from public;
grant execute on function public.sync_logistics_recurring_services(),
  public.save_logistics_recurrence(jsonb,date),
  public.change_logistics_recurrence_from_visit(uuid,jsonb) to authenticated;

-- Supabase runs this even while every desktop client is closed.
do $cron$
begin
  if exists(select 1 from pg_available_extensions where name='pg_cron') then
    execute 'create extension if not exists pg_cron with schema pg_catalog';
    perform cron.schedule('dicsa-logistics-next-seven-days','5 6 * * *',
      'select public.sync_logistics_recurring_services();');
  end if;
end $cron$;
commit;
