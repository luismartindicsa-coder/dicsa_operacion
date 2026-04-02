create table if not exists public.maintenance_orders_backup_20260325
  (like public.maintenance_orders including all);

create table if not exists public.maintenance_tasks_backup_20260325
  (like public.maintenance_tasks including all);

create table if not exists public.maintenance_materials_backup_20260325
  (like public.maintenance_materials including all);

create table if not exists public.maintenance_time_logs_backup_20260325
  (like public.maintenance_time_logs including all);

create table if not exists public.maintenance_evidence_backup_20260325
  (like public.maintenance_evidence including all);

create table if not exists public.maintenance_approvals_backup_20260325
  (like public.maintenance_approvals including all);

create table if not exists public.maintenance_status_log_backup_20260325
  (like public.maintenance_status_log including all);

insert into public.maintenance_orders_backup_20260325
select *
from public.maintenance_orders
where not exists (
  select 1 from public.maintenance_orders_backup_20260325
);

insert into public.maintenance_tasks_backup_20260325
select *
from public.maintenance_tasks
where not exists (
  select 1 from public.maintenance_tasks_backup_20260325
);

insert into public.maintenance_materials_backup_20260325
select *
from public.maintenance_materials
where not exists (
  select 1 from public.maintenance_materials_backup_20260325
);

insert into public.maintenance_time_logs_backup_20260325
select *
from public.maintenance_time_logs
where not exists (
  select 1 from public.maintenance_time_logs_backup_20260325
);

insert into public.maintenance_evidence_backup_20260325
select *
from public.maintenance_evidence
where not exists (
  select 1 from public.maintenance_evidence_backup_20260325
);

insert into public.maintenance_approvals_backup_20260325
select *
from public.maintenance_approvals
where not exists (
  select 1 from public.maintenance_approvals_backup_20260325
);

insert into public.maintenance_status_log_backup_20260325
select *
from public.maintenance_status_log
where not exists (
  select 1 from public.maintenance_status_log_backup_20260325
);

alter table public.maintenance_orders
  add column if not exists mechanic_name text,
  add column if not exists mechanic_contact text;
