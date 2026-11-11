begin;

-- Rendimiento needs aggregate mileage and fuel prices, not GPS locations or
-- the write RPCs protected by can_view_logistics_gps(). Keep those unchanged.
create function public.can_view_logistics_performance() returns boolean
language sql stable security definer set search_path = '' as $$
  select public.can_view_logistics_gps() or exists (
    select 1
    from public.profiles p join auth.users u on u.id = p.user_id
    cross join lateral (
      select regexp_replace(
        translate(lower(btrim(p.role)), 'áéíóú', 'aeiou'),
        '[[:space:]-]+', '_', 'g'
      ) as role
    ) normalized
    where p.user_id = auth.uid() and p.is_active
      and normalized.role <> 'bascula'
      and lower(btrim(coalesce(u.email, ''))) <> 'bascula@dicsamx.com'
      and (
        normalized.role in ('gerencia', 'management', 'gerencia_general')
        or normalized.role like 'gerencia\_%' escape '\'
        or normalized.role like 'management\_%' escape '\'
        or normalized.role like '%\_gerencia' escape '\'
        or normalized.role like '%\_management' escape '\'
        or lower(btrim(coalesce(u.email, ''))) = 'gerencia@dicsamx.com'
      )
  );
$$;
revoke all on function public.can_view_logistics_performance() from public, anon;
grant execute on function public.can_view_logistics_performance() to authenticated, service_role;

alter policy logistics_gps_mileage_read on public.logistics_gps_daily_mileage
  using ((select public.can_view_logistics_performance()));
alter policy logistics_load_mileage_read on public.logistics_gps_load_mileage
  using ((select public.can_view_logistics_performance()));
alter policy logistics_fuel_prices_read on public.logistics_fuel_prices
  using ((select public.can_view_logistics_performance()));

notify pgrst, 'reload schema';
commit;
