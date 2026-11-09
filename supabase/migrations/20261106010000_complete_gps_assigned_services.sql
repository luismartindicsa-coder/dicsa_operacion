begin;

-- Complete the service atomically with the GPS assignment. Unlinking does not reopen it.
create or replace function public.assign_logistics_gps_visit(p_service uuid,p_visit uuid,p_expected uuid default null,p_note text default '')
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
  if current_id is not null and exists(select 1 from public.logistics_gps_assignments where id=current_id and visit_id=p_visit) then
    update public.services set status='completado' where id=p_service and status is distinct from 'completado';
    return current_id;
  end if;
  update public.logistics_gps_assignments set revoked_at=now(),revoked_by=auth.uid() where id=current_id;
  insert into public.logistics_gps_assignments(service_id,visit_id,service_snapshot,visit_snapshot,note,assigned_by)
    values(p_service,p_visit,to_jsonb(s),to_jsonb(v),btrim(p_note),auth.uid()) returning id into result_id;
  update public.services set status='completado' where id=p_service and status is distinct from 'completado';
  return result_id;
end; $$;


-- Reconcile existing active assignments without reopening cancelled services.
update public.services s set status='completado'
where s.area='LOGISTICA' and s.status is distinct from 'completado'
  and s.status is distinct from 'cancelado'
  and exists(select 1 from public.logistics_gps_assignments a where a.service_id=s.id and a.revoked_at is null);

commit;
