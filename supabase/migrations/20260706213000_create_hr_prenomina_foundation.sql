create table if not exists public.hr_prenomina_draft_rows (
  id uuid primary key default gen_random_uuid(),
  period_label text not null default '',
  employee_id text not null references public.hr_employee_profiles(id) on delete cascade,
  employee_name text not null default '',
  empresa text not null default '',
  draft_status text not null default 'borrador',
  manual_adjustment_amount numeric(12,2) not null default 0,
  notes text not null default '',
  source_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hr_prenomina_draft_rows_status_check
    check (draft_status in ('borrador', 'revision_rh', 'listo', 'publicado')),
  constraint hr_prenomina_draft_rows_employee_period_unique
    unique (period_label, employee_id)
);

create index if not exists hr_prenomina_draft_rows_period_idx
  on public.hr_prenomina_draft_rows (period_label, draft_status, employee_id);

drop trigger if exists set_hr_prenomina_draft_rows_updated_at
  on public.hr_prenomina_draft_rows;
create trigger set_hr_prenomina_draft_rows_updated_at
before update on public.hr_prenomina_draft_rows
for each row
execute function public.set_updated_at();

alter table public.hr_prenomina_draft_rows enable row level security;

drop policy if exists "hr_prenomina_draft_rows_authenticated_select"
  on public.hr_prenomina_draft_rows;
create policy "hr_prenomina_draft_rows_authenticated_select"
on public.hr_prenomina_draft_rows
for select
to authenticated
using (true);

drop policy if exists "hr_prenomina_draft_rows_authenticated_insert"
  on public.hr_prenomina_draft_rows;
create policy "hr_prenomina_draft_rows_authenticated_insert"
on public.hr_prenomina_draft_rows
for insert
to authenticated
with check (true);

drop policy if exists "hr_prenomina_draft_rows_authenticated_update"
  on public.hr_prenomina_draft_rows;
create policy "hr_prenomina_draft_rows_authenticated_update"
on public.hr_prenomina_draft_rows
for update
to authenticated
using (true)
with check (true);

drop policy if exists "hr_prenomina_draft_rows_authenticated_delete"
  on public.hr_prenomina_draft_rows;
create policy "hr_prenomina_draft_rows_authenticated_delete"
on public.hr_prenomina_draft_rows
for delete
to authenticated
using (true);

comment on table public.hr_prenomina_draft_rows is
  'Borrador semanal de prenómina RH por colaborador y periodo; consolida asistencia, vacaciones y permisos antes de nómina final.';
