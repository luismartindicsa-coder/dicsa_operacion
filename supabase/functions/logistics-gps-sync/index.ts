import {GpsError, readUnits} from './wialon.ts';

// Called by pg_cron with a dedicated secret, never directly by the Flutter client.
Deno.serve(async (request: Request) => {
  const reply = (status: number, value: unknown) => Response.json(value, {status, headers: {'Cache-Control': 'no-store'}});
  const secret = Deno.env.get('DICSA_GPS_SYNC_KEY');
  if (!secret || request.headers.get('x-dicsa-gps-key') !== secret) return reply(401, {error: 'unauthorized'});
  if (request.method !== 'POST') return reply(405, {error: 'method_not_allowed'});
  const db = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!db || !key) return reply(503, {error: 'storage'});
  async function rpc(name: string, body: unknown) {
    const response = await fetch(`${db}/rest/v1/rpc/${name}`, {method: 'POST',
      headers: {'Content-Type': 'application/json', apikey: key!, Authorization: `Bearer ${key}`},
      body: JSON.stringify(body), signal: AbortSignal.timeout(10000), redirect: 'error'});
    if (!response.ok) throw new GpsError('storage');
    return await response.json();
  }
  let run: string | undefined;
  const expiry = Deno.env.get('WIALON_TOKEN_EXPIRES_AT') || null;
  try {
    run = await rpc('claim_logistics_gps_sync', {});
    if (!run) return reply(200, {status: 'already_scheduled'});
    const token = Deno.env.get('WIALON_TOKEN') || '';
    const origin = Deno.env.get('WIALON_API_URL') || '';
    const units = await readUnits(origin, token);
    const accepted = await rpc('complete_logistics_gps_sync', {
      p_run_id: run, p_units: units, p_error: null, p_token_expires_at: expiry,
    });
    if (!accepted) return reply(409, {error: 'superseded'});
    return reply(200, {status: 'ok', unit_count: units.length});
  } catch (error) {
    const code = error instanceof GpsError ? error.code : 'storage';
    if (run) {
      try { await rpc('complete_logistics_gps_sync', {
        p_run_id: run, p_units: [], p_error: code, p_token_expires_at: expiry,
      }); } catch { /* The UI also detects overdue last_success_at. */ }
    }
    // Never log tokens, sessions, coordinates, upstream responses or raw exceptions.
    return reply(503, {error: code});
  }
});
