begin;

-- Enums (idempotent)
do $$
begin
  if not exists (select 1 from pg_type where typname = 'maintenance_status') then
    create type public.maintenance_status as enum (
      'aviso_falla',
      'revision_area',
      'reporte_mantenimiento',
      'cotizacion',
      'autorizacion_finanzas',
      'material_recolectado',
      'programado',
      'mantenimiento_realizado',
      'supervision',
      'cerrado',
      'rechazado'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'maintenance_priority') then
    create type public.maintenance_priority as enum ('alta', 'media', 'baja');
  end if;

  if not exists (select 1 from pg_type where typname = 'maintenance_type') then
    create type public.maintenance_type as enum ('preventivo', 'correctivo', 'mejora');
  end if;

  if not exists (select 1 from pg_type where typname = 'maintenance_category') then
    create type public.maintenance_category as enum (
      'mecanica',
      'electrica',
      'hidraulica',
      'neumatica',
      'electronica',
      'otros'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'maintenance_impact') then
    create type public.maintenance_impact as enum (
      'paro_total',
      'paro_parcial',
      'sin_impacto'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'provider_type') then
    create type public.provider_type as enum ('interno', 'externo');
  end if;

  if not exists (select 1 from pg_type where typname = 'material_source') then
    create type public.material_source as enum ('almacen', 'compra', 'proveedor');
  end if;

  if not exists (select 1 from pg_type where typname = 'evidence_category') then
    create type public.evidence_category as enum (
      'antes',
      'durante',
      'despues',
      'facturas',
      'otros'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'approval_step') then
    create type public.approval_step as enum (
      'area',
      'mantenimiento',
      'verificacion',
      'direccion'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'approval_status') then
    create type public.approval_status as enum ('pendiente', 'aprobada', 'rechazada');
  end if;
end
$$;

create table if not exists public.maintenance_orders (
  id uuid primary key default gen_random_uuid(),
  ot_folio text not null unique,
  site_id uuid,
  status public.maintenance_status not null default 'aviso_falla',
  priority public.maintenance_priority not null default 'media',
  type public.maintenance_type not null default 'correctivo',
  category public.maintenance_category not null default 'otros',
  impact public.maintenance_impact not null default 'sin_impacto',
  area_id uuid,
  area_label text,
  equipment_id uuid,
  equipment_label text,
  equipment_serial text,
  requester_name text,
  requester_user_id uuid,
  provider_type public.provider_type not null default 'interno',
  provider_name text,
  provider_contact text,
  problem_description text,
  diagnosis text,
  work_summary text,
  assigned_to_user_id uuid,
  assigned_to_name text,
  assigned_at timestamptz,
  cost_estimated_total numeric(12,2),
  cost_actual_total numeric(12,2),
  requested_at timestamptz not null default now(),
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.maintenance_orders
  add column if not exists ot_folio text,
  add column if not exists site_id uuid,
  add column if not exists status public.maintenance_status default 'aviso_falla',
  add column if not exists priority public.maintenance_priority default 'media',
  add column if not exists type public.maintenance_type default 'correctivo',
  add column if not exists category public.maintenance_category default 'otros',
  add column if not exists impact public.maintenance_impact default 'sin_impacto',
  add column if not exists area_id uuid,
  add column if not exists area_label text,
  add column if not exists equipment_id uuid,
  add column if not exists equipment_label text,
  add column if not exists equipment_serial text,
  add column if not exists requester_name text,
  add column if not exists requester_user_id uuid,
  add column if not exists provider_type public.provider_type default 'interno',
  add column if not exists provider_name text,
  add column if not exists provider_contact text,
  add column if not exists problem_description text,
  add column if not exists diagnosis text,
  add column if not exists work_summary text,
  add column if not exists assigned_to_user_id uuid,
  add column if not exists assigned_to_name text,
  add column if not exists assigned_at timestamptz,
  add column if not exists cost_estimated_total numeric(12,2),
  add column if not exists cost_actual_total numeric(12,2),
  add column if not exists requested_at timestamptz default now(),
  add column if not exists created_by uuid,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

create table if not exists public.maintenance_tasks (
  id uuid primary key default gen_random_uuid(),
  ot_id uuid not null references public.maintenance_orders(id) on delete cascade,
  line_no int not null default 1,
  description text not null,
  unit text,
  qty numeric(12,3),
  is_done boolean not null default false,
  notes text,
  done_at timestamptz,
  done_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.maintenance_materials (
  id uuid primary key default gen_random_uuid(),
  ot_id uuid not null references public.maintenance_orders(id) on delete cascade,
  line_no int not null default 1,
  name text not null,
  qty numeric(12,3),
  source public.material_source not null default 'almacen',
  cost_estimated numeric(12,2),
  cost_actual numeric(12,2),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.maintenance_time_logs (
  id uuid primary key default gen_random_uuid(),
  ot_id uuid not null references public.maintenance_orders(id) on delete cascade,
  tech_user_id uuid,
  tech_name text,
  start_at timestamptz not null,
  end_at timestamptz,
  minutes int,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.maintenance_evidence (
  id uuid primary key default gen_random_uuid(),
  ot_id uuid not null references public.maintenance_orders(id) on delete cascade,
  category public.evidence_category not null default 'otros',
  file_url text not null,
  storage_path text,
  thumbnail_url text,
  uploaded_by uuid,
  uploaded_by_name text,
  uploaded_at timestamptz not null default now(),
  comment text
);

create table if not exists public.maintenance_approvals (
  id uuid primary key default gen_random_uuid(),
  ot_id uuid not null references public.maintenance_orders(id) on delete cascade,
  step public.approval_step not null,
  status public.approval_status not null default 'pendiente',
  by_user_id uuid,
  by_user_name text,
  at timestamptz,
  comment text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.maintenance_status_log (
  id uuid primary key default gen_random_uuid(),
  ot_id uuid not null references public.maintenance_orders(id) on delete cascade,
  from_status public.maintenance_status,
  to_status public.maintenance_status not null,
  changed_by uuid,
  changed_by_name text,
  changed_at timestamptz not null default now(),
  comment text
);

-- compatibility alias if legacy code expects maintenance_items
do $$
declare
  relkind_char "char";
begin
  select c.relkind
  into relkind_char
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'maintenance_items'
  limit 1;

  if relkind_char is null then
    execute $v$
      create view public.maintenance_items as
      select
        id,
        ot_id,
        line_no,
        description,
        unit,
        qty,
        is_done,
        notes,
        done_at,
        done_by,
        created_at,
        updated_at
      from public.maintenance_tasks
    $v$;
  elsif relkind_char = 'v' then
    execute $v$
      create or replace view public.maintenance_items as
      select
        id,
        ot_id,
        line_no,
        description,
        unit,
        qty,
        is_done,
        notes,
        done_at,
        done_by,
        created_at,
        updated_at
      from public.maintenance_tasks
    $v$;
  end if;
end
$$;

create index if not exists maintenance_orders_status_idx on public.maintenance_orders (status);
create index if not exists maintenance_orders_requested_at_idx on public.maintenance_orders (requested_at desc);
create index if not exists maintenance_orders_priority_idx on public.maintenance_orders (priority);
create index if not exists maintenance_orders_area_label_idx on public.maintenance_orders (area_label);
create index if not exists maintenance_orders_equipment_label_idx on public.maintenance_orders (equipment_label);
create index if not exists maintenance_tasks_ot_idx on public.maintenance_tasks (ot_id, line_no);
create index if not exists maintenance_materials_ot_idx on public.maintenance_materials (ot_id, line_no);
create index if not exists maintenance_time_logs_ot_idx on public.maintenance_time_logs (ot_id, start_at);
create index if not exists maintenance_evidence_ot_idx on public.maintenance_evidence (ot_id, category, uploaded_at desc);
create index if not exists maintenance_approvals_ot_idx on public.maintenance_approvals (ot_id, step);
create index if not exists maintenance_status_log_ot_idx on public.maintenance_status_log (ot_id, changed_at desc);

create or replace function public.set_maintenance_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_set_maintenance_orders_updated_at on public.maintenance_orders;
create trigger trg_set_maintenance_orders_updated_at
before update on public.maintenance_orders
for each row
execute function public.set_maintenance_updated_at();

drop trigger if exists trg_set_maintenance_tasks_updated_at on public.maintenance_tasks;
create trigger trg_set_maintenance_tasks_updated_at
before update on public.maintenance_tasks
for each row
execute function public.set_maintenance_updated_at();

drop trigger if exists trg_set_maintenance_materials_updated_at on public.maintenance_materials;
create trigger trg_set_maintenance_materials_updated_at
before update on public.maintenance_materials
for each row
execute function public.set_maintenance_updated_at();

drop trigger if exists trg_set_maintenance_time_logs_updated_at on public.maintenance_time_logs;
create trigger trg_set_maintenance_time_logs_updated_at
before update on public.maintenance_time_logs
for each row
execute function public.set_maintenance_updated_at();

drop trigger if exists trg_set_maintenance_approvals_updated_at on public.maintenance_approvals;
create trigger trg_set_maintenance_approvals_updated_at
before update on public.maintenance_approvals
for each row
execute function public.set_maintenance_updated_at();

alter table public.maintenance_orders enable row level security;
alter table public.maintenance_tasks enable row level security;
alter table public.maintenance_materials enable row level security;
alter table public.maintenance_time_logs enable row level security;
alter table public.maintenance_evidence enable row level security;
alter table public.maintenance_approvals enable row level security;
alter table public.maintenance_status_log enable row level security;

grant select, insert, update, delete on public.maintenance_orders to authenticated;
grant select, insert, update, delete on public.maintenance_tasks to authenticated;
grant select, insert, update, delete on public.maintenance_materials to authenticated;
grant select, insert, update, delete on public.maintenance_time_logs to authenticated;
grant select, insert, update, delete on public.maintenance_evidence to authenticated;
grant select, insert, update, delete on public.maintenance_approvals to authenticated;
grant select, insert, update, delete on public.maintenance_status_log to authenticated;
grant select on public.maintenance_items to authenticated;

do $$
declare
  tbl text;
  tables text[] := array[
    'maintenance_orders',
    'maintenance_tasks',
    'maintenance_materials',
    'maintenance_time_logs',
    'maintenance_evidence',
    'maintenance_approvals',
    'maintenance_status_log'
  ];
  policy_name text;
begin
  foreach tbl in array tables loop
    policy_name := format('%s_authenticated_all', tbl);

    if not exists (
      select 1
      from pg_policies
      where schemaname = 'public'
        and tablename = tbl
        and policyname = policy_name
    ) then
      execute format(
        'create policy %I on public.%I for all to authenticated using (true) with check (true)',
        policy_name,
        tbl
      );
    end if;
  end loop;
end
$$;

-- Storage bucket + policies for evidence files
insert into storage.buckets (id, name, public)
select 'maintenance_evidence', 'maintenance_evidence', true
where not exists (select 1 from storage.buckets where id = 'maintenance_evidence');

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'maintenance_evidence_authenticated_read'
  ) then
    create policy maintenance_evidence_authenticated_read
      on storage.objects
      for select
      to authenticated
      using (bucket_id = 'maintenance_evidence');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'maintenance_evidence_authenticated_write'
  ) then
    create policy maintenance_evidence_authenticated_write
      on storage.objects
      for insert
      to authenticated
      with check (bucket_id = 'maintenance_evidence');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'maintenance_evidence_authenticated_update'
  ) then
    create policy maintenance_evidence_authenticated_update
      on storage.objects
      for update
      to authenticated
      using (bucket_id = 'maintenance_evidence')
      with check (bucket_id = 'maintenance_evidence');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'maintenance_evidence_authenticated_delete'
  ) then
    create policy maintenance_evidence_authenticated_delete
      on storage.objects
      for delete
      to authenticated
      using (bucket_id = 'maintenance_evidence');
  end if;
end
$$;

commit;
