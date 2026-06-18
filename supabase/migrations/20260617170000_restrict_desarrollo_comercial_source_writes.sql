begin;

alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check
  check (
    role = any (
      array[
        'admin'::text,
        'ops_manager'::text,
        'services'::text,
        'fleet'::text,
        'fuel'::text,
        'viewer'::text,
        'direccion'::text,
        'desarrollo_comercial'::text
      ]
    )
  );

create or replace function public.is_desarrollo_comercial_profile()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and coalesce(p.is_active, true) = true
      and regexp_replace(
        lower(
          translate(coalesce(p.role, ''), 'áéíóúÁÉÍÓÚ', 'aeiouAEIOU')
        ),
        '[\s-]+',
        '_',
        'g'
      ) = 'desarrollo_comercial'
  );
$$;

comment on function public.is_desarrollo_comercial_profile() is
  'Retorna true cuando el usuario autenticado pertenece al perfil desarrollo_comercial. Se usa para bloquear escritura en tablas fuente de Menudeo y Mayoreo.';

drop policy if exists men_counterparties_authenticated_all
  on public.men_counterparties;
drop policy if exists men_material_aliases_authenticated_all
  on public.men_material_aliases;
drop policy if exists men_counterparty_material_prices_authenticated_all
  on public.men_counterparty_material_prices;
drop policy if exists men_tickets_authenticated_all
  on public.men_tickets;
drop policy if exists men_price_adjustment_history_authenticated_all
  on public.men_price_adjustment_history;

create policy men_counterparties_authenticated_read
  on public.men_counterparties
  for select
  to authenticated
  using (true);

create policy men_counterparties_authenticated_write_non_commercial
  on public.men_counterparties
  for all
  to authenticated
  using (not public.is_desarrollo_comercial_profile())
  with check (not public.is_desarrollo_comercial_profile());

create policy men_material_aliases_authenticated_read
  on public.men_material_aliases
  for select
  to authenticated
  using (true);

create policy men_material_aliases_authenticated_write_non_commercial
  on public.men_material_aliases
  for all
  to authenticated
  using (not public.is_desarrollo_comercial_profile())
  with check (not public.is_desarrollo_comercial_profile());

create policy men_counterparty_material_prices_authenticated_read
  on public.men_counterparty_material_prices
  for select
  to authenticated
  using (true);

create policy men_counterparty_material_prices_authenticated_write_non_commercial
  on public.men_counterparty_material_prices
  for all
  to authenticated
  using (not public.is_desarrollo_comercial_profile())
  with check (not public.is_desarrollo_comercial_profile());

create policy men_tickets_authenticated_read
  on public.men_tickets
  for select
  to authenticated
  using (true);

create policy men_tickets_authenticated_write_non_commercial
  on public.men_tickets
  for all
  to authenticated
  using (not public.is_desarrollo_comercial_profile())
  with check (not public.is_desarrollo_comercial_profile());

create policy men_price_adjustment_history_authenticated_read
  on public.men_price_adjustment_history
  for select
  to authenticated
  using (true);

create policy men_price_adjustment_history_authenticated_write_non_commercial
  on public.men_price_adjustment_history
  for all
  to authenticated
  using (not public.is_desarrollo_comercial_profile())
  with check (not public.is_desarrollo_comercial_profile());

drop policy if exists mayoreo_counterparties_authenticated_all
  on public.mayoreo_counterparties;
drop policy if exists mayoreo_material_catalog_authenticated_all
  on public.mayoreo_material_catalog;
drop policy if exists mayoreo_counterparty_material_prices_authenticated_all
  on public.mayoreo_counterparty_material_prices;
drop policy if exists mayoreo_sales_reports_authenticated_all
  on public.mayoreo_sales_reports;
drop policy if exists mayoreo_price_adjustment_history_authenticated_read
  on public.mayoreo_price_adjustment_history;
drop policy if exists mayoreo_price_adjustment_history_authenticated_insert
  on public.mayoreo_price_adjustment_history;

create policy mayoreo_counterparties_authenticated_read
  on public.mayoreo_counterparties
  for select
  to authenticated
  using (true);

create policy mayoreo_counterparties_authenticated_write_non_commercial
  on public.mayoreo_counterparties
  for all
  to authenticated
  using (not public.is_desarrollo_comercial_profile())
  with check (not public.is_desarrollo_comercial_profile());

create policy mayoreo_material_catalog_authenticated_read
  on public.mayoreo_material_catalog
  for select
  to authenticated
  using (true);

create policy mayoreo_material_catalog_authenticated_write_non_commercial
  on public.mayoreo_material_catalog
  for all
  to authenticated
  using (not public.is_desarrollo_comercial_profile())
  with check (not public.is_desarrollo_comercial_profile());

create policy mayoreo_counterparty_material_prices_authenticated_read
  on public.mayoreo_counterparty_material_prices
  for select
  to authenticated
  using (true);

create policy mayoreo_counterparty_material_prices_authenticated_write_non_commercial
  on public.mayoreo_counterparty_material_prices
  for all
  to authenticated
  using (not public.is_desarrollo_comercial_profile())
  with check (not public.is_desarrollo_comercial_profile());

create policy mayoreo_sales_reports_authenticated_read
  on public.mayoreo_sales_reports
  for select
  to authenticated
  using (true);

create policy mayoreo_sales_reports_authenticated_write_non_commercial
  on public.mayoreo_sales_reports
  for all
  to authenticated
  using (not public.is_desarrollo_comercial_profile())
  with check (not public.is_desarrollo_comercial_profile());

create policy mayoreo_price_adjustment_history_authenticated_read
  on public.mayoreo_price_adjustment_history
  for select
  to authenticated
  using (true);

create policy mayoreo_price_adjustment_history_authenticated_insert_non_commercial
  on public.mayoreo_price_adjustment_history
  for insert
  to authenticated
  with check (not public.is_desarrollo_comercial_profile());

drop policy if exists compras_counterparties_authenticated_all
  on public.compras_counterparties;
drop policy if exists compras_material_catalog_authenticated_all
  on public.compras_material_catalog;
drop policy if exists compras_counterparty_material_prices_authenticated_all
  on public.compras_counterparty_material_prices;
drop policy if exists compras_price_adjustment_history_authenticated_read
  on public.compras_price_adjustment_history;
drop policy if exists compras_price_adjustment_history_authenticated_insert
  on public.compras_price_adjustment_history;

create policy compras_counterparties_authenticated_read
  on public.compras_counterparties
  for select
  to authenticated
  using (true);

create policy compras_counterparties_authenticated_write_non_commercial
  on public.compras_counterparties
  for all
  to authenticated
  using (not public.is_desarrollo_comercial_profile())
  with check (not public.is_desarrollo_comercial_profile());

create policy compras_material_catalog_authenticated_read
  on public.compras_material_catalog
  for select
  to authenticated
  using (true);

create policy compras_material_catalog_authenticated_write_non_commercial
  on public.compras_material_catalog
  for all
  to authenticated
  using (not public.is_desarrollo_comercial_profile())
  with check (not public.is_desarrollo_comercial_profile());

create policy compras_counterparty_material_prices_authenticated_read
  on public.compras_counterparty_material_prices
  for select
  to authenticated
  using (true);

create policy compras_counterparty_material_prices_authenticated_write_non_commercial
  on public.compras_counterparty_material_prices
  for all
  to authenticated
  using (not public.is_desarrollo_comercial_profile())
  with check (not public.is_desarrollo_comercial_profile());

create policy compras_price_adjustment_history_authenticated_read
  on public.compras_price_adjustment_history
  for select
  to authenticated
  using (true);

create policy compras_price_adjustment_history_authenticated_insert_non_commercial
  on public.compras_price_adjustment_history
  for insert
  to authenticated
  with check (not public.is_desarrollo_comercial_profile());

commit;
