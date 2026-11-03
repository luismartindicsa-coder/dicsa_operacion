import 'dart:convert';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_engine.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_models.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'statement_fixture.dart';

void main() {
  test(
    'reviewed economic date retrieves a document outside the native date window',
    () async {
      final data = accountingFixture();
      final sale = data['mayoreo_sales_reports']!.first;
      data['accounting_statement_reviews']!.add(
        StatementDecision(
          id: 'sale:${sale['id']}',
          signature: stSignature([sale, 'approved']),
          note: 'Entrega de octubre',
          account: StatementAccount.sales,
          amount: 1000,
          economicDate: DateTime(2026, 10, 1),
        ).toRow()..['revision'] = 1,
      );
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://review.test',
        'test',
        httpClient: MockClient((r) async {
          requests.add(r);
          if (r.url.pathSegments.last == 'mayoreo_sales_reports') {
            return http.Response(
              jsonEncode(r.url.queryParameters.containsKey('id') ? [sale] : []),
              200,
              headers: {'content-type': 'application/json'},
              request: r,
            );
          }
          return accountingResponse(r, data);
        }),
      );
      final b = await StatementRepository(
        client: client,
      ).load(StatementPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31)));
      expect(b.rows('mayoreo_sales_reports'), [sale]);
      expect(analyzeStatement(b).total(StatementAccount.sales), 1000);
      expect(
        requests.any(
          (r) => r.url.queryParameters['id']?.startsWith('in.') == true,
        ),
        isTrue,
      );
      expect(
        requests
            .firstWhere(
              (r) => r.url.pathSegments.last == 'mayoreo_sales_reports',
            )
            .url
            .queryParameters['or'],
        contains('sale_date.is.null'),
      );
      expect(requests.map((r) => r.method).toSet(), {'GET'});
      final purchaseWindow = requests
          .firstWhere(
            (r) => r.url.pathSegments.last == 'maintenance_purchase_orders',
          )
          .url
          .queryParameters['or'];
      expect(purchaseWindow, contains('order_date.gte.2026-09-24'));
      expect(purchaseWindow, contains('order_date.lt.2026-11-08'));
      await client.dispose();
    },
  );
}
