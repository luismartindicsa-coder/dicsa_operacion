create table if not exists public.hr_attendance_import_lots (
  id text primary key,
  source text not null check (source in ('ngteco', 'contpaq')),
  file_name text not null,
  imported_at timestamptz not null default now(),
  valid_rows integer not null default 0,
  rejected_rows integer not null default 0,
  period_label text not null default '',
  issues jsonb not null default '[]'::jsonb,
  preview_rows jsonb not null default '[]'::jsonb,
  unique_employee_ids jsonb not null default '[]'::jsonb,
  entries jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists hr_attendance_import_lots_source_idx
  on public.hr_attendance_import_lots (source);

create index if not exists hr_attendance_import_lots_imported_at_idx
  on public.hr_attendance_import_lots (imported_at desc);

drop trigger if exists set_hr_attendance_import_lots_updated_at on public.hr_attendance_import_lots;
create trigger set_hr_attendance_import_lots_updated_at
before update on public.hr_attendance_import_lots
for each row
execute function public.set_updated_at();

alter table public.hr_attendance_import_lots enable row level security;

drop policy if exists "hr_attendance_import_lots_select_authenticated" on public.hr_attendance_import_lots;
create policy "hr_attendance_import_lots_select_authenticated"
on public.hr_attendance_import_lots
for select
to authenticated
using (true);

drop policy if exists "hr_attendance_import_lots_insert_authenticated" on public.hr_attendance_import_lots;
create policy "hr_attendance_import_lots_insert_authenticated"
on public.hr_attendance_import_lots
for insert
to authenticated
with check (true);

drop policy if exists "hr_attendance_import_lots_update_authenticated" on public.hr_attendance_import_lots;
create policy "hr_attendance_import_lots_update_authenticated"
on public.hr_attendance_import_lots
for update
to authenticated
using (true)
with check (true);

drop policy if exists "hr_attendance_import_lots_delete_authenticated" on public.hr_attendance_import_lots;
create policy "hr_attendance_import_lots_delete_authenticated"
on public.hr_attendance_import_lots
for delete
to authenticated
using (true);
