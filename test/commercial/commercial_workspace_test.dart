import 'dart:convert';
import 'dart:io';
import 'package:dicsa_operacion/app/commercial/commercial_account_activity.dart';
import 'package:dicsa_operacion/app/commercial/commercial_development_dashboard_page.dart';
import 'package:dicsa_operacion/app/commercial/commercial_directory_page.dart';
import 'package:dicsa_operacion/app/commercial/commercial_quotes.dart';
import 'package:dicsa_operacion/app/commercial/commercial_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = <String, List<Map<String, dynamic>>>{};
  final writes = <http.Request>[];
  final reads = <http.Request>[];
  var idCounter = 0;
  setUpAll(() async {
    final config = File('.dart_tool/package_config.json');
    final packages =
        jsonDecode(await config.readAsString())['packages'] as List;
    final root = config.absolute.uri.resolve(
      '${packages.singleWhere((row) => row['name'] == 'flutter')['rootUri']}/',
    );
    for (final font in ['Roboto', 'MaterialIcons']) {
      final file = File.fromUri(
        root.resolve(
          '../../bin/cache/artifacts/material_fonts/${font == 'Roboto' ? 'Roboto-Regular.ttf' : 'MaterialIcons-Regular.otf'}',
        ),
      );
      await (FontLoader(
        font,
      )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
    }
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://commercial-test.invalid',
      anonKey: 'test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        final table = request.url.pathSegments.last;
        final rows = db.putIfAbsent(table, () => []);
        final params = request.url.queryParameters;
        bool matches(Map<String, dynamic> row) {
          for (final p in params.entries) {
            if (p.value.startsWith('eq.') &&
                row[p.key]?.toString() != p.value.substring(3)) {
              return false;
            }
            if (p.value.startsWith('gte.') &&
                (row[p.key]?.toString() ?? '').compareTo(p.value.substring(4)) <
                    0) {
              return false;
            }
          }
          return true;
        }

        var response = <Map<String, dynamic>>[];
        if (request.method == 'GET') {
          reads.add(request);
          response = rows
              .where(matches)
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
          response = response
              .skip(int.tryParse(params['offset'] ?? '') ?? 0)
              .take(int.tryParse(params['limit'] ?? '') ?? 1000)
              .toList();
          final select = params['select'];
          if (select != null && select != '*') {
            response = response
                .map(
                  (row) => {
                    for (final field in select.split(',')) field: row[field],
                  },
                )
                .toList();
          }
        } else if (request.method == 'POST') {
          writes.add(request);
          final body = jsonDecode(request.body);
          for (final data in body is List ? body : [body]) {
            final row = Map<String, dynamic>.from(data as Map);
            row['id'] ??=
                '00000000-0000-0000-0000-${(++idCounter).toString().padLeft(12, '0')}';
            final index = rows.indexWhere((old) => old['id'] == row['id']);
            if (index >= 0) {
              rows[index] = {...rows[index], ...row};
              response.add(rows[index]);
            } else {
              rows.add(row);
              response.add(row);
            }
          }
        } else if (request.method == 'PATCH') {
          writes.add(request);
          final patch = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          for (final row in rows.where(matches)) {
            row.addAll(patch);
            response.add(row);
          }
        } else if (request.method == 'DELETE') {
          fail('Commercial workspace must not delete operational rows');
        }
        final single =
            request.headers['accept']?.contains('vnd.pgrst.object') ?? false;
        return http.Response(
          jsonEncode(single ? response.firstOrNull : response),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    db.clear();
    writes.clear();
    reads.clear();
    idCounter = 100;
    final today = DateUtils.dateOnly(DateTime.now());
    db.addAll({
      'v_commercial_unified_counterparties': [
        {
          'source_area': 'mayoreo_ventas',
          'source_record_id': 'client-a',
          'channel': 'mayoreo',
          'flow': 'sale',
          'name': 'ACEROS CLIENTE',
          'kind': 'customer',
          'active': true,
          'counterparty_business_type': 'cliente_final',
          'counterparty_business_group': 'mayoreo_cliente',
        },
        {
          'source_area': 'menudeo',
          'source_record_id': 'client-a',
          'channel': 'menudeo',
          'flow': 'sale',
          'name': 'OTRO CLIENTE',
          'kind': 'customer',
          'active': true,
          'counterparty_business_type': 'cliente_final',
          'counterparty_business_group': 'menudeo_cliente',
        },
        {
          'source_area': 'mayoreo_compras',
          'source_record_id': 'provider-a',
          'channel': 'mayoreo',
          'flow': 'purchase',
          'name': 'METALES PROVEEDOR',
          'kind': 'supplier',
          'active': true,
          'counterparty_business_type': 'proveedor_grande',
          'counterparty_business_group': 'mayoreo_proveedor',
        },
      ],
      'compras_material_catalog': [
        {'id': 'material-a', 'name': 'ALUMINIO', 'unit': 'KG'},
      ],
      'compras_tickets': [
        {
          'id': 'buy-a',
          'provider_id': 'provider-a',
          'ticket_date': today.toIso8601String(),
          'material_id': 'material-a',
          'material_name_snapshot': 'ALUMINIO',
          'payable_weight': 50,
          'price': 3,
          'premium': 1,
          'amount': 200,
        },
        {
          'id': 'buy-b',
          'provider_id': 'provider-a',
          'ticket_date': today.toIso8601String(),
          'material_id': 'material-a',
          'material_name_snapshot': 'ALUMINIO',
          'payable_weight': 150,
          'price': 6,
          'premium': 0,
          'amount': 900,
        },
        {
          'id': 'buy-other',
          'provider_id': 'provider-b',
          'ticket_date': today.toIso8601String(),
          'material_id': 'material-a',
          'material_name_snapshot': 'ALUMINIO',
          'payable_weight': 9000,
          'price': 9999,
          'premium': 0,
          'amount': 89991000,
        },
      ],
      'commercial_accounts': [
        {
          'id': 'lead-id',
          'display_name': 'PROSPECTO NUEVO',
          'kind': 'prospect',
          'primary_channel': 'mayoreo',
          'status': 'prospecto',
          'priority': 'alta',
          'is_active': true,
        },
      ],
      'commercial_follow_ups': [
        {
          'id': 'follow-id',
          'account_id': 'lead-id',
          'interaction_at': today
              .subtract(const Duration(days: 3))
              .toIso8601String(),
          'interaction_type': 'llamada',
          'summary': 'Enviar precios',
          'next_action': 'Llamar al comprador',
          'next_follow_up_at': today.toIso8601String(),
          'status': 'abierto',
          'contact_id': 'contact-preserve',
          'material_interest_snapshot': 'CARTON',
        },
      ],
      'mayoreo_material_catalog': [
        {'id': 'material-a', 'name': 'ALUMINIO', 'unit': 'KG'},
      ],
      'mayoreo_sales_reports': [
        {
          'id': 'sale-a',
          'ticket': '1001',
          'remision': 'R-10',
          'client_id': 'client-a',
          'sale_date': today.toIso8601String(),
          'material_id': 'material-a',
          'material_name_snapshot': 'ALUMINIO',
          'approved_weight': 100,
          'approved_price': 2,
          'approved_amount': 200,
        },
        {
          'id': 'sale-b',
          'ticket': '1002',
          'remision': 'R-11',
          'client_id': 'client-a',
          'sale_date': today
              .subtract(const Duration(days: 30))
              .toIso8601String(),
          'material_id': 'material-a',
          'material_name_snapshot': 'ALUMINIO',
          'approved_weight': 300,
          'approved_price': 4,
          'approved_amount': 1200,
        },
        {
          'id': 'pending',
          'ticket': '1003',
          'remision': 'R-12',
          'client_id': 'client-a',
          'sale_date': today.toIso8601String(),
          'material_id': 'material-a',
          'material_name_snapshot': 'ALUMINIO',
          'exit_weight': 10,
          'price_snapshot': 50,
        },
        {
          'id': 'cancelled',
          'ticket': '1004',
          'client_id': 'client-a',
          'sale_date': today.toIso8601String(),
          'approved_weight': 200,
          'approved_price': 10,
          'approved_amount': 2000,
        },
        {
          'id': 'other',
          'ticket': '1005',
          'client_id': 'client-b',
          'sale_date': today.toIso8601String(),
          'approved_weight': 1,
          'approved_price': 9999,
          'approved_amount': 9999,
        },
      ],
      'mayoreo_accounts': [
        {'id': 'cancelled', 'client_id': 'client-a', 'status': 'cancelada'},
      ],
      'men_tickets': [
        {
          'id': 'retail-sale',
          'ticket_number': 'M-1',
          'counterparty_id': 'client-a',
          'direction': 'sale',
          'ticket_date': today.toIso8601String(),
          'material_label_snapshot': 'CARTON',
          'payable_weight': 5,
          'price_at_entry': 10,
          'premium_per_kg': 2,
          'amount_total': 60,
        },
        {
          'id': 'purchase',
          'counterparty_id': 'client-a',
          'direction': 'purchase',
          'ticket_date': today.toIso8601String(),
          'amount_total': 5000,
          'material_label_snapshot': 'CARTON',
          'payable_weight': 25,
          'price_at_entry': 4,
          'premium_per_kg': 0,
        },
      ],
    });
  });
  Future<void> open(WidgetTester tester, {Widget? page}) async {
    tester.view.physicalSize = const Size(1800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: page ?? const CommercialDirectoryPage(instantOpen: true),
      ),
    );
    await tester.pumpAndSettle();
  }

  test(
    'lead alerts cover overdue, today, missing dates and exclude completed/future/closed leads',
    () async {
      final bundle = await CommercialStore.loadDirectory();
      expect(bundle.leadAlerts().single.label, 'Seguimiento para hoy');
      db['commercial_follow_ups']!.single['next_follow_up_at'] = DateTime.now()
          .subtract(const Duration(days: 5))
          .toIso8601String();
      expect(
        (await CommercialStore.loadDirectory()).leadAlerts().single.label,
        'Seguimiento vencido',
      );
      db['commercial_follow_ups']!.single['status'] = 'hecho';
      expect(
        (await CommercialStore.loadDirectory()).leadAlerts().single.label,
        'Sin próximo seguimiento',
      );
      db['commercial_follow_ups']!.single['status'] = 'pospuesto';
      db['commercial_follow_ups']!.single['next_follow_up_at'] = DateTime.now()
          .add(const Duration(days: 3))
          .toIso8601String();
      expect((await CommercialStore.loadDirectory()).leadAlerts(), isEmpty);
      db['commercial_accounts']!.single['status'] = 'cerrado';
      db['commercial_follow_ups']!.single['next_follow_up_at'] = DateTime.now()
          .subtract(const Duration(days: 5))
          .toIso8601String();
      expect((await CommercialStore.loadDirectory()).leadAlerts(), isEmpty);
    },
  );
  test(
    'trade averages isolate account, channel and flow and exclude unapproved/cancelled sales',
    () async {
      final bundle = await CommercialStore.loadDirectory();
      final sales = await CommercialActivityStore.load(
        bundle.accounts.singleWhere(
          (row) => row.sourceArea == 'mayoreo_ventas',
        ),
        flow: CommercialTradeFlow.sale,
      );
      final buys = await CommercialActivityStore.load(
        bundle.accounts.singleWhere(
          (row) => row.sourceArea == 'mayoreo_compras',
        ),
        flow: CommercialTradeFlow.purchase,
      );
      final retail = bundle.accounts.singleWhere(
        (row) => row.sourceArea == 'menudeo',
      );
      final retailSales = await CommercialActivityStore.load(
        retail,
        flow: CommercialTradeFlow.sale,
      );
      final retailBuys = await CommercialActivityStore.load(
        retail,
        flow: CommercialTradeFlow.purchase,
      );
      final sellAverage = commercialMaterialAverages(sales, days: 90).single;
      final buyAverage = commercialMaterialAverages(buys, days: 90).single;
      expect(sales, hasLength(2));
      expect(sellAverage.averageQuantity, 200);
      expect(sellAverage.averagePrice, 3.5);
      expect(buyAverage.averageQuantity, 100);
      expect(buyAverage.averagePrice, 5.5);
      expect(
        commercialMaterialAverages(retailSales, days: 90).single.averagePrice,
        12,
      );
      expect(
        commercialMaterialAverages(retailBuys, days: 90).single.averagePrice,
        4,
      );
      expect(retailBuys.single.quantity, 25);
      expect(
        commercialMaterialAverages(sales, days: 30).single.averageQuantity,
        100,
      );
      expect(
        await CommercialActivityStore.load(
          bundle.accounts.singleWhere(
            (row) => row.sourceArea == 'mayoreo_compras',
          ),
          flow: CommercialTradeFlow.sale,
        ),
        isEmpty,
      );
      for (final request in reads.where(
        (request) => [
          'men_tickets',
          'compras_tickets',
          'mayoreo_sales_reports',
        ].contains(request.url.pathSegments.last),
      )) {
        final fields = request.url.queryParameters['select']!.split(',');
        expect(fields, isNot(contains('*')));
        expect(fields, isNot(contains('amount')));
        expect(fields, isNot(contains('amount_total')));
        expect(fields, isNot(contains('approved_amount')));
        expect(fields, isNot(contains('ticket_number')));
        expect(fields, isNot(contains('remision')));
      }
      expect(writes, isEmpty);
    },
  );
  test(
    'averages keep units apart, respect the period and omit invalid/future operations',
    () {
      final now = DateTime(2026, 10, 12);
      CommercialTradeSample sample(
        String unit,
        double quantity,
        double price,
        DateTime date,
      ) => CommercialTradeSample(
        material: 'TARIMA',
        materialId: 'pallet',
        unit: unit,
        quantity: quantity,
        price: price,
        date: date,
      );
      final rows = [
        sample('PZA', 10, 50, now),
        sample('KG', 20, 1, now),
        sample('KG', 0, 999, now),
        sample('KG', 1000, 999, now.subtract(const Duration(days: 31))),
        sample('KG', 1000, 999, now.add(const Duration(days: 1))),
      ];
      final averages = commercialMaterialAverages(rows, days: 30, now: now);
      expect(averages, hasLength(2));
      expect(averages.map((row) => row.averageQuantity), containsAll([10, 20]));
      expect(averages.map((row) => row.averagePrice), containsAll([50, 1]));
      expect(averages.first.unit, 'KG');
    },
  );
  test(
    'quote validates dates and values, preserves accepted status after expiry and updates without duplication',
    () async {
      final date = DateTime(2026, 10, 12);
      CommercialQuote quote({
        String? id,
        double quantity = 10,
        DateTime? until,
        String status = 'enviada',
      }) => CommercialQuote(
        id: id,
        accountId: 'lead-id',
        status: status,
        notes: 'Entrega en planta',
        date: date,
        validUntil: until ?? DateTime(2026, 10, 20),
        lines: [
          CommercialQuoteLine(
            material: 'ALUMINIO',
            unit: 'KG',
            quantity: quantity,
            price: 12.5,
          ),
        ],
      );
      await CommercialQuotesStore.save(quote());
      final saved = (await CommercialQuotesStore.load('lead-id')).single;
      expect(saved.total, 125);
      expect(saved.expired(DateTime(2026, 10, 20)), isFalse);
      expect(saved.expired(DateTime(2026, 10, 21)), isTrue);
      await CommercialQuotesStore.save(quote(id: saved.id, status: 'aceptada'));
      expect(db['commercial_quotes'], hasLength(1));
      expect(
        (await CommercialQuotesStore.load(
          'lead-id',
        )).single.expired(DateTime(2026, 10, 21)),
        isFalse,
      );
      await expectLater(
        CommercialQuotesStore.save(quote(quantity: 0)),
        throwsArgumentError,
      );
      await expectLater(
        CommercialQuotesStore.save(
          quote(until: date.subtract(const Duration(days: 1))),
        ),
        throwsArgumentError,
      );
      expect(db['commercial_quotes'], hasLength(1));
    },
  );
  test(
    'editing and completing follow-up preserve its contact and commercial context',
    () async {
      final row = (await CommercialStore.loadDirectory())
          .followUpsByAccountId['lead-id']!
          .single;
      await CommercialStore.saveFollowUp(
        followUpId: row.id,
        accountId: row.accountId,
        interactionAt: row.interactionAt!,
        interactionType: row.interactionType,
        summary: 'Contacto actualizado',
        nextAction: 'Visitar',
        nextFollowUpAt: row.nextFollowUpAt,
        status: 'abierto',
      );
      await CommercialStore.completeFollowUp(row);
      expect(db['commercial_follow_ups']!.single['status'], 'hecho');
      expect(
        db['commercial_follow_ups']!.single['contact_id'],
        'contact-preserve',
      );
      expect(
        db['commercial_follow_ups']!.single['material_interest_snapshot'],
        'CARTON',
      );
    },
  );
  testWidgets(
    'directory shows only material averages for sales and purchases with one click',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('ACEROS CLIENTE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compras y ventas'));
      await tester.pumpAndSettle();
      expect(find.text('Material'), findsOneWidget);
      expect(find.text('Peso promedio'), findsOneWidget);
      expect(find.text('Precio promedio'), findsOneWidget);
      expect(find.text('200.00 KG'), findsOneWidget);
      expect(find.text(r'$3.50 / KG'), findsOneWidget);
      expect(find.textContaining('1,400'), findsNothing);
      expect(find.text('Importe'), findsNothing);
      expect(find.textContaining('R-10'), findsNothing);
      expect(find.textContaining('Estimada'), findsNothing);
      await tester.tap(find.text('OTRO CLIENTE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compras y ventas'));
      await tester.pumpAndSettle();
      expect(find.text(r'$12.00 / KG'), findsOneWidget);
      await tester.tap(find.text('Compras'));
      await tester.pumpAndSettle();
      expect(find.text('25.00 KG'), findsOneWidget);
      expect(find.text(r'$4.00 / KG'), findsOneWidget);
      expect(find.text(r'$12.00 / KG'), findsNothing);
      await tester.tap(find.text('METALES PROVEEDOR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compras y ventas'));
      await tester.pumpAndSettle();
      expect(find.text('100.00 KG'), findsOneWidget);
      expect(find.text(r'$5.50 / KG'), findsOneWidget);
      expect(writes, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'creates account quotation, changes status and keeps operational sources read-only',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('ACEROS CLIENTE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cotizaciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva cotización'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cotización'));
      await tester.pumpAndSettle();
      expect(find.text('Captura el material'), findsOneWidget);
      expect(writes, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Material'),
        'ALUMINIO',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Cantidad'),
        '100',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Precio unitario'),
        '20',
      );
      await tester.tap(find.text('Guardar cotización'));
      await tester.pumpAndSettle();
      expect(db['commercial_quotes'], hasLength(1));
      expect(find.textContaining('No se pudo guardar'), findsNothing);
      expect(find.text('Cotización guardada.'), findsOneWidget);
      final overlay = db['commercial_accounts']!.singleWhere(
        (row) => row['source_area'] == 'mayoreo_ventas',
      );
      expect(db['commercial_quotes']!.single['account_id'], overlay['id']);
      expect(find.text('Cotizaciones'), findsOneWidget);
      await tester.tap(find.textContaining('Borrador ·'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar cotización'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Estatus'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptada').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cotización'));
      await tester.pumpAndSettle();
      expect(db['commercial_quotes']!.single['status'], 'aceptada');
      expect(db['commercial_quotes'], hasLength(1));
      expect(
        writes.every(
          (request) => [
            'commercial_quotes',
            'commercial_accounts',
          ].contains(request.url.pathSegments.last),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'quotation supports multiple materials and pickers in a smaller window',
    (tester) async {
      await open(tester);
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cotizaciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva cotización'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Material'),
        'ALUMINIO',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Cantidad'),
        '10',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Precio unitario'),
        '20',
      );
      await tester.tap(find.byTooltip('Elegir material del catálogo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('ALUMINIO'), findsOneWidget);
      await tester.tap(find.textContaining('Vigencia:'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(CommercialQuoteDialog), findsOneWidget);
      await tester.tap(find.text('Agregar material'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Material').last,
        'TARIMA',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Cantidad').last,
        '5',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Precio unitario').last,
        '50',
      );
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Unidad').last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('PZA').last);
      await tester.pumpAndSettle();
      expect(find.text('Total: \$450.00'), findsOneWidget);
      await tester.tap(find.text('Guardar cotización'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo guardar'), findsNothing);
      final saved = (await CommercialQuotesStore.load('lead-id')).single;
      expect(saved.lines, hasLength(2));
      expect(saved.lines.last.unit, 'PZA');
      expect(saved.total, 450);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'quotation unit picker fits every unit with enlarged desktop text',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final account = (await CommercialStore.loadDirectory()).accounts.first;
      for (final scale in [1.0, 1.5]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              platform: TargetPlatform.macOS,
              fontFamily: 'Roboto',
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => CommercialQuoteDialog(account: account),
                  ),
                  child: const Text('Abrir cotización'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir cotización'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final field = find.widgetWithText(
          DropdownButtonFormField<String>,
          'Unidad',
        );
        for (final unit in ['PZA', 'TON', 'KG']) {
          await tester.tap(field);
          await tester.pumpAndSettle();
          await tester.tap(find.text(unit).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final text = tester.getRect(
            find.descendant(of: field, matching: find.text(unit)),
          );
          final bounds = tester.getRect(field);
          expect(text.left, greaterThanOrEqualTo(bounds.left));
          expect(text.right, lessThanOrEqualTo(bounds.right));
        }
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
  testWidgets(
    'dashboard lead alert opens the correct account and allows completion',
    (tester) async {
      await open(
        tester,
        page: const CommercialDevelopmentDashboardPage(instantOpen: true),
      );
      expect(find.text('Seguimiento de prospectos'), findsOneWidget);
      expect(find.text('Compras y ventas'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
      expect(
        reads.any(
          (request) =>
              request.url.pathSegments.last == 'v_commercial_market_events',
        ),
        isFalse,
      );
      await tester.ensureVisible(find.text('PROSPECTO NUEVO'));
      await tester.tap(find.text('PROSPECTO NUEVO'));
      await tester.pumpAndSettle();
      expect(find.text('Marcar realizado'), findsOneWidget);
      await tester.tap(find.text('Marcar realizado'));
      await tester.pumpAndSettle();
      expect(db['commercial_follow_ups']!.single['status'], 'hecho');
      expect(find.text('Marcar realizado'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
