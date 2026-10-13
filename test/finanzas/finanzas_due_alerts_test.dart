import 'package:dicsa_operacion/app/finanzas/finanzas_due_alerts_store.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_due_notification_dialog.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_fixed_payments_store.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_provider_accounts_store.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FinanzasSupplierInvoiceRecord invoice(
  String id,
  String date, {
  bool paid = false,
}) => FinanzasSupplierInvoiceRecord.fromRemoteRow({
  'id': id,
  'invoice_folio': id,
  'provider_name_snapshot': id,
  'invoice_date': date,
  'due_date': date,
  'total_amount': 100,
  'balance_amount': paid ? 0 : 100,
  'status': paid ? 'PAGADA' : 'PENDIENTE',
});

FinanzasFixedPaymentRecord fixed(String id, String date, {bool paid = false}) =>
    FinanzasFixedPaymentRecord.fromRemoteRow({
      'id': id,
      'company_name_snapshot': id,
      'payment_date': date,
      'amount': 200,
      'status': paid ? 'PAGADO' : 'PENDIENTE',
    });

FinanzasDueAlertsSummary summary({DateTime? now}) =>
    FinanzasDueAlertsStore.summarize(
      now: now ?? DateTime(2026, 10, 14),
      invoices: [
        for (var day = 12; day <= 19; day++)
          invoice('Factura-$day', '2026-10-$day'),
        for (var i = 0; i < 12; i++) invoice('Anterior-$i', '2026-09-01'),
        invoice('Pagada', '2026-10-14', paid: true),
        invoice('Futura', '2026-11-01'),
      ],
      fixedPayments: [
        fixed('Renta semanal', '2026-10-16'),
        fixed('Renta anterior', '2026-10-11'),
        fixed('Renta pagada', '2026-10-14', paid: true),
      ],
      agreements: [],
      installments: [],
      agreementInvoiceLinks: [],
    );

void main() {
  test('complete calendar week and all past debt have separate totals', () {
    final result = summary();
    expect(result.weekStart, DateTime(2026, 10, 12));
    expect(result.weekEnd, DateTime(2026, 10, 19));
    expect(result.weekItems, hasLength(8));
    expect(
      result.weekItems.fold<double>(0, (sum, row) => sum + row.amount),
      900,
    );
    expect(result.pastDueItems, hasLength(13));
    expect(result.notificationCount, 21);
    expect(result.totalCount, 22); // Next Monday remains available to reports.
    expect(
      result.items.any(
        (row) =>
            row.title == 'Pagada' ||
            row.title == 'Renta pagada' ||
            row.title == 'Futura',
      ),
      isFalse,
    );
    expect(result.weekItems.any((row) => row.title == 'Factura-12'), isTrue);
    expect(result.weekItems.any((row) => row.title == 'Factura-18'), isTrue);
    expect(
      result.pastDueItems.any((row) => row.title == 'Factura-12'),
      isFalse,
    );
  });

  test(
    'Sunday stays in its week and Monday moves unpaid invoices to history',
    () {
      final sunday = summary(now: DateTime(2026, 10, 18));
      final monday = summary(now: DateTime(2026, 10, 19));
      expect(sunday.weekItems, hasLength(8));
      expect(monday.weekItems.map((row) => row.title), ['Factura-19']);
      expect(monday.pastDueItems, hasLength(21));
      final newYear = summary(now: DateTime(2027, 1, 1));
      expect(newYear.weekStart, DateTime(2026, 12, 28));
      expect(newYear.weekEnd, DateTime(2027, 1, 4));
    },
  );

  test(
    'active installments replace linked invoices and retain old unpaid debt',
    () {
      final result = FinanzasDueAlertsStore.summarize(
        now: DateTime(2026, 10, 14),
        invoices: [invoice('covered', '2026-10-14')],
        fixedPayments: [],
        agreements: [
          FinanzasSupplierAgreementRecord.fromRemoteRow({
            'id': 'agreement',
            'remaining_amount': 50,
            'status': 'ACTIVO',
          }),
        ],
        installments: [
          FinanzasSupplierAgreementInstallmentRecord.fromRemoteRow({
            'id': 'installment',
            'agreement_id': 'agreement',
            'due_date': '2026-09-01',
            'amount': 100,
            'paid_amount': 50,
            'status': 'PARCIAL',
          }),
        ],
        agreementInvoiceLinks: [
          FinanzasSupplierAgreementInvoiceRecord.fromRemoteRow({
            'id': 'link',
            'agreement_id': 'agreement',
            'installment_id': 'installment',
            'invoice_id': 'covered',
          }),
        ],
      );
      expect(result.weekItems, isEmpty);
      expect(result.pastDueItems.single.sourceType, 'CONVENIO');
      expect(result.pastDueItems.single.amount, 50);
    },
  );

  test(
    'automatic presentation is shared across dashboards and resets at logout',
    () {
      FinanzasDueAlertsSessionGate.reset();
      expect(
        FinanzasDueAlertsSessionGate.registerPresentation(
          FinanzasDueAlertsSessionScope.directionDashboard,
        ),
        isTrue,
      );
      expect(
        FinanzasDueAlertsSessionGate.registerPresentation(
          FinanzasDueAlertsSessionScope.finanzasDashboard,
        ),
        isFalse,
      );
      expect(
        FinanzasDueAlertsSessionGate.registerPresentation(
          FinanzasDueAlertsSessionScope.directionDashboard,
        ),
        isFalse,
      );
      FinanzasDueAlertsSessionGate.reset();
      expect(
        FinanzasDueAlertsSessionGate.registerPresentation(
          FinanzasDueAlertsSessionScope.finanzasDashboard,
        ),
        isTrue,
      );
      FinanzasDueAlertsSessionGate.reset();
    },
  );

  testWidgets(
    'popup defaults to week, separates history and keeps source colors',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinanzasDueNotificationDialog(
              summary: summary(),
              tokens: finanzasAreaTokens,
              actionLabel: 'Abrir pagos',
              onOpenPayments: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Esta semana (8)'), findsOneWidget);
      expect(find.text('Factura-12'), findsOneWidget);
      expect(find.text('Anterior-0'), findsNothing);
      final invoiceCard = tester.widget<Container>(
        find.byKey(const ValueKey('invoice-Factura-12-overdue')),
      );
      final fixedCard = tester.widget<Container>(
        find.byKey(const ValueKey('fixed-Renta semanal-two_days')),
      );
      expect(
        (invoiceCard.decoration as BoxDecoration).color,
        isNot((fixedCard.decoration as BoxDecoration).color),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('due-notification-total')))
            .data,
        contains('900'),
      );
      await tester.tap(find.text('Deuda anterior (13)'));
      await tester.pumpAndSettle();
      expect(find.text('Anterior-11'), findsOneWidget);
      expect(find.text('Factura-12'), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('due-notification-total')))
            .data,
        contains('1,400'),
      );
      await tester.tap(find.text('Esta semana (8)'));
      await tester.pumpAndSettle();
      expect(find.text('Factura-12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
