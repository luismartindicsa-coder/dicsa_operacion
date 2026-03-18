begin;

do $$
declare
  v_carton_general uuid;
  v_chatarra_general uuid;
  v_metal_general uuid;
  v_plastico_general uuid;
  v_madera_general uuid;
  v_papel_general uuid;

  v_carton_americano uuid;
  v_chat_mixta uuid;
  v_mixto uuid;
  v_plastico_mixto uuid;
  v_revuelto uuid;
  v_tarima uuid;

  v_paca_americana uuid;
  v_paca_nacional uuid;
  v_paca_limpia uuid;
  v_pesado uuid;
  v_placa_larga uuid;
  v_paca_primera uuid;
  v_aluminio uuid;
  v_cobre_primera uuid;
  v_archivo uuid;
  v_magazine uuid;
  v_bolsa uuid;
  v_unicel uuid;
  v_pedacera uuid;

  v_run_carton uuid;
  v_run_chatarra uuid;
  v_run_metal uuid;
  v_run_papel uuid;
  v_run_plastico uuid;
  v_run_madera uuid;
begin
  select id into v_carton_general from public.material_general_catalog_v2 where code = 'CARTON';
  select id into v_chatarra_general from public.material_general_catalog_v2 where code = 'CHATARRA';
  select id into v_metal_general from public.material_general_catalog_v2 where code = 'METAL';
  select id into v_plastico_general from public.material_general_catalog_v2 where code = 'PLASTICO';
  select id into v_madera_general from public.material_general_catalog_v2 where code = 'MADERA';
  select id into v_papel_general from public.material_general_catalog_v2 where code = 'PAPEL';

  select id into v_carton_americano from public.material_commercial_catalog_v2 where code = 'CARTON_AMERICANO';
  select id into v_chat_mixta from public.material_commercial_catalog_v2 where code = 'CHATARRA_MIXTA';
  select id into v_mixto from public.material_commercial_catalog_v2 where code = 'MIXTO';
  select id into v_plastico_mixto from public.material_commercial_catalog_v2 where code = 'PLASTICO_MIXTO';
  select id into v_revuelto from public.material_commercial_catalog_v2 where code = 'REVUELTO';
  select id into v_tarima from public.material_commercial_catalog_v2 where code = 'TARIMA';

  select id into v_paca_americana from public.material_commercial_catalog_v2 where code = 'PACA_AMERICANA';
  select id into v_paca_nacional from public.material_commercial_catalog_v2 where code = 'PACA_NACIONAL';
  select id into v_paca_limpia from public.material_commercial_catalog_v2 where code = 'PACA_LIMPIA';
  select id into v_pesado from public.material_commercial_catalog_v2 where code = 'PESADO';
  select id into v_placa_larga from public.material_commercial_catalog_v2 where code = 'PLACA_Y_ESTRUCTURA_LARGA';
  select id into v_paca_primera from public.material_commercial_catalog_v2 where code = 'PACA_DE_PRIMERA';
  select id into v_aluminio from public.material_commercial_catalog_v2 where code = 'ALUMINIO';
  select id into v_cobre_primera from public.material_commercial_catalog_v2 where code = 'COBRE_DE_PRIMERA';
  select id into v_archivo from public.material_commercial_catalog_v2 where code = 'ARCHIVO';
  select id into v_magazine from public.material_commercial_catalog_v2 where code = 'MAGAZINE';
  select id into v_bolsa from public.material_commercial_catalog_v2 where code = 'BOLSA';
  select id into v_unicel from public.material_commercial_catalog_v2 where code = 'UNICEL';
  select id into v_pedacera from public.material_commercial_catalog_v2 where code = 'PEDACERA';

  insert into public.inventory_opening_balances_v2 (
    period_month, as_of_date, inventory_level, general_material_id, weight_kg, site, notes
  )
  values
    (date '2026-03-01', date '2026-03-01', 'GENERAL', v_chatarra_general, 900.000, 'DICSA_CELAYA', 'MOCK 2 - apertura chatarra'),
    (date '2026-03-01', date '2026-03-01', 'GENERAL', v_plastico_general, 350.000, 'DICSA_CELAYA', 'MOCK 2 - apertura plastico'),
    (date '2026-03-01', date '2026-03-01', 'GENERAL', v_madera_general, 280.000, 'DICSA_CELAYA', 'MOCK 2 - apertura madera'),
    (date '2026-03-01', date '2026-03-01', 'GENERAL', v_metal_general, 240.000, 'DICSA_CELAYA', 'MOCK 2 - apertura metal');

  insert into public.inventory_movements_v2 (
    op_date, inventory_level, flow, general_material_id, source_commercial_material_id,
    origin_type, weight_kg, gross_kg, tare_kg, net_kg, total_amount_kg, site,
    counterparty, reference, notes
  )
  values
    (date '2026-03-18', 'GENERAL', 'IN', v_carton_general, v_carton_americano, 'DIRECT_PURCHASE', 2200.000, 2500.000, 300.000, 2200.000, 2200.000, 'DICSA_CELAYA', 'MOCK 2 PROVEEDOR CARTON', 'MOCK2-ENT-CARTON-001', 'MOCK 2 - entrada carton americano'),
    (date '2026-03-18', 'GENERAL', 'IN', v_chatarra_general, v_chat_mixta, 'DIRECT_PURCHASE', 1800.000, 2100.000, 300.000, 1800.000, 1800.000, 'DICSA_CELAYA', 'MOCK 2 PROVEEDOR CHATARRA', 'MOCK2-ENT-CHAT-001', 'MOCK 2 - entrada chatarra mixta'),
    (date '2026-03-18', 'GENERAL', 'IN', v_metal_general, v_mixto, 'DIRECT_PURCHASE', 420.000, 500.000, 80.000, 420.000, 420.000, 'DICSA_CELAYA', 'MOCK 2 PROVEEDOR METAL', 'MOCK2-ENT-METAL-001', 'MOCK 2 - entrada metal mixto'),
    (date '2026-03-18', 'GENERAL', 'IN', v_plastico_general, v_plastico_mixto, 'DIRECT_PURCHASE', 500.000, 620.000, 120.000, 500.000, 500.000, 'DICSA_CELAYA', 'MOCK 2 PROVEEDOR PLASTICO', 'MOCK2-ENT-PLAST-001', 'MOCK 2 - entrada plastico mixto'),
    (date '2026-03-18', 'GENERAL', 'IN', v_papel_general, v_revuelto, 'DIRECT_PURCHASE', 900.000, 1040.000, 140.000, 900.000, 900.000, 'DICSA_CELAYA', 'MOCK 2 PROVEEDOR PAPEL', 'MOCK2-ENT-PAPEL-001', 'MOCK 2 - entrada papel revuelto'),
    (date '2026-03-18', 'GENERAL', 'IN', v_madera_general, v_tarima, 'DIRECT_PURCHASE', 480.000, 530.000, 50.000, 480.000, 480.000, 'DICSA_CELAYA', 'MOCK 2 PROVEEDOR MADERA', 'MOCK2-ENT-MADERA-001', 'MOCK 2 - entrada madera tarima');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-03-18', 'DAY', v_carton_general, 'MIXED', 1800.000, 'DICSA_CELAYA', 'MOCK 2 - transformacion carton')
  returning id into v_run_carton;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_carton, v_paca_americana, 1200.000, 2, 'MOCK 2 - paca americana'),
    (v_run_carton, v_paca_nacional, 420.000, 1, 'MOCK 2 - paca nacional'),
    (v_run_carton, v_paca_limpia, 120.000, 1, 'MOCK 2 - paca limpia');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-03-18', 'DAY', v_papel_general, 'MIXED', 700.000, 'DICSA_CELAYA', 'MOCK 2 - transformacion papel en pacas')
  returning id into v_run_papel;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_papel, v_archivo, 430.000, 2, 'MOCK 2 - archivo en pacas'),
    (v_run_papel, v_magazine, 180.000, 1, 'MOCK 2 - magazine en pacas');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-03-18', 'DAY', v_chatarra_general, 'MIXED', 1600.000, 'DICSA_CELAYA', 'MOCK 2 - transformacion chatarra')
  returning id into v_run_chatarra;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_chatarra, v_pesado, 860.000, null, 'MOCK 2 - pesado'),
    (v_run_chatarra, v_placa_larga, 420.000, null, 'MOCK 2 - placa larga'),
    (v_run_chatarra, v_paca_primera, 180.000, 1, 'MOCK 2 - paca de primera');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-03-18', 'DAY', v_metal_general, 'MIXED', 300.000, 'DICSA_CELAYA', 'MOCK 2 - transformacion metal')
  returning id into v_run_metal;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_metal, v_aluminio, 170.000, null, 'MOCK 2 - aluminio'),
    (v_run_metal, v_cobre_primera, 55.000, null, 'MOCK 2 - cobre de primera');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-03-18', 'DAY', v_plastico_general, 'MIXED', 420.000, 'DICSA_CELAYA', 'MOCK 2 - transformacion plastico')
  returning id into v_run_plastico;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_plastico, v_bolsa, 210.000, null, 'MOCK 2 - bolsa'),
    (v_run_plastico, v_unicel, 90.000, null, 'MOCK 2 - unicel');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-03-18', 'DAY', v_madera_general, 'MIXED', 500.000, 'DICSA_CELAYA', 'MOCK 2 - transformacion madera')
  returning id into v_run_madera;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_madera, v_tarima, 260.000, 18, 'MOCK 2 - tarima clasificada'),
    (v_run_madera, v_pedacera, 150.000, null, 'MOCK 2 - pedacera');

  insert into public.inventory_movements_v2 (
    op_date, inventory_level, flow, commercial_material_id, origin_type,
    weight_kg, gross_kg, tare_kg, net_kg, total_amount_kg, site,
    counterparty, reference, notes
  )
  values
    (date '2026-03-18', 'COMMERCIAL', 'OUT', v_paca_americana, 'SALE', 650.000, 720.000, 70.000, 650.000, 650.000, 'DICSA_CELAYA', 'MOCK 2 CLIENTE CARTON', 'MOCK2-SAL-CARTON-001', 'MOCK 2 - salida paca americana'),
    (date '2026-03-18', 'COMMERCIAL', 'OUT', v_archivo, 'SALE', 210.000, 240.000, 30.000, 210.000, 210.000, 'DICSA_CELAYA', 'MOCK 2 CLIENTE PAPEL', 'MOCK2-SAL-PAPEL-001', 'MOCK 2 - salida archivo'),
    (date '2026-03-18', 'COMMERCIAL', 'OUT', v_pesado, 'SALE', 320.000, 360.000, 40.000, 320.000, 320.000, 'DICSA_CELAYA', 'MOCK 2 CLIENTE CHATARRA', 'MOCK2-SAL-CHAT-001', 'MOCK 2 - salida pesado'),
    (date '2026-03-18', 'COMMERCIAL', 'OUT', v_aluminio, 'SALE', 60.000, 72.000, 12.000, 60.000, 60.000, 'DICSA_CELAYA', 'MOCK 2 CLIENTE METAL', 'MOCK2-SAL-METAL-001', 'MOCK 2 - salida aluminio'),
    (date '2026-03-18', 'COMMERCIAL', 'OUT', v_bolsa, 'SALE', 70.000, 82.000, 12.000, 70.000, 70.000, 'DICSA_CELAYA', 'MOCK 2 CLIENTE PLASTICO', 'MOCK2-SAL-PLAST-001', 'MOCK 2 - salida bolsa'),
    (date '2026-03-18', 'COMMERCIAL', 'OUT', v_tarima, 'SALE', 110.000, 130.000, 20.000, 110.000, 110.000, 'DICSA_CELAYA', 'MOCK 2 CLIENTE MADERA', 'MOCK2-SAL-MADERA-001', 'MOCK 2 - salida tarima');
end
$$;

commit;
