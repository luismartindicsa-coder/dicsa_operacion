import 'dart:convert';
import 'dart:io';

import 'package:dicsa_operacion/app/compras/compras_tickets_store.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_provider_accounts_page.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_provider_accounts_store.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_fixed_payments_store.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_provider_account_balance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final database = <String, List<Map<String, dynamic>>>{};
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
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://provider-accounts-test.invalid',
      anonKey: 'test-only-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/rpc/app_commit_preserving_data')) {
          writes.add(request);
          final body = jsonDecode(request.body) as Map;
          final result = <Map<String, dynamic>>[];
          for (final raw in body['p_operations'] as List) {
            final op = Map<String, dynamic>.from(raw as Map);
            final rows = database.putIfAbsent(op['table'].toString(), () => []);
            final index = rows.indexWhere((r) => r['id'] == op['id']);
            final before = index < 0 ? <String, dynamic>{} : rows[index];
            final next = <String, dynamic>{...before, ...?op['values']};
            if (index >= 0) rows.removeAt(index);
            if (op['action'] != 'delete') rows.add(next);
            result.add({
              'table': op['table'],
              'action': op['action'],
              'row': next,
            });
          }
          return http.Response(
            jsonEncode(result),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        final table = request.url.pathSegments.last;
        final rows = database.putIfAbsent(table, () => []);
        final params = request.url.queryParameters;
        bool matches(Map<String, dynamic> row) {
          for (final entry in params.entries) {
            if (entry.value.startsWith('eq.') &&
                row[entry.key]?.toString() != entry.value.substring(3) &&
                !(row[entry.key] is num &&
                    row[entry.key] == num.tryParse(entry.value.substring(3)))) {
              return false;
            }
            if (entry.value.startsWith('in.(') &&
                !entry.value
                    .substring(4, entry.value.length - 1)
                    .split(',')
                    .map((value) => value.replaceAll('"', ''))
                    .contains(row[entry.key]?.toString())) {
              return false;
            }
          }
          return true;
        }

        if (request.method == 'PATCH') {
          writes.add(request);
          final patch = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          final updated = rows.where(matches).toList();
          for (final row in updated) {
            row.addAll(patch);
          }
          return http.Response(
            jsonEncode(updated),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'POST') {
          writes.add(request);
          final body = jsonDecode(request.body);
          final entries = body is List ? body : [body];
          final key = params['on_conflict'] ?? 'id';
          for (final entry in entries) {
            final row = Map<String, dynamic>.from(entry as Map);
            rows.removeWhere((old) => old[key] == row[key]);
            rows.add(row);
          }
        } else if (request.method == 'DELETE') {
          writes.add(request);
          rows.removeWhere(matches);
        }
        return http.Response(
          jsonEncode(
            request.method == 'GET'
                ? rows
                      .where(matches)
                      .skip(int.tryParse(params['offset'] ?? '') ?? 0)
                      .take(int.tryParse(params['limit'] ?? '') ?? 1000)
                      .toList()
                : [],
          ),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  setUp(() {
    writes.clear();
    database.clear();
    database.addAll({
      'finanzas_catalog_companies': [
        {
          'id': 'compras_provider',
          'name': 'PROVEEDOR SIN FACTURA',
          'source': 'COMPRAS',
          'linked_name': 'PROVEEDOR SIN FACTURA',
          'is_active': true,
        },
      ],
      'compras_counterparties': [
        {'id': 'provider', 'name': 'PROVEEDOR SIN FACTURA', 'is_active': true},
      ],
      'mayoreo_counterparties': [
        {'id': 'unused', 'name': 'UNUSED', 'is_active': false},
      ],
      'compras_tickets': [
        {
          'id': 'ticket',
          'provider_id': 'provider',
          'provider_name_snapshot': 'PROVEEDOR SIN FACTURA',
          'ticket_number': '1001',
          'ticket_date': '2026-09-10',
          'amount': 1000,
          'factura_status': 'SIN_FACTURA',
          'pago_status': 'PENDIENTE_DE_PAGO',
        },
      ],
    });
  });

  Future<void> openPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: const FinanzasProviderAccountsPage(instantOpen: true),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectBalance(String value) {
    for (final label in ['Por pagar', 'Saldo abierto']) {
      final card = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget.runtimeType.toString() ==
              (label == 'Por pagar'
                  ? '_ProviderAccountListCard'
                  : '_SummaryMetricCard'),
        ),
      );
      expect(
        find.descendant(of: card, matching: find.text(value)),
        findsOneWidget,
        reason: label,
      );
    }
  }

  testWidgets(
    'saves signed adjustment, refreshes totals and reloads persisted correction',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openPage(tester);
      expectBalance(r'$1,000.00');
      expect(find.textContaining('Tickets sin facturar 1'), findsOneWidget);
      await tester.tap(find.text('Movimientos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar movimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abono'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajuste'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Monto'),
        '-250.25',
      );
      await tester.pump();
      await tester.tap(find.text('Guardar movimiento'));
      await tester.pumpAndSettle();
      expect(database['compras_provider_movements']!.single['amount'], -250.25);
      expect(
        database['compras_provider_movements']!.single['movement_type'],
        'AJUSTE',
      );
      expectBalance(r'$749.75');
      expect(find.text('Ajustes y cargos'), findsOneWidget);
      expect(
        writes.where(
          (request) =>
              request.url.path.endsWith('/compras_tickets') ||
              request.url.path.endsWith('/compras_ticket_payment_applications'),
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);

      // Editing must replace the same movement, not accumulate another correction.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Monto'), '100');
      await tester.pump();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(database['compras_provider_movements'], hasLength(1));
      expectBalance(r'$1,100.00');
      await tester.pumpWidget(const SizedBox.shrink());
      await openPage(tester);
      expectBalance(r'$1,100.00');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('negative abonos and zero adjustments stay disabled', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openPage(tester);
    await tester.tap(find.text('Movimientos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar movimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '-100');
    await tester.pump();
    await tester.tap(find.text('Guardar movimiento'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(database['compras_provider_movements'], isEmpty);
    await tester.tap(find.text('Abono'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajuste'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '0');
    await tester.pump();
    await tester.tap(find.text('Guardar movimiento'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(database['compras_provider_movements'], isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'finds invoice folios and corrects paid total and notes without reopening debt',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      database['finanzas_supplier_invoices'] = [
        {
          'id': 'paid-invoice',
          'provider_id': 'compras_provider',
          'provider_name_snapshot': 'PROVEEDOR SIN FACTURA',
          'invoice_folio': 'ABC-9052',
          'origin_type': 'MANUAL',
          'invoice_date': '2026-09-12',
          'due_date': '2026-09-15',
          'total_amount': 1000,
          'balance_amount': 0,
          'status': 'PAGADA',
          'notes': 'Comentario original',
        },
        {
          'id': 'other-invoice',
          'provider_id': 'compras_provider',
          'invoice_folio': 'OTRA-123',
          'total_amount': 500,
          'balance_amount': 500,
          'invoice_date': '2026-09-13',
          'status': 'PENDIENTE',
        },
      ];
      database['finanzas_bank_movements'] = [
        {
          'id': 'payment',
          'linked_supplier_invoice_id': 'paid-invoice',
          'debit_amount': 1000,
          'applied_supplier_amount': 1000,
          'reference': 'ABC-9052',
          'source_type': 'COMPRA_FACTURA',
        },
      ];
      await openPage(tester);
      final search = find.widgetWithText(
        TextField,
        'Buscar proveedor o factura',
      );
      await tester.enterText(search, 'abc-9052');
      await tester.pumpAndSettle();
      expect(find.text('ABC-9052'), findsOneWidget);
      expect(find.text('OTRA-123'), findsNothing);
      await tester.tap(find.byTooltip('Editar folio, total y comentarios'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('conservará su estado Pagada'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Total de la factura'),
        '1250.75',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Comentarios'),
        'Corrección solicitada',
      );
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      final saved = database['finanzas_supplier_invoices']!.firstWhere(
        (r) => r['id'] == 'paid-invoice',
      );
      expect(saved['total_amount'], 1250.75);
      expect(saved['notes'], 'Corrección solicitada');
      expect(saved['status'], 'PAGADA');
      expect(saved['balance_amount'], 0);
      expect(database['finanzas_bank_movements']!.single['debit_amount'], 1000);
      expect(
        effectiveSupplierInvoiceBalance(
          FinanzasSupplierInvoiceRecord.fromRemoteRow(saved),
          {'paid-invoice': 1000},
        ),
        0,
      );
      expect(
        writes.where((r) => r.url.path.endsWith('/finanzas_bank_movements')),
        isEmpty,
      );
      await tester.enterText(search, 'no-existe');
      await tester.pumpAndSettle();
      expect(find.text('ABC-9052'), findsNothing);
      await tester.enterText(search, 'proveedor sin');
      await tester.pumpAndSettle();
      expect(find.text('ABC-9052'), findsOneWidget);
      expect(find.text('OTRA-123'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'corrections keep settlement, synchronize folio and reject stale writes',
    () async {
      final row = FinanzasSupplierInvoiceRecord.fromRemoteRow({
        'id': 'invoice',
        'invoice_folio': 'OLD',
        'total_amount': 100,
        'balance_amount': 0,
        'status': 'PAGADA',
        'notes': 'old',
      });
      database['finanzas_supplier_invoices'] = [row.toUpsertJson()];
      database['finanzas_bank_movements'] = [
        {
          'id': 'bank',
          'linked_supplier_invoice_id': 'invoice',
          'reference': 'OLD',
          'amount': 100,
        },
      ];
      await FinanzasProviderAccountsStore.correctInvoice(
        invoice: row,
        folio: 'NEW',
        totalAmount: 80,
        notes: 'corrected',
      );
      expect(
        database['finanzas_supplier_invoices']!.single['balance_amount'],
        0,
      );
      expect(
        database['finanzas_supplier_invoices']!.single['status'],
        'PAGADA',
      );
      expect(database['finanzas_bank_movements']!.single['reference'], 'NEW');
      expect(database['finanzas_bank_movements']!.single['amount'], 100);
      await expectLater(
        FinanzasProviderAccountsStore.correctInvoice(
          invoice: row,
          folio: 'STALE',
          totalAmount: 120,
          notes: '',
        ),
        throwsStateError,
      );
      expect(
        database['finanzas_supplier_invoices']!.single['total_amount'],
        80,
      );
    },
  );

  test(
    'history loads invoices and fixed payments beyond the server page limit',
    () async {
      database['finanzas_supplier_invoices'] = [
        for (var i = 0; i < 1005; i++)
          {'id': 'invoice-$i', 'total_amount': 10, 'balance_amount': 10},
      ];
      database['finanzas_fixed_payments'] = [
        for (var i = 0; i < 1005; i++) {'id': 'fixed-$i', 'amount': 10},
      ];
      expect(
        await FinanzasProviderAccountsStore.loadInvoices(),
        hasLength(1005),
      );
      expect(await FinanzasFixedPaymentsStore.loadPayments(), hasLength(1005));
    },
  );

  test('loads complete payment history beyond the first server page', () async {
    database['compras_provider_movements'] = [
      for (var i = 0; i < 1005; i++)
        {
          'id': 'movement-$i',
          'provider_id': 'provider',
          'movement_type': 'ABONO',
          'amount': 1,
        },
    ];
    database['compras_ticket_payment_applications'] = [
      for (var i = 0; i < 1005; i++)
        {
          'id': 'application-$i',
          'ticket_id': 'ticket',
          'provider_movement_id': 'movement-$i',
          'applied_amount': 1,
        },
    ];
    expect(await ComprasTicketsStore.loadProviderMovements(), hasLength(1005));
    expect(
      await ComprasTicketsStore.loadTicketPaymentApplications(),
      hasLength(1005),
    );
  });

  test(
    'changing a payment to an adjustment rebuilds previous ticket applications',
    () async {
      database['compras_provider_movements'] = [
        {
          'id': 'movement',
          'provider_id': 'provider',
          'movement_type': 'ABONO',
          'amount': 200,
        },
      ];
      database['compras_ticket_payment_applications'] = [
        {
          'id': 'application',
          'ticket_id': 'ticket',
          'provider_movement_id': 'movement',
          'applied_amount': 200,
        },
      ];
      await ComprasTicketsStore.updateProviderMovementAndAutoApply(
        movement: ComprasProviderMovementRecord.fromRemoteRow({
          'id': 'movement',
          'provider_id': 'provider',
          'movement_type': 'AJUSTE',
          'amount': -100,
        }),
        previousType: 'ABONO',
      );
      expect(database['compras_ticket_payment_applications'], isEmpty);
      expect(
        database['compras_tickets']!.single['pago_status'],
        'PENDIENTE_DE_PAGO',
      );
      expect(database['compras_provider_movements']!.single['amount'], -100);
    },
  );

  test(
    'deleting an adjustment preserves existing payment applications',
    () async {
      database['compras_provider_movements'] = [
        {
          'id': 'adjustment',
          'provider_id': 'provider',
          'movement_type': 'AJUSTE',
          'amount': -100,
        },
      ];
      database['compras_ticket_payment_applications'] = [
        {
          'id': 'application',
          'ticket_id': 'ticket',
          'provider_movement_id': 'payment',
          'applied_amount': 200,
        },
      ];
      await ComprasTicketsStore.deleteProviderMovementAndRebuildApplications(
        movement: ComprasProviderMovementRecord.fromRemoteRow(
          database['compras_provider_movements']!.single,
        ),
      );
      expect(database['compras_provider_movements'], isEmpty);
      expect(database['compras_ticket_payment_applications'], hasLength(1));
    },
  );
}
