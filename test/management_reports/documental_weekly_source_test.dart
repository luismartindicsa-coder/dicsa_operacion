import 'dart:convert';

import 'package:dicsa_operacion/app/management_reports/documental_weekly_source.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_pdf_export.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  var size = 505;
  var expected = 505;
  var denied = false;
  var failRecords = false;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://documental-report-test.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((r) async {
        requests.add(r);
        final resource = r.url.pathSegments.last;
        if ((denied && resource == 'documental_dashboard') ||
            (failRecords && resource == 'documental_records')) {
          return http.Response(
            '{"message":"permission denied","code":"42501"}',
            403,
            request: r,
          );
        }
        final Object response;
        if (resource == 'documental_dashboard') {
          expect(r.method, 'POST');
          response = {
            'context': {
              'today': '2026-09-18',
              'seconds_to_midnight': 3600,
              'responsibles': [
                {'id': 'owner', 'label': 'Responsable real'},
              ],
            },
            'metrics': <String, int>{},
            'categories': {
              'documentacion-legal': {
                'total': expected,
                'upcoming': 0,
                'expired': 0,
                'pending': 0,
              },
            },
            'upcoming': [],
            'upcoming_total': 0,
          };
        } else if (resource == 'documental_records') {
          expect(r.method, 'GET');
          final offset = int.parse(r.url.queryParameters['offset']!);
          final limit = int.parse(r.url.queryParameters['limit']!);
          expect(r.url.queryParameters['order'], startsWith('id.asc'));
          expect(r.url.queryParameters['select'], contains('next_action'));
          response = [
            for (var i = offset; i < size && i < offset + limit; i++)
              {
                'id': '$i',
                'category': 'documentacion-legal',
                'title': 'Expediente real $i',
                'document_type': 'Actas',
                'status': 'Pendiente',
                'priority': 'Media',
                'responsible_user_id': 'owner',
                'reference': 'REAL-$i',
                'revision': 1,
                'expiration_date': '2026-09-20',
                'next_action': 'VALIDAR EXPEDIENTE REAL',
              },
          ];
        } else {
          throw StateError('Unexpected source: $resource');
        }
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  setUp(() {
    requests.clear();
    size = expected = 505;
    denied = failRecords = false;
  });

  test(
    'loads every page and the business date from the authorized dashboard',
    () async {
      final source = await loadDocumentalWeeklySource();
      expect(source.records, hasLength(505));
      expect(source.records.last.id, '504');
      expect(source.context.today, DateTime(2026, 9, 18));
      expect(requests.map((r) => r.url.pathSegments.last), [
        'documental_dashboard',
        'documental_records',
        'documental_records',
      ]);
    },
  );

  test('denied access cannot produce an empty report', () async {
    denied = true;
    await expectLater(
      loadDocumentalWeeklySource(),
      throwsA(isA<PostgrestException>()),
    );
    expect(requests, hasLength(1));
  });

  test('source failures and incomplete pages stop report generation', () async {
    failRecords = true;
    await expectLater(
      loadDocumentalWeeklySource(),
      throwsA(isA<PostgrestException>()),
    );
    failRecords = false;
    size = 400;
    await expectLater(loadDocumentalWeeklySource(), throwsStateError);
  });

  test(
    'central Friday export dispatches to document data, not the catalogue',
    () async {
      size = expected = 2;
      final bytes = await buildManagementReportPdfBytes(
        area: managementAreaDefinition(ManagementAreaKey.gestion),
        frequency: ManagementReportFrequency.weeklyFriday,
        generatedAt: DateTime(2026, 9, 18),
        generatedBy: 'prueba',
      );
      expect(bytes.take(4), [37, 80, 68, 70]);
      expect(requests.map((r) => r.url.pathSegments.last), [
        'documental_dashboard',
        'documental_records',
      ]);
    },
  );
}
