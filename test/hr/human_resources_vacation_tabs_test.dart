import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:dicsa_operacion/app/hr/human_resources_vacations_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const may = 'Periodo 19 semanal · 01/05/2026 - 07/05/2026';
const august = 'Periodo 35 semanal · 21/08/2026 - 27/08/2026';
const paymentId = '00000000-0000-4000-8000-000000000001';
const enjoymentId = '00000000-0000-4000-8000-000000000002';
Map<String, dynamic> payment() => {
  'id': paymentId,
  'employee_id': '8',
  'event_type': 'vacaciones_pagadas',
  'status': 'aplicado',
  'start_date': '2026-05-01',
  'end_date': '2026-05-01',
  'days_applied': 12,
  'additional_paid_days': 2,
  'attendance_period_label': may,
  'impact_attendance': false,
  'impact_prenomina': true,
  'prenomina_sync_status': 'pendiente',
};
Map<String, dynamic> enjoyment() => {
  'id': enjoymentId,
  'employee_id': '8',
  'event_type': 'vacaciones_disfrutadas',
  'status': 'aplicado',
  'start_date': '2026-08-24',
  'end_date': '2026-08-26',
  'days_applied': 3,
  'additional_paid_days': 0,
  'attendance_period_label': august,
  'impact_attendance': true,
  'impact_prenomina': true,
  'prenomina_sync_status': 'pendiente',
};

Future<void> preview(WidgetTester tester, String name) async {
  if (Platform.environment['VACATION_PREVIEW'] != '1') return;
  await tester.runAsync(() async {
    final image = await tester
        .renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('preview')),
        )
        .toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '/private/tmp/dicsa_vacation_tabs/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (Platform.environment['VACATION_PREVIEW'] != '1') return;
    for (final font in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final file = File(
        '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/${font.$2}',
      );
      await (FontLoader(
        font.$1,
      )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  test(
    'reload keeps paid days, Sundays and payment period; enjoyment is not payment',
    () {
      final paid = hrVacationReloadForTesting(payment());
      expect(paid['days'], 12);
      expect(paid['extra'], 2);
      expect(paid['period'], may);
      expect(paid['paid'], 12);
      expect(paid['enjoyed'], 0);
      expect(paid['payroll_payment'], true);
      final enjoyed = hrVacationReloadForTesting(enjoyment());
      expect(enjoyed['paid'], 0);
      expect(enjoyed['enjoyed'], 3);
      expect(enjoyed['payroll_payment'], false);
    },
  );
  testWidgets(
    'separate tabs retain edits and saving does not sum paid and enjoyed days',
    (tester) async {
      tester.view.physicalSize = const Size(1555, 1012);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) =>
              RepaintBoundary(key: const ValueKey('preview'), child: child!),
          home: Scaffold(
            body: hrVacationTabsForTesting(
              events: [payment(), enjoyment()],
              periods: [may, august],
              onSave: (v) => saved = v,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir expediente'));
      await tester.pumpAndSettle();
      final days = find.byKey(const ValueKey('vacation-days-$paymentId'));
      await tester.ensureVisible(days);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('vacation-days-$enjoymentId')),
        findsNothing,
      );
      await preview(tester, 'payments');
      await tester.enterText(days, '10');
      await tester.pumpAndSettle();
      final extra = find.byKey(
        const ValueKey('vacation-extra-days-$paymentId'),
      );
      await tester.ensureVisible(extra);
      await tester.pumpAndSettle();
      await tester.enterText(extra, '0');
      await tester.pumpAndSettle();
      final tabs = find.byType(SegmentedButton<bool>);
      await tester.ensureVisible(tabs);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: tabs, matching: find.text('Eventos')),
      );
      await tester.pumpAndSettle();
      expect(days, findsNothing);
      expect(
        find.byKey(const ValueKey('vacation-extra-days-$enjoymentId')),
        findsNothing,
      );
      final enjoymentDays = find.byKey(
        const ValueKey('vacation-days-$enjoymentId'),
      );
      await tester.ensureVisible(enjoymentDays);
      await tester.pumpAndSettle();
      await preview(tester, 'events');
      await tester.enterText(enjoymentDays, '2');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar vacaciones'));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!['paid'], 10);
      expect(saved!['enjoyed'], 2);
      final rows = (saved!['events'] as List).cast<Map<String, dynamic>>();
      final paid = hrVacationReloadForTesting(rows.first);
      expect(paid['days'], 10);
      expect(paid['extra'], 0);
      expect(paid['period'], may);
      expect(hrVacationReloadForTesting(rows.last)['days'], 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'receipt action keeps payment period and locked payments cannot receive focus',
    (tester) async {
      tester.view.physicalSize = const Size(1555, 1012);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) =>
              RepaintBoundary(key: const ValueKey('preview'), child: child!),
          home: Scaffold(
            body: hrVacationTabsForTesting(
              events: [
                {...payment(), 'prenomina_sync_status': 'aplicado'},
                enjoyment(),
              ],
              periods: [may, august],
              onSave: (v) => saved = v,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir expediente'));
      await tester.pumpAndSettle();
      final receipt = find.byKey(const ValueKey('vacation-receipt-$paymentId'));
      await tester.ensureVisible(receipt);
      await tester.pumpAndSettle();
      final days = find.byKey(const ValueKey('vacation-days-$paymentId'));
      final focus = find.ancestor(
        of: days,
        matching: find.byWidgetPredicate(
          (w) => w is ExcludeFocus && w.excluding,
        ),
      );
      expect(focus, findsWidgets);
      await tester.tap(receipt);
      await tester.pumpAndSettle();
      expect(saved!['action'], 'receipt');
      expect((saved!['events'] as List).first['attendance_period_label'], may);
      expect((saved!['events'] as List).first['days_applied'], 12);
    },
  );
}
