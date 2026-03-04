alter table if exists public.movements
  add column if not exists gross_kg numeric,
  add column if not exists tare_kg numeric,
  add column if not exists net_kg numeric,
  add column if not exists humidity_percent numeric,
  add column if not exists trash_kg numeric,
  add column if not exists total_amount_kg numeric;

update public.movements
set
  net_kg = coalesce(net_kg, weight_kg),
  total_amount_kg = coalesce(total_amount_kg, coalesce(net_kg, weight_kg))
where net_kg is null or total_amount_kg is null;
