begin;

alter table if exists public.movements
  add column if not exists movement_origin text,
  add column if not exists origin_table text,
  add column if not exists origin_row_id uuid,
  add column if not exists origin_line text;

update public.movements
set movement_origin = 'MANUAL'
where movement_origin is null or btrim(movement_origin) = '';

alter table if exists public.movements
  alter column movement_origin set default 'MANUAL';

alter table if exists public.movements
  drop constraint if exists movements_movement_origin_check;

alter table if exists public.movements
  add constraint movements_movement_origin_check
  check (movement_origin in ('MANUAL', 'PRODUCTION', 'SEPARATION'));

alter table if exists public.movements
  drop constraint if exists movements_origin_line_check;

alter table if exists public.movements
  add constraint movements_origin_line_check
  check (
    origin_line is null
    or origin_line in ('SOURCE_OUT', 'PRODUCT_IN')
  );

create index if not exists movements_origin_idx
  on public.movements (movement_origin, origin_table, origin_row_id);

create index if not exists movements_material_commercial_idx
  on public.movements (material, commercial_material_code, op_date desc);

alter table if exists public.material_separation_runs
  add column if not exists site text not null default 'DICSA_CELAYA';

create index if not exists material_separation_runs_site_idx
  on public.material_separation_runs (site, source_material, op_date desc);

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
    concat('PROD:', v_row_id::text),
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
    concat('PROD:', v_row_id::text),
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

drop trigger if exists trg_sync_production_run_movements on public.production_runs;
create trigger trg_sync_production_run_movements
after insert or update or delete on public.production_runs
for each row
execute function public.fn_sync_production_run_movements();

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

drop trigger if exists trg_sync_material_separation_movements on public.material_separation_runs;
create trigger trg_sync_material_separation_movements
after insert or update or delete on public.material_separation_runs
for each row
execute function public.fn_sync_material_separation_movements();

create or replace function public.rpc_inventory_summary_by_period(
  p_period_month date,
  p_as_of_date date,
  p_site text
)
returns table (
  material text,
  opening_kg numeric,
  net_movement_kg numeric,
  prod_in_kg numeric,
  prod_out_kg numeric,
  on_hand_kg numeric
)
language sql
stable
as $$
  with opening as (
    select
      ob.material::text as material,
      coalesce(sum(ob.weight_kg), 0)::numeric as opening_kg
    from public.opening_balances ob
    where ob.period_month = p_period_month
      and ob.site = p_site
    group by 1
  ),
  movement_rollup as (
    select
      m.material::text as material,
      coalesce(sum(
        case
          when upper(coalesce(m.movement_origin, 'MANUAL')) = 'MANUAL' and upper(m.flow::text) = 'IN' then coalesce(m.net_kg, m.weight_kg, 0)
          when upper(coalesce(m.movement_origin, 'MANUAL')) = 'MANUAL' and upper(m.flow::text) = 'OUT' then -coalesce(m.net_kg, m.weight_kg, 0)
          else 0
        end
      ), 0)::numeric as net_movement_kg,
      coalesce(sum(
        case
          when upper(coalesce(m.movement_origin, 'MANUAL')) <> 'MANUAL' and upper(m.flow::text) = 'IN' then coalesce(m.net_kg, m.weight_kg, 0)
          else 0
        end
      ), 0)::numeric as prod_in_kg,
      coalesce(sum(
        case
          when upper(coalesce(m.movement_origin, 'MANUAL')) <> 'MANUAL' and upper(m.flow::text) = 'OUT' then coalesce(m.net_kg, m.weight_kg, 0)
          else 0
        end
      ), 0)::numeric as prod_out_kg
    from public.movements m
    where coalesce(m.site, p_site) = p_site
      and m.op_date >= p_period_month
      and m.op_date <= p_as_of_date
    group by 1
  ),
  material_keys as (
    select material from opening
    union
    select material from movement_rollup
  )
  select
    mk.material,
    coalesce(o.opening_kg, 0) as opening_kg,
    coalesce(mr.net_movement_kg, 0) as net_movement_kg,
    coalesce(mr.prod_in_kg, 0) as prod_in_kg,
    coalesce(mr.prod_out_kg, 0) as prod_out_kg,
    coalesce(o.opening_kg, 0)
      + coalesce(mr.net_movement_kg, 0)
      + coalesce(mr.prod_in_kg, 0)
      - coalesce(mr.prod_out_kg, 0) as on_hand_kg
  from material_keys mk
  left join opening o using (material)
  left join movement_rollup mr using (material)
  order by mk.material;
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
select r.*
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

-- Historical backfill is intentionally omitted here because remote legacy rows
-- contain inconsistent values that must be normalized first. New and edited
-- rows will stay synchronized via triggers above.

commit;
