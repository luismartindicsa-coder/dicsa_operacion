import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';

const { PGlite } = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const rh = id(1), direction = id(2), payroll = id(3), viewer = id(4), missing = id(5);

await db.exec(`
  create role authenticated; create role anon; create schema auth;
  create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
  $$;
  create function auth.jwt() returns jsonb language sql stable as $$
    select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb
  $$;
  grant usage on schema auth to authenticated;
  create table auth.users(id uuid primary key, email text);
  create table public.profiles(user_id uuid primary key, role text, is_active boolean);
  create table public.hr_employee_profiles(id text primary key);
  insert into auth.users values
    ('${rh}','rh@dicsamx.com'), ('${direction}','direccion@dicsamx.com'),
    ('${payroll}','nominas@example.test'), ('${viewer}','viewer@example.test'),
    ('${missing}','otro@example.test');
  insert into profiles values ('${payroll}','Recursos-Humanos',true), ('${viewer}','viewer',true);
  insert into hr_employee_profiles values ('test-employee');
`);
const migration = name => readFile(new URL(`../supabase/migrations/${name}.sql`, import.meta.url), 'utf8');
await db.exec(await migration('20260909210000_create_hr_termination_calculations'));

const session = async (user, email) => {
  await db.exec('set role authenticated');
  await db.query("select set_config('request.jwt.claim.sub',$1,false), set_config('request.jwt.claims',$2,false)",
    [user, JSON.stringify({sub: user, email})]);
};
const allowed = async () => (await db.query('select hr_can_access_termination_calculations() as allowed')).rows[0].allowed;
await session(rh, 'rh@dicsamx.com');
assert.equal(await allowed(), false, 'reproduce rejection of the RH account without a profile');
await db.exec('reset role');
await db.exec(await migration('20260917150000_fix_hr_termination_email_access'));

const inputs = {mode:'finiquito', start_date:'2026-01-01', end_date:'2026-09-17',
  formula_version:'test', official_isr:'0', isr_reference:'Referencia de prueba', history_reviewed:true};
const result = {lines:[], gross:{base:100,flow:0,total:100}, deductions:{base:0,flow:0,total:0},
  pending:[], net:{base:100,flow:0,total:100}};
const save = async (status='borrador', savedResult=result) => (await db.query(`
  insert into hr_employee_termination_calculations
    (employee_id,employee_name,mode,status,start_date,end_date,formula_version,inputs,result,source_snapshot,created_by)
  values ('test-employee','Prueba','finiquito',$1,'2026-01-01','2026-09-17','test',$2::jsonb,$3::jsonb,
    '{"personal":{"id":"test-employee"}}'::jsonb,$4)
  returning revision,created_by,status
`, [status, JSON.stringify(inputs), JSON.stringify(savedResult), viewer])).rows[0];
const visible = async () => (await db.query('select count(*)::int as n from hr_employee_termination_calculations')).rows[0].n;

await session(rh, 'rh@dicsamx.com');
assert.equal(await allowed(), true);
assert.deepEqual(await save(), {revision:1,created_by:rh,status:'borrador'});
assert.deepEqual(await save('revisado'), {revision:2,created_by:rh,status:'revisado'});
assert.equal(await visible(), 2);
await assert.rejects(() => save('revisado', {...result, net:null, pending:['Falta ISR']}), e => e.code === '23514');
await assert.rejects(() => db.exec("update hr_employee_termination_calculations set employee_name='Cambio'"), e => e.code === '42501');
await assert.rejects(() => db.exec('delete from hr_employee_termination_calculations'), e => e.code === '42501');

for (const [user,email] of [[direction,'direccion@dicsamx.com'],[payroll,'nominas@example.test']]) {
  await session(user,email);
  assert.equal(await allowed(), true);
  assert.equal((await save()).created_by, user);
}
for (const user of [viewer,missing]) {
  // A client-supplied RH email cannot impersonate the real authenticated account.
  await session(user,'rh@dicsamx.com');
  assert.equal(await allowed(), false);
  assert.equal(await visible(), 0);
  await assert.rejects(() => save(), e => e.code === '42501');
}

await db.exec(`reset role; insert into profiles values ('${rh}','rh',false);`);
await session(rh,'rh@dicsamx.com');
assert.equal(await allowed(), false, 'an explicitly inactive RH profile stays blocked');
assert.equal(await visible(), 0);
await assert.rejects(() => save(), e => e.code === '42501');
await session('','rh@dicsamx.com');
assert.equal(await allowed(), false, 'a session identity is required');
await db.exec('reset role; set role anon;');
await assert.rejects(() => allowed(), e => e.code === '42501');
await assert.rejects(() => visible(), e => e.code === '42501');

await db.close();
console.log('HR termination SQL: missing RH/Direction profiles, role normalization, drafts, reviewed versions, immutable history, authorship, incomplete reviews, inactive profiles and unauthorized accounts passed.');
