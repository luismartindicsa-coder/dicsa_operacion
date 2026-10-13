import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_engine.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_models.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_parameters.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_account_models.dart';
import 'profitability_fixtures.dart';

ProfitSources accountFixture({
  Map<String, List<ProfitRow>> overrides = const {},
}) => profitFixture(
  overrides: {
    'mayoreo_sales_reports': [
      for (final r in [sale('v1', 100, 500), sale('v2', 300, 2100)])
        {...r, 'material_name_snapshot': 'CARTON NACIONAL EN PACAS'},
    ],
    'services': [
      {
        'id': 't1',
        'due_date': '2026-09-12',
        'area': 'LOGISTICA',
        'status': 'completado',
        'client_id': 's1',
        'vehicle_id': 'truck',
        'material_type': 'CARTON NACIONAL',
      },
    ],
    'logistics_diesel_consumption': [],
    'hr_employee_profiles': [
      {
        'id': 'e1',
        'empresa': 'PLANTA A',
        'salario': 700,
        'salario_flujo': 0,
        'employment_status': 'ACTIVO',
      },
      {
        'id': 'e2',
        'empresa': 'DICSA CELAYA',
        'salario': 700,
        'salario_flujo': 0,
        'employment_status': 'ACTIVO',
      },
      {
        'id': 'e3',
        'empresa': 'DICSA APASEO',
        'salario': 1400,
        'salario_flujo': 0,
        'employment_status': 'ACTIVO',
      },
    ],
    ...overrides,
  },
);
ProfitAnalysis operational(
  ProfitSources s, {
  ProfitMaster master = const ProfitMaster(),
}) => analyzeProfitability(
  s,
  const ProfitReview(),
  master: master,
  inferOperations: true,
);
ProfitAccountResult account(ProfitAnalysis a, [String key = 'site:s1']) =>
    a.companies.singleWhere((c) => c.entity.key == key).account!;
ProfitRow expense(String id, double amount, String category) => {
  'id': id,
  'movement_date': '2026-09-12',
  'debit_amount': amount,
  'category': category,
};
ProfitParameter concept({
  String block = 'containers',
  double rate = 3000,
  String basis = 'monthly',
  String line = 'Toda la cuenta',
  String from = '2026-09-01',
  String? to,
}) => ProfitParameter(
  id: 'account-$block',
  kind: ProfitParameterKind.account,
  from: DateTime.parse(from),
  to: to == null ? null : DateTime.parse(to),
  note: 'Condición de prueba',
  data: {
    'company': 'site:s1',
    'line': line,
    'block': block,
    'rate': rate,
    'quantity': 1,
    'basis': basis,
  },
);
void main() {
  test(
    'cost basis partitions the same total and distinguishes published payroll',
    () {
      final a = account(operational(accountFixture()));
      expect(
        a.costBasis.values.fold<double>(0, (t, v) => t + v),
        closeTo(a.costs, .001),
      );
      expect(
        a.costBasis['documents'],
        940,
      ); // Purchases 700, published RH 140, documented fuel 100.
      expect(a.costBasis['salary_reference'], 2100);
      expect(a.costBasis['other_estimates'], 100); // External scale reference.
      expect(a.costBasis['inferred_purchase'], 0);
    },
  );
  test(
    'American cardboard uses confirmed Celanese sale, not purchase cost',
    () {
      final a = operational(
        accountFixture(
          overrides: {
            'compras_tickets': [
              {
                ...purchase('american', 100, 100, 220),
                'material_name_snapshot': 'CARTON AMERICANO',
              },
            ],
            'mayoreo_material_catalog': [
              {
                'id': 'celanese',
                'name': 'CARTON CELANESE',
                'unit': 'KG',
                'category': 'CARTON',
              },
            ],
            'mayoreo_sales_reports': [
              {
                ...sale('celanese', 200, 770),
                'material_id': 'celanese',
                'material_name_snapshot': 'CARTON CELANESE',
              },
            ],
          },
        ),
      );
      expect(account(a).block('value'), closeTo(385, .001));
      expect(
        account(a).components.where((c) => c.block == 'value').single.rule,
        contains('confirmada'),
      );
    },
  );
  test(
    'AVON only explicitly American cardboard uses Celanese; a trip cannot regrade other cardboard',
    () {
      ProfitAccountResult run(bool withAmericanPurchase) => account(
        operational(
          accountFixture(
            overrides: {
              'sites': [
                {'id': 's1', 'name': 'AVON'},
              ],
              'compras_counterparties': [
                {'id': 'c1', 'name': 'AVON'},
              ],
              'men_counterparties': [],
              'compras_tickets': [
                {
                  ...purchase('national', 100, 100, 100),
                  'material_name_snapshot': 'CARTON NACIONAL',
                },
                {
                  ...purchase('corrugated', 100, 100, 100),
                  'material_name_snapshot': 'CORRUGADO CARTON',
                },
                if (withAmericanPurchase)
                  {
                    ...purchase('american', 100, 100, 220),
                    'material_name_snapshot': 'CARTON AMERICANO',
                  },
              ],
              'services': [
                {
                  'id': 'american-trip',
                  'due_date': '2026-09-12',
                  'area': 'LOGISTICA',
                  'status': 'completado',
                  'client_id': 's1',
                  'vehicle_id': 'truck',
                  'material_type': 'CARTON AMERICANO',
                },
              ],
              'mayoreo_material_catalog': [
                {
                  'id': 'national',
                  'name': 'CARTON NACIONAL',
                  'unit': 'KG',
                  'category': 'CARTON',
                },
                {
                  'id': 'celanese',
                  'name': 'CARTON CELANESE',
                  'unit': 'KG',
                  'category': 'CARTON',
                },
              ],
              'mayoreo_sales_reports': [
                {
                  ...sale('national', 100, 250),
                  'material_id': 'national',
                  'material_name_snapshot': 'CARTON NACIONAL',
                },
                {
                  ...sale('celanese', 200, 770),
                  'material_id': 'celanese',
                  'material_name_snapshot': 'CARTON CELANESE',
                },
              ],
            },
          ),
        ),
      );
      final without = run(false), withPurchase = run(true);
      final emptyAmerican = without.lines.singleWhere(
        (l) => l.key == 'CARTON AMERICANO',
      );
      final valuedAmerican = withPurchase.lines.singleWhere(
        (l) => l.key == 'CARTON AMERICANO',
      );
      expect(emptyAmerican.services, 1);
      expect(emptyAmerican.kg, 0);
      expect(emptyAmerican.block('value'), 0);
      expect(valuedAmerican.kg, 100);
      expect(valuedAmerican.block('value'), closeTo(385, .001));
      for (final result in [without, withPurchase]) {
        expect(
          result.lines.singleWhere((l) => l.key == 'CARTON').block('value'),
          closeTo(590, .001),
        );
      }
    },
  );
  test(
    'family fallback weights catalog sales instead of selecting the cheapest SKU',
    () {
      final a = operational(
        accountFixture(
          overrides: {
            'compras_material_catalog': [
              {
                'id': 'carton',
                'name': 'CARTON',
                'unit': 'KG',
                'category': 'CARTON',
              },
            ],
            'mayoreo_material_catalog': [
              {
                'id': 'ordinary',
                'name': 'ORDINARIO DE PRIMERA',
                'unit': 'KG',
                'category': 'CARTON',
              },
              {
                'id': 'national',
                'name': 'CARTON NACIONAL',
                'unit': 'KG',
                'category': 'CARTON',
              },
            ],
            'mayoreo_sales_reports': [
              {
                ...sale('one', 100, 200),
                'material_id': 'national',
                'material_name_snapshot': 'CARTON NACIONAL',
              },
              {
                ...sale('two', 300, 1200),
                'material_id': 'ordinary',
                'material_name_snapshot': 'ORDINARIO DE PRIMERA',
              },
            ],
          },
        ),
      );
      expect(account(a).block('value'), 1400); // 400 × ((200+1200)/(100+300))
    },
  );
  test(
    'financial, personal and treasury flows stay quantified outside operating costs',
    () {
      final a = operational(
        accountFixture(
          overrides: {
            'finanzas_bank_movements': [
              expense('debt', 600, 'GASTOS FINANCIEROS'),
              expense('personal', 80, 'GASTOS PERSONALES'),
              expense('card', 20, 'ABONO TC'),
              expense('operating', 50, 'GASTO OPERATIVO'),
            ],
          },
        ),
      );
      expect(account(a).block('other'), 50);
      expect(
        a.nonOperatingFlows.fold<double>(
          0,
          (t, r) => t + (profitNumber(r['amount']) ?? 0),
        ),
        700,
      );
      expect(account(a).sharedSupport, closeTo(2150, .001));
      expect(account(a).beforeSharedSupport, greaterThan(0));
      expect(account(a).decision, 'Cubre atención; revisar soporte');
    },
  );
  test('DICSA cash funding does not duplicate RH or real cash purchases', () {
    ProfitRow cash(String id, double amount, String payee, String comment) => {
      ...expense(id, amount, 'GASTOS ADMINISTRATIVOS'),
      'counterparty_name_snapshot': payee,
      'comment': comment,
    };
    final a = operational(
      accountFixture(
        overrides: {
          'finanzas_bank_movements': [
            cash('fund1', 19168.60, 'CHEQUE DICSA', 'PAGO EN EFECTIVO'),
            cash('fund2', 28709.80, 'CHEQUE DICSA', 'PAGO EN EFECTIVO'),
            cash('supplier', 300, 'PROVEEDOR', 'PAGO EN EFECTIVO'),
            cash('unconfirmed', 200, 'CHEQUE DICSA', 'OTRO CONCEPTO'),
          ],
        },
      ),
    );
    final baseline = operational(
      accountFixture(overrides: {'finanzas_bank_movements': []}),
    );
    expect(
      account(a).block('administration'),
      closeTo(account(baseline).block('administration') + 500, .001),
    );
    expect(account(a).block('payroll'), account(baseline).block('payroll'));
    expect(a.nonOperatingFlows.map((r) => r['id']).toSet(), {
      'bank:fund1',
      'bank:fund2',
    });
    expect(
      a.nonOperatingFlows.fold<double>(0, (v, r) => v + r['amount']),
      closeTo(47878.40, .001),
    );
    expect(
      account(a).lines
          .singleWhere((l) => l.key == 'Gastos administrativos distribuidos')
          .label,
      'Gastos administrativos distribuidos',
    );
  });
  test('historic cash funding is not projected as another operating cost', () {
    final a = operational(
      accountFixture(
        overrides: {
          'finanzas_bank_movements': [
            {
              ...expense('old-funding', 9000, 'GASTOS ADMINISTRATIVOS'),
              'movement_date': '2026-09-04',
              'counterparty_name_snapshot': 'CHEQUE DICSA',
              'comment': 'PAGO EN EFECTIVO',
            },
          ],
        },
      ),
    );
    final baseline = operational(
      accountFixture(overrides: {'finanzas_bank_movements': []}),
    );
    expect(account(a).costs, closeTo(account(baseline).costs, .001));
    expect(a.nonOperatingFlows, isEmpty); // Prior funding is outside this cut.
  });
  ProfitRow intake(
    String id,
    double kg, {
    String site = 's1',
    String folio = 'unlinked',
  }) => {
    'id': id,
    'op_date': '2026-09-12',
    'flow': 'IN',
    'inventory_level': 'GENERAL',
    'origin_type': 'DIRECT_PURCHASE',
    'net_kg': kg,
    'counterparty_site_id': site,
    'counterparty': site == 's1' ? 'PLANTA A' : 'PLANTA B',
    'source_commercial_material_id': 'physical',
    'reference': folio,
  };
  const physicalCatalog = [
    {'id': 'physical', 'name': 'CARTON NACIONAL'},
  ];
  test(
    'intake only fills residual kg and carries an inferred purchase cost',
    () {
      final a = operational(
        accountFixture(
          overrides: {
            'material_commercial_catalog_v2': physicalCatalog,
            'inventory_movements_v2': [
              intake('in', 600),
              {...intake('conversion', 500), 'origin_type': 'TRANSFORMATION'},
            ],
          },
        ),
      );
      expect(account(a).kg, 600); // max(600, 400), not 1000
      expect(account(a).block('purchase'), 1050); // 700 + (200 × 700/400)
      expect(account(a).block('value'), 3900);
      expect(
        account(a).assumptions.join(' '),
        contains('Conciliación estimada'),
      );
    },
  );
  test(
    'folio material and kg move both purchase and value to physical plant once',
    () {
      final a = operational(
        accountFixture(
          overrides: {
            'material_commercial_catalog_v2': physicalCatalog,
            'compras_tickets': [],
            'men_tickets': [
              {
                'id': 'retail',
                'ticket_date': '2026-09-13',
                'ticket_number': '84474',
                'counterparty_id': 'm1',
                'counterparty_name_snapshot': 'PLANTA A',
                'commercial_material_id': 'physical',
                'material_label_snapshot': 'CARTON NACIONAL',
                'net_weight': 100,
                'payable_weight': 100,
                'amount_total': 170,
                'direction': 'purchase',
                'status': 'PAGADO',
              },
            ],
            'inventory_movements_v2': [
              intake('in', 100, site: 's2', folio: '84474'),
            ],
          },
        ),
      );
      expect(account(a, 'site:s1').block('purchase'), 0);
      expect(account(a, 'site:s2').block('purchase'), 170);
      expect(account(a, 'site:s2').block('value'), 650);
      expect(
        a.companies
            .where((c) => c.account != null)
            .fold<double>(0, (t, c) => t + c.account!.kg),
        100,
      );
    },
  );
  test(
    'generic cardboard intake does not duplicate American commercial purchases',
    () {
      final a = operational(
        accountFixture(
          overrides: {
            'material_commercial_catalog_v2': physicalCatalog,
            'compras_tickets': [
              {
                ...purchase('american', 400, 400, 880),
                'material_name_snapshot': 'CARTON AMERICANO',
              },
            ],
            'inventory_movements_v2': [intake('generic', 300)],
          },
        ),
      );
      expect(account(a).kg, 400);
      expect(account(a).block('purchase'), 880);
    },
  );
  test(
    'a personal voucher residual retains its rubric and stays outside costs',
    () {
      final a = operational(
        accountFixture(
          overrides: {
            'men_cash_vouchers': [
              {
                'id': 'personal',
                'voucher_date': '2026-09-12',
                'voucher_type': 'expense',
                'folio': 'P1',
                'rubric': 'Personales',
                'total_amount': 125,
              },
            ],
            'men_cash_voucher_lines': [],
          },
        ),
      );
      expect(account(a).block('other'), 0);
      expect(a.nonOperatingFlows.single['amount'], 125);
    },
  );
  test(
    'generic public intake and outgoing inventory cannot duplicate supplier kg',
    () {
      final a = operational(
        accountFixture(
          overrides: {
            'material_commercial_catalog_v2': physicalCatalog,
            'inventory_movements_v2': [
              {...intake('public', 999), 'counterparty': 'PUBLICO'},
              {...intake('out', 999), 'flow': 'OUT'},
            ],
          },
        ),
      );
      expect(account(a).kg, 400);
      expect(account(a).block('purchase'), 700);
    },
  );

  test(
    'five areas quantify an account without manually linking catalogs or adding rates',
    () {
      final a = operational(accountFixture()), r = account(a);
      expect(a.companies.where((c) => c.account != null).length, 1);
      expect(r.block('value'), 2600); // 400 physical kg × weighted 6.50
      expect(r.block('purchase'), 700); // actual payable amounts
      expect(r.block('fuel'), 100);
      expect(
        r.block('payroll'),
        closeTo(140, 0.001),
      ); // closed payroll beats current salary
      expect(
        r.block('administration'),
        closeTo(2100, 0.001),
      ); // both shared RH groups, once each
      expect(r.block('scale'), 100);
      expect(r.contribution, closeTo(-540, 0.001));
      expect(
        r.lines.fold<double>(0, (sum, l) => sum + l.contribution),
        closeTo(r.contribution, 0.001),
      );
      expect(
        r.components.every((c) => c.amount != null && c.amount!.isFinite),
        isTrue,
      );
      expect(
        r.components.every((c) => c.rule.isNotEmpty && c.reference.isNotEmpty),
        isTrue,
      );
      expect(a.snapshot()['inference_model'], 'operational-account-v2');
    },
  );
  test(
    'all same-day shared financial expenses are conserved and split by measured km',
    () {
      final a = operational(
        accountFixture(
          overrides: {
            'services': [
              for (final id in ['s1', 's2'])
                {
                  'id': id,
                  'due_date': '2026-09-12',
                  'area': 'LOGISTICA',
                  'status': 'completado',
                  'client_id': id,
                  'vehicle_id': id,
                  'material_type': 'CARTON',
                },
            ],
            'logistics_vehicle_mileage': [
              for (final (id, km) in [('s1', 100), ('s2', 300)])
                {
                  'id': id,
                  'entry_date': '2026-09-12',
                  'vehicle_id': id,
                  'kilometers': km,
                },
            ],
            'finanzas_bank_movements': [
              expense('f1', 100, 'DIESEL'),
              expense('f2', 300, 'DIESEL'),
              expense('other1', 30, 'GASTO'),
              expense('other2', 70, 'GASTO'),
            ],
          },
        ),
      );
      expect(account(a).block('fuel'), 100);
      expect(account(a, 'site:s2').block('fuel'), 300);
      // General support follows kg/movements, not an equal company count.
      expect(account(a).block('other'), closeTo(100 * 5 / 6, .001));
      expect(account(a, 'site:s2').block('other'), closeTo(100 / 6, .001));
      expect(
        account(a).block('administration') +
            account(a, 'site:s2').block('administration'),
        closeTo(2100, 0.001),
      );
    },
  );
  test(
    'invoice payment and linked maintenance purchase do not duplicate the cost',
    () {
      final a = operational(
        accountFixture(
          overrides: {
            'finanzas_bank_movements': [
              {
                ...expense('payment', 500, 'GASTO'),
                'linked_supplier_invoice_id': 'invoice',
              },
            ],
            'finanzas_supplier_invoices': [
              {
                'id': 'invoice',
                'invoice_date': '2026-09-12',
                'invoice_folio': 'F1',
                'origin_type': 'MANUAL',
                'total_amount': 500,
                'status': 'PAGADO',
              },
            ],
            'maintenance_orders': [
              {
                'id': 'ot',
                'end_at': '2026-09-12',
                'status': 'cerrado',
                'site_id': 's1',
                'cost_actual_total': 200,
              },
            ],
            'maintenance_purchase_orders': [
              {
                'id': 'po',
                'purchased_at': '2026-09-12',
                'status': 'purchased',
                'linked_ot_id': 'ot',
                'actual_total': 200,
              },
            ],
          },
        ),
      );
      expect(account(a).block('other'), 500);
      expect(account(a).block('maintenance'), 200);
    },
  );
  test(
    'fuel uses dispatched logistics liters, without adding the fuel payment again',
    () {
      final a = operational(
        accountFixture(
          overrides: {
            'logistics_diesel_consumption': [
              {
                'id': 'fuel',
                'entry_date': '2026-09-12',
                'vehicle_id': 'truck',
                'liters_purchased': 0,
                'liters_requested': 100,
              },
            ],
          },
        ),
      );
      expect(account(a).block('fuel'), closeTo(2367, 0.001));
      expect(
        account(a).components
            .where((v) => v.block == 'fuel')
            .every((v) => v.basisLevel == 'fuel_dispatch'),
        true,
      );
    },
  );
  test(
    'unit-priced retail wood sales cannot be used as per-kg wholesale benchmarks',
    () {
      final a = operational(
        accountFixture(
          overrides: {
            'compras_tickets': [
              {
                ...purchase('wood', 100, 100, 100),
                'material_name_snapshot': 'LEÑA',
              },
            ],
            'men_tickets': [
              {
                'id': 'sale-by-trip',
                'ticket_date': '2026-09-12',
                'direction': 'sale',
                'status': 'PAGADO',
                'commercial_material_id': 'wood',
                'material_label_snapshot': 'LEÑA',
                'payable_weight': 1,
                'amount_total': 1050,
                'price_at_entry': 1050,
              },
            ],
          },
        ),
      );
      expect(
        account(a).lines.singleWhere((l) => l.key == 'LENA').materialValue,
        0,
      );
    },
  );
  test('wood is quantified as a losing line with break-even compensation', () {
    final a = operational(
      accountFixture(
        overrides: {
          'compras_tickets': [
            {
              ...purchase('wood', 100, 100, 100),
              'material_name_snapshot': 'LEÑA',
            },
          ],
          'services': [
            {
              'id': 'wood-trip',
              'due_date': '2026-09-12',
              'area': 'LOGISTICA',
              'status': 'completado',
              'client_id': 's1',
              'vehicle_id': 'truck',
              'material_type': 'LENA',
            },
          ],
        },
      ),
    );
    final wood = account(a).lines.singleWhere((l) => l.key == 'LENA');
    expect(wood.materialValue, 0);
    expect(wood.kg, 100);
    expect(wood.services, 1);
    expect(wood.contribution, -300);
    expect(wood.additionalPerKg, 3);
    expect(wood.additionalPerService, 300);
  });
  test(
    'MONROE waste charge is income, with distinct North/South plants and actual sales preferred',
    () {
      final base = accountFixture(
        overrides: {
          'sites': [
            {'id': 's1', 'name': 'MONROE'},
            {'id': 's2', 'name': 'MONROE SUR'},
          ],
          'compras_counterparties': [
            {'id': 'c1', 'name': 'MONROE NORTE'},
          ],
          'mayoreo_counterparties': [
            {'id': 'v1', 'name': 'MONROE'},
          ],
          'hr_employee_profiles': [],
          'hr_prenomina_draft_rows': [],
          'services': [
            for (final id in ['s1', 's2'])
              {
                'id': id,
                'due_date': '2026-09-12',
                'area': 'LOGISTICA',
                'status': 'completado',
                'client_id': id,
                'material_type': 'BASURA',
              },
          ],
        },
      );
      final a = operational(base);
      expect(account(a).block('income'), 5800);
      expect(account(a, 'site:s2').block('income'), 5800);
      expect(account(a).block('containers'), closeTo(20657 * 7 / 30, 0.001));
      final real = operational(
        ProfitSources(
          period: base.period,
          readAt: base.readAt,
          tables: {
            ...base.tables,
            'mayoreo_sales_reports': [
              {
                'id': 'service',
                'sale_date': '2026-09-12',
                'client_id': 'v1',
                'material_id': 'servicio',
                'material_name_snapshot': 'RECOLECCION BASURA',
                'approved_amount': 6000,
                'approved_price': 6000,
              },
            ],
          },
        ),
      );
      expect(account(real).block('income'), 6000);
    },
  );
  test(
    'fixed monthly and yearly costs accrue by calendar, including leap February',
    () {
      for (final (year, month, days) in [
        (2026, 2, 28),
        (2028, 2, 29),
        (2026, 4, 30),
        (2026, 1, 31),
      ]) {
        final p = ProfitPeriod(
          DateTime(year, month),
          DateTime(year, month, days),
        );
        expect(profitMonthFraction(p), closeTo(1, 1e-10));
        final source = accountFixture();
        final s = ProfitSources(
          period: p,
          readAt: p.end,
          tables: {
            ...source.tables,
            'hr_prenomina_draft_rows': [],
            'hr_payroll_period_closures': [],
          },
        );
        final r = account(
          operational(
            s,
            master: ProfitMaster(
              rules: [
                concept(from: '2025-01-01'),
                concept(
                  block: 'training',
                  rate: 27000,
                  basis: 'annual',
                  from: '2025-01-01',
                ),
              ],
            ),
          ),
        );
        expect(r.block('containers'), closeTo(3000, 0.001));
        expect(r.block('training'), closeTo(2250, 0.001));
      }
    },
  );
  test(
    'zero concept is respected and a finite dated concept is not charged outside its validity',
    () {
      final a = operational(
        accountFixture(),
        master: ProfitMaster(
          rules: [
            concept(block: 'scale', rate: 0),
            concept(from: '2026-09-13', to: '2026-09-14'),
          ],
        ),
      );
      expect(account(a).block('scale'), 0);
      expect(account(a).block('containers'), 200);
    },
  );
  test(
    'live source salaries cover only days without closed payroll and exclude terminated employees',
    () {
      final a = operational(
        accountFixture(
          overrides: {
            'hr_prenomina_draft_rows': [],
            'hr_employee_profiles': [
              {
                'id': 'active',
                'empresa': 'PLANTA A',
                'salario': 700,
                'salario_flujo': 0,
                'fecha_ingreso': '2026-09-14',
                'employment_status': 'ACTIVO',
              },
              {
                'id': 'left',
                'empresa': 'PLANTA A',
                'salario': 700,
                'salario_flujo': 0,
                'termination_date': '2026-09-12',
                'employment_status': 'BAJA',
              },
            ],
          },
        ),
      );
      expect(account(a).block('payroll'), 600); // 4 + 2 calendar days
    },
  );
  test('replacing a concept preserves past and future conditions', () {
    final previous = concept(from: '2026-01-01', rate: 3000);
    final next = concept(from: '2026-09-13', to: '2026-09-14', rate: 6000);
    final result = ProfitMaster(
      rules: replaceProfitAccountConcept(
        ProfitMaster(rules: [previous]),
        ProfitParameter(
          id: 'new',
          kind: next.kind,
          from: next.from,
          to: next.to,
          note: next.note,
          data: next.data,
        ),
      ),
    );
    result.validate();
    expect(result.rules.length, 3);
    expect(
      result
          .at(ProfitParameterKind.account, DateTime(2026, 9, 12))
          .single
          .number('rate'),
      3000,
    );
    expect(
      result
          .at(ProfitParameterKind.account, DateTime(2026, 9, 13))
          .single
          .number('rate'),
      6000,
    );
    expect(
      result
          .at(ProfitParameterKind.account, DateTime(2026, 9, 15))
          .single
          .number('rate'),
      3000,
    );
  });
  test(
    'document container reference fills only days outside a custom concept',
    () {
      final source = accountFixture(
        overrides: {
          'sites': [
            {'id': 's1', 'name': 'MONROE'},
          ],
          'compras_counterparties': [
            {'id': 'c1', 'name': 'MONROE'},
          ],
          'hr_employee_profiles': [],
          'hr_prenomina_draft_rows': [],
        },
      );
      final r = account(
        operational(
          source,
          master: ProfitMaster(
            rules: [concept(from: '2026-09-13', to: '2026-09-14', rate: 3000)],
          ),
        ),
      );
      expect(
        r.block('containers'),
        closeTo(20657 * 5 / 30 + 3000 * 2 / 30, 0.001),
      );
    },
  );
  test(
    'a named monthly IMSS charge is prorated and a card settlement is not an extra operating expense',
    () {
      final r = account(
        operational(
          accountFixture(
            overrides: {
              'finanzas_bank_movements': [
                {
                  ...expense('imss', 30000, 'AJUSTES'),
                  'comment': 'IMSS SEPTIEMBRE',
                },
                {
                  ...expense('card', 1000, 'AJUSTES'),
                  'comment': 'PAGO TARJETA DE CREDITO',
                },
              ],
            },
          ),
        ),
      );
      // RH is 140 dedicated + 2100 common: employer charges follow that split.
      expect(
        r.block('administration'),
        closeTo(7000 * 2100 / 2240 + 2100, .001),
      );
      expect(r.block('payroll'), closeTo(7000 * 140 / 2240 + 140, .001));
      expect(r.block('other'), 0);
    },
  );
}
