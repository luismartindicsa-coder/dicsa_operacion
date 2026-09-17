import 'dart:io';

import 'package:dicsa_operacion/app/direction/operating_program/operating_program_models.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_pdf.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'operating_program_engine_test.dart' as f;
import 'operating_program_pdf_test.dart' as pdf;
import 'operating_program_view_test.dart' as view;

class _OldAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key.startsWith('assets/fonts/')) {
      throw FlutterError(
        'Unable to load asset: "$key". The asset does not exist.',
      );
    }
    return rootBundle.load(key);
  }
}

class _SavePicker extends FilePicker {
  String? path, suggestedName;
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
    suggestedName = fileName;
    expect(type, FileType.custom);
    expect(allowedExtensions, ['pdf']);
    if (error != null) throw error!;
    return path;
  }
}

Future<void> _export(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('export-operating-program'));
  await tester.ensureVisible(button);
  final callback = tester.widget<OutlinedButton>(button).onPressed;
  expect(callback, isNotNull);
  // Await the actual registered button handler, including asset reads and the
  // real filesystem write. Fake only the OS destination picker.
  await tester.runAsync(callback! as Future<void> Function());
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an older desktop bundle can still generate the complete PDF', () async {
    final c = f.conditions(
      share: 52,
      yard: [21, 22, 32],
      days: [
        const ProgramDayCondition(),
        const ProgramDayCondition(),
        const ProgramDayCondition(working: false),
        const ProgramDayCondition(),
        const ProgramDayCondition(nightAvailable: false),
      ],
    );
    final demands = [
      f.demand(0, 40),
      f.demand(0, 40, material: 2),
      f.demand(1, 80),
      f.demand(3, 100),
      f.demand(3, 70, material: 1),
      f.demand(4, 40),
      f.demand(4, 40, material: 2),
    ];
    final p = pdf.program(conditions: c, demands: demands);
    final bytes = await buildOperatingProgramPdf(
      p,
      assetBundle: _OldAssetBundle(),
    );
    pdf.expectOneA4Page(bytes);
    final path = Platform.environment['DICSA_FALLBACK_QA_PDF'];
    if (path != null) await File(path).writeAsBytes(bytes);
  });

  testWidgets('PDF button saves a real file and confirms the chosen path', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1050));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final folder = Directory.systemTemp.createTempSync('dicsa-pdf-button-');
    addTearDown(() => folder.deleteSync(recursive: true));
    final picker = _SavePicker()..path = '${folder.path}/programa';
    FilePicker.platform = picker;
    final repo = view.TestPrograms();
    await tester.pumpWidget(
      DefaultAssetBundle(bundle: _OldAssetBundle(), child: view.harness(repo)),
    );
    await tester.pumpAndSettle();
    await view.generate(tester);
    await _export(tester);
    expect(picker.calls, 1);
    expect(picker.suggestedName, 'programa_operativo_carton_2026-09-14_v1.pdf');
    final file = File('${folder.path}/programa.pdf');
    pdf.expectOneA4Page(file.readAsBytesSync());
    expect(find.text('PDF guardado en ${file.path}'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'picker failures are visible beside the button and survive refresh',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      FilePicker.platform = _SavePicker()
        ..error = PlatformException(
          code: 'SAVE_FAILED',
          message: 'No se pudo abrir Guardar',
        );
      await tester.pumpWidget(view.harness(view.TestPrograms()));
      await tester.pumpAndSettle();
      await view.generate(tester);
      await _export(tester);
      expect(find.textContaining('No se pudo abrir Guardar'), findsWidgets);
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo abrir Guardar'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('export-operating-program')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('cancelled save reports that no destination was selected', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1050));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    FilePicker.platform = _SavePicker();
    await tester.pumpWidget(view.harness(view.TestPrograms()));
    await tester.pumpAndSettle();
    await view.generate(tester);
    await _export(tester);
    expect(
      find.textContaining('no se eligió un archivo de destino'),
      findsWidgets,
    );
    expect(find.textContaining('PDF guardado en'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'generation failures are visible before opening the save picker',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final picker = _SavePicker();
      FilePicker.platform = picker;
      final repo = view.TestPrograms();
      repo.saved.add(
        pdf.program(
          demands: [f.demand(4, 10)],
          lines: f.withQuantity(0, 0, 0, 11),
        ),
      );
      await tester.pumpWidget(view.harness(repo));
      await tester.pumpAndSettle();
      await _export(tester);
      expect(picker.calls, 0);
      expect(
        find.textContaining('excede las 10 pacas requeridas'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
