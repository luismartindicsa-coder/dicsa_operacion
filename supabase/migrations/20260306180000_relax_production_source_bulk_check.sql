alter table if exists public.production_runs
  drop constraint if exists production_runs_source_bulk_check;

alter table if exists public.production_runs
  add constraint production_runs_source_bulk_check
  check (
    source_bulk is null
    or source_bulk in (
      'CARDBOARD_BULK_NATIONAL',
      'CARDBOARD_BULK_AMERICAN',
      'CAPLE'
    )
  );

update public.production_runs
set source_bulk = case bale_material
  when 'BALE_AMERICAN' then 'CARDBOARD_BULK_AMERICAN'::inv_material
  when 'CAPLE' then 'CAPLE'::inv_material
  else 'CARDBOARD_BULK_NATIONAL'::inv_material
end
where source_bulk is null
   or source_bulk not in (
     'CARDBOARD_BULK_NATIONAL'::inv_material,
     'CARDBOARD_BULK_AMERICAN'::inv_material,
     'CAPLE'::inv_material
   );
