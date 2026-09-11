import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const period = 'Periodo 37 semanal · 04/09/2026 - 10/09/2026';
final employees = [
  for (final id in ['1', '2'])
    {
      'id': id,
      'nombre': id == '1' ? 'ANA PRUEBA' : 'BETO PRUEBA',
      'empresa': id == '1' ? 'KS' : 'DICSA',
      'salario': 2205.28,
      'salario_flujo': 1000,
    },
];
final drafts = [
  for (final id in ['1', '2'])
    {
      'id': 'draft-$id',
      'employee_id': id,
      'period_label': period,
      'draft_status': 'borrador',
      'fiscal_net_amount': 1800,
      'fiscal_manual_deduction_amount': 50,
      'fiscal_manual_deduction_reason': 'Ajuste autorizado',
      'cash_salary_amount': 1000,
      'cash_salary_is_manual': true,
      'cash_vacation_amount': 100,
      'transport_support_amount': 80,
      'manual_bonus_amount': 120,
      'overtime_monetized_amount': 240,
      'loan_deduction_amount': 100,
      'cash_infonavit_deduction_amount': 70,
      'manual_adjustment_amount': -20,
      'check_amount': 1750,
      'payment_outside_amount': 30,
      'notes': 'Conservar esta nota',
      'source_snapshot': {
        'contpaq_official_net': 1800,
        'incidences_informational': true,
        'fiscal_payment_is_manual': true,
      },
    },
];

void main() {
  setUpAll(() async {
    if (Platform.environment['HR_STATUS_PREVIEW_DIR'] == null) return;
    const fonts =
        '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts';
    for (final pair in [
      ('Ahem', 'Roboto-Regular.ttf'),
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(pair.$1)..addFont(
            File('$fonts/${pair.$2}').readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
  });
  var snapshot = <String, dynamic>{};
  final saved = <Map<String, dynamic>>[];
  final actions = <String>[];
  Future<void> mount(
    WidgetTester tester, {
    bool closed = false,
    String? loanError,
    List<Map<String, dynamic>>? records,
    Future<void> Function(Map<String, dynamic>)? persist,
    Size size = const Size(1700, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    saved.clear();
    actions.clear();
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => RepaintBoundary(
          key: const ValueKey('status-preview'),
          child: child!,
        ),
        home: hrPrenominaGridForTesting(
          period: period,
          employees: employees,
          drafts: records ?? drafts,
          periodClosed: closed,
          loanLoadError: loanError,
          useStatusActions: true,
          onPersistDraft: (payload) async {
            await persist?.call(payload);
            saved.add(payload);
          },
          onSnapshot: (value) => snapshot = value,
          onAction: actions.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder status(String id) => find.byKey(ValueKey('prenomina-status-$id'));
  Finder option(String value) =>
      find.byKey(ValueKey('prenomina-status-option-$value'));
  Future<void> open(WidgetTester tester, [String id = '1']) async {
    await tester.ensureVisible(status(id));
    await tester.pumpAndSettle();
    await tester.tap(status(id));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String value) async {
    await open(tester);
    await tester.tap(option(value));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final directory = Platform.environment['HR_STATUS_PREVIEW_DIR'];
    if (directory == null) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('status-preview')),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'all inline statuses persist without altering money or opening detail',
    (tester) async {
      await mount(tester);
      final totals = {
        for (final key in ['fiscal', 'deposit', 'cheque', 'flow', 'total'])
          key: snapshot[key],
      };
      for (final value in ['revisionRh', 'listo', 'borrador']) {
        await choose(tester, value);
        expect(
          saved.last['draft_status'],
          value == 'revisionRh' ? 'revision_rh' : value,
        );
        expect(find.byKey(const ValueKey('picker-Estatus')), findsNothing);
        for (final key in totals.keys) {
          expect(snapshot[key], totals[key], reason: key);
        }
        for (final key in [
          'fiscal_net_amount',
          'fiscal_manual_deduction_amount',
          'fiscal_manual_deduction_reason',
          'cash_salary_amount',
          'cash_salary_is_manual',
          'cash_vacation_amount',
          'transport_support_amount',
          'manual_bonus_amount',
          'overtime_monetized_amount',
          'loan_deduction_amount',
          'cash_infonavit_deduction_amount',
          'manual_adjustment_amount',
          'check_amount',
          'payment_outside_amount',
          'notes',
        ]) {
          expect(saved.last[key], drafts.first[key], reason: key);
        }
        expect(saved.last['period_label'], period);
        expect(saved.last['employee_id'], '1');
        expect(snapshot['statuses']['2'], 'Borrador');
      }
      expect(saved, hasLength(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'publication requires confirmation and preserves filter on cancel and save',
    (tester) async {
      await mount(tester);
      await tester.enterText(
        find.byKey(const ValueKey('employee-search')),
        'ANA',
      );
      await tester.pumpAndSettle();
      await choose(tester, 'publicado');
      expect(find.text('Publicar cierre semanal'), findsOneWidget);
      expect(saved, isEmpty);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      expect(snapshot['statuses']['1'], 'Borrador');
      await choose(tester, 'publicado');
      await tester.tap(find.text('Publicar cierre'));
      await tester.pumpAndSettle();
      expect(saved.single['draft_status'], 'publicado');
      expect(snapshot['statuses']['1'], 'Publicado');
      expect(snapshot['visible_ids'], ['1']);
      await choose(tester, 'publicado');
      expect(saved, hasLength(1));
      expect(find.text('Publicar cierre semanal'), findsNothing);
    },
  );

  testWidgets(
    'closed period disables status and new drafts can be saved from grid',
    (tester) async {
      await mount(tester, closed: true);
      await open(tester);
      expect(option('publicado'), findsNothing);
      expect(saved, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await mount(tester, records: []);
      await choose(tester, 'listo');
      expect(saved.single['employee_id'], '1');
      expect(saved.single['draft_status'], 'listo');
    },
  );

  testWidgets(
    'busy save prevents duplicate actions and failure leaves the status unchanged',
    (tester) async {
      final completer = Completer<void>();
      await mount(tester, persist: (_) => completer.future);
      await open(tester);
      await tester.tap(option('listo'));
      await tester.pumpAndSettle();
      expect(find.text('Guardando'), findsOneWidget);
      await tester.tap(status('2'));
      await tester.pump();
      expect(option('publicado'), findsNothing);
      completer.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      expect(snapshot['statuses']['1'], 'Borrador');
      expect(
        find.textContaining('No se pudo completar el cambio de estado'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'state filter updates after inline save and the grid stays editable',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Borrador').first);
      await tester.pumpAndSettle();
      expect(snapshot['count'], 2);
      await choose(tester, 'listo');
      expect(snapshot['visible_ids'], ['2']);
      expect(snapshot['statuses']['1'], 'Listo');
      await open(tester, '2');
      await tester.tap(option('revisionRh'));
      await tester.pumpAndSettle();
      expect(snapshot['count'], 0);
      expect(saved, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'status change retains money validation and loan load protection',
    (tester) async {
      await mount(
        tester,
        records: [
          {...drafts.first, 'fiscal_manual_deduction_reason': ''},
        ],
      );
      await choose(tester, 'publicado');
      expect(saved, isEmpty);
      expect(
        find.textContaining('Indica el motivo del descuento fiscal manual'),
        findsOneWidget,
      );
      expect(find.text('Publicar cierre semanal'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await mount(tester, loanError: 'No se pudieron cargar los préstamos.');
      await choose(tester, 'listo');
      expect(saved, isEmpty);
      expect(find.text('No se pudieron cargar los préstamos.'), findsOneWidget);
    },
  );

  testWidgets('Enter on the status column opens its picker and Space selects', (
    tester,
  ) async {
    await mount(tester);
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    for (var i = 0; i < 9; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(option('listo'), findsOneWidget);
    expect(find.byKey(const ValueKey('section-resumen')), findsNothing);
    await capture(tester, 'status-desktop');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(saved.single['draft_status'], 'revision_rh');
  });

  testWidgets(
    'menu fits compact grid and supports keyboard selection and escape',
    (tester) async {
      await mount(tester, size: const Size(1100, 800));
      await open(tester);
      await capture(tester, 'status-compact');
      for (final value in ['borrador', 'revisionRh', 'listo', 'publicado']) {
        expect(option(value), findsOneWidget);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(option('publicado'), findsNothing);
      expect(saved, isEmpty);
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(saved.single['draft_status'], 'revision_rh');
      expect(tester.takeException(), isNull);
    },
  );
}
