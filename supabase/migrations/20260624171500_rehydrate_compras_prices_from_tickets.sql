begin;

with latest_ticket_price as (
  select distinct on (ticket.provider_id, ticket.material_id)
    ticket.provider_id as company_id,
    ticket.material_id,
    ticket.price as final_price,
    ticket.ticket_date,
    ticket.updated_at,
    ticket.created_at
  from public.compras_tickets ticket
  join public.compras_counterparties company
    on company.id = ticket.provider_id
  join public.compras_material_catalog material
    on material.id = ticket.material_id
  where ticket.provider_id is not null
    and ticket.material_id is not null
    and ticket.price >= 0
  order by
    ticket.provider_id,
    ticket.material_id,
    ticket.ticket_date desc,
    ticket.updated_at desc,
    ticket.created_at desc,
    ticket.id desc
)
insert into public.compras_counterparty_material_prices (
  id,
  company_id,
  material_id,
  final_price,
  is_active,
  notes
)
select
  case
    when latest.company_id = 'cp_import_ricardo_garcia_mendieta'
     and latest.material_id = 'ca_comercial_carton'
      then 'cpr_ricardo_garcia_mendieta_carton'
    else 'cpr_rehydrated_' || md5(latest.company_id || '|' || latest.material_id)
  end as id,
  latest.company_id,
  latest.material_id,
  latest.final_price,
  true,
  'REHIDRATADO DESDE COMPRAS_TICKETS ' ||
      to_char(
        now() at time zone 'America/Mexico_City',
        'YYYY-MM-DD HH24:MI:SS'
      )
from latest_ticket_price latest
on conflict (company_id, material_id) do update
set
  final_price = excluded.final_price,
  is_active = true,
  notes = excluded.notes,
  updated_at = now();

commit;
