import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dicsa_operacion/app/direction/direction_cash_entries_exits_page.dart';
import 'package:dicsa_operacion/app/direction/direction_cash_taxonomy_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  final savedVouchers = <Map<String, dynamic>>[];
  var failCatalog = false;
  Completer<void>? catalogGate;
  Map<String, dynamic>? catalog;
  Map<String, dynamic>? legacyCatalog;
  var vouchers = <Map<String, dynamic>>[];

  Map<String, dynamic> peopleCatalog() => {
    'entry_people': ['REMITENTE ACTUAL'],
    'exit_people': ['DESTINATARIO ACTUAL'],
  };

  setUpAll(() async {
    await (FontLoader('Roboto')..addFont(
          File(
            'assets/fonts/Roboto-Regular.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://vault-test.invalid',
      anonKey: 'test-only-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        final table = request.url.pathSegments.last;
        Object data = <dynamic>[];
        if (table == 'cash_taxonomy_configs') {
          final area = request.url.queryParameters['area'];
          if (area == 'eq.direccion') {
            await catalogGate?.future;
            if (failCatalog) {
              return http.Response(
                '{"message":"catalog temporarily unavailable","code":"TEST"}',
                400,
                request: request,
              );
            }
            if (catalog != null) {
              data = [
                {'payload': catalog},
              ];
            }
          } else if (area == 'eq.mayoreo' && legacyCatalog != null) {
            data = [
              {'payload': legacyCatalog},
            ];
          }
        } else if (table == 'direction_vault_vouchers') {
          if (request.method == 'POST') {
            savedVouchers.addAll(
              (jsonDecode(request.body) as List).cast<Map<String, dynamic>>(),
            );
          } else {
            data = vouchers;
          }
        } else if (table == 'direction_vault_voucher_lines' &&
            request.method == 'GET') {
          data = [
            for (final voucher in vouchers)
              {
                'id': '${voucher['id']}-line-1',
                'voucher_id': voucher['id'],
                'line_order': 1,
                'concept': 'Concepto guardado',
                'amount': 125,
              },
          ];
        }
        return http.Response(
          jsonEncode(data),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });

  setUp(() {
    requests.clear();
    savedVouchers.clear();
    failCatalog = false;
    catalogGate = null;
    catalog = peopleCatalog();
    legacyCatalog = null;
    vouchers = [];
  });

  tearDownAll(() => Supabase.instance.dispose());

  test(
    'initial failure retries and concurrent callers await the same load',
    () async {
      failCatalog = true;
      final store = DirectionCashTaxonomyStore.instance;
      await expectLater(
        store.ensureLoaded(),
        throwsA(isA<PostgrestException>()),
      );
      expect(requests.map((r) => r.url.queryParameters['area']), [
        'eq.direccion',
      ]);

      failCatalog = false;
      catalogGate = Completer<void>();
      var completed = false;
      final retry = store.ensureLoaded();
      expect(identical(retry, store.ensureLoaded()), isTrue);
      final observed = retry.then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      catalogGate!.complete();
      await observed;
      expect(store.peopleFor(DirectionCashMovementType.entry), [
        'REMITENTE ACTUAL',
      ]);
      expect(store.peopleFor(DirectionCashMovementType.exit), [
        'DESTINATARIO ACTUAL',
      ]);
      expect(requests.length, 2);
    },
  );

  test(
    'refresh failure retains people and does not fall back to another area',
    () async {
      final store = DirectionCashTaxonomyStore.instance;
      await store.ensureLoaded(refresh: true);
      requests.clear();
      failCatalog = true;
      legacyCatalog = {
        'entry_people': ['PERSONA DE OTRA AREA'],
      };
      await expectLater(
        store.ensureLoaded(refresh: true),
        throwsA(isA<PostgrestException>()),
      );
      expect(store.peopleFor(DirectionCashMovementType.entry), [
        'REMITENTE ACTUAL',
      ]);
      expect(requests.map((r) => r.url.queryParameters['area']), [
        'eq.direccion',
      ]);
      failCatalog = false;
      catalog = {'entry_people': [], 'exit_people': []};
      await store.ensureLoaded(refresh: true);
      expect(store.peopleFor(DirectionCashMovementType.entry), isEmpty);
      expect(store.peopleFor(DirectionCashMovementType.exit), isEmpty);
    },
  );

  test(
    'legacy catalog is used only when the direction catalog is absent',
    () async {
      catalog = null;
      legacyCatalog = peopleCatalog();
      final store = DirectionCashTaxonomyStore.instance;
      await store.ensureLoaded(refresh: true);
      expect(requests.map((r) => r.url.queryParameters['area']), [
        'eq.direccion',
        'eq.mayoreo',
      ]);
      expect(store.peopleFor(DirectionCashMovementType.entry), [
        'REMITENTE ACTUAL',
      ]);
    },
  );

  Future<void> openPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: const DirectionCashEntriesExitsPage(instantOpen: true),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> finishCatalogLoad(WidgetTester tester) async {
    // The singleton also serves the non-widget tests, so its cached futures
    // can belong to the real async zone rather than the widget test clock.
    await tester.runAsync(() async {
      try {
        await DirectionCashTaxonomyStore.instance.ensureLoaded();
      } catch (_) {
        // The page presents the load error and must remain available to retry.
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> tapToOpen(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() => tester.tap(finder));
  }

  testWidgets(
    'editor waits for both people lists and refreshes them on reopen',
    (tester) async {
      await openPage(tester);
      catalogGate = Completer<void>();
      await tapToOpen(tester, find.text('Nuevo movimiento'));
      await tester.pump();
      expect(find.text('Cargando catálogo...'), findsOneWidget);
      expect(find.text('Guardar movimiento'), findsNothing);
      catalogGate!.complete();
      await finishCatalogLoad(tester);
      expect(find.text('DESTINATARIO ACTUAL'), findsOneWidget);
      await tester.tap(find.text('Entrada'));
      await tester.pumpAndSettle();
      expect(find.text('REMITENTE ACTUAL'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      catalog = {
        'entry_people': ['REMITENTE NUEVO'],
        'exit_people': ['DESTINATARIO NUEVO'],
      };
      await tapToOpen(tester, find.text('Nuevo movimiento'));
      await finishCatalogLoad(tester);
      expect(find.text('DESTINATARIO NUEVO'), findsOneWidget);
      await tester.tap(find.text('Entrada'));
      await tester.pumpAndSettle();
      expect(find.text('REMITENTE NUEVO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed catalog blocks the editor and another open retries', (
    tester,
  ) async {
    await openPage(tester);
    failCatalog = true;
    await tapToOpen(tester, find.text('Nuevo movimiento'));
    await finishCatalogLoad(tester);
    expect(find.text('Guardar movimiento'), findsNothing);
    expect(
      find.textContaining('No se pudo cargar el catálogo de Bóveda'),
      findsOneWidget,
    );
    failCatalog = false;
    await tapToOpen(tester, find.text('Nuevo movimiento'));
    await finishCatalogLoad(tester);
    expect(find.text('DESTINATARIO ACTUAL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final type in ['deposit', 'expense']) {
    testWidgets('$type preserves and saves a person removed from the catalog', (
      tester,
    ) async {
      vouchers = [
        {
          'id': 'voucher-1',
          'folio': '18421',
          'voucher_date': '2026-09-23',
          'voucher_type': type,
          'person_label': 'PERSONA HISTORICA',
          'rubric': type == 'deposit'
              ? 'Venta de material'
              : 'Gastos operativos',
          'total_amount': 125,
        },
      ];
      await openPage(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('18421'));
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await tester.tap(find.text('18421'));
      });
      await finishCatalogLoad(tester);
      final inDialog = find.descendant(
        of: find.byType(Dialog),
        matching: find.text('PERSONA HISTORICA'),
      );
      expect(inDialog, findsOneWidget);
      await tester.tap(inDialog);
      await tester.pumpAndSettle();
      expect(
        find.text(
          type == 'deposit' ? 'REMITENTE ACTUAL' : 'DESTINATARIO ACTUAL',
        ),
        findsOneWidget,
      );
      final search = tester.widget<EditableText>(
        find.byType(EditableText).last,
      );
      expect(search.focusNode.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Guardar movimiento'));
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(savedVouchers, hasLength(1));
      expect(savedVouchers.single['person_label'], 'PERSONA HISTORICA');
      expect(savedVouchers.single['voucher_type'], type);
      expect(tester.takeException(), isNull);
    });
  }
}
