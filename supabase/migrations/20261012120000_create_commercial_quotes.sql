begin;

create function public.commercial_quote_items_valid(items jsonb)
returns boolean language plpgsql immutable set search_path = pg_catalog, public as $$
declare item jsonb;
begin
  if jsonb_typeof(items) is distinct from 'array' then return false; end if;
  if jsonb_array_length(items) = 0 then return false; end if;
  for item in select value from jsonb_array_elements(items) loop
    if jsonb_typeof(item) is distinct from 'object'
      or jsonb_typeof(item->'material') is distinct from 'string'
      or length(btrim(item->>'material')) = 0
      or coalesce(item->>'unit','') not in ('KG','PZA','TON')
      or jsonb_typeof(item->'quantity') is distinct from 'number'
      or jsonb_typeof(item->'price') is distinct from 'number' then return false; end if;
    if (item->>'quantity')::numeric <= 0 or (item->>'price')::numeric < 0 then return false; end if;
  end loop;
  return true;
end;
$$;

create table public.commercial_quotes (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.commercial_accounts(id) on delete restrict,
  quotation_date date not null default current_date,
  valid_until date not null,
  status text not null default 'borrador' check (status in ('borrador','enviada','aceptada','rechazada','cancelada')),
  items jsonb not null check (public.commercial_quote_items_valid(items)),
  notes text not null default '',
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_until >= quotation_date)
);
create index commercial_quotes_account_date_idx on public.commercial_quotes(account_id,quotation_date desc,created_at desc);
create trigger trg_commercial_quotes_updated_at before update on public.commercial_quotes
  for each row execute function public.set_commercial_updated_at();
alter table public.commercial_quotes enable row level security;
grant select,insert,update on public.commercial_quotes to authenticated;
-- Same access boundary as the commercial account/agenda data; cancellation keeps history.
create policy commercial_quotes_authenticated_read on public.commercial_quotes for select to authenticated using (true);
create policy commercial_quotes_authenticated_insert on public.commercial_quotes for insert to authenticated with check (true);
create policy commercial_quotes_authenticated_update on public.commercial_quotes for update to authenticated using (true) with check (true);
comment on table public.commercial_quotes is 'Cotizaciones propias por cuenta comercial. No altera precios ni movimientos de Menudeo/Mayoreo.';
commit;
