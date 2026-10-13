begin;

create function public.hr_job_position_normalize(p_name text) returns text
language sql immutable set search_path = '' as $$
  select upper(trim(regexp_replace(coalesce(p_name,''), '[[:space:]]+', ' ', 'g')));
$$;
create function public.hr_job_position_key(p_name text) returns text
language sql immutable set search_path = '' as $$
  select translate(public.hr_job_position_normalize(p_name), 'ÁÉÍÓÚÜ', 'AEIOUU');
$$;

create table public.hr_job_positions (
  name text not null check (length(name) between 1 and 120 and name = public.hr_job_position_normalize(name)),
  name_key text generated always as (public.hr_job_position_key(name)) stored primary key,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);
alter table public.hr_job_positions enable row level security;
revoke all on public.hr_job_positions from anon, authenticated;
grant select on public.hr_job_positions to authenticated;
create policy hr_job_positions_read on public.hr_job_positions for select to authenticated
  using (public.hr_can_access_loans());

create function public.hr_job_position_ensure(p_name text) returns text
language plpgsql security definer set search_path = '' as $$
declare normalized text := public.hr_job_position_normalize(p_name); saved text;
begin
  if auth.uid() is null or not public.hr_can_access_loans() then
    raise exception 'Tu perfil no tiene acceso al catálogo de puestos de RH.' using errcode = '42501';
  end if;
  if length(normalized) not between 1 and 120 then
    raise exception 'Escribe un puesto de hasta 120 caracteres.' using errcode = '22023';
  end if;
  -- Concurrent creators and retries reuse the first spelling, never add a
  -- duplicate or rename a value already assigned to another employee.
  insert into public.hr_job_positions as p(name, created_by) values(normalized, auth.uid())
    on conflict(name_key) do update set name = p.name
    returning name into saved;
  return saved;
end;
$$;
revoke all on function public.hr_job_position_ensure(text) from public, anon;
grant execute on function public.hr_job_position_ensure(text) to authenticated;

alter table public.hr_employee_profiles add column puesto text not null default '';
alter table public.hr_employee_profiles add constraint hr_employee_puesto_length check (length(puesto) <= 120);

create function public.hr_employee_sync_job_position() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.puesto := public.hr_job_position_normalize(new.puesto);
  if new.puesto <> '' then
    new.puesto := public.hr_job_position_ensure(new.puesto);
  end if;
  return new;
end;
$$;
-- Runs inside the existing atomic profile save. Other fields and attached
-- documents remain unchanged, and assignment failure rolls back the save.
create trigger hr_employee_sync_job_position before insert or update of puesto
  on public.hr_employee_profiles for each row execute function public.hr_employee_sync_job_position();

notify pgrst, 'reload schema';
commit;
