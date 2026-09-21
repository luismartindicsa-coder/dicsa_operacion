import 'dart:io';

import 'package:dicsa_operacion/app/management_reports/operations_weekly_analysis.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_operations_daily_pdf.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_registry.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> ot(String id, {double? actual = 1500}) => {
  'id': id,
  'ot_folio': 'OT-$id',
  'status': 'cotizacion',
  'priority': 'alta',
  'impact': 'paro_parcial',
  'area_label': 'PATIO',
  'equipment_label': 'PRENSA $id',
  'assigned_to_name': 'RESPONSABLE DE PRUEBA',
  'problem_description': 'MANTENIMIENTO DE SISTEMA HIDRAULICO',
  'requested_at': '2026-09-01T08:00:00',
  'updated_at': '2026-09-17T10:00:00',
  'cost_estimated_total': 1000,
  'cost_actual_total': actual,
};

Map<String, dynamic> purchase(
  String id, {
  String linkedId = '1',
  String folio = 'OT-1',
  String? bought = '2026-09-17T11:00:00',
  double? actual = 120,
  String status = 'purchased',
}) => {
  'id': id,
  'folio': 'OC-$id',
  'order_date': '2026-09-01',
  'status': status,
  'quote_vendor_name': 'PROVEEDOR DE REFACCIONES',
  'target_label': 'PRENSA',
  'estimated_total': 100,
  'actual_total': actual,
  'purchased_at': bought,
  'linked_ot_id': linkedId,
  'linked_ot_folio': folio,
  'linked_material_label': 'REFACCION HIDRAULICA',
};

Map<String, dynamic> run(
  String id,
  String date, {
  String general = 'CARTON',
  String material = 'PACA_NACIONAL',
  double kg = 1000,
  int units = 2,
  String shift = 'DAY',
}) => {
  'id': id,
  'op_date': date,
  'shift': shift,
  'general_material': {'code': general},
  'outputs': [
    {
      'commercial_material_id': material,
      'commercial_material': {
        'code': material,
        'name': material.replaceAll('_', ' '),
      },
      'output_weight_kg': kg,
      'output_unit_count': units,
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final at = DateTime(2026, 9, 18, 14);
  final area = managementAreaDefinition(ManagementAreaKey.operaciones);

  test('weekly purchases and accumulated OT costs never add together', () {
    final data = OperationsWeeklyAnalysis(
      OperationsWeeklySource(
        orders: [ot('1')],
        purchases: [
          purchase('a'),
          purchase('b', actual: 80),
          purchase('unlinked', linkedId: '', folio: ''),
        ],
      ),
      at,
    );
    expect(data.expenses.current.actual, 200);
    expect(data.costs.single.actual, 1500);
    expect(data.costs.single.purchases.actual, 200);
    expect(data.costs.single.variance, 500);
    expect(data.expenses.current.variance, 0);
  });

  test('uses purchase date and excludes future, rejected and unlinked OCs', () {
    final data = OperationsWeeklyAnalysis(
      OperationsWeeklySource(
        orders: [ot('1')],
        purchases: [
          purchase('week'),
          purchase('previous', bought: '2026-09-10T11:00:00'),
          purchase('future', bought: '2026-09-18T15:00:00'),
          purchase('rejected', status: 'rejected'),
          purchase('undated', bought: null),
          purchase('pending', status: 'authorized', bought: null),
        ],
      ),
      at,
    );
    expect(data.expenses.current.rows.single.id, 'week');
    expect(data.expenses.previous.rows.single.id, 'previous');
    expect(data.expenses.undatedPurchases.single.id, 'undated');
    expect(data.expenses.pending.single.id, 'pending');
  });

  test('missing and default zero amounts cannot create savings', () {
    final data = OperationsWeeklyAnalysis(
      OperationsWeeklySource(
        orders: [ot('1', actual: 0)],
        purchases: [
          purchase('zero', actual: 0),
          purchase('null', actual: null),
        ],
      ),
      at,
    );
    expect(data.expenses.current.withoutActual, 2);
    expect(data.expenses.current.variance, isNull);
    expect(data.costs.single.actual, isNull);
    expect(data.costs.single.variance, isNull);
  });

  test('FK wins; unresolved and ambiguous links remain explicit', () {
    final data = OperationsWeeklyAnalysis(
      OperationsWeeklySource(
        orders: [
          ot('1'),
          {...ot('2'), 'ot_folio': 'DUP'},
          {...ot('3'), 'ot_folio': 'DUP'},
        ],
        purchases: [
          purchase('valid'),
          purchase('stale', linkedId: 'missing'),
          purchase('folio', linkedId: ''),
          purchase('ambiguous', linkedId: '', folio: 'DUP'),
        ],
      ),
      at,
    );
    expect(data.expenses.current.actual, 480);
    expect(data.costs.first.purchases.actual, 240);
    expect(data.unresolvedPurchases.map((r) => r.id).toSet(), {
      'stale',
      'ambiguous',
    });
  });

  test(
    'V2 production replaces cardboard legacy without losing other materials',
    () {
      final data = OperationsWeeklyAnalysis(
        OperationsWeeklySource(
          transformations: [
            run('c', '2026-09-17'),
            run(
              'p',
              '2026-09-17',
              general: 'PAPEL',
              material: 'PAPEL',
              kg: 300,
            ),
          ],
          legacyProduction: [
            {
              'op_date': '2026-09-17',
              'shift': 'DAY',
              'bale_material': 'BALE_NATIONAL',
              'bale_count': 99,
            },
          ],
        ),
        at,
      );
      expect(data.currentProduction.kg, 1300);
      expect(data.currentProduction.units, 4);
      expect(data.currentProduction.rows.any((r) => r.legacy), isFalse);
    },
  );

  test(
    'legacy fallback is separate for each compared window and has no invented kg',
    () {
      final data = OperationsWeeklyAnalysis(
        OperationsWeeklySource(
          transformations: [run('c', '2026-09-17')],
          legacyProduction: [
            {
              'op_date': '2026-09-10',
              'shift': 'NIGHT',
              'bale_material': 'BALE_NATIONAL',
              'bale_count': 3,
            },
          ],
        ),
        at,
      );
      expect(data.currentProduction.kg, 1000);
      expect(data.previousProduction.units, 3);
      expect(data.previousProduction.hasWeight, isFalse);
      expect(data.previousProduction.missingWeight, 1);
      expect(
        data.productionByMaterial(previous: true).keys.single,
        'PACA_NACIONAL',
      );
    },
  );

  test(
    'same weekday comparison and weekend cut exclude later operational days',
    () {
      final source = OperationsWeeklySource(
        transformations: [
          run('mon', '2026-09-14'),
          run('wed', '2026-09-16'),
          run('future', '2026-09-17'),
          run('sat', '2026-09-19'),
          run('prev-wed', '2026-09-09', kg: 500),
          run('prev-thu', '2026-09-10'),
        ],
      );
      final data = OperationsWeeklyAnalysis(source, DateTime(2026, 9, 16, 12));
      expect(data.currentProduction.kg, 2000);
      expect(data.previousProduction.kg, 500);
      final weekend = OperationsWeeklyAnalysis(source, DateTime(2026, 9, 20));
      expect(weekend.cut.start, DateTime(2026, 9, 14));
      expect(weekend.cut.end.day, 18);
      expect(weekend.currentProduction.kg, 3000);
    },
  );

  test('empty transformation is flagged and never replaced with legacy', () {
    final data = OperationsWeeklyAnalysis(
      OperationsWeeklySource(
        transformations: [
          {...run('c', '2026-09-17'), 'outputs': []},
        ],
        legacyProduction: [
          {
            'op_date': '2026-09-17',
            'bale_material': 'BALE_NATIONAL',
            'bale_count': 99,
          },
        ],
      ),
      at,
    );
    expect(data.currentProduction.rows, isEmpty);
    expect(data.warnings, contains(contains('sin salidas')));
  });

  test('complete Friday PDF paginates dense data and empty source', () async {
    final source = OperationsWeeklySource(
      orders: [
        for (var i = 1; i <= 28; i++)
          ot('$i', actual: i % 3 == 0 ? null : 1500),
      ],
      purchases: [
        for (var i = 1; i <= 35; i++)
          purchase(
            '$i',
            linkedId: '${i % 28 + 1}',
            folio: 'OT-${i % 28 + 1}',
            actual: i % 5 == 0 ? null : i * 25.0,
          ),
        purchase('open', status: 'authorized', bought: null),
        purchase('undated', bought: null),
      ],
      transformations: [
        for (var i = 0; i < 18; i++)
          run(
            '$i',
            '2026-09-${14 + i % 5}',
            material: 'MATERIAL_$i',
            shift: i.isEven ? 'DAY' : 'NIGHT',
          ),
        for (var i = 0; i < 18; i++)
          run(
            'p$i',
            '2026-09-${(7 + i % 5).toString().padLeft(2, '0')}',
            material: 'MATERIAL_$i',
            kg: 800,
          ),
      ],
    );
    final bytes = await buildOperationsWeeklySupervisionPdfBytes(
      area: area,
      generatedAt: at,
      generatedBy: 'PRUEBA - DATOS FICTICIOS',
      source: source,
    );
    expect(bytes.length, greaterThan(1000));
    final qa = Platform.environment['DICSA_OPERATIONS_QA_DIR'];
    if (qa != null) {
      await Directory(qa).create(recursive: true);
      await File('$qa/operaciones_viernes.pdf').writeAsBytes(bytes);
    }
    final empty = await buildOperationsWeeklySupervisionPdfBytes(
      area: area,
      generatedAt: DateTime(2026, 9, 20),
      generatedBy: 'PRUEBA - SIN DATOS',
      source: const OperationsWeeklySource(),
    );
    expect(empty.length, greaterThan(1000));
    final daily = await buildOperationsDailySupervisionPdfBytes(
      area: area,
      generatedAt: at,
      generatedBy: 'PRUEBA',
      orders: [
        {...ot('1'), 'requested_at': '2026-09-18T08:00:00'},
      ],
    );
    if (qa != null) {
      await File('$qa/operaciones_viernes_vacio.pdf').writeAsBytes(empty);
      await File('$qa/operaciones_diario.pdf').writeAsBytes(daily);
    }
      expect(
        area.reportsFor(ManagementReportFrequency.daily).single.key,
        'operations_new_ot_daily',
      );
      final denseDaily = await buildOperationsDailySupervisionPdfBytes(
        area: area,
        generatedAt: at,
        generatedBy: 'PRUEBA',
        orders: [
          for (var i = 0; i < 45; i++)
            {...ot('$i'), 'requested_at': '2026-09-18T08:00:00'},
        ],
      );
      expect(denseDaily.length, greaterThan(daily.length));
  });
}
