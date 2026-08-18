with sem33_vacations as (
  select *
  from (
    values
      (
        '121',
        'MIGUEL ANGEL NOYOLA ELIZALDE',
        'Periodo 33 semanal · 07/08/2026 - 13/08/2026',
        '2026-08-07'::date,
        '2026-08-13'::date,
        'MIG_SEM33_VAC|2026-08-07|2026-08-13|121',
        'No. CTA. 1515180877',
        2205.28::numeric(12,2),
        2205.28::numeric(12,2),
        7.00::numeric(8,2),
        'sem33.xlsx · Periodo 33 semanal · 07/08/2026 - 13/08/2026 · Sembrado desde nómina final semanal · Cheque=VACACIONES · Importe base 2205.28'
      ),
      (
        '132',
        'JOSE JESUS CIENEGA HERNANDEZ',
        'Periodo 33 semanal · 07/08/2026 - 13/08/2026',
        '2026-08-07'::date,
        '2026-08-13'::date,
        'MIG_SEM33_VAC|2026-08-07|2026-08-13|132',
        'No. CTA. 2742464225',
        4600.00::numeric(12,2),
        4600.00::numeric(12,2),
        7.00::numeric(8,2),
        'sem33.xlsx · Periodo 33 semanal · 07/08/2026 - 13/08/2026 · Sembrado desde nómina final semanal · Cheque=VACACIONES · Importe base 4600.00 · Extras detectadas 755.40 · Infonavit fiscal 2046.74'
      ),
      (
        '135',
        'JAVIER MARTINEZ BARRERA',
        'Periodo 33 semanal · 07/08/2026 - 13/08/2026',
        '2026-08-07'::date,
        '2026-08-13'::date,
        'MIG_SEM33_VAC|2026-08-07|2026-08-13|135',
        'No. CTA. 2709849068',
        4900.00::numeric(12,2),
        2100.00::numeric(12,2),
        3.00::numeric(8,2),
        'sem33.xlsx · Periodo 33 semanal · 07/08/2026 - 13/08/2026 · Sembrado desde nómina final semanal · Cheque=VACACIONES · Importe base 2100.00'
      ),
      (
        '223',
        'CRUZ ANGEL RAMIREZ CAMPOS',
        'Periodo 33 semanal · 07/08/2026 - 13/08/2026',
        '2026-08-07'::date,
        '2026-08-13'::date,
        'MIG_SEM33_VAC|2026-08-07|2026-08-13|223',
        'No. CTA. 1527321812',
        2205.28::numeric(12,2),
        2205.28::numeric(12,2),
        7.00::numeric(8,2),
        'sem33.xlsx · Periodo 33 semanal · 07/08/2026 - 13/08/2026 · Sembrado desde nómina final semanal · Cheque=VACACIONES · Importe base 2205.28 · Fonacot fiscal 357.80 · Desc. Infonavit operativo 357.80 · Desc. préstamo operativo 100.00'
      )
  ) as seeded(
    employee_id,
    employee_name_snapshot,
    period_label,
    period_start,
    period_end,
    receipt_group_key,
    account_reference,
    weekly_salary,
    vacation_amount,
    vacation_days,
    notes
  )
),
profiles as (
  select
    seeded.*,
    profile.id as employee_id_fk,
    coalesce(nullif(trim(profile.nombre), ''), seeded.employee_name_snapshot) as employee_name,
    coalesce(nullif(trim(profile.empresa), ''), '') as empresa,
    profile.fecha_ingreso,
    profile.fecha_alta,
    coalesce(profile.salario, 0)::numeric(12,2) as salary_snapshot,
    coalesce(profile.salario_real_percibido, 0)::numeric(12,2) as salary_perceived_snapshot
  from sem33_vacations as seeded
  join public.hr_employee_profiles as profile
    on profile.id = seeded.employee_id
),
balance_seed as (
  select
    profile.employee_id,
    profile.employee_name,
    profile.empresa,
    2026 as exercise_year,
    coalesce(existing.base_date_policy, 'fecha_ingreso') as base_date_policy,
    coalesce(existing.base_fecha_ingreso, profile.fecha_ingreso) as base_fecha_ingreso,
    coalesce(existing.base_fecha_alta, profile.fecha_alta) as base_fecha_alta,
    case
      when coalesce(existing.base_date_policy, 'fecha_ingreso') = 'fecha_alta'
        then coalesce(existing.base_fecha_alta, profile.fecha_alta)
      else coalesce(existing.base_fecha_ingreso, profile.fecha_ingreso)
    end as anchor_date,
    coalesce(existing.salary_snapshot, nullif(profile.salary_snapshot, 0), profile.weekly_salary) as salary_snapshot,
    coalesce(existing.salary_perceived_snapshot, nullif(profile.salary_perceived_snapshot, 0), profile.weekly_salary) as salary_perceived_snapshot,
    existing.status as existing_status,
    existing.days_entitled as existing_days_entitled,
    existing.entitlement_rule_key as existing_entitlement_rule_key
  from profiles as profile
  left join public.hr_employee_vacation_balances as existing
    on existing.employee_id = profile.employee_id
   and existing.exercise_year = 2026
),
balances_ready as (
  select
    balance_seed.employee_id,
    balance_seed.employee_name,
    balance_seed.empresa,
    balance_seed.exercise_year,
    balance_seed.base_date_policy,
    balance_seed.base_fecha_ingreso,
    balance_seed.base_fecha_alta,
    greatest(
      0,
      extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer
    ) as antiguedad_years,
    case
      when balance_seed.existing_entitlement_rule_key is not null and balance_seed.existing_entitlement_rule_key <> ''
        then balance_seed.existing_entitlement_rule_key
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 1 and 1 then '1'
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 2 and 2 then '2'
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 3 and 3 then '3'
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 4 and 4 then '4'
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 5 and 5 then '5'
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 6 and 10 then '6_10'
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 11 and 15 then '11_15'
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 16 and 20 then '16_20'
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 21 and 25 then '21_25'
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 26 and 30 then '26_30'
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 31 and 35 then '31_35'
      else ''
    end as entitlement_rule_key,
    case
      when balance_seed.existing_days_entitled is not null and balance_seed.existing_days_entitled > 0
        then balance_seed.existing_days_entitled
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 1 and 1 then 12
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 2 and 2 then 14
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 3 and 3 then 16
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 4 and 4 then 18
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 5 and 5 then 20
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 6 and 10 then 22
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 11 and 15 then 24
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 16 and 20 then 26
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 21 and 25 then 28
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 26 and 30 then 30
      when extract(year from age('2026-08-13'::date, balance_seed.anchor_date))::integer between 31 and 35 then 32
      else 0
    end as days_entitled,
    balance_seed.salary_snapshot,
    balance_seed.salary_perceived_snapshot,
    coalesce(balance_seed.existing_status, 'calculado') as status
  from balance_seed
),
upsert_balances as (
  insert into public.hr_employee_vacation_balances (
    employee_id,
    employee_name,
    empresa,
    exercise_year,
    base_date_policy,
    base_fecha_ingreso,
    base_fecha_alta,
    antiguedad_years,
    entitlement_rule_key,
    days_entitled,
    days_taken,
    days_available,
    salary_snapshot,
    salary_perceived_snapshot,
    status,
    manual_override,
    manual_override_reason,
    notes
  )
  select
    employee_id,
    employee_name,
    empresa,
    exercise_year,
    base_date_policy,
    base_fecha_ingreso,
    base_fecha_alta,
    antiguedad_years,
    nullif(entitlement_rule_key, ''),
    days_entitled,
    0,
    days_entitled,
    salary_snapshot,
    salary_perceived_snapshot,
    status,
    false,
    '',
    'Semilla base para migración semanal sem33'
  from balances_ready
  on conflict (employee_id, exercise_year) do update
  set
    employee_name = excluded.employee_name,
    empresa = excluded.empresa,
    base_fecha_ingreso = coalesce(public.hr_employee_vacation_balances.base_fecha_ingreso, excluded.base_fecha_ingreso),
    base_fecha_alta = coalesce(public.hr_employee_vacation_balances.base_fecha_alta, excluded.base_fecha_alta),
    antiguedad_years = greatest(public.hr_employee_vacation_balances.antiguedad_years, excluded.antiguedad_years),
    entitlement_rule_key = coalesce(public.hr_employee_vacation_balances.entitlement_rule_key, excluded.entitlement_rule_key),
    days_entitled = greatest(public.hr_employee_vacation_balances.days_entitled, excluded.days_entitled),
    salary_snapshot = coalesce(public.hr_employee_vacation_balances.salary_snapshot, excluded.salary_snapshot),
    salary_perceived_snapshot = coalesce(public.hr_employee_vacation_balances.salary_perceived_snapshot, excluded.salary_perceived_snapshot),
    notes = case
      when public.hr_employee_vacation_balances.notes ilike '%sem33%'
        then public.hr_employee_vacation_balances.notes
      when public.hr_employee_vacation_balances.notes = ''
        then excluded.notes
      else public.hr_employee_vacation_balances.notes || ' · ' || excluded.notes
    end
  returning id, employee_id, base_date_policy
),
updated_events as (
  update public.hr_employee_vacation_events as event
  set
    balance_id = balance.id,
    employee_name = profile.employee_name,
    exercise_year = 2026,
    event_type = 'vacaciones_pagadas',
    start_date = profile.period_end,
    end_date = profile.period_end,
    days_applied = profile.vacation_days,
    attendance_period_label = '',
    attendance_sync_status = 'omitido',
    prenomina_sync_status = 'aplicado',
    impact_attendance = false,
    impact_prenomina = true,
    generate_receipt = true,
    status = 'aplicado',
    notes = profile.notes
  from profiles as profile
  join upsert_balances as balance
    on balance.employee_id = profile.employee_id
  where event.receipt_group_key = profile.receipt_group_key
  returning event.id, event.employee_id, event.receipt_group_key
),
inserted_events as (
  insert into public.hr_employee_vacation_events (
    balance_id,
    employee_id,
    employee_name,
    exercise_year,
    event_type,
    start_date,
    end_date,
    days_applied,
    attendance_period_label,
    attendance_sync_status,
    prenomina_sync_status,
    impact_attendance,
    impact_prenomina,
    generate_receipt,
    receipt_group_key,
    status,
    notes
  )
  select
    balance.id,
    profile.employee_id,
    profile.employee_name,
    2026,
    'vacaciones_pagadas',
    profile.period_end,
    profile.period_end,
    profile.vacation_days,
    '',
    'omitido',
    'aplicado',
    false,
    true,
    true,
    profile.receipt_group_key,
    'aplicado',
    profile.notes
  from profiles as profile
  join upsert_balances as balance
    on balance.employee_id = profile.employee_id
  where not exists (
    select 1
    from public.hr_employee_vacation_events as event
    where event.receipt_group_key = profile.receipt_group_key
  )
  returning id, employee_id, receipt_group_key
),
all_events as (
  select id, employee_id, receipt_group_key
  from updated_events
  union all
  select id, employee_id, receipt_group_key
  from inserted_events
),
updated_calculations as (
  update public.hr_employee_vacation_calculations as calc
  set
    employee_id = profile.employee_id,
    exercise_year = 2026,
    component_label = 'Migración sem33 vacaciones',
    calculation_mode = 'manual_rh',
    base_date_policy = balance.base_date_policy,
    days_paid = profile.vacation_days,
    daily_salary_used = round(profile.weekly_salary / 7.0, 2),
    daily_salary_perceived_used = 0,
    vacation_pay = profile.vacation_amount,
    vacation_bonus_rate = 0,
    vacation_bonus_pay = 0,
    transfer_component = 0,
    cash_component = profile.vacation_amount,
    difference_component = 0,
    status = 'vigente',
    is_final = true,
    notes = profile.notes
  from profiles as profile
  join upsert_balances as balance
    on balance.employee_id = profile.employee_id
  join all_events as event
    on event.receipt_group_key = profile.receipt_group_key
  where calc.vacation_event_id = event.id
    and calc.sequence_no = 1
  returning calc.id
),
inserted_calculations as (
  insert into public.hr_employee_vacation_calculations (
    vacation_event_id,
    employee_id,
    exercise_year,
    sequence_no,
    component_label,
    calculation_mode,
    base_date_policy,
    days_paid,
    daily_salary_used,
    daily_salary_perceived_used,
    vacation_pay,
    vacation_bonus_rate,
    vacation_bonus_pay,
    transfer_component,
    cash_component,
    difference_component,
    status,
    is_final,
    notes
  )
  select
    event.id,
    profile.employee_id,
    2026,
    1,
    'Migración sem33 vacaciones',
    'manual_rh',
    balance.base_date_policy,
    profile.vacation_days,
    round(profile.weekly_salary / 7.0, 2),
    0,
    profile.vacation_amount,
    0,
    0,
    0,
    profile.vacation_amount,
    0,
    'vigente',
    true,
    profile.notes
  from profiles as profile
  join upsert_balances as balance
    on balance.employee_id = profile.employee_id
  join all_events as event
    on event.receipt_group_key = profile.receipt_group_key
  where not exists (
    select 1
    from public.hr_employee_vacation_calculations as calc
    where calc.vacation_event_id = event.id
      and calc.sequence_no = 1
  )
),
event_totals as (
  select
    event.employee_id,
    event.exercise_year,
    sum(
      case
        when event.status = 'aplicado'
          and (
            event.event_type = 'vacaciones_pagadas'
            or event.impact_prenomina = true
            or event.generate_receipt = true
          )
        then event.days_applied
        else 0
      end
    ) as days_paid,
    sum(
      case
        when event.status = 'aplicado'
          and (
            event.event_type = 'vacaciones_disfrutadas'
            or event.impact_attendance = true
          )
        then event.days_applied
        else 0
      end
    ) as days_enjoyed,
    sum(
      case
        when event.status <> 'aplicado'
          and event.status <> 'cancelado'
          and (
            event.event_type = 'vacaciones_pendientes'
            or event.event_type = 'vacaciones_disfrutadas'
            or event.event_type = 'ajuste_rh'
            or event.impact_attendance = true
          )
        then event.days_applied
        else 0
      end
    ) as days_reserved
  from public.hr_employee_vacation_events as event
  where event.employee_id in (select employee_id from profiles)
    and event.exercise_year = 2026
  group by event.employee_id, event.exercise_year
)
update public.hr_employee_vacation_balances as balance
set
  days_paid = coalesce(event_totals.days_paid, 0),
  days_enjoyed = coalesce(event_totals.days_enjoyed, 0),
  days_reserved = coalesce(event_totals.days_reserved, 0),
  days_taken = greatest(coalesce(event_totals.days_enjoyed, 0) + coalesce(event_totals.days_reserved, 0), 0),
  days_available = greatest(balance.days_entitled - (coalesce(event_totals.days_enjoyed, 0) + coalesce(event_totals.days_reserved, 0)), 0),
  status = case
    when coalesce(event_totals.days_paid, 0) > 0 then 'aplicado'
    else balance.status
  end
from event_totals
where balance.employee_id = event_totals.employee_id
  and balance.exercise_year = event_totals.exercise_year;
