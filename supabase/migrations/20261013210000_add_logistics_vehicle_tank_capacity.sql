begin;

alter table public.logistics_vehicle_profiles
  add column tank_capacity_liters numeric(8,2),
  add constraint logistics_vehicle_profiles_tank_capacity_chk check (
    tank_capacity_liters is null
    or (tank_capacity_liters > 0 and tank_capacity_liters <= 999999.99)
  );

comment on column public.logistics_vehicle_profiles.tank_capacity_liters is
  'Capacidad del tanque de combustible de la unidad, en litros. NULL si aún no se captura.';

commit;
