begin;

create table public.mayoreo_invoice_reconciliations (
  id uuid primary key,
  client_key text not null,
  client_name text not null,
  target_cents bigint not null check (target_cents > 0 and target_cents <= 999999999999),
  total_cents bigint not null check (total_cents > 0 and total_cents <= target_cents),
  missing_cents bigint generated always as (target_cents - total_cents) stored,
  reference text not null default '',
  origin text not null default 'app' check (origin in ('app', 'historical')),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid()
);

-- A ticket can have several material rows. Reserve the entire ticket, and also
-- each source ID so changing its client or ticket later cannot free it again.
-- No cascading FK to the operational tables: deleting a sale must not erase
-- the audit or make a previously used ticket available again.
create table public.mayoreo_invoice_reconciliation_tickets (
  id uuid primary key default gen_random_uuid(),
  reconciliation_id uuid not null references public.mayoreo_invoice_reconciliations(id),
  client_key text not null,
  client_name text not null,
  ticket_key text not null,
  ticket text not null,
  sale_date timestamptz not null,
  amount_cents bigint not null check (amount_cents > 0),
  source_ids text[] not null,
  details jsonb not null,
  unique (client_key, ticket_key)
);

create table public.mayoreo_invoice_reconciliation_sources (
  source_id text primary key,
  ticket_id uuid not null references public.mayoreo_invoice_reconciliation_tickets(id)
);
create index on public.mayoreo_invoice_reconciliations(created_at desc, id);
create index on public.mayoreo_invoice_reconciliation_tickets(reconciliation_id);

alter table public.mayoreo_invoice_reconciliations enable row level security;
alter table public.mayoreo_invoice_reconciliation_tickets enable row level security;
alter table public.mayoreo_invoice_reconciliation_sources enable row level security;
-- Same authenticated readership as Cuentas; all writes go through the RPC.
create policy mayoreo_reconciliation_read on public.mayoreo_invoice_reconciliations
  for select to authenticated using (true);
create policy mayoreo_reconciliation_ticket_read on public.mayoreo_invoice_reconciliation_tickets
  for select to authenticated using (true);
create policy mayoreo_reconciliation_source_read on public.mayoreo_invoice_reconciliation_sources
  for select to authenticated using (true);
revoke all on public.mayoreo_invoice_reconciliations,
  public.mayoreo_invoice_reconciliation_tickets,
  public.mayoreo_invoice_reconciliation_sources from anon, authenticated;
grant select on public.mayoreo_invoice_reconciliations,
  public.mayoreo_invoice_reconciliation_tickets,
  public.mayoreo_invoice_reconciliation_sources to authenticated;

create view public.mayoreo_invoice_available_tickets with (security_invoker = true) as
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
    sum(round(s.approved_amount * 100))::bigint as amount_cents,
    array_agg(s.id order by s.id) as source_ids,
    jsonb_agg(jsonb_build_object(
      'source_id', s.id, 'ticket', s.ticket, 'sale_date', s.sale_date,
      'client_name', s.client_name_snapshot, 'remision', s.remision,
      'material', s.material_name_snapshot, 'approved_weight', s.approved_weight,
      'approved_price', s.approved_price,
      'amount_cents', round(s.approved_amount * 100)::bigint
    ) order by s.id) as details
  from source s
  group by s.client_key, s.ticket_key
  having bool_and(coalesce(s.approved_weight > 0 and s.approved_price > 0
    and round(s.approved_amount * 100) > 0, false)
    and coalesce(s.account_status, '') <> 'cancelada')
)
select g.* from grouped g
where g.ticket_key <> '' and not exists (
  select 1 from public.mayoreo_invoice_reconciliation_tickets t
  where t.client_key = g.client_key and t.ticket_key = g.ticket_key
) and not exists (
  select 1 from public.mayoreo_invoice_reconciliation_sources s
  where s.source_id = any(g.source_ids)
);
grant select on public.mayoreo_invoice_available_tickets to authenticated;
revoke all on public.mayoreo_invoice_available_tickets from anon;

create function public.mayoreo_invoice_reconciliation_clients()
returns table(client_key text, client_name text)
language sql stable security invoker set search_path = public
as $$
  select client_key, max(client_name) from public.mayoreo_invoice_available_tickets
  group by client_key order by max(client_name), client_key;
$$;
revoke all on function public.mayoreo_invoice_reconciliation_clients() from public, anon;
grant execute on function public.mayoreo_invoice_reconciliation_clients() to authenticated;

create function public.mayoreo_save_invoice_reconciliation(
  p_id uuid, p_client_key text, p_target_cents bigint, p_tickets jsonb,
  p_reference text default '', p_origin text default 'app'
) returns jsonb
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_saved public.mayoreo_invoice_reconciliations;
  v_row record;
  v_ticket_id uuid;
  v_total bigint;
  v_count integer;
  v_client_name text;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Se requiere iniciar sesión.';
  end if;
  if p_id is null or nullif(btrim(p_client_key), '') is null
    or p_target_cents is null or p_target_cents <= 0 or p_target_cents > 999999999999
    or p_tickets is null or jsonb_typeof(p_tickets) <> 'array'
    or p_origin is null or p_origin not in ('app', 'historical')
    or p_reference is null or length(p_reference) > 500 then
    raise exception using errcode = '22023', message = 'Datos de conciliación inválidos.';
  end if;
  if jsonb_array_length(p_tickets) = 0 then
    raise exception using errcode = '22023', message = 'Selecciona al menos una boleta.';
  end if;

  -- Serializes retries and competing reconciliations. The short SHARE locks
  -- additionally prevent sales edits/inserts/deletes while snapshots are saved.
  perform pg_advisory_xact_lock(2812092026::bigint);
  select * into v_saved from public.mayoreo_invoice_reconciliations where id = p_id;
  if found then
    if v_saved.client_key <> p_client_key or v_saved.target_cents <> p_target_cents
      or v_saved.reference <> btrim(p_reference) or v_saved.origin <> p_origin
      or (select jsonb_agg(jsonb_build_object('ticket_key', t.ticket_key,
          'amount_cents', t.amount_cents, 'source_ids', t.source_ids, 'details', t.details)
          order by t.ticket_key)
        from public.mayoreo_invoice_reconciliation_tickets t where t.reconciliation_id = p_id)
        is distinct from (select jsonb_agg(j order by j->>'ticket_key') from jsonb_array_elements(p_tickets) j)
    then
      raise exception using errcode = 'PT409', message = 'La solicitud ya existe con otro contenido.';
    end if;
    return to_jsonb(v_saved);
  end if;
  lock table public.mayoreo_sales_reports, public.mayoreo_accounts in share mode;

  select count(*), sum(c.amount_cents), max(c.client_name)
    into v_count, v_total, v_client_name
  from public.mayoreo_invoice_available_tickets c
  join jsonb_array_elements(p_tickets) j on j->>'ticket_key' = c.ticket_key
  where c.client_key = p_client_key
    and j = jsonb_build_object('ticket_key', c.ticket_key, 'amount_cents', c.amount_cents,
      'source_ids', c.source_ids, 'details', c.details);
  if v_count <> jsonb_array_length(p_tickets)
    or v_count <> (select count(distinct j->>'ticket_key') from jsonb_array_elements(p_tickets) j)
  then
    raise exception using errcode = 'PT409',
      message = 'Una boleta ya fue utilizada o cambió. Vuelve a buscar la combinación.';
  end if;
  if v_total is null or v_total <= 0 or v_total > p_target_cents then
    raise exception using errcode = '22023', message = 'El total de boletas excede el importe solicitado.';
  end if;

  insert into public.mayoreo_invoice_reconciliations
    (id, client_key, client_name, target_cents, total_cents, reference, origin)
  values (p_id, p_client_key, v_client_name, p_target_cents, v_total, btrim(p_reference), p_origin)
  returning * into v_saved;
  for v_row in
    select c.* from public.mayoreo_invoice_available_tickets c
    where c.client_key = p_client_key
      and c.ticket_key in (select j->>'ticket_key' from jsonb_array_elements(p_tickets) j)
    order by c.ticket_key
  loop
    insert into public.mayoreo_invoice_reconciliation_tickets
      (reconciliation_id, client_key, client_name, ticket_key, ticket, sale_date,
        amount_cents, source_ids, details)
    values (p_id, v_row.client_key, v_row.client_name, v_row.ticket_key, v_row.ticket,
      v_row.sale_date, v_row.amount_cents, v_row.source_ids, v_row.details)
    returning id into v_ticket_id;
    insert into public.mayoreo_invoice_reconciliation_sources (source_id, ticket_id)
      select unnest(v_row.source_ids), v_ticket_id;
  end loop;
  return to_jsonb(v_saved);
end;
$$;
revoke all on function public.mayoreo_save_invoice_reconciliation(uuid,text,bigint,jsonb,text,text) from public, anon;
grant execute on function public.mayoreo_save_invoice_reconciliation(uuid,text,bigint,jsonb,text,text) to authenticated;

commit;
