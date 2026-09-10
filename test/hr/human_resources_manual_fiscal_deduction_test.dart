import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:dicsa_operacion/app/hr/human_resources_nomina_page.dart';
import 'package:dicsa_operacion/app/hr/human_resources_dashboard_page.dart';

const period = 'Periodo 37 semanal · 04/09/2026 - 10/09/2026';
const person = {
  'id': 'test-fiscal',
  'nombre': 'COLABORADOR DE PRUEBA',
  'empresa': 'DICSA',
  'salario': 2205.28,
  'salario_flujo': 300,
};
Map<String, dynamic> draft({double amount = 150, String mode = 'deposito'}) => {
  'id': 'test-draft',
  'employee_id': 'test-fiscal',
  'employee_name': 'COLABORADOR DE PRUEBA',
  'empresa': 'DICSA',
  'period_label': period,
  'draft_status': 'borrador',
  'fiscal_net_amount': 1700,
  'cash_salary_amount': 300,
  'fiscal_manual_deduction_amount': amount,
  'fiscal_manual_deduction_reason': 'Ajuste adicional autorizado por RH',
  'fiscal_late_deduction_amount': 100,
  'fiscal_absence_amount': 315.04,
  'cash_absence_deduction_amount': 50,
  'source_snapshot': {
    'contpaq_official_net': 1700,
    'incidences_informational': true,
    'fiscal_payment_is_manual': false,
    'personal_fiscal_payment_mode': mode,
    'loan_fund': {
      'version': 2,
      'end_date': '2026-09-10',
      'requested_amount': 500,
      'amount': 0,
      'fiscal_amount': 500,
      'pending_amount': 0,
      'fiscal_ready': true,
      'dues': [],
      'allocations': [],
    },
  },
};
Map<String, dynamic> project(
  Map<String, dynamic> row, {
  String mode = 'deposito',
  double net = 1700,
}) => hrPrenominaPeriodProjectionForTesting(
  period: period,
  employees: [
    {...person, 'fiscal_payment_mode': mode},
  ],
  drafts: [row],
  contpaq: [
    {'employee_id': 'test-fiscal', 'net': '$net'},
  ],
).single;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['MANUAL_FISCAL_QA'] == null) return;
    final regular = File(
      '/opt/homebrew/share/flutter/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf',
    ).readAsBytesSync();
    for (final font in ['Roboto', 'Ahem']) {
      await (FontLoader(
        font,
      )..addFont(Future.value(ByteData.sublistView(regular)))).load();
    }
    final icons = File(
      '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
  });
  for (final mode in ['deposito', 'cheque']) {
    test(
      'manual deduction preserves official net, flow and repeats safely with $mode',
      () {
        var row = draft(mode: mode);
        for (var i = 0; i < 4; i++) {
          final result = project(row, mode: mode);
          expect(result['fiscal'], 1550);
          expect(result['total'], 1850);
          expect(result['cash_salary'], 300);
          expect(result['fiscal_cash'], mode == 'cheque' ? 1550 : 0);
          expect(result['fiscal_deposit'], mode == 'cheque' ? 0 : 1550);
          row = Map<String, dynamic>.from(result['payload']);
          expect(row['fiscal_net_amount'], 1700);
          expect(row['source_snapshot']['contpaq_official_net'], 1700);
          expect(row['fiscal_manual_deduction_amount'], 150);
          expect(
            row['fiscal_manual_deduction_reason'],
            'Ajuste adicional autorizado por RH',
          );
          final nomina = hrNominaFiscalTotalsForTesting(
            drafts: [row],
            period: period,
            personalFiscalModes: {'test-fiscal': mode},
          );
          expect(nomina['fiscal'], 1550);
          expect(nomina['total'], 1850);
          expect(nomina['cheque'], result['fiscal_cash']);
          expect(hrDashboardPayrollForTesting([row]), {
            'fiscal': 1550.0,
            'total': 1850.0,
          });
        }
        final published = {...row, 'draft_status': 'publicado'};
        expect(project(published, mode: mode, net: 9999)['fiscal'], 1550);
        final cleared = project({
          ...row,
          'fiscal_manual_deduction_amount': 0,
          'fiscal_manual_deduction_reason': '',
        }, mode: mode);
        expect(cleared['fiscal'], 1700);
        expect(cleared['total'], 2000);
      },
    );
  }
  test(
    'a later CONTPAQ import keeps the explicit deduction and a full deduction leaves flow unchanged',
    () {
      final changed = project(draft(), net: 1600);
      expect(changed['fiscal'], 1450);
      expect(changed['total'], 1750);
      final all = project(draft(amount: 1700), mode: 'cheque');
      expect(all['fiscal'], 0);
      expect(all['fiscal_cash'], 0);
      expect(all['total'], 300);
    },
  );
  testWidgets(
    'editor requires a reason, rejects invalid amounts and saves once across tabs',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? saved;
      final key = GlobalKey();
      final fixture = hrPrenominaEditorForTesting(
        period: period,
        employee: person,
        storedDraft: draft(amount: 0)..['fiscal_manual_deduction_reason'] = '',
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Abrir'),
                onPressed: () async {
                  saved = await fixture.open(context);
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('section-descuentos')));
      await tester.pumpAndSettle();
      final amount = find.byKey(const ValueKey('fiscalManualDeductionAmount'));
      for (final value in ['NaN', '1.005', '-5', '1701']) {
        await tester.enterText(amount, value);
        await tester.tap(find.text('Guardar borrador'));
        await tester.pumpAndSettle();
        expect(saved, isNull);
        expect(find.byType(Dialog), findsOneWidget);
      }
      await tester.enterText(amount, '150');
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(
        find.text('Indica el motivo del descuento fiscal manual.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('fiscalManualDeductionReason')),
        'Ajuste adicional autorizado por RH',
      );
      await tester.pumpAndSettle();
      expect(find.text(r'$1,550.00'), findsWidgets);
      final folder = Platform.environment['MANUAL_FISCAL_QA'];
      if (folder != null) {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$folder/editor.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.byKey(const ValueKey('section-resumen')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('section-descuentos')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(amount).initialValue, '150');
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(saved!['payload']['fiscal_manual_deduction_amount'], 150);
      expect(saved!['payload']['fiscal_net_amount'], 1700);
      expect(saved!['payload']['cash_salary_amount'], 300);
      final reopened = hrPrenominaEditorForTesting(
        period: period,
        employee: person,
        storedDraft: Map<String, dynamic>.from(saved!['payload']),
      );
      expect(reopened.totals['fiscal'], 1550);
      expect(reopened.totals['total'], 1850);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'report and archived receipt include the additional deduction',
    () async {
      final row =
          project(draft(mode: 'cheque'), mode: 'cheque')['payload']
              as Map<String, dynamic>;
      final report = await hrNominaPeriodReportPdfForTesting(
        drafts: [
          {...row, 'draft_status': 'publicado'},
        ],
        period: period,
        closed: true,
      );
      final receipt = await hrNominaManualFiscalReceiptForTesting(row);
      expect(report.take(4), [37, 80, 68, 70]);
      expect(receipt.take(4), [37, 80, 68, 70]);
      final folder = Platform.environment['MANUAL_FISCAL_QA'];
      if (folder != null) {
        await File('$folder/report.pdf').writeAsBytes(report);
        await File('$folder/receipt.pdf').writeAsBytes(receipt);
      }
    },
  );
}
