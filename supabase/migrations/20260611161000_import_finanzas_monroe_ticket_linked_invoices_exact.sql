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
    and t.ticket_date::date between '2026-04-01'::date and '2026-04-04'::date
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
    'fin-invoice-legacy-ticketed-2',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000230',
    'TICKETS',
    '2026-05-25T00:00:00',
    null,
    17979.20,
    17979.20,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 01-04 ABRIL 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 17979.20) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000230'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-2' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-2',
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
    and t.ticket_date::date between '2026-04-06'::date and '2026-04-11'::date
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
    'fin-invoice-legacy-ticketed-3',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000231',
    'TICKETS',
    '2026-05-25T00:00:00',
    null,
    28342.30,
    28342.30,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    '06-11 ABRIL 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 28342.30) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000231'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-3' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-3',
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
    and t.ticket_date::date between '2026-04-13'::date and '2026-04-18'::date
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
    'fin-invoice-legacy-ticketed-4',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000232',
    'TICKETS',
    '2026-05-25T00:00:00',
    null,
    31937.10,
    31937.10,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 13-18 ABRIL 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 31937.10) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000232'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-4' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-4',
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
    and t.ticket_date::date between '2026-04-20'::date and '2026-04-25'::date
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
    'fin-invoice-legacy-ticketed-5',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000229',
    'TICKETS',
    '2026-05-25T00:00:00',
    null,
    35629.30,
    35629.30,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 20-25 ABRIL 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 35629.30) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000229'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-5' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-5',
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
    and t.ticket_date::date between '2026-04-27'::date and '2026-04-30'::date
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
    'fin-invoice-legacy-ticketed-6',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000233',
    'TICKETS',
    '2026-05-25T00:00:00',
    null,
    30998.00,
    30998.00,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 27-30 ABRIL 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 30998.00) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000233'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-6' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-6',
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
    and t.ticket_date::date between '2026-05-04'::date and '2026-05-08'::date
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
    'fin-invoice-legacy-ticketed-7',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000234',
    'TICKETS',
    '2026-05-25T00:00:00',
    null,
    29723.50,
    29723.50,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 04-08 MAYO 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 29723.50) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000234'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-7' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-7',
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
    and t.ticket_date::date between '2026-05-11'::date and '2026-05-15'::date
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
    'fin-invoice-legacy-ticketed-8',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000228',
    'TICKETS',
    '2026-05-25T00:00:00',
    null,
    32996.40,
    32996.40,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 11-15 MAYO 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 32996.40) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000228'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-8' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-8',
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
    and t.ticket_date::date between '2026-03-23'::date and '2026-03-31'::date
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
    'fin-invoice-legacy-ticketed-9',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000227',
    'TICKETS',
    '2026-04-29T00:00:00',
    null,
    50087.30,
    50087.30,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 23-31 MZO 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 50087.30) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000227'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-9' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-9',
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
    and t.ticket_date::date between '2026-03-09'::date and '2026-03-14'::date
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
    'fin-invoice-legacy-ticketed-10',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000226',
    'TICKETS',
    '2026-04-29T00:00:00',
    null,
    31746.90,
    31746.90,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 09-14 MZO 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 31746.90) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000226'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-10' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-10',
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
    and t.ticket_date::date between '2026-02-23'::date and '2026-02-28'::date
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
    'fin-invoice-legacy-ticketed-11',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000225',
    'TICKETS',
    '2026-04-29T00:00:00',
    null,
    31260.20,
    31260.20,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 23-28 FEB 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 31260.20) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000225'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-11' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-11',
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
    and t.ticket_date::date between '2026-01-26'::date and '2026-01-31'::date
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
    'fin-invoice-legacy-ticketed-13',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000223',
    'TICKETS',
    '2026-04-29T00:00:00',
    null,
    32693.00,
    32693.00,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 26-31 ENE 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 32693.00) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000223'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-13' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-13',
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
    and t.ticket_date::date between '2026-01-19'::date and '2026-01-24'::date
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
    'fin-invoice-legacy-ticketed-14',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000222',
    'TICKETS',
    '2026-04-29T00:00:00',
    null,
    29030.50,
    29030.50,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 19-24 ENERO 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 29030.50) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000222'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-14' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-14',
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
    and t.ticket_date::date between '2026-01-12'::date and '2026-01-17'::date
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
    'fin-invoice-legacy-ticketed-15',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '10000000221',
    'TICKETS',
    '2026-04-29T00:00:00',
    null,
    60466.50,
    60466.50,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 12-17 ENERO 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 60466.50) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('10000000221'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-15' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-15',
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
    and t.ticket_date::date between '2026-03-16'::date and '2026-03-21'::date
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
    'fin-invoice-legacy-ticketed-17',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000219',
    'TICKETS',
    '2026-04-29T00:00:00',
    null,
    24468.70,
    24468.70,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 16-21 MARZO 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 24468.70) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000219'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-17' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-17',
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
    and t.ticket_date::date between '2026-03-02'::date and '2026-03-07'::date
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
    'fin-invoice-legacy-ticketed-18',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000218',
    'TICKETS',
    '2026-04-29T00:00:00',
    null,
    37272.70,
    37272.70,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 02-07 MZO 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 37272.70) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000218'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-18' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-18',
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
    'fin-invoice-legacy-ticketed-19',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000217',
    'TICKETS',
    '2026-04-29T00:00:00',
    null,
    33826.00,
    33826.00,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 02-09-2026 ENE 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 33826.00) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000217'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-19' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-19',
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
    and t.ticket_date::date between '2026-02-16'::date and '2026-02-21'::date
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
    'fin-invoice-legacy-ticketed-20',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000216',
    'TICKETS',
    '2026-04-29T00:00:00',
    null,
    33974.20,
    33974.20,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 16-21 FEB 2026',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 33974.20) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000216'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-20' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-20',
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
    and t.ticket_date::date between '2025-12-08'::date and '2025-12-12'::date
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
    'fin-invoice-legacy-ticketed-25',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000207',
    'TICKETS',
    '2026-03-03T00:00:00',
    null,
    26798.90,
    26798.90,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 08-12 DICIEMBRE 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 26798.90) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000207'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-25' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-25',
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
    and t.ticket_date::date between '2025-12-29'::date and '2025-12-31'::date
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
    'fin-invoice-legacy-ticketed-28',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000198',
    'TICKETS',
    '2026-03-03T00:00:00',
    null,
    7987.00,
    7987.00,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 29-31 DICIEMBRE 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 7987.00) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000198'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-28' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-28',
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
    and t.ticket_date::date between '2025-09-01'::date and '2025-09-05'::date
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
    'fin-invoice-legacy-ticketed-29',
    'compras_cp_import_monroe',
    'MONROE',
    'DICSA',
    'CELAYA',
    '1000000202',
    'TICKETS',
    '2026-03-03T00:00:00',
    null,
    31370.80,
    31370.80,
    case
      when null is not null and null::timestamptz < '2026-06-11'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    'REPORTE 01-05 SEPTIEMBRE 2025',
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - 31370.80) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = 'compras_cp_import_monroe'
        and upper(trim(existing.invoice_folio)) = upper(trim('1000000202'))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || 'fin-invoice-legacy-ticketed-29' || '-' || mt.id,
    'fin-invoice-legacy-ticketed-29',
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
