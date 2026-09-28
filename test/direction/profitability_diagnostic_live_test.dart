import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_models.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_repository.dart';

void main() {
  final token = Platform.environment['DICSA_PROFIT_TEST_BEARER'];
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
