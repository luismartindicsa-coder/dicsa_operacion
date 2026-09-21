begin;

alter table public.logistics_diesel_consumption
  add column if not exists load_origin text not null default 'PATIO';

alter table public.logistics_diesel_consumption
  drop constraint if exists logistics_diesel_consumption_load_origin_chk;

alter table public.logistics_diesel_consumption
  add constraint logistics_diesel_consumption_load_origin_chk
  check (load_origin in ('PATIO', 'GASOLINERA'));

alter table public.logistics_gasoline_control
  add column if not exists load_origin text not null default 'GASOLINERA';

alter table public.logistics_gasoline_control
  drop constraint if exists logistics_gasoline_control_load_origin_chk;

alter table public.logistics_gasoline_control
  add constraint logistics_gasoline_control_load_origin_chk
  check (load_origin in ('PATIO', 'GASOLINERA'));

commit;
