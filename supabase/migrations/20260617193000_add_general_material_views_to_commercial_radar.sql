begin;

drop view if exists public.v_commercial_counterparty_general_activity_snapshot;
drop view if exists public.v_commercial_material_general_snapshot;
drop view if exists public.v_commercial_variation_alerts;
drop view if exists public.v_commercial_counterparty_activity_snapshot;
drop view if exists public.v_commercial_material_market_snapshot;
drop view if exists public.v_commercial_market_events;

create view public.v_commercial_market_events as
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
    coalesce(gen.code, regexp_replace(upper(btrim(t.material_label_snapshot)), '\s+', ' ', 'g')) as general_material_key,
    coalesce(gen.name, t.material_label_snapshot) as general_material_label,
    t.payable_weight::numeric(14,4) as volume_kg,
    t.amount_total::numeric(14,4) as amount_total,
    (t.price_at_entry + t.premium_per_kg)::numeric(14,4) as unit_price
  from public.men_tickets t
  left join public.v_commercial_unified_counterparties u
    on u.source_area = 'menudeo'
   and u.source_record_id = t.counterparty_id::text
  left join public.material_general_catalog_v2 gen
    on gen.id = t.general_material_id
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
    coalesce(gen.code, regexp_replace(upper(btrim(t.material_name_snapshot)), '\s+', ' ', 'g')) as general_material_key,
    coalesce(gen.name, t.material_name_snapshot) as general_material_label,
    t.payable_weight::numeric(14,4) as volume_kg,
    t.amount::numeric(14,4) as amount_total,
    (t.price + t.premium)::numeric(14,4) as unit_price
  from public.compras_tickets t
  left join public.v_commercial_unified_counterparties u
    on u.source_area = 'mayoreo_compras'
   and u.source_record_id = t.provider_id::text
  left join public.compras_material_catalog mat
    on mat.id = t.material_id
  left join public.compras_material_catalog gen
    on gen.id = coalesce(mat.general_material_id, mat.id)
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
    coalesce(gen.code, regexp_replace(upper(btrim(r.material_name_snapshot)), '\s+', ' ', 'g')) as general_material_key,
    coalesce(gen.name, r.material_name_snapshot) as general_material_label,
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
  left join public.mayoreo_material_catalog mat
    on mat.id = r.material_id
  left join public.mayoreo_material_catalog gen
    on gen.id = coalesce(mat.general_material_id, mat.id)
)
select * from men_events
union all
select * from compras_events
union all
select * from ventas_events;

comment on view public.v_commercial_market_events is
  'Eventos readonly normalizados para Desarrollo Comercial. Conservan source_area, canal, flujo y tipo comercial de contraparte.';

create view public.v_commercial_material_market_snapshot as
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

create view public.v_commercial_counterparty_activity_snapshot as
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

create view public.v_commercial_variation_alerts as
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
    em.current_value,
    em.baseline_value,
    em.delta_percent,
    em.days_since_last_activity,
    em.message,
    em.suggested_action,
    em.detected_at
  from (
    select
      em.*,
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
  ) em
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
    coalesce(s.avg_days_between_operations, 0)::numeric(14,4) as baseline_value,
    null::numeric as delta_percent,
    extract(day from now() - s.last_activity_at)::integer as days_since_last_activity,
    s.name || ' tiene menor frecuencia operativa en '
      || coalesce(s.material_label, 'material sin etiqueta')
      || ' para el segmento ' || s.counterparty_business_group || '.' as message,
    'Marcar y validar continuidad, precio o competencia.'::text as suggested_action,
    now() as detected_at
  from public.v_commercial_counterparty_activity_snapshot s
  where s.last_activity_at is not null
    and extract(day from now() - s.last_activity_at) > greatest(7, coalesce(s.avg_days_between_operations, 0) * 2)
)
select * from entity_alerts
union all
select * from frequency_alerts;

create or replace view public.v_commercial_material_general_snapshot as
select
  e.channel,
  e.counterparty_business_group,
  e.counterparty_business_type,
  e.general_material_key,
  min(e.general_material_label) as general_material_label,
  sum(e.volume_kg) filter (
    where e.flow = 'purchase'
      and e.event_at >= date_trunc('day', now()) - interval '29 days'
  )::numeric(14,4) as buy_volume_30d,
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
  )::numeric(14,4) as sell_amount_30d
from public.v_commercial_market_events e
group by
  e.channel,
  e.counterparty_business_group,
  e.counterparty_business_type,
  e.general_material_key;

comment on view public.v_commercial_material_general_snapshot is
  'Resumen readonly por material general y segmento comparable para Desarrollo Comercial.';

create or replace view public.v_commercial_counterparty_general_activity_snapshot as
select
  e.source_area,
  e.source_record_id,
  e.counterparty_name as name,
  e.kind,
  e.channel,
  e.flow,
  e.counterparty_business_type,
  e.counterparty_business_group,
  e.general_material_key,
  min(e.general_material_label) as general_material_label,
  sum(e.volume_kg) filter (
    where e.event_at >= date_trunc('day', now()) - interval '29 days'
  )::numeric(14,4) as volume_30d,
  sum(e.amount_total) filter (
    where e.event_at >= date_trunc('day', now()) - interval '29 days'
  )::numeric(14,4) as amount_30d,
  max(e.event_at) as last_activity_at
from public.v_commercial_market_events e
group by
  e.source_area,
  e.source_record_id,
  e.counterparty_name,
  e.kind,
  e.channel,
  e.flow,
  e.counterparty_business_type,
  e.counterparty_business_group,
  e.general_material_key;

comment on view public.v_commercial_counterparty_general_activity_snapshot is
  'Resumen readonly por contraparte y material general para Desarrollo Comercial.';

grant select on public.v_commercial_market_events to authenticated;
grant select on public.v_commercial_material_market_snapshot to authenticated;
grant select on public.v_commercial_counterparty_activity_snapshot to authenticated;
grant select on public.v_commercial_variation_alerts to authenticated;
grant select on public.v_commercial_material_general_snapshot to authenticated;
grant select on public.v_commercial_counterparty_general_activity_snapshot to authenticated;

commit;
