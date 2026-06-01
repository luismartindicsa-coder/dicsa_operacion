alter table public.finanzas_fixed_payments
add column if not exists branch text not null default 'CELAYA'
  check (branch in ('CELAYA', 'MAZATLAN'));

update public.finanzas_fixed_payments
set branch = case
  when upper(company_name_snapshot) like '%MAZATLAN%' then 'MAZATLAN'
  else 'CELAYA'
end
where branch is null
   or branch not in ('CELAYA', 'MAZATLAN');

create index if not exists finanzas_fixed_payments_branch_idx
  on public.finanzas_fixed_payments (branch);
