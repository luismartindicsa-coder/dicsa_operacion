-- User correction: imported paid days use the same editor and automatic
-- calculation as + Pago. The workbook remains the source of days and dates.
begin;

lock table public.hr_employee_vacation_events in access exclusive mode;

drop trigger hr_vacation_history_no_estimated_calculation
  on public.hr_employee_vacation_calculations;
drop function public.hr_guard_vacation_history_calculation();
drop trigger hr_vacation_history_read_only
  on public.hr_employee_vacation_events;
drop function public.hr_guard_vacation_history_edit();
alter table public.hr_employee_vacation_events
  drop constraint hr_vacation_history_without_amount_check;

-- The previous importer marked these as settled although they have never
-- entered a payroll closure. Convert only those workbook imports, under a
-- table lock; the regular settled-event protection is restored immediately.
alter table public.hr_employee_vacation_events
  disable trigger guard_hr_vacation_settled_events;

update public.hr_employee_vacation_events e
set historical_payment_without_amount = false,
    generate_receipt = true,
    isr_method = 'tarifa_semanal',
    payroll_settlement_status = 'pendiente',
    import_source = e.import_source || jsonb_build_object(
      'amount_basis', 'app_calculation',
      'calculation_authorized_by_user', true,
      'previous_import_mode', 'historical_without_amount'
    ),
    notes = 'Pago importado de VACACION_DICSA_estructurado.xlsx · Pagos fila '
      || (e.import_source->>'row') || ' · '
      || (e.import_source->>'record_id')
      || '. Días pagados y fecha asignada según Excel. Importes calculados por la app con los datos del expediente.'
where e.historical_payment_without_amount
  and e.import_source->>'source_key' like 'VACACION_DICSA:2026:%'
  and e.event_type = 'vacaciones_pagadas'
  and e.status = 'aplicado'
  and not e.impact_attendance and not e.impact_prenomina
  and e.attendance_sync_status = 'omitido'
  and e.prenomina_sync_status = 'omitido'
  and e.payroll_settled_at is null
  and e.receipt_status = 'pendiente'
  and not exists (
    select 1 from public.hr_employee_event_period_impacts i
    where i.vacation_event_id = e.id
  );

alter table public.hr_employee_vacation_events
  enable trigger guard_hr_vacation_settled_events;

-- Keep the salary inputs used by the regular payment editor. When a historical
-- hire date differs from Personal, retain its manual criterion and reason.
update public.hr_employee_vacation_balances b
set salary_snapshot = p.salario,
    salary_perceived_snapshot = p.salario_real_percibido,
    manual_override = case when b.base_date_policy = 'manual_rh'
      then true else b.manual_override end,
    manual_override_reason = case
      when b.base_date_policy = 'manual_rh' and b.manual_override_reason = ''
      then 'Fecha de ingreso histórica del Excel; se conserva Personal.'
      else b.manual_override_reason end
from public.hr_employee_profiles p
where p.id = b.employee_id
  and exists (
    select 1 from public.hr_employee_vacation_events e
    where e.balance_id = b.id
      and e.import_source->>'source_key' like 'VACACION_DICSA:2026:%'
      and e.import_source->>'previous_import_mode' = 'historical_without_amount'
      and e.import_source->>'amount_basis' = 'app_calculation'
  );

comment on column public.hr_employee_vacation_events.historical_payment_without_amount is
  'Marca legada del primer importador. Los pagos del Excel usan ahora el cálculo normal de la app; procedencia en import_source.';

notify pgrst, 'reload schema';
commit;
