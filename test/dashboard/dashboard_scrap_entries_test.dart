import 'dart:async';
import 'dart:convert';

import 'package:dicsa_operacion/app/dashboard/dashboard_scrap_entries.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final from = DateTime(2026, 7, 31);
final today = DateTime(2026, 10, 28);

Map<String, dynamic> entry(String date, num kg, {String code = 'PESADO'}) => {
  'id': '$date-$code-$kg',
  'flow': 'IN',
  'inventory_level': 'GENERAL',
  'site': 'DICSA_CELAYA',
  'op_date': date,
  'general_material': {'code': 'CHATARRA'},
  'source_commercial': {'code': code, 'name': code},
  'net_kg': kg,
  'weight_kg': kg + 100,
};

void main() {
  test('daily receipts keep history, types, net kg and unclassified scrap', () {
    final series = buildDashboardScrapEntries(
      from: from,
      asOf: today,
      counterpartyNamesById: {'public': 'PUBLICO', 'supplier': 'MONROE'},
      movements: [
        entry('2026-07-31', 800),
        entry('2026-10-26', 3330, code: 'RETORNO_INDUSTRIAL'),
        entry('2026-10-26', 4000),
        entry('2026-10-26', 4090),
        entry('2026-10-26', 775, code: 'REBABA'),
        {...entry('2026-10-27', 99999), 'flow': 'OUT'},
        {...entry('2026-10-27', 500), 'net_kg': 0},
        {...entry('2026-10-28', 25), 'net_kg': null},
        {...entry('2026-10-28', 0), 'net_kg': '1.25', 'site': null},
        {
          ...entry('2026-10-28', 100, code: 'CHATARRA'),
          'counterparty': ' Público ',
        },
        {
          ...entry('2026-10-28', 27, code: 'CHATARRA'),
          'counterparty': 'Old name',
          'counterparty_site_id': 'public',
        },
        entry('2026-10-28', 4000, code: 'MIXTO'),
        {
          ...entry('2026-10-28', 35, code: 'CHATARRA'),
          'counterparty': 'PUBLICO',
          'counterparty_site_id': 'supplier',
        },
        {...entry('2026-10-28', 12), 'source_commercial': null},
        // Any extra within the general scrap material belongs in this chart.
        entry('2026-10-28', 40, code: 'LAMINA'),
        entry('2026-07-30', 99999),
        entry('2026-10-29', 99999),
        {...entry('invalid', 99999)},
        {...entry('2026-10-28', 99999), 'site': 'DICSA_APASEO'},
        {...entry('2026-10-28', 99999), 'inventory_level': 'COMMERCIAL'},
        {
          ...entry('2026-10-28', 99999),
          'general_material': {'code': 'PAPEL'},
        },
        {...entry('2026-10-28', 99999), 'net_kg': -1},
        {...entry('2026-10-28', 99999), 'net_kg': 'NaN'},
      ],
    );
    final byCode = {for (final s in series) s.code: s.kgByDay};
    expect(byCode['PESADO'], {
      from: 800.0,
      DateTime(2026, 10, 26): 8090.0,
      DateTime(2026, 10, 27): 0.0,
      today: 126.25,
    });
    expect(byCode['RETORNO_INDUSTRIAL'], {DateTime(2026, 10, 26): 3330.0});
    expect(byCode['REBABA'], {DateTime(2026, 10, 26): 775.0});
    expect(byCode['MIXTO'], {today: 4127.0});
    expect(byCode['CHATARRA'], {today: 35.0});
    expect(byCode['SIN_CLASIFICAR'], {today: 12.0});
    expect(byCode['LAMINA'], {today: 40.0});
    expect(series.first.code, 'PESADO');
  });

  test(
    'loads all pages of general scrap entries over the inclusive range',
    () async {
      var movementRequests = 0;
      final client = SupabaseClient(
        'https://scrap-entries.invalid',
        'key',
        httpClient: MockClient((request) async {
          final query = request.url.queryParameters;
          final isSites = request.url.pathSegments.last == 'sites';
          final rows = isSites
              ? [
                  {'id': 'public', 'name': 'PUBLICO'},
                ]
              : List.generate(
                  1001,
                  (i) => {
                    ...entry('2026-10-26', 1, code: 'CHATARRA'),
                    'id': '$i',
                    'counterparty_site_id': 'public',
                  },
                );
          if (!isSites) {
            movementRequests++;
            expect(request.url.pathSegments.last, 'inventory_movements_v2');
            expect(query['flow'], 'eq.IN');
            expect(query['inventory_level'], 'eq.GENERAL');
            expect(query['general_material.code'], 'eq.CHATARRA');
            expect(query['or'], '(site.eq.DICSA_CELAYA,site.is.null)');
            expect(query['order'], startsWith('id.asc'));
            expect(
              request.url.queryParametersAll['op_date'],
              containsAll(['gte.2026-07-31', 'lte.2026-10-28']),
            );
            expect(
              query['select'],
              contains('general_material_id!inner(code)'),
            );
            expect(
              query['select'],
              contains('source_commercial_material_id(code,name)'),
            );
            expect(query.containsKey('source_commercial_material_id'), isFalse);
          }
          final offset = int.parse(query['offset'] ?? '0');
          final limit = int.parse(query['limit'] ?? '1000');
          return http.Response(
            jsonEncode(rows.skip(offset).take(limit).toList()),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final series = await loadDashboardScrapEntries(
        client,
        from: from,
        asOf: today,
      );
      expect(movementRequests, 2);
      expect(series.single.code, 'MIXTO');
      expect(series.single.kgByDay, {DateTime(2026, 10, 26): 1001.0});
    },
  );

  test('read failures are not presented as empty daily receipts', () async {
    final client = SupabaseClient(
      'https://scrap-entries.invalid',
      'key',
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
      loadDashboardScrapEntries(client, from: from, asOf: today),
      throwsA(isA<ParallelWaitError>()),
    );
  });
}
