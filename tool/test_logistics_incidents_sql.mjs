import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';

const {PGlite} = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const service = '00000000-0000-4000-8000-000000000001';
const vehicle = '00000000-0000-4000-8000-000000000002';
const driver = '00000000-0000-4000-8000-000000000003';
const user = '00000000-0000-4000-8000-000000000004';
await db.exec(`
 create role authenticated; create role anon; create schema auth;
 create table auth.users(id uuid primary key);
 create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
 grant usage on schema auth to authenticated;
 create table public.services(id uuid primary key, status text);
 create table public.vehicles(id uuid primary key, status text);
 create table public.employees(id uuid primary key);
 insert into services values('${service}','programado');
 insert into vehicles values('${vehicle}','activo');
 insert into employees values('${driver}');
 insert into auth.users values('${user}');
`);
const beforeServices = (await db.query('select * from services')).rows;
const beforeVehicles = (await db.query('select * from vehicles')).rows;
await db.exec(await readFile(new URL('../supabase/migrations/20261012160000_create_logistics_trip_incidents.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20261012170000_create_logistics_unit_states.sql',import.meta.url),'utf8'));
await db.query("select set_config('request.jwt.claim.sub',$1,false)",[user]);
await db.exec('set role authenticated');
const create = (type='FALLA_MECANICA',summary='Falla de frenos',link=service) => db.query(
 `insert into logistics_trip_incidents(service_id,vehicle_id,driver_employee_id,service_label,vehicle_code,driver_name,incident_type,impact_level,summary)
 values($1,$2,$3,'Servicio original','C-01','Chofer original',$4,'ALTA',$5) returning *`,[link,vehicle,driver,type,summary]);
const original = (await create()).rows[0];
assert.equal(original.reported_by,user);assert.equal(original.resolution_status,'ABIERTA');assert.equal(original.resolved_at,null);
await db.query("update logistics_trip_incidents set resolution_status='EN_SEGUIMIENTO',responsible_name='OPERACIONES' where id=$1",[original.id]);
assert.equal((await db.query('select resolution_status from logistics_trip_incidents')).rows[0].resolution_status,'EN_SEGUIMIENTO');
console.log('PASS: authenticated incident creation and follow-up');
async function fails(action,code){await assert.rejects(action,e=>e.code===code);}
await fails(()=>create('INVALID'),'23514');await fails(()=>create('RETRASO',' '),'23514');await fails(()=>create('RETRASO','Falla',user),'23503');
await fails(()=>db.query("update logistics_trip_incidents set resolution_status='RESUELTA'"),'23514');
await db.query("update logistics_trip_incidents set resolution_status='RESUELTA',action_taken='Frenos reparados' where id=$1",[original.id]);
const resolved=(await db.query('select * from logistics_trip_incidents')).rows[0];
assert(resolved.resolved_at);assert.equal(resolved.reported_at.getTime(),original.reported_at.getTime());
await db.query("update logistics_trip_incidents set notes='Corregida la nota' where id=$1",[original.id]);
const edited=(await db.query('select * from logistics_trip_incidents')).rows[0];
assert.equal(edited.resolved_at.getTime(),resolved.resolved_at.getTime());
// Compare PostgreSQL timestamps as text so microseconds are not lost to JS Date.
const version=(await db.query('select updated_at::text as version from logistics_trip_incidents')).rows[0].version;
await db.query("update logistics_trip_incidents set notes='Nueva revisión' where id=$1",[original.id]);
assert.equal((await db.query('update logistics_trip_incidents set notes=$1 where id=$2 and updated_at=$3::timestamptz returning id',['Edición obsoleta',original.id,version])).rows.length,0);
await db.query("update logistics_trip_incidents set resolution_status='ABIERTA' where id=$1",[original.id]);
assert.equal((await db.query('select resolved_at from logistics_trip_incidents')).rows[0].resolved_at,null);
console.log('PASS: resolution validation, retained history, reopen and stale-edit protection');
const state = (await db.query("insert into logistics_unit_states(vehicle_id,operational_status,notes) values($1,'EN_REVISION','Revisar frenos') returning *",[vehicle])).rows[0];
assert.equal(state.operational_status,'EN_REVISION');assert.equal(state.updated_by,user);
await fails(()=>db.query("insert into logistics_unit_states(vehicle_id,operational_status) values($1,'INVALID')",[vehicle]),'23514');
await db.query("update logistics_unit_states set operational_status='FUERA_DE_SERVICIO',notes='Esperando refacción' where vehicle_id=$1",[vehicle]);
assert.equal((await db.query('select operational_status from logistics_unit_states')).rows[0].operational_status,'FUERA_DE_SERVICIO');
const stateVersion=(await db.query('select updated_at::text as version from logistics_unit_states')).rows[0].version;
await db.query("update logistics_unit_states set notes='Nueva observación' where vehicle_id=$1",[vehicle]);
assert.equal((await db.query("update logistics_unit_states set operational_status='DISPONIBLE' where vehicle_id=$1 and updated_at=$2::timestamptz returning vehicle_id",[vehicle,stateVersion])).rows.length,0);
await fails(()=>db.query('delete from logistics_unit_states'),'42501');
console.log('PASS: manual unit states validate values, retain the author and prevent stale overwrites');

await fails(()=>db.query('delete from logistics_trip_incidents'),'42501');
await db.exec('reset role; set role anon');await fails(()=>db.query('select * from logistics_trip_incidents'),'42501');
await fails(()=>db.query('select * from logistics_unit_states'),'42501');
await db.exec('reset role');
assert.deepEqual((await db.query('select * from services')).rows,beforeServices);
assert.deepEqual((await db.query('select * from vehicles')).rows,beforeVehicles);
await db.query('delete from services where id=$1',[service]);await db.query('delete from vehicles where id=$1',[vehicle]);await db.query('delete from employees where id=$1',[driver]);
const historical=(await db.query('select * from logistics_trip_incidents')).rows[0];
assert.equal(historical.service_id,null);assert.equal(historical.vehicle_id,null);assert.equal(historical.driver_employee_id,null);
assert.equal(historical.service_label,'Servicio original');assert.equal(historical.vehicle_code,'C-01');assert.equal(historical.driver_name,'Chofer original');
console.log('PASS: warnings leave assignments unchanged, source deletion retains incident history, anonymous access/deletion denied');
await db.close();
