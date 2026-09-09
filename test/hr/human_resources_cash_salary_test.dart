import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/hr/human_resources_nomina_page.dart';

void main() {
  test(
    'official net survives incidence detail, vacations and repeated saves',
    () {
      const p = 'Periodo 35 semanal · 21/08/2026 - 27/08/2026';
      Map<String, dynamic>? draft = {
        'employee_id': 'test',
        'period_label': p,
        'fiscal_net_amount': 2205.28,
        'fiscal_late_deduction_amount': 100,
        'fiscal_absence_amount': 500,
        'cash_absence_deduction_amount': 200,
        'fiscal_vacation_amount': 800,
      };
      for (var i = 0; i < 3; i++) {
        final result = hrPrenominaPrepaidProjectionForTesting(
          period: p,
          employee: {
            'id': 'test',
            'salario': 2205.28,
            'salario_real_percibido': 2205.28,
          },
          contpaq: i == 0
              ? {'employee_id': 'test', 'net': 1530.50, 'vacations': 800}
              : null,
          draft: draft,
          vacations: [],
          attendance: [
            {
              'employee_id': 'test',
              'period_label': p,
              'status': 'falto',
              'source_date': '21/08/2026',
            },
            {
              'employee_id': 'test',
              'period_label': p,
              'status': 'laboro',
              'late_minutes': 60,
              'source_date': '22/08/2026',
            },
          ],
          permissions: [
            {
              'employee_id': 'test',
              'attendance_period_label': p,
              'permission_type': 'permiso_sin_goce',
              'request_unit': 'dia',
              'quantity_days': 1,
              'status': 'aplicado',
              'impact_prenomina': true,
            },
          ],
        );
        expect(result['fiscal'], 1530.50);
        expect(result['total'], 1530.50);
        draft = Map<String, dynamic>.from(result['payload'] as Map);
        final payroll = hrNominaOfficialNetForTesting({
          ...draft,
          'draft_status': 'publicado',
        });
        expect(payroll['fiscal'], 1530.50);
        expect(payroll['total'], 1530.50);
        expect(payroll['receipt_total'], 1530.50);
        expect(payroll['receipt_deductions'], 0);
        expect(payroll['informational'], true);
        final snapshot = draft['source_snapshot'] as Map;
        expect(snapshot['incidences_informational'], true);
        expect(snapshot['attendance_absence_reference'], closeTo(315.04, .001));
        expect(snapshot['attendance_late_reference'], closeTo(39.38, .001));
        expect(snapshot['permission_reference'], closeTo(315.04, .001));
      }
    },
  );

  const period = 'Periodo 35 semanal · 21/08/2026 - 27/08/2026';
  Map<String, dynamic> project({
    double perceived = 2205.28,
    double net = 1530.50,
    Map<String, dynamic>? draft,
  }) => hrPrenominaPrepaidProjectionForTesting(
    period: period,
    employee: {
      'id': 'test',
      'nombre': 'TEST',
      'salario': 2205.28,
      'salario_real_percibido': perceived,
    },
    vacations: [],
    contpaq: {
      'employee_id': 'test',
      'salary': 1530.50,
      'net': net,
      'absence_deduction': 674.78,
    },
    draft: draft,
  );

  test('base-only employee keeps reduced CONTPAQ net, including zero', () {
    for (final net in [1530.50, 0.0, 2400.0]) {
      final result = project(net: net);
      expect(result['cash_salary'], 0);
      expect(result['fiscal'], net);
      expect(result['total'], net);
    }
  });
  test(
    'complement depends on contractual base, never reduced salary or net',
    () {
      final result = project(perceived: 3000);
      expect(result['cash_salary'], closeTo(794.72, 0.001));
      expect(result['total'], closeTo(2325.22, 0.001));
      expect(project(perceived: 2000)['cash_salary'], 0);
    },
  );
  test(
    'stale automatic complement is corrected and stays corrected after save',
    () {
      Map<String, dynamic> draft = {
        'employee_id': 'test',
        'period_label': period,
        'fiscal_net_amount': 1530.50,
        'cash_salary_amount': 674.78,
        'cash_salary_is_manual': false,
        'draft_status': 'borrador',
      };
      for (var i = 0; i < 3; i++) {
        final result = project(draft: draft);
        expect(result['total'], 1530.50);
        draft = Map<String, dynamic>.from(result['payload'] as Map);
        expect(draft['cash_salary_amount'] ?? 0, 0);
      }
    },
  );
  test('explicit RH complement and published amounts remain intact', () {
    for (final patch in [
      {'cash_salary_is_manual': true, 'draft_status': 'borrador'},
      {'cash_salary_is_manual': false, 'draft_status': 'publicado'},
    ]) {
      final result = project(
        draft: {
          'employee_id': 'test',
          'period_label': period,
          'fiscal_net_amount': 1530.50,
          'cash_salary_amount': 100,
          ...patch,
        },
      );
      expect(result['cash_salary'], 100);
      expect(result['total'], 1630.50);
    }
  });
}
