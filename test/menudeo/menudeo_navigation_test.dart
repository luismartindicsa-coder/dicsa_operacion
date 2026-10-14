import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/auth/auth_access.dart';
import 'package:dicsa_operacion/app/menudeo/menudeo_cash_cuts_page.dart';
import 'package:dicsa_operacion/app/menudeo/menudeo_cash_taxonomy_page.dart';
import 'package:dicsa_operacion/app/menudeo/menudeo_catalog_page.dart';
import 'package:dicsa_operacion/app/menudeo/menudeo_dashboard_page.dart';
import 'package:dicsa_operacion/app/menudeo/menudeo_deposits_expenses_page.dart';
import 'package:dicsa_operacion/app/menudeo/menudeo_navigation.dart';
import 'package:dicsa_operacion/app/menudeo/menudeo_price_adjustments_page.dart';
import 'package:dicsa_operacion/app/menudeo/menudeo_sales_page.dart';
import 'package:dicsa_operacion/app/menudeo/menudeo_theme.dart';
import 'package:dicsa_operacion/app/menudeo/menudeo_tickets_page.dart';
import 'package:dicsa_operacion/app/shared/ui_contract_core/theme/area_theme_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const commonDestinations = [
  MenudeoDestination.purchases,
  MenudeoDestination.sales,
  MenudeoDestination.depositsExpenses,
  MenudeoDestination.priceAdjustments,
  MenudeoDestination.catalog,
  MenudeoDestination.dashboard,
];
const restrictedDestinations = [
  MenudeoDestination.cashCuts,
  MenudeoDestination.direction,
  MenudeoDestination.operation,
];
Finder item(MenudeoDestination destination) =>
    find.byKey(ValueKey('menudeo-nav-${destination.name}'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Roboto')..addFont(
          File(
            'assets/fonts/Roboto-Regular.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    final config = File('.dart_tool/package_config.json');
    final packages =
        jsonDecode(await config.readAsString())['packages'] as List;
    final flutter = packages.singleWhere((p) => p['name'] == 'flutter');
    final flutterRoot = config.absolute.uri.resolve('${flutter['rootUri']}/');
    await (FontLoader('MaterialIcons')..addFont(
          File.fromUri(
            flutterRoot.resolve(
              '../../bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ),
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://menudeo-navigation-test.invalid',
      anonKey: 'test-only-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient(
        (request) async => http.Response(
          request.url.pathSegments.last == 'profiles'
              ? jsonEncode({'role': 'menudeo', 'is_active': true})
              : '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json', 'content-range': '*/0'},
        ),
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  void viewport(WidgetTester tester, {Size size = const Size(1920, 1200)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final pages = <MenudeoDestination, Widget Function()>{
    MenudeoDestination.dashboard: () =>
        const MenudeoDashboardPage(instantOpen: true),
    MenudeoDestination.purchases: () =>
        const MenudeoTicketsPage(instantOpen: true),
    MenudeoDestination.sales: () => const MenudeoSalesPage(instantOpen: true),
    MenudeoDestination.depositsExpenses: () =>
        const MenudeoDepositsExpensesPage(instantOpen: true),
    MenudeoDestination.priceAdjustments: () =>
        const MenudeoPriceAdjustmentsPage(instantOpen: true),
    MenudeoDestination.catalog: () =>
        const MenudeoCatalogPage(instantOpen: true),
    MenudeoDestination.cashCuts: () =>
        const MenudeoCashCutsPage(instantOpen: true),
    MenudeoDestination.cashTaxonomy: () =>
        const MenudeoCashTaxonomyPage(instantOpen: true),
  };

  testWidgets(
    'each menu tile accepts one mouse click across its painted surface',
    (tester) async {
      viewport(tester);
      final selections = <MenudeoDestination>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Scaffold(
            body: AreaThemeScope(
              tokens: menudeoAreaTokens,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 320,
                  child: MenudeoNavigationPanel(
                    currentDestination: MenudeoDestination.dashboard,
                    canReturnToDirection: false,
                    canOpenCashTaxonomy: true,
                    onNavigate: selections.add,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(1000, 50));
      addTearDown(mouse.removePointer);
      for (final destination in [
        ...commonDestinations,
        MenudeoDestination.cashTaxonomy,
      ]) {
        for (final edge in ['center', 'top', 'left', 'right', 'bottom']) {
          await mouse.moveTo(const Offset(1000, 50));
          await tester.pumpAndSettle();
          await mouse.moveTo(tester.getCenter(item(destination)));
          await tester.pumpAndSettle();
          final painted = tester.getRect(
            find
                .descendant(
                  of: item(destination),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          final position = switch (edge) {
            'top' => Offset(painted.center.dx, painted.top + 1),
            'left' => Offset(painted.left + 1, painted.center.dy),
            'right' => Offset(painted.right - 1, painted.center.dy),
            'bottom' => Offset(painted.center.dx, painted.bottom - 1),
            _ => painted.center,
          };
          final count = selections.length;
          await mouse.moveTo(position);
          await tester.pump(const Duration(milliseconds: 40));
          await mouse.down(position);
          await tester.pump(const Duration(milliseconds: 60));
          await mouse.up();
          await tester.pumpAndSettle();
          expect(
            selections.length,
            count + 1,
            reason: '${destination.name}: $edge',
          );
          expect(selections.last, destination);
        }
      }
    },
  );

  testWidgets(
    'navigation header accepts one mouse click at its visible edges',
    (tester) async {
      viewport(tester);
      var clicks = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Scaffold(
            body: AreaThemeScope(
              tokens: menudeoAreaTokens,
              child: Center(
                child: MenudeoNavigationButton(
                  isOpen: false,
                  onToggle: () => clicks++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(1200, 50));
      addTearDown(mouse.removePointer);
      final button = find.byType(MenudeoNavigationButton);
      for (final edge in ['top', 'bottom', 'left', 'right', 'text', 'icon']) {
        await mouse.moveTo(const Offset(1200, 50));
        await tester.pumpAndSettle();
        await mouse.moveTo(tester.getCenter(button));
        await tester.pumpAndSettle();
        final painted = tester.getRect(
          find
              .descendant(of: button, matching: find.byType(DecoratedBox))
              .first,
        );
        final point = switch (edge) {
          'top' => Offset(painted.center.dx, painted.top + 1),
          'bottom' => Offset(painted.center.dx, painted.bottom - 1),
          'left' => Offset(painted.left + 1, painted.center.dy),
          'right' => Offset(painted.right - 1, painted.center.dy),
          'text' => tester.getCenter(find.text('Navegación')),
          _ => tester.getCenter(find.byIcon(Icons.menu_rounded)),
        };
        final before = clicks;
        await mouse.moveTo(point);
        await tester.pump(const Duration(milliseconds: 40));
        await mouse.down(point);
        await tester.pump(const Duration(milliseconds: 60));
        await mouse.up();
        await tester.pumpAndSettle();
        expect(clicks, before + 1, reason: edge);
      }
    },
  );

  testWidgets(
    'navigation opens with one mouse click while a text field is focused',
    (tester) async {
      viewport(tester);
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(1200, 50));
      addTearDown(mouse.removePointer);
      for (final entry in pages.entries) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            home: entry.value(),
          ),
        );
        await tester.pumpAndSettle();
        final inputs = find.byType(TextField).hitTestable();
        if (inputs.evaluate().isNotEmpty) {
          await tester.tap(inputs.first);
          await tester.pumpAndSettle();
          expect(FocusManager.instance.primaryFocus, isNotNull);
        }
        final button = find.byType(MenudeoNavigationButton);
        final position = tester.getCenter(button);
        await mouse.moveTo(position);
        await tester.pump(const Duration(milliseconds: 40));
        await mouse.down(position);
        await tester.pump(const Duration(milliseconds: 60));
        await mouse.up();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MenudeoNavigationOverlay>(
                find.byType(MenudeoNavigationOverlay),
              )
              .isOpen,
          true,
          reason: entry.key.name,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'all eight pages keep the same menu, positions and closing behavior',
    (tester) async {
      viewport(tester);
      Map<MenudeoDestination, Rect>? reference;
      Rect? buttonReference;
      for (final entry in pages.entries) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            home: entry.value(),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.byType(MenudeoNavigationButton);
        buttonReference ??= tester.getRect(button);
        expect(tester.getRect(button), buttonReference, reason: entry.key.name);
        await tester.tap(button);
        await tester.pumpAndSettle();
        final positions = {
          for (final d in commonDestinations) d: tester.getRect(item(d)),
        };
        reference ??= positions;
        expect(positions, reference, reason: entry.key.name);
        for (final d in restrictedDestinations) {
          expect(
            item(d),
            findsNothing,
            reason: 'No privilegios nuevos en ${entry.key.name}',
          );
        }
        expect(find.text('Volver a Dirección'), findsNothing);
        if (commonDestinations.contains(entry.key)) {
          expect(
            tester.widget<Semantics>(item(entry.key)).properties.selected,
            true,
          );
          await tester.tap(item(entry.key));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<MenudeoNavigationOverlay>(
                  find.byType(MenudeoNavigationOverlay),
                )
                .isOpen,
            false,
          );
          await tester.tap(button);
          await tester.pumpAndSettle();
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MenudeoNavigationOverlay>(
                find.byType(MenudeoNavigationOverlay),
              )
              .isOpen,
          false,
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(800, 300));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MenudeoNavigationOverlay>(
                find.byType(MenudeoNavigationOverlay),
              )
              .isOpen,
          false,
        );
        expect(tester.takeException(), isNull, reason: entry.key.name);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'one mouse click follows every standard menu destination during opening',
    (tester) async {
      viewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: const MenudeoCashTaxonomyPage(instantOpen: true),
        ),
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(1200, 50));
      addTearDown(mouse.removePointer);
      for (final destination in commonDestinations) {
        var point = tester.getCenter(find.byType(MenudeoNavigationButton));
        await mouse.moveTo(point);
        await mouse.down(point);
        await tester.pump(const Duration(milliseconds: 60));
        await mouse.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        point = tester.getCenter(item(destination));
        await mouse.moveTo(point);
        await mouse.down(point);
        await tester.pump(const Duration(milliseconds: 60));
        await mouse.up();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MenudeoNavigationOverlay>(
                find.byType(MenudeoNavigationOverlay),
              )
              .currentDestination,
          destination,
        );
        expect(
          tester
              .widget<MenudeoNavigationOverlay>(
                find.byType(MenudeoNavigationOverlay),
              )
              .isOpen,
          false,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  test('cash taxonomy admits active Menudeo and Direction profiles only', () {
    for (final role in [
      'menudeo',
      'retail',
      'retail_cashier',
      'caja_menudeo',
      'menudeo_cajero',
      'auxiliar_menudeo',
      'direccion',
    ]) {
      expect(
        canNavigateMenudeo(
          MenudeoDestination.cashTaxonomy,
          AuthResolvedProfile(
            email: 'test@example.invalid',
            role: role,
            isActive: true,
          ),
        ),
        true,
        reason: role,
      );
      expect(
        canNavigateMenudeo(
          MenudeoDestination.cashTaxonomy,
          AuthResolvedProfile(
            email: 'test@example.invalid',
            role: role,
            isActive: false,
          ),
        ),
        false,
        reason: '$role inactive',
      );
    }
    for (final role in ['mayoreo', 'operacion', 'finanzas', 'viewer']) {
      expect(
        canNavigateMenudeo(
          MenudeoDestination.cashTaxonomy,
          AuthResolvedProfile(
            email: 'test@example.invalid',
            role: role,
            isActive: true,
          ),
        ),
        false,
        reason: role,
      );
    }
    expect(canNavigateMenudeo(MenudeoDestination.cashTaxonomy, null), false);
    expect(
      canNavigateMenudeo(
        MenudeoDestination.cashTaxonomy,
        const AuthResolvedProfile(
          email: 'menudeo@dicsamx.com',
          role: 'viewer',
          isActive: true,
        ),
      ),
      true,
    );
  });

  testWidgets(
    'Menudeo user can open cash taxonomy with one click from every area page',
    (tester) async {
      viewport(tester);
      await Supabase.instance.client.auth.setInitialSession(
        jsonEncode({
          'access_token': 'test-token',
          'token_type': 'bearer',
          'refresh_token': 'test-refresh',
          'user': {
            'id': '00000000-0000-4000-8000-000000000001',
            'email': 'cashier@example.invalid',
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );
      try {
        for (final entry in pages.entries) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(fontFamily: 'Roboto'),
              home: entry.value(),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byType(MenudeoNavigationButton));
          await tester.pumpAndSettle();
          expect(
            item(MenudeoDestination.cashTaxonomy),
            findsOneWidget,
            reason: entry.key.name,
          );
          for (final restricted in restrictedDestinations) {
            expect(item(restricted), findsNothing);
          }
          expect(find.text('Volver a Dirección'), findsNothing);
          await tester.ensureVisible(item(MenudeoDestination.cashTaxonomy));
          await tester.tap(item(MenudeoDestination.cashTaxonomy));
          await tester.pumpAndSettle();
          expect(find.byType(MenudeoCashTaxonomyPage), findsOneWidget);
          expect(find.text('Catálogo Efectivo'), findsOneWidget);
          expect(
            tester
                .widget<MenudeoNavigationOverlay>(
                  find.byType(MenudeoNavigationOverlay),
                )
                .isOpen,
            false,
          );
          expect(tester.takeException(), isNull, reason: entry.key.name);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => Supabase.instance.client.auth.signOut());
      }
    },
  );

  test('restricted destinations retain user permissions', () {
    for (final role in ['menudeo', 'mayoreo', 'operacion']) {
      final profile = AuthResolvedProfile(
        email: 'test@example.invalid',
        role: role,
        isActive: true,
      );
      for (final d in commonDestinations) {
        expect(canNavigateMenudeo(d, profile), true);
      }
      for (final d in restrictedDestinations) {
        expect(canNavigateMenudeo(d, profile), false);
        expect(canNavigateMenudeo(d, null), false);
      }
    }
    const direction = AuthResolvedProfile(
      email: 'test@example.invalid',
      role: 'direccion',
      isActive: true,
    );
    for (final d in restrictedDestinations) {
      expect(canNavigateMenudeo(d, direction), true);
    }
  });

  testWidgets(
    'privileged menu stays fixed across active pages and scrolls on small screens',
    (tester) async {
      viewport(tester, size: const Size(800, 720));
      Map<MenudeoDestination, Rect>? reference;
      for (final current in pages.keys) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            home: Scaffold(
              body: AreaThemeScope(
                tokens: menudeoAreaTokens,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 320,
                    child: RepaintBoundary(
                      key: const ValueKey('preview'),
                      child: MenudeoNavigationPanel(
                        currentDestination: current,
                        canReturnToDirection: true,
                        canOpenCashTaxonomy: true,
                        onNavigate: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final positions = {
          for (final d in [
            ...commonDestinations,
            MenudeoDestination.cashTaxonomy,
            ...restrictedDestinations,
          ])
            d: tester.getRect(item(d)),
        };
        reference ??= positions;
        expect(positions, reference, reason: current.name);
        if (const bool.fromEnvironment('MENU_PREVIEW') &&
            current == MenudeoDestination.dashboard) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('preview')),
            );
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/private/tmp/dicsa_menudeo_navigation/menu.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(item(MenudeoDestination.operation));
        await tester.pumpAndSettle();
        expect(
          item(MenudeoDestination.operation).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );
}
