import 'package:dicsa_operacion/app/contabilidad/contabilidad_income_statement_store.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_engine.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_expense_coverage.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_expense_coverage_panel.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final october = StatementPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
Map<String, List<StatementRow>> sources() => {
  'finanzas_supplier_invoices': [
    {'id': 'current', 'invoice_date': '2026-10-01', 'total_amount': 116},
    {'id': 'prior', 'invoice_date': '2026-09-01', 'total_amount': 232},
  ],
  'finanzas_bank_movements': [
    {
      'id': 'b1',
      'movement_date': '2026-10-03',
      'category': 'SERVICIOS',
      'debit_amount': 116,
      'linked_supplier_invoice_id': 'current',
    },
    {
      'id': 'b2',
      'movement_date': '2026-10-03',
      'category': 'SERVICIOS',
      'debit_amount': 232,
      'linked_supplier_invoice_id': 'prior',
    },
    {
      'id': 'b3',
      'movement_date': '2026-10-03',
      'category': 'GASTOS ADMINISTRATIVOS',
      'debit_amount': 300,
    },
    {
      'id': 'credit',
      'movement_date': '2026-10-03',
      'category': 'GASTOS ADMINISTRATIVOS',
      'credit_amount': 999,
    },
    {
      'id': 'outside',
      'movement_date': '2026-09-03',
      'category': 'GASTOS ADMINISTRATIVOS',
      'debit_amount': 999,
    },
  ],
  'men_cash_vouchers': [
    {
      'id': 'v1',
      'voucher_date': '2026-10-02',
      'voucher_type': 'expense',
      'rubric': 'Operativo',
      'total_amount': 100,
      'comment': 'Báscula',
    },
    {
      'id': 'v2',
      'voucher_date': '2026-10-02',
      'voucher_type': 'expense',
      'rubric': 'Operativo',
      'total_amount': 500,
      'comment': 'Dinero de ventas entregado',
    },
    {
      'id': 'deposit',
      'voucher_date': '2026-10-02',
      'voucher_type': 'deposit',
      'rubric': 'Operativo',
      'total_amount': 999,
    },
  ],
  'men_cash_voucher_lines': [
    {'id': 'l1', 'voucher_id': 'v1', 'concept': 'Bascula', 'amount': 100},
    {'id': 'l2', 'voucher_id': 'v2', 'concept': 'Comisiones', 'amount': 500},
  ],
  'direction_vault_vouchers': [
    {
      'id': 'f',
      'voucher_date': '2026-10-03',
      'voucher_type': 'expense',
      'rubric': 'Gastos administrativos',
      'total_amount': 1000,
    },
  ],
};
StatementAnalysis analyze({
  Map<String, StatementDecision> decisions = const {},
}) => analyzeStatement(
  StatementBundle(period: october, tables: sources(), decisions: decisions),
);

void main() {
  test(
    'original categories expose missing and linked sources without changing result',
    () {
      final a = analyze();
      final coverage = statementExpenseCoverage(a);
      final services = coverage.singleWhere((r) => r.category == 'Servicios');
      expect(services.recorded, 348);
      expect(services.linked, 348);
      expect(
        services.linkedIncludedPending,
        116,
      ); // prior invoice is not this period's missing cost
      expect(services.recognizedHere, 0);
      final cash = coverage.singleWhere((r) => r.source == 'Menudeo');
      expect(cash.count, 2);
      expect(cash.recorded, 600);
      expect(cash.recognizedHere, 100);
      expect(
        cash.pending,
        500,
      ); // sale proceeds under Operativo are not an expense
      expect(
        coverage
            .singleWhere(
              (r) => r.source == 'Bancos' && r.category == 'Administrativos',
            )
            .recorded,
        300,
      );
      expect(coverage.singleWhere((r) => r.source == 'Bóveda').pending, 1000);
      expect(a.result, -216);
      expect(
        a.entries
            .singleWhere((e) => e.fact.id == 'invoice:current')
            .includedPending,
        isTrue,
      );
      expect(services.linkedPending, 0);
      expect(
        statementDatasetFromAnalysis(
          a,
        ).warnings.any((s) => s.startsWith('Gastos incompletos:')),
        isTrue,
      );
    },
  );
  test(
    'invoice net recognition resolves its pending payment without counting the bank again',
    () {
      final initial = analyze();
      final invoice = initial.entries.singleWhere(
        (e) => e.fact.id == 'invoice:current',
      );
      final a = analyze(
        decisions: {
          invoice.fact.id: StatementDecision(
            id: invoice.fact.id,
            signature: invoice.fact.signature,
            account: StatementAccount.operating,
            amount: 100,
            note: 'Base 100; IVA 16 confirmado en el comprobante',
          ),
        },
      );
      final services = statementExpenseCoverage(
        a,
      ).singleWhere((r) => r.category == 'Servicios');
      expect(services.linkedPending, 0);
      expect(services.recognizedHere, 0);
      expect(
        a.total(StatementAccount.operating),
        200,
      ); // voucher + invoice, no second bank expense
      expect(a.result, -200);
    },
  );
  test(
    'reclassification to payroll stays outside operating/admin recognition',
    () {
      final initial = analyze();
      final voucher = initial.entries.singleWhere(
        (e) => e.fact.id == 'vault:f',
      );
      final a = analyze(
        decisions: {
          voucher.fact.id: StatementDecision(
            id: voucher.fact.id,
            signature: voucher.fact.signature,
            account: StatementAccount.payroll,
            amount: 1000,
            note: 'Finiquito devengado y no incluido en prenómina',
          ),
        },
      );
      final row = statementExpenseCoverage(
        a,
      ).singleWhere((r) => r.source == 'Bóveda');
      expect(row.recorded, 1000);
      expect(row.recognizedHere, 0);
      expect(row.pending, 0);
      expect(a.total(StatementAccount.payroll), 1000);
    },
  );
  for (final width in [390.0, 1440.0]) {
    testWidgets('coverage is readable without overflow at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  StatementRecognizedExpensesPanel(
                    analysis: analyze(),
                    money: (n) => '\$${n.toStringAsFixed(2)}',
                  ),
                  StatementExpenseCoveragePanel(
                    rows: statementExpenseCoverage(analyze()),
                    money: (n) => '\$${n.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('REGISTRADO Y RECONOCIDO POR FUENTE'), findsOneWidget);
      expect(find.textContaining('documentos pendientes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
