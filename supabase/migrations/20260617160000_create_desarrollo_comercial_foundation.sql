begin;

create table if not exists public.commercial_accounts (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  kind text not null
    check (kind in ('supplier', 'customer', 'both', 'prospect')),
  counterparty_business_type text not null default 'prospect',
  counterparty_business_group text not null default 'manual_prospect',
  source_area text
    check (source_area in ('menudeo', 'mayoreo_ventas', 'mayoreo_compras', 'manual')),
  source_record_id text,
  primary_channel text not null default 'menudeo'
    check (primary_channel in ('menudeo', 'mayoreo')),
  city text,
  zone text,
  status text not null default 'prospecto'
    check (status in ('activo', 'prospecto', 'dormido', 'cerrado')),
  priority text not null default 'media'
    check (priority in ('baja', 'media', 'alta', 'estrategica')),
  owner_user_id uuid references auth.users (id) on delete set null,
  notes text,
  is_active boolean not null default true,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint commercial_accounts_display_name_trim_chk check (
    display_name = btrim(display_name) and length(display_name) > 0
  ),
  constraint commercial_accounts_source_record_pair_chk check (
    (source_area is null and source_record_id is null)
    or (source_area is not null and source_record_id is not null)
  )
);

create unique index if not exists commercial_accounts_source_unique_idx
  on public.commercial_accounts (source_area, source_record_id)
  where source_area is not null and source_record_id is not null;

create index if not exists commercial_accounts_display_name_idx
  on public.commercial_accounts (upper(display_name));

create index if not exists commercial_accounts_status_priority_idx
  on public.commercial_accounts (status, priority, updated_at desc);

create table if not exists public.commercial_account_contacts (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.commercial_accounts(id) on delete cascade,
  name text not null,
  role text,
  phone text,
  email text,
  preferred_channel text,
  notes text,
  is_primary boolean not null default false,
  is_active boolean not null default true,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint commercial_account_contacts_name_trim_chk check (
    name = btrim(name) and length(name) > 0
  )
);

create index if not exists commercial_account_contacts_account_idx
  on public.commercial_account_contacts (account_id, is_primary desc, name);

create table if not exists public.commercial_follow_ups (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.commercial_accounts(id) on delete cascade,
  contact_id uuid references public.commercial_account_contacts(id) on delete set null,
  interaction_at timestamptz not null default now(),
  interaction_type text not null
    check (interaction_type in ('llamada', 'whatsapp', 'visita', 'correo', 'cotizacion', 'seguimiento')),
  summary text not null,
  next_action text,
  next_follow_up_at timestamptz,
  material_interest_snapshot text,
  estimated_volume_snapshot numeric(14,4),
  price_reference_snapshot numeric(14,4),
  status text not null default 'abierto'
    check (status in ('abierto', 'hecho', 'pospuesto', 'sin_respuesta')),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint commercial_follow_ups_summary_trim_chk check (
    summary = btrim(summary) and length(summary) > 0
  )
);

create index if not exists commercial_follow_ups_account_idx
  on public.commercial_follow_ups (account_id, interaction_at desc);

create index if not exists commercial_follow_ups_next_idx
  on public.commercial_follow_ups (status, next_follow_up_at asc);

create table if not exists public.commercial_account_material_focus (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.commercial_accounts(id) on delete cascade,
  material_key text not null,
  material_label text not null,
  interest_type text not null
    check (interest_type in ('compra', 'venta', 'ambos')),
  priority text not null default 'media'
    check (priority in ('baja', 'media', 'alta', 'estrategica')),
  notes text,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint commercial_account_material_focus_material_key_trim_chk check (
    material_key = btrim(material_key) and length(material_key) > 0
  ),
  constraint commercial_account_material_focus_material_label_trim_chk check (
    material_label = btrim(material_label) and length(material_label) > 0
  )
);

create unique index if not exists commercial_account_material_focus_unique_idx
  on public.commercial_account_material_focus (account_id, material_key, interest_type);

create index if not exists commercial_account_material_focus_account_idx
  on public.commercial_account_material_focus (account_id, priority desc);

create or replace function public.set_commercial_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_commercial_accounts_updated_at on public.commercial_accounts;
create trigger trg_commercial_accounts_updated_at
before update on public.commercial_accounts
for each row execute function public.set_commercial_updated_at();

drop trigger if exists trg_commercial_account_contacts_updated_at on public.commercial_account_contacts;
create trigger trg_commercial_account_contacts_updated_at
before update on public.commercial_account_contacts
for each row execute function public.set_commercial_updated_at();

drop trigger if exists trg_commercial_follow_ups_updated_at on public.commercial_follow_ups;
create trigger trg_commercial_follow_ups_updated_at
before update on public.commercial_follow_ups
for each row execute function public.set_commercial_updated_at();

drop trigger if exists trg_commercial_account_material_focus_updated_at on public.commercial_account_material_focus;
create trigger trg_commercial_account_material_focus_updated_at
before update on public.commercial_account_material_focus
for each row execute function public.set_commercial_updated_at();

create or replace view public.v_commercial_unified_counterparties as
select
  'menudeo'::text as source_area,
  cp.id::text as source_record_id,
  'menudeo'::text as channel,
  case
    when cp.kind = 'customer' then 'sale'
    else 'purchase'
  end as flow,
  cp.name,
  cp.kind,
  case
    when cp.kind = 'customer' then 'cliente_final'
    when upper(coalesce(cp.group_code, '')) like '%EMPRESA%' then 'empresa_generadora'
    when upper(coalesce(cp.group_code, '')) like '%TRICIC%' then 'proveedor_directo'
    when upper(coalesce(cp.group_code, '')) like '%PREFEREN%' then 'proveedor_grande'
    else 'proveedor_directo'
  end as counterparty_business_type,
  case
    when cp.kind = 'customer' then 'menudeo_cliente'
    when upper(coalesce(cp.group_code, '')) like '%EMPRESA%' then 'menudeo_empresa'
    when upper(coalesce(cp.group_code, '')) like '%TRICIC%' then 'menudeo_triciclo'
    when upper(coalesce(cp.group_code, '')) like '%PREFEREN%' then 'menudeo_preferencial'
    else 'menudeo_proveedor_directo'
  end as counterparty_business_group,
  coalesce(cp.group_code, '') as source_group_label,
  nullif(btrim(cp.notes), '') as notes,
  cp.site_id::text as related_site_id,
  cp.is_active as active,
  null::text as contact
from public.men_counterparties cp

union all

select
  'mayoreo_compras'::text as source_area,
  cp.id::text as source_record_id,
  'mayoreo'::text as channel,
  'purchase'::text as flow,
  cp.name,
  'supplier'::text as kind,
  'proveedor_grande'::text as counterparty_business_type,
  'mayoreo_proveedor'::text as counterparty_business_group,
  null::text as source_group_label,
  nullif(btrim(cp.notes), '') as notes,
  null::text as related_site_id,
  cp.is_active as active,
  nullif(btrim(cp.contact), '') as contact
from public.compras_counterparties cp

union all

select
  'mayoreo_ventas'::text as source_area,
  cp.id::text as source_record_id,
  'mayoreo'::text as channel,
  'sale'::text as flow,
  cp.name,
  'customer'::text as kind,
  'cliente_final'::text as counterparty_business_type,
  'mayoreo_cliente'::text as counterparty_business_group,
  null::text as source_group_label,
  nullif(btrim(cp.notes), '') as notes,
  null::text as related_site_id,
  cp.is_active as active,
  nullif(btrim(cp.contact), '') as contact
from public.mayoreo_counterparties cp;

comment on view public.v_commercial_unified_counterparties is
  'Vista readonly de contrapartes para Desarrollo Comercial. Conserva canal y segmento comparable para evitar mezclar benchmarks.';

create or replace view public.v_commercial_market_events as
with men_events as (
  select
    'menudeo'::text as source_area,
    t.id::text as source_event_id,
    t.ticket_date::timestamptz as event_at,
    'menudeo'::text as channel,
    t.direction as flow,
    t.counterparty_id::text as source_record_id,
    t.counterparty_name_snapshot as counterparty_name,
    coalesce(u.kind, case when t.direction = 'sale' then 'customer' else 'supplier' end) as kind,
    coalesce(
      u.counterparty_business_type,
      case
        when t.direction = 'sale' then 'cliente_final'
        else 'proveedor_directo'
      end
    ) as counterparty_business_type,
    coalesce(
      u.counterparty_business_group,
      case
        when t.direction = 'sale' then 'menudeo_cliente'
        else 'menudeo_proveedor_directo'
      end
    ) as counterparty_business_group,
    regexp_replace(upper(btrim(t.material_label_snapshot)), '\s+', ' ', 'g') as material_key,
    t.material_label_snapshot as material_label,
    t.payable_weight::numeric(14,4) as volume_kg,
    t.amount_total::numeric(14,4) as amount_total,
    (t.price_at_entry + t.premium_per_kg)::numeric(14,4) as unit_price
  from public.men_tickets t
  left join public.v_commercial_unified_counterparties u
    on u.source_area = 'menudeo'
   and u.source_record_id = t.counterparty_id::text
),
compras_events as (
  select
    'mayoreo_compras'::text as source_area,
    t.id::text as source_event_id,
    t.ticket_date as event_at,
    'mayoreo'::text as channel,
    'purchase'::text as flow,
    t.provider_id::text as source_record_id,
    t.provider_name_snapshot as counterparty_name,
    'supplier'::text as kind,
    coalesce(u.counterparty_business_type, 'proveedor_grande') as counterparty_business_type,
    coalesce(u.counterparty_business_group, 'mayoreo_proveedor') as counterparty_business_group,
    regexp_replace(upper(btrim(t.material_name_snapshot)), '\s+', ' ', 'g') as material_key,
    t.material_name_snapshot as material_label,
    t.payable_weight::numeric(14,4) as volume_kg,
    t.amount::numeric(14,4) as amount_total,
    (t.price + t.premium)::numeric(14,4) as unit_price
  from public.compras_tickets t
  left join public.v_commercial_unified_counterparties u
    on u.source_area = 'mayoreo_compras'
   and u.source_record_id = t.provider_id::text
),
ventas_events as (
  select
    'mayoreo_ventas'::text as source_area,
    r.id::text as source_event_id,
    r.sale_date as event_at,
    'mayoreo'::text as channel,
    'sale'::text as flow,
    r.client_id::text as source_record_id,
    r.client_name_snapshot as counterparty_name,
    'customer'::text as kind,
    coalesce(u.counterparty_business_type, 'cliente_final') as counterparty_business_type,
    coalesce(u.counterparty_business_group, 'mayoreo_cliente') as counterparty_business_group,
    regexp_replace(upper(btrim(r.material_name_snapshot)), '\s+', ' ', 'g') as material_key,
    r.material_name_snapshot as material_label,
    coalesce(r.approved_weight, r.exit_weight, 0)::numeric(14,4) as volume_kg,
    coalesce(
      nullif(r.approved_amount, 0),
      coalesce(r.approved_weight, r.exit_weight, 0) * coalesce(r.approved_price, r.price_snapshot, 0),
      0
    )::numeric(14,4) as amount_total,
    coalesce(r.approved_price, r.price_snapshot, 0)::numeric(14,4) as unit_price
  from public.mayoreo_sales_reports r
  left join public.v_commercial_unified_counterparties u
    on u.source_area = 'mayoreo_ventas'
   and u.source_record_id = r.client_id::text
)
select * from men_events
union all
select * from compras_events
union all
select * from ventas_events;

comment on view public.v_commercial_market_events is
  'Eventos readonly normalizados para Desarrollo Comercial. Conservan source_area, canal, flujo y tipo comercial de contraparte.';

create or replace view public.v_commercial_material_market_snapshot as
select
  e.channel,
  e.counterparty_business_group,
  e.counterparty_business_type,
  e.material_key,
  min(e.material_label) as material_label,
  sum(e.volume_kg) filter (
    where e.flow = 'purchase'
      and e.event_at >= date_trunc('day', now()) - interval '6 days'
  )::numeric(14,4) as buy_volume_7d,
  sum(e.volume_kg) filter (
    where e.flow = 'purchase'
      and e.event_at >= date_trunc('day', now()) - interval '29 days'
  )::numeric(14,4) as buy_volume_30d,
  sum(e.volume_kg) filter (
    where e.flow = 'sale'
      and e.event_at >= date_trunc('day', now()) - interval '6 days'
  )::numeric(14,4) as sell_volume_7d,
  sum(e.volume_kg) filter (
    where e.flow = 'sale'
      and e.event_at >= date_trunc('day', now()) - interval '29 days'
  )::numeric(14,4) as sell_volume_30d,
  sum(e.amount_total) filter (
    where e.flow = 'purchase'
      and e.event_at >= date_trunc('day', now()) - interval '29 days'
  )::numeric(14,4) as buy_amount_30d,
  sum(e.amount_total) filter (
    where e.flow = 'sale'
      and e.event_at >= date_trunc('day', now()) - interval '29 days'
  )::numeric(14,4) as sell_amount_30d,
  (
    sum(e.amount_total) filter (
      where e.flow = 'purchase'
        and e.event_at >= date_trunc('day', now()) - interval '29 days'
    )
    / nullif(sum(e.volume_kg) filter (
      where e.flow = 'purchase'
        and e.event_at >= date_trunc('day', now()) - interval '29 days'
    ), 0)
  )::numeric(14,4) as avg_buy_price_30d,
  (
    sum(e.amount_total) filter (
      where e.flow = 'sale'
        and e.event_at >= date_trunc('day', now()) - interval '29 days'
    )
    / nullif(sum(e.volume_kg) filter (
      where e.flow = 'sale'
        and e.event_at >= date_trunc('day', now()) - interval '29 days'
    ), 0)
  )::numeric(14,4) as avg_sell_price_30d,
  max(e.event_at) as last_activity_at
from public.v_commercial_market_events e
group by
  e.channel,
  e.counterparty_business_group,
  e.counterparty_business_type,
  e.material_key;

comment on view public.v_commercial_material_market_snapshot is
  'Resumen readonly por material y segmento comparable. Nunca mezcla benchmarks unitarios entre canales o grupos comerciales.';

create or replace view public.v_commercial_counterparty_activity_snapshot as
with base as (
  select
    e.source_area,
    e.source_record_id,
    e.counterparty_name as name,
    e.kind,
    e.channel,
    e.flow,
    e.counterparty_business_type,
    e.counterparty_business_group,
    e.material_key,
    e.material_label,
    e.event_at,
    e.volume_kg,
    e.amount_total,
    lag(e.event_at) over (
      partition by
        e.source_area,
        e.source_record_id,
        e.flow,
        e.counterparty_business_group,
        e.material_key
      order by e.event_at
    ) as prev_event_at
  from public.v_commercial_market_events e
)
select
  b.source_area,
  b.source_record_id,
  b.name,
  b.kind,
  b.channel,
  b.flow,
  b.counterparty_business_type,
  b.counterparty_business_group,
  b.material_key,
  min(b.material_label) as material_label,
  sum(b.volume_kg) filter (
    where b.event_at >= date_trunc('day', now()) - interval '13 days'
  )::numeric(14,4) as volume_14d,
  sum(b.volume_kg) filter (
    where b.event_at >= date_trunc('day', now()) - interval '29 days'
  )::numeric(14,4) as volume_30d,
  sum(b.amount_total) filter (
    where b.event_at >= date_trunc('day', now()) - interval '29 days'
  )::numeric(14,4) as amount_30d,
  max(b.event_at) as last_activity_at,
  count(*) filter (
    where b.event_at >= date_trunc('day', now()) - interval '29 days'
  )::integer as activity_count_30d,
  avg(extract(epoch from (b.event_at - b.prev_event_at)) / 86400.0)
    filter (where b.prev_event_at is not null)::numeric(14,4) as avg_days_between_operations
from base b
group by
  b.source_area,
  b.source_record_id,
  b.name,
  b.kind,
  b.channel,
  b.flow,
  b.counterparty_business_type,
  b.counterparty_business_group,
  b.material_key;

comment on view public.v_commercial_counterparty_activity_snapshot is
  'Resumen readonly de actividad por cuenta y material conservando canal, flujo y tipo comercial comparable.';

create or replace view public.v_commercial_variation_alerts as
with entity_metrics as (
  select
    e.source_area,
    e.source_record_id,
    e.counterparty_name as entity_label,
    e.channel,
    e.flow,
    e.counterparty_business_type,
    e.counterparty_business_group,
    e.material_key,
    min(e.material_label) as material_label,
    sum(e.volume_kg) filter (
      where e.event_at >= date_trunc('day', now()) - interval '13 days'
    )::numeric(14,4) as current_volume_14d,
    (
      sum(e.volume_kg) filter (
        where e.event_at < date_trunc('day', now()) - interval '13 days'
          and e.event_at >= date_trunc('day', now()) - interval '41 days'
      ) / 2.0
    )::numeric(14,4) as baseline_volume_14d,
    max(e.event_at) as last_activity_at
  from public.v_commercial_market_events e
  group by
    e.source_area,
    e.source_record_id,
    e.counterparty_name,
    e.channel,
    e.flow,
    e.counterparty_business_type,
    e.counterparty_business_group,
    e.material_key
),
entity_alerts as (
  select
    'counterparty_volume_drop'::text as alert_type,
    case
      when em.current_volume_14d <= em.baseline_volume_14d * 0.65 then 'critica'
      else 'atencion'
    end as severity,
    'counterparty'::text as entity_type,
    em.source_area || ':' || coalesce(em.source_record_id, 'sin_id') as entity_id,
    em.entity_label,
    em.channel,
    em.flow,
    em.counterparty_business_type,
    em.counterparty_business_group,
    em.material_key,
    em.material_label,
    em.current_volume_14d as current_value,
    em.baseline_volume_14d as baseline_value,
    case
      when coalesce(em.baseline_volume_14d, 0) = 0 then null
      else round(((em.current_volume_14d - em.baseline_volume_14d) / em.baseline_volume_14d) * 100.0, 2)
    end as delta_percent,
    extract(day from now() - em.last_activity_at)::integer as days_since_last_activity,
    em.entity_label || ' bajó su volumen de '
      || coalesce(em.material_label, 'material sin etiqueta')
      || ' en los últimos 14 días dentro del segmento '
      || em.counterparty_business_group || '.' as message,
    'Marcar y validar precio, servicio o competencia.'::text as suggested_action,
    now() as detected_at
  from entity_metrics em
  where coalesce(em.baseline_volume_14d, 0) >= 100
    and em.current_volume_14d < em.baseline_volume_14d * 0.80
),
frequency_alerts as (
  select
    'counterparty_frequency_drop'::text as alert_type,
    case
      when extract(day from now() - s.last_activity_at) > greatest(7, coalesce(s.avg_days_between_operations, 0) * 3) then 'critica'
      else 'atencion'
    end as severity,
    'counterparty'::text as entity_type,
    s.source_area || ':' || coalesce(s.source_record_id, 'sin_id') as entity_id,
    s.name as entity_label,
    s.channel,
    s.flow,
    s.counterparty_business_type,
    s.counterparty_business_group,
    s.material_key,
    s.material_label,
    extract(day from now() - s.last_activity_at)::numeric(14,4) as current_value,
    s.avg_days_between_operations as baseline_value,
    case
      when coalesce(s.avg_days_between_operations, 0) = 0 then null
      else round((((extract(day from now() - s.last_activity_at)) - s.avg_days_between_operations) / s.avg_days_between_operations) * 100.0, 2)
    end as delta_percent,
    extract(day from now() - s.last_activity_at)::integer as days_since_last_activity,
    s.name || ' lleva más tiempo sin operar de lo normal en '
      || coalesce(s.material_label, 'material sin etiqueta')
      || ' para el segmento ' || s.counterparty_business_group || '.' as message,
    'Marcar para recuperar frecuencia o entender freno.'::text as suggested_action,
    now() as detected_at
  from public.v_commercial_counterparty_activity_snapshot s
  where s.last_activity_at is not null
    and s.avg_days_between_operations is not null
    and extract(day from now() - s.last_activity_at) > greatest(7, s.avg_days_between_operations * 2)
),
material_metrics as (
  select
    e.channel,
    e.flow,
    e.counterparty_business_type,
    e.counterparty_business_group,
    e.material_key,
    min(e.material_label) as material_label,
    sum(e.volume_kg) filter (
      where e.event_at >= date_trunc('day', now()) - interval '13 days'
    )::numeric(14,4) as current_volume_14d,
    (
      sum(e.volume_kg) filter (
        where e.event_at < date_trunc('day', now()) - interval '13 days'
          and e.event_at >= date_trunc('day', now()) - interval '41 days'
      ) / 2.0
    )::numeric(14,4) as baseline_volume_14d
  from public.v_commercial_market_events e
  group by
    e.channel,
    e.flow,
    e.counterparty_business_type,
    e.counterparty_business_group,
    e.material_key
),
material_alerts as (
  select
    'material_volume_drop'::text as alert_type,
    case
      when mm.current_volume_14d <= mm.baseline_volume_14d * 0.65 then 'critica'
      else 'atencion'
    end as severity,
    'material'::text as entity_type,
    mm.channel || ':' || mm.flow || ':' || mm.counterparty_business_group || ':' || mm.material_key as entity_id,
    mm.material_label as entity_label,
    mm.channel,
    mm.flow,
    mm.counterparty_business_type,
    mm.counterparty_business_group,
    mm.material_key,
    mm.material_label,
    mm.current_volume_14d as current_value,
    mm.baseline_volume_14d as baseline_value,
    case
      when coalesce(mm.baseline_volume_14d, 0) = 0 then null
      else round(((mm.current_volume_14d - mm.baseline_volume_14d) / mm.baseline_volume_14d) * 100.0, 2)
    end as delta_percent,
    null::integer as days_since_last_activity,
    mm.material_label || ' cayó de volumen en el segmento '
      || mm.counterparty_business_group || ' de ' || mm.channel || '.' as message,
    'Validar si es tema de precio, temporada o fuga de cuenta.'::text as suggested_action,
    now() as detected_at
  from material_metrics mm
  where coalesce(mm.baseline_volume_14d, 0) >= 250
    and mm.current_volume_14d < mm.baseline_volume_14d * 0.80
)
select * from entity_alerts
union all
select * from frequency_alerts
union all
select * from material_alerts;

comment on view public.v_commercial_variation_alerts is
  'Alertas readonly para Desarrollo Comercial. Todas se calculan dentro de segmentos comparables para evitar promedios mezclados entre menudeo, mayoreo o tipos distintos de contraparte.';

alter table public.commercial_accounts enable row level security;
alter table public.commercial_account_contacts enable row level security;
alter table public.commercial_follow_ups enable row level security;
alter table public.commercial_account_material_focus enable row level security;

grant select, insert, update, delete on public.commercial_accounts to authenticated;
grant select, insert, update, delete on public.commercial_account_contacts to authenticated;
grant select, insert, update, delete on public.commercial_follow_ups to authenticated;
grant select, insert, update, delete on public.commercial_account_material_focus to authenticated;

grant select on public.v_commercial_unified_counterparties to authenticated;
grant select on public.v_commercial_market_events to authenticated;
grant select on public.v_commercial_material_market_snapshot to authenticated;
grant select on public.v_commercial_counterparty_activity_snapshot to authenticated;
grant select on public.v_commercial_variation_alerts to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'commercial_accounts'
      and policyname = 'commercial_accounts_authenticated_all'
  ) then
    create policy commercial_accounts_authenticated_all
      on public.commercial_accounts
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'commercial_account_contacts'
      and policyname = 'commercial_account_contacts_authenticated_all'
  ) then
    create policy commercial_account_contacts_authenticated_all
      on public.commercial_account_contacts
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'commercial_follow_ups'
      and policyname = 'commercial_follow_ups_authenticated_all'
  ) then
    create policy commercial_follow_ups_authenticated_all
      on public.commercial_follow_ups
      for all
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'commercial_account_material_focus'
      and policyname = 'commercial_account_material_focus_authenticated_all'
  ) then
    create policy commercial_account_material_focus_authenticated_all
      on public.commercial_account_material_focus
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
