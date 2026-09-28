import 'dart:io';

import 'package:dicsa_operacion/app/direction/projection/weekly_projection_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_payment_catalog.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_view.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_provider_accounts_store.dart';
import 'package:dicsa_operacion/app/management_reports/finance_weekly_budget_analysis.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../management_reports/finance_weekly_budget_fixtures.dart' as b;
import 'expected_income_test.dart' as f;
import 'expected_income_view_test.dart' as income;
import 'weekly_projection_view_test.dart' as fixtures;

FinanceWeeklyBudgetSource agreementSource({
  String agreementStatus = 'ATRASADO',
  String due = '2026-09-07',
  String invoiceStatus = 'CONVENIO',
}) => b.budgetSource(
  invoices: [
    b
        .invoice(
          'decasa',
          700,
          '2026-09-01',
          provider: 'DECASA',
          balance: 450,
          status: invoiceStatus,
        )
        .copyWith(folio: 'AB 00004251'),
    b
        .invoice(
          'other-invoice',
          550,
          '2026-09-01',
          provider: 'DECASA',
          status: invoiceStatus,
        )
        .copyWith(folio: 'AB 00004252'),
    b.invoice('unrelated', 300, '2026-09-01', provider: 'DECASA'),
  ],
  agreements: [
    FinanzasSupplierAgreementRecord.fromRemoteRow({
      'id': 'decasa-agreement',
      'provider_name_snapshot': 'DECASA',
      'agreement_type': 'POR_FACTURAS',
      'status': agreementStatus,
      'remaining_amount': 1000,
      'total_amount': 1250,
    }),
  ],
  installments: [
    FinanzasSupplierAgreementInstallmentRecord.fromRemoteRow({
      'id': 'overdue',
      'agreement_id': 'decasa-agreement',
      'sequence_number': 1,
      'due_date': due,
      'amount': 1250,
      'paid_amount': 250,
      'status': 'ATRASADO',
    }),
  ],
  links: [
    for (final id in ['decasa', 'other-invoice'])
      FinanzasSupplierAgreementInvoiceRecord.fromRemoteRow({
        'id': 'link-$id',
        'agreement_id': 'decasa-agreement',
        'installment_id': 'overdue',
        'invoice_id': id,
      }),
  ],
);

FinanceWeeklyBudgetAnalysis analyze(FinanceWeeklyBudgetSource source) =>
    FinanceWeeklyBudgetAnalysis(source, f.incomeWeek, targetWeek: f.incomeWeek);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Roboto', 'Ahem']) {
      await (FontLoader(family)..addFont(
            Future.value(
              ByteData.sublistView(
                await File('assets/fonts/Roboto-Regular.ttf').readAsBytes(),
              ),
            ),
          ))
          .load();
    }
  });
  Future<void> size(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1050));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget harness(fixtures.MemoryProjectionRepository repo) => income.app(
    WeeklyProjectionView(
      bundle: f.incomeBundle(),
      repository: repo,
      incomeRepository: income.MemoryIncomeRepository(),
      active: true,
      flow: false,
      clock: () => f.incomeWeek,
      onWeekChanged: (_) async {},
    ),
  );
  Finder pickerSearch() => find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextField),
  );
  Future<void> findInvoice(WidgetTester tester, String query) async {
    await tester.ensureVisible(
      find.byKey(const ValueKey('add-projected-expense')),
    );
    await tester.tap(find.byKey(const ValueKey('add-projected-expense')));
    await tester.pumpAndSettle();
    await tester.enterText(pickerSearch(), query);
    await tester.pumpAndSettle();
  }

  test(
    'overdue agreement invoices resolve to their exact unpaid installment in a later week',
    () {
      final analysis = analyze(agreementSource());
      final catalog = ProjectionPaymentCatalog(analysis);
      final target = catalog.commitmentsFor('invoice:decasa').single;
      expect(target.id, 'agreement:overdue');
      expect(target.available, 100000);
      expect(target.date, f.incomeWeek);
      expect(target.warning, contains('Vencimiento original: 2026-09-07'));
      expect(target.warning, contains('Cuota atrasada'));
      expect(target.reference, contains('AB 00004251, AB 00004252'));
      expect(catalog.byId['invoice:decasa']!.available, 0);
      expect(
        catalog.commitmentsFor('invoice:other-invoice').single.id,
        target.id,
      );
      expect(catalog.commitmentsFor('invoice:unrelated'), isEmpty);
      expect(catalog.byId['invoice:unrelated']!.available, 30000);
      expect(analysis.proposedRows.map((r) => r.invoice.id), ['unrelated']);
    },
  );

  test(
    'future, closed and orphan agreement links explain the restriction without guessing a payment',
    () {
      final future = ProjectionPaymentCatalog(
        analyze(agreementSource(due: '2026-10-05')),
      );
      expect(future.commitmentsFor('invoice:decasa'), isEmpty);
      expect(future.byId['invoice:decasa']!.warning, contains('2026-10-05'));
      for (final status in ['CUMPLIDO', 'CANCELADO']) {
        final closed = ProjectionPaymentCatalog(
          analyze(agreementSource(agreementStatus: status)),
        );
        expect(closed.commitmentsFor('invoice:decasa'), isEmpty);
        expect(
          closed.byId['invoice:decasa']!.warning,
          contains('Revisa el calendario y el vínculo'),
        );
        final released = ProjectionPaymentCatalog(
          analyze(
            agreementSource(
              agreementStatus: status,
              invoiceStatus: 'PENDIENTE',
            ),
          ),
        );
        expect(released.byId['invoice:decasa']!.available, 45000);
      }
    },
  );

  test(
    'paid, cancelled and covered invoices remain searchable and never regain a payable balance',
    () {
      final catalog = ProjectionPaymentCatalog(
        analyze(
          b.budgetSource(
            invoices: [
              b.invoice('paid', 100, '2026-09-01', status: 'PAGADA'),
              b.invoice('cancelled', 100, '2026-09-01', status: 'CANCELADA'),
              b.invoice('zero', 100, '2026-09-01', balance: 0),
              b.invoice('settled', 100, '2026-09-01'),
            ],
            movements: [
              b.bank('payment', '2026-09-01', 0, 100, invoice: 'settled'),
            ],
          ),
        ),
      );
      expect(catalog.byId.length, 4);
      expect(
        catalog.byId.values.every((r) => r.available == 0 && r.total == 0),
        true,
      );
      expect(catalog.byId['invoice:paid']!.warning, contains('pagada'));
      expect(catalog.byId['invoice:cancelled']!.warning, contains('cancelada'));
      expect(catalog.byId['invoice:zero']!.warning, contains('sin saldo'));
      expect(catalog.byId['invoice:settled']!.warning, contains('abonos'));
      final saved = catalog.byId['invoice:paid']!.copyWith(
        amount: 10000,
        included: true,
      );
      final reconciled = reconcilePayments([
        saved,
      ], catalog.byId.values.toList()).single;
      expect(reconciled.total, 0);
      expect(reconciled.warning, contains('pagada'));
    },
  );

  testWidgets(
    'searching 4251 opens its overdue agreement and includes one partial payment in the current week',
    (tester) async {
      await size(tester);
      final repo = fixtures.MemoryProjectionRepository()
        ..sourceOverride = agreementSource();
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await findInvoice(tester, '4251');
      await tester.tap(find.textContaining('Factura AB 00004251 · DECASA'));
      await tester.pumpAndSettle();
      expect(find.text('1000.0'), findsOneWidget);
      expect(
        find.textContaining('Vencimiento original: 2026-09-07'),
        findsOneWidget,
      );
      expect(
        find.textContaining('el importe corresponde a toda la cuota'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const ValueKey('amount')), '600');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final saved = repo.saved[f.incomeWeek]!.payments.single;
      expect(saved.id, 'agreement:overdue');
      expect(saved.total, 60000);
      expect(saved.date, f.incomeWeek);
      expect(saved.reference, contains('4251'));
      expect(saved.paymentType, 'FISCAL');
      // Searching the other invoice in the same quota edits the same payment.
      await findInvoice(tester, '4252');
      await tester.tap(find.textContaining('Factura AB 00004252 · DECASA'));
      await tester.pumpAndSettle();
      expect(find.text('600.0'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('amount')), '700');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(repo.saved[f.incomeWeek]!.payments.length, 1);
      expect(repo.saved[f.incomeWeek]!.total, 70000);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'excluded invoice opens its removed overdue quota and can explicitly restore it once',
    (tester) async {
      await size(tester);
      final source = agreementSource();
      final repo = fixtures.MemoryProjectionRepository()
        ..sourceOverride = source;
      repo.saved[f.incomeWeek] = WeeklyExpensePlan(
        week: f.incomeWeek,
        generated: true,
        payments: [
          for (final p in paymentProposal(analyze(source)))
            if (p.source == 'agreement')
              p.copyWith(removed: true, included: false)
            else
              p,
        ],
      );
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mostrar solo pagos incluidos'));
      await tester.tap(find.text('Mostrar solo pagos incluidos'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('payment-search')),
        '4251',
      );
      await tester.pumpAndSettle();
      final action = find.byKey(
        const ValueKey('agreement-payment-invoice:decasa'),
      );
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repo.writes, 0);
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('amount')), '1000');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final saved = repo.saved[f.incomeWeek]!;
      expect(
        saved.payments.where((r) => r.id == 'agreement:overdue').length,
        1,
      );
      expect(
        saved.payments.singleWhere((r) => r.id == 'agreement:overdue').total,
        100000,
      );
      expect(
        saved.payments.singleWhere((r) => r.id == 'invoice:decasa').total,
        0,
      );
      expect(find.text('Editar pago del convenio'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'zero proposal checkbox opens the editor with its balance and only saves on confirmation',
    (tester) async {
      await size(tester);
      final repo = fixtures.MemoryProjectionRepository()
        ..invoices = [b.invoice('later', 850, '2026-10-01')];
      repo.saved[f.incomeWeek] = WeeklyExpensePlan(
        week: f.incomeWeek,
        payments: paymentProposal(
          await repo.proposal(f.incomeWeek, f.incomeWeek),
        ),
      );
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mostrar solo pagos incluidos'));
      await tester.tap(find.text('Mostrar solo pagos incluidos'));
      await tester.pumpAndSettle();
      final checkbox = find.byKey(
        const ValueKey('include-payment-invoice:later'),
      );
      await tester.ensureVisible(checkbox);
      expect(tester.widget<Checkbox>(checkbox).onChanged, isNotNull);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(find.text('850.0'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repo.writes, 0);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        repo.saved[f.incomeWeek]!.payments
            .singleWhere((r) => r.id == 'invoice:later')
            .total,
        85000,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'unavailable invoice appears in search with an explanation instead of a payment editor',
    (tester) async {
      await size(tester);
      final repo = fixtures.MemoryProjectionRepository()
        ..invoices = [
          b.invoice('paid-4251', 850, '2026-09-01', status: 'PAGADA'),
        ];
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await findInvoice(tester, '4251');
      expect(find.textContaining('No disponible'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Disponibilidad del egreso'), findsOneWidget);
      expect(find.textContaining('Factura pagada en Finanzas'), findsOneWidget);
      expect(find.byKey(const ValueKey('amount')), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repo.writes, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
