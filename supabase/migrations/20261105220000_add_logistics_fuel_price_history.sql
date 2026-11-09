begin;

-- Dated general prices are independent of GPS readings and Excel imports.
-- A blank fuel keeps its previous rate; each fuel changes on its own dates.
create table public.logistics_fuel_prices (
  effective_date date primary key,
  diesel_price_per_liter numeric(8,2),
  gasoline_price_per_liter numeric(8,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  check (diesel_price_per_liter is not null or gasoline_price_per_liter is not null),
  check (diesel_price_per_liter is null or diesel_price_per_liter between 0.01 and 999999.99),
  check (gasoline_price_per_liter is null or gasoline_price_per_liter between 0.01 and 999999.99)
);
alter table public.logistics_fuel_prices enable row level security;
revoke all on public.logistics_fuel_prices from public,anon,authenticated;
grant select on public.logistics_fuel_prices to authenticated;
grant all on public.logistics_fuel_prices to service_role;
create policy logistics_fuel_prices_read on public.logistics_fuel_prices
  for select to authenticated using ((select public.can_view_logistics_gps()));

create function public.set_logistics_fuel_prices(p_effective_date date,
  p_diesel numeric default null,p_gasoline numeric default null) returns void
language plpgsql security definer set search_path='' as $$
begin
  if not public.can_view_logistics_gps() then raise insufficient_privilege; end if;
  if p_effective_date is null or p_effective_date<date '2000-01-01'
    or p_effective_date>(now() at time zone 'America/Mexico_City')::date then
    raise exception 'La fecha de vigencia no puede estar en el futuro.';
  end if;
  if p_diesel is null and p_gasoline is null then
    raise exception 'Captura al menos un precio de combustible.';
  end if;
  if (p_diesel is not null and not(p_diesel between 0.01 and 999999.99 and p_diesel=round(p_diesel,2)))
    or (p_gasoline is not null and not(p_gasoline between 0.01 and 999999.99 and p_gasoline=round(p_gasoline,2))) then
    raise exception 'Captura un precio mayor a 0 con hasta 2 decimales.';
  end if;
  insert into public.logistics_fuel_prices(effective_date,diesel_price_per_liter,gasoline_price_per_liter,updated_by)
    values(p_effective_date,p_diesel,p_gasoline,auth.uid())
    on conflict(effective_date) do update set
      diesel_price_per_liter=coalesce(excluded.diesel_price_per_liter,logistics_fuel_prices.diesel_price_per_liter),
      gasoline_price_per_liter=coalesce(excluded.gasoline_price_per_liter,logistics_fuel_prices.gasoline_price_per_liter),
      updated_at=now(),updated_by=auth.uid();
end; $$;
revoke all on function public.set_logistics_fuel_prices(date,numeric,numeric) from public,anon;
grant execute on function public.set_logistics_fuel_prices(date,numeric,numeric) to authenticated;

comment on table public.logistics_fuel_prices is
  'Precios generales vigentes por fecha. Cada combustible conserva el último valor no nulo. Los precios individuales de unidad/día tienen prioridad.';
notify pgrst,'reload schema';
commit;
