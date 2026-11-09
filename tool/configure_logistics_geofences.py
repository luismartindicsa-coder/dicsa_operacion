#!/usr/bin/env python3
"""Schedule geofence reads using the existing server-only GPS credentials."""
import json
import re
import sys
from pathlib import Path
from urllib.request import Request, urlopen
from configure_logistics_gps import database_connection


def configure():
    ref = Path('supabase/.temp/project-ref').read_text().strip()
    if not re.fullmatch(r'[a-z]{20}', ref):
        raise ValueError('Invalid project')
    endpoint = f'https://{ref}.supabase.co/functions/v1/logistics-geofences-sync'
    with database_connection() as db:
        if not db.execute("select to_regclass('public.logistics_geofences')").fetchone()[0]:
            raise ValueError('Migration missing')
        key = db.execute("select decrypted_secret from vault.decrypted_secrets where name='dicsa_gps_sync_key'").fetchone()[0]
        command = """select net.http_post(url := '%s',
          headers := jsonb_build_object('Content-Type','application/json',
            'x-dicsa-gps-key',(select decrypted_secret from vault.decrypted_secrets where name='dicsa_gps_sync_key')),
          body := '{}'::jsonb, timeout_milliseconds := 85000);""" % endpoint
        db.execute('select cron.schedule(%s,%s,%s)', ('dicsa-logistics-geofences','*/10 * * * *',command))
    request = Request(endpoint, data=b'{}',headers={'Content-Type':'application/json','x-dicsa-gps-key':key},method='POST')
    with urlopen(request,timeout=85) as response:
        result = json.load(response)
    print(json.dumps({'status':result.get('status'),'geofence_count':result.get('geofence_count'),'interval_minutes':10}))


if __name__ == '__main__':
    try:
        configure()
    except Exception:
        print('No se completó la configuración de geocercas. Consulta logistics_geofence_sync_state.',file=sys.stderr)
        sys.exit(1)
