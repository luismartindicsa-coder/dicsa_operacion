import 'package:dicsa_operacion/app/compras/compras_tickets_store.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_financial_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('finanzas financial rules', () {
    test('derives overdue fixed payments without touching paid rows', () {
      final today = DateTime(2026, 5, 28);

      expect(
        deriveFixedPaymentOperationalStatus(
          persistedStatus: 'PENDIENTE',
          paymentDate: DateTime(2026, 5, 20),
          today: today,
        ),
        'VENCIDO',
      );
      expect(
        deriveFixedPaymentOperationalStatus(
          persistedStatus: 'PENDIENTE',
          paymentDate: DateTime(2026, 5, 30),
          today: today,
        ),
        'PENDIENTE',
      );
      expect(
        deriveFixedPaymentOperationalStatus(
          persistedStatus: 'PAGADO',
          paymentDate: DateTime(2026, 5, 10),
          today: today,
        ),
        'PAGADO',
      );
    });

    test(
      'saldo general excludes facturado tickets and discounts direct abonos',
      () {
        final tickets = <ComprasTicketRecord>[
          _ticket(
            id: 't1',
            providerId: 'p1',
            amount: 1000,
            facturaStatus: 'SIN_FACTURA',
          ),
          _ticket(
            id: 't2',
            providerId: 'p1',
            amount: 500,
            facturaStatus: 'SIN_FACTURA',
          ),
          _ticket(
            id: 't3',
            providerId: 'p1',
            amount: 700,
            facturaStatus: 'FACTURADO',
          ),
          _ticket(
            id: 't4',
            providerId: 'p2',
            amount: 800,
            facturaStatus: 'PENDIENTE_DE_FACTURAR',
          ),
        ];
        final applications = <ComprasTicketPaymentApplicationRecord>[
          _application(ticketId: 't2', appliedAmount: 200),
          _application(
            ticketId: 't3',
            appliedAmount: 999,
          ), // ignored for saldo general
          _application(ticketId: 't4', appliedAmount: 800), // fully covered
        ];

        final result = computeOpenGeneralAmountsByProvider(
          tickets: tickets,
          applications: applications,
        );

        expect(result['p1'], closeTo(1300, 0.001));
        expect(result.containsKey('p2'), isFalse);
      },
    );

    test(
      'full settlement validation rejects partial invoice or fixed payment',
      () {
        expect(
          () => assertFullSettlementAmount(
            appliedAmount: 2500,
            expectedAmount: 3000,
            contextLabel: 'La factura proveedor',
          ),
          throwsA(isA<StateError>()),
        );

        expect(
          () => assertFullSettlementAmount(
            appliedAmount: 3000,
            expectedAmount: 3000,
            contextLabel: 'La factura proveedor',
          ),
          returnsNormally,
        );
      },
    );

    test(
      'supplier settlement allows exact and cent differences with reason',
      () {
        expect(
          () => assertSupplierSettlementAmountAllowed(
            debitAmount: 9383.00,
            expectedSupplierAmount: 9383.01,
            appliedSupplierAmount: 9383.01,
            differenceReason: 'REDONDEO_OPERATIVO',
          ),
          returnsNormally,
        );

        expect(
          () => assertSupplierSettlementAmountAllowed(
            debitAmount: 13850.01,
            expectedSupplierAmount: 13850.00,
            appliedSupplierAmount: 13850.00,
            differenceReason: 'AJUSTE_CENTAVOS_AUTORIZADO',
          ),
          returnsNormally,
        );
      },
    );

    test('supplier settlement requires reason when there is delta', () {
      expect(
        () => assertSupplierSettlementAmountAllowed(
          debitAmount: 9383.00,
          expectedSupplierAmount: 9383.01,
          appliedSupplierAmount: 9383.01,
          differenceReason: null,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('supplier settlement blocks differences over phase one tolerance', () {
      expect(
        () => assertSupplierSettlementAmountAllowed(
          debitAmount: 49995.00,
          expectedSupplierAmount: 50000.00,
          appliedSupplierAmount: 50000.00,
          differenceReason: 'AJUSTE_CENTAVOS_AUTORIZADO',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'recomputes agreement summary and installment status realistically',
      () {
        final today = DateTime(2026, 5, 28);
        final installment1 = AgreementInstallmentSnapshot(
          sequenceNumber: 1,
          dueDate: DateTime(2026, 5, 20),
          amount: 10000,
          paidAmount: 10000,
          status: deriveAgreementInstallmentStatus(
            dueDate: DateTime(2026, 5, 20),
            amount: 10000,
            paidAmount: 10000,
            today: today,
          ),
        );
        final installment2 = AgreementInstallmentSnapshot(
          sequenceNumber: 2,
          dueDate: DateTime(2026, 5, 27),
          amount: 15000,
          paidAmount: 5000,
          status: deriveAgreementInstallmentStatus(
            dueDate: DateTime(2026, 5, 27),
            amount: 15000,
            paidAmount: 5000,
            today: today,
          ),
        );
        final installment3 = AgreementInstallmentSnapshot(
          sequenceNumber: 3,
          dueDate: DateTime(2026, 6, 3),
          amount: 8000,
          paidAmount: 0,
          status: deriveAgreementInstallmentStatus(
            dueDate: DateTime(2026, 6, 3),
            amount: 8000,
            paidAmount: 0,
            today: today,
          ),
        );

        expect(installment1.status, 'PAGADO');
        expect(installment2.status, 'VENCIDO');
        expect(installment3.status, 'PENDIENTE');

        final summary = recomputeAgreementSummary(
          currentStatus: 'ACTIVO',
          installments: <AgreementInstallmentSnapshot>[
            installment1,
            installment2,
            installment3,
          ],
          today: today,
        );

        expect(summary.remainingAmount, closeTo(18000, 0.001));
        expect(summary.nextDueDate, DateTime(2026, 5, 27));
        expect(summary.status, 'ATRASADO');
      },
    );

    test(
      'distributes paid invoice amount across linked tickets by antiguedad',
      () {
        final coverage = computeInvoiceTicketCoverage(
          invoiceTotalAmount: 30000,
          invoiceBalanceAmount: 12000,
          tickets: <InvoiceTicketSnapshot>[
            InvoiceTicketSnapshot(
              ticketId: 'a',
              ticketAmount: 10000,
              ticketDate: DateTime(2026, 5, 1),
              ticketNumber: '0001',
            ),
            InvoiceTicketSnapshot(
              ticketId: 'b',
              ticketAmount: 12000,
              ticketDate: DateTime(2026, 5, 2),
              ticketNumber: '0002',
            ),
            InvoiceTicketSnapshot(
              ticketId: 'c',
              ticketAmount: 8000,
              ticketDate: DateTime(2026, 5, 3),
              ticketNumber: '0003',
            ),
          ],
          directAppliedByTicketId: const <String, double>{},
        );

        expect(coverage['a']!.appliedAmount, closeTo(10000, 0.001));
        expect(coverage['a']!.pagoStatus, 'PAGADO');
        expect(coverage['b']!.appliedAmount, closeTo(8000, 0.001));
        expect(coverage['b']!.pagoStatus, 'ABONO');
        expect(coverage['b']!.coverageStatus, 'PARCIAL');
        expect(coverage['c']!.appliedAmount, closeTo(0, 0.001));
        expect(coverage['c']!.pagoStatus, 'PENDIENTE_DE_PAGO');
      },
    );

    test(
      'invoice coverage respects direct cash abonos before bank settlement',
      () {
        final coverage = computeInvoiceTicketCoverage(
          invoiceTotalAmount: 10000,
          invoiceBalanceAmount: 3500,
          tickets: <InvoiceTicketSnapshot>[
            InvoiceTicketSnapshot(
              ticketId: 'old',
              ticketAmount: 4000,
              ticketDate: DateTime(2026, 4, 10),
              ticketNumber: '0100',
            ),
            InvoiceTicketSnapshot(
              ticketId: 'new',
              ticketAmount: 6000,
              ticketDate: DateTime(2026, 4, 11),
              ticketNumber: '0101',
            ),
          ],
          directAppliedByTicketId: const <String, double>{'old': 1500},
        );

        expect(coverage['old']!.appliedAmount, closeTo(4000, 0.001));
        expect(coverage['old']!.pagoStatus, 'PAGADO');
        expect(coverage['new']!.appliedAmount, closeTo(4000, 0.001));
        expect(coverage['new']!.pagoStatus, 'ABONO');
      },
    );

    test('handles realistic batch data without duplicating facturado debt', () {
      final tickets = <ComprasTicketRecord>[];
      final applications = <ComprasTicketPaymentApplicationRecord>[];
      final expectedByProvider = <String, double>{};
      final providerIds = <String>['p1', 'p2', 'p3'];

      var sequence = 0;
      for (final providerId in providerIds) {
        for (var i = 0; i < 40; i++) {
          sequence += 1;
          final amount = 1000 + (i * 37);
          final facturaStatus = i % 3 == 0
              ? 'FACTURADO'
              : i % 3 == 1
              ? 'SIN_FACTURA'
              : 'PENDIENTE_DE_FACTURAR';
          final ticketId = 'ticket_$sequence';
          tickets.add(
            _ticket(
              id: ticketId,
              providerId: providerId,
              amount: amount.toDouble(),
              facturaStatus: facturaStatus,
            ),
          );

          double expectedRemaining = 0;
          if (facturaStatus != 'FACTURADO') {
            if (i % 5 == 0) {
              applications.add(
                _application(
                  ticketId: ticketId,
                  appliedAmount: amount.toDouble(),
                ),
              );
              expectedRemaining = 0;
            } else if (i % 2 == 0) {
              final partial = amount * 0.4;
              applications.add(
                _application(ticketId: ticketId, appliedAmount: partial),
              );
              expectedRemaining = amount - partial;
            } else {
              expectedRemaining = amount.toDouble();
            }
          }

          if (expectedRemaining > 0.009) {
            expectedByProvider.update(
              providerId,
              (value) => value + expectedRemaining,
              ifAbsent: () => expectedRemaining,
            );
          }
        }
      }

      final result = computeOpenGeneralAmountsByProvider(
        tickets: tickets,
        applications: applications,
      );

      expect(result.length, expectedByProvider.length);
      for (final entry in expectedByProvider.entries) {
        expect(
          result[entry.key],
          closeTo(entry.value, 0.001),
          reason: 'provider ${entry.key}',
        );
      }
    });

    test(
      'optimization keeps accounts independent and covers critical first',
      () {
        final decisions = optimizePaymentExecution(
          items: <PaymentOptimizationSnapshot>[
            PaymentOptimizationSnapshot(
              id: 'dc_obl',
              accountKey: 'DICSA_CELAYA',
              bucketKey: 'OBLIGATORIO',
              itemType: 'Pago fijo',
              amountSuggested: 3000,
              allowPartialPayment: false,
              priorityScore: 500,
              dueDate: DateTime(2026, 5, 28),
            ),
            PaymentOptimizationSnapshot(
              id: 'dc_rec',
              accountKey: 'DICSA_CELAYA',
              bucketKey: 'RECOMENDADO',
              itemType: 'Factura',
              amountSuggested: 2000,
              allowPartialPayment: false,
              priorityScore: 120,
              dueDate: DateTime(2026, 6, 2),
            ),
            PaymentOptimizationSnapshot(
              id: 'vh_urg',
              accountKey: 'VH_MAZATLAN',
              bucketKey: 'URGENTE',
              itemType: 'Factura',
              amountSuggested: 1500,
              allowPartialPayment: false,
              priorityScore: 300,
              dueDate: DateTime(2026, 5, 29),
            ),
            PaymentOptimizationSnapshot(
              id: 'vh_rec',
              accountKey: 'VH_MAZATLAN',
              bucketKey: 'RECOMENDADO',
              itemType: 'Saldo general',
              amountSuggested: 1000,
              allowPartialPayment: true,
              priorityScore: 100,
              dueDate: DateTime(2026, 6, 3),
            ),
          ],
          balances: <String, double>{'DICSA_CELAYA': 5000, 'VH_MAZATLAN': 1500},
        );

        expect(decisions['dc_obl']!.decisionKey, 'PAGAR_COMPLETO');
        expect(decisions['dc_rec']!.decisionKey, 'PAGAR_COMPLETO');
        expect(decisions['vh_urg']!.decisionKey, 'PAGAR_COMPLETO');
        expect(decisions['vh_rec']!.decisionKey, 'ESPERAR');
      },
    );

    test('optimization uses excedente util only after critical is covered', () {
      final decisions = optimizePaymentExecution(
        items: <PaymentOptimizationSnapshot>[
          PaymentOptimizationSnapshot(
            id: 'urgent_big',
            accountKey: 'DICSA_CELAYA',
            bucketKey: 'URGENTE',
            itemType: 'Factura',
            amountSuggested: 7000,
            allowPartialPayment: false,
            priorityScore: 400,
            dueDate: DateTime(2026, 5, 29),
          ),
          PaymentOptimizationSnapshot(
            id: 'recommended_small',
            accountKey: 'DICSA_CELAYA',
            bucketKey: 'RECOMENDADO',
            itemType: 'Factura',
            amountSuggested: 2000,
            allowPartialPayment: false,
            priorityScore: 120,
            dueDate: DateTime(2026, 6, 4),
          ),
          PaymentOptimizationSnapshot(
            id: 'general_partial',
            accountKey: 'DICSA_CELAYA',
            bucketKey: 'URGENTE',
            itemType: 'Saldo general',
            amountSuggested: 10000,
            allowPartialPayment: true,
            priorityScore: 350,
            dueDate: DateTime(2026, 5, 30),
          ),
        ],
        balances: <String, double>{'DICSA_CELAYA': 5000},
      );

      expect(decisions['urgent_big']!.decisionKey, 'ESPERAR');
      expect(decisions['recommended_small']!.decisionKey, 'PAGAR_COMPLETO');
      expect(decisions['general_partial']!.decisionKey, 'ABONAR');
      expect(
        decisions['general_partial']!.executionAmount,
        closeTo(3000, 0.001),
      );
    });

    test('optimization advances non critical debt when sobra flujo hoy', () {
      final decisions = optimizePaymentExecution(
        items: <PaymentOptimizationSnapshot>[
          PaymentOptimizationSnapshot(
            id: 'critical_fixed',
            accountKey: 'VH_CELAYA',
            bucketKey: 'OBLIGATORIO',
            itemType: 'Pago fijo',
            amountSuggested: 2500,
            allowPartialPayment: false,
            priorityScore: 450,
            dueDate: DateTime(2026, 5, 28),
          ),
          PaymentOptimizationSnapshot(
            id: 'future_invoice',
            accountKey: 'VH_CELAYA',
            bucketKey: 'RECOMENDADO',
            itemType: 'Factura',
            amountSuggested: 2000,
            allowPartialPayment: false,
            priorityScore: 110,
            dueDate: DateTime(2026, 6, 6),
          ),
          PaymentOptimizationSnapshot(
            id: 'future_general',
            accountKey: 'VH_CELAYA',
            bucketKey: 'POSTERGABLE',
            itemType: 'Saldo general',
            amountSuggested: 5000,
            allowPartialPayment: true,
            priorityScore: 80,
            dueDate: DateTime(2026, 6, 10),
          ),
        ],
        balances: <String, double>{'VH_CELAYA': 6000},
      );

      expect(decisions['critical_fixed']!.decisionKey, 'PAGAR_COMPLETO');
      expect(decisions['future_invoice']!.decisionKey, 'PAGAR_COMPLETO');
      expect(decisions['future_general']!.decisionKey, 'ABONAR');
      expect(
        decisions['future_general']!.executionAmount,
        closeTo(1500, 0.001),
      );
    });
  });
}

ComprasTicketRecord _ticket({
  required String id,
  required String providerId,
  required double amount,
  required String facturaStatus,
}) {
  return ComprasTicketRecord(
    id: id,
    date: DateTime(2026, 5, 1),
    ticket: id,
    providerId: providerId,
    providerNameSnapshot: providerId.toUpperCase(),
    materialId: 'mat',
    materialNameSnapshot: 'CARTON',
    grossWeight: 0,
    tareWeight: 0,
    netWeight: 0,
    humidityPercent: 0,
    trashPercent: 0,
    trashKg: 0,
    trashCaptureMode: 'PERCENT',
    payableWeight: 0,
    price: 0,
    premium: 0,
    amount: amount,
    facturaStatus: facturaStatus,
    pagoStatus: 'PENDIENTE_DE_PAGO',
    coverageStatus: 'SIN_CUBRIR',
    createdAt: null,
    updatedAt: null,
  );
}

ComprasTicketPaymentApplicationRecord _application({
  required String ticketId,
  required double appliedAmount,
}) {
  return ComprasTicketPaymentApplicationRecord(
    id: '${ticketId}_app',
    providerMovementId: 'm_$ticketId',
    ticketId: ticketId,
    appliedAmount: appliedAmount,
    appliedAt: DateTime(2026, 5, 2),
  );
}
