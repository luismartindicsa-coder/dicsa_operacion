begin;

create table if not exists public.direction_shipment_plans (
  id uuid primary key default gen_random_uuid(),
  ship_date date not null,
  client_name text not null,
  commercial_material_code text not null,
  planned_units integer not null default 0,
  priority text not null default 'normal'
    check (priority in ('alta', 'normal', 'flexible')),
  status text not null default 'planeado'
    check (status in ('planeado', 'confirmado', 'embarcado', 'movido', 'cancelado')),
  notes text,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint direction_shipment_plans_client_name_trim_chk check (
    client_name = btrim(client_name) and length(client_name) > 0
  ),
  constraint direction_shipment_plans_material_trim_chk check (
    commercial_material_code = btrim(commercial_material_code)
    and length(commercial_material_code) > 0
  ),
  constraint direction_shipment_plans_units_positive_chk check (
    planned_units > 0
  )
);

create table if not exists public.direction_production_capacity_impacts (
  id uuid primary key default gen_random_uuid(),
  machine_key text not null
    check (machine_key in ('c1', 'c2', 'ambas')),
  start_date date not null,
  end_date date not null,
  impact_percent integer not null default 100
    check (impact_percent > 0 and impact_percent <= 100),
  notes text,
  source text not null default 'manual'
    check (source in ('manual', 'maintenance')),
  linked_maintenance_order_id uuid
    references public.maintenance_orders(id) on delete set null,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_active boolean not null default true,
  constraint direction_production_capacity_impacts_range_chk check (
    end_date >= start_date
  )
);

drop trigger if exists trg_direction_shipment_plans_updated_at
  on public.direction_shipment_plans;
create trigger trg_direction_shipment_plans_updated_at
before update on public.direction_shipment_plans
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_direction_production_capacity_impacts_updated_at
  on public.direction_production_capacity_impacts;
create trigger trg_direction_production_capacity_impacts_updated_at
before update on public.direction_production_capacity_impacts
for each row execute function public.set_updated_at_v2();

create index if not exists direction_shipment_plans_ship_date_idx
  on public.direction_shipment_plans (ship_date, status, priority);

create index if not exists direction_shipment_plans_material_date_idx
  on public.direction_shipment_plans (commercial_material_code, ship_date);

create index if not exists direction_capacity_impacts_dates_idx
  on public.direction_production_capacity_impacts (
    start_date,
    end_date,
    is_active
  );

create index if not exists direction_capacity_impacts_machine_idx
  on public.direction_production_capacity_impacts (machine_key, start_date);

alter table public.direction_shipment_plans enable row level security;
alter table public.direction_production_capacity_impacts enable row level security;

grant select, insert, update, delete
  on public.direction_shipment_plans
  to authenticated;

grant select, insert, update, delete
  on public.direction_production_capacity_impacts
  to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'direction_shipment_plans'
      and policyname = 'direction_shipment_plans_authenticated_all'
  ) then
    create policy direction_shipment_plans_authenticated_all
      on public.direction_shipment_plans
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'direction_production_capacity_impacts'
      and policyname = 'direction_production_capacity_impacts_authenticated_all'
  ) then
    create policy direction_production_capacity_impacts_authenticated_all
      on public.direction_production_capacity_impacts
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
