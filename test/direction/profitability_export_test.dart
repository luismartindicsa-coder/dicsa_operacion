import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/direction/direction_theme.dart';
import 'package:dicsa_operacion/app/shared/ui_contract_core/theme/area_theme_scope.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_models.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_view.dart';
import 'profitability_view_test.dart' show MemoryProfitRepo;
import 'expected_income_export_test.dart' show IncomeSavePicker;
import 'profitability_pdf_test.dart' show pages;

Widget harness(MemoryProfitRepo repo) => MaterialApp(
  theme: ThemeData.dark(useMaterial3: true),
  home: Scaffold(
    body: AreaThemeScope(
      tokens: directionAreaTokens,
      child: ProfitabilityView(
        repository: repo,
        initialPeriod: ProfitPeriod.pilot(),
      ),
    ),
  ),
);
Future<void> openAccount(WidgetTester tester, MemoryProfitRepo repo) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(harness(repo));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('profit-company-pdf')), findsNothing);
  await tester.tap(find.byKey(const ValueKey('account:site:s1')));
  await tester.pumpAndSettle();
}

Future<void> export(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('profit-company-pdf'));
  final callback = tester.widget<OutlinedButton>(button).onPressed;
  expect(callback, isNotNull);
  await tester.runAsync(callback! as Future<void> Function());
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('selected company exports a real PDF named for its period', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('profit-pdf-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final picker = IncomeSavePicker()..path = '${directory.path}/analisis';
    FilePicker.platform = picker;
    final repo = MemoryProfitRepo()..infer = true;
    await openAccount(tester, repo);
    await export(tester);
    expect(picker.calls, 1);
    expect(picker.name, 'rentabilidad_planta_a_2026-09-11_2026-09-17.pdf');
    expect(
      pages(File('${directory.path}/analisis.pdf').readAsBytesSync()),
      greaterThan(3),
    );
    expect(find.text('PDF de PLANTA A guardado.'), findsWidgets);
    expect(repo.writes, 0);
    expect(repo.snapshots, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final failure in [false, true]) {
    testWidgets('cancel or failed save remains retryable: $failure', (
      tester,
    ) async {
      FilePicker.platform = IncomeSavePicker()
        ..error = failure
            ? PlatformException(
                code: 'SAVE_FAILED',
                message: 'No se pudo abrir Guardar',
              )
            : null;
      await openAccount(tester, MemoryProfitRepo()..infer = true);
      await export(tester);
      expect(
        find.textContaining(
          failure ? 'No se pudo abrir Guardar' : 'No se guardó el PDF.',
        ),
        findsWidgets,
      );
      expect(find.text('PDF de PLANTA A guardado.'), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('profit-company-pdf')),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('failed source refresh blocks export until source recovery', (
    tester,
  ) async {
    final repo = MemoryProfitRepo()..infer = true;
    final picker = IncomeSavePicker();
    FilePicker.platform = picker;
    await openAccount(tester, repo);
    repo.fail = true;
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('profit-company-pdf'));
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    expect(picker.calls, 0);
    repo.fail = false;
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
