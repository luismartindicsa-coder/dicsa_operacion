-- El retardo se descuenta de la bolsa fiscal y las horas extra se pagan por
-- efectivo. Se conserva el importe calculado/confirmado para que Nómina y
-- el recibo imprimible reproduzcan exactamente el cierre de Prenómina.
alter table public.hr_prenomina_draft_rows
  add column if not exists fiscal_late_deduction_amount numeric(14,2);

comment on column public.hr_prenomina_draft_rows.fiscal_late_deduction_amount is
  'Descuento fiscal por retardos: salario base semanal / 7 / 8 x minutos de retardo / 60. RH puede confirmar o ajustar el importe.';
