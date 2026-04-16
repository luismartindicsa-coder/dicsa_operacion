begin;

create table if not exists public.men_price_adjustment_history (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null default gen_random_uuid(),
  price_id uuid not null references public.men_counterparty_material_prices(id) on delete cascade,
  counterparty_id uuid references public.men_counterparties(id) on delete set null,
  counterparty_name_snapshot text not null,
  group_code_snapshot text not null,
  general_material_id uuid references public.material_general_catalog_v2(id) on delete set null,
  commercial_material_id uuid references public.material_commercial_catalog_v2(id) on delete set null,
  material_alias_id uuid references public.men_material_aliases(id) on delete set null,
  material_label_snapshot text not null,
  previous_price numeric(14,4),
  new_price numeric(14,4) not null,
  adjustment_mode text,
  adjustment_value numeric(14,4),
  event_kind text not null default 'direct_edit',
  event_source text not null default 'system',
  reason text,
  is_active_snapshot boolean not null default true,
  applied_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  constraint men_price_adjustment_history_counterparty_name_trim_chk check (
    counterparty_name_snapshot = btrim(counterparty_name_snapshot)
    and length(counterparty_name_snapshot) > 0
  ),
  constraint men_price_adjustment_history_group_trim_chk check (
    group_code_snapshot = btrim(group_code_snapshot)
    and length(group_code_snapshot) > 0
  ),
  constraint men_price_adjustment_history_label_trim_chk check (
    material_label_snapshot = btrim(material_label_snapshot)
    and length(material_label_snapshot) > 0
  ),
  constraint men_price_adjustment_history_new_price_chk check (
    new_price >= 0
  ),
  constraint men_price_adjustment_history_previous_price_chk check (
    previous_price is null or previous_price >= 0
  ),
  constraint men_price_adjustment_history_event_kind_chk check (
    event_kind in ('create', 'adjustment', 'direct_edit', 'status_change')
  ),
  constraint men_price_adjustment_history_mode_chk check (
    adjustment_mode is null
    or adjustment_mode in ('delta_amount', 'delta_percent', 'replace')
  ),
  constraint men_price_adjustment_history_event_source_chk check (
    event_source in ('catalog_insert', 'catalog_edit', 'adjustment_workspace', 'migration', 'system')
  )
);

create index if not exists men_price_adjustment_history_price_created_idx
  on public.men_price_adjustment_history (price_id, created_at desc, id desc);

create index if not exists men_price_adjustment_history_batch_idx
  on public.men_price_adjustment_history (batch_id, created_at desc);

create index if not exists men_price_adjustment_history_counterparty_idx
  on public.men_price_adjustment_history (counterparty_id, created_at desc);

alter table public.men_price_adjustment_history enable row level security;

grant select, insert, update, delete on public.men_price_adjustment_history to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'men_price_adjustment_history'
      and policyname = 'men_price_adjustment_history_authenticated_all'
  ) then
    create policy men_price_adjustment_history_authenticated_all
      on public.men_price_adjustment_history
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

create or replace function public.log_men_price_history()
returns trigger
language plpgsql
as $$
declare
  v_counterparty_name text;
  v_group_code text;
begin
  if coalesce(current_setting('app.men_skip_price_history', true), '0') = '1' then
    return new;
  end if;

  select cp.name, cp.group_code
    into v_counterparty_name, v_group_code
  from public.men_counterparties cp
  where cp.id = new.counterparty_id;

  if tg_op = 'INSERT' then
    insert into public.men_price_adjustment_history (
      batch_id,
      price_id,
      counterparty_id,
      counterparty_name_snapshot,
      group_code_snapshot,
      general_material_id,
      commercial_material_id,
      material_alias_id,
      material_label_snapshot,
      previous_price,
      new_price,
      adjustment_mode,
      adjustment_value,
      event_kind,
      event_source,
      reason,
      is_active_snapshot
    )
    values (
      gen_random_uuid(),
      new.id,
      new.counterparty_id,
      coalesce(v_counterparty_name, 'SIN CONTRAPARTE'),
      coalesce(v_group_code, 'SIN GRUPO'),
      new.general_material_id,
      new.commercial_material_id,
      new.material_alias_id,
      new.material_label_snapshot,
      null,
      new.final_price,
      'replace',
      new.final_price,
      'create',
      'catalog_insert',
      'Alta inicial del precio vigente',
      new.is_active
    );
    return new;
  end if;

  if old.final_price is distinct from new.final_price then
    insert into public.men_price_adjustment_history (
      batch_id,
      price_id,
      counterparty_id,
      counterparty_name_snapshot,
      group_code_snapshot,
      general_material_id,
      commercial_material_id,
      material_alias_id,
      material_label_snapshot,
      previous_price,
      new_price,
      adjustment_mode,
      adjustment_value,
      event_kind,
      event_source,
      reason,
      is_active_snapshot
    )
    values (
      gen_random_uuid(),
      new.id,
      new.counterparty_id,
      coalesce(v_counterparty_name, 'SIN CONTRAPARTE'),
      coalesce(v_group_code, 'SIN GRUPO'),
      new.general_material_id,
      new.commercial_material_id,
      new.material_alias_id,
      new.material_label_snapshot,
      old.final_price,
      new.final_price,
      'replace',
      new.final_price,
      'direct_edit',
      'catalog_edit',
      'Edicion puntual del precio vigente',
      new.is_active
    );
  elsif old.is_active is distinct from new.is_active then
    insert into public.men_price_adjustment_history (
      batch_id,
      price_id,
      counterparty_id,
      counterparty_name_snapshot,
      group_code_snapshot,
      general_material_id,
      commercial_material_id,
      material_alias_id,
      material_label_snapshot,
      previous_price,
      new_price,
      adjustment_mode,
      adjustment_value,
      event_kind,
      event_source,
      reason,
      is_active_snapshot
    )
    values (
      gen_random_uuid(),
      new.id,
      new.counterparty_id,
      coalesce(v_counterparty_name, 'SIN CONTRAPARTE'),
      coalesce(v_group_code, 'SIN GRUPO'),
      new.general_material_id,
      new.commercial_material_id,
      new.material_alias_id,
      new.material_label_snapshot,
      old.final_price,
      new.final_price,
      null,
      null,
      'status_change',
      'catalog_edit',
      case when new.is_active then 'Reactivacion del precio vigente' else 'Desactivacion del precio vigente' end,
      new.is_active
    );
  end if;

  return new;
end
$$;

drop trigger if exists trg_men_counterparty_material_prices_history on public.men_counterparty_material_prices;
create trigger trg_men_counterparty_material_prices_history
after insert or update on public.men_counterparty_material_prices
for each row execute function public.log_men_price_history();

insert into public.men_price_adjustment_history (
  batch_id,
  price_id,
  counterparty_id,
  counterparty_name_snapshot,
  group_code_snapshot,
  general_material_id,
  commercial_material_id,
  material_alias_id,
  material_label_snapshot,
  previous_price,
  new_price,
  adjustment_mode,
  adjustment_value,
  event_kind,
  event_source,
  reason,
  is_active_snapshot,
  created_at
)
select
  gen_random_uuid(),
  price.id,
  price.counterparty_id,
  cp.name,
  cp.group_code,
  price.general_material_id,
  price.commercial_material_id,
  price.material_alias_id,
  price.material_label_snapshot,
  null,
  price.final_price,
  'replace',
  price.final_price,
  'create',
  'migration',
  'Backfill inicial del precio vigente',
  price.is_active,
  price.created_at
from public.men_counterparty_material_prices price
join public.men_counterparties cp
  on cp.id = price.counterparty_id
where not exists (
  select 1
  from public.men_price_adjustment_history hist
  where hist.price_id = price.id
);

create or replace function public.apply_men_price_adjustment(
  p_price_ids uuid[],
  p_adjustment_mode text,
  p_adjustment_value numeric,
  p_reason text default null
)
returns table (
  batch_id uuid,
  price_id uuid,
  previous_price numeric(14,4),
  new_price numeric(14,4)
)
language plpgsql
as $$
declare
  v_batch_id uuid := gen_random_uuid();
  v_row public.men_counterparty_material_prices%rowtype;
  v_counterparty_name text;
  v_group_code text;
  v_new_price numeric(14,4);
begin
  if coalesce(array_length(p_price_ids, 1), 0) = 0 then
    raise exception 'Selecciona al menos un precio para ajustar';
  end if;

  if p_adjustment_mode not in ('delta_amount', 'delta_percent', 'replace') then
    raise exception 'Modo de ajuste invalido: %', p_adjustment_mode;
  end if;

  perform set_config('app.men_skip_price_history', '1', true);

  for v_row in
    select *
    from public.men_counterparty_material_prices
    where id = any(p_price_ids)
      and is_active = true
    for update
  loop
    case p_adjustment_mode
      when 'delta_amount' then
        v_new_price := round((v_row.final_price + p_adjustment_value)::numeric, 4);
      when 'delta_percent' then
        v_new_price := round((v_row.final_price * (1 + (p_adjustment_value / 100.0)))::numeric, 4);
      when 'replace' then
        v_new_price := round(p_adjustment_value::numeric, 4);
      else
        raise exception 'Modo de ajuste invalido: %', p_adjustment_mode;
    end case;

    if v_new_price < 0 then
      raise exception 'El ajuste genera un precio negativo para %', v_row.id;
    end if;

    update public.men_counterparty_material_prices
      set final_price = v_new_price
    where id = v_row.id;

    select cp.name, cp.group_code
      into v_counterparty_name, v_group_code
    from public.men_counterparties cp
    where cp.id = v_row.counterparty_id;

    insert into public.men_price_adjustment_history (
      batch_id,
      price_id,
      counterparty_id,
      counterparty_name_snapshot,
      group_code_snapshot,
      general_material_id,
      commercial_material_id,
      material_alias_id,
      material_label_snapshot,
      previous_price,
      new_price,
      adjustment_mode,
      adjustment_value,
      event_kind,
      event_source,
      reason,
      is_active_snapshot
    )
    values (
      v_batch_id,
      v_row.id,
      v_row.counterparty_id,
      coalesce(v_counterparty_name, 'SIN CONTRAPARTE'),
      coalesce(v_group_code, 'SIN GRUPO'),
      v_row.general_material_id,
      v_row.commercial_material_id,
      v_row.material_alias_id,
      v_row.material_label_snapshot,
      v_row.final_price,
      v_new_price,
      p_adjustment_mode,
      p_adjustment_value,
      'adjustment',
      'adjustment_workspace',
      nullif(btrim(coalesce(p_reason, '')), ''),
      v_row.is_active
    );

    batch_id := v_batch_id;
    price_id := v_row.id;
    previous_price := v_row.final_price;
    new_price := v_new_price;
    return next;
  end loop;

  perform set_config('app.men_skip_price_history', '0', true);
  return;
exception
  when others then
    perform set_config('app.men_skip_price_history', '0', true);
    raise;
end
$$;

grant execute on function public.apply_men_price_adjustment(uuid[], text, numeric, text) to authenticated;

create or replace view public.vw_men_price_adjustment_history as
select
  hist.id,
  hist.batch_id,
  hist.price_id,
  hist.counterparty_id,
  hist.counterparty_name_snapshot as counterparty_name,
  hist.group_code_snapshot as group_code,
  hist.general_material_id,
  gen.code as general_material_code,
  gen.name as general_material_name,
  hist.commercial_material_id,
  com.code as commercial_material_code,
  com.name as commercial_material_name,
  hist.material_alias_id,
  alias.label as material_alias_label,
  hist.material_label_snapshot,
  hist.previous_price,
  hist.new_price,
  hist.adjustment_mode,
  hist.adjustment_value,
  hist.event_kind,
  hist.event_source,
  hist.reason,
  hist.is_active_snapshot,
  hist.applied_by,
  hist.created_at
from public.men_price_adjustment_history hist
left join public.material_general_catalog_v2 gen
  on gen.id = hist.general_material_id
left join public.material_commercial_catalog_v2 com
  on com.id = hist.commercial_material_id
left join public.men_material_aliases alias
  on alias.id = hist.material_alias_id;

comment on view public.vw_men_price_adjustment_history is
  'Historial auditable de movimientos de precio en Menudeo. Cada nuevo precio absorbe el vigente anterior.';

create or replace view public.vw_men_price_audit_catalog as
select
  cat.*,
  last_hist.previous_price as last_previous_price,
  last_hist.new_price as last_new_price,
  last_hist.adjustment_mode as last_adjustment_mode,
  last_hist.adjustment_value as last_adjustment_value,
  last_hist.event_kind as last_event_kind,
  last_hist.reason as last_reason,
  last_hist.created_at as last_changed_at
from public.vw_men_counterparty_price_catalog cat
left join lateral (
  select
    hist.previous_price,
    hist.new_price,
    hist.adjustment_mode,
    hist.adjustment_value,
    hist.event_kind,
    hist.reason,
    hist.created_at
  from public.men_price_adjustment_history hist
  where hist.price_id = cat.price_id
  order by hist.created_at desc, hist.id desc
  limit 1
) last_hist on true;

comment on view public.vw_men_price_audit_catalog is
  'Catalogo vigente de precios de Menudeo con metadatos del ultimo movimiento registrado.';

grant select on public.vw_men_price_adjustment_history to authenticated;
grant select on public.vw_men_price_audit_catalog to authenticated;

commit;
