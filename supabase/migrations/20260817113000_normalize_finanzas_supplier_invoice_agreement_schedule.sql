begin;

-- Normalize existing POR_FACTURAS agreements so the oldest linked invoice
-- group receives the earliest commitment slot, without moving invoices across
-- groups or touching supplier catalogs / invoices themselves.
--
-- Scope safeguards:
-- 1. Skip canceled agreements.
-- 2. Skip any agreement that already has paid or canceled installments.
-- 3. Skip malformed agreements where any installment lacks linked invoices
--    or links are not attached to a concrete installment.

create temporary table tmp_fin_agreement_schedule_candidates
on commit drop as
select
  a.id as agreement_id
from public.finanzas_supplier_agreements a
join lateral (
  select
    count(*) as installment_count,
    count(*) filter (where i.status = 'PAGADO') as paid_installment_count,
    count(*) filter (where i.status = 'CANCELADO') as canceled_installment_count
  from public.finanzas_supplier_agreement_installments i
  where i.agreement_id = a.id
) installments on true
join lateral (
  select
    count(*) as link_count,
    count(*) filter (where l.installment_id is null) as null_installment_link_count,
    count(distinct l.installment_id) filter (
      where l.installment_id is not null
    ) as linked_installment_count
  from public.finanzas_supplier_agreement_invoices l
  where l.agreement_id = a.id
) links on true
where a.agreement_type = 'POR_FACTURAS'
  and a.status <> 'CANCELADO'
  and installments.installment_count > 0
  and installments.paid_installment_count = 0
  and installments.canceled_installment_count = 0
  and links.link_count > 0
  and links.null_installment_link_count = 0
  and links.linked_installment_count = installments.installment_count;

create temporary table tmp_fin_agreement_canonical_links
on commit drop as
select
  l.id as link_id,
  l.agreement_id,
  l.installment_id,
  row_number() over (
    partition by l.agreement_id
    order by
      coalesce(inv.due_date::date, inv.invoice_date::date),
      inv.invoice_date::date,
      upper(trim(inv.invoice_folio)),
      inv.id,
      l.id
  ) as canonical_sequence_number
from public.finanzas_supplier_agreement_invoices l
join tmp_fin_agreement_schedule_candidates candidate
  on candidate.agreement_id = l.agreement_id
join public.finanzas_supplier_invoices inv
  on inv.id = l.invoice_id;

create temporary table tmp_fin_agreement_installment_schedule
on commit drop as
with installment_group_rank as (
  select
    links.agreement_id,
    links.installment_id,
    min(links.canonical_sequence_number) as first_canonical_sequence_number,
    count(*) as scheduled_invoice_count
  from tmp_fin_agreement_canonical_links links
  group by links.agreement_id, links.installment_id
),
schedule_slots as (
  select
    installment.agreement_id,
    installment.id as installment_id,
    row_number() over (
      partition by installment.agreement_id
      order by installment.due_date, installment.sequence_number, installment.id
    ) as slot_index,
    installment.sequence_number as slot_sequence_number,
    installment.due_date as slot_due_date
  from public.finanzas_supplier_agreement_installments installment
  join tmp_fin_agreement_schedule_candidates candidate
    on candidate.agreement_id = installment.agreement_id
)
select
  ranked.agreement_id,
  ranked.installment_id,
  slots.slot_sequence_number as target_sequence_number,
  slots.slot_due_date as target_due_date,
  ranked.scheduled_invoice_count
from (
  select
    group_rank.agreement_id,
    group_rank.installment_id,
    group_rank.scheduled_invoice_count,
    row_number() over (
      partition by group_rank.agreement_id
      order by group_rank.first_canonical_sequence_number, group_rank.installment_id
    ) as desired_slot_index
  from installment_group_rank group_rank
) ranked
join schedule_slots slots
  on slots.agreement_id = ranked.agreement_id
 and slots.slot_index = ranked.desired_slot_index;

update public.finanzas_supplier_agreement_invoices link
set sequence_number = canonical.canonical_sequence_number
from tmp_fin_agreement_canonical_links canonical
where canonical.link_id = link.id
  and link.sequence_number is distinct from canonical.canonical_sequence_number;

update public.finanzas_supplier_agreement_installments installment
set sequence_number = installment.sequence_number + 1000
where exists (
  select 1
  from tmp_fin_agreement_schedule_candidates candidate
  where candidate.agreement_id = installment.agreement_id
);

update public.finanzas_supplier_agreement_installments installment
set
  sequence_number = mapping.target_sequence_number,
  due_date = mapping.target_due_date,
  commitment_type = 'FACTURAS',
  scheduled_invoice_count = mapping.scheduled_invoice_count,
  status = case
    when coalesce(installment.paid_amount, 0) >= coalesce(installment.amount, 0) - 0.009
      then 'PAGADO'
    when mapping.target_due_date::date < timezone('America/Mexico_City', now())::date
      then 'VENCIDO'
    else 'PENDIENTE'
  end
from tmp_fin_agreement_installment_schedule mapping
where mapping.installment_id = installment.id;

with agreement_summaries as (
  select
    agreement.id as agreement_id,
    coalesce(link_counts.link_count, 0) as scheduled_invoice_count,
    installment_totals.installment_count,
    installment_totals.total_amount,
    installment_totals.remaining_amount,
    next_installment.next_due_date,
    case
      when agreement.status = 'CANCELADO' then 'CANCELADO'
      when installment_totals.remaining_amount <= 0.009 then 'CUMPLIDO'
      when installment_totals.has_overdue then 'ATRASADO'
      else 'ACTIVO'
    end as agreement_status
  from public.finanzas_supplier_agreements agreement
  join tmp_fin_agreement_schedule_candidates candidate
    on candidate.agreement_id = agreement.id
  join lateral (
    select
      count(*) as installment_count,
      coalesce(sum(installment.amount), 0)::numeric(14,2) as total_amount,
      coalesce(
        sum(
          case
            when installment.status in ('PAGADO', 'CANCELADO') then 0
            else greatest(installment.amount - installment.paid_amount, 0)
          end
        ),
        0
      )::numeric(14,2) as remaining_amount,
      coalesce(
        bool_or(
          installment.status not in ('PAGADO', 'CANCELADO')
          and installment.due_date::date < timezone('America/Mexico_City', now())::date
        ),
        false
      ) as has_overdue
    from public.finanzas_supplier_agreement_installments installment
    where installment.agreement_id = agreement.id
  ) installment_totals on true
  left join lateral (
    select next_row.due_date as next_due_date
    from public.finanzas_supplier_agreement_installments next_row
    where next_row.agreement_id = agreement.id
      and next_row.status not in ('PAGADO', 'CANCELADO')
    order by next_row.sequence_number, next_row.due_date, next_row.id
    limit 1
  ) next_installment on true
  left join lateral (
    select count(*) as link_count
    from public.finanzas_supplier_agreement_invoices link
    where link.agreement_id = agreement.id
  ) link_counts on true
)
update public.finanzas_supplier_agreements agreement
set
  scheduled_invoice_count = summary.scheduled_invoice_count,
  installment_count = summary.installment_count,
  total_amount = summary.total_amount,
  remaining_amount = summary.remaining_amount,
  next_due_date = summary.next_due_date,
  status = summary.agreement_status
from agreement_summaries summary
where summary.agreement_id = agreement.id;

commit;
