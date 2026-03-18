begin;

do $$
begin
  if not exists (
    select 1 from pg_type where typname = 'material_commercial_classification_kind_v2'
  ) then
    create type public.material_commercial_classification_kind_v2 as enum (
      'general_input',
      'classified_stock',
      'legacy_alias'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'material_commercial_flow_scope_v2'
  ) then
    create type public.material_commercial_flow_scope_v2 as enum (
      'IN',
      'OUT',
      'BOTH',
      'PRODUCTION_ONLY'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'inventory_level_v2'
  ) then
    create type public.inventory_level_v2 as enum (
      'GENERAL',
      'COMMERCIAL'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'inventory_flow_v2'
  ) then
    create type public.inventory_flow_v2 as enum (
      'IN',
      'OUT',
      'ADJUSTMENT'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'transformation_origin_type_v2'
  ) then
    create type public.transformation_origin_type_v2 as enum (
      'DIRECT_PURCHASE',
      'TRANSFORMATION',
      'OPENING',
      'ADJUSTMENT'
    );
  end if;
end
$$;

create table if not exists public.material_general_catalog_v2 (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  is_active boolean not null default true,
  sort_order int not null default 100,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint material_general_catalog_v2_code_trim_chk check (
    code = btrim(code) and length(code) > 0
  ),
  constraint material_general_catalog_v2_name_trim_chk check (
    name = btrim(name) and length(name) > 0
  )
);

create table if not exists public.material_commercial_catalog_v2 (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  family text not null,
  general_material_id uuid not null references public.material_general_catalog_v2(id) on delete restrict,
  classification_kind public.material_commercial_classification_kind_v2 not null,
  flow_scope public.material_commercial_flow_scope_v2 not null default 'BOTH',
  tracks_patio_stock boolean not null default false,
  allows_direct_entry boolean not null default false,
  allows_transformation_output boolean not null default false,
  allows_sale boolean not null default false,
  is_active boolean not null default true,
  sort_order int not null default 100,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint material_commercial_catalog_v2_code_trim_chk check (
    code = btrim(code) and length(code) > 0
  ),
  constraint material_commercial_catalog_v2_name_trim_chk check (
    name = btrim(name) and length(name) > 0
  ),
  constraint material_commercial_catalog_v2_family_trim_chk check (
    family = btrim(family) and length(family) > 0
  )
);

create table if not exists public.inventory_opening_balances_v2 (
  id uuid primary key default gen_random_uuid(),
  period_month date not null,
  as_of_date date not null,
  inventory_level public.inventory_level_v2 not null,
  general_material_id uuid references public.material_general_catalog_v2(id) on delete restrict,
  commercial_material_id uuid references public.material_commercial_catalog_v2(id) on delete restrict,
  weight_kg numeric(14,3) not null,
  site text not null default 'DICSA_CELAYA',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint inventory_opening_balances_v2_weight_chk check (weight_kg >= 0),
  constraint inventory_opening_balances_v2_material_target_chk check (
    (inventory_level = 'GENERAL' and general_material_id is not null and commercial_material_id is null)
    or
    (inventory_level = 'COMMERCIAL' and commercial_material_id is not null and general_material_id is null)
  )
);

create table if not exists public.inventory_movements_v2 (
  id uuid primary key default gen_random_uuid(),
  op_date date not null,
  inventory_level public.inventory_level_v2 not null,
  flow public.inventory_flow_v2 not null,
  general_material_id uuid references public.material_general_catalog_v2(id) on delete restrict,
  commercial_material_id uuid references public.material_commercial_catalog_v2(id) on delete restrict,
  origin_type public.transformation_origin_type_v2 not null default 'DIRECT_PURCHASE',
  weight_kg numeric(14,3) not null,
  site text not null default 'DICSA_CELAYA',
  counterparty_site_id uuid,
  counterparty text,
  reference text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint inventory_movements_v2_weight_chk check (
    (flow in ('IN', 'OUT') and weight_kg > 0)
    or
    (flow = 'ADJUSTMENT' and weight_kg <> 0)
  ),
  constraint inventory_movements_v2_material_target_chk check (
    (inventory_level = 'GENERAL' and general_material_id is not null and commercial_material_id is null)
    or
    (inventory_level = 'COMMERCIAL' and commercial_material_id is not null and general_material_id is null)
  )
);

create table if not exists public.material_transformation_runs_v2 (
  id uuid primary key default gen_random_uuid(),
  op_date date not null,
  shift text not null,
  source_general_material_id uuid not null references public.material_general_catalog_v2(id) on delete restrict,
  input_weight_kg numeric(14,3) not null,
  site text not null default 'DICSA_CELAYA',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint material_transformation_runs_v2_input_weight_chk check (input_weight_kg > 0),
  constraint material_transformation_runs_v2_shift_chk check (shift in ('DAY', 'NIGHT'))
);

create table if not exists public.material_transformation_run_outputs_v2 (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.material_transformation_runs_v2(id) on delete cascade,
  commercial_material_id uuid not null references public.material_commercial_catalog_v2(id) on delete restrict,
  output_weight_kg numeric(14,3) not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint material_transformation_run_outputs_v2_weight_chk check (output_weight_kg > 0),
  constraint material_transformation_run_outputs_v2_unique unique (run_id, commercial_material_id)
);

create index if not exists material_commercial_catalog_v2_general_idx
  on public.material_commercial_catalog_v2 (general_material_id, is_active, sort_order, name);

create index if not exists inventory_opening_balances_v2_period_general_idx
  on public.inventory_opening_balances_v2 (period_month, inventory_level, general_material_id, commercial_material_id);

create index if not exists inventory_movements_v2_date_level_idx
  on public.inventory_movements_v2 (op_date desc, inventory_level, general_material_id, commercial_material_id);

create index if not exists material_transformation_runs_v2_source_date_idx
  on public.material_transformation_runs_v2 (source_general_material_id, op_date desc);

create or replace function public.set_updated_at_v2()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end
$$;

drop trigger if exists trg_material_general_catalog_v2_updated_at on public.material_general_catalog_v2;
create trigger trg_material_general_catalog_v2_updated_at
before update on public.material_general_catalog_v2
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_material_commercial_catalog_v2_updated_at on public.material_commercial_catalog_v2;
create trigger trg_material_commercial_catalog_v2_updated_at
before update on public.material_commercial_catalog_v2
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_inventory_opening_balances_v2_updated_at on public.inventory_opening_balances_v2;
create trigger trg_inventory_opening_balances_v2_updated_at
before update on public.inventory_opening_balances_v2
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_inventory_movements_v2_updated_at on public.inventory_movements_v2;
create trigger trg_inventory_movements_v2_updated_at
before update on public.inventory_movements_v2
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_material_transformation_runs_v2_updated_at on public.material_transformation_runs_v2;
create trigger trg_material_transformation_runs_v2_updated_at
before update on public.material_transformation_runs_v2
for each row execute function public.set_updated_at_v2();

drop trigger if exists trg_material_transformation_run_outputs_v2_updated_at on public.material_transformation_run_outputs_v2;
create trigger trg_material_transformation_run_outputs_v2_updated_at
before update on public.material_transformation_run_outputs_v2
for each row execute function public.set_updated_at_v2();

alter table public.material_general_catalog_v2 enable row level security;
alter table public.material_commercial_catalog_v2 enable row level security;
alter table public.inventory_opening_balances_v2 enable row level security;
alter table public.inventory_movements_v2 enable row level security;
alter table public.material_transformation_runs_v2 enable row level security;
alter table public.material_transformation_run_outputs_v2 enable row level security;

grant select, insert, update, delete on public.material_general_catalog_v2 to authenticated;
grant select, insert, update, delete on public.material_commercial_catalog_v2 to authenticated;
grant select, insert, update, delete on public.inventory_opening_balances_v2 to authenticated;
grant select, insert, update, delete on public.inventory_movements_v2 to authenticated;
grant select, insert, update, delete on public.material_transformation_runs_v2 to authenticated;
grant select, insert, update, delete on public.material_transformation_run_outputs_v2 to authenticated;

do $$
declare
  t text;
begin
  foreach t in array array[
    'material_general_catalog_v2',
    'material_commercial_catalog_v2',
    'inventory_opening_balances_v2',
    'inventory_movements_v2',
    'material_transformation_runs_v2',
    'material_transformation_run_outputs_v2'
  ]
  loop
    if not exists (
      select 1
        from pg_policies
       where schemaname = 'public'
         and tablename = t
         and policyname = t || '_authenticated_all'
    ) then
      execute format(
        'create policy %I on public.%I for all to authenticated using (true) with check (true)',
        t || '_authenticated_all',
        t
      );
    end if;
  end loop;
end
$$;

insert into public.material_general_catalog_v2 (code, name, sort_order, notes)
values
  ('CARTON', 'CARTON', 10, 'Base general para compras y aperturas de carton'),
  ('CHATARRA', 'CHATARRA', 20, 'Base general para compras y aperturas de chatarra'),
  ('METAL', 'METAL', 30, 'Base general para compras y aperturas de metal'),
  ('PLASTICO', 'PLASTICO', 40, 'Base general para compras y aperturas de plastico'),
  ('MADERA', 'MADERA', 50, 'Base general para compras y aperturas de madera'),
  ('PAPEL', 'PAPEL', 60, 'Base general para compras y aperturas de papel')
on conflict (code) do update
set name = excluded.name,
    sort_order = excluded.sort_order,
    notes = excluded.notes,
    is_active = true,
    updated_at = now();

with commercial_seed(code, name, family, general_code, classification_kind, flow_scope, tracks_patio_stock, allows_direct_entry, allows_transformation_output, allows_sale, sort_order, active, notes) as (
  values
    ('ACERO','ACERO','metal','METAL','classified_stock','BOTH',true,true,true,true,10,true,'Clasificacion comercial de metal'),
    ('ACERO_CON_PINTURA','ACERO CON PINTURA','metal','METAL','classified_stock','BOTH',true,true,true,true,20,true,'Clasificacion comercial de metal'),
    ('ALAMBRE_DE_ALUMINIO','ALAMBRE DE ALUMINIO','metal','METAL','classified_stock','BOTH',true,true,true,true,30,true,'Clasificacion comercial de metal'),
    ('ALUMINIO','ALUMINIO','metal','METAL','classified_stock','BOTH',true,true,true,true,40,true,'Clasificacion comercial de metal'),
    ('ALUMINIO_BLANDO','ALUMINIO BLANDO','metal','METAL','classified_stock','BOTH',true,true,true,true,50,true,'Clasificacion comercial de metal'),
    ('ALUMINIO_MACIZO','ALUMINIO MACIZO','metal','METAL','classified_stock','BOTH',true,true,true,true,60,true,'Clasificacion comercial de metal'),
    ('ALUMINIO_PISTON','ALUMINIO PISTON','metal','METAL','classified_stock','BOTH',true,true,true,true,70,true,'Clasificacion comercial de metal'),
    ('ALUMINIO_TUBO','ALUMINIO TUBO','metal','METAL','classified_stock','BOTH',true,true,true,true,80,true,'Clasificacion comercial de metal'),
    ('AMERICANO','AMERICANO','fiber','CARTON','legacy_alias','PRODUCTION_ONLY',false,false,false,false,90,false,'Alias heredado; reemplazar por CARTON_AMERICANO o PACA_AMERICANA segun flujo'),
    ('ARCHIVO','ARCHIVO','fiber','PAPEL','classified_stock','BOTH',true,true,true,true,100,true,'Clasificacion comercial de papel'),
    ('BASURA','BASURA','fiber','CARTON','classified_stock','BOTH',true,true,true,true,110,true,'Salida clasificada de carton'),
    ('BLANCO_SELECCION','BLANCO SELECCION','fiber','PAPEL','classified_stock','BOTH',true,true,true,true,120,true,'Clasificacion comercial de papel'),
    ('BOLSA','BOLSA','polymer','PLASTICO','classified_stock','BOTH',true,true,true,true,130,true,'Clasificacion comercial de plastico'),
    ('BOTE_GRANEL','BOTE GRANEL','metal','CHATARRA','classified_stock','BOTH',true,true,true,true,140,true,'Clasificacion comercial de chatarra'),
    ('BRONCE','BRONCE','metal','METAL','classified_stock','BOTH',true,true,true,true,150,true,'Clasificacion comercial de metal'),
    ('CAPLE','CAPLE','fiber','CARTON','classified_stock','BOTH',true,true,true,true,160,true,'Clasificacion comercial de carton'),
    ('CARTON_AMERICANO','CARTON AMERICANO','fiber','CARTON','general_input','IN',false,true,false,false,170,true,'Entrada comercial que suma a CARTON'),
    ('CARTON_NACIONAL','CARTON NACIONAL','fiber','CARTON','general_input','IN',false,true,false,false,180,true,'Entrada comercial que suma a CARTON'),
    ('CHATARRA_MIXTA','CHATARRA MIXTA','metal','CHATARRA','classified_stock','BOTH',true,true,true,true,190,true,'Clasificacion comercial de chatarra'),
    ('COBRE_CANDY','COBRE CANDY','metal','METAL','classified_stock','BOTH',true,true,true,true,200,true,'Clasificacion comercial de metal'),
    ('COBRE_DE_PRIMERA','COBRE DE PRIMERA','metal','METAL','classified_stock','BOTH',true,true,true,true,210,true,'Clasificacion comercial de metal'),
    ('COBRE_DE_SEGUNDA','COBRE DE SEGUNDA','metal','METAL','classified_stock','BOTH',true,true,true,true,220,true,'Clasificacion comercial de metal'),
    ('COLOR','COLOR','fiber','PAPEL','classified_stock','BOTH',true,true,true,true,230,true,'Clasificacion comercial de papel'),
    ('FIERRO_VACIADO','FIERRO VACIADO','metal','METAL','classified_stock','BOTH',true,true,true,true,240,true,'Clasificacion comercial de metal'),
    ('FOLLETO','FOLLETO','fiber','PAPEL','classified_stock','BOTH',true,true,true,true,250,true,'Clasificacion comercial de papel'),
    ('LAMINA','LAMINA','metal','CHATARRA','classified_stock','BOTH',true,true,true,true,260,true,'Clasificacion comercial de chatarra'),
    ('LENA','LENA','other','MADERA','classified_stock','BOTH',true,true,true,true,270,true,'Clasificacion comercial de madera'),
    ('LIBRO','LIBRO','fiber','PAPEL','classified_stock','BOTH',true,true,true,true,280,true,'Clasificacion comercial de papel'),
    ('LIMPIO','LIMPIO','fiber','CARTON','legacy_alias','PRODUCTION_ONLY',false,false,false,false,290,false,'Alias heredado; reemplazar por PACA_LIMPIA'),
    ('LODOS','LODOS','other','CARTON','classified_stock','BOTH',true,true,true,true,300,true,'Clasificacion comercial heredada; validar si se conserva como subproducto'),
    ('MAGAZINE','MAGAZINE','fiber','PAPEL','classified_stock','BOTH',true,true,true,true,310,true,'Clasificacion comercial de papel'),
    ('MANGUERA','MANGUERA','polymer','PLASTICO','classified_stock','BOTH',true,true,true,true,320,true,'Clasificacion comercial de plastico'),
    ('MIXTO','MIXTO','metal','CHATARRA','classified_stock','BOTH',true,true,true,true,330,true,'Clasificacion comercial de chatarra'),
    ('MIXTO_PARA_PROCESAR','MIXTO PARA PROCESAR','metal','CHATARRA','classified_stock','BOTH',true,true,true,true,340,true,'Clasificacion comercial de chatarra'),
    ('NACIONAL','NACIONAL','fiber','CARTON','legacy_alias','PRODUCTION_ONLY',false,false,false,false,350,false,'Alias heredado; reemplazar por CARTON_NACIONAL o PACA_NACIONAL segun flujo'),
    ('PACA_AMERICANA','PACA AMERICANA','fiber','CARTON','classified_stock','BOTH',true,true,true,true,360,true,'Producto clasificado de carton para patio y venta'),
    ('PACA_BASURA','PACA BASURA','fiber','CARTON','classified_stock','BOTH',true,true,true,true,370,true,'Producto clasificado de carton para patio y venta'),
    ('PACA_DE_PRIMERA','PACA DE PRIMERA','metal','CHATARRA','classified_stock','BOTH',true,true,true,true,380,true,'Clasificacion comercial de chatarra'),
    ('PACA_DE_SEGUNDA','PACA DE SEGUNDA','metal','CHATARRA','classified_stock','BOTH',true,true,true,true,390,true,'Clasificacion comercial de chatarra'),
    ('PACA_LIMPIA','PACA LIMPIA','fiber','CARTON','classified_stock','BOTH',true,true,true,true,400,true,'Producto clasificado de carton para patio y venta'),
    ('PACA_NACIONAL','PACA NACIONAL','fiber','CARTON','classified_stock','BOTH',true,true,true,true,410,true,'Producto clasificado de carton para patio y venta'),
    ('PAPEL_REVUELTO','PAPEL REVUELTO','fiber','PAPEL','classified_stock','BOTH',true,true,true,true,420,true,'Clasificacion comercial de papel'),
    ('PEDACERA','PEDACERA','other','MADERA','classified_stock','BOTH',true,true,true,true,430,true,'Clasificacion comercial de madera'),
    ('PERFIL_CON_PINTURA','PERFIL CON PINTURA','metal','METAL','classified_stock','BOTH',true,true,true,true,440,true,'Clasificacion comercial de metal'),
    ('PERFIL_SIN_PINTURA','PERFIL SIN PINTURA','metal','METAL','classified_stock','BOTH',true,true,true,true,450,true,'Clasificacion comercial de metal'),
    ('PESADO','PESADO','metal','CHATARRA','classified_stock','BOTH',true,true,true,true,460,true,'Clasificacion comercial de chatarra'),
    ('PLACA_DE_ALUMINIO','PLACA DE ALUMINIO','metal','METAL','classified_stock','BOTH',true,true,true,true,470,true,'Clasificacion comercial de metal'),
    ('PLACA_Y_ESTRUCTURA_CORTA','PLACA Y ESTRUCTURA CORTA','metal','CHATARRA','classified_stock','BOTH',true,true,true,true,480,true,'Clasificacion comercial de chatarra'),
    ('PLACA_Y_ESTRUCTURA_LARGA','PLACA Y ESTRUCTURA LARGA','metal','CHATARRA','classified_stock','BOTH',true,true,true,true,490,true,'Clasificacion comercial de chatarra'),
    ('PLASTICO_MIXTO','PLASTICO MIXTO','polymer','PLASTICO','classified_stock','BOTH',true,true,true,true,500,true,'Clasificacion comercial de plastico'),
    ('RADIADOR_DE_ALUMINIO','RADIADOR DE ALUMINIO','metal','METAL','classified_stock','BOTH',true,true,true,true,510,true,'Clasificacion comercial de metal'),
    ('RADIADOR_DE_COBRE','RADIADOR DE COBRE','metal','METAL','classified_stock','BOTH',true,true,true,true,520,true,'Clasificacion comercial de metal'),
    ('RADIADOR_LATON','RADIADOR LATON','metal','METAL','classified_stock','BOTH',true,true,true,true,530,true,'Clasificacion comercial de metal'),
    ('RADIADOR_PUNTA_DE_COBRE','RADIADOR PUNTA DE COBRE','metal','METAL','classified_stock','BOTH',true,true,true,true,540,true,'Clasificacion comercial de metal'),
    ('REBABA','REBABA','metal','CHATARRA','classified_stock','BOTH',true,true,true,true,550,true,'Clasificacion comercial de chatarra'),
    ('REBABA_DE_BRONCE','REBABA DE BRONCE','metal','METAL','classified_stock','BOTH',true,true,true,true,560,true,'Clasificacion comercial de metal'),
    ('RETORNO_INDUSTRIAL','RETORNO INDUSTRIAL','metal','CHATARRA','classified_stock','BOTH',true,true,true,true,570,true,'Clasificacion comercial de chatarra'),
    ('RETORNO_INDUSTRIAL_ALTO_RES','RETORNO INDUSTRIAL ALTO RES','metal','CHATARRA','classified_stock','BOTH',true,true,true,true,580,true,'Clasificacion comercial de chatarra'),
    ('RETORNO_INDUSTRIAL_ESPECIAL','RETORNO INDUSTRIAL ESPECIAL','metal','CHATARRA','classified_stock','BOTH',true,true,true,true,590,true,'Clasificacion comercial de chatarra'),
    ('REVUELTO','REVUELTO','fiber','PAPEL','general_input','IN',false,true,false,false,600,true,'Entrada comercial que suma a PAPEL'),
    ('RIN_CHICO','RIN CHICO','metal','METAL','classified_stock','BOTH',true,true,true,true,610,true,'Clasificacion comercial de metal'),
    ('RIN_DE_ALUMINIO','RIN DE ALUMINIO','metal','METAL','classified_stock','BOTH',true,true,true,true,620,true,'Clasificacion comercial de metal'),
    ('RIN_GRANDE','RIN GRANDE','metal','METAL','classified_stock','BOTH',true,true,true,true,630,true,'Clasificacion comercial de metal'),
    ('TARIMA','TARIMA','other','MADERA','classified_stock','BOTH',true,true,true,true,640,true,'Clasificacion comercial de madera'),
    ('TRASTE','TRASTE','metal','METAL','classified_stock','BOTH',true,true,true,true,650,true,'Clasificacion comercial de metal'),
    ('TUBO','TUBO','metal','METAL','classified_stock','BOTH',true,true,true,true,660,true,'Clasificacion comercial de metal'),
    ('UNICEL','UNICEL','polymer','PLASTICO','classified_stock','BOTH',true,true,true,true,670,true,'Clasificacion comercial de plastico')
)
insert into public.material_commercial_catalog_v2 (
  code,
  name,
  family,
  general_material_id,
  classification_kind,
  flow_scope,
  tracks_patio_stock,
  allows_direct_entry,
  allows_transformation_output,
  allows_sale,
  sort_order,
  is_active,
  notes
)
select
  s.code,
  s.name,
  s.family,
  g.id,
  s.classification_kind::public.material_commercial_classification_kind_v2,
  s.flow_scope::public.material_commercial_flow_scope_v2,
  s.tracks_patio_stock,
  s.allows_direct_entry,
  s.allows_transformation_output,
  s.allows_sale,
  s.sort_order,
  s.active,
  s.notes
from commercial_seed s
join public.material_general_catalog_v2 g
  on g.code = s.general_code
on conflict (code) do update
set name = excluded.name,
    family = excluded.family,
    general_material_id = excluded.general_material_id,
    classification_kind = excluded.classification_kind,
    flow_scope = excluded.flow_scope,
    tracks_patio_stock = excluded.tracks_patio_stock,
    allows_direct_entry = excluded.allows_direct_entry,
    allows_transformation_output = excluded.allows_transformation_output,
    allows_sale = excluded.allows_sale,
    sort_order = excluded.sort_order,
    is_active = excluded.is_active,
    notes = excluded.notes,
    updated_at = now();

create or replace view public.v_inventory_general_balance_v2 as
with opening as (
  select
    general_material_id,
    coalesce(sum(weight_kg), 0)::numeric as opening_kg
  from public.inventory_opening_balances_v2
  where inventory_level = 'GENERAL'
  group by 1
),
movements as (
  select
    general_material_id,
    coalesce(sum(
      case flow
        when 'IN' then weight_kg
        when 'OUT' then -weight_kg
        else weight_kg
      end
    ), 0)::numeric as movement_kg
  from public.inventory_movements_v2
  where inventory_level = 'GENERAL'
  group by 1
)
select
  g.id,
  g.code,
  g.name,
  coalesce(o.opening_kg, 0) as opening_kg,
  coalesce(m.movement_kg, 0) as movement_kg,
  coalesce(o.opening_kg, 0) + coalesce(m.movement_kg, 0) as on_hand_kg
from public.material_general_catalog_v2 g
left join opening o on o.general_material_id = g.id
left join movements m on m.general_material_id = g.id
where g.is_active;

create or replace view public.v_inventory_commercial_balance_v2 as
with opening as (
  select
    commercial_material_id,
    coalesce(sum(weight_kg), 0)::numeric as opening_kg
  from public.inventory_opening_balances_v2
  where inventory_level = 'COMMERCIAL'
  group by 1
),
movements as (
  select
    commercial_material_id,
    coalesce(sum(
      case flow
        when 'IN' then weight_kg
        when 'OUT' then -weight_kg
        else weight_kg
      end
    ), 0)::numeric as movement_kg
  from public.inventory_movements_v2
  where inventory_level = 'COMMERCIAL'
  group by 1
)
select
  c.id,
  c.code,
  c.name,
  c.family,
  g.code as general_code,
  coalesce(o.opening_kg, 0) as opening_kg,
  coalesce(m.movement_kg, 0) as movement_kg,
  coalesce(o.opening_kg, 0) + coalesce(m.movement_kg, 0) as on_hand_kg
from public.material_commercial_catalog_v2 c
join public.material_general_catalog_v2 g on g.id = c.general_material_id
left join opening o on o.commercial_material_id = c.id
left join movements m on m.commercial_material_id = c.id
where c.is_active;

grant select on public.v_inventory_general_balance_v2 to authenticated;
grant select on public.v_inventory_commercial_balance_v2 to authenticated;

commit;
