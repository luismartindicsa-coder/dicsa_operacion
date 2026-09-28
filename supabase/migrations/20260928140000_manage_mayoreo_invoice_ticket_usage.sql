begin;

-- Keep historical snapshots; exclusivity applies to active reservations only.
alter table public.mayoreo_invoice_reconciliation_tickets
  alter column reconciliation_id drop not null,
  add column usage_origin text not null default 'reconciliation'
    check (usage_origin in ('reconciliation', 'manual')),
  add column created_at timestamptz not null default now(),
  add column released_at timestamptz,
  add column released_by uuid,
  add constraint mayoreo_ticket_origin_check check (
    (usage_origin = 'manual' and reconciliation_id is null)
    or (usage_origin = 'reconciliation' and reconciliation_id is not null)),
  add constraint mayoreo_ticket_release_check check (
    (released_at is null) = (released_by is null));

update public.mayoreo_invoice_reconciliation_tickets t
set created_at = r.created_at
from public.mayoreo_invoice_reconciliations r where r.id = t.reconciliation_id;

-- PostgreSQL truncates generated names differently from a literal long name.
do $$
declare v_name text;
begin
  select conname into strict v_name from pg_constraint
  where conrelid = 'public.mayoreo_invoice_reconciliation_tickets'::regclass
    and contype = 'u' and pg_get_constraintdef(oid) = 'UNIQUE (client_key, ticket_key)';
  execute format('alter table public.mayoreo_invoice_reconciliation_tickets drop constraint %I', v_name);
end;
$$;
alter table public.mayoreo_invoice_reconciliation_tickets
  drop constraint mayoreo_invoice_reconciliation_tickets_amount_cents_check,
  add constraint mayoreo_ticket_amount_check check (
    amount_cents > 0 or usage_origin = 'manual');
create unique index mayoreo_invoice_active_ticket_key
  on public.mayoreo_invoice_reconciliation_tickets(client_key, ticket_key)
  where released_at is null;

alter table public.mayoreo_invoice_reconciliation_sources
  add column released_at timestamptz,
  drop constraint mayoreo_invoice_reconciliation_sources_pkey,
  add primary key(source_id, ticket_id);
create unique index mayoreo_invoice_active_source_key
  on public.mayoreo_invoice_reconciliation_sources(source_id)
  where released_at is null;

create table public.mayoreo_invoice_ticket_usage_changes (
  request_id uuid primary key,
  client_key text not null,
  ticket_key text not null,
  used boolean not null,
  request jsonb not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid()
);
alter table public.mayoreo_invoice_ticket_usage_changes enable row level security;
create policy mayoreo_ticket_usage_changes_read on public.mayoreo_invoice_ticket_usage_changes
  for select to authenticated using (true);
revoke all on public.mayoreo_invoice_ticket_usage_changes from anon, authenticated;
grant select on public.mayoreo_invoice_ticket_usage_changes to authenticated;

-- All operational tickets, including used/cancelled/unapproved tickets. The
-- eligibility flag stays separate from the user-editable used/not-used flag.
create view public.mayoreo_invoice_ticket_catalog with (security_invoker = true) as
with source as (
  select r.*,
    case when nullif(btrim(r.client_id), '') is not null then 'id:' || r.client_id
      else 'name:' || upper(btrim(r.client_name_snapshot)) end as client_key,
    upper(btrim(r.ticket)) as ticket_key,
    a.status as account_status
  from public.mayoreo_sales_reports r
  left join public.mayoreo_accounts a on a.id = r.id
  where left(r.id, 4) <> 'rep_'
), grouped as (
  select s.client_key, max(s.client_name_snapshot) as client_name,
    s.ticket_key, max(s.ticket) as ticket, max(s.sale_date) as sale_date,
    coalesce(sum(round(s.approved_amount * 100)), 0)::bigint as amount_cents,
    array_agg(s.id order by s.id) as source_ids,
    jsonb_agg(jsonb_build_object(
      'source_id', s.id, 'ticket', s.ticket, 'sale_date', s.sale_date,
      'client_name', s.client_name_snapshot, 'remision', s.remision,
      'material', s.material_name_snapshot, 'approved_weight', s.approved_weight,
      'approved_price', s.approved_price,
      'amount_cents', round(s.approved_amount * 100)::bigint
    ) order by s.id) as details,
    bool_and(coalesce(s.approved_weight > 0 and s.approved_price > 0
      and round(s.approved_amount * 100) > 0, false)) as approved,
    bool_or(coalesce(s.account_status, '') = 'cancelada') as cancelled
  from source s group by s.client_key, s.ticket_key
)
select g.client_key, g.client_name, g.ticket_key, g.ticket, g.sale_date,
  g.amount_cents, g.source_ids, g.details,
  (g.approved and not g.cancelled and g.ticket_key <> '') as eligible,
  case when g.cancelled then 'Cuenta cancelada'
    when not g.approved then 'Pendiente de aprobación'
    when g.ticket_key = '' then 'Sin número de boleta'
    else '' end as eligibility_reason,
  cardinality(c.claim_ids) > 0 as used, c.claim_ids, c.usage_origin
from grouped g
cross join lateral (
  select coalesce(array_agg(t.id order by t.id), '{}'::uuid[]) as claim_ids,
    case when bool_or(t.reconciliation_id is not null) then 'reconciliation'
      when count(*) > 0 then 'manual' else null end as usage_origin
  from public.mayoreo_invoice_reconciliation_tickets t
  where t.released_at is null and (
    (t.client_key = g.client_key and t.ticket_key = g.ticket_key)
    or exists (select 1 from public.mayoreo_invoice_reconciliation_sources s
      where s.ticket_id = t.id and s.released_at is null and s.source_id = any(g.source_ids))
  )
) c;
revoke all on public.mayoreo_invoice_ticket_catalog from anon, authenticated;
grant select on public.mayoreo_invoice_ticket_catalog to authenticated;

-- Preserve the original column contract used by both the search and save RPC.
create or replace view public.mayoreo_invoice_available_tickets with (security_invoker = true) as
select client_key, client_name, ticket_key, ticket, sale_date, amount_cents, source_ids, details
from public.mayoreo_invoice_ticket_catalog where eligible and not used;

create function public.mayoreo_set_invoice_ticket_usage(
  p_request_id uuid, p_client_key text, p_ticket_key text,
  p_used boolean, p_expected_claim_ids uuid[], p_snapshot jsonb
) returns jsonb
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_current record;
  v_previous public.mayoreo_invoice_ticket_usage_changes;
  v_request jsonb;
  v_result jsonb;
  v_ticket_id uuid;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Se requiere iniciar sesión.';
  end if;
  if p_request_id is null or nullif(btrim(p_client_key), '') is null
    or p_ticket_key is null or p_used is null or p_expected_claim_ids is null
    or p_snapshot is null or jsonb_typeof(p_snapshot) <> 'object' then
    raise exception using errcode = '22023', message = 'Datos de boleta inválidos.';
  end if;
  v_request := jsonb_build_object('client_key', p_client_key, 'ticket_key', p_ticket_key,
    'used', p_used, 'claim_ids', p_expected_claim_ids, 'snapshot', p_snapshot);
  -- The same lock as saving a reconciliation prevents a stale "unused" action
  -- from accidentally releasing a newly created invoice reservation.
  perform pg_advisory_xact_lock(2812092026::bigint);
  select * into v_previous from public.mayoreo_invoice_ticket_usage_changes
    where request_id = p_request_id;
  if found then
    if v_previous.request is distinct from v_request then
      raise exception using errcode = 'PT409', message = 'La solicitud ya existe con otro contenido.';
    end if;
    return v_previous.result;
  end if;
  lock table public.mayoreo_sales_reports, public.mayoreo_accounts in share mode;
  select * into v_current from public.mayoreo_invoice_ticket_catalog
    where client_key = p_client_key and ticket_key = p_ticket_key;
  if not found then
    raise exception using errcode = 'PT409', message = 'La boleta cambió o ya no existe. Revisa la lista actualizada.';
  end if;
  if v_current.claim_ids is distinct from p_expected_claim_ids
    or p_snapshot is distinct from jsonb_build_object(
      'ticket_key', v_current.ticket_key, 'amount_cents', v_current.amount_cents,
      'source_ids', v_current.source_ids, 'details', v_current.details) then
    raise exception using errcode = 'PT409',
      message = 'El uso o los datos de esta boleta cambiaron. Revisa la lista actualizada.';
  end if;

  if p_used and not v_current.used then
    insert into public.mayoreo_invoice_reconciliation_tickets
      (reconciliation_id, usage_origin, client_key, client_name, ticket_key,
        ticket, sale_date, amount_cents, source_ids, details)
    values (null, 'manual', v_current.client_key, v_current.client_name,
      v_current.ticket_key, v_current.ticket, v_current.sale_date,
      v_current.amount_cents, v_current.source_ids, v_current.details)
    returning id into v_ticket_id;
    insert into public.mayoreo_invoice_reconciliation_sources(source_id, ticket_id)
      select unnest(v_current.source_ids), v_ticket_id;
  elsif not p_used and v_current.used then
    update public.mayoreo_invoice_reconciliation_sources
      set released_at = now() where ticket_id = any(v_current.claim_ids) and released_at is null;
    update public.mayoreo_invoice_reconciliation_tickets
      set released_at = now(), released_by = auth.uid()
      where id = any(v_current.claim_ids) and released_at is null;
  end if;
  select to_jsonb(c) into v_result from public.mayoreo_invoice_ticket_catalog c
    where client_key = p_client_key and ticket_key = p_ticket_key;
  insert into public.mayoreo_invoice_ticket_usage_changes
    (request_id, client_key, ticket_key, used, request, result)
  values (p_request_id, p_client_key, p_ticket_key, p_used, v_request, v_result);
  return v_result;
end;
$$;
revoke all on function public.mayoreo_set_invoice_ticket_usage(uuid,text,text,boolean,uuid[],jsonb) from public, anon;
grant execute on function public.mayoreo_set_invoice_ticket_usage(uuid,text,text,boolean,uuid[],jsonb) to authenticated;

commit;
