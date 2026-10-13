import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const {PGlite} = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const id = '00000000-0000-4000-8000-000000000001';
await db.exec(`
  create role authenticated;
  create table vehicles(id uuid primary key,code text,serial_number text,type text,status text);
  create table employees(id uuid primary key,full_name text,is_driver boolean);
  insert into vehicles values('${id}','T-01','SERIE','camion','activo');
`);
for (const file of ['20260806190000_create_logistics_driver_vehicle_profiles.sql','20261013210000_add_logistics_vehicle_tank_capacity.sql']) {
  await db.exec(await readFile(new URL(`../supabase/migrations/${file}`, import.meta.url), 'utf8'));
}
const capacity = async () => (await db.query('select tank_capacity_liters from logistics_vehicle_profiles')).rows[0].tank_capacity_liters;
assert.equal(await capacity(), null);
await db.exec('set role authenticated');
await db.query('update logistics_vehicle_profiles set tank_capacity_liters=$1',[450.75]);
assert.equal(Number(await capacity()), 450.75);
for (const value of ['0','-1','1000000','NaN','Infinity']) {
  await assert.rejects(() => db.query('update logistics_vehicle_profiles set tank_capacity_liters=$1',[value]), e => ['23514','22003'].includes(e.code));
}
console.log('PASS: existing units stay unspecified, decimal liters persist, invalid capacities are rejected');
await db.exec('reset role');
await db.query("update vehicles set code='T-01 NUEVA' where id=$1",[id]);
assert.equal(Number(await capacity()),450.75);
await db.query(`insert into logistics_vehicle_profiles(vehicle_id,vehicle_code) values($1,'T-01') on conflict(vehicle_id) do update set vehicle_code=excluded.vehicle_code`,[id]);
assert.equal(Number(await capacity()),450.75);
console.log('PASS: fleet synchronization and legacy writes preserve tank capacity');
await db.exec('set role authenticated');
await db.query('update logistics_vehicle_profiles set tank_capacity_liters=null');
assert.equal(await capacity(),null);
await db.close();
console.log('PASS: capacity can be cleared without deleting the unit');
