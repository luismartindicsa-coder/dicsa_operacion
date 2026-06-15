with real_invoiced_tickets as (
  select distinct link.ticket_id
  from public.finanzas_supplier_invoice_tickets link
  join public.finanzas_supplier_invoices invoice
    on invoice.id = link.invoice_id
)
update public.compras_tickets ticket
set factura_status = 'PENDIENTE_DE_FACTURAR'
where ticket.factura_status = 'FACTURADO'
  and not exists (
    select 1
    from real_invoiced_tickets real_ticket
    where real_ticket.ticket_id = ticket.id
  );
