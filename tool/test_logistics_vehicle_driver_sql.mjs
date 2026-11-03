import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';

const {PGlite} = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const vehicleId = '00000000-0000-4000-8000-000000000001';
const driverId = '00000000-0000-4000-8000-000000000002';
const otherDriverId = '00000000-0000-4000-8000-000000000003';
await db.exec(`
  create role authenticated;
  create table vehicles(id uuid primary key, code text, serial_number text, type text, status text);
  create table employees(id uuid primary key, full_name text, is_driver boolean);
  insert into vehicles values('${vehicleId}', 'T-01', 'SERIE', 'camion', 'activo');
  insert into employees values('${driverId}', 'ANA LOPEZ', true), ('${otherDriverId}', 'ZULIO PEREZ', true);
`);
for (const file of [
  '20260806190000_create_logistics_driver_vehicle_profiles.sql',
  '20261013210000_add_logistics_vehicle_tank_capacity.sql',
  '20261103120000_add_logistics_vehicle_driver_assignment.sql',
]) {
  await db.exec(await readFile(new URL(`../supabase/migrations/${file}`, import.meta.url), 'utf8'));
}
const assignment = async () => (await db.query('select assigned_driver_employee_id from logistics_vehicle_profiles')).rows[0].assigned_driver_employee_id;
assert.equal(await assignment(), null);
await db.exec('set role authenticated');
await db.query('update logistics_vehicle_profiles set assigned_driver_employee_id=$1', [driverId]);
assert.equal(await assignment(), driverId);
await assert.rejects(
  () => db.query('update logistics_vehicle_profiles set assigned_driver_employee_id=$1', [vehicleId]),
  error => error.code === '23503',
);
await db.exec('reset role');
await db.query("update vehicles set code='T-01 NUEVA' where id=$1", [vehicleId]);
assert.equal(await assignment(), driverId);
await db.query("insert into logistics_vehicle_profiles(vehicle_id,vehicle_code) values($1,'T-01') on conflict(vehicle_id) do update set vehicle_code=excluded.vehicle_code", [vehicleId]);
assert.equal(await assignment(), driverId);
await db.exec('set role authenticated');
await db.query('update logistics_vehicle_profiles set assigned_driver_employee_id=$1', [otherDriverId]);
assert.equal(await assignment(), otherDriverId);
await db.exec('reset role');
await db.query('delete from employees where id=$1', [otherDriverId]);
assert.equal(await assignment(), null);
await db.exec('set role authenticated');
await db.query('update logistics_vehicle_profiles set assigned_driver_employee_id=$1', [driverId]);
await db.query('update logistics_vehicle_profiles set assigned_driver_employee_id=null');
assert.equal(await assignment(), null);
assert.equal((await db.query('select count(*) from logistics_vehicle_profiles')).rows[0].count, 1);
await db.close();
console.log('PASS: assign, replace and clear; FK validation; fleet sync preservation; employee deletion preserves the unit.');
