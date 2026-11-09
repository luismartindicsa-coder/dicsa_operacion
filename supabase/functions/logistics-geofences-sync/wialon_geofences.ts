import {apiOrigin, GpsError} from '../logistics-gps-sync/wialon.ts';

export type Geofence = {
  resource_id: string; geofence_id: string; provider_name: string;
  shape_type: number; width_m: number; points: {lat: number; lng: number}[];
  provider_created_at: number; provider_modified_at: number;
};

export function normalizeGeofence(raw: any, resource: any): Geofence {
  if (!raw || !Number.isSafeInteger(raw.id) || raw.id <= 0 ||
      !Number.isSafeInteger(resource.id) || resource.id <= 0 ||
      typeof raw.n !== 'string' || !raw.n.trim() ||
      ![1, 2, 3].includes(raw.t) || ![0, 1, 2, 3].includes(resource.mu) ||
      !Number.isFinite(raw.w) || raw.w < 0 ||
      !Number.isSafeInteger(raw.ct) || raw.ct < 0 ||
      !Number.isSafeInteger(raw.mt) || raw.mt < 0 ||
      !Array.isArray(raw.p) || raw.p.length > 10000 ||
      raw.p.length < (raw.t === 3 ? 1 : raw.t === 2 ? 3 : 2) ||
      (raw.t === 3 && (raw.p.length !== 1 || raw.w === 0))) {
    throw new GpsError('invalid_response');
  }
  const points = raw.p.map((p: any) => {
    if (!p || !Number.isFinite(p.y) || Math.abs(p.y) > 90 ||
        !Number.isFinite(p.x) || Math.abs(p.x) > 180) throw new GpsError('invalid_response');
    return {lat: p.y, lng: p.x};
  });
  return {resource_id: String(resource.id), geofence_id: String(raw.id),
    provider_name: raw.n.trim(), shape_type: raw.t,
    width_m: raw.w * ([1, 2].includes(resource.mu) ? 0.3048 : 1), points,
    provider_created_at: raw.ct, provider_modified_at: raw.mt};
}

export async function readGeofences(origin: string, token: string, fetcher = fetch): Promise<Geofence[]> {
  const endpoint = apiOrigin(origin) + '/wialon/ajax.html';
  if (!/^[a-zA-Z0-9]{72}$/.test(token)) throw new GpsError('not_configured');
  const deadline = Date.now() + 55000;
  async function call(svc: string, params: any, sid?: string): Promise<any> {
    const remaining = deadline - Date.now();
    if (remaining <= 0 && svc !== 'core/logout') throw new GpsError('provider_unavailable');
    const body = new URLSearchParams({svc, params: JSON.stringify(params)});
    if (sid) body.set('sid', sid);
    let response;
    try { response = await fetcher(endpoint, {method: 'POST', body, redirect: 'error',
      signal: AbortSignal.timeout(svc === 'core/logout' ? 5000 : Math.max(1, Math.min(12000, remaining)))}); }
    catch { throw new GpsError('provider_unavailable'); }
    if (!response.ok) throw new GpsError('provider_unavailable');
    let data;
    try { data = await response.json(); } catch { throw new GpsError('invalid_response'); }
    if (!data || typeof data !== 'object') throw new GpsError('invalid_response');
    if (data.error !== undefined && data.error !== 0) {
      throw new GpsError([1, 7, 8].includes(data.error) ? 'authorization' : 'provider_unavailable');
    }
    return data;
  }
  const login = await call('token/login', {token, fl: 1});
  if (typeof login.eid !== 'string' || !login.eid) throw new GpsError('invalid_response');
  try {
    const resources: any[] = [];
    const seenResources = new Set();
    while (true) {
      const page = await call('core/search_items', {spec: {itemsType: 'avl_resource',
        propName: 'sys_name', propValueMask: '*', sortType: 'sys_name', propType: 'property'},
        force: resources.length === 0 ? 1 : 0, flags: 4097, from: resources.length, to: resources.length + 99}, login.eid);
      if (!Array.isArray(page.items) || !Number.isSafeInteger(page.totalItemsCount) ||
          page.totalItemsCount < 0 || page.totalItemsCount > 1000 ||
          resources.length + page.items.length > page.totalItemsCount) throw new GpsError('invalid_response');
      for (const r of page.items) {
        if (!Number.isSafeInteger(r.id) || seenResources.has(r.id)) throw new GpsError('invalid_response');
        seenResources.add(r.id); resources.push(r);
      }
      if (resources.length === page.totalItemsCount) break;
      if (!page.items.length) throw new GpsError('invalid_response');
    }
    const result: Geofence[] = [];
    for (const resource of resources) {
      // Missing zl means no geofence visibility on this resource. A successful
      // snapshot omits it, removing cached geometry previously visible to us.
      if (resource.zl === undefined) continue;
      if (!resource.zl || Array.isArray(resource.zl) || typeof resource.zl !== 'object') throw new GpsError('invalid_response');
      const ids = Object.keys(resource.zl).map(Number);
      if (ids.some(id => !Number.isSafeInteger(id) || id <= 0)) throw new GpsError('invalid_response');
      for (let offset = 0; offset < ids.length; offset += 100) {
        const batch = ids.slice(offset, offset + 100);
        const zones = await call('resource/get_zone_data', {itemId: resource.id, col: batch, flags: 28}, login.eid);
        if (!Array.isArray(zones) || zones.length !== batch.length) throw new GpsError('invalid_response');
        const seen = new Set();
        for (const zone of zones) {
          if (!batch.includes(zone.id) || seen.has(zone.id)) throw new GpsError('invalid_response');
          seen.add(zone.id); result.push(normalizeGeofence(zone, resource));
        }
        if (result.length > 10000) throw new GpsError('invalid_response');
      }
    }
    return result;
  } finally {
    try { await call('core/logout', {}, login.eid); } catch { /* Session expires server-side. */ }
  }
}
