-- Independent, append-only calculation history. Does not change any payroll.
begin;

create table public.hr_employee_termination_calculations (
  id uuid primary key default gen_random_uuid(),
  employee_id text not null references public.hr_employee_profiles(id) on delete restrict,
  employee_name text not null,
  empresa text not null default '',
  revision integer not null,
  mode text not null check (mode in ('finiquito', 'liquidacion', 'indemnizacion')),
  status text not null check (status in ('borrador', 'revisado')),
  start_date date not null,
  end_date date not null check (end_date >= start_date),
  formula_version text not null,
  inputs jsonb not null check (jsonb_typeof(inputs) = 'object'),
  result jsonb not null check (jsonb_typeof(result) = 'object'),
  source_snapshot jsonb not null check (jsonb_typeof(source_snapshot) = 'object'),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  constraint hr_termination_employee_revision unique (employee_id, revision),
  constraint hr_termination_snapshot_consistency check (
    (inputs ->> 'mode') is not distinct from mode
    and (inputs ->> 'start_date') is not distinct from start_date::text
    and (inputs ->> 'end_date') is not distinct from end_date::text
    and (inputs ->> 'formula_version') is not distinct from formula_version
    and (source_snapshot #>> '{personal,id}') is not distinct from employee_id
    and result ?& array['lines','gross','deductions','pending','net']
    and jsonb_typeof(result -> 'lines') = 'array'
    and jsonb_typeof(result -> 'gross') = 'object'
    and jsonb_typeof(result -> 'deductions') = 'object'
    and jsonb_typeof(result -> 'pending') = 'array'
  ),
  constraint hr_termination_review_complete check (
    status <> 'revisado' or coalesce((
      result -> 'pending' = '[]'::jsonb
      and jsonb_typeof(result -> 'net') = 'object'
      and coalesce(inputs ->> 'official_isr', '') <> ''
      and coalesce(inputs ->> 'isr_reference', '') <> ''
      and inputs ->> 'history_reviewed' = 'true'
    ), false)
  )
);

-- Same HR / Dirección roles as AuthAccess, evaluated on the server.
create function public.hr_can_access_termination_calculations()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p
    cross join lateral (
      select regexp_replace(translate(lower(trim(p.role::text)), 'áéíóú', 'aeiou'), '[[:space:]-]+', '_', 'g') as role
    ) normalized
    where p.user_id = auth.uid() and p.is_active is true and (
      lower(coalesce(auth.jwt() ->> 'email', '')) in ('rh@dicsamx.com', 'direccion@dicsamx.com')
      or normalized.role in ('rh', 'rrhh', 'human_resources', 'recursos_humanos', 'nominas', 'payroll', 'direccion', 'direction', 'auxiliar_direccion', 'direccion_general')
      or normalized.role ~ '^(rh_|human_resources_|recursos_humanos_|direccion_)'
      or normalized.role ~ '(_rh|_human_resources|_recursos_humanos|_direccion)$'
      or normalized.role like '%direction%'
    )
  );
$$;
revoke all on function public.hr_can_access_termination_calculations() from public, anon;
grant execute on function public.hr_can_access_termination_calculations() to authenticated;

create function public.hr_termination_assign_revision()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  -- Serialize versions for the same employee, including concurrent RH editors.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('hr_termination:' || new.employee_id, 0));
  select coalesce(max(revision), 0) + 1 into new.revision
    from public.hr_employee_termination_calculations where employee_id = new.employee_id;
  new.created_at := now();
  new.created_by := auth.uid();
  return new;
end;
$$;
revoke all on function public.hr_termination_assign_revision() from public, anon, authenticated;
create trigger hr_termination_assign_revision before insert
  on public.hr_employee_termination_calculations for each row
  execute function public.hr_termination_assign_revision();

alter table public.hr_employee_termination_calculations enable row level security;
revoke all on table public.hr_employee_termination_calculations from anon, authenticated;
grant select, insert on table public.hr_employee_termination_calculations to authenticated;
create policy hr_termination_select on public.hr_employee_termination_calculations
  for select to authenticated using (public.hr_can_access_termination_calculations());
create policy hr_termination_insert on public.hr_employee_termination_calculations
  for insert to authenticated with check (
    public.hr_can_access_termination_calculations() and created_by = auth.uid()
  );

create index hr_termination_employee_created on public.hr_employee_termination_calculations(employee_id, created_at desc);
comment on table public.hr_employee_termination_calculations is
  'Versioned RH finiquito/liquidacion/indemnizacion snapshots. Reviewed calculation does not execute payment, change payroll or terminate Personal.';
notify pgrst, 'reload schema';
commit;
