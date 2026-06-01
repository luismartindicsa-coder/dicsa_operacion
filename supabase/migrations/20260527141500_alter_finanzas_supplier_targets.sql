alter table public.finanzas_supplier_invoices
add column if not exists target_company text not null default 'DICSA'
  check (target_company in ('DICSA', 'VH'));

alter table public.finanzas_supplier_invoices
add column if not exists target_branch text not null default 'CELAYA'
  check (target_branch in ('CELAYA', 'MAZATLAN'));

update public.finanzas_supplier_invoices
set target_company = 'VH'
where (target_company is null
   or target_company not in ('DICSA', 'VH'))
  and upper(provider_name_snapshot) like '%VH%';

update public.finanzas_supplier_invoices
set target_company = 'DICSA'
where target_company is null
   or target_company not in ('DICSA', 'VH');

update public.finanzas_supplier_invoices
set target_branch = case
  when upper(provider_name_snapshot) like '%MAZATLAN%' then 'MAZATLAN'
  else 'CELAYA'
end
where target_branch is null
   or target_branch not in ('CELAYA', 'MAZATLAN');

alter table public.finanzas_supplier_agreements
add column if not exists target_company text not null default 'DICSA'
  check (target_company in ('DICSA', 'VH'));

alter table public.finanzas_supplier_agreements
add column if not exists target_branch text not null default 'CELAYA'
  check (target_branch in ('CELAYA', 'MAZATLAN'));

update public.finanzas_supplier_agreements
set target_company = 'VH'
where (target_company is null
   or target_company not in ('DICSA', 'VH'))
  and upper(provider_name_snapshot) like '%VH%';

update public.finanzas_supplier_agreements
set target_company = 'DICSA'
where target_company is null
   or target_company not in ('DICSA', 'VH');

update public.finanzas_supplier_agreements
set target_branch = case
  when upper(provider_name_snapshot) like '%MAZATLAN%' then 'MAZATLAN'
  else 'CELAYA'
end
where target_branch is null
   or target_branch not in ('CELAYA', 'MAZATLAN');

create index if not exists finanzas_supplier_invoices_target_company_branch_idx
  on public.finanzas_supplier_invoices (target_company, target_branch);

create index if not exists finanzas_supplier_agreements_target_company_branch_idx
  on public.finanzas_supplier_agreements (target_company, target_branch);
