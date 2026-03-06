begin;

alter table if exists public.vehicles
  add column if not exists serial_number text;

create index if not exists vehicles_serial_number_idx on public.vehicles (serial_number);

commit;
