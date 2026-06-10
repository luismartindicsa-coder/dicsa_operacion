alter table public.finanzas_fixed_payments
add column if not exists target_company text not null default 'DICSA'
  check (target_company in ('DICSA', 'VH'));

update public.finanzas_fixed_payments
set target_company = case
  when upper(company_name_snapshot) like '%VH%' then 'VH'
  else 'DICSA'
end
where target_company is null
   or target_company not in ('DICSA', 'VH');

create index if not exists finanzas_fixed_payments_target_company_idx
  on public.finanzas_fixed_payments (target_company);
