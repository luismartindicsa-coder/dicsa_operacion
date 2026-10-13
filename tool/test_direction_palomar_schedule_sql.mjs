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
await db.exec(await readFile(new URL('../supabase/migrations/20260929160000_add_palomar_receipt_schedule.sql', import.meta.url), 'utf8'));
await db.exec('set role authenticated');
async function save(revision=0, cash='2026-09-23', fiscal='2026-09-25', week='2026-09-21') {
  return (await db.query('select direction_income_save_palomar_schedule($1,$2,$3,$4) as p', [week,cash,fiscal,revision])).rows[0].p;
}
const first = await save();
assert.equal(first.revision,1); assert.equal(first.cash_date,'2026-09-23');
assert.equal(first.fiscal_date,'2026-09-25'); assert.equal(first.updated_by,user);
await assert.rejects(()=>save(), e=>e.code==='PT409');
for (const args of [[1,'2026-09-20'],[1,null,'2026-09-28'],[-1],
  [1,null,null,'2026-09-22'],[null], [1,null,null,null]]) {
  await assert.rejects(()=>save(...args));
}
assert.equal((await db.query('select revision from direction_income_palomar_schedule')).rows[0].revision,1);
const cleared = await save(1,null,null);
assert.equal(cleared.cash_date,null); assert.equal(cleared.fiscal_date,null);
const partial = await save(2,null,'2026-09-27');
assert.equal(partial.revision,3); assert.equal(partial.cash_date,null);
const next = await save(0,'2026-09-28','2026-10-04','2026-09-28');
assert.equal(next.revision,1);
assert.equal((await db.query('select count(*)::int as n from direction_income_palomar_schedule')).rows[0].n,2);
await assert.rejects(()=>db.query('update direction_income_palomar_schedule set cash_date=null'),e=>e.code==='42501');
await assert.rejects(()=>db.query('delete from direction_income_palomar_schedule'),e=>e.code==='42501');
await db.query("select set_config('test.manage','no',false)");
assert.equal((await db.query('select * from direction_income_palomar_schedule')).rows.length,0);
await assert.rejects(()=>save(3),e=>e.code==='42501');
await db.query("select set_config('test.manage','',false)");
await assert.rejects(()=>save(3),e=>e.code==='42501');
await db.exec('set role anon');
await assert.rejects(()=>save(3),e=>e.code==='42501');
console.log('PASS: Palomar dates, null/partial schedules, week bounds, atomic revisions, independent weeks and role permissions');
await db.close();
