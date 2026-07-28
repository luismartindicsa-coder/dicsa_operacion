begin;

alter table public.gerencia_bale_weekly_plans
  add column if not exists snapshot_production_actual_bales integer,
  add column if not exists snapshot_production_target_bales integer,
  add column if not exists snapshot_shipment_actual_bales integer,
  add column if not exists snapshot_shipment_target_bales integer,
  add column if not exists snapshot_refreshed_at timestamptz;

comment on column public.gerencia_bale_weekly_plans.snapshot_production_actual_bales is
  'Snapshot persistido del total real de produccion semanal para el historico de Gerencia.';

comment on column public.gerencia_bale_weekly_plans.snapshot_production_target_bales is
  'Snapshot persistido del total meta de produccion semanal para el historico de Gerencia.';

comment on column public.gerencia_bale_weekly_plans.snapshot_shipment_actual_bales is
  'Snapshot persistido del total real de embarque semanal para el historico de Gerencia.';

comment on column public.gerencia_bale_weekly_plans.snapshot_shipment_target_bales is
  'Snapshot persistido del total meta de embarque semanal para el historico de Gerencia.';

comment on column public.gerencia_bale_weekly_plans.snapshot_refreshed_at is
  'Ultima fecha de refresco del snapshot historico semanal de Gerencia.';

commit;
