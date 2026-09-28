import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const user = '00000000-0000-4000-8000-000000000001';
await db.exec(`
  create role authenticated; create role anon; create schema auth;
  create function auth.uid() returns uuid language sql stable as
    $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
  create table public.mayoreo_sales_reports(id text primary key,ticket text,
    sale_date timestamptz default now(),client_id text,client_name_snapshot text,
    remision text default '',material_name_snapshot text default 'CARTON',
    approved_weight numeric default 1,approved_price numeric default 1,
    approved_amount numeric);
  create table public.mayoreo_accounts(id text primary key,status text);
  grant select on public.mayoreo_sales_reports,public.mayoreo_accounts to authenticated;
  select set_config('request.jwt.claim.sub','${user}',false);
  insert into mayoreo_sales_reports(id,ticket,client_id,client_name_snapshot,approved_amount)
    values('a1','B1','a','CLIENTE A',60.01),('a2','B1','a','CLIENTE A',39.99),
    ('a3','B2','a','CLIENTE A',65.43),('b1','B1','b','CLIENTE B',10),
    ('cancelled','B3','a','CLIENTE A',99),('rep_demo','DEMO','a','CLIENTE A',99),
    ('unapproved','B4','a','CLIENTE A',99),('round','B5','a','CLIENTE A',1.005);
  insert into mayoreo_accounts values('cancelled','cancelada');
  update mayoreo_sales_reports set approved_weight=null where id='unapproved';
`);
await db.exec(await readFile(new URL('../supabase/migrations/20260928120000_create_mayoreo_invoice_reconciliations.sql', import.meta.url),'utf8'));
await db.exec('set role authenticated');
const available = async(client='id:a') => (await db.query(
  'select * from mayoreo_invoice_available_tickets where client_key=$1 order by ticket_key',[client])).rows;
const proposal = rows => rows.map(({ticket_key,amount_cents,source_ids,details}) =>
  ({ticket_key,amount_cents:Number(amount_cents),source_ids,details}));
let rows = await available();
assert.equal(rows.length,3);
assert.equal(Number(rows[0].amount_cents),10000,'whole ticket includes both material rows');
assert.equal(Number(rows[2].amount_cents),101,'round once per source to integer cents');
assert.equal(rows[0].source_ids.length,2);
const p = proposal(rows.slice(0,2));
let seq=10;
const id = () => `00000000-0000-4000-8000-${String(seq++).padStart(12,'0')}`;
async function save({request=id(),client='id:a',target=16544,tickets=p,origin='app'}={}) {
  return (await db.query('select mayoreo_save_invoice_reconciliation($1,$2,$3,$4,$5,$6) as result',
    [request,client,target,JSON.stringify(tickets),'TEST',origin])).rows[0].result;
}
const request = id();
const saved = await save({request});
assert.equal(Number(saved.total_cents),16543);
assert.equal(Number(saved.missing_cents),1);
assert.equal((await available()).length,1);
assert.deepEqual(await save({request}),saved,'retries are idempotent');
await assert.rejects(()=>save({request,target:16545}),e=>e.code==='PT409');
await assert.rejects(()=>save(),e=>e.code==='PT409','used tickets cannot be reused');
assert.equal((await available('id:b')).length,1,'same ticket label on another client is independent');
// Snapshot guards: a changed amount or material is rejected, not silently saved.
const old = proposal(await available());
await db.exec("reset role; update mayoreo_sales_reports set material_name_snapshot='PET' where id='round'; set role authenticated");
await assert.rejects(()=>save({tickets:old}),e=>e.code==='PT409');
const fresh = proposal(await available());
for (const args of [
  {tickets:[]}, {tickets:[fresh[0],fresh[0]]}, {tickets:fresh,target:100},
  {tickets:fresh,target:0}, {tickets:fresh,client:'id:b'},
  {tickets:[{...fresh[0],amount_cents:1}]},
  {tickets:[{...fresh[0],source_ids:[]}]}, {tickets:fresh,origin:'bad'},
]) await assert.rejects(()=>save(args));
assert.equal((await db.query('select count(*)::int n from mayoreo_invoice_reconciliations')).rows[0].n,1,
  'failed saves must leave no header or claims');
await save({tickets:fresh,target:101,origin:'historical'});
assert.equal((await available()).length,0,'historical claims are excluded too');
await assert.rejects(()=>db.exec('delete from mayoreo_invoice_reconciliation_tickets'),e=>e.code==='42501');
await assert.rejects(()=>db.exec('update mayoreo_invoice_reconciliations set total_cents=1'),e=>e.code==='42501');
await db.exec(`reset role;
  update mayoreo_sales_reports set ticket='RENAMED', client_id='b' where id in ('a1','a2');
  delete from mayoreo_sales_reports where id='a3';
  insert into mayoreo_sales_reports(id,ticket,client_id,client_name_snapshot,approved_amount)
    values('replacement','B2','a','CLIENTE A',5);
  set role authenticated;
`);
assert.equal((await available()).length,0,'recreating a used ticket does not free it');
assert.equal((await available('id:b')).length,1,'renaming/reassigning source IDs does not free them');
assert.equal((await db.query('select count(*)::int n from mayoreo_invoice_reconciliation_sources')).rows[0].n,4);
// Upgrade with existing reservations and history; do not lose earlier usage.
await db.exec('reset role');
await db.exec(await readFile(new URL('../supabase/migrations/20260928140000_manage_mayoreo_invoice_ticket_usage.sql', import.meta.url),'utf8'));
await db.exec(`
  insert into mayoreo_sales_reports(id,ticket,client_id,client_name_snapshot,approved_amount)
    values('manage1','M1','m','MANUAL',50),('manage2','M2','m','MANUAL',60);
  set role authenticated;
`);
assert.equal((await available()).length,0,'migration preserves earlier reservations');
assert.deepEqual(await save({request}),saved,'invoice retries survive availability edits');
const catalog = async(client='id:m') => (await db.query(
  'select * from mayoreo_invoice_ticket_catalog where client_key=$1 order by ticket_key',[client])).rows;
const use = async(row,used,requestId=id()) => (await db.query(
  'select mayoreo_set_invoice_ticket_usage($1,$2,$3,$4,$5,$6) result',
  [requestId,row.client_key,row.ticket_key,used,row.claim_ids,JSON.stringify(proposal([row])[0])]
)).rows[0].result;
const initial = await catalog();
const invoiceId = id();
const invoice = await save({request:invoiceId,client:'id:m',target:5000,tickets:proposal([initial[0]])});
let m1 = (await catalog())[0];
assert.equal(m1.used,true);
assert.equal(m1.usage_origin,'reconciliation');
await assert.rejects(()=>use(initial[0],false),e=>e.code==='PT409',
  'a stale unused checkbox cannot release a newly reserved invoice');
const releaseRequest = id();
assert.equal((await use(m1,false,releaseRequest)).used,false);
await use(m1,false,releaseRequest);
assert.equal((await available('id:m')).length,2);
const released = (await db.query('select released_at,released_by,amount_cents from mayoreo_invoice_reconciliation_tickets where reconciliation_id=$1',[invoiceId])).rows[0];
assert.ok(released.released_at);
assert.equal(released.released_by,user);
assert.equal(Number(released.amount_cents),5000);
assert.deepEqual(await save({request:invoiceId,client:'id:m',target:5000,tickets:proposal([initial[0]])}),invoice,
  'releasing does not rewrite original totals or snapshots');
await save({client:'id:m',target:5000,tickets:proposal([initial[0]])});
assert.equal((await db.query("select count(*)::int n from mayoreo_invoice_reconciliation_tickets where client_key='id:m' and ticket_key='M1'")).rows[0].n,2);
await assert.rejects(()=>use(m1,false),e=>e.code==='PT409',
  'an old reservation cannot release the second reconciliation');

const m2 = initial[1];
const manualRequest = id();
const manual = await use(m2,true,manualRequest);
assert.equal(manual.used,true);
assert.equal(manual.usage_origin,'manual');
assert.deepEqual(await use(m2,true,manualRequest),manual);
await assert.rejects(()=>use(m2,false,manualRequest),e=>e.code==='PT409');
await assert.rejects(()=>save({client:'id:m',target:6000,tickets:proposal([m2])}),e=>e.code==='PT409');
await assert.rejects(()=>use(m2,true),e=>e.code==='PT409');
assert.equal((await use((await catalog())[1],false)).used,false);
await save({client:'id:m',target:6000,tickets:proposal([m2])});
assert.equal((await available('id:m')).length,0);

const cancelled = (await catalog('id:a')).find(row=>row.ticket_key==='B3');
assert.equal(cancelled.eligible,false);
await use(cancelled,true);
await use((await catalog('id:a')).find(row=>row.ticket_key==='B3'),false);
assert.equal((await available()).length,0,'manual unused cannot override cancellation/approval rules');
assert.ok((await catalog('id:a')).some(row=>row.ticket_key==='B4' && !row.eligible),
  'the ticket tab includes unapproved tickets');
await assert.rejects(()=>db.exec('update mayoreo_invoice_reconciliation_tickets set released_at=now(),released_by=auth.uid()'),e=>e.code==='42501');
await assert.rejects(()=>db.exec('delete from mayoreo_invoice_ticket_usage_changes'),e=>e.code==='42501');
assert.ok((await db.query('select count(*)::int n from mayoreo_invoice_ticket_usage_changes')).rows[0].n>=5);
await db.exec('set role anon');
await assert.rejects(()=>save(),e=>e.code==='42501');
await assert.rejects(()=>use(m2,true),e=>e.code==='42501');
await db.exec('set role authenticated');
await db.query("select set_config('request.jwt.claim.sub','',false)");
await assert.rejects(()=>save(),e=>e.code==='42501');
console.log('PASS: exact cents, atomic saves, usage editing, releases, re-use, preserved history, stale-edit protection, idempotency, upgrade and permissions');
await db.close();
