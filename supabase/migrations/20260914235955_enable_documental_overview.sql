begin;

-- Derived dates only: no calendar rows or duplicate document data are stored.
create function public.documental_event_dates(r public.documental_records)
returns table(event_kind text,event_date date)
language sql immutable set search_path=public,pg_temp as $$
  select e.kind,e.day from (values
    ('vencimiento',r.expiration_date),
    ('inicio',r.start_date),
    ('renovacion',case when r.category in ('contratos','seguros') and r.renewal_type<>'No aplica' then r.renewal_date end),
    ('programacion',case when r.category in ('mantenimiento','auditorias') then r.scheduled_date end),
    ('realizacion',case when r.category in ('mantenimiento','auditorias') then r.performed_date end)
  ) e(kind,day) where e.day is not null;
$$;
revoke all on function public.documental_event_dates(public.documental_records) from public,anon,authenticated;

create function public.documental_dashboard() returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare ctx jsonb; today date; result jsonb;
begin
  if not public.documental_can_manage() then raise exception 'No tienes acceso a Gestión Documental.' using errcode='42501'; end if;
  ctx:=public.documental_context(); today:=(ctx->>'today')::date;
  with base as materialized (
    select r.*,r.status in ('Pendiente','En proceso') as active from public.documental_records r
  ), totals as (
    select count(*) filter(where active) as active,
      count(*) filter(where active and expiration_date between today and today+15) as upcoming,
      count(*) filter(where active and expiration_date between today and today+5) as critical,
      count(*) filter(where active and expiration_date<today) as expired,
      count(*) filter(where category='permisos-y-tramites' and status='Pendiente') as pending_procedures,
      count(*) filter(where category='permisos-y-tramites' and status='En proceso') as in_progress_procedures from base
  ), categories as (
    select category,count(*) as total,
      count(*) filter(where active and expiration_date between today and today+15) as upcoming,
      count(*) filter(where active and expiration_date<today) as expired,
      count(*) filter(where active) as pending from base group by category
  ), dates as materialized (
    select r.id,r.category,r.title,r.document_type,r.responsible_user_id,r.reference,r.status,r.priority,r.revision,r.expiration_date,e.event_kind,e.event_date
    from public.documental_records r cross join lateral public.documental_event_dates(r) e
    where r.status in ('Pendiente','En proceso') and e.event_kind<>'realizacion'
      and e.event_date>=today and e.event_date<today+30
  ), upcoming as (
    select * from dates order by event_date,lower(title),reference,id,event_kind limit 12
  ) select jsonb_build_object(
    'context',ctx,'metrics',(select to_jsonb(t) from totals t),
    'categories',coalesce((select jsonb_object_agg(category,to_jsonb(c)-'category') from categories c),'{}'::jsonb),
    'upcoming',coalesce((select jsonb_agg(jsonb_build_object('event_kind',u.event_kind,'event_date',u.event_date,'record',to_jsonb(u)-'event_kind'-'event_date')) from upcoming u),'[]'::jsonb),
    'upcoming_total',(select count(*) from dates)) into result;
  return result;
end; $$;
revoke all on function public.documental_dashboard() from public,anon;
grant execute on function public.documental_dashboard() to authenticated;

create function public.documental_calendar(p_month date default null,p_selected date default null,
  p_category text default null,p_status text default null,p_responsible uuid default null,p_event_kind text default null,p_page integer default 0)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare ctx jsonb; today date; month_start date; month_end date; selected_day date; result jsonb;
begin
  if not public.documental_can_manage() then raise exception 'No tienes acceso a Gestión Documental.' using errcode='42501'; end if;
  ctx:=public.documental_context(); today:=(ctx->>'today')::date;
  month_start:=date_trunc('month',coalesce(p_month,p_selected,today))::date;
  month_end:=(month_start+interval '1 month')::date;
  selected_day:=coalesce(p_selected,case when today>=month_start and today<month_end then today else month_start end);
  if selected_day<month_start or selected_day>=month_end then raise exception 'La fecha seleccionada debe pertenecer al mes mostrado.' using errcode='23514'; end if;
  if p_category is not null and p_category not in ('documentacion-legal','permisos-y-tramites','seguridad-e-higiene','medio-ambiente','vehiculos','personal','proteccion-civil','contratos','seguros','mantenimiento','auditorias') then
    raise exception 'Categoría no válida.' using errcode='23514';
  end if;
  if p_status is not null and p_status not in ('Pendiente','En proceso','Completado','Cancelado','No aplica') then raise exception 'Estatus no válido.' using errcode='23514'; end if;
  if p_event_kind is not null and p_event_kind not in ('vencimiento','inicio','renovacion','programacion','realizacion') then raise exception 'Tipo de fecha no válido.' using errcode='23514'; end if;
  if coalesce(p_page,0)<0 then raise exception 'Página no válida.' using errcode='23514'; end if;
  with filtered as materialized (
    select r.id,r.category,r.title,r.document_type,r.responsible_user_id,r.reference,r.status,r.priority,r.revision,r.expiration_date,e.event_kind,e.event_date
    from public.documental_records r cross join lateral public.documental_event_dates(r) e
    where e.event_date>=month_start and e.event_date<month_end
      and (p_category is null or r.category=p_category) and (p_status is null or r.status=p_status)
      and (p_responsible is null or r.responsible_user_id=p_responsible)
      and (p_event_kind is null or e.event_kind=p_event_kind)
  ), days as (
    select event_date,count(*) as count from filtered group by event_date
  ), agenda as (
    select * from filtered where event_date=selected_day
    order by lower(title),reference,id,event_kind limit 50 offset coalesce(p_page,0)::bigint*50
  ) select jsonb_build_object('context',ctx,'month',month_start,'selected',selected_day,
    'days',coalesce((select jsonb_object_agg(event_date,count) from days),'{}'::jsonb),
    'month_total',(select count(*) from filtered),
    'total',(select count(*) from filtered where event_date=selected_day),
    'events',coalesce((select jsonb_agg(jsonb_build_object('event_kind',a.event_kind,'event_date',a.event_date,'record',to_jsonb(a)-'event_kind'-'event_date')) from agenda a),'[]'::jsonb)) into result;
  return result;
end; $$;
revoke all on function public.documental_calendar(date,date,text,text,uuid,text,integer) from public,anon;
grant execute on function public.documental_calendar(date,date,text,text,uuid,text,integer) to authenticated;
notify pgrst,'reload schema';
commit;
