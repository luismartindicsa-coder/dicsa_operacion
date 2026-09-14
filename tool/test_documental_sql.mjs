// Run with DOCUMENTAL_PGLITE_MODULE pointing to an isolated PGlite installation.
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.DOCUMENTAL_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const manager='00000000-0000-4000-8000-000000000001';
const viewer='00000000-0000-4000-8000-000000000002';
const documental='00000000-0000-4000-8000-000000000003';
const record='00000000-0000-4000-8000-000000000010';
const request='00000000-0000-4000-8000-000000000020';
await db.exec(`
  create role authenticated; create role anon;
  create schema auth; create schema storage;
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
  grant usage on schema auth,storage to authenticated,anon;
  create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}');
  create table public.profiles(user_id uuid primary key references auth.users(id),role text,is_active boolean,
    constraint profiles_role_check check(role in ('admin','ops_manager','services','fleet','fuel','viewer','direccion','desarrollo_comercial')));
  create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint);
  create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,metadata jsonb);
  alter table storage.objects enable row level security;
  grant all on storage.objects to authenticated,anon;
  create policy legacy_broad_access on storage.objects for all to authenticated,anon using(true) with check(true);
  insert into auth.users(id,email) values('${manager}','manager@test.invalid'),('${viewer}','viewer@test.invalid'),('${documental}','gestion@dicsamx.com');
  insert into public.profiles values('${manager}','direccion',true),('${viewer}','viewer',true);
`);
const migration = await readFile(new URL('../supabase/migrations/20260914120000_create_documental_legal_foundation.sql',import.meta.url),'utf8');
await db.exec(migration);
await db.exec(await readFile(new URL('../supabase/migrations/20260914121000_fix_documental_revision_conflict.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20260914210000_enable_documental_procedures.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20260914220000_enable_gestion_documental_role.sql',import.meta.url),'utf8'));
assert.deepEqual((await db.query('select role,is_active from public.profiles where user_id=$1',[documental])).rows[0],{role:'gestion_documental',is_active:true});
await db.exec(`set role authenticated; select set_config('request.jwt.claim.sub','${manager}',false);`);
const context=(await db.query('select public.documental_context() as data')).rows[0].data;
assert.equal(context.responsibles.length,3);
const data={title:'Acta de prueba',document_type:'Acta constitutiva',responsible_user_id:manager,status:'Pendiente',priority:'Media'};
const save=async(revision,requestId,payload=data,files=[]) => (await db.query(
  'select public.documental_save_record($1,$2,$3,$4::jsonb,$5::jsonb) as data',
  [record,revision,requestId,JSON.stringify(payload),JSON.stringify(files)])).rows[0].data;
const path=`${manager}/${record}/principal-1`;
await db.query("insert into storage.objects(bucket_id,name,metadata) values('documental',$1,'{\"size\":128}')",[path]);
const file={role:'principal',file_name:'acta-1.pdf',mime_type:'application/pdf',size_bytes:128,storage_path:path};
let saved=await save(0,request,data,[file]);
assert.equal(saved.record.revision,1);
assert.equal(saved.record.expiration_date,null);
assert.equal(saved.files.length,1);
saved=await save(0,request,data,[file]);
assert.equal(saved.history.length,1,'retry must not duplicate history or files');
const path2=`${manager}/${record}/principal-2`;
await db.query("insert into storage.objects(bucket_id,name,metadata) values('documental',$1,'{\"size\":256}')",[path2]);
saved=await save(1,'00000000-0000-4000-8000-000000000021',
  {...data,status:'Completado',expiration_date:'2020-01-01'},[{...file,storage_path:path2,file_name:'acta-2.pdf'}]);
assert.equal(saved.record.revision,2);
assert.equal(saved.files.length,2);
assert.equal(saved.files.filter(f=>f.is_current).length,1);
assert.equal(saved.history[1].snapshot.files[0].storage_path,path);
await assert.rejects(()=>save(1,'00000000-0000-4000-8000-000000000022'),e=>e.code==='PT409');
await assert.rejects(()=>save(2,'00000000-0000-4000-8000-000000000023',
  {...data,start_date:'2027-01-01',expiration_date:'2026-01-01'}),e=>e.code==='23514');
const after=(await db.query('select public.documental_get_record($1) as data',[record])).rows[0].data;
assert.equal(after.record.revision,2,'failed save must roll back record, files and history');
const completed=(await db.query("select public.documental_list_records(p_urgency=>'Completado') as data")).rows[0].data;
assert.equal(completed.total,1);
assert.equal((await db.query("select public.documental_list_records(p_urgency=>'Vencido') as data")).rows[0].data.total,0);
assert.equal((await db.query("select public.documental_list_records(p_search=>'inexistente') as data")).rows[0].data.total,0);
assert.equal((await db.query("delete from storage.objects where bucket_id='documental' returning name")).rows.length,0,'history files cannot be deleted, even with a legacy broad policy');
assert.equal((await db.query("update storage.objects set name='overwritten' where bucket_id='documental' returning name")).rows.length,0);
await assert.rejects(()=>db.query("update public.documental_records set title='bypass'"),e=>e.code==='42501');

const procedureId='00000000-0000-4000-8000-000000000030';
const procedure={...data,category:'permisos-y-tramites',title:'Licencia de operación',document_type:'Licencia',authority:'Ayuntamiento',progress_percentage:35,priority:'Alta',expiration_date:context.today};
const saveProcedure=async(revision,payload=procedure)=>(await db.query(
  'select public.documental_save_record($1,$2,gen_random_uuid(),$3::jsonb) as data',
  [procedureId,revision,JSON.stringify(payload)])).rows[0].data;
let procedureSaved=await saveProcedure(0);
assert.equal(procedureSaved.record.progress_percentage,35);
const query=async(category,priority=null,search='',page=0)=>(await db.query(
  'select public.documental_query_records(p_category=>$1,p_priority=>$2,p_search=>$3,p_page=>$4) as data',[category,priority,search,page])).rows[0].data;
assert.equal((await query('documentacion-legal')).total,1);
assert.equal((await query('permisos-y-tramites','Alta','Ayuntamiento')).total,1);
assert.equal((await query('permisos-y-tramites','Baja')).total,0);
assert.equal((await db.query("select public.documental_query_records('permisos-y-tramites',p_urgency=>'Crítico') as data")).rows[0].data.total,1);
assert.equal((await db.query('select public.documental_list_records() as data')).rows[0].data.total,1,'legacy Legal query must not leak procedures');
procedureSaved=await saveProcedure(1,{...procedure,progress_percentage:85,next_action:'Entregar solicitud',status:'En proceso'});
assert.equal(procedureSaved.record.progress_percentage,85);
assert.equal(procedureSaved.history[1].snapshot.record.progress_percentage,35);
await assert.rejects(()=>saveProcedure(1),e=>e.code==='PT409');
for (const invalid of [-1,101,null,1.5]) {
  await assert.rejects(()=>saveProcedure(2,{...procedure,progress_percentage:invalid}),e=>e.code==='23514');
}
await assert.rejects(()=>saveProcedure(2,{...data,category:'documentacion-legal'}),e=>e.code==='23514');
await assert.rejects(()=>save(2,'00000000-0000-4000-8000-000000000041',procedure),e=>e.code==='23514');
assert.equal((await db.query('select public.documental_get_record($1) as data',[procedureId])).rows[0].data.record.progress_percentage,85);
await db.query(`do $paging$ begin for i in 1..51 loop
 perform public.documental_save_record(gen_random_uuid(),0,gen_random_uuid(),
 jsonb_build_object('category','permisos-y-tramites','title','PAGING CHECK '||i,'document_type','Trámite','responsible_user_id',auth.uid(),'status','Pendiente','priority','Media','progress_percentage',0));
 end loop; end $paging$;`);
assert.equal((await query('permisos-y-tramites',null,'PAGING CHECK')).records.length,50);
const lastPage=await query('permisos-y-tramites',null,'PAGING CHECK',1);
assert.equal(lastPage.total,51);
assert.equal(lastPage.records.length,1);

await db.query("select set_config('request.jwt.claim.sub',$1,false)",[documental]);
assert.equal((await db.query('select public.documental_can_manage() as allowed')).rows[0].allowed,true);
assert.equal((await query('documentacion-legal')).total,1);
assert.equal((await query('permisos-y-tramites')).total,52);
assert.equal((await db.query("select * from storage.objects where bucket_id='documental'")).rows.length,2,'documental role can read existing versioned files');
saved=await save(2,'00000000-0000-4000-8000-000000000025',{...data,responsible_user_id:documental});
assert.equal(saved.record.updated_by,documental);
assert.equal(saved.history[0].actor_id,documental);
procedureSaved=await saveProcedure(2,{...procedure,responsible_user_id:documental,progress_percentage:90});
assert.equal(procedureSaved.record.progress_percentage,90);
const documentalPath=`${documental}/${procedureId}/attachment`;
await db.query("insert into storage.objects(bucket_id,name,metadata) values('documental',$1,'{\"size\":128}')",[documentalPath]);
assert.equal((await db.query('delete from storage.objects where name=$1 returning name',[documentalPath])).rows.length,1,'documental can clean its own unreferenced upload');
await db.exec(`reset role; update public.profiles set is_active=false where user_id='${documental}'; set role authenticated;`);
assert.equal((await db.query('select public.documental_can_manage() as allowed')).rows[0].allowed,false);
assert.equal((await db.query('select * from public.documental_records')).rows.length,0);
assert.equal((await db.query("select * from storage.objects where bucket_id='documental'")).rows.length,0);
await assert.rejects(()=>query('documentacion-legal'),e=>e.code==='42501');
await assert.rejects(()=>saveProcedure(3),e=>e.code==='42501');

await db.query("select set_config('request.jwt.claim.sub',$1,false)",[viewer]);
assert.equal((await db.query('select * from public.documental_records')).rows.length,0);
assert.equal((await db.query("select * from storage.objects where bucket_id='documental'")).rows.length,0);
await assert.rejects(()=>db.query('select public.documental_context()'),e=>e.code==='42501');
await assert.rejects(()=>save(2,'00000000-0000-4000-8000-000000000024'),e=>e.code==='42501');
await db.exec('reset role; set role anon;');
assert.equal((await db.query("select * from storage.objects where bucket_id='documental'")).rows.length,0);
await db.close();
console.log('SQL: procedures, progress bounds, category isolation, pagination, legacy compatibility, creation, atomic save, idempotent retry, conflict, versions, filters, RLS and private immutable files passed.');
