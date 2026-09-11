import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/gerencia/gerencia_bale_weekly_tracking_store.dart';
import 'package:dicsa_operacion/app/management_reports/gerencia_weekly_analysis.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_operations_daily_pdf.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_registry.dart';

GerenciaBaleWeeklyTrackingBundle fixture({
  int types = 1,
  int? target = 60,
  int daily = 5,
  DateTime? week,
}) {
  final start = week ?? DateTime(2026, 9, 7);
  final lines = [
    for (var i = 0; i < types; i++)
      GerenciaBaleWeeklyLineSummary(
        baleType: GerenciaBaleTypeRecord(
          key: '$i',
          label: 'CARTON COMERCIAL TIPO $i',
          sortOrder: i,
          isActive: true,
        ),
        planLine: target == null
            ? null
            : GerenciaBaleWeeklyPlanLineRecord(
                id: '$i',
                baleTypeKey: '$i',
                sortOrder: i,
                productionTargetBales: target,
                shipmentTargetBales: target,
                notes:
                    'Programar capacidad y confirmar disponibilidad con las areas responsables.',
              ),
        productionActualBales: 9999,
        shipmentActualBales: 9999,
        productionEstimatedBales: 9999,
        shipmentEstimatedBales: 9999,
        productionNeedBales: 0,
        shipmentNeedBales: 0,
        dailyActuals: [
          for (var d = 0; d < 6; d++)
            GerenciaBaleDailyActualRecord(
              opDate: start.add(Duration(days: d)),
              productionBales: daily,
              shipmentBales: daily,
              expectedProductionCumulativeBales: 0,
              expectedShipmentCumulativeBales: 0,
              actualProductionCumulativeBales: 0,
              actualShipmentCumulativeBales: 0,
            ),
        ],
      ),
  ];
  return GerenciaBaleWeeklyTrackingBundle(
    weekStartDate: start,
    weekEndDate: start.add(const Duration(days: 5)),
    baleTypes: lines.map((r) => r.baleType).toList(),
    currentPlan: target == null
        ? null
        : GerenciaBaleWeeklyPlanRecord(
            id: 'p',
            weekStartDate: start,
            weekEndDate: start.add(const Duration(days: 5)),
            status: 'open',
            notes: 'Meta semanal registrada por el equipo.',
            closedAt: null,
            snapshotProductionActualBales: null,
            snapshotProductionTargetBales: null,
            snapshotShipmentActualBales: null,
            snapshotShipmentTargetBales: null,
            snapshotRefreshedAt: null,
            lines: lines.map((r) => r.planLine!).toList(),
          ),
    lineSummaries: lines,
    unmappedProductionCodes: ['SIN-MAPEO'],
    unmappedShipmentCodes: [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final friday = DateTime(2026, 9, 11, 15);
  test('Friday excludes Saturday real and uses six-day target pacing', () {
    final data = GerenciaWeeklyAnalysis(fixture(), friday);
    final goal = data.goals.first;
    expect(goal.actual, 25);
    expect(goal.expected, 50);
    expect(goal.gap, -25);
    expect(goal.remaining, 35);
    expect(goal.requiredPerDay, 35);
    expect(goal.projected, 30);
    expect(goal.state, 'Debajo del ritmo');
  });
  test('missing and zero targets are not failures or full compliance', () {
    for (final target in [null, 0]) {
      final data = GerenciaWeeklyAnalysis(fixture(target: target), friday);
      expect(data.goals.first.state, 'Sin meta definida');
      expect(data.goals.first.progress, isNull);
      expect(data.goals.first.remaining, isNull);
    }
  });
  test('reaching target does not produce negative remaining', () {
    final goal = GerenciaWeeklyAnalysis(fixture(daily: 20), friday).goals.first;
    expect(goal.remaining, 0);
    expect(goal.state, 'Meta alcanzada');
    expect(goal.progress, greaterThan(100));
  });
  test('close uses no remaining days and reports missed goal', () {
    final goal = GerenciaWeeklyAnalysis(
      fixture(),
      DateTime(2026, 9, 13),
    ).goals.first;
    expect(goal.actual, 30);
    expect(goal.state, 'Meta no alcanzada');
    expect(goal.requiredPerDay, isNull);
  });
  test('previous comparison uses the same weekday, not full weekly total', () {
    final previous = GerenciaWeeklyAnalysis(
      fixture(week: DateTime(2026, 8, 31)),
      friday.subtract(const Duration(days: 7)),
    );
    expect(previous.actual('Produccion'), 25);
  });
  test(
    'reports all goal lines independently and prioritizes missing definitions',
    () {
      final data = GerenciaWeeklyAnalysis(
        fixture(types: 3, target: null),
        friday,
      );
      expect(data.goals.length, 6);
      expect(data.priorities.length, 6);
      expect(data.actual('Produccion'), 75);
    },
  );
  test('renders missing plan without inventing goals or assignments', () async {
    final bytes = await buildGerenciaWeeklySupervisionPdfBytes(
      area: managementAreaCatalog.singleWhere(
        (a) => a.key == ManagementAreaKey.gerencia,
      ),
      generatedAt: friday,
      generatedBy: 'PRUEBA',
      bundle: fixture(target: null),
      previousBundle: fixture(target: null, week: DateTime(2026, 8, 31)),
      dashboardSections: const [],
    );
    expect(bytes.length, greaterThan(1000));
  });
  test(
    'renders complete report with many materials and dashboard sections',
    () async {
      final bytes = await buildGerenciaWeeklySupervisionPdfBytes(
        area: managementAreaCatalog.singleWhere(
          (a) => a.key == ManagementAreaKey.gerencia,
        ),
        generatedAt: friday,
        generatedBy: 'PRUEBA - DATOS FICTICIOS',
        bundle: fixture(types: 10),
        previousBundle: fixture(types: 10, week: DateTime(2026, 8, 31)),
        dashboardSections: [
          for (final title in [
            'Produccion diaria consolidada por turno',
            'Produccion por material y turno',
            'Flujo de material operativo',
            'Logistica - pulso semanal',
            'Logistica por operador',
            'Logistica por unidad',
          ])
            GerenciaReportSection(
              title,
              ['Indicador', 'Valor'],
              [
                for (var i = 0; i < 10; i++) ['Dato de prueba $i', '$i'],
              ],
              note: 'Datos ficticios para verificacion de formato.',
            ),
        ],
      );
      expect(bytes.length, greaterThan(1000));
      final path = Platform.environment['DICSA_GERENCIA_QA_PDF'];
      if (path != null) await File(path).writeAsBytes(bytes);
    },
  );
}
