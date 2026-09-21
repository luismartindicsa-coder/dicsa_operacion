import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/direction_theme.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_forms.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_repository.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_view.dart';
import 'package:dicsa_operacion/app/shared/ui_contract_core/theme/area_theme_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'expected_income_collections_test.dart' as c;
import 'expected_income_test.dart' as f;
import 'package:dicsa_operacion/app/mayoreo/mayoreo_expected_collections.dart';

class MemoryIncomeRepository extends ExpectedIncomeRepository {
  bool fail = false;
  int reads = 0;
  IncomeMaterialRule? saved;
  PalomarIncomeConfig palomar = const PalomarIncomeConfig(
    cashCheck1: 99000,
    cashCheck2: 99000,
  );
  List<PalomarIncomeMovement> movements = [];
  @override
  Future<ExpectedIncomeData> load(
    DirectionShipmentPlanningBundle bundle, {
    DateTime? now,
  }) async {
    reads++;
    if (fail) throw StateError('Fuente no disponible');
    return ExpectedIncomeData(
      materials: saved == null ? f.incomeMaterials : [saved!],
      clients: f.incomeClients,
      collections: mayoreoExpectedCollections([c.account()], {}),
      productionSource: 'Programa operativo v3 · Aprobado',
      palomarConfig: palomar,
      palomarMovements: movements,
    );
  }

  @override
  Future<void> saveMaterial(IncomeMaterialRule rule) async {
    saved = rule;
  }

  @override
  Future<void> savePalomarConfig(PalomarIncomeConfig config) async {
    palomar = config;
  }
}

Widget app(Widget child) => MaterialApp(
  theme: ThemeData.dark(),
  home: AreaThemeScope(
    tokens: directionAreaTokens,
    child: Scaffold(
      body: Stack(
        children: [
          const DirectionExecutiveBackground(),
          Positioned.fill(
            child: Padding(padding: const EdgeInsets.all(20), child: child),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Roboto', 'Ahem']) {
      final font = FontLoader(family);
      font.addFont(
        Future.value(
          ByteData.sublistView(
            await File('assets/fonts/Roboto-Regular.ttf').readAsBytes(),
          ),
        ),
      );
      await font.load();
    }
    final iconPath = Platform.environment['DICSA_INCOME_QA_ICONS'];
    if (iconPath != null) {
      final icons = FontLoader('MaterialIcons');
      icons.addFont(
        Future.value(ByteData.sublistView(await File(iconPath).readAsBytes())),
      );
      await icons.load();
    }
  });
  testWidgets(
    'income dashboard renders combined forecast at desktop and compact sizes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final boundary = GlobalKey();
      final repo = MemoryIncomeRepository();
      await tester.pumpWidget(
        app(
          RepaintBoundary(
            key: boundary,
            child: ExpectedIncomeView(
              bundle: f.incomeBundle(stock: {'PACA_NACIONAL': 50}),
              repository: repo,
              clock: () => f.incomeWeek,
              onWeekChanged: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('INGRESOS ESPERADOS'), findsOneWidget);
      expect(find.text(r'$82,500.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (Platform.environment['DICSA_INCOME_QA'] == '1') {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final picture = await render.toImage(pixelRatio: 1);
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await File(
            '/tmp/dicsa-expected-income.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }
      await tester.ensureVisible(find.text('Cobranza de Ventas Mayoreo'));
      await tester.pumpAndSettle();
      if (Platform.environment['DICSA_INCOME_QA'] == '1') {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final picture = await render.toImage(pixelRatio: 1);
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await File(
            '/tmp/dicsa-expected-income-collections.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }
      await tester.binding.setSurfaceSize(const Size(780, 1000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Silent refresh failure remains visible without turning the result into zero.
      repo.fail = true;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.textContaining('última lectura'), findsOneWidget);
      expect(find.text(r'$82,500.00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'saving Palomar immediately updates the week cards and respects its eligibility',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = MemoryIncomeRepository();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        app(
          RepaintBoundary(
            key: boundary,
            child: ExpectedIncomeView(
              bundle: f.incomeBundle(),
              repository: repo,
              clock: () => f.incomeWeek,
              onWeekChanged: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final current = find.byKey(const ValueKey('income-bucket-Esta semana'));
      final next = find.byKey(const ValueKey('income-bucket-Próxima semana'));
      expect(
        find.descendant(of: current, matching: find.text(r'$82,500.00')),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Configurar disposición'));
      await tester.tap(find.text('Configurar disposición'));
      await tester.pumpAndSettle();
      final readsBeforeSave = repo.reads;
      await tester.enterText(find.byKey(const ValueKey('limit')), '500000');
      await tester.enterText(find.byKey(const ValueKey('draw')), '400000');
      await tester.pump(
        const Duration(seconds: 31),
      ); // No refresh may reset the open form.
      expect(repo.reads, readsBeforeSave);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(repo.reads, readsBeforeSave + 1);
      expect(find.byType(IncomeFormDialog), findsNothing);
      expect(
        find.descendant(of: current, matching: find.text(r'$482,500.00')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: current,
          matching: find.text(r'EFECTIVO: $271,500.00'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: current,
          matching: find.text(r'FISCAL: $211,000.00'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: current,
          matching: find.text(r'Cobros por ventas: $82,500.00'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: current,
          matching: find.text(r'Disposición El Palomar: $400,000.00'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: next, matching: find.text(r'$0.00')),
        findsOneWidget,
      );
      await tester.ensureVisible(current);
      await tester.pumpAndSettle();
      if (Platform.environment['DICSA_INCOME_QA'] == '1') {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final picture = await render.toImage(pixelRatio: 1);
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await File(
            '/tmp/dicsa-palomar-week-cards.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }

      await tester.ensureVisible(find.text('Configurar disposición'));
      await tester.tap(find.text('Configurar disposición'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('draw')), '200000');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: current, matching: find.text(r'$282,500.00')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: current,
          matching: find.text(r'FISCAL: $11,000.00'),
        ),
        findsOneWidget,
      );

      // Later source changes revoke an ineligible disposition automatically.
      repo.movements = [
        PalomarIncomeMovement(
          id: 'new-check',
          date: f.incomeWeek,
          signedCents: 50000000,
          concept: 'Cheque liberado',
        ),
      ];
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: current, matching: find.text(r'$82,500.00')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: current,
          matching: find.textContaining(r'$500,000.00 por cubrir'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'number form accepts first click, validates input, Enter saves and Escape cancels',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = MemoryIncomeRepository();
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  editIncomeMaterial(context, f.incomeMaterials.first, repo),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('kg')));
      await tester.enterText(find.byKey(const ValueKey('kg')), '0');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(repo.saved, isNull);
      await tester.enterText(find.byKey(const ValueKey('kg')), '725');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(repo.saved!.kgPerBale, 725);
      expect(find.byType(IncomeFormDialog), findsNothing);
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('kg')), '800');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repo.saved!.kgPerBale, 725);
      expect(find.byType(IncomeFormDialog), findsNothing);
    },
  );
}
