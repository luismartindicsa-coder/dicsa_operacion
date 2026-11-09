#!/usr/bin/env python3
"""Enable unknown-stop detection using synchronized EPCOM positions and speed."""
import json
import sys
from configure_logistics_gps import database_connection


def configure():
    with database_connection() as db:
        db.execute('select cron.schedule(%s,%s,%s)', (
            'dicsa-logistics-gps-stops', '* * * * *',
            'select public.process_logistics_gps_stops();'))
        processed = db.execute('select public.process_logistics_gps_stops()').fetchone()[0]
        status = db.execute('select status from public.logistics_gps_stop_monitor').fetchone()[0]
    print(json.dumps({'status': status, 'processed_units': processed, 'interval_seconds': 60}))
    if status == 'error':
        raise RuntimeError('Stop detector failed')


if __name__ == '__main__':
    try:
        configure()
    except Exception:
        print('No se completó la configuración de paradas GPS. Consulta logistics_gps_stop_monitor.', file=sys.stderr)
        sys.exit(1)
