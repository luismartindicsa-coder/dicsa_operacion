alter table public.logistics_vehicle_mileage
  add column if not exists diesel_price_per_liter numeric(8,2),
  add column if not exists gasoline_price_per_liter numeric(8,2);

alter table public.logistics_vehicle_mileage
  add constraint logistics_mileage_diesel_price_valid check (
    diesel_price_per_liter is null or
    (diesel_price_per_liter > 0 and diesel_price_per_liter <= 999999.99)
  ),
  add constraint logistics_mileage_gasoline_price_valid check (
    gasoline_price_per_liter is null or
    (gasoline_price_per_liter > 0 and gasoline_price_per_liter <= 999999.99)
  );

comment on column public.logistics_vehicle_mileage.diesel_price_per_liter
  is 'Precio de diésel por litro capturado al importar esta lectura. NULL significa sin capturar.';
comment on column public.logistics_vehicle_mileage.gasoline_price_per_liter
  is 'Precio de gasolina por litro capturado al importar esta lectura. NULL significa sin capturar.';
