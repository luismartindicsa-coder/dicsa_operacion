begin;

create table public.direction_shipment_week_clients (
  week_start date primary key check (extract(isodow from week_start) = 1),
  client_names text[] not null default '{}',
  check (array_position(client_names, null) is null)
);

alter table public.direction_shipment_week_clients enable row level security;
grant select, insert, update on public.direction_shipment_week_clients to authenticated;
create policy direction_shipment_week_clients_manage
  on public.direction_shipment_week_clients for all to authenticated
  using (public.direction_program_can_manage())
  with check (public.direction_program_can_manage());

comment on table public.direction_shipment_week_clients is
  'Empresas elegidas por semana para generar embarques sugeridos. Una semana nueva empieza sin selección; no elimina ni modifica embarques existentes.';

commit;
