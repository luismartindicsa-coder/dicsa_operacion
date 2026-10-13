import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const {PGlite} = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
await db.exec('create role authenticated; create table vehicles(id uuid primary key);');
const migration = async name => db.exec(await readFile(new URL(`../supabase/migrations/${name}`, import.meta.url), 'utf8'));
await migration('20260914190000_create_logistics_vehicle_mileage.sql');
await db.exec("insert into logistics_vehicle_mileage(entry_date,vehicle_label,vehicle_key,kilometers) values('2026-10-01','T-01','T1',300)");
await migration('20261013220000_add_logistics_mileage_fuel_prices.sql');
const row = async () => (await db.query('select * from logistics_vehicle_mileage')).rows[0];
assert.equal((await row()).diesel_price_per_liter, null);
assert.equal((await row()).gasoline_price_per_liter, null);
await db.exec('set role authenticated');
await db.exec('update logistics_vehicle_mileage set diesel_price_per_liter=25.50,gasoline_price_per_liter=24.10');
assert.equal(Number((await row()).diesel_price_per_liter), 25.50);
assert.equal(Number((await row()).gasoline_price_per_liter), 24.10);
for (const column of ['diesel_price_per_liter','gasoline_price_per_liter']) {
  for (const value of ['0','-1','1000000','NaN','Infinity']) {
    await assert.rejects(() => db.query(`update logistics_vehicle_mileage set ${column}=$1`,[value]), e => ['23514','22003'].includes(e.code));
  }
}
console.log('PASS: existing readings remain unspecified, both prices persist, invalid prices are rejected');
await db.exec(`insert into logistics_vehicle_mileage(entry_date,vehicle_label,vehicle_key,kilometers,diesel_price_per_liter)
  values('2026-10-01','T-01','T1',350,26)
  on conflict(entry_date,vehicle_key) do update set kilometers=excluded.kilometers,diesel_price_per_liter=excluded.diesel_price_per_liter`);
assert.equal((await db.query('select * from logistics_vehicle_mileage')).rows.length, 1);
assert.equal(Number((await row()).diesel_price_per_liter), 26);
assert.equal(Number((await row()).gasoline_price_per_liter), 24.10);
assert.equal(Number((await row()).kilometers), 350);
console.log('PASS: reimport updates the same reading and preserves the omitted fuel price');
await db.exec("insert into logistics_vehicle_mileage(entry_date,vehicle_label,vehicle_key,kilometers,diesel_price_per_liter) values('2026-10-02','T-01','T1',300,27)");
assert.equal(Number((await row()).diesel_price_per_liter), 26);
console.log('PASS: a new import date cannot change earlier captured prices');
await db.close();
