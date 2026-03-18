begin;

delete from public.material_transformation_runs_v2;
delete from public.inventory_movements_v2;
delete from public.inventory_opening_balances_v2;

do $$
declare
  v_carton_general uuid;
  v_chatarra_general uuid;
  v_metal_general uuid;
  v_plastico_general uuid;
  v_madera_general uuid;
  v_papel_general uuid;

  v_carton_nacional uuid;
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

  v_run_carton_jan uuid;
  v_run_papel_jan uuid;
  v_run_metal_jan uuid;
  v_run_chatarra_jan uuid;
  v_run_carton_feb uuid;
  v_run_chatarra_feb uuid;
  v_run_plastico_feb uuid;
  v_run_madera_feb uuid;
  v_run_carton_mar uuid;
  v_run_papel_mar uuid;
  v_run_chatarra_mar uuid;
  v_run_metal_mar uuid;
begin
  select id into v_carton_general from public.material_general_catalog_v2 where code = 'CARTON';
  select id into v_chatarra_general from public.material_general_catalog_v2 where code = 'CHATARRA';
  select id into v_metal_general from public.material_general_catalog_v2 where code = 'METAL';
  select id into v_plastico_general from public.material_general_catalog_v2 where code = 'PLASTICO';
  select id into v_madera_general from public.material_general_catalog_v2 where code = 'MADERA';
  select id into v_papel_general from public.material_general_catalog_v2 where code = 'PAPEL';

  select id into v_carton_nacional from public.material_commercial_catalog_v2 where code = 'CARTON_NACIONAL';
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
    (date '2026-01-01', date '2026-01-01', 'GENERAL', v_carton_general, 1500.000, 'DICSA_CELAYA', 'DEMO MULTIMES - apertura inicial carton'),
    (date '2026-01-01', date '2026-01-01', 'GENERAL', v_chatarra_general, 800.000, 'DICSA_CELAYA', 'DEMO MULTIMES - apertura inicial chatarra'),
    (date '2026-01-01', date '2026-01-01', 'GENERAL', v_metal_general, 300.000, 'DICSA_CELAYA', 'DEMO MULTIMES - apertura inicial metal'),
    (date '2026-01-01', date '2026-01-01', 'GENERAL', v_plastico_general, 250.000, 'DICSA_CELAYA', 'DEMO MULTIMES - apertura inicial plastico'),
    (date '2026-01-01', date '2026-01-01', 'GENERAL', v_madera_general, 200.000, 'DICSA_CELAYA', 'DEMO MULTIMES - apertura inicial madera'),
    (date '2026-01-01', date '2026-01-01', 'GENERAL', v_papel_general, 600.000, 'DICSA_CELAYA', 'DEMO MULTIMES - apertura inicial papel');

  insert into public.inventory_opening_balances_v2 (
    period_month, as_of_date, inventory_level, commercial_material_id, weight_kg, site, notes
  )
  values
    (date '2026-01-01', date '2026-01-01', 'COMMERCIAL', v_paca_americana, 380.000, 'DICSA_CELAYA', 'DEMO MULTIMES - apertura inicial paca americana'),
    (date '2026-01-01', date '2026-01-01', 'COMMERCIAL', v_archivo, 120.000, 'DICSA_CELAYA', 'DEMO MULTIMES - apertura inicial archivo'),
    (date '2026-01-01', date '2026-01-01', 'COMMERCIAL', v_aluminio, 90.000, 'DICSA_CELAYA', 'DEMO MULTIMES - apertura inicial aluminio');

  insert into public.inventory_movements_v2 (
    op_date, inventory_level, flow, general_material_id, source_commercial_material_id,
    origin_type, weight_kg, gross_kg, tare_kg, net_kg, total_amount_kg, site,
    counterparty, reference, notes
  )
  values
    (date '2026-01-08', 'GENERAL', 'IN', v_carton_general, v_carton_nacional, 'DIRECT_PURCHASE', 1600.000, 1850.000, 250.000, 1600.000, 1600.000, 'DICSA_CELAYA', 'PROVEEDOR ENERO CARTON', 'ENE-ENT-CARTON-001', 'ENERO - entrada carton nacional'),
    (date '2026-01-09', 'GENERAL', 'IN', v_chatarra_general, v_chat_mixta, 'DIRECT_PURCHASE', 900.000, 1100.000, 200.000, 900.000, 900.000, 'DICSA_CELAYA', 'PROVEEDOR ENERO CHATARRA', 'ENE-ENT-CHAT-001', 'ENERO - entrada chatarra mixta'),
    (date '2026-01-10', 'GENERAL', 'IN', v_metal_general, v_mixto, 'DIRECT_PURCHASE', 180.000, 230.000, 50.000, 180.000, 180.000, 'DICSA_CELAYA', 'PROVEEDOR ENERO METAL', 'ENE-ENT-MET-001', 'ENERO - entrada metal mixto'),
    (date '2026-01-11', 'GENERAL', 'IN', v_papel_general, v_revuelto, 'DIRECT_PURCHASE', 500.000, 620.000, 120.000, 500.000, 500.000, 'DICSA_CELAYA', 'PROVEEDOR ENERO PAPEL', 'ENE-ENT-PAP-001', 'ENERO - entrada papel revuelto'),
    (date '2026-02-04', 'GENERAL', 'IN', v_carton_general, v_carton_americano, 'DIRECT_PURCHASE', 1800.000, 2100.000, 300.000, 1800.000, 1800.000, 'DICSA_CELAYA', 'PROVEEDOR FEBRERO CARTON', 'FEB-ENT-CARTON-001', 'FEBRERO - entrada carton americano'),
    (date '2026-02-06', 'GENERAL', 'IN', v_chatarra_general, v_chat_mixta, 'DIRECT_PURCHASE', 600.000, 760.000, 160.000, 600.000, 600.000, 'DICSA_CELAYA', 'PROVEEDOR FEBRERO CHATARRA', 'FEB-ENT-CHAT-001', 'FEBRERO - entrada chatarra mixta'),
    (date '2026-02-09', 'GENERAL', 'IN', v_metal_general, v_mixto, 'DIRECT_PURCHASE', 350.000, 430.000, 80.000, 350.000, 350.000, 'DICSA_CELAYA', 'PROVEEDOR FEBRERO METAL', 'FEB-ENT-MET-001', 'FEBRERO - entrada metal mixto'),
    (date '2026-02-10', 'GENERAL', 'IN', v_plastico_general, v_plastico_mixto, 'DIRECT_PURCHASE', 420.000, 520.000, 100.000, 420.000, 420.000, 'DICSA_CELAYA', 'PROVEEDOR FEBRERO PLASTICO', 'FEB-ENT-PLA-001', 'FEBRERO - entrada plastico mixto'),
    (date '2026-02-12', 'GENERAL', 'IN', v_madera_general, v_tarima, 'DIRECT_PURCHASE', 300.000, 360.000, 60.000, 300.000, 300.000, 'DICSA_CELAYA', 'PROVEEDOR FEBRERO MADERA', 'FEB-ENT-MAD-001', 'FEBRERO - entrada madera tarima'),
    (date '2026-03-03', 'GENERAL', 'IN', v_papel_general, v_revuelto, 'DIRECT_PURCHASE', 900.000, 1040.000, 140.000, 900.000, 900.000, 'DICSA_CELAYA', 'PROVEEDOR MARZO PAPEL', 'MAR-ENT-PAP-001', 'MARZO - entrada papel revuelto'),
    (date '2026-03-05', 'GENERAL', 'IN', v_chatarra_general, v_chat_mixta, 'DIRECT_PURCHASE', 1200.000, 1440.000, 240.000, 1200.000, 1200.000, 'DICSA_CELAYA', 'PROVEEDOR MARZO CHATARRA', 'MAR-ENT-CHAT-001', 'MARZO - entrada chatarra mixta'),
    (date '2026-03-07', 'GENERAL', 'IN', v_carton_general, v_carton_nacional, 'DIRECT_PURCHASE', 1100.000, 1320.000, 220.000, 1100.000, 1100.000, 'DICSA_CELAYA', 'PROVEEDOR MARZO CARTON', 'MAR-ENT-CARTON-001', 'MARZO - entrada carton nacional'),
    (date '2026-03-08', 'GENERAL', 'IN', v_metal_general, v_mixto, 'DIRECT_PURCHASE', 160.000, 210.000, 50.000, 160.000, 160.000, 'DICSA_CELAYA', 'PROVEEDOR MARZO METAL', 'MAR-ENT-MET-001', 'MARZO - entrada metal mixto');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-01-14', 'DAY', v_carton_general, 'MIXED', 1200.000, 'DICSA_CELAYA', 'ENERO - transformacion carton')
  returning id into v_run_carton_jan;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_carton_jan, v_paca_americana, 700.000, 1, 'ENERO - paca americana'),
    (v_run_carton_jan, v_paca_nacional, 280.000, 1, 'ENERO - paca nacional'),
    (v_run_carton_jan, v_paca_limpia, 90.000, 1, 'ENERO - paca limpia');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-01-15', 'DAY', v_papel_general, 'MIXED', 400.000, 'DICSA_CELAYA', 'ENERO - transformacion papel')
  returning id into v_run_papel_jan;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_papel_jan, v_archivo, 260.000, 2, 'ENERO - archivo'),
    (v_run_papel_jan, v_magazine, 90.000, 1, 'ENERO - magazine');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-01-16', 'DAY', v_metal_general, 'MIXED', 220.000, 'DICSA_CELAYA', 'ENERO - transformacion metal')
  returning id into v_run_metal_jan;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_metal_jan, v_aluminio, 140.000, null, 'ENERO - aluminio'),
    (v_run_metal_jan, v_cobre_primera, 35.000, null, 'ENERO - cobre primera');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-01-17', 'DAY', v_chatarra_general, 'MIXED', 700.000, 'DICSA_CELAYA', 'ENERO - transformacion chatarra')
  returning id into v_run_chatarra_jan;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_chatarra_jan, v_pesado, 320.000, null, 'ENERO - pesado'),
    (v_run_chatarra_jan, v_placa_larga, 180.000, null, 'ENERO - placa y estructura larga'),
    (v_run_chatarra_jan, v_paca_primera, 90.000, 1, 'ENERO - paca de primera');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-02-14', 'DAY', v_carton_general, 'MIXED', 1500.000, 'DICSA_CELAYA', 'FEBRERO - transformacion carton')
  returning id into v_run_carton_feb;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_carton_feb, v_paca_americana, 980.000, 2, 'FEBRERO - paca americana'),
    (v_run_carton_feb, v_paca_nacional, 260.000, 1, 'FEBRERO - paca nacional'),
    (v_run_carton_feb, v_paca_limpia, 80.000, 1, 'FEBRERO - paca limpia');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-02-16', 'DAY', v_chatarra_general, 'MIXED', 600.000, 'DICSA_CELAYA', 'FEBRERO - transformacion chatarra')
  returning id into v_run_chatarra_feb;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_chatarra_feb, v_pesado, 270.000, null, 'FEBRERO - pesado'),
    (v_run_chatarra_feb, v_paca_primera, 130.000, 1, 'FEBRERO - paca de primera');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-02-18', 'DAY', v_plastico_general, 'MIXED', 300.000, 'DICSA_CELAYA', 'FEBRERO - transformacion plastico')
  returning id into v_run_plastico_feb;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_plastico_feb, v_bolsa, 140.000, null, 'FEBRERO - bolsa'),
    (v_run_plastico_feb, v_unicel, 80.000, null, 'FEBRERO - unicel');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-02-20', 'DAY', v_madera_general, 'MIXED', 240.000, 'DICSA_CELAYA', 'FEBRERO - transformacion madera')
  returning id into v_run_madera_feb;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_madera_feb, v_tarima, 160.000, 10, 'FEBRERO - tarima'),
    (v_run_madera_feb, v_pedacera, 50.000, null, 'FEBRERO - pedacera');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-03-10', 'DAY', v_carton_general, 'MIXED', 900.000, 'DICSA_CELAYA', 'MARZO - transformacion carton')
  returning id into v_run_carton_mar;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_carton_mar, v_paca_americana, 620.000, 1, 'MARZO - paca americana'),
    (v_run_carton_mar, v_paca_nacional, 190.000, 1, 'MARZO - paca nacional');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-03-11', 'DAY', v_papel_general, 'MIXED', 700.000, 'DICSA_CELAYA', 'MARZO - transformacion papel')
  returning id into v_run_papel_mar;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_papel_mar, v_archivo, 430.000, 2, 'MARZO - archivo'),
    (v_run_papel_mar, v_magazine, 180.000, 1, 'MARZO - magazine');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-03-12', 'DAY', v_chatarra_general, 'MIXED', 900.000, 'DICSA_CELAYA', 'MARZO - transformacion chatarra')
  returning id into v_run_chatarra_mar;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_chatarra_mar, v_pesado, 410.000, null, 'MARZO - pesado'),
    (v_run_chatarra_mar, v_placa_larga, 230.000, null, 'MARZO - placa y estructura larga'),
    (v_run_chatarra_mar, v_paca_primera, 110.000, 1, 'MARZO - paca de primera');

  insert into public.material_transformation_runs_v2 (
    op_date, shift, source_general_material_id, source_mode, input_weight_kg, site, notes
  )
  values
    (date '2026-03-13', 'DAY', v_metal_general, 'MIXED', 180.000, 'DICSA_CELAYA', 'MARZO - transformacion metal')
  returning id into v_run_metal_mar;

  insert into public.material_transformation_run_outputs_v2 (
    run_id, commercial_material_id, output_weight_kg, output_unit_count, notes
  )
  values
    (v_run_metal_mar, v_aluminio, 90.000, null, 'MARZO - aluminio');

  insert into public.inventory_movements_v2 (
    op_date, inventory_level, flow, commercial_material_id, origin_type,
    weight_kg, gross_kg, tare_kg, net_kg, total_amount_kg, site,
    counterparty, reference, notes
  )
  values
    (date '2026-01-21', 'COMMERCIAL', 'OUT', v_paca_americana, 'SALE', 300.000, 340.000, 40.000, 300.000, 300.000, 'DICSA_CELAYA', 'CLIENTE ENERO CARTON', 'ENE-SAL-CART-001', 'ENERO - salida paca americana'),
    (date '2026-01-23', 'COMMERCIAL', 'OUT', v_archivo, 'SALE', 100.000, 120.000, 20.000, 100.000, 100.000, 'DICSA_CELAYA', 'CLIENTE ENERO PAPEL', 'ENE-SAL-PAP-001', 'ENERO - salida archivo'),
    (date '2026-01-24', 'COMMERCIAL', 'OUT', v_aluminio, 'SALE', 60.000, 75.000, 15.000, 60.000, 60.000, 'DICSA_CELAYA', 'CLIENTE ENERO METAL', 'ENE-SAL-MET-001', 'ENERO - salida aluminio'),
    (date '2026-02-22', 'COMMERCIAL', 'OUT', v_paca_nacional, 'SALE', 150.000, 180.000, 30.000, 150.000, 150.000, 'DICSA_CELAYA', 'CLIENTE FEBRERO CARTON', 'FEB-SAL-CART-001', 'FEBRERO - salida paca nacional'),
    (date '2026-02-23', 'COMMERCIAL', 'OUT', v_pesado, 'SALE', 200.000, 230.000, 30.000, 200.000, 200.000, 'DICSA_CELAYA', 'CLIENTE FEBRERO CHATARRA', 'FEB-SAL-CHAT-001', 'FEBRERO - salida pesado'),
    (date '2026-02-24', 'COMMERCIAL', 'OUT', v_tarima, 'SALE', 70.000, 88.000, 18.000, 70.000, 70.000, 'DICSA_CELAYA', 'CLIENTE FEBRERO MADERA', 'FEB-SAL-MAD-001', 'FEBRERO - salida tarima'),
    (date '2026-02-25', 'COMMERCIAL', 'OUT', v_bolsa, 'SALE', 60.000, 74.000, 14.000, 60.000, 60.000, 'DICSA_CELAYA', 'CLIENTE FEBRERO PLASTICO', 'FEB-SAL-PLA-001', 'FEBRERO - salida bolsa'),
    (date '2026-03-15', 'COMMERCIAL', 'OUT', v_paca_americana, 'SALE', 500.000, 560.000, 60.000, 500.000, 500.000, 'DICSA_CELAYA', 'CLIENTE MARZO CARTON', 'MAR-SAL-CART-001', 'MARZO - salida paca americana'),
    (date '2026-03-16', 'COMMERCIAL', 'OUT', v_archivo, 'SALE', 180.000, 210.000, 30.000, 180.000, 180.000, 'DICSA_CELAYA', 'CLIENTE MARZO PAPEL', 'MAR-SAL-PAP-001', 'MARZO - salida archivo'),
    (date '2026-03-17', 'COMMERCIAL', 'OUT', v_pesado, 'SALE', 220.000, 250.000, 30.000, 220.000, 220.000, 'DICSA_CELAYA', 'CLIENTE MARZO CHATARRA', 'MAR-SAL-CHAT-001', 'MARZO - salida pesado'),
    (date '2026-03-17', 'COMMERCIAL', 'OUT', v_aluminio, 'SALE', 40.000, 52.000, 12.000, 40.000, 40.000, 'DICSA_CELAYA', 'CLIENTE MARZO METAL', 'MAR-SAL-MET-001', 'MARZO - salida aluminio'),
    (date '2026-03-18', 'COMMERCIAL', 'OUT', v_magazine, 'SALE', 70.000, 86.000, 16.000, 70.000, 70.000, 'DICSA_CELAYA', 'CLIENTE MARZO PAPEL', 'MAR-SAL-MAG-001', 'MARZO - salida magazine');
end
$$;

commit;
