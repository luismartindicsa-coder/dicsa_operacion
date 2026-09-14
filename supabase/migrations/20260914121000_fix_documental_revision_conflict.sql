begin;

-- A stale revision is an HTTP 409 business conflict, not a retryable PostgreSQL
-- serialization failure. PostgREST retries SQLSTATE 40001 indefinitely.
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
  if coalesce(p_record->>'category','documentacion-legal')<>'documentacion-legal' then
    raise exception 'Esta categoría todavía no está habilitada.';
  end if;
  if not exists(select 1 from public.profiles p where p.user_id=(p_record->>'responsible_user_id')::uuid and p.is_active) then
    raise exception 'Selecciona un responsable activo.' using errcode='23514';
  end if;
  if p_record->>'document_type' not in ('Acta constitutiva','Constancia de situación fiscal','Contrato constitutivo','Documento corporativo','Documento notarial','Escritura','Identificación legal','Modificación societaria','Poder notarial') then
    raise exception 'Selecciona un tipo documental válido.' using errcode='23514';
  end if;
  insert into public.documental_records(id,category,title,document_type,responsible_user_id,department,authority,reference,status,priority,
    issue_date,start_date,expiration_date,observations,next_action,revision,created_by,updated_by)
  values(p_id,'documentacion-legal',btrim(p_record->>'title'),p_record->>'document_type',(p_record->>'responsible_user_id')::uuid,
    btrim(coalesce(p_record->>'department','')),btrim(coalesce(p_record->>'authority','')),btrim(coalesce(p_record->>'reference','')),
    p_record->>'status',p_record->>'priority',nullif(p_record->>'issue_date','')::date,nullif(p_record->>'start_date','')::date,
    nullif(p_record->>'expiration_date','')::date,coalesce(p_record->>'observations',''),coalesce(p_record->>'next_action',''),v_revision,auth.uid(),auth.uid())
  on conflict(id) do update set title=excluded.title,document_type=excluded.document_type,responsible_user_id=excluded.responsible_user_id,
    department=excluded.department,authority=excluded.authority,reference=excluded.reference,status=excluded.status,priority=excluded.priority,
    issue_date=excluded.issue_date,start_date=excluded.start_date,expiration_date=excluded.expiration_date,observations=excluded.observations,
    next_action=excluded.next_action,revision=v_revision,updated_at=now(),updated_by=auth.uid();
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
    case when v_revision=1 then 'Documento registrado' when exists(select 1 from jsonb_array_elements(p_files) e where e->>'role'='principal') then 'Documento principal sustituido' else 'Expediente actualizado' end,
    jsonb_build_object('record',to_jsonb(d),'files',coalesce((select jsonb_agg(to_jsonb(df)) from public.documental_files df where df.record_id=p_id and df.is_current),'[]'::jsonb))
  from public.documental_records d where d.id=p_id;
  return public.documental_get_record(p_id);
end; $$;

notify pgrst,'reload schema';
commit;
