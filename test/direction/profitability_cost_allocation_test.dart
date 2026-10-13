import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_models.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_cost_basis.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_inference.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_engine.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_parameters.dart';
import 'profitability_account_test.dart' as fixtures;
import 'profitability_fixtures.dart';

ProfitSources costFixture(
  Map<String, List<ProfitRow>> overrides, {
  int from = 11,
  int to = 17,
}) {
  final base = fixtures.accountFixture(
    overrides: {
      'hr_employee_profiles': [],
      'hr_prenomina_draft_rows': [],
      'hr_payroll_period_closures': [],
      'finanzas_bank_movements': [],
      'services': [],
      'logistics_vehicle_mileage': [],
      ...overrides,
    },
  );
  return ProfitSources(
    period: ProfitPeriod(DateTime(2026, 9, from), DateTime(2026, 9, to)),
    readAt: DateTime(2026, 9, 22),
    tables: base.tables,
  );
}

ProfitRow trip(String id, String site, String unit) => {
  'id': id,
  'due_date': '2026-09-12',
  'area': 'LOGISTICA',
  'status': 'completado',
  'client_id': site,
  'vehicle_id': unit,
  'material_type': 'CARTON',
};

void main() {
  test(
    'confirmed July IMSS belongs to September workforce, other centers stay separate',
    () {
      ProfitAnalysis calculate({required String julyId}) =>
          fixtures.operational(
            costFixture(
              {
                'hr_employee_profiles': [
                  {
                    'id': 'worker',
                    'empresa': 'PLANTA A',
                    'salario': 700,
                    'employment_status': 'ACTIVO',
                  },
                ],
                'finanzas_bank_movements': [
                  {
                    ...fixtures.expense(
                      julyId,
                      304252.15,
                      'GASTOS ADMINISTRATIVOS',
                    ),
                    'movement_date': '2026-07-20',
                    'counterparty_name_snapshot': 'IMSS',
                    'comment': 'IMSS JULIO',
                    'company': 'DICSA',
                    'branch': 'MAZATLAN',
                  },
                  {
                    ...fixtures.expense('september', 316748.88, 'AJUSTES'),
                    'movement_date': '2026-09-17',
                    'counterparty_name_snapshot': 'IMSS',
                    'comment': 'IMSS SEPTIEMBRE',
                    'company': 'DICSA',
                    'branch': 'CELAYA',
                  },
                ],
              },
              from: 1,
              to: 22,
            ),
          );
      final matched = calculate(julyId: 'fin-bank-mov-1784571582468557');
      final independent = calculate(julyId: 'another-workforce');
      expect(fixtures.account(matched).historicalCostEstimate, 0);
      expect(
        fixtures.account(independent).historicalCostEstimate,
        closeTo(304252.15 / 90 * 22, .01),
      );
      expect(
        fixtures
            .account(matched)
            .components
            .where((v) => v.basisLevel == 'allocation')
            .fold<double>(0, (t, v) => t + v.amount!),
        closeTo(316748.88 / 30 * 22, .01),
      );
      expect(
        matched
            .historicalCostEvidence
            .single['documents']
            .single['reconciliation'],
        contains('misma plantilla'),
      );
    },
  );
  test(
    'confirmed FONACOT remittance is not an additional expense; other fees stay',
    () {
      final a = fixtures.operational(
        costFixture(
          {
            'finanzas_bank_movements': [
              {
                ...fixtures.expense(
                  'fin-bank-mov-1788294629527877',
                  3613.76,
                  'GASTOS ADMINISTRATIVOS',
                ),
                'movement_date': '2026-09-01',
                'counterparty_name_snapshot': 'FONACOT',
              },
              {
                ...fixtures.expense('fee', 50, 'GASTOS ADMINISTRATIVOS'),
                'counterparty_name_snapshot': 'FONACOT',
                'comment': 'COMISION ADICIONAL',
              },
            ],
          },
          from: 1,
          to: 22,
        ),
      );
      expect(fixtures.account(a).block('administration'), 50);
      expect(a.payrollWithholdingSettlements.single['amount'], 3613.76);
      expect(a.reportingScope['payroll_withholding_settlements'], hasLength(1));
    },
  );
  test(
    'financial charges have separate lines and never masquerade as RH wages',
    () {
      final a = fixtures.operational(
        fixtures.accountFixture(
          overrides: {
            'finanzas_bank_movements': [
              fixtures.expense('imss', 300, 'IMSS'),
              fixtures.expense('office', 80, 'GASTOS ADMINISTRATIVOS'),
            ],
          },
        ),
      );
      final result = fixtures.account(a);
      for (final line in result.lines.where(
        (l) => l.label.startsWith('Nómina de '),
      )) {
        expect(
          line.components.every(
            (c) =>
                ['salary_reference', 'payroll_period'].contains(c.basisLevel),
          ),
          true,
        );
      }
      expect(
        result.lines.any(
          (l) => l.label == 'Cargas laborales compartidas (Finanzas)',
        ),
        true,
      );
      expect(
        result.lines.any(
          (l) => l.label == 'Cargas laborales de personal dedicado (Finanzas)',
        ),
        true,
      );
      expect(
        result.lines
            .singleWhere(
              (l) => l.label == 'Gastos administrativos distribuidos',
            )
            .costs,
        80,
      );
      expect(
        result.components
            .where((c) => c.reference.contains('bank:imss'))
            .fold<double>(0, (t, c) => t + c.amount!),
        closeTo(300, .001),
      );
    },
  );
  test(
    'material tickets stay covered and ambiguous Maricruz remains unassigned',
    () {
      final a = fixtures.operational(
        costFixture({
          'finanzas_supplier_invoices': [
            for (final entry in [
              ('mauricio', 'MAURICIO ALCALA', 100),
              ('monica', 'MONICA CHAVEZ', 200),
              ('maricruz', 'MARICRUZ QUIROGA ACOSTA', 300),
            ])
              {
                'id': entry.$1,
                'invoice_date': '2026-09-12',
                'provider_name_snapshot': entry.$2,
                'total_amount': entry.$3,
                'origin_type': 'MANUAL',
                'status': 'pendiente',
              },
          ],
          'finanzas_bank_movements': [
            {
              ...fixtures.expense('part-payment', 50, 'OTROS'),
              'linked_supplier_invoice_id': 'monica',
            },
            {
              ...fixtures.expense('maricruz-payment', 50, 'COMPRA DE MATERIAL'),
              'linked_supplier_invoice_id': 'maricruz',
            },
          ],
        }),
      );
      expect(fixtures.account(a).block('other'), 0);
      expect(a.unclassifiedCosts, 300);
      expect(a.retainedOperatingCosts, 300);
      expect(a.unassignedCosts.single['id'], 'invoice:maricruz');
      expect(
        a.modeledResult,
        closeTo(fixtures.account(a).afterOverhead - 300, .001),
      );
      expect(a.reportingScope['result_provisional'], true);
      expect(fixtures.account(a).block('purchase'), 700);
      expect(fixtures.account(a).block('value'), 2600);
      expect(a.coveredMaterialPurchases.length, 2);
      expect(
        a.coveredMaterialPurchases.fold<double>(0, (t, r) => t + r['amount']),
        300,
      );
      expect(
        a.reportingScope['material_invoices_covered_by_tickets'],
        hasLength(2),
      );
    },
  );
  test(
    'Bosch aliases consolidate purchases and services under catalog name',
    () {
      final a = fixtures.operational(
        costFixture({
          'sites': [
            {'id': 's1', 'name': 'BOCHS'},
          ],
          'compras_counterparties': [
            {'id': 'c1', 'name': 'DESPERDICIOS QUERETANA BOSCH'},
          ],
          'men_counterparties': [],
          'services': [trip('bosch-trip', 's1', 'u1')],
        }),
      );
      expect(a.reportCompanies.length, 1);
      expect(
        a.reportCompanies.single.displayName,
        'DESPERDICIOS QUERETANA BOSCH',
      );
      expect(a.reportCompanies.single.services, 1);
      expect(a.reportCompanies.single.account!.block('purchase'), 700);
      expect(
        (a.snapshot()['companies'] as List).single['name'],
        'DESPERDICIOS QUERETANA BOSCH',
      );
    },
  );
  test('empty compras catalog never exposes unrelated accounts', () {
    final a = fixtures.operational(costFixture({'compras_counterparties': []}));
    expect(a.reportCompanies, isEmpty);
    expect(a.companies.where((c) => c.account != null), isNotEmpty);
    expect(a.reportingScope['other_activities'], isNotEmpty);
  });
  test(
    'opaque historical expense is evidence, not new recurring consumption',
    () {
      final a = fixtures.operational(
        costFixture({
          'finanzas_bank_movements': [
            {
              ...fixtures.expense('old', 9000, 'OTROS'),
              'movement_date': '2026-08-20',
              'counterparty_name_snapshot': 'PROVEEDOR',
            },
            {
              ...fixtures.expense('current', 1, 'OTROS'),
              'counterparty_name_snapshot': 'PROVEEDOR',
            },
          ],
        }),
      );
      expect(fixtures.account(a).block('other'), 1);
      expect(a.historicalCostEvidence.single['applied'], false);
    },
  );
  test(
    'current IMSS coverage supersedes same center history despite category change',
    () {
      final a = fixtures.operational(
        costFixture({
          'hr_employee_profiles': [
            {
              'id': 'worker',
              'empresa': 'PLANTA A',
              'salario': 700,
              'salario_flujo': 0,
              'employment_status': 'ACTIVO',
            },
          ],
          'finanzas_bank_movements': [
            {
              ...fixtures.expense('old', 3000, 'GASTOS ADMINISTRATIVOS'),
              'movement_date': '2026-08-15',
              'counterparty_name_snapshot': 'IMSS',
              'comment': 'IMSS AGOSTO',
              'company': 'DICSA',
              'branch': 'CELAYA',
            },
            {
              ...fixtures.expense('new', 3000, 'AJUSTES'),
              'counterparty_name_snapshot': 'IMSS',
              'comment': 'IMSS SEPTIEMBRE',
              'company': 'DICSA',
              'branch': 'CELAYA',
            },
          ],
        }),
      );
      expect(fixtures.account(a).block('payroll'), closeTo(1400, .001));
      expect(fixtures.account(a).block('administration'), 0);
      expect(a.historicalCostEvidence.single['applied'], false);
    },
  );
  test(
    'zero service override suppresses only services inside its validity',
    () {
      final a = fixtures.operational(
        costFixture({
          'sites': [
            {'id': 's1', 'name': 'MONROE'},
          ],
          'compras_counterparties': [
            {'id': 'c1', 'name': 'MONROE'},
          ],
          'men_counterparties': [],
          'services': [
            {...trip('first', 's1', 'u1'), 'material_type': 'BASURA'},
            {
              ...trip('second', 's1', 'u1'),
              'due_date': '2026-09-13',
              'material_type': 'BASURA',
            },
          ],
        }),
        master: ProfitMaster(
          rules: [
            fixtures.concept(
              block: 'income',
              rate: 0,
              from: '2026-09-12',
              to: '2026-09-12',
            ),
          ],
        ),
      );
      expect(fixtures.account(a).block('income'), 5800);
    },
  );
  test(
    'unmatched fuel remains in total while other unit routes stay quantified',
    () {
      final a = fixtures.operational(
        costFixture({
          'services': [trip('run', 's1', 'u1')],
          'logistics_vehicle_mileage': [
            {
              'id': 'km',
              'entry_date': '2026-09-12',
              'vehicle_id': 'u1',
              'kilometers': 90,
            },
          ],
          'logistics_diesel_consumption': [
            {
              'id': 'idle',
              'entry_date': '2026-09-12',
              'vehicle_id': 'u2',
              'liters_requested': 10,
            },
          ],
        }),
      );
      expect(fixtures.account(a).block('fuel'), closeTo(710.1, .001));
      expect(a.retainedOperatingCosts, closeTo(236.7, .001));
      expect(
        a.modeledResult,
        closeTo(
          a.companies.fold<double>(
                0,
                (total, c) => total + (c.account?.afterOverhead ?? 0),
              ) -
              236.7,
          .001,
        ),
      );
    },
  );
  test('unit fuel attribution never uses kilometers of another vehicle', () {
    double run(bool extra) {
      final a = fixtures.operational(
        costFixture({
          'services': [
            trip('a', 's1', 'u1'),
            trip('b', 's2', 'u1'),
            if (extra) trip('a2', 's1', 'u2'),
          ],
          'logistics_vehicle_mileage': [
            {
              'id': 'k1',
              'entry_date': '2026-09-12',
              'vehicle_id': 'u1',
              'kilometers': 100,
            },
            if (extra)
              {
                'id': 'k2',
                'entry_date': '2026-09-12',
                'vehicle_id': 'u2',
                'kilometers': 900,
              },
          ],
          'logistics_diesel_consumption': [
            {
              'id': 'load',
              'entry_date': '2026-09-12',
              'vehicle_id': 'u1',
              'liters_requested': 100,
            },
          ],
        }),
      );
      return fixtures
          .account(a)
          .components
          .where((c) => c.basisLevel == 'fuel_dispatch')
          .fold<double>(0, (t, c) => t + c.amount!);
    }

    expect(run(false), closeTo(1183.5, .001));
    expect(run(true), closeTo(1183.5, .001));
  });
  test(
    'history tops up only the shortfall after comparable actual consumption',
    () {
      ProfitAnalysis run(double? current, {bool unrelated = false}) =>
          fixtures.operational(
            costFixture({
              'finanzas_bank_movements': [
                {
                  ...fixtures.expense('old', 9000, 'GASTOS ADMINISTRATIVOS'),
                  'movement_date': '2026-08-20',
                  'counterparty_name_snapshot': 'CONTADOR',
                },
                if (current != null)
                  {
                    ...fixtures.expense(
                      'new',
                      current,
                      'GASTOS ADMINISTRATIVOS',
                    ),
                    'counterparty_name_snapshot': unrelated
                        ? 'OTRO PROVEEDOR'
                        : 'CONTADOR',
                  },
              ],
            }),
          );
      expect(
        fixtures.account(run(null)).block('administration'),
        closeTo(700, .001),
      );
      final partial = run(100);
      expect(
        fixtures.account(partial).block('administration'),
        closeTo(700, .001),
      );
      expect(
        partial.historicalCostEvidence.single['residual_amount'],
        closeTo(600, .001),
      );
      expect(
        partial.historicalCostEvidence.single['current_amount_offset'],
        100,
      );
      final covered = run(1000);
      expect(
        fixtures.account(covered).block('administration'),
        closeTo(1000, .001),
      );
      expect(covered.historicalCostEvidence.single['applied'], false);
      expect(
        fixtures.account(run(1000, unrelated: true)).block('administration'),
        closeTo(1700, .001),
      );
    },
  );
  test(
    'maintenance pools compare consumption even when repair suppliers change',
    () {
      final a = fixtures.operational(
        costFixture({
          'services': [trip('route', 's1', 'u1')],
          'logistics_vehicle_mileage': [
            {'entry_date': '2026-09-12', 'vehicle_id': 'u1', 'kilometers': 100},
          ],
          'finanzas_bank_movements': [
            {
              ...fixtures.expense('old-repair', 9000, 'MANTENIMIENTO'),
              'movement_date': '2026-08-20',
              'counterparty_name_snapshot': 'TALLER ANTERIOR',
              'company': 'DICSA',
              'branch': 'CELAYA',
            },
            {
              ...fixtures.expense('new-repair', 1000, 'MANTENIMIENTO'),
              'counterparty_name_snapshot': 'TALLER ACTUAL',
              'company': 'DICSA',
              'branch': 'CELAYA',
            },
          ],
        }),
      );
      expect(fixtures.account(a).block('maintenance'), closeTo(1000, .001));
      expect(a.historicalCostEvidence.single['residual_amount'], 0);
    },
  );
  test('a reviewed actual expense also offsets its historical reference', () {
    final sources = costFixture({
      'finanzas_bank_movements': [
        {
          ...fixtures.expense('old', 9000, 'GASTOS ADMINISTRATIVOS'),
          'movement_date': '2026-08-20',
          'counterparty_name_snapshot': 'CONTADOR',
        },
        {
          ...fixtures.expense('new', 1000, 'GASTOS ADMINISTRATIVOS'),
          'counterparty_name_snapshot': 'CONTADOR',
        },
      ],
    });
    final initial = fixtures.operational(sources);
    final fact = initial.costFacts.singleWhere((f) => f.key == 'bank:new');
    final a = analyzeProfitability(
      sources,
      ProfitReview(
        costs: {
          fact.key: ProfitCostRule(
            treatment: ProfitCostTreatment.include,
            kind: ProfitCostKind.other,
            shares: {'site:s1': 1},
            sourceSignature: fact.signature,
            note: 'Revisado',
          ),
        },
      ),
      inferOperations: true,
    );
    expect(a.historicalCostEvidence.single['residual_amount'], 0);
    expect(fixtures.account(a).historicalCostEstimate, 0);
    expect(
      fixtures.account(a).costs - fixtures.account(a).block('purchase'),
      closeTo(1000, .001),
    );
  });
  test(
    'repairs of another unit do not suppress a unit historical shortfall',
    () {
      double run(String currentUnit) {
        final a = fixtures.operational(
          costFixture({
            'services': [trip('a', 's1', 'u1'), trip('b', 's1', 'u2')],
            'logistics_vehicle_mileage': [
              for (final unit in ['u1', 'u2'])
                {
                  'entry_date': '2026-09-12',
                  'vehicle_id': unit,
                  'kilometers': 100,
                },
            ],
            'maintenance_orders': [
              {
                'id': 'old',
                'end_at': '2026-08-20',
                'equipment_id': 'u1',
                'equipment_label': 'CAMION',
                'cost_actual_total': 9000,
                'status': 'cerrado',
              },
              {
                'id': 'new',
                'end_at': '2026-09-12',
                'equipment_id': currentUnit,
                'equipment_label': 'CAMION',
                'cost_actual_total': 1000,
                'status': 'cerrado',
              },
            ],
          }),
        );
        return fixtures.account(a).block('maintenance');
      }

      expect(run('u1'), closeTo(1000, .001));
      expect(run('u2'), closeTo(1700, .001));
    },
  );
  test('monthly consumption is conserved across adjacent views', () {
    double run(int from, int to) => fixtures
        .account(
          fixtures.operational(
            costFixture(
              {
                'compras_tickets': [
                  purchase('p1', 100, 100, 100),
                  {
                    ...purchase('p2', 100, 100, 100),
                    'ticket_date': '2026-09-01',
                  },
                ],
                'finanzas_bank_movements': [
                  fixtures.expense('rent', 3000, 'RENTA MENSUAL SEPTIEMBRE'),
                ],
              },
              from: from,
              to: to,
            ),
          ),
        )
        .block('other');
    expect(run(1, 22), closeTo(2200, .001));
    expect(run(1, 11) + run(12, 22), closeTo(run(1, 22), .001));
  });
  test('one billed service leaves four unbilled services accrued', () {
    double run(bool billed) => fixtures
        .account(
          fixtures.operational(
            costFixture({
              'sites': [
                {'id': 's1', 'name': 'MONROE'},
              ],
              'compras_counterparties': [
                {'id': 'c1', 'name': 'MONROE'},
              ],
              'men_counterparties': [],
              'mayoreo_counterparties': [
                {'id': 'v1', 'name': 'MONROE'},
              ],
              'services': [
                for (var i = 0; i < 5; i++)
                  {...trip('s$i', 's1', 'u1'), 'material_type': 'BASURA'},
              ],
              'mayoreo_material_catalog': [
                {
                  'id': 'service',
                  'name': 'SERVICIO DE RECOLECCION DE BASURA',
                  'unit': 'SERVICIO',
                },
              ],
              'mayoreo_sales_reports': [
                if (billed)
                  {
                    ...sale('s1', 1, 5800),
                    'client_id': 'v1',
                    'material_id': 'service',
                    'material_name_snapshot':
                        'SERVICIO DE RECOLECCION DE BASURA',
                  },
              ],
            }),
          ),
        )
        .block('income');
    expect(run(false), 29000);
    expect(run(true), 29000);
  });
  test('invoice consumption is unchanged by partial or full settlement', () {
    double run(double payment) => fixtures
        .account(
          fixtures.operational(
            costFixture({
              'finanzas_supplier_invoices': [
                {
                  'id': 'invoice',
                  'invoice_date': '2026-09-12',
                  'invoice_folio': 'I',
                  'provider_name_snapshot': 'PROVEEDOR',
                  'total_amount': 1000,
                  'status': 'pendiente',
                  'origin_type': 'MANUAL',
                },
              ],
              'finanzas_bank_movements': [
                if (payment > 0)
                  {
                    ...fixtures.expense('payment', payment, 'SERVICIOS'),
                    'linked_supplier_invoice_id': 'invoice',
                  },
              ],
            }),
          ),
        )
        .block('other');
    for (final payment in [0.0, 200.0, 1000.0]) {
      expect(run(payment), 1000);
    }
  });
  test('consumption coverage honors date ranges and previous named months', () {
    expect(
      profitCostCoverage(DateTime(2026, 9, 11), 'CFE 31 JUL–31 AGO').label,
      '2026-07-31 → 2026-08-31',
    );
    expect(
      profitCostCoverage(DateTime(2026, 9, 11), 'HONORARIOS JULIO').label,
      '2026-07-01 → 2026-07-31',
    );
    expect(
      profitCostCoverage(
        DateTime(2026, 9, 12),
        'DEL 01/08/2026 AL 31/08/2026',
      ).days,
      31,
    );
  });
  test(
    'scope filters output only and preserves outside activity cost shares',
    () {
      final a = fixtures.operational(
        costFixture({
          'compras_tickets': [
            purchase('a', 100, 100, 100),
            {
              ...purchase('b', 300, 300, 300),
              'provider_id': 'outside',
              'provider_name_snapshot': 'PLANTA B',
            },
          ],
          'finanzas_bank_movements': [fixtures.expense('shared', 400, 'OTROS')],
        }),
      );
      expect(a.reportCompanies.map((c) => c.entity.key), ['site:s1']);
      expect(
        fixtures.account(a).block('other'),
        150,
      ); // mean of kg and movements
      expect(fixtures.account(a, 'compras:outside').block('other'), 250);
      expect((a.snapshot()['companies'] as List).length, 1);
      expect((a.reportingScope['other_activities'] as List).length, 1);
    },
  );
  test(
    'confirmed aliases keep purchases and operational costs on one company',
    () {
      expect(profitOperationalName('SETEXMES'), profitOperationalName('SETEX'));
      expect(
        profitOperationalName('BOCHS'),
        profitOperationalName('DESPERDICIOS QUERETANA BOSCH'),
      );
      final a = fixtures.operational(
        costFixture({
          'sites': [
            {'id': 's1', 'name': 'SETEX'},
          ],
          'compras_counterparties': [
            {'id': 'c1', 'name': 'SETEXMES'},
          ],
          'men_counterparties': [],
        }),
      );
      expect(a.reportCompanies.single.entity.key, 'site:s1');
      expect(a.reportCompanies.single.account!.block('purchase'), 700);
    },
  );
  test(
    'idle driver pay remains quantified without charging direct delivery',
    () {
      final a = fixtures.operational(
        costFixture({
          'hr_employee_profiles': [
            {
              'id': 'driver',
              'empresa': 'DICSA CELAYA',
              'salario': 700,
              'salario_flujo': 0,
              'profit_payroll_role': 'driver',
              'employment_status': 'ACTIVO',
            },
          ],
        }),
      );
      expect(fixtures.account(a).block('administration'), 0);
      expect(a.unassignedCosts.fold<double>(0, (t, r) => t + r['amount']), 700);
    },
  );
  test('all legal centers stay included by confirmed scope', () {
    final a = fixtures.operational(
      costFixture({
        'finanzas_bank_movements': [
          {
            ...fixtures.expense('vh', 400, 'OTROS'),
            'company': 'VH',
            'branch': 'MAZATLAN',
          },
        ],
      }),
    );
    expect(fixtures.account(a).block('other'), 400);
    expect(
      fixtures.account(a).components.any((c) => c.rule.contains('VH|MAZATLAN')),
      true,
    );
  });
  test('point six material valuation and purchase basis remain unchanged', () {
    final base = costFixture({});
    final a = fixtures.account(fixtures.operational(base));
    final b = fixtures.account(
      fixtures.operational(
        costFixture({
          'finanzas_bank_movements': [fixtures.expense('cost', 800, 'OTROS')],
        }),
      ),
    );
    expect(a.block('value'), 2600);
    expect(a.block('purchase'), 700);
    expect(b.block('value'), a.block('value'));
    expect(b.block('purchase'), a.block('purchase'));
    expect(b.kg, a.kg);
  });
}
