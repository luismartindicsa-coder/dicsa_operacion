import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/contabilidad/contabilidad_income_statement_store.dart';
import 'package:dicsa_operacion/app/direction/direction_accounting_dashboard_card.dart';
import 'package:dicsa_operacion/app/direction/direction_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ContabilidadIncomeStatementDataset fixture(
  DateTimeRange range, {
  double sales = 485000,
  double other = 25000,
  double purchases = 296000,
  double expenses = 84500,
}) {
  final gross = sales + other - purchases;
  final net = gross - expenses;
  return ContabilidadIncomeStatementDataset(
    range: range,
    snapshot: ContabilidadIncomeStatementSnapshot(
      revenue: sales,
      otherIncome: other,
      commercialCost: purchases,
      commercialResult: gross,
      operatingExpense: expenses,
      administrativeExpense: 0,
      financialExpense: 0,
      payrollExpense: 0,
      recognizedExpenses: expenses,
      periodResult: net,
      internalExcluded: 0,
      reviewPending: 0,
    ),
    lines: [
      ContabilidadIncomeStatementLine(
        label: 'Ventas de material',
        amount: sales,
        emphasis: false,
        tone: ColorTone.positive,
      ),
      ContabilidadIncomeStatementLine(
        label: 'Entradas por otros medios',
        amount: other,
        emphasis: false,
        tone: ColorTone.positive,
      ),
      ContabilidadIncomeStatementLine(
        label: 'Compra de material',
        amount: -purchases,
        emphasis: false,
        tone: ColorTone.caution,
      ),
      ContabilidadIncomeStatementLine(
        label: 'Utilidad bruta',
        amount: gross,
        emphasis: true,
        tone: gross >= 0 ? ColorTone.positive : ColorTone.negative,
      ),
      ContabilidadIncomeStatementLine(
        label: 'Gastos',
        amount: -expenses,
        emphasis: false,
        tone: ColorTone.neutral,
      ),
      ContabilidadIncomeStatementLine(
        label: 'Utilidad neta',
        amount: net,
        emphasis: true,
        tone: net >= 0 ? ColorTone.positive : ColorTone.negative,
      ),
    ],
    sourceRows: [],
    familyExpenseRows: [],
    expenseBreakdown: [],
    otherIncomeBreakdown: [],
    reviewRows: [],
    familyRows: [],
    insights: [],
    warnings: ['Traspasos internos excluidos por Contabilidad.'],
  );
}

Widget harness({
  required Future<ContabilidadIncomeStatementDataset> Function(DateTimeRange)
  loader,
  Future<void> Function(DateTimeRange)? onOpen,
  DateTime Function()? now,
  double width = 420,
  double scale = 1,
  GlobalKey? captureKey,
}) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(
    backgroundColor: kDirectionBg,
    body: Center(
      child: RepaintBoundary(
        key: captureKey,
        child: ColoredBox(
          color: kDirectionBg,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SizedBox(
                width: width,
                height: 428,
                child: DirectionAccountingDashboardCard(
                  loadStatement: loader,
                  now: now ?? () => DateTime(2026, 9, 15),
                  onOpenStatement: onOpen ?? (_) async {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final path = Platform.environment['DICSA_ACCOUNTING_QA_FONTS'];
    if (path == null) return;
    for (final (family, file) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(family);
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File('$path/$file').readAsBytes()),
        ),
      );
      await loader.load();
    }
  });

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const ValueKey('direction-accounting-period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  for (final width in [420.0, 320.0]) {
    testWidgets(
      'accounting statement fits at $width and preserves all source lines',
      (tester) async {
        final capture = GlobalKey();
        await tester.pumpWidget(
          harness(
            loader: (range) async => fixture(range),
            width: width,
            scale: width == 320 ? 1.3 : 1,
            captureKey: capture,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Contabilidad'), findsOneWidget);
        expect(find.text('09/09/2026 – 15/09/2026'), findsOneWidget);
        expect(find.text('\$485,000.00'), findsOneWidget);
        expect(find.text('\$25,000.00'), findsOneWidget);
        expect(
          find.byTooltip('Traspasos internos excluidos por Contabilidad.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        final output = Platform.environment['DICSA_ACCOUNTING_QA_PNG'];
        if (output != null && width == 420) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(output).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        final net = find.byKey(
          const ValueKey('direction-accounting-net-result'),
        );
        await tester.scrollUntilVisible(
          net,
          70,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(net).data, '\$129,500.00');
        expect(net.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await dispose(tester);
      },
    );
  }

  testWidgets(
    '7, 30 and 90 day windows use inclusive dates and preserve range in detail',
    (tester) async {
      final loads = <DateTimeRange>[];
      DateTimeRange? opened;
      await tester.pumpWidget(
        harness(
          loader: (range) async {
            loads.add(range);
            return fixture(range);
          },
          onOpen: (range) async => opened = range,
        ),
      );
      await tester.pumpAndSettle();
      expect(loads.last.start, DateTime(2026, 9, 9));
      await select(tester, 'Últimos 30 días');
      expect(loads.last.start, DateTime(2026, 8, 17));
      expect(loads.last.end, DateTime(2026, 9, 15));
      await select(tester, 'Últimos 90 días');
      expect(loads.last.duration.inDays, 89);
      await tester.tap(find.byTooltip('Ver Estado de Resultados'));
      await tester.pumpAndSettle();
      expect(opened, loads.last);
      expect(loads, hasLength(4));
      await dispose(tester);
    },
  );

  testWidgets(
    'custom period uses contract picker, supports cancel and stays fixed at midnight',
    (tester) async {
      var now = DateTime(2026, 9, 15);
      final loads = <DateTimeRange>[];
      await tester.pumpWidget(
        harness(
          now: () => now,
          loader: (range) async {
            loads.add(range);
            return fixture(range);
          },
        ),
      );
      await tester.pumpAndSettle();
      await select(tester, 'Seleccionar fechas');
      expect(find.text('Periodo del Estado de Resultados'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(loads, hasLength(1));
      await select(tester, 'Seleccionar fechas');
      final range = DateTimeRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      );
      Navigator.of(
        tester.element(find.text('Periodo del Estado de Resultados')),
      ).pop(range);
      await tester.pumpAndSettle();
      expect(loads.last, range);
      expect(find.text('Periodo personalizado'), findsOneWidget);
      now = DateTime(2026, 9, 16);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(loads.last, range);
      await dispose(tester);
    },
  );

  testWidgets(
    'old refresh cannot overwrite a newly selected reporting period',
    (tester) async {
      final pending = Completer<ContabilidadIncomeStatementDataset>();
      var calls = 0;
      final oldRange = DateTimeRange(
        start: DateTime(2026, 9, 9),
        end: DateTime(2026, 9, 15),
      );
      await tester.pumpWidget(
        harness(
          loader: (range) async {
            calls++;
            if (calls == 2) return pending.future;
            return fixture(range, sales: calls == 1 ? 485000 : 600000);
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 1));
      await tester.tap(
        find.byKey(const ValueKey('direction-accounting-period')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Últimos 30 días'));
      await tester.pump();
      expect(find.text('\$485,000.00'), findsNothing);
      pending.complete(fixture(oldRange));
      await tester.pumpAndSettle();
      expect(find.text('\$600,000.00'), findsOneWidget);
      expect(find.text('17/08/2026 – 15/09/2026'), findsOneWidget);
      await dispose(tester);
    },
  );

  testWidgets('error states keep known values and never invent a zero result', (
    tester,
  ) async {
    var fail = true;
    await tester.pumpWidget(
      harness(
        loader: (range) async {
          if (fail) throw StateError('offline');
          return fixture(range, sales: 0, other: 0, purchases: 0, expenses: 0);
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudo cargar el Estado de Resultados.'),
      findsOneWidget,
    );
    expect(find.text('\$0.00'), findsNothing);
    fail = false;
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.text('\$0.00'), findsWidgets);
    fail = true;
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Se conservan los últimos datos'),
      findsOneWidget,
    );
    expect(find.text('\$0.00'), findsWidgets);
    await dispose(tester);
  });

  testWidgets(
    'negative net result retains sign and loss color from accounting',
    (tester) async {
      await tester.pumpWidget(
        harness(loader: (range) async => fixture(range, expenses: 300000)),
      );
      await tester.pumpAndSettle();
      final net = find.byKey(const ValueKey('direction-accounting-net-result'));
      await tester.scrollUntilVisible(
        net,
        70,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(net).data, '\$-86,000.00');
      expect(tester.widget<Text>(net).style!.color, kDirectionDanger);
      await dispose(tester);
    },
  );
}
