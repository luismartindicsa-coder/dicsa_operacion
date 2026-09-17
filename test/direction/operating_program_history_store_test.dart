import 'dart:convert';

import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final week = DateTime(2026, 9, 14);
  final requests = <Uri>[];
  var failProduction = false;
  Map<String, dynamic> output(
    String id,
    String date,
    String material,
    int units, {
    String shift = 'DAY',
    int kg = 0,
  }) => {
    'id': id,
    'output_unit_count': units,
    'output_weight_kg': kg,
    'commercial_material': {'code': material},
    'run': {'op_date': date, 'shift': shift},
  };
  final modern = [
    for (var i = 0; i < 1001; i++)
      output('$i', '2026-09-07', 'PACA_NACIONAL', 1),
    output('paper', '2026-08-31', 'PAPEL', 0, kg: 999),
    output('unknown-shift', '2026-08-24', 'PACA_NACIONAL', 5, shift: 'unknown'),
    output('current', '2026-09-14', 'PACA_NACIONAL', 3),
  ];
  final legacy = [
    {
      'op_date': '2026-09-07',
      'shift': 'DAY',
      'bale_material': 'BALE_NATIONAL',
      'bale_count': 200,
    },
    {
      'op_date': '2026-08-31',
      'shift': 'NOCHE',
      'bale_material': 'BALE_CLEAN',
      'bale_count': 20,
    },
    {
      'op_date': '2026-08-17',
      'shift': 'DIA',
      'bale_material': 'BALE_AMERICAN',
      'bale_count': 10,
    },
  ];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://production-history-test.invalid',
      anonKey: 'test-only-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request.url);
        final isModern = request.url.path.endsWith(
          '/material_transformation_run_outputs_v2',
        );
        final isLegacy = request.url.path.endsWith('/production_runs');
        if (failProduction && isModern) {
          return http.Response(
            '{"message":"production unavailable"}',
            500,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        final params = request.url.queryParameters;
        List<Map<String, dynamic>> rows = isModern
            ? modern
            : isLegacy
            ? legacy
            : [];
        if (isModern || isLegacy) {
          final filters = request
              .url
              .queryParametersAll[isModern ? 'run.op_date' : 'op_date']!;
          final from = filters
              .firstWhere((f) => f.startsWith('gte.'))
              .substring(4);
          final to = filters
              .firstWhere((f) => f.startsWith('lte.'))
              .substring(4);
          rows = rows.where((r) {
            final date =
                (isModern ? (r['run'] as Map)['op_date'] : r['op_date'])
                    as String;
            return date.compareTo(from) >= 0 && date.compareTo(to) <= 0;
          }).toList();
          if (isModern) {
            expect(params['select'], contains('run:run_id!inner('));
            expect(params['order'], startsWith('id.asc'));
          }
          rows = rows
              .skip(int.parse(params['offset'] ?? '0'))
              .take(int.parse(params['limit'] ?? '1000'))
              .toList();
        }
        return http.Response(
          jsonEncode(rows),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  test(
    'reads all pages and retains legacy weeks without mixing sources or kg',
    () async {
      final bundle = await DirectionShipmentsStore.loadWeek(week);
      final h = ProgramConditions.fromReference(bundle).history!;
      expect(h.recordCount, 1003);
      expect(h.legacyRecordCount, 2);
      expect(h.unknownShiftCount, 1);
      expect(h.total(material: 'PACA_NACIONAL'), 1001);
      expect(h.total(material: 'PACA_LIMPIA', shift: 1), 20);
      expect(h.total(material: 'PACA_AMERICANA', shift: 0), 10);
      expect(h.total(), 1031);
      expect(h.observedWeeks, ['2026-08-17', '2026-08-31', '2026-09-07']);
      expect(
        requests
            .where(
              (u) => u.path.endsWith('/material_transformation_run_outputs_v2'),
            )
            .length,
        2,
      );
    },
  );

  test(
    'actual comparison reads only the program week from the same operation source',
    () async {
      final actual = await DirectionShipmentsStore.loadProgramProductionActuals(
        week,
      );
      expect(actual, [
        {
          'date': '2026-09-14',
          'material': 'PACA_NACIONAL',
          'shift': 'DAY',
          'quantity': 3,
        },
      ]);
    },
  );

  test(
    'a failed production read is not silently treated as missing history',
    () async {
      failProduction = true;
      addTearDown(() => failProduction = false);
      await expectLater(
        DirectionShipmentsStore.loadProgramProductionActuals(week),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}
