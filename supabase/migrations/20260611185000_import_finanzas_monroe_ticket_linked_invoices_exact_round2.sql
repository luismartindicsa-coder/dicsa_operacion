-- Generated from legacy ticket-linked supplier invoices

with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    'compras_cp_import_monroe',
    'MONROE',
    'COMPRAS',
    'MONROE',
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
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2025-12-01'::date and '2025-12-06'::date
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
    'fin-invoice-legacy-ticketed-24',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000204',
    'TICKETS',
    '2026-03-03T00:00:00',
    null,
    36463.10,
    36463.10,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 01-06 DICIEMBRE 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 36463.10) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000204'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-24' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-24',
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
    'compras_cp_import_monroe',
    'MONROE',
    'COMPRAS',
    'MONROE',
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
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
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
    'fin-invoice-legacy-ticketed-26',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000211',
    'TICKETS',
    '2026-03-03T00:00:00',
    null,
    18589.90,
    18589.90,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 15-19 DICIEMBRE 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 18589.90) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000211'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-26' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-26',
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
    'compras_cp_import_monroe',
    'MONROE',
    'COMPRAS',
    'MONROE',
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
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
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
    'fin-invoice-legacy-ticketed-27',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000206',
    'TICKETS',
    '2026-03-03T00:00:00',
    null,
    14783.10,
    14783.10,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 22-26 DICIEMBRE 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 14783.10) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000206'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-27' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-27',
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
    'compras_cp_import_monroe',
    'MONROE',
    'COMPRAS',
    'MONROE',
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
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
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
    'fin-invoice-legacy-ticketed-30',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000200',
    'TICKETS',
    '2026-03-03T00:00:00',
    null,
    33041.00,
    33041.00,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 08-12 SEPTIEMBRE 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 33041.00) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000200'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-30' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-30',
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
    'compras_cp_import_monroe',
    'MONROE',
    'COMPRAS',
    'MONROE',
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
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
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
    'fin-invoice-legacy-ticketed-32',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000210',
    'TICKETS',
    '2026-03-03T00:00:00',
    null,
    23606.40,
    23606.40,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 15-19 SEPTIEMBRE 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 23606.40) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000210'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-32' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-32',
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
    'compras_cp_import_monroe',
    'MONROE',
    'COMPRAS',
    'MONROE',
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
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2025-10-20'::date and '2025-10-25'::date
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
    'fin-invoice-legacy-ticketed-34',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000208',
    'TICKETS',
    '2026-03-03T00:00:00',
    null,
    34633.90,
    34633.90,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 20-25 OCTUBRE 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 34633.90) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000208'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-34' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-34',
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
    'compras_cp_import_monroe',
    'MONROE',
    'COMPRAS',
    'MONROE',
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
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
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
    'fin-invoice-legacy-ticketed-36',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000197',
    'TICKETS',
    '2026-03-03T00:00:00',
    null,
    49830.30,
    49830.30,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 22-30 SEPTIEMBRE 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 49830.30) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000197'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-36' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-36',
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
