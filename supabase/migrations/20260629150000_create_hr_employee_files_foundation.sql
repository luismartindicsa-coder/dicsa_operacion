create table if not exists public.hr_employee_profiles (
  id text primary key,
  nombre text not null,
  empresa text not null,
  horario text not null,
  nss text not null,
  rfc text not null,
  curp text not null,
  fecha_ingreso date not null,
  telefono text not null,
  numero_cuenta text not null,
  calzado text not null,
  credito_declarado boolean,
  credito_detalle text,
  photo_file_url text,
  photo_storage_path text,
  photo_file_name text,
  photo_mime_type text,
  photo_uploaded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.hr_employee_documents (
  id text primary key,
  employee_id text not null references public.hr_employee_profiles(id) on delete cascade,
  category_key text not null,
  category_label text not null,
  title text not null,
  file_url text not null,
  storage_path text,
  file_name text not null,
  mime_type text not null default 'application/octet-stream',
  size_bytes bigint not null default 0,
  uploaded_by uuid,
  uploaded_by_name text,
  uploaded_at timestamptz not null default now(),
  is_required boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists hr_employee_documents_employee_idx
  on public.hr_employee_documents (employee_id, uploaded_at desc);

create index if not exists hr_employee_documents_category_idx
  on public.hr_employee_documents (category_key, employee_id);

drop trigger if exists trg_hr_employee_profiles_updated_at
on public.hr_employee_profiles;
create trigger trg_hr_employee_profiles_updated_at
before update on public.hr_employee_profiles
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_hr_employee_documents_updated_at
on public.hr_employee_documents;
create trigger trg_hr_employee_documents_updated_at
before update on public.hr_employee_documents
for each row execute function public.set_updated_at_v2();

alter table public.hr_employee_profiles enable row level security;
alter table public.hr_employee_documents enable row level security;

grant select, insert, update, delete on public.hr_employee_profiles to authenticated;
grant select, insert, update, delete on public.hr_employee_documents to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'hr_employee_profiles'
      and policyname = 'hr_employee_profiles_authenticated_all'
  ) then
    create policy hr_employee_profiles_authenticated_all
      on public.hr_employee_profiles
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'hr_employee_documents'
      and policyname = 'hr_employee_documents_authenticated_all'
  ) then
    create policy hr_employee_documents_authenticated_all
      on public.hr_employee_documents
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

insert into storage.buckets (id, name, public)
select 'hr_employee_files', 'hr_employee_files', true
where not exists (select 1 from storage.buckets where id = 'hr_employee_files');

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'hr_employee_files_authenticated_read'
  ) then
    create policy hr_employee_files_authenticated_read
      on storage.objects
      for select
      to authenticated
      using (bucket_id = 'hr_employee_files');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'hr_employee_files_authenticated_write'
  ) then
    create policy hr_employee_files_authenticated_write
      on storage.objects
      for insert
      to authenticated
      with check (bucket_id = 'hr_employee_files');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'hr_employee_files_authenticated_update'
  ) then
    create policy hr_employee_files_authenticated_update
      on storage.objects
      for update
      to authenticated
      using (bucket_id = 'hr_employee_files')
      with check (bucket_id = 'hr_employee_files');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'hr_employee_files_authenticated_delete'
  ) then
    create policy hr_employee_files_authenticated_delete
      on storage.objects
      for delete
      to authenticated
      using (bucket_id = 'hr_employee_files');
  end if;
end
$$;
