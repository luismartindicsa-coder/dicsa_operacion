begin;

alter table public.cash_taxonomy_configs
  drop constraint if exists cash_taxonomy_configs_area_chk;

alter table public.cash_taxonomy_configs
  add constraint cash_taxonomy_configs_area_chk
  check (
    area in (
      'menudeo',
      'mayoreo',
      'direccion',
      'direccion_boveda_vouchers'
    )
  );

commit;
