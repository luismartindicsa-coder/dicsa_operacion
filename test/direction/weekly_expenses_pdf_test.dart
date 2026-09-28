import 'dart:io';
import 'dart:convert';

import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_expenses_pdf.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expected_income_pdf_test.dart' as pdf;
import 'weekly_projection_test.dart' as f;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'removed Finance payment survives storage and refresh, contributes nothing',
    () {
      final legacy = f.payment('legacy', 90000).toJson()..remove('removed');
      expect(ProjectedPayment.fromJson(legacy).removed, false);
      final json = f.payment('invoice:removed', 90000).toJson()
        ..['source'] = 'invoice'
        ..['removed'] = true;
      final removed = ProjectedPayment.fromJson(json);
      final current = ProjectedPayment.fromJson({...json, 'removed': false});
      expect(ProjectedPayment.fromJson(removed.toJson()).removed, true);
      for (final pending in [
        [current],
        <ProjectedPayment>[],
      ]) {
        final reconciled = reconcilePayments([removed], pending).single;
        expect(reconciled.removed, true);
        expect(reconciled.total, 0);
        final plan = WeeklyExpensePlan(
          week: f.week,
          payments: [
            reconciled,
            f.payment('cash', 12345),
            f.payment('excluded', 60000, included: false),
          ],
        );
        expect(plan.activePayments.length, 2);
        expect(plan.scheduledPayments.single.id, 'cash');
        expect(plan.total, 12345);
        final flow = WeeklyCashFlow(
          IncomeTotals()..add('EFECTIVO', 20000),
          plan,
        );
        expect(flow.expenses, 12345);
        expect(flow.expense('EFECTIVO'), 12345);
        expect(flow.net, 7655);
      }
    },
  );

  ProjectedPayment detail(
    String id,
    String source,
    String payee,
    String reference,
    int amount,
    int day, {
    String type = 'FISCAL',
  }) => ProjectedPayment(
    id: id,
    source: source,
    payee: payee,
    reference: reference,
    account: 'DICSA|CELAYA',
    date: f.week.add(Duration(days: day)),
    amount: amount,
    available: amount,
    paymentType: type,
  );
  for (final scenario in [
    'normal',
    'empty',
    'incomplete',
    'large',
    'long',
    'tickets-only',
  ]) {
    test('itemized expense PDF paginates without losing detail: $scenario', () async {
      final plan = WeeklyExpensePlan(
        week: f.week,
        revision: 4,
        generated: scenario != 'incomplete',
        payments: scenario == 'empty'
            ? []
            : scenario == 'tickets-only'
            ? [
                detail(
                  'only-ticket',
                  'ticket',
                  'PROVEEDOR DE TICKET',
                  'TICKET-NO-EXPORTAR',
                  999999,
                  0,
                  type: 'SIN_CLASIFICAR',
                ),
              ]
            : [
                // Deliberately unsorted to verify the report's day/folio order.
                detail(
                  'fiscal',
                  'invoice',
                  'PAPELERA DEL NORTE',
                  'Factura FAC-2026-0925',
                  2750000,
                  4,
                ),
                detail(
                  'cash',
                  'fixed',
                  'SERVICIOS INDUSTRIALES',
                  'Pago fijo de mantenimiento',
                  1250000,
                  0,
                  type: 'EFECTIVO',
                ),
                detail(
                  'unknown',
                  'manual',
                  'GASTO ADICIONAL DE PATIO',
                  'Egreso adicional',
                  37500,
                  6,
                  type: 'SIN_CLASIFICAR',
                ),
                detail(
                  'agreement',
                  'agreement',
                  'TRANSPORTES DEL BAJÍO',
                  'Convenio / cuota 3',
                  120000,
                  2,
                ),
                detail(
                  'ticket',
                  'ticket',
                  'RECICLADORA EL SOL',
                  'Ticket SIN-FACTURA-024',
                  155000,
                  1,
                  type: 'EFECTIVO',
                ),
                detail(
                  'excluded',
                  'manual',
                  'BENEFICIARIO EXCLUIDO',
                  'REFERENCIA-EXCLUIDA',
                  99999999,
                  0,
                ).copyWith(included: false),
                detail(
                  'removed',
                  'manual',
                  'BENEFICIARIO BORRADO',
                  'REFERENCIA-BORRADA',
                  99999999,
                  0,
                ).copyWith(removed: true),
                if (scenario == 'large')
                  for (var i = 0; i < 4993; i++)
                    detail(
                      '$i',
                      'invoice',
                      'PROVEEDOR ${i.toString().padLeft(5, '0')}',
                      'FOLIO-${i.toString().padLeft(5, '0')}-X',
                      100000000000000,
                      i % 7,
                      type: i.isEven ? 'EFECTIVO' : 'FISCAL',
                    ),
                if (scenario == 'long')
                  detail(
                    'long',
                    'invoice',
                    'INICIO BENEFICIARIO ${List.filled(35, 'RAZÓN SOCIAL LARGA CON NOMBRE COMPLETO').join(' ')} FIN BENEFICIARIO',
                    'INICIO REFERENCIA ${List.filled(30, 'REFERENCIA DE FACTURA CON DESCRIPCIÓN COMPLETA').join(' ')} FIN REFERENCIA',
                    12345,
                    0,
                  ),
              ],
      );
      if (scenario == 'normal') {
        expect(plan.total, 4312500);
        expect(plan.scheduledPayments.length, 5);
      }
      final bytes = await buildWeeklyExpensesPdf(plan, generatedAt: f.week);
      // Export does not remove obligations from the saved weekly plan.
      if (scenario == 'normal') expect(plan.total, 4312500);
      expect(
        pdf.pages(bytes),
        scenario == 'large' || scenario == 'long' ? greaterThan(1) : 1,
      );
      if (Platform.environment['DICSA_FLOW_QA'] == '1') {
        await File(
          '/private/tmp/dicsa-expenses-$scenario.pdf',
        ).writeAsBytes(bytes);
        await File('/private/tmp/dicsa-expenses-$scenario.json').writeAsString(
          jsonEncode({
            'total': plan.scheduledPayments
                .where((p) => p.source != 'ticket')
                .fold<int>(0, (s, p) => s + p.amount),
            'payments': plan.scheduledPayments
                .where((p) => p.source != 'ticket')
                .map((p) => p.toJson())
                .toList(),
          }),
        );
      }
    });
  }
}
