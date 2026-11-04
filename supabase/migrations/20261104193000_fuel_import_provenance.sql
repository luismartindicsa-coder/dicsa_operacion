begin;

-- Preserve original amounts, source cells and the basis of estimated quantities.
-- Nullable so existing records retain their original values unchanged.
alter table public.logistics_diesel_consumption
  add column source_metadata jsonb check (source_metadata is null or jsonb_typeof(source_metadata) = 'object');
alter table public.logistics_gasoline_control
  add column source_metadata jsonb check (source_metadata is null or jsonb_typeof(source_metadata) = 'object');

comment on column public.logistics_diesel_consumption.source_metadata is
  'Import provenance, original amount and estimated liters/reference price when source liters are missing.';
comment on column public.logistics_gasoline_control.source_metadata is
  'Import provenance, original amount and estimated liters/reference price when source liters are missing.';

notify pgrst, 'reload schema';
commit;
