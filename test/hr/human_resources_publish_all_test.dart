import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const period = 'Periodo 37 semanal · 04/09/2026 - 10/09/2026';
Map<String, dynamic> employee(int id) => {
  'id': '$id',
  'nombre': 'COLABORADOR $id',
  'empresa': id.isEven ? 'DICSA' : 'KS',
  'salario': 2205.28,
  'salario_flujo': 1000,
};
Map<String, dynamic> draft(int id, [String status = 'borrador']) => {
  'id': 'draft-$id',
  'employee_id': '$id',
  'period_label': period,
  'draft_status': status,
  'fiscal_net_amount': 1800,
  'fiscal_manual_deduction_amount': 50,
  'fiscal_manual_deduction_reason': 'Ajuste autorizado',
  'cash_salary_amount': 1000,
  'cash_salary_is_manual': true,
  'manual_bonus_amount': 120,
  'loan_deduction_amount': 100,
  'check_amount': 1750,
  'notes': 'Nota de RH $id',
  'source_snapshot': {
    'contpaq_official_net': 1800,
    'incidences_informational': true,
    'fiscal_payment_is_manual': true,
  },
};

void main() {
  setUpAll(() async {
    if (Platform.environment['HR_PUBLISH_PREVIEW_DIR'] == null) return;
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
  Future<void> mount(
    WidgetTester tester, {
    int count = 3,
    List<Map<String, dynamic>>? records,
    String? loanError,
    bool closed = false,
    Future<void> Function(Map<String, dynamic>)? beforeSave,
    Future<void> Function(Map<String, dynamic>)? afterSave,
    Size size = const Size(1700, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    saved.clear();
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => RepaintBoundary(
          key: const ValueKey('publication-preview'),
          child: child!,
        ),
        home: hrPrenominaGridForTesting(
          period: period,
          employees: [for (var id = 1; id <= count; id++) employee(id)],
          drafts: records ?? [for (var id = 1; id <= count; id++) draft(id)],
          periodClosed: closed,
          loanLoadError: loanError,
          useStatusActions: true,
          useClosureReview: true,
          onPersistDraft: (payload) async {
            await beforeSave?.call(payload);
            saved.add(payload);
          },
          onAfterPersistDraft: afterSave,
          onSnapshot: (value) => snapshot = value,
          onAction: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('publish-all')));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('confirm-publish-all')));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final directory = Platform.environment['HR_PUBLISH_PREVIEW_DIR'];
    if (directory == null) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('publication-preview')),
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
    'one confirmation publishes the entire period across filters and pages',
    (tester) async {
      await mount(
        tester,
        count: 45,
        records: [
          for (var id = 1; id < 45; id++)
            draft(
              id,
              id == 2
                  ? 'publicado'
                  : id % 3 == 0
                  ? 'listo'
                  : id % 3 == 1
                  ? 'borrador'
                  : 'revision_rh',
            ),
        ],
      );
      final totals = {
        for (final key in ['fiscal', 'deposit', 'cheque', 'flow', 'total'])
          key: snapshot[key],
      };
      expect(snapshot['visible_ids'], hasLength(40));
      await tester.enterText(
        find.byKey(const ValueKey('employee-search')),
        'SIN COINCIDENCIAS',
      );
      await tester.pumpAndSettle();
      expect(snapshot['count'], 0);
      await open(tester);
      expect(
        find.textContaining('Se publicarán 44 colaboradores'),
        findsOneWidget,
      );
      expect(
        find.textContaining('1 ya publicados se conservarán'),
        findsOneWidget,
      );
      await capture(tester, 'publish-all-desktop');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      await open(tester);
      await confirm(tester);
      expect(find.text('Publicación completada'), findsOneWidget);
      expect(saved, hasLength(44));
      expect(saved.any((row) => row['employee_id'] == '2'), isFalse);
      expect(saved.any((row) => row['employee_id'] == '45'), isTrue);
      for (final payload in saved) {
        expect(payload['period_label'], period);
        expect(payload['draft_status'], 'publicado');
        if (payload['employee_id'] == '45') continue;
        for (final key in [
          'fiscal_net_amount',
          'fiscal_manual_deduction_amount',
          'fiscal_manual_deduction_reason',
          'cash_salary_amount',
          'cash_salary_is_manual',
          'manual_bonus_amount',
          'loan_deduction_amount',
          'check_amount',
          'notes',
        ]) {
          expect(
            payload[key],
            draft(int.parse(payload['employee_id']))[key],
            reason: key,
          );
        }
      }
      expect((snapshot['statuses'] as Map).values.toSet(), {'Publicado'});
      expect(snapshot['count'], 0);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('employee-search')), '');
      await tester.pumpAndSettle();
      for (final key in totals.keys) {
        expect(snapshot[key], totals[key], reason: key);
      }
      expect(find.text('Cerrar periodo'), findsOneWidget);
      await open(tester);
      expect(
        find.text('Todos los colaboradores del periodo ya están publicados.'),
        findsOneWidget,
      );
      expect(saved, hasLength(44));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'validates all candidates before saving and explains employee errors',
    (tester) async {
      await mount(
        tester,
        records: [
          draft(1),
          {...draft(2), 'fiscal_manual_deduction_reason': ''},
          draft(3),
        ],
      );
      await open(tester);
      expect(find.text('Revisa estos colaboradores'), findsOneWidget);
      expect(
        find.textContaining('COLABORADOR 2 · ID 2 · DICSA'),
        findsOneWidget,
      );
      expect(find.textContaining('Indica el motivo'), findsOneWidget);
      expect(saved, isEmpty);
      expect(find.byKey(const ValueKey('confirm-publish-all')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await mount(tester, loanError: 'Préstamos no disponibles');
      await open(tester);
      expect(find.text('Préstamos no disponibles'), findsOneWidget);
      expect(saved, isEmpty);
    },
  );

  testWidgets(
    'partial failure retries even a row whose upsert already succeeded',
    (tester) async {
      var fail = true;
      final gate = Completer<void>();
      await mount(
        tester,
        beforeSave: (_) => gate.future,
        afterSave: (payload) async {
          if (payload['employee_id'] == '2' && fail) {
            throw StateError('event settlement failed');
          }
        },
      );
      await open(tester);
      await confirm(tester);
      expect(find.text('Publicando prenómina'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Publicando prenómina'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Publicación con pendientes'), findsOneWidget);
      expect(
        find.textContaining('2 colaboradores publicados.'),
        findsOneWidget,
      );
      expect(find.text('COLABORADOR 2 · ID 2 · DICSA'), findsOneWidget);
      expect(saved, hasLength(3));
      expect((snapshot['statuses'] as Map).values.toSet(), {'Publicado'});
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar periodo'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'completar las publicaciones pendientes antes de cerrar',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      fail = false;
      await open(tester);
      expect(
        find.textContaining('Se publicarán 1 colaboradores'),
        findsOneWidget,
      );
      await confirm(tester);
      expect(saved, hasLength(4));
      expect(saved.last['employee_id'], '2');
      expect(find.text('Publicación completada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closed and empty periods disable publishing', (tester) async {
    await mount(tester, closed: true);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('publish-all')))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    await mount(tester, count: 0);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('publish-all')))
          .onPressed,
      isNull,
    );
    expect(saved, isEmpty);
  });

  testWidgets('compact confirmation can be dismissed with Escape', (
    tester,
  ) async {
    await mount(tester, size: const Size(1000, 760));
    await open(tester);
    await capture(tester, 'publish-all-compact');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('confirm-publish-all')), findsNothing);
    expect(saved, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
