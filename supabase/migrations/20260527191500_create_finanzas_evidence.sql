create table if not exists public.finanzas_evidence (
  id text primary key,
  owner_type text not null,
  owner_id text not null,
  file_url text not null,
  storage_path text,
  file_name text not null,
  mime_type text not null default 'application/octet-stream',
  comment text,
  uploaded_by uuid,
  uploaded_by_name text,
  uploaded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists finanzas_evidence_owner_idx
  on public.finanzas_evidence (owner_type, owner_id, uploaded_at desc);

drop trigger if exists trg_finanzas_evidence_updated_at
on public.finanzas_evidence;
create trigger trg_finanzas_evidence_updated_at
before update on public.finanzas_evidence
for each row execute function public.set_updated_at_v2();

alter table public.finanzas_evidence enable row level security;

grant select, insert, update, delete on public.finanzas_evidence to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'finanzas_evidence'
      and policyname = 'finanzas_evidence_authenticated_all'
  ) then
    create policy finanzas_evidence_authenticated_all
      on public.finanzas_evidence
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

insert into storage.buckets (id, name, public)
select 'finanzas_evidence', 'finanzas_evidence', true
where not exists (select 1 from storage.buckets where id = 'finanzas_evidence');

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'finanzas_evidence_authenticated_read'
  ) then
    create policy finanzas_evidence_authenticated_read
      on storage.objects
      for select
      to authenticated
      using (bucket_id = 'finanzas_evidence');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'finanzas_evidence_authenticated_write'
  ) then
    create policy finanzas_evidence_authenticated_write
      on storage.objects
      for insert
      to authenticated
      with check (bucket_id = 'finanzas_evidence');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'finanzas_evidence_authenticated_update'
  ) then
    create policy finanzas_evidence_authenticated_update
      on storage.objects
      for update
      to authenticated
      using (bucket_id = 'finanzas_evidence')
      with check (bucket_id = 'finanzas_evidence');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'finanzas_evidence_authenticated_delete'
  ) then
    create policy finanzas_evidence_authenticated_delete
      on storage.objects
      for delete
      to authenticated
      using (bucket_id = 'finanzas_evidence');
  end if;
end
$$;
