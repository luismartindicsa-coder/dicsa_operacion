import 'dart:io';
import 'dart:ui' as ui;
import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const period = 'Periodo 35 semanal · 21/08/2026 - 27/08/2026';
final employees = [
  for (var i = 1; i <= 45; i++)
    {
      'id': '$i',
      'nombre': 'COLABORADOR ${i.toString().padLeft(2, '0')}',
      'empresa': i <= 20 ? 'MONROE' : 'DICSA',
      'salario': 2500,
      'salario_real_percibido': 2500,
    },
];
final drafts = [
  for (var i = 1; i <= 45; i++)
    {
      'id': 'draft-$i',
      'employee_id': '$i',
      'period_label': period,
      'draft_status': i == 1 ? 'revision_rh' : 'listo',
      'fiscal_net_amount': 2200,
      'fiscal_late_deduction_amount': 0,
      'fiscal_vacation_amount': 0,
      'cash_salary_amount': 300,
      'cash_salary_is_manual': true,
      'cash_vacation_amount': 0,
      'transport_support_amount': 0,
      'holiday_amount': 0,
      'overtime_monetized_amount': 0,
      'manual_bonus_amount': 0,
      'cash_isr_amount': 0,
      'cash_absence_deduction_amount': 0,
      'cash_infonavit_deduction_amount': 0,
      'cash_fonacot_deduction_amount': 0,
      'loan_deduction_amount': 0,
      'check_amount': 100,
      'payment_outside_amount': 50,
      'manual_adjustment_amount': -20,
    },
];
final attendance = [
  for (var i = 1; i <= 45; i++)
    {
      'employee_id': '$i',
      'period_label': period,
      'source_date': '21/08/2026',
      'status': i == 1 ? 'falto' : 'laboro',
      'source_mode': 'manual',
      'late_minutes': i == 1 ? 30 : 0,
      'overtime_minutes': i == 2 ? 120 : 0,
    },
];

final event = {
  'employee_id': '2',
  'attendance_period_label': period,
  'start_date': '2026-08-21',
  'end_date': '2026-08-21',
  'status': 'aprobado',
  'impact_prenomina': true,
  'prenomina_sync_status': 'pendiente',
};
final vacations = [
  {...event, 'id': 'v1', 'event_type': 'vacaciones_pagadas', 'days_applied': 1},
];
final permissions = [
  {
    ...event,
    'id': 'p1',
    'permission_type': 'permiso_sin_goce',
    'request_unit': 'dia',
    'quantity_days': 1,
  },
  {
    ...event,
    'id': 'p2',
    'permission_type': 'incapacidad',
    'request_unit': 'dia',
    'quantity_days': 0.5,
  },
];

void main() {
  setUpAll(() async {
    final path = Platform.environment['DICSA_PRENOMINA_FONT_PATH'];
    if (path != null) {
      for (final pair in [
        ('Roboto', 'Roboto-Regular.ttf'),
        ('Ahem', 'Roboto-Regular.ttf'),
        ('MaterialIcons', 'MaterialIcons-Regular.otf'),
      ]) {
        final file = File('${File(path).parent.path}/${pair.$2}');
        await (FontLoader(pair.$1)..addFont(
              file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            ))
            .load();
      }
    }
  });
  Map<String, dynamic> snapshot = {};
  final actions = <String>[];
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1555, 1012),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    snapshot = {};
    actions.clear();
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            RepaintBoundary(key: const ValueKey('grid-preview'), child: child!),
        home: hrPrenominaGridForTesting(
          period: period,
          employees: employees,
          drafts: drafts,
          attendance: attendance,
          vacations: vacations,
          permissions: permissions,
          onSnapshot: (value) => snapshot = value,
          onAction: actions.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('same period totals and real 40/80/120 pagination', (
    tester,
  ) async {
    await mount(tester);
    expect(snapshot['count'], 45);
    expect(snapshot['ready'], 44);
    expect(snapshot['review'], 1);
    expect(snapshot['extra'], 120);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('kpi-Vacaciones')),
        matching: find.text('1 d'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('kpi-Permisos')),
        matching: find.text('1.50 d'),
      ),
      findsOneWidget,
    );
    expect(snapshot['fiscal'], 99000);
    expect(snapshot['flow'], 14850);
    expect(snapshot['total'], 113850);
    expect(snapshot['visible_ids'], hasLength(40));
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(snapshot['page'], 1);
    expect(snapshot['visible_ids'], ['41', '42', '43', '44', '45']);
    expect(snapshot['total'], 113850);
    await tester.tap(find.text('Anterior'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('80').last);
    await tester.pumpAndSettle();
    expect(snapshot['page_size'], 80);
    expect(snapshot['visible_ids'], hasLength(45));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'search keeps native Delete, Backspace and cursor keys inside text',
    (tester) async {
      await mount(tester);
      final search = find.byKey(const ValueKey('employee-search'));
      await tester.enterText(search, 'COLABORADOR 03');
      await tester.pumpAndSettle();
      final controller = tester.widget<TextField>(search).controller!;
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(controller.text, 'COLABORADOR 0');
      expect(snapshot['count'], 9);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(controller.text, 'COLABORADOR ');
      expect(snapshot['count'], 45);
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(controller.text, isEmpty);
      expect(snapshot['count'], 45);
      expect(actions, isEmpty);
      expect(find.byKey(const ValueKey('section-resumen')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search, existing state filter, derived incidents, company and clearing compose locally',
    (tester) async {
      await mount(tester);
      await tester.enterText(
        find.byKey(const ValueKey('employee-search')),
        'COLABORADOR 03',
      );
      await tester.pumpAndSettle();
      expect(snapshot['visible_ids'], ['3']);
      expect(snapshot['total'], 2530);
      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();
      expect(snapshot['count'], 45);
      await tester.tap(find.byKey(const ValueKey('filter-Revisión RH')));
      await tester.pumpAndSettle();
      expect(snapshot['visible_ids'], ['1']);
      await tester.tap(find.byKey(const ValueKey('filter-Todos')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter-Con incidencias')));
      await tester.pumpAndSettle();
      expect(snapshot['visible_ids'], ['1', '2']);
      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Todas las empresas'));
      await tester.tap(find.text('Todas las empresas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MONROE').last);
      await tester.pumpAndSettle();
      expect(snapshot['count'], 20);
      await tester.ensureVisible(find.text('Limpiar'));
      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();
      expect(snapshot['count'], 45);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'existing row selection, double click detail, cancel and action dispatch',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('COLABORADOR 02'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar borrador'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('section-resumen')), findsOneWidget);
      expect(find.textContaining('ID #2'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(snapshot['count'], 45);
      await tester.tap(find.text('COLABORADOR 03'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.text('COLABORADOR 03'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('section-resumen')), findsOneWidget);
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(actions, contains('save:3:save'));
      await tester.tap(find.text('Exportar sobres'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar periodo'));
      await tester.pumpAndSettle();
      expect(actions, containsAll(['export', 'close']));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'known baseline limitation: navigation collapses modifier selection',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('COLABORADOR 01'));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('COLABORADOR 03'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('Seleccionados: 1'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('COLABORADOR 05'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.text('Seleccionados: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(1555, 1012), const Size(1000, 760)]) {
    testWidgets(
      'grid layout keeps critical columns through horizontal scroll at $size',
      (tester) async {
        await mount(tester, size: size);
        expect(find.text('PAGO FISCAL'), findsOneWidget);
        expect(find.text('PAGO FLUJO'), findsOneWidget);
        expect(find.byKey(const ValueKey('kpi-Total a pagar')), findsOneWidget);
        expect(tester.takeException(), isNull);
        final path = Platform.environment['DICSA_PRENOMINA_GRID_PREVIEW_PATH'];
        if (path != null && size.width == 1555) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('grid-preview')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(path).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
}
