import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:dicsa_operacion/app/hr/human_resources_nomina_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const period = 'Periodo 35 semanal · 21/08/2026 - 27/08/2026';
final drafts = [
  for (var i = 1; i <= 45; i++)
    {
      'id': 'draft-$i',
      'employee_id': '$i',
      'employee_name': 'COLABORADOR ${i.toString().padLeft(2, '0')}',
      'empresa': i < 20 ? 'MONROE' : 'DICSA',
      'period_label': period,
      'created_at': '2026-08-27T12:00:00Z',
      'draft_status': i == 1
          ? 'publicado'
          : i == 2
          ? 'revisionRh'
          : 'listo',
      'fiscal_net_amount': 2200,
      'fiscal_late_deduction_amount': 20,
      'cash_salary_amount': 300,
      'cash_vacation_amount': 100,
      'transport_support_amount': 50,
      'holiday_amount': 30,
      'overtime_monetized_amount': 40,
      'manual_bonus_amount': 60,
      'manual_adjustment_amount': -10,
      'cash_isr_amount': 10,
      'cash_absence_deduction_amount': 20,
      'cash_infonavit_deduction_amount': 30,
      'cash_fonacot_deduction_amount': 40,
      'loan_deduction_amount': 50,
      'check_amount': 100,
      'payment_outside_amount': 70,
      'payment_channel': 'mixto',
      'payment_reference': 'REF-$i',
      'notes': 'Nota original de RH',
    },
];
Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['NOMINA_PREVIEW'] != '1') return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('preview-root')),
    );
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '/private/tmp/dicsa_nomina_ui/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final path = Platform.environment['NOMINA_FONT_PATH'];
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

  late Map<String, dynamic> snapshot;
  late List<String> actions;
  Future<void> load(
    WidgetTester tester, {
    bool closed = true,
    Size size = const Size(1555, 1012),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    actions = [];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            RepaintBoundary(key: const ValueKey('preview-root'), child: child!),
        home: hrNominaForTesting(
          drafts: drafts,
          period: period,
          closed: closed,
          onSnapshot: (s) => snapshot = s,
          onAction: actions.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'same financial projection, pagination, filters and period actions',
    (tester) async {
      await load(tester);
      expect(tester.takeException(), isNull);
      await capture(tester, 'grid');
      expect(snapshot['count'], 45);
      expect(snapshot['visible'], 40);
      expect(snapshot['fiscal'], 98100);
      expect(snapshot['deposit'], 93600);
      expect(snapshot['flow'], 26550); // Incluye los 4,500 de cheque fiscal.
      expect(snapshot['total'], 120150);
      final rows = snapshot['rows'] as List;
      expect(rows.first, {
        'id': '1',
        'fiscal': 2180.0,
        'flow': 590.0,
        'deductions': 150.0,
        'total': 2670.0,
        'status': 'Publicado',
      });
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(snapshot['visible'], 5);
      await tester.enterText(
        find.byKey(const ValueKey('nomina-search')),
        'COLABORADOR 01',
      );
      await tester.pumpAndSettle();
      expect(snapshot['filtered'], 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(snapshot['filtered'], 9);
      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();
      expect(snapshot['filtered'], 45);
      await tester.tap(find.text('PDF del periodo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver a prenómina'));
      await tester.pumpAndSettle();
      expect(actions, ['period-pdf', 'prenomina']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('detail tabs use read-only data and preserve receipt guards', (
    tester,
  ) async {
    await load(tester);
    await tester.tap(find.byTooltip('Ver detalle').first);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await capture(tester, 'detail');
    final dialog = find.byType(Dialog);
    for (var i = 0; i < 7; i++) {
      await tester.ensureVisible(find.byKey(ValueKey('nomina-tab-$i')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('nomina-tab-$i')));
      await tester.pumpAndSettle();
      await capture(tester, 'detail-section-$i');
      expect(
        find.descendant(of: dialog, matching: find.byType(EditableText)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Nota original de RH'), findsOneWidget);
    await tester.tap(find.text('Abrir / generar recibo'));
    await tester.pumpAndSettle();
    expect(actions, ['receipt:1']);
    await tester.tap(find.text('Ver prenómina'));
    await tester.pumpAndSettle();
    expect(actions.last, 'prenomina');
    expect(dialog, findsNothing);
  });
  testWidgets('open period cannot issue receipt and compact viewport fits', (
    tester,
  ) async {
    await load(tester, closed: false, size: const Size(1000, 760));
    expect(tester.takeException(), isNull);
    await capture(tester, 'grid-compact');
    // The table preserves its columns with horizontal scrolling at this width.
    await tester.ensureVisible(find.byTooltip('Ver detalle').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ver detalle').first);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await capture(tester, 'detail-compact');
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('nomina-receipt')),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'status and company filters, page size and unpublished receipt guard',
    (tester) async {
      await load(tester);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Revisión RH'));
      await tester.pumpAndSettle();
      expect(snapshot['filtered'], 1);
      expect(snapshot['total'], 120150);
      await tester.tap(find.byTooltip('Ver detalle').first);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('nomina-receipt')))
            .onPressed,
        isNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('80').last);
      await tester.pumpAndSettle();
      expect(snapshot['visible'], 45);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MONROE').last);
      await tester.pumpAndSettle();
      expect(snapshot['filtered'], 19);
      expect(tester.takeException(), isNull);
    },
  );
}
