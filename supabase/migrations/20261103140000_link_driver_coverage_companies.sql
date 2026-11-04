begin;

-- Coverage remains verbatim; relationships are stored independently.
create table public.logistics_driver_companies (
  employee_id uuid not null references public.logistics_driver_profiles(employee_id) on delete cascade,
  site_id uuid not null references public.sites(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (employee_id, site_id)
);
create index logistics_driver_companies_site_idx on public.logistics_driver_companies(site_id);
alter table public.logistics_driver_companies enable row level security;
create policy logistics_driver_companies_authenticated_all on public.logistics_driver_companies
  for all to authenticated using (true) with check (true);
grant select, insert, update, delete on public.logistics_driver_companies to authenticated;

-- Audit of names that could not be matched uniquely during this one-time import.
alter table public.logistics_driver_profiles
  add column coverage_import_pending text[] not null default '{}';

create function public.logistics_coverage_name_key(value text)
returns text language sql immutable strict set search_path = public as $$
  select btrim(regexp_replace(
    translate(upper(value), 'ÁÉÍÓÚÜÑ', 'AEIOUUN'), '[^A-Z0-9]+', ' ', 'g'
  ));
$$;

-- Commas/semicolons delimit companies. Newlines are whitespace so wrapped
-- names such as ROCIO\nCARVAJAL still match. Never match by substring/fuzziness.
create temporary table coverage_company_matches on commit drop as
select p.employee_id, btrim(token) as original_name,
       count(distinct s.id) as match_count, (array_agg(s.id) filter (where s.id is not null))[1] as site_id
from public.logistics_driver_profiles p
cross join lateral regexp_split_to_table(coalesce(p.coverage_note, ''), '[,;]') token
left join public.sites s on s.type = 'cliente' and s.is_active
  and public.logistics_coverage_name_key(s.name) = public.logistics_coverage_name_key(token)
where public.logistics_coverage_name_key(token) <> ''
group by p.employee_id, btrim(token);

insert into public.logistics_driver_companies(employee_id, site_id)
select distinct employee_id, site_id from coverage_company_matches where match_count = 1
on conflict do nothing;

update public.logistics_driver_profiles p
set coverage_import_pending = m.names
from (
  select employee_id, array_agg(original_name order by original_name) as names
  from coverage_company_matches where match_count <> 1 group by employee_id
) m where p.employee_id = m.employee_id;

-- Profile and all company assignments commit together. A stale editor cannot
-- silently restore links removed by another operator.
create function public.save_logistics_driver_with_companies(
  p_profile jsonb, p_site_ids uuid[], p_expected_site_ids uuid[]
) returns void language plpgsql security invoker set search_path = public as $$
declare
  v_employee_id uuid := (p_profile->>'employee_id')::uuid;
  v_current uuid[];
  v_selected uuid[];
  v_expected uuid[];
  v_driver_name text;
begin
  if p_site_ids is null or p_expected_site_ids is null then
    raise exception 'La selección de empresas está incompleta.' using errcode = '22023';
  end if;
  select full_name into v_driver_name from public.employees
    where id = v_employee_id and is_driver;
  if not found then
    raise exception 'El chofer ya no está disponible.' using errcode = '22023';
  end if;
  insert into public.logistics_driver_profiles(employee_id, driver_name)
    values(v_employee_id, v_driver_name) on conflict do nothing;
  perform 1 from public.logistics_driver_profiles where employee_id = v_employee_id for update;
  select coalesce(array_agg(site_id order by site_id), '{}') into v_current
    from public.logistics_driver_companies where employee_id = v_employee_id;
  select coalesce(array_agg(id order by id), '{}') into v_expected
    from (select distinct unnest(p_expected_site_ids) as id) ids;
  select coalesce(array_agg(id order by id), '{}') into v_selected
    from (select distinct unnest(p_site_ids) as id) ids;
  if v_current is distinct from v_expected then
    raise exception 'Las empresas del chofer cambiaron. Abre nuevamente el perfil para revisar la selección.' using errcode = '40001';
  end if;
  if exists (
    select 1 from unnest(v_selected) as selected(site_id) left join public.sites s on s.id = selected.site_id
    where s.id is null or s.type <> 'cliente' or (not s.is_active and not selected.site_id = any(v_current))
  ) then
    raise exception 'Selecciona empresas activas del catálogo.' using errcode = '22023';
  end if;

  update public.logistics_driver_profiles set
    driver_name = v_driver_name,
    compatible_unit_types = p_profile->'compatible_unit_types',
    planning_status = p_profile->>'planning_status',
    coverage_note = p_profile->>'coverage_note',
    notes = p_profile->>'notes'
  where employee_id = v_employee_id;
  delete from public.logistics_driver_companies
    where employee_id = v_employee_id and not site_id = any(v_selected);
  insert into public.logistics_driver_companies(employee_id, site_id)
    select v_employee_id, unnest(v_selected) on conflict do nothing;
end;
$$;
revoke all on function public.save_logistics_driver_with_companies(jsonb, uuid[], uuid[]) from public;
grant execute on function public.save_logistics_driver_with_companies(jsonb, uuid[], uuid[]) to authenticated;

commit;
