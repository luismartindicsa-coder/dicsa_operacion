with shared_aliases as (
  select upper(trim(name)) as alias_name
  from public.compras_counterparties
  where coalesce(is_active, true)
  intersect
  select upper(trim(name)) as alias_name
  from public.mayoreo_counterparties
  where coalesce(is_active, true)
)
update public.finanzas_catalog_companies as company
set
  source = 'DIRECTO',
  linked_name = coalesce(nullif(company.linked_name, ''), company.name),
  notes = case
    when coalesce(trim(company.notes), '') = '' then
      'SINCRONIZADO DESDE COMPRAS MAYOREO Y VENTAS MAYOREO'
    when upper(trim(company.notes)) in (
      'SINCRONIZADO DESDE COMPRAS MAYOREO',
      'SINCRONIZADO DESDE VENTAS MAYOREO'
    ) then
      'SINCRONIZADO DESDE COMPRAS MAYOREO Y VENTAS MAYOREO'
    else company.notes
  end
where upper(trim(coalesce(nullif(company.linked_name, ''), company.name))) in (
  select alias_name from shared_aliases
);

with shared_aliases as (
  select upper(trim(name)) as alias_name
  from public.compras_counterparties
  where coalesce(is_active, true)
  intersect
  select upper(trim(name)) as alias_name
  from public.mayoreo_counterparties
  where coalesce(is_active, true)
)
update public.finanzas_company_directory as directory
set
  source = 'DIRECTO',
  linked_name = coalesce(nullif(directory.linked_name, ''), directory.company_name)
where upper(trim(coalesce(nullif(directory.linked_name, ''), directory.company_name))) in (
  select alias_name from shared_aliases
);
