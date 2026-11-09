import io
import json
import os
import queue
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.parse import parse_qs, urlencode, urlsplit
from urllib.request import urlopen

from epcom_gps_probe import (NoRedirect, ProbeError, WialonClient, authorize, callback_api_origin,
                             login_url, normalize_unit, probe, save_report, secure_origin)


TOKEN = 'a' * 72
NOW = 1800000000


class FakeOpener:
    def __init__(self, responses):
        self.responses = iter(responses)
        self.requests = []

    def open(self, request, timeout):
        self.requests.append(request)
        response = next(self.responses)
        if isinstance(response, Exception):
            raise response
        return io.BytesIO(json.dumps(response).encode())


def page(items, total=None):
    return {'items': items, 'totalItemsCount': len(items) if total is None else total}


class EpcomProbeTests(unittest.TestCase):
    def test_pagination_post_credentials_and_logout(self):
        opener = FakeOpener([
            {'eid': 'private-session'},
            page([{'id': 1, 'nm': 'T-01', 'pos': {'x': -100, 'y': 20, 't': NOW - 60}}], 2),
            page([{'id': 2, 'nm': 'T-02', 'pos': None}], 2),
            {'error': 0},
        ])
        report = probe(WialonClient('https://hst-api.wialon.com', opener), TOKEN, NOW)
        self.assertEqual(report['unit_count'], 2)
        self.assertEqual([r['status'] for r in report['units']], ['reciente', 'sin_posicion'])
        self.assertNotIn(TOKEN, json.dumps(report))
        self.assertNotIn('private-session', json.dumps(report))
        for request in opener.requests:
            self.assertEqual(request.method, 'POST')
            self.assertNotIn(TOKEN, request.full_url)
            self.assertNotIn('private-session', request.full_url)
        forms = [parse_qs(r.data.decode()) for r in opener.requests]
        self.assertEqual(forms[-1]['svc'], ['core/logout'])
        self.assertEqual(json.loads(forms[2]['params'][0])['from'], 1)

    def test_access_denied_in_http_200_closes_session_without_exposing_reason(self):
        opener = FakeOpener([{'eid': 's'}, {'error': 7, 'reason': TOKEN}, {'error': 0}])
        with self.assertRaisesRegex(ProbeError, 'Acceso denegado') as error:
            probe(WialonClient('https://hst-api.wialon.com', opener), TOKEN)
        self.assertNotIn(TOKEN, str(error.exception))
        self.assertEqual(parse_qs(opener.requests[-1].data.decode())['svc'], ['core/logout'])

    def test_empty_account_is_not_misreported_as_a_connected_fleet(self):
        opener = FakeOpener([{'eid': 's'}, page([]), {'error': 0}])
        result = probe(WialonClient('https://hst-api.wialon.com', opener), TOKEN, NOW)
        self.assertEqual(result['unit_count'], 0)
        self.assertIn('no devolvió unidades', result['warnings'][0])

    def test_incomplete_and_repeating_pages_fail_and_logout(self):
        for second in [page([], 2), page([{'id': 1}], 2)]:
            opener = FakeOpener([{'eid': 's'}, page([{'id': 1}], 2), second, {'error': 0}])
            with self.assertRaises(ProbeError):
                probe(WialonClient('https://hst-api.wialon.com', opener), TOKEN, NOW)
            self.assertEqual(parse_qs(opener.requests[-1].data.decode())['svc'], ['core/logout'])

    def test_private_invalid_old_and_future_positions(self):
        for pos in [None, {'t': NOW, 'f': 262144}, {'x': -100, 'y': 91, 't': NOW},
                    {'x': float('nan'), 'y': 20, 't': NOW}]:
            row = normalize_unit({'id': 1, 'pos': pos}, NOW)
            self.assertIsNone(row['latitude'])
            self.assertEqual(row['status'], 'sin_posicion')
        for timestamp, status in [(NOW - 3600, 'atrasada'), (NOW + 120, 'reloj_adelantado')]:
            row = normalize_unit({'id': 1, 'pos': {'x': 0, 'y': 0, 't': timestamp}}, NOW)
            self.assertEqual(row['latitude'], 0)
            self.assertEqual(row['status'], status)

    def test_login_is_scoped_and_temporary(self):
        url = login_url('https://gps.epcom.net', 'http://127.0.0.1:1234/callback/test')
        self.assertEqual(urlsplit(url).hostname, 'gps.epcom.net')
        params = parse_qs(urlsplit(url).query)
        self.assertEqual(params['access_type'], ['256'])
        self.assertEqual(params['duration'], ['3600'])

    def test_browser_callback_keeps_token_out_of_page_and_logs(self):
        callbacks, results = queue.Queue(), queue.Queue()

        def capture_url(portal, callback, **kwargs):
            callbacks.put(callback)
            return login_url(portal, callback, **kwargs)

        def run():
            try:
                results.put(authorize('https://gps.epcom.net', timeout=5))
            except Exception as error:
                results.put(error)

        with patch('epcom_gps_probe.login_url', side_effect=capture_url), patch('builtins.print') as output:
            thread = threading.Thread(target=run, daemon=True)
            thread.start()
            callback = callbacks.get(timeout=3)
            with self.assertRaises(HTTPError) as error:
                urlopen(callback + '?access_token=invalid', timeout=2)
            self.assertEqual(error.exception.code, 400)
            with urlopen(callback + '?' + urlencode({
                    'access_token': TOKEN, 'wialon_sdk_url': 'https://hst-api.wialon.com'}), timeout=2) as response:
                html = response.read().decode()
                self.assertEqual(response.headers['Cache-Control'], 'no-store')
                self.assertEqual(response.headers['Referrer-Policy'], 'no-referrer')
            thread.join(timeout=3)
            self.assertFalse(thread.is_alive())
            self.assertNotIn(TOKEN, html)
            self.assertIn('history.replaceState', html)
            self.assertNotIn(TOKEN, str(output.call_args_list))
            self.assertEqual(results.get_nowait()['token'], TOKEN)

    def test_endpoint_validation_and_callback_origin_restriction(self):
        for url in ['http://gps.epcom.net', 'https://user:pass@gps.epcom.net',
                    'https://gps.epcom.net/?token=secret', 'https://gps.epcom.net:4433',
                    'https://gps.epcom.net/other']:
            with self.assertRaises(ProbeError):
                secure_origin(url)
        for url in ['https://hst-api.wialon.com.attacker.example', 'https://unrelated.example', '']:
            with self.assertRaises(ProbeError):
                callback_api_origin(url, 'https://gps.epcom.net')
        self.assertEqual(callback_api_origin('https://hst-api.wialon.us/', 'https://gps.epcom.net'),
                         'https://hst-api.wialon.us')

    def test_redirects_and_mutations_are_not_permitted(self):
        self.assertIsNone(NoRedirect().redirect_request(None, None, None, None, None, None))
        opener = FakeOpener([HTTPError('https://hst-api.wialon.com', 302, TOKEN, {}, None)])
        client = WialonClient('https://hst-api.wialon.com', opener)
        with self.assertRaisesRegex(ProbeError, 'HTTP 302') as error:
            client.call('token/login', {'token': TOKEN})
        self.assertNotIn(TOKEN, str(error.exception))
        with self.assertRaises(ProbeError):
            client.call('unit/exec_cmd', {})
        self.assertEqual(len(opener.requests), 1)

    def test_failed_logout_is_visible_in_result(self):
        opener = FakeOpener([{'eid': 's'}, page([{'id': 1}]), {'error': 1}])
        report = probe(WialonClient('https://hst-api.wialon.com', opener), TOKEN, NOW)
        self.assertIn('cierre', report['warnings'][0])

    def test_report_is_private_and_does_not_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'probe.json'
            save_report(path, {'unit_count': 1})
            self.assertEqual(os.stat(path).st_mode & 0o777, 0o600)
            with self.assertRaises(FileExistsError):
                save_report(path, {'unit_count': 2})
            self.assertEqual(json.loads(path.read_text()), {'unit_count': 1})


if __name__ == '__main__':
    unittest.main()
