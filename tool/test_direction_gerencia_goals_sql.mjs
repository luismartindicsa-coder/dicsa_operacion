import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const user = '00000000-0000-4000-8000-000000000001';
const uuid = n => `00000000-0000-4000-9000-${String(n).padStart(12, '0')}`;
const migrate = async name => db.exec(await readFile(new URL(`../supabase/migrations/${name}.sql`, import.meta.url), 'utf8'));
await db.exec(`
  create role authenticated; create role anon; create schema auth;
  create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
  grant usage on schema auth to authenticated;
  create function set_updated_at_v2() returns trigger language plpgsql as $$begin new.updated_at=now(); return new; end;$$;
  create table profiles(user_id uuid primary key,role text,is_active boolean);
  insert into profiles values('${user}','direccion',true);
  create table direction_shipment_plans(id uuid primary key,ship_date date,client_name text,planning_material_code text,planned_units integer,priority text,status text,quantity_unit text);
  create table direction_production_capacity_impacts(machine_key text,start_date date,end_date date,impact_percent integer,is_active boolean);
  select set_config('request.jwt.claim.sub','${user}',false);
`);
await migrate('20260628113000_create_gerencia_bale_weekly_plans');
await migrate('20260728123000_add_gerencia_weekly_summary_snapshots');
await migrate('20260915100000_create_direction_operating_programs');
const current = (await db.query("select date_trunc('week',now() at time zone 'America/Mexico_City')::date::text as d")).rows[0].d;
const offset = (date, days) => new Date(Date.parse(date) + days * 86400000).toISOString().slice(0,10);
const material = ['PACA_NACIONAL','PACA_LIMPIA','PACA_AMERICANA'];
const conditions = {daily_capacity:100,day_share:50,yard:{PACA_NACIONAL:10,PACA_LIMPIA:0,PACA_AMERICANA:5},days:Array.from({length:5},()=>({working:true,day_available:true,night_available:true,loss_percent:0}))};
const production = (cells = [[0,'DAY',0,30]]) => Array.from({length:5},(_,day_index)=>['DAY','NIGHT'].flatMap(shift=>material.map((material_code,i)=>({day_index,shift,material_code,quantity:cells.find(c=>c[0]===day_index&&c[1]===shift&&c[2]===i)?.[3] ?? 0})))).flat();
let shipmentId = 100;
async function source(week, demands = [[0,0,40]]) {
  await db.exec('reset role');
  await db.query('delete from direction_shipment_plans where ship_date between $1::date and $1::date+6',[week]);
  for (const [day,m,qty,status='confirmado',unit='PACAS'] of demands) {
    await db.query('insert into direction_shipment_plans values($1,$2,$3,$4,$5,$6,$7,$8)',[uuid(shipmentId++),offset(week,day),'CLIENTE',material[m],qty,'normal',status,unit]);
  }
  const result = (await db.query('select direction_program_source($1) as s',[week])).rows[0].s;
  await db.exec('set role authenticated');
  return result;
}
async function save(n,week,version,demands,lines=production()) {
  return (await db.query('select direction_save_operating_program($1,$2,$3,$4,$5,$6) as p',[uuid(n),week,version,conditions,demands,lines])).rows[0].p;
}
async function approve(n,execute=false) {
  return (await db.query('select direction_approve_operating_program($1,$2) as p',[uuid(n),execute])).rows[0].p;
}
async function plan(week=current) {
  return (await db.query('select * from gerencia_bale_weekly_plans where week_start_date=$1',[week])).rows[0];
}
async function targets(week=current) {
  return (await db.query('select l.* from gerencia_bale_weekly_plan_lines l join gerencia_bale_weekly_plans p on p.id=l.plan_id where p.week_start_date=$1 order by bale_type_key',[week])).rows;
}
// Existing approved weeks: current/future must become linked, history/closed not.
const dates = [offset(current,-7),current,offset(current,7),offset(current,14)];
for (let i=0;i<dates.length;i++) {
  const s = await source(dates[i]);
  await save(i+1,dates[i],0,s);
  await approve(i+1);
}
await db.query("insert into gerencia_bale_weekly_plans(week_start_date,week_end_date,status,closed_at) values($1::date,$1::date+5,'cerrada',now())",[dates[3]]);
await db.exec('reset role');
await migrate('20260921200000_sync_operating_program_gerencia_goals');
await db.exec('set role authenticated');
assert.equal(await plan(dates[0]),undefined,'historical programs do not rewrite historical targets');
assert.equal((await plan()).source_operating_program_id,uuid(2));
assert.equal((await plan(dates[2])).source_operating_program_id,uuid(3));
assert.equal((await plan(dates[3])).source_operating_program_id,null,'closed weeks are preserved by backfill');
assert.deepEqual((await targets()).map(l=>[l.bale_type_key,l.production_target_bales,l.shipment_target_bales]),[
  ['americano',0,0],['limpio',0,0],['revuelto',30,40],
]);
const original = await plan();
const initialLines = await targets();
await db.query("update gerencia_bale_weekly_plans set notes='Conservar',status='en_curso',snapshot_production_actual_bales=12,snapshot_shipment_actual_bales=8 where id=$1",[original.id]);
await db.query("update gerencia_bale_weekly_plan_lines set notes='Nota ejecutiva' where plan_id=$1",[original.id]);
const s2 = await source(current,[[4,0,60],[1,1,20],[4,2,35],[0,0,999,'planeado'],[5,0,999],[0,0,999,'confirmado','KG']]);
const cells2 = [[1,'DAY',1,20],[3,'DAY',0,50],[3,'NIGHT',2,30]];
await save(5,current,1,s2,production(cells2));
assert.equal((await plan()).source_operating_program_id,uuid(2),'a saved draft must not change goals');
await approve(5);
const linked = await plan();
assert.equal(linked.id,original.id,'one Gerencia plan per week');
assert.equal(linked.source_operating_program_version,2);
assert.equal(linked.source_operating_program_id,uuid(5));
assert.equal(linked.status,'en_curso');
assert.equal(linked.notes,'Conservar');
assert.equal(linked.snapshot_production_actual_bales,12);
assert.equal(linked.snapshot_shipment_actual_bales,8);
assert.equal(linked.snapshot_production_target_bales,100);
assert.equal(linked.snapshot_shipment_target_bales,115);
assert.deepEqual((await targets()).map(l=>[l.bale_type_key,l.production_target_bales,l.shipment_target_bales]),[
  ['americano',30,35],['limpio',20,20],['revuelto',50,60],
]);
assert.deepEqual((await targets()).map(l=>l.id),initialLines.map(l=>l.id),'upsert preserves goal IDs and notes');
assert.ok((await targets()).every(l=>l.notes==='Nota ejecutiva'));
await approve(5,true);
await approve(5,true);
assert.deepEqual((await plan()).operating_program_synced_at,linked.operating_program_synced_at,'starting/retrying execution never accumulates targets');
await assert.rejects(()=>db.query('update gerencia_bale_weekly_plan_lines set production_target_bales=999 where plan_id=$1',[linked.id]),e=>e.code==='PT409');
await assert.rejects(()=>db.query('delete from gerencia_bale_weekly_plan_lines where plan_id=$1',[linked.id]),e=>e.code==='PT409');
await db.query("update gerencia_bale_weekly_plan_lines set notes='Nueva nota' where plan_id=$1",[linked.id]);
await assert.rejects(()=>db.query('select direction_sync_gerencia_goals($1)',[uuid(5)]),e=>e.code==='42501','private sync cannot bypass approval');
// Reapproval clears a removed material and uses programmed production including
// reserve production, rather than deriving production targets from shipments.
const s3 = await source(current,[[4,0,60],[1,1,20]]);
await save(6,current,2,s3,production([[1,'DAY',1,20],[3,'DAY',0,50],[3,'NIGHT',0,5]]));
assert.equal((await targets())[0].shipment_target_bales,35);
await approve(6);
assert.deepEqual((await targets()).map(l=>[l.production_target_bales,l.shipment_target_bales]),[[0,0],[20,20],[55,60]]);
assert.equal((await plan()).snapshot_production_target_bales,75);
assert.equal((await plan()).snapshot_shipment_target_bales,80);
// Failures roll back BOTH program promotion and the goal changes.
await save(7,current,3,s3,production([[1,'DAY',1,20],[3,'DAY',0,50]]));
await db.query("update gerencia_bale_weekly_plans set status='cerrada',closed_at=now() where id=$1",[linked.id]);
await assert.rejects(()=>approve(7),e=>e.code==='PT409'&&e.message.includes('cerrada'));
assert.equal((await plan()).source_operating_program_id,uuid(6));
const programs = (await db.query('select id,status,is_operational from direction_operating_programs where week_start=$1 order by version',[current])).rows;
assert.equal(programs.find(p=>p.id===uuid(6)).is_operational,true);
assert.equal(programs.find(p=>p.id===uuid(7)).status,'draft');
assert.equal((await plan()).snapshot_production_target_bales,75);
await db.query("update gerencia_bale_weekly_plans set status='en_curso',closed_at=null where id=$1",[linked.id]);
await source(current,[[4,0,61],[1,1,20]]);
await assert.rejects(()=>approve(7),e=>e.code==='PT409');
assert.equal((await plan()).source_operating_program_id,uuid(6));
// A new week's first approval creates the plan and all three material rows.
const freshWeek = offset(current,21);
await save(8,freshWeek,0,await source(freshWeek));
assert.equal(await plan(freshWeek),undefined);
await approve(8);
assert.equal((await plan(freshWeek)).source_operating_program_id,uuid(8));
assert.equal((await targets(freshWeek)).length,3);
console.log('Gerencia goals SQL passed: backfill, approval-only sync, material/shift totals, yard, scope, version replacement, zeroed removed materials, snapshots, notes, immutability, permissions, closed/stale rollback, automatic plan creation.');
await db.close();
