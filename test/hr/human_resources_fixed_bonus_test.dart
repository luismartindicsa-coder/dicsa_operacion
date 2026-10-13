import 'dart:io';
import 'dart:ui' as ui;
import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'human_resources_cash_envelopes_test.dart' show readEnvelopeXlsx;

const p1 = 'Periodo 37 semanal · 04/09/2026 - 10/09/2026';
const p2 = 'Periodo 38 semanal · 11/09/2026 - 17/09/2026';
const p3 = 'Periodo 39 semanal · 18/09/2026 - 24/09/2026';
const p4 = 'Periodo 40 semanal · 25/09/2026 - 01/10/2026';
const employee = {
  'id': '1',
  'nombre': 'COLABORADOR UNO',
  'empresa': 'DICSA',
  'salario': 2000,
  'salario_flujo': 1000,
  'employment_status': 'activo',
};
const fixedKey = 'manual_bonus_fixed';

Map<String, dynamic> draft(
  String period,
  num amount, {
  bool? fixed = true,
  String id = '1',
}) => {
  'period_label': period,
  'employee_id': id,
  'manual_bonus_amount': amount,
  'draft_status': 'borrador',
  'source_snapshot': {fixedKey: ?fixed},
};
Map<String, dynamic> project(
  String period,
  List<Map<String, dynamic>> drafts, {
  bool closed = false,
}) => hrPrenominaPeriodProjectionForTesting(
  period: period,
  employees: [employee],
  drafts: drafts,
  freezeLoanPlans: closed,
).single;
Map<String, dynamic> payload(
  String period,
  List<Map<String, dynamic>> drafts, {
  bool closed = false,
}) => Map<String, dynamic>.from(
  project(period, drafts, closed: closed)['payload'],
);

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('HR_BONUS_PREVIEW')) return;
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '/private/tmp/dicsa_prenomina_bonus/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void size(WidgetTester tester, [Size value = const Size(1440, 960)]) {
  tester.view.physicalSize = value;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('HR_BONUS_PREVIEW')) return;
    final font = File(
      '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    ).readAsBytesSync();
    for (final name in ['Ahem', 'Roboto']) {
      await (FontLoader(
        name,
      )..addFont(Future.value(ByteData.sublistView(font)))).load();
    }
    final icons = File(
      '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
  });

  test(
    'ordinary bonuses do not repeat; fixed 200 is inherited once in a new period',
    () {
      expect(
        payload(p2, [draft(p1, 200, fixed: null)])['manual_bonus_amount'],
        isNull,
      );
      final next = payload(p2, [draft(p1, 200)]);
      expect(next['manual_bonus_amount'], 200);
      expect(next['source_snapshot'][fixedKey], true);
      expect(
        project(p2, [draft(p1, 200)])['total'],
        project(p2, [])['total'] + 200,
      );
      expect(payload(p2, [draft(p1, 200), next])['manual_bonus_amount'], 200);
    },
  );
  test(
    'editing the fixed 200 to 180 becomes the next default and survives repeated saves',
    () {
      final first = draft(p1, 200);
      var second = {
        ...payload(p2, [first]),
        'manual_bonus_amount': 180,
      };
      for (var i = 0; i < 3; i++) {
        second = payload(p2, [first, second]);
      }
      expect(second['manual_bonus_amount'], 180);
      final third = payload(p3, [second, first]);
      expect(third['manual_bonus_amount'], 180);
      expect(payload(p4, [third, first, second])['manual_bonus_amount'], 180);
    },
  );
  test(
    'turning off preserves this period amount and stops repetition across gaps',
    () {
      final first = draft(p1, 200), second = draft(p2, 180, fixed: false);
      expect(payload(p2, [first, second])['manual_bonus_amount'], 180);
      expect(payload(p3, [first, second])['manual_bonus_amount'], isNull);
      expect(payload(p4, [first, second])['manual_bonus_amount'], isNull);
      expect(payload(p4, [first, second])['source_snapshot'][fixedKey], false);
    },
  );
  test(
    'zero stays fixed at zero and is not replaced by an older nonzero bonus',
    () {
      final next = payload(p3, [draft(p1, 200), draft(p2, 0)]);
      expect(next['manual_bonus_amount'], isNull);
      expect(next['source_snapshot'][fixedKey], true);
    },
  );
  test(
    'existing, published and closed amounts remain unchanged; future periods do not backfill the past',
    () {
      expect(payload(p1, [draft(p2, 180)])['manual_bonus_amount'], isNull);
      final old = draft(p1, 200), saved = draft(p2, 50, fixed: null);
      expect(payload(p2, [old, saved])['manual_bonus_amount'], 50);
      expect(
        payload(p2, [old, draft(p2, 0, fixed: null)])['manual_bonus_amount'],
        isNull,
      );
      expect(
        payload(p2, [
          old,
          {...saved, 'draft_status': 'publicado'},
        ])['manual_bonus_amount'],
        50,
      );
      expect(payload(p2, [old], closed: true)['manual_bonus_amount'], isNull);
      expect(
        payload('Periodo sin fechas', [old])['manual_bonus_amount'],
        isNull,
      );
    },
  );
  test(
    'recurrence uses employee identity and actual date order across years',
    () {
      const december = 'Periodo 52 semanal · 25/12/2026 - 31/12/2026';
      const january = 'Periodo 1 semanal · 01/01/2027 - 07/01/2027';
      expect(
        payload(january, [
          draft(december, 180),
          draft(p1, 200),
        ])['manual_bonus_amount'],
        180,
      );
      expect(
        payload(p2, [draft(p1, 999, id: '2')])['manual_bonus_amount'],
        isNull,
      );
      final changedCompany = hrPrenominaPeriodProjectionForTesting(
        period: p2,
        employees: [
          {...employee, 'empresa': 'KS'},
        ],
        drafts: [draft(p1, 200)],
      ).single;
      expect(changedCompany['payload']['manual_bonus_amount'], 200);
    },
  );

  testWidgets(
    'pin is next to Bonos, editable, saved with the amount, and cancellable',
    (tester) async {
      size(tester);
      final boundary = GlobalKey();
      Map<String, dynamic>? saved;
      final editor = hrPrenominaEditorForTesting(
        period: p2,
        employee: employee,
        priorDrafts: [draft(p1, 200)],
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Abrir'),
                  onPressed: () async {
                    saved = await editor.open(context);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('section-percepciones')));
      await tester.pumpAndSettle();
      final bonus = find.byKey(const ValueKey('manualBonusAmount'));
      final pin = find.byKey(const ValueKey('fixed-bonus-toggle'));
      await tester.ensureVisible(pin);
      expect(tester.widget<IconButton>(pin).isSelected, true);
      expect(tester.widget<TextFormField>(bonus).initialValue, '200.00');
      await tester.enterText(bonus, '180');
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(pin).isSelected, true);
      await tester.tap(pin);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(pin).isSelected, false);
      await tester.tap(pin);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(pin).isSelected, true);
      await capture(tester, boundary, 'fixed_bonus');
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(saved!['payload']['manual_bonus_amount'], 180);
      expect(saved!['payload']['source_snapshot'][fixedKey], true);
      expect(
        payload(p3, [
          draft(p1, 200),
          Map<String, dynamic>.from(saved!['payload']),
        ])['manual_bonus_amount'],
        180,
      );
      saved = null;
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('section-percepciones')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(pin);
      await tester.tap(pin);
      await tester.pump();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'several companies combine with search; selection survives reopening and Escape; clear restores all',
    (tester) async {
      size(tester);
      final boundary = GlobalKey();
      var snapshot = <String, dynamic>{};
      Uint8List? exported;
      final companies = ['DICSA', 'KS', 'MONROE'];
      final employees = <Map<String, dynamic>>[
        for (var i = 0; i < 6; i++)
          {
            ...employee,
            'id': '${i + 1}',
            'nombre': 'PERSONA ${i + 1}',
            'empresa': companies[i % 3],
          },
      ];
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: hrPrenominaGridForTesting(
              period: p2,
              employees: employees,
              drafts: const [],
              onSnapshot: (value) => snapshot = value,
              onAction: (_) {},
              onExportBytes: (bytes) => exported = bytes,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Todas las empresas'));
      await tester.tap(find.text('Todas las empresas'));
      await tester.pumpAndSettle();
      final search = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      final editable = tester.widget<EditableText>(
        find.descendant(of: search, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('2 seleccionados'), findsOneWidget);
      await capture(tester, boundary, 'company_filter');
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(snapshot['visible_ids'], ['1', '2', '4', '5']);
      expect(snapshot['count'], 4);
      expect(snapshot['flow'], 4000);
      await tester.tap(find.text('Exportar sobres'));
      await tester.pumpAndSettle();
      expect(readEnvelopeXlsx(exported!).skip(1).map((r) => r.first), [
        '1',
        '2',
        '4',
        '5',
      ]);
      await tester.enterText(
        find.byKey(const ValueKey('employee-search')),
        'PERSONA 4',
      );
      await tester.pumpAndSettle();
      expect(snapshot['visible_ids'], ['4']);
      await tester.enterText(find.byKey(const ValueKey('employee-search')), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('DICSA, KS'));
      await tester.pumpAndSettle();
      expect(find.text('2 seleccionados'), findsOneWidget);
      await tester.tap(find.text('MONROE').last);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(snapshot['count'], 4);
      await tester.tap(find.text('DICSA, KS'));
      await tester.pumpAndSettle();
      await tester.enterText(search, 'MON');
      await tester.pumpAndSettle();
      await tester.tap(find.text('MONROE').last);
      await tester.pump();
      expect(find.text('3 seleccionados'), findsOneWidget);
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(snapshot['count'], 6);
      await tester.ensureVisible(find.text('Limpiar'));
      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();
      expect(find.text('Todas las empresas'), findsOneWidget);
      expect(snapshot['count'], 6);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switching directly from a closed period loads the next fixed bonus immediately',
    (tester) async {
      size(tester);
      SharedPreferences.setMockInitialValues({});
      var snapshot = <String, dynamic>{};
      await tester.pumpWidget(
        MaterialApp(
          home: hrPrenominaGridForTesting(
            period: p1,
            otherPeriods: [p2],
            periodClosed: true,
            employees: [employee],
            drafts: [
              {...draft(p1, 200), 'draft_status': 'publicado'},
            ],
            onSnapshot: (value) => snapshot = value,
            onAction: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(p1));
      await tester.pumpAndSettle();
      await tester.tap(find.text(p2).last);
      await tester.pumpAndSettle();
      expect(snapshot['bonuses'], {'1': 200});
      expect(snapshot['flow'], 1200);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing saved drafts blocks publication instead of saving zero bonuses',
    (tester) async {
      size(tester);
      final writes = <Map<String, dynamic>>[];
      const error = 'No se pudieron consultar los borradores y bonos fijos.';
      await tester.pumpWidget(
        MaterialApp(
          home: hrPrenominaGridForTesting(
            period: p2,
            employees: [employee],
            drafts: const [],
            draftLoadError: error,
            onSnapshot: (_) {},
            onAction: (_) {},
            onPersistDraft: (row) async {
              writes.add(row);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publicar todo'));
      await tester.pumpAndSettle();
      expect(find.text(error), findsOneWidget);
      expect(writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bulk publishing inherits each fixed bonus and persists its setting',
    (tester) async {
      size(tester);
      final saved = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: hrPrenominaGridForTesting(
            period: p2,
            employees: [
              employee,
              {
                ...employee,
                'id': '2',
                'nombre': 'COLABORADOR DOS',
                'empresa': 'KS',
              },
            ],
            drafts: [
              draft(p1, 200),
              draft(p1, 180, id: '2'),
            ],
            onSnapshot: (_) {},
            onAction: (_) {},
            onPersistDraft: (row) async {
              saved.add(row);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publicar todo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publicar todo').last);
      await tester.pumpAndSettle();
      expect(saved.length, 2);
      expect(saved.map((p) => p['manual_bonus_amount']), [200, 180]);
      expect(saved.every((p) => p['source_snapshot'][fixedKey] == true), true);
      expect(tester.takeException(), isNull);
    },
  );
}
