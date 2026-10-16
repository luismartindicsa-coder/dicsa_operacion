import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dicsa_operacion/app/shared/production_daily_summary_widget.dart';
import 'package:dicsa_operacion/app/shared/utils/production_compactor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final database = <String, List<Map<String, dynamic>>>{};
  final requests = <http.Request>[];
  Completer<void>? blockNextRuns;
  const runsTable = 'material_transformation_runs_v2';
  final week = DateTime(2026, 10, 12);

  setUpAll(() async {
    await (FontLoader('Roboto')..addFont(
          File(
            'assets/fonts/Roboto-Regular.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://summary-test.invalid',
      anonKey: 'test-only-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        requests.add(request);
        final table = request.url.pathSegments.last;
        if (table == runsTable && blockNextRuns != null) {
          final wait = blockNextRuns!;
          blockNextRuns = null;
          await wait.future;
        }
        final params = request.url.queryParameters;
        final rows = (database[table] ?? [])
            .where((row) {
              for (final entry in request.url.queryParametersAll.entries) {
                for (final condition in entry.value) {
                  final value = row[entry.key]?.toString() ?? '';
                  if (condition.startsWith('eq.') &&
                      value != condition.substring(3)) {
                    return false;
                  }
                  if (condition.startsWith('gte.') &&
                      value.compareTo(condition.substring(4)) < 0) {
                    return false;
                  }
                  if (condition.startsWith('lte.') &&
                      value.compareTo(condition.substring(4)) > 0) {
                    return false;
                  }
                }
              }
              return true;
            })
            .skip(int.tryParse(params['offset'] ?? '') ?? 0)
            .take(int.tryParse(params['limit'] ?? '') ?? 1000)
            .toList();
        return http.Response(
          jsonEncode(rows),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    requests.clear();
    blockNextRuns = null;
    database.clear();
    database.addAll({
      'material_general_catalog_v2': [
        {'id': 'carton', 'code': 'CARTON'},
        {'id': 'papel', 'code': 'PAPEL'},
      ],
      runsTable: [],
      'production_runs': [],
    });
  });

  Map<String, dynamic> run(
    int count, {
    String notes = 'COMPACTADORA 1',
    String? outputNotes,
    String material = 'PACA_NACIONAL',
    String source = 'carton',
    String shift = 'DAY',
    DateTime? date,
  }) => {
    'id': 'run-${database[runsTable]!.length}',
    'op_date': (date ?? week).toIso8601String().substring(0, 10),
    'source_general_material_id': source,
    'shift': shift,
    'notes': notes,
    'outputs': [
      {
        'output_unit_count': count,
        'output_weight_kg': count * 850,
        'notes': outputNotes,
        'commercial_material': {'code': material},
      },
    ],
  };
  Future<ProductionDailySummaryBundle> load() =>
      ProductionDailySummaryStore.loadWeek(week, forceRefresh: true);
  int countFor(
    ProductionDailySummaryBundle bundle,
    String key, {
    String shift = 'DAY',
  }) => bundle.rows.singleWhere((row) => row.key == key).countFor(week, shift);
  void legacy(int count) => database['production_runs']!.add({
    'id': 'legacy',
    'op_date': '2026-10-12',
    'shift': 'DAY',
    'bale_material': 'BALE_NATIONAL',
    'bale_count': count,
    'notes': 'C2',
  });

  test(
    'historical machine variants are recognized without guessing ambiguous labels',
    () {
      for (final text in [
        'COMPACTADORA 2',
        'COMPACTADORA2',
        'COMPACTRADORA 2',
        'compactadora  2',
        'C2',
        'C 2',
      ]) {
        expect(productionCompactorNumberFromNotes(text), 2, reason: text);
      }
      for (final text in [
        '',
        'COMPACTADORA 10',
        'COMPACTADORA 21',
        'C1 C2',
        'COMPACTADORA 1 / COMPACTADORA2',
      ]) {
        expect(productionCompactorNumberFromNotes(text), isNull, reason: text);
      }
    },
  );

  test(
    'counts registered bales by day and shift, including historical C2 spellings',
    () async {
      database[runsTable]!.addAll([
        run(27, notes: 'COMPACTRADORA 2'),
        run(42, notes: 'COMPACTADORA2', shift: 'NIGHT'),
        run(10, notes: 'COMPACTADORA 1', outputNotes: ''),
        run(5, material: 'PACA_LIMPIA'),
        run(3, material: 'ARCHIVO', source: 'papel'),
      ]);
      legacy(999);
      final bundle = await load();
      expect(bundle.totalBales, 87);
      expect(bundle.days.first.dayShiftTotal, 45);
      expect(bundle.days.first.nightShiftTotal, 42);
      expect(countFor(bundle, 'revueltaC2'), 27);
      expect(countFor(bundle, 'revueltaC2', shift: 'NIGHT'), 42);
      expect(countFor(bundle, 'revueltaC1'), 10);
      expect(bundle.unassignedNationalCount, 0);
      expect(
        bundle.rows.where((row) => row.key == 'revueltaSinCompactadora'),
        isEmpty,
      );
      expect(
        requests.where(
          (request) => request.url.path.endsWith('/production_runs'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'unassigned modern bales remain in totals and never trigger legacy fallback',
    () async {
      database[runsTable]!.add(run(9, notes: 'SIN DATO'));
      legacy(999);
      final bundle = await load();
      expect(bundle.totalBales, 9);
      expect(bundle.unassignedNationalCount, 9);
      expect(countFor(bundle, 'revueltaSinCompactadora'), 9);
      expect(
        bundle.rows.fold<int>(0, (sum, row) => sum + row.countFor(week, 'DAY')),
        9,
      );
    },
  );

  test(
    'incomplete V2 runs are not replaced by unrelated legacy records',
    () async {
      database[runsTable]!.add({...run(1), 'outputs': <dynamic>[]});
      legacy(999);
      expect((await load()).totalBales, 0);
    },
  );

  test(
    'uses historical production only when the week has no modern carton runs',
    () async {
      legacy(12);
      database[runsTable]!.add(run(3, material: 'ARCHIVO', source: 'papel'));
      final bundle = await load();
      expect(bundle.totalBales, 15);
      expect(countFor(bundle, 'revueltaC2'), 12);
    },
  );

  test('fetches every page of a busy production week', () async {
    for (var i = 0; i < 1001; i++) {
      database[runsTable]!.add(run(3));
    }
    expect((await load()).totalBales, 3003);
    expect(
      requests.any((r) => r.url.queryParameters['offset'] == '1000'),
      isTrue,
    );
  });

  test(
    'forced refresh immediately reflects edits while ordinary callers share cache',
    () async {
      database[runsTable]!.add(run(10));
      expect((await load()).totalBales, 10);
      database[runsTable]![0] = run(20);
      expect((await ProductionDailySummaryStore.loadWeek(week)).totalBales, 10);
      expect((await load()).totalBales, 20);
    },
  );

  testWidgets('changing weeks during a pending load keeps the requested week', (
    tester,
  ) async {
    final now = DateUtils.dateOnly(DateTime.now());
    final current = now.subtract(Duration(days: now.weekday - DateTime.monday));
    database[runsTable]!.addAll([
      run(10, date: current),
      run(20, date: current.subtract(const Duration(days: 7)), notes: ''),
    ]);
    final gate = Completer<void>();
    blockNextRuns = gate;
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProductionDailySummaryWidget(
              title: 'Producción diaria consolidada',
              subtitle: 'Producción por turno',
              palette: ProductionDailySummaryPalette(
                surface: Colors.white,
                border: Colors.grey,
                accent: Colors.blue,
                accentSoft: Colors.lightBlue,
                text: Colors.black,
                mutedText: Colors.grey,
                gridLine: Colors.grey,
                highlightSurface: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(blockNextRuns, isNull);
    await tester.tap(find.text('Semana anterior'));
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('20 pacas'), findsOneWidget);
    expect(find.text('10 pacas'), findsNothing);
    expect(
      find.text('Revuelta sin compactadora'.toUpperCase()),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  final auditPath = Platform.environment['DICSA_PRODUCTION_AUDIT_SNAPSHOT'];
  if (auditPath != null) {
    test(
      'reconciles the read-only live snapshot against the production records',
      () async {
        final snapshot = jsonDecode(File(auditPath).readAsStringSync()) as Map;
        database['material_general_catalog_v2'] = (snapshot['general'] as List)
            .cast<Map<String, dynamic>>();
        database[runsTable] = (snapshot['runs'] as List)
            .cast<Map<String, dynamic>>();
        database['production_runs'] = (snapshot['legacy'] as List)
            .cast<Map<String, dynamic>>();
        final totals = <DateTime, int>{};
        for (final row in database[runsTable]!) {
          final date = DateTime.parse(row['op_date'] as String);
          if (date.weekday > DateTime.friday) continue;
          final start = date.subtract(
            Duration(days: date.weekday - DateTime.monday),
          );
          totals.update(
            start,
            (value) =>
                value +
                (row['outputs'] as List).fold<int>(
                  0,
                  (sum, output) =>
                      sum +
                      ((output['output_unit_count'] as num?)?.toInt() ?? 0),
                ),
            ifAbsent: () => (row['outputs'] as List).fold<int>(
              0,
              (sum, output) =>
                  sum + ((output['output_unit_count'] as num?)?.toInt() ?? 0),
            ),
          );
        }
        for (final entry in totals.entries) {
          final summary = await ProductionDailySummaryStore.loadWeek(
            entry.key,
            forceRefresh: true,
          );
          expect(summary.totalBales, entry.value, reason: 'Week ${entry.key}');
          expect(
            summary.unassignedNationalCount,
            0,
            reason: 'Week ${entry.key}',
          );
        }
      },
    );
  }
}
