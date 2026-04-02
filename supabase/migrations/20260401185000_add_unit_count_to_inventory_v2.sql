begin;

alter table public.inventory_opening_balances_v2
  add column if not exists unit_count integer;

alter table public.inventory_movements_v2
  add column if not exists unit_count integer;

alter table public.inventory_opening_balances_v2
  drop constraint if exists inventory_opening_balances_v2_unit_count_chk;

alter table public.inventory_opening_balances_v2
  add constraint inventory_opening_balances_v2_unit_count_chk
  check (unit_count is null or unit_count > 0);

alter table public.inventory_movements_v2
  drop constraint if exists inventory_movements_v2_unit_count_chk;

alter table public.inventory_movements_v2
  add constraint inventory_movements_v2_unit_count_chk
  check (unit_count is null or unit_count > 0);

update public.inventory_movements_v2 movement
   set unit_count = output.output_unit_count
  from public.material_transformation_run_outputs_v2 output
 where movement.transformation_run_id = output.run_id
   and movement.commercial_material_id = output.commercial_material_id
   and movement.inventory_level = 'COMMERCIAL'
   and movement.origin_type = 'TRANSFORMATION'
   and movement.unit_count is distinct from output.output_unit_count;

create or replace view public.v_inventory_general_balance_v2 as
with opening as (
  select
    general_material_id,
    coalesce(sum(weight_kg), 0)::numeric as opening_kg,
    coalesce(sum(unit_count), 0)::numeric as opening_units
  from public.inventory_opening_balances_v2
  where inventory_level = 'GENERAL'
  group by 1
),
movements as (
  select
    general_material_id,
    coalesce(sum(
      case flow
        when 'IN' then weight_kg
        when 'OUT' then -weight_kg
        else weight_kg
      end
    ), 0)::numeric as movement_kg,
    coalesce(sum(
      case flow
        when 'IN' then coalesce(unit_count, 0)
        when 'OUT' then -coalesce(unit_count, 0)
        else coalesce(unit_count, 0)
      end
    ), 0)::numeric as movement_units
  from public.inventory_movements_v2
  where inventory_level = 'GENERAL'
  group by 1
)
select
  g.id,
  g.code,
  g.name,
  coalesce(o.opening_kg, 0) as opening_kg,
  coalesce(m.movement_kg, 0) as movement_kg,
  coalesce(o.opening_kg, 0) + coalesce(m.movement_kg, 0) as on_hand_kg,
  coalesce(o.opening_units, 0) as opening_units,
  coalesce(m.movement_units, 0) as movement_units,
  coalesce(o.opening_units, 0) + coalesce(m.movement_units, 0) as on_hand_units
from public.material_general_catalog_v2 g
left join opening o on o.general_material_id = g.id
left join movements m on m.general_material_id = g.id
where g.is_active;

create or replace view public.v_inventory_commercial_balance_v2 as
with opening as (
  select
    commercial_material_id,
    coalesce(sum(weight_kg), 0)::numeric as opening_kg,
    coalesce(sum(unit_count), 0)::numeric as opening_units
  from public.inventory_opening_balances_v2
  where inventory_level = 'COMMERCIAL'
  group by 1
),
movements as (
  select
    commercial_material_id,
    coalesce(sum(
      case flow
        when 'IN' then weight_kg
        when 'OUT' then -weight_kg
        else weight_kg
      end
    ), 0)::numeric as movement_kg,
    coalesce(sum(
      case flow
        when 'IN' then coalesce(unit_count, 0)
        when 'OUT' then -coalesce(unit_count, 0)
        else coalesce(unit_count, 0)
      end
    ), 0)::numeric as movement_units
  from public.inventory_movements_v2
  where inventory_level = 'COMMERCIAL'
  group by 1
)
select
  c.id,
  c.code,
  c.name,
  c.family,
  g.code as general_code,
  coalesce(o.opening_kg, 0) as opening_kg,
  coalesce(m.movement_kg, 0) as movement_kg,
  coalesce(o.opening_kg, 0) + coalesce(m.movement_kg, 0) as on_hand_kg,
  coalesce(o.opening_units, 0) as opening_units,
  coalesce(m.movement_units, 0) as movement_units,
  coalesce(o.opening_units, 0) + coalesce(m.movement_units, 0) as on_hand_units
from public.material_commercial_catalog_v2 c
left join public.material_general_catalog_v2 g on g.id = c.general_material_id
left join opening o on o.commercial_material_id = c.id
left join movements m on m.commercial_material_id = c.id
where c.is_active;

create or replace function public.fn_sync_transformation_general_movement_v2()
returns trigger
language plpgsql
as $$
begin
  update public.inventory_movements_v2
     set op_date = new.op_date,
         flow = 'OUT',
         general_material_id = new.source_general_material_id,
         origin_type = 'TRANSFORMATION',
         weight_kg = new.input_weight_kg,
         net_kg = new.input_weight_kg,
         unit_count = null,
         site = new.site,
         reference = 'TRANSFORMATION',
         notes = new.notes,
         updated_at = now()
   where transformation_run_id = new.id
     and inventory_level = 'GENERAL';

  if not found then
    insert into public.inventory_movements_v2 (
      transformation_run_id,
      op_date,
      inventory_level,
      flow,
      general_material_id,
      origin_type,
      weight_kg,
      net_kg,
      unit_count,
      site,
      reference,
      notes
    )
    values (
      new.id,
      new.op_date,
      'GENERAL',
      'OUT',
      new.source_general_material_id,
      'TRANSFORMATION',
      new.input_weight_kg,
      new.input_weight_kg,
      null,
      new.site,
      'TRANSFORMATION',
      new.notes
    );
  end if;

  update public.inventory_movements_v2
     set op_date = new.op_date,
         site = new.site,
         reference = 'TRANSFORMATION',
         notes = coalesce(public.inventory_movements_v2.notes, new.notes),
         updated_at = now()
   where transformation_run_id = new.id
     and inventory_level = 'COMMERCIAL';

  return new;
end
$$;

create or replace function public.fn_sync_transformation_output_movement_v2()
returns trigger
language plpgsql
as $$
declare
  v_run public.material_transformation_runs_v2%rowtype;
begin
  if tg_op = 'DELETE' then
    delete from public.inventory_movements_v2
     where transformation_run_id = old.run_id
       and inventory_level = 'COMMERCIAL'
       and commercial_material_id = old.commercial_material_id;
    return old;
  end if;

  select *
    into v_run
    from public.material_transformation_runs_v2
   where id = new.run_id;

  update public.inventory_movements_v2
     set op_date = v_run.op_date,
         flow = 'IN',
         origin_type = 'TRANSFORMATION',
         weight_kg = new.output_weight_kg,
         net_kg = new.output_weight_kg,
         unit_count = new.output_unit_count,
         site = v_run.site,
         reference = 'TRANSFORMATION',
         notes = coalesce(new.notes, v_run.notes),
         updated_at = now()
   where transformation_run_id = new.run_id
     and inventory_level = 'COMMERCIAL'
     and commercial_material_id = new.commercial_material_id;

  if not found then
    insert into public.inventory_movements_v2 (
      transformation_run_id,
      op_date,
      inventory_level,
      flow,
      commercial_material_id,
      origin_type,
      weight_kg,
      net_kg,
      unit_count,
      site,
      reference,
      notes
    )
    values (
      new.run_id,
      v_run.op_date,
      'COMMERCIAL',
      'IN',
      new.commercial_material_id,
      'TRANSFORMATION',
      new.output_weight_kg,
      new.output_weight_kg,
      new.output_unit_count,
      v_run.site,
      'TRANSFORMATION',
      coalesce(new.notes, v_run.notes)
    );
  end if;

  return new;
end
$$;

commit;
