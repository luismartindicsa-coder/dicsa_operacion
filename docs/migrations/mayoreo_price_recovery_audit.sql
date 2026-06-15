with latest_report_price as (
  select distinct on (report.client_id, report.material_id)
    report.client_id as company_id,
    report.material_id,
    report.price_snapshot as latest_price_snapshot,
    report.sale_date as latest_sale_date,
    report.updated_at as latest_report_updated_at
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
select
  company.name as company_name,
  material.name as material_name,
  price.final_price as current_catalog_price,
  latest.latest_price_snapshot as latest_operational_price,
  latest.latest_sale_date,
  latest.latest_report_updated_at,
  case
    when latest.company_id is null then 'SIN_RESPALDO_OPERATIVO'
    when abs(coalesce(price.final_price, 0) - coalesce(latest.latest_price_snapshot, 0)) < 0.0001
      then 'OK'
    else 'DIFIERE_DE_OPERACION'
  end as audit_status
from public.mayoreo_counterparty_material_prices price
join public.mayoreo_counterparties company
  on company.id = price.company_id
join public.mayoreo_material_catalog material
  on material.id = price.material_id
left join latest_report_price latest
  on latest.company_id = price.company_id
 and latest.material_id = price.material_id
where price.is_active = true
order by
  audit_status desc,
  company.name asc,
  material.name asc;
