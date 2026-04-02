begin;

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
  price.updated_at
from public.men_counterparty_material_prices price
join public.men_counterparties cp
  on cp.id = price.counterparty_id
left join public.material_general_catalog_v2 gen
  on gen.id = price.general_material_id
left join public.material_commercial_catalog_v2 com
  on com.id = price.commercial_material_id
left join public.men_material_aliases alias
  on alias.id = price.material_alias_id;

comment on view public.vw_men_counterparty_price_catalog is
  'Catalogo consolidado de contrapartes, materiales y precios de menudeo.';

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
  price.updated_at
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

comment on view public.vw_men_effective_prices is
  'Precios efectivos activos para resolver contraparte + material en tickets de menudeo.';

grant select on public.vw_men_counterparty_price_catalog to authenticated;
grant select on public.vw_men_effective_prices to authenticated;

commit;
