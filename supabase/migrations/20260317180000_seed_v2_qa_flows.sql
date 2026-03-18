begin;

do $$
declare
  v_carton_general uuid;
  v_papel_general uuid;
  v_carton_nacional uuid;
  v_paca_americana uuid;
  v_revuelto uuid;
  v_archivo uuid;
  v_aluminio uuid;
  v_run_carton uuid;
  v_run_papel uuid;
begin
  select id into v_carton_general
    from public.material_general_catalog_v2
   where code = 'CARTON';

  select id into v_papel_general
    from public.material_general_catalog_v2
   where code = 'PAPEL';

  select id into v_carton_nacional
    from public.material_commercial_catalog_v2
   where code = 'CARTON_NACIONAL';

  select id into v_paca_americana
    from public.material_commercial_catalog_v2
   where code = 'PACA_AMERICANA';

  select id into v_revuelto
    from public.material_commercial_catalog_v2
   where code = 'REVUELTO';

  select id into v_archivo
    from public.material_commercial_catalog_v2
   where code = 'ARCHIVO';

  select id into v_aluminio
    from public.material_commercial_catalog_v2
   where code = 'ALUMINIO';

  if v_carton_general is null or v_papel_general is null then
    raise exception 'Catálogo general v2 incompleto para QA.';
  end if;

  if v_carton_nacional is null or v_paca_americana is null or v_revuelto is null or v_archivo is null or v_aluminio is null then
    raise exception 'Catálogo comercial v2 incompleto para QA.';
  end if;

  insert into public.inventory_opening_balances_v2 (
    period_month,
    as_of_date,
    inventory_level,
    general_material_id,
    weight_kg,
    site,
    notes
  )
  values (
    date '2026-03-01',
    date '2026-03-01',
    'GENERAL',
    v_papel_general,
    500.000,
    'DICSA_CELAYA',
    'QA V2 - apertura papel'
  );

  insert into public.inventory_opening_balances_v2 (
    period_month,
    as_of_date,
    inventory_level,
    commercial_material_id,
    weight_kg,
    site,
    notes
  )
  values (
    date '2026-03-01',
    date '2026-03-01',
    'COMMERCIAL',
    v_aluminio,
    120.000,
    'DICSA_CELAYA',
    'QA V2 - apertura aluminio en patio'
  );

  insert into public.inventory_movements_v2 (
    op_date,
    inventory_level,
    flow,
    general_material_id,
    source_commercial_material_id,
    origin_type,
    weight_kg,
    gross_kg,
    tare_kg,
    net_kg,
    total_amount_kg,
    site,
    counterparty,
    reference,
    notes
  )
  values (
    date '2026-03-17',
    'GENERAL',
    'IN',
    v_carton_general,
    v_carton_nacional,
    'DIRECT_PURCHASE',
    1200.000,
    1400.000,
    200.000,
    1200.000,
    1200.000,
    'DICSA_CELAYA',
    'QA PROVEEDOR CARTON',
    'QA-ENT-CARTON-001',
    'QA V2 - entrada carton nacional'
  );

  insert into public.inventory_movements_v2 (
    op_date,
    inventory_level,
    flow,
    general_material_id,
    source_commercial_material_id,
    origin_type,
    weight_kg,
    gross_kg,
    tare_kg,
    net_kg,
    total_amount_kg,
    site,
    counterparty,
    reference,
    notes
  )
  values (
    date '2026-03-17',
    'GENERAL',
    'IN',
    v_papel_general,
    v_revuelto,
    'DIRECT_PURCHASE',
    400.000,
    480.000,
    80.000,
    400.000,
    400.000,
    'DICSA_CELAYA',
    'QA PROVEEDOR PAPEL',
    'QA-ENT-PAPEL-001',
    'QA V2 - entrada papel revuelto'
  );

  insert into public.material_transformation_runs_v2 (
    op_date,
    shift,
    source_general_material_id,
    source_mode,
    input_weight_kg,
    site,
    notes
  )
  values (
    date '2026-03-17',
    'DAY',
    v_carton_general,
    'MIXED',
    1000.000,
    'DICSA_CELAYA',
    'QA V2 - transformacion carton a paca americana'
  )
  returning id into v_run_carton;

  insert into public.material_transformation_run_outputs_v2 (
    run_id,
    commercial_material_id,
    output_weight_kg,
    output_unit_count,
    notes
  )
  values (
    v_run_carton,
    v_paca_americana,
    920.000,
    1,
    'QA V2 - salida clasificada carton'
  );

  insert into public.material_transformation_runs_v2 (
    op_date,
    shift,
    source_general_material_id,
    source_mode,
    input_weight_kg,
    site,
    notes
  )
  values (
    date '2026-03-17',
    'DAY',
    v_papel_general,
    'MIXED',
    300.000,
    'DICSA_CELAYA',
    'QA V2 - transformacion papel a archivo'
  )
  returning id into v_run_papel;

  insert into public.material_transformation_run_outputs_v2 (
    run_id,
    commercial_material_id,
    output_weight_kg,
    output_unit_count,
    notes
  )
  values (
    v_run_papel,
    v_archivo,
    250.000,
    null,
    'QA V2 - salida clasificada papel'
  );

  insert into public.inventory_movements_v2 (
    op_date,
    inventory_level,
    flow,
    commercial_material_id,
    origin_type,
    weight_kg,
    gross_kg,
    tare_kg,
    net_kg,
    total_amount_kg,
    site,
    counterparty,
    reference,
    notes
  )
  values (
    date '2026-03-17',
    'COMMERCIAL',
    'OUT',
    v_paca_americana,
    'SALE',
    300.000,
    340.000,
    40.000,
    300.000,
    300.000,
    'DICSA_CELAYA',
    'QA CLIENTE PACA',
    'QA-SAL-CARTON-001',
    'QA V2 - salida paca americana'
  );

  insert into public.inventory_movements_v2 (
    op_date,
    inventory_level,
    flow,
    commercial_material_id,
    origin_type,
    weight_kg,
    gross_kg,
    tare_kg,
    net_kg,
    total_amount_kg,
    site,
    counterparty,
    reference,
    notes
  )
  values (
    date '2026-03-17',
    'COMMERCIAL',
    'OUT',
    v_archivo,
    'SALE',
    100.000,
    120.000,
    20.000,
    100.000,
    100.000,
    'DICSA_CELAYA',
    'QA CLIENTE PAPEL',
    'QA-SAL-PAPEL-001',
    'QA V2 - salida archivo'
  );
end
$$;

commit;
