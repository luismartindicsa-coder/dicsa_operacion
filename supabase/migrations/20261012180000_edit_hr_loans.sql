begin;

-- Corrections are separate from receipts: closed payroll and imported evidence
-- remain intact. All writers continue to serialize on the fund's singleton row.
alter table public.hr_employee_loans
  add column paid_adjustment_amount numeric(14,2) not null default 0,
  add column revision bigint not null default 0;
alter table public.hr_loan_payments
  add column principal_only_amount numeric(14,2) not null default 0
    check (principal_only_amount between 0 and amount),
  add constraint hr_loan_extra_cash_only check (method = 'efectivo' or principal_only_amount = 0);

create table public.hr_loan_changes (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique,
  loan_id uuid not null references public.hr_employee_loans(id) on delete restrict,
  request_payload jsonb not null,
  before_values jsonb not null,
  after_values jsonb not null,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id)
);
create index hr_loan_changes_loan_idx on public.hr_loan_changes(loan_id, created_at desc);
alter table public.hr_loan_changes enable row level security;
revoke all on public.hr_loan_changes from public, anon, authenticated;
grant select on public.hr_loan_changes to authenticated;
create policy hr_loan_changes_read on public.hr_loan_changes for select to authenticated
  using (public.hr_can_access_loans());

create function public.hr_loan_bump_revision() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_table_name = 'hr_employee_loans' then
    new.revision := old.revision + 1;
  else
    update public.hr_employee_loans set revision = revision + 1 where id = new.loan_id;
  end if;
  return new;
end;
$$;
create trigger hr_loan_revision before update on public.hr_employee_loans
  for each row execute function public.hr_loan_bump_revision();
create trigger hr_loan_payment_revision after insert on public.hr_loan_payments
  for each row execute function public.hr_loan_bump_revision();
revoke all on function public.hr_loan_bump_revision() from public, anon, authenticated;

create or replace function public.hr_loan_available() returns numeric
language sql stable security definer set search_path = '' as $$
  select f.capital - coalesce((select sum(principal - opening_paid_amount - paid_adjustment_amount)
    from public.hr_employee_loans), 0)
    + coalesce((select sum(amount) from public.hr_loan_payments), 0)
  from public.hr_loan_fund f where id;
$$;

create or replace function public.hr_loan_due(p_loan_id uuid, p_through date) returns numeric
language sql stable security definer set search_path = '' as $$
  with l as (select * from public.hr_employee_loans where id = p_loan_id),
  scheduled as (
    select case frequency
      when 'semanal' then first_due_on + ((i - opening_paid_installments) * 7)
      when 'quincenal' then first_due_on + ((i - opening_paid_installments) * 14)
      else (first_due_on + pg_catalog.make_interval(months => i - opening_paid_installments))::date
    end as due_on,
    case when i = installment_count - 1
      then principal - coalesce(installment_amount, trunc(principal / installment_count, 2)) * (installment_count - 1)
      else coalesce(installment_amount, trunc(principal / installment_count, 2)) end as installment
    from l cross join lateral pg_catalog.generate_series(opening_paid_installments, installment_count - 1) i
  ), paid as (
    select coalesce(sum(amount),0) as total, coalesce(sum(amount - principal_only_amount),0) as credited
    from public.hr_loan_payments where loan_id = p_loan_id
  )
  select case when l.issued_on > p_through or l.first_due_on > p_through then 0 else greatest(0, least(
    l.principal - l.opening_paid_amount - l.paid_adjustment_amount - paid.total,
    coalesce((select sum(installment) from scheduled where due_on <= p_through),0)
      - paid.credited - least(l.paid_adjustment_amount,0))) end
  from l cross join paid;
$$;

create function public.hr_loan_edit(
  p_request_id uuid, p_loan_id uuid, p_expected_revision bigint,
  p_expected_paid numeric, p_principal numeric, p_paid_amount numeric,
  p_requested_on date, p_first_due_on date, p_notes text default ''
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  l public.hr_employee_loans; saved public.hr_loan_changes; v_after public.hr_employee_loans;
  v_payload jsonb; v_payments numeric; v_payroll numeric; v_paid numeric;
  v_quota numeric; v_count integer; v_issued date; v_adjustment numeric;
begin
  perform public.hr_loan_assert_access();
  perform 1 from public.hr_loan_fund where id for update;
  v_payload := jsonb_build_object('loan_id',p_loan_id,'revision',p_expected_revision,
    'expected_paid',p_expected_paid,'principal',p_principal,'paid_amount',p_paid_amount,
    'requested_on',p_requested_on,'first_due_on',p_first_due_on,'notes',coalesce(p_notes,''));
  select * into saved from public.hr_loan_changes where request_id = p_request_id;
  if found then
    if saved.request_payload is distinct from v_payload then
      raise exception 'La solicitud ya se guardó con otros datos. Cierra y vuelve a abrir el préstamo.';
    end if;
    return saved.loan_id;
  end if;
  select * into l from public.hr_employee_loans where id = p_loan_id;
  if not found then raise exception 'El préstamo ya no está disponible.'; end if;
  select coalesce(sum(amount),0), coalesce(sum(amount) filter(where method = 'nomina'),0)
    into v_payments,v_payroll from public.hr_loan_payments where loan_id = l.id;
  v_paid := l.opening_paid_amount + l.paid_adjustment_amount + v_payments;
  if l.revision is distinct from p_expected_revision or v_paid is distinct from p_expected_paid then
    raise exception 'El préstamo o sus abonos cambiaron. Cierra y vuelve a abrir el préstamo para actualizarlo.';
  end if;
  if p_principal is null or p_principal <= 0 or p_principal <> round(p_principal,2)
    or p_paid_amount is null or p_paid_amount < 0 or p_paid_amount <> round(p_paid_amount,2)
    or p_paid_amount > p_principal then
    raise exception 'Revisa el monto y lo aportado: usa dos decimales y un aportado entre cero y el monto.';
  end if;
  if p_paid_amount < v_payroll then
    raise exception 'Lo aportado no puede ser menor a los descuentos confirmados en nóminas cerradas (%).', v_payroll;
  end if;
  if p_principal < l.opening_paid_amount then
    raise exception 'El monto no puede ser menor a los abonos históricos documentados (%).', l.opening_paid_amount;
  end if;
  if p_requested_on is null or p_requested_on > timezone('America/Mexico_City',now())::date
    or p_first_due_on is null or p_first_due_on < p_requested_on then
    raise exception 'Revisa las fechas: la entrega no puede ser futura ni posterior al primer vencimiento.';
  end if;
  v_issued := case when l.opening_snapshot <> '{}'::jsonb then l.issued_on else p_requested_on end;
  if p_first_due_on < v_issued or (l.opening_snapshot <> '{}'::jsonb and p_requested_on > l.issued_on)
    or exists(select 1 from public.hr_loan_payments where loan_id=l.id and paid_on < v_issued) then
    raise exception 'Las fechas deben respetar el saldo inicial y los abonos ya registrados.';
  end if;
  -- Keep the regular installment when correcting the amount; shorten/extend
  -- only the final term. Preserve legacy equal schedules on non-amount edits.
  v_quota := l.installment_amount; v_count := l.installment_count;
  if p_principal <> l.principal then
    v_quota := least(p_principal, coalesce(l.installment_amount,trunc(l.principal/l.installment_count,2)));
    v_count := ceil(p_principal/v_quota)::integer;
    if v_count > 260 then raise exception 'El monto supera 260 cuotas habituales.'; end if;
  end if;
  v_adjustment := p_paid_amount - l.opening_paid_amount - v_payments;
  if p_principal - p_paid_amount > l.principal - v_paid
    and (p_principal - p_paid_amount) - (l.principal - v_paid) > public.hr_loan_available() then
    raise exception 'La corrección supera el saldo disponible del fondo.';
  end if;
  update public.hr_employee_loans set principal=p_principal, paid_adjustment_amount=v_adjustment,
    issued_on=v_issued, first_due_on=p_first_due_on, notes=coalesce(p_notes,''),
    installment_amount=v_quota, installment_count=v_count,
    opening_snapshot=case when l.opening_snapshot <> '{}'::jsonb
      then l.opening_snapshot || jsonb_build_object('requested_on',p_requested_on) else l.opening_snapshot end
    where id=l.id returning * into v_after;
  insert into public.hr_loan_changes(request_id,loan_id,request_payload,before_values,after_values,created_by)
    values(p_request_id,l.id,v_payload,to_jsonb(l)||jsonb_build_object('paid_amount',v_paid),
      to_jsonb(v_after)||jsonb_build_object('paid_amount',p_paid_amount),auth.uid());
  return l.id;
end;
$$;
revoke all on function public.hr_loan_edit(uuid,uuid,bigint,numeric,numeric,numeric,date,date,text) from public, anon, authenticated;
grant execute on function public.hr_loan_edit(uuid,uuid,bigint,numeric,numeric,numeric,date,date,text) to authenticated;

create or replace function public.hr_loan_record_cash_payment(
  p_request_id uuid, p_loan_id uuid, p_amount numeric, p_paid_on date, p_notes text default ''
) returns uuid language plpgsql security definer set search_path = '' as $$
declare l public.hr_employee_loans; payment public.hr_loan_payments; balance numeric;
  v_id uuid; v_horizon date; v_credit numeric;
begin
  perform public.hr_loan_assert_access();
  perform 1 from public.hr_loan_fund where id for update;
  select * into payment from public.hr_loan_payments where request_id = p_request_id;
  if found then
    if payment.loan_id is distinct from p_loan_id or payment.amount is distinct from p_amount
      or payment.paid_on is distinct from p_paid_on or payment.method <> 'efectivo'
      or payment.notes is distinct from coalesce(p_notes,'') then
      raise exception 'El abono ya existe con otros datos.';
    end if;
    return payment.id;
  end if;
  select * into l from public.hr_employee_loans where id = p_loan_id;
  if not found then raise exception 'El préstamo ya no está disponible.'; end if;
  select l.principal - l.opening_paid_amount - l.paid_adjustment_amount - coalesce(sum(amount),0)
    into balance from public.hr_loan_payments where loan_id=l.id;
  if p_amount is null or p_amount <= 0 or p_amount <> round(p_amount,2) or p_amount > balance then
    raise exception 'El abono debe ser positivo y no superar el saldo pendiente.';
  end if;
  if p_paid_on is null or p_paid_on < l.issued_on or p_paid_on > timezone('America/Mexico_City',now())::date then
    raise exception 'La fecha del abono debe estar entre la entrega o saldo inicial y hoy.';
  end if;
  -- Cover accrued installments (or the first one if paid before it starts).
  -- Repeated payments in the same period do not prepay subsequent periods.
  v_horizon := greatest(l.first_due_on,p_paid_on);
  v_credit := least(p_amount,public.hr_loan_due(l.id,v_horizon));
  insert into public.hr_loan_payments(request_id,loan_id,amount,method,paid_on,notes,created_by,principal_only_amount)
    values(p_request_id,l.id,p_amount,'efectivo',p_paid_on,coalesce(p_notes,''),auth.uid(),p_amount-v_credit)
    returning id into v_id;
  return v_id;
end;
$$;

-- Existing channel edits must see the corrected balance too.
create or replace function public.hr_loan_set_payroll_channel(
  p_request_id uuid, p_loan_id uuid, p_expected_channel text, p_channel text, p_notes text default ''
) returns uuid language plpgsql security definer set search_path = '' as $$
declare l public.hr_employee_loans; previous public.hr_loan_channel_changes; v_balance numeric;
begin
  perform public.hr_loan_assert_access();
  perform 1 from public.hr_loan_fund where id for update;
  select * into previous from public.hr_loan_channel_changes where request_id=p_request_id;
  if found then
    if previous.loan_id is distinct from p_loan_id or previous.payroll_channel is distinct from p_channel
      or previous.previous_channel is distinct from p_expected_channel then
      raise exception 'La solicitud ya existe con otros datos.';
    end if;
    return previous.loan_id;
  end if;
  if p_channel is null or p_channel not in ('flujo','fiscal') then raise exception 'Selecciona Flujo o Fiscal.'; end if;
  select * into l from public.hr_employee_loans where id=p_loan_id;
  if not found or l.repayment_method <> 'nomina' then raise exception 'Selecciona un préstamo con cobro por nómina.'; end if;
  if l.payroll_channel is distinct from p_expected_channel then raise exception 'La forma de cobro cambió. Actualiza el préstamo.'; end if;
  select l.principal-l.opening_paid_amount-l.paid_adjustment_amount-coalesce(sum(amount),0)
    into v_balance from public.hr_loan_payments where loan_id=l.id;
  if v_balance <= 0 then raise exception 'El préstamo ya está liquidado.'; end if;
  if l.payroll_channel=p_channel then return l.id; end if;
  insert into public.hr_loan_channel_changes(request_id,loan_id,previous_channel,payroll_channel,notes,created_by)
    values(p_request_id,l.id,l.payroll_channel,p_channel,coalesce(p_notes,''),auth.uid());
  update public.hr_employee_loans set payroll_channel=p_channel where id=l.id;
  return l.id;
end;
$$;
notify pgrst,'reload schema';
commit;
