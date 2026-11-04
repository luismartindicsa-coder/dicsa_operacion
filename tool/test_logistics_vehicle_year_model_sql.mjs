import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';

const {PGlite} = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const vehicleId = '00000000-0000-4000-8000-000000000001';
await db.exec(`
  create role authenticated;
  create table vehicles(id uuid primary key, code text, serial_number text, type text, status text);
  create table employees(id uuid primary key, full_name text, is_driver boolean);
  insert into vehicles values('${vehicleId}', 'T-01', 'SERIE', 'camion', 'activo');
`);
for (const file of [
  '20260806190000_create_logistics_driver_vehicle_profiles.sql',
  '20261013210000_add_logistics_vehicle_tank_capacity.sql',
]) {
  await db.exec(await readFile(new URL(`../supabase/migrations/${file}`, import.meta.url), 'utf8'));
}
await db.exec("update logistics_vehicle_profiles set notes='Conservar', tank_capacity_liters=400");
await db.exec(await readFile(new URL('../supabase/migrations/20261103150000_add_logistics_vehicle_year_model.sql', import.meta.url), 'utf8'));
const read = async () => (await db.query('select model_year,model_name,notes,tank_capacity_liters from logistics_vehicle_profiles')).rows[0];
assert.deepEqual(await read(), {model_year: null, model_name: null, notes: 'Conservar', tank_capacity_liters: '400.00'});
await db.exec('set role authenticated');
for (const year of [1900, 2020, 2100]) {
  await db.query('update logistics_vehicle_profiles set model_year=$1,model_name=$2', [year, 'Kenworth T680']);
  assert.equal((await read()).model_year, year);
}
for (const year of [1899, 2101, 0, -1]) {
  await assert.rejects(() => db.query('update logistics_vehicle_profiles set model_year=$1', [year]), error => error.code === '23514');
}
await db.exec('reset role');
await db.exec("update vehicles set code='T-01 NUEVA',serial_number='NUEVA SERIE'");
assert.equal((await read()).model_year, 2100);
assert.equal((await read()).model_name, 'Kenworth T680');
await db.exec('set role authenticated');
await db.exec('update logistics_vehicle_profiles set model_year=null,model_name=null');
assert.deepEqual(await read(), {model_year: null, model_name: null, notes: 'Conservar', tank_capacity_liters: '400.00'});
await db.close();
console.log('PASS: optional year/model, year limits, authenticated saves, fleet sync and existing data preserved.');
