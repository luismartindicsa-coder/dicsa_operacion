-- Repairs orphan TICKETS invoices that already existed before exact ticket-link migrations.
-- Re-anchors MONROE and TENNECO invoices to their exact ticket ranges without touching MANUAL invoices.

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000230'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 17979.20) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2026-04-01'::date and '2026-04-04'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000230-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 17979.20) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000231'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 28342.30) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2026-04-06'::date and '2026-04-11'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000231-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 28342.30) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000232'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 31937.10) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2026-04-13'::date and '2026-04-18'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000232-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 31937.10) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000229'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 35629.30) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2026-04-20'::date and '2026-04-25'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000229-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 35629.30) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000233'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 30998.00) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2026-04-27'::date and '2026-04-30'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000233-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 30998.00) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000234'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 29723.50) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2026-05-04'::date and '2026-05-08'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000234-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 29723.50) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000228'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 32996.40) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2026-05-11'::date and '2026-05-15'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000228-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 32996.40) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000227'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 50087.30) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2026-03-23'::date and '2026-03-31'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000227-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 50087.30) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000226'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 31746.90) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2026-03-09'::date and '2026-03-14'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000226-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 31746.90) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000225'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 31260.20) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2026-02-23'::date and '2026-02-28'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000225-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 31260.20) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000223'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 32693.00) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2026-01-26'::date and '2026-01-31'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000223-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 32693.00) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000222'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 29030.50) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2026-01-19'::date and '2026-01-24'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000222-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 29030.50) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('10000000221'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 60466.50) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2026-01-12'::date and '2026-01-17'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-10000000221-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 60466.50) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000219'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 24468.70) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2026-03-16'::date and '2026-03-21'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000219-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 24468.70) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000218'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 37272.70) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2026-03-02'::date and '2026-03-07'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000218-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 37272.70) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000217'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 33826.00) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2026-01-02'::date and '2026-01-09'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000217-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 33826.00) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000216'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 33974.20) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2026-02-16'::date and '2026-02-21'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000216-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 33974.20) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000207'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 26798.90) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2025-12-08'::date and '2025-12-12'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000207-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 26798.90) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000198'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 7987.00) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2025-12-29'::date and '2025-12-31'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000198-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 7987.00) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000202'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 31370.80) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2025-09-01'::date and '2025-09-05'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000202-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 31370.80) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000204'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 36463.10) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2025-12-01'::date and '2025-12-06'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000204-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 36463.10) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000211'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 18589.90) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2025-12-15'::date and '2025-12-19'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000211-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 18589.90) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000206'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 14783.10) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2025-12-22'::date and '2025-12-26'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000206-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 14783.10) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000200'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 33041.00) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2025-09-08'::date and '2025-09-12'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000200-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 33041.00) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000210'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 23606.40) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2025-09-15'::date and '2025-09-19'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000210-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 23606.40) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000208'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 34633.90) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2025-10-20'::date and '2025-10-25'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000208-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 34633.90) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('MONROE'))
    and upper(trim(inv.invoice_folio)) = upper(trim('1000000197'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 49830.30) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('MONROE'))
    and t.ticket_date::date between '2025-09-22'::date and '2025-09-30'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-monroe-1000000197-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 49830.30) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004567'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 60496.00) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2026-01-02'::date and '2026-01-09'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004567-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 60496.00) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004566'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 111507.20) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2026-01-12'::date and '2026-01-16'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004566-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 111507.20) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004565'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 71592.00) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2026-01-19'::date and '2026-01-23'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004565-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 71592.00) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004564'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 73902.40) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2026-01-26'::date and '2026-01-30'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004564-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 73902.40) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004534'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 36019.50) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-12-22'::date and '2025-12-26'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004534-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 36019.50) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004533'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 11003.50) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-12-29'::date and '2025-12-30'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004533-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 11003.50) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004535'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 119445.50) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-12-15'::date and '2025-12-19'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004535-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 119445.50) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004536'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 87172.50) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-12-08'::date and '2025-12-11'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004536-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 87172.50) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004537'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 101834.00) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-12-01'::date and '2025-12-05'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004537-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 101834.00) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004538'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 136574.40) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-11-24'::date and '2025-11-28'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004538-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 136574.40) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004539'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 68997.60) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-11-18'::date and '2025-11-21'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004539-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 68997.60) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004540'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 74621.60) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-11-10'::date and '2025-11-14'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004540-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 74621.60) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004541'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 97650.40) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-11-03'::date and '2025-11-07'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004541-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 97650.40) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004542'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 56580.00) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-10-27'::date and '2025-10-31'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004542-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 56580.00) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004543'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 86610.00) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-10-20'::date and '2025-10-24'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004543-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 86610.00) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004544'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 95820.00) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-10-13'::date and '2025-10-17'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004544-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 95820.00) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004545'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 102510.00) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-10-06'::date and '2025-10-10'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004545-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 102510.00) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004546'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 79080.00) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-10-01'::date and '2025-10-04'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004546-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 79080.00) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004547'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 128290.20) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-09-22'::date and '2025-09-30'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004547-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 128290.20) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004548'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 83961.30) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-09-15'::date and '2025-09-19'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004548-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 83961.30) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);

with target_invoice as (
  select inv.id
  from public.finanzas_supplier_invoices inv
  left join public.finanzas_supplier_invoice_tickets existing_link
    on existing_link.invoice_id = inv.id
  where upper(trim(inv.provider_name_snapshot)) = upper(trim('TENNECO'))
    and upper(trim(inv.invoice_folio)) = upper(trim('560004549'))
    and upper(trim(inv.origin_type)) = 'TICKETS'
    and abs(coalesce(inv.total_amount, 0) - 85324.80) <= 0.01
  group by inv.id, inv.created_at
  having count(existing_link.id) = 0
  order by min(inv.created_at) nulls first, inv.id
  limit 1
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim('TENNECO'))
    and t.ticket_date::date between '2025-09-08'::date and '2025-09-12'::date
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'repair-fin-inv-ticket-tenneco-560004549-' || mt.id,
    ti.id,
    mt.id,
    mt.amount
  from target_invoice ti
  cross join ticket_totals tt
  join matched_tickets mt on true
  where tt.ticket_count > 0
    and abs(tt.total_amount - 85324.80) <= 0.01
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);
