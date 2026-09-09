import 'dart:io';
import 'dart:ui' as ui;
import 'package:dicsa_operacion/app/hr/human_resources_personnel_page.dart';
import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final path = Platform.environment['DICSA_COMPENSATION_FONT_PATH'];
    if (path != null) {
      await (FontLoader('Roboto')..addFont(
            File(
              path,
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          ))
          .load();
    }
  });
  testWidgets(
    'Personal changes base, flow, cheque and rate; saved values reopen',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic> employee = {
        'salario': 2205.28,
        'salario_flujo': 2694.72,
      };
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: const ValueKey('capture'),
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    saved = await hrPersonnelCompensationEditorForTesting(
                      context,
                      employee: employee,
                    );
                  },
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      final base = find.byKey(const ValueKey('personalSalaryBase'));
      final flow = find.byKey(const ValueKey('personalSalaryFlow'));
      await tester.ensureVisible(base);
      await tester.enterText(base, '2205.28');
      await tester.enterText(flow, '3009.76');
      await tester.pump();
      expect(find.text(r'$5215.04'), findsOneWidget);
      // Backspace edits salary text; it must not close or delete the employee.
      await tester.enterText(flow, '0');
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.enterText(flow, '0');
      await tester.pump();
      expect(find.text(r'$2205.28'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('personalFiscalCheck')),
      );
      await tester.tap(find.byKey(const ValueKey('personalFiscalCheck')));
      await tester.ensureVisible(
        find.byKey(const ValueKey('personalOvertimeRate')),
      );
      await tester.tap(find.byKey(const ValueKey('personalOvertimeRate')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(r'$80 por hora').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Guardar expediente'));
      await tester.pumpAndSettle();
      expect(saved, {
        'salario': 2205.28,
        'salario_flujo': 0.0,
        'salario_real_percibido': 2205.28,
        'fiscal_payment_mode': 'cheque',
        'overtime_hourly_rate': 80.0,
      });
      employee = saved!;
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(flow);
      expect(tester.widget<TextFormField>(flow).controller!.text, '0.00');
      expect(find.text('Cheque · fiscal en efectivo'), findsOneWidget);
      expect(find.text(r'$80 por hora'), findsOneWidget);
      expect(find.text(r'$2205.28'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('personalOvertimeRate')),
      );
      await tester.pumpAndSettle();
      final imagePath = Platform.environment['DICSA_COMPENSATION_PREVIEW'];
      if (imagePath != null) {
        await tester.runAsync(() async {
          // The dialog is in the overlay, so capture the entire render view.
          final layer =
              tester.binding.renderViews.first.debugLayer! as OffsetLayer;
          final image = await layer.toImage(
            const Rect.fromLTWH(0, 0, 1600, 1200),
          );
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(imagePath).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );

  testWidgets('editing flow to zero in Prenomina persists on reopen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const period = 'Periodo 35 semanal · 21/08/2026 - 27/08/2026';
    Map<String, dynamic>? draft;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await hrPrenominaEditorForTesting(
                  period: period,
                  employee: {
                    'id': 'test',
                    'nombre': 'PRUEBA',
                    'salario': 2205.28,
                    'salario_flujo': 2694.72,
                  },
                  storedDraft: draft,
                ).open(context);
                if (result != null) {
                  draft = Map<String, dynamic>.from(result['payload'] as Map);
                }
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    final flow = find.byKey(const ValueKey('cashSalaryAmount'));
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('section-percepciones')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(flow);
      if (i == 0) {
        await tester.enterText(flow, '0');
      } else {
        expect(tester.widget<TextFormField>(flow).initialValue, '0.00');
      }
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(draft!['cash_salary_is_manual'], true);
      expect(draft!['cash_salary_amount'], 0);
      expect(tester.takeException(), isNull);
    }
  });
}
