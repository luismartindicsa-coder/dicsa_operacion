begin;

create table if not exists public.men_cash_cuts_backup_20260424 as
select * from public.men_cash_cuts;

create table if not exists public.men_cash_cut_checks_backup_20260424 as
select * from public.men_cash_cut_checks;

create table if not exists public.men_cash_vouchers_backup_20260424 as
select * from public.men_cash_vouchers;

create table if not exists public.men_cash_voucher_lines_backup_20260424 as
select * from public.men_cash_voucher_lines;

create table if not exists public.men_tickets_backup_20260424 as
select * from public.men_tickets;

alter table public.men_cash_cuts
  drop constraint if exists men_cash_cuts_cut_date_key;

alter table public.men_cash_cuts
  add column if not exists opened_at timestamptz;

update public.men_cash_cuts
set opened_at = coalesce(
  opened_at,
  created_at,
  timezone('utc'::text, cut_date::timestamp)
)
where opened_at is null;

update public.men_cash_cuts
set closed_at = coalesce(closed_at, updated_at)
where closed_at is null
  and status in ('CERRADO', 'CON_PENDIENTES');

alter table public.men_cash_cuts
  alter column opened_at set not null;

create index if not exists men_cash_cuts_opened_at_idx
  on public.men_cash_cuts (opened_at desc);

create index if not exists men_cash_cuts_open_state_idx
  on public.men_cash_cuts (closed_at, opened_at desc);

create unique index if not exists men_cash_cuts_single_open_idx
  on public.men_cash_cuts ((1))
  where closed_at is null;

alter table public.men_tickets
  add column if not exists cash_cut_id uuid references public.men_cash_cuts(id) on delete set null;

alter table public.men_cash_vouchers
  add column if not exists cash_cut_id uuid references public.men_cash_cuts(id) on delete set null;

create index if not exists men_tickets_cash_cut_idx
  on public.men_tickets (cash_cut_id, created_at);

create index if not exists men_cash_vouchers_cash_cut_idx
  on public.men_cash_vouchers (cash_cut_id, created_at);

update public.men_tickets t
set cash_cut_id = c.id
from public.men_cash_cuts c
where t.cash_cut_id is null
  and t.ticket_date = c.cut_date;

update public.men_cash_vouchers v
set cash_cut_id = c.id
from public.men_cash_cuts c
where v.cash_cut_id is null
  and v.voucher_date = c.cut_date;

do $$
declare
  bootstrap_cut_id uuid;
  bootstrap_opened_at timestamptz;
  bootstrap_cut_date date;
begin
  select c.id
  into bootstrap_cut_id
  from public.men_cash_cuts c
  where c.closed_at is null
  order by c.opened_at desc, c.created_at desc
  limit 1;

  if bootstrap_cut_id is null then
    select
      min(src.created_at),
      min(src.cut_date)
    into
      bootstrap_opened_at,
      bootstrap_cut_date
    from (
      select t.created_at, t.ticket_date as cut_date
      from public.men_tickets t
      where t.cash_cut_id is null
      union all
      select v.created_at, v.voucher_date as cut_date
      from public.men_cash_vouchers v
      where v.cash_cut_id is null
    ) src;

    if bootstrap_opened_at is not null then
      insert into public.men_cash_cuts (
        cut_date,
        opened_at,
        opening_cash,
        sales_total,
        purchases_total,
        deposits_total,
        expenses_total,
        theoretical_cash_total,
        counted_cash_total,
        difference_total,
        pending_checks_count,
        status,
        notes,
        created_at,
        updated_at
      ) values (
        coalesce(bootstrap_cut_date, (bootstrap_opened_at at time zone 'utc')::date),
        bootstrap_opened_at,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        'ABIERTO',
        'Sesion abierta migrada automaticamente desde el esquema diario anterior.',
        bootstrap_opened_at,
        timezone('utc'::text, now())
      )
      returning id into bootstrap_cut_id;
    end if;
  end if;

  if bootstrap_cut_id is not null then
    update public.men_tickets
    set cash_cut_id = bootstrap_cut_id
    where cash_cut_id is null;

    update public.men_cash_vouchers
    set cash_cut_id = bootstrap_cut_id
    where cash_cut_id is null;
  end if;
end $$;

create or replace function public.attach_open_men_cash_cut()
returns trigger
language plpgsql
as $$
declare
  open_cut_id uuid;
begin
  if new.cash_cut_id is not null then
    return new;
  end if;

  select c.id
  into open_cut_id
  from public.men_cash_cuts c
  where c.closed_at is null
  order by c.opened_at desc, c.created_at desc
  limit 1;

  if open_cut_id is not null then
    new.cash_cut_id := open_cut_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_attach_men_ticket_cash_cut on public.men_tickets;
create trigger trg_attach_men_ticket_cash_cut
before insert on public.men_tickets
for each row
execute function public.attach_open_men_cash_cut();

drop trigger if exists trg_attach_men_voucher_cash_cut on public.men_cash_vouchers;
create trigger trg_attach_men_voucher_cash_cut
before insert on public.men_cash_vouchers
for each row
execute function public.attach_open_men_cash_cut();

drop view if exists public.vw_men_tickets_grid;
create view public.vw_men_tickets_grid as
select
  t.id,
  t.split_batch_id,
  t.cash_cut_id,
  t.ticket_date,
  t.ticket_base,
  t.ticket_suffix,
  t.ticket_number,
  t.counterparty_id,
  t.counterparty_name_snapshot,
  t.price_id,
  t.general_material_id,
  t.commercial_material_id,
  t.material_alias_id,
  t.material_label_snapshot,
  t.price_at_entry,
  t.gross_weight,
  t.tare_weight,
  t.humidity_percent,
  t.trash_weight,
  t.premium_per_kg,
  t.net_weight,
  t.payable_weight,
  t.amount_total,
  t.status,
  t.comment,
  t.created_by,
  t.created_at,
  t.updated_at
from public.men_tickets t
order by t.ticket_date desc, t.ticket_number;

drop view if exists public.vw_men_cash_vouchers_grid;
create view public.vw_men_cash_vouchers_grid as
with first_line as (
  select distinct on (l.voucher_id)
    l.voucher_id,
    l.concept
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
  v.person_label,
  v.rubric,
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

drop view if exists public.vw_men_cash_cuts_grid;
create view public.vw_men_cash_cuts_grid as
select
  c.id,
  c.cut_date,
  c.opened_at,
  c.opening_cash,
  c.sales_total,
  c.purchases_total,
  c.deposits_total,
  c.expenses_total,
  c.theoretical_cash_total,
  c.counted_cash_total,
  c.difference_total,
  coalesce(p.pending_checks_count, c.pending_checks_count, 0) as pending_checks_count,
  c.status,
  c.notes,
  c.created_by,
  c.closed_at,
  c.created_at,
  c.updated_at
from public.men_cash_cuts c
left join (
  select
    cash_cut_id,
    count(*) filter (where is_verified is false) as pending_checks_count
  from public.men_cash_cut_checks
  group by cash_cut_id
) p on p.cash_cut_id = c.id
order by coalesce(c.closed_at, c.opened_at) desc, c.opened_at desc;

comment on table public.men_cash_cuts is
  'Bloques o sesiones de caja de menudeo. Una apertura inicia el bloque y el corte lo cierra, incluso si cruza de un dia a otro.';

comment on view public.vw_men_cash_cuts_grid is
  'Vista historica de bloques de caja de menudeo ordenada por cierre/apertura real, no por dia calendario.';

grant select on public.vw_men_tickets_grid to authenticated;
grant select on public.vw_men_cash_vouchers_grid to authenticated;
grant select on public.vw_men_cash_cuts_grid to authenticated;

commit;
