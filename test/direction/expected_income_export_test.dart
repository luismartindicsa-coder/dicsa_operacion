import 'dart:io';

import 'package:dicsa_operacion/app/direction/expected_income/expected_income_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expected_income_pdf_test.dart' as pdf;
import 'expected_income_test.dart' as f;
import 'expected_income_view_test.dart' as view;

class IncomeSavePicker extends FilePicker {
  String? path, name;
  Object? error;
  int calls = 0;
  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    calls++;
    name = fileName;
    expect(type, FileType.custom);
    expect(allowedExtensions, ['pdf']);
    if (error != null) throw error!;
    return path;
  }
}

Future<void> export(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('export-expected-income'));
  await tester.ensureVisible(button);
  final callback = tester.widget<OutlinedButton>(button).onPressed;
  expect(callback, isNotNull);
  await tester.runAsync(callback! as Future<void> Function());
  await tester.pumpAndSettle();
}

Widget harness(view.MemoryIncomeRepository repository) => view.app(
  ExpectedIncomeView(
    bundle: f.incomeBundle(stock: {'PACA_NACIONAL': 50}),
    repository: repository,
    clock: () => f.incomeWeek,
    onWeekChanged: (_) async {},
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'weekly income PDF button writes a real file and names the selected week',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final directory = Directory.systemTemp.createTempSync('income-pdf-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final picker = IncomeSavePicker()..path = '${directory.path}/ingresos';
      FilePicker.platform = picker;
      await tester.pumpWidget(harness(view.MemoryIncomeRepository()));
      await tester.pumpAndSettle();
      await export(tester);
      expect(picker.calls, 1);
      expect(picker.name, 'ingreso_proyectado_embarques_2026-09-21.pdf');
      final file = File('${directory.path}/ingresos.pdf');
      expect(file.existsSync(), isTrue);
      expect(pdf.pages(file.readAsBytesSync()), 1);
      expect(find.text('PDF guardado en ${file.path}'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final failure in [false, true]) {
    testWidgets(
      'cancel or OS save failure is explicit and retry remains available: $failure',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        FilePicker.platform = IncomeSavePicker()
          ..error = failure
              ? PlatformException(
                  code: 'SAVE_FAILED',
                  message: 'No se pudo abrir Guardar',
                )
              : null;
        await tester.pumpWidget(harness(view.MemoryIncomeRepository()));
        await tester.pumpAndSettle();
        await export(tester);
        expect(
          find.textContaining(
            failure
                ? 'No se pudo abrir Guardar'
                : 'no se eligió un archivo de destino',
          ),
          findsWidgets,
        );
        expect(find.textContaining('PDF guardado en'), findsNothing);
        await tester.pump(const Duration(seconds: 31));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            failure
                ? 'No se pudo abrir Guardar'
                : 'no se eligió un archivo de destino',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const ValueKey('export-expected-income')),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'a failed source refresh blocks exporting stale amounts until recovery',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = view.MemoryIncomeRepository();
      final picker = IncomeSavePicker();
      FilePicker.platform = picker;
      await tester.pumpWidget(harness(repository));
      await tester.pumpAndSettle();
      repository.fail = true;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('export-expected-income'));
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(picker.calls, 0);
      repository.fail = false;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
