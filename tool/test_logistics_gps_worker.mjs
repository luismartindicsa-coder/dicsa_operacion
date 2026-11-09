import assert from 'node:assert/strict';
import {test} from 'node:test';
import {apiOrigin, normalizeUnit, readUnits} from '../supabase/functions/logistics-gps-sync/wialon.ts';

const token = 'a'.repeat(72);
const origin = 'https://hst-api.wialon.com';
const page = (items, total = items.length) => ({items, totalItemsCount: total});
function transport(replies) {
  const calls = [];
  const fetcher = async (url, options) => {
    calls.push({url, ...options, fields: Object.fromEntries(options.body)});
    const next = replies.shift();
    if (next instanceof Error) throw next;
    return Response.json(next);
  };
  return {calls, fetcher};
}

test('pages every unit, uses POST credentials, and closes its session', async () => {
  const {calls, fetcher} = transport([{eid:'secret'}, page([{id:1,nm:'C1',pos:{x:-100,y:20,t:1800000000}}],2),
    page([{id:2,nm:'C2',pos:null}],2), {error:0}]);
  const units = await readUnits(origin, token, fetcher);
  assert.equal(units.length,2); assert.equal(units[0].latitude,20);
  assert.equal(units[1].position_at,null);
  assert.equal(calls[3].fields.svc,'core/logout');
  assert.equal(JSON.parse(calls[2].fields.params).from,1);
  assert.ok(calls.every(c=>c.method==='POST' && c.redirect==='error' && !c.url.includes(token)));
  assert.ok(!JSON.stringify(units).includes(token));
});
test('HTTP 200 API error is a failure, with no leaked upstream reason', async () => {
  const {fetcher,calls} = transport([{eid:'secret'}, {error:7,reason:token}, {error:0}]);
  await assert.rejects(readUnits(origin,token,fetcher), e=>e.code==='authorization' && !e.message.includes(token));
  assert.equal(calls.at(-1).fields.svc,'core/logout');
});
test('duplicate or incomplete pages fail rather than publishing partial fleet', async () => {
  for (const second of [page([],2),page([{id:1,nm:'C1'}],2)]) {
    const {fetcher} = transport([{eid:'s'},page([{id:1,nm:'C1'}],2),second,{error:0}]);
    await assert.rejects(readUnits(origin,token,fetcher),e=>e.code==='invalid_response');
  }
});
test('missing private coordinates stay absent and zero coordinates remain valid', () => {
  assert.equal(normalizeUnit({id:1,nm:'C1',pos:{t:1800000000,f:262144}}).latitude,null);
  assert.equal(normalizeUnit({id:1,nm:'C1',pos:{t:1800000000,y:NaN,x:20}}).position_at,null);
  assert.equal(normalizeUnit({id:1,nm:'C1',pos:{t:1800000000,y:0,x:0}}).latitude,0);
});
test('speed belongs to a valid position and absent/invalid speed remains unknown', () => {
  const valid = {id:1,nm:'C1',pos:{t:1800000000,y:20,x:-100,s:0}};
  assert.equal(normalizeUnit(valid).speed_kph,0);
  for (const speed of [undefined,null,'0',-1,NaN,Infinity,1001]) {
    assert.equal(normalizeUnit({...valid,pos:{...valid.pos,s:speed}}).speed_kph,null);
  }
  assert.equal(normalizeUnit({...valid,pos:{t:1800000000,s:0}}).speed_kph,null);
  assert.equal(normalizeUnit({...valid,pos:{...valid.pos,s:85}}).speed_kph,85);
});
test('only explicit provider origins accept credentials', () => {
  for (const url of ['http://hst-api.wialon.com','https://hst-api.wialon.com.attacker.example',
    'https://user:secret@hst-api.wialon.com','https://hst-api.wialon.com/?token=x']) {
    assert.throws(()=>apiOrigin(url));
  }
});
test('worker rejects missing credentials and arbitrary methods before reading anything', async () => {
  let handler;
  globalThis.Deno = {env: {get: name => ({DICSA_GPS_SYNC_KEY:'test-sync-key'})[name]}, serve: callback => {handler=callback;}};
  await import('../supabase/functions/logistics-gps-sync/index.ts');
  assert.equal((await handler(new Request('https://worker.test',{method:'POST'}))).status,401);
  assert.equal((await handler(new Request('https://worker.test',{headers:{'x-dicsa-gps-key':'test-sync-key'}}))).status,405);
});
