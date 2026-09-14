begin;

-- First operational category. Files remain in the existing Supabase Storage.
create table public.documental_records (
  id uuid primary key,
  category text not null default 'documentacion-legal',
  title text not null check (length(btrim(title)) between 1 and 300),
  document_type text not null check (length(btrim(document_type)) between 1 and 100),
  responsible_user_id uuid not null references auth.users(id) on delete restrict,
  department text not null default '',
  authority text not null default '',
  reference text not null default '',
  status text not null check (status in ('Pendiente','En proceso','Completado','Cancelado','No aplica')),
  priority text not null check (priority in ('Urgente','Alta','Media','Baja')),
  issue_date date,
  start_date date,
  expiration_date date,
  observations text not null default '',
  next_action text not null default '',
  revision integer not null default 1 check (revision > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  updated_by uuid not null references auth.users(id),
  check (expiration_date is null or start_date is null or expiration_date >= start_date)
);
create index documental_records_category_order on public.documental_records(category,created_at desc,reference,id);
create index documental_records_expiration on public.documental_records(category,expiration_date);
create index documental_records_responsible on public.documental_records(responsible_user_id);

create table public.documental_files (
  id uuid primary key default gen_random_uuid(),
  record_id uuid not null references public.documental_records(id) on delete restrict,
  role text not null check (role in ('principal','complementario')),
  file_name text not null check (length(btrim(file_name)) between 1 and 500),
  mime_type text not null,
  size_bytes bigint not null check (size_bytes between 0 and 52428800),
  storage_path text not null unique,
  revision integer not null,
  is_current boolean not null default true,
  uploaded_at timestamptz not null default now(),
  uploaded_by uuid not null references auth.users(id)
);
create unique index documental_one_current_principal on public.documental_files(record_id)
  where is_current and role='principal';
create index documental_files_record on public.documental_files(record_id,revision desc);

create table public.documental_history (
  id uuid primary key default gen_random_uuid(),
  record_id uuid not null references public.documental_records(id) on delete restrict,
  revision integer not null,
  request_id uuid not null unique,
  actor_id uuid not null references auth.users(id),
  actor_name text not null,
  event text not null,
  snapshot jsonb not null,
  created_at timestamptz not null default now(),
  unique(record_id,revision)
);

create function public.documental_can_manage() returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists(select 1 from public.profiles p where p.user_id=auth.uid()
    and p.is_active and (
      lower(p.role::text) in ('direccion','direction','direccion_general','auxiliar_direccion','admin')
      or lower(p.role::text) like 'direccion\_%' escape '\'
      or lower(p.role::text) like '%\_direccion' escape '\'
    ));
$$;
revoke all on function public.documental_can_manage() from public;
grant execute on function public.documental_can_manage() to authenticated;

alter table public.documental_records enable row level security;
alter table public.documental_files enable row level security;
alter table public.documental_history enable row level security;
revoke all on public.documental_records,public.documental_files,public.documental_history from anon,authenticated;
grant select on public.documental_records,public.documental_files,public.documental_history to authenticated;
create policy documental_records_read on public.documental_records for select to authenticated using(public.documental_can_manage());
create policy documental_files_read on public.documental_files for select to authenticated using(public.documental_can_manage());
create policy documental_history_read on public.documental_history for select to authenticated using(public.documental_can_manage());

insert into storage.buckets(id,name,public,file_size_limit)
values ('documental','documental',false,52428800);

-- Restrictive policies also constrain any older, broadly permissive policies.
create policy documental_storage_read on storage.objects for select to authenticated
using(bucket_id='documental' and public.documental_can_manage());
create policy documental_storage_read_guard on storage.objects as restrictive for select to authenticated
using(bucket_id<>'documental' or public.documental_can_manage());
create policy documental_storage_no_anon on storage.objects as restrictive for all to anon
using(bucket_id<>'documental') with check(bucket_id<>'documental');
create policy documental_storage_insert on storage.objects for insert to authenticated
with check(bucket_id='documental' and public.documental_can_manage() and split_part(name,'/',1)=auth.uid()::text);
create policy documental_storage_insert_guard on storage.objects as restrictive for insert to authenticated
with check(bucket_id<>'documental' or (public.documental_can_manage() and split_part(name,'/',1)=auth.uid()::text));
create policy documental_storage_immutable on storage.objects as restrictive for update to authenticated
using(bucket_id<>'documental') with check(bucket_id<>'documental');
create policy documental_storage_cleanup on storage.objects for delete to authenticated
using(bucket_id='documental' and public.documental_can_manage() and split_part(name,'/',1)=auth.uid()::text
  and not exists(select 1 from public.documental_files f where f.storage_path=name));
create policy documental_storage_delete_guard on storage.objects as restrictive for delete to authenticated
using(bucket_id<>'documental' or (public.documental_can_manage() and split_part(name,'/',1)=auth.uid()::text
  and not exists(select 1 from public.documental_files f where f.storage_path=name)));

create function public.documental_context() returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if not public.documental_can_manage() then
    raise exception 'No tienes acceso a Gestión Documental.' using errcode='42501';
  end if;
  return jsonb_build_object(
    'today',(now() at time zone 'America/Mexico_City')::date,
    'seconds_to_midnight',extract(epoch from (
      (((now() at time zone 'America/Mexico_City')::date+1)::timestamp at time zone 'America/Mexico_City')-now())),
    'responsibles',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'label',
      coalesce(nullif(btrim(u.raw_user_meta_data->>'full_name'),''),nullif(btrim(u.raw_user_meta_data->>'name'),''),u.email,u.id::text))
      order by coalesce(u.raw_user_meta_data->>'full_name',u.email,u.id::text))
      from auth.users u where exists(select 1 from public.profiles p where p.user_id=u.id and p.is_active)),'[]'::jsonb)
  );
end; $$;

create function public.documental_get_record(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare r public.documental_records;
begin
  if not public.documental_can_manage() then
    raise exception 'No tienes acceso a Gestión Documental.' using errcode='42501';
  end if;
  select * into r from public.documental_records where id=p_id;
  if not found then raise exception 'El documento no existe.' using errcode='P0002'; end if;
  return jsonb_build_object('record',to_jsonb(r),
    'files',coalesce((select jsonb_agg(to_jsonb(f) order by f.revision desc,f.uploaded_at desc) from public.documental_files f where f.record_id=p_id),'[]'::jsonb),
    'history',coalesce((select jsonb_agg(to_jsonb(h) order by h.revision desc) from public.documental_history h where h.record_id=p_id),'[]'::jsonb));
end; $$;

-- One atomic, idempotent save. Uploads use new paths before this RPC. Old files
-- and snapshots remain immutable; stale editors cannot overwrite newer saves.
create function public.documental_save_record(
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
      raise exception 'El expediente cambió. Cierra y vuelve a abrirlo antes de guardar.' using errcode='40001';
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

create function public.documental_list_records(p_search text default '',p_status text default null,p_type text default null,
  p_responsible uuid default null,p_urgency text default null,p_page integer default 0,p_sort text default 'recent') returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare result jsonb;
begin
  if not public.documental_can_manage() then raise exception 'No tienes acceso a Gestión Documental.' using errcode='42501'; end if;
  with filtered as materialized (
    select id,title,document_type,responsible_user_id,reference,status,priority,issue_date,start_date,expiration_date,revision,created_at
    from public.documental_records r
    where category='documentacion-legal'
      and (coalesce(p_search,'')='' or concat_ws(' ',title,reference,authority,department) ilike '%'||p_search||'%')
      and (p_status is null or status=p_status) and (p_type is null or document_type=p_type)
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
revoke all on function public.documental_list_records(text,text,text,uuid,text,integer,text) from public;
grant execute on function public.documental_list_records(text,text,text,uuid,text,integer,text) to authenticated;

revoke all on function public.documental_context(),public.documental_get_record(uuid),public.documental_save_record(uuid,integer,uuid,jsonb,jsonb,uuid[]) from public;
grant execute on function public.documental_context(),public.documental_get_record(uuid),public.documental_save_record(uuid,integer,uuid,jsonb,jsonb,uuid[]) to authenticated;

do $$ begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    alter publication supabase_realtime add table public.documental_records;
  end if;
end; $$;
notify pgrst,'reload schema';
commit;
