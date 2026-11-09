#!/usr/bin/env python3
"""Schedule closed days and recent fuel-load windows with read-only EPCOM access."""
import json
import re
import sys
from pathlib import Path
from configure_logistics_gps import database_connection


def configure():
    ref = Path('supabase/.temp/project-ref').read_text().strip()
    if not re.fullmatch(r'[a-z]{20}', ref):
        raise ValueError('Invalid project')
    with database_connection() as db:
        if not db.execute("select exists(select 1 from logistics_gps_daily_mileage where status='ok' and kilometers>0)").fetchone()[0]:
            raise ValueError('Verify a real historical trip before scheduling')
        command = """select net.http_post(
          url := 'https://%s.supabase.co/functions/v1/logistics-mileage-sync',
          headers := jsonb_build_object('Content-Type','application/json',
            'x-dicsa-gps-key',(select decrypted_secret from vault.decrypted_secrets where name='dicsa_gps_sync_key')),
          body := '{}'::jsonb, timeout_milliseconds := 85000
        );""" % ref
        db.execute('select cron.schedule(%s,%s,%s)', ('dicsa-logistics-mileage','* * * * *',command))
    print(json.dumps({'status':'scheduled','interval_seconds':60,'source':'historical_trips',
      'daily_through':'previous_day','load_windows_through':'last_observed_position',
      'load_window_refresh_minutes':5}))


if __name__ == '__main__':
    try:
        configure()
    except Exception:
        print('No se activó la programación de kilometraje. Verifica la migración, la función y el acceso real al historial.',file=sys.stderr)
        sys.exit(1)
