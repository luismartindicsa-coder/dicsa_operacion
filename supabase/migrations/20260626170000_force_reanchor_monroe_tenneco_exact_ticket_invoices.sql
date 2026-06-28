-- Force re-anchor exact TICKETS invoices for MONROE and TENNECO.
-- Replaces wrong/missing ticket links with the exact historical mapping derived from invoice comments and current ticket snapshot.

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000223'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 32693.00) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1835', 'ct_legacy_row_566', 'ct_legacy_row_567', 'ct_legacy_row_170', 'ct_legacy_row_169', 'ct_legacy_row_2043', 'ct_legacy_row_565', 'ct_legacy_row_564', 'ct_legacy_row_1834', 'ct_legacy_row_563', 'ct_legacy_row_2042', 'ct_legacy_row_1833', 'ct_legacy_row_561', 'ct_legacy_row_562', 'ct_legacy_row_167', 'ct_legacy_row_168', 'ct_legacy_row_2041', 'ct_legacy_row_560', 'ct_legacy_row_1832', 'ct_legacy_row_1831', 'ct_legacy_row_31', 'ct_legacy_row_559', 'ct_legacy_row_558', 'ct_legacy_row_2040', 'ct_legacy_row_1830', 'ct_legacy_row_557')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-monroe-1000000223-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000222'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 29030.50) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1841', 'ct_legacy_row_577', 'ct_legacy_row_174', 'ct_legacy_row_173', 'ct_legacy_row_2047', 'ct_legacy_row_1840', 'ct_legacy_row_576', 'ct_legacy_row_575', 'ct_legacy_row_2046', 'ct_legacy_row_1839', 'ct_legacy_row_574', 'ct_legacy_row_573', 'ct_legacy_row_1838', 'ct_legacy_row_572', 'ct_legacy_row_571', 'ct_legacy_row_172', 'ct_legacy_row_171', 'ct_legacy_row_2045', 'ct_legacy_row_1837', 'ct_legacy_row_570', 'ct_legacy_row_569', 'ct_legacy_row_32', 'ct_legacy_row_2044', 'ct_legacy_row_568', 'ct_legacy_row_1836')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-monroe-1000000222-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('10000000221'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 60466.50) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1851', 'ct_legacy_row_589', 'ct_legacy_row_588', 'ct_legacy_row_335', 'ct_legacy_row_1852', 'ct_legacy_row_336', 'ct_legacy_row_177', 'ct_legacy_row_2053', 'ct_legacy_row_178', 'ct_legacy_row_1849', 'ct_legacy_row_587', 'ct_legacy_row_586', 'ct_legacy_row_333', 'ct_legacy_row_334', 'ct_legacy_row_2051', 'ct_legacy_row_2052', 'ct_legacy_row_1847', 'ct_legacy_row_585', 'ct_legacy_row_584', 'ct_legacy_row_1846', 'ct_legacy_row_583', 'ct_legacy_row_582', 'ct_legacy_row_175', 'ct_legacy_row_2050', 'ct_legacy_row_176', 'ct_legacy_row_2049', 'ct_legacy_row_1843', 'ct_legacy_row_33', 'ct_legacy_row_580', 'ct_legacy_row_581', 'ct_legacy_row_2048', 'ct_legacy_row_1842', 'ct_legacy_row_579', 'ct_legacy_row_578')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-monroe-10000000221-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000217'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 33826.00) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_2058', 'ct_legacy_row_1859', 'ct_legacy_row_598', 'ct_legacy_row_597', 'ct_legacy_row_1858', 'ct_legacy_row_596', 'ct_legacy_row_180', 'ct_legacy_row_2057', 'ct_legacy_row_179', 'ct_legacy_row_35', 'ct_legacy_row_1857', 'ct_legacy_row_595', 'ct_legacy_row_337', 'ct_legacy_row_2056', 'ct_legacy_row_1856', 'ct_legacy_row_593', 'ct_legacy_row_594', 'ct_legacy_row_2055', 'ct_legacy_row_1855', 'ct_legacy_row_592', 'ct_legacy_row_1854', 'ct_legacy_row_591', 'ct_legacy_row_34', 'ct_legacy_row_590', 'ct_legacy_row_2054')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-monroe-1000000217-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000185'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 29273.30) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_monroe_missing_row_21', 'ct_monroe_missing_row_20', 'ct_monroe_missing_row_24', 'ct_monroe_missing_row_22', 'ct_monroe_missing_row_23', 'ct_monroe_missing_row_17', 'ct_monroe_missing_row_18', 'ct_monroe_missing_row_16', 'ct_monroe_missing_row_19', 'ct_monroe_missing_row_15', 'ct_monroe_missing_row_14', 'ct_monroe_missing_row_13', 'ct_monroe_missing_row_8', 'ct_monroe_missing_row_11', 'ct_monroe_missing_row_10', 'ct_monroe_missing_row_9', 'ct_monroe_missing_row_7', 'ct_monroe_missing_row_6', 'ct_monroe_missing_row_12', 'ct_monroe_missing_row_4', 'ct_monroe_missing_row_3', 'ct_monroe_missing_row_2', 'ct_monroe_missing_row_5')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-monroe-1000000185-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000204'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 36463.10) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1869', 'ct_legacy_row_2198', 'ct_legacy_row_2199', 'ct_legacy_row_186', 'ct_legacy_row_2065', 'ct_legacy_row_187', 'ct_legacy_row_2204', 'ct_legacy_row_1868', 'ct_legacy_row_2194', 'ct_legacy_row_2192', 'ct_legacy_row_2193', 'ct_legacy_row_2186', 'ct_legacy_row_615', 'ct_legacy_row_2178', 'ct_legacy_row_2177', 'ct_legacy_row_2169', 'ct_legacy_row_2168', 'ct_legacy_row_185', 'ct_legacy_row_2167', 'ct_legacy_row_2176', 'ct_legacy_row_2166', 'ct_legacy_row_614', 'ct_legacy_row_2157', 'ct_legacy_row_2156', 'ct_legacy_row_613', 'ct_legacy_row_2153', 'ct_legacy_row_2154')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-monroe-1000000204-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000207'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 26798.90) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1867', 'ct_legacy_row_612', 'ct_legacy_row_2063', 'ct_legacy_row_2064', 'ct_legacy_row_184', 'ct_legacy_row_183', 'ct_legacy_row_611', 'ct_legacy_row_1866', 'ct_legacy_row_610', 'ct_legacy_row_2062', 'ct_legacy_row_1865', 'ct_legacy_row_608', 'ct_legacy_row_609', 'ct_legacy_row_1864', 'ct_legacy_row_607', 'ct_legacy_row_606', 'ct_legacy_row_181', 'ct_legacy_row_182', 'ct_legacy_row_2061', 'ct_legacy_row_604', 'ct_legacy_row_605', 'ct_legacy_row_1863', 'ct_legacy_row_37', 'ct_legacy_row_2060')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-monroe-1000000207-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000211'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 18589.90) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_2118', 'ct_legacy_row_2122', 'ct_legacy_row_2121', 'ct_legacy_row_2120', 'ct_legacy_row_2119', 'ct_legacy_row_2123', 'ct_legacy_row_2116', 'ct_legacy_row_2114', 'ct_legacy_row_2115', 'ct_legacy_row_2117', 'ct_legacy_row_2112', 'ct_legacy_row_2113', 'ct_legacy_row_1862', 'ct_legacy_row_2109', 'ct_legacy_row_2110', 'ct_legacy_row_2107', 'ct_legacy_row_2108', 'ct_legacy_row_2111')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-monroe-1000000211-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000206'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 14783.10) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_2104', 'ct_legacy_row_2105', 'ct_legacy_row_2106', 'ct_legacy_row_2059', 'ct_legacy_row_2099', 'ct_legacy_row_2102', 'ct_legacy_row_2101', 'ct_legacy_row_2100', 'ct_legacy_row_2103', 'ct_legacy_row_2097', 'ct_legacy_row_2098', 'ct_legacy_row_36', 'ct_legacy_row_2095', 'ct_legacy_row_2094', 'ct_legacy_row_2096')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-monroe-1000000206-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000198'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 7987.00) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_603', 'ct_legacy_row_1861', 'ct_legacy_row_602', 'ct_legacy_row_601', 'ct_legacy_row_1860', 'ct_legacy_row_600', 'ct_legacy_row_599')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-monroe-1000000198-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000202'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 31370.80) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_203', 'ct_legacy_row_2086', 'ct_legacy_row_202', 'ct_legacy_row_1912', 'ct_legacy_row_1913', 'ct_legacy_row_654', 'ct_legacy_row_655', 'ct_legacy_row_2085', 'ct_legacy_row_1911', 'ct_legacy_row_653', 'ct_legacy_row_652', 'ct_legacy_row_650', 'ct_legacy_row_651', 'ct_legacy_row_1910', 'ct_legacy_row_201', 'ct_legacy_row_200', 'ct_legacy_row_2084', 'ct_legacy_row_1909', 'ct_legacy_row_649', 'ct_legacy_row_648', 'ct_legacy_row_2083', 'ct_legacy_row_1908', 'ct_legacy_row_39', 'ct_legacy_row_647', 'ct_legacy_row_646')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-monroe-1000000202-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000200'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 33041.00) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_2376', 'ct_legacy_row_2379', 'ct_legacy_row_199', 'ct_legacy_row_1906', 'ct_legacy_row_1907', 'ct_legacy_row_2378', 'ct_legacy_row_2377', 'ct_legacy_row_645', 'ct_legacy_row_2082', 'ct_legacy_row_2375', 'ct_legacy_row_2373', 'ct_legacy_row_1905', 'ct_legacy_row_2374', 'ct_legacy_row_2372', 'ct_legacy_row_2371', 'ct_legacy_row_2370', 'ct_legacy_row_2366', 'ct_legacy_row_2365', 'ct_legacy_row_2369', 'ct_legacy_row_2364', 'ct_legacy_row_2367', 'ct_legacy_row_2368', 'ct_legacy_row_2363', 'ct_legacy_row_1904', 'ct_legacy_row_2361', 'ct_legacy_row_2362', 'ct_legacy_row_2360')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-monroe-1000000200-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000210'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 23606.40) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_2357', 'ct_legacy_row_2081', 'ct_legacy_row_2356', 'ct_legacy_row_1903', 'ct_legacy_row_2359', 'ct_legacy_row_2358', 'ct_legacy_row_644', 'ct_legacy_row_2355', 'ct_legacy_row_2354', 'ct_legacy_row_2351', 'ct_legacy_row_2353', 'ct_legacy_row_2352', 'ct_legacy_row_2348', 'ct_legacy_row_2079', 'ct_legacy_row_2349', 'ct_legacy_row_2350', 'ct_legacy_row_1901', 'ct_legacy_row_2080', 'ct_legacy_row_2346', 'ct_legacy_row_2078', 'ct_legacy_row_1900', 'ct_legacy_row_2347', 'ct_legacy_row_643')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-monroe-1000000210-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000208'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 34633.90) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1895', 'ct_legacy_row_634', 'ct_legacy_row_2292', 'ct_legacy_row_197', 'ct_legacy_row_2291', 'ct_legacy_row_2293', 'ct_legacy_row_2290', 'ct_legacy_row_2286', 'ct_legacy_row_2288', 'ct_legacy_row_2287', 'ct_legacy_row_2289', 'ct_legacy_row_2282', 'ct_legacy_row_2283', 'ct_legacy_row_2285', 'ct_legacy_row_2284', 'ct_legacy_row_1894', 'ct_legacy_row_2279', 'ct_legacy_row_2280', 'ct_legacy_row_2277', 'ct_legacy_row_2281', 'ct_legacy_row_2278', 'ct_legacy_row_2276', 'ct_legacy_row_2271', 'ct_legacy_row_2273', 'ct_legacy_row_2274', 'ct_legacy_row_2272', 'ct_legacy_row_2275', 'ct_legacy_row_1893', 'ct_legacy_row_2270')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-monroe-1000000208-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000197'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 49830.30) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_2342', 'ct_legacy_row_2341', 'ct_legacy_row_2077', 'ct_legacy_row_2340', 'ct_legacy_row_2339', 'ct_legacy_row_2345', 'ct_legacy_row_2344', 'ct_legacy_row_2343', 'ct_legacy_row_2335', 'ct_legacy_row_2336', 'ct_legacy_row_2337', 'ct_legacy_row_2338', 'ct_legacy_row_1899', 'ct_legacy_row_641', 'ct_legacy_row_642', 'ct_legacy_row_2329', 'ct_legacy_row_2333', 'ct_legacy_row_2332', 'ct_legacy_row_2331', 'ct_legacy_row_2330', 'ct_legacy_row_2334', 'ct_legacy_row_2325', 'ct_legacy_row_2327', 'ct_legacy_row_2328', 'ct_legacy_row_2326', 'ct_legacy_row_2076', 'ct_legacy_row_2319', 'ct_legacy_row_2318', 'ct_legacy_row_2322', 'ct_legacy_row_2323', 'ct_legacy_row_640', 'ct_legacy_row_2321', 'ct_legacy_row_2320', 'ct_legacy_row_2324', 'ct_legacy_row_1898', 'ct_legacy_row_2315', 'ct_legacy_row_2316', 'ct_legacy_row_2317')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-monroe-1000000197-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004567'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 60496.00) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1419', 'ct_legacy_row_1418', 'ct_legacy_row_1417', 'ct_legacy_row_1416', 'ct_legacy_row_1415', 'ct_legacy_row_1414', 'ct_legacy_row_1413')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004567-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004566'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 111507.20) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1411', 'ct_legacy_row_1412', 'ct_legacy_row_1409', 'ct_legacy_row_1410', 'ct_legacy_row_1408', 'ct_legacy_row_1406', 'ct_legacy_row_1407', 'ct_legacy_row_1405')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004566-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004565'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 71592.00) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1402', 'ct_legacy_row_1403', 'ct_legacy_row_1404', 'ct_legacy_row_1401', 'ct_legacy_row_1399', 'ct_legacy_row_1397', 'ct_legacy_row_1398', 'ct_legacy_row_1396')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004565-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004564'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 73902.40) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1395', 'ct_legacy_row_1394', 'ct_legacy_row_1393', 'ct_legacy_row_1392', 'ct_legacy_row_1391', 'ct_legacy_row_1390', 'ct_legacy_row_1389')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004564-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004534'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 36019.50) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1425', 'ct_legacy_row_1423', 'ct_legacy_row_1424', 'ct_legacy_row_1422')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004534-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004533'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 11003.50) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1421', 'ct_legacy_row_1420')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004533-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004535'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 119445.50) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1431', 'ct_legacy_row_1432', 'ct_legacy_row_1430', 'ct_legacy_row_1429', 'ct_legacy_row_1427', 'ct_legacy_row_1428', 'ct_legacy_row_1426')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004535-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004536'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 87172.50) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1437', 'ct_legacy_row_1438', 'ct_legacy_row_1436', 'ct_legacy_row_1435', 'ct_legacy_row_1434', 'ct_legacy_row_1433')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004536-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004537'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 101834.00) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1446', 'ct_legacy_row_1444', 'ct_legacy_row_1445', 'ct_legacy_row_1443', 'ct_legacy_row_1442', 'ct_legacy_row_1440', 'ct_legacy_row_1441', 'ct_legacy_row_1439')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004537-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004538'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 136574.40) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1457', 'ct_legacy_row_1455', 'ct_legacy_row_1456', 'ct_legacy_row_1454', 'ct_legacy_row_1453', 'ct_legacy_row_1450', 'ct_legacy_row_1451', 'ct_legacy_row_1448', 'ct_legacy_row_1449', 'ct_legacy_row_1447')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004538-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004539'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 68997.60) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1461', 'ct_legacy_row_1462', 'ct_legacy_row_1460', 'ct_legacy_row_1459', 'ct_legacy_row_1458')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004539-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004540'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 74621.60) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1469', 'ct_legacy_row_1470', 'ct_legacy_row_1468', 'ct_legacy_row_1466', 'ct_legacy_row_1467', 'ct_legacy_row_1464', 'ct_legacy_row_1465', 'ct_legacy_row_1463')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004540-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004541'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 97650.40) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1477', 'ct_legacy_row_1476', 'ct_legacy_row_1475', 'ct_legacy_row_1474', 'ct_legacy_row_1473', 'ct_legacy_row_1472', 'ct_legacy_row_1471')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004541-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004542'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 56580.00) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1482', 'ct_legacy_row_1483', 'ct_legacy_row_1481', 'ct_legacy_row_1480', 'ct_legacy_row_1479', 'ct_legacy_row_1478')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004542-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004543'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 86610.00) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1489', 'ct_legacy_row_1490', 'ct_legacy_row_1488', 'ct_legacy_row_1487', 'ct_legacy_row_1485', 'ct_legacy_row_1486', 'ct_legacy_row_1484')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004543-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004544'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 95820.00) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1498', 'ct_legacy_row_1499', 'ct_legacy_row_1497', 'ct_legacy_row_1496', 'ct_legacy_row_1495', 'ct_legacy_row_1493', 'ct_legacy_row_1494', 'ct_legacy_row_1492', 'ct_legacy_row_1491')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004544-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004545'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 102510.00) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1505', 'ct_legacy_row_1506', 'ct_legacy_row_1504', 'ct_legacy_row_1503', 'ct_legacy_row_1501', 'ct_legacy_row_1502', 'ct_legacy_row_1500')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004545-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004546'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 79080.00) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1512', 'ct_legacy_row_1511', 'ct_legacy_row_1510', 'ct_legacy_row_1508', 'ct_legacy_row_1509', 'ct_legacy_row_1507')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004546-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004547'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 128290.20) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1522', 'ct_legacy_row_1521', 'ct_legacy_row_1520', 'ct_legacy_row_1519', 'ct_legacy_row_1518', 'ct_legacy_row_1517', 'ct_legacy_row_1516', 'ct_legacy_row_1515', 'ct_legacy_row_1514', 'ct_legacy_row_1513')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004547-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004548'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 83961.30) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1530', 'ct_legacy_row_1529', 'ct_legacy_row_1528', 'ct_legacy_row_1525', 'ct_legacy_row_1527', 'ct_legacy_row_1524', 'ct_legacy_row_1526', 'ct_legacy_row_1523')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004548-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004549'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 85324.80) <= 0.01
  order by inv.created_at nulls first, inv.id
  limit 1
),
expected_tickets as (
  select t.id, t.amount
  from public.compras_tickets t
  where t.id in ('ct_legacy_row_1538', 'ct_legacy_row_1537', 'ct_legacy_row_1536', 'ct_legacy_row_1535', 'ct_legacy_row_1534', 'ct_legacy_row_1532', 'ct_legacy_row_1533', 'ct_legacy_row_1531')
),
purged_target_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.invoice_id in (select id from target_invoice)
    and fit.ticket_id not in (select id from expected_tickets)
  returning fit.ticket_id
),
released_wrong_links as (
  delete from public.finanzas_supplier_invoice_tickets fit
  where fit.ticket_id in (select id from expected_tickets)
    and fit.invoice_id not in (select id from target_invoice)
  returning fit.ticket_id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-force-fin-inv-ticket-tenneco-560004549-' || et.id,
    ti.id,
    et.id,
    et.amount
  from target_invoice ti
  join expected_tickets et on true
  on conflict (ticket_id) do update set
    invoice_id = excluded.invoice_id,
    applied_amount = excluded.applied_amount
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select id from expected_tickets);
