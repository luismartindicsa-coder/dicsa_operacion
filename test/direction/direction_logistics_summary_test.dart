import 'dart:convert';

import 'package:dicsa_operacion/app/direction/direction_logistics_summary.dart';
import 'package:dicsa_operacion/app/logistica/logistics_diesel_store.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gasoline_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final week = DateTime(2026, 9, 14);

Map<String, dynamic> row({
  String date = '2026-09-15',
  String? driver = '1',
  String name = 'ANA MARTÍNEZ',
  num requested = 120,
  num purchased = 0,
  num loaded = 30,
}) => {
  'entry_date': date,
  'operator_employee_id': driver,
  'operator_name': name,
  'liters_requested': requested,
  'liters_purchased': purchased,
  'liters_loaded': loaded,
  'balance_liters': 9000,
};

DirectionLogisticsWeeklySummary summary({
  DateTime? date,
  List<Map<String, dynamic>> diesel = const [],
  List<Map<String, dynamic>> gasoline = const [],
}) => DirectionLogisticsWeeklySummary.fromEntries(
  weekDate: date ?? week,
  diesel: diesel.map(LogisticsDieselConsumptionRecord.fromRemoteRow),
  gasoline: gasoline.map(LogisticsGasolineControlRecord.fromRemoteRow),
);

DirectionLogisticsWeeklySummary fixture([DateTime? date]) {
  final day = (date ?? week).toIso8601String().substring(0, 10);
  return summary(
    date: date,
    diesel: [
      row(date: day, driver: null, name: '', purchased: 1500, requested: 0),
      row(date: day, requested: 320),
      row(date: day, driver: '2', name: 'LUIS GARCÍA', requested: 245.5),
      row(date: day, driver: '3', name: 'JORGE HERNÁNDEZ', requested: 180),
      row(date: day, driver: '4', name: 'MARIO LÓPEZ', requested: 125),
    ],
    gasoline: [
      row(date: day, name: 'ANA MARTÍNEZ', loaded: 75.5),
      row(date: day, driver: '5', name: 'PEDRO RAMÍREZ', loaded: 48),
    ],
  );
}

void main() {
  test(
    'week includes Monday through Sunday and keeps fuels and purchases separate',
    () {
      final result = summary(
        date: DateTime(2026, 9, 20, 23),
        diesel: [
          row(date: '2026-09-13', requested: 9999),
          row(
            date: '2026-09-14',
            purchased: 1000,
            requested: 0,
            driver: null,
            name: '',
          ),
          row(date: '2026-09-15', requested: 100.25),
          row(date: '2026-09-20', requested: 200.5),
          row(date: '2026-09-21', requested: 9999),
        ],
        gasoline: [
          row(loaded: 45.75),
          row(date: '2026-09-21', loaded: 9999),
        ],
      );
      expect(result.weekStart, week);
      expect(result.dieselPurchased, 1000);
      expect(result.dieselRequested, 300.75);
      expect(result.gasolineLoaded, 45.75);
      expect(result.dieselEntries, 3);
      expect(result.dieselDrivers.single.liters, 300.75);
      expect(result.dieselDrivers.single.name, 'ANA MARTÍNEZ');
    },
  );

  test(
    'driver identities survive name changes, missing names and equal names',
    () {
      final result = summary(
        diesel: [
          row(driver: '1', name: '  ANA   MARTÍNEZ ', requested: 30),
          row(
            driver: '1',
            name: 'NOMBRE VIEJO',
            date: '2026-09-14',
            requested: 20,
          ),
          row(driver: '2', name: 'ANA MARTÍNEZ', requested: 40),
          row(driver: null, name: ' luis ', requested: 10),
          row(driver: null, name: 'LUIS', requested: 15),
          row(driver: null, name: '', requested: 5),
        ],
      );
      expect(result.dieselDrivers.map((row) => row.liters), [50, 40, 25, 5]);
      expect(result.dieselDrivers.map((row) => row.name), [
        'ANA MARTÍNEZ',
        'ANA MARTÍNEZ',
        'LUIS',
        'Sin chofer',
      ]);
      expect(
        result.dieselDrivers.fold(0.0, (sum, row) => sum + row.liters),
        result.dieselRequested,
      );
    },
  );

  test('empty and purchase-only weeks have no driver consumption', () {
    final empty = summary();
    expect(empty.dieselRequested, 0);
    expect(empty.gasolineLoaded, 0);
    expect(empty.dieselDrivers, isEmpty);
    final purchase = summary(diesel: [row(purchased: 700, requested: 0)]);
    expect(purchase.dieselPurchased, 700);
    expect(purchase.dieselDrivers, isEmpty);
    expect(
      DirectionLogisticsWeeklySummary.startOfWeek(DateTime(2027, 1, 1)),
      DateTime(2026, 12, 28),
    );
  });

  test(
    'store paginates both fuels and uses the same exclusive week bounds',
    () async {
      final calls = <String, int>{};
      final client = SupabaseClient(
        'https://logistics-test.invalid',
        'test',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          final table = request.url.pathSegments.last;
          calls.update(table, (value) => value + 1, ifAbsent: () => 1);
          expect(request.url.queryParametersAll['entry_date'], [
            'gte.2026-09-14',
            'lt.2026-09-21',
          ]);
          expect(request.url.queryParameters['order'], contains('id.asc'));
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          final data = List.generate(
            offset == 0 ? 1000 : 1,
            (index) => {
              ...row(requested: 0.5, loaded: 0.25),
              'id': '${offset + index}',
            },
          );
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final result = await DirectionLogisticsStore(
        client: client,
      ).loadWeek(week);
      expect(calls, {
        'logistics_diesel_consumption': 2,
        'logistics_gasoline_control': 2,
      });
      expect(result.dieselEntries, 1001);
      expect(result.gasolineEntries, 1001);
      expect(result.dieselRequested, 500.5);
      expect(result.gasolineLoaded, 250.25);
    },
  );

  test(
    'source controls retain older weeks beyond the first database page',
    () async {
      final client = SupabaseClient(
        'https://logistics-test.invalid',
        'test',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          final data = offset == 0
              ? List.generate(
                  1000,
                  (index) => {...row(date: '2026-09-21'), 'id': '$index'},
                )
              : [
                  {...row(requested: 75.5, loaded: 25.5), 'id': '1000'},
                ];
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final diesel = await LogisticsDieselConsumptionStore.loadEntries(
        client: client,
      );
      final gasoline = await LogisticsGasolineControlStore.loadEntries(
        client: client,
      );
      expect(diesel, hasLength(1001));
      expect(gasoline, hasLength(1001));
      final result = DirectionLogisticsWeeklySummary.fromEntries(
        weekDate: week,
        diesel: diesel,
        gasoline: gasoline,
      );
      expect(result.dieselRequested, 75.5);
      expect(result.gasolineLoaded, 25.5);
    },
  );

  test(
    'source errors propagate instead of generating false zero totals',
    () async {
      final client = SupabaseClient(
        'https://logistics-test.invalid',
        'test',
        httpClient: MockClient(
          (request) async =>
              http.Response('{"message":"unavailable"}', 503, request: request),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        DirectionLogisticsStore(client: client).loadWeek(week),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}
