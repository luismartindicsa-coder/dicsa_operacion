import 'dart:io';
import 'dart:ui' as ui;
import 'package:dicsa_operacion/app/hr/human_resources_fiscal_payment.dart';
import 'package:dicsa_operacion/app/hr/human_resources_nomina_page.dart';
import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const period = 'Periodo 35 semanal · 21/08/2026 - 27/08/2026';
const chequeIds = [
  '114',
  '217',
  '252',
  '285',
  '286',
  '287',
  '289',
  '290',
  '297',
  '298',
  '299',
];
final modes = {for (final id in chequeIds) id: 'cheque', '900': 'deposito'};
final drafts = [
  for (final id in [...chequeIds, '900'])
    {
      'id': 'draft-$id',
      'employee_id': id,
      'employee_name': 'COLABORADOR DE PRUEBA $id',
      'empresa': 'DICSA',
      'period_label': period,
      'draft_status': 'listo',
      'fiscal_net_amount': id == '900' ? 1500.0 : 2200.0,
      'cash_salary_amount': id == '900' ? 0.0 : 300.0,
      'check_amount': 0.0,
      'payment_channel': 'deposito',
      'source_snapshot': {'incidences_informational': true},
    },
];
final employees = [
  for (final draft in drafts)
    {
      'id': draft['employee_id'],
      'nombre': draft['employee_name'],
      'empresa': 'DICSA',
      'salario': draft['fiscal_net_amount'],
      'salario_flujo': draft['cash_salary_amount'],
      'fiscal_payment_mode': modes[draft['employee_id']],
      'overtime_hourly_rate': 60,
    },
];

void main() {
  setUpAll(() async {
    final fontDir = Platform.environment['FISCAL_REPORT_FONT_DIR'];
    if (fontDir != null) {
      for (final (family, file) in [
        ('Roboto', 'Roboto-Regular.ttf'),
        ('Ahem', 'Roboto-Regular.ttf'),
        ('MaterialIcons', 'MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(family)..addFont(
              File(
                '$fontDir/$file',
              ).readAsBytes().then((b) => ByteData.sublistView(b)),
            ))
            .load();
      }
    }
  });
  test(
    'legacy zero follows Personal but explicit zero and positive manual allocation remain',
    () {
      for (final zero in [null, 0.0]) {
        expect(
          HrFiscalPayment.resolve(
            total: 2200,
            storedCheque: zero,
            snapshot: {},
            personalMode: 'cheque',
          ).cheque,
          2200,
        );
      }
      expect(
        HrFiscalPayment.resolve(
          total: 2200,
          storedCheque: 0,
          snapshot: {'fiscal_payment_is_manual': true},
          personalMode: 'cheque',
        ).cheque,
        0,
      );
      expect(
        HrFiscalPayment.resolve(
          total: 2200,
          storedCheque: 100,
          snapshot: {},
          personalMode: 'cheque',
        ).cheque,
        100,
      );
      final bounded = HrFiscalPayment.resolve(
        total: 1200,
        storedCheque: 9999,
        snapshot: {},
        personalMode: 'cheque',
      );
      expect(bounded.cheque, 1200);
      expect(bounded.deposit, 0);
    },
  );
  test(
    '11 Personal cheque profiles reach Prenomina, saved draft, published Nomina and report totals',
    () {
      final payloads = <Map<String, dynamic>>[];
      for (var i = 0; i < drafts.length; i++) {
        final result = hrPrenominaPrepaidProjectionForTesting(
          period: period,
          employee: employees[i],
          draft: drafts[i],
          vacations: [],
        );
        final expected = i < 11 ? 2200.0 : 0.0;
        expect(result['fiscal_cash'], expected);
        expect(result['fiscal_deposit'], i < 11 ? 0 : 1500);
        final payload = Map<String, dynamic>.from(result['payload'] as Map);
        expect(payload['check_amount'], expected);
        payloads.add({...payload, 'draft_status': 'publicado'});
      }
      // Published amounts remain correctly allocated even if Personal later changes.
      final linked = hrNominaFiscalTotalsForTesting(
        drafts: payloads,
        period: period,
        personalFiscalModes: {for (final id in modes.keys) id: 'deposito'},
        closed: true,
      );
      expect(linked['cheque'], 24200);
      expect(linked['deposit'], 1500);
      expect(linked['fiscal'], 25700);
      expect(linked['total'], 29000);
      final preliminary = hrNominaFiscalTotalsForTesting(
        drafts: drafts,
        period: period,
        personalFiscalModes: modes,
      );
      expect(preliminary['rows'], linked['rows']);
    },
  );
  test(
    'old published, closed, receipted and manual distributions do not change from Personal',
    () {
      for (final change in [
        {'draft_status': 'publicado'},
        {
          'source_snapshot': {'payroll_receipt': {}},
        },
        {
          'source_snapshot': {'fiscal_payment_is_manual': true},
        },
      ]) {
        final result = hrNominaFiscalTotalsForTesting(
          drafts: [
            {...drafts.first, ...change},
          ],
          period: period,
          personalFiscalModes: modes,
        );
        expect(result['cheque'], 0);
        expect(result['deposit'], 2200);
        expect(result['total'], 2500);
      }
      final closed = hrNominaFiscalTotalsForTesting(
        drafts: drafts,
        period: period,
        personalFiscalModes: modes,
        closed: true,
      );
      expect(closed['cheque'], 0);
      expect(closed['deposit'], 25700);
    },
  );
  test(
    'automatic saved snapshot follows current Personal and fallback is retained without master',
    () {
      final row = {
        ...drafts.first,
        'source_snapshot': {
          'fiscal_payment_is_manual': false,
          'personal_fiscal_payment_mode': 'cheque',
        },
      };
      expect(
        hrNominaFiscalTotalsForTesting(drafts: [row], period: period)['cheque'],
        2200,
      );
      expect(
        hrNominaFiscalTotalsForTesting(
          drafts: [row],
          period: period,
          personalFiscalModes: {'114': 'deposito'},
        )['cheque'],
        0,
      );
    },
  );
  test('production PDF uses the linked fiscal allocation', () async {
    final bytes = await hrNominaPeriodReportPdfForTesting(
      drafts: drafts,
      period: period,
      personalFiscalModes: modes,
    );
    expect(bytes.take(4).toList(), [37, 80, 68, 70]);
    final path = Platform.environment['FISCAL_REPORT_PDF'];
    if (path != null) await File(path).writeAsBytes(bytes);
  });

  for (final isNomina in [false, true]) {
    testWidgets(
      '${isNomina ? 'Nomina' : 'Prenomina'} shows period deposit, cheque and fiscal without filtering them',
      (tester) async {
        tester.view.physicalSize = const Size(1555, 1012);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Map<String, dynamic> snapshot = {};
        await tester.pumpWidget(
          MaterialApp(
            builder: (_, child) => RepaintBoundary(
              key: const ValueKey('fiscal-preview'),
              child: child!,
            ),
            home: isNomina
                ? hrNominaForTesting(
                    drafts: drafts,
                    period: period,
                    closed: false,
                    personalFiscalModes: modes,
                    onSnapshot: (s) => snapshot = s,
                    onAction: (_) {},
                  )
                : hrPrenominaGridForTesting(
                    period: period,
                    employees: employees,
                    drafts: drafts,
                    onSnapshot: (s) => snapshot = s,
                    onAction: (_) {},
                  ),
          ),
        );
        await tester.pumpAndSettle();
        expect(snapshot['cheque'], 24200);
        expect(snapshot['deposit'], 1500);
        String value(String key) =>
            tester.widget<Text>(find.byKey(ValueKey(key))).data!;
        expect(value('fiscal-cheque-total'), r'$24,200.00');
        expect(value('fiscal-deposit-total'), r'$1,500.00');
        expect(value('fiscal-combined-total'), r'$25,700.00');
        expect(tester.takeException(), isNull);
        final outputDir = Platform.environment['FISCAL_REPORT_PREVIEW_DIR'];
        if (outputDir != null) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('fiscal-preview')),
            );
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$outputDir/${isNomina ? 'nomina' : 'prenomina'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.enterText(
          find.byKey(ValueKey(isNomina ? 'nomina-search' : 'employee-search')),
          '900',
        );
        await tester.pumpAndSettle();
        expect(value('fiscal-cheque-total'), r'$24,200.00');
        expect(value('fiscal-deposit-total'), r'$1,500.00');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
