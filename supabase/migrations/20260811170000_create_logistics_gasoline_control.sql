begin;

create table if not exists public.logistics_gasoline_control (
  id uuid primary key default gen_random_uuid(),
  entry_date date not null,
  operator_employee_id uuid references public.employees(id) on delete set null,
  operator_name text not null,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  vehicle_label text not null,
  liters_loaded numeric(12,2) not null default 0,
  notes text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint logistics_gasoline_operator_name_trim_chk check (
    operator_name = btrim(operator_name) and length(operator_name) > 0
  ),
  constraint logistics_gasoline_vehicle_label_trim_chk check (
    vehicle_label = btrim(vehicle_label) and length(vehicle_label) > 0
  ),
  constraint logistics_gasoline_liters_loaded_nonnegative_chk check (
    liters_loaded >= 0
  ),
  constraint logistics_gasoline_notes_trim_chk check (
    notes = btrim(notes)
  )
);

create index if not exists logistics_gasoline_control_entry_date_idx
  on public.logistics_gasoline_control (
    entry_date desc,
    created_at desc
  );

create index if not exists logistics_gasoline_control_operator_idx
  on public.logistics_gasoline_control (
    operator_employee_id,
    entry_date desc
  );

create index if not exists logistics_gasoline_control_vehicle_idx
  on public.logistics_gasoline_control (
    vehicle_id,
    entry_date desc
  );

create or replace function public.set_logistics_gasoline_control_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists logistics_gasoline_control_set_updated_at
on public.logistics_gasoline_control;

create trigger logistics_gasoline_control_set_updated_at
before update on public.logistics_gasoline_control
for each row
execute function public.set_logistics_gasoline_control_updated_at();

alter table public.logistics_gasoline_control enable row level security;

grant select, insert, update, delete
on public.logistics_gasoline_control
to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'logistics_gasoline_control'
      and policyname = 'logistics_gasoline_control_authenticated_all'
  ) then
    create policy logistics_gasoline_control_authenticated_all
      on public.logistics_gasoline_control
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
