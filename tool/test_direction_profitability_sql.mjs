import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const uid='00000000-0000-4000-8000-000000000001';
await db.exec(`create role authenticated; create role anon; create schema auth;
create table auth.users(id uuid primary key); insert into auth.users values('${uid}');
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create function public.direction_program_can_manage() returns boolean language sql stable as $$select current_setting('test.manage',true)='yes'$$;
select set_config('request.jwt.claim.sub','${uid}',false); select set_config('test.manage','yes',false);`);
await db.exec(await readFile(new URL('../supabase/migrations/20260922000000_create_direction_profitability.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20260922020000_extend_profitability_executive.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20260922030000_profitability_operational_accounts.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../supabase/migrations/20260922040000_profitability_inference_correction.sql',import.meta.url),'utf8'));
await db.exec('set role authenticated');
const signature='a'.repeat(64);
const config={identities:{'compras:1':'site:1'},recipes:{'site:1|compras:carton':{outputs:[{benchmark:'ventas:paca',yield:0.8}],note:'Ensayo'}},costs:{'cash:1':{treatment:'include',kind:'fuel',shares:{'site:1':0.4,'site:2':0.6},amount:100,note:'Comprobante',source_signature:signature,estimated:true}},companies:{},excluded_purchases:{}};
const save=(revision,c=config,start='2026-09-11',end='2026-09-17')=>db.query('select direction_save_profitability_review($1,$2,$3,$4) as p',[start,end,revision,JSON.stringify(c)]);
let row=(await save(0)).rows[0].p;
assert.equal(row.revision,1); assert.equal(row.updated_by,uid);
await assert.rejects(()=>save(0),e=>e.code==='PT409');
for(const mutate of [
 c=>c.identities['site:1']='compras:1',
 c=>c.costs['cash:1'].shares['site:1']=0.5,
 c=>c.costs['cash:1'].shares['site:1']=-0.4,
 c=>c.costs['cash:1'].amount=-1,
 c=>c.costs['cash:1'].note='',
 c=>c.costs['cash:1'].source_signature='',
 c=>c.recipes['site:1|compras:carton'].outputs[0].yield=1.2,
 c=>c.recipes['site:1|compras:carton'].outputs.push({benchmark:'ventas:paca',yield:0.1}),
 c=>c.companies['site:1']={note:'Incomplete'},
 c=>c.excluded_purchases['ticket:1']={signature,note:''},
 c=>c.extra={},
]){const c=structuredClone(config); mutate(c); await assert.rejects(()=>save(1,c));}
await assert.rejects(()=>save(1,config,'2026-09-18','2026-09-17'));
assert.equal((await db.query('select revision from direction_profitability_reviews')).rows[0].revision,1);
const payload={engine_version:1,start:'2026-09-11',end:'2026-09-17',review_revision:1,config,evidence_signature:signature,companies:[],issues:['Pendiente']};
const snapshot=(revision,p=payload)=>db.query('select direction_save_profitability_snapshot($1,$2,$3,$4) as id',['2026-09-11','2026-09-17',revision,JSON.stringify(p)]);
const snapshotId=(await snapshot(1)).rows[0].id; assert.ok(snapshotId);
await assert.rejects(()=>snapshot(0),e=>e.code==='PT409');
await assert.rejects(()=>snapshot(1,{...payload,config:{}}));
await save(1,{...config,identities:{}});
const old=(await db.query('select payload from direction_profitability_snapshots where id=$1',[snapshotId])).rows[0].payload;
assert.deepEqual(old.config,config,'historical evidence stays immutable');
for(const table of ['direction_profitability_reviews','direction_profitability_snapshots']) {
 await assert.rejects(()=>db.query(`delete from ${table}`),e=>e.code==='42501');
 await assert.rejects(()=>db.query(`update ${table} set period_end=period_end+1`),e=>e.code==='42501');
}
// Effective-dated masters: persistent across periods, CAS, read-only history.
const rules = [
  {id:'identity-a',kind:'identity',valid_from:'2026-09-01',valid_to:null,note:'Aprobación',data:{site:'site:norte',company_group:'MONROE',compras_supplier_id:'1',aliases:'MONROE NORTE'}},
  {id:'identity-b',kind:'identity',valid_from:'2026-09-01',valid_to:null,note:'Aprobación',data:{site:'site:sur',company_group:'MONROE',compras_supplier_id:'2',aliases:'MONROE SUR'}},
  {id:'truck',kind:'vehicle',valid_from:'2026-09-01',valid_to:null,note:'Costo probado',data:{unit:'type:TRAILER',fuel_cost_per_km:6}},
];
const saveMaster=(rev,config={rules})=>db.query('select direction_save_profitability_master($1,$2) as p',[rev,JSON.stringify(config)]);
assert.equal((await saveMaster(0)).rows[0].p.revision,1);
await assert.rejects(()=>saveMaster(0),e=>e.code==='PT409');
for(const change of [
  r=>r[1].data.aliases='MONROE NORTE',
  r=>r[1].data.compras_supplier_id='1',
  r=>r[0].data.site='group:MONROE',
  r=>r[2].data.fuel_cost_per_km=-1,
  r=>r[2].valid_to='2026-08-31',
  r=>r.push({...r[2],id:'truck-overlap'}),
]) {const copy=structuredClone(rules);change(copy);await assert.rejects(()=>saveMaster(1,{rules:copy}));}
const v2={...payload,engine_version:2,review_revision:2,config:{...config,identities:{}},master_revision:1,master_config:{rules},shared_cost_review_evidence:[]};
assert.ok((await snapshot(2,v2)).rows[0].id);
await saveMaster(1,{rules:[]});
await assert.rejects(()=>snapshot(2,v2),e=>e.code==='PT409');
assert.deepEqual((await db.query('select config from direction_profitability_master_history where revision=1')).rows[0].config,{rules});
for(const table of ['direction_profitability_master','direction_profitability_master_history']) {
 await assert.rejects(()=>db.query(`delete from ${table}`),e=>e.code==='42501');
}
const invalidCoverage=structuredClone(config);invalidCoverage.costs['cash:1'].coverage_start='2026-09-01';
await assert.rejects(()=>save(2,invalidCoverage));
invalidCoverage.costs['cash:1'].coverage_end='2026-08-01';
await assert.rejects(()=>save(2,invalidCoverage));
const accountRule={id:'container',kind:'account',valid_from:'2026-09-01',valid_to:null,note:'Contrato de prueba SQL',data:{company:'site:norte',line:'Contenedores',block:'containers',basis:'monthly',rate:3000,quantity:2}};
for (const change of [r=>r.data.rate=-1,r=>r.data.quantity=null,r=>r.data.basis='unknown',r=>r.data.block='unknown',r=>r.data.line='']) {
 const r=structuredClone(accountRule);change(r);await assert.rejects(()=>saveMaster(2,{rules:[r]}));
}
await assert.rejects(()=>saveMaster(2,{rules:[accountRule,{...accountRule,id:'overlap'}]}));
assert.equal((await saveMaster(2,{rules:[accountRule]})).rows[0].p.revision,3);
const v3={...v2,engine_version:3,inference_model:'operational-account-v1',master_revision:3,master_config:{rules:[accountRule]}};
assert.ok((await snapshot(2,{...v3,inference_model:'operational-account-v2'})).rows[0].id);
assert.ok((await snapshot(2,v3)).rows[0].id);
await assert.rejects(()=>snapshot(2,{...v3,inference_model:'fake'}));
assert.deepEqual((await db.query('select payload from direction_profitability_snapshots where id=$1',[snapshotId])).rows[0].payload,old);
await db.query("select set_config('test.manage','no',false)");
assert.equal((await db.query('select * from direction_profitability_reviews')).rows.length,0);
assert.equal((await db.query('select * from direction_profitability_snapshots')).rows.length,0);
assert.equal((await db.query('select * from direction_profitability_master')).rows.length,0);
await assert.rejects(()=>saveMaster(2),e=>e.code==='42501');
await assert.rejects(()=>save(2),e=>e.code==='42501');
await assert.rejects(()=>snapshot(2),e=>e.code==='42501');
await db.exec('set role anon'); await assert.rejects(()=>save(2),e=>e.code==='42501');
await db.close();
console.log('PASS: profitability permissions, revision conflicts, atomic validation, percentages, immutable historical cuts.');
