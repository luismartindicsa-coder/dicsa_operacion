import 'dart:convert';

import 'package:dicsa_operacion/app/dashboard/dashboard_yard_stock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final today = DateTime(2026, 10, 28);
const materialCodes = {
  'heavy': 'PESADO',
  'return': 'RETORNO_INDUSTRIAL',
  'shavings': 'REBABA',
  'mixed': 'MIXTO',
  'generic-scrap': 'CHATARRA',
  'bale': 'PACA_NACIONAL',
};

Map<String, dynamic> entry(
  String id,
  String date,
  double kg, {
  String material = 'heavy',
}) => {
  'id': id,
  'flow': 'IN',
  'inventory_level': 'GENERAL',
  'op_date': date,
  'site': 'DICSA_CELAYA',
  'source_commercial_material_id': material,
  'weight_kg': kg,
  'net_kg': kg,
};

Map<String, dynamic> exit(
  String id,
  String date, {
  String material = 'heavy',
}) => {
  'id': id,
  'flow': 'OUT',
  'inventory_level': 'COMMERCIAL',
  'op_date': date,
  'site': 'DICSA_CELAYA',
  'commercial_material_id': material,
  'weight_kg': 100,
};

Map<String, DashboardYardStock> calculate(List<Map<String, dynamic>> rows) =>
    buildDashboardYardStock(
      movements: rows,
      materialCodesById: materialCodes,
      counterpartyNamesById: {'public': 'PUBLICO', 'other': 'OTHER SUPPLIER'},
      asOf: today,
    );

void main() {
  test('Público scrap adds to Mixto using only the last Mixto exit', () {
    final stock = calculate([
      exit('mixed-out', '2026-10-09', material: 'mixed'),
      exit('generic-out', '2026-10-27', material: 'generic-scrap'),
      entry('classified', '2026-10-12', 100, material: 'mixed'),
      {
        ...entry('public', '2026-10-13', 4000, material: 'generic-scrap'),
        'counterparty': ' Público ',
      },
      {
        ...entry('linked', '2026-10-14', 27, material: 'generic-scrap'),
        'counterparty': 'Old name',
        'counterparty_site_id': 'public',
      },
      {
        ...entry('before', '2026-10-08', 999, material: 'generic-scrap'),
        'counterparty': 'PUBLICO',
      },
      {
        ...entry('other', '2026-10-14', 888, material: 'generic-scrap'),
        'counterparty': 'MONROE',
      },
      {
        ...entry(
          'different-site',
          '2026-10-14',
          777,
          material: 'generic-scrap',
        ),
        'counterparty': 'PUBLICO',
        'counterparty_site_id': 'other',
      },
    ]);
    expect(stock['MIXTO']!.weightKg, 4127);
    expect(stock['MIXTO']!.entryCount, 3);
    expect(stock['MIXTO']!.lastExitDate, DateTime(2026, 10, 9));
    expect(stock['PESADO']!.weightKg, 0);
  });

  test('each material has its own last exit and only sums matching extras', () {
    final stock = calculate([
      entry('h-after', '2026-10-24', 8000),
      exit('h-old', '2026-10-10'),
      entry('r-after', '2026-10-21', 500, material: 'return'),
      entry('h-before', '2026-10-22', 9000),
      entry('h-latest', '2026-10-28', 3420),
      exit('h-last', '2026-10-23'),
      exit('r-last', '2026-10-20', material: 'return'),
      entry('rebaba', '2026-10-28', 700, material: 'shavings'),
      exit('rebaba-last', '2026-10-27', material: 'shavings'),
      entry('generic', '2026-10-28', 99999, material: 'generic-scrap'),
    ]);
    expect(stock['PESADO']!.lastExitDate, DateTime(2026, 10, 23));
    expect(stock['PESADO']!.weightKg, 11420);
    expect(stock['PESADO']!.entryCount, 2);
    expect(stock['RETORNO_INDUSTRIAL']!.weightKg, 500);
    expect(stock['REBABA']!.weightKg, 700);
    expect(stock.containsKey('PACA_NACIONAL'), isFalse);
  });

  test('the whole exit date is included regardless of capture timestamp', () {
    final stock = calculate([
      exit('out', '2026-10-23'),
      {
        ...entry('same-day', '2026-10-23', 10),
        'created_at': '2026-10-23T06:00:00Z',
      },
      {
        ...entry('backdated', '2026-10-22', 999),
        'created_at': '2026-10-28T15:00:00Z',
      },
      {
        ...entry('late-capture', '2026-10-24', 20),
        'created_at': '2026-10-28T15:00:00Z',
      },
    ]);
    expect(stock['PESADO']!.weightKg, 30);
  });

  test('a new exit resets the floor even if its weight is small', () {
    final rows = [exit('old', '2026-10-20'), entry('in', '2026-10-21', 5000)];
    expect(calculate(rows)['PESADO']!.weightKg, 5000);
    rows.add({...exit('partial', '2026-10-22'), 'weight_kg': 1});
    expect(calculate(rows)['PESADO']!.weightKg, 0);
    rows.add(entry('after', '2026-10-23', 25));
    expect(calculate(rows)['PESADO']!.weightKg, 25);
  });

  test('editing or deleting an exit recomputes the reference', () {
    final rows = [
      exit('old', '2026-10-20'),
      exit('last', '2026-10-25'),
      entry('in', '2026-10-23', 40),
    ];
    expect(calculate(rows)['PESADO']!.weightKg, 0);
    rows[1] = exit('last', '2026-10-22');
    expect(calculate(rows)['PESADO']!.weightKg, 40);
    rows.removeAt(1);
    expect(calculate(rows)['PESADO']!.lastExitDate, DateTime(2026, 10, 20));
    rows.removeAt(0);
    expect(calculate(rows)['PESADO']!.lastExitDate, isNull);
  });

  test('missing exit is distinct from a referenced zero balance', () {
    final stock = calculate([
      entry('unreferenced', '2026-10-28', 800),
      exit('return-out', '2026-10-28', material: 'return'),
    ]);
    expect(stock['PESADO']!.lastExitDate, isNull);
    expect(stock['PESADO']!.weightKg, 0);
    expect(stock['RETORNO_INDUSTRIAL']!.lastExitDate, today);
    expect(stock['RETORNO_INDUSTRIAL']!.weightKg, 0);
  });

  test('uses displayed net kg, preserves zero, and falls back when absent', () {
    final stock = calculate([
      exit('out', '2026-10-23'),
      {...entry('net', '2026-10-24', 1000), 'net_kg': 800},
      {...entry('zero', '2026-10-24', 1000), 'net_kg': 0},
      {...entry('fallback', '2026-10-24', 200), 'net_kg': null},
      {...entry('decimal', '2026-10-24', 0), 'net_kg': '1.25'},
    ]);
    expect(stock['PESADO']!.weightKg, 1001.25);
  });

  test(
    'future dates, other yards, and transformation legs do not affect floor',
    () {
      final stock = calculate([
        exit('out', '2026-10-23'),
        {...entry('legacy-site', '2026-10-24', 50), 'site': null},
        entry('future', '2026-10-29', 1000),
        exit('future-out', '2026-10-29'),
        {...entry('other', '2026-10-24', 1000), 'site': 'DICSA_APASEO'},
        {...exit('other-out', '2026-10-28'), 'site': 'DICSA_APASEO'},
        {
          ...entry('production', '2026-10-24', 1000),
          'inventory_level': 'COMMERCIAL',
        },
        {...exit('consumption', '2026-10-28'), 'inventory_level': 'GENERAL'},
      ]);
      expect(stock['PESADO']!.lastExitDate, DateTime(2026, 10, 23));
      expect(stock['PESADO']!.weightKg, 50);
    },
  );

  test(
    'repository loads all pages and scopes the same flows as the grid',
    () async {
      final requests = <Uri>[];
      final client = SupabaseClient(
        'https://test.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          requests.add(request.url);
          if (request.url.path == '/rest/v1/sites') {
            return http.Response(
              jsonEncode([
                {'id': 'public', 'name': 'PUBLICO'},
              ]),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          final query = request.url.queryParameters;
          expect(request.url.path, '/rest/v1/inventory_movements_v2');
          expect(query['op_date'], 'lte.2026-10-28');
          expect(query['or'], '(site.eq.DICSA_CELAYA,site.is.null)');
          expect(query['order'], startsWith('id.asc'));
          final incoming = query['flow'] == 'eq.IN';
          expect(
            query['inventory_level'],
            incoming ? 'eq.GENERAL' : 'eq.COMMERCIAL',
          );
          final filter = incoming
              ? 'source_commercial_material_id'
              : 'commercial_material_id';
          expect(query[filter], contains('heavy'));
          expect(query[filter], isNot(contains('bale')));
          expect(
            query[filter],
            incoming
                ? contains('generic-scrap')
                : isNot(contains('generic-scrap')),
          );
          expect(query['select'], contains('counterparty_site_id'));
          final all = incoming
              ? List.generate(1001, (i) => entry('in-$i', '2026-10-24', 1))
              : [exit('last', '2026-10-23')];
          final offset = int.parse(query['offset'] ?? '0');
          final limit = int.parse(query['limit'] ?? '1000');
          return http.Response(
            jsonEncode(all.skip(offset).take(limit).toList()),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final stock = await loadDashboardYardStock(
        client,
        commercialCatalog: [
          for (final e in materialCodes.entries) {'id': e.key, 'code': e.value},
        ],
        asOf: today,
      );
      expect(stock['PESADO']!.weightKg, 1001);
      expect(stock['PESADO']!.entryCount, 1001);
      expect(
        requests.where((uri) => uri.queryParameters['flow'] == 'eq.IN'),
        hasLength(2),
      );
    },
  );

  test('read errors propagate rather than becoming a zero stock', () async {
    final client = SupabaseClient(
      'https://test.supabase.co',
      'test-key',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({'message': 'Unavailable', 'code': '42501'}),
          403,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      loadDashboardYardStock(
        client,
        commercialCatalog: [
          {'id': 'heavy', 'code': 'PESADO'},
        ],
        asOf: today,
      ),
      throwsA(isA<PostgrestException>()),
    );
  });
}
