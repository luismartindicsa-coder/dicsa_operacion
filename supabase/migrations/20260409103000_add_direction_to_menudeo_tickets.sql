begin;

alter table public.men_tickets
  add column if not exists direction text;

update public.men_tickets
set direction = 'purchase'
where direction is null;

alter table public.men_tickets
  alter column direction set default 'purchase';

alter table public.men_tickets
  alter column direction set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'men_tickets_direction_chk'
  ) then
    alter table public.men_tickets
      add constraint men_tickets_direction_chk
      check (direction in ('purchase', 'sale'));
  end if;
end
$$;

create index if not exists men_tickets_direction_ticket_date_idx
  on public.men_tickets (direction, ticket_date desc, ticket_number);

create or replace view public.vw_men_tickets_grid as
select
  t.id,
  t.split_batch_id,
  t.ticket_date,
  t.ticket_base,
  t.ticket_suffix,
  t.ticket_number,
  t.counterparty_id,
  t.counterparty_name_snapshot,
  t.price_id,
  t.general_material_id,
  t.commercial_material_id,
  t.material_alias_id,
  t.material_label_snapshot,
  t.price_at_entry,
  t.gross_weight,
  t.tare_weight,
  t.humidity_percent,
  t.trash_weight,
  t.premium_per_kg,
  t.net_weight,
  t.payable_weight,
  t.amount_total,
  t.status,
  t.comment,
  t.created_by,
  t.created_at,
  t.updated_at,
  t.direction
from public.men_tickets t
order by t.ticket_date desc, t.ticket_number;

comment on table public.men_tickets is
  'Tickets virtuales de menudeo por sentido de negocio (purchase/sale). Guardan el price_at_entry para que la edicion posterior no recalcule con el catalogo vigente.';

comment on view public.vw_men_tickets_grid is
  'Vista operativa para grid y detalle de tickets de menudeo, separable por direction.';

commit;
