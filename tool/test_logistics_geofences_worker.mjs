import assert from 'node:assert/strict';
import {test} from 'node:test';
import {normalizeGeofence,readGeofences} from '../supabase/functions/logistics-geofences-sync/wialon_geofences.ts';
const zone={id:1,n:'AVON',t:2,w:0,ct:10,mt:20,p:[{x:-100,y:20},{x:-100,y:21},{x:-99,y:21}]};
const resource={id:9,mu:0,zl:{1:{id:1}}};
function transport(replies) {
  const calls=[];
  return {calls,fetcher:async(url,options)=>{calls.push({url,...options,fields:Object.fromEntries(options.body)});return Response.json(replies.shift());}};
}
test('reads explicit geofence IDs in batches and logs out without returning credentials',async()=>{
  const {calls,fetcher}=transport([{eid:'session-secret'},{totalItemsCount:1,items:[resource]},[zone],{error:0}]);
  const rows=await readGeofences('https://hst-api.wialon.com','a'.repeat(72),fetcher);
  assert.equal(rows[0].resource_id,'9');assert.equal(rows[0].points[0].lng,-100);
  assert.equal(calls[2].fields.svc,'resource/get_zone_data');
  assert.deepEqual(JSON.parse(calls[2].fields.params).col,[1]);
  assert.equal(calls.at(-1).fields.svc,'core/logout');
  assert.ok(calls.every(c=>c.method==='POST'&&c.redirect==='error'));
  assert.ok(!JSON.stringify(rows).includes('session-secret'));
});
test('empty and revoked resource visibility produce an empty successful snapshot',async()=>{
  for(const items of [[],[{id:9,mu:0}]]) {
    const {fetcher}=transport([{eid:'s'},{totalItemsCount:items.length,items},{error:0}]);
    assert.deepEqual(await readGeofences('https://hst-api.wialon.com','a'.repeat(72),fetcher),[]);
  }
});
test('partial details, duplicates and authorization errors cannot publish partial geometry',async()=>{
  for(const detail of [[],[zone,zone],{error:7,reason:'sensitive'}]) {
    const {fetcher,calls}=transport([{eid:'s'},{totalItemsCount:1,items:[resource]},detail,{error:0}]);
    await assert.rejects(readGeofences('https://hst-api.wialon.com','a'.repeat(72),fetcher),e=>['authorization','invalid_response'].includes(e.code));
    assert.equal(calls.at(-1).fields.svc,'core/logout');
  }
});
test('converts feet to metres and validates geometry before storing it',()=>{
  assert.equal(normalizeGeofence({...zone,t:3,w:100,p:[{x:0,y:0}]},{id:9,mu:1}).width_m,30.48);
  for(const invalid of [{...zone,p:[]},{...zone,p:[{x:0,y:91},...zone.p]},
    {...zone,t:3,w:0,p:[{x:0,y:0}]}]) assert.throws(()=>normalizeGeofence(invalid,resource));
});
test('endpoint rejects unauthenticated calls before any provider access',async()=>{
  let handler;
  globalThis.Deno={env:{get:()=>undefined},serve:f=>{handler=f;}};
  await import('../supabase/functions/logistics-geofences-sync/index.ts');
  assert.equal((await handler(new Request('https://worker.test',{method:'POST'}))).status,401);
});
