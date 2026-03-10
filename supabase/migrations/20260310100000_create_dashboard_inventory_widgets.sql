create table if not exists public.dashboard_inventory_widgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  widget_key text not null,
  source_kind text not null,
  material text,
  commercial_material_code text,
  sort_order integer not null default 0,
  is_visible boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint dashboard_inventory_widgets_user_key_unique
    unique (user_id, widget_key),
  constraint dashboard_inventory_widgets_source_kind_chk
    check (source_kind in ('bales_total', 'operational_material', 'commercial_material')),
  constraint dashboard_inventory_widgets_payload_chk
    check (
      (source_kind = 'bales_total' and material is null and commercial_material_code is null) or
      (source_kind = 'operational_material' and material is not null and commercial_material_code is null) or
      (source_kind = 'commercial_material' and commercial_material_code is not null)
    )
);

create index if not exists dashboard_inventory_widgets_user_sort_idx
  on public.dashboard_inventory_widgets (user_id, sort_order, created_at);

create or replace function public.set_dashboard_inventory_widgets_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_dashboard_inventory_widgets_updated_at
  on public.dashboard_inventory_widgets;

create trigger set_dashboard_inventory_widgets_updated_at
before update on public.dashboard_inventory_widgets
for each row
execute function public.set_dashboard_inventory_widgets_updated_at();

alter table public.dashboard_inventory_widgets enable row level security;

drop policy if exists "dashboard_inventory_widgets_select_own"
  on public.dashboard_inventory_widgets;
create policy "dashboard_inventory_widgets_select_own"
on public.dashboard_inventory_widgets
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "dashboard_inventory_widgets_insert_own"
  on public.dashboard_inventory_widgets;
create policy "dashboard_inventory_widgets_insert_own"
on public.dashboard_inventory_widgets
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "dashboard_inventory_widgets_update_own"
  on public.dashboard_inventory_widgets;
create policy "dashboard_inventory_widgets_update_own"
on public.dashboard_inventory_widgets
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "dashboard_inventory_widgets_delete_own"
  on public.dashboard_inventory_widgets;
create policy "dashboard_inventory_widgets_delete_own"
on public.dashboard_inventory_widgets
for delete
to authenticated
using (auth.uid() = user_id);
