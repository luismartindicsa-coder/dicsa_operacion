begin;
-- RH chooses where each payroll loan is collected. Fiscal is informational in
-- Prenomina because CONTPAQ already includes the deduction in its official net.
alter table public.hr_employee_loans add column payroll_channel text not null default 'flujo'
  check (payroll_channel in ('flujo', 'fiscal'));
alter table public.hr_employee_loans add constraint hr_loan_cash_channel_check
  check (repayment_method = 'nomina' or payroll_channel = 'flujo');
alter table public.hr_loan_payments add column payroll_channel text;
update public.hr_loan_payments set payroll_channel = 'flujo' where method = 'nomina';
alter table public.hr_loan_payments add constraint hr_loan_payment_channel_check
  check ((method = 'nomina' and payroll_channel is not null and payroll_channel in ('flujo', 'fiscal'))
    or (method = 'efectivo' and payroll_channel is null));

create table public.hr_loan_channel_changes (
  id uuid primary key default gen_random_uuid(), request_id uuid not null unique,
  loan_id uuid not null references public.hr_employee_loans(id) on delete restrict,
  previous_channel text not null check (previous_channel in ('flujo','fiscal')),
  payroll_channel text not null check (payroll_channel in ('flujo','fiscal')),
  notes text not null default '', created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id)
);
alter table public.hr_loan_channel_changes enable row level security;
revoke all on public.hr_loan_channel_changes from anon, authenticated;
grant select on public.hr_loan_channel_changes to authenticated;
create policy hr_loan_channel_changes_read on public.hr_loan_channel_changes for select to authenticated
  using (public.hr_can_access_loans());
create index hr_loan_channel_changes_loan_idx on public.hr_loan_channel_changes(loan_id);

drop function public.hr_loan_create(uuid,text,numeric,integer,text,text,date,date,text);
create function public.hr_loan_create(
  p_request_id uuid, p_employee_id text, p_principal numeric,
  p_installment_count integer, p_repayment_method text, p_frequency text,
  p_issued_on date, p_first_due_on date, p_notes text default '', p_payroll_channel text default 'flujo'
) returns uuid language plpgsql security definer set search_path = '' as $$
declare l public.hr_employee_loans; person public.hr_employee_profiles; v_id uuid;
begin
  perform public.hr_loan_assert_access();
  perform 1 from public.hr_loan_fund where id for update;
  select * into l from public.hr_employee_loans where request_id = p_request_id;
  if found then
    if l.employee_id <> p_employee_id or l.principal <> p_principal
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
    principal, installment_count, repayment_method, frequency, issued_on, first_due_on, notes, created_by, payroll_channel)
  values(p_request_id, person.id, person.nombre, coalesce(person.empresa, ''),
    p_principal, p_installment_count, p_repayment_method, p_frequency, p_issued_on, p_first_due_on,
    coalesce(p_notes, ''), auth.uid(), p_payroll_channel) returning id into v_id;
  return v_id;
end;
$$;

create function public.hr_loan_set_payroll_channel(
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
  select l.principal - coalesce(sum(amount),0) into v_balance from public.hr_loan_payments where loan_id = l.id;
  if v_balance <= 0 then raise exception 'El préstamo ya está liquidado.'; end if;
  if l.payroll_channel = p_channel then return l.id; end if;
  insert into public.hr_loan_channel_changes(request_id,loan_id,previous_channel,payroll_channel,notes,created_by)
    values(p_request_id,l.id,l.payroll_channel,p_channel,coalesce(p_notes,''),auth.uid());
  update public.hr_employee_loans set payroll_channel = p_channel where id = l.id;
  return l.id;
end;
$$;

create or replace function public.hr_loan_guard_draft() returns trigger
language plpgsql security definer set search_path = '' as $$
declare s jsonb; a jsonb; v_amount numeric; v_fiscal numeric; v_flow_sum numeric := 0; v_fiscal_sum numeric := 0;
begin
  perform 1 from public.hr_loan_fund where id for update;
  if tg_op = 'DELETE' then return old; end if;
  s := new.source_snapshot -> 'loan_fund';
  if tg_op = 'UPDATE' and exists(select 1 from public.hr_payroll_period_closures
      where period_label = old.period_label and status = 'cerrado')
      and (old.source_snapshot -> 'loan_fund') is distinct from s then
    raise exception 'Los abonos de un periodo cerrado son inmutables.';
  end if;
  if s is null then return new; end if;
  perform public.hr_loan_assert_access();
  v_amount := (s ->> 'amount')::numeric;
  v_fiscal := coalesce((s ->> 'fiscal_amount')::numeric,0);
  if jsonb_typeof(s -> 'allocations') is distinct from 'array'
    or coalesce((s ->> 'version')::integer,0) not in (1,2)
    or v_amount is null or v_amount < 0 or v_amount <> round(v_amount,2)
    or v_fiscal < 0 or v_fiscal <> round(v_fiscal,2)
    or coalesce(new.loan_deduction_amount,0) < v_amount then
    raise exception 'El desglose del préstamo no coincide con el descuento de flujo.';
  end if;
  for a in select * from jsonb_array_elements(s -> 'allocations') loop
    if (a ->> 'amount')::numeric is null or (a ->> 'amount')::numeric <= 0
      or (a ->> 'amount')::numeric <> round((a ->> 'amount')::numeric,2)
      or coalesce(a ->> 'channel','flujo') not in ('flujo','fiscal') then
      raise exception 'Revisa los importes y canales del préstamo.';
    end if;
    if coalesce(a ->> 'channel','flujo') = 'fiscal' then
      v_fiscal_sum := v_fiscal_sum + (a ->> 'amount')::numeric;
    else v_flow_sum := v_flow_sum + (a ->> 'amount')::numeric;
    end if;
  end loop;
  if v_flow_sum <> v_amount or v_fiscal_sum <> v_fiscal then raise exception 'El desglose de abonos no coincide con sus canales.'; end if;
  if v_fiscal > 0 and new.source_snapshot ->> 'contpaq_official_net' is null then
    raise exception 'Importa CONTPAQ del periodo para registrar el cobro fiscal informativo.';
  end if;
  return new;
end;
$$;

create or replace function public.hr_loan_settle_payroll() returns trigger
language plpgsql security definer set search_path = '' as $$
declare d public.hr_prenomina_draft_rows; s jsonb; a jsonb; l public.hr_employee_loans;
  v_end date; parts text[]; v_due numeric; v_expected numeric; v_amount numeric;
  v_available_flow numeric; v_manual numeric; v_total numeric; v_fiscal numeric; v_expected_fiscal numeric; v_channel text; v_count integer;
begin
  if new.status <> 'cerrado' then return new; end if;
  if tg_op = 'UPDATE' and old.status = 'cerrado' then return new; end if;
  perform 1 from public.hr_loan_fund where id for update;
  if not exists(select 1 from public.hr_employee_loans) then return new; end if;
  perform public.hr_loan_assert_access();
  select end_date into v_end from public.hr_attendance_operational_periods where period_label = new.period_label limit 1;
  if v_end is null then
    parts := regexp_match(new.period_label, '(\d{2}/\d{2}/\d{4})\s*-\s*(\d{2}/\d{2}/\d{4})');
    if parts is not null then v_end := to_date(parts[2], 'DD/MM/YYYY'); end if;
  end if;
  if v_end is null then raise exception 'El periodo requiere fechas para validar los préstamos.'; end if;
  for l in select * from public.hr_employee_loans where repayment_method = 'nomina'
      and issued_on <= v_end and public.hr_loan_due(id, v_end) > 0
      and exists(select 1 from public.hr_employee_profiles p where p.id = employee_id
        and (p.employment_status is distinct from 'baja' or p.termination_date > v_end)) loop
    if not exists(select 1 from public.hr_prenomina_draft_rows
      where period_label = new.period_label and employee_id = l.employee_id and draft_status = 'publicado') then
      raise exception 'Falta publicar la prenómina de % para revisar su préstamo.', l.employee_name;
    end if;
  end loop;
  for d in select * from public.hr_prenomina_draft_rows where period_label = new.period_label
      order by employee_id for update loop
    select coalesce(sum(public.hr_loan_due(id, v_end)), 0),
      coalesce(sum(public.hr_loan_due(id, v_end)) filter (where payroll_channel = 'fiscal'), 0) into v_expected, v_expected_fiscal
      from public.hr_employee_loans where employee_id = d.employee_id and repayment_method = 'nomina';
    s := d.source_snapshot -> 'loan_fund';
    if v_expected = 0 and coalesce((s ->> 'amount')::numeric, 0) + coalesce((s ->> 'fiscal_amount')::numeric,0) = 0 then continue; end if;
    if s is null or coalesce((s ->> 'version')::integer,0) not in (1,2)
      or (s ->> 'end_date')::date is distinct from v_end
      or (s ->> 'requested_amount')::numeric is distinct from v_expected then
      raise exception 'Los préstamos de % cambiaron. Actualiza y guarda su prenómina antes de cerrar.', d.employee_name;
    end if;
    v_total := coalesce((s ->> 'amount')::numeric, 0);
    v_fiscal := coalesce((s ->> 'fiscal_amount')::numeric,0);
    if v_expected_fiscal > 0 and d.source_snapshot ->> 'contpaq_official_net' is null then
      raise exception 'Importa CONTPAQ de % antes de confirmar el abono fiscal.', d.employee_name;
    end if;
    if v_fiscal <> v_expected_fiscal then raise exception 'Actualiza el cobro fiscal de % desde Préstamos y Prenómina.', d.employee_name; end if;
    -- Validate each current obligation, even when flow capacity was zero.
    v_amount := 0;
    if jsonb_typeof(s -> 'dues') is distinct from 'array' then raise exception 'Falta el desglose de cuotas.'; end if;
    select count(*),count(distinct x ->> 'loan_id') into v_count,v_amount from jsonb_array_elements(s -> 'dues') x;
    if v_count <> v_amount then raise exception 'Hay cuotas repetidas.'; end if;
    v_amount := 0;
    for a in select * from jsonb_array_elements(s -> 'dues') loop
      select * into l from public.hr_employee_loans where id = (a ->> 'loan_id')::uuid;
      if l.id is null or l.employee_id <> d.employee_id or l.repayment_method <> 'nomina'
        or coalesce(a ->> 'channel','flujo') <> l.payroll_channel
        or (a ->> 'amount')::numeric is distinct from public.hr_loan_due(l.id,v_end) then
        raise exception 'La cuota o forma de cobro de % cambió. Actualiza su prenómina.', d.employee_name;
      end if;
      v_amount := v_amount + (a ->> 'amount')::numeric;
    end loop;
    if v_amount <> v_expected then raise exception 'Faltan cuotas en el desglose de %.', d.employee_name; end if;
    v_manual := coalesce(d.loan_deduction_amount, 0) - v_total;
    v_available_flow := greatest(0,
      coalesce(d.cash_salary_amount, 0) + coalesce(d.cash_vacation_amount, 0)
      + coalesce(d.transport_support_amount, 0) + coalesce(d.holiday_amount, 0)
      + coalesce(d.overtime_monetized_amount, 0) + coalesce(d.manual_bonus_amount, 0)
      + coalesce(d.manual_adjustment_amount, 0)
      - coalesce(d.cash_isr_amount, 0) - coalesce(d.cash_infonavit_deduction_amount, 0)
      - coalesce(d.cash_fonacot_deduction_amount, 0) - v_manual
      - case when d.source_snapshot ->> 'incidences_informational' = 'true' then 0
        else coalesce(d.cash_absence_deduction_amount, 0) end);
    if v_total < 0 or v_total + v_fiscal > v_expected or v_total > round(v_available_flow, 2) or v_manual < 0 then
      raise exception 'El abono de % supera la deuda o el flujo disponible.', d.employee_name;
    end if;
    select count(*), count(distinct a2 ->> 'loan_id') into v_count, v_amount
      from jsonb_array_elements(s -> 'allocations') a2;
    if v_count <> v_amount then raise exception 'Hay préstamos repetidos en el desglose.'; end if;
    v_amount := 0;
    for a in select * from jsonb_array_elements(s -> 'allocations') loop
      select * into l from public.hr_employee_loans where id = (a ->> 'loan_id')::uuid;
      v_due := public.hr_loan_due(l.id, v_end);
      v_channel := coalesce(a ->> 'channel','flujo');
      if l.id is null or l.employee_id <> d.employee_id or l.repayment_method <> 'nomina'
        or v_channel <> l.payroll_channel
        or (a ->> 'amount')::numeric is null or (a ->> 'amount')::numeric <= 0
        or (a ->> 'amount')::numeric <> round((a ->> 'amount')::numeric, 2)
        or (a ->> 'amount')::numeric > v_due then
        raise exception 'El abono de % ya no coincide con el saldo de su préstamo.', d.employee_name;
      end if;
      insert into public.hr_loan_payments(request_id, loan_id, amount, method, paid_on, period_label, closure_id, notes, created_by, payroll_channel)
      values(gen_random_uuid(), l.id, (a ->> 'amount')::numeric, 'nomina', v_end, new.period_label, new.id,
        case when v_channel = 'fiscal' then 'Cobro fiscal incluido en CONTPAQ; informativo en la app.'
          else 'Descuento de flujo confirmado al cerrar nómina.' end, auth.uid(), v_channel);
      v_amount := v_amount + (a ->> 'amount')::numeric;
    end loop;
    if v_amount <> v_total + v_fiscal then raise exception 'El total del préstamo no coincide con sus abonos.'; end if;
  end loop;
  return new;
end;
$$;
revoke all on function public.hr_loan_create(uuid,text,numeric,integer,text,text,date,date,text,text),
  public.hr_loan_set_payroll_channel(uuid,uuid,text,text,text) from public, anon, authenticated;
grant execute on function public.hr_loan_create(uuid,text,numeric,integer,text,text,date,date,text,text),
  public.hr_loan_set_payroll_channel(uuid,uuid,text,text,text) to authenticated;
comment on column public.hr_employee_loans.payroll_channel is 'RH elige flujo (reduce pago app) o fiscal (ya incluido en CONTPAQ; informativo). No hay cambio automático por insuficiencia.';
comment on column public.hr_loan_payments.payroll_channel is 'Canal efectivo de cada abono confirmado; cambiar el préstamo no altera su historial.';
notify pgrst, 'reload schema';
commit;
