begin;

create table public.hr_staffing_targets (
  id uuid primary key,
  company text not null check (length(company) between 1 and 160),
  position text not null check (length(position) between 1 and 120),
  company_key text generated always as (public.hr_job_position_key(company)) stored,
  position_key text generated always as (public.hr_job_position_key(position)) stored,
  required_count integer not null check (required_count between 0 and 100000),
  revision integer not null default 1,
  updated_at timestamptz not null default now(),
  updated_by uuid not null references auth.users(id),
  unique(company_key,position_key)
);
create table public.hr_staffing_revisions (
  request_id uuid primary key,
  target_id uuid not null references public.hr_staffing_targets(id),
  actor_id uuid not null references auth.users(id),
  request_body jsonb not null,
  result jsonb not null,
  created_at timestamptz not null default now()
);
alter table public.hr_staffing_targets enable row level security;
alter table public.hr_staffing_revisions enable row level security;
revoke all on public.hr_staffing_targets,public.hr_staffing_revisions from anon,authenticated;
grant select on public.hr_staffing_targets,public.hr_staffing_revisions to authenticated;
create policy hr_staffing_read on public.hr_staffing_targets for select to authenticated
  using(public.hr_can_access_loans());
create policy hr_staffing_history_read on public.hr_staffing_revisions for select to authenticated
  using(public.hr_can_access_loans());

create function public.hr_staffing_save(p_id uuid,p_expected_revision integer,p_request_id uuid,p_company text,p_position text,p_required_count integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  target public.hr_staffing_targets;
  prior public.hr_staffing_revisions;
  body jsonb := jsonb_build_object('id',p_id,'revision',p_expected_revision,'company',p_company,'position',p_position,'required_count',p_required_count);
  company_name text := public.hr_job_position_normalize(p_company);
  position_name text;
  result jsonb;
begin
  if auth.uid() is null or not public.hr_can_access_loans() then
    raise exception 'Tu perfil no tiene acceso a Vacantes RH.' using errcode='42501';
  end if;
  if p_id is null or p_request_id is null or p_expected_revision is null or p_expected_revision<0
    or length(company_name) not between 1 and 160 or p_required_count is null or p_required_count not between 0 and 100000 then
    raise exception 'Selecciona empresa, puesto y una plantilla entre 0 y 100,000 personas.' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
  select * into prior from public.hr_staffing_revisions where request_id=p_request_id;
  if found then
    if prior.actor_id<>auth.uid() or prior.request_body<>body then
      raise exception 'La solicitud cambió durante el reintento.' using errcode='22023';
    end if;
    return prior.result;
  end if;
  select * into target from public.hr_staffing_targets where id=p_id for update;
  if (found and target.revision<>p_expected_revision) or (not found and p_expected_revision<>0) then
    raise exception 'La plantilla cambió en otro equipo. Cierra la edición y vuelve a abrirla para consultar el dato actual.' using errcode='40001';
  end if;
  position_name := public.hr_job_position_ensure(p_position);
  if target.id is null then
    insert into public.hr_staffing_targets(id,company,position,required_count,updated_by)
      values(p_id,company_name,position_name,p_required_count,auth.uid()) returning * into target;
  else
    -- A target always represents the same company/position. Adjust its size;
    -- use a separate row for a different company or role.
    if target.company_key<>public.hr_job_position_key(company_name) or target.position_key<>public.hr_job_position_key(position_name) then
      raise exception 'La empresa y el puesto de una plantilla existente no pueden cambiarse.' using errcode='22023';
    end if;
    update public.hr_staffing_targets set required_count=p_required_count,revision=revision+1,updated_at=now(),updated_by=auth.uid()
      where id=p_id returning * into target;
  end if;
  result := to_jsonb(target);
  insert into public.hr_staffing_revisions(request_id,target_id,actor_id,request_body,result)
    values(p_request_id,p_id,auth.uid(),body,result);
  return result;
exception when unique_violation then
  raise exception 'Ya existe una plantilla para esa empresa y puesto. Edita la cantidad de la fila existente.' using errcode='23505';
end;
$$;

-- One statement returns a consistent, unpaginated aggregate. No names,
-- payroll figures or other employee details are exposed by this endpoint.
create function public.hr_staffing_snapshot() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  if auth.uid() is null or not public.hr_can_access_loans() then
    raise exception 'Tu perfil no tiene acceso a Vacantes RH.' using errcode='42501';
  end if;
  with occupied as (
    select public.hr_job_position_key(empresa) company_key,public.hr_job_position_key(puesto) position_key,count(*)::integer filled_count
    from public.hr_employee_profiles where employment_status='activo'
    group by 1,2
  ), targets as (
    select t.*,coalesce(o.filled_count,0) filled_count,greatest(t.required_count-coalesce(o.filled_count,0),0) vacant_count
    from public.hr_staffing_targets t left join occupied o using(company_key,position_key)
  ), companies as (
    select public.hr_job_position_normalize(empresa) name from public.hr_employee_profiles
    union select company from public.hr_staffing_targets
  )
  select jsonb_build_object(
    'targets',coalesce((select jsonb_agg(to_jsonb(t) order by company_key,position_key) from targets t),'[]'::jsonb),
    'companies',coalesce((select jsonb_agg(name order by name) from companies where name<>''),'[]'::jsonb),
    'unassigned_count',(select count(*) from public.hr_employee_profiles where employment_status='activo' and public.hr_job_position_key(puesto)='')
  ) into result;
  return result;
end;
$$;
create function public.hr_staffing_save_batch(p_operations jsonb) returns void
language plpgsql security invoker set search_path='' as $$
declare op jsonb;
begin
  if jsonb_typeof(p_operations) is distinct from 'array' or jsonb_array_length(p_operations) not between 1 and 1000 then
    raise exception 'Selecciona entre 1 y 1,000 plantillas.' using errcode='22023';
  end if;
  -- Sorted locking prevents reverse-order deadlocks. A conflict in any row
  -- rolls back all target changes and all request receipts in this batch.
  for op in select value from jsonb_array_elements(p_operations) order by value->>'p_id' loop
    perform public.hr_staffing_save((op->>'p_id')::uuid,(op->>'p_expected_revision')::integer,(op->>'p_request_id')::uuid,
      op->>'p_company',op->>'p_position',(op->>'p_required_count')::integer);
  end loop;
end;
$$;
revoke all on function public.hr_staffing_save_batch(jsonb) from public,anon;
grant execute on function public.hr_staffing_save_batch(jsonb) to authenticated;
revoke all on function public.hr_staffing_save(uuid,integer,uuid,text,text,integer),public.hr_staffing_snapshot() from public,anon;
grant execute on function public.hr_staffing_save(uuid,integer,uuid,text,text,integer),public.hr_staffing_snapshot() to authenticated;
notify pgrst,'reload schema';
commit;
