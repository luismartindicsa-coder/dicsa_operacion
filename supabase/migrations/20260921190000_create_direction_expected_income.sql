begin;

-- Estimates only. No example balances, sales, collections or loans are seeded.
create table public.direction_income_material_rules (
  material_code text primary key check (material_code in ('PACA_NACIONAL','PACA_LIMPIA','PACA_AMERICANA')),
  kg_per_bale numeric(12,4) not null check (kg_per_bale > 0 and kg_per_bale <= 10000),
  price_per_kg numeric(12,4) check (price_per_kg >= 0 and price_per_kg <= 100000),
  updated_at timestamptz not null default now()
);
insert into public.direction_income_material_rules values
  ('PACA_NACIONAL',700,2.50,now()),('PACA_LIMPIA',700,2.70,now()),('PACA_AMERICANA',700,3.80,now());

create table public.direction_income_client_rules (
  client_key text primary key check (client_key = upper(btrim(client_key)) and length(client_key) > 0),
  client_name text not null check (length(btrim(client_name)) > 0),
  client_id text references public.mayoreo_counterparties(id) on delete set null,
  aliases text[] not null default '{}',
  payment_type text not null check (payment_type in ('EFECTIVO','FISCAL','MIXTO')),
  term_unit text not null check (term_unit in ('INMEDIATO','DIAS','SEMANAS')),
  term_value integer not null check (term_value between 0 and 365),
  default_price_per_kg numeric(12,4) check (default_price_per_kg >= 0 and default_price_per_kg <= 100000),
  usual_material text references public.direction_income_material_rules(material_code),
  special_rules text not null default '',
  is_active boolean not null default true,
  is_revolving boolean not null default false,
  updated_at timestamptz not null default now()
);
insert into public.direction_income_client_rules
  (client_key, client_name, aliases, payment_type, term_unit, term_value, is_revolving) values
  ('SAN LUIS','SAN LUIS','{DESPERDICIOS QUERETANA SAN LUIS}','FISCAL','SEMANAS',1,false),
  ('PAPELERA DEL NEVADO','PAPELERA DEL NEVADO','{PAPELERA NEVADO}','FISCAL','DIAS',2,false),
  ('EL PALOMAR','EL PALOMAR','{}','MIXTO','INMEDIATO',0,true),
  ('ECO FIBRAS','ECO FIBRAS','{ECOFIBRAS}','FISCAL','SEMANAS',1,false),
  ('BIO PAPEL','BIO PAPEL','{BIO PAPPEL,BIOPAPEL,BIOPAPPEL}','FISCAL','SEMANAS',1,false),
  ('RICARDO MENDIETA','RICARDO MENDIETA','{}','EFECTIVO','INMEDIATO',0,false);

create table public.direction_income_client_prices (
  client_key text not null references public.direction_income_client_rules(client_key) on delete cascade,
  material_code text not null references public.direction_income_material_rules(material_code),
  price_per_kg numeric(12,4) not null check (price_per_kg >= 0 and price_per_kg <= 100000),
  updated_at timestamptz not null default now(),
  primary key (client_key, material_code)
);

create table public.direction_income_shipment_links (
  shipment_id uuid primary key references public.direction_shipment_plans(id) on delete cascade,
  sale_report_id text not null unique references public.mayoreo_sales_reports(id) on delete restrict,
  updated_at timestamptz not null default now()
);

create table public.direction_income_palomar_config (
  id boolean primary key default true check (id),
  credit_limit numeric(16,2) check (credit_limit >= 0),
  draw_amount numeric(16,2) check (draw_amount >= 0),
  cash_check_1 numeric(16,2) not null check (cash_check_1 >= 0),
  cash_check_2 numeric(16,2) not null check (cash_check_2 >= 0),
  shipment_effect integer not null default -1 check (shipment_effect = -1),
  require_covered boolean not null default true,
  updated_at timestamptz not null default now()
);
-- Confirmed by the user: remissions reduce the balance; checks increase it.
insert into public.direction_income_palomar_config
  (id,cash_check_1,cash_check_2) values (true,99000,99000);

create table public.direction_income_palomar_adjustments (
  id uuid primary key default gen_random_uuid(),
  expected_date date not null,
  concept text not null check (concept in ('PESADO','RETORNO','MIXTO','REBABA','ABONO','OTRO')),
  effect integer not null check (effect in (-1,1)),
  amount numeric(16,2) not null check (amount > 0),
  notes text not null default '',
  updated_at timestamptz not null default now()
);
create index direction_income_palomar_adjustments_date on public.direction_income_palomar_adjustments(expected_date);

do $$
declare t text;
begin
  foreach t in array array['direction_income_material_rules','direction_income_client_rules',
    'direction_income_client_prices','direction_income_shipment_links','direction_income_palomar_config',
    'direction_income_palomar_adjustments'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('create policy direction_income_manage on public.%I for all to authenticated using (public.direction_program_can_manage()) with check (public.direction_program_can_manage())',t);
    execute format('create trigger income_updated_at before update on public.%I for each row execute function public.set_updated_at_v2()',t);
  end loop;
end $$;

-- Atomic rule and three material overrides; existing commercial prices remain intact.
create function public.direction_income_save_client(p_rule jsonb, p_prices jsonb)
returns void language plpgsql security invoker set search_path = public as $$
declare r public.direction_income_client_rules;
begin
  if not public.direction_program_can_manage() then raise exception 'Sin permiso' using errcode='42501'; end if;
  r := jsonb_populate_record(null::public.direction_income_client_rules, p_rule);
  insert into public.direction_income_client_rules
    (client_key,client_name,client_id,aliases,payment_type,term_unit,term_value,default_price_per_kg,usual_material,special_rules,is_active,is_revolving)
  values (r.client_key,r.client_name,r.client_id,r.aliases,r.payment_type,r.term_unit,r.term_value,r.default_price_per_kg,r.usual_material,r.special_rules,r.is_active,r.is_revolving)
  on conflict(client_key) do update set client_name=excluded.client_name,client_id=excluded.client_id,
    aliases=excluded.aliases,payment_type=excluded.payment_type,term_unit=excluded.term_unit,term_value=excluded.term_value,
    default_price_per_kg=excluded.default_price_per_kg,usual_material=excluded.usual_material,special_rules=excluded.special_rules,
    is_active=excluded.is_active,is_revolving=excluded.is_revolving;
  delete from public.direction_income_client_prices where client_key=r.client_key;
  insert into public.direction_income_client_prices(client_key,material_code,price_per_kg)
    select r.client_key,key,value::numeric from jsonb_each_text(p_prices);
end $$;
revoke all on function public.direction_income_save_client(jsonb,jsonb) from public;
grant execute on function public.direction_income_save_client(jsonb,jsonb) to authenticated;

commit;
