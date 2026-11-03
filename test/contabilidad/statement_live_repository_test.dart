import 'dart:io';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_engine.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_models.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'deployed schema serves a complete paginated read-only statement',
    () async {
      final env = Platform.environment;
      final transport = http.Client();
      var count = 0;
      final client = SupabaseClient(
        env['DICSA_READONLY_URL']!,
        env['DICSA_READONLY_KEY']!,
        headers: {'Authorization': 'Bearer ${env['DICSA_READONLY_TOKEN']}'},
        httpClient: MockClient((r) async {
          expect(
            r.method,
            'GET',
            reason: 'Production verification must remain read-only',
          );
          count++;
          final outbound = http.Request(r.method, r.url)
            ..headers.addAll(r.headers);
          return http.Response.fromStream(await transport.send(outbound));
        }),
      );
      try {
        final b = await StatementRepository(
          client: client,
        ).load(StatementPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31)));
        final a = analyzeStatement(b);
        expect(b.canManage, isTrue);
        expect(b.rows('men_tickets').length, greaterThan(1000));
        expect(
          b.rows('finanzas_supplier_invoice_tickets').length,
          greaterThan(4000),
        );
        expect(
          a.entries
              .singleWhere(
                (e) => e.fact.id == 'conversion:confirmed-bianca-160',
              )
              .amount,
          6000,
        );
        expect(a.complete, isFalse);
        expect(count, greaterThan(25));
        // ignore: avoid_print
        print(
          'Live October: ${a.entries.length} operations, ${a.pending.length} pending, ${a.automaticCount} automatic; GET requests: $count',
        );
      } finally {
        await client.dispose();
        transport.close();
      }
    },
    skip: Platform.environment['DICSA_READONLY_TOKEN'] == null,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
