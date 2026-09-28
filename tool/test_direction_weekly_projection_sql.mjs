import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const user = '00000000-0000-4000-8000-000000000001';
await db.exec(`
  create role authenticated; create role anon; create schema auth;
  create table auth.users(id uuid primary key);
  insert into auth.users values('${user}');
  create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
  create function public.direction_program_can_manage() returns boolean language sql stable as $$select current_setting('test.manage',true)='yes'$$;
  select set_config('request.jwt.claim.sub','${user}',false);
  select set_config('test.manage','yes',false);
`);
await db.exec(await readFile(new URL('../supabase/migrations/20260921210000_create_direction_weekly_projections.sql', import.meta.url), 'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20260921220000_auto_classify_direction_payments.sql', import.meta.url), 'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20260922010000_add_menudeo_weekly_projection.sql', import.meta.url), 'utf8'));
await db.exec('set role authenticated');
const row = {id:'invoice:1',source:'invoice',payee:'Proveedor',reference:'F-1',account:'DICSA|CELAYA',date:'2026-09-25',amount:12345,available:20000,included:true,payment_type:'EFECTIVO',notes:'Programación',selection_automatic:false};
async function save(revision, rows=[row], cash=100000, fiscal=200000, week='2026-09-21') {
  return (await db.query('select direction_save_weekly_projection($1,$2,$3,$4,$5,$6) as p', [week,revision,JSON.stringify(rows),cash,fiscal,true])).rows[0].p;
}
let plan = await save(0);
assert.equal(plan.revision,1); assert.equal(plan.opening_cash,100000);
assert.equal(plan.updated_by,user); assert.deepEqual(plan.payments,[row]);
await assert.rejects(()=>save(0), e=>e.code==='PT409');
plan = await save(1,[{...row, amount:5000,payment_type:'FISCAL',date:'2026-09-23'}],-1000,0);
assert.equal(plan.revision,2); assert.equal(plan.opening_cash,-1000);
assert.equal(plan.payments[0].amount,5000);
for (const invalid of [
  {...row, amount:-1}, {...row, amount:0}, {...row, amount:0.5}, {...row, amount:20001},
  {...row, amount:'123'}, {...row, date:'2026-09-28'}, {...row, payment_type:'BANCO'},
  {...row, included:null}, {...row, payee:''}, {...row, notes:null}, {...row, source:null},
  {...row, payment_type_automatic:'yes'},
]) await assert.rejects(()=>save(2,[invalid]));
await assert.rejects(()=>save(2,[row,row]));
await assert.rejects(()=>save(2,[],100,100,'2026-09-22'));
assert.equal((await db.query('select revision from direction_weekly_projections')).rows[0].revision,2,'rejected writes are atomic');
await assert.rejects(()=>db.query("update direction_weekly_projections set payments='[]'"),e=>e.code==='42501');
await assert.rejects(()=>db.query('delete from direction_weekly_projections'),e=>e.code==='42501');
await db.query("select set_config('test.manage','no',false)");
assert.equal((await db.query('select * from direction_weekly_projections')).rows.length,0);
await assert.rejects(()=>save(2),e=>e.code==='42501');
await db.exec('set role anon');
await assert.rejects(()=>save(2),e=>e.code==='42501');
await db.exec('set role authenticated');
await db.query("select set_config('test.manage','yes',false)");
plan = await save(2,[],null,null);
assert.equal(plan.revision,3); assert.equal(plan.opening_cash,null);
const next = await save(0,[{...row,date:'2026-09-28'}],0,0,'2026-09-28');
assert.equal(next.revision,1); assert.equal(next.opening_cash,0);
const ticket = await save(1,[{...row,id:'ticket:1',source:'ticket',payment_type:'EFECTIVO',payment_type_automatic:true,date:'2026-09-28'}],0,0,'2026-09-28');
assert.equal(ticket.payments[0].payment_type_automatic,true);
// Optional removal metadata uses the existing JSON contract. No Finance row is deleted.
const removed = {...ticket.payments[0], removed:true, included:false};
const removal = await save(2,[removed],0,0,'2026-09-28');
assert.deepEqual(removal.payments,[removed]);
assert.equal((await db.query("select payments from direction_weekly_projections where week_start='2026-09-28'")).rows[0].payments[0].removed,true);
await assert.rejects(()=>save(2,[],0,0,'2026-09-28'), e=>e.code==='PT409');
assert.equal((await db.query("select payments from direction_weekly_projections where week_start='2026-09-28'")).rows[0].payments.length,1);
assert.equal((await db.query('select count(*)::int as n from direction_weekly_projections')).rows[0].n,2);
console.log('PASS: atomic weekly projection, cents/date validation, revisions, persistent removal, independent weeks and role permissions');
async function menudeo(settings, revision=3) {
  return (await db.query('select direction_save_weekly_projection($1,$2,$3,$4,$5,$6,$7) as p',
    ['2026-09-21',revision,'[]',100,200,true,JSON.stringify(settings)])).rows[0].p;
}
for (const settings of [[],{}, {included:null}, {included:'yes'}, {included:true,purchases:-1},
  {included:true,purchases:1.5}, {included:true,expenses:'100'}, {included:true,expenses:100000000000001},
  {included:true,unknown:1}]) await assert.rejects(()=>menudeo(settings));
const forecast = await menudeo({included:true,purchases:12345,expenses:0});
assert.deepEqual(forecast.menudeo_settings,{included:true,purchases:12345,expenses:0});
await assert.rejects(()=>menudeo({included:false}),e=>e.code==='PT409');
const legacy = await save(4,[]);
assert.deepEqual(legacy.menudeo_settings,forecast.menudeo_settings,'legacy clients preserve Menudeo settings');
const automatic = await menudeo({included:false,purchases:null,expenses:null},5);
assert.equal(automatic.revision,6); assert.equal(automatic.menudeo_settings.purchases,null);
await db.query("select set_config('test.manage','no',false)");
await assert.rejects(()=>menudeo({included:true},6),e=>e.code==='42501');
console.log('PASS: Menudeo weekly settings, automatic/manual/zero, validation, optimistic locking, legacy preservation and permissions');
await db.close();
