begin;

-- Opening balances preserve RH's paid amount/count without inventing historical
-- receipts, payment dates, or payment channels. first_due_on anchors the FIRST
-- PENDING installment; issued_on is the operational cutover for imported loans.
alter table public.hr_employee_loans
  add column installment_amount numeric(14,2),
  add column opening_paid_amount numeric(14,2) not null default 0,
  add column opening_paid_installments integer not null default 0,
  add column opening_snapshot jsonb not null default '{}'::jsonb,
  add constraint hr_loan_fixed_installment_check check (
    installment_amount is null or (installment_amount > 0 and installment_amount <= principal
      and installment_count = ceil(principal / installment_amount))),
  add constraint hr_loan_opening_balance_check check (
    opening_paid_installments between 0 and installment_count
    and opening_paid_amount between 0 and principal
    and opening_paid_amount = case when opening_paid_installments = installment_count then principal
      else opening_paid_installments * coalesce(installment_amount, trunc(principal / installment_count, 2)) end
    and jsonb_typeof(opening_snapshot) = 'object'
    and (opening_paid_amount = 0 or opening_snapshot <> '{}'::jsonb));

comment on column public.hr_employee_loans.opening_snapshot is
  'Provenance for migrated balances: requested_on, as_of, source and first pending period. Prior payment dates/channels are not inferred.';
comment on column public.hr_employee_loans.opening_paid_amount is
  'Already recovered before cutover. Included in fund availability and balance, never inserted again as a payment.';
comment on column public.hr_employee_loans.installment_amount is
  'Regular payment; the last installment is the exact remainder. NULL preserves legacy equal-installment schedules.';

create or replace function public.hr_loan_available() returns numeric
language sql stable security definer set search_path = '' as $$
  select f.capital - coalesce((select sum(principal - opening_paid_amount) from public.hr_employee_loans), 0)
    + coalesce((select sum(amount) from public.hr_loan_payments), 0)
  from public.hr_loan_fund f where id;
$$;

create or replace function public.hr_loan_due(p_loan_id uuid, p_through date) returns numeric
language sql stable security definer set search_path = '' as $$
  with l as (select * from public.hr_employee_loans where id = p_loan_id),
  scheduled as (
    select l.*,
      case frequency
        when 'semanal' then first_due_on + ((i - opening_paid_installments) * 7)
        when 'quincenal' then first_due_on + ((i - opening_paid_installments) * 14)
        else (first_due_on + pg_catalog.make_interval(months => i - opening_paid_installments))::date
      end as due_on,
      case when i = installment_count - 1
        then principal - coalesce(installment_amount, trunc(principal / installment_count, 2)) * (installment_count - 1)
        else coalesce(installment_amount, trunc(principal / installment_count, 2)) end as installment
    from l cross join lateral pg_catalog.generate_series(opening_paid_installments, installment_count - 1) i
  )
  select greatest(0, coalesce(sum(installment) filter (where due_on <= p_through and issued_on <= p_through), 0)
    - coalesce((select sum(amount) from public.hr_loan_payments where loan_id = p_loan_id), 0))
  from scheduled;
$$;

drop function public.hr_loan_create(uuid,text,numeric,integer,text,text,date,date,text,text);
create function public.hr_loan_create(
  p_request_id uuid, p_employee_id text, p_principal numeric,
  p_installment_count integer, p_repayment_method text, p_frequency text,
  p_issued_on date, p_first_due_on date, p_notes text default '', p_payroll_channel text default 'flujo',
  p_installment_amount numeric default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare l public.hr_employee_loans; person public.hr_employee_profiles; v_id uuid;
begin
  perform public.hr_loan_assert_access();
  perform 1 from public.hr_loan_fund where id for update;
  select * into l from public.hr_employee_loans where request_id = p_request_id;
  if found then
    if l.employee_id <> p_employee_id or l.principal <> p_principal
      or l.installment_amount is distinct from p_installment_amount
      or l.installment_count <> p_installment_count or l.repayment_method <> p_repayment_method
      or l.payroll_channel is distinct from p_payroll_channel
      or l.frequency <> p_frequency or l.issued_on <> p_issued_on or l.first_due_on <> p_first_due_on then
      raise exception 'La solicitud ya existe con otros datos.';
    end if;
    return l.id;
  end if;
  if p_principal is null or p_principal <= 0 or p_principal <> round(p_principal, 2) then
    raise exception 'Captura un importe positivo con máximo dos decimales.';
  end if;
  if p_installment_amount is not null and (p_installment_amount <= 0
    or p_installment_amount <> round(p_installment_amount, 2)
    or p_installment_count is distinct from ceil(p_principal / p_installment_amount)::integer) then
    raise exception 'La cuota debe ser positiva y cubrir el préstamo en el número de pagos indicado.';
  end if;
  if p_principal > public.hr_loan_available() then
    raise exception 'El préstamo supera el saldo disponible del fondo.';
  end if;
  if p_issued_on > timezone('America/Mexico_City', now())::date then
    raise exception 'Registra la entrega cuando se haya realizado.';
  end if;
  select * into person from public.hr_employee_profiles where id = p_employee_id;
  if not found or person.employment_status = 'baja' then
    raise exception 'Selecciona un colaborador activo de Personal.';
  end if;
  insert into public.hr_employee_loans(request_id, employee_id, employee_name, empresa,
    principal, installment_count, repayment_method, frequency, issued_on, first_due_on, notes, created_by, payroll_channel, installment_amount)
  values(p_request_id, person.id, person.nombre, coalesce(person.empresa, ''),
    p_principal, p_installment_count, p_repayment_method, p_frequency, p_issued_on, p_first_due_on,
    coalesce(p_notes, ''), auth.uid(), p_payroll_channel, p_installment_amount) returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.hr_loan_record_cash_payment(
  p_request_id uuid, p_loan_id uuid, p_amount numeric, p_paid_on date, p_notes text default ''
) returns uuid language plpgsql security definer set search_path = '' as $$
declare l public.hr_employee_loans; payment public.hr_loan_payments; balance numeric; v_id uuid;
begin
  perform public.hr_loan_assert_access();
  perform 1 from public.hr_loan_fund where id for update;
  select * into payment from public.hr_loan_payments where request_id = p_request_id;
  if found then
    if payment.loan_id <> p_loan_id or payment.amount <> p_amount
      or payment.paid_on <> p_paid_on or payment.method <> 'efectivo' then
      raise exception 'El abono ya existe con otros datos.';
    end if;
    return payment.id;
  end if;
  select * into l from public.hr_employee_loans where id = p_loan_id;
  if not found then raise exception 'El préstamo ya no está disponible.'; end if;
  select l.principal - l.opening_paid_amount - coalesce(sum(amount), 0) into balance
    from public.hr_loan_payments where loan_id = l.id;
  if p_amount is null or p_amount <= 0 or p_amount <> round(p_amount, 2) or p_amount > balance then
    raise exception 'El abono debe ser positivo y no superar el saldo pendiente.';
  end if;
  if p_paid_on < l.issued_on or p_paid_on > timezone('America/Mexico_City', now())::date then
    raise exception 'La fecha del abono debe estar entre la entrega o saldo inicial y hoy.';
  end if;
  insert into public.hr_loan_payments(request_id, loan_id, amount, method, paid_on, notes, created_by)
    values(p_request_id, p_loan_id, p_amount, 'efectivo', p_paid_on, coalesce(p_notes, ''), auth.uid())
    returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.hr_loan_set_payroll_channel(
  p_request_id uuid, p_loan_id uuid, p_expected_channel text, p_channel text, p_notes text default ''
) returns uuid language plpgsql security definer set search_path = '' as $$
declare l public.hr_employee_loans; previous public.hr_loan_channel_changes; v_balance numeric;
begin
  perform public.hr_loan_assert_access();
  perform 1 from public.hr_loan_fund where id for update;
  select * into previous from public.hr_loan_channel_changes where request_id = p_request_id;
  if found then
    if previous.loan_id is distinct from p_loan_id or previous.payroll_channel is distinct from p_channel
      or previous.previous_channel is distinct from p_expected_channel then
      raise exception 'La solicitud ya existe con otros datos.';
    end if;
    return previous.loan_id;
  end if;
  if p_channel is null or p_channel not in ('flujo','fiscal') then raise exception 'Selecciona Flujo o Fiscal.'; end if;
  select * into l from public.hr_employee_loans where id = p_loan_id;
  if not found or l.repayment_method <> 'nomina' then raise exception 'Selecciona un préstamo con cobro por nómina.'; end if;
  if l.payroll_channel is distinct from p_expected_channel then raise exception 'La forma de cobro cambió. Actualiza el préstamo.'; end if;
  select l.principal - l.opening_paid_amount - coalesce(sum(amount),0) into v_balance from public.hr_loan_payments where loan_id = l.id;
  if v_balance <= 0 then raise exception 'El préstamo ya está liquidado.'; end if;
  if l.payroll_channel = p_channel then return l.id; end if;
  insert into public.hr_loan_channel_changes(request_id,loan_id,previous_channel,payroll_channel,notes,created_by)
    values(p_request_id,l.id,l.payroll_channel,p_channel,coalesce(p_notes,''),auth.uid());
  update public.hr_employee_loans set payroll_channel = p_channel where id = l.id;
  return l.id;
end;
$$;

revoke all on function public.hr_loan_create(uuid,text,numeric,integer,text,text,date,date,text,text,numeric) from public, anon, authenticated;
grant execute on function public.hr_loan_create(uuid,text,numeric,integer,text,text,date,date,text,text,numeric) to authenticated;
notify pgrst, 'reload schema';
commit;
