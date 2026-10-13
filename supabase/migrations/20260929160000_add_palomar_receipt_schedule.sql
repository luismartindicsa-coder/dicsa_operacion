begin;

-- Expected receipt dates only. No real Palomar, bank, collection or payment
-- movement is created. Global credit/cheque configuration remains unchanged.
create table public.direction_income_palomar_schedule (
  week_start date primary key check (extract(isodow from week_start)=1),
  cash_date date check (cash_date between week_start and week_start+6),
  fiscal_date date check (fiscal_date between week_start and week_start+6),
  revision integer not null check (revision > 0),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);
alter table public.direction_income_palomar_schedule enable row level security;
revoke all on public.direction_income_palomar_schedule from anon, authenticated;
grant select on public.direction_income_palomar_schedule to authenticated;
create policy direction_palomar_schedule_read on public.direction_income_palomar_schedule
  for select to authenticated using (public.direction_program_can_manage());

create function public.direction_income_save_palomar_schedule(
  p_week date, p_cash_date date, p_fiscal_date date, p_expected_revision integer
) returns jsonb language plpgsql security definer set search_path=public as $$
declare old_revision integer; saved public.direction_income_palomar_schedule;
begin
  if not coalesce(public.direction_program_can_manage(),false) then
    raise exception 'Sin permiso' using errcode='42501';
  end if;
  if p_week is null or extract(isodow from p_week) <> 1
      or p_expected_revision is null or p_expected_revision < 0
      or p_cash_date not between p_week and p_week+6
      or p_fiscal_date not between p_week and p_week+6 then
    raise exception 'Las fechas deben pertenecer a la semana seleccionada.';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('direction-palomar-schedule:' || p_week::text,0));
  select revision into old_revision from public.direction_income_palomar_schedule
    where week_start=p_week for update;
  if coalesce(old_revision,0) <> p_expected_revision then
    raise exception 'Las fechas cambiaron en otra sesión. Cierra la edición y vuelve a abrirla para usar la versión actual.' using errcode='PT409';
  end if;
  insert into public.direction_income_palomar_schedule(week_start,cash_date,fiscal_date,revision,updated_by)
    values(p_week,p_cash_date,p_fiscal_date,p_expected_revision+1,auth.uid())
    on conflict(week_start) do update set cash_date=excluded.cash_date,fiscal_date=excluded.fiscal_date,
      revision=excluded.revision,updated_at=now(),updated_by=excluded.updated_by returning * into saved;
  return to_jsonb(saved);
end $$;
revoke all on function public.direction_income_save_palomar_schedule(date,date,date,integer) from public, anon;
grant execute on function public.direction_income_save_palomar_schedule(date,date,date,integer) to authenticated;
notify pgrst, 'reload schema';
commit;
