begin;

with counterparties_by_name as (
  select
    id,
    upper(regexp_replace(btrim(name), '\s+', ' ', 'g')) as normalized_name
  from public.mayoreo_counterparties
),
dead_sales_client_refs as (
  select report.id, company.id as resolved_client_id
  from public.mayoreo_sales_reports report
  join counterparties_by_name company
    on company.normalized_name =
      upper(regexp_replace(btrim(report.client_name_snapshot), '\s+', ' ', 'g'))
  left join public.mayoreo_counterparties existing
    on existing.id = report.client_id
  where report.client_name_snapshot is not null
    and btrim(report.client_name_snapshot) <> ''
    and (report.client_id is null or existing.id is null)
)
update public.mayoreo_sales_reports report
set client_id = refs.resolved_client_id
from dead_sales_client_refs refs
where report.id = refs.id;

with counterparties_by_name as (
  select
    id,
    upper(regexp_replace(btrim(name), '\s+', ' ', 'g')) as normalized_name
  from public.mayoreo_counterparties
),
dead_accounts_client_refs as (
  select account.id, company.id as resolved_client_id
  from public.mayoreo_accounts account
  join counterparties_by_name company
    on company.normalized_name =
      upper(regexp_replace(btrim(account.client_name_snapshot), '\s+', ' ', 'g'))
  left join public.mayoreo_counterparties existing
    on existing.id = account.client_id
  where account.client_name_snapshot is not null
    and btrim(account.client_name_snapshot) <> ''
    and (account.client_id is null or existing.id is null)
)
update public.mayoreo_accounts account
set client_id = refs.resolved_client_id
from dead_accounts_client_refs refs
where account.id = refs.id;

with materials_by_name as (
  select
    id,
    upper(regexp_replace(btrim(name), '\s+', ' ', 'g')) as normalized_name
  from public.mayoreo_material_catalog
  where level = 'COMERCIAL'
),
dead_sales_material_refs as (
  select report.id, material.id as resolved_material_id
  from public.mayoreo_sales_reports report
  join materials_by_name material
    on material.normalized_name =
      upper(regexp_replace(btrim(report.material_name_snapshot), '\s+', ' ', 'g'))
  left join public.mayoreo_material_catalog existing
    on existing.id = report.material_id
  where report.material_name_snapshot is not null
    and btrim(report.material_name_snapshot) <> ''
    and (report.material_id is null or existing.id is null)
)
update public.mayoreo_sales_reports report
set material_id = refs.resolved_material_id
from dead_sales_material_refs refs
where report.id = refs.id;

with latest_report_price as (
  select distinct on (report.client_id, report.material_id)
    report.client_id as company_id,
    report.material_id,
    report.price_snapshot as final_price,
    report.sale_date,
    report.updated_at,
    report.created_at
  from public.mayoreo_sales_reports report
  where report.client_id is not null
    and report.material_id is not null
    and report.price_snapshot >= 0
  order by
    report.client_id,
    report.material_id,
    report.sale_date desc,
    report.updated_at desc,
    report.created_at desc,
    report.id desc
)
insert into public.mayoreo_counterparty_material_prices (
  id,
  company_id,
  material_id,
  final_price,
  is_active,
  notes
)
select
  'mp_recovered_' || md5(company_id || '|' || material_id),
  company_id,
  material_id,
  final_price,
  true,
  'RECUPERADO DESDE SNAPSHOT DE REPORTES MAYOREO ' ||
      to_char(now() at time zone 'America/Mexico_City', 'YYYY-MM-DD HH24:MI:SS')
from latest_report_price
on conflict (company_id, material_id) do update
set final_price = excluded.final_price,
    is_active = true,
    notes = excluded.notes,
    updated_at = now();

commit;
