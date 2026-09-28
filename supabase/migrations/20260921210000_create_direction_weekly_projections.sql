begin;

-- Editable forecasts only. No payment, invoice, bank or cash ledger is mutated.
create table public.direction_weekly_projections (
  week_start date primary key check (extract(isodow from week_start)=1),
  revision integer not null check (revision > 0),
  opening_cash bigint check (abs(opening_cash::numeric) <= 100000000000000),
  opening_fiscal bigint check (abs(opening_fiscal::numeric) <= 100000000000000),
  generated boolean not null default false,
  payments jsonb not null default '[]' check (jsonb_typeof(payments)='array'),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);
alter table public.direction_weekly_projections enable row level security;
grant select on public.direction_weekly_projections to authenticated;
create policy direction_projection_read on public.direction_weekly_projections
  for select to authenticated using (public.direction_program_can_manage());

create function public.direction_save_weekly_projection(
  p_week date, p_expected_revision integer, p_payments jsonb,
  p_opening_cash bigint, p_opening_fiscal bigint, p_generated boolean
) returns jsonb language plpgsql security definer set search_path=public as $$
declare old_revision integer; item jsonb; ids text[] := '{}'; saved public.direction_weekly_projections;
begin
  if not public.direction_program_can_manage() then
    raise exception 'Sin permiso' using errcode='42501';
  end if;
  if p_week is null or extract(isodow from p_week) <> 1 or p_expected_revision is null
      or p_expected_revision < 0 or p_generated is null then
    raise exception 'Semana o versión no válida';
  end if;
  if p_payments is null or jsonb_typeof(p_payments) <> 'array'
      or jsonb_array_length(p_payments) > 5000 then
    raise exception 'Propuesta no válida';
  end if;
  for item in select value from jsonb_array_elements(p_payments) loop
    if jsonb_typeof(item) <> 'object' or not (item ?& array['id','source','payee','reference','account','date','amount','available','included','payment_type','notes'])
      or length(btrim(coalesce(item->>'id',''))) = 0 or (item->>'id') = any(ids)
      or item->>'source' not in ('invoice','fixed','agreement','manual')
      or item->>'payment_type' not in ('EFECTIVO','FISCAL','SIN_CLASIFICAR')
      or jsonb_typeof(item->'included') <> 'boolean'
      or jsonb_typeof(item->'amount') <> 'number'
      or jsonb_typeof(item->'available') <> 'number'
      or (item->>'amount')::numeric <> trunc((item->>'amount')::numeric)
      or (item->>'available')::numeric <> trunc((item->>'available')::numeric)
      or (item->>'amount')::numeric not between 0 and 100000000000000
      or (item->>'available')::numeric not between 0 and 100000000000000
      or (item->>'amount')::numeric > (item->>'available')::numeric
      or ((item->>'included')::boolean and (item->>'amount')::numeric <= 0)
      or (item->>'date')::date not between p_week and p_week+6
      or length(btrim(coalesce(item->>'payee',''))) = 0
      or jsonb_typeof(item->'reference') <> 'string'
      or jsonb_typeof(item->'account') <> 'string'
      or jsonb_typeof(item->'notes') <> 'string'
      or exists(select 1 from jsonb_each(item) x where x.value='null'::jsonb) then
      raise exception 'Pago proyectado no válido';
    end if;
    ids := array_append(ids,item->>'id');
  end loop;
  perform pg_advisory_xact_lock(hashtextextended('direction-projection:' || p_week::text,0));
  select revision into old_revision from public.direction_weekly_projections where week_start=p_week for update;
  if coalesce(old_revision,0) <> p_expected_revision then
    raise exception 'La proyección cambió en otra sesión. Cierra la edición y vuelve a abrirla para usar la versión actual.' using errcode='PT409';
  end if;
  insert into public.direction_weekly_projections(week_start,revision,opening_cash,opening_fiscal,generated,payments,updated_by)
    values(p_week,p_expected_revision+1,p_opening_cash,p_opening_fiscal,p_generated,p_payments,auth.uid())
    on conflict(week_start) do update set revision=excluded.revision,opening_cash=excluded.opening_cash,
      opening_fiscal=excluded.opening_fiscal,generated=excluded.generated,payments=excluded.payments,
      updated_at=now(),updated_by=excluded.updated_by returning * into saved;
  return to_jsonb(saved);
end $$;
revoke all on function public.direction_save_weekly_projection(date,integer,jsonb,bigint,bigint,boolean) from public;
grant execute on function public.direction_save_weekly_projection(date,integer,jsonb,bigint,bigint,boolean) to authenticated;

commit;
