#!/usr/bin/env python3
"""Authorize read-only EPCOM access and configure the deployed DICSA GPS worker.

Requires the authenticated Supabase CLI and psycopg[binary]. Keeps credentials out
of source, logs and command-line arguments. Run from the Flutter project root.
"""
import json
import os
import re
import secrets
import shlex
import subprocess
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.request import Request, urlopen

import psycopg
from epcom_gps_probe import ProbeError, WialonClient, authorize, callback_api_origin, probe


def database_connection():
    result = subprocess.run(['supabase', 'db', 'dump', '--dry-run'], capture_output=True, text=True)
    if result.returncode:
        raise ProbeError('No se pudo obtener la conexión administrativa de Supabase.')
    env = {}
    for line in result.stdout.splitlines():
        if line.startswith('export PG'):
            key, value = shlex.split(line)[1].split('=', 1)
            env[key] = value
    connection = psycopg.connect(host=env['PGHOST'], port=env['PGPORT'], user=env['PGUSER'],
        password=env['PGPASSWORD'], dbname=env['PGDATABASE'], sslmode='require', connect_timeout=15, autocommit=True)
    connection.execute('set role postgres')
    return connection


def configure():
    ref = Path('supabase/.temp/project-ref').read_text().strip()
    if not re.fullmatch(r'[a-z]{20}', ref):
        raise ProbeError('Proyecto Supabase no válido.')
    with database_connection() as db:
        if db.execute("select to_regclass('public.logistics_gps_units')").fetchone()[0] is None:
            raise ProbeError('Primero aplica la migración de GPS y despliega logistics-gps-sync.')
    duration = 365 * 24 * 60 * 60
    auth = authorize('https://gps.epcom.net', duration=duration, client_name='DICSA GPS - Logistica')
    origin = callback_api_origin(auth['api_url'], 'https://gps.epcom.net')
    report = probe(WialonClient(origin), auth['token'])
    if report['unit_count'] == 0:
        raise ProbeError('La cuenta no tiene unidades visibles; no se activó la sincronización.')
    # The token is activated during browser authorization, shortly before this time.
    expiry = datetime.now(timezone.utc) + timedelta(seconds=duration - 120)
    with database_connection() as db:
        existing = db.execute("select decrypted_secret from vault.decrypted_secrets where name='dicsa_gps_sync_key'").fetchone()
        sync_key = existing[0] if existing else secrets.token_urlsafe(48)
        values = {'WIALON_API_URL': origin, 'WIALON_TOKEN': auth['token'],
                  'WIALON_TOKEN_EXPIRES_AT': expiry.isoformat(), 'DICSA_GPS_SYNC_KEY': sync_key}
        with tempfile.TemporaryDirectory(prefix='dicsa-gps-secrets-') as directory:
            secret_file = Path(directory) / 'worker.env'
            fd = os.open(secret_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, 'w') as output:
                for key, value in values.items():
                    output.write(key + '=' + value + '\n')
            result = subprocess.run(['supabase','secrets','set','--env-file',str(secret_file),
                '--project-ref',ref], capture_output=True, text=True)
            if result.returncode:
                raise ProbeError('No se pudieron guardar los secretos en Supabase; no se activó la programación.')
        db.execute('create extension if not exists pg_cron with schema pg_catalog')
        db.execute('create extension if not exists pg_net with schema extensions')
        if not existing:
            db.execute('select vault.create_secret(%s,%s,%s)',
                (sync_key,'dicsa_gps_sync_key','Dedicated invocation key for the DICSA GPS worker'))
        endpoint = f'https://{ref}.supabase.co/functions/v1/logistics-gps-sync'
        command = """select net.http_post(
          url := '%s',
          headers := jsonb_build_object('Content-Type','application/json',
            'x-dicsa-gps-key',(select decrypted_secret from vault.decrypted_secrets where name='dicsa_gps_sync_key')),
          body := '{}'::jsonb, timeout_milliseconds := 85000
        );""" % endpoint
        db.execute('select cron.schedule(%s,%s,%s)',('dicsa-logistics-gps','* * * * *',command))
    request = Request(endpoint, data=b'{}', headers={'Content-Type':'application/json','x-dicsa-gps-key':sync_key},method='POST')
    with urlopen(request,timeout=85) as response:
        result = json.load(response)
    print(json.dumps({'status':result.get('status'), 'unit_count':result.get('unit_count'),
        'interval_seconds':60, 'token_expires_at':expiry.isoformat()},ensure_ascii=False),flush=True)


if __name__ == '__main__':
    try:
        configure()
    except ProbeError as error:
        print(str(error),file=sys.stderr)
        sys.exit(1)
    except (Exception, KeyboardInterrupt):
        # Never include raw connection strings, secret-bearing exceptions or HTTP bodies.
        print('No se completó la configuración. Revisa el estado del worker y la programación antes de repetir.',file=sys.stderr)
        sys.exit(1)
