begin;

create table if not exists public.men_tickets (
  id uuid primary key default gen_random_uuid(),
  split_batch_id uuid not null default gen_random_uuid(),
  ticket_date date not null default current_date,
  ticket_base text not null,
  ticket_suffix text,
  ticket_number text generated always as (
    case
      when ticket_suffix is null or btrim(ticket_suffix) = '' then ticket_base
      else ticket_base || '-' || upper(btrim(ticket_suffix))
    end
  ) stored,
  counterparty_id uuid references public.men_counterparties(id) on delete set null,
  counterparty_name_snapshot text not null,
  price_id uuid references public.men_counterparty_material_prices(id) on delete set null,
  general_material_id uuid references public.material_general_catalog_v2(id) on delete set null,
  commercial_material_id uuid references public.material_commercial_catalog_v2(id) on delete set null,
  material_alias_id uuid references public.men_material_aliases(id) on delete set null,
  material_label_snapshot text not null,
  price_at_entry numeric(14,4) not null,
  gross_weight numeric(14,4) not null default 0,
  tare_weight numeric(14,4) not null default 0,
  humidity_percent numeric(8,4) not null default 0,
  trash_weight numeric(14,4) not null default 0,
  premium_per_kg numeric(14,4) not null default 0,
  net_weight numeric(14,4) generated always as (
    gross_weight - tare_weight
  ) stored,
  payable_weight numeric(14,4) generated always as (
    ((gross_weight - tare_weight) * (1 - (humidity_percent / 100))) - trash_weight
  ) stored,
  amount_total numeric(14,4) generated always as (
    ((((gross_weight - tare_weight) * (1 - (humidity_percent / 100))) - trash_weight)
      * (price_at_entry + premium_per_kg))
  ) stored,
  status text not null default 'PENDIENTE',
  comment text,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists men_tickets_ticket_date_idx
  on public.men_tickets (ticket_date desc, ticket_number);

create index if not exists men_tickets_counterparty_idx
  on public.men_tickets (counterparty_id, ticket_date desc);

create index if not exists men_tickets_split_batch_idx
  on public.men_tickets (split_batch_id, ticket_number);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'men_tickets_ticket_base_trim_chk'
  ) then
    alter table public.men_tickets
      add constraint men_tickets_ticket_base_trim_chk
      check (ticket_base = btrim(ticket_base) and length(ticket_base) > 0);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'men_tickets_counterparty_name_trim_chk'
  ) then
    alter table public.men_tickets
      add constraint men_tickets_counterparty_name_trim_chk
      check (
        counterparty_name_snapshot = btrim(counterparty_name_snapshot)
        and length(counterparty_name_snapshot) > 0
      );
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'men_tickets_material_label_trim_chk'
  ) then
    alter table public.men_tickets
      add constraint men_tickets_material_label_trim_chk
      check (
        material_label_snapshot = btrim(material_label_snapshot)
        and length(material_label_snapshot) > 0
      );
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'men_tickets_ticket_suffix_format_chk'
  ) then
    alter table public.men_tickets
      add constraint men_tickets_ticket_suffix_format_chk
      check (
        ticket_suffix is null
        or upper(btrim(ticket_suffix)) ~ '^[A-Z0-9]+$'
      );
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'men_tickets_status_chk'
  ) then
    alter table public.men_tickets
      add constraint men_tickets_status_chk
      check (status in ('PENDIENTE', 'PAGADO'));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'men_tickets_price_nonnegative_chk'
  ) then
    alter table public.men_tickets
      add constraint men_tickets_price_nonnegative_chk
      check (
        price_at_entry >= 0
        and gross_weight >= 0
        and tare_weight >= 0
        and humidity_percent >= 0
        and trash_weight >= 0
        and premium_per_kg >= 0
      );
  end if;
end
$$;

create or replace function public.set_men_tickets_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_set_men_tickets_updated_at on public.men_tickets;
create trigger trg_set_men_tickets_updated_at
before update on public.men_tickets
for each row
execute function public.set_men_tickets_updated_at();

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
  t.updated_at
from public.men_tickets t
order by t.ticket_date desc, t.ticket_number;

comment on table public.men_tickets is
  'Tickets virtuales de menudeo. Guardan el price_at_entry para que la edicion posterior no recalcule con el catalogo vigente.';

comment on view public.vw_men_tickets_grid is
  'Vista operativa para grid y detalle de tickets de menudeo.';

alter table public.men_tickets enable row level security;

grant select, insert, update, delete on public.men_tickets to authenticated;
grant select on public.vw_men_tickets_grid to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'men_tickets'
      and policyname = 'men_tickets_authenticated_all'
  ) then
    create policy men_tickets_authenticated_all
      on public.men_tickets
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
