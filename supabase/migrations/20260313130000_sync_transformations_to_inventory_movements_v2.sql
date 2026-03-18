begin;

alter table public.inventory_movements_v2
  add column if not exists transformation_run_id uuid references public.material_transformation_runs_v2(id) on delete cascade;

alter table public.material_transformation_runs_v2
  add column if not exists source_mode text not null default 'MIXED';

alter table public.material_transformation_runs_v2
  drop constraint if exists material_transformation_runs_v2_source_mode_chk;

alter table public.material_transformation_runs_v2
  add constraint material_transformation_runs_v2_source_mode_chk
  check (source_mode in ('MIXED', 'DIRECT'));

alter table public.material_transformation_run_outputs_v2
  add column if not exists output_unit_count integer;

alter table public.material_transformation_run_outputs_v2
  drop constraint if exists material_transformation_run_outputs_v2_output_unit_count_chk;

alter table public.material_transformation_run_outputs_v2
  add constraint material_transformation_run_outputs_v2_output_unit_count_chk
  check (output_unit_count is null or output_unit_count > 0);

create unique index if not exists inventory_movements_v2_transformation_general_uidx
  on public.inventory_movements_v2 (transformation_run_id, inventory_level)
  where transformation_run_id is not null
    and inventory_level = 'GENERAL';

create unique index if not exists inventory_movements_v2_transformation_commercial_uidx
  on public.inventory_movements_v2 (transformation_run_id, commercial_material_id, inventory_level)
  where transformation_run_id is not null
    and inventory_level = 'COMMERCIAL';

create or replace function public.fn_sync_transformation_general_movement_v2()
returns trigger
language plpgsql
as $$
begin
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
  )
  on conflict (transformation_run_id, inventory_level)
    where inventory_level = 'GENERAL'
  do update set
    op_date = excluded.op_date,
    general_material_id = excluded.general_material_id,
    weight_kg = excluded.weight_kg,
    net_kg = excluded.net_kg,
    site = excluded.site,
    reference = excluded.reference,
    notes = excluded.notes,
    updated_at = now();

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
  )
  on conflict (transformation_run_id, commercial_material_id, inventory_level)
    where inventory_level = 'COMMERCIAL'
  do update set
    op_date = excluded.op_date,
    weight_kg = excluded.weight_kg,
    net_kg = excluded.net_kg,
    site = excluded.site,
    reference = excluded.reference,
    notes = excluded.notes,
    updated_at = now();

  return new;
end
$$;

drop trigger if exists trg_sync_transformation_general_movement_v2
  on public.material_transformation_runs_v2;

create trigger trg_sync_transformation_general_movement_v2
after insert or update on public.material_transformation_runs_v2
for each row execute function public.fn_sync_transformation_general_movement_v2();

drop trigger if exists trg_sync_transformation_output_movement_v2
  on public.material_transformation_run_outputs_v2;

create trigger trg_sync_transformation_output_movement_v2
after insert or update or delete on public.material_transformation_run_outputs_v2
for each row execute function public.fn_sync_transformation_output_movement_v2();

commit;
