#!/usr/bin/env python3
"""Local, read-only EPCOM/Wialon connection trial; Python standard library only."""

import argparse
import getpass
import json
import math
import os
import secrets
import sys
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlencode, urlsplit, urlunsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener


class ProbeError(Exception):
    """Safe user-facing error: never includes upstream bodies or credentials."""


def secure_origin(value):
    try:
        url = urlsplit(value)
        port = url.port
    except ValueError:
        raise ProbeError('La dirección del servidor no es válida.') from None
    if (url.scheme != 'https' or not url.hostname or url.username or
            url.password or url.query or url.fragment or port not in (None, 443) or
            url.path not in ('', '/', '/login.html', '/wialon/ajax.html')):
        raise ProbeError('Usa la dirección HTTPS del servidor, sin parámetros ni credenciales.')
    return urlunsplit(('https', url.netloc, '', '', ''))


def callback_api_origin(value, portal):
    if not value:
        raise ProbeError('EPCOM no indicó el servidor de API; solicita su dirección al proveedor y usa --api-url.')
    origin = secure_origin(value)
    host = urlsplit(origin).hostname
    trusted = {'hst-api.wialon.com', 'hst-api.wialon.us',
               'hst-api.wialon.eu', 'hst-api.wialon.org'}
    if origin != secure_origin(portal) and host not in trusted:
        raise ProbeError('El servidor de API devuelto necesita verificación antes de enviar el token.')
    return origin


def login_url(portal, callback, *, duration=3600, client_name='DICSA GPS - prueba de consulta'):
    return secure_origin(portal) + '/login.html?' + urlencode({
        'client_id': client_name,
        'access_type': 256,  # Online tracking only; no modification or commands.
        'activation_time': 0,
        'duration': duration,
        'lang': 'es',
        'flags': 0,
        'response_type': 'token',
        'redirect_uri': callback,
    })


def authorize(portal, timeout=1200, *, duration=3600, client_name='DICSA GPS - prueba de consulta'):
    """Receive the vendor's OAuth-style callback on loopback; keep token in memory."""
    callback_path = '/callback/' + secrets.token_urlsafe(32)
    result = {}

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass  # The callback URL contains a credential; never log requests.

        def do_GET(self):
            url = urlsplit(self.path)
            if url.path != callback_path:
                self.send_error(404)
                return
            params = parse_qs(url.query)
            token = params.get('access_token', [''])[0]
            if len(token) != 72 or not token.isascii() or not token.isalnum():
                self.send_error(400, 'No se recibio un token valido')
                return
            result.update(token=token, api_url=params.get('wialon_sdk_url', [''])[0])
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Referrer-Policy', 'no-referrer')
            self.send_header('Content-Security-Policy', "default-src 'none'; script-src 'unsafe-inline'")
            self.end_headers()
            self.wfile.write(('<!doctype html><html lang="es"><meta charset="utf-8">'
                '<title>DICSA · Acceso recibido</title>'
                '<script>history.replaceState(null,"","/listo")</script>'
                '<h1>Acceso recibido</h1><p>DICSA está comprobando la conexión con EPCOM GPS. '
                'Puedes regresar al chat.</p></html>').encode())

    with HTTPServer(('127.0.0.1', 0), Handler) as server:
        server.timeout = 1
        callback = 'http://127.0.0.1:%s%s' % (server.server_port, callback_path)
        print('Abre este enlace e inicia sesión en EPCOM GPS:', flush=True)
        print(login_url(portal, callback, duration=duration, client_name=client_name), flush=True)
        deadline = time.monotonic() + timeout
        while not result and time.monotonic() < deadline:
            server.handle_request()
    if not result:
        raise ProbeError('Terminó el tiempo de espera para iniciar sesión; puedes repetir la prueba.')
    return result


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *_args, **_kwargs):
        return None


class WialonClient:
    def __init__(self, api_url, opener=None):
        self.endpoint = secure_origin(api_url) + '/wialon/ajax.html'
        self.opener = opener or build_opener(NoRedirect())

    def call(self, method, params, sid=None):
        if method not in {'token/login', 'core/search_items', 'core/logout'}:
            raise ProbeError('Esta prueba solo permite iniciar sesión, consultar unidades y salir.')
        fields = {'svc': method, 'params': json.dumps(params)}
        if sid:
            fields['sid'] = sid
        request = Request(self.endpoint, data=urlencode(fields).encode(), headers={
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
        }, method='POST')
        try:
            with self.opener.open(request, timeout=15) as response:
                payload = response.read(5_000_001)
                if len(payload) > 5_000_000:
                    raise ProbeError('La respuesta de EPCOM supera el límite de esta prueba.')
                data = json.loads(payload)
        except HTTPError as error:
            raise ProbeError('EPCOM respondió HTTP %d; verifica el servidor de API.' % error.code) from None
        except (URLError, TimeoutError, OSError):
            raise ProbeError('No se pudo conectar con EPCOM; revisa la red y el servidor de API.') from None
        except (ValueError, UnicodeError):
            raise ProbeError('El servidor no devolvió una respuesta JSON válida de Wialon.') from None
        if not isinstance(data, dict):
            raise ProbeError('El formato de la respuesta de Wialon no es válido.')
        code = data.get('error', 0)
        if type(code) is not int:
            raise ProbeError('Wialon devolvió un código de respuesta inválido.')
        if code != 0:
            reasons = {
                1: 'La sesión no es válida.',
                4: 'El servidor rechazó los parámetros de consulta.',
                7: 'Acceso denegado: verifica permisos del usuario/token y servicios habilitados con el proveedor.',
                8: 'El token no es válido para este servidor o usuario.',
                1003: 'Se alcanzó el límite de solicitudes; vuelve a intentar más tarde.',
            }
            raise ProbeError(reasons.get(code, 'Wialon rechazó la solicitud.'))
        return data


def finite_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def normalize_unit(item, now):
    if not isinstance(item, dict) or not isinstance(item.get('id'), int) or isinstance(item['id'], bool):
        raise ProbeError('Se recibió una unidad sin identificador válido.')
    pos = item.get('pos')
    row = {'provider_unit_id': str(item['id']), 'name': str(item.get('nm', '')),
           'latitude': None, 'longitude': None, 'position_at_utc': None,
           'age_seconds': None, 'status': 'sin_posicion'}
    if not isinstance(pos, dict):
        return row
    lat, lon, timestamp = pos.get('y'), pos.get('x'), pos.get('t')
    # Private trips can omit coordinates; never turn missing fields into (0, 0).
    if not (finite_number(lat) and -90 <= lat <= 90 and
            finite_number(lon) and -180 <= lon <= 180 and
            finite_number(timestamp) and 0 < timestamp < 253402300800):
        return row
    age = now - timestamp
    row.update(latitude=lat, longitude=lon,
               position_at_utc=datetime.fromtimestamp(timestamp, timezone.utc).isoformat(),
               age_seconds=max(0, int(age)),
               status='reloj_adelantado' if age < -60 else ('reciente' if age <= 900 else 'atrasada'))
    return row


def probe(client, token, now=None):
    if len(token) != 72 or not token.isascii() or not token.isalnum():
        raise ProbeError('Se necesita un token Wialon válido de 72 caracteres.')
    login = client.call('token/login', {'token': token, 'fl': 1})
    sid = login.get('eid')
    if not isinstance(sid, str) or not sid:
        raise ProbeError('Wialon no devolvió una sesión válida.')
    rows, warnings, seen = [], [], set()
    now = time.time() if now is None else now
    try:
        offset = 0
        while True:
            page = client.call('core/search_items', {
                'spec': {'itemsType': 'avl_unit', 'propName': 'sys_name',
                         'propValueMask': '*', 'sortType': 'sys_name', 'propType': 'property'},
                'force': 1 if offset == 0 else 0,
                'flags': 1025,  # General properties + last message and location.
                'from': offset, 'to': offset + 99,
            }, sid)
            items, total = page.get('items'), page.get('totalItemsCount')
            if (not isinstance(items, list) or type(total) is not int or total < 0 or
                    total > 10000 or offset + len(items) > total):
                raise ProbeError('Wialon devolvió una paginación inválida o más de 10,000 unidades.')
            for item in items:
                row = normalize_unit(item, now)
                if row['provider_unit_id'] in seen:
                    raise ProbeError('La lista de unidades cambió durante la consulta; repite la prueba.')
                seen.add(row['provider_unit_id'])
                rows.append(row)
            offset += len(items)
            if offset >= total:
                break
            if not items:
                raise ProbeError('La consulta de unidades quedó incompleta; repite la prueba.')
    finally:
        try:
            client.call('core/logout', {}, sid)
        except ProbeError:
            warnings.append('No se pudo confirmar el cierre de la sesión temporal.')
    if not rows:
        warnings.append('La cuenta no devolvió unidades visibles; verifica sus permisos.')
    return {'provider': 'epcom_wialon', 'checked_at_utc': datetime.fromtimestamp(now, timezone.utc).isoformat(),
            'unit_count': len(rows), 'units': rows, 'warnings': warnings}


def save_report(path, report):
    # Exclusive creation avoids overwriting reports or following an existing symlink.
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w', encoding='utf-8') as output:
        json.dump(report, output, ensure_ascii=False, indent=2)
        output.write('\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--authorize', action='store_true', help='Iniciar sesión en el portal; token temporal en memoria')
    parser.add_argument('--portal-url', default='https://gps.epcom.net')
    parser.add_argument('--api-url', help='Servidor API confirmado por EPCOM; no es necesariamente el portal')
    parser.add_argument('--token-file', type=Path, help='Archivo privado local con un token ya autorizado')
    parser.add_argument('--output', type=Path, help='Guardar ubicaciones en un archivo privado nuevo')
    args = parser.parse_args()
    try:
        if args.authorize and args.token_file:
            raise ProbeError('Usa --authorize o --token-file, no ambos.')
        if args.authorize:
            auth = authorize(secure_origin(args.portal_url))
            token = auth['token']
            api_url = args.api_url or callback_api_origin(auth['api_url'], args.portal_url)
        else:
            if not args.api_url:
                raise ProbeError('Falta --api-url; también puedes usar --authorize para iniciar sesión.')
            api_url = args.api_url
            token = args.token_file.read_text().strip() if args.token_file else getpass.getpass('Token Wialon (oculto): ')
        report = probe(WialonClient(api_url), token)
        counts = {}
        for unit in report['units']:
            counts[unit['status']] = counts.get(unit['status'], 0) + 1
        print(json.dumps({'unit_count': report['unit_count'], 'position_status': counts,
                          'warnings': report['warnings']}, ensure_ascii=False, indent=2))
        if args.output:
            save_report(args.output, report)
            print('Reporte privado guardado. No contiene el token ni la sesión.')
        return 0
    except ProbeError as error:
        print('Prueba pendiente: ' + str(error), file=sys.stderr)
        return 1
    except OSError:
        print('No se pudo leer o crear el archivo local; el reporte debe tener un nombre nuevo.', file=sys.stderr)
        return 1
    except (KeyboardInterrupt, EOFError):
        print('Prueba cancelada.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
