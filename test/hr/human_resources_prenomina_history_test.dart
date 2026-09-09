import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:flutter_test/flutter_test.dart';

const period = 'Periodo 35 semanal · 21/08/2026 - 27/08/2026';
final imports = [
  for (final entry in [
    ('234', 2205.2),
    ('252', 2205.4),
    ('261', 1877.2),
    ('298', 2202.0),
  ])
    {'employee_id': entry.$1, 'net': entry.$2.toString()},
];
final employees = [
  for (final entry in imports)
    {
      'id': entry['employee_id'],
      'nombre': 'COLABORADOR ${entry['employee_id']}',
      'employment_status': 'baja',
      'termination_date': '2026-09-08',
      'fecha_ingreso': '2020-01-01',
      'salario': 2205.28,
      'salario_flujo': entry['employee_id'] == '252' ? 294.72 : 0,
      'fiscal_payment_mode': ['252', '298'].contains(entry['employee_id'])
          ? 'cheque'
          : 'deposito',
    },
];

void main() {
  test(
    'later baja preserves prior payroll and its deposit/cheque allocation',
    () {
      List<Map<String, dynamic>> project(List<Map<String, dynamic>> people) =>
          hrPrenominaPeriodProjectionForTesting(
            period: period,
            employees: people,
            contpaq: imports,
          );
      final before = project([
        for (final employee in employees)
          {...employee, 'employment_status': 'activo'},
      ]);
      final after = project(employees);
      expect(after, before);
      double sum(String key) => after.fold(0.0, (s, r) => s + (r[key] as num));
      expect(sum('fiscal'), closeTo(8489.80, .001));
      expect(sum('fiscal_deposit'), closeTo(4082.40, .001));
      expect(sum('fiscal_cash'), closeTo(4407.40, .001));
    },
  );

  test(
    'termination period, later periods and missing dates retain exclusion',
    () {
      for (final termination in ['2026-08-20', '2026-08-27', null]) {
        final rows = hrPrenominaPeriodProjectionForTesting(
          period: period,
          employees: [
            {...employees.first, 'termination_date': termination},
          ],
          contpaq: imports,
        );
        expect(rows, isEmpty);
      }
      expect(
        hrPrenominaPeriodProjectionForTesting(
          period: 'Periodo 38 semanal · 11/09/2026 - 17/09/2026',
          employees: employees,
        ),
        isEmpty,
      );
      expect(
        hrPrenominaPeriodProjectionForTesting(
          period: period,
          employees: [
            {...employees.first, 'fecha_ingreso': '2026-09-01'},
          ],
        ),
        isEmpty,
      );
    },
  );

  test('saved published payroll remains visible after termination', () {
    final rows = hrPrenominaPeriodProjectionForTesting(
      period: period,
      employees: [
        {...employees.first, 'termination_date': '2026-08-20'},
      ],
      drafts: [
        {
          'employee_id': '234',
          'period_label': period,
          'draft_status': 'publicado',
          'fiscal_net_amount': 1000,
          'check_amount': 200,
        },
      ],
    );
    expect(rows.single['fiscal'], 1000);
    expect(rows.single['fiscal_cash'], 200);
    expect(rows.single['fiscal_deposit'], 800);
  });
}
