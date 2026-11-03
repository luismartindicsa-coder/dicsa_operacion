begin;

-- Accounting recognition overlays. Operational documents and balances are never rewritten.
create function public.accounting_statement_can_manage() returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.profiles p where p.user_id=auth.uid() and p.is_active
   and (lower(p.role::text) in ('admin','direccion','direction','direccion_general','auxiliar_direccion','ops_manager','accounting','contabilidad','finanzas')
     or lower(p.role::text) like 'direccion\_%' escape '\'
     or lower(p.role::text) like '%\_direccion' escape '\'
     or exists(select 1 from auth.users u where u.id=p.user_id and lower(u.email) in ('direccion@dicsamx.com','contabilidad@dicsamx.com','finanzas@dicsamx.com'))));
$$;
create function public.accounting_statement_can_read() returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select public.accounting_statement_can_manage() or exists(select 1 from public.profiles p
   where p.user_id=auth.uid() and p.is_active and lower(p.role::text) in ('gerencia','management','supervision','supervisor'));
$$;

create table public.accounting_statement_reviews (
 id text primary key, revision integer not null check(revision>0),
 source_signature text not null check(source_signature ~ '^[a-f0-9]{64}$'),
 account text not null check(account in ('sales','otherIncome','cost','operating','administrative','payroll','financial','depreciation','incomeTax','balance','duplicate','pending')),
 amount numeric(20,4) not null check(amount between -1000000000000 and 1000000000000),
 economic_date date, estimated boolean not null default false,
 duplicate_of text not null default '', note text not null check(btrim(note)<>''),
 updated_at timestamptz not null default now(), updated_by uuid references auth.users(id),
 check(account<>'duplicate' or (duplicate_of<>'' and duplicate_of<>id))
);
create table public.accounting_statement_closures (
 period_start date not null, period_end date not null, revision integer not null check(revision>0),
 payload jsonb not null, updated_at timestamptz not null default now(), updated_by uuid references auth.users(id),
 primary key(period_start,period_end), check(period_end between period_start and period_start+365)
);
create table public.accounting_cash_conversions (
 id text primary key, bank_id text not null references public.finanzas_bank_movements(id) on delete restrict,
 vault_id text not null references public.direction_vault_vouchers(id) on delete restrict,
 invoice_id text references public.finanzas_supplier_invoices(id) on delete restrict,
 active boolean not null default true,
 effective_date date not null, bank_amount numeric(20,4) not null, cash_amount numeric(20,4) not null,
 fee numeric(20,4) not null, note text not null check(btrim(note)<>''),
 created_at timestamptz not null default now(), created_by uuid references auth.users(id),
 check(bank_amount>0 and cash_amount>0 and fee>=0 and abs(bank_amount-cash_amount-fee)<0.005)
);
create unique index accounting_conversion_bank_active on public.accounting_cash_conversions(bank_id) where active;
create unique index accounting_conversion_vault_active on public.accounting_cash_conversions(vault_id) where active;
create unique index accounting_conversion_invoice_active on public.accounting_cash_conversions(invoice_id) where active;
create table public.accounting_statement_history (
 id bigint generated always as identity primary key, kind text not null, record_key text not null,
 payload jsonb not null, created_at timestamptz not null default now(), created_by uuid references auth.users(id)
);
alter table public.accounting_statement_reviews enable row level security;
alter table public.accounting_statement_closures enable row level security;
alter table public.accounting_cash_conversions enable row level security;
alter table public.accounting_statement_history enable row level security;
revoke all on public.accounting_statement_reviews,public.accounting_statement_closures,public.accounting_cash_conversions,public.accounting_statement_history from anon,authenticated;
grant select on public.accounting_statement_reviews,public.accounting_statement_closures,public.accounting_cash_conversions,public.accounting_statement_history to authenticated;
create policy accounting_reviews_read on public.accounting_statement_reviews for select to authenticated using(public.accounting_statement_can_read());
create policy accounting_closures_read on public.accounting_statement_closures for select to authenticated using(public.accounting_statement_can_read());
create policy accounting_conversions_read on public.accounting_cash_conversions for select to authenticated using(public.accounting_statement_can_read());
create policy accounting_history_read on public.accounting_statement_history for select to authenticated using(public.accounting_statement_can_read());

create function public.accounting_save_statement_review(p_id text,p_expected_revision integer,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare previous integer; saved public.accounting_statement_reviews; cursor_key text; visited text[];
begin
 if not public.accounting_statement_can_manage() then raise exception 'Sin permiso' using errcode='42501'; end if;
 if p_id is null or btrim(p_id)='' or length(p_id)>1000 or p_expected_revision is null or p_expected_revision<0
   or jsonb_typeof(p_payload) is distinct from 'object' or octet_length(p_payload::text)>100000
   or p_payload->>'id' is distinct from p_id or coalesce(p_payload->>'source_signature','') !~ '^[a-f0-9]{64}$'
   or jsonb_typeof(p_payload->'amount') is distinct from 'number'
   or jsonb_typeof(p_payload->'estimated') is distinct from 'boolean'
   or coalesce(btrim(p_payload->>'note'),'')='' then raise exception 'Clasificación incompleta'; end if;
 if p_id ~ '^(cost|payroll|service-coverage|fuel-coverage):[0-9]{4}-[0-9]{2}-[0-9]{2}:'
   and nullif(p_payload->>'economic_date','')::date not between split_part(p_id,':',2)::date and split_part(p_id,':',3)::date then
   raise exception 'El cálculo agregado debe permanecer dentro del periodo';
 end if;
 -- Serializes link graph edits, including concurrent attempts to form a cycle.
 perform pg_advisory_xact_lock(hashtextextended('accounting-review-graph',0));
 select revision into previous from public.accounting_statement_reviews where id=p_id for update;
 if coalesce(previous,0)<>p_expected_revision then raise exception 'La clasificación cambió en otra sesión. Vuelve a abrirla.' using errcode='PT409'; end if;
 if p_payload->>'account'='duplicate' then
   cursor_key:=p_payload->>'duplicate_of'; visited:=array[p_id];
   loop
     if cursor_key is null or cursor_key='' or cursor_key=any(visited) then raise exception 'Vínculo circular o vacío'; end if;
     visited:=array_append(visited,cursor_key);
     select duplicate_of into cursor_key from public.accounting_statement_reviews where id=cursor_key and account='duplicate';
     exit when not found;
   end loop;
 end if;
 insert into public.accounting_statement_reviews(id,revision,source_signature,account,amount,economic_date,estimated,duplicate_of,note,updated_by)
 values(p_id,p_expected_revision+1,p_payload->>'source_signature',p_payload->>'account',(p_payload->>'amount')::numeric,
   nullif(p_payload->>'economic_date','')::date,(p_payload->>'estimated')::boolean,coalesce(p_payload->>'duplicate_of',''),p_payload->>'note',auth.uid())
 on conflict(id) do update set revision=excluded.revision,source_signature=excluded.source_signature,account=excluded.account,
   amount=excluded.amount,economic_date=excluded.economic_date,estimated=excluded.estimated,duplicate_of=excluded.duplicate_of,
   note=excluded.note,updated_at=now(),updated_by=auth.uid() returning * into saved;
 insert into public.accounting_statement_history(kind,record_key,payload,created_by) values('review',p_id,to_jsonb(saved),auth.uid());
 return to_jsonb(saved);
end $$;

create function public.accounting_save_statement_closing(p_start date,p_end date,p_expected_revision integer,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare previous integer; saved public.accounting_statement_closures; item jsonb; ids text[]:='{}';
begin
 if not public.accounting_statement_can_manage() then raise exception 'Sin permiso' using errcode='42501'; end if;
 if p_start is null or p_end is null or p_end not between p_start and p_start+365 or p_expected_revision is null or p_expected_revision<0
   or jsonb_typeof(p_payload) is distinct from 'object' or octet_length(p_payload::text)>8000000
   or jsonb_typeof(p_payload->'checks') is distinct from 'array' or jsonb_typeof(p_payload->'adjustments') is distinct from 'array'
   or coalesce(p_payload->>'signature','') !~ '^([a-f0-9]{64})?$' or coalesce(btrim(p_payload->>'note'),'')='' then raise exception 'Cierre incompleto'; end if;
 if exists(select 1 from jsonb_array_elements_text(p_payload->'checks') c where c not in ('scope','sales','material','expenses','payroll','tax','accruals','cash')) then raise exception 'Control desconocido'; end if;
 if length(p_payload->>'signature')=64 and (
   not (p_payload->'checks' @> '["scope","sales","material","expenses","payroll","tax","accruals","cash"]'::jsonb)
   or jsonb_typeof(p_payload->'snapshot') is distinct from 'object'
   or p_payload->'snapshot'->>'source_signature' is distinct from p_payload->>'signature'
   or p_payload->'snapshot'->>'engine_version' is distinct from '1'
   or p_payload->'snapshot'->>'pending_count' is distinct from '0'
   or p_payload->'snapshot'->>'estimated' is distinct from 'false'
 ) then raise exception 'No puede cerrarse un resultado pendiente o sin evidencia completa'; end if;
 for item in select value from jsonb_array_elements(p_payload->'adjustments') loop
   if coalesce(item->>'id','')='' or (item->>'id')=any(ids) or coalesce(btrim(item->>'note'),'')=''
     or coalesce(item->>'account','') not in ('sales','otherIncome','cost','operating','administrative','payroll','financial','depreciation','incomeTax')
     or jsonb_typeof(item->'amount') is distinct from 'number' or (item->>'amount')::numeric not between -1000000000000 and 1000000000000
     or (item->>'date') is null or (item->>'date')::date not between p_start and p_end then raise exception 'Ajuste de cierre inválido'; end if;
   ids:=array_append(ids,item->>'id');
 end loop;
 perform pg_advisory_xact_lock(hashtextextended('accounting-closing:'||p_start::text||':'||p_end::text,0));
 select revision into previous from public.accounting_statement_closures where period_start=p_start and period_end=p_end for update;
 if coalesce(previous,0)<>p_expected_revision then raise exception 'El cierre cambió en otra sesión. Vuelve a abrirlo.' using errcode='PT409'; end if;
 insert into public.accounting_statement_closures(period_start,period_end,revision,payload,updated_by)
 values(p_start,p_end,p_expected_revision+1,p_payload,auth.uid()) on conflict(period_start,period_end) do update
 set revision=excluded.revision,payload=excluded.payload,updated_at=now(),updated_by=auth.uid() returning * into saved;
 insert into public.accounting_statement_history(kind,record_key,payload,created_by) values('closing',p_start::text||':'||p_end::text,to_jsonb(saved),auth.uid());
 return to_jsonb(saved);
end $$;

create function public.accounting_link_cash_conversion(p_bank_id text,p_vault_id text,p_bank_amount numeric,p_cash_amount numeric,p_note text) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare bank public.finanzas_bank_movements; cash public.direction_vault_vouchers; saved public.accounting_cash_conversions;
begin
 if not public.accounting_statement_can_manage() then raise exception 'Sin permiso' using errcode='42501'; end if;
 if coalesce(btrim(p_note),'')='' or p_bank_amount is null or p_cash_amount is null or p_cash_amount<=0 or p_bank_amount<p_cash_amount
   or p_bank_amount>1000000000000 then raise exception 'Importes o fundamento inválidos'; end if;
 select * into strict bank from public.finanzas_bank_movements where id=p_bank_id for share;
 select * into strict cash from public.direction_vault_vouchers where id=p_vault_id for share;
 if abs(bank.debit_amount-p_bank_amount)>.004 or coalesce(bank.credit_amount,0)<>0 or cash.voucher_type<>'deposit'
   or abs(cash.total_amount-p_cash_amount)>.004 then raise exception 'Los importes de origen cambiaron. Recarga y concilia.' using errcode='PT409'; end if;
 insert into public.accounting_cash_conversions(id,bank_id,vault_id,invoice_id,effective_date,bank_amount,cash_amount,fee,note,created_by)
 values('conversion:'||gen_random_uuid()::text,p_bank_id,p_vault_id,nullif(bank.linked_supplier_invoice_id,''),
   (bank.movement_date at time zone 'UTC')::date,p_bank_amount,p_cash_amount,p_bank_amount-p_cash_amount,p_note,auth.uid()) returning * into saved;
 insert into public.accounting_statement_history(kind,record_key,payload,created_by) values('conversion',saved.id,to_jsonb(saved),auth.uid());
 return to_jsonb(saved);
end $$;

create function public.accounting_unlink_cash_conversion(p_id text,p_note text) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare saved public.accounting_cash_conversions;
begin
 if not public.accounting_statement_can_manage() then raise exception 'Sin permiso' using errcode='42501'; end if;
 if coalesce(btrim(p_note),'')='' then raise exception 'Documenta el motivo de la corrección'; end if;
 update public.accounting_cash_conversions set active=false where id=p_id and active returning * into saved;
 if not found then raise exception 'El vínculo ya cambió. Recarga.' using errcode='PT409'; end if;
 insert into public.accounting_statement_history(kind,record_key,payload,created_by)
 values('conversion_void',p_id,jsonb_build_object('record',to_jsonb(saved),'reason',p_note),auth.uid());
end $$;

revoke all on function public.accounting_statement_can_manage(),public.accounting_statement_can_read(),
 public.accounting_save_statement_review(text,integer,jsonb),public.accounting_save_statement_closing(date,date,integer,jsonb),
 public.accounting_link_cash_conversion(text,text,numeric,numeric,text),public.accounting_unlink_cash_conversion(text,text) from public;
grant execute on function public.accounting_statement_can_manage(),public.accounting_statement_can_read(),
 public.accounting_save_statement_review(text,integer,jsonb),public.accounting_save_statement_closing(date,date,integer,jsonb),
 public.accounting_link_cash_conversion(text,text,numeric,numeric,text),public.accounting_unlink_cash_conversion(text,text) to authenticated;

-- Explicit user confirmation on 2026-11-02: invoice 160 represents cash only;
-- 39,000 kg in its purchase tickets were not physically received. Fail closed
-- if the audited amounts or relationships have changed. No CFDI is modified.
insert into public.accounting_cash_conversions(id,bank_id,vault_id,invoice_id,effective_date,bank_amount,cash_amount,fee,note)
select 'confirmed-bianca-160',b.id,v.id,b.linked_supplier_invoice_id,date '2026-10-30',156000,150000,6000,
 'Confirmado por el usuario el 02/11/2026: únicamente efectivo, sin recepción física de cartón. Factura 160: $156,000; Bóveda 18870: $150,000; costo $6,000. Comprobante fiscal pendiente de regularización con el contador.'
from public.finanzas_bank_movements b join public.direction_vault_vouchers v on v.id='dir-vault-1793388220221699'
where b.id='fin-bank-mov-1793378039242105' and b.linked_supplier_invoice_id='fin-invoice-1793378003210669'
 and b.debit_amount=156000 and coalesce(b.credit_amount,0)=0 and v.total_amount=150000 and v.voucher_type='deposit';
insert into public.accounting_statement_history(kind,record_key,payload)
select 'conversion',id,to_jsonb(c) from public.accounting_cash_conversions c where id='confirmed-bianca-160';

do $$ begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
   alter publication supabase_realtime add table public.accounting_statement_reviews,public.accounting_statement_closures,public.accounting_cash_conversions;
 end if;
end $$;
notify pgrst,'reload schema';
commit;
