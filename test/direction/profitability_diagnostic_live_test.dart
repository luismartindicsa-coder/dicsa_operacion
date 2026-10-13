import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_models.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_repository.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_engine.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_parameters.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final token = Platform.environment['DICSA_PROFIT_TEST_BEARER'];
  final replayPath = Platform.environment['DICSA_PROFIT_REPLAY_CACHE'];
  test(
    'same-source replay reconciles material price and unit corrections without new costs',
    () async {
      final cache = jsonDecode(await File(replayPath!).readAsString()) as Map;
      final baselinePath = Platform.environment['DICSA_PROFIT_REPLAY_BASELINE'];
      final baseline = baselinePath == null
          ? cache['baseline'] as Map
          : (jsonDecode(await File(baselinePath).readAsString())
                    as Map)['snapshot']
                as Map;
      final source = ProfitSources(
        period: ProfitPeriod(
          DateTime.parse(cache['start']),
          DateTime.parse(cache['end']),
        ),
        readAt: DateTime.parse(cache['read_at']),
        tables: {
          for (final e in (cache['tables'] as Map).entries)
            e.key: (e.value as List)
                .map((r) => Map<String, dynamic>.from(r))
                .toList(),
        },
      );
      final a = analyzeProfitability(
        source,
        ProfitReview.fromJson({
          'revision': baseline['review_revision'],
          'config': cache['review'],
        }),
        master: ProfitMaster.fromJson({
          'revision': baseline['master_revision'],
          'config': cache['master'],
        }),
        inferOperations: true,
      );
      final before = {for (final c in baseline['companies']) c['key']: c};
      final comparison = <ProfitRow>[];
      var inferredPurchaseReduction = 0.0;
      for (final c in a.reportCompanies.where((c) => c.account != null)) {
        final old = before[c.entity.key]['account'] as Map,
            current = c.account!;
        final oldComponents = (old['lines'] as List)
            .expand((l) => l['components'] as List)
            .toList();
        for (final block in ['income', 'purchase']) {
          final previous =
              oldComponents.where((v) => v['block'] == block).toList()..sort(
                (a, b) => (a['id'] as String).compareTo(b['id'] as String),
              );
          final now =
              current.components
                  .where((v) => v.block == block)
                  .map((v) => v.toJson())
                  .toList()
                ..sort(
                  (a, b) => (a['id'] as String).compareTo(b['id'] as String),
                );
          Map<String, dynamic> financialFields(Map row) => {
            for (final key in ['id', 'block', 'date', 'amount', 'source_type'])
              key: row[key],
          };
          final priorById = {for (final r in previous) r['id']: r};
          expect(now.map((r) => r['id']).toSet(), priorById.keys.toSet());
          for (final r in now) {
            final prior = priorById[r['id']] as Map;
            if (block == 'purchase' && r['source_type'] == 'estimated') {
              inferredPurchaseReduction +=
                  (prior['amount'] as num) - (r['amount'] as num);
            } else {
              expect(
                financialFields(r),
                financialFields(prior),
                reason: '${c.displayName}: ${r['id']}',
              );
            }
          }
        }
        final oldRh = oldComponents
            .where(
              (v) => [
                'salary_reference',
                'payroll_period',
              ].contains(v['basis_level']),
            )
            .fold<double>(0, (t, v) => t + v['amount']);
        final newRh = current.components
            .where(
              (v) =>
                  ['salary_reference', 'payroll_period'].contains(v.basisLevel),
            )
            .fold<double>(0, (t, v) => t + v.amount!);
        expect(
          current.costBasis.values.fold<double>(0, (t, v) => t + v),
          closeTo(current.costs, .001),
        );
        comparison.add({
          'name': c.displayName,
          'generated': current.generated,
          'before_generated': old['generated'],
          'value_change': current.generated - old['generated'],
          'before_cost': old['costs'],
          'after_cost': current.costs,
          'reduction': old['costs'] - current.costs,
          'contribution': current.contribution,
          'cost_basis': current.costBasis,
          'payroll_allocation_delta': newRh - oldRh,
        });
      }
      final oldGenerated =
          (baseline['companies'] as List).fold<double>(
            0,
            (t, c) =>
                t + ((c['account']?['generated'] as num?)?.toDouble() ?? 0),
          ) +
          (baseline['reporting_scope']['other_activities'] as List)
              .fold<double>(
                0,
                (t, c) => t + (c['generated'] as num).toDouble(),
              );
      final newGenerated = a.companies.fold<double>(
        0,
        (t, c) => t + (c.account?.generated ?? 0),
      );
      final valueChange = newGenerated - oldGenerated;
      final costReduction =
          a.modeledResult -
          (baseline['reporting_scope']['result_all_activities'] as num) -
          valueChange;
      final originalReserve = (baseline['historical_cost_evidence'] as List)
          .singleWhere(
            (h) => (h['documents'] as List? ?? []).any(
              (d) => d['id'] == 'bank:fin-bank-mov-1784571582468557',
            ),
          );
      expect(
        costReduction,
        closeTo(
          (baselinePath == null ? originalReserve['residual_amount'] : 0) +
              inferredPurchaseReduction,
          .01,
        ),
      );
      final path = Platform.environment['DICSA_PROFIT_TEST_REPORT'];
      if (path != null) {
        await File(path).writeAsString(
          jsonEncode({
            'read_at': cache['read_at'],
            'period': source.period.key,
            'global_reduction': costReduction,
            'inferred_purchase_reduction': inferredPurchaseReduction,
            'global_value_change': valueChange,
            'companies': comparison,
            'snapshot': a.snapshot(),
          }),
        );
      }
      final pdfPath = Platform.environment['DICSA_PROFIT_TEST_PDF'];
      if (pdfPath != null) {
        final monroe = a.reportCompanies.singleWhere(
          (c) => c.displayName == 'MONROE',
        );
        final pdf = ProfitabilityPdfData.fromSnapshot(
          a.snapshot(),
          monroe.entity.key,
        );
        await File(pdfPath).writeAsBytes(await buildProfitabilityPdf(pdf));
      }
    },
    skip: replayPath == null,
  );
  test(
    'audit account valuation and full allocation, read-only',
    () async {
      final db = SupabaseClient(
        Platform.environment['DICSA_PROFIT_TEST_URL']!,
        Platform.environment['DICSA_PROFIT_TEST_KEY']!,
        accessToken: () async => token,
      );
      final bundle = await ProfitabilityRepository(client: db).load(
        ProfitPeriod(
          DateTime.parse(
            Platform.environment['DICSA_PROFIT_TEST_START'] ?? '2026-09-01',
          ),
          DateTime.parse(
            Platform.environment['DICSA_PROFIT_TEST_END'] ?? '2026-09-22',
          ),
        ),
      );
      final a = bundle.analysis;
      final cachePath = Platform.environment['DICSA_PROFIT_SOURCE_CACHE'];
      if (cachePath != null) {
        await File(cachePath).writeAsString(
          jsonEncode({
            'start': profitDateText(bundle.sources.period.start),
            'end': profitDateText(bundle.sources.period.end),
            'read_at': bundle.sources.readAt.toIso8601String(),
            'tables': bundle.sources.tables,
            'review': bundle.review.toJson(),
            'master': bundle.master.toJson(),
            'baseline': a.snapshot(),
          }),
        );
      }
      final output = {
        'analysis': a.snapshot(),
        'american_material_valuation': [
          for (final company in a.companies)
            if (company.account != null)
              for (final line in company.account!.lines)
                if (line.key == 'CARTON AMERICANO')
                  {
                    'company': company.displayName,
                    'visible': a.reportCompanies.contains(company),
                    ...line.toJson(),
                  },
        ],
        'business_sources': {
          for (final table in [
            'compras_tickets',
            'men_tickets',
            'mayoreo_sales_reports',
            'profit_history_mayoreo',
            'compras_material_catalog',
            'mayoreo_material_catalog',
            'material_commercial_catalog_v2',
            'finanzas_bank_movements',
            'finanzas_supplier_invoices',
            'men_cash_vouchers',
            'men_cash_voucher_lines',
            'direction_vault_vouchers',
            'direction_vault_voucher_lines',
            'maintenance_orders',
            'maintenance_purchase_orders',
            'sites',
            'compras_counterparties',
            'mayoreo_counterparties',
            'services',
          ])
            table: bundle.sources.rows(table),
        },
      };
      final path = Platform.environment['DICSA_PROFIT_TEST_REPORT'];
      if (path != null) await File(path).writeAsString(jsonEncode(output));
      expect(a.companies.where((c) => c.account != null), isNotEmpty);
      final visible = a.reportCompanies.where((c) => c.account != null);
      final outside = a.companies.where(
        (c) => c.account != null && !a.reportCompanies.contains(c),
      );
      final reconciled =
          [
            ...visible,
            ...outside,
          ].fold<double>(0, (t, c) => t + c.account!.afterOverhead) -
          a.retainedOperatingCosts;
      expect(reconciled, closeTo(a.modeledResult, .001));
      for (final c in a.companies.where((c) => c.account != null)) {
        expect(
          c.account!.components.every(
            (v) => v.amount != null && v.amount!.isFinite,
          ),
          true,
        );
        for (final covered in a.coveredMaterialPurchases) {
          expect(
            c.account!.components.any(
              (v) => v.reference.startsWith('${covered['id']} ·'),
            ),
            false,
          );
        }
      }
      expect(utf8.encode(jsonEncode(a.snapshot())).length, lessThan(20000000));
      await db.dispose();
    },
    skip: token == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
