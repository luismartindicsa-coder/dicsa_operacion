import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';

const { PGlite } = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const migration = name => readFile(new URL(`../supabase/migrations/${name}.sql`, import.meta.url), 'utf8');
const change = await migration('20261016130000_allow_sales_without_available_inventory_v2');

try {
  await db.exec('create role authenticated; create role anon;');
  for (const name of [
    '20260313113000_create_materials_v2_foundation',
    '20260313134500_add_sale_origin_type_to_inventory_v2',
    '20260317103000_prevent_negative_inventory_v2',
  ]) {
    await db.exec(await migration(name));
  }
  const materials = (await db.query(`
    select id, general_material_id from material_commercial_catalog_v2
    where allows_sale order by code limit 2
  `)).rows;
  assert.equal(materials.length, 2);
  const [first, second] = materials;
  const sale = async (weight, site = 'DICSA_CELAYA') => (await db.query(`
    insert into inventory_movements_v2
      (op_date, inventory_level, flow, commercial_material_id, origin_type, weight_kg, site, reference)
    values ('2026-10-16', 'COMMERCIAL', 'OUT', $1, 'SALE', $2, $3, 'TEST-ONLY')
    returning id
  `, [first.id, weight, site])).rows[0].id;
  const balance = async (material = first.id) => Number((await db.query(`
    select on_hand_kg from v_inventory_commercial_balance_v2 where id = $1
  `, [material])).rows[0].on_hand_kg);
  const snapshot = async () => (await db.query(
    'select to_jsonb(m) as row from inventory_movements_v2 m order by id',
  )).rows;
  const insufficient = error => error.code === 'P0001' && error.message.includes('Inventario insuficiente');

  await db.exec('set role authenticated');
  await assert.rejects(() => sale(1000), insufficient);
  await db.query(`
    insert into inventory_movements_v2
      (op_date, inventory_level, flow, general_material_id, origin_type, weight_kg)
    values ('2026-10-16', 'GENERAL', 'IN', $1, 'DIRECT_PURCHASE', 10)
  `, [first.general_material_id]);
  const before = await snapshot();
  await db.exec('reset role');
  await db.exec(change);
  assert.deepEqual(await snapshot(), before);
  await db.exec('set role authenticated');

  const firstSale = await sale(1000);
  assert.equal(await balance(), -1000);
  await db.query('update inventory_movements_v2 set weight_kg = 2500 where id = $1', [firstSale]);
  assert.equal(await balance(), -2500);
  const secondSale = await sale(500);
  assert.equal(await balance(), -3000);
  await db.query("update inventory_movements_v2 set notes = 'EDITED' where id = $1", [firstSale]);
  assert.equal(await balance(), -3000);
  console.log('PASS: sales can be inserted and edited with zero or negative stock; all kg still reduce inventory');

  await db.query(`
    insert into inventory_movements_v2
      (op_date, inventory_level, flow, commercial_material_id, origin_type, weight_kg)
    values ('2026-10-16', 'COMMERCIAL', 'IN', $1, 'TRANSFORMATION', 2000)
  `, [first.id]);
  assert.equal(await balance(), -1000);
  await db.query('update inventory_movements_v2 set commercial_material_id = $1 where id = $2', [second.id, firstSale]);
  assert.equal(await balance(), 1500);
  assert.equal(await balance(second.id), -2500);
  await db.query('delete from inventory_movements_v2 where id = $1', [secondSale]);
  assert.equal(await balance(), 2000);
  await sale(2500);
  assert.equal(await balance(), -500);
  console.log('PASS: later production, material corrections and deletions reconcile normally; partial stock does not block sales');

  const unchanged = await snapshot();
  for (const weight of [0, -1]) {
    await assert.rejects(() => sale(weight), error => error.code === '23514');
  }
  await assert.rejects(() => db.query(`
    update inventory_movements_v2 set commercial_material_id = $1 where id = $2
  `, ['00000000-0000-4000-8000-000000000099', firstSale]), error => error.code === '23503');
  await assert.rejects(() => db.query(`
    update inventory_movements_v2 set general_material_id = $1 where id = $2
  `, [first.general_material_id, firstSale]), error => error.code === '23514');
  await assert.rejects(() => db.query(`
    insert into inventory_movements_v2
      (op_date, inventory_level, flow, general_material_id, origin_type, weight_kg)
    values ('2026-10-16', 'GENERAL', 'OUT', $1, 'TRANSFORMATION', 11)
  `, [first.general_material_id]), insufficient);
  await assert.rejects(() => db.query(`
    insert into inventory_movements_v2
      (op_date, inventory_level, flow, commercial_material_id, origin_type, weight_kg)
    values ('2026-10-16', 'COMMERCIAL', 'OUT', $1, 'TRANSFORMATION', 100)
  `, [first.id]), insufficient);
  await assert.rejects(() => db.query(`
    insert into inventory_movements_v2
      (op_date, inventory_level, flow, commercial_material_id, origin_type, weight_kg)
    values ('2026-10-16', 'COMMERCIAL', 'ADJUSTMENT', $1, 'ADJUSTMENT', -100)
  `, [first.id]), insufficient);
  assert.deepEqual(await snapshot(), unchanged);
  console.log('PASS: weight/material validation and stock checks for transformations and adjustments remain enforced');

  await db.exec('reset role');
  const after = await snapshot();
  await db.exec(change);
  assert.deepEqual(await snapshot(), after);
  assert.equal((await db.query(`
    select count(*)::int as n from pg_trigger
    where tgrelid = 'public.inventory_movements_v2'::regclass
      and tgname = 'trg_validate_inventory_movement_stock_v2'
  `)).rows[0].n, 1);
  await db.exec('set role anon');
  await assert.rejects(() => sale(1000), error => error.code === '42501');
  console.log('PASS: migration is repeatable, preserves existing records and does not change access permissions');
} finally {
  await db.close();
}
