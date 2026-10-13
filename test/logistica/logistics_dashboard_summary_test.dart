import 'dart:convert';

import 'package:dicsa_operacion/app/logistica/logistics_dashboard_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final dashboardDate = DateTime(2026, 10, 13, 12, 30);
Map<String, dynamic> service(
  String id,
  String date, {
  String status = 'programado',
  String? vehicle = 'v1',
  String? driver = 'd1',
  String company = 'c1',
}) => {
  'id': id,
  'due_date': date,
  'status': status,
  'vehicle_id': vehicle,
  'driver_employee_id': driver,
  'client_id': company,
};

LogisticsDashboardRows dashboardFixture() => {
  'services': [
    service('1', '2026-10-13'),
    service('2', '2026-10-13', vehicle: null, driver: null),
    service('3', '2026-10-13', status: 'completado'),
    service('4', '2026-10-13', status: 'cancelado'),
    service('5', '2026-10-12'),
    service('6', '2026-10-19', company: 'c2'),
    service('7', '2026-10-20', company: 'c2'),
  ],
  'vehicles': [
    {'id': 'v1', 'code': 'T-01', 'status': 'activo'},
    {'id': 'v2', 'code': 'T-02', 'status': 'activo'},
    {'id': 'v3', 'code': 'T-03', 'status': 'activo'},
    {'id': 'v4', 'code': 'T-04', 'status': 'baja'},
  ],
  'logistics_unit_states': [
    {'vehicle_id': 'v1', 'operational_status': 'DISPONIBLE'},
    {'vehicle_id': 'v2', 'operational_status': 'EN_MANTENIMIENTO'},
    {'vehicle_id': 'v4', 'operational_status': 'DISPONIBLE'},
  ],
  'logistics_trip_incidents': [
    {'id': 'i1', 'resolution_status': 'ABIERTA', 'impact_level': 'ALTA'},
    {
      'id': 'i2',
      'resolution_status': 'EN_SEGUIMIENTO',
      'impact_level': 'MEDIA',
    },
    {'id': 'i3', 'resolution_status': 'RESUELTA', 'impact_level': 'ALTA'},
  ],
  'diesel_latest': [
    {'entry_date': '2026-10-13', 'balance_liters': 550},
  ],
  'logistics_diesel_consumption': [
    {'id': 'f1', 'entry_date': '2026-10-12', 'liters_purchased': 1000},
    {
      'id': 'f2',
      'entry_date': '2026-10-13',
      'liters_requested': 50,
      'vehicle_id': 'v1',
    },
    {
      'id': 'f3',
      'entry_date': '2026-10-18',
      'liters_requested': 20,
      'vehicle_label': 'T-01',
    },
    {'id': 'f4', 'entry_date': '2026-10-11', 'liters_requested': 9999},
    {'id': 'f5', 'entry_date': '2026-10-19', 'liters_requested': 9999},
  ],
  'logistics_gasoline_control': [
    {'entry_date': '2026-10-13', 'liters_loaded': 30, 'vehicle_id': 'v2'},
    {'entry_date': '2026-10-14', 'liters_loaded': 5},
    {'entry_date': '2026-10-11', 'liters_loaded': 9999},
  ],
  'logistics_vehicle_mileage': [
    {'entry_date': '2026-10-13', 'vehicle_key': 'T1', 'kilometers': 200},
    {'entry_date': '2026-10-18', 'vehicle_key': 'T1', 'kilometers': 100},
    {'entry_date': '2026-10-13', 'vehicle_key': 'T2', 'kilometers': 90},
    {'entry_date': '2026-10-14', 'vehicle_key': 'T1', 'kilometers': 800},
    {'entry_date': '2026-10-19', 'vehicle_key': 'T1', 'kilometers': 9999},
  ],
  'sites': [
    {'id': 'c1', 'name': 'EMPRESA UNO', 'type': 'cliente', 'is_active': true},
    {'id': 'c2', 'name': 'EMPRESA DOS', 'type': 'cliente', 'is_active': true},
    {'id': 'c3', 'name': 'BAJA', 'type': 'cliente', 'is_active': false},
  ],
  'employees': [
    {'id': 'd1', 'is_driver': true, 'is_active': true},
    {'id': 'd2', 'is_driver': true, 'is_active': false},
  ],
  'logistics_containers': [
    {'id': 't1', 'is_active': true},
    {'id': 't2', 'is_active': false},
  ],
  'logistics_company_profiles': [
    {'site_id': 'c1', 'zone_id': 'z1'},
    {'site_id': 'c2', 'zone_id': 'z2'},
  ],
  'logistics_zones': [
    {'id': 'z1', 'is_active': true},
    {'id': 'z2', 'is_active': false},
  ],
};

LogisticsDashboardSnapshot fixtureSnapshot() =>
    LogisticsDashboardSnapshot.fromRows(
      now: dashboardDate,
      rows: dashboardFixture(),
    );
String metric(LogisticsDashboardSummary card, String label) =>
    card.details.singleWhere((d) => d.$1 == label).$2;

void main() {
  test(
    'today excludes old services and cancellations; one missing assignment counts once',
    () {
      final card = fixtureSnapshot().summaries[LogisticsDashboardModule.daily]!;
      expect(card.value, '2');
      expect(metric(card, 'Programados'), '3');
      expect(metric(card, 'Completados'), '1');
      expect(metric(card, 'Sin chofer o unidad'), '1');
    },
  );
  test(
    'fleet uses manual status, never infers availability from services or incidents',
    () {
      final card = fixtureSnapshot().summaries[LogisticsDashboardModule.units]!;
      expect(card.value, '1');
      expect(metric(card, 'Con advertencia'), '1');
      expect(metric(card, 'Sin estado capturado'), '1');
      expect(metric(card, 'Unidades activas'), '3');
    },
  );
  test(
    'incidents include unresolved history and exclude resolved high impact',
    () {
      final card =
          fixtureSnapshot().summaries[LogisticsDashboardModule.incidents]!;
      expect(card.value, '2');
      expect(metric(card, 'Impacto alto'), '1');
      expect(metric(card, 'En seguimiento'), '1');
    },
  );
  test('fuel is Monday through Sunday; latest tank balance is not a sum', () {
    final s = fixtureSnapshot().summaries;
    expect(s[LogisticsDashboardModule.diesel]!.value, '550 L');
    expect(
      metric(s[LogisticsDashboardModule.diesel]!, 'Comprados en la semana'),
      '1,000 L',
    );
    expect(
      metric(s[LogisticsDashboardModule.diesel]!, 'Solicitados en la semana'),
      '70 L',
    );
    expect(s[LogisticsDashboardModule.diesel]!.attention, isTrue);
    expect(s[LogisticsDashboardModule.gasoline]!.value, '35 L');
  });
  test(
    'performance weights matched daily fuel, excluding purchases and unpaired kilometers',
    () {
      final card =
          fixtureSnapshot().summaries[LogisticsDashboardModule.performance]!;
      expect(card.value, '1,190 km');
      expect(metric(card, 'Rendimiento con carga'), '3.90 km/L');
      expect(metric(card, 'Lecturas sin carga vinculada'), '1');
    },
  );
  test(
    'planning includes seven dates, ignores closed services and inactive zones',
    () {
      final card =
          fixtureSnapshot().summaries[LogisticsDashboardModule.savings]!;
      expect(card.value, '3');
      expect(metric(card, 'Grupos para combinar rutas'), '1');
      expect(metric(card, 'Empresas por zonificar'), '1');
      expect(metric(card, 'Zonas activas'), '1');
    },
  );
  test('catalog counts exclude inactive resources', () {
    final card =
        fixtureSnapshot().summaries[LogisticsDashboardModule.catalogs]!;
    expect(card.value, '1');
    expect(metric(card, 'Empresas activas'), '2');
    expect(metric(card, 'Contenedores activos'), '1');
  });
  test(
    'empty fleet and missing fuel do not imply critical tank or fabricated performance',
    () {
      final s = LogisticsDashboardSnapshot.fromRows(
        now: dashboardDate,
        rows: {},
      ).summaries;
      expect(s.length, 8);
      expect(s[LogisticsDashboardModule.diesel]!.value, '—');
      expect(s[LogisticsDashboardModule.diesel]!.attention, isFalse);
      expect(
        metric(
          s[LogisticsDashboardModule.performance]!,
          'Rendimiento con carga',
        ),
        'Sin datos',
      );
    },
  );
  test(
    'source errors affect only dependent summaries and never become zero',
    () {
      final s = LogisticsDashboardSnapshot.fromRows(
        now: dashboardDate,
        rows: dashboardFixture(),
        failedSources: {'services', 'logistics_vehicle_mileage'},
      ).summaries;
      for (final module in [
        LogisticsDashboardModule.daily,
        LogisticsDashboardModule.savings,
        LogisticsDashboardModule.performance,
      ]) {
        expect(s[module]!.error, isNotNull);
        expect(s[module]!.value, '—');
      }
      expect(s[LogisticsDashboardModule.units]!.value, '1');
      expect(s[LogisticsDashboardModule.incidents]!.value, '2');
      expect(s[LogisticsDashboardModule.diesel]!.error, isNull);
    },
  );
  test(
    'store paginates, bounds periods, reads real schema columns and isolates access failure',
    () async {
      final requests = <http.Request>[];
      final db = SupabaseClient(
        'https://dashboard.invalid',
        'key',
        httpClient: MockClient((r) async {
          requests.add(r);
          final table = r.url.pathSegments.last;
          final p = r.url.queryParameters;
          if (table == 'logistics_trip_incidents') {
            return http.Response(
              jsonEncode({'code': '42501', 'message': 'Denied'}),
              403,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }
          final offset = int.tryParse(p['offset'] ?? '') ?? 0;
          final limit = int.tryParse(p['limit'] ?? '') ?? 1000;
          var rows = table == 'vehicles'
              ? List.generate(
                  1001,
                  (i) => {'id': '$i', 'code': 'T$i', 'status': 'activo'},
                )
              : dashboardFixture()[table] ?? <Map<String, dynamic>>[];
          if (table == 'logistics_diesel_consumption' && limit == 1) {
            rows = dashboardFixture()['diesel_latest']!;
          }
          return http.Response(
            jsonEncode(rows.skip(offset).take(limit).toList()),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final s = (await LogisticsDashboardStore.load(
        client: db,
        now: dashboardDate,
      )).summaries;
      expect(
        metric(s[LogisticsDashboardModule.units]!, 'Unidades activas'),
        '1001',
      );
      expect(s[LogisticsDashboardModule.incidents]!.error, isNotNull);
      expect(s[LogisticsDashboardModule.daily]!.value, '2');
      expect(requests.every((r) => r.method == 'GET'), isTrue);
      expect(
        requests.where((r) => r.url.pathSegments.last == 'vehicles').length,
        2,
      );
      final serviceRequest = requests.singleWhere(
        (r) => r.url.pathSegments.last == 'services',
      );
      expect(
        serviceRequest.url.queryParameters['or'],
        contains('due_date.lt.2026-10-20'),
      );
      final fuelRequest = requests.firstWhere(
        (r) => r.url.pathSegments.last == 'logistics_gasoline_control',
      );
      expect(fuelRequest.url.queryParametersAll['entry_date'], [
        'gte.2026-10-12',
        'lt.2026-10-19',
      ]);
      for (final table in ['logistics_zones', 'logistics_containers']) {
        expect(
          requests
              .singleWhere((r) => r.url.pathSegments.last == table)
              .url
              .queryParameters['select'],
          'id,is_active',
        );
      }
      expect(requests.any((r) => r.url.path.contains('maintenance')), isFalse);
      await db.dispose();
    },
  );
}
