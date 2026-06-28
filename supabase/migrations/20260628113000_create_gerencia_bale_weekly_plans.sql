begin;

create table if not exists public.gerencia_bale_type_catalog (
  key text primary key,
  label text not null,
  sort_order integer not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint gerencia_bale_type_catalog_key_trim_chk check (
    key = btrim(key) and length(key) > 0
  ),
  constraint gerencia_bale_type_catalog_label_trim_chk check (
    label = btrim(label) and length(label) > 0
  ),
  constraint gerencia_bale_type_catalog_sort_order_chk check (
    sort_order >= 0
  )
);

create table if not exists public.gerencia_bale_weekly_plans (
  id uuid primary key default gen_random_uuid(),
  week_start_date date not null,
  week_end_date date not null,
  status text not null default 'planeada'
    check (status in ('planeada', 'en_curso', 'cerrada', 'cancelada')),
  notes text,
  created_by uuid default auth.uid(),
  closed_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz,
  constraint gerencia_bale_weekly_plans_week_start_monday_chk check (
    extract(isodow from week_start_date) = 1
  ),
  constraint gerencia_bale_weekly_plans_week_span_chk check (
    week_end_date >= week_start_date + 5
    and week_end_date <= week_start_date + 6
  ),
  constraint gerencia_bale_weekly_plans_closed_fields_chk check (
    (status <> 'cerrada')
    or (closed_at is not null)
  )
);

create table if not exists public.gerencia_bale_weekly_plan_lines (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.gerencia_bale_weekly_plans(id) on delete cascade,
  bale_type_key text not null references public.gerencia_bale_type_catalog(key) on delete restrict,
  sort_order integer not null default 100,
  production_target_bales integer not null default 0,
  shipment_target_bales integer not null default 0,
  notes text,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint gerencia_bale_weekly_plan_lines_sort_order_chk check (
    sort_order >= 0
  ),
  constraint gerencia_bale_weekly_plan_lines_production_target_chk check (
    production_target_bales >= 0
  ),
  constraint gerencia_bale_weekly_plan_lines_shipment_target_chk check (
    shipment_target_bales >= 0
  )
);

drop trigger if exists trg_gerencia_bale_type_catalog_updated_at
  on public.gerencia_bale_type_catalog;
create trigger trg_gerencia_bale_type_catalog_updated_at
before update on public.gerencia_bale_type_catalog
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_gerencia_bale_weekly_plans_updated_at
  on public.gerencia_bale_weekly_plans;
create trigger trg_gerencia_bale_weekly_plans_updated_at
before update on public.gerencia_bale_weekly_plans
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_gerencia_bale_weekly_plan_lines_updated_at
  on public.gerencia_bale_weekly_plan_lines;
create trigger trg_gerencia_bale_weekly_plan_lines_updated_at
before update on public.gerencia_bale_weekly_plan_lines
for each row execute function public.set_updated_at_v2();

create unique index if not exists gerencia_bale_weekly_plans_week_start_idx
  on public.gerencia_bale_weekly_plans (week_start_date);

create index if not exists gerencia_bale_weekly_plans_status_idx
  on public.gerencia_bale_weekly_plans (status, week_start_date desc);

create unique index if not exists gerencia_bale_weekly_plan_lines_unique_type_idx
  on public.gerencia_bale_weekly_plan_lines (plan_id, bale_type_key);

create index if not exists gerencia_bale_weekly_plan_lines_plan_sort_idx
  on public.gerencia_bale_weekly_plan_lines (plan_id, sort_order, bale_type_key);

create index if not exists gerencia_bale_type_catalog_active_sort_idx
  on public.gerencia_bale_type_catalog (is_active, sort_order, label);

insert into public.gerencia_bale_type_catalog (
  key,
  label,
  sort_order,
  is_active
)
values
  ('limpio', 'Limpio', 10, true),
  ('revuelto', 'Revuelto', 20, true),
  ('americano', 'Americano', 30, true)
on conflict (key) do update
set
  label = excluded.label,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  updated_at = now();

alter table public.gerencia_bale_type_catalog enable row level security;
alter table public.gerencia_bale_weekly_plans enable row level security;
alter table public.gerencia_bale_weekly_plan_lines enable row level security;

grant select, insert, update, delete on public.gerencia_bale_type_catalog to authenticated;
grant select, insert, update, delete on public.gerencia_bale_weekly_plans to authenticated;
grant select, insert, update, delete on public.gerencia_bale_weekly_plan_lines to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'gerencia_bale_type_catalog'
      and policyname = 'gerencia_bale_type_catalog_authenticated_all'
  ) then
    create policy gerencia_bale_type_catalog_authenticated_all
      on public.gerencia_bale_type_catalog
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'gerencia_bale_weekly_plans'
      and policyname = 'gerencia_bale_weekly_plans_authenticated_all'
  ) then
    create policy gerencia_bale_weekly_plans_authenticated_all
      on public.gerencia_bale_weekly_plans
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'gerencia_bale_weekly_plan_lines'
      and policyname = 'gerencia_bale_weekly_plan_lines_authenticated_all'
  ) then
    create policy gerencia_bale_weekly_plan_lines_authenticated_all
      on public.gerencia_bale_weekly_plan_lines
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
