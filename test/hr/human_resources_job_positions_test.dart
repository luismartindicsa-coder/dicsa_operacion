import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/hr/human_resources_personnel_page.dart';
import 'package:dicsa_operacion/app/hr/personnel/hr_job_position_picker.dart';
import 'package:dicsa_operacion/app/hr/personnel/hr_job_positions.dart';

const preview = bool.fromEnvironment('HR_POSITIONS_PREVIEW');
final search = find.byKey(const ValueKey('jobPositionSearch'));
final puesto = find.byKey(const ValueKey('personalJobPosition'));

Future<void> app(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1600, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (preview) {
    await tester.runAsync(() async {
      for (final font in {
        'Roboto': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(font.key)..addFont(
              File(
                '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/${font.value}',
              ).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      }
    });
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: preview ? 'Roboto' : null),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!preview) return;
  await tester.runAsync(() async {
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    final image = await layer.toImage(const Rect.fromLTWH(0, 0, 1600, 1100));
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '/private/tmp/dicsa_hr_positions/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> openPicker(
  WidgetTester tester, {
  String current = '',
  required Future<List<String>> Function() load,
  required Future<String> Function(String) create,
  required void Function(String?) result,
}) async {
  await app(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          result(
            await showHrJobPositionPicker(
              context,
              current: current,
              load: load,
              create: create,
            ),
          );
        },
        child: const Text('Abrir'),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'reuses names across accents, case and repeated spaces; options sort alphabetically',
    () {
      expect(
        hrJobPositionOptions([
          ' operador  ',
          'AUXILIAR',
          'OPERADOR',
          '  técnico\tde patio ',
          'TECNICO DE PATIO',
          '',
        ]),
        ['AUXILIAR', 'OPERADOR', 'TÉCNICO DE PATIO'],
      );
    },
  );

  testWidgets(
    'search autofocus, arrows and Space select existing value without creating',
    (tester) async {
      String? selected;
      await openPicker(
        tester,
        load: () async => ['OPERADOR', 'AUXILIAR', 'TÉCNICO'],
        create: (_) async => throw StateError('Must not create'),
        result: (s) => selected = s,
      );
      expect(tester.widget<TextField>(search).focusNode!.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(selected, 'OPERADOR');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('arrows reveal and select catalog options beyond the viewport', (
    tester,
  ) async {
    String? selected;
    await openPicker(
      tester,
      load: () async =>
          List.generate(30, (i) => 'PUESTO ${i.toString().padLeft(2, '0')}'),
      create: (_) async => throw StateError('Unexpected'),
      result: (s) => selected = s,
    );
    for (var i = 0; i < 25; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(find.text('PUESTO 24').hitTestable(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 'PUESTO 24');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'exact match accepts Enter and accent-insensitive search with no duplicate',
    (tester) async {
      String? selected;
      await openPicker(
        tester,
        load: () async => ['TÉCNICO DE PATIO'],
        create: (_) async => throw StateError('Duplicate'),
        result: (s) => selected = s,
      );
      await tester.enterText(search, '  tecnico de patio ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(selected, 'TÉCNICO DE PATIO');
    },
  );

  testWidgets(
    'create failure in empty catalog retains text and allows retry, with duplicate clicks blocked',
    (tester) async {
      var attempts = 0;
      String? selected;
      final pending = Completer<String>();
      await openPicker(
        tester,
        load: () async => [],
        create: (name) async {
          attempts++;
          expect(name, 'JEFE DE PATIO');
          if (attempts == 1) throw StateError('offline');
          return pending.future;
        },
        result: (s) => selected = s,
      );
      await tester.enterText(search, '  jefe   de patio ');
      await tester.pump();
      await tester.tap(find.text('Agregar «JEFE DE PATIO»'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo guardar'), findsOneWidget);
      expect(
        tester.widget<TextField>(search).controller!.text,
        '  jefe   de patio ',
      );
      await tester.tap(find.text('Agregar «JEFE DE PATIO»'));
      await tester.pump();
      await tester.tap(find.text('Agregar «JEFE DE PATIO»'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(attempts, 2);
      expect(find.byType(HrJobPositionPicker), findsOneWidget);
      pending.complete('JEFE DE PATIO');
      await tester.pumpAndSettle();
      expect(selected, 'JEFE DE PATIO');
    },
  );

  testWidgets('failed catalog load retains query and retries before creation', (
    tester,
  ) async {
    var attempts = 0;
    String? selected;
    await openPicker(
      tester,
      load: () async {
        if (++attempts == 1) throw StateError('offline');
        return ['CONTADOR'];
      },
      create: (_) async => throw StateError('Duplicate'),
      result: (s) => selected = s,
    );
    await tester.enterText(search, 'contador');
    await tester.pump();
    expect(find.textContaining('Agregar «'), findsNothing);
    await tester.tap(find.text('Reintentar carga'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, 'contador');
    await tester.tap(find.text('CONTADOR'));
    await tester.pumpAndSettle();
    expect(selected, 'CONTADOR');
  });

  testWidgets(
    'Escape cancels; clearing an assignment never deletes catalog options',
    (tester) async {
      String? selected = 'untouched';
      final catalog = ['OPERADOR'];
      await openPicker(
        tester,
        current: 'OPERADOR',
        load: () async => catalog,
        create: (_) async => throw StateError('unexpected'),
        result: (s) => selected = s,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(selected, isNull);
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin puesto'));
      await tester.pumpAndSettle();
      expect(selected, '');
      expect(catalog, ['OPERADOR']);
    },
  );

  testWidgets(
    'real expediente saves and reopens position; newly created options can be reused by another employee',
    (tester) async {
      final catalog = ['AUXILIAR', 'OPERADOR DE UNIDAD'];
      String current = 'AUXILIAR';
      Map<String, dynamic>? saved;
      bool failSave = true;
      await app(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await hrPersonnelPositionEditorForTesting(
                context,
                puesto: current,
                loadPositions: () async => catalog,
                createPosition: (name) async {
                  catalog.add(name);
                  return name;
                },
                persist: (_) async => !failSave,
              );
              if (result != null) {
                saved = result;
                current = result['puesto'] as String;
              }
            },
            child: const Text('Abrir'),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(puesto);
      await tester.tap(puesto);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).focusNode!.hasFocus, isTrue);
      await capture(tester, 'picker');
      await tester.enterText(search, 'supervisor de patio');
      await tester.pump();
      await tester.tap(find.text('Agregar «SUPERVISOR DE PATIO»'));
      await tester.pumpAndSettle();
      expect(find.text('SUPERVISOR DE PATIO'), findsOneWidget);
      await tester.tap(find.text('Guardar expediente'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text('SUPERVISOR DE PATIO'), findsOneWidget);
      failSave = false;
      await tester.tap(find.text('Guardar expediente'));
      await tester.pumpAndSettle();
      expect(saved!['puesto'], 'SUPERVISOR DE PATIO');
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(puesto);
      expect(find.text('SUPERVISOR DE PATIO'), findsOneWidget);
      await capture(tester, 'expediente');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      current = '';
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(puesto);
      await tester.tap(puesto);
      await tester.pumpAndSettle();
      await tester.tap(find.text('SUPERVISOR DE PATIO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar expediente'));
      await tester.pumpAndSettle();
      expect(saved!['puesto'], 'SUPERVISOR DE PATIO');
      expect(catalog.where((s) => s == 'SUPERVISOR DE PATIO'), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [900.0, 1450.0]) {
    testWidgets(
      'real Personal header and row fit $width with new column and actions',
      (tester) async {
        await app(
          tester,
          Center(child: hrPersonnelPositionGridForTesting(width: width)),
        );
        expect(find.text('PUESTO'), findsOneWidget);
        expect(find.text('OPERADOR DE UNIDAD'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(tester, 'grid-${width.toInt()}');
      },
    );
  }
}
