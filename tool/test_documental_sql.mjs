// Run with DOCUMENTAL_PGLITE_MODULE pointing to an isolated PGlite installation.
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.DOCUMENTAL_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const manager='00000000-0000-4000-8000-000000000001';
const viewer='00000000-0000-4000-8000-000000000002';
const documental='00000000-0000-4000-8000-000000000003';
const vehicle='00000000-0000-4000-8000-000000000007';
const vehicle2='00000000-0000-4000-8000-000000000008';
const employee='00000000-0000-4000-8000-000000000005';
const record='00000000-0000-4000-8000-000000000010';
const request='00000000-0000-4000-8000-000000000020';
await db.exec(`
  create role authenticated; create role anon;
  create schema auth; create schema storage;
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
  grant usage on schema auth,storage to authenticated,anon;
  create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}');
  create table public.vehicles(id uuid primary key,code text,nickname text,plate text,status text);
  insert into public.vehicles values('${vehicle}','C1','C1','ABC-123','activo'),('${vehicle2}','C2','Camión dos','DEF-456','mantenimiento');
  create table public.employees(id uuid primary key,full_name text,is_active boolean);
  insert into public.employees values('${employee}','Trabajador de prueba',true),('00000000-0000-4000-8000-000000000006','Inactivo',false);
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
await db.exec(await readFile(new URL('../supabase/migrations/20260914230000_enable_documental_safety.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20260914233000_enable_documental_environment.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20260914234500_enable_documental_vehicles.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20260914235000_enable_documental_personnel.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20260914235500_enable_documental_civil_protection.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20260914235900_enable_documental_contracts.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20260914235930_enable_documental_insurance.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20260914235945_enable_documental_maintenance.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20260914235950_enable_documental_audits.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20260914235955_enable_documental_overview.sql',import.meta.url),'utf8'));
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

const safetyId='00000000-0000-4000-8000-000000000050';
const safety={...procedure,category:'seguridad-e-higiene',title:'Capacitación de seguridad',document_type:'DC3',related_employee_id:employee,
  related_employee_name:'Untrusted supplied name',study_type:'Ergonomía',provider_name:'Capacitador de prueba',periodicity:'Anual',department:'Patio'};
const saveSafety=async(revision,payload=safety,id=safetyId)=>(await db.query(
  'select public.documental_save_record($1,$2,gen_random_uuid(),$3::jsonb) as data',[id,revision,JSON.stringify(payload)])).rows[0].data;
assert.equal((await db.query('select public.documental_safety_context() as data')).rows[0].data.employees.length,1);
let safetySaved=await saveSafety(0);
assert.equal(safetySaved.record.related_employee_name,'Trabajador de prueba','employee name comes from HR, not a client string');
assert.equal(safetySaved.record.progress_percentage,35);
assert.equal((await query('seguridad-e-higiene',null,'Trabajador de prueba')).total,1);
assert.equal((await query('seguridad-e-higiene',null,'Capacitador')).total,1);
assert.equal((await query('documentacion-legal',null,'Capacitador')).total,0);
assert.equal((await query('permisos-y-tramites',null,'Capacitador')).total,0);
await db.exec(`reset role; update public.employees set full_name='Nombre actualizado',is_active=false where id='${employee}'; set role authenticated;`);
safetySaved=await saveSafety(1,{...safety,progress_percentage:80,periodicity:'Semestral'});
assert.equal(safetySaved.record.related_employee_name,'Nombre actualizado');
assert.equal(safetySaved.history[1].snapshot.record.related_employee_name,'Trabajador de prueba');
assert.equal(safetySaved.history[1].snapshot.record.periodicity,'Anual');
assert.equal((await db.query('select public.documental_safety_context() as data')).rows[0].data.employees.length,0);
await assert.rejects(()=>saveSafety(0,safety,'00000000-0000-4000-8000-000000000051'),e=>e.code==='23514','inactive employee cannot be assigned to a new record');
for(const payload of [{...safety,study_type:'inventado'},{...safety,periodicity:'inventada'},{...safety,document_type:'Acta constitutiva'},
  {...safety,related_employee_id:'00000000-0000-4000-8000-000000000099'},{...safety,progress_percentage:101}, {...safety,category:'permisos-y-tramites'}]) {
  await assert.rejects(()=>saveSafety(2,payload),e=>e.code==='23514');
}
safetySaved=await saveSafety(2,{...safety,related_employee_id:null,periodicity:'',study_type:'',expiration_date:null});
assert.equal(safetySaved.record.related_employee_id,null);
assert.equal(safetySaved.record.related_employee_name,'');
assert.equal(safetySaved.record.expiration_date,null);
assert.equal(safetySaved.record.department,'Patio','an area-wide obligation need not link a worker');

const environmentId='00000000-0000-4000-8000-000000000060';
const environmental={...procedure,category:'medio-ambiente',title:'Autorización ambiental',document_type:'Autorización',authority:'Autoridad ambiental de prueba',
  authorization_number:'  AMB-001  ',installation_name:'  Instalación de prueba  ',reference:'FOL-001',expiration_date:null};
const saveEnvironment=async(revision,payload=environmental)=>(await db.query(
  'select public.documental_save_record($1,$2,gen_random_uuid(),$3::jsonb) as data',[environmentId,revision,JSON.stringify(payload)])).rows[0].data;
let environmentalSaved=await saveEnvironment(0);
assert.equal(environmentalSaved.record.authorization_number,'AMB-001');
assert.equal(environmentalSaved.record.installation_name,'Instalación de prueba');
assert.equal(environmentalSaved.record.reference,'FOL-001','authorization number must not overwrite the reference');
for(const text of ['AMB-001','Instalación de prueba','Autoridad ambiental de prueba']) {
  assert.equal((await query('medio-ambiente',null,text)).total,1);
  for(const category of ['documentacion-legal','permisos-y-tramites','seguridad-e-higiene']) {
    assert.equal((await query(category,null,text)).total,0);
  }
}
environmentalSaved=await saveEnvironment(1,{...environmental,authorization_number:'AMB-002',installation_name:'Instalación renovada',progress_percentage:75});
assert.equal(environmentalSaved.record.authorization_number,'AMB-002');
assert.equal(environmentalSaved.history[1].snapshot.record.authorization_number,'AMB-001');
assert.equal(environmentalSaved.history[1].snapshot.record.installation_name,'Instalación de prueba');
await assert.rejects(()=>saveEnvironment(1),e=>e.code==='PT409');
for(const payload of [{...environmental,document_type:'DC3'},{...environmental,category:'seguridad-e-higiene'},{...environmental,progress_percentage:101}]) {
  await assert.rejects(()=>saveEnvironment(2,payload),e=>e.code==='23514');
}
environmentalSaved=await saveEnvironment(2,{...environmental,authorization_number:'',installation_name:'',expiration_date:null});
assert.equal(environmentalSaved.record.installation_name,'');
assert.equal(environmentalSaved.record.expiration_date,null,'not every environmental document has a due date or an authorization');
const vehicularId='00000000-0000-4000-8000-000000000070';
const vehicular={...procedure,category:'vehiculos',title:'Seguro de la unidad',document_type:'Seguro',vehicle_id:vehicle,vehicle_label:'Identidad falsa',reference:'POL-001',expiration_date:null};
const saveVehicle=async(revision,payload=vehicular)=>(await db.query(
  'select public.documental_save_record($1,$2,gen_random_uuid(),$3::jsonb) as data',[vehicularId,revision,JSON.stringify(payload)])).rows[0].data;
const vehicleContext=(await db.query('select public.documental_vehicle_context() as data')).rows[0].data;
assert.deepEqual(vehicleContext.vehicles,[{id:vehicle,label:'C1 · ABC-123'},{id:vehicle2,label:'C2 · Camión dos · DEF-456'}]);
let vehicleSaved=await saveVehicle(0);
assert.equal(vehicleSaved.record.vehicle_id,vehicle);
assert.equal(vehicleSaved.record.vehicle_label,'C1 · ABC-123','server must resolve identity from the vehicle catalog');
for(const text of ['ABC-123','C1','POL-001']) {
  assert.equal((await query('vehiculos',null,text)).total,1);
  for(const category of ['documentacion-legal','permisos-y-tramites','seguridad-e-higiene','medio-ambiente']) {
    assert.equal((await query(category,null,text)).total,0);
  }
}
await db.exec(`reset role; update public.vehicles set plate='XYZ-789',status='fuera_servicio' where id='${vehicle}'; set role authenticated;`);
vehicleSaved=await saveVehicle(1);
assert.equal(vehicleSaved.record.vehicle_label,'C1 · XYZ-789');
assert.equal(vehicleSaved.history[1].snapshot.record.vehicle_label,'C1 · ABC-123','catalog changes must not rewrite historical identities');
await assert.rejects(()=>saveVehicle(1),e=>e.code==='PT409');
for(const payload of [{...vehicular,document_type:'DC3'},{...vehicular,category:'medio-ambiente'},{...vehicular,progress_percentage:101},{...vehicular,vehicle_id:'00000000-0000-4000-8000-000000000099'}]) {
  await assert.rejects(()=>saveVehicle(2,payload),e=>e.code==='23514');
}
vehicleSaved=await saveVehicle(2,{...vehicular,vehicle_id:vehicle2});
assert.equal(vehicleSaved.record.vehicle_label,'C2 · Camión dos · DEF-456','units in maintenance remain documentable');
vehicleSaved=await saveVehicle(3,{...vehicular,vehicle_id:null});
assert.equal(vehicleSaved.record.vehicle_id,null);
assert.equal(vehicleSaved.record.vehicle_label,'','fleet-wide documents must clear previous unit identity');
assert.equal(vehicleSaved.record.expiration_date,null);
vehicleSaved=await saveVehicle(4);
await db.exec(`reset role; delete from public.vehicles where id='${vehicle}'; set role authenticated;`);
assert.equal((await db.query('select public.documental_get_record($1) as data',[vehicularId])).rows[0].data.record.vehicle_id,null);
assert.equal((await db.query('select public.documental_get_record($1) as data',[vehicularId])).rows[0].data.history[0].snapshot.record.vehicle_id,vehicle,'deleting a catalog entry preserves its historical record');
const personnelId='00000000-0000-4000-8000-000000000080';
const inactiveEmployee='00000000-0000-4000-8000-000000000006';
const personnel={...procedure,category:'personal',title:'Contrato del trabajador',document_type:'Contrato laboral',related_employee_id:inactiveEmployee,
  related_employee_name:'Identidad falsa',reference:'RH-001',authority:'Emisor de prueba RH',department:'Recursos Humanos',expiration_date:null,
  study_type:'Ergonomía',provider_name:'No corresponde',periodicity:'Anual',vehicle_id:vehicle2};
const savePersonnel=async(revision,payload=personnel)=>(await db.query(
  'select public.documental_save_record($1,$2,gen_random_uuid(),$3::jsonb) as data',[personnelId,revision,JSON.stringify(payload)])).rows[0].data;
const personnelContext=(await db.query('select public.documental_personnel_context() as data')).rows[0].data;
assert.deepEqual(personnelContext.employees,[{id:inactiveEmployee,label:'Inactivo',is_active:false},{id:employee,label:'Nombre actualizado',is_active:false}]);
let personnelSaved=await savePersonnel(0);
assert.equal(personnelSaved.record.related_employee_id,inactiveEmployee,'Personal can create documents for inactive employees');
assert.equal(personnelSaved.record.related_employee_name,'Inactivo','name comes from HR, never from supplied text');
assert.equal(personnelSaved.record.study_type,'');
assert.equal(personnelSaved.record.provider_name,'');
assert.equal(personnelSaved.record.periodicity,'');
assert.equal(personnelSaved.record.vehicle_id,null,'fields from other categories are not copied into personnel files');
for(const text of ['Inactivo','RH-001','Emisor de prueba RH']) {
  assert.equal((await query('personal',null,text)).total,1);
  for(const category of ['documentacion-legal','permisos-y-tramites','seguridad-e-higiene','medio-ambiente','vehiculos']) {
    assert.equal((await query(category,null,text)).total,0);
  }
}
await db.exec(`reset role; update public.employees set full_name='Trabajador actualizado',is_active=true where id='${inactiveEmployee}'; set role authenticated;`);
assert.equal((await db.query('select public.documental_personnel_context() as data')).rows[0].data.employees.find(e=>e.id===inactiveEmployee).is_active,true);
personnelSaved=await savePersonnel(1,{...personnel,progress_percentage:70});
assert.equal(personnelSaved.record.related_employee_name,'Trabajador actualizado');
assert.equal(personnelSaved.history[1].snapshot.record.related_employee_name,'Inactivo','renaming a worker does not rewrite history');
assert.equal(personnelSaved.record.progress_percentage,70);
await assert.rejects(()=>savePersonnel(1),e=>e.code==='PT409');
for(const payload of [{...personnel,document_type:'DC3'},{...personnel,category:'seguridad-e-higiene'},{...personnel,progress_percentage:101},
  {...personnel,related_employee_id:'00000000-0000-4000-8000-000000000099'}]) {
  await assert.rejects(()=>savePersonnel(2,payload),e=>e.code==='23514');
}
personnelSaved=await savePersonnel(2,{...personnel,related_employee_id:null});
assert.equal(personnelSaved.record.related_employee_id,null);
assert.equal(personnelSaved.record.related_employee_name,'');
assert.equal(personnelSaved.record.department,'Recursos Humanos');
assert.equal(personnelSaved.record.expiration_date,null,'a general document need not expire or link a worker');
personnelSaved=await savePersonnel(3);
await db.exec(`reset role; delete from public.employees where id='${inactiveEmployee}'; set role authenticated;`);
const afterEmployeeDeletion=(await db.query('select public.documental_get_record($1) as data',[personnelId])).rows[0].data;
assert.equal(afterEmployeeDeletion.record.related_employee_id,null);
assert.equal(afterEmployeeDeletion.history[0].snapshot.record.related_employee_id,inactiveEmployee);
assert.equal(afterEmployeeDeletion.history[0].snapshot.record.related_employee_name,'Trabajador actualizado');
const civilId='00000000-0000-4000-8000-000000000090';
const civil={...procedure,category:'proteccion-civil',title:'Simulacro de evacuación',document_type:'Simulacro',reference:'PC-001',authority:'Coordinación de prueba',department:'Patio de prueba',expiration_date:null,
  related_employee_id:employee,vehicle_id:vehicle2,authorization_number:'No corresponde',study_type:'Ergonomía',provider_name:'No corresponde'};
const saveCivil=async(revision,payload=civil)=>(await db.query(
  'select public.documental_save_record($1,$2,gen_random_uuid(),$3::jsonb) as data',[civilId,revision,JSON.stringify(payload)])).rows[0].data;
let civilSaved=await saveCivil(0);
assert.equal(civilSaved.record.authority,'Coordinación de prueba');
assert.equal(civilSaved.record.department,'Patio de prueba');
assert.equal(civilSaved.record.expiration_date,null);
assert.equal(civilSaved.record.related_employee_id,null);
assert.equal(civilSaved.record.vehicle_id,null);
assert.equal(civilSaved.record.authorization_number,'');
assert.equal(civilSaved.record.study_type,'');
assert.equal(civilSaved.record.provider_name,'');
for(const text of ['PC-001','Coordinación de prueba','Patio de prueba']) {
  assert.equal((await query('proteccion-civil',null,text)).total,1);
  for(const category of ['documentacion-legal','permisos-y-tramites','seguridad-e-higiene','medio-ambiente','vehiculos','personal']) {
    assert.equal((await query(category,null,text)).total,0);
  }
}
assert.equal((await db.query("select public.documental_query_records('proteccion-civil',p_type=>'Programa interno') as data")).rows[0].data.total,0);
assert.equal((await db.query("select public.documental_query_records('proteccion-civil',p_type=>'Simulacro') as data")).rows[0].data.total,1);
civilSaved=await saveCivil(1,{...civil,document_type:'Visto bueno',authority:'Autoridad actualizada',department:'Oficinas',progress_percentage:80,next_action:'Entregar constancia'});
assert.equal(civilSaved.record.progress_percentage,80);
assert.equal(civilSaved.record.document_type,'Visto bueno');
assert.equal(civilSaved.history[1].snapshot.record.document_type,'Simulacro');
assert.equal(civilSaved.history[1].snapshot.record.authority,'Coordinación de prueba');
assert.equal(civilSaved.history[1].snapshot.record.department,'Patio de prueba');
await assert.rejects(()=>saveCivil(1),e=>e.code==='PT409');
for(const payload of [{...civil,document_type:'DC3'},{...civil,category:'seguridad-e-higiene'},...[-1,101,1.5,null].map(v=>({...civil,progress_percentage:v})),
  {...civil,start_date:'2027-01-01',expiration_date:'2026-01-01'}]) {
  await assert.rejects(()=>saveCivil(2,payload),e=>e.code==='23514');
}
assert.equal((await db.query('select public.documental_get_record($1) as data',[civilId])).rows[0].data.record.revision,2);
for(const type of ['Brigada','Capacitación','Dictamen','Plan de respuesta','Programa interno','Simulacro','Visto bueno']) {
  civilSaved=await saveCivil(civilSaved.record.revision,{...civil,document_type:type});
  assert.equal(civilSaved.record.document_type,type);
}
const contractId='00000000-0000-4000-8000-000000000100';
const contract={...procedure,category:'contratos',title:'Contrato de servicios',document_type:'Contrato',counterparty_name:'  Contraparte de prueba  ',reference:'CT-001',
  signature_date:'2026-01-10',issue_date:'2026-01-05',start_date:'2026-02-01',expiration_date:'2027-01-31',
  renewal_type:'Por acuerdo',renewal_date:'2027-01-01',renewal_notes:'  Aviso con treinta días  ',authority:'Notaría de prueba'};
const saveContract=async(revision,payload=contract)=>(await db.query(
  'select public.documental_save_record($1,$2,gen_random_uuid(),$3::jsonb) as data',[contractId,revision,JSON.stringify(payload)])).rows[0].data;
let contractSaved=await saveContract(0);
assert.equal(contractSaved.record.counterparty_name,'Contraparte de prueba');
assert.equal(contractSaved.record.signature_date,'2026-01-10');
assert.equal(contractSaved.record.issue_date,'2026-01-05','signature and issue dates are independent');
assert.equal(contractSaved.record.renewal_date,'2027-01-01');
assert.equal(contractSaved.record.expiration_date,'2027-01-31');
assert.equal(contractSaved.record.renewal_notes,'Aviso con treinta días');
for(const text of ['Contraparte de prueba','CT-001','treinta días']) {
  assert.equal((await query('contratos',null,text)).total,1);
  for(const category of ['documentacion-legal','permisos-y-tramites','seguridad-e-higiene','medio-ambiente','vehiculos','personal','proteccion-civil']) {
    assert.equal((await query(category,null,text)).total,0);
  }
}
contractSaved=await saveContract(1,{...contract,counterparty_name:'Contraparte renovada',signature_date:'2026-01-15',renewal_type:'Automática',renewal_date:'2027-01-15',renewal_notes:'Aviso con quince días',progress_percentage:80});
assert.equal(contractSaved.record.expiration_date,'2027-01-31','renewal must not shift validity dates');
assert.equal(contractSaved.history[1].snapshot.record.counterparty_name,'Contraparte de prueba');
assert.equal(contractSaved.history[1].snapshot.record.signature_date,'2026-01-10');
assert.equal(contractSaved.history[1].snapshot.record.renewal_type,'Por acuerdo');
assert.equal(contractSaved.history[1].snapshot.record.renewal_date,'2027-01-01');
assert.equal(contractSaved.history[1].snapshot.record.renewal_notes,'Aviso con treinta días');
await assert.rejects(()=>saveContract(1),e=>e.code==='PT409');
for(const payload of [{...contract,counterparty_name:' '},{...contract,counterparty_name:null},{...contract,document_type:'DC3'},{...contract,category:'personal'},
  {...contract,renewal_type:'Inventada'},{...contract,renewal_type:'No aplica'}, {...contract,progress_percentage:101},{...contract,start_date:'2028-01-01'}]) {
  await assert.rejects(()=>saveContract(2,payload),e=>e.code==='23514');
}
contractSaved=await saveContract(2,{...contract,signature_date:null,start_date:null,expiration_date:null,renewal_type:'No aplica',renewal_date:null,renewal_notes:''});
assert.equal(contractSaved.record.signature_date,null);
assert.equal(contractSaved.record.expiration_date,null,'unsigned or indefinite contracts can be tracked');
assert.equal(contractSaved.record.renewal_type,'No aplica');
assert.equal(contractSaved.record.renewal_date,null);
for(const type of ['Anexo','Contrato','Convenio','Renovación']) {
  contractSaved=await saveContract(contractSaved.record.revision,{...contract,document_type:type});
  assert.equal(contractSaved.record.document_type,type);
}
const insuranceId='00000000-0000-4000-8000-000000000110';
const insurance={...procedure,category:'seguros',title:'Seguro de flota',document_type:'Póliza',authority:'  Aseguradora de prueba  ',reference:'POL-110',
  insured_subject:'  Flota y operadores  ',coverage_description:'  Daños materiales y asistencia  ',start_date:'2026-01-01',expiration_date:'2026-12-31',
  renewal_type:'Por acuerdo',renewal_date:'2026-12-01',renewal_notes:'  Avisar al responsable  ',counterparty_name:'Ignorar',signature_date:'2026-01-02'};
const saveInsurance=async(revision,payload=insurance)=>(await db.query(
  'select public.documental_save_record($1,$2,gen_random_uuid(),$3::jsonb) as data',[insuranceId,revision,JSON.stringify(payload)])).rows[0].data;
let insuranceSaved=await saveInsurance(0);
assert.equal(insuranceSaved.record.authority,'Aseguradora de prueba');
assert.equal(insuranceSaved.record.insured_subject,'Flota y operadores');
assert.equal(insuranceSaved.record.coverage_description,'Daños materiales y asistencia');
assert.equal(insuranceSaved.record.counterparty_name,'');
assert.equal(insuranceSaved.record.signature_date,null);
assert.equal(insuranceSaved.record.renewal_date,'2026-12-01');
for(const text of ['Flota y operadores','POL-110','Aseguradora de prueba','Daños materiales']) {
  assert.equal((await query('seguros',null,text)).total,1);
  assert.equal((await query('contratos',null,text)).total,0);
}
insuranceSaved=await saveInsurance(1,{...insurance,insured_subject:'Instalación asegurada',coverage_description:'Incendio',renewal_type:'Automática',renewal_date:'2026-12-15'});
assert.equal(insuranceSaved.record.expiration_date,'2026-12-31');
assert.equal(insuranceSaved.history[1].snapshot.record.insured_subject,'Flota y operadores');
assert.equal(insuranceSaved.history[1].snapshot.record.coverage_description,'Daños materiales y asistencia');
assert.equal(insuranceSaved.history[1].snapshot.record.renewal_date,'2026-12-01');
await assert.rejects(()=>saveInsurance(1),e=>e.code==='PT409');
for(const payload of [{...insurance,authority:' '},{...insurance,insured_subject:null},{...insurance,insured_subject:' '},
  {...insurance,document_type:'Contrato'},{...insurance,document_type:null},{...insurance,renewal_type:'Inventada'},
  {...insurance,renewal_type:'No aplica'},{...insurance,progress_percentage:101},{...insurance,start_date:'2027-01-01'},
  {...insurance,category:'contratos',counterparty_name:'Contraparte'}]) {
  await assert.rejects(()=>saveInsurance(2,payload),e=>e.code==='23514');
}
assert.equal((await db.query('select public.documental_get_record($1) as data',[insuranceId])).rows[0].data.record.revision,2);
insuranceSaved=await saveInsurance(2,{...insurance,reference:'',coverage_description:'',start_date:null,expiration_date:null,renewal_type:'No aplica',renewal_date:null});
assert.equal(insuranceSaved.record.renewal_date,null);
assert.equal(insuranceSaved.record.coverage_description,'');
for(const type of ['Cobertura','Endoso','Póliza','Renovación']) {
  insuranceSaved=await saveInsurance(insuranceSaved.record.revision,{...insurance,document_type:type});
  assert.equal(insuranceSaved.record.document_type,type);
}
contractSaved=await saveContract(contractSaved.record.revision,{...contract,insured_subject:'Ignorar',coverage_description:'Ignorar'});
assert.equal(contractSaved.record.insured_subject,'');
assert.equal(contractSaved.record.coverage_description,'');
const maintenanceId='00000000-0000-4000-8000-000000000120';
const maintenance={...procedure,category:'mantenimiento',title:'Inspección de equipos',document_type:'Inspección periódica',reference:'MT-120',
  maintenance_subject:'  Equipos de planta  ',provider_name:'  Proveedor técnico  ',periodicity:'Trimestral',scheduled_date:'2026-09-20',performed_date:'2026-09-18',
  start_date:'2026-01-01',expiration_date:'2027-01-01',authority:'Certificador',renewal_type:'Automática',insured_subject:'Ignorar'};
const saveMaintenance=async(revision,payload=maintenance)=>(await db.query(
  'select public.documental_save_record($1,$2,gen_random_uuid(),$3::jsonb) as data',[maintenanceId,revision,JSON.stringify(payload)])).rows[0].data;
let maintenanceSaved=await saveMaintenance(0);
assert.equal(maintenanceSaved.record.maintenance_subject,'Equipos de planta');
assert.equal(maintenanceSaved.record.provider_name,'Proveedor técnico');
assert.equal(maintenanceSaved.record.periodicity,'Trimestral');
assert.equal(maintenanceSaved.record.scheduled_date,'2026-09-20');
assert.equal(maintenanceSaved.record.performed_date,'2026-09-18','completion can precede the planned date');
assert.equal(maintenanceSaved.record.expiration_date,'2027-01-01');
assert.equal(maintenanceSaved.record.renewal_type,'');
assert.equal(maintenanceSaved.record.insured_subject,'');
for(const text of ['Equipos de planta','MT-120','Proveedor técnico','Trimestral']) {
  assert.equal((await query('mantenimiento',null,text)).total,1);
  assert.equal((await query('seguros',null,text)).total,0);
}
maintenanceSaved=await saveMaintenance(1,{...maintenance,maintenance_subject:'Instalación norte',provider_name:'Proveedor renovado',periodicity:'Anual',scheduled_date:'2026-10-01',performed_date:'2026-10-02'});
assert.equal(maintenanceSaved.record.expiration_date,'2027-01-01','rescheduling must not change document expiry');
assert.equal(maintenanceSaved.history[1].snapshot.record.maintenance_subject,'Equipos de planta');
assert.equal(maintenanceSaved.history[1].snapshot.record.provider_name,'Proveedor técnico');
assert.equal(maintenanceSaved.history[1].snapshot.record.periodicity,'Trimestral');
assert.equal(maintenanceSaved.history[1].snapshot.record.scheduled_date,'2026-09-20');
assert.equal(maintenanceSaved.history[1].snapshot.record.performed_date,'2026-09-18');
await assert.rejects(()=>saveMaintenance(1),e=>e.code==='PT409');
for(const payload of [{...maintenance,maintenance_subject:' '},{...maintenance,maintenance_subject:null},
  {...maintenance,document_type:'Póliza'},{...maintenance,document_type:null},{...maintenance,periodicity:'Inventada'},
  {...maintenance,progress_percentage:101},{...maintenance,start_date:'2028-01-01'},{...maintenance,category:'seguros'}]) {
  await assert.rejects(()=>saveMaintenance(2,payload),e=>e.code==='23514');
}
assert.equal((await db.query('select public.documental_get_record($1) as data',[maintenanceId])).rows[0].data.record.revision,2);
maintenanceSaved=await saveMaintenance(2,{...maintenance,scheduled_date:null,performed_date:null,periodicity:'',provider_name:''});
assert.equal(maintenanceSaved.record.scheduled_date,null);
assert.equal(maintenanceSaved.record.performed_date,null);
assert.equal(maintenanceSaved.record.periodicity,'');
for(const type of ['Certificado','Contrato','Evidencia','Inspección periódica','Mantenimiento obligatorio','Programa']) {
  maintenanceSaved=await saveMaintenance(maintenanceSaved.record.revision,{...maintenance,document_type:type});
  assert.equal(maintenanceSaved.record.document_type,type);
}
const scheduleIds=['00000000-0000-4000-8000-000000000121','00000000-0000-4000-8000-000000000122'];
for(const [index,id] of scheduleIds.entries()) {
  await db.query('select public.documental_save_record($1,0,gen_random_uuid(),$2::jsonb)',[id,JSON.stringify({...maintenance,scheduled_date:index===0?'2026-09-01':null})]);
}
const scheduled=(await db.query("select public.documental_query_records('mantenimiento',p_sort=>'scheduled') as data")).rows[0].data;
assert.deepEqual(scheduled.records.map(r=>r.id),[scheduleIds[0],maintenanceId,scheduleIds[1]],'schedule order is ascending with undated records last');
insuranceSaved=await saveInsurance(insuranceSaved.record.revision,{...insurance,maintenance_subject:'Ignorar',scheduled_date:'2026-10-01',performed_date:'2026-10-02',provider_name:'Ignorar',periodicity:'Anual'});
assert.equal(insuranceSaved.record.maintenance_subject,'');
assert.equal(insuranceSaved.record.scheduled_date,null);
assert.equal(insuranceSaved.record.performed_date,null);
assert.equal(insuranceSaved.record.provider_name,'');
assert.equal(insuranceSaved.record.periodicity,'');
const auditId='00000000-0000-4000-8000-000000000130';
const audit={...procedure,category:'auditorias',title:'Auditoría de procesos',document_type:'Interna',reference:'AUD-130',
  authority:'  Organismo auditor  ',audit_result:'  Con observaciones  ',audit_findings:'  Falta evidencia de calibración  ',next_action:'Entregar plan correctivo',observations:'Revisión de equipos',
  scheduled_date:'2026-10-20',performed_date:'2026-10-18',start_date:'2026-01-01',expiration_date:'2027-01-01',
  maintenance_subject:'Ignorar',provider_name:'Ignorar',periodicity:'Anual'};
const saveAudit=async(revision,payload=audit)=>(await db.query(
  'select public.documental_save_record($1,$2,gen_random_uuid(),$3::jsonb) as data',[auditId,revision,JSON.stringify(payload)])).rows[0].data;
let auditSaved=await saveAudit(0);
assert.equal(auditSaved.record.authority,'Organismo auditor');
assert.equal(auditSaved.record.audit_result,'Con observaciones');
assert.equal(auditSaved.record.audit_findings,'Falta evidencia de calibración');
assert.equal(auditSaved.record.next_action,'Entregar plan correctivo');
assert.equal(auditSaved.record.observations,'Revisión de equipos');
assert.equal(auditSaved.record.scheduled_date,'2026-10-20');
assert.equal(auditSaved.record.performed_date,'2026-10-18');
assert.equal(auditSaved.record.maintenance_subject,'');
assert.equal(auditSaved.record.provider_name,'');
assert.equal(auditSaved.record.periodicity,'');
for(const text of ['Organismo auditor','AUD-130','Con observaciones','calibración','plan correctivo']) {
  assert.equal((await query('auditorias',null,text)).total,1);
  assert.equal((await query('mantenimiento',null,text)).total,0);
}
auditSaved=await saveAudit(1,{...audit,authority:'Organismo actualizado',audit_result:'No conforme',audit_findings:'Nueva observación',next_action:'Sustituir evidencia',scheduled_date:'2026-11-01',performed_date:'2026-11-02',status:'Completado',progress_percentage:100});
assert.equal(auditSaved.record.status,'Completado','process status and audit outcome are independent');
assert.equal(auditSaved.record.audit_result,'No conforme');
assert.equal(auditSaved.record.expiration_date,'2027-01-01');
assert.equal(auditSaved.history[1].snapshot.record.authority,'Organismo auditor');
assert.equal(auditSaved.history[1].snapshot.record.audit_result,'Con observaciones');
assert.equal(auditSaved.history[1].snapshot.record.audit_findings,'Falta evidencia de calibración');
assert.equal(auditSaved.history[1].snapshot.record.next_action,'Entregar plan correctivo');
assert.equal(auditSaved.history[1].snapshot.record.scheduled_date,'2026-10-20');
assert.equal(auditSaved.history[1].snapshot.record.performed_date,'2026-10-18');
await assert.rejects(()=>saveAudit(1),e=>e.code==='PT409');
for(const payload of [{...audit,authority:' '},{...audit,authority:null},{...audit,document_type:'Póliza'},
  {...audit,document_type:null},{...audit,audit_result:'Inventado'},{...audit,progress_percentage:101},
  {...audit,start_date:'2028-01-01'},{...audit,category:'mantenimiento'}]) {
  await assert.rejects(()=>saveAudit(2,payload),e=>e.code==='23514');
}
assert.equal((await db.query('select public.documental_get_record($1) as data',[auditId])).rows[0].data.record.revision,2);
auditSaved=await saveAudit(2,{...audit,scheduled_date:null,performed_date:null,audit_result:'',audit_findings:'',next_action:'',expiration_date:null});
assert.equal(auditSaved.record.scheduled_date,null);
assert.equal(auditSaved.record.performed_date,null);
assert.equal(auditSaved.record.audit_result,'');
assert.equal(auditSaved.record.audit_findings,'');
for(const type of ['Certificación','Externa','Interna','Regulatoria','Seguimiento']) {
  auditSaved=await saveAudit(auditSaved.record.revision,{...audit,document_type:type});
  assert.equal(auditSaved.record.document_type,type);
}
for(const result of ['Con observaciones','Conforme','No aplica','No conforme']) {
  auditSaved=await saveAudit(auditSaved.record.revision,{...audit,audit_result:result});
  assert.equal(auditSaved.record.audit_result,result);
}
const auditScheduleIds=['00000000-0000-4000-8000-000000000131','00000000-0000-4000-8000-000000000132'];
for(const [index,id] of auditScheduleIds.entries()) {
  await db.query('select public.documental_save_record($1,0,gen_random_uuid(),$2::jsonb)',[id,JSON.stringify({...audit,scheduled_date:index===0?'2026-09-01':null})]);
}
const auditScheduled=(await db.query("select public.documental_query_records('auditorias',p_sort=>'scheduled') as data")).rows[0].data;
assert.deepEqual(auditScheduled.records.map(r=>r.id),[auditScheduleIds[0],auditId,auditScheduleIds[1]]);
maintenanceSaved=await saveMaintenance(maintenanceSaved.record.revision,{...maintenance,audit_result:'Conforme',audit_findings:'Ignorar'});
assert.equal(maintenanceSaved.record.audit_result,'');
assert.equal(maintenanceSaved.record.audit_findings,'');
// Isolated overview fixture; rollback preserves the category/access fixtures.
await db.exec('begin; reset role; truncate public.documental_records cascade; set role authenticated;');
const dash=async()=>(await db.query('select public.documental_dashboard() as data')).rows[0].data;
const cal=async(params={})=>{
  const {month=null,day=null,category=null,status=null,responsible=null,kind=null,page=0}=params;
  return (await db.query('select public.documental_calendar($1::date,$2::date,$3,$4,$5::uuid,$6,$7) as data',[month,day,category,status,responsible,kind,page])).rows[0].data;
};
const overviewToday=(await dash()).context.today;
const offsetDay=(n)=>new Date(Date.parse(overviewToday+'T12:00:00Z')+n*86400000).toISOString().slice(0,10);
assert.deepEqual((await dash()).metrics,{active:0,upcoming:0,critical:0,expired:0,pending_procedures:0,in_progress_procedures:0});
assert.equal((await cal()).total,0);
assert.equal((await cal()).selected,overviewToday);
const saveOverview=async(payload, id=null,revision=0)=>(await db.query(
  'select public.documental_save_record(coalesce($1::uuid,gen_random_uuid()),$2,gen_random_uuid(),$3::jsonb) as data',
  [id,revision,JSON.stringify({category:'documentacion-legal',title:'Límite',document_type:'Escritura',responsible_user_id:documental,status:'Pendiente',priority:'Media',...payload})])).rows[0].data;
for(const day of [-1,0,5,6,15,16,null]) await saveOverview({title:`Límite ${day}`,expiration_date:day===null?null:offsetDay(day)});
for(const [status,day] of [['Completado',-1],['Cancelado',0],['No aplica',-1]]) await saveOverview({status,expiration_date:offsetDay(day)});
await saveOverview({category:'permisos-y-tramites',document_type:'Trámite',progress_percentage:10});
await saveOverview({category:'permisos-y-tramites',document_type:'Trámite',status:'En proceso',progress_percentage:30,expiration_date:offsetDay(15)});
const overview=await dash();
assert.deepEqual(overview.metrics,{active:9,upcoming:5,critical:2,expired:1,pending_procedures:1,in_progress_procedures:1});
assert.deepEqual(overview.categories['documentacion-legal'],{total:10,upcoming:4,expired:1,pending:7});
assert.equal((await cal({day:overviewToday})).total,2,'calendar retains cancelled history');
assert.equal((await cal({day:overviewToday,status:'Pendiente'})).total,1);
assert.equal((await cal({day:overviewToday,status:'Cancelado'})).total,1);
for(let index=0;index<55;index++) await saveOverview({title:'Paginada',reference:String(index).padStart(3,'0'),responsible_user_id:manager,expiration_date:overviewToday});
const overviewLarge=await dash();
assert.equal(overviewLarge.metrics.active,64,'dashboard counts are not limited to 50 rows');
assert.equal(overviewLarge.upcoming.length,12);
assert.equal(overviewLarge.upcoming_total,61,'preview total includes all future dates in 30 days');
assert.equal(overviewLarge.upcoming.some(e=>['Completado','Cancelado','No aplica'].includes(e.record.status)),false);
const firstAgenda=await cal({responsible:manager});
const lastAgenda=await cal({responsible:manager,page:1});
assert.equal(firstAgenda.total,55); assert.equal(firstAgenda.events.length,50); assert.equal(lastAgenda.events.length,5);
assert.equal(firstAgenda.days[overviewToday],55); assert.equal(firstAgenda.month_total,55);
assert.equal(new Set([...firstAgenda.events,...lastAgenda.events].map(e=>e.record.id+e.event_kind)).size,55);
assert.deepEqual([...firstAgenda.events,...lastAgenda.events].map(e=>e.record.reference),Array.from({length:55},(_,i)=>String(i).padStart(3,'0')));
assert.equal((await cal({kind:'renovacion'})).total,0);
const policyPayload={category:'seguros',title:'Póliza bisiesta',document_type:'Póliza',authority:'Aseguradora',insured_subject:'Equipo',progress_percentage:20,
  start_date:'2028-02-29',expiration_date:'2028-03-01',renewal_type:'Por acuerdo',renewal_date:'2028-02-29'};
const policyOverview=await saveOverview(policyPayload);
let leap=await cal({month:'2028-02-01',day:'2028-02-29',category:'seguros'});
assert.equal(leap.month_total,2); assert.equal(leap.total,2);
assert.deepEqual(new Set(leap.events.map(e=>e.event_kind)),new Set(['inicio','renovacion']));
assert.equal((await cal({month:'2028-03-01',day:'2028-03-01',category:'seguros'})).total,1);
await saveOverview({...policyPayload,renewal_type:'No aplica',renewal_date:null},policyOverview.record.id,1);
leap=await cal({month:'2028-02-01',day:'2028-02-29',category:'seguros'});
assert.equal(leap.total,1,'calendar immediately drops a retired renewal date');
assert.equal(leap.events[0].event_kind,'inicio');
const categoryFixtures={
  'documentacion-legal':{document_type:'Escritura'},'permisos-y-tramites':{document_type:'Trámite'},
  'seguridad-e-higiene':{document_type:'Estudio'},'medio-ambiente':{document_type:'Agua'},'vehiculos':{document_type:'Seguro'},
  'personal':{document_type:'Constancia'},'proteccion-civil':{document_type:'Simulacro'},
  'contratos':{document_type:'Contrato',counterparty_name:'Contraparte'},
  'seguros':{document_type:'Póliza',insured_subject:'Equipo'},
  'mantenimiento':{document_type:'Programa',maintenance_subject:'Equipo',scheduled_date:'2028-01-12',performed_date:'2028-01-11'},
  'auditorias':{document_type:'Interna',scheduled_date:'2028-01-12',performed_date:'2028-01-11'},
};
let overviewAudit;
for(const [category,fields] of Object.entries(categoryFixtures)) {
  const payload={...fields,category,title:category,authority:'Entidad',progress_percentage:10,expiration_date:'2028-01-12'};
  const saved=await saveOverview(payload);
  if(category==='auditorias') overviewAudit={payload,saved};
  assert.equal((await cal({month:'2028-01-01',day:'2028-01-12',category,kind:'vencimiento'})).total,1);
}
const everyCategory=await cal({month:'2028-01-01',day:'2028-01-12'});
assert.equal(everyCategory.total,13); assert.equal(new Set(everyCategory.events.map(e=>e.record.category)).size,11);
assert.equal((await cal({month:'2028-01-01',day:'2028-01-11',kind:'realizacion'})).total,2);
await saveOverview({...overviewAudit.payload,scheduled_date:'2028-01-13',performed_date:'2028-01-12'},overviewAudit.saved.record.id,1);
const moved=await cal({month:'2028-01-01',day:'2028-01-12',category:'auditorias'});
assert.deepEqual(new Set(moved.events.map(e=>e.event_kind)),new Set(['realizacion','vencimiento']));
assert.equal((await cal({month:'2028-01-01',day:'2028-01-13',category:'auditorias',kind:'programacion'})).total,1);
for(const params of [{month:'2028-01-01',day:'2028-02-01'},{category:'inventada'},{kind:'inventado'},{status:'inventado'},{page:-1}]) {
  await db.exec('savepoint invalid_calendar');
  await assert.rejects(()=>cal(params),e=>e.code==='23514');
  await db.exec('rollback to savepoint invalid_calendar; release savepoint invalid_calendar;');
}
await assert.rejects(()=>db.query('select * from public.documental_event_dates(null::public.documental_records)'),e=>e.code==='42501');
await db.exec('rollback;');
await db.exec(`reset role; update public.profiles set is_active=false where user_id='${documental}'; set role authenticated;`);
assert.equal((await db.query('select public.documental_can_manage() as allowed')).rows[0].allowed,false);
assert.equal((await db.query('select * from public.documental_records')).rows.length,0);
assert.equal((await db.query("select * from storage.objects where bucket_id='documental'")).rows.length,0);
await assert.rejects(()=>query('documentacion-legal'),e=>e.code==='42501');
await assert.rejects(()=>db.query('select public.documental_safety_context()'),e=>e.code==='42501');
await assert.rejects(()=>saveSafety(3),e=>e.code==='42501');
await assert.rejects(()=>saveEnvironment(3),e=>e.code==='42501');
await assert.rejects(()=>db.query('select public.documental_vehicle_context()'),e=>e.code==='42501');
await assert.rejects(()=>db.query('select public.documental_personnel_context()'),e=>e.code==='42501');
await assert.rejects(()=>query('proteccion-civil'),e=>e.code==='42501');
await assert.rejects(()=>query('contratos'),e=>e.code==='42501');
await assert.rejects(()=>query('seguros'),e=>e.code==='42501');
await assert.rejects(()=>query('mantenimiento'),e=>e.code==='42501');
await assert.rejects(()=>query('auditorias'),e=>e.code==='42501');
await assert.rejects(()=>dash(),e=>e.code==='42501');
await assert.rejects(()=>cal(),e=>e.code==='42501');
await assert.rejects(()=>saveAudit(12),e=>e.code==='42501');
await assert.rejects(()=>saveMaintenance(9),e=>e.code==='42501');
await assert.rejects(()=>saveInsurance(7),e=>e.code==='42501');
await assert.rejects(()=>saveVehicle(5),e=>e.code==='42501');
await assert.rejects(()=>savePersonnel(4),e=>e.code==='42501');
await assert.rejects(()=>saveCivil(9),e=>e.code==='42501');
await assert.rejects(()=>saveContract(7),e=>e.code==='42501');
await assert.rejects(()=>saveProcedure(3),e=>e.code==='42501');

await db.query("select set_config('request.jwt.claim.sub',$1,false)",[viewer]);
assert.equal((await db.query('select * from public.documental_records')).rows.length,0);
assert.equal((await db.query("select * from storage.objects where bucket_id='documental'")).rows.length,0);
await assert.rejects(()=>db.query('select public.documental_context()'),e=>e.code==='42501');
await assert.rejects(()=>db.query('select public.documental_vehicle_context()'),e=>e.code==='42501');
await assert.rejects(()=>db.query('select public.documental_personnel_context()'),e=>e.code==='42501');
await assert.rejects(()=>query('proteccion-civil'),e=>e.code==='42501');
await assert.rejects(()=>query('contratos'),e=>e.code==='42501');
await assert.rejects(()=>query('seguros'),e=>e.code==='42501');
await assert.rejects(()=>query('mantenimiento'),e=>e.code==='42501');
await assert.rejects(()=>query('auditorias'),e=>e.code==='42501');
await assert.rejects(()=>dash(),e=>e.code==='42501');
await assert.rejects(()=>cal(),e=>e.code==='42501');
await assert.rejects(()=>saveAudit(12),e=>e.code==='42501');
await assert.rejects(()=>saveMaintenance(9),e=>e.code==='42501');
await assert.rejects(()=>saveInsurance(7),e=>e.code==='42501');
await assert.rejects(()=>save(2,'00000000-0000-4000-8000-000000000024'),e=>e.code==='42501');
await db.exec('reset role; set role anon;');
await assert.rejects(()=>dash(),e=>e.code==='42501');
await assert.rejects(()=>cal(),e=>e.code==='42501');
assert.equal((await db.query("select * from storage.objects where bucket_id='documental'")).rows.length,0);
await db.close();
console.log('SQL: dashboard counts, urgency boundaries, closed statuses, derived calendar dates, all categories, pagination, filters, leap dates, rescheduling and access, audit types, organizations, independent outcomes, findings, pending actions, scheduling and historical versions, maintenance scope, providers, periodicity, scheduling, performance dates and immutable history, insurance insurer, policy, insured subject, coverage, renewal, history and validation, contract counterparties, signature and renewal dates, terms and version history, civil protection types, authority, area, progress, history, personnel identity, inactive workers, worker snapshots, vehicle identity, fleet scope, catalog changes, safety, environment, procedures, progress bounds, category isolation, pagination, legacy compatibility, creation, atomic save, idempotent retry, conflict, versions, filters, RLS and private immutable files passed.');
