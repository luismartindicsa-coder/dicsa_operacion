import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
const {PGlite} = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const user = randomUUID(), denied = randomUUID();
await db.exec(`
create role authenticated; create role anon; create schema auth;
create table auth.users(id uuid primary key,email text);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
grant usage on schema auth to authenticated;
create table profiles(user_id uuid,role text,is_active boolean);
create table hr_employee_profiles(id text primary key,nombre text,empresa text,employment_status text,termination_date date);
create table hr_payroll_period_closures(id uuid primary key default gen_random_uuid(),period_label text,status text);
create table hr_attendance_operational_periods(period_label text,end_date date);
create table hr_prenomina_draft_rows(
  id uuid primary key default gen_random_uuid(),period_label text,employee_id text,employee_name text,draft_status text,
  source_snapshot jsonb,loan_deduction_amount numeric,cash_salary_amount numeric,cash_vacation_amount numeric,
  transport_support_amount numeric,holiday_amount numeric,overtime_monetized_amount numeric,manual_bonus_amount numeric,
  manual_adjustment_amount numeric,cash_isr_amount numeric,cash_infonavit_deduction_amount numeric,
  cash_fonacot_deduction_amount numeric,cash_absence_deduction_amount numeric);
insert into auth.users values('${user}','rh@dicsamx.com'),('${denied}','other@example.test');
insert into profiles values('${user}','rh',true),('${denied}','operacion',true);
insert into hr_employee_profiles values('rh-test','QA RH','DICSA','activo',null);
grant select,insert,update on hr_prenomina_draft_rows,hr_payroll_period_closures to authenticated;
`);
for (const file of ['20260910010000_create_hr_loan_fund.sql','20260910100000_add_hr_loan_payroll_channels.sql',
  '20260910110000_support_hr_loan_opening_balances.sql','20261012180000_edit_hr_loans.sql']) {
  await db.exec(await readFile(new URL(`../supabase/migrations/${file}`,import.meta.url),'utf8'));
}
await db.query("select set_config('request.jwt.claim.sub',$1,false)",[user]);
await db.exec('set role authenticated');
const query = (sql,params=[]) => db.query(sql,params);
async function owner(sql,params=[]) {
  await db.exec('reset role');
  try { return await query(sql,params); } finally { await db.exec('set role authenticated'); }
}
const row = async id => (await query('select * from hr_employee_loans where id=$1',[id])).rows[0];
const ledger = async id => (await query('select * from hr_loan_payments where loan_id=$1 order by paid_on,id',[id])).rows;
const due = async (id,date) => +(await owner('select hr_loan_due($1,$2) amount',[id,date])).rows[0].amount;
const available = async () => +(await owner('select hr_loan_available() amount')).rows[0].amount;
const paid = async id => { const l = await row(id); return +l.opening_paid_amount + +l.paid_adjustment_amount + (await ledger(id)).reduce((s,p)=>s + +p.amount,0); };
const create = async (method='efectivo',first='2026-09-04') => (await query(
  "select hr_loan_create($1,'rh-test',1200,4,$2,'semanal','2026-09-01',$3,'','flujo',300) id",[randomUUID(),method,first])).rows[0].id;
const cash = async (id,amount,date='2026-09-05',request=randomUUID()) => query(
  "select hr_loan_record_cash_payment($1,$2,$3,$4,'Pago QA')",[request,id,amount,date]);
const editArgs = async (id,changes={}) => ({request:randomUUID(),id,revision:(await row(id)).revision,
  expectedPaid:await paid(id),principal:1200,paid:await paid(id),date:'2026-09-01',first:'2026-09-04',notes:'Corrección QA',...changes});
const edit = p => query('select hr_loan_edit($1,$2,$3,$4,$5,$6,$7,$8,$9)',
  [p.request,p.id,p.revision,p.expectedPaid,p.principal,p.paid,p.date,p.first,p.notes]);
const rejects = (action,pattern) => assert.rejects(action,e=>pattern instanceof RegExp ? pattern.test(e.message) : e.code===pattern);

const id = await create();
const request = randomUUID();
await cash(id,400,'2026-09-05',request);
await cash(id,400,'2026-09-05',request);
assert.equal((await ledger(id)).length,1);
assert.equal(+(await ledger(id))[0].principal_only_amount,100);
assert.equal(await due(id,'2026-09-10'),0);
assert.equal(await due(id,'2026-09-17'),300);
await cash(id,200,'2026-09-06'); // Same period: the entire extra retires final terms.
assert.equal(+(await ledger(id))[1].principal_only_amount,200);
assert.equal(await due(id,'2026-09-17'),300);
await cash(id,300,'2026-09-11');
assert.equal(await due(id,'2026-09-24'),300);
await cash(id,300,'2026-09-18');
assert.equal(await due(id,'2026-10-30'),0);
assert.equal(await available(),15000);
await rejects(()=>cash(id,1),'P0001');
console.log('PASS: larger/repeated payments retain the next quota, retire early, never overpay, and retries are idempotent');

const corrected = await create();
await cash(corrected,300);
const before = await ledger(corrected);
const parameters = await editArgs(corrected,{principal:1500,paid:500,date:'2026-08-29'});
await edit(parameters); await edit(parameters);
assert.equal(await paid(corrected),500);
assert.equal((await row(corrected)).installment_count,5);
assert.equal(+(await row(corrected)).installment_amount,300);
assert.equal(await due(corrected,'2026-09-17'),300);
assert.equal(await available(),14000);
assert.deepEqual(await ledger(corrected),before);
assert.equal((await query('select * from hr_loan_changes where loan_id=$1',[corrected])).rows.length,1);
await rejects(()=>edit({...parameters,notes:'Different retry'}),/otros datos/);
await rejects(()=>edit({...parameters,request:randomUUID()}),/cambiaron/);
const stale = await editArgs(corrected,{principal:1500});
await cash(corrected,50,'2026-09-06');
await rejects(()=>edit(stale),/cambiaron/);
await rejects(async()=>edit(await editArgs(corrected,{principal:20000})),/fondo/);
await rejects(async()=>edit(await editArgs(corrected,{paid:1300})),/aportado/);
await rejects(async()=>edit(await editArgs(corrected,{date:'2026-09-06'})),/fechas/);
await rejects(async()=>edit(await editArgs(corrected,{date:'2099-01-01'})),/fechas/);
await rejects(async()=>edit(await editArgs(corrected,{principal:1000.001})),/decimales/);
await edit(await editArgs(corrected,{principal:1500,paid:1500}));
assert.equal(await due(corrected,'2026-12-01'),0);
await edit(await editArgs(corrected,{principal:1500,paid:100})); // Reopen via an audited correction.
assert.equal(await paid(corrected),100);
assert.equal(await due(corrected,'2026-12-01'),1400);
assert.deepEqual((await ledger(corrected)).slice(0,1),before);
await edit(await editArgs(corrected,{principal:1500,paid:1500}));
console.log('PASS: dates, principal and paid corrections reconcile the fund, preserve receipts, audit/retry, reject stale state and validate amounts');

// Imported balances retain their provenance and operating cutover.
const historical = await create();
await owner(`update hr_employee_loans set principal=2500,installment_count=9,opening_paid_amount=600,
  opening_paid_installments=2,issued_on='2026-09-10',first_due_on='2026-09-10',
  opening_snapshot='{"requested_on":"2026-08-17","as_of":"2026-09-10","source":"QA"}' where id=$1`,[historical]);
await edit(await editArgs(historical,{principal:2800,paid:750,date:'2026-08-18',first:'2026-09-10'}));
const migrated = await row(historical);
assert.equal(migrated.opening_snapshot.requested_on,'2026-08-18');
assert.equal(migrated.opening_snapshot.source,'QA');
assert.equal(+migrated.opening_paid_amount,600);
assert.equal(migrated.installment_count,10);
assert.equal(await due(historical,'2026-09-10'),300);
await rejects(async()=>edit(await editArgs(historical,{principal:500,paid:400,date:'2026-08-18',first:'2026-09-10'})),/históricos/);
console.log('PASS: imported balances retain dates, receipts and provenance while allowing partial paid corrections');

const payroll = await create('nomina');
async function draft(period,end,amount,channel='flujo') {
  await owner('insert into hr_attendance_operational_periods values($1,$2)',[period,end]);
  const allocations = amount ? [{loan_id:payroll,amount,channel}] : [];
  const snapshot={loan_fund:{version:2,end_date:end,requested_amount:amount,amount:channel==='flujo'?amount:0,
    fiscal_amount:channel==='fiscal'?amount:0,dues:allocations,allocations},contpaq_official_net:1700};
  await query(`insert into hr_prenomina_draft_rows(period_label,employee_id,employee_name,draft_status,source_snapshot,
    loan_deduction_amount,cash_salary_amount) values($1,'rh-test','QA RH','publicado',$2,$3,1000)`,
    [period,snapshot,channel==='flujo'?amount:0]);
}
const close = period => query("insert into hr_payroll_period_closures(period_label,status) values($1,'cerrado')",[period]);
await draft('P1','2026-09-10',300);
await cash(payroll,400);
await rejects(()=>close('P1'),/cambiaron/);
assert.equal((await query("select * from hr_payroll_period_closures where period_label='P1'")).rows.length,0);
await draft('P2','2026-09-17',300);
await close('P2');
assert.equal(await paid(payroll),700);
const closedReceipts = await ledger(payroll);
const closedDraft = (await query("select * from hr_prenomina_draft_rows where period_label='P2'")).rows;
await rejects(async()=>edit(await editArgs(payroll,{paid:200})),/nóminas cerradas/);
await edit(await editArgs(payroll,{principal:900,paid:700,notes:'Corrección posterior al cierre'}));
assert.deepEqual(await ledger(payroll),closedReceipts);
assert.deepEqual((await query("select * from hr_prenomina_draft_rows where period_label='P2'")).rows,closedDraft);
await query("select hr_loan_set_payroll_channel($1,$2,'flujo','fiscal','QA')",[randomUUID(),payroll]);
assert.equal(await due(payroll,'2026-09-24'),200);
await draft('P3','2026-09-24',200,'fiscal');
await close('P3');
assert.equal(await paid(payroll),900);
assert.equal((await ledger(payroll)).at(-1).payroll_channel,'fiscal');
assert.equal(await due(payroll,'2026-10-01'),0);
await query("update hr_payroll_period_closures set status='cerrado' where period_label='P3'");
assert.equal(await paid(payroll),900);
await rejects(()=>query("select hr_loan_set_payroll_channel($1,$2,'fiscal','flujo','QA')",[randomUUID(),payroll]),/liquidado/);
console.log('PASS: stale payroll closure rolls back, both collection channels respect the final balance, and closed receipts remain intact');

await rejects(()=>query('update hr_employee_loans set principal=1'),'42501');
await rejects(()=>query('delete from hr_loan_changes'),'42501');
await rejects(()=>query('update hr_loan_payments set amount=1'),'42501');
await query("select set_config('request.jwt.claim.sub',$1,false)",[denied]);
assert.equal((await query('select * from hr_loan_changes')).rows.length,0);
await rejects(()=>edit(parameters),'42501');
await db.exec('reset role; set role anon');
await rejects(()=>edit(parameters),'42501');
console.log('PASS: RH permissions, anonymous denial and immutable ledger/audit enforced by PostgreSQL');
await db.close();
