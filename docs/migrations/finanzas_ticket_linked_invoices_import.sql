-- Generated from legacy ticket-linked supplier invoices

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2026-01-02'::date and '2026-01-09'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-2',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004567',
    'TICKETS',
    '2026-05-25T00:00:00',
    null,
    60496.00,
    60496.00,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 02-09 ENERO 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 60496.00) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004567'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-2' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-2',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2026-01-12'::date and '2026-01-16'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-3',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004566',
    'TICKETS',
    '2026-05-25T00:00:00',
    null,
    111507.20,
    111507.20,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 12-16 ENERO 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 111507.20) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004566'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-3' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-3',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2026-01-19'::date and '2026-01-23'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-4',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004565',
    'TICKETS',
    '2026-05-25T00:00:00',
    null,
    71592.00,
    71592.00,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 19-23 ENERO 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 71592.00) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004565'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-4' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-4',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2026-01-26'::date and '2026-01-30'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-5',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004564',
    'TICKETS',
    '2026-05-25T00:00:00',
    null,
    73902.40,
    73902.40,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 26-30 ENER 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 73902.40) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004564'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-5' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-5',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-12-22'::date and '2025-12-26'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-14',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004534',
    'TICKETS',
    '2026-05-04T00:00:00',
    null,
    36019.50,
    36019.50,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 22-26 DIC 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 36019.50) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004534'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-14' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-14',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-12-29'::date and '2025-12-30'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-15',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004533',
    'TICKETS',
    '2026-05-04T00:00:00',
    null,
    11003.50,
    11003.50,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 29-30 DIC 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 11003.50) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004533'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-15' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-15',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-12-15'::date and '2025-12-19'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-16',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004535',
    'TICKETS',
    '2026-05-04T00:00:00',
    null,
    119445.50,
    119445.50,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 15-19 DIC 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 119445.50) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004535'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-16' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-16',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-12-08'::date and '2025-12-11'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-17',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004536',
    'TICKETS',
    '2026-05-04T00:00:00',
    null,
    87172.50,
    87172.50,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 08-11-DIC 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 87172.50) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004536'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-17' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-17',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-12-01'::date and '2025-12-05'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-18',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004537',
    'TICKETS',
    '2026-05-04T00:00:00',
    null,
    101834.00,
    101834.00,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE01-05-DIC 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 101834.00) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004537'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-18' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-18',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-11-24'::date and '2025-11-28'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-19',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004538',
    'TICKETS',
    '2026-05-04T00:00:00',
    null,
    136574.40,
    136574.40,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 24-28 NOV 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 136574.40) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004538'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-19' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-19',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-11-18'::date and '2025-11-21'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-20',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004539',
    'TICKETS',
    '2026-05-04T00:00:00',
    null,
    68997.60,
    68997.60,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 18-21 NOV 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 68997.60) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004539'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-20' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-20',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-11-10'::date and '2025-11-14'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-21',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004540',
    'TICKETS',
    '2026-05-04T00:00:00',
    null,
    74621.60,
    74621.60,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 10-14 NOV 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 74621.60) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004540'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-21' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-21',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-11-03'::date and '2025-11-07'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-22',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004541',
    'TICKETS',
    '2026-05-04T00:00:00',
    null,
    97650.40,
    97650.40,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 03-07 NOV 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 97650.40) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004541'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-22' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-22',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-10-27'::date and '2025-10-31'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-23',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004542',
    'TICKETS',
    '2026-05-04T00:00:00',
    null,
    56580.00,
    56580.00,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 27-31 OCT 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 56580.00) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004542'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-23' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-23',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-10-20'::date and '2025-10-24'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-24',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004543',
    'TICKETS',
    '2026-05-04T00:00:00',
    null,
    86610.00,
    86610.00,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 20-24 OCT 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 86610.00) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004543'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-24' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-24',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-10-13'::date and '2025-10-17'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-25',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004544',
    'TICKETS',
    '2026-05-04T00:00:00',
    null,
    95820.00,
    95820.00,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE13-17 OCT 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 95820.00) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004544'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-25' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-25',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-10-06'::date and '2025-10-10'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-26',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004545',
    'TICKETS',
    '2026-05-04T00:00:00',
    null,
    102510.00,
    102510.00,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 06-10 OCT 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 102510.00) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004545'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-26' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-26',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-10-01'::date and '2025-10-04'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-27',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004546',
    'TICKETS',
    '2026-05-04T00:00:00',
    null,
    79080.00,
    79080.00,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 01-04 OCT 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 79080.00) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004546'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-27' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-27',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-09-22'::date and '2025-09-30'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-28',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004547',
    'TICKETS',
    '2026-05-04T00:00:00',
    null,
    128290.20,
    128290.20,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE22-30 SEPT 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 128290.20) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004547'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-28' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-28',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-09-15'::date and '2025-09-19'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-29',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004548',
    'TICKETS',
    '2026-05-04T00:00:00',
    null,
    83961.30,
    83961.30,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE15-19 SEPT 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 83961.30) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004548'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-29' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-29',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_tenneco',
    'TENNECO',
    'COMPRAS',
    'TENNECO',
    true,
    'SINCRONIZADO DESDE COMPRAS MAYOREO'
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-09-08'::date and '2025-09-12'::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    'fin-invoice-legacy-ticketed-tenneco-30',
    'compras_cp_import_tenneco',
    'TENNECO',
    'DICSA',
    'CELAYA',
    '560004549',
    'TICKETS',
    '2026-05-04T00:00:00',
    null,
    85324.80,
    85324.80,
    case
      when null is not null and null::timestamptz < '2026-06-15'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 08-12 SEPT 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 85324.80) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_tenneco'
        and upper(trim(existing.invoice_folio)) = upper(trim('560004549'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-tenneco-30' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-tenneco-30',
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);
