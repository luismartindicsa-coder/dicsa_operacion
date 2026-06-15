-- Generated from Facturas Manuales Pendientes.xlsx

insert into public.finanzas_catalog_companies (id, name, source, linked_name, is_active, notes)
select 'fc_import_togo', 'TOGO', 'DIRECTO', 'TOGO', true, 'IMPORTADO DESDE LEGACY PROVEEDORES PAGOS 2026-06-10'
where not exists (
  select 1
  from public.finanzas_catalog_companies existing
  where existing.id = 'fc_import_togo'
);

insert into public.finanzas_catalog_companies (id, name, source, linked_name, is_active, notes)
select 'fc_import_opresa', 'OPRESA', 'DIRECTO', 'OPRESA', true, 'IMPORTADO DESDE LEGACY PROVEEDORES PAGOS 2026-06-10'
where not exists (
  select 1
  from public.finanzas_catalog_companies existing
  where existing.id = 'fc_import_opresa'
);

insert into public.finanzas_catalog_companies (id, name, source, linked_name, is_active, notes)
select 'fc_import_grupo_constructor_pate', 'GRUPO CONSTRUCTOR PATE', 'DIRECTO', 'GRUPO CONSTRUCTOR PATE', true, 'IMPORTADO DESDE LEGACY PROVEEDORES PAGOS 2026-06-10'
where not exists (
  select 1
  from public.finanzas_catalog_companies existing
  where existing.id = 'fc_import_grupo_constructor_pate'
);

insert into public.finanzas_catalog_companies (id, name, source, linked_name, is_active, notes)
select 'fc_import_cbicentenario', 'CBICENTENARIO', 'DIRECTO', 'CBICENTENARIO', true, 'IMPORTADO DESDE LEGACY PROVEEDORES PAGOS 2026-06-10'
where not exists (
  select 1
  from public.finanzas_catalog_companies existing
  where existing.id = 'fc_import_cbicentenario'
);

insert into public.finanzas_catalog_companies (id, name, source, linked_name, is_active, notes)
select 'fc_import_melvar_solutions', 'MELVAR SOLUTIONS', 'DIRECTO', 'MELVAR SOLUTIONS', true, 'IMPORTADO DESDE LEGACY PROVEEDORES PAGOS 2026-06-10'
where not exists (
  select 1
  from public.finanzas_catalog_companies existing
  where existing.id = 'fc_import_melvar_solutions'
);

insert into public.finanzas_catalog_companies (id, name, source, linked_name, is_active, notes)
select 'fc_import_qualitas_seguros', 'QUALITAS SEGUROS', 'DIRECTO', 'QUALITAS SEGUROS', true, 'IMPORTADO DESDE LEGACY PROVEEDORES PAGOS 2026-06-10'
where not exists (
  select 1
  from public.finanzas_catalog_companies existing
  where existing.id = 'fc_import_qualitas_seguros'
);

insert into public.finanzas_catalog_companies (id, name, source, linked_name, is_active, notes)
select 'fc_import_serindmontacargas', 'SERINDMONTACARGAS', 'DIRECTO', 'SERINDMONTACARGAS', true, 'IMPORTADO DESDE LEGACY PROVEEDORES PAGOS 2026-06-10'
where not exists (
  select 1
  from public.finanzas_catalog_companies existing
  where existing.id = 'fc_import_serindmontacargas'
);

insert into public.finanzas_catalog_companies (id, name, source, linked_name, is_active, notes)
select 'fc_import_sarollantas', 'SAROLLANTAS', 'DIRECTO', 'SAROLLANTAS', true, 'IMPORTADO DESDE LEGACY PROVEEDORES PAGOS 2026-06-10'
where not exists (
  select 1
  from public.finanzas_catalog_companies existing
  where existing.id = 'fc_import_sarollantas'
);

insert into public.finanzas_catalog_companies (id, name, source, linked_name, is_active, notes)
select 'fc_import_miguel_angel_mendoza_barajas', 'MIGUEL ANGEL MENDOZA BARAJAS', 'DIRECTO', 'MIGUEL ANGEL MENDOZA BARAJAS', true, 'IMPORTADO DESDE LEGACY PROVEEDORES PAGOS 2026-06-10'
where not exists (
  select 1
  from public.finanzas_catalog_companies existing
  where existing.id = 'fc_import_miguel_angel_mendoza_barajas'
);

insert into public.finanzas_catalog_companies (id, name, source, linked_name, is_active, notes)
select 'compras_cp_import_acroma', 'ACROMA', 'COMPRAS', 'ACROMA', true, 'SINCRONIZADO DESDE COMPRAS MAYOREO'
where not exists (
  select 1
  from public.finanzas_catalog_companies existing
  where existing.id = 'compras_cp_import_acroma'
);

insert into public.finanzas_catalog_companies (id, name, source, linked_name, is_active, notes)
select 'fc_import_juan_arellano_rangel', 'JUAN ARELLANO RANGEL', 'DIRECTO', 'JUAN ARELLANO RANGEL', true, 'IMPORTADO DESDE LEGACY PROVEEDORES PAGOS 2026-06-10'
where not exists (
  select 1
  from public.finanzas_catalog_companies existing
  where existing.id = 'fc_import_juan_arellano_rangel'
);

insert into public.finanzas_catalog_companies (id, name, source, linked_name, is_active, notes)
select 'fc_import_ricardo_moreno_arreguin', 'RICARDO MORENO ARREGUIN', 'DIRECTO', 'RICARDO MORENO ARREGUIN', true, 'IMPORTADO DESDE LEGACY PROVEEDORES PAGOS 2026-06-10'
where not exists (
  select 1
  from public.finanzas_catalog_companies existing
  where existing.id = 'fc_import_ricardo_moreno_arreguin'
);

insert into public.finanzas_catalog_companies (id, name, source, linked_name, is_active, notes)
select 'fc_import_lub_bajio', 'LUB BAJIO', 'DIRECTO', 'LUB BAJIO', true, 'IMPORTADO DESDE LEGACY PROVEEDORES PAGOS 2026-06-10'
where not exists (
  select 1
  from public.finanzas_catalog_companies existing
  where existing.id = 'fc_import_lub_bajio'
);

insert into public.finanzas_catalog_companies (id, name, source, linked_name, is_active, notes)
select 'fc_import_transportes_tseh', 'TRANSPORTES TSEH', 'DIRECTO', 'TRANSPORTES TSEH', true, 'IMPORTADO DESDE LEGACY PROVEEDORES PAGOS 2026-06-10'
where not exists (
  select 1
  from public.finanzas_catalog_companies existing
  where existing.id = 'fc_import_transportes_tseh'
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-togo-6326-2026-06-09', 'fc_import_togo', 'TOGO', 'DICSA', 'CELAYA', '6326', 'MANUAL', '2026-06-09T00:00:00', '2026-06-24T00:00:00', 4828.01, 4828.01, case when 4828.01 <= 0 then 'PAGADA' when '2026-06-24T00:00:00' is not null and '2026-06-24T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, '4 CUBETAS DE ACEITE HIDRAULICO', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_togo'
    and upper(existing.invoice_folio) = upper('6326')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-opresa-8491-2026-06-08', 'fc_import_opresa', 'OPRESA', 'DICSA', 'CELAYA', '8491', 'MANUAL', '2026-06-08T00:00:00', '2026-06-10T00:00:00', 506.92, 506.92, case when 506.92 <= 0 then 'PAGADA' when '2026-06-10T00:00:00' is not null and '2026-06-10T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'DEL 23-31 MAYO 2026', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_opresa'
    and upper(existing.invoice_folio) = upper('8491')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-grupo-constructor-pate-482-2026-06-05', 'fc_import_grupo_constructor_pate', 'GRUPO CONSTRUCTOR PATE', 'DICSA', 'CELAYA', '482', 'MANUAL', '2026-06-05T00:00:00', '2026-06-12T00:00:00', 12180.00, 12180.00, case when 12180.00 <= 0 then 'PAGADA' when '2026-06-12T00:00:00' is not null and '2026-06-12T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'ESTUDIO VIAL', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_grupo_constructor_pate'
    and upper(existing.invoice_folio) = upper('482')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-cbicentenario-10551-2026-06-04', 'fc_import_cbicentenario', 'CBICENTENARIO', 'DICSA', 'CELAYA', '10551', 'MANUAL', '2026-06-04T00:00:00', '2026-06-19T00:00:00', 14627.00, 14627.00, case when 14627.00 <= 0 then 'PAGADA' when '2026-06-19T00:00:00' is not null and '2026-06-19T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'DEL 21-31 MAYO 2026', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_cbicentenario'
    and upper(existing.invoice_folio) = upper('10551')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-togo-6270-2026-06-03', 'fc_import_togo', 'TOGO', 'DICSA', 'CELAYA', '6270', 'MANUAL', '2026-06-03T00:00:00', '2026-06-17T00:00:00', 2960.99, 2960.99, case when 2960.99 <= 0 then 'PAGADA' when '2026-06-17T00:00:00' is not null and '2026-06-17T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, '3 CUBETAS ANTICONGELANTE', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_togo'
    and upper(existing.invoice_folio) = upper('6270')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-melvar-solutions-1428-2026-06-02', 'fc_import_melvar_solutions', 'MELVAR SOLUTIONS', 'DICSA', 'CELAYA', '1428', 'MANUAL', '2026-06-02T00:00:00', '2026-06-09T00:00:00', 7275.02, 7275.02, case when 7275.02 <= 0 then 'PAGADA' when '2026-06-09T00:00:00' is not null and '2026-06-09T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'SERVICIOS', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_melvar_solutions'
    and upper(existing.invoice_folio) = upper('1428')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-togo-6261-2026-06-02', 'fc_import_togo', 'TOGO', 'DICSA', 'CELAYA', '6261', 'MANUAL', '2026-06-02T00:00:00', '2026-06-24T00:00:00', 4828.01, 4828.01, case when 4828.01 <= 0 then 'PAGADA' when '2026-06-24T00:00:00' is not null and '2026-06-24T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, '4 CUBETAS DE ACEITE HIDRAULICO', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_togo'
    and upper(existing.invoice_folio) = upper('6261')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-qualitas-seguros-301762933-2026-06-01', 'fc_import_qualitas_seguros', 'QUALITAS SEGUROS', 'DICSA', 'CELAYA', '301762933', 'MANUAL', '2026-06-01T00:00:00', '2026-08-14T00:00:00', 4789.00, 4789.00, case when 4789.00 <= 0 then 'PAGADA' when '2026-08-14T00:00:00' is not null and '2026-08-14T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'SEGURO FORD 350', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_qualitas_seguros'
    and upper(existing.invoice_folio) = upper('301762933')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-qualitas-seguros-301763428-2026-06-01', 'fc_import_qualitas_seguros', 'QUALITAS SEGUROS', 'DICSA', 'CELAYA', '301763428', 'MANUAL', '2026-06-01T00:00:00', '2026-08-14T00:00:00', 3845.00, 3845.00, case when 3845.00 <= 0 then 'PAGADA' when '2026-08-14T00:00:00' is not null and '2026-08-14T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'SEGURO FORD F350', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_qualitas_seguros'
    and upper(existing.invoice_folio) = upper('301763428')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-qualitas-seguros-301768569-2026-06-01', 'fc_import_qualitas_seguros', 'QUALITAS SEGUROS', 'DICSA', 'CELAYA', '301768569', 'MANUAL', '2026-06-01T00:00:00', '2026-08-14T00:00:00', 2620.00, 2620.00, case when 2620.00 <= 0 then 'PAGADA' when '2026-08-14T00:00:00' is not null and '2026-08-14T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'SEGURO NISSAN ESTACAS', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_qualitas_seguros'
    and upper(existing.invoice_folio) = upper('301768569')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-qualitas-seguros-301768218-2026-06-01', 'fc_import_qualitas_seguros', 'QUALITAS SEGUROS', 'DICSA', 'CELAYA', '301768218', 'MANUAL', '2026-06-01T00:00:00', '2026-08-14T00:00:00', 2531.00, 2531.00, case when 2531.00 <= 0 then 'PAGADA' when '2026-08-14T00:00:00' is not null and '2026-08-14T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'SEGURO NISSAN PICK UP', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_qualitas_seguros'
    and upper(existing.invoice_folio) = upper('301768218')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-serindmontacargas-1833-2026-06-01', 'fc_import_serindmontacargas', 'SERINDMONTACARGAS', 'DICSA', 'CELAYA', '1833', 'MANUAL', '2026-06-01T00:00:00', '2026-06-30T00:00:00', 4640.00, 4640.00, case when 4640.00 <= 0 then 'PAGADA' when '2026-06-30T00:00:00' is not null and '2026-06-30T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, '03 MARZO AL 10 MARZO 2026', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_serindmontacargas'
    and upper(existing.invoice_folio) = upper('1833')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-opresa-8482-2026-05-31', 'fc_import_opresa', 'OPRESA', 'DICSA', 'CELAYA', '8482', 'MANUAL', '2026-05-31T00:00:00', '2026-06-08T00:00:00', 506.92, 506.92, case when 506.92 <= 0 then 'PAGADA' when '2026-06-08T00:00:00' is not null and '2026-06-08T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, '25-30 MAYO', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_opresa'
    and upper(existing.invoice_folio) = upper('8482')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-sarollantas-4581-2026-05-29', 'fc_import_sarollantas', 'SAROLLANTAS', 'DICSA', 'CELAYA', '4581', 'MANUAL', '2026-05-29T00:00:00', '2026-07-02T00:00:00', 3600.00, 3600.00, case when 3600.00 <= 0 then 'PAGADA' when '2026-07-02T00:00:00' is not null and '2026-07-02T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, '1 LLANTA 7.5 17', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_sarollantas'
    and upper(existing.invoice_folio) = upper('4581')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-miguel-angel-mendoza-barajas-5ca02-2026-05-28', 'fc_import_miguel_angel_mendoza_barajas', 'MIGUEL ANGEL MENDOZA BARAJAS', 'DICSA', 'CELAYA', '5CA02', 'MANUAL', '2026-05-28T00:00:00', '2026-06-12T00:00:00', 2320.00, 2320.00, case when 2320.00 <= 0 then 'PAGADA' when '2026-06-12T00:00:00' is not null and '2026-06-12T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'CONSULTORIA AMBIENTE', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_miguel_angel_mendoza_barajas'
    and upper(existing.invoice_folio) = upper('5CA02')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-acroma-4619-2026-05-27', 'compras_cp_import_acroma', 'ACROMA', 'DICSA', 'CELAYA', '4619', 'MANUAL', '2026-05-27T00:00:00', null, 46174.00, 46174.00, case when 46174.00 <= 0 then 'PAGADA' when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'CHATARRA', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'compras_cp_import_acroma'
    and upper(existing.invoice_folio) = upper('4619')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-cbicentenario-10509-2026-05-25', 'fc_import_cbicentenario', 'CBICENTENARIO', 'DICSA', 'CELAYA', '10509', 'MANUAL', '2026-05-25T00:00:00', '2026-06-05T00:00:00', 16044.01, 16044.01, case when 16044.01 <= 0 then 'PAGADA' when '2026-06-05T00:00:00' is not null and '2026-06-05T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'DEL 11-20MAYO 2026', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_cbicentenario'
    and upper(existing.invoice_folio) = upper('10509')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-opresa-8471-2026-05-25', 'fc_import_opresa', 'OPRESA', 'DICSA', 'CELAYA', '8471', 'MANUAL', '2026-05-25T00:00:00', '2026-05-29T00:00:00', 506.92, 506.92, case when 506.92 <= 0 then 'PAGADA' when '2026-05-29T00:00:00' is not null and '2026-05-29T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, '18-24 MAYO 2026', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_opresa'
    and upper(existing.invoice_folio) = upper('8471')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-togo-6054-2026-05-21', 'fc_import_togo', 'TOGO', 'DICSA', 'CELAYA', '6054', 'MANUAL', '2026-05-21T00:00:00', '2026-06-11T00:00:00', 2960.99, 2960.99, case when 2960.99 <= 0 then 'PAGADA' when '2026-06-11T00:00:00' is not null and '2026-06-11T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, '3 CUBETAS DE ANTICONGELANTE', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_togo'
    and upper(existing.invoice_folio) = upper('6054')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-juan-arellano-rangel-11736-2026-05-19', 'fc_import_juan_arellano_rangel', 'JUAN ARELLANO RANGEL', 'DICSA', 'CELAYA', '11736', 'MANUAL', '2026-05-19T00:00:00', '2026-06-05T00:00:00', 6960.00, 6960.00, case when 6960.00 <= 0 then 'PAGADA' when '2026-06-05T00:00:00' is not null and '2026-06-05T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'PROTECCION CIVIL', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_juan_arellano_rangel'
    and upper(existing.invoice_folio) = upper('11736')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-juan-arellano-rangel-11737-2026-05-19', 'fc_import_juan_arellano_rangel', 'JUAN ARELLANO RANGEL', 'DICSA', 'CELAYA', '11737', 'MANUAL', '2026-05-19T00:00:00', '2026-06-05T00:00:00', 18560.00, 18560.00, case when 18560.00 <= 0 then 'PAGADA' when '2026-06-05T00:00:00' is not null and '2026-06-05T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'PROTECCION CIVIL', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_juan_arellano_rangel'
    and upper(existing.invoice_folio) = upper('11737')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-sarollantas-4573-2026-05-18', 'fc_import_sarollantas', 'SAROLLANTAS', 'DICSA', 'CELAYA', '4573', 'MANUAL', '2026-05-18T00:00:00', '2026-06-30T00:00:00', 16700.00, 16700.00, case when 16700.00 <= 0 then 'PAGADA' when '2026-06-30T00:00:00' is not null and '2026-06-30T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, '4 LLANTAS', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_sarollantas'
    and upper(existing.invoice_folio) = upper('4573')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-ricardo-moreno-arreguin-1313-2026-05-18', 'fc_import_ricardo_moreno_arreguin', 'RICARDO MORENO ARREGUIN', 'DICSA', 'CELAYA', '1313', 'MANUAL', '2026-05-18T00:00:00', '2026-06-04T00:00:00', 7900.00, 7900.00, case when 7900.00 <= 0 then 'PAGADA' when '2026-06-04T00:00:00' is not null and '2026-06-04T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'CONTABILIDAD ABRIL 2026', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_ricardo_moreno_arreguin'
    and upper(existing.invoice_folio) = upper('1313')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-ricardo-moreno-arreguin-1314-2026-05-18', 'fc_import_ricardo_moreno_arreguin', 'RICARDO MORENO ARREGUIN', 'DICSA', 'CELAYA', '1314', 'MANUAL', '2026-05-18T00:00:00', '2026-06-04T00:00:00', 2500.00, 2500.00, case when 2500.00 <= 0 then 'PAGADA' when '2026-06-04T00:00:00' is not null and '2026-06-04T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'CONTABILIDAD ABRIL 2026', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_ricardo_moreno_arreguin'
    and upper(existing.invoice_folio) = upper('1314')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-togo-5999-2026-05-15', 'fc_import_togo', 'TOGO', 'DICSA', 'CELAYA', '5999', 'MANUAL', '2026-05-15T00:00:00', '2026-05-29T00:00:00', 23550.78, 23550.78, case when 23550.78 <= 0 then 'PAGADA' when '2026-05-29T00:00:00' is not null and '2026-05-29T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, '2 TAMB ACEITE HIDRAULICO', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_togo'
    and upper(existing.invoice_folio) = upper('5999')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-ricardo-moreno-arreguin-1312-2026-05-14', 'fc_import_ricardo_moreno_arreguin', 'RICARDO MORENO ARREGUIN', 'DICSA', 'CELAYA', '1312', 'MANUAL', '2026-05-14T00:00:00', '2026-05-29T00:00:00', 2500.00, 2500.00, case when 2500.00 <= 0 then 'PAGADA' when '2026-05-29T00:00:00' is not null and '2026-05-29T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'EDOS FINANCIEROS', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_ricardo_moreno_arreguin'
    and upper(existing.invoice_folio) = upper('1312')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-cbicentenario-10476-2026-05-13', 'fc_import_cbicentenario', 'CBICENTENARIO', 'DICSA', 'CELAYA', '10476', 'MANUAL', '2026-05-13T00:00:00', '2026-05-21T00:00:00', 11366.00, 11366.00, case when 11366.00 <= 0 then 'PAGADA' when '2026-05-21T00:00:00' is not null and '2026-05-21T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'DEL 01-09 MAYO 2026', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_cbicentenario'
    and upper(existing.invoice_folio) = upper('10476')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-sarollantas-4566-2026-05-08', 'fc_import_sarollantas', 'SAROLLANTAS', 'DICSA', 'CELAYA', '4566', 'MANUAL', '2026-05-08T00:00:00', '2026-07-01T00:00:00', 17000.00, 17000.00, case when 17000.00 <= 0 then 'PAGADA' when '2026-07-01T00:00:00' is not null and '2026-07-01T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, '4 LLANTAS', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_sarollantas'
    and upper(existing.invoice_folio) = upper('4566')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-lub-bajio-3331276236-2026-05-06', 'fc_import_lub_bajio', 'LUB BAJIO', 'DICSA', 'CELAYA', '3331276236', 'MANUAL', '2026-05-06T00:00:00', '2026-05-14T00:00:00', 10963.95, 10963.95, case when 10963.95 <= 0 then 'PAGADA' when '2026-05-14T00:00:00' is not null and '2026-05-14T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'LUBRICANTES 3 TAPA AMARILLA', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_lub_bajio'
    and upper(existing.invoice_folio) = upper('3331276236')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-cbicentenario-10441-2026-05-05', 'fc_import_cbicentenario', 'CBICENTENARIO', 'DICSA', 'CELAYA', '10441', 'MANUAL', '2026-05-05T00:00:00', '2026-05-14T00:00:00', 16957.00, 16957.00, case when 16957.00 <= 0 then 'PAGADA' when '2026-05-14T00:00:00' is not null and '2026-05-14T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'DEL 21-30 ABRIL DE 2026', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_cbicentenario'
    and upper(existing.invoice_folio) = upper('10441')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-ricardo-moreno-arreguin-1301-2026-04-29', 'fc_import_ricardo_moreno_arreguin', 'RICARDO MORENO ARREGUIN', 'DICSA', 'CELAYA', '1301', 'MANUAL', '2026-04-29T00:00:00', '2026-05-07T00:00:00', 18575.00, 18575.00, case when 18575.00 <= 0 then 'PAGADA' when '2026-05-07T00:00:00' is not null and '2026-05-07T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'SERV DE CONTABILIDAD', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_ricardo_moreno_arreguin'
    and upper(existing.invoice_folio) = upper('1301')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-cbicentenario-10403-2026-04-24', 'fc_import_cbicentenario', 'CBICENTENARIO', 'DICSA', 'CELAYA', '10403', 'MANUAL', '2026-04-24T00:00:00', '2026-05-08T00:00:00', 13046.00, 13046.00, case when 13046.00 <= 0 then 'PAGADA' when '2026-05-08T00:00:00' is not null and '2026-05-08T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'DEL 13-20 ABRIL 2026', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_cbicentenario'
    and upper(existing.invoice_folio) = upper('10403')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-lub-bajio-5905-2026-04-22', 'fc_import_lub_bajio', 'LUB BAJIO', 'DICSA', 'CELAYA', '5905', 'MANUAL', '2026-04-22T00:00:00', '2026-05-11T00:00:00', 9535.20, 9535.20, case when 9535.20 <= 0 then 'PAGADA' when '2026-05-11T00:00:00' is not null and '2026-05-11T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'LUBRICANTES', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_lub_bajio'
    and upper(existing.invoice_folio) = upper('5905')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-juan-arellano-rangel-59f33c91528a-2026-04-17', 'fc_import_juan_arellano_rangel', 'JUAN ARELLANO RANGEL', 'DICSA', 'CELAYA', '59F33C91528A', 'MANUAL', '2026-04-17T00:00:00', '2026-04-24T00:00:00', 11600.00, 11600.00, case when 11600.00 <= 0 then 'PAGADA' when '2026-04-24T00:00:00' is not null and '2026-04-24T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'PROGRAMA INTERNO DE PROTECCION CIVIL FOLIO 11723', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_juan_arellano_rangel'
    and upper(existing.invoice_folio) = upper('59F33C91528A')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-sarollantas-4542-2026-04-17', 'fc_import_sarollantas', 'SAROLLANTAS', 'DICSA', 'CELAYA', '4542', 'MANUAL', '2026-04-17T00:00:00', '2026-06-17T00:00:00', 8400.00, 8400.00, case when 8400.00 <= 0 then 'PAGADA' when '2026-06-17T00:00:00' is not null and '2026-06-17T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, '2 LLANTAS', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_sarollantas'
    and upper(existing.invoice_folio) = upper('4542')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-cbicentenario-10371-2026-04-17', 'fc_import_cbicentenario', 'CBICENTENARIO', 'DICSA', 'CELAYA', '10371', 'MANUAL', '2026-04-17T00:00:00', '2026-05-21T00:00:00', 14428.00, 14428.00, case when 14428.00 <= 0 then 'PAGADA' when '2026-05-21T00:00:00' is not null and '2026-05-21T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'DEL 01-10 ABRIL 2026', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_cbicentenario'
    and upper(existing.invoice_folio) = upper('10371')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-qualitas-seguros-27965-2026-04-10', 'fc_import_qualitas_seguros', 'QUALITAS SEGUROS', 'DICSA', 'CELAYA', '27965', 'MANUAL', '2026-04-10T00:00:00', null, 46170.00, 46170.00, case when 46170.00 <= 0 then 'PAGADA' when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'POLIZA G1', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_qualitas_seguros'
    and upper(existing.invoice_folio) = upper('27965')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-lub-bajio-3331275383-2026-04-06', 'fc_import_lub_bajio', 'LUB BAJIO', 'DICSA', 'CELAYA', '3331275383', 'MANUAL', '2026-04-06T00:00:00', '2026-05-06T00:00:00', 13507.04, 13507.04, case when 13507.04 <= 0 then 'PAGADA' when '2026-05-06T00:00:00' is not null and '2026-05-06T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, '3 TAPAS VERDE/ 2 TAPA ROJA', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_lub_bajio'
    and upper(existing.invoice_folio) = upper('3331275383')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-sarollantas-r-4525-2026-04-01', 'fc_import_sarollantas', 'SAROLLANTAS', 'DICSA', 'CELAYA', 'R-4525', 'MANUAL', '2026-04-01T00:00:00', '2026-06-10T00:00:00', 7900.00, 7900.00, case when 7900.00 <= 0 then 'PAGADA' when '2026-06-10T00:00:00' is not null and '2026-06-10T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'COMPRA 2 LLANTAS F2 DANIEL GARCIA', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_sarollantas'
    and upper(existing.invoice_folio) = upper('R-4525')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-sarollantas-r-4521-2026-03-27', 'fc_import_sarollantas', 'SAROLLANTAS', 'DICSA', 'CELAYA', 'R-4521', 'MANUAL', '2026-03-27T00:00:00', '2026-06-03T00:00:00', 8800.00, 8800.00, case when 8800.00 <= 0 then 'PAGADA' when '2026-06-03T00:00:00' is not null and '2026-06-03T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'COMPRA 2 LLANTAS MANUEL PAVANA - PLATAFORMA', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_sarollantas'
    and upper(existing.invoice_folio) = upper('R-4521')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-transportes-tseh-67-2026-03-04', 'fc_import_transportes_tseh', 'TRANSPORTES TSEH', 'DICSA', 'CELAYA', '67', 'MANUAL', '2026-03-04T00:00:00', '2026-04-24T00:00:00', 33600.00, 33600.00, case when 33600.00 <= 0 then 'PAGADA' when '2026-04-24T00:00:00' is not null and '2026-04-24T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, 'FLETE FOLIO 220-221 (SAN PABLO)', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_transportes_tseh'
    and upper(existing.invoice_folio) = upper('67')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-sarollantas-r-4490-2026-02-25', 'fc_import_sarollantas', 'SAROLLANTAS', 'DICSA', 'CELAYA', 'R-4490', 'MANUAL', '2026-02-25T00:00:00', '2026-05-20T00:00:00', 14900.00, 14900.00, case when 14900.00 <= 0 then 'PAGADA' when '2026-05-20T00:00:00' is not null and '2026-05-20T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, '2 LLANTAS ANGEL LOPEZ)', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_sarollantas'
    and upper(existing.invoice_folio) = upper('R-4490')
);

insert into public.finanzas_supplier_invoices (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
select 'fin-invoice-legacy-manual-sarollantas-r-4488-2026-02-23', 'fc_import_sarollantas', 'SAROLLANTAS', 'DICSA', 'CELAYA', 'R-4488', 'MANUAL', '2026-02-23T00:00:00', '2026-05-13T00:00:00', 17600.00, 17600.00, case when 17600.00 <= 0 then 'PAGADA' when '2026-05-13T00:00:00' is not null and '2026-05-13T00:00:00'::timestamptz < '2026-06-11'::date then 'VENCIDA' else 'PENDIENTE' end, '4 LLANTAS PARA T2 MANUEL PAVANA', 'NORMAL', null
where not exists (
  select 1
  from public.finanzas_supplier_invoices existing
  where existing.provider_id = 'fc_import_sarollantas'
    and upper(existing.invoice_folio) = upper('R-4488')
);
