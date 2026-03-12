begin;

alter table if exists public.production_runs
  drop constraint if exists production_runs_source_bulk_check;

alter table if exists public.production_runs
  add constraint production_runs_source_bulk_check
  check (
    (
      bale_material = 'BALE_AMERICAN'
      and source_bulk in ('CARDBOARD_BULK_AMERICAN', 'CARDBOARD_BULK_NATIONAL')
    )
    or (
      bale_material in ('BALE_NATIONAL', 'BALE_CLEAN', 'BALE_TRASH')
      and source_bulk = 'CARDBOARD_BULK_NATIONAL'
    )
    or (
      bale_material = 'CAPLE'
      and source_bulk in ('CAPLE', 'CARDBOARD_BULK_NATIONAL', 'CARDBOARD_BULK_AMERICAN')
    )
  );

commit;
