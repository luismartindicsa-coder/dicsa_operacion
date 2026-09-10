-- Paid-day history is evidence of a past payment, not a new payroll charge.
alter table public.hr_employee_vacation_events
  add column historical_payment_without_amount boolean not null default false,
  add column import_source jsonb not null default '{}'::jsonb;

alter table public.hr_employee_vacation_events
  add constraint hr_vacation_history_without_amount_check check (
    not historical_payment_without_amount or (
      event_type = 'vacaciones_pagadas' and status = 'aplicado'
      and not impact_attendance and not impact_prenomina and not generate_receipt
      and attendance_sync_status = 'omitido' and prenomina_sync_status = 'omitido'
      and payroll_settlement_status = 'liquidado'
      and receipt_status = 'pendiente'
      and start_date = end_date
      and import_source <> '{}'::jsonb
    )
  );

create unique index hr_vacation_import_source_key_unique
  on public.hr_employee_vacation_events ((import_source->>'source_key'))
  where import_source ? 'source_key';

create function public.hr_guard_vacation_history_calculation()
returns trigger language plpgsql set search_path = public as $$
begin
  if exists (
    select 1 from public.hr_employee_vacation_events
    where id = new.vacation_event_id and historical_payment_without_amount
  ) then
    raise exception 'El pago histórico no tiene importe documentado; no se puede recalcular con salarios actuales.';
  end if;
  return new;
end;
$$;

create trigger hr_vacation_history_no_estimated_calculation
before insert or update on public.hr_employee_vacation_calculations
for each row execute function public.hr_guard_vacation_history_calculation();

create function public.hr_guard_vacation_history_edit()
returns trigger language plpgsql set search_path = public as $$
begin
  if old.historical_payment_without_amount
      and current_user not in ('postgres', 'supabase_admin') then
    raise exception 'El pago histórico se conserva en sólo lectura con su fuente original.';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger hr_vacation_history_read_only
before update or delete on public.hr_employee_vacation_events
for each row execute function public.hr_guard_vacation_history_edit();

comment on column public.hr_employee_vacation_events.historical_payment_without_amount is
  'Pago anterior documentado en días; importe desconocido, no cero. No genera recibo, cálculo ni impacto operativo.';
comment on column public.hr_employee_vacation_events.import_source is
  'Procedencia del pago: archivo y SHA256, hoja/fila, criterio de fecha asignada, identidad y referencia original.';

notify pgrst, 'reload schema';
