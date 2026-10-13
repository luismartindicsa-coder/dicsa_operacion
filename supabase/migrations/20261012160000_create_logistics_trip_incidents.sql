begin;
create table public.logistics_trip_incidents (
  id uuid primary key default gen_random_uuid(),
  service_id uuid references public.services(id) on delete set null,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  driver_employee_id uuid references public.employees(id) on delete set null,
  service_label text not null default '',
  vehicle_code text not null default '',
  driver_name text not null default '',
  incident_type text not null check (incident_type in ('ACCESO','CAMBIO_UNIDAD','FALLA_MECANICA','FALTA_CHOFER','MATERIAL_NO_LISTO','OTRA','REPROGRAMACION','RETRASO')),
  impact_level text not null default 'MEDIA' check (impact_level in ('ALTA','MEDIA','BAJA')),
  resolution_status text not null default 'ABIERTA' check (resolution_status in ('ABIERTA','EN_SEGUIMIENTO','RESUELTA')),
  summary text not null check (length(btrim(summary)) > 0),
  action_taken text not null default '',
  responsible_name text not null default '',
  notes text not null default '',
  reported_at timestamptz not null default now(),
  reported_by uuid default auth.uid() references auth.users(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (resolution_status <> 'RESUELTA' or length(btrim(action_taken)) > 0),
  check ((resolution_status = 'RESUELTA') = (resolved_at is not null))
);
create index logistics_trip_incidents_vehicle_idx on public.logistics_trip_incidents(vehicle_id,resolution_status,reported_at desc);
create index logistics_trip_incidents_service_idx on public.logistics_trip_incidents(service_id);
create function public.set_logistics_incident_timestamps() returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE' then
    new.updated_at := greatest(clock_timestamp(), old.updated_at + interval '1 microsecond');
  else
    new.updated_at := clock_timestamp();
  end if;
  if new.resolution_status = 'RESUELTA' then
    if tg_op = 'UPDATE' and old.resolution_status = 'RESUELTA' then new.resolved_at := old.resolved_at;
    else new.resolved_at := clock_timestamp(); end if;
  else new.resolved_at := null; end if;
  return new;
end;
$$;
create trigger logistics_trip_incidents_timestamps before insert or update on public.logistics_trip_incidents
for each row execute function public.set_logistics_incident_timestamps();
alter table public.logistics_trip_incidents enable row level security;
grant select,insert,update on public.logistics_trip_incidents to authenticated;
create policy logistics_trip_incidents_read on public.logistics_trip_incidents for select to authenticated using (true);
create policy logistics_trip_incidents_insert on public.logistics_trip_incidents for insert to authenticated with check (true);
create policy logistics_trip_incidents_update on public.logistics_trip_incidents for update to authenticated using (true) with check (true);
comment on table public.logistics_trip_incidents is 'Seguimiento operativo de Logística. Solo advertencias; no bloquea ni modifica servicios, unidades u órdenes de mantenimiento.';
commit;
