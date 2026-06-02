begin;

create table if not exists public.men_cash_vouchers_duplicate_fix_backup_20260601 as
select *
from public.men_cash_vouchers
where false;

insert into public.men_cash_vouchers_duplicate_fix_backup_20260601
select v.*
from public.men_cash_vouchers v
where exists (
  select 1
  from public.men_cash_vouchers d
  where d.voucher_type = v.voucher_type
    and d.folio = v.folio
  group by d.voucher_type, d.folio
  having count(*) > 1
)
and not exists (
  select 1
  from public.men_cash_vouchers_duplicate_fix_backup_20260601 b
  where b.id = v.id
);

with duplicate_groups as (
  select voucher_type, folio
  from public.men_cash_vouchers
  group by voucher_type, folio
  having count(*) > 1
),
ranked_duplicates as (
  select
    v.id,
    v.voucher_type,
    v.folio,
    v.created_at,
    row_number() over (
      partition by v.voucher_type, v.folio
      order by v.created_at asc, v.id asc
    ) as duplicate_rank
  from public.men_cash_vouchers v
  join duplicate_groups g
    on g.voucher_type = v.voucher_type
   and g.folio = v.folio
),
rows_to_fix as (
  select
    d.id,
    d.voucher_type,
    row_number() over (
      partition by d.voucher_type
      order by d.created_at asc, d.id asc
    ) as fix_ordinal
  from ranked_duplicates d
  where d.duplicate_rank > 1
),
sequence_base as (
  select
    voucher_type,
    greatest(
      case
        when voucher_type = 'deposit' then 250
        else 18420
      end,
      coalesce(
        max(
          case
            when regexp_replace(folio, '[^0-9]', '', 'g') = '' then null
            else regexp_replace(folio, '[^0-9]', '', 'g')::integer
          end
        ),
        0
      )
    ) as max_numeric_folio
  from public.men_cash_vouchers
  group by voucher_type
),
assigned_folios as (
  select
    r.id,
    (s.max_numeric_folio + r.fix_ordinal)::text as new_folio
  from rows_to_fix r
  join sequence_base s
    on s.voucher_type = r.voucher_type
)
update public.men_cash_vouchers v
set folio = a.new_folio
from assigned_folios a
where v.id = a.id;

create unique index if not exists men_cash_vouchers_type_folio_uidx
  on public.men_cash_vouchers (voucher_type, folio);

commit;
