import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const {PGlite} = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite(), uid = '11111111-1111-4111-8111-111111111111';
await db.exec(`create role anon; create role authenticated; create role service_role bypassrls;
create schema auth; create table auth.users(id uuid primary key,email text);
create function auth.uid() returns uuid language sql as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create table profiles(user_id uuid primary key,role text,is_active boolean);
create table vehicles(id uuid primary key,code text);
insert into auth.users values('${uid}','logistica@example.test');
insert into profiles values('${uid}','logistics',true);
insert into vehicles values('${uid}','C1');
select set_config('request.jwt.claim.sub','${uid}',false);`);
for (const name of ['20261104235900_add_logistics_gps.sql','20261105220000_add_logistics_fuel_price_history.sql']) {
  await db.exec(await readFile(new URL('../supabase/migrations/'+name,import.meta.url),'utf8'));
}
const scalar = async (sql,args=[]) => Object.values((await db.query(sql,args)).rows[0])[0];
const save = (date,diesel,gasoline) => scalar('select set_logistics_fuel_prices($1,$2,$3)',[date,diesel,gasoline]);
await db.exec('set role authenticated');
await save('2026-01-01',25.5,24.1);
await save('2026-01-02',26,null);
await save('2026-01-01',null,24.5);
assert.equal(await scalar('select count(*) from logistics_fuel_prices'),2);
const first = (await db.query("select * from logistics_fuel_prices where effective_date='2026-01-01'")).rows[0];
assert.equal(Number(first.diesel_price_per_liter),25.5,'blank preserves saved diesel');
assert.equal(Number(first.gasoline_price_per_liter),24.5);
assert.equal(first.updated_by,uid);
assert.equal(await scalar("select to_regclass('public.logistics_gps_daily_mileage')"),null,'prices work without a mileage table');
for (const args of [
  [null,25,null],['1999-01-01',25,null],['2099-01-01',25,null],
  ['2026-01-03',null,null],['2026-01-03',0,null],['2026-01-03',-1,null],
  ['2026-01-03',25.123,null],['2026-01-03',null,1000000],['2026-01-03','NaN',null],
]) await assert.rejects(save(...args));
assert.equal(await scalar('select count(*) from logistics_fuel_prices'),2,'invalid input makes no changes');
for (const sql of [
  "insert into logistics_fuel_prices values ('2026-02-01',25,null)",
  'update logistics_fuel_prices set diesel_price_per_liter=99',
  'delete from logistics_fuel_prices',
]) await assert.rejects(db.exec(sql),e=>e.code==='42501');
await db.exec("reset role; update profiles set role='bascula'; set role authenticated");
assert.equal(await scalar('select count(*) from logistics_fuel_prices'),0);
await assert.rejects(save('2026-01-01',99,null),e=>e.code==='42501');
await db.exec("reset role; update profiles set role='logistics',is_active=false; set role authenticated");
assert.equal(await scalar('select count(*) from logistics_fuel_prices'),0);
await assert.rejects(save('2026-01-01',99,null),e=>e.code==='42501');
await db.exec('reset role; set role anon');
await assert.rejects(db.exec('select * from logistics_fuel_prices'),e=>e.code==='42501');
await assert.rejects(save('2026-01-01',99,null),e=>e.code==='42501');
await db.close();
console.log('PASS: dated prices, independent fuels, preserved blanks, invalid input and role restrictions.');
