begin;

create table if not exists public.cash_taxonomy_configs (
  area text primary key,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'cash_taxonomy_configs_area_chk'
  ) then
    alter table public.cash_taxonomy_configs
      add constraint cash_taxonomy_configs_area_chk
      check (area in ('menudeo', 'mayoreo'));
  end if;
end $$;

create or replace function public.set_cash_taxonomy_configs_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists trg_set_cash_taxonomy_configs_updated_at on public.cash_taxonomy_configs;
create trigger trg_set_cash_taxonomy_configs_updated_at
before update on public.cash_taxonomy_configs
for each row
execute function public.set_cash_taxonomy_configs_updated_at();

comment on table public.cash_taxonomy_configs is
  'Snapshot configurable por area para catalogos de efectivo, conceptos, subconceptos y listas controladas.';

alter table public.cash_taxonomy_configs enable row level security;

grant select, insert, update, delete on public.cash_taxonomy_configs to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'cash_taxonomy_configs'
      and policyname = 'cash_taxonomy_configs_authenticated_all'
  ) then
    create policy cash_taxonomy_configs_authenticated_all
      on public.cash_taxonomy_configs
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end $$;

commit;
