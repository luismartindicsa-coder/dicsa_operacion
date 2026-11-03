begin;

alter table public.dashboard_yard_manual_counts add column counted_on date
  generated always as ((updated_at at time zone 'America/Mexico_City')::date) stored;

create table public.dashboard_yard_week_openings (
  site text not null,
  week_start date not null check (extract(isodow from week_start) = 1),
  widget_key text not null,
  count_id uuid not null,
  source_kind text not null,
  material text,
  commercial_material_code text,
  count_units integer not null check (count_units >= 0),
  counted_at timestamptz not null,
  updated_by uuid,
  primary key (site, week_start, widget_key)
);

alter table public.dashboard_yard_week_openings enable row level security;
grant select on public.dashboard_yard_week_openings to authenticated;
create policy dashboard_yard_week_openings_read
  on public.dashboard_yard_week_openings for select to authenticated using (true);

-- Always classify the server save instant in the site's timezone, including
-- Friday evening instants whose UTC calendar date is already Saturday.
create function public.dashboard_yard_opening_monday(p_saved_at timestamptz)
returns date language sql immutable strict set search_path = public as $$
  select case
    when extract(isodow from p_saved_at at time zone 'America/Mexico_City') = 5
      and (p_saved_at at time zone 'America/Mexico_City')::time >= time '17:00'
    then (p_saved_at at time zone 'America/Mexico_City')::date + 3
  end;
$$;

create function public.capture_dashboard_yard_week_opening()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_week date;
begin
  if tg_op = 'DELETE' then
    -- Clearing the count invalidates its matching closing snapshot. A later
    -- weekday count can be cleared without deleting an older weekly opening.
    delete from public.dashboard_yard_week_openings
      where count_id = old.id and counted_at = old.updated_at;
    return old;
  end if;
  if new.site <> 'DICSA_CELAYA' then return new; end if;
  v_week := public.dashboard_yard_opening_monday(new.updated_at);
  if v_week is null then return new; end if;
  insert into public.dashboard_yard_week_openings
    (site, week_start, widget_key, count_id, source_kind, material,
     commercial_material_code, count_units, counted_at, updated_by)
  values (new.site, v_week, new.widget_key, new.id, new.source_kind, new.material,
    new.commercial_material_code, new.count_units, new.updated_at, new.updated_by)
  on conflict (site, week_start, widget_key) do update set
    count_id = excluded.count_id, source_kind = excluded.source_kind,
    material = excluded.material, commercial_material_code = excluded.commercial_material_code,
    count_units = excluded.count_units, counted_at = excluded.counted_at,
    updated_by = excluded.updated_by
  where excluded.counted_at >= dashboard_yard_week_openings.counted_at;
  return new;
end;
$$;

create trigger trg_capture_dashboard_yard_week_opening
after insert or update or delete on public.dashboard_yard_manual_counts
for each row execute function public.capture_dashboard_yard_week_opening();

-- Preserve a qualifying latest count already captured before this release.
insert into public.dashboard_yard_week_openings
  (site, week_start, widget_key, count_id, source_kind, material,
   commercial_material_code, count_units, counted_at, updated_by)
select site, public.dashboard_yard_opening_monday(updated_at), widget_key, id,
  source_kind, material, commercial_material_code, count_units, updated_at, updated_by
from public.dashboard_yard_manual_counts
where site = 'DICSA_CELAYA' and public.dashboard_yard_opening_monday(updated_at) is not null;

revoke all on function public.capture_dashboard_yard_week_opening() from public, anon, authenticated;
revoke all on function public.dashboard_yard_opening_monday(timestamptz) from public, anon;
grant execute on function public.dashboard_yard_opening_monday(timestamptz) to authenticated;

comment on table public.dashboard_yard_week_openings is
  'Cierre por material capturado en Operación el viernes desde las 17:00, hora de Celaya, para el piso inicial del lunes siguiente. Se conserva al recapturar el conteo físico durante la semana.';

commit;
