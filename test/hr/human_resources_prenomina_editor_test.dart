import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const period = 'Periodo 35 semanal · 21/08/2026 - 27/08/2026';
const employee = {
  'id': 'test-1',
  'nombre': 'COLABORADOR DE PRUEBA',
  'empresa': 'DICSA',
  'salario': 3500,
  'salario_real_percibido': 4500,
};
const amounts = <String, num>{
  'fiscal_net_amount': 3000,
  'fiscal_vacation_amount': 100,
  'fiscal_late_deduction_amount': 30,
  'fiscal_imss_amount': 100,
  'fiscal_infonavit_amount': 200,
  'fiscal_fonacot_amount': 50,
  'fiscal_absence_amount': 60,
  'cash_salary_amount': 1000,
  'cash_vacation_amount': 50,
  'transport_support_amount': 100,
  'holiday_amount': 60,
  'overtime_monetized_amount': 120,
  'manual_bonus_amount': 80,
  'cash_isr_amount': 10,
  'cash_absence_deduction_amount': 20,
  'cash_infonavit_deduction_amount': 30,
  'cash_fonacot_deduction_amount': 40,
  'loan_deduction_amount': 50,
  'check_amount': 500,
  'payment_outside_amount': 70,
  'manual_adjustment_amount': -25,
};
Map<String, dynamic> draft() => {
  'id': 'draft-1',
  'period_label': period,
  'employee_id': 'test-1',
  'employee_name': employee['nombre'],
  'empresa': 'DICSA',
  'draft_status': 'borrador',
  ...amounts,
  'cash_salary_is_manual': true,
  'payment_channel': 'mixto',
  'payment_reference': 'REF',
  'notes': 'Nota original',
};
final attendance = [
  for (var i = 0; i < 6; i++)
    {
      'period_label': period,
      'employee_id': 'test-1',
      'source_date': '${21 + i}/08/2026',
      'status': i == 5 ? 'falto' : 'laboro',
      'source_mode': 'manual',
      'late_minutes': i == 0 ? 30 : 0,
      'overtime_minutes': i == 0 ? 120 : 0,
    },
];
final event = {
  'employee_id': 'test-1',
  'attendance_period_label': period,
  'start_date': '2026-08-21',
  'end_date': '2026-08-21',
  'status': 'aprobado',
  'impact_prenomina': true,
  'prenomina_sync_status': 'pendiente',
};

final fieldSections = <String, List<String>>{
  'percepciones': [
    'fiscalNetAmount',
    'fiscalVacationAmount',
    'cashSalaryAmount',
    'cashVacationAmount',
    'transportSupportAmount',
    'holidayAmount',
    'overtimeMonetizedAmount',
    'manualBonusAmount',
    'paymentOutsideAmount',
    'manualAdjustmentAmount',
  ],
  'descuentos': [
    'fiscalImssAmount',
    'fiscalInfonavitAmount',
    'fiscalFonacotAmount',
    'fiscalAbsenceAmount',
    'fiscalLateDeductionAmount',
    'cashIsrAmount',
    'cashAbsenceDeductionAmount',
    'cashInfonavitDeductionAmount',
    'cashFonacotDeductionAmount',
    'loanDeductionAmount',
  ],
  'notas': ['checkAmount'],
};
String snake(String text) =>
    text.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

void main() {
  setUpAll(() async {
    final path = Platform.environment['DICSA_PRENOMINA_FONT_PATH'];
    if (path != null) {
      final loader = FontLoader('Roboto')
        ..addFont(
          File(path).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
      final icons = File('${File(path).parent.path}/MaterialIcons-Regular.otf');
      if (await icons.exists()) {
        await (FontLoader('MaterialIcons')..addFont(
              icons.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            ))
            .load();
      }
    }
  });
  test(
    'existing fiscal net, deductions and weekly result remain unchanged',
    () {
      final preview = hrPrenominaEditorForTesting(
        period: period,
        employee: employee,
        storedDraft: draft(),
        attendanceRows: attendance,
        vacationRows: [
          {
            ...event,
            'id': 'vacation',
            'event_type': 'vacaciones_pagadas',
            'days_applied': 1,
          },
        ],
        permissionRows: [
          {
            ...event,
            'id': 'permission',
            'permission_type': 'permiso_sin_goce',
            'request_unit': 'dia',
            'quantity_days': 1,
          },
        ],
      );
      expect(preview.totals, {
        'fiscal': 3100.0,
        'flow': 1325.0,
        'total': 4425.0,
        'flow_deductions': 130.0,
        'fiscal_deductions': 440.0,
        'vacation_days': 1.0,
        'without_pay_days': 1.0,
        'late_minutes': 30.0,
        'extra_minutes': 120.0,
      });
      for (final distribution in [0, 500, 99999]) {
        final varied = hrPrenominaEditorForTesting(
          period: period,
          employee: employee,
          storedDraft: {...draft(), 'check_amount': distribution},
        );
        expect(varied.totals['total'], 4425);
        expect(varied.totals['flow'], 1325);
      }
    },
  );

  test(
    'automatic complement uses contractual base and fiscal retardo stays bounded',
    () {
      final automatic = hrPrenominaEditorForTesting(
        period: period,
        employee: employee,
        storedDraft: {
          ...draft(),
          'cash_salary_is_manual': false,
          'cash_salary_amount': 99999,
        },
      );
      expect(automatic.totals['flow'], 1325);
      final bounded = hrPrenominaEditorForTesting(
        period: period,
        employee: employee,
        storedDraft: {...draft(), 'fiscal_late_deduction_amount': 5000},
      );
      expect(bounded.totals['fiscal'], 3100);
      expect(bounded.totals['total'], 4425);
    },
  );

  Future<void> select(WidgetTester tester, String section) async {
    final target = find.byKey(ValueKey('section-$section'));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> mount(
    WidgetTester tester,
    Future<void> Function(BuildContext) open, {
    Size size = const Size(1440, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            RepaintBoundary(key: const ValueKey('preview-root'), child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => open(context),
              child: const Text('Abrir empleado'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir empleado'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'all 21 inputs survive section switches, save payload and reopen',
    (tester) async {
      Map<String, dynamic>? result;
      var stored = draft();
      await mount(tester, (context) async {
        result = await hrPrenominaEditorForTesting(
          period: period,
          employee: employee,
          storedDraft: stored,
          attendanceRows: attendance,
        ).open(context);
        if (result != null) {
          stored = Map<String, dynamic>.from(result!['payload'] as Map);
        }
      });
      expect(find.textContaining('5 trabajados · 1 faltas'), findsOneWidget);
      expect(find.byKey(const ValueKey('total-Fiscal')), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      final expected = <String, double>{};
      var amount = 101;
      for (final section in fieldSections.entries) {
        await select(tester, section.key);
        for (final id in section.value) {
          final target = find.byKey(ValueKey(id));
          await tester.ensureVisible(target);
          await tester.enterText(target, '$amount.25');
          expected[snake(id)] = amount + .25;
          amount++;
        }
      }
      for (final pair in [
        ('notes', '  Nota actualizada  '),
        ('paymentReference', '  NUEVA REF  '),
      ]) {
        final target = find.byKey(ValueKey(pair.$1));
        await tester.ensureVisible(target);
        await tester.enterText(target, pair.$2);
      }
      await select(tester, 'resumen');
      expect(find.text('1 nota RH'), findsOneWidget);
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(result!['action'], 'save');
      for (final entry in expected.entries) {
        expect(stored[entry.key], entry.value, reason: entry.key);
      }
      expect(stored['cash_salary_is_manual'], isTrue);
      expect(stored['notes'], 'Nota actualizada');
      expect(stored['payment_reference'], 'NUEVA REF');
      expect(stored['payment_channel'], 'mixto');
      expect(stored['draft_status'], 'borrador');
      expect(stored['fiscal_manual_deduction_amount'], 0);
      expect(stored['fiscal_manual_deduction_reason'], '');
      expect(stored.keys.toSet(), {
        ...draft().keys,
        'source_snapshot',
        'fiscal_manual_deduction_amount',
        'fiscal_manual_deduction_reason',
      });
      await tester.tap(find.text('Abrir empleado'));
      await tester.pumpAndSettle();
      for (final section in fieldSections.entries) {
        await select(tester, section.key);
        for (final id in section.value) {
          final field = tester.widget<TextFormField>(find.byKey(ValueKey(id)));
          expect(field.initialValue, expected[snake(id)]!.toStringAsFixed(2));
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final action in [('Anterior', 'previous'), ('Siguiente', 'next')]) {
    testWidgets('${action.$1} uses existing save result with pending edits', (
      tester,
    ) async {
      Map<String, dynamic>? result;
      await mount(tester, (context) async {
        result = await hrPrenominaEditorForTesting(
          period: period,
          employee: employee,
          storedDraft: draft(),
        ).open(context);
      });
      await select(tester, 'percepciones');
      await tester.enterText(
        find.byKey(const ValueKey('fiscalNetAmount')),
        '3210',
      );
      await tester.tap(find.text(action.$1));
      await tester.pumpAndSettle();
      expect(result!['action'], action.$2);
      expect(result!['payload']['fiscal_net_amount'], 3210);
    });
  }

  testWidgets('invalid input prevents save and cancel discards edits', (
    tester,
  ) async {
    Map<String, dynamic>? result;
    await mount(tester, (context) async {
      result = await hrPrenominaEditorForTesting(
        period: period,
        employee: employee,
        storedDraft: draft(),
      ).open(context);
    });
    await select(tester, 'percepciones');
    await tester.enterText(
      find.byKey(const ValueKey('fiscalNetAmount')),
      'abc',
    );
    await select(tester, 'resumen');
    await tester.tap(find.text('Guardar borrador'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Captura un monto válido'), findsOneWidget);
    await select(tester, 'percepciones');
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('fiscalNetAmount')))
          .initialValue,
      'abc',
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('published state returns original publication payload', (
    tester,
  ) async {
    Map<String, dynamic>? result;
    await mount(tester, (context) async {
      result = await hrPrenominaEditorForTesting(
        period: period,
        employee: employee,
        storedDraft: draft(),
      ).open(context);
    });
    await select(tester, 'notas');
    await tester.tap(find.byKey(const ValueKey('picker-Estatus')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publicado'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('picker-Canal de pago')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flujo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar y publicar'));
    await tester.pumpAndSettle();
    expect(result!['action'], 'save');
    expect(result!['payload']['draft_status'], 'publicado');
    expect(result!['payload']['payment_channel'], 'efectivo');
  });

  for (final size in [const Size(1440, 1000), const Size(900, 700)]) {
    testWidgets('layout and diagnostics remain accessible at $size', (
      tester,
    ) async {
      await mount(tester, (context) async {
        await hrPrenominaEditorForTesting(
          period: period,
          employee: employee,
          storedDraft: draft(),
          attendanceRows: attendance,
        ).open(context);
      }, size: size);
      expect(tester.takeException(), isNull);
      final previewPath = Platform.environment['DICSA_PRENOMINA_PREVIEW_PATH'];
      if (previewPath != null && size.width == 1440) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('preview-root')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(previewPath).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      for (final section in fieldSections.keys) {
        await select(tester, section);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
