import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_models.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_repository.dart';
import 'profitability_fixtures.dart';

void main() {
  test(
    'required sources paginate, fallback dates filter correctly and payroll avoids names/receipts',
    () async {
      final requests = <http.Request>[];
      final fixture = profitFixture(
        overrides: {
          'employees': [
            {'id': 'driver', 'full_name': 'JUAN PEREZ', 'is_driver': true},
          ],
          'hr_employee_profiles': [
            {
              'id': 'hr-driver',
              'nombre': 'JUAN PEREZ LOPEZ',
              'empresa': 'DICSA CELAYA',
              'salario': 700,
              'salario_flujo': 0,
            },
          ],
        },
      );
      final client = SupabaseClient(
        'https://example.test',
        'public-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          final table = request.url.pathSegments.last;
          final q = request.url.queryParameters;
          if (table == 'direction_program_can_manage') {
            return http.Response('true', 200, request: request);
          }
          if (table == 'direction_profitability_reviews') {
            return http.Response('[]', 200, request: request);
          }
          final data = table == 'compras_tickets'
              ? [for (var i = 0; i < 1050; i++) purchase('p$i', 10, 10, 20)]
              : fixture.rows(table);
          final offset = int.tryParse(q['offset'] ?? '') ?? 0,
              limit = int.tryParse(q['limit'] ?? '') ?? 1000;
          return http.Response(
            jsonEncode(data.skip(offset).take(limit).toList()),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final bundle = await ProfitabilityRepository(
        client: client,
      ).load(ProfitPeriod.pilot());
      expect(bundle.sources.rows('compras_tickets').length, 1050);
      expect(
        requests.where((r) => r.url.path.endsWith('/compras_tickets')).length,
        2,
      );
      final services = requests
          .firstWhere((r) => r.url.path.endsWith('/services'))
          .url
          .queryParameters;
      expect(services['or'], contains('due_date.is.null'));
      expect(services['or'], contains('service_date.lt.2026-09-18'));
      final payroll = requests
          .firstWhere((r) => r.url.path.endsWith('/hr_prenomina_draft_rows'))
          .url
          .queryParameters;
      expect(payroll['select'], isNot(contains('employee_name')));
      expect(payroll['select'], isNot(contains('payroll_receipt')));
      expect(payroll['period_label'], contains('SEM 38'));
      expect(
        bundle.sources
            .rows('hr_employee_profiles')
            .single['profit_payroll_role'],
        'driver',
      );
      expect(jsonEncode(bundle.sources.tables), isNot(contains('JUAN PEREZ')));
      final drivers = requests
          .firstWhere((r) => r.url.path.endsWith('/employees'))
          .url
          .queryParameters;
      expect(drivers['is_driver'], 'eq.true');
      await client.dispose();
    },
  );
  test(
    'one failed required source fails the bundle instead of becoming zero',
    () async {
      final client = SupabaseClient(
        'https://example.test',
        'public-key',
        httpClient: MockClient((r) async {
          if (r.url.path.endsWith('/direction_program_can_manage')) {
            return http.Response('true', 200, request: r);
          }
          if (r.url.path.endsWith('/men_tickets')) {
            return http.Response(
              '{"message":"permission denied","code":"42501"}',
              403,
              request: r,
            );
          }
          return http.Response('[]', 200, request: r);
        }),
      );
      await expectLater(
        ProfitabilityRepository(client: client).load(ProfitPeriod.pilot()),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'source',
            contains('men_tickets'),
          ),
        ),
      );
      await client.dispose();
    },
  );
  test('permission preflight stops source retrieval', () async {
    var calls = 0;
    final client = SupabaseClient(
      'https://example.test',
      'public-key',
      httpClient: MockClient((r) async {
        calls++;
        return http.Response('false', 200, request: r);
      }),
    );
    await expectLater(
      ProfitabilityRepository(client: client).load(ProfitPeriod.pilot()),
      throwsStateError,
    );
    expect(calls, 1);
    await client.dispose();
  });
}
