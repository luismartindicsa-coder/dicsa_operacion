import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const {PGlite} = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const uid = '11111111-1111-4111-8111-111111111111';
await db.exec(`
  create role anon;
  create role authenticated;
  create role service_role bypassrls;
  create schema auth;
  create table auth.users(id uuid primary key,email text);
  create function auth.uid() returns uuid language sql as $$select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid$$;
  create table public.profiles(user_id uuid primary key,role text,is_active boolean);
  create table public.vehicles(id uuid primary key,code text);
  insert into auth.users values('${uid}','logistica@example.test');
  insert into public.profiles values('${uid}','logistics',true);
  insert into public.vehicles values('${uid}','C1');
  select set_config('request.jwt.claim.sub','${uid}',false);
`);
await db.exec(await readFile(new URL('../supabase/migrations/20261104235900_add_logistics_gps.sql',import.meta.url),'utf8'));
const scalar = async sql => Object.values((await db.query(sql)).rows[0])[0];
assert.equal(await scalar('select count(*) from logistics_gps_units'),15);
assert.equal(await scalar("select vehicle_id::text from logistics_gps_units where provider_unit_id='25592942'"),uid);
await db.exec('set role authenticated');
assert.equal(await scalar('select count(*) from logistics_gps_units'),15);
await assert.rejects(db.exec("update logistics_gps_units set provider_name='tampered'"),e=>e.code==='42501');
await assert.rejects(db.exec('select claim_logistics_gps_sync()'),e=>e.code==='42501');
await db.exec('reset role');
for (const [role,active,email,expected] of [
  ['finanzas',true,'finance@example.test',0], ['logistics',false,'logistica@example.test',0],
  ['bascula',true,'direccion@dicsamx.com',0], ['direccion',true,'direction@example.test',15],
  ['services',true,'logistica@example.test',15],
]) {
  await db.query('update profiles set role=$1,is_active=$2',[role,active]);
  await db.query('update auth.users set email=$1',[email]);
  await db.exec('set role authenticated');
  assert.equal(await scalar('select count(*) from logistics_gps_units'),expected);
  await db.exec('reset role');
}
await db.exec('set role anon');
await assert.rejects(db.exec('select * from logistics_gps_units'),e=>e.code==='42501');
await db.exec('reset role; set role service_role');
const run=await scalar('select claim_logistics_gps_sync()');
assert.ok(run);
assert.equal(await scalar('select claim_logistics_gps_sync()'),null);
const snapshot=[{provider_unit_id:'25592942',provider_name:'C-001 NEW',latitude:20,longitude:-100,position_at:'2026-11-04T20:00:00Z'}];
const finish = (id,units,error=null) => db.query('select complete_logistics_gps_sync($1,$2::jsonb,$3)',[id,JSON.stringify(units),error]);
assert.equal((await finish(uid,snapshot)).rows[0].complete_logistics_gps_sync,false);
await finish(run,snapshot);
assert.equal(await scalar('select count(*) from logistics_gps_units where provider_visible'),1);
assert.equal(await scalar("select vehicle_id::text from logistics_gps_units where provider_unit_id='25592942'"),uid);
await db.exec("update logistics_gps_sync_state set last_attempt_at=now()-interval '2 minutes'");
const run2=await scalar('select claim_logistics_gps_sync()');
await finish(run2,[],'authorization');
assert.equal(await scalar("select latitude from logistics_gps_units where provider_unit_id='25592942'"),20);
assert.equal(await scalar('select status from logistics_gps_sync_state'),'error');
await db.exec("update logistics_gps_sync_state set last_attempt_at=now()-interval '2 minutes'");
const run3=await scalar('select claim_logistics_gps_sync()');
await assert.rejects(finish(run3,[...snapshot,...snapshot]));
assert.equal(await scalar("select latitude from logistics_gps_units where provider_unit_id='25592942'"),20);
await finish(run3,[]);
assert.equal(await scalar('select count(*) from logistics_gps_units where latitude is not null'),0);
assert.equal(await scalar('select count(*) from logistics_gps_units where vehicle_id is not null'),1);
await db.close();
console.log('PASS: GPS role isolation, protected writes, explicit mapping, leases, atomic snapshots, failure retention and revoked visibility.');
