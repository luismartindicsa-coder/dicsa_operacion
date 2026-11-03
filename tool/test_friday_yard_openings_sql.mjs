import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.DICSA_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
await db.exec(`
  create role authenticated; create role anon; create schema auth;
  create function auth.uid() returns uuid language sql stable as $$select null::uuid$$;
  create function set_updated_at_v2() returns trigger language plpgsql as $$begin
    new.updated_at := current_setting('test.save_time')::timestamptz; return new; end$$;
`);
await db.exec(await readFile(new URL('../supabase/migrations/20260519113000_create_dashboard_yard_manual_counts.sql', import.meta.url), 'utf8'));
await db.exec(`insert into dashboard_yard_manual_counts(site,widget_key,source_kind,commercial_material_code,count_units,updated_at)
  values('DICSA_CELAYA','national','commercial_material','PACA_NACIONAL',35,'2026-10-16T23:01:00Z');`);
await db.exec(await readFile(new URL('../supabase/migrations/20261016170000_capture_friday_yard_openings.sql', import.meta.url), 'utf8'));
for (const [stamp, monday] of [
  ['2026-10-16T22:59:59Z', null],
  ['2026-10-16T23:00:00Z', '2026-10-19'],
  ['2026-10-17T05:59:59Z', '2026-10-19'],
  ['2026-10-17T06:00:00Z', null],
  ['2026-10-15T23:30:00Z', null],
  ['2027-01-01T23:00:00Z', '2027-01-04'],
]) {
  assert.equal((await db.query('select dashboard_yard_opening_monday($1)::text as day', [stamp])).rows[0].day, monday, stamp);
}
const read = async () => (await db.query("select week_start::text, count_units from dashboard_yard_week_openings where widget_key='national' order by week_start")).rows;
assert.deepEqual(await read(), [{week_start: '2026-10-19', count_units: 35}], 'latest qualifying count is backfilled');
await db.exec('set role authenticated;');
const recount = async (stamp, quantity) => {
  await db.query("select set_config('test.save_time',$1,false)", [stamp]);
  await db.query("update dashboard_yard_manual_counts set count_units=$1 where widget_key='national'", [quantity]);
};
await recount('2026-10-17T00:00:00Z', 50);
assert.equal((await read())[0].count_units, 50, 'Friday correction replaces same weekly opening');
await recount('2026-10-17T16:00:00Z', 65);
assert.equal((await read())[0].count_units, 50, 'Saturday recount preserves closing');
await recount('2026-10-19T16:00:00Z', 70);
assert.equal((await read())[0].count_units, 50, 'Monday recount preserves closing');
await recount('2026-10-23T22:59:00Z', 90);
assert.equal((await read()).length, 1, 'before 17:00 does not set next Monday');
await recount('2026-10-23T23:00:00Z', 0);
assert.deepEqual(await read(), [{week_start: '2026-10-19', count_units: 50}, {week_start: '2026-10-26', count_units: 0}], 'next week and zero remain separate');
await assert.rejects(() => db.query('update dashboard_yard_week_openings set count_units=999'), e => e.code === '42501');
await db.exec("delete from dashboard_yard_manual_counts where widget_key='national';");
assert.deepEqual(await read(), [{week_start: '2026-10-19', count_units: 50}], 'clearing removes matching closing, preserves older weeks');
await db.exec('reset role; set role anon;');
await assert.rejects(() => db.query('select * from dashboard_yard_week_openings'), e => e.code === '42501');
console.log('Friday closing SQL passed: Celaya boundary, UTC rollover, year change, backfill, later counts, zero, independent weeks, clear and permissions.');
await db.close();
