import 'package:dicsa_operacion/app/finanzas/finanzas_payment_center_budget_engine.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_payment_center_budget_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('finanzas payment center budget engine', () {
    test('protects tomorrow commitments before spending all cash today', () {
      final today = DateTime(2026, 8, 13);
      final items = <FinanzasPaymentCenterOperationalItem>[
        _item(
          providerId: 'prov-hoy',
          providerName: 'Proveedor Hoy',
          itemType: 'Factura',
          dueDate: today,
          amountSuggested: 500,
          priorityScore: 320,
          allowPartialPayment: false,
          executionAmount: 500,
          executionDecision:
              FinanzasPaymentCenterExecutionDecision.pagarCompleto,
        ),
        _item(
          providerId: 'prov-manana',
          providerName: 'Proveedor Manana',
          itemType: 'Pago fijo',
          dueDate: today.add(const Duration(days: 1)),
          amountSuggested: 400,
          priorityScore: 420,
          allowPartialPayment: false,
          executionAmount: 0,
        ),
      ];

      applyFinanzasPaymentCenterNearTermLiquidityGuard(
        items: items,
        balances: <String, double>{'DICSA_CELAYA': 500},
        today: today,
      );

      expect(items.first.executionAmount, 0);
      expect(
        items.first.executionDecision,
        FinanzasPaymentCenterExecutionDecision.esperar,
      );
      expect(items.first.executionSummary, contains('siguiente dia'));
    });

    test('trims partial today movement to the real margin after tomorrow', () {
      final today = DateTime(2026, 8, 13);
      final items = <FinanzasPaymentCenterOperationalItem>[
        _item(
          providerId: 'prov-abono',
          providerName: 'Proveedor Abono',
          itemType: 'Saldo general',
          dueDate: null,
          amountSuggested: 300,
          priorityScore: 280,
          allowPartialPayment: true,
          executionAmount: 300,
          executionDecision: FinanzasPaymentCenterExecutionDecision.abonar,
        ),
        _item(
          providerId: 'prov-manana',
          providerName: 'Proveedor Manana',
          itemType: 'Factura',
          dueDate: today.add(const Duration(days: 1)),
          amountSuggested: 400,
          priorityScore: 360,
          allowPartialPayment: false,
          executionAmount: 0,
        ),
      ];

      applyFinanzasPaymentCenterNearTermLiquidityGuard(
        items: items,
        balances: <String, double>{'DICSA_CELAYA': 500},
        today: today,
      );

      expect(items.first.executionAmount, closeTo(100, 0.001));
      expect(
        items.first.executionDecision,
        FinanzasPaymentCenterExecutionDecision.abonar,
      );
      expect(items.first.executionSummary, contains('margen real de hoy'));
    });
  });
}

FinanzasPaymentCenterOperationalItem _item({
  required String providerId,
  required String providerName,
  required String itemType,
  required DateTime? dueDate,
  required double amountSuggested,
  required int priorityScore,
  required bool allowPartialPayment,
  required double executionAmount,
  FinanzasPaymentCenterExecutionDecision executionDecision =
      FinanzasPaymentCenterExecutionDecision.esperar,
}) {
  return FinanzasPaymentCenterOperationalItem(
    providerId: providerId,
    providerName: providerName,
    bucket: FinanzasPaymentCenterPriorityBucket.urgente,
    itemType: itemType,
    sourceLabel: itemType,
    dueDate: dueDate,
    agreementLabel: 'Sin convenio',
    amountSuggested: amountSuggested,
    amountTotal: amountSuggested,
    targetCompany: 'DICSA',
    targetBranch: 'CELAYA',
    urgencyLabel: 'Urgente',
    recommendation: '',
    decisionReasons: const <String>[],
    priorityScore: priorityScore,
    allowPartialPayment: allowPartialPayment,
    canPayNow: executionAmount > 0.009,
    executionDecision: executionDecision,
    executionAmount: executionAmount,
    executionSummary: '',
  );
}
