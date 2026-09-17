import 'dart:convert';
import 'dart:io';

import 'package:dicsa_operacion/app/mayoreo/mayoreo_accounts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final accounts = <Map<String, dynamic>>[];
  final writes = <http.Request>[];

  setUpAll(() async {
    final config = File('.dart_tool/package_config.json');
    final packages =
        jsonDecode(await config.readAsString())['packages'] as List;
    final flutter = packages.singleWhere((row) => row['name'] == 'flutter');
    final root = config.absolute.uri.resolve('${flutter['rootUri']}/');
    final font = File.fromUri(
      root.resolve(
        '../../bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      ),
    );
    await (FontLoader(
      'Roboto',
    )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
    // Explicit styles in the grid use Flutter test's default family (Ahem).
    // Render those with the app's real font as well.
    await (FontLoader(
      'Ahem',
    )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
    final icons = File.fromUri(
      root.resolve(
        '../../bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    );
    await (FontLoader(
      'MaterialIcons',
    )..addFont(icons.readAsBytes().then(ByteData.sublistView))).load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://mayoreo-accounts-test.invalid',
      anonKey: 'test-only-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        if (request.method != 'GET') writes.add(request);
        final table = request.url.pathSegments.last;
        final rows =
            table == 'mayoreo_accounts' || table == 'mayoreo_sales_reports'
            ? accounts
            : const [];
        return http.Response(
          jsonEncode(rows),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    accounts.clear();
    writes.clear();
  });

  Future<void> openPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: const MayoreoAccountsPage(instantOpen: true),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectPending(String value) {
    final card = find.ancestor(
      of: find.text('TOTAL PENDIENTE'),
      matching: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_AccountsMetricCard',
      ),
    );
    expect(
      find.descendant(of: card, matching: find.text(value)),
      findsOneWidget,
    );
  }

  testWidgets(
    'redeemed checks are excluded regardless of missing evidence or paid amount',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      accounts.addAll([
        _account(
          'redeemed-empty',
          'CANJEADO SIN DATOS',
          'chequeCanjeado',
          2000,
        ),
        _account(
          'redeemed-partial',
          'CANJEADO PARCIAL',
          'chequeCanjeado',
          3000,
          paid: 500,
        ),
        _account('palomar', 'EL PALOMAR', 'chequeCanjeado', 4000),
        _account('pending', 'CHEQUE POR COBRAR', 'pendienteCheque', 400),
        _account(
          'received',
          'CHEQUE RECIBIDO CLIENTE',
          'chequeRecibido',
          600,
          paid: 200,
        ),
        _account(
          'invoice',
          'FACTURA ABIERTA',
          'pagoParcial',
          1000,
          paid: 100,
          operation: 'factura',
        ),
        _account('cancelled', 'CUENTA CANCELADA', 'cancelada', 800),
      ]);
      await openPage(tester);
      expectPending(r'$1,700');
      expect(find.text('CANJEADO SIN DATOS'), findsOneWidget);
      expect(find.text('CANJEADO PARCIAL'), findsOneWidget);
      expect(find.text('EL PALOMAR'), findsOneWidget);

      await tester.tap(find.text('TOTAL PENDIENTE'));
      await tester.pumpAndSettle();
      expect(find.text('CANJEADO SIN DATOS'), findsNothing);
      expect(find.text('CANJEADO PARCIAL'), findsNothing);
      expect(find.text('EL PALOMAR'), findsNothing);
      expect(find.text('CUENTA CANCELADA'), findsNothing);
      expect(find.text('CHEQUE POR COBRAR'), findsOneWidget);
      expect(find.text('CHEQUE RECIBIDO CLIENTE'), findsOneWidget);
      expect(find.text('FACTURA ABIERTA'), findsOneWidget);
      expectPending(r'$1,700');
      expect(writes, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'marking a check redeemed removes it on reload even without cheque details',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      accounts.add(
        _account('check', 'CLIENTE CHEQUE', 'chequePendienteCanje', 1500),
      );
      await openPage(tester);
      expectPending(r'$1,500');
      await tester.pumpWidget(const SizedBox.shrink());
      accounts.single['status'] = 'chequeCanjeado';
      await openPage(tester);
      expectPending(r'$0');
      await tester.tap(find.text('TOTAL PENDIENTE'));
      await tester.pumpAndSettle();
      expect(find.text('CLIENTE CHEQUE'), findsNothing);
      expect(accounts.single['paid_amount'], 0);
      expect(writes, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}

Map<String, dynamic> _account(
  String id,
  String client,
  String status,
  double amount, {
  double paid = 0,
  String operation = 'cheque',
}) => {
  'id': id,
  'ticket': id,
  'sale_date': '2026-09-17',
  'client_id': 'client-$id',
  'client_name_snapshot': client,
  'material_name_snapshot': 'CARTON',
  'approved_weight': 100,
  'approved_price': amount / 100,
  'approved_amount': amount,
  'operation_type': operation,
  'status': status,
  'paid_amount': paid,
  'document_number': '',
  'document_date': null,
  'settlement_date': null,
};
