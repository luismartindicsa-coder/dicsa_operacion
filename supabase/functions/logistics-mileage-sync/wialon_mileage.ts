import {apiOrigin, GpsError} from '../logistics-gps-sync/wialon.ts';

export type MileageJob = {provider_unit_id: string; time_from: number; time_to: number};
export type MileageResult = {kilometers: number | null; trip_count: number; message_count: number};

export function normalizeTrips(trips: unknown, count: number, job: MileageJob): MileageResult {
  if (!Number.isSafeInteger(count) || count < 0 || !Array.isArray(trips)) throw new GpsError('invalid_response');
  let meters = 0;
  let lastEnd = job.time_from - 1;
  for (const t of trips) {
    if (!t || !Number.isFinite(t.m) || t.m < 0 ||
        !Number.isSafeInteger(t.from?.t) || !Number.isSafeInteger(t.to?.t) ||
        t.from.t < job.time_from || t.to.t > job.time_to || t.to.t < t.from.t ||
        t.from.t < lastEnd) throw new GpsError('invalid_response');
    meters += t.m;
    lastEnd = t.to.t;
  }
  const days = Math.max(1, Math.ceil((job.time_to - job.time_from + 1) / 86400));
  if (meters > days * 5000000 || (count < 2 && trips.length > 0)) throw new GpsError('invalid_response');
  return {kilometers: count >= 2 ? meters / 1000 : null, trip_count: trips.length, message_count: count};
}

export async function readDailyMileage(origin: string, token: string, job: MileageJob, fetcher = fetch): Promise<MileageResult> {
  if (job.time_to - job.time_from !== 86399) throw new GpsError('invalid_response');
  return readMileageWindow(origin, token, job, fetcher);
}

// A provisional load window ends at the last observed position, never the clock.
export async function readMileageWindow(origin: string, token: string, job: MileageJob, fetcher = fetch): Promise<MileageResult> {
  const endpoint = apiOrigin(origin) + '/wialon/ajax.html';
  if (!/^[a-zA-Z0-9]{72}$/.test(token)) throw new GpsError('not_configured');
  if (!/^\d+$/.test(job.provider_unit_id) || !Number.isSafeInteger(Number(job.provider_unit_id)) ||
      !Number.isSafeInteger(job.time_from) || !Number.isSafeInteger(job.time_to) ||
      job.time_from < 0 || job.time_to < job.time_from || job.time_to - job.time_from > 31 * 86400 || job.time_to >= Date.now() / 1000) {
    throw new GpsError('invalid_response');
  }
  let sid: string | undefined;
  const deadline = Date.now() + 65000;
  async function call(svc: string, params: unknown) {
    const remaining = deadline - Date.now();
    if (remaining <= 0 && svc !== 'core/logout') throw new GpsError('provider_unavailable');
    const body = new URLSearchParams({svc, params: JSON.stringify(params)});
    if (sid) body.set('sid', sid);
    let response;
    try { response = await fetcher(endpoint, {method: 'POST', body, redirect: 'error',
      signal: AbortSignal.timeout(svc === 'core/logout' ? 5000 : Math.max(1, Math.min(25000, remaining)))}); }
    catch { throw new GpsError('provider_unavailable'); }
    if (!response.ok) throw new GpsError('provider_unavailable');
    let data;
    try { data = await response.json(); } catch { throw new GpsError('invalid_response'); }
    if (!data || typeof data !== 'object') throw new GpsError('invalid_response');
    if (data.error !== undefined && data.error !== 0) throw new GpsError([1,7,8].includes(data.error) ? 'authorization' : 'provider_unavailable');
    return data;
  }
  const login = await call('token/login', {token, fl: 1});
  if (typeof login.eid !== 'string' || !login.eid) throw new GpsError('invalid_response');
  sid = login.eid;
  try {
    // Load position-bearing data messages into this isolated session. Do not download raw
    // positions; the provider's trip detector computes the historical distance.
    const loaded = await call('messages/load_interval', {itemId: Number(job.provider_unit_id),
      timeFrom: job.time_from, timeTo: job.time_to, flags: 1, flagsMask: 65281, loadCount: 0});
    if (!Number.isSafeInteger(loaded.count) || loaded.count < 0) throw new GpsError('invalid_response');
    if (loaded.count < 2) return normalizeTrips([], loaded.count, job);
    const trips = await call('unit/get_trips', {itemId: Number(job.provider_unit_id), msgsSource: '1',
      timeFrom: job.time_from, timeTo: job.time_to});
    return normalizeTrips(trips, loaded.count, job);
  } finally {
    try { await call('core/logout', {}); } catch { /* Only this session; token remains valid. */ }
  }
}
