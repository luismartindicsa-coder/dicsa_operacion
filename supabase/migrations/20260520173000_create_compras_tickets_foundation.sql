create table if not exists public.compras_tickets (
  id text primary key,
  ticket_date timestamptz not null default now(),
  ticket_number text not null,
  provider_id text not null references public.compras_counterparties (id) on delete restrict,
  provider_name_snapshot text not null,
  material_id text not null references public.compras_material_catalog (id) on delete restrict,
  material_name_snapshot text not null,
  gross_weight numeric(14,3) not null default 0,
  tare_weight numeric(14,3) not null default 0,
  net_weight numeric(14,3) not null default 0,
  humidity_percent numeric(8,3) not null default 0,
  trash_percent numeric(8,3) not null default 0,
  payable_weight numeric(14,3) not null default 0,
  price numeric(14,4) not null default 0,
  premium numeric(14,4) not null default 0,
  amount numeric(14,2) not null default 0,
  factura_status text not null default 'PENDIENTE_DE_FACTURAR'
    check (factura_status in ('SIN_FACTURA', 'PENDIENTE_DE_FACTURAR', 'FACTURADO')),
  pago_status text not null default 'PENDIENTE_DE_PAGO'
    check (pago_status in ('PENDIENTE_DE_PAGO', 'ABONO', 'PAGADO')),
  coverage_status text not null default 'SIN_CUBRIR'
    check (coverage_status in ('SIN_CUBRIR', 'PARCIAL', 'CUBIERTO')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists compras_tickets_date_idx
  on public.compras_tickets (ticket_date desc);

create index if not exists compras_tickets_provider_idx
  on public.compras_tickets (provider_id, ticket_date desc);

create index if not exists compras_tickets_factura_pago_idx
  on public.compras_tickets (factura_status, pago_status);

create table if not exists public.compras_provider_movements (
  id text primary key,
  provider_id text not null references public.compras_counterparties (id) on delete restrict,
  movement_date timestamptz not null default now(),
  movement_type text not null
    check (movement_type in ('ABONO', 'PAGO', 'AJUSTE', 'CARGO')),
  source_type text not null
    check (source_type in ('EFECTIVO', 'BANCO', 'BOVEDA', 'INTERNO')),
  amount numeric(14,2) not null default 0,
  reference text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists compras_provider_movements_provider_idx
  on public.compras_provider_movements (provider_id, movement_date desc);

create table if not exists public.compras_ticket_payment_applications (
  id text primary key,
  ticket_id text not null references public.compras_tickets (id) on delete cascade,
  provider_movement_id text not null references public.compras_provider_movements (id) on delete cascade,
  applied_amount numeric(14,2) not null default 0,
  applied_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists compras_ticket_payment_apps_unique_idx
  on public.compras_ticket_payment_applications (ticket_id, provider_movement_id);

create index if not exists compras_ticket_payment_apps_movement_idx
  on public.compras_ticket_payment_applications (provider_movement_id);

create or replace function public.set_compras_tickets_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists compras_tickets_set_updated_at on public.compras_tickets;
create trigger compras_tickets_set_updated_at
before update on public.compras_tickets
for each row
execute function public.set_compras_tickets_updated_at();

drop trigger if exists compras_provider_movements_set_updated_at on public.compras_provider_movements;
create trigger compras_provider_movements_set_updated_at
before update on public.compras_provider_movements
for each row
execute function public.set_compras_tickets_updated_at();

drop trigger if exists compras_ticket_payment_apps_set_updated_at on public.compras_ticket_payment_applications;
create trigger compras_ticket_payment_apps_set_updated_at
before update on public.compras_ticket_payment_applications
for each row
execute function public.set_compras_tickets_updated_at();
