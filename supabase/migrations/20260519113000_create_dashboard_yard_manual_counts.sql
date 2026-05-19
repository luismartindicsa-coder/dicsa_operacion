begin;

create table if not exists public.dashboard_yard_manual_counts (
  id uuid primary key default gen_random_uuid(),
  site text not null default 'DICSA_CELAYA',
  widget_key text not null,
  source_kind text not null,
  material text,
  commercial_material_code text,
  count_units integer not null default 0,
  weight_kg numeric(14,3) not null default 0,
  notes text,
  counted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  constraint dashboard_yard_manual_counts_site_trim_chk check (
    site = btrim(site) and length(site) > 0
  ),
  constraint dashboard_yard_manual_counts_widget_key_trim_chk check (
    widget_key = btrim(widget_key) and length(widget_key) > 0
  ),
  constraint dashboard_yard_manual_counts_source_kind_chk check (
    source_kind in ('bales_total', 'operational_material', 'commercial_material')
  ),
  constraint dashboard_yard_manual_counts_count_units_chk check (
    count_units >= 0
  ),
  constraint dashboard_yard_manual_counts_weight_kg_chk check (
    weight_kg >= 0
  )
);

create unique index if not exists dashboard_yard_manual_counts_site_widget_key_uidx
  on public.dashboard_yard_manual_counts (site, widget_key);

create index if not exists dashboard_yard_manual_counts_site_source_idx
  on public.dashboard_yard_manual_counts (site, source_kind);

drop trigger if exists trg_dashboard_yard_manual_counts_updated_at
  on public.dashboard_yard_manual_counts;
create trigger trg_dashboard_yard_manual_counts_updated_at
before update on public.dashboard_yard_manual_counts
for each row execute function public.set_updated_at_v2();

alter table public.dashboard_yard_manual_counts enable row level security;

grant select, insert, update, delete
  on public.dashboard_yard_manual_counts
  to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'dashboard_yard_manual_counts'
      and policyname = 'dashboard_yard_manual_counts_authenticated_all'
  ) then
    create policy dashboard_yard_manual_counts_authenticated_all
      on public.dashboard_yard_manual_counts
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
