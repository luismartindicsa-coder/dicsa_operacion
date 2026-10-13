begin;

create table public.hr_documentation (
  id uuid primary key,
  revision integer not null default 1 check (revision > 0),
  category text not null check (category in ('reglamento','manual','comisiones','telefono','laptop','unidad','vacaciones','finiquito','renuncia','recomendacion','acta','otros')),
  kind text not null check (kind in ('generated','uploaded','template')),
  title text not null check (length(trim(title)) between 1 and 240),
  document_date date not null,
  employee_id text,
  fields jsonb not null default '[]' check (jsonb_typeof(fields) = 'array' and jsonb_array_length(fields) <= 60),
  data jsonb not null default '{}' check (jsonb_typeof(data) = 'object'),
  body text not null default '' check (length(body) <= 100000),
  signatures jsonb not null default '[]' check (jsonb_typeof(signatures) = 'array' and jsonb_array_length(signatures) <= 8),
  file jsonb,
  archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  updated_by uuid not null references auth.users(id),
  check ((kind = 'uploaded' and file is not null and jsonb_typeof(file) = 'object')
    or (kind <> 'uploaded' and file is null and length(trim(body)) > 0))
);
create index hr_documentation_category_date_idx on public.hr_documentation(category, document_date desc, id);
create table public.hr_documentation_revisions (
  document_id uuid not null references public.hr_documentation(id),
  revision integer not null,
  request_id uuid not null unique,
  request_payload jsonb not null,
  snapshot jsonb not null,
  changed_at timestamptz not null default now(),
  changed_by uuid not null references auth.users(id),
  primary key(document_id, revision)
);
alter table public.hr_documentation enable row level security;
alter table public.hr_documentation_revisions enable row level security;
revoke all on public.hr_documentation, public.hr_documentation_revisions from anon, authenticated;
grant select on public.hr_documentation, public.hr_documentation_revisions to authenticated;
-- RH and Dirección share the same existing, server-validated access boundary.
create policy hr_documentation_read on public.hr_documentation for select to authenticated
  using (public.hr_can_access_loans());
create policy hr_documentation_revisions_read on public.hr_documentation_revisions for select to authenticated
  using (public.hr_can_access_loans());

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('hr_documentation', 'hr_documentation', false, 26214400,
  array['application/pdf','image/jpeg','image/png','application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict(id) do nothing;
create policy hr_documentation_files_read on storage.objects for select to authenticated
  using (bucket_id = 'hr_documentation' and public.hr_can_access_loans());
create policy hr_documentation_files_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'hr_documentation' and public.hr_can_access_loans()
    and split_part(name, '/', 1) = auth.uid()::text);
-- Stored files are immutable. Replacing a file creates a new object and keeps
-- the previous revision available; no overwrite/delete policy is granted.

create function public.hr_documentation_save(p_id uuid, p_expected_revision integer,
  p_request_id uuid, p_record jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  old public.hr_documentation;
  saved public.hr_documentation;
  prior public.hr_documentation_revisions;
  payload jsonb := jsonb_build_object('id',p_id,'revision',p_expected_revision,'record',p_record);
  field jsonb;
  attachment jsonb := nullif(p_record->'file','null'::jsonb);
begin
  if auth.uid() is null or not public.hr_can_access_loans() then
    raise exception 'Tu perfil no tiene acceso a Documentación RH.' using errcode = '42501';
  end if;
  if p_id is null or p_request_id is null or p_expected_revision is null or p_expected_revision < 0
    or jsonb_typeof(p_record) is distinct from 'object' then
    raise exception 'Datos de guardado incompletos.' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  perform pg_advisory_xact_lock(hashtextextended(p_id::text, 1));
  select * into prior from public.hr_documentation_revisions where request_id = p_request_id;
  if found then
    if prior.request_payload is distinct from payload or prior.changed_by <> auth.uid() then
      raise exception 'La solicitud ya se utilizó con otros datos.' using errcode = '22023';
    end if;
    return prior.snapshot;
  end if;
  select * into old from public.hr_documentation where id = p_id for update;
  if (old.id is null and p_expected_revision <> 0) or
     (old.id is not null and old.revision <> p_expected_revision) then
    raise exception 'El documento cambió en otra sesión. Cierra el editor y vuelve a abrirlo.' using errcode = '40001';
  end if;
  if old.id is not null and (old.kind <> p_record->>'kind' or old.category <> p_record->>'category') then
    raise exception 'El tipo y la sección del documento no se pueden cambiar.' using errcode = '22023';
  end if;
  if jsonb_typeof(p_record->'fields') is distinct from 'array'
    or jsonb_typeof(p_record->'data') is distinct from 'object'
    or jsonb_typeof(p_record->'signatures') is distinct from 'array'
    or length(p_record::text) > 1500000 then
    raise exception 'Revisa los datos del documento.' using errcode = '22023';
  end if;
  for field in select value from jsonb_array_elements(p_record->'fields') loop
    if coalesce(field->>'key','') !~ '^[a-z][a-z0-9_]{0,39}$' or field->>'key' = 'fecha'
      or length(coalesce(field->>'label','')) not between 1 and 100
      or coalesce(field->>'type','') not in ('text','multiline','date','money','number')
      or jsonb_typeof(field->'required') is distinct from 'boolean' then
      raise exception 'Campo de plantilla inválido.' using errcode = '22023';
    end if;
  end loop;
  if (select count(*) <> count(distinct value->>'key') from jsonb_array_elements(p_record->'fields')) then
    raise exception 'Hay campos de plantilla repetidos.' using errcode = '22023';
  end if;
  if exists(select 1 from jsonb_each(p_record->'data') where jsonb_typeof(value) <> 'string' or length(value #>> '{}') > 100000) then
    raise exception 'Valores de documento inválidos.' using errcode = '22023';
  end if;
  for field in select value from jsonb_array_elements(p_record->'signatures') loop
    if jsonb_typeof(field->'label') is distinct from 'string' or jsonb_typeof(field->'name') is distinct from 'string'
      or length(field->>'label') > 100 or length(field->>'name') > 240 then
      raise exception 'Revisa los nombres y cargos de las firmas.' using errcode = '22023';
    end if;
  end loop;
  if p_record->>'kind' = 'template' and (p_record->'data' <> '{}'::jsonb or nullif(p_record->>'employee_id','') is not null
    or exists(select 1 from jsonb_array_elements(p_record->'signatures') where value->>'name' <> '')) then
    raise exception 'Las plantillas no guardan datos personales de la captura.' using errcode = '22023';
  end if;
  if attachment is not null and attachment is distinct from old.file then
    if split_part(coalesce(attachment->>'path',''), '/', 1) <> auth.uid()::text
      or split_part(attachment->>'path', '/', 2) <> p_id::text
      or coalesce(attachment->>'name','') = ''
      or coalesce((attachment->>'size')::bigint,0) not between 1 and 26214400
      or not exists (select 1 from storage.objects where bucket_id = 'hr_documentation' and name = attachment->>'path') then
      raise exception 'El archivo no está disponible para este documento.' using errcode = '22023';
    end if;
  end if;
  insert into public.hr_documentation as d(id, revision, category, kind, title, document_date,
    employee_id, fields, data, body, signatures, file, archived, created_by, updated_by)
  values(p_id, 1, p_record->>'category', p_record->>'kind', trim(p_record->>'title'),
    (p_record->>'document_date')::date, nullif(p_record->>'employee_id',''), p_record->'fields',
    p_record->'data', coalesce(p_record->>'body',''), p_record->'signatures', attachment,
    coalesce((p_record->>'archived')::boolean,false), auth.uid(), auth.uid())
  on conflict(id) do update set revision = d.revision + 1, title = excluded.title,
    document_date = excluded.document_date, employee_id = excluded.employee_id,
    fields = excluded.fields, data = excluded.data, body = excluded.body,
    signatures = excluded.signatures, file = excluded.file, archived = excluded.archived,
    updated_at = clock_timestamp(), updated_by = auth.uid()
  returning * into saved;
  insert into public.hr_documentation_revisions(document_id,revision,request_id,request_payload,snapshot,changed_by)
  values(p_id,saved.revision,p_request_id,payload,to_jsonb(saved),auth.uid());
  return to_jsonb(saved);
end;
$$;
revoke all on function public.hr_documentation_save(uuid,integer,uuid,jsonb) from public, anon;
grant execute on function public.hr_documentation_save(uuid,integer,uuid,jsonb) to authenticated;
commit;
