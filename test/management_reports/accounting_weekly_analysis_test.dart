import 'dart:io';

import 'package:dicsa_operacion/app/commercial/commercial_store.dart';
import 'package:dicsa_operacion/app/contabilidad/contabilidad_income_statement_store.dart';
import 'package:dicsa_operacion/app/management_reports/accounting_weekly_analysis.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_accounting_pdf.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CommercialMarketEventRecord event(
  String id,
  String date,
  String flow,
  double kg,
  double amount, {
  String material = 'CARTON',
  String channel = 'menudeo',
  String? label,
}) => CommercialMarketEventRecord(
  sourceArea: channel,
  sourceEventId: id,
  eventAt: DateTime.parse(date),
  channel: channel,
  flow: flow,
  generalMaterialKey: material,
  generalMaterialLabel: label ?? material,
  volumeKg: kg,
  amountTotal: amount,
  unitPrice:
      999, // Report must weight captured amounts, not average unit prices.
);

ContabilidadIncomeStatementDataset statement(
  DateTimeRange range, {
  double sales = 1000,
  double purchases = 500,
  double expenses = 100,
  List<ContabilidadIncomeStatementBreakdownRow> breakdown = const [],
}) => ContabilidadIncomeStatementDataset(
  range: range,
  snapshot: ContabilidadIncomeStatementSnapshot(
    revenue: sales,
    otherIncome: 0,
    commercialCost: purchases,
    commercialResult: sales - purchases,
    operatingExpense: expenses,
    administrativeExpense: 0,
    financialExpense: 0,
    payrollExpense: 0,
    recognizedExpenses: expenses,
    periodResult: sales - purchases - expenses,
    internalExcluded: 0,
    reviewPending: 0,
  ),
  lines: [],
  sourceRows: [],
  familyExpenseRows: [],
  expenseBreakdown: breakdown.isNotEmpty || expenses == 0
      ? breakdown
      : [
          ContabilidadIncomeStatementBreakdownRow(
            label: 'Gastos operativos',
            amount: expenses,
            count: 1,
            sourceLabel: 'Bancos',
          ),
        ],
  otherIncomeBreakdown: [],
  reviewRows: [],
  familyRows: [],
  insights: [],
  warnings: [],
);

AccountingWeeklySource source(
  List<CommercialMarketEventRecord> events, {
  DateTime? at,
  List<ContabilidadIncomeStatementBreakdownRow> currentExpenses = const [],
  List<ContabilidadIncomeStatementBreakdownRow> previousExpenses = const [],
}) {
  final cut = AccountingWeeklyCut(at ?? DateTime(2026, 9, 18));
  return AccountingWeeklySource(
    cut: cut,
    events: events,
    currentStatement: statement(
      cut.current,
      breakdown: currentExpenses,
      expenses: currentExpenses.isEmpty
          ? 100
          : currentExpenses.fold<double>(0, (sum, row) => sum + row.amount),
    ),
    previousStatement: statement(
      cut.previous,
      sales: 800,
      breakdown: previousExpenses,
      expenses: previousExpenses.isEmpty
          ? 100
          : previousExpenses.fold<double>(0, (sum, row) => sum + row.amount),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Friday, partial weekdays, weekends and year boundaries compare equal weekdays',
    () {
      final thursday = AccountingWeeklyCut(DateTime(2026, 9, 17, 12));
      expect(
        thursday.current,
        DateTimeRange(start: DateTime(2026, 9, 14), end: DateTime(2026, 9, 17)),
      );
      expect(thursday.previous.end, DateTime(2026, 9, 10));
      expect(thursday.partial, isTrue);
      expect(thursday.contains(DateTime(2026, 9, 18)), isFalse);
      expect(thursday.contains(DateTime(2026, 9, 17, 23, 59, 59, 999)), isTrue);
      for (final day in [18, 19, 20]) {
        final cut = AccountingWeeklyCut(DateTime(2026, 9, day));
        expect(cut.current.end, DateTime(2026, 9, 18));
        expect(cut.previous.end, DateTime(2026, 9, 11));
        expect(cut.partial, isFalse);
        expect(cut.contains(DateTime(2026, 9, 19)), isFalse);
      }
      final january = AccountingWeeklyCut(DateTime(2027, 1, 1));
      expect(january.current.start, DateTime(2026, 12, 28));
      expect(january.previous.end, DateTime(2026, 12, 25));
    },
  );

  test(
    'commercial totals keep prior-only materials and use weighted prices',
    () {
      final report = AccountingWeeklyAnalysis(
        source([
          event('a', '2026-09-14', 'purchase', 100, 200),
          event('b', '2026-09-15', 'purchase', 300, 900, channel: 'mayoreo'),
          event('c', '2026-09-18T23:59:59', 'sale', 200, 900),
          event('d', '2026-09-11', 'sale', 100, 300, material: 'PLASTICO'),
          event('weekend', '2026-09-12', 'sale', 1000, 99999),
          event('future', '2026-09-19', 'sale', 1000, 99999),
        ]),
      );
      expect(report.current.purchases, 1100);
      expect(report.current.sales, 900);
      expect(report.current.result, -200);
      expect(report.previous.result, 300);
      final carton = report.materials.first;
      expect(carton.current.purchasePrice, 2.75);
      expect(carton.current.salePrice, 4.5);
      expect(report.materials.last.label, 'PLASTICO');
      expect(report.materials.last.current.sales, 0);
      expect(report.materials.last.previous.sales, 300);
      expect(
        report.channels.fold<double>(0, (sum, r) => sum + r.current.result),
        -200,
      );
    },
  );

  test('zero kg and zero or negative comparison baselines remain explicit', () {
    expect(accountingChangePercent(100, 0), isNull);
    expect(accountingChangePercent(0, 0), isNull);
    expect(accountingChangePercent(-50, -100), 50);
    expect(accountingChangePercent(50, -100), 150);
    expect(accountingChangePercent(50, 100), -50);
    final totals = AccountingTradeTotals([
      event('zero', '2026-09-18', 'sale', 0, 100),
    ]);
    expect(totals.salePrice, isNull);
    expect(totals.sales, 100);
  });

  test('unknown flow is excluded rather than treated as sales', () {
    final report = AccountingWeeklyAnalysis(
      source([event('unknown', '2026-09-18', 'transfer', 200, 999)]),
    );
    expect(report.current.events, isEmpty);
    expect(report.ignoredEvents, 1);
  });

  test(
    'expense comparison keeps source separation and prior-only categories',
    () {
      ContabilidadIncomeStatementBreakdownRow row(
        String label,
        String source,
        double amount,
      ) => ContabilidadIncomeStatementBreakdownRow(
        label: label,
        amount: amount,
        count: 1,
        sourceLabel: source,
      );
      final report = AccountingWeeklyAnalysis(
        source(
          [],
          currentExpenses: [
            row('Fletes', 'Bancos', 300),
            row('Fletes', 'Menudeo', 50),
          ],
          previousExpenses: [
            row('Fletes', 'Bancos', 100),
            row('Renta', 'Bóveda', 1000),
          ],
        ),
      );
      expect(report.expenses, hasLength(3));
      expect(report.expenses.first.label, 'Renta');
      expect(report.expenses.first.current, 0);
      expect(report.expenses.first.change, -1000);
      expect(report.expenses.fold<double>(0, (sum, r) => sum + r.change), -750);
    },
  );

  test('statement date mismatch cannot be exported under another cutoff', () {
    final valid = source([]);
    final wrong = AccountingWeeklySource(
      cut: valid.cut,
      events: [],
      currentStatement: valid.previousStatement,
      previousStatement: valid.currentStatement,
    );
    expect(() => AccountingWeeklyAnalysis(wrong), throwsArgumentError);
  });

  test(
    'complete, empty and partial PDFs paginate all materials and long expense labels',
    () async {
      final rows = [
        for (var i = 0; i < 35; i++) ...[
          event(
            'buy-$i',
            '2026-09-15',
            'purchase',
            100,
            300,
            material: 'M-$i',
            label: 'MATERIAL DE PRUEBA $i',
          ),
          event('sell-$i', '2026-09-16', 'sale', 80, 400, material: 'M-$i'),
          event('prior-$i', '2026-09-08', 'sale', 60, 210, material: 'M-$i'),
        ],
      ];
      final expenses = [
        for (var i = 0; i < 27; i++)
          ContabilidadIncomeStatementBreakdownRow(
            label: 'GASTO $i ${List.filled(8, "DE OPERACIÓN").join(" ")}',
            amount: 100 + i.toDouble(),
            count: 1,
            sourceLabel: i.isEven ? 'Bancos' : 'Menudeo',
          ),
      ];
      for (final entry in {
        'contabilidad_viernes': source(rows, currentExpenses: expenses),
        'contabilidad_vacio': (() {
          final cut = AccountingWeeklyCut(DateTime(2026, 9, 18));
          return AccountingWeeklySource(
            cut: cut,
            events: [],
            currentStatement: statement(
              cut.current,
              sales: 0,
              purchases: 0,
              expenses: 0,
            ),
            previousStatement: statement(
              cut.previous,
              sales: 0,
              purchases: 0,
              expenses: 0,
            ),
          );
        })(),
        'contabilidad_parcial': source(
          rows.take(3).toList(),
          at: DateTime(2026, 9, 16),
        ),
      }.entries) {
        final bytes = await buildAccountingWeeklySupervisionPdfBytes(
          area: managementAreaDefinition(ManagementAreaKey.contabilidad),
          generatedAt: entry.value.cut.current.end,
          generatedBy: 'supervision@prueba.invalid',
          source: entry.value,
        );
        expect(bytes.take(4), [37, 80, 68, 70]);
        final dir = Platform.environment['DICSA_ACCOUNTING_QA_DIR'];
        if (dir != null) {
          await Directory(dir).create(recursive: true);
          await File('$dir/${entry.key}.pdf').writeAsBytes(bytes);
        }
      }
    },
  );
}
