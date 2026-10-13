begin;
-- Manual information owned by Logistics; no changes to operational assignments.
create table public.logistics_unit_states (
  vehicle_id uuid primary key references public.vehicles(id) on delete cascade,
  operational_status text not null check (operational_status in (
    'DISPONIBLE','ASIGNADA','EN_RUTA','EN_REVISION','EN_MANTENIMIENTO','FUERA_DE_SERVICIO'
  )),
  notes text not null default '',
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
create function public.set_logistics_unit_state_metadata() returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE' then
    new.updated_at := greatest(clock_timestamp(), old.updated_at + interval '1 microsecond');
  else
    new.updated_at := clock_timestamp();
  end if;
  new.updated_by := auth.uid();
  return new;
end;
$$;
create trigger logistics_unit_states_metadata before insert or update on public.logistics_unit_states
for each row execute function public.set_logistics_unit_state_metadata();
alter table public.logistics_unit_states enable row level security;
grant select,insert,update on public.logistics_unit_states to authenticated;
create policy logistics_unit_states_read on public.logistics_unit_states for select to authenticated using (true);
create policy logistics_unit_states_insert on public.logistics_unit_states for insert to authenticated with check (true);
create policy logistics_unit_states_update on public.logistics_unit_states for update to authenticated using (true) with check (true);
comment on table public.logistics_unit_states is 'Estado manual y observaciones de cada unidad, propios de Logística. Es informativo; no bloquea asignaciones ni se infiere de Servicios o Mantenimiento.';
commit;
