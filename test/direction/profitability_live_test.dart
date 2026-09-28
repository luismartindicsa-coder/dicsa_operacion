// Read-only integration test; run only with the existing app session supplied
// through environment variables. Never prints credentials or personnel rows.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_engine.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_models.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_repository.dart';

void main() {
  final token = Platform.environment['DICSA_PROFIT_TEST_BEARER'];
  test(
    'live pilot reads every required source and quantifies accounts with explicit inferences',
    () async {
      final db = SupabaseClient(
        Platform.environment['DICSA_PROFIT_TEST_URL']!,
        Platform.environment['DICSA_PROFIT_TEST_KEY']!,
        accessToken: () async => token,
      );
      final repo = ProfitabilityRepository(client: db);
      final bundle = await repo.load(ProfitPeriod.pilot());
      final source = bundle.sources;
      final a = analyzeProfitability(source, const ProfitReview());
      expect(source.counts.length, profitSourceSpecs.length + 6);
      expect(a.companies, isNotEmpty);
      expect(a.purchases, isNotEmpty);
      expect(a.companies.every((c) => c.contribution == null), true);
      final operational = bundle.analysis;
      final accounts = operational.companies
          .where((c) => c.account != null)
          .toList();
      expect(accounts, isNotEmpty);
      for (final c in accounts) {
        expect(
          c.account!.components.every(
            (v) => v.amount != null && v.amount!.isFinite && v.amount! >= 0,
          ),
          isTrue,
        );
        expect(
          c.account!.contribution,
          closeTo(c.account!.generated - c.account!.costs, 0.001),
        );
      }
      final summary = {
        'operational_accounts': [
          for (final c in accounts)
            {'name': c.entity.name, ...c.account!.toJson()},
        ],
        'read_at': source.readAt.toIso8601String(),
        'period': source.period.key,
        'counts': source.counts,
        'companies': a.companies.length,
        'purchase_tickets': a.purchases.length,
        'purchase_total': a.purchaseTotal,
        'pending_documents': a.pendingCosts.length,
        'benchmark_groups': a.benchmarks.length,
        'issues': a.issues,
        'company_summary': [
          for (final c in a.companies)
            {
              'name': c.entity.name,
              'source': c.entity.source,
              'physical_kg': c.kg,
              'payable_kg': c.payableKg,
              'purchase_amount': c.purchases,
              'services': c.services,
              'decision': c.decision,
            },
        ],
      };
      final path = Platform.environment['DICSA_PROFIT_TEST_REPORT'];
      if (path != null) {
        await File(
          path,
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(summary));
      }
      // ignore: avoid_print
      print(
        'LIVE PILOT: ${accounts.length} quantified accounts; ${a.purchases.length} purchase tickets; ${a.companies.length} source entities; ${a.pendingCosts.length} documents to reconcile; ${a.benchmarks.length} comparable sale groups.',
      );
      for (final issue in a.issues) {
        /* Aggregate observations only. */
        // ignore: avoid_print
        print('SOURCE OBSERVATION: $issue');
      }
      await db.dispose();
    },
    skip: token == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'persist the operational pilot cut through the normal Dirección role',
    () async {
      final db = SupabaseClient(
        Platform.environment['DICSA_PROFIT_TEST_URL']!,
        Platform.environment['DICSA_PROFIT_TEST_KEY']!,
        accessToken: () async => token,
      );
      final repo = ProfitabilityRepository(client: db);
      var bundle = await repo.load(ProfitPeriod.pilot());
      if (bundle.review.revision == 0) {
        final review = await repo.save(bundle.sources.period, bundle.review);
        bundle = ProfitBundle(bundle.sources, review, bundle.master);
      }
      final a = bundle.analysis;
      final history = await repo.history(a.sources.period);
      final existing = history
          .where(
            (r) =>
                (r['payload'] as Map)['evidence_signature'] ==
                    a.evidenceSignature &&
                (r['payload'] as Map)['engine_version'] == ProfitAnalysis.engineVersion &&
                (r['payload'] as Map)['inference_model'] == 'operational-account-v2' &&
                r['review_revision'] == a.review.revision,
          )
          .firstOrNull;
      final id = existing == null
          ? await repo.saveSnapshot(a)
          : profitText(existing['id']);
      final persisted = (await repo.history(
        a.sources.period,
      )).firstWhere((r) => r['id'] == id);
      final payload = Map<String, dynamic>.from(persisted['payload']);
      expect(payload['evidence_signature'], a.evidenceSignature);
      expect(payload['companies'], a.snapshot()['companies']);
      final path = Platform.environment['DICSA_PROFIT_TEST_REPORT'];
      if (path != null) {
        await File('$path.saved.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'snapshot_id': id,
            'period': a.sources.period.key,
            'review_revision': a.review.revision,
            'companies': a.companies.length,
            'pending_documents': a.pendingCosts.length,
            'evidence_signature': a.evidenceSignature,
            'created_at': persisted['created_at'],
          }),
        );
      }
      // ignore: avoid_print
      print(
        'SAVED ACTUAL PILOT: $id; revision ${a.review.revision}; ${a.companies.length} source entities; pending classifications retained.',
      );
      await db.dispose();
    },
    skip:
        token == null || Platform.environment['DICSA_PROFIT_SAVE_PILOT'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
