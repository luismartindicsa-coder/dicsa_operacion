import 'dart:convert';
import 'dart:io';

import 'package:dicsa_operacion/app/services/inventory_transformation_grid.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final database = <String, List<Map<String, dynamic>>>{};
  final writes = <http.Request>[];
  const runs = 'material_transformation_runs_v2';
  const outputs = 'material_transformation_run_outputs_v2';

  setUpAll(() async {
    await (FontLoader('Roboto')..addFont(
          File(
            'assets/fonts/Roboto-Regular.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://production-test.invalid',
      anonKey: 'test-only-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        final table = request.url.pathSegments.last;
        final rows = database.putIfAbsent(table, () => []);
        bool matches(Map<String, dynamic> row) => request
            .url
            .queryParameters
            .entries
            .where((entry) => entry.value.startsWith('eq.'))
            .every(
              (entry) => row[entry.key]?.toString() == entry.value.substring(3),
            );
        dynamic response;
        if (request.method == 'POST') {
          writes.add(request);
          final row = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          row['id'] = '$table-${rows.length}';
          rows.add(row);
          response = request.headers['accept']?.contains('object') == true
              ? row
              : [row];
        } else if (request.method == 'PATCH') {
          writes.add(request);
          final patch = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          for (final row in rows.where(matches)) {
            row.addAll(patch);
          }
          response = rows.where(matches).toList();
        } else {
          response = [
            for (final row in rows.where(matches))
              {
                ...row,
                if (table == runs)
                  'outputs': database[outputs]!
                      .where((output) => output['run_id'] == row['id'])
                      .toList(),
              },
          ];
        }
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });

  tearDownAll(() => Supabase.instance.dispose());

  setUp(() {
    writes.clear();
    database.clear();
    database.addAll({
      'material_general_catalog_v2': [
        for (final code in ['CARTON', 'PAPEL'])
          {'id': code, 'code': code, 'name': code, 'is_active': true},
      ],
      'material_commercial_catalog_v2': [
        for (final code in ['CARTON', 'PAPEL'])
          {
            'id': 'commercial-$code',
            'code': code == 'CARTON' ? 'PACA_NACIONAL' : 'ARCHIVO',
            'name': code == 'CARTON' ? 'PACA NACIONAL' : 'ARCHIVO',
            'general_material_id': code,
            'is_active': true,
            'tracks_patio_stock': true,
            'allows_transformation_output': true,
          },
      ],
      runs: [],
      outputs: [],
    });
  });

  void seedRow({
    String notes = 'C1',
    String code = 'CARTON',
    String id = 'existing',
  }) {
    database[runs]!.add({
      'id': 'run-$id',
      'op_date': '2026-10-16',
      'shift': 'DAY',
      'source_mode': 'MIXED',
      'source_general_material_id': code,
      'input_weight_kg': 7200,
      'notes': notes,
    });
    database[outputs]!.add({
      'id': 'output-$id',
      'run_id': 'run-$id',
      'commercial_material_id': 'commercial-$code',
      'output_weight_kg': 7000,
      'output_unit_count': 10,
      'notes': notes,
    });
  }

  Future<void> openGrid(WidgetTester tester, {String code = 'CARTON'}) async {
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InventoryTransformationGrid(
            sourceGeneralCode: code,
            title: code,
            metricIcon: Icons.inventory,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Finder field(String hint) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
  );

  void expectWeights(WidgetTester tester, String text, {bool editing = false}) {
    for (final hint in ['Kg salida', 'Consumo']) {
      final widget = tester.widget<TextField>(
        editing ? field(hint).last : field(hint).first,
      );
      expect(widget.readOnly, isTrue);
      expect(widget.controller!.text, text);
    }
  }

  Future<void> chooseCompactor(
    WidgetTester tester,
    String current,
    String choice,
  ) async {
    await tester.tap(find.text(current).last);
    await tester.pumpAndSettle();
    expect(find.text('Selecciona compactadora'), findsOneWidget);
    await tester.tap(find.text(choice).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'recalculates both weights and persists compactor and bale count',
    (tester) async {
      await openGrid(tester);
      expect(find.text('COMPACTADORA'), findsOneWidget);
      expect(field('Comentario / notas'), findsNothing);
      await tester.enterText(field('Pacas'), '10');
      expectWeights(tester, '');
      await chooseCompactor(tester, 'Compactadora', 'COMPACTADORA 1');
      expectWeights(tester, '7500.00');
      await chooseCompactor(tester, 'COMPACTADORA 1', 'COMPACTADORA 2');
      expectWeights(tester, '8500.00');
      await tester.enterText(field('Pacas'), '4');
      expectWeights(tester, '3400.00');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(database[runs]!.single['input_weight_kg'], 3400);
      expect(database[outputs]!.single['output_weight_kg'], 3400);
      expect(database[outputs]!.single['output_unit_count'], 4);
      expect(database[runs]!.single['notes'], 'COMPACTADORA 2');
      expect(database[outputs]!.single['notes'], 'COMPACTADORA 2');
      expectWeights(tester, '');
      expect(find.text('Compactadora'), findsOneWidget);
    },
  );

  testWidgets(
    'rejects missing compactor and invalid bale counts without writes',
    (tester) async {
      await openGrid(tester);
      await tester.enterText(field('Pacas'), '10');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      expect(find.text('Selecciona una compactadora.'), findsOneWidget);
      await chooseCompactor(tester, 'Compactadora', 'COMPACTADORA 1');
      for (final count in ['', '0', '-1', '1.5', 'abc']) {
        await tester.enterText(field('Pacas'), count);
        expectWeights(tester, '');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(writes, isEmpty);
      }
    },
  );

  testWidgets(
    'inline editing recognizes legacy C1 and recalculates on change',
    (tester) async {
      seedRow();
      await openGrid(tester);
      expect(writes, isEmpty);
      expect(find.text('7000.00 kg'), findsOneWidget);
      await tester.tap(find.text('10'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();
      expect(find.text('ACTUALIZAR'), findsOneWidget);
      expectWeights(tester, '7500.00', editing: true);
      await tester.enterText(field('Pacas').last, '3');
      expectWeights(tester, '2250.00', editing: true);
      await chooseCompactor(tester, 'COMPACTADORA 1', 'COMPACTADORA 2');
      expectWeights(tester, '2550.00', editing: true);
      await tester.tap(find.text('ACTUALIZAR'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(database[runs]!.single['input_weight_kg'], 2550);
      expect(database[outputs]!.single['output_weight_kg'], 2550);
      expect(database[outputs]!.single['output_unit_count'], 3);
      expect(database[outputs]!.single['notes'], 'COMPACTADORA 2');
    },
  );

  testWidgets(
    'dialog editing requires choosing a compactor for old free text',
    (tester) async {
      seedRow(notes: 'REGISTRO ANTERIOR');
      await openGrid(tester);
      await tester.tap(
        find.text('REGISTRO ANTERIOR'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('EDITAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      expect(find.text('Editar transformación'), findsOneWidget);
      await tester.tap(find.text('Compactadora').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('COMPACTADORA 1').last);
      await tester.pumpAndSettle();
      final bales = find.widgetWithText(TextField, 'Pacas contadas');
      await tester.enterText(bales, '2');
      for (final label in ['Kg salida', 'Consumo kg']) {
        final field = tester.widget<TextField>(
          find.widgetWithText(TextField, label).last,
        );
        expect(field.controller!.text, '1500.00');
        expect(field.readOnly, isTrue);
      }
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Editar transformación'), findsNothing);
      expect(database[runs]!.single['input_weight_kg'], 1500);
      expect(database[outputs]!.single['output_weight_kg'], 1500);
      expect(database[outputs]!.single['notes'], 'COMPACTADORA 1');
    },
  );

  testWidgets(
    'compactor picker works with keyboard and Escape preserves draft',
    (tester) async {
      await openGrid(tester);
      await tester.tap(field('Pacas'));
      await tester.enterText(field('Pacas'), '2');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('Selecciona compactadora'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('Buscar')).focusNode!.hasFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expectWeights(tester, '1700.00');
      await tester.tap(find.text('COMPACTADORA 2'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expectWeights(tester, '1700.00');
      expect(writes, isEmpty);
    },
  );

  testWidgets(
    'invalid inline edits stay open and Escape restores saved values',
    (tester) async {
      seedRow(notes: 'compactadora 2');
      await openGrid(tester);
      await tester.tap(find.text('10'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();
      expectWeights(tester, '8500.00', editing: true);
      await tester.enterText(field('Pacas').last, '0');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('ACTUALIZAR'), findsOneWidget);
      expect(writes, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('ACTUALIZAR'), findsNothing);
      expect(find.text('7000.00 kg'), findsOneWidget);
      expect(find.text('7200.00 kg'), findsOneWidget);
      expect(writes, isEmpty);
    },
  );

  testWidgets('other material families keep manual weights and comments', (
    tester,
  ) async {
    await openGrid(tester, code: 'PAPEL');
    expect(find.text('COMENTARIO'), findsOneWidget);
    expect(tester.widget<TextField>(field('Kg salida')).readOnly, isFalse);
    expect(tester.widget<TextField>(field('Consumo')).readOnly, isFalse);
    await tester.enterText(field('Kg salida'), '1000');
    await tester.enterText(field('Comentario / notas'), 'CLASIFICACIÓN');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(database[runs]!.single['input_weight_kg'], 1000);
    expect(database[outputs]!.single['output_weight_kg'], 1000);
    expect(database[runs]!.single['notes'], 'CLASIFICACIÓN');
  });

  for (final code in ['CARTON', 'PAPEL']) {
    testWidgets('Delete and Backspace edit $code cells without deleting rows', (
      tester,
    ) async {
      seedRow(code: code);
      await openGrid(tester, code: code);
      await tester.tap(find.text('10'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();

      final inputs = {
        code == 'CARTON' ? 'Pacas' : 'Unidades': '123',
        if (code == 'PAPEL') ...{
          'Kg salida': '456',
          'Consumo': '789',
          'Comentario / notas': 'ABC123',
        },
      };
      for (final input in inputs.entries) {
        final target = field(input.key).last;
        await tester.tap(target);
        await tester.enterText(target, input.value);
        final controller = tester.widget<TextField>(target).controller!;
        controller.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          controller.text,
          input.value.substring(0, input.value.length - 1),
        );

        controller.selection = const TextSelection.collapsed(offset: 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          controller.text,
          input.value.substring(1, input.value.length - 1),
        );

        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.pumpAndSettle();
        expect(controller.text, isEmpty);
        for (final key in [
          LogicalKeyboardKey.backspace,
          LogicalKeyboardKey.delete,
        ]) {
          await tester.sendKeyEvent(key);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
        }
      }
      expect(find.text('ACTUALIZAR'), findsOneWidget);
      expect(writes, isEmpty);
      expect(database[runs], hasLength(1));
    });
  }

  testWidgets('Delete and Backspace edit text during multiple row editing', (
    tester,
  ) async {
    seedRow(code: 'PAPEL', notes: 'PRIMERA');
    seedRow(code: 'PAPEL', notes: 'SEGUNDA', id: 'second');
    await openGrid(tester, code: 'PAPEL');
    final selection = await tester.startGesture(
      tester.getCenter(find.text('PRIMERA')),
      kind: PointerDeviceKind.mouse,
    );
    await selection.moveTo(tester.getCenter(find.text('SEGUNDA')));
    await selection.up();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('ACTUALIZAR'), findsNWidgets(2));

    // Focus the first row while the second remains the active selected row.
    final target = field('Comentario / notas').at(1);
    await tester.enterText(target, 'ABC123');
    final controller = tester.widget<TextField>(target).controller!;
    controller.selection = const TextSelection.collapsed(offset: 6);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(controller.text, 'ABC12');
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(controller.text, 'BC12');
    expect(writes, isEmpty);
    expect(database[runs], hasLength(2));
  });

  testWidgets('Delete and Backspace still request deletion outside editing', (
    tester,
  ) async {
    seedRow();
    await openGrid(tester);
    for (final key in [
      LogicalKeyboardKey.delete,
      LogicalKeyboardKey.backspace,
    ]) {
      await tester.tap(find.text('10'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(find.text('Eliminar transformación'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    }
    expect(writes, isEmpty);
    expect(database[runs], hasLength(1));
  });
}
