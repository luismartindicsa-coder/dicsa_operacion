begin;

alter table public.hr_prenomina_draft_rows
  add column fiscal_manual_deduction_amount numeric(12,2) not null default 0,
  add column fiscal_manual_deduction_reason text not null default '',
  add constraint hr_prenomina_manual_fiscal_deduction_check check (
    fiscal_manual_deduction_amount >= 0 and fiscal_manual_deduction_amount <> 'NaN'::numeric
    and (fiscal_manual_deduction_amount = 0 or length(trim(fiscal_manual_deduction_reason)) > 0));

comment on column public.hr_prenomina_draft_rows.fiscal_manual_deduction_amount is
  'Additional RH deduction from fiscal payable, applied once. Does not overwrite the official CONTPAQ net or reduce flow.';

create table public.hr_prenomina_fiscal_deduction_changes (
  id uuid primary key default gen_random_uuid(),
  draft_id uuid references public.hr_prenomina_draft_rows(id) on delete set null,
  employee_id text not null,
  period_label text not null,
  previous_amount numeric(12,2) not null,
  amount numeric(12,2) not null,
  previous_reason text not null,
  reason text not null,
  fiscal_net_at_change numeric(12,2),
  contpaq_net_at_change numeric(12,2),
  changed_at timestamptz not null default now(),
  changed_by uuid references auth.users(id)
);
alter table public.hr_prenomina_fiscal_deduction_changes enable row level security;
revoke all on public.hr_prenomina_fiscal_deduction_changes from anon, authenticated;
grant select on public.hr_prenomina_fiscal_deduction_changes to authenticated;
create policy hr_prenomina_fiscal_deduction_changes_read
  on public.hr_prenomina_fiscal_deduction_changes for select to authenticated
  using (public.hr_can_access_loans());

create function public.hr_guard_manual_fiscal_deduction() returns trigger
language plpgsql security definer set search_path = '' as $$
declare prior_amount numeric := 0; prior_reason text := ''; available numeric;
begin
  if tg_op = 'UPDATE' then
    prior_amount := old.fiscal_manual_deduction_amount;
    prior_reason := old.fiscal_manual_deduction_reason;
  end if;
  if new.fiscal_manual_deduction_amount > 0 then
    available := greatest(0, coalesce(new.fiscal_net_amount,0)
      - case when new.source_snapshot ->> 'incidences_informational' = 'true' then 0
        else coalesce(new.fiscal_late_deduction_amount,0) end)
      + case when new.source_snapshot ->> 'contpaq_official_net' is not null then 0
        else coalesce(new.fiscal_vacation_amount,0) end;
    if new.fiscal_manual_deduction_amount > available then
      raise exception 'El descuento fiscal manual supera el fiscal disponible (%).', available;
    end if;
  end if;
  if (prior_amount,prior_reason) is distinct from
      (new.fiscal_manual_deduction_amount,new.fiscal_manual_deduction_reason) then
    perform public.hr_loan_assert_access();
  end if;
  return new;
end;
$$;
create trigger hr_guard_manual_fiscal_deduction before insert or update on public.hr_prenomina_draft_rows
for each row execute function public.hr_guard_manual_fiscal_deduction();

create function public.hr_audit_manual_fiscal_deduction() returns trigger
language plpgsql security definer set search_path = '' as $$
declare prior_amount numeric := 0; prior_reason text := '';
begin
  if tg_op = 'UPDATE' then
    prior_amount := old.fiscal_manual_deduction_amount;
    prior_reason := old.fiscal_manual_deduction_reason;
  end if;
  if (prior_amount,prior_reason) is distinct from
      (new.fiscal_manual_deduction_amount,new.fiscal_manual_deduction_reason) then
    insert into public.hr_prenomina_fiscal_deduction_changes
      (draft_id,employee_id,period_label,previous_amount,amount,previous_reason,reason,
       fiscal_net_at_change,contpaq_net_at_change,changed_by)
    values(new.id,new.employee_id,new.period_label,prior_amount,new.fiscal_manual_deduction_amount,
      prior_reason,new.fiscal_manual_deduction_reason,new.fiscal_net_amount,
      (new.source_snapshot ->> 'contpaq_official_net')::numeric,auth.uid());
  end if;
  return new;
end;
$$;
create trigger hr_audit_manual_fiscal_deduction after insert or update on public.hr_prenomina_draft_rows
for each row execute function public.hr_audit_manual_fiscal_deduction();
revoke all on function public.hr_guard_manual_fiscal_deduction(), public.hr_audit_manual_fiscal_deduction() from public, anon, authenticated;
notify pgrst, 'reload schema';
commit;
