begin;

alter table if exists public.production_runs
  add column if not exists site text not null default 'DICSA_CELAYA';
alter table if exists public.production_runs
  alter column site set default 'DICSA_CELAYA';

alter table if exists public.material_separation_runs
  add column if not exists site text not null default 'DICSA_CELAYA';
alter table if exists public.material_separation_runs
  alter column site set default 'DICSA_CELAYA';

alter table if exists public.movements
  add column if not exists site text not null default 'DICSA_CELAYA';
alter table if exists public.movements
  alter column site set default 'DICSA_CELAYA';

alter table if exists public.opening_balances
  add column if not exists site text not null default 'DICSA_CELAYA';
alter table if exists public.opening_balances
  alter column site set default 'DICSA_CELAYA';

alter table if exists public.inventory_opening_templates
  add column if not exists site text not null default 'DICSA';
alter table if exists public.inventory_opening_templates
  alter column site set default 'DICSA';

create or replace function public.fn_sync_production_run_movements()
returns trigger
language plpgsql
as $$
declare
  v_row_id uuid := coalesce(new.id, old.id);
  v_site text := coalesce(new.site, old.site, 'DICSA_CELAYA');
  v_weight numeric := 0;
  v_source text := coalesce(new.source_bulk::text, old.source_bulk::text);
  v_product text := coalesce(new.bale_material::text, old.bale_material::text);
  v_date date := coalesce(new.op_date, old.op_date);
  v_notes text := nullif(btrim(coalesce(new.notes, old.notes, '')), '');
  v_source_commercial text := case upper(coalesce(new.source_bulk::text, old.source_bulk::text, ''))
    when 'CARDBOARD_BULK_NATIONAL' then 'CARTON_NACIONAL'
    when 'CARDBOARD_BULK_AMERICAN' then 'CARTON_AMERICANO'
    when 'CAPLE' then 'CAPLE'
    else nullif(btrim(coalesce(new.source_bulk::text, old.source_bulk::text, '')), '')
  end;
  v_product_commercial text := case upper(coalesce(new.bale_material::text, old.bale_material::text, ''))
    when 'BALE_NATIONAL' then 'PACA_NACIONAL'
    when 'BALE_AMERICAN' then 'PACA_AMERICANA'
    when 'BALE_CLEAN' then 'PACA_LIMPIA'
    when 'BALE_TRASH' then 'PACA_BASURA'
    when 'CAPLE' then 'CAPLE'
    else nullif(btrim(coalesce(new.bale_material::text, old.bale_material::text, '')), '')
  end;
  v_source_material_id uuid;
  v_product_material_id uuid;
begin
  select m.id
    into v_source_material_id
    from public.materials m
   where upper(coalesce(m.inventory_material_code::text, '')) = upper(coalesce(v_source, ''))
   limit 1;

  select m.id
    into v_product_material_id
    from public.materials m
   where upper(coalesce(m.inventory_material_code::text, '')) = upper(coalesce(v_product, ''))
   limit 1;

  delete from public.movements
  where movement_origin = 'PRODUCTION'
    and origin_table = 'production_runs'
    and origin_row_id = v_row_id;

  if tg_op = 'DELETE' then
    return old;
  end if;

  v_weight := coalesce(
    new.produced_weight_kg,
    coalesce(new.bale_count, 0)::numeric * coalesce(new.avg_bale_weight_kg, 0)
  );

  if v_weight <= 0
    or v_date is null
    or v_source is null
    or v_product is null
    or btrim(v_source) = ''
    or btrim(v_product) = '' then
    return new;
  end if;

  insert into public.movements (
    op_date,
    flow,
    material_id,
    material,
    weight_kg,
    net_kg,
    total_amount_kg,
    counterparty,
    reference,
    notes,
    site,
    movement_origin,
    origin_table,
    origin_row_id,
    origin_line,
    commercial_material_code,
    movement_reason
  ) values (
    v_date,
    'OUT'::public.inv_flow,
    v_source_material_id,
    v_source::public.inv_material,
    v_weight,
    v_weight,
    v_weight,
    'PRODUCCION INTERNA',
    concat('PRD:', v_row_id::text),
    coalesce(v_notes, 'Salida interna generada por producción'),
    v_site,
    'PRODUCTION',
    'production_runs',
    v_row_id,
    'SOURCE_OUT',
    v_source_commercial,
    null
  );

  insert into public.movements (
    op_date,
    flow,
    material_id,
    material,
    weight_kg,
    net_kg,
    total_amount_kg,
    counterparty,
    reference,
    notes,
    site,
    movement_origin,
    origin_table,
    origin_row_id,
    origin_line,
    commercial_material_code,
    movement_reason
  ) values (
    v_date,
    'IN'::public.inv_flow,
    v_product_material_id,
    v_product::public.inv_material,
    v_weight,
    v_weight,
    v_weight,
    'PRODUCCION INTERNA',
    concat('PRD:', v_row_id::text),
    coalesce(v_notes, 'Entrada interna generada por producción'),
    v_site,
    'PRODUCTION',
    'production_runs',
    v_row_id,
    'PRODUCT_IN',
    v_product_commercial,
    null
  );

  return new;
end;
$$;

create or replace function public.fn_sync_material_separation_movements()
returns trigger
language plpgsql
as $$
declare
  v_row_id uuid := coalesce(new.id, old.id);
  v_site text := coalesce(new.site, old.site, 'DICSA_CELAYA');
  v_source text := coalesce(new.source_material, old.source_material);
  v_mode text := upper(coalesce(new.source_mode::text, old.source_mode::text, 'MIXED'));
  v_date date := coalesce(new.op_date, old.op_date);
  v_weight numeric := coalesce(new.weight_kg, old.weight_kg, 0);
  v_commercial text := nullif(btrim(coalesce(new.commercial_material_code, old.commercial_material_code, '')), '');
  v_notes text := nullif(btrim(coalesce(new.notes, old.notes, '')), '');
  v_mixed_commercial text := case upper(coalesce(new.source_material, old.source_material, ''))
    when 'SCRAP' then 'CHATARRA_MIXTA'
    when 'PAPER' then 'PAPEL_REVUELTO'
    else concat(upper(coalesce(new.source_material, old.source_material, '')), '_MIXTO')
  end;
  v_source_material_id uuid;
  v_product_material_id uuid;
begin
  select m.id
    into v_source_material_id
    from public.materials m
   where upper(coalesce(m.inventory_material_code::text, '')) = upper(coalesce(v_source, ''))
   limit 1;

  select cmc.material_id
    into v_product_material_id
    from public.commercial_material_catalog cmc
   where upper(cmc.code) = upper(coalesce(v_commercial, ''))
   limit 1;

  if v_product_material_id is null then
    v_product_material_id := v_source_material_id;
  end if;

  delete from public.movements
  where movement_origin = 'SEPARATION'
    and origin_table = 'material_separation_runs'
    and origin_row_id = v_row_id;

  if tg_op = 'DELETE' then
    return old;
  end if;

  if v_mode <> 'MIXED' or v_weight <= 0 or v_date is null or v_source is null or v_commercial is null then
    return new;
  end if;

  insert into public.movements (
    op_date,
    flow,
    material_id,
    material,
    weight_kg,
    net_kg,
    total_amount_kg,
    counterparty,
    reference,
    notes,
    site,
    movement_origin,
    origin_table,
    origin_row_id,
    origin_line,
    commercial_material_code,
    movement_reason
  ) values (
    v_date,
    'OUT'::public.inv_flow,
    v_source_material_id,
    upper(v_source)::public.inv_material,
    v_weight,
    v_weight,
    v_weight,
    'SEPARACION INTERNA',
    concat('SEP:', v_row_id::text),
    coalesce(v_notes, 'Salida interna generada por separación'),
    v_site,
    'SEPARATION',
    'material_separation_runs',
    v_row_id,
    'SOURCE_OUT',
    v_mixed_commercial,
    null
  );

  insert into public.movements (
    op_date,
    flow,
    material_id,
    material,
    weight_kg,
    net_kg,
    total_amount_kg,
    counterparty,
    reference,
    notes,
    site,
    movement_origin,
    origin_table,
    origin_row_id,
    origin_line,
    commercial_material_code,
    movement_reason
  ) values (
    v_date,
    'IN'::public.inv_flow,
    v_product_material_id,
    upper(v_source)::public.inv_material,
    v_weight,
    v_weight,
    v_weight,
    'SEPARACION INTERNA',
    concat('SEP:', v_row_id::text),
    coalesce(v_notes, 'Entrada interna generada por separación'),
    v_site,
    'SEPARATION',
    'material_separation_runs',
    v_row_id,
    'PRODUCT_IN',
    v_commercial,
    null
  );

  return new;
end;
$$;

drop view if exists public.v_cardboard_widget;
drop view if exists public.v_inventory_summary;

create view public.v_inventory_summary as
with params as (
  select
    date_trunc('month', current_date)::date as period_month,
    current_date::date as as_of_date,
    'DICSA_CELAYA'::text as site
)
select
  p.site,
  r.material::public.inv_material as material,
  r.opening_kg,
  r.net_movement_kg,
  r.prod_in_kg,
  r.prod_out_kg,
  r.on_hand_kg
from params p
cross join lateral public.rpc_inventory_summary_by_period(
  p.period_month,
  p.as_of_date,
  p.site
) r;

create view public.v_cardboard_widget as
select
  coalesce(sum(case when material in ('CARDBOARD_BULK_NATIONAL', 'CARDBOARD_BULK_AMERICAN') then on_hand_kg else 0 end), 0)::numeric as bulk_kg,
  coalesce(sum(case when material in ('BALE_NATIONAL', 'BALE_AMERICAN', 'BALE_CLEAN', 'BALE_TRASH', 'CAPLE') then on_hand_kg else 0 end), 0)::numeric as bales_kg,
  coalesce(sum(case when material in ('CARDBOARD_BULK_NATIONAL', 'CARDBOARD_BULK_AMERICAN', 'BALE_NATIONAL', 'BALE_AMERICAN', 'BALE_CLEAN', 'BALE_TRASH', 'CAPLE') then on_hand_kg else 0 end), 0)::numeric as cardboard_kg,
  coalesce(sum(case when material = 'SCRAP' then on_hand_kg else 0 end), 0)::numeric as scrap_kg,
  coalesce(sum(case when material in ('METAL', 'METAL_ALUMINUM', 'METAL_STEEL', 'METAL_COPPER', 'METAL_BRASS', 'METAL_OTHER') then on_hand_kg else 0 end), 0)::numeric as metal_kg,
  coalesce(sum(case when material = 'WOOD' then on_hand_kg else 0 end), 0)::numeric as wood_kg,
  coalesce(sum(case when material = 'PAPER' then on_hand_kg else 0 end), 0)::numeric as paper_kg,
  coalesce(sum(case when material = 'PLASTIC' then on_hand_kg else 0 end), 0)::numeric as plastic_kg
from public.v_inventory_summary;

create or replace function public.seed_demo_operational_data(
  reset_existing boolean default false
)
returns void
language plpgsql
as $$
declare
  v_period_month date := date_trunc('month', current_date)::date;
  v_site_inventory text := 'DICSA_CELAYA';
  v_site_template text := 'DICSA';
  v_area_logistica_id uuid;
  v_area_mantenimiento_id uuid;
  v_mat_carton_nacional uuid;
  v_mat_carton_americano uuid;
  v_mat_paca_nacional uuid;
  v_mat_paca_americana uuid;
  v_mat_paca_limpia uuid;
  v_mat_paca_basura uuid;
  v_mat_caple uuid;
  v_mat_chatarra uuid;
  v_mat_papel uuid;
  v_mat_plastico uuid;
  v_mat_tarima uuid;
  v_client_aceros uuid;
  v_client_bajio uuid;
  v_client_papelera uuid;
  v_provider_reciclados uuid;
  v_provider_industrial uuid;
  v_driver_juan uuid;
  v_driver_luis uuid;
  v_driver_pedro uuid;
  v_vehicle_14 uuid;
  v_vehicle_21 uuid;
  v_vehicle_7 uuid;
  v_wh_filter uuid;
  v_wh_hose uuid;
  v_wh_grease uuid;
  v_wh_gloves uuid;
  v_cut_id uuid;
  v_ot_1 uuid;
  v_ot_2 uuid;
  v_ot_3 uuid;
begin
  select id into v_area_logistica_id
  from public.areas
  where upper(name) = 'LOGISTICA'
  limit 1;

  select id into v_area_mantenimiento_id
  from public.areas
  where upper(name) = 'MANTENIMIENTO'
  limit 1;

  if reset_existing then
    delete from public.maintenance_evidence;
    delete from public.maintenance_approvals;
    delete from public.maintenance_status_log;
    delete from public.maintenance_time_logs;
    delete from public.maintenance_materials;
    delete from public.maintenance_tasks;
    delete from public.maintenance_orders;

    delete from public.opening_balances;
    delete from public.inventory_monthly_cut_lines;
    delete from public.inventory_monthly_cuts;
    delete from public.inventory_movements;
    delete from public.inventory_items;

    delete from public.services;
    delete from public.pesadas;
    truncate table public.material_separation_runs;
    truncate table public.production_runs;
    truncate table public.movements;

    delete from public.inventory_opening_templates;
    delete from public.commercial_material_catalog;
    delete from public.materials;
    delete from public.sites;
  end if;

  insert into public.inventory_monthly_cuts (
    period_month, month, year, status
  ) values (
    v_period_month,
    extract(month from current_date)::int,
    extract(year from current_date)::int,
    'abierto'
  )
  returning id into v_cut_id;

  insert into public.sites (name, type)
  values
    ('ACEROS DEL BAJIO', 'cliente'),
    ('MANUFACTURAS DEL CENTRO', 'cliente'),
    ('PAPELERA CELAYA', 'cliente'),
    ('RECICLADOS INDUSTRIALES', 'proveedor'),
    ('RECUPERADORA INDUSTRIAL DEL BAJIO', 'proveedor');

  select id into v_client_aceros from public.sites where name = 'ACEROS DEL BAJIO' limit 1;
  select id into v_client_bajio from public.sites where name = 'MANUFACTURAS DEL CENTRO' limit 1;
  select id into v_client_papelera from public.sites where name = 'PAPELERA CELAYA' limit 1;
  select id into v_provider_reciclados from public.sites where name = 'RECICLADOS INDUSTRIALES' limit 1;
  select id into v_provider_industrial from public.sites where name = 'RECUPERADORA INDUSTRIAL DEL BAJIO' limit 1;

  insert into public.employees (full_name, is_driver, is_active)
  select 'JUAN PEREZ', true, true
  where not exists (
    select 1 from public.employees where upper(full_name) = 'JUAN PEREZ'
  );

  insert into public.employees (full_name, is_driver, is_active)
  select 'LUIS RAMIREZ', true, true
  where not exists (
    select 1 from public.employees where upper(full_name) = 'LUIS RAMIREZ'
  );

  insert into public.employees (full_name, is_driver, is_active)
  select 'PEDRO GARCIA', true, true
  where not exists (
    select 1 from public.employees where upper(full_name) = 'PEDRO GARCIA'
  );

  select id into v_driver_juan from public.employees where full_name = 'JUAN PEREZ' limit 1;
  select id into v_driver_luis from public.employees where full_name = 'LUIS RAMIREZ' limit 1;
  select id into v_driver_pedro from public.employees where full_name = 'PEDRO GARCIA' limit 1;

  select id into v_vehicle_14
  from public.vehicles
  where status::text = 'activo'
  order by code nulls last, created_at nulls last
  limit 1;

  select id into v_vehicle_21
  from public.vehicles
  where status::text = 'activo'
    and id is distinct from v_vehicle_14
  order by code nulls last, created_at nulls last
  limit 1;

  select id into v_vehicle_7
  from public.vehicles
  where status::text = 'activo'
    and id is distinct from v_vehicle_14
    and id is distinct from v_vehicle_21
  order by code nulls last, created_at nulls last
  limit 1;

  insert into public.materials (name, area_id, inventory_material_code, is_active)
  values
    ('CARTON NACIONAL', v_area_logistica_id, 'CARDBOARD_BULK_NATIONAL', true),
    ('CARTON AMERICANO', v_area_logistica_id, 'CARDBOARD_BULK_AMERICAN', true),
    ('PACA NACIONAL', v_area_logistica_id, 'BALE_NATIONAL', true),
    ('PACA AMERICANA', v_area_logistica_id, 'BALE_AMERICAN', true),
    ('PACA LIMPIA', v_area_logistica_id, 'BALE_CLEAN', true),
    ('PACA BASURA', v_area_logistica_id, 'BALE_TRASH', true),
    ('CAPLE', v_area_logistica_id, 'CAPLE', true),
    ('CHATARRA', v_area_logistica_id, 'SCRAP', true),
    ('PAPEL', v_area_logistica_id, 'PAPER', true),
    ('PLASTICO', v_area_logistica_id, 'PLASTIC', true),
    ('TARIMA', v_area_logistica_id, 'WOOD', true);

  select id into v_mat_carton_nacional from public.materials where inventory_material_code = 'CARDBOARD_BULK_NATIONAL' limit 1;
  select id into v_mat_carton_americano from public.materials where inventory_material_code = 'CARDBOARD_BULK_AMERICAN' limit 1;
  select id into v_mat_paca_nacional from public.materials where inventory_material_code = 'BALE_NATIONAL' limit 1;
  select id into v_mat_paca_americana from public.materials where inventory_material_code = 'BALE_AMERICAN' limit 1;
  select id into v_mat_paca_limpia from public.materials where inventory_material_code = 'BALE_CLEAN' limit 1;
  select id into v_mat_paca_basura from public.materials where inventory_material_code = 'BALE_TRASH' limit 1;
  select id into v_mat_caple from public.materials where inventory_material_code = 'CAPLE' limit 1;
  select id into v_mat_chatarra from public.materials where inventory_material_code = 'SCRAP' limit 1;
  select id into v_mat_papel from public.materials where inventory_material_code = 'PAPER' limit 1;
  select id into v_mat_plastico from public.materials where inventory_material_code = 'PLASTIC' limit 1;
  select id into v_mat_tarima from public.materials where inventory_material_code = 'WOOD' limit 1;

  insert into public.commercial_material_catalog (
    code, name, family, material_id, inventory_material, active
  ) values
    ('CARTON_NACIONAL', 'CARTON NACIONAL', 'fiber', v_mat_carton_nacional, 'CARDBOARD_BULK_NATIONAL', true),
    ('CARTON_AMERICANO', 'CARTON AMERICANO', 'fiber', v_mat_carton_americano, 'CARDBOARD_BULK_AMERICAN', true),
    ('PACA_NACIONAL', 'PACA NACIONAL', 'fiber', v_mat_paca_nacional, 'BALE_NATIONAL', true),
    ('PACA_AMERICANA', 'PACA AMERICANA', 'fiber', v_mat_paca_americana, 'BALE_AMERICAN', true),
    ('PACA_LIMPIA', 'PACA LIMPIA', 'fiber', v_mat_paca_limpia, 'BALE_CLEAN', true),
    ('PACA_BASURA', 'PACA BASURA', 'fiber', v_mat_paca_basura, 'BALE_TRASH', true),
    ('CAPLE', 'CAPLE', 'fiber', v_mat_caple, 'CAPLE', true),
    ('CHATARRA_MIXTA', 'CHATARRA MIXTA', 'metal', v_mat_chatarra, 'SCRAP', true),
    ('COBRE', 'COBRE', 'metal', v_mat_chatarra, 'SCRAP', true),
    ('ACERO', 'ACERO', 'metal', v_mat_chatarra, 'SCRAP', true),
    ('ALUMINIO', 'ALUMINIO', 'metal', v_mat_chatarra, 'SCRAP', true),
    ('PAPEL_REVUELTO', 'PAPEL REVUELTO', 'fiber', v_mat_papel, 'PAPER', true),
    ('ARCHIVO', 'ARCHIVO', 'fiber', v_mat_papel, 'PAPER', true),
    ('PERIODICO', 'PERIODICO', 'fiber', v_mat_papel, 'PAPER', true),
    ('KRAFT', 'KRAFT', 'fiber', v_mat_papel, 'PAPER', true),
    ('PLASTICO_MIXTO', 'PLASTICO MIXTO', 'polymer', v_mat_plastico, 'PLASTIC', true),
    ('TARIMA', 'TARIMA', 'other', v_mat_tarima, 'WOOD', true);

  insert into public.inventory_opening_templates (
    site, material, commercial_material_code, sort_order, is_active
  ) values
    (v_site_template, 'CARDBOARD_BULK_NATIONAL', 'CARTON_NACIONAL', 10, true),
    (v_site_template, 'CARDBOARD_BULK_AMERICAN', 'CARTON_AMERICANO', 20, true),
    (v_site_template, 'BALE_NATIONAL', 'PACA_NACIONAL', 30, true),
    (v_site_template, 'BALE_AMERICAN', 'PACA_AMERICANA', 40, true),
    (v_site_template, 'BALE_CLEAN', 'PACA_LIMPIA', 50, true),
    (v_site_template, 'BALE_TRASH', 'PACA_BASURA', 60, true),
    (v_site_template, 'CAPLE', 'CAPLE', 70, true),
    (v_site_template, 'SCRAP', 'CHATARRA_MIXTA', 80, true),
    (v_site_template, 'SCRAP', 'COBRE', 81, true),
    (v_site_template, 'SCRAP', 'ACERO', 82, true),
    (v_site_template, 'SCRAP', 'ALUMINIO', 83, true),
    (v_site_template, 'PAPER', 'PAPEL_REVUELTO', 90, true),
    (v_site_template, 'PAPER', 'ARCHIVO', 91, true),
    (v_site_template, 'PAPER', 'PERIODICO', 92, true),
    (v_site_template, 'PAPER', 'KRAFT', 93, true),
    (v_site_template, 'PLASTIC', 'PLASTICO_MIXTO', 100, true),
    (v_site_template, 'WOOD', 'TARIMA', 110, true);

  insert into public.opening_balances (
    period_month, as_of_date, material, commercial_material_code,
    weight_kg, source, is_manual, notes
  ) values
    (v_period_month, v_period_month, 'CARDBOARD_BULK_NATIONAL', 'CARTON_NACIONAL', 36000, 'manual', true, 'Demo apertura de mes'),
    (v_period_month, v_period_month, 'CARDBOARD_BULK_AMERICAN', 'CARTON_AMERICANO', 18000, 'manual', true, 'Demo apertura de mes'),
    (v_period_month, v_period_month, 'BALE_NATIONAL', 'PACA_NACIONAL', 12000, 'manual', true, 'Demo apertura de mes'),
    (v_period_month, v_period_month, 'BALE_AMERICAN', 'PACA_AMERICANA', 6000, 'manual', true, 'Demo apertura de mes'),
    (v_period_month, v_period_month, 'CAPLE', 'CAPLE', 8000, 'manual', true, 'Demo apertura de mes'),
    (v_period_month, v_period_month, 'SCRAP', 'CHATARRA_MIXTA', 26000, 'manual', true, 'Demo apertura de mes'),
    (v_period_month, v_period_month, 'PAPER', 'PAPEL_REVUELTO', 18000, 'manual', true, 'Demo apertura de mes');

  insert into public.movements (
    op_date, flow, movement_origin, material_id, material, weight_kg, gross_kg,
    tare_kg, net_kg, total_amount_kg, commercial_material_code, movement_reason,
    scale_ticket, counterparty_site_id, driver_employee_id, vehicle_id,
    counterparty, reference, notes
  ) values
    (current_date - 7, 'IN', 'MANUAL', v_mat_chatarra, 'SCRAP', 5200, 6600, 1400, 5200, 5200, 'CHATARRA_MIXTA', 'compra', 'SC-1001', v_provider_reciclados, v_driver_juan, v_vehicle_14, 'RECICLADOS INDUSTRIALES', 'ENTRADA-001', 'Compra mixta para demo'),
    (current_date - 6, 'IN', 'MANUAL', v_mat_papel, 'PAPER', 3600, 4700, 1100, 3600, 3600, 'PAPEL_REVUELTO', 'compra', 'PP-2001', v_provider_industrial, v_driver_luis, v_vehicle_21, 'RECUPERADORA INDUSTRIAL DEL BAJIO', 'ENTRADA-002', 'Compra revuelta para demo'),
    (current_date - 4, 'OUT', 'MANUAL', v_mat_chatarra, 'SCRAP', 1800, 1800, 0, 1800, 1800, 'ACERO', null, 'SV-3001', v_client_aceros, v_driver_pedro, v_vehicle_7, 'ACEROS DEL BAJIO', 'SALIDA-001', 'Venta de acero demo'),
    (current_date - 2, 'OUT', 'MANUAL', v_mat_papel, 'PAPER', 900, 900, 0, 900, 900, 'ARCHIVO', null, 'SV-3002', v_client_papelera, v_driver_luis, v_vehicle_21, 'PAPELERA CELAYA', 'SALIDA-002', 'Venta de archivo demo');

  insert into public.production_runs (
    op_date, shift, bale_material, source_bulk, bale_count,
    avg_bale_weight_kg, notes
  ) values
    (current_date - 6, 'DAY', 'BALE_NATIONAL', 'CARDBOARD_BULK_NATIONAL', 18, 820, 'Turno matutino demo'),
    (current_date - 5, 'NIGHT', 'BALE_AMERICAN', 'CARDBOARD_BULK_AMERICAN', 9, 860, 'Turno nocturno demo'),
    (current_date - 3, 'DAY', 'CAPLE', 'CAPLE', 6, 780, 'Producción de caple demo'),
    (current_date - 1, 'DAY', 'BALE_CLEAN', 'CARDBOARD_BULK_NATIONAL', 5, 800, 'Selección de calidad demo');

  insert into public.material_separation_runs (
    op_date, shift, source_material, source_mode,
    commercial_material_code, weight_kg, notes
  ) values
    (current_date - 7, 'DAY', 'SCRAP', 'MIXED', 'COBRE', 900, 'Separación demo de cobre'),
    (current_date - 7, 'DAY', 'SCRAP', 'MIXED', 'ACERO', 2400, 'Separación demo de acero'),
    (current_date - 6, 'NIGHT', 'SCRAP', 'DIRECT', 'ALUMINIO', 600, 'Compra directa clasificada'),
    (current_date - 5, 'DAY', 'PAPER', 'MIXED', 'ARCHIVO', 1800, 'Separación demo de archivo'),
    (current_date - 5, 'DAY', 'PAPER', 'MIXED', 'KRAFT', 900, 'Separación demo de kraft'),
    (current_date - 4, 'NIGHT', 'PAPER', 'DIRECT', 'PERIODICO', 700, 'Compra directa clasificada');

  insert into public.services (
    service_date, due_date, direction, status, client_id, material_id,
    driver_employee_id, vehicle_id, notes, area, client_name, material_type
  ) values
    (current_date - 1, current_date + 1, 'recoleccion', 'programado', v_client_aceros, v_mat_chatarra, v_driver_juan, v_vehicle_14, 'Recolección de chatarra programada', 'LOGISTICA', 'ACEROS DEL BAJIO', 'CHATARRA'),
    (current_date, current_date + 2, 'recoleccion', 'en_ruta', v_client_bajio, v_mat_carton_nacional, v_driver_luis, v_vehicle_21, 'Cartón nacional listo para retiro', 'LOGISTICA', 'MANUFACTURAS DEL CENTRO', 'CARTON NACIONAL'),
    (current_date + 1, current_date + 1, 'entrega', 'programado', v_client_papelera, v_mat_papel, v_driver_pedro, v_vehicle_7, 'Entrega de papel clasificado', 'LOGISTICA', 'PAPELERA CELAYA', 'PAPEL'),
    (current_date - 2, current_date - 1, 'entrega', 'completado', v_client_aceros, v_mat_paca_nacional, v_driver_juan, v_vehicle_14, 'Entrega de paca nacional demo', 'LOGISTICA', 'ACEROS DEL BAJIO', 'PACA NACIONAL'),
    (current_date - 3, current_date - 2, 'recoleccion', 'completado', v_client_bajio, v_mat_carton_americano, v_driver_luis, v_vehicle_21, 'Servicio cerrado de cartón americano', 'LOGISTICA', 'MANUFACTURAS DEL CENTRO', 'CARTON AMERICANO');

  insert into public.pesadas (fecha, ticket, proveedor, precio)
  values
    (current_date - 8, 'P-001', 'RECICLADOS INDUSTRIALES', 4.80),
    (current_date - 6, 'P-002', 'RECUPERADORA INDUSTRIAL DEL BAJIO', 5.10),
    (current_date - 3, 'P-003', 'RECICLADOS INDUSTRIALES', 4.95),
    (current_date - 1, 'P-004', 'RECUPERADORA INDUSTRIAL DEL BAJIO', 5.05);

  insert into public.inventory_items (
    code, name, category, description, unit, current_stock,
    minimum_stock, location, assigned_to, is_active
  ) values
    ('FLT-001', 'FILTRO HIDRAULICO 1R-1808', 'refaccion', 'Filtro para empacadora', 'PIEZA', 0, 2, 'ANAQUEL A1', null, true),
    ('MNG-010', 'MANGUERA 3/4 ALTA PRESION', 'refaccion', 'Manguera para circuito hidráulico', 'PIEZA', 0, 1, 'ANAQUEL B2', null, true),
    ('GRS-020', 'GRASA LITIO EP2', 'consumible', 'Cartucho de grasa', 'CARTUCHO', 0, 6, 'ESTANTE C1', null, true),
    ('EPP-001', 'GUANTE NITRILO', 'uniforme', 'Guante de seguridad', 'PAR', 0, 12, 'ESTANTE D4', null, true);

  select id into v_wh_filter from public.inventory_items where code = 'FLT-001' limit 1;
  select id into v_wh_hose from public.inventory_items where code = 'MNG-010' limit 1;
  select id into v_wh_grease from public.inventory_items where code = 'GRS-020' limit 1;
  select id into v_wh_gloves from public.inventory_items where code = 'EPP-001' limit 1;

  insert into public.inventory_movements (
    item_id, movement_type, quantity, area, responsible_name, reason, reference
  ) values
    (v_wh_filter, 'entrada', 8, 'MANTENIMIENTO', 'ALMACEN GENERAL', 'Compra inicial demo', 'OC-001'),
    (v_wh_filter, 'salida', 2, 'MANTENIMIENTO', 'ALMACEN GENERAL', 'Consumo en empacadora demo', 'OT-DEMO-001'),
    (v_wh_hose, 'entrada', 3, 'MANTENIMIENTO', 'ALMACEN GENERAL', 'Compra inicial demo', 'OC-002'),
    (v_wh_grease, 'entrada', 24, 'MANTENIMIENTO', 'ALMACEN GENERAL', 'Compra inicial demo', 'OC-003'),
    (v_wh_grease, 'salida', 5, 'MANTENIMIENTO', 'ALMACEN GENERAL', 'Lubricación semanal demo', 'OT-DEMO-002'),
    (v_wh_gloves, 'entrada', 40, 'OPERACION', 'ALMACEN GENERAL', 'Compra inicial demo', 'OC-004'),
    (v_wh_gloves, 'salida', 8, 'OPERACION', 'ALMACEN GENERAL', 'Entrega de EPP demo', 'EPP-001');

  insert into public.inventory_monthly_cut_lines (
    cut_id, item_id, system_stock, physical_stock, adjustment_applied
  ) values
    (v_cut_id, v_wh_filter, 6, 6, false),
    (v_cut_id, v_wh_hose, 3, 3, false),
    (v_cut_id, v_wh_grease, 19, 19, false),
    (v_cut_id, v_wh_gloves, 32, 31, false);

  insert into public.maintenance_orders (
    ot_folio, status, priority, type, category, impact,
    area_id, area_label, equipment_id, equipment_label, equipment_serial,
    requester_name, provider_type, problem_description, diagnosis,
    work_summary, assigned_to_name, assigned_at, cost_estimated_total,
    cost_actual_total, requested_at, created_at, updated_at
  ) values
    (
      'OT-' || extract(year from current_date)::int || '-000001',
      'programado', 'alta', 'correctivo', 'hidraulica', 'paro_parcial',
      v_area_mantenimiento_id, 'MANTENIMIENTO', v_vehicle_14, 'TR-14', 'VINTR14001',
      'JEFE DE PATIO', 'interno', 'Fuga en línea hidráulica principal',
      'Manguera con desgaste en cople', 'Cambio de manguera y prueba de presión',
      'TECNICO A', current_timestamp - interval '2 days', 5800, 5450,
      current_timestamp - interval '3 days', current_timestamp - interval '3 days', current_timestamp - interval '1 day'
    ),
    (
      'OT-' || extract(year from current_date)::int || '-000002',
      'supervision', 'media', 'preventivo', 'mecanica', 'sin_impacto',
      v_area_mantenimiento_id, 'MANTENIMIENTO', v_vehicle_21, 'TR-21', 'VINTR21001',
      'SUPERVISOR LOGISTICA', 'interno', 'Servicio preventivo general',
      'Desgaste normal', 'Afinación, cambio de filtro y ajuste general',
      'TECNICO B', current_timestamp - interval '5 days', 3200, 2980,
      current_timestamp - interval '6 days', current_timestamp - interval '6 days', current_timestamp - interval '2 days'
    ),
    (
      'OT-' || extract(year from current_date)::int || '-000003',
      'aviso_falla', 'baja', 'mejora', 'electronica', 'sin_impacto',
      v_area_mantenimiento_id, 'MANTENIMIENTO', v_vehicle_7, 'TR-07', 'VINTR07001',
      'COORDINADOR OPERATIVO', 'externo', 'Instalar testigo luminoso de saturación',
      null, null, null, null, 1500, null,
      current_timestamp - interval '1 day', current_timestamp - interval '1 day', current_timestamp - interval '1 day'
    );

  select id into v_ot_1 from public.maintenance_orders where ot_folio like 'OT-%-000001' limit 1;
  select id into v_ot_2 from public.maintenance_orders where ot_folio like 'OT-%-000002' limit 1;
  select id into v_ot_3 from public.maintenance_orders where ot_folio like 'OT-%-000003' limit 1;

  insert into public.maintenance_tasks (ot_id, line_no, description, unit, qty, is_done, notes, done_at)
  values
    (v_ot_1, 1, 'Despresurizar línea principal', 'SERVICIO', 1, true, 'Completado sin novedad', current_timestamp - interval '2 days'),
    (v_ot_1, 2, 'Reemplazar manguera 3/4', 'PIEZA', 1, true, 'Se instaló nueva manguera', current_timestamp - interval '2 days'),
    (v_ot_1, 3, 'Prueba de fugas', 'SERVICIO', 1, false, 'Pendiente verificación final', null),
    (v_ot_2, 1, 'Cambio de filtro hidráulico', 'PIEZA', 1, true, 'Filtro sustituido', current_timestamp - interval '4 days'),
    (v_ot_2, 2, 'Lubricación general', 'SERVICIO', 1, true, 'Puntos de engrase atendidos', current_timestamp - interval '4 days'),
    (v_ot_3, 1, 'Levantamiento para mejora', 'SERVICIO', 1, false, null, null);

  insert into public.maintenance_materials (ot_id, line_no, name, qty, source, cost_estimated, cost_actual, notes)
  values
    (v_ot_1, 1, 'MANGUERA 3/4 ALTA PRESION', 1, 'compra', 4200, 4050, 'Proveedor local'),
    (v_ot_1, 2, 'COPLE HIDRAULICO', 2, 'almacen', 800, 760, null),
    (v_ot_2, 1, 'FILTRO HIDRAULICO 1R-1808', 1, 'almacen', 650, 650, null),
    (v_ot_2, 2, 'GRASA LITIO EP2', 4, 'almacen', 300, 260, null),
    (v_ot_3, 1, 'TORRETA LUMINOSA', 1, 'proveedor', 1500, null, 'Pendiente cotización');

  insert into public.maintenance_time_logs (ot_id, tech_name, start_at, end_at, minutes, note)
  values
    (v_ot_1, 'TECNICO A', current_timestamp - interval '2 days 4 hours', current_timestamp - interval '2 days 1 hour', 180, 'Atención hidráulica'),
    (v_ot_2, 'TECNICO B', current_timestamp - interval '4 days 5 hours', current_timestamp - interval '4 days 2 hours', 180, 'Preventivo programado');

  insert into public.maintenance_approvals (ot_id, step, status, by_user_name, at, comment)
  values
    (v_ot_1, 'area', 'aprobada', 'JEFE DE PATIO', current_timestamp - interval '3 days', 'Procede atención'),
    (v_ot_1, 'mantenimiento', 'aprobada', 'COORDINADOR MTTO', current_timestamp - interval '3 days', 'Asignar técnico'),
    (v_ot_2, 'area', 'aprobada', 'SUPERVISOR LOGISTICA', current_timestamp - interval '6 days', 'Preventivo confirmado'),
    (v_ot_3, 'area', 'pendiente', null, null, null);

  insert into public.maintenance_status_log (ot_id, from_status, to_status, changed_by_name, changed_at, comment)
  values
    (v_ot_1, 'aviso_falla', 'programado', 'COORDINADOR MTTO', current_timestamp - interval '3 days', 'OT planeada'),
    (v_ot_2, 'programado', 'mantenimiento_realizado', 'TECNICO B', current_timestamp - interval '4 days', 'Trabajo ejecutado'),
    (v_ot_2, 'mantenimiento_realizado', 'supervision', 'COORDINADOR MTTO', current_timestamp - interval '2 days', 'Pendiente revisión final'),
    (v_ot_3, null, 'aviso_falla', 'COORDINADOR OPERATIVO', current_timestamp - interval '1 day', 'Reporte inicial');
end;
$$;

commit;
