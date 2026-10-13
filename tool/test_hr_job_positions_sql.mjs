import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const {PGlite} = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const migration = n => readFile(new URL(`../supabase/migrations/${n}.sql`,import.meta.url),'utf8');
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const rh=id(1), director=id(2), outsider=id(3), inactive=id(4);
await db.exec(`create role anon; create role authenticated; create schema auth;
create table auth.users(id uuid primary key,email text);
create table public.profiles(user_id uuid primary key,role text,is_active boolean);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
grant usage on schema auth to authenticated;
insert into auth.users values('${rh}','rh@dicsamx.com'),('${director}','director@example.test'),('${outsider}','operacion@example.test'),('${inactive}','direccion@dicsamx.com');
insert into profiles values('${director}','direccion',true),('${outsider}','operacion',true),('${inactive}','direccion',false);`);
const loanSql=await migration('20260910010000_create_hr_loan_fund');
await db.exec(loanSql.slice(loanSql.indexOf('create function public.hr_can_access_loans()'),loanSql.indexOf('alter table public.hr_loan_fund enable')));
const foundation=await migration('20260629150000_create_hr_employee_files_foundation');
for(const table of ['hr_employee_profiles','hr_employee_documents']) {
  const match=foundation.match(new RegExp(`create table if not exists public\\.${table} \\([\\s\\S]*?\\n\\);`));
  assert(match); await db.exec(match[0]);
}
await db.exec(`alter table hr_employee_profiles add column salario numeric default 0;
insert into hr_employee_profiles(id,nombre,empresa,horario,nss,rfc,curp,fecha_ingreso,telefono,numero_cuenta,calzado,salario)
values('person-1','PRUEBA','TEST','TEST','','','','2026-01-01','','','',2000);
insert into hr_employee_documents(id,employee_id,category_key,category_label,title,file_url,file_name)
values('doc-1','person-1','adicional','Adicional','PRUEBA','synthetic.invalid/doc','doc.pdf');
grant select,insert,update,delete on hr_employee_profiles,hr_employee_documents to authenticated;`);
const rows=async table=>(await db.query(`select to_jsonb(t) as row from ${table} t`)).rows.map(r=>r.row);
const before=(await rows('hr_employee_profiles'))[0], docs=await rows('hr_employee_documents');
await db.exec(await migration('20261002193000_add_preserving_atomic_saves'));
await db.exec(await migration('20261013100000_add_hr_job_positions'));
assert.deepEqual((await rows('hr_employee_profiles'))[0],{...before,puesto:''});
assert.deepEqual(await rows('hr_employee_documents'),docs);
assert.equal((await rows('hr_job_positions')).length,0);
console.log('PASS: migration adds a blank optional position without changing existing employee data or files');
const login=async user=>{
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,false)",[user]);
  await db.exec('set role authenticated');
};
const ensure=async name=>(await db.query('select hr_job_position_ensure($1) as name',[name])).rows[0].name;
const fails=(fn,code)=>assert.rejects(fn,e=>e.code===code);
await login(rh);
assert.equal(await ensure('  técnico\t de   patio  '),'TÉCNICO DE PATIO');
await login(director);
assert.equal(await ensure('tecnico de patio'),'TÉCNICO DE PATIO');
assert.equal((await rows('hr_job_positions')).length,1);
assert.equal((await rows('hr_job_positions'))[0].created_by,rh);
for(const invalid of ['',null,' '.repeat(20),'A'.repeat(121)]) await fails(()=>ensure(invalid),'22023');
await fails(()=>db.query("insert into hr_job_positions(name) values('BYPASS')"),'42501');
console.log('PASS: shared RH/Dirección catalog normalizes and reuses canonical names, validates lengths and prevents direct mutation');
let request=100;
const commit=async(ops,rid=id(request++))=>(await db.query('select app_commit_preserving_data($1,$2::jsonb) as result',[rid,JSON.stringify(ops)])).rows[0].result;
const patch=(values,expected)=>({table:'hr_employee_profiles',action:'update',id:'person-1',values,expected});
const rid=id(request++), ops=[patch({puesto:'tecnico de patio'},{puesto:''})];
const response=await commit(ops,rid);
assert.equal(response[0].row.puesto,'TÉCNICO DE PATIO');
assert.deepEqual(await commit(ops,rid),response);
assert.equal((await rows('hr_job_positions')).length,1);
await db.query("update hr_employee_profiles set salario=2200 where id='person-1'");
await commit([patch({puesto:' supervisor  '},{puesto:'TÉCNICO DE PATIO'})]);
const saved=(await rows('hr_employee_profiles'))[0];
assert.equal(saved.salario,2200);
assert.equal(saved.puesto,'SUPERVISOR');
assert.deepEqual(await rows('hr_employee_documents'),docs);
await fails(()=>commit([patch({nombre:'STALE',puesto:'AUXILIAR'},{puesto:'TÉCNICO DE PATIO'})]),'40001');
assert.deepEqual((await rows('hr_employee_profiles'))[0],saved);
assert.equal((await rows('hr_job_positions')).length,2);
await commit([patch({nombre:'ACTUALIZADO'},{nombre:'PRUEBA'})]);
assert.equal((await rows('hr_employee_profiles'))[0].puesto,'SUPERVISOR');
await commit([patch({puesto:''},{puesto:'SUPERVISOR'})]);
assert.equal((await rows('hr_job_positions')).length,2);
assert.equal((await rows('hr_employee_profiles'))[0].puesto,'');
await fails(()=>commit([
  patch({puesto:'NUEVO PUESTO'},{puesto:''}),
  {table:'hr_employee_documents',action:'update',id:'doc-1',values:{title:null},expected:{title:'PRUEBA'}},
]),'23502');
assert.equal((await rows('hr_employee_profiles'))[0].puesto,'');
assert.equal((await rows('hr_job_positions')).length,2);
assert.deepEqual(await rows('hr_employee_documents'),docs);
console.log('PASS: atomic assignment and retries preserve salary/files; stale changes and later failures roll back; clearing retains reusable options');
for(const user of [outsider,inactive]) {
  await login(user);
  assert.equal((await rows('hr_job_positions')).length,0);
  await fails(()=>ensure('SIN ACCESO'),'42501');
  await fails(()=>commit([patch({puesto:'SIN ACCESO'},{puesto:''})]),'42501');
}
await db.exec('reset role;set role anon');
await fails(()=>rows('hr_job_positions'),'42501');
await fails(()=>ensure('SIN ACCESO'),'42501');
console.log('PASS: unrelated, inactive and anonymous roles cannot access or add job positions');
await db.close();
