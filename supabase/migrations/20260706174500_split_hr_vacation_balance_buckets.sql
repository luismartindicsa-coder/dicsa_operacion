alter table public.hr_employee_vacation_balances
  add column if not exists days_paid numeric(8,2) not null default 0;

alter table public.hr_employee_vacation_balances
  add column if not exists days_enjoyed numeric(8,2) not null default 0;

alter table public.hr_employee_vacation_balances
  add column if not exists days_reserved numeric(8,2) not null default 0;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'hr_employee_vacation_balances_split_days_check'
  ) then
    alter table public.hr_employee_vacation_balances
      add constraint hr_employee_vacation_balances_split_days_check
      check (
        days_paid >= 0
        and days_enjoyed >= 0
        and days_reserved >= 0
      );
  end if;
end $$;

with event_totals as (
  select
    employee_id,
    exercise_year,
    sum(
      case
        when status = 'aplicado'
          and (
            event_type = 'vacaciones_pagadas'
            or impact_prenomina = true
            or generate_receipt = true
          )
        then days_applied
        else 0
      end
    ) as days_paid,
    sum(
      case
        when status = 'aplicado'
          and (
            event_type = 'vacaciones_disfrutadas'
            or impact_attendance = true
          )
        then days_applied
        else 0
      end
    ) as days_enjoyed,
    sum(
      case
        when status <> 'aplicado'
          and status <> 'cancelado'
          and (
            event_type = 'vacaciones_pendientes'
            or event_type = 'vacaciones_disfrutadas'
            or event_type = 'ajuste_rh'
            or impact_attendance = true
          )
        then days_applied
        else 0
      end
    ) as days_reserved
  from public.hr_employee_vacation_events
  group by employee_id, exercise_year
)
update public.hr_employee_vacation_balances as balance
set
  days_paid = coalesce(event_totals.days_paid, 0),
  days_enjoyed = coalesce(event_totals.days_enjoyed, 0),
  days_reserved = coalesce(event_totals.days_reserved, 0)
from event_totals
where balance.employee_id = event_totals.employee_id
  and balance.exercise_year = event_totals.exercise_year;

update public.hr_employee_vacation_balances
set
  days_enjoyed = days_taken
where days_paid = 0
  and days_enjoyed = 0
  and days_reserved = 0
  and days_taken > 0;

update public.hr_employee_vacation_balances
set
  days_taken = greatest(days_enjoyed + days_reserved, 0),
  days_available = greatest(days_entitled - (days_enjoyed + days_reserved), 0);

comment on column public.hr_employee_vacation_balances.days_paid is
  'Dias ya pagados fiscalmente o por recibo, sin asumir que ya fueron disfrutados.';

comment on column public.hr_employee_vacation_balances.days_enjoyed is
  'Dias ya disfrutados por el colaborador e impactados operativamente en asistencia.';

comment on column public.hr_employee_vacation_balances.days_reserved is
  'Dias reservados o comprometidos para disfrutar despues, todavia no aplicados en asistencia.';
