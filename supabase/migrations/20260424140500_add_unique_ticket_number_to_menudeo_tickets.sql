begin;

create table if not exists public.men_tickets_duplicate_fix_backup_20260424 as
select *
from public.men_tickets
where false;

insert into public.men_tickets_duplicate_fix_backup_20260424
select t.*
from public.men_tickets t
where t.ticket_number in (
  select ticket_number
  from public.men_tickets
  group by ticket_number
  having count(*) > 1
)
and not exists (
  select 1
  from public.men_tickets_duplicate_fix_backup_20260424 b
  where b.id = t.id
);

with duplicate_numbers as (
  select ticket_number
  from public.men_tickets
  group by ticket_number
  having count(*) > 1
),
ranked_duplicates as (
  select
    t.id,
    t.ticket_base,
    row_number() over (
      partition by t.ticket_number
      order by t.created_at asc, t.id asc
    ) as duplicate_rank
  from public.men_tickets t
  where t.ticket_number in (select ticket_number from duplicate_numbers)
),
rows_to_fix as (
  select
    d.id,
    d.ticket_base,
    row_number() over (
      partition by d.ticket_base
      order by mt.created_at asc, mt.id asc
    ) as fix_ordinal
  from ranked_duplicates d
  join public.men_tickets mt on mt.id = d.id
  where d.duplicate_rank > 1
),
existing_suffixes as (
  select distinct
    ticket_base,
    coalesce(nullif(upper(btrim(ticket_suffix)), ''), '') as normalized_suffix
  from public.men_tickets
),
available_suffixes as (
  select
    bases.ticket_base,
    candidates.suffix,
    row_number() over (
      partition by bases.ticket_base
      order by candidates.sort_order asc
    ) as available_ordinal
  from (
    select distinct ticket_base
    from rows_to_fix
  ) bases
  cross join lateral (
    select suffix, sort_order
    from (
      select chr(64 + n) as suffix, n as sort_order
      from generate_series(1, 26) as gs(n)
      union all
      select 'A' || n::text as suffix, 1000 + n as sort_order
      from generate_series(1, 999) as gs(n)
    ) generated
    where not exists (
      select 1
      from existing_suffixes e
      where e.ticket_base = bases.ticket_base
        and e.normalized_suffix = generated.suffix
    )
  ) candidates
),
assigned_suffixes as (
  select
    rows_to_fix.id,
    available_suffixes.suffix
  from rows_to_fix
  join available_suffixes
    on available_suffixes.ticket_base = rows_to_fix.ticket_base
   and available_suffixes.available_ordinal = rows_to_fix.fix_ordinal
)
update public.men_tickets t
set ticket_suffix = assigned_suffixes.suffix
from assigned_suffixes
where t.id = assigned_suffixes.id;

create unique index if not exists men_tickets_ticket_number_uidx
  on public.men_tickets (ticket_number);

commit;
