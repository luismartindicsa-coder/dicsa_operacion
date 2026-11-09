export class GpsError extends Error {
  code: string;
  constructor(code: string) { super(code); this.code = code; }
}

export function apiOrigin(value: string): string {
  let url: URL;
  try { url = new URL(value); } catch { throw new GpsError('not_configured'); }
  const hosts = ['hst-api.wialon.com', 'hst-api.wialon.us', 'hst-api.wialon.eu', 'hst-api.wialon.org', 'gps.epcom.net'];
  if (url.protocol !== 'https:' || !hosts.includes(url.hostname) || url.port ||
      url.username || url.password || url.search || url.hash || !['', '/'].includes(url.pathname)) {
    throw new GpsError('not_configured');
  }
  return url.origin;
}

type Unit = {provider_unit_id: string; provider_name: string; latitude: number | null;
  longitude: number | null; position_at: string | null; speed_kph: number | null};

export function normalizeUnit(raw: Record<string, unknown>): Unit {
  if (!raw || !Number.isSafeInteger(raw.id) || Number(raw.id) <= 0 || typeof raw.nm !== 'string' || !raw.nm.trim()) {
    throw new GpsError('invalid_response');
  }
  const unit: Unit = {provider_unit_id: String(raw.id), provider_name: raw.nm,
    latitude: null, longitude: null, position_at: null, speed_kph: null};
  const pos = raw.pos as Record<string, unknown> | undefined;
  if (pos && typeof pos.x === 'number' && Number.isFinite(pos.x) && Math.abs(pos.x) <= 180 &&
      typeof pos.y === 'number' && Number.isFinite(pos.y) && Math.abs(pos.y) <= 90 &&
      typeof pos.t === 'number' && Number.isFinite(pos.t) && pos.t > 0 && pos.t < 253402300800) {
    unit.latitude = pos.y; unit.longitude = pos.x; unit.position_at = new Date(pos.t * 1000).toISOString();
    // Wialon pos.s belongs to this fix; absence is never interpreted as zero.
    if (typeof pos.s === 'number' && Number.isFinite(pos.s) && pos.s >= 0 && pos.s <= 1000) {
      unit.speed_kph = pos.s;
    }
  }
  return unit;
}

export async function readUnits(origin: string, token: string, fetcher = fetch): Promise<Unit[]> {
  const endpoint = apiOrigin(origin) + '/wialon/ajax.html';
  if (!/^[a-zA-Z0-9]{72}$/.test(token)) throw new GpsError('not_configured');
  const deadline = Date.now() + 55000;
  async function call(svc: string, params: Record<string, unknown>, sid?: string) {
    const remaining = deadline - Date.now();
    if (remaining <= 0 && svc !== 'core/logout') throw new GpsError('provider_unavailable');
    const body = new URLSearchParams({svc, params: JSON.stringify(params)});
    if (sid) body.set('sid', sid);
    let response: Response;
    try {
      response = await fetcher(endpoint, {method: 'POST', body, redirect: 'error',
        signal: AbortSignal.timeout(svc === 'core/logout' ? 5000 : Math.max(1, Math.min(12000, remaining)))});
    } catch { throw new GpsError('provider_unavailable'); }
    if (!response.ok) throw new GpsError('provider_unavailable');
    let data;
    try { data = await response.json(); } catch { throw new GpsError('invalid_response'); }
    if (!data || Array.isArray(data) || typeof data !== 'object') throw new GpsError('invalid_response');
    if (data.error !== undefined && data.error !== 0) {
      throw new GpsError([1, 7, 8].includes(data.error) ? 'authorization' : 'provider_unavailable');
    }
    return data;
  }
  const login = await call('token/login', {token, fl: 1});
  if (typeof login.eid !== 'string' || !login.eid) throw new GpsError('invalid_response');
  const units: Unit[] = [];
  const seen = new Set<string>();
  try {
    while (true) {
      const page = await call('core/search_items', {
        spec: {itemsType: 'avl_unit', propName: 'sys_name', propValueMask: '*', sortType: 'sys_name', propType: 'property'},
        force: units.length === 0 ? 1 : 0, flags: 1025, from: units.length, to: units.length + 99,
      }, login.eid);
      if (!Array.isArray(page.items) || !Number.isInteger(page.totalItemsCount) ||
          page.totalItemsCount < 0 || page.totalItemsCount > 10000 ||
          units.length + page.items.length > page.totalItemsCount) throw new GpsError('invalid_response');
      for (const item of page.items) {
        const unit = normalizeUnit(item);
        if (seen.has(unit.provider_unit_id)) throw new GpsError('invalid_response');
        seen.add(unit.provider_unit_id); units.push(unit);
      }
      if (units.length >= page.totalItemsCount) return units;
      if (page.items.length === 0) throw new GpsError('invalid_response');
    }
  } finally {
    // An upstream logout failure must not leak the session or discard valid positions.
    try { await call('core/logout', {}, login.eid); } catch { /* Session expires server-side. */ }
  }
}
