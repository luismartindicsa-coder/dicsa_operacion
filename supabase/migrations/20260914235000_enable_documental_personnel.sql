begin;

create or replace function public.documental_save_record(
  p_id uuid, p_expected_revision integer, p_request_id uuid, p_record jsonb,
  p_files jsonb default '[]'::jsonb, p_retire_file_ids uuid[] default '{}'::uuid[]
) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  r public.documental_records;
  f jsonb;
  prior public.documental_history;
  v_revision integer;
  v_actor_name text;
  v_size bigint;
  v_path text;
  v_category text:=coalesce(p_record->>'category','documentacion-legal');
  v_progress smallint;
  v_employee uuid;
  v_employee_name text:='';
  v_study text:='';
  v_provider text:='';
  v_periodicity text:='';
  v_authorization text:='';
  v_installation text:='';
  v_vehicle uuid;
  v_vehicle_label text:='';
begin
  if not public.documental_can_manage() then
    raise exception 'No tienes acceso a Gestión Documental.' using errcode='42501';
  end if;
  if p_id is null or p_request_id is null then raise exception 'Falta identidad de la solicitud.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_id::text,0));
  select * into prior from public.documental_history where request_id=p_request_id;
  if found then
    if prior.record_id<>p_id or prior.actor_id<>auth.uid() then
      raise exception 'Solicitud no válida.' using errcode='42501';
    end if;
    return public.documental_get_record(p_id);
  end if;
  select * into r from public.documental_records where id=p_id for update;
  if found then
    if p_expected_revision is distinct from r.revision then
      raise exception 'El expediente cambió. Cierra y vuelve a abrirlo antes de guardar.' using errcode='PT409';
    end if;
    v_revision:=r.revision+1;
  else
    if coalesce(p_expected_revision,0)<>0 then raise exception 'El documento no existe.' using errcode='P0002'; end if;
    v_revision:=1;
  end if;
  if v_category not in ('documentacion-legal','permisos-y-tramites','seguridad-e-higiene','medio-ambiente','vehiculos','personal') then
    raise exception 'Esta categoría todavía no está habilitada.' using errcode='23514';
  end if;
  if r.id is not null and r.category<>v_category then
    raise exception 'No se puede cambiar la categoría de un expediente.' using errcode='23514';
  end if;
  if v_category in ('permisos-y-tramites','seguridad-e-higiene','medio-ambiente','vehiculos','personal') then
    if coalesce(p_record->>'progress_percentage','') !~ '^[0-9]{1,3}$' then
      raise exception 'Captura un avance de 0 a 100.' using errcode='23514';
    end if;
    v_progress:=(p_record->>'progress_percentage')::smallint;
    if v_progress>100 then raise exception 'Captura un avance de 0 a 100.' using errcode='23514'; end if;
  else
    v_progress:=coalesce(r.progress_percentage,0);
  end if;
  if not exists(select 1 from public.profiles p where p.user_id=(p_record->>'responsible_user_id')::uuid and p.is_active) then
    raise exception 'Selecciona un responsable activo.' using errcode='23514';
  end if;
  if v_category='documentacion-legal' and p_record->>'document_type' not in ('Acta constitutiva','Constancia de situación fiscal','Contrato constitutivo','Documento corporativo','Documento notarial','Escritura','Identificación legal','Modificación societaria','Poder notarial') then
    raise exception 'Selecciona un tipo documental válido.' using errcode='23514';
  end if;
  if v_category='permisos-y-tramites' and coalesce(p_record->>'document_type','') not in ('Expediente','Licencia','Permiso','Renovación','Trámite') then
    raise exception 'Selecciona un tipo de gestión válido.' using errcode='23514';
  end if;
  if v_category in ('seguridad-e-higiene','personal') then
    v_employee:=nullif(p_record->>'related_employee_id','')::uuid;
    if v_employee is not null then
      select e.full_name into v_employee_name from public.employees e
      where e.id=v_employee and (v_category='personal' or e.is_active or r.related_employee_id=v_employee);
      if not found then
        if v_category='personal' then raise exception 'El trabajador ya no está disponible. Vuelve a seleccionarlo.' using errcode='23514'; end if;
        raise exception 'Selecciona un trabajador activo.' using errcode='23514';
      end if;
    end if;
  end if;
  if v_category='personal' and coalesce(p_record->>'document_type','') not in ('Certificación','Constancia','Contrato laboral','Documento laboral','Identificación','Licencia') then
    raise exception 'Selecciona un tipo de documento de personal válido.' using errcode='23514';
  end if;
  if v_category='seguridad-e-higiene' then
    if coalesce(p_record->>'document_type','') not in ('Capacitación','DC3','Dictamen','Documentación STPS','Equipo','Estudio','Inspección','Obligación','Programa') then
      raise exception 'Selecciona un tipo de registro válido.' using errcode='23514';
    end if;
    v_study:=btrim(coalesce(p_record->>'study_type',''));
    v_provider:=btrim(coalesce(p_record->>'provider_name',''));
    v_periodicity:=btrim(coalesce(p_record->>'periodicity',''));
    if v_study not in ('','Condiciones térmicas','Ergonomía','Iluminación','Otro','Ruido','Sustancias químicas','Vibraciones') then
      raise exception 'Selecciona un tipo de estudio válido.' using errcode='23514';
    end if;
    if v_periodicity not in ('','Anual','Bimestral','Mensual','Por evento','Semestral','Sin periodicidad','Trimestral','Única') then
      raise exception 'Selecciona una periodicidad válida.' using errcode='23514';
    end if;
  end if;
  if v_category='medio-ambiente' then
    if coalesce(p_record->>'document_type','') not in ('Agua','Autorización','Emisiones','Estudio','Licencia','Manifiesto','Permiso','Residuos') then
      raise exception 'Selecciona un tipo de registro ambiental válido.' using errcode='23514';
    end if;
    v_authorization:=btrim(coalesce(p_record->>'authorization_number',''));
    v_installation:=btrim(coalesce(p_record->>'installation_name',''));
  end if;
  if v_category='vehiculos' then
    if coalesce(p_record->>'document_type','') not in ('Licencia relacionada','Mantenimiento documental','Permiso','Seguro','Tarjeta de circulación','Tenencia','Verificación') then
      raise exception 'Selecciona un tipo de documento vehicular válido.' using errcode='23514';
    end if;
    v_vehicle:=nullif(p_record->>'vehicle_id','')::uuid;
    if v_vehicle is not null then
      select coalesce(nullif(concat_ws(' · ',nullif(btrim(v.code),''),
        case when btrim(coalesce(v.nickname,''))<>btrim(coalesce(v.code,'')) then nullif(btrim(v.nickname),'') end,
        nullif(btrim(v.plate),'')),''),v.id::text) into v_vehicle_label from public.vehicles v where v.id=v_vehicle;
      if not found then raise exception 'La unidad ya no está disponible. Vuelve a seleccionarla.' using errcode='23514'; end if;
    end if;
  end if;
  insert into public.documental_records(id,category,title,document_type,responsible_user_id,department,authority,reference,status,priority,
    issue_date,start_date,expiration_date,observations,next_action,revision,created_by,updated_by,progress_percentage,related_employee_id,related_employee_name,study_type,provider_name,periodicity,authorization_number,installation_name,vehicle_id,vehicle_label)
  values(p_id,v_category,btrim(p_record->>'title'),p_record->>'document_type',(p_record->>'responsible_user_id')::uuid,
    btrim(coalesce(p_record->>'department','')),btrim(coalesce(p_record->>'authority','')),btrim(coalesce(p_record->>'reference','')),
    p_record->>'status',p_record->>'priority',nullif(p_record->>'issue_date','')::date,nullif(p_record->>'start_date','')::date,
    nullif(p_record->>'expiration_date','')::date,coalesce(p_record->>'observations',''),coalesce(p_record->>'next_action',''),v_revision,auth.uid(),auth.uid(),v_progress,v_employee,v_employee_name,v_study,v_provider,v_periodicity,v_authorization,v_installation,v_vehicle,v_vehicle_label)
  on conflict(id) do update set title=excluded.title,document_type=excluded.document_type,responsible_user_id=excluded.responsible_user_id,
    department=excluded.department,authority=excluded.authority,reference=excluded.reference,status=excluded.status,priority=excluded.priority,
    issue_date=excluded.issue_date,start_date=excluded.start_date,expiration_date=excluded.expiration_date,observations=excluded.observations,
    next_action=excluded.next_action,progress_percentage=excluded.progress_percentage,
    related_employee_id=excluded.related_employee_id,related_employee_name=excluded.related_employee_name,study_type=excluded.study_type,provider_name=excluded.provider_name,periodicity=excluded.periodicity,
    authorization_number=excluded.authorization_number,installation_name=excluded.installation_name,vehicle_id=excluded.vehicle_id,vehicle_label=excluded.vehicle_label,revision=v_revision,updated_at=now(),updated_by=auth.uid();
  if jsonb_typeof(p_files)<>'array' or jsonb_array_length(p_files)>30 then raise exception 'Adjuntos no válidos.'; end if;
  if (select count(*) from jsonb_array_elements(p_files) e where e->>'role'='principal')>1 then raise exception 'Selecciona un solo documento principal.'; end if;
  update public.documental_files set is_current=false where record_id=p_id and id=any(p_retire_file_ids) and role='complementario';
  for f in select * from jsonb_array_elements(p_files) loop
    v_path:=f->>'storage_path';
    if split_part(v_path,'/',1)<>auth.uid()::text or split_part(v_path,'/',2)<>p_id::text then
      raise exception 'El archivo no pertenece a esta captura.' using errcode='42501';
    end if;
    select (o.metadata->>'size')::bigint into v_size from storage.objects o where o.bucket_id='documental' and o.name=v_path;
    if not found then raise exception 'La carga del archivo no se ha completado.'; end if;
    if f->>'role'='principal' then update public.documental_files set is_current=false where record_id=p_id and role='principal' and is_current; end if;
    insert into public.documental_files(record_id,role,file_name,mime_type,size_bytes,storage_path,revision,uploaded_by)
    values(p_id,f->>'role',f->>'file_name',coalesce(f->>'mime_type','application/octet-stream'),coalesce(v_size,(f->>'size_bytes')::bigint),v_path,v_revision,auth.uid());
  end loop;
  select coalesce(nullif(u.raw_user_meta_data->>'full_name',''),u.email,u.id::text) into v_actor_name from auth.users u where u.id=auth.uid();
  insert into public.documental_history(record_id,revision,request_id,actor_id,actor_name,event,snapshot)
  select p_id,v_revision,p_request_id,auth.uid(),v_actor_name,
    case when v_revision=1 and v_category='permisos-y-tramites' then 'Trámite registrado' when v_revision=1 then 'Documento registrado' when exists(select 1 from jsonb_array_elements(p_files) e where e->>'role'='principal') then 'Documento principal sustituido' else 'Expediente actualizado' end,
    jsonb_build_object('record',to_jsonb(d),'files',coalesce((select jsonb_agg(to_jsonb(df)) from public.documental_files df where df.record_id=p_id and df.is_current),'[]'::jsonb))
  from public.documental_records d where d.id=p_id;
  return public.documental_get_record(p_id);
end; $$;

create or replace function public.documental_query_records(p_category text,p_search text default '',p_status text default null,p_type text default null,
  p_responsible uuid default null,p_urgency text default null,p_page integer default 0,p_sort text default 'recent',p_priority text default null) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare result jsonb;
begin
  if not public.documental_can_manage() then raise exception 'No tienes acceso a Gestión Documental.' using errcode='42501'; end if;
  if p_category not in ('documentacion-legal','permisos-y-tramites','seguridad-e-higiene','medio-ambiente','vehiculos','personal') or p_category is null then raise exception 'Categoría no habilitada.' using errcode='23514'; end if;
  with filtered as materialized (
    select id,category,title,document_type,authority,department,progress_percentage,related_employee_id,related_employee_name,study_type,provider_name,periodicity,authorization_number,installation_name,vehicle_id,vehicle_label,responsible_user_id,reference,status,priority,issue_date,start_date,expiration_date,revision,created_at
    from public.documental_records r
    where category=p_category
      and (coalesce(p_search,'')='' or concat_ws(' ',title,reference,authority,department,related_employee_name,provider_name,study_type,periodicity,authorization_number,installation_name,vehicle_id,vehicle_label) ilike '%'||p_search||'%')
      and (p_status is null or status=p_status) and (p_type is null or document_type=p_type)
      and (p_priority is null or priority=p_priority)
      and (p_responsible is null or responsible_user_id=p_responsible)
      and (p_urgency is null or p_urgency=case
        when status='Completado' then 'Completado'
        when expiration_date is null then 'Sin vencimiento'
        when expiration_date<(now() at time zone 'America/Mexico_City')::date then 'Vencido'
        when expiration_date-(now() at time zone 'America/Mexico_City')::date<=5 then 'Crítico'
        when expiration_date-(now() at time zone 'America/Mexico_City')::date<=15 then 'Atención'
        else 'En tiempo' end)
  ), page as (
    select * from filtered order by
      case when p_sort='name' then lower(title) end asc,
      case when p_sort='expiration' then expiration_date end asc nulls last,
      case when p_sort='recent' then created_at end desc,
      reference asc,id asc limit 50 offset greatest(coalesce(p_page,0),0)*50
  ) select jsonb_build_object('records',coalesce((select jsonb_agg(to_jsonb(p)) from page p),'[]'::jsonb),
    'total',(select count(*) from filtered)) into result;
  return result;
end; $$;
revoke all on function public.documental_query_records(text,text,text,text,uuid,text,integer,text,text) from public;
grant execute on function public.documental_query_records(text,text,text,text,uuid,text,integer,text,text) to authenticated;

-- Personal includes inactive workers so their employment files can be completed.
-- Expose only identity and active state; no parallel HR catalog or sensitive HR fields.
create or replace function public.documental_personnel_context() returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare result jsonb;
begin
  if not public.documental_can_manage() then raise exception 'No tienes acceso a Gestión Documental.' using errcode='42501'; end if;
  result:=public.documental_context();
  return result || jsonb_build_object('employees',coalesce((
    select jsonb_agg(jsonb_build_object('id',e.id,'label',e.full_name,'is_active',coalesce(e.is_active,false)) order by lower(e.full_name),e.id)
    from public.employees e
  ),'[]'::jsonb));
end; $$;
revoke all on function public.documental_personnel_context() from public;
grant execute on function public.documental_personnel_context() to authenticated;

-- Existing context, list and save signatures remain compatible with prior clients.
notify pgrst,'reload schema';
commit;
