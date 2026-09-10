begin;

create table public.hr_loan_fund (
  id boolean primary key default true check (id),
  capital numeric(14,2) not null check (capital >= 0),
  created_at timestamptz not null default now()
);
insert into public.hr_loan_fund(id, capital) values (true, 15000.00);

create table public.hr_employee_loans (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique,
  folio bigint generated always as identity unique,
  employee_id text not null references public.hr_employee_profiles(id) on delete restrict,
  employee_name text not null,
  empresa text not null default '',
  principal numeric(14,2) not null check (principal > 0),
  installment_count integer not null check (installment_count between 1 and 260),
  repayment_method text not null check (repayment_method in ('nomina', 'efectivo')),
  frequency text not null check (frequency in ('semanal', 'quincenal', 'mensual')),
  issued_on date not null,
  first_due_on date not null check (first_due_on >= issued_on),
  check (principal * 100 >= installment_count),
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id)
);

create table public.hr_loan_payments (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique,
  loan_id uuid not null references public.hr_employee_loans(id) on delete restrict,
  amount numeric(14,2) not null check (amount > 0),
  method text not null check (method in ('nomina', 'efectivo')),
  paid_on date not null,
  period_label text,
  closure_id uuid references public.hr_payroll_period_closures(id) on delete restrict,
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  check ((method = 'nomina' and period_label is not null and closure_id is not null)
    or (method = 'efectivo' and period_label is null and closure_id is null)),
  unique (loan_id, closure_id)
);
create index hr_employee_loans_employee_idx on public.hr_employee_loans(employee_id);
create index hr_loan_payments_loan_idx on public.hr_loan_payments(loan_id);

-- Match AuthAccess, including the designated RH account without a profiles
-- row; an explicitly inactive profile never receives access.
create function public.hr_can_access_loans() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from auth.users u left join public.profiles p on p.user_id = u.id
    cross join lateral (select regexp_replace(translate(lower(trim(coalesce(p.role::text, ''))),
      'áéíóú', 'aeiou'), '[[:space:]-]+', '_', 'g') as role) normalized
    where u.id = auth.uid() and coalesce(p.is_active, true) and (
      lower(u.email) in ('rh@dicsamx.com', 'direccion@dicsamx.com')
      or normalized.role in ('rh','rrhh','human_resources','recursos_humanos','nominas','payroll',
        'direccion','direction','auxiliar_direccion','direccion_general')
      or normalized.role ~ '^(rh_|human_resources_|recursos_humanos_|direccion_)'
      or normalized.role ~ '(_rh|_human_resources|_recursos_humanos|_direccion)$'
      or normalized.role like '%direction%'
    )
  );
$$;
revoke all on function public.hr_can_access_loans() from public, anon;
grant execute on function public.hr_can_access_loans() to authenticated;
alter table public.hr_loan_fund enable row level security;
alter table public.hr_employee_loans enable row level security;
alter table public.hr_loan_payments enable row level security;
revoke all on public.hr_loan_fund, public.hr_employee_loans, public.hr_loan_payments from anon, authenticated;
grant select on public.hr_loan_fund, public.hr_employee_loans, public.hr_loan_payments to authenticated;
create policy hr_loan_fund_read on public.hr_loan_fund for select to authenticated
  using (public.hr_can_access_loans());
create policy hr_employee_loans_read on public.hr_employee_loans for select to authenticated
  using (public.hr_can_access_loans());
create policy hr_loan_payments_read on public.hr_loan_payments for select to authenticated
  using (public.hr_can_access_loans());

create function public.hr_loan_assert_access() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.hr_can_access_loans() then
    raise exception 'Tu perfil no tiene acceso al fondo de préstamos.' using errcode = '42501';
  end if;
end;
$$;

-- Every financial mutation locks this single fund row, including payroll close.
-- Balance is derived from the ledger, never an editable client-side counter.
create function public.hr_loan_available() returns numeric
language sql stable security definer set search_path = '' as $$
  select f.capital - coalesce((select sum(principal) from public.hr_employee_loans), 0)
    + coalesce((select sum(amount) from public.hr_loan_payments), 0)
  from public.hr_loan_fund f where id;
$$;

create function public.hr_loan_due(p_loan_id uuid, p_through date) returns numeric
language sql stable security definer set search_path = '' as $$
  with l as (select * from public.hr_employee_loans where id = p_loan_id),
  scheduled as (
    select l.*,
      case frequency
        when 'semanal' then first_due_on + (i * 7)
        when 'quincenal' then first_due_on + (i * 14)
        else (first_due_on + pg_catalog.make_interval(months => i))::date
      end as due_on,
      case when i = installment_count - 1
        then principal - trunc(principal / installment_count, 2) * (installment_count - 1)
        else trunc(principal / installment_count, 2) end as installment
    from l cross join lateral pg_catalog.generate_series(0, installment_count - 1) i
  )
  select greatest(0, coalesce(sum(installment) filter (where due_on <= p_through and issued_on <= p_through), 0)
    - coalesce((select sum(amount) from public.hr_loan_payments where loan_id = p_loan_id), 0))
  from scheduled;
$$;

create function public.hr_loan_create(
  p_request_id uuid, p_employee_id text, p_principal numeric,
  p_installment_count integer, p_repayment_method text, p_frequency text,
  p_issued_on date, p_first_due_on date, p_notes text default ''
) returns uuid language plpgsql security definer set search_path = '' as $$
declare l public.hr_employee_loans; person public.hr_employee_profiles; v_id uuid;
begin
  perform public.hr_loan_assert_access();
  perform 1 from public.hr_loan_fund where id for update;
  select * into l from public.hr_employee_loans where request_id = p_request_id;
  if found then
    if l.employee_id <> p_employee_id or l.principal <> p_principal
      or l.installment_count <> p_installment_count or l.repayment_method <> p_repayment_method
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
    principal, installment_count, repayment_method, frequency, issued_on, first_due_on, notes, created_by)
  values(p_request_id, person.id, person.nombre, coalesce(person.empresa, ''),
    p_principal, p_installment_count, p_repayment_method, p_frequency, p_issued_on, p_first_due_on,
    coalesce(p_notes, ''), auth.uid()) returning id into v_id;
  return v_id;
end;
$$;

create function public.hr_loan_record_cash_payment(
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
  select l.principal - coalesce(sum(amount), 0) into balance
    from public.hr_loan_payments where loan_id = l.id;
  if p_amount is null or p_amount <= 0 or p_amount <> round(p_amount, 2) or p_amount > balance then
    raise exception 'El abono debe ser positivo y no superar el saldo pendiente.';
  end if;
  if p_paid_on < l.issued_on or p_paid_on > timezone('America/Mexico_City', now())::date then
    raise exception 'La fecha del abono debe estar entre la entrega y hoy.';
  end if;
  insert into public.hr_loan_payments(request_id, loan_id, amount, method, paid_on, notes, created_by)
    values(p_request_id, p_loan_id, p_amount, 'efectivo', p_paid_on, coalesce(p_notes, ''), auth.uid())
    returning id into v_id;
  return v_id;
end;
$$;

-- Protect the loan part of the existing draft snapshot and synchronize edits
-- with closure. Existing manual loan deductions keep their original meaning.
create function public.hr_loan_guard_draft() returns trigger
language plpgsql security definer set search_path = '' as $$
declare s jsonb; v_amount numeric; v_sum numeric;
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
  if jsonb_typeof(s -> 'allocations') is distinct from 'array'
    or v_amount is null or v_amount < 0 or v_amount <> round(v_amount, 2)
    or coalesce(new.loan_deduction_amount, 0) < v_amount then
    raise exception 'El desglose del préstamo no coincide con el descuento.';
  end if;
  select coalesce(sum((a ->> 'amount')::numeric), 0) into v_sum
    from jsonb_array_elements(s -> 'allocations') a;
  if v_sum <> v_amount then raise exception 'El desglose de abonos no coincide con su total.'; end if;
  return new;
end;
$$;
create trigger a_hr_loan_guard_draft before insert or update or delete
  on public.hr_prenomina_draft_rows for each row execute function public.hr_loan_guard_draft();

-- AFTER insert/update: the FK can reference the closure. Any failure rolls
-- back both closure and all payments; retrying a closed period is a no-op.
create function public.hr_loan_settle_payroll() returns trigger
language plpgsql security definer set search_path = '' as $$
declare d public.hr_prenomina_draft_rows; s jsonb; a jsonb; l public.hr_employee_loans;
  v_end date; parts text[]; v_due numeric; v_expected numeric; v_amount numeric;
  v_available_flow numeric; v_manual numeric; v_total numeric; v_count integer;
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
    select coalesce(sum(public.hr_loan_due(id, v_end)), 0) into v_expected
      from public.hr_employee_loans where employee_id = d.employee_id and repayment_method = 'nomina';
    s := d.source_snapshot -> 'loan_fund';
    if v_expected = 0 and coalesce((s ->> 'amount')::numeric, 0) = 0 then continue; end if;
    if s is null or (s ->> 'version')::integer is distinct from 1
      or (s ->> 'end_date')::date is distinct from v_end
      or (s ->> 'requested_amount')::numeric is distinct from v_expected then
      raise exception 'Los préstamos de % cambiaron. Actualiza y guarda su prenómina antes de cerrar.', d.employee_name;
    end if;
    v_total := coalesce((s ->> 'amount')::numeric, 0);
    v_manual := coalesce(d.loan_deduction_amount, 0) - v_total;
    v_available_flow := greatest(0,
      coalesce(d.cash_salary_amount, 0) + coalesce(d.cash_vacation_amount, 0)
      + coalesce(d.transport_support_amount, 0) + coalesce(d.holiday_amount, 0)
      + coalesce(d.overtime_monetized_amount, 0) + coalesce(d.manual_bonus_amount, 0)
      + coalesce(d.payment_outside_amount, 0) + coalesce(d.manual_adjustment_amount, 0)
      - coalesce(d.cash_isr_amount, 0) - coalesce(d.cash_infonavit_deduction_amount, 0)
      - coalesce(d.cash_fonacot_deduction_amount, 0) - v_manual
      - case when d.source_snapshot ->> 'incidences_informational' = 'true' then 0
        else coalesce(d.cash_absence_deduction_amount, 0) end);
    if v_total < 0 or v_total > v_expected or v_total > round(v_available_flow, 2) or v_manual < 0 then
      raise exception 'El abono de % supera la deuda o el flujo disponible.', d.employee_name;
    end if;
    select count(*), count(distinct a2 ->> 'loan_id') into v_count, v_amount
      from jsonb_array_elements(s -> 'allocations') a2;
    if v_count <> v_amount then raise exception 'Hay préstamos repetidos en el desglose.'; end if;
    v_amount := 0;
    for a in select * from jsonb_array_elements(s -> 'allocations') loop
      select * into l from public.hr_employee_loans where id = (a ->> 'loan_id')::uuid;
      v_due := public.hr_loan_due(l.id, v_end);
      if l.id is null or l.employee_id <> d.employee_id or l.repayment_method <> 'nomina'
        or (a ->> 'amount')::numeric is null or (a ->> 'amount')::numeric <= 0
        or (a ->> 'amount')::numeric <> round((a ->> 'amount')::numeric, 2)
        or (a ->> 'amount')::numeric > v_due then
        raise exception 'El abono de % ya no coincide con el saldo de su préstamo.', d.employee_name;
      end if;
      insert into public.hr_loan_payments(request_id, loan_id, amount, method, paid_on, period_label, closure_id, notes, created_by)
      values(gen_random_uuid(), l.id, (a ->> 'amount')::numeric, 'nomina', v_end, new.period_label, new.id,
        'Descuento confirmado al cerrar nómina.', auth.uid());
      v_amount := v_amount + (a ->> 'amount')::numeric;
    end loop;
    if v_amount <> v_total then raise exception 'El total del préstamo no coincide con sus abonos.'; end if;
  end loop;
  return new;
end;
$$;
create trigger hr_loan_settle_payroll after insert or update on public.hr_payroll_period_closures
  for each row execute function public.hr_loan_settle_payroll();

revoke all on function public.hr_loan_assert_access(), public.hr_loan_available(),
  public.hr_loan_due(uuid,date), public.hr_loan_guard_draft(), public.hr_loan_settle_payroll(),
  public.hr_loan_create(uuid,text,numeric,integer,text,text,date,date,text),
  public.hr_loan_record_cash_payment(uuid,uuid,numeric,date,text) from public, anon, authenticated;
grant execute on function public.hr_loan_create(uuid,text,numeric,integer,text,text,date,date,text),
  public.hr_loan_record_cash_payment(uuid,uuid,numeric,date,text) to authenticated;

comment on table public.hr_loan_fund is 'Capital fijo inicial de 15000 MXN. Disponible = capital - entregas + abonos confirmados.';
comment on table public.hr_employee_loans is 'Préstamos sin intereses, cuota y calendario propios. Registrar representa una entrega ya realizada.';
comment on table public.hr_loan_payments is 'Abonos inmutables en efectivo o por cierre de nómina; no incluye descuentos manuales históricos sin préstamo ligado.';
notify pgrst, 'reload schema';
commit;
