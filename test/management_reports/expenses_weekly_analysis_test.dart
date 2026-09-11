import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/management_reports/expenses_weekly_analysis.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_operations_daily_pdf.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_registry.dart';

ExpensesWeeklyOrder order(
  String id, {
  DateTime? date,
  DateTime? bought,
  String status = 'purchased',
  double? estimated = 100,
  double? actual = 120,
  DateTime? created,
  String vendor = 'PROVEEDOR DE PRUEBA',
  String ot = 'OT-123',
}) => ExpensesWeeklyOrder(
  id: id,
  folio: id,
  orderDate: date ?? DateTime(2026, 9, 7),
  status: status,
  vendor: vendor,
  target: 'TALLER / UNIDAD 123',
  concept:
      'REFACCION DE PRUEBA CON DESCRIPCION EXTENSA PARA VERIFICAR EL REPORTE',
  ot: ot,
  estimated: estimated,
  actual: actual,
  purchasedAt: bought,
  sentToCashAt: null,
  createdAt: created,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 9, 11, 15);
  test('purchases use purchase date, not order date or update date', () {
    final data = ExpensesWeeklyAnalysis([
      order(
        'old-order',
        date: DateTime(2026, 8, 1),
        bought: DateTime(2026, 9, 10),
      ),
      order('future', bought: DateTime(2026, 9, 11, 16)),
      order('undated'),
      order(
        'previous',
        date: DateTime(2026, 9, 1),
        bought: DateTime(2026, 9, 3),
      ),
      order('rejected', status: 'rejected', bought: now),
    ], ExpensesWeeklyCut(now));
    expect(data.current.rows.map((r) => r.id), ['old-order']);
    expect(data.previous.rows.map((r) => r.id), ['previous']);
    expect(data.undatedPurchases.length, 1);
    expect(data.pending, isEmpty);
  });
  test('variance only compares the same rows with both values', () {
    final data = ExpensesWeeklyAnalysis([
      order('pair', bought: now),
      order('no-real', bought: now, actual: null, estimated: 900),
      order('no-estimate', bought: now, estimated: null, actual: 400),
    ], ExpensesWeeklyCut(now));
    expect(data.current.actual, 520);
    expect(data.current.comparableEstimate, 100);
    expect(data.current.comparableActual, 120);
    expect(data.current.variance, 20);
    expect(data.current.variancePercent, 20);
    expect(data.current.withoutActual, 1);
  });
  test('missing values and zero estimate never create artificial savings', () {
    final data = ExpensesWeeklySummary([
      order('missing', actual: null),
      order('zero-estimate', estimated: 0),
    ]);
    expect(data.variance, isNull);
    expect(data.variancePercent, isNull);
    expect(data.comparable, isEmpty);
  });
  test('weekend closes Friday; previous week has matching partial cutoff', () {
    final saturday = ExpensesWeeklyCut(DateTime(2026, 9, 12, 10));
    expect(saturday.start, DateTime(2026, 9, 7));
    expect(saturday.end.day, 11);
    expect(saturday.contains(DateTime(2026, 9, 12)), isFalse);
    final wednesday = ExpensesWeeklyCut(DateTime(2026, 9, 9, 13));
    expect(wednesday.previousEnd, DateTime(2026, 9, 2, 13));
    expect(
      wednesday.contains(DateTime(2026, 9, 2, 14), previous: true),
      isFalse,
    );
  });
  test('backlog excludes rejected, purchased and future records', () {
    final data = ExpensesWeeklyAnalysis([
      order('active', status: 'authorized', date: DateTime(2026, 8, 1)),
      order('rejected', status: 'rejected'),
      order('purchased', bought: now),
      order('future', status: 'draft', created: DateTime(2026, 9, 12)),
    ], ExpensesWeeklyCut(now));
    expect(data.pending.single.id, 'active');
    expect(data.backlog.single.id, 'active');
    expect(data.pendingEstimate, 100);
  });
  test(
    'grouped totals reconcile to the weekly actual and keep unlinked OTs',
    () {
      final data = ExpensesWeeklyAnalysis([
        order('a', bought: now, vendor: 'A', actual: 50),
        order('b', bought: now, vendor: 'B', actual: 300, ot: ''),
      ], ExpensesWeeklyCut(now));
      expect(
        data
            .groupBy((r) => r.vendor)
            .values
            .fold<double>(0, (sum, s) => sum + s.actual),
        data.current.actual,
      );
      expect(data.groupBy((r) => r.ot).containsKey(''), isTrue);
    },
  );
  test(
    'complete PDF handles many rows, empty data and missing amounts',
    () async {
      final area = managementAreaCatalog.singleWhere(
        (a) => a.key == ManagementAreaKey.gastos,
      );
      final rows = [
        for (var i = 0; i < 35; i++)
          order(
            'OCM-${i.toString().padLeft(6, '0')}',
            bought: now,
            actual: i % 5 == 0 ? null : 120 + i.toDouble(),
            estimated: i % 7 == 0 ? null : 100,
            vendor: 'PROVEEDOR ${i % 4}',
            ot: i % 3 == 0 ? '' : 'OT-${i % 5}',
          ),
        order('OCM-PENDING', status: 'authorized', date: DateTime(2026, 8, 1)),
        order('OCM-NO-DATE'),
      ];
      final bytes = await buildExpensesWeeklySupervisionPdfBytes(
        area: area,
        generatedAt: now,
        generatedBy: 'PRUEBA DE FORMATO - DATOS FICTICIOS',
        orders: rows,
      );
      expect(bytes.length, greaterThan(1000));
      final qaPath = Platform.environment['DICSA_EXPENSES_QA_PDF'];
      if (qaPath != null) await File(qaPath).writeAsBytes(bytes);
      final empty = await buildExpensesWeeklySupervisionPdfBytes(
        area: area,
        generatedAt: now,
        generatedBy: 'PRUEBA',
        orders: [],
      );
      expect(empty.length, greaterThan(1000));
    },
  );
}
