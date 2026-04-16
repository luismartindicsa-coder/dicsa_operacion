begin;

alter table public.men_counterparty_material_prices
  add column if not exists direction text;

update public.men_counterparty_material_prices price
set direction = case
  when cp.kind = 'customer' then 'sale'
  else 'purchase'
end
from public.men_counterparties cp
where cp.id = price.counterparty_id
  and price.direction is null;

alter table public.men_counterparty_material_prices
  alter column direction set default 'purchase';

alter table public.men_counterparty_material_prices
  alter column direction set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'men_counterparty_material_prices_direction_chk'
      and conrelid = 'public.men_counterparty_material_prices'::regclass
  ) then
    alter table public.men_counterparty_material_prices
      add constraint men_counterparty_material_prices_direction_chk
      check (direction in ('purchase', 'sale'));
  end if;
end
$$;

create index if not exists men_counterparty_material_prices_direction_idx
  on public.men_counterparty_material_prices (direction, is_active, created_at desc);

create or replace view public.vw_men_counterparty_price_catalog as
select
  cp.id as counterparty_id,
  cp.site_id,
  cp.name as counterparty_name,
  cp.kind,
  cp.group_code,
  cp.is_active as counterparty_active,
  price.id as price_id,
  price.general_material_id,
  gen.code as general_material_code,
  gen.name as general_material_name,
  price.commercial_material_id,
  com.code as commercial_material_code,
  com.name as commercial_material_name,
  price.material_alias_id,
  alias.label as material_alias_label,
  price.material_label_snapshot,
  price.final_price,
  price.is_active as price_active,
  price.notes,
  price.created_at,
  price.updated_at,
  price.direction
from public.men_counterparty_material_prices price
join public.men_counterparties cp
  on cp.id = price.counterparty_id
left join public.material_general_catalog_v2 gen
  on gen.id = price.general_material_id
left join public.material_commercial_catalog_v2 com
  on com.id = price.commercial_material_id
left join public.men_material_aliases alias
  on alias.id = price.material_alias_id;

create or replace view public.vw_men_effective_prices as
select
  cp.id as counterparty_id,
  cp.site_id,
  cp.name as counterparty_name,
  cp.kind,
  cp.group_code,
  cp.is_active as counterparty_active,
  price.id as price_id,
  coalesce(price.commercial_material_id, alias.commercial_material_id) as commercial_material_id,
  coalesce(com.name, alias_com.name) as commercial_material_name,
  coalesce(com.code, alias_com.code) as commercial_material_code,
  coalesce(
    price.general_material_id,
    com.general_material_id,
    alias.general_material_id,
    alias_com.general_material_id
  ) as general_material_id,
  coalesce(gen.name, alias_gen.name, via_com_gen.name) as general_material_name,
  coalesce(gen.code, alias_gen.code, via_com_gen.code) as general_material_code,
  price.material_alias_id,
  alias.label as material_alias_label,
  price.material_label_snapshot,
  price.final_price,
  price.notes,
  price.created_at,
  price.updated_at,
  price.direction
from public.men_counterparty_material_prices price
join public.men_counterparties cp
  on cp.id = price.counterparty_id
left join public.material_general_catalog_v2 gen
  on gen.id = price.general_material_id
left join public.material_commercial_catalog_v2 com
  on com.id = price.commercial_material_id
left join public.material_general_catalog_v2 via_com_gen
  on via_com_gen.id = com.general_material_id
left join public.men_material_aliases alias
  on alias.id = price.material_alias_id
left join public.material_general_catalog_v2 alias_gen
  on alias_gen.id = alias.general_material_id
left join public.material_commercial_catalog_v2 alias_com
  on alias_com.id = alias.commercial_material_id
where cp.is_active = true
  and price.is_active = true;

create or replace view public.vw_men_price_adjustment_history as
select
  hist.id,
  hist.batch_id,
  hist.price_id,
  hist.counterparty_id,
  hist.counterparty_name_snapshot as counterparty_name,
  hist.group_code_snapshot as group_code,
  hist.general_material_id,
  gen.code as general_material_code,
  gen.name as general_material_name,
  hist.commercial_material_id,
  com.code as commercial_material_code,
  com.name as commercial_material_name,
  hist.material_alias_id,
  alias.label as material_alias_label,
  hist.material_label_snapshot,
  hist.previous_price,
  hist.new_price,
  hist.adjustment_mode,
  hist.adjustment_value,
  hist.event_kind,
  hist.event_source,
  hist.reason,
  hist.is_active_snapshot,
  hist.applied_by,
  hist.created_at,
  price.direction
from public.men_price_adjustment_history hist
left join public.men_counterparty_material_prices price
  on price.id = hist.price_id
left join public.material_general_catalog_v2 gen
  on gen.id = hist.general_material_id
left join public.material_commercial_catalog_v2 com
  on com.id = hist.commercial_material_id
left join public.men_material_aliases alias
  on alias.id = hist.material_alias_id;

create or replace view public.vw_men_price_audit_catalog as
select
  cat.counterparty_id,
  cat.site_id,
  cat.counterparty_name,
  cat.kind,
  cat.group_code,
  cat.counterparty_active,
  cat.price_id,
  cat.general_material_id,
  cat.general_material_code,
  cat.general_material_name,
  cat.commercial_material_id,
  cat.commercial_material_code,
  cat.commercial_material_name,
  cat.material_alias_id,
  cat.material_alias_label,
  cat.material_label_snapshot,
  cat.final_price,
  cat.price_active,
  cat.notes,
  cat.created_at,
  cat.updated_at,
  last_hist.previous_price as last_previous_price,
  last_hist.new_price as last_new_price,
  last_hist.adjustment_mode as last_adjustment_mode,
  last_hist.adjustment_value as last_adjustment_value,
  last_hist.event_kind as last_event_kind,
  last_hist.reason as last_reason,
  last_hist.created_at as last_changed_at,
  cat.direction
from public.vw_men_counterparty_price_catalog cat
left join lateral (
  select
    hist.previous_price,
    hist.new_price,
    hist.adjustment_mode,
    hist.adjustment_value,
    hist.event_kind,
    hist.reason,
    hist.created_at
  from public.men_price_adjustment_history hist
  where hist.price_id = cat.price_id
  order by hist.created_at desc, hist.id desc
  limit 1
) last_hist on true;

commit;
