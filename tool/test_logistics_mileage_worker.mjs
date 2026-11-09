import assert from 'node:assert/strict';
import {test} from 'node:test';
import {normalizeTrips,readDailyMileage,readMileageWindow} from '../supabase/functions/logistics-mileage-sync/wialon_mileage.ts';
const origin='https://hst-api.wialon.com', token='a'.repeat(72);
const job={provider_unit_id:'123',time_from:1793512800,time_to:1793599199};
const trip=(start=100,end=200,m=1234.5)=>({from:{t:job.time_from+start},to:{t:job.time_from+end},m});
test('historical trips convert meters once; no messages is missing, stationary messages is zero',()=>{
 assert.deepEqual(normalizeTrips([trip(),trip(300,400,2500)],20,job),{kilometers:3.7345,trip_count:2,message_count:20});
 assert.equal(normalizeTrips([],0,job).kilometers,null);
 assert.equal(normalizeTrips([],1,job).kilometers,null);
 assert.equal(normalizeTrips([],20,job).kilometers,0);
 for(const bad of [[trip(-1)], [trip(100,90000)], [trip(),trip(150,250)], [trip(100,200,NaN)], [trip(100,200,-1)]])
  assert.throws(()=>normalizeTrips(bad,20,job));
 assert.throws(()=>normalizeTrips([trip()],0,job));
});
function transport(replies){
 const calls=[];
 return {calls,fetcher:async(url,options)=>{calls.push({url,...options,fields:Object.fromEntries(options.body)});return Response.json(replies.shift());}};
}
test('loads full closed-day messages without downloading coordinates, computes trips sequentially and logs out',async()=>{
 const {calls,fetcher}=transport([{eid:'private-session'},{count:30,messages:[]},[trip()],{error:0}]);
 assert.equal((await readDailyMileage(origin,token,job,fetcher)).kilometers,1.2345);
 assert.deepEqual(calls.map(c=>c.fields.svc),['token/login','messages/load_interval','unit/get_trips','core/logout']);
 const params=JSON.parse(calls[1].fields.params);
 assert.equal(params.loadCount,0);assert.equal(params.flagsMask,65281);assert.equal(params.flags,1);assert.equal(params.timeTo,job.time_to);
 assert.equal(JSON.parse(calls[2].fields.params).msgsSource,'1');
 assert.ok(calls.every(c=>c.method==='POST'&&c.redirect==='error'&&!c.url.includes(token)));
});
test('denied history never becomes zero; logout still happens and no raw error leaks',async()=>{
 const {calls,fetcher}=transport([{eid:'s'},{error:7,reason:token},{error:0}]);
 await assert.rejects(readDailyMileage(origin,token,job,fetcher),e=>e.code==='authorization'&&!e.message.includes(token));
 assert.equal(calls.at(-1).fields.svc,'core/logout');
});
test('no messages skips trip calculation; malformed replies and current/future periods fail',async()=>{
 const {calls,fetcher}=transport([{eid:'s'},{count:0,messages:[]},{error:0}]);
 assert.equal((await readDailyMileage(origin,token,job,fetcher)).kilometers,null);assert.equal(calls.length,3);
 await assert.rejects(readDailyMileage(origin,token,{...job,time_to:job.time_to+1},fetcher));
 const invalid=transport([{eid:'s'},{count:-1},{error:0}]);
 await assert.rejects(readDailyMileage(origin,token,job,invalid.fetcher));
});
test('worker requires the dedicated server key and never accepts browser credentials',async()=>{
 let handler;globalThis.Deno={env:{get:n=>({DICSA_GPS_SYNC_KEY:'test-key'})[n]},serve:h=>handler=h};
 await import('../supabase/functions/logistics-mileage-sync/index.ts');
 assert.equal((await handler(new Request('https://test.invalid',{method:'POST'}))).status,401);
 assert.equal((await handler(new Request('https://test.invalid',{headers:{'x-dicsa-gps-key':'test-key'}}))).status,405);
});
test('provisional windows use exact load time, preserve missing data, and reject future or unbounded intervals',async()=>{
 const partial={...job,time_from:job.time_from+80,time_to:job.time_from+500};
 const {calls,fetcher}=transport([{eid:'isolated-load-session'},{count:30},[trip()],{error:0}]);
 assert.equal((await readMileageWindow(origin,token,partial,fetcher)).kilometers,1.2345);
 assert.equal(JSON.parse(calls[1].fields.params).timeFrom,partial.time_from);
 assert.equal(JSON.parse(calls[2].fields.params).timeTo,partial.time_to);
 await assert.rejects(readMileageWindow(origin,token,{...job,time_to:job.time_from+32*86400},fetcher));
 await assert.rejects(readMileageWindow(origin,token,{...job,time_from:job.time_to+1},fetcher));
 await assert.rejects(readMileageWindow(origin,token,{...job,time_to:Math.ceil(Date.now()/1000)+1},fetcher));
});
