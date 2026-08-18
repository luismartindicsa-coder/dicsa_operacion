begin;

create table if not exists public.commercial_agenda_entries (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  event_type text not null default 'cita'
    check (event_type in ('cita', 'reunion', 'foro', 'convencion', 'otro')),
  starts_at timestamptz not null,
  ends_at timestamptz,
  location text,
  notes text,
  status text not null default 'programado'
    check (status in ('programado', 'realizado', 'cancelado')),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint commercial_agenda_entries_title_trim_chk check (
    title = btrim(title) and length(title) > 0
  ),
  constraint commercial_agenda_entries_dates_chk check (
    ends_at is null or ends_at >= starts_at
  )
);

create index if not exists commercial_agenda_entries_starts_at_idx
  on public.commercial_agenda_entries (starts_at, status);

drop trigger if exists trg_commercial_agenda_entries_updated_at
  on public.commercial_agenda_entries;
create trigger trg_commercial_agenda_entries_updated_at
before update on public.commercial_agenda_entries
for each row execute function public.set_updated_at();

alter table public.commercial_agenda_entries enable row level security;
grant select, insert, update, delete on public.commercial_agenda_entries to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'commercial_agenda_entries'
      and policyname = 'commercial_agenda_entries_authenticated_all'
  ) then
    create policy commercial_agenda_entries_authenticated_all
      on public.commercial_agenda_entries
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
