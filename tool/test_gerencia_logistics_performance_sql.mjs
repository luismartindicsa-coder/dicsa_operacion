import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const {PGlite} = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const uid = '11111111-1111-4111-8111-111111111111';
await db.exec(`
  create role anon; create role authenticated; create role service_role bypassrls;
  create schema auth; create table auth.users(id uuid primary key,email text);
  create function auth.uid() returns uuid language sql as
    $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
  create table profiles(user_id uuid primary key,role text,is_active boolean);
  create table vehicles(id uuid primary key,code text);
  insert into auth.users values('${uid}','gerencia@example.test');
  insert into profiles values('${uid}','gerencia',true);
  insert into vehicles values('${uid}','C1');
  select set_config('request.jwt.claim.sub','${uid}',false);
  create table logistics_diesel_consumption(id uuid primary key,vehicle_id uuid,entry_date date,liters_requested numeric);
  create table logistics_gasoline_control(id uuid primary key,vehicle_id uuid,entry_date date,liters_loaded numeric);
`);
for (const name of [
  '20261104235900_add_logistics_gps.sql',
  '20261105160000_add_epcom_daily_mileage.sql',
  '20261105210000_add_fuel_load_followup.sql',
  '20261105220000_add_logistics_fuel_price_history.sql',
  '20261111190000_grant_gerencia_logistics_performance_read.sql',
]) await db.exec(await readFile(new URL('../supabase/migrations/' + name, import.meta.url), 'utf8'));
await db.exec(`
  insert into logistics_gps_daily_mileage(provider_unit_id,entry_date,vehicle_id,vehicle_label,status,kilometers)
    values('25592942','2026-11-01','${uid}','C1','ok',150);
  insert into logistics_gps_load_mileage(vehicle_id,provider_unit_id,load_date,load_snapshot,window_kind,from_at)
    values('${uid}','25592942','2026-11-01','[]','after_load_day','2026-11-02T06:00:00Z');
  insert into logistics_fuel_prices(effective_date,diesel_price_per_liter) values('2026-11-01',26);
`);
const scalar = async (sql, args = []) => Object.values((await db.query(sql, args)).rows[0])[0];
const readTables = ['logistics_gps_daily_mileage', 'logistics_gps_load_mileage', 'logistics_fuel_prices'];
async function profile(role, email = 'gerencia@example.test', active = true) {
  await db.exec('reset role');
  await db.query('update profiles set role=$1,is_active=$2', [role, active]);
  await db.query('update auth.users set email=$1', [email]);
  await db.exec('set role authenticated');
}
for (const role of ['gerencia', 'management', 'gerencia_general', 'gerencia_logistica', 'auxiliar_gerencia', 'management_ops', 'ops_management', 'Geréncia General']) {
  await profile(role);
  assert.equal(await scalar('select can_view_logistics_performance()'), true, role);
  assert.equal(await scalar('select can_view_logistics_gps()'), false, role);
  for (const table of readTables) assert.equal(await scalar(`select count(*) from ${table}`), 1, role + ': ' + table);
  assert.equal(await scalar('select count(*) from logistics_gps_units'), 0, 'no live GPS access');
  assert.equal((await db.query('update logistics_gps_daily_mileage set diesel_price_per_liter=99 returning *')).rows.length, 0);
  await assert.rejects(db.exec("select set_logistics_fuel_prices('2026-11-01',99,null)"), e => e.code === '42501');
  await assert.rejects(db.exec("select set_logistics_fuel_load_time('diesel',null,null,null,null,null)"), e => e.code === '42501');
  await assert.rejects(db.exec('update logistics_gps_load_mileage set kilometers=99'), e => e.code === '42501');
}
await profile('employee', 'GERENCIA@DICSAMX.COM');
assert.equal(await scalar('select can_view_logistics_performance()'), true, 'management account fallback');
for (const [role, email, active] of [
  ['bascula', 'gerencia@dicsamx.com', true],
  ['gerencia', 'bascula@dicsamx.com', true],
  ['gerencia', 'gerencia@dicsamx.com', false],
  ['employee', 'employee@example.test', true],
]) {
  await profile(role, email, active);
  assert.equal(await scalar('select can_view_logistics_performance()'), false);
  for (const table of readTables) assert.equal(await scalar(`select count(*) from ${table}`), 0);
}
for (const role of ['logistics', 'logistica', 'services', 'direccion', 'direction']) {
  await profile(role, 'existing@example.test');
  for (const table of readTables) assert.equal(await scalar(`select count(*) from ${table}`), 1);
  await db.exec("select set_logistics_fuel_prices('2026-11-01',27,null)");
  assert.equal((await db.query('update logistics_gps_daily_mileage set diesel_price_per_liter=28 returning *')).rows.length, 1);
}
await db.exec('reset role; set role anon');
await assert.rejects(db.exec('select can_view_logistics_performance()'), e => e.code === '42501');
for (const table of readTables) await assert.rejects(db.exec(`select * from ${table}`), e => e.code === '42501');
await db.close();
console.log('PASS: Gerencia reads performance, cannot edit prices/load times or view GPS; existing Logistics/Direction access preserved.');
