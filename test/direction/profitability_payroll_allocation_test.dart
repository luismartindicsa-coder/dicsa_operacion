import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_payroll_allocation.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_models.dart';
import 'profitability_account_test.dart'
    show accountFixture, operational, account;
import 'profitability_fixtures.dart' show purchase, payrollLabel;

ProfitPayrollActivity activity(
  String name, {
  double kg = 100,
  double movements = 1,
  double trips = 0,
  double km = 0,
}) => ProfitPayrollActivity(
  name,
  kg: kg,
  movements: movements,
  trips: trips,
  kilometers: km,
);
ProfitRow employee(
  String id,
  String role,
  double wage, {
  String company = 'DICSA CELAYA',
}) => {
  'id': id,
  'empresa': company,
  'salario': wage,
  'salario_flujo': 0,
  'employment_status': 'ACTIVO',
  'profit_payroll_role': role,
};
ProfitSources payrollFixture({
  List<ProfitRow>? employees,
  List<ProfitRow>? published,
  List<ProfitRow>? services,
}) => accountFixture(
  overrides: {
    'compras_tickets': [
      purchase('a', 100, 100, 100),
      {
        ...purchase('b', 300, 300, 300),
        'provider_id': 'c2',
        'provider_name_snapshot': 'PLANTA B',
      },
    ],
    'compras_counterparties': [
      {'id': 'c1', 'name': 'PLANTA A'},
      {'id': 'c2', 'name': 'PLANTA B'},
    ],
    'hr_employee_profiles':
        employees ??
        [
          employee('driver', 'driver', 700),
          employee('yard', 'unclassified', 1400),
        ],
    'hr_prenomina_draft_rows': published ?? [],
    'services': ?services,
  },
);
double rh(ProfitAnalysis a, String company, {String? line}) =>
    account(a, company).components
        .where(
          (c) =>
              ['salary_reference', 'payroll_period'].contains(c.basisLevel) &&
              (line == null || c.line == line),
        )
        .fold<double>(0, (s, c) => s + c.amount!);

void main() {
  test(
    'direct delivery has no transport share, and transport is gradual by trips and km',
    () {
      final rows = [
        activity('direct', kg: 1000, movements: 10),
        activity('near', trips: 3, km: 30),
        activity('far', trips: 1, km: 90),
      ];
      final shares = profitPayrollShares(rows, drivers: true);
      expect(shares['direct']!.share, 0);
      expect(shares['near']!.share, .5); // (.75 trips + .25 km) / 2
      expect(shares['far']!.share, .5);
      final changed = profitPayrollShares([
        rows[0],
        rows[1],
        activity('far', trips: 2, km: 100),
      ], drivers: true);
      expect(changed['far']!.share, greaterThan(.5));
      expect(
        changed.values.fold<double>(0, (s, v) => s + v.share),
        closeTo(1, 1e-12),
      );
    },
  );
  test(
    'yard support averages relative kg and activity without unit dominance',
    () {
      final shares = profitPayrollShares([
        activity('small', kg: 100, movements: 3),
        activity('large', kg: 300, movements: 1),
      ], drivers: false);
      expect(shares['small']!.share, .5);
      expect(shares['large']!.share, .5);
      final scaled = profitPayrollShares([
        activity('small', kg: 100000, movements: 3),
        activity('large', kg: 300000, movements: 1),
      ], drivers: false);
      expect(scaled['small']!.share, .5);
    },
  );
  test('missing metrics and fleet with no trips retain quantified payroll', () {
    final noTrips = profitPayrollShares([
      activity('a', kg: 100),
      activity('b', kg: 300),
    ], drivers: true);
    expect(noTrips['a']!.fallback, isTrue);
    expect(noTrips['a']!.share, 0);
    final empty = profitPayrollShares([
      activity('a', kg: 0, movements: 0),
      activity('b', kg: 0, movements: 0),
    ], drivers: true);
    expect(empty['a']!.share, 0);
    expect(empty.values.fold<double>(0, (s, v) => s + v.share), 0);
    final noKm = profitPayrollShares([
      activity('a', trips: 1),
      activity('b', trips: 3),
    ], drivers: true);
    expect(noKm['a']!.share, .25);
  });
  test(
    'catalog abbreviations require unique multiword matches and personal names are discarded',
    () {
      final tables = <String, List<ProfitRow>>{
        'hr_employee_profiles': [
          {'id': 'h1', 'nombre': 'JOSÉ LÓPEZ RAMÍREZ'},
          {'id': 'h2', 'nombre': 'LUIS PEREZ DIAZ'},
          {'id': 'h3', 'nombre': 'LUIS PEREZ SOTO'},
          {'id': 'h4', 'nombre': 'PEDRO GOMEZ'},
        ],
        'employees': [
          {'id': 'd1', 'full_name': 'JOSE LOPEZ', 'is_driver': true},
          {'id': 'd2', 'full_name': 'LUIS PEREZ', 'is_driver': true},
          {'id': 'd3', 'full_name': 'PEDRO', 'is_driver': true},
        ],
      };
      inferProfitPayrollRoles(tables);
      expect(
        tables['hr_employee_profiles']![0]['profit_payroll_role'],
        'driver',
      );
      expect(
        tables['hr_employee_profiles']!
            .skip(1)
            .every((p) => p['profit_payroll_role'] == 'unclassified'),
        isTrue,
      );
      expect(jsonEncode(tables), isNot(contains('nombre')));
      expect(jsonEncode(tables), isNot(contains('full_name')));
      expect(jsonEncode(tables), isNot(contains('RAMÍREZ')));
    },
  );
  test('two driver records cannot both claim the same payroll profile', () {
    final t = <String, List<ProfitRow>>{
      'hr_employee_profiles': [
        {'id': 'h', 'nombre': 'JOSE LOPEZ RAMIREZ'},
      ],
      'employees': [
        for (final id in ['a', 'b'])
          {'id': id, 'full_name': 'JOSE LOPEZ', 'is_driver': true},
      ],
    };
    inferProfitPayrollRoles(t);
    expect(
      t['hr_employee_profiles']!.single['profit_payroll_role'],
      'unclassified',
    );
  });
  test(
    'source payroll is conserved while direct delivery avoids driver cost',
    () {
      final a = operational(payrollFixture());
      expect(
        rh(a, 'site:s1', line: 'Nómina de transporte compartida'),
        closeTo(700, .001),
      );
      expect(rh(a, 'site:s2', line: 'Nómina de transporte compartida'), 0);
      // A: 25% kg and 1/2 movements; its purchase and trip describe one movement.
      expect(
        rh(a, 'site:s1', line: 'Nómina de patio y soporte'),
        closeTo(1400 * (.25 + .5) / 2, .001),
      );
      expect(rh(a, 'site:s1') + rh(a, 'site:s2'), closeTo(2100, .001));
      expect(
        a.snapshot()['payroll_allocation_model'],
        'activity-proportions-v2',
      );
    },
  );
  test(
    'published group total is split by role without adding profile pay for absent published roles',
    () {
      final published = [
        {
          'id': 'p',
          'employee_id': 'yard',
          'empresa': 'DICSA CELAYA',
          'period_label': payrollLabel,
          'draft_status': 'publicado',
          'fiscal_net_amount': 1000,
        },
      ];
      final a = operational(payrollFixture(published: published));
      expect(rh(a, 'site:s1') + rh(a, 'site:s2'), closeTo(1000, .001));
      expect(rh(a, 'site:s1', line: 'Nómina de transporte compartida'), 0);
    },
  );
  test(
    'dedicated staff stays with its own account even when identified as driver',
    () {
      final a = operational(
        payrollFixture(
          employees: [
            employee('dedicated', 'driver', 700, company: 'PLANTA B'),
          ],
        ),
      );
      expect(account(a, 'site:s2').block('payroll'), closeTo(700, .001));
      expect(account(a, 'site:s1').block('payroll'), 0);
      expect(account(a, 'site:s2').block('administration'), 0);
    },
  );
}
