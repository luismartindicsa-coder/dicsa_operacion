import 'dart:io';
import 'dart:ui' as ui;
import 'package:dicsa_operacion/app/contabilidad/contabilidad_income_statement_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'statement_fixture.dart';
import 'package:dicsa_operacion/app/contabilidad/contabilidad_income_statement_store.dart';

class ClosingFailureStore extends ContabilidadIncomeStatementStore {
  @override
  Future<ContabilidadIncomeStatementDataset> loadAccrual({
    required int windowDays,
    required DateTimeRange? dateRange,
  }) async {
    throw StateError('Cierre temporalmente no disponible');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    await font.load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://statement-page.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient(
        (r) async => accountingResponse(r, {
          ...accountingFixture(),
          'vw_men_cash_vouchers_grid': [],
          'vw_men_cash_cuts_grid': [],
          'cash_taxonomy_configs': [],
        }),
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  testWidgets(
    'base opens without closing reviews and closing keeps all operations accessible',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      final realtime = RealtimeClient(
        'ws://offline.test',
        transport: (_, _) => throw StateError('Offline widget test'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: ContabilidadIncomeStatementPage(
              realtime: realtime,
              instantOpen: true,
              initialDateRange: DateTimeRange(
                start: DateTime(2026, 9, 14),
                end: DateTime(2026, 9, 18),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ventas cobradas'), findsOneWidget);
      expect(find.text('Compras pagadas'), findsOneWidget);
      expect(find.text('Gastos pagados'), findsOneWidget);
      expect(find.textContaining('Por conciliar ('), findsNothing);
      expect(find.text('Por determinar'), findsNothing);
      expect(find.textContaining('Resultado provisional:'), findsNothing);
      Future<void> screenshot(String name) async {
        final root = Platform.environment['DICSA_ACCOUNTING_SCREENSHOTS'];
        if (root == null) return;
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final img = await boundary.toImage();
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$root/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          img.dispose();
        });
      }

      await screenshot('pantalla_resumen');
      await tester.tap(find.text('Cierre contable'));
      await tester.pumpAndSettle();
      expect(find.text('Vincular efectivo'), findsOneWidget);
      expect(find.text('Datos por completar'), findsOneWidget);
      expect(
        find.text('Resultado contable y ajustes de cierre'),
        findsOneWidget,
      );
      await tester.tap(find.text('Datos por completar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todas las operaciones').last);
      await tester.pumpAndSettle();
      expect(find.text('Base física · Entradas y Salidas'), findsOneWidget);
      await screenshot('pantalla_conciliacion');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await realtime.disconnect();
      await tester.pump(const Duration(seconds: 2));
    },
  );
  testWidgets('closing failure does not block base or expense tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final realtime = RealtimeClient(
      'ws://offline.test',
      transport: (_, _) => throw StateError('Offline widget test'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ContabilidadIncomeStatementPage(
          store: ClosingFailureStore(),
          realtime: realtime,
          instantOpen: true,
          initialDateRange: DateTimeRange(
            start: DateTime(2026, 9, 14),
            end: DateTime(2026, 9, 18),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ventas cobradas'), findsOneWidget);
    await tester.tap(find.text('Cierre contable'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Cierre temporalmente no disponible'),
      findsOneWidget,
    );
    await tester.tap(find.text('Resultado base').first);
    await tester.pumpAndSettle();
    expect(find.text('Ventas cobradas'), findsOneWidget);
    await tester.tap(find.text('Gastos'));
    await tester.pumpAndSettle();
    expect(find.text('DESGLOSE DE GASTOS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await realtime.disconnect();
    await tester.pump(const Duration(seconds: 2));
  });
}
