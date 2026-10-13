import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const {PGlite} = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const migration = n => readFile(new URL(`../supabase/migrations/${n}.sql`,import.meta.url),'utf8');
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
let request=100;
await db.exec(`create role authenticated; create role anon; create schema auth;
create function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
grant usage on schema auth to authenticated;
create table compras_counterparties(id text primary key);
create table compras_material_catalog(id text primary key);`);
async function tables(name, names) {
 const source=await migration(name);
 for(const table of names) {
  const match=source.match(new RegExp(`create table if not exists public\\.${table} \\([\\s\\S]*?\\n\\);`));
  assert(match,table); await db.exec(match[0]);
 }
}
const maintenance=await migration('20260305121000_create_maintenance_ot_mvp');
await db.exec(maintenance.slice(maintenance.indexOf('do $$'),maintenance.indexOf('create table')));
const mt=['maintenance_orders','maintenance_tasks','maintenance_materials','maintenance_time_logs'];
await tables('20260305121000_create_maintenance_ot_mvp',mt);
const hr=['hr_employee_profiles','hr_employee_documents'];
await tables('20260629150000_create_hr_employee_files_foundation',hr);
const ct=['compras_tickets','compras_provider_movements','compras_ticket_payment_applications'];
await tables('20260520173000_create_compras_tickets_foundation',ct);
await db.exec(`create table hr_employee_vacation_events(
 id uuid primary key, employee_id text references hr_employee_profiles(id) on delete cascade,
 notes text);
 insert into maintenance_orders(id,ot_folio,problem_description) values('${id(1)}','OT-SYNTHETIC','Original');
 insert into maintenance_tasks(id,ot_id,description) values('${id(2)}','${id(1)}','Original');
 insert into maintenance_materials(id,ot_id,name,cost_actual) values('${id(3)}','${id(1)}','Original',100);
 insert into maintenance_time_logs(id,ot_id,start_at) values('${id(4)}','${id(1)}','2026-10-01T12:00:00Z');
 insert into hr_employee_profiles(id,nombre,empresa,horario,nss,rfc,curp,fecha_ingreso,telefono,numero_cuenta,calzado)
 values('person-1','SYNTHETIC','TEST','TEST','','','','2026-01-01','','','');
 insert into hr_employee_documents(id,employee_id,category_key,category_label,title,file_url,file_name,storage_path)
 values('doc-1','person-1','adicional','Adicional','SYNTHETIC','synthetic.invalid/doc','doc.pdf','old/doc.pdf');
 insert into hr_employee_vacation_events values('${id(9)}','person-1','History');
 insert into compras_counterparties values('provider-1'); insert into compras_material_catalog values('material-1');
 insert into compras_tickets(id,ticket_number,provider_id,provider_name_snapshot,material_id,material_name_snapshot,amount,pago_status,coverage_status)
 values('ticket-1','TEST','provider-1','TEST','material-1','TEST',100,'PAGADO','CUBIERTO');
 insert into compras_provider_movements(id,provider_id,movement_type,source_type,amount)
 values('payment-1','provider-1','PAGO','BANCO',100);
 insert into compras_ticket_payment_applications(id,ticket_id,provider_movement_id,applied_amount)
 values('app-1','ticket-1','payment-1',100);
 grant select,insert,update,delete on all tables in schema public to authenticated;`);
const rows=async table=>(await db.query(`select to_jsonb(t) as row from ${table} t order by id`)).rows.map(r=>r.row);
const all=async()=>Object.fromEntries(await Promise.all([...mt,...hr,...ct,'hr_employee_vacation_events'].map(async t=>[t,await rows(t)])));
const before=await all();
await db.exec(await migration('20261002193000_add_preserving_atomic_saves'));
assert.deepEqual(await all(),before,'installing migration leaves every preexisting row unchanged');
await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id(99)]);
await db.exec('set role authenticated');
const commit=async(ops,checks=[],rid=id(request++))=>(await db.query(
 'select app_commit_preserving_data($1,$2::jsonb,$3::jsonb) as result',[rid,JSON.stringify(ops),JSON.stringify(checks)])).rows[0].result;
const patch=(table,id,values,expected)=>({table,action:'update',id,values,expected});
const del=(table,id,expected)=>({table,action:'delete',id,expected});
const insert=(table,values)=>({table,action:'insert',id:values.id,values});
const fails=async(fn,code)=>{try{await fn();assert.fail('Expected rollback');}catch(e){assert.equal(e.code,code,e.message);}};

// Failure at the last operation must roll back header and every earlier deletion.
await fails(()=>commit([
 patch('maintenance_orders',id(1),{problem_description:'Changed'},{problem_description:'Original'}),
 del('maintenance_tasks',id(2),before.maintenance_tasks[0]),
 del('maintenance_materials',id(3),before.maintenance_materials[0]),
 insert('maintenance_time_logs',{id:id(5),ot_id:id(1),start_at:null}),
]),'23502');
assert.deepEqual(await all(),before);
console.log('PASS: installation and failed multi-table save preserve all existing rows');

// Concurrent modification rejects the entire request, including earlier writes.
await db.query('update maintenance_tasks set description=$1 where id=$2',['Other user',id(2)]);
const concurrent=await all();
await fails(()=>commit([
 patch('maintenance_orders',id(1),{problem_description:'Changed'},{problem_description:'Original'}),
 patch('maintenance_tasks',id(2),{description:'Stale'},{description:'Original'}),
]),'40001');
assert.deepEqual(await all(),concurrent);
const check={table:'maintenance_tasks',column:'ot_id',ids:[id(1)],rows:before.maintenance_tasks};
await fails(()=>commit([patch('maintenance_orders',id(1),{problem_description:'Changed'},{problem_description:'Original'})],[check]),'40001');
assert.deepEqual(await all(),concurrent);
console.log('PASS: stale rows and incomplete detail snapshots cannot overwrite concurrent work');

// Successful save and repeated request preserve identities and don't duplicate.
const rid=id(request++), ops=[patch('maintenance_tasks',id(2),{description:'Saved'},{description:'Other user'})];
const response=await commit(ops,[],rid), after=await all();
assert.deepEqual(await commit(ops,[],rid),response);
assert.deepEqual(await all(),after);
assert.equal(after.maintenance_tasks[0].created_at,before.maintenance_tasks[0].created_at);
await fails(()=>commit([patch('maintenance_tasks',id(2),{description:'Different'},{description:'Saved'})],[],rid),'22023');
console.log('PASS: committed requests can be retried without duplicate writes or new IDs');

// RH name-only updates leave concurrently added documents untouched.
await db.exec(`insert into hr_employee_documents(id,employee_id,category_key,category_label,title,file_url,file_name)
 values('concurrent-doc','person-1','adicional','Adicional','Other user','synthetic.invalid/new','new.pdf')`);
await commit([patch('hr_employee_profiles','person-1',{nombre:'EDITED'},{nombre:'SYNTHETIC'})]);
assert.equal((await rows('hr_employee_documents')).length,2);
const rhBefore=await all();
await fails(()=>commit([
 del('hr_employee_documents','doc-1',rhBefore.hr_employee_documents.find(r=>r.id==='doc-1')),
 patch('hr_employee_profiles','person-1',{nombre:null},{nombre:'EDITED'}),
]),'23502');
assert.deepEqual(await all(),rhBefore);
console.log('PASS: RH retains concurrent files and rolls back attempted detach on failure');

// ID changes move relations; they never erase the old profile by cascade.
await db.exec('reset role');
await db.exec(`create table hr_readonly_reference_fixture(
 id uuid primary key, employee_id text references hr_employee_profiles(id) on delete cascade);
 grant select on hr_readonly_reference_fixture to authenticated;`);
await db.exec('set role authenticated');
await commit([{table:'hr_employee_profiles',action:'rename',id:'person-1',values:{id:'person-2'},
 expected:rhBefore.hr_employee_profiles[0]}]);
assert.deepEqual((await rows('hr_employee_profiles')).map(r=>r.id),['person-2']);
assert((await rows('hr_employee_documents')).every(r=>r.employee_id==='person-2'));
assert.equal((await rows('hr_employee_vacation_events'))[0].employee_id,'person-2');
await db.exec('reset role');
await db.exec(`insert into hr_readonly_reference_fixture values('${id(10)}','person-2');`);
const readonlyBefore=await all();
await db.exec('set role authenticated');
await fails(()=>commit([{table:'hr_employee_profiles',action:'rename',id:'person-2',values:{id:'person-readonly'},
 expected:readonlyBefore.hr_employee_profiles[0]}]),'40001');
await db.exec('reset role');
assert.deepEqual(await all(),readonlyBefore);
assert.equal((await rows('hr_readonly_reference_fixture'))[0].employee_id,'person-2');
await db.exec('delete from hr_readonly_reference_fixture');
console.log('PASS: read-only empty history allows rename; existing protected links prevent any cascade');
await db.exec(`create function reject_closed_history_change() returns trigger language plpgsql as $$
 begin raise exception 'Closed history'; end $$;
 create trigger preserve_closed_history before update on hr_employee_vacation_events
 for each row execute function reject_closed_history_change();`);
await db.exec('set role authenticated');
const closed=await all();
await fails(()=>commit([{table:'hr_employee_profiles',action:'rename',id:'person-2',values:{id:'person-3'},
 expected:closed.hr_employee_profiles[0]}]),'P0001');
assert.deepEqual(await all(),closed);
console.log('PASS: ID rename preserves relationships or rolls back completely for immutable history');
await db.exec('reset role');
await db.exec(`drop trigger preserve_closed_history on hr_employee_vacation_events;
 alter table hr_employee_vacation_events enable row level security;`);
await db.exec('set role authenticated');
await fails(()=>commit([{table:'hr_employee_profiles',action:'rename',id:'person-2',values:{id:'person-hidden'},
 expected:closed.hr_employee_profiles[0]}]),'40001');
await db.exec('reset role');
assert.deepEqual(await all(),closed);
await db.exec('set role authenticated');
console.log('PASS: hidden child rows cannot be lost through rename cascades');


// Reconciliation snapshot and status failure protect payments and allocations.
const tickets=await rows('compras_tickets');
const paymentOps=[
 insert('compras_provider_movements',{id:'payment-2',provider_id:'provider-1',movement_type:'PAGO',source_type:'BANCO',amount:10}),
 del('compras_ticket_payment_applications','app-1',(await rows('compras_ticket_payment_applications'))[0]),
 patch('compras_tickets','ticket-1',{pago_status:'INVALID'},{pago_status:'PAGADO'}),
];
const checks=[{table:'compras_tickets',column:'provider_id',ids:['provider-1'],rows:tickets}];
const financialBefore=await all();
await fails(()=>commit(paymentOps,checks),'23514');
assert.deepEqual(await all(),financialBefore);
await db.exec("update compras_tickets set amount=200 where id='ticket-1'");
const financialConcurrent=await all();
await fails(()=>commit(paymentOps,checks),'40001');
assert.deepEqual(await all(),financialConcurrent);
console.log('PASS: reconciliation failures preserve payment, allocation, ticket amounts and states');

// The new function cannot bypass existing RLS or caller privileges.
await db.exec('reset role');
await db.exec('alter table maintenance_tasks enable row level security');
await db.exec('set role authenticated');
await fails(()=>commit([patch('maintenance_tasks',id(2),{description:'Forbidden'},{description:'Saved'})]),'40001');
await fails(()=>commit([del('hr_employee_profiles','person-2',closed.hr_employee_profiles[0])]),'22023');
await db.exec('reset role');
assert.equal((await rows('maintenance_tasks'))[0].description,'Saved');
console.log('PASS: existing permissions and guards remain in force');
await db.close();
