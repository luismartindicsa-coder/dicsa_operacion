begin;

create table public.logistics_gps_assignments (
  id uuid primary key default gen_random_uuid(),
  service_id uuid not null references public.services(id) on delete cascade,
  visit_id uuid not null references public.logistics_gps_visits(id) on delete cascade,
  service_snapshot jsonb not null,
  visit_snapshot jsonb not null,
  note text not null default '' check(char_length(note)<=1000),
  assigned_by uuid references auth.users(id) on delete set null,
  assigned_at timestamptz not null default now(),
  revoked_by uuid references auth.users(id) on delete set null,
  revoked_at timestamptz
);
create unique index logistics_gps_assignment_service_active on public.logistics_gps_assignments(service_id) where revoked_at is null;
create unique index logistics_gps_assignment_visit_active on public.logistics_gps_assignments(visit_id) where revoked_at is null;

create table public.logistics_gps_trash (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid references public.logistics_gps_visits(id) on delete cascade,
  stop_id uuid references public.logistics_gps_stops(id) on delete cascade,
  event_snapshot jsonb not null,
  reason text not null check(char_length(btrim(reason)) between 1 and 1000),
  discarded_by uuid references auth.users(id) on delete set null,
  discarded_at timestamptz not null default now(),
  restored_by uuid references auth.users(id) on delete set null,
  restored_at timestamptz,
  check(num_nonnulls(visit_id,stop_id)=1)
);
create unique index logistics_gps_trash_visit_active on public.logistics_gps_trash(visit_id) where restored_at is null;
create unique index logistics_gps_trash_stop_active on public.logistics_gps_trash(stop_id) where restored_at is null;
alter table public.logistics_gps_assignments enable row level security;
alter table public.logistics_gps_trash enable row level security;
revoke all on public.logistics_gps_assignments,public.logistics_gps_trash from anon,authenticated;
grant select on public.logistics_gps_assignments,public.logistics_gps_trash to authenticated;
grant all on public.logistics_gps_assignments,public.logistics_gps_trash to service_role;
create policy gps_assignments_read on public.logistics_gps_assignments for select to authenticated using ((select public.can_view_logistics_gps()));
create policy gps_trash_read on public.logistics_gps_trash for select to authenticated using ((select public.can_view_logistics_gps()));

-- Service-row lock + visit-row lock serialize assignment, unassignment and trash.
-- Expected assignment UUID prevents stale clients from replacing another review.
create function public.assign_logistics_gps_visit(p_service uuid,p_visit uuid,p_expected uuid default null,p_note text default '')
returns uuid language plpgsql security definer set search_path='' as $$
declare s public.services%rowtype; v public.logistics_gps_visits%rowtype;
  current_id uuid; result_id uuid; operation_day date; day_start timestamptz;
begin
  if not public.can_view_logistics_gps() or auth.uid() is null then raise insufficient_privilege; end if;
  if p_note is null or char_length(p_note)>1000 then raise exception 'La nota no es válida.'; end if;
  select * into s from public.services where id=p_service for update;
  if not found or s.area is distinct from 'LOGISTICA' then raise exception 'Servicio no disponible en Logística.'; end if;
  select id into current_id from public.logistics_gps_assignments where service_id=p_service and revoked_at is null;
  if current_id is distinct from p_expected then raise exception 'La asignación cambió. Actualiza antes de continuar.'; end if;
  if p_visit is null then
    update public.logistics_gps_assignments set revoked_at=now(),revoked_by=auth.uid() where id=current_id;
    return null;
  end if;
  if s.status='cancelado' then raise exception 'No se puede asignar un servicio cancelado.'; end if;
  select * into v from public.logistics_gps_visits where id=p_visit for update;
  if not found then raise exception 'Visita no disponible.'; end if;
  if exists(select 1 from public.logistics_gps_trash where visit_id=p_visit and restored_at is null) then
    raise exception 'La visita está en la papelera. Restáurala antes de asignarla.';
  end if;
  if exists(select 1 from public.logistics_gps_assignments where visit_id=p_visit and revoked_at is null and service_id<>p_service) then
    raise exception 'La visita ya está asignada a otro servicio.';
  end if;
  if coalesce(v.ended_at,v.last_inside_at)-v.started_at < interval '5 minutes'
     or v.place_label ~* '\mdicsa[[:space:]·_-]+celaya\M'
     or v.geofence_name ~* '\mdicsa[[:space:]·_-]+celaya\M' then
    raise exception 'Esta visita está excluida del cruce.';
  end if;
  operation_day:=coalesce(s.due_date,s.service_date);
  day_start:=operation_day::timestamp at time zone 'America/Mexico_City';
  if s.vehicle_id is null or s.client_id is null or s.vehicle_id<>v.vehicle_id or s.client_id is distinct from v.site_id then
    raise exception 'La unidad o empresa no coincide. Corrige el servicio antes de asignar.';
  end if;
  if v.started_at>=day_start+interval '1 day' or coalesce(v.ended_at,v.last_inside_at)<day_start then
    raise exception 'La visita no corresponde a la fecha prevista del servicio.';
  end if;
  if (v.has_gap or v.status='interrupted') and btrim(p_note)='' then
    raise exception 'Escribe una nota para asignar una visita con interrupciones.';
  end if;
  if current_id is not null and exists(select 1 from public.logistics_gps_assignments where id=current_id and visit_id=p_visit) then return current_id; end if;
  update public.logistics_gps_assignments set revoked_at=now(),revoked_by=auth.uid() where id=current_id;
  insert into public.logistics_gps_assignments(service_id,visit_id,service_snapshot,visit_snapshot,note,assigned_by)
    values(p_service,p_visit,to_jsonb(s),to_jsonb(v),btrim(p_note),auth.uid()) returning id into result_id;
  return result_id;
end; $$;

create function public.trash_logistics_gps_event(p_kind text,p_event uuid,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare snapshot jsonb; result_id uuid;
begin
  if not public.can_view_logistics_gps() or auth.uid() is null then raise insufficient_privilege; end if;
  if p_reason is null or char_length(btrim(p_reason)) not between 1 and 1000 then raise exception 'Escribe el motivo (máximo 1000 caracteres).'; end if;
  if p_kind='visit' then
    select to_jsonb(v) into snapshot from public.logistics_gps_visits v where id=p_event for update;
    if exists(select 1 from public.logistics_gps_assignments where visit_id=p_event and revoked_at is null) then
      raise exception 'Quita la asignación al servicio antes de enviar esta visita a la papelera.';
    end if;
  elsif p_kind='stop' then
    select to_jsonb(s) into snapshot from public.logistics_gps_stops s where id=p_event for update;
  else raise exception 'Tipo de registro no válido.';
  end if;
  if snapshot is null then raise exception 'Registro GPS no disponible.'; end if;
  if exists(select 1 from public.logistics_gps_trash where restored_at is null and
      (visit_id=p_event and p_kind='visit' or stop_id=p_event and p_kind='stop')) then
    raise exception 'El registro ya está en la papelera.';
  end if;
  insert into public.logistics_gps_trash(visit_id,stop_id,event_snapshot,reason,discarded_by)
    values(case when p_kind='visit' then p_event end,case when p_kind='stop' then p_event end,snapshot,btrim(p_reason),auth.uid())
    returning id into result_id;
  return result_id;
end; $$;
create function public.restore_logistics_gps_event(p_trash uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  if not public.can_view_logistics_gps() or auth.uid() is null then raise insufficient_privilege; end if;
  update public.logistics_gps_trash set restored_at=now(),restored_by=auth.uid() where id=p_trash and restored_at is null;
  if not found then raise exception 'La papelera cambió. Actualiza antes de continuar.'; end if;
end; $$;
revoke all on function public.assign_logistics_gps_visit(uuid,uuid,uuid,text),public.trash_logistics_gps_event(text,uuid,text),public.restore_logistics_gps_event(uuid) from public,anon;
grant execute on function public.assign_logistics_gps_visit(uuid,uuid,uuid,text),public.trash_logistics_gps_event(text,uuid,text),public.restore_logistics_gps_event(uuid) to authenticated;
commit;
