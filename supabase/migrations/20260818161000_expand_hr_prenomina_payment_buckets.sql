alter table public.hr_prenomina_draft_rows
  add column if not exists fiscal_net_amount numeric(12,2),
  add column if not exists fiscal_imss_amount numeric(12,2),
  add column if not exists fiscal_infonavit_amount numeric(12,2),
  add column if not exists fiscal_fonacot_amount numeric(12,2),
  add column if not exists fiscal_absence_amount numeric(12,2),
  add column if not exists fiscal_vacation_amount numeric(12,2),
  add column if not exists cash_salary_amount numeric(12,2),
  add column if not exists cash_vacation_amount numeric(12,2),
  add column if not exists cash_isr_amount numeric(12,2),
  add column if not exists transport_support_amount numeric(12,2),
  add column if not exists holiday_amount numeric(12,2),
  add column if not exists overtime_monetized_amount numeric(12,2),
  add column if not exists manual_bonus_amount numeric(12,2),
  add column if not exists cash_absence_deduction_amount numeric(12,2),
  add column if not exists cash_infonavit_deduction_amount numeric(12,2),
  add column if not exists cash_fonacot_deduction_amount numeric(12,2),
  add column if not exists loan_deduction_amount numeric(12,2),
  add column if not exists check_amount numeric(12,2),
  add column if not exists payment_outside_amount numeric(12,2),
  add column if not exists payment_channel text not null default '',
  add column if not exists payment_reference text not null default '';

comment on column public.hr_prenomina_draft_rows.fiscal_net_amount is
  'Neto fiscal de CONTPAQ o valor manual confirmado por RH para el periodo.';
comment on column public.hr_prenomina_draft_rows.fiscal_imss_amount is
  'Huella fiscal de IMSS tomada de CONTPAQ o ajustada manualmente.';
comment on column public.hr_prenomina_draft_rows.fiscal_infonavit_amount is
  'Huella fiscal de INFONAVIT tomada de CONTPAQ o ajustada manualmente.';
comment on column public.hr_prenomina_draft_rows.fiscal_fonacot_amount is
  'Huella fiscal de FONACOT tomada de CONTPAQ o ajustada manualmente.';
comment on column public.hr_prenomina_draft_rows.fiscal_absence_amount is
  'Descuento fiscal por faltas o ausencia en la corrida de CONTPAQ.';
comment on column public.hr_prenomina_draft_rows.fiscal_vacation_amount is
  'Monto fiscal de vacaciones visible en CONTPAQ para el periodo.';
comment on column public.hr_prenomina_draft_rows.cash_salary_amount is
  'Bolsa operativa RH de sueldo en efectivo para el cierre semanal.';
comment on column public.hr_prenomina_draft_rows.cash_vacation_amount is
  'Vacaciones pagadas en efectivo fuera del depósito fiscal.';
comment on column public.hr_prenomina_draft_rows.cash_isr_amount is
  'ISR que RH descuenta dentro de la bolsa operativa semanal.';
comment on column public.hr_prenomina_draft_rows.transport_support_amount is
  'Apoyo de transporte aplicado por RH en el cierre semanal.';
comment on column public.hr_prenomina_draft_rows.holiday_amount is
  'Pago de día festivo aplicado en la bolsa operativa semanal.';
comment on column public.hr_prenomina_draft_rows.overtime_monetized_amount is
  'Horas extra ya monetizadas dentro de la bolsa operativa semanal.';
comment on column public.hr_prenomina_draft_rows.manual_bonus_amount is
  'Bono o ajuste positivo manual distinto de horas extra monetizadas.';
comment on column public.hr_prenomina_draft_rows.cash_absence_deduction_amount is
  'Descuento operativo por faltas aplicado por RH.';
comment on column public.hr_prenomina_draft_rows.cash_infonavit_deduction_amount is
  'Descuento operativo de INFONAVIT fuera del neto fiscal.';
comment on column public.hr_prenomina_draft_rows.cash_fonacot_deduction_amount is
  'Descuento operativo de FONACOT fuera del neto fiscal.';
comment on column public.hr_prenomina_draft_rows.loan_deduction_amount is
  'Descuento operativo por préstamo interno o externo.';
comment on column public.hr_prenomina_draft_rows.check_amount is
  'Monto pagado por cheque dentro del cierre semanal.';
comment on column public.hr_prenomina_draft_rows.payment_outside_amount is
  'Monto pagado por fuera o en sobre dentro del cierre semanal.';
comment on column public.hr_prenomina_draft_rows.payment_channel is
  'Canal dominante de pago para el cierre semanal: depósito, cheque, mixto, etc.';
comment on column public.hr_prenomina_draft_rows.payment_reference is
  'Referencia libre RH para describir cuenta, cheque o nota de pago.';
