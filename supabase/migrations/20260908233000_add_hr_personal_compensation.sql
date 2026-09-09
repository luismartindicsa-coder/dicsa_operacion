begin;

alter table public.hr_employee_profiles
  add column if not exists salario_flujo numeric(12,2),
  add column if not exists fiscal_payment_mode text not null default 'deposito',
  add column if not exists overtime_hourly_rate numeric(12,2) not null default 60;

-- One-time migration of the existing contractual complement, never CONTPAQ net.
-- Do not infer cheque or a different rate from account strings or imports.
update public.hr_employee_profiles
set salario_flujo = case when coalesce(salario, 0) > 0
  then greatest(coalesce(salario_real_percibido, 0) - salario, 0)
  else 0 end
where salario_flujo is null;

update public.hr_employee_profiles
set salario_real_percibido = coalesce(salario, 0) + salario_flujo
where salario_real_percibido is distinct from coalesce(salario, 0) + salario_flujo;

alter table public.hr_employee_profiles
  alter column salario_flujo set default 0,
  alter column salario_flujo set not null,
  add constraint hr_employee_profiles_flow_nonnegative check (salario_flujo >= 0),
  add constraint hr_employee_profiles_fiscal_payment_mode_check
    check (fiscal_payment_mode in ('deposito', 'cheque')),
  add constraint hr_employee_profiles_overtime_rate_check
    check (overtime_hourly_rate in (60, 80));

create or replace function public.hr_employee_compensation_total()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.salario_real_percibido := coalesce(new.salario, 0) + new.salario_flujo;
  return new;
end;
$$;

create trigger hr_employee_compensation_total
before insert or update of salario, salario_flujo, salario_real_percibido
on public.hr_employee_profiles
for each row execute function public.hr_employee_compensation_total();

comment on column public.hr_employee_profiles.salario_flujo is
  'Flujo semanal acordado en Personal. Cero es explícito. No se compensa contra el neto de CONTPAQ.';
comment on column public.hr_employee_profiles.salario_real_percibido is
  'Total semanal calculado como salario base + salario flujo; base del pago de vacaciones y prima.';
comment on column public.hr_employee_profiles.fiscal_payment_mode is
  'deposito: cuenta fiscal; cheque: fiscal timbrado entregado en efectivo, incluido una sola vez en el total.';
comment on column public.hr_prenomina_draft_rows.cash_salary_is_manual is
  'RH fijó el flujo del periodo, incluido cero. Si es falso, se toma salario_flujo de Personal.';

notify pgrst, 'reload schema';
commit;
