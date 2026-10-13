import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dicsa_operacion/app/shared/persistence/atomic_save.dart';
import 'package:dicsa_operacion/app/maintenance/maintenance_order_persistence.dart';
import 'package:dicsa_operacion/app/hr/human_resources_personnel_page.dart';
import 'package:dicsa_operacion/app/compras/compras_tickets_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = <String, List<Map<String, dynamic>>>{};
  final writes = <http.Request>[];
  String? failRead;
  String? rpcError;
  var loseReply = false;
  final receipts = <String, List<dynamic>>{};
  var applied = 0;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://preservation-test.invalid',
      anonKey: 'synthetic',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((r) async {
        expect(r.url.host, 'preservation-test.invalid');
        final table = r.url.pathSegments.last;
        if (r.method != 'GET') writes.add(r);
        if (r.method == 'GET' && table == failRead) {
          throw http.ClientException('Injected read failure');
        }
        if (r.url.path.contains('/rpc/')) {
          expect(table, 'app_commit_preserving_data');
          if (rpcError != null) {
            return http.Response(
              jsonEncode({'message': 'Injected conflict', 'code': rpcError}),
              409,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }
          final body = jsonDecode(r.body) as Map;
          final rid = body['p_request_id'] as String;
          if (!receipts.containsKey(rid)) {
            applied++;
            receipts[rid] = [
              for (final op in body['p_operations'])
                {
                  'table': op['table'],
                  'action': op['action'],
                  'row': {'id': op['id'], ...?op['values']},
                },
            ];
            if (loseReply) {
              loseReply = false;
              throw http.ClientException('Reply lost after commit');
            }
          }
          return http.Response(
            jsonEncode(receipts[rid]),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }
        if (r.method != 'GET') {
          throw StateError(
            'Sequential mutation must never run: ${r.method} ${r.url}',
          );
        }
        var result = tables[table] ?? <Map<String, dynamic>>[];
        for (final e in r.url.queryParameters.entries) {
          if (e.value.startsWith('eq.')) {
            result = result
                .where((row) => '${row[e.key]}' == e.value.substring(3))
                .toList();
          }
        }
        return http.Response(
          jsonEncode(result),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    tables.clear();
    writes.clear();
    receipts.clear();
    failRead = null;
    rpcError = null;
    loseReply = false;
    applied = 0;
  });
  Map<String, dynamic> lastBody() =>
      jsonDecode(writes.last.body) as Map<String, dynamic>;
  List<Map<String, dynamic>> operations() =>
      (lastBody()['p_operations'] as List).cast<Map<String, dynamic>>();
  void seedEmployee() {
    tables['hr_employee_profiles'] = [
      {
        'id': 'person-1',
        'nombre': 'SYNTHETIC',
        'empresa': 'TEST',
        'puesto': 'OPERADOR',
        'fecha_ingreso': '2026-01-01',
        'salario': 1000,
        'salario_flujo': 0,
        'dias_labora': [],
      },
    ];
    tables['hr_employee_documents'] = [];
  }

  Map<String, dynamic> doc(String id) => {
    'id': id,
    'employee_id': 'person-1',
    'category_key': 'adicional',
    'category_label': 'Adicional',
    'title': 'SYNTHETIC',
    'file_url': 'https://preservation-test.invalid/$id',
    'storage_path': 'synthetic/$id.pdf',
    'file_name': 'synthetic.pdf',
    'mime_type': 'application/pdf',
    'size_bytes': 10,
    'uploaded_at': '2026-10-01T12:00:00Z',
  };
  void seedPayment() {
    tables['compras_tickets'] = [
      {
        'id': 'ticket-1',
        'provider_id': 'provider-1',
        'ticket_date': '2026-10-01',
        'ticket_number': 'TEST',
        'amount': 100,
        'pago_status': 'PAGADO',
        'coverage_status': 'CUBIERTO',
      },
    ];
    tables['compras_provider_movements'] = [
      {
        'id': 'payment-1',
        'provider_id': 'provider-1',
        'movement_date': '2026-10-01',
        'movement_type': 'PAGO',
        'source_type': 'BANCO',
        'amount': 100,
      },
    ];
    tables['compras_ticket_payment_applications'] = [
      {
        'id': 'app-original',
        'ticket_id': 'ticket-1',
        'provider_movement_id': 'payment-1',
        'applied_amount': 100,
        'applied_at': '2026-10-01T00:00:00',
      },
    ];
  }

  ComprasProviderMovementRecord payment() =>
      ComprasProviderMovementRecord.fromRemoteRow({
        'id': 'payment-2',
        'provider_id': 'provider-1',
        'movement_date': '2026-10-02',
        'movement_type': 'PAGO',
        'source_type': 'BANCO',
        'amount': 10,
      });

  test(
    'RH position edit only patches changed fields and checks original position',
    () async {
      seedEmployee();
      tables['hr_employee_documents']!.add(doc('original'));
      await hrPreservingSaveForTesting(puesto: 'SUPERVISOR');
      expect(operations(), hasLength(1));
      expect(operations().single['values'], {
        'nombre': 'PERSONA DE PRUEBA EDITADA',
        'puesto': 'SUPERVISOR',
      });
      expect(operations().single['expected']['puesto'], 'OPERADOR');
      expect(tables['hr_employee_documents'], hasLength(1));
    },
  );
  test(
    'RH name edit never deletes a document added after the screen loaded',
    () async {
      seedEmployee();
      await hrPreservingSaveForTesting(
        afterLoad: () async {
          tables['hr_employee_documents']!.add(doc('concurrent'));
        },
      );
      expect(writes, hasLength(1));
      expect(operations(), hasLength(1));
      expect(operations().single['table'], 'hr_employee_profiles');
      expect(operations().single['values'], {
        'nombre': 'PERSONA DE PRUEBA EDITADA',
      });
      expect(tables['hr_employee_documents'], hasLength(1));
    },
  );
  test(
    'RH only detaches documents explicitly removed from the loaded list; retains Storage',
    () async {
      seedEmployee();
      tables['hr_employee_documents']!.add(doc('original'));
      await hrPreservingSaveForTesting(
        removeDocuments: true,
        afterLoad: () async {
          tables['hr_employee_documents']!.add(doc('concurrent'));
        },
      );
      final deletes = operations()
          .where((op) => op['action'] == 'delete')
          .toList();
      expect(deletes, hasLength(1));
      expect(deletes.single['id'], 'original');
      expect(writes.every((r) => r.url.path.contains('/rpc/')), isTrue);
    },
  );
  test(
    'RH server conflict propagates without any sequential or Storage mutation',
    () async {
      seedEmployee();
      rpcError = '40001';
      await expectLater(
        hrPreservingSaveForTesting(),
        throwsA(isA<PostgrestException>()),
      );
      expect(writes, hasLength(1));
      expect(applied, 0);
    },
  );
  for (final table in [
    'compras_tickets',
    'compras_provider_movements',
    'compras_ticket_payment_applications',
  ]) {
    test('a failed $table read causes zero writes', () async {
      seedPayment();
      failRead = table;
      await expectLater(
        ComprasTicketsStore.createProviderMovementAndAutoApply(
          movement: payment(),
        ),
        throwsA(isA<http.ClientException>()),
      );
      expect(writes, isEmpty);
      expect(tables['compras_ticket_payment_applications'], hasLength(1));
    });
  }
  test(
    'purchase payment and allocations are a single RPC and preserve existing application ID',
    () async {
      seedPayment();
      await ComprasTicketsStore.createProviderMovementAndAutoApply(
        movement: payment(),
      );
      expect(writes, hasLength(1));
      expect(lastBody()['p_checks'], hasLength(3));
      expect(operations().first['table'], 'compras_provider_movements');
      expect(operations().where((op) => op['action'] == 'delete'), isEmpty);
      expect(
        operations().where((op) => op['table'] == 'compras_tickets'),
        isEmpty,
      );
    },
  );
  test(
    'purchase reconciliation changes only payment status, never amount or unrelated ticket fields',
    () async {
      seedPayment();
      tables['compras_tickets']!.single['amount'] = 200;
      await ComprasTicketsStore.createProviderMovementAndAutoApply(
        movement: payment(),
      );
      final ticketOp = operations().singleWhere(
        (op) => op['table'] == 'compras_tickets',
      );
      expect(ticketOp['values'], {
        'pago_status': 'ABONO',
        'coverage_status': 'PARCIAL',
      });
      expect(operations().where((op) => op['action'] == 'delete'), isEmpty);
      final apps = operations()
          .where((op) => op['table'] == 'compras_ticket_payment_applications')
          .toList();
      expect(apps, hasLength(1));
      expect(apps.single['values']['applied_amount'], 10);
    },
  );
  test(
    'lost acknowledgement retries the exact request ID and applies only once',
    () async {
      loseReply = true;
      final save = AtomicSave(
        operations: [
          {
            'table': 'maintenance_tasks',
            'action': 'insert',
            'id': 'task',
            'values': {'id': 'task'},
          },
        ],
      );
      await save.commit(Supabase.instance.client);
      expect(writes, hasLength(2));
      expect(writes[0].body, writes[1].body);
      expect(applied, 1);
    },
  );
  test('missing RPC does not fall back to old destructive writes', () async {
    rpcError = 'PGRST202';
    await expectLater(
      AtomicSave(operations: []).commit(Supabase.instance.client),
      throwsA(isA<PostgrestException>()),
    );
    expect(writes, hasLength(1));
    expect(applied, 0);
  });
  test(
    'maintenance keeps IDs and metadata, patches details and checks concurrent additions',
    () async {
      final old = {
        'id': 'task-1',
        'ot_id': 'ot-1',
        'description': 'Original',
        'created_at': '2026-01-01',
      };
      final save = prepareMaintenanceSave(
        originalOrder: {'id': 'ot-1', 'problem_description': 'Original'},
        header: {'problem_description': 'Updated'},
        originalDetails: {
          'maintenance_tasks': [old],
        },
        details: {
          'maintenance_tasks': [
            {'id': 'task-1', 'ot_id': 'ot-1', 'description': 'Updated'},
          ],
        },
      );
      expect(save.operations, hasLength(2));
      expect(save.operations.last['action'], 'update');
      expect(save.operations.last['id'], 'task-1');
      expect(save.operations.last['values'], {'description': 'Updated'});
      expect(save.checks.single['rows'], [old]);
      await save.commit(Supabase.instance.client);
      expect(writes, hasLength(1));
    },
  );
  test(
    'maintenance removes only IDs explicitly removed from original details',
    () {
      final save = prepareMaintenanceSave(
        originalOrder: {'id': 'ot-1'},
        header: {},
        originalDetails: {
          'maintenance_tasks': [
            {'id': 'removed', 'description': 'Old'},
          ],
        },
        details: {'maintenance_tasks': []},
      );
      expect(save.operations.single['id'], 'removed');
      expect(save.operations.single['expected'], {
        'id': 'removed',
        'description': 'Old',
      });
    },
  );
}
