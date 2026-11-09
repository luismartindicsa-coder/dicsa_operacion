import {GpsError} from '../logistics-gps-sync/wialon.ts';
import {readDailyMileage, readMileageWindow} from './wialon_mileage.ts';

Deno.serve(async (request: Request) => {
  const reply = (status: number, value: unknown) => Response.json(value, {status, headers: {'Cache-Control': 'no-store'}});
  const secret = Deno.env.get('DICSA_GPS_SYNC_KEY');
  if (!secret || request.headers.get('x-dicsa-gps-key') !== secret) return reply(401, {error: 'unauthorized'});
  if (request.method !== 'POST') return reply(405, {error: 'method_not_allowed'});
  const db = Deno.env.get('SUPABASE_URL'), key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!db || !key) return reply(503, {error: 'storage'});
  async function rpc(name: string, body: unknown) {
    const response = await fetch(`${db}/rest/v1/rpc/${name}`, {method: 'POST',
      headers: {'Content-Type': 'application/json', apikey: key!, Authorization: `Bearer ${key}`},
      body: JSON.stringify(body), signal: AbortSignal.timeout(10000), redirect: 'error'});
    if (!response.ok) throw new GpsError('storage');
    return await response.json();
  }
  let run: string | undefined;
  async function processLoadWindow() {
    let liveRun: string | undefined;
    try {
      const job = await rpc('claim_logistics_gps_load_mileage', {});
      if (!job) return 'idle';
      liveRun = job.run_id;
      const result = await readMileageWindow(Deno.env.get('WIALON_API_URL') || '', Deno.env.get('WIALON_TOKEN') || '', job);
      const accepted = await rpc('complete_logistics_gps_load_mileage', {p_run_id: liveRun,
        p_kilometers: result.kilometers, p_message_count: result.message_count});
      return accepted ? (result.kilometers !== null ? 'ok' : 'no_data') : 'superseded';
    } catch (error) {
      const code = error instanceof GpsError ? error.code : 'storage';
      if (liveRun) {
        try { await rpc('complete_logistics_gps_load_mileage', {p_run_id: liveRun, p_error: code}); } catch { /* Lease expires. */ }
      }
      return code;
    }
  }
  try {
    const job = await rpc('claim_logistics_gps_mileage', {});
    if (!job) {
      // At most three isolated provider sessions per minute: ~5-minute rotation
      // for 15 units. Historical closed days retain priority after midnight.
      const windows = await Promise.all([processLoadWindow(), processLoadWindow(), processLoadWindow()]);
      return reply(windows.some(s => ['storage','authorization','provider_unavailable','invalid_response','not_configured'].includes(s)) ? 503 : 200,
        {status: windows.every(s => s === 'idle') ? 'idle' : 'load_windows', windows});
    }
    run = job.run_id;
    const result = await readDailyMileage(Deno.env.get('WIALON_API_URL') || '', Deno.env.get('WIALON_TOKEN') || '', job);
    const accepted = await rpc('complete_logistics_gps_mileage', {p_run_id: run,
      p_kilometers: result.kilometers, p_trip_count: result.trip_count, p_message_count: result.message_count});
    if (!accepted) return reply(409, {error: 'superseded'});
    return reply(200, {status: result.kilometers !== null ? 'ok' : 'no_data', entry_date: job.entry_date});
  } catch (error) {
    const code = error instanceof GpsError ? error.code : 'storage';
    if (run) {
      try { await rpc('complete_logistics_gps_mileage', {p_run_id: run, p_error: code}); } catch { /* Lease expires. */ }
    }
    return reply(503, {error: code});
  }
});
