import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const {PGlite} = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
await db.exec(`
  create schema auth;
  create table auth.users(id uuid primary key, email text, encrypted_password text);
  create table profiles(user_id uuid primary key references auth.users(id), role text,
    is_active boolean, constraint profiles_role_check check(role in ('viewer','admin','services','gestion_documental','custom_existing_role')));
  insert into auth.users values
    ('00000000-0000-4000-8000-000000000001','bascula@dicsamx.com','test-password-hash'),
    ('00000000-0000-4000-8000-000000000002','other@example.test','other-hash');
  insert into profiles values
    ('00000000-0000-4000-8000-000000000001','services',true),
    ('00000000-0000-4000-8000-000000000002','custom_existing_role',true);
`);
const sql = await readFile(new URL('../supabase/migrations/20261014120000_enable_bascula_role.sql',import.meta.url),'utf8');
const usersBefore = (await db.query('select * from auth.users order by id')).rows;
await db.exec(sql);
assert.deepEqual((await db.query('select role,is_active from profiles order by user_id')).rows,
  [{role:'bascula',is_active:true},{role:'custom_existing_role',is_active:true}]);
assert.deepEqual((await db.query('select * from auth.users order by id')).rows, usersBefore);
await db.exec("update profiles set is_active=false where role='bascula'");
await db.exec(sql);
assert.equal((await db.query("select is_active from profiles where role='bascula'")).rows[0].is_active,false);
await assert.rejects(()=>db.exec("update profiles set role='unknown_role'"), e=>e.code==='23514');
await db.exec("delete from profiles where role='bascula'");
await db.exec(sql);
assert.equal((await db.query("select count(*)::int as n from profiles where role='bascula'")).rows[0].n,1);
await db.exec("delete from profiles where role='bascula'; delete from auth.users where email='bascula@dicsamx.com'");
await db.exec(sql);
assert.equal((await db.query('select count(*)::int as n from auth.users')).rows[0].n,1);
await db.close();
console.log('PASS: assigns the existing Báscula account; preserves passwords, other roles and inactive status; supports missing profiles; never creates auth users.');
