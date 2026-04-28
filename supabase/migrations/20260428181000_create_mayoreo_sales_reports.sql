begin;

create table if not exists public.mayoreo_sales_reports (
  id text primary key,
  ticket text not null,
  sale_date timestamptz not null,
  client_id text references public.mayoreo_counterparties(id) on delete set null,
  client_name_snapshot text not null,
  remision text not null default '',
  material_id text references public.mayoreo_material_catalog(id) on delete set null,
  material_name_snapshot text not null,
  exit_weight numeric(14,4) not null default 0,
  price_snapshot numeric(14,4) not null default 0,
  approved_weight numeric(14,4),
  approved_price numeric(14,4),
  approved_amount numeric(14,4) not null default 0,
  operation_type text not null default 'factura',
  observations text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint mayoreo_sales_reports_id_trim_chk check (
    id = btrim(id) and length(id) > 0
  ),
  constraint mayoreo_sales_reports_ticket_trim_chk check (
    ticket = btrim(ticket) and length(ticket) > 0
  ),
  constraint mayoreo_sales_reports_client_name_trim_chk check (
    client_name_snapshot = btrim(client_name_snapshot) and length(client_name_snapshot) > 0
  ),
  constraint mayoreo_sales_reports_material_name_trim_chk check (
    material_name_snapshot = btrim(material_name_snapshot) and length(material_name_snapshot) > 0
  ),
  constraint mayoreo_sales_reports_operation_type_chk check (
    operation_type in ('factura', 'cheque')
  )
);

drop trigger if exists trg_mayoreo_sales_reports_updated_at on public.mayoreo_sales_reports;
create trigger trg_mayoreo_sales_reports_updated_at
before update on public.mayoreo_sales_reports
for each row execute function public.set_updated_at_v2();

create index if not exists mayoreo_sales_reports_sale_date_idx
  on public.mayoreo_sales_reports (sale_date desc, created_at desc);

create index if not exists mayoreo_sales_reports_client_idx
  on public.mayoreo_sales_reports (client_id, sale_date desc);

create index if not exists mayoreo_sales_reports_material_idx
  on public.mayoreo_sales_reports (material_id, sale_date desc);

alter table public.mayoreo_sales_reports enable row level security;

grant select, insert, update, delete on public.mayoreo_sales_reports to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'mayoreo_sales_reports'
      and policyname = 'mayoreo_sales_reports_authenticated_all'
  ) then
    create policy mayoreo_sales_reports_authenticated_all
      on public.mayoreo_sales_reports
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

grant select on public.mayoreo_sales_reports to authenticated;

commit;
