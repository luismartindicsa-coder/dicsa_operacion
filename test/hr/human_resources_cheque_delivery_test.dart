import 'package:dicsa_operacion/app/hr/human_resources_nomina_page.dart';
import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const period = 'Periodo 37 semanal · 04/09/2026 - 10/09/2026';
const employee = {
  'id': 'delivery-test',
  'nombre': 'COLABORADOR DE PRUEBA',
  'empresa': 'DICSA',
  'salario': 2205.28,
  'salario_flujo': 0,
  'fiscal_payment_mode': 'cheque',
};

Map<String, dynamic> draft({double flow = 0, double deduction = 0}) => {
  'id': 'draft-delivery',
  'employee_id': employee['id'],
  'employee_name': employee['nombre'],
  'empresa': 'DICSA',
  'period_label': period,
  'draft_status': 'listo',
  // CONTPAQ has already applied its own deductions.
  'fiscal_net_amount': 1800,
  'fiscal_manual_deduction_amount': deduction,
  'fiscal_manual_deduction_reason': deduction > 0 ? 'Ajuste RH' : '',
  'cash_salary_amount': flow,
  'cash_salary_is_manual': true,
  'check_amount': 0,
  'source_snapshot': {
    'contpaq_official_net': 1800,
    'incidences_informational': true,
    'fiscal_payment_is_manual': false,
    'personal_fiscal_payment_mode': 'cheque',
  },
};

void main() {
  test(
    'cheque moves delivery once and preserves fiscal, salary and publication',
    () {
      for (final mode in ['cheque', 'deposito']) {
        for (final flow in [0.0, 300.0]) {
          for (final deduction in [0.0, 200.0]) {
            final master = {...employee, 'fiscal_payment_mode': mode};
            final result = hrPrenominaPrepaidProjectionForTesting(
              period: period,
              employee: master,
              draft: draft(flow: flow, deduction: deduction),
              vacations: [],
            );
            final fiscal = 1800 - deduction;
            final cheque = mode == 'cheque' ? fiscal : 0.0;
            expect(result['fiscal'], fiscal);
            expect(result['fiscal_cash'], cheque);
            expect(result['fiscal_deposit'], fiscal - cheque);
            expect(result['flow_delivery'], flow + cheque);
            expect(result['cash_salary'], flow);
            expect(result['total'], fiscal + flow);
            expect(result['envelope'], flow + cheque);
            final payload = Map<String, dynamic>.from(result['payload'] as Map);
            expect(payload['fiscal_net_amount'], 1800);
            expect(payload['cash_salary_amount'], flow);
            expect(payload['check_amount'], cheque);

            final reopened = hrPrenominaPrepaidProjectionForTesting(
              period: period,
              employee: master,
              draft: payload,
              vacations: [],
            );
            expect(reopened['flow_delivery'], result['flow_delivery']);
            expect(reopened['total'], result['total']);
            final published = hrNominaFiscalTotalsForTesting(
              period: period,
              drafts: [
                {...payload, 'draft_status': 'publicado'},
              ],
              closed: true,
              personalFiscalModes: {'delivery-test': 'deposito'},
            );
            expect(published['fiscal'], fiscal);
            expect(published['deposit'], fiscal - cheque);
            expect(published['cheque'], cheque);
            expect(published['flow_delivery'], flow + cheque);
            expect(published['total'], fiscal + flow);
          }
        }
      }
    },
  );

  test(
    'partial manual cheque keeps the remaining deposit and zero does not create payment',
    () {
      for (final net in [1800.0, 0.0]) {
        final row = draft(flow: 300)
          ..['fiscal_net_amount'] = net
          ..['check_amount'] = 500
          ..['source_snapshot'] = {
            'incidences_informational': true,
            'contpaq_official_net': net,
            'fiscal_payment_is_manual': true,
          };
        final result = hrPrenominaPrepaidProjectionForTesting(
          period: period,
          employee: employee,
          draft: row,
          vacations: [],
        );
        final cheque = net > 0 ? 500.0 : 0.0;
        expect(result['fiscal_deposit'], net - cheque);
        expect(result['flow_delivery'], 300 + cheque);
        expect(result['total'], net + 300);
      }
    },
  );

  testWidgets(
    'Prenomina editor shows cheque in delivery and saves fiscal origin',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? saved;
      final editor = hrPrenominaEditorForTesting(
        period: period,
        employee: employee,
        storedDraft: draft(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async => saved = await editor.open(context),
                  child: const Text('Abrir'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      String value(String key) =>
          tester.widget<Text>(find.byKey(ValueKey(key))).data!;
      expect(value('total-Fiscal'), r'$0.00');
      expect(value('total-Flujo'), r'$1,800.00');
      expect(value('total-Total'), r'$1,800.00');
      expect(find.text('Depósito fiscal'), findsWidgets);
      expect(find.text('Cheque · pago de origen fiscal'), findsOneWidget);
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      final payload = saved!['payload'] as Map;
      expect(payload['fiscal_net_amount'], 1800);
      expect(payload['cash_salary_amount'], 0);
      expect(payload['check_amount'], 1800);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Nomina detail shows the same cheque delivery after publication',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: hrNominaForTesting(
            period: period,
            closed: true,
            drafts: [
              {...draft(), 'check_amount': 1800, 'draft_status': 'publicado'},
            ],
            onSnapshot: (_) {},
            onAction: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ver detalle').first);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      String value(String key) =>
          tester.widget<Text>(find.byKey(ValueKey(key))).data!;
      expect(value('nomina-total-Fiscal'), r'$0.00');
      expect(value('nomina-total-Flujo'), r'$1,800.00');
      expect(value('nomina-total-Total'), r'$1,800.00');
      await tester.ensureVisible(find.byKey(const ValueKey('nomina-tab-3')));
      await tester.tap(find.byKey(const ValueKey('nomina-tab-3')));
      await tester.pumpAndSettle();
      expect(find.text('Cheque · pago de origen fiscal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
