import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';

const {PGlite} = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const migration = name => readFile(new URL(`../supabase/migrations/${name}.sql`, import.meta.url), 'utf8');
const accountId = '00000000-0000-4000-8000-000000000001';
const userId = '00000000-0000-4000-8000-000000000002';
await db.exec(`
  create role authenticated; create role anon; create schema auth;
  create table auth.users(id uuid primary key);
  create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
  grant usage on schema auth to authenticated;
  insert into auth.users values('${userId}');
`);
const foundation = await migration('20260617160000_create_desarrollo_comercial_foundation');
await db.exec(foundation.match(/create table if not exists public\.commercial_accounts \([\s\S]*?\n\);/)[0]);
await db.exec(foundation.match(/create or replace function public\.set_commercial_updated_at\(\)[\s\S]*?\$\$;/)[0]);
await db.query('insert into commercial_accounts(id,display_name,kind) values($1,$2,$3)', [accountId, 'CLIENTE DE PRUEBA', 'customer']);
const before = (await db.query('select * from commercial_accounts')).rows;
await db.exec(await migration('20261012120000_create_commercial_quotes'));
assert.deepEqual((await db.query('select * from commercial_accounts')).rows, before);
console.log('PASS: migration preserves existing accounts');

await db.query("select set_config('request.jwt.claim.sub',$1,false)", [userId]);
await db.exec('set role authenticated');
const lines = [
  {material:'ALUMINIO', unit:'KG', quantity:100, price:12.5},
  {material:'TARIMA', unit:'PZA', quantity:10, price:45},
];
const create = (items=lines, status='enviada', until='2026-10-20', account=accountId) => db.query(
  `insert into commercial_quotes(account_id,quotation_date,valid_until,status,items,notes)
   values($1,'2026-10-12',$2,$3,$4,'Entrega en planta') returning *`,
  [account, until, status, JSON.stringify(items)],
);
const original = (await create()).rows[0];
assert.equal(original.created_by, userId);
assert.deepEqual(original.items, lines);
await db.query("update commercial_quotes set status='aceptada',notes='Confirmada' where id=$1", [original.id]);
const accepted = (await db.query('select * from commercial_quotes')).rows[0];
assert.equal(accepted.status, 'aceptada');
assert.equal(accepted.created_at.getTime(), original.created_at.getTime());
assert(accepted.updated_at >= original.updated_at);
console.log('PASS: authenticated creation and updates preserve quotation identity and items');

async function fails(action, code) {
  await assert.rejects(action, error => error.code === code);
}
for (const items of [null, [], {}, [null], [{...lines[0], material:' '}], [{...lines[0], unit:'INVALID'}], [{...lines[0], quantity:0}], [{...lines[0], quantity:'100'}], [{...lines[0], price:-1}], [{...lines[0], price:null}]]) {
  await fails(() => create(items), '23514');
}
await fails(() => create(lines, 'INVALID'), '23514');
await fails(() => create(lines, 'enviada', '2026-10-01'), '23514');
await fails(() => create(lines, 'enviada', '2026-10-20', userId), '23503');
assert.equal((await db.query('select * from commercial_quotes')).rows.length, 1);
console.log('PASS: invalid material, unit, quantity, price, validity, status and account rejected');

await db.query("update commercial_quotes set status='cancelada' where id=$1", [original.id]);
assert.equal((await db.query('select status from commercial_quotes')).rows[0].status, 'cancelada');
await fails(() => db.query('delete from commercial_quotes'), '42501');
await db.exec('reset role; set role anon');
await fails(() => db.query('select * from commercial_quotes'), '42501');
console.log('PASS: cancellation retains history; anonymous access and deletion are blocked');
await db.close();
