begin;

alter table public.gerencia_bale_weekly_plans
  add column source_operating_program_id uuid references public.direction_operating_programs(id),
  add column source_operating_program_version integer,
  add column operating_program_synced_at timestamptz;

comment on column public.gerencia_bale_weekly_plans.source_operating_program_id is
  'Programa operativo aprobado que fija las metas de cartón. Una nueva aprobación reemplaza las metas, no las acumula.';

-- Private helper: runs in the same transaction and weekly lock as approval.
create function public.direction_sync_gerencia_goals(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare p public.direction_operating_programs;
  v_plan public.gerencia_bale_weekly_plans;
begin
  select * into p from public.direction_operating_programs where id = p_id;
  if not found or not p.is_operational or p.status not in ('approved','executing') then
    raise exception 'Solo el programa operativo aprobado puede fijar metas de Gerencia';
  end if;

  insert into public.gerencia_bale_weekly_plans(week_start_date,week_end_date,status,created_by)
    values(p.week_start,p.week_start+5,'planeada',p.approved_by)
    on conflict (week_start_date) do nothing;
  select * into v_plan from public.gerencia_bale_weekly_plans
    where week_start_date=p.week_start for update;
  if v_plan.source_operating_program_id = p_id then return; end if;
  if v_plan.status in ('cerrada','cancelada') then
    raise exception 'La semana de Gerencia está cerrada o cancelada. Reábrela antes de aprobar un nuevo programa.' using errcode='PT409';
  end if;

  update public.gerencia_bale_weekly_plans set
    source_operating_program_id=p.id,
    source_operating_program_version=p.version,
    operating_program_synced_at=now()
    where id=v_plan.id;

  insert into public.gerencia_bale_weekly_plan_lines(
    plan_id,bale_type_key,sort_order,production_target_bales,shipment_target_bales,created_by
  )
  select v_plan.id, t.key, t.sort_order,
    (select coalesce(sum(l.quantity),0)::integer
      from public.direction_operating_program_lines l
      where l.program_id=p.id and l.material_code=m.material),
    (select coalesce(sum((s->>'quantity')::integer),0)::integer
      from jsonb_array_elements(p.shipments) s where s->>'material'=m.material),
    p.approved_by
  from (values ('PACA_NACIONAL','revuelto'),('PACA_LIMPIA','limpio'),('PACA_AMERICANA','americano')) m(material,bale_type)
    join public.gerencia_bale_type_catalog t on t.key=m.bale_type
  on conflict (plan_id,bale_type_key) do update set
    production_target_bales=excluded.production_target_bales,
    shipment_target_bales=excluded.shipment_target_bales;

  -- Update the dashboard/history totals without modifying actual production,
  -- actual shipments, notes, the weekly status or unrelated material goals.
  update public.gerencia_bale_weekly_plans set
    snapshot_production_target_bales=(select sum(production_target_bales) from public.gerencia_bale_weekly_plan_lines where plan_id=v_plan.id),
    snapshot_shipment_target_bales=(select sum(shipment_target_bales) from public.gerencia_bale_weekly_plan_lines where plan_id=v_plan.id)
    where id=v_plan.id;
end;
$$;

create function public.direction_program_sync_gerencia_on_approval()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.is_operational and new.status='approved'
    and (old.status is distinct from new.status or not old.is_operational) then
    perform public.direction_sync_gerencia_goals(new.id);
  end if;
  return new;
end;
$$;

create trigger direction_program_sync_gerencia_on_approval
after update of status,is_operational on public.direction_operating_programs
for each row execute function public.direction_program_sync_gerencia_on_approval();

-- Prevent an old manual-edit dialog from overwriting newly linked goals.
-- Notes remain editable; the three quantities must match the approved source.
create function public.gerencia_guard_operating_program_goals()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_source uuid; v_material text; v_production integer; v_shipments integer;
begin
  if tg_op <> 'INSERT' then
    if old.bale_type_key in ('revuelto','limpio','americano') and
      (tg_op='DELETE' or new.plan_id is distinct from old.plan_id or new.bale_type_key is distinct from old.bale_type_key) and
      exists(select 1 from public.gerencia_bale_weekly_plans where id=old.plan_id and source_operating_program_id is not null) then
      raise exception 'Las metas vinculadas se ajustan aprobando una nueva versión del programa operativo.' using errcode='PT409';
    end if;
  end if;
  if tg_op='DELETE' then return old; end if;
  v_material := case new.bale_type_key when 'revuelto' then 'PACA_NACIONAL'
    when 'limpio' then 'PACA_LIMPIA' when 'americano' then 'PACA_AMERICANA' end;
  if v_material is null then return new; end if;
  select source_operating_program_id into v_source from public.gerencia_bale_weekly_plans
    where id=new.plan_id for share;
  if v_source is null then return new; end if;
  select coalesce(sum(quantity),0) into v_production from public.direction_operating_program_lines
    where program_id=v_source and material_code=v_material;
  select coalesce(sum((s->>'quantity')::integer),0) into v_shipments
    from public.direction_operating_programs p cross join lateral jsonb_array_elements(p.shipments) s
    where p.id=v_source and s->>'material'=v_material;
  if new.production_target_bales <> v_production or new.shipment_target_bales <> v_shipments then
    raise exception 'Las metas vinculadas se ajustan aprobando una nueva versión del programa operativo.' using errcode='PT409';
  end if;
  return new;
end;
$$;

create trigger gerencia_guard_operating_program_goals
before insert or update or delete on public.gerencia_bale_weekly_plan_lines
for each row execute function public.gerencia_guard_operating_program_goals();

revoke all on function public.direction_sync_gerencia_goals(uuid),
  public.direction_program_sync_gerencia_on_approval(),
  public.gerencia_guard_operating_program_goals() from public,anon,authenticated;

-- Link already approved current/future weeks too. Historical and closed weeks
-- retain their original targets. Use the same lock as the approval RPC.
do $$
declare p record;
begin
  for p in select id,week_start from public.direction_operating_programs
    where is_operational and status in ('approved','executing')
      and week_start >= date_trunc('week',now() at time zone 'America/Mexico_City')::date
    order by week_start loop
    perform pg_advisory_xact_lock(hashtextextended('direction-program:' || p.week_start::text,0));
    if not exists(select 1 from public.gerencia_bale_weekly_plans
      where week_start_date=p.week_start and status in ('cerrada','cancelada')) then
      perform public.direction_sync_gerencia_goals(p.id);
    end if;
  end loop;
end;
$$;

-- The existing Gerencia listeners receive target changes immediately.
do $$
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime' and not puballtables)
    and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime'
      and schemaname='public' and tablename='gerencia_bale_weekly_plan_lines') then
    alter publication supabase_realtime add table public.gerencia_bale_weekly_plan_lines;
  end if;
end;
$$;

commit;
