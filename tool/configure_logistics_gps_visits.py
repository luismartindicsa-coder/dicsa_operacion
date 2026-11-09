#!/usr/bin/env python3
"""Enable the independent visit detector using already-synchronized GPS data."""
import json
import sys
from configure_logistics_gps import database_connection


def configure():
    with database_connection() as db:
        db.execute('select cron.schedule(%s,%s,%s)', (
            'dicsa-logistics-gps-visits', '* * * * *',
            'select public.process_logistics_gps_visits();'))
        processed = db.execute('select public.process_logistics_gps_visits()').fetchone()[0]
        status = db.execute('select status from public.logistics_gps_visit_monitor').fetchone()[0]
    print(json.dumps({'status': status, 'processed_positions': processed, 'interval_seconds': 60}))
    if status == 'error':
        raise RuntimeError('Visit detector failed')


if __name__ == '__main__':
    try:
        configure()
    except Exception:
        print('No se completó la configuración de visitas GPS. Consulta logistics_gps_visit_monitor.', file=sys.stderr)
        sys.exit(1)
