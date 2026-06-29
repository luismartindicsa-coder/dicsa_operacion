begin;

alter table public.men_cash_vouchers
  add column if not exists person_catalog_id text not null default '',
  add column if not exists person_label_snapshot text not null default '',
  add column if not exists rubric_catalog_id text not null default '',
  add column if not exists rubric_label_snapshot text not null default '';

alter table public.men_cash_voucher_lines
  add column if not exists concept_catalog_id text not null default '',
  add column if not exists concept_label_snapshot text not null default '',
  add column if not exists subconcept_snapshot text not null default '',
  add column if not exists mode_snapshot text not null default '';

update public.men_cash_vouchers
set
  person_catalog_id = case
    when btrim(person_catalog_id) <> '' then person_catalog_id
    when btrim(person_label) = '' then ''
    else voucher_type || '-person-' ||
      trim(both '-' from regexp_replace(lower(btrim(person_label)), '[^a-z0-9]+', '-', 'g'))
  end,
  person_label_snapshot = case
    when btrim(person_label_snapshot) <> '' then person_label_snapshot
    else person_label
  end,
  rubric_catalog_id = case
    when btrim(rubric_catalog_id) <> '' then rubric_catalog_id
    when btrim(rubric) = '' then ''
    else voucher_type || '-rubric-' ||
      trim(both '-' from regexp_replace(lower(btrim(rubric)), '[^a-z0-9]+', '-', 'g'))
  end,
  rubric_label_snapshot = case
    when btrim(rubric_label_snapshot) <> '' then rubric_label_snapshot
    else rubric
  end;

update public.men_cash_voucher_lines
set
  concept_label_snapshot = case
    when btrim(concept_label_snapshot) <> '' then concept_label_snapshot
    else concept
  end,
  subconcept_snapshot = case
    when btrim(subconcept_snapshot) <> '' then subconcept_snapshot
    else subconcept
  end,
  mode_snapshot = case
    when btrim(mode_snapshot) <> '' then mode_snapshot
    else mode
  end;

drop view if exists public.vw_men_cash_vouchers_grid;

create view public.vw_men_cash_vouchers_grid as
with first_line as (
  select distinct on (l.voucher_id)
    l.voucher_id,
    coalesce(nullif(l.concept_label_snapshot, ''), l.concept) as concept
  from public.men_cash_voucher_lines l
  order by l.voucher_id, l.line_order asc, l.created_at asc
),
line_totals as (
  select
    l.voucher_id,
    count(*) as line_count,
    coalesce(sum(l.amount), 0) as line_total
  from public.men_cash_voucher_lines l
  group by l.voucher_id
)
select
  v.id,
  v.cash_cut_id,
  v.voucher_date,
  v.folio,
  v.voucher_type,
  v.person_catalog_id,
  coalesce(nullif(v.person_label_snapshot, ''), v.person_label) as person_label,
  v.rubric_catalog_id,
  coalesce(nullif(v.rubric_label_snapshot, ''), v.rubric) as rubric,
  v.comment,
  coalesce(lt.line_total, v.total_amount, 0) as total_amount,
  coalesce(lt.line_count, 0) as line_count,
  case
    when coalesce(lt.line_count, 0) <= 1 then coalesce(fl.concept, '')
    else coalesce(fl.concept, '') || ' +' || (lt.line_count - 1)::text
  end as concepts_preview,
  case
    when regexp_replace(v.folio, '[^0-9]', '', 'g') = '' then null
    else regexp_replace(v.folio, '[^0-9]', '', 'g')::bigint
  end as folio_sort,
  v.created_by,
  v.created_at,
  v.updated_at
from public.men_cash_vouchers v
left join first_line fl on fl.voucher_id = v.id
left join line_totals lt on lt.voucher_id = v.id
order by v.voucher_date desc, folio_sort desc nulls last, v.folio desc;

comment on view public.vw_men_cash_vouchers_grid is
  'Vista resumida para grid operativo de vouchers de depositos y gastos con snapshots historicos de catalogo.';

commit;
