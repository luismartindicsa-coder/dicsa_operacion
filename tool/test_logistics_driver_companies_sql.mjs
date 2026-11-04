import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const {PGlite} = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const driver = id(1);
const original = '  MONROE SUR, ROCIO\nCARVAJAL, avón, MONROE SUR; DUPLICADA, BASURERO  ';
await db.exec(`
  create role authenticated;
  create role anon;
  create table vehicles(id uuid primary key, code text, serial_number text, type text, status text);
  create table employees(id uuid primary key, full_name text, is_driver boolean);
  create table sites(id uuid primary key, name text, type text, is_active boolean);
  grant select on employees, sites to authenticated;
`);
await db.query('insert into employees values ($1,$2,true)', [driver, 'RENE']);
for (const [n, name, active, type] of [[10,'MONROE',true,'cliente'],[11,'MONROE SUR',true,'cliente'],[12,'ROCIO CARVAJAL',true,'cliente'],[13,'AVON',true,'cliente'],[14,'DUPLICADA',true,'cliente'],[15,'Duplicada',true,'cliente'],[16,'INACTIVA',false,'cliente'],[17,'PROVEEDOR',true,'proveedor']]) {
  await db.query('insert into sites values($1,$2,$3,$4)', [id(n),name,type,active]);
}
await db.exec(await readFile(new URL('../supabase/migrations/20260806190000_create_logistics_driver_vehicle_profiles.sql',import.meta.url),'utf8'));
await db.query('update logistics_driver_profiles set coverage_note=$1,notes=$2', [original,'NOTA INTACTA']);
await db.exec(await readFile(new URL('../supabase/migrations/20261103140000_link_driver_coverage_companies.sql',import.meta.url),'utf8'));
const profile = async () => (await db.query('select * from logistics_driver_profiles')).rows[0];
const links = async () => (await db.query('select site_id from logistics_driver_companies order by site_id')).rows.map(r=>r.site_id);
assert.deepEqual(await links(),[id(11),id(12),id(13)]);
assert.equal((await profile()).coverage_note,original);
assert.deepEqual((await profile()).coverage_import_pending,['BASURERO','DUPLICADA']);
assert.equal((await profile()).notes,'NOTA INTACTA');
const payload = {employee_id:driver,driver_name:'RENE',compatible_unit_types:['GRUA'],planning_status:'ACTIVO',coverage_note:original,notes:'CAMBIO'};
const save = (selected,expected,p=payload) => db.query('select save_logistics_driver_with_companies($1,$2,$3)',[JSON.stringify(p),selected,expected]);
await db.exec('set role authenticated');
await save([id(10),id(11),id(11)],[id(11),id(12),id(13)]);
assert.deepEqual(await links(),[id(10),id(11)]);
assert.equal((await profile()).coverage_note,original);
await assert.rejects(()=>save([id(12)],[id(11),id(12),id(13)]),e=>e.code==='40001');
for (const invalid of [id(16),id(17),id(100),null]) {
  await assert.rejects(()=>save([id(10),invalid],[id(10),id(11)],{...payload,notes:'NO GUARDAR'}),e=>e.code==='22023');
  assert.equal((await profile()).notes,'CAMBIO');
  assert.deepEqual(await links(),[id(10),id(11)]);
}
await db.exec('reset role');
await db.query('update sites set is_active=false where id=$1',[id(11)]);
await db.exec('set role authenticated');
await save([id(10),id(11)],[id(10),id(11)]); // preserve existing inactive link
await save([], [id(10),id(11)]);
assert.deepEqual(await links(),[]);
await db.exec('reset role');
await db.query("update employees set full_name='RENE JIMENEZ' where id=$1",[driver]);
assert.deepEqual(await links(),[]); // reading/name sync must not reimport removed links
assert.equal((await profile()).coverage_note,original);
await db.exec('set role anon');
await assert.rejects(()=>save([],[]),e=>e.code==='42501');
await db.exec('reset role');
await save([id(10)],[]);
await db.query('delete from sites where id=$1',[id(10)]);
assert.deepEqual(await links(),[]);
assert.equal((await profile()).coverage_note,original);
await db.close();
console.log('PASS: exact unique import, wrapped names/accents, duplicate/ambiguous names, original text preserved, atomic multi-selection/clear, stale editor conflict, inactive and foreign company validation, role and FK protection.');
