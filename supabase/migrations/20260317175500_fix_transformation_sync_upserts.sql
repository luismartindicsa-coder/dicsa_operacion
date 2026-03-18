begin;

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
      v_run.site,
      'TRANSFORMATION',
      coalesce(new.notes, v_run.notes)
    );
  end if;

  return new;
end
$$;

commit;
