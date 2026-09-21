import 'dart:convert';
import 'dart:io';

import 'package:dicsa_operacion/app/management_reports/direction_weekly_source.dart';
import 'package:dicsa_operacion/app/management_reports/direction_weekly_summary.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_pdf_export.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  var failedTable = '';
  var dense = false;
  var empty = false;
  Map<String, dynamic> market(
    String id,
    String source,
    String flow,
    num amount, [
    String date = '2026-09-15T12:00:00',
  ]) => {
    'source_event_id': id,
    'source_area': source,
    'event_at': date,
    'channel': source == 'menudeo' ? 'menudeo' : 'mayoreo',
    'flow': flow,
    'amount_total': amount,
    'volume_kg': 100,
    'general_material_key': 'CARTON',
    'general_material_label': 'Cartón',
  };
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://direction-summary.invalid',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((r) async {
        requests.add(r);
        final table = r.url.pathSegments.last;
        // The documentary dashboard is a read-only RPC; every other call is GET.
        expect(r.method, table == 'documental_dashboard' ? 'POST' : 'GET');
        if (table == failedTable || failedTable == '*') {
          return http.Response(
            '{"message":"permission denied","code":"42501"}',
            403,
            request: r,
          );
        }
        Object response;
        if (table == 'documental_dashboard') {
          response = {
            'context': {
              'today': '2026-09-18',
              'seconds_to_midnight': 3600,
              'responsibles': [],
            },
            'metrics': {},
            'categories': {
              'documentacion-legal': {
                'total': empty ? 0 : 1,
                'upcoming': 0,
                'expired': 1,
                'pending': 0,
              },
            },
            'upcoming': [],
            'upcoming_total': 0,
          };
        } else {
          List<Map<String, dynamic>> rows;
          switch (table) {
            case 'v_commercial_market_events':
              rows = dense
                  ? [
                      for (var i = 0; i < 505; i++)
                        market('p$i', 'mayoreo_compras', 'purchase', 1),
                    ]
                  : [
                      market('p', 'mayoreo_compras', 'purchase', 500),
                      market(
                        'p0',
                        'mayoreo_compras',
                        'purchase',
                        300,
                        '2026-09-08T12:00:00',
                      ),
                      market('s', 'mayoreo_ventas', 'sale', 1000),
                      market('m', 'menudeo', 'purchase', 100),
                    ];
            case 'finanzas_bank_movements':
              rows = [
                {
                  'id': 'sale',
                  'movement_date': '2026-09-15',
                  'category': 'VENTAS',
                  'credit_amount': 1000,
                  'debit_amount': 0,
                },
                {
                  'id': 'buy',
                  'movement_date': '2026-09-15',
                  'category': 'COMPRA DE MATERIAL',
                  'credit_amount': 0,
                  'debit_amount': 200,
                },
              ];
            case 'finanzas_supplier_invoices':
              rows = [
                {
                  'id': 'invoice',
                  'invoice_date': '2026-09-10',
                  'due_date': '2026-09-16',
                  'balance_amount': 250,
                  'status': 'VENCIDA',
                },
              ];
            case 'v_inventory_general_balance_v2':
              rows = [
                {
                  'code': 'CARTON',
                  'name': 'Cartón',
                  'on_hand_kg': 5000,
                  'on_hand_units': 0,
                },
              ];
            case 'v_inventory_commercial_balance_v2':
              rows = [
                {
                  'code': 'PACA_LIMPIA',
                  'name': 'Paca limpia',
                  'on_hand_kg': -100,
                  'on_hand_units': 5,
                },
              ];
            case 'inventory_items':
              rows = dense
                  ? [
                      for (var i = 0; i < 505; i++)
                        {
                          'id': '$i',
                          'current_stock': 0,
                          'minimum_stock': 5,
                          'is_active': true,
                        },
                    ]
                  : [
                      {
                        'id': 'oil',
                        'code': 'ACEITE',
                        'name': 'Aceite',
                        'current_stock': 0,
                        'minimum_stock': 5,
                        'is_active': true,
                      },
                    ];
            case 'documental_records':
              rows = [
                {
                  'id': 'doc',
                  'category': 'documentacion-legal',
                  'title': 'Permiso',
                  'status': 'Pendiente',
                  'priority': 'Alta',
                  'expiration_date': '2026-09-16',
                },
              ];
            case 'direction_shipment_plans':
              rows = [
                {
                  'id': 'ship',
                  'ship_date': '2026-09-15',
                  'commercial_material_code': 'PACA_LIMPIA',
                  'planning_material_code': 'PACA_LIMPIA',
                  'quantity_unit': 'bales',
                  'planned_units': 100,
                  'status': 'embarcado',
                },
              ];
            case 'production_runs':
              rows = dense
                  ? [
                      for (var i = 0; i < 505; i++)
                        {
                          'id': 'run$i',
                          'op_date': '2026-09-15',
                          'shift': 'DAY',
                          'bale_material': 'BALE_CLEAN',
                          'bale_count': 1,
                        },
                    ]
                  : [
                      {
                        'id': 'run',
                        'op_date': '2026-09-15',
                        'shift': 'DAY',
                        'bale_material': 'BALE_CLEAN',
                        'bale_count': 40,
                      },
                    ];
            case 'gerencia_bale_type_catalog':
              rows = [
                {
                  'key': 'limpio',
                  'label': 'Paca limpia',
                  'sort_order': 1,
                  'is_active': true,
                },
              ];
            case 'hr_employee_profiles':
              rows = [
                {
                  'id': 'employee',
                  'nombre': 'Colaborador QA',
                  'empresa': 'DICSA',
                  'employment_status': 'activo',
                },
              ];
            default:
              rows = [];
          }
          if (empty) rows = [];
          // Apply date/flow predicates like the database; paging after filters.
          for (final entry in r.url.queryParametersAll.entries) {
            if (![
              'event_at',
              'flow',
              'ship_date',
              'op_date',
            ].contains(entry.key)) {
              continue;
            }
            for (final predicate in entry.value) {
              final dot = predicate.indexOf('.');
              if (dot < 0) continue;
              final op = predicate.substring(0, dot),
                  value = predicate.substring(dot + 1);
              rows = rows.where((row) {
                final actual = '${row[entry.key] ?? ''}';
                final a = DateTime.tryParse(actual),
                    b = DateTime.tryParse(value);
                final c = a != null && b != null
                    ? a.compareTo(b)
                    : actual.compareTo(value);
                return switch (op) {
                  'gte' => c >= 0,
                  'lte' => c <= 0,
                  'lt' => c < 0,
                  'eq' => c == 0,
                  _ => true,
                };
              }).toList();
            }
          }
          final offset =
              int.tryParse(r.url.queryParameters['offset'] ?? '') ?? 0;
          final limit =
              int.tryParse(r.url.queryParameters['limit'] ?? '') ?? rows.length;
          response = rows.skip(offset).take(limit).toList();
        }
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  setUp(() {
    requests.clear();
    failedTable = '';
    dense = empty = false;
  });
  DirectionAreaSummary area(
    List<DirectionAreaSummary> rows,
    DirectionSummaryArea key,
  ) => rows.firstWhere((r) => r.area == key);
  String value(DirectionAreaSummary area, String label) =>
      area.metrics.firstWhere((m) => m.label == label).current;

  test('all 18 blocks consult their actual sources without mutations', () async {
    final rows = await loadDirectionWeeklySource(DateTime(2026, 9, 18, 17));
    expect(rows, hasLength(18));
    expect(rows.where((r) => !r.available).map((r) => r.area), isEmpty);
    expect(
      value(area(rows, DirectionSummaryArea.compras), 'Compras registradas'),
      '\$500.00',
    );
    expect(
      value(area(rows, DirectionSummaryArea.ventas), 'Ventas registradas'),
      '\$1,000.00',
    );
    expect(
      value(
        area(rows, DirectionSummaryArea.contabilidad),
        'Resultado comercial consolidado',
      ),
      '\$400.00',
    );
    expect(
      value(
        area(rows, DirectionSummaryArea.contabilidad),
        'Utilidad neta del estado de resultados',
      ),
      '\$800.00',
    );
    expect(
      value(area(rows, DirectionSummaryArea.finanzas), 'Facturas vencidas'),
      '1',
    );
    expect(value(area(rows, DirectionSummaryArea.gestion), 'Vencidos'), '1');
    expect(
      value(area(rows, DirectionSummaryArea.rh), 'Cierre de nómina'),
      'Sin periodo',
    );
    expect(
      value(
        area(rows, DirectionSummaryArea.rh),
        'Nómina operativa del periodo',
      ),
      'Sin captura',
    );
    expect(
      value(
        area(rows, DirectionSummaryArea.operaciones),
        'Unidades producidas',
      ),
      '40',
    );
    final tables = requests.map((r) => r.url.pathSegments.last).toSet();
    expect(
      tables,
      containsAll([
        'maintenance_orders',
        'inventory_movements_v2',
        'services',
        'vw_men_tickets_grid',
        'mayoreo_accounts',
        'commercial_accounts',
        'finanzas_bank_movements',
        'direction_vault_vouchers',
        'maintenance_purchase_orders',
        'hr_employee_profiles',
        'documental_records',
        'gerencia_bale_weekly_plans',
        'inventory_items',
        'direction_shipment_plans',
      ]),
    );
    // Commercial totals shared by Purchasing, Sales, Accounting; CRM has its own sales-only query.
    expect(
      requests.where(
        (r) =>
            r.url.pathSegments.last == 'v_commercial_market_events' &&
            !r.url.queryParameters.containsKey('flow'),
      ),
      hasLength(1),
    );
  });
  test(
    'pagination retains more than 500 purchases, production runs and warehouse articles',
    () async {
      dense = true;
      final rows = await loadDirectionWeeklySource(DateTime(2026, 9, 18, 17));
      expect(
        value(area(rows, DirectionSummaryArea.compras), 'Compras registradas'),
        '\$505.00',
      );
      expect(
        value(area(rows, DirectionSummaryArea.almacen), 'Artículos activos'),
        '505',
      );
      expect(
        value(
          area(rows, DirectionSummaryArea.gerencia),
          'Pacas producidas del plan',
        ),
        '505',
      );
    },
  );
  test(
    'bank outage isolates financial blocks and never reports collection as zero',
    () async {
      failedTable = 'finanzas_bank_movements';
      final rows = await loadDirectionWeeklySource(DateTime(2026, 9, 18, 17));
      expect(area(rows, DirectionSummaryArea.finanzas).available, isFalse);
      expect(area(rows, DirectionSummaryArea.ventas).available, isFalse);
      expect(area(rows, DirectionSummaryArea.contabilidad).available, isFalse);
      expect(area(rows, DirectionSummaryArea.compras).available, isTrue);
      expect(area(rows, DirectionSummaryArea.operaciones).available, isTrue);
      expect(area(rows, DirectionSummaryArea.ventas).metrics, isEmpty);
    },
  );
  test(
    'weekend generated overview retains the Friday just completed',
    () async {
      await loadDirectionWeeklySource(DateTime(2026, 9, 20, 10));
      final ticketQueries = requests.where(
        (r) => r.url.pathSegments.last == 'vw_men_tickets_grid',
      );
      expect(
        ticketQueries.any(
          (r) =>
              r.url.queryParametersAll['ticket_date']?.contains(
                'gte.2026-09-14',
              ) ??
              false,
        ),
        isTrue,
      );
      expect(
        ticketQueries.any(
          (r) =>
              r.url.queryParametersAll['ticket_date']?.contains(
                'gte.2026-09-21',
              ) ??
              false,
        ),
        isFalse,
      );
    },
  );
  test(
    'central export reads all sources and renders regular and empty PDFs',
    () async {
      final out = Platform.environment['DICSA_DIRECTION_QA_DIR'];
      for (final isEmpty in [false, true]) {
        empty = isEmpty;
        final bytes = await buildManagementReportPdfBytes(
          area: managementAreaDefinition(ManagementAreaKey.direccionGeneral),
          frequency: ManagementReportFrequency.weeklyFriday,
          generatedAt: DateTime(2026, 9, 18, 17),
          generatedBy: 'QA · DATOS SIMULADOS',
        );
        expect(bytes.take(4), [37, 80, 68, 70]);
        if (out != null) {
          await Directory(out).create(recursive: true);
          await File(
            '$out/direccion_${empty ? 'vacio' : 'viernes'}.pdf',
          ).writeAsBytes(bytes);
        }
      }
    },
  );
  test(
    'complete outage is surfaced by the export instead of saving a catalogue PDF',
    () async {
      failedTable = '*';
      await expectLater(
        buildManagementReportPdfBytes(
          area: managementAreaDefinition(ManagementAreaKey.direccionGeneral),
          frequency: ManagementReportFrequency.weeklyFriday,
          generatedAt: DateTime(2026, 9, 18, 17),
          generatedBy: 'QA',
        ),
        throwsStateError,
      );
    },
  );
}
