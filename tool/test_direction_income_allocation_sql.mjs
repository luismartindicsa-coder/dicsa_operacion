import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const user = '00000000-0000-4000-8000-000000000001';
const shipment = '00000000-0000-4000-8000-000000000002';
const other = '00000000-0000-4000-8000-000000000003';
await db.exec(`
  create role authenticated; create role anon; create schema auth;
  create table auth.users(id uuid primary key);
  insert into auth.users values('${user}');
  create table public.direction_shipment_plans(id uuid primary key);
  insert into public.direction_shipment_plans values('${shipment}'),('${other}');
  create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
  create function public.direction_program_can_manage() returns boolean language sql stable as $$select current_setting('test.manage',true)='yes'$$;
  select set_config('request.jwt.claim.sub','${user}',false);
  select set_config('test.manage','yes',false);
`);
await db.exec(await readFile(new URL('../supabase/migrations/20260921230000_create_direction_income_allocations.sql', import.meta.url), 'utf8'));
await db.exec('set role authenticated');
async function save({id=shipment, key='snapshot', total=10001, cash=3000, fiscal=7001, revision=0}={}) {
  return (await db.query('select direction_income_save_allocation($1,$2,$3,$4,$5,$6) as a', [id,key,total,cash,fiscal,revision])).rows[0].a;
}
let saved = await save();
assert.equal(saved.revision,1); assert.equal(saved.cash_cents,3000); assert.equal(saved.updated_by,user);
await assert.rejects(()=>save(),e=>e.code==='PT409');
for (const invalid of [
  {cash:-1,fiscal:10002}, {cash:3000.5,fiscal:7000.5}, {total:0,cash:0,fiscal:0},
  {cash:3000,fiscal:7000}, {cash:null}, {fiscal:null}, {total:null}, {revision:null},
  {total:100000000000001,cash:0,fiscal:100000000000001}, {key:''}, {key:'x'.repeat(4001)},
  {id:user}, {id:null},
]) await assert.rejects(()=>save({revision:1,...invalid}));
assert.equal((await db.query('select revision from direction_income_allocations')).rows[0].revision,1);
saved = await save({cash:0,fiscal:10001,revision:1});
assert.equal(saved.revision,2); assert.equal(saved.cash_cents,0);
saved = await save({key:'new-snapshot',total:5000,cash:5000,fiscal:0,revision:2});
assert.equal(saved.revision,3); assert.equal(saved.source_key,'new-snapshot');
assert.equal((await save({id:other})).revision,1);
await assert.rejects(()=>db.exec('update direction_income_allocations set cash_cents=0'),e=>e.code==='42501');
await assert.rejects(()=>db.exec('delete from direction_income_allocations'),e=>e.code==='42501');
await db.query("select set_config('test.manage','no',false)");
assert.equal((await db.query('select * from direction_income_allocations')).rows.length,0);
await assert.rejects(()=>save({revision:3}),e=>e.code==='42501');
await db.exec('set role anon');
await assert.rejects(()=>save(),e=>e.code==='42501');
await db.exec('reset role');
await db.query('delete from direction_shipment_plans where id=$1',[shipment]);
assert.equal((await db.query('select count(*)::int as n from direction_income_allocations')).rows[0].n,1);
console.log('PASS: exact cents, atomic saves, revisions, independent shipments, permissions and cascade');
await db.close();
