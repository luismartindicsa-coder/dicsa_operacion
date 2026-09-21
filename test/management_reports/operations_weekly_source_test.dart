import 'dart:convert';

import 'package:dicsa_operacion/app/management_reports/operations_weekly_analysis.dart';
import 'package:dicsa_operacion/app/management_reports/operations_weekly_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  var fail = false;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://operations-test.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((r) async {
        requests.add(r);
        expect(r.method, 'GET');
        final table = r.url.pathSegments.last;
        if (fail && table == 'material_transformation_runs_v2') {
          return http.Response(
            '{"message":"permission denied","code":"42501"}',
            403,
            request: r,
          );
        }
        final rows = switch (table) {
          'maintenance_orders' => [
            {
              'id': 'ot',
              'ot_folio': 'OT-1',
              'requested_at': '2026-09-01',
              'status': 'cerrado',
              'cost_actual_total': 500,
            },
          ],
          'maintenance_purchase_orders' => [
            {
              'id': 'oc',
              'folio': 'OC-1',
              'order_date': '2026-09-01',
              'status': 'purchased',
              'purchased_at': '2026-09-17T08:00:00',
              'linked_ot_id': 'ot',
              'actual_total': 120,
              'lines': [
                {'description': 'Refaccion', 'qty': 2, 'amount': 50},
              ],
            },
          ],
          'material_transformation_runs_v2' => [
            {
              'id': 'v2',
              'op_date': '2026-09-17',
              'shift': 'DAY',
              'general_material': {'code': 'CARTON'},
              'outputs': [
                {
                  'commercial_material_id': 'mat',
                  'commercial_material': {
                    'code': 'PACA_LIMPIA',
                    'name': 'Paca limpia',
                  },
                  'output_weight_kg': 750,
                  'output_unit_count': 1,
                },
              ],
            },
          ],
          'production_runs' => <Map<String, dynamic>>[],
          _ => throw StateError('Unexpected source $table'),
        };
        return http.Response(
          jsonEncode(rows),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());

  test(
    'loads real source shapes, nested purchase lines and equivalent cutoff',
    () async {
      final at = DateTime(2026, 9, 20);
      final source = await loadOperationsWeeklySource(at);
      final report = OperationsWeeklyAnalysis(source, at);
      expect(report.expenses.current.actual, 120);
      expect(report.expenses.current.comparableEstimate, 100);
      expect(report.costs.single.purchases.rows.single.ot, 'OT-1');
      expect(report.currentProduction.kg, 750);
      for (final table in [
        'material_transformation_runs_v2',
        'production_runs',
      ]) {
        final query = requests
            .singleWhere((r) => r.url.pathSegments.last == table)
            .url
            .queryParametersAll;
        expect(query['op_date'], ['gte.2026-09-07', 'lte.2026-09-18']);
        expect(query['order']!.single, startsWith('id.asc'));
      }
    },
  );

  test(
    'missing source access fails instead of exporting a false zero report',
    () async {
      fail = true;
      await expectLater(
        loadOperationsWeeklySource(DateTime(2026, 9, 18)),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}
