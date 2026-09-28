import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_engine.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_models.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_parameters.dart';
import 'profitability_fixtures.dart';

ProfitParameter parameter(
  String id,
  ProfitParameterKind kind,
  ProfitRow data, {
  String from = '2026-09-01',
  String? to,
}) => ProfitParameter(
  id: id,
  kind: kind,
  from: DateTime.parse(from),
  to: to == null ? null : DateTime.parse(to),
  note: 'Base verificada para prueba',
  data: data,
);
ProfitMaster operatingMaster({List<ProfitParameter> extra = const []}) =>
    ProfitMaster(
      revision: 1,
      rules: [
        parameter('identity', ProfitParameterKind.identity, {
          'site': 'site:s1',
          'company_group': 'GRUPO A',
          'compras_supplier_id': 'c1',
          'hr_company_identifier': 'PLANTA A',
          'aliases': 'PLANTA A',
        }),
        parameter('recovery', ProfitParameterKind.recovery, {
          'company': 'site:s1',
          'material': 'compras:carton',
          'outputs': [
            {'benchmark': 'ventas:paca', 'yield': .9},
          ],
          'note': 'Ensayo de recuperación',
        }),
        parameter('truck', ProfitParameterKind.vehicle, {
          'unit': 'vehicle:truck',
          'fuel_cost_per_km': 2,
          'maintenance_cost_per_km': 1,
          'fixed_cost_per_service': 10,
        }),
        parameter('process', ProfitParameterKind.process, {
          'company': 'site:s1',
          'material': 'compras:carton',
          'process': 'COMPACTADO',
          'kg_basis': 'received',
          'cost_per_kg': .2,
        }),
        ...extra,
      ],
    );
ProfitOperatingResult operating(
  ProfitAnalysis a, [
  String company = 'site:s1',
]) => a.companies.firstWhere((c) => c.entity.key == company).operating!;

void main() {
  test(
    'partial managerial result survives pending documents, preserves provenance and arithmetic',
    () {
      final a = analyzeProfitability(
        profitFixture(),
        const ProfitReview(),
        master: operatingMaster(),
      );
      final o = operating(a);
      expect(a.pendingCosts, isNotEmpty);
      expect(o.known('value'), 2340); // 400 physical × .90 × weighted sale 6.50
      expect(o.known('purchase'), 700);
      expect(o.known('fuel'), 160);
      expect(o.known('maintenance'), 80);
      expect(o.known('transport'), 10);
      expect(o.known('process'), 80);
      expect(o.contribution, 1310);
      expect(o.partial, isTrue);
      expect(o.total('payroll'), isNull);
      expect(o.amountOf(ProfitSourceType.actual), 700);
      expect(o.confidence, inExclusiveRange(0, 1));
      expect(
        o.components.every((c) => c.reference.isNotEmpty && c.rule.isNotEmpty),
        isTrue,
      );
      expect(a.snapshot()['engine_version'], 3);
      expect(a.snapshot()['master_revision'], 1);
    },
  );
  test(
    'real fuel replaces matching estimate, closed OT replaces only maintenance',
    () {
      final source = profitFixture(
        overrides: {
          'maintenance_orders': [
            {
              'id': 'closed',
              'end_at': '2026-09-12',
              'status': 'cerrado',
              'site_id': 's1',
              'equipment_id': 'truck',
              'cost_actual_total': 55,
            },
          ],
        },
      );
      final base = analyzeProfitability(
        source,
        const ProfitReview(),
        master: operatingMaster(),
      );
      final fact = base.costFacts.firstWhere((f) => f.key == 'bank:fuel');
      final review = ProfitReview(
        costs: {
          fact.key: ProfitCostRule(
            treatment: ProfitCostTreatment.include,
            kind: ProfitCostKind.fuel,
            note: 'Factura y reparto completos',
            sourceSignature: fact.signature,
            shares: {'site:s1': 1},
          ),
        },
      );
      final o = operating(
        analyzeProfitability(source, review, master: operatingMaster()),
      );
      expect(o.known('fuel'), 100);
      expect(o.known('maintenance'), 55);
      expect(
        o
            .inBlock('fuel')
            .where((c) => c.sourceType == ProfitSourceType.estimated),
        isEmpty,
      );
      expect(
        o
            .inBlock('maintenance')
            .where((c) => c.sourceType == ProfitSourceType.estimated),
        isEmpty,
      );
    },
  );
  test(
    'replacement is scoped by day and vehicle; composite transport does not duplicate maintenance',
    () {
      final source = profitFixture(
        overrides: {
          'services': [
            ...profitFixture().rows('services'),
            {
              ...profitFixture().rows('services').single,
              'id': 'trip2',
              'due_date': '2026-09-13',
            },
          ],
          'logistics_vehicle_mileage': [
            ...profitFixture().rows('logistics_vehicle_mileage'),
            {
              'id': 'km2',
              'entry_date': '2026-09-13',
              'vehicle_id': 'truck',
              'kilometers': 40,
            },
          ],
        },
      );
      final fact = analyzeProfitability(
        source,
        const ProfitReview(),
      ).costFacts.firstWhere((f) => f.key == 'bank:fuel');
      final review = ProfitReview(
        costs: {
          fact.key: ProfitCostRule(
            treatment: ProfitCostTreatment.include,
            kind: ProfitCostKind.transport,
            note: 'Transporte completo, mantenimiento incluido',
            sourceSignature: fact.signature,
            shares: {'site:s1': 1},
            includesMaintenance: true,
            coverageVehicle: 'truck',
            coverageStart: DateTime(2026, 9, 12),
            coverageEnd: DateTime(2026, 9, 12),
          ),
        },
      );
      final o = operating(
        analyzeProfitability(source, review, master: operatingMaster()),
      );
      expect(o.known('transport'), 110); // actual first day, fixed second day
      expect(o.known('maintenance'), 40); // only second day estimate
      expect(o.known('fuel'), 240); // separate fuel never absorbed implicitly
    },
  );
  test(
    'dated parameters split costs within one selection and preserve separate plants in one group',
    () {
      final master = ProfitMaster(
        rules: [
          parameter('norte', ProfitParameterKind.identity, {
            'site': 'site:s1',
            'company_group': 'MONROE',
            'compras_supplier_id': 'c1',
          }, to: '2026-09-12'),
          parameter('sur', ProfitParameterKind.identity, {
            'site': 'site:s2',
            'company_group': 'MONROE',
            'compras_supplier_id': 'c1',
          }, from: '2026-09-13'),
          parameter('v1', ProfitParameterKind.vehicle, {
            'unit': 'vehicle:truck',
            'fuel_cost_per_km': 2,
          }, to: '2026-09-12'),
          parameter('v2', ProfitParameterKind.vehicle, {
            'unit': 'vehicle:truck',
            'fuel_cost_per_km': 3,
          }, from: '2026-09-13'),
        ],
      );
      final source = profitFixture(
        overrides: {
          'compras_tickets': [
            purchase('p1', 100, 100, 100),
            {...purchase('p2', 200, 200, 200), 'ticket_date': '2026-09-13'},
          ],
          'services': [
            ...profitFixture().rows('services'),
            {
              ...profitFixture().rows('services').single,
              'id': 't2',
              'due_date': '2026-09-13',
            },
          ],
          'logistics_vehicle_mileage': [
            ...profitFixture().rows('logistics_vehicle_mileage'),
            {
              'id': 'k2',
              'entry_date': '2026-09-13',
              'vehicle_id': 'truck',
              'kilometers': 20,
            },
          ],
        },
      );
      final a = analyzeProfitability(
        source,
        const ProfitReview(),
        master: master,
      );
      expect(operating(a).known('purchase'), 100);
      expect(operating(a, 'site:s2').known('purchase'), 200);
      expect(operating(a).known('fuel'), 220);
      expect(
        operating(a).group,
        '',
      ); // site north validity ended before period end
      expect(operating(a, 'site:s2').group, 'MONROE');
      expect(
        operating(a).contribution,
        isNull,
      ); // unknown material value is never a made-up loss
    },
  );
  test(
    'shared daily km is conserved and attributed by service count, never duplicated',
    () {
      final source = profitFixture(
        overrides: {
          'services': [
            ...profitFixture().rows('services'),
            {
              ...profitFixture().rows('services').single,
              'id': 'trip2',
              'client_id': 's2',
            },
          ],
        },
      );
      final a = analyzeProfitability(
        source,
        const ProfitReview(),
        master: operatingMaster(),
      );
      expect(operating(a).known('fuel'), 80);
      expect(operating(a, 'site:s2').known('fuel'), 80);
      expect(
        operating(a).inBlock('fuel').single.rule,
        contains('1/2 servicios'),
      );
      expect(
        operating(a).inBlock('fuel').single.sourceType,
        ProfitSourceType.estimated,
      );
    },
  );
  test(
    'closed reconciled payroll supersedes dedicated standard across its whole period',
    () {
      final master = operatingMaster(
        extra: [
          parameter('labor', ProfitParameterKind.labor, {
            'company': 'site:s1',
            'role': 'OPERADOR',
            'basis': 'dedicated',
            'period_labor_cost': 2100,
            'working_days': 21,
            'workers': 1,
            'week_days': '7',
          }),
        ],
      );
      final source = profitFixture();
      final fact = analyzeProfitability(
        source,
        const ProfitReview(),
        master: master,
      ).costFacts.firstWhere((f) => f.payrollNet);
      final review = ProfitReview(
        costs: {
          fact.key: ProfitCostRule(
            treatment: ProfitCostTreatment.include,
            kind: ProfitCostKind.payroll,
            shares: {'site:s1': 1},
            recognizedAmount: 777,
            note: 'Costo patronal conciliado',
            sourceSignature: fact.signature,
          ),
        },
      );
      final o = operating(analyzeProfitability(source, review, master: master));
      expect(o.known('payroll'), 777);
      expect(
        o
            .inBlock('payroll')
            .where((c) => c.sourceType == ProfitSourceType.estimated),
        isEmpty,
      );
      expect(o.inBlock('payroll').length, 7);
    },
  );
  test(
    'daily view reuses weekly reconciliation and prorates cents before clipping',
    () {
      final fixture = profitFixture();
      final fact = analyzeProfitability(
        fixture,
        const ProfitReview(),
      ).costFacts.firstWhere((f) => f.key == 'bank:fuel');
      final rule = ProfitCostRule(
        treatment: ProfitCostTreatment.include,
        kind: ProfitCostKind.fuel,
        shares: {'site:s1': 1},
        recognizedAmount: 100.01,
        note: 'Cobertura semanal',
        sourceSignature: fact.signature,
        coverageStart: DateTime(2026, 9, 11),
        coverageEnd: DateTime(2026, 9, 17),
      );
      final daily = ProfitSources(
        period: ProfitPeriod(DateTime(2026, 9, 13), DateTime(2026, 9, 13)),
        readAt: fixture.readAt,
        tables: {
          ...fixture.tables,
          'profit_shared_cost_reviews': [
            {
              'id': 'weekly',
              'period_start': '2026-09-11',
              'period_end': '2026-09-17',
              'revision': 1,
              'costs': {fact.key: rule.toJson()},
            },
          ],
        },
      );
      final a = analyzeProfitability(
        daily,
        const ProfitReview(),
        master: operatingMaster(),
      );
      expect(operating(a).known('fuel'), 14.29);
      expect(a.snapshot()['shared_cost_review_evidence'], isNotEmpty);
      expect(a.review.costs, isEmpty); // no mutation of the period review
    },
  );
  test(
    'historical prices are a comparable fallback, selected-period prices take precedence',
    () {
      final previous = {...sale('old', 100, 100), 'sale_date': '2026-09-01'};
      final onlyPast = profitFixture(
        overrides: {
          'mayoreo_sales_reports': [],
          'profit_history_mayoreo': [previous],
        },
      );
      expect(
        operating(
          analyzeProfitability(
            onlyPast,
            const ProfitReview(),
            master: operatingMaster(),
          ),
        ).known('value'),
        360,
      );
      final both = profitFixture(
        overrides: {
          'profit_history_mayoreo': [previous],
        },
      );
      expect(
        operating(
          analyzeProfitability(
            both,
            const ProfitReview(),
            master: operatingMaster(),
          ),
        ).known('value'),
        2340,
      );
      final otherGrade = profitFixture(
        overrides: {
          'mayoreo_sales_reports': [],
          'profit_history_mayoreo': [
            {...previous, 'material_id': 'other-grade'},
          ],
        },
      );
      expect(
        operating(
          analyzeProfitability(
            otherGrade,
            const ProfitReview(),
            master: operatingMaster(),
          ),
        ).total('value'),
        isNull,
      );
    },
  );
  test(
    'direct service income requires an approved alias and remains separate from material value',
    () {
      final source = profitFixture(
        overrides: {
          'pesadas': [
            {
              'id': 'w1',
              'fecha': '2026-09-12',
              'proveedor': 'PLANTA A',
              'precio': 300,
              'ticket': 'W1',
            },
            {
              'id': 'w2',
              'fecha': '2026-09-12',
              'proveedor': 'PLANTA A SUR',
              'precio': 999,
              'ticket': 'W2',
            },
          ],
        },
      );
      final o = operating(
        analyzeProfitability(
          source,
          const ProfitReview(),
          master: operatingMaster(),
        ),
      );
      expect(o.known('income'), 300);
      expect(o.contribution, 1610);
      expect(o.inBlock('income').first.sourceType, ProfitSourceType.actual);
    },
  );
  test(
    'unknown costs do not inflate amount coverage and explicit zero needs an approved rule',
    () {
      final base = operating(
        analyzeProfitability(
          profitFixture(),
          const ProfitReview(),
          master: operatingMaster(),
        ),
      );
      expect(base.total('other'), isNull);
      final master = operatingMaster(
        extra: [
          parameter('zero', ProfitParameterKind.coverage, {
            'company': 'site:s1',
            'block': 'other',
          }),
        ],
      );
      final o = operating(
        analyzeProfitability(
          profitFixture(),
          const ProfitReview(),
          master: master,
        ),
      );
      expect(o.total('other'), 0);
      expect(o.blockCoverage, greaterThan(base.blockCoverage));
      expect(o.knownAmount, base.knownAmount);
      expect(o.verifiedShare, base.verifiedShare);
    },
  );
  test(
    'overlapping tariffs and aliases to different plants fail atomically; adjacent dates are valid',
    () {
      final rules = [
        parameter('a', ProfitParameterKind.vehicle, {
          'unit': 'type:TRAILER',
          'fuel_cost_per_km': 1,
        }, to: '2026-09-12'),
        parameter('b', ProfitParameterKind.vehicle, {
          'unit': 'type:TRAILER',
          'fuel_cost_per_km': 2,
        }, from: '2026-09-13'),
      ];
      expect(() => ProfitMaster(rules: rules).validate(), returnsNormally);
      expect(
        () => ProfitMaster(
          rules: [
            ...rules,
            parameter('c', ProfitParameterKind.vehicle, {
              'unit': 'type:TRAILER',
              'fuel_cost_per_km': 3,
            }),
          ],
        ).validate(),
        throwsStateError,
      );
      expect(
        () => ProfitMaster(
          rules: [
            parameter('a', ProfitParameterKind.identity, {
              'site': 'site:s1',
              'company_group': 'M',
              'aliases': 'MONROE',
            }),
            parameter('b', ProfitParameterKind.identity, {
              'site': 'site:s2',
              'company_group': 'M',
              'aliases': 'monroe',
            }),
          ],
        ).validate(),
        throwsStateError,
      );
    },
  );
}
