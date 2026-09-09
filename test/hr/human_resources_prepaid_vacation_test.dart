import 'package:dicsa_operacion/app/hr/human_resources_prepaid_vacation.dart';
import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:flutter_test/flutter_test.dart';

const period = 'Periodo 35 semanal · 21/08/2026 - 27/08/2026';
Map<String, dynamic> event(
  String id,
  String type,
  String start,
  String end,
  double days,
) => {
  'id': id,
  'employee_id': '8',
  'exercise_year': 2026,
  'status': 'aplicado',
  'event_type': type,
  'start_date': start,
  'end_date': end,
  'days_applied': days,
  'impact_prenomina': true,
  'attendance_period_label': period,
};
final history = [
  {
    ...event(
      'may-payment',
      'vacaciones_pagadas',
      '2026-05-01',
      '2026-05-01',
      12,
    ),
    'attendance_period_label': 'Mayo',
    'prenomina_sync_status': 'aplicado',
  },
  {
    ...event(
      'june-enjoyment',
      'vacaciones_disfrutadas',
      '2026-06-01',
      '2026-06-06',
      6,
    ),
    'attendance_period_label': 'Junio',
    'prenomina_sync_status': 'aplicado',
  },
  event(
    'period35-enjoyment',
    'vacaciones_disfrutadas',
    '2026-08-24',
    '2026-08-26',
    3,
  ),
];
void main() {
  test(
    'dated prepaid salary coverage ends on Sep 4 and does not erase later worked days',
    () {
      final events = [
        history.first,
        event(
          'dated',
          'vacaciones_disfrutadas',
          '2026-08-21',
          '2026-09-04',
          12,
        ),
      ];
      for (final entry in [
        (DateTime(2026, 8, 21), 7.0),
        (DateTime(2026, 8, 28), 7.0),
        (DateTime(2026, 9, 4), 1.0),
        (DateTime(2026, 9, 11), 0.0),
      ]) {
        final result = hrPrepaidVacationDays(
          events: events,
          periodStart: entry.$1,
          periodEnd: entry.$1.add(const Duration(days: 6)),
        );
        expect(result['dated'] ?? 0, entry.$2);
      }
    },
  );

  test(
    'Aug 21 to Sep 4 covers the whole weekly salary despite bank-day proration',
    () {
      for (final bankDays in [12.0, 14.0]) {
        Map<String, dynamic>? draft;
        final vacations = [
          {...history.first, 'days_applied': bankDays},
          event(
            'rebeca-dates',
            'vacaciones_disfrutadas',
            '2026-08-21',
            '2026-09-04',
            bankDays,
          ),
        ];
        for (var i = 0; i < 3; i++) {
          final result = hrPrenominaPrepaidProjectionForTesting(
            period: period,
            employee: {
              'id': '8',
              'nombre': 'TEST',
              'salario': 2205.40,
              'salario_real_percibido': 4500,
            },
            contpaq: {'employee_id': '8', 'net': 2205.20},
            vacations: vacations,
            draft: draft,
            impacts: [
              {
                'id': 'old-impact',
                'event_kind': 'vacacion',
                'vacation_event_id': 'rebeca-dates',
                'employee_id': '8',
                'period_label': period,
                'period_start_date': '2026-08-21',
                'period_end_date': '2026-08-27',
                'days_applied': 3.27,
                'impact_prenomina': true,
              },
            ],
          );
          expect(result['enjoyed_days'], 7);
          expect(result['days'], 7);
          expect(result['fiscal'], 0);
          expect(result['total'], 0);
          draft = Map<String, dynamic>.from(result['payload'] as Map);
        }
      }
    },
  );

  test(
    'full prepaid week settles both fiscal and flow, including official net',
    () {
      Map<String, dynamic>? draft;
      final vacations = [
        history.first,
        event(
          'full-week',
          'vacaciones_disfrutadas',
          '2026-08-21',
          '2026-08-27',
          7,
        ),
      ];
      for (var i = 0; i < 3; i++) {
        final result = hrPrenominaPrepaidProjectionForTesting(
          period: period,
          employee: {
            'id': '8',
            'nombre': 'TEST',
            'salario': 2205.40,
            'salario_real_percibido': 4500,
          },
          contpaq: {'employee_id': '8', 'net': 2205.20},
          draft: draft,
          vacations: vacations,
        );
        expect(result['days'], 7);
        expect(result['fiscal'], 0);
        expect(result['total'], 0);
        draft = Map<String, dynamic>.from(result['payload'] as Map);
        expect(draft['fiscal_net_amount'], 0);
        expect(draft['cash_salary_amount'], 0);
      }
    },
  );

  test(
    'other-period enjoyment cannot reduce salary; stale draft is restored',
    () {
      const employee = {
        'id': '8',
        'nombre': 'TEST',
        'salario': 2100,
        'salario_real_percibido': 3500,
      };
      Map<String, dynamic> draft = {
        'employee_id': '8',
        'period_label': period,
        'fiscal_net_amount': 1200,
        'cash_salary_amount': 800,
        'cash_salary_is_manual': true,
        'source_snapshot': {
          'prepaid_vacation': {'days': 3, 'fiscal': 900, 'flow': 600},
        },
      };
      for (var i = 0; i < 3; i++) {
        final result = hrPrenominaPrepaidProjectionForTesting(
          period: period,
          employee: employee,
          draft: draft,
          vacations: [
            history.first,
            {
              ...history.last,
              'attendance_period_label':
                  'Periodo 36 semanal · 28/08/2026 - 03/09/2026',
            },
          ],
        );
        expect(result['days'], 0);
        expect(result['enjoyed_days'], 0);
        expect(result['deduction'], 0);
        expect(result['total'], 3500);
        draft = Map<String, dynamic>.from(result['payload'] as Map);
      }
    },
  );
  test(
    'payment alone and enjoyment dates outside period leave ordinary wages intact',
    () {
      for (final vacations in [
        [history.first],
        history.take(2).toList(),
        [
          history.first,
          {
            ...history.last,
            'start_date': '2026-09-01',
            'end_date': '2026-09-03',
          },
        ],
        [
          history.first,
          {...history.last, 'impact_prenomina': false},
        ],
      ]) {
        final result = hrPrenominaPrepaidProjectionForTesting(
          period: period,
          employee: {
            'id': '8',
            'nombre': 'TEST',
            'salario': 2100,
            'salario_real_percibido': 3500,
          },
          contpaq: {'employee_id': '8', 'net': 2100},
          vacations: vacations,
        );
        expect(result['days'], 0);
        expect(result['enjoyed_days'], 0);
        expect(result['total'], 3500);
      }
    },
  );
  test('synchronized enjoyment stays visible only in its allocated period', () {
    final result = hrPrenominaPrepaidProjectionForTesting(
      period: period,
      employee: {
        'id': '8',
        'nombre': 'TEST',
        'salario': 2100,
        'salario_real_percibido': 3500,
      },
      contpaq: {'employee_id': '8', 'net': 2100},
      vacations: [
        history.first,
        {...history.last, 'prenomina_sync_status': 'aplicado'},
      ],
    );
    expect(result['enjoyed_days'], 3);
    expect(result['days'], 3);
    expect(result['total'], 2000);
    expect(
      result['fiscal'],
      1200,
    ); // Salary already covered by vacation advance.
  });
  test('multi-period allocations control both display and deduction', () {
    final vacations = [
      history.first,
      event('span', 'vacaciones_disfrutadas', '2026-08-26', '2026-08-29', 4),
    ];
    final impacts = [
      {
        'id': 'a',
        'event_kind': 'vacacion',
        'vacation_event_id': 'span',
        'employee_id': '8',
        'period_label': period,
        'period_start_date': '2026-08-21',
        'period_end_date': '2026-08-27',
        'days_applied': 2,
        'impact_prenomina': true,
        'prenomina_sync_status': 'aplicado',
      },
      {
        'id': 'b',
        'event_kind': 'vacacion',
        'vacation_event_id': 'span',
        'employee_id': '8',
        'period_label': 'Periodo 36 semanal · 28/08/2026 - 03/09/2026',
        'period_start_date': '2026-08-28',
        'period_end_date': '2026-09-03',
        'days_applied': 2,
        'impact_prenomina': true,
      },
    ];
    for (final label in [period, impacts.last['period_label'] as String]) {
      final result = hrPrenominaPrepaidProjectionForTesting(
        period: label,
        employee: {
          'id': '8',
          'nombre': 'TEST',
          'salario': 2100,
          'salario_real_percibido': 3500,
        },
        contpaq: {'employee_id': '8', 'net': 2100},
        vacations: vacations,
        impacts: impacts,
      );
      expect(result['days'], 2);
      expect(result['enjoyed_days'], 2);
      expect(result['total'], 2500);
      expect(result['fiscal'], 1500);
    }
    final absent = hrPrenominaPrepaidProjectionForTesting(
      period: period,
      employee: {
        'id': '8',
        'nombre': 'TEST',
        'salario': 2100,
        'salario_real_percibido': 3500,
      },
      vacations: vacations,
      impacts: [impacts.last],
    );
    expect(absent['days'], 0);
    expect(absent['enjoyed_days'], 0);
  });

  test(
    'earlier payment covers only current enjoyment after past consumption',
    () {
      final result = hrPrepaidVacationDays(
        events: history,
        periodStart: DateTime(2026, 8, 21),
        periodEnd: DateTime(2026, 8, 27),
      );
      expect(result, {'period35-enjoyment': 3.0});
      final partial = [...history];
      partial[0] = {...partial[0], 'days_applied': 7};
      expect(
        hrPrepaidVacationDays(
          events: partial,
          periodStart: DateTime(2026, 8, 21),
          periodEnd: DateTime(2026, 8, 27),
        ),
        {'period35-enjoyment': 1.0},
      );
    },
  );
  test(
    'unpaid, cancelled, other employee/exercise and future payments cannot cover days',
    () {
      for (final patch in [
        {'status': 'cancelado'},
        {'status': 'aprobado'},
        {'employee_id': '99'},
        {'exercise_year': 2025},
        {'start_date': '2026-09-01', 'end_date': '2026-09-01'},
      ]) {
        expect(
          hrPrepaidVacationDays(
            events: [
              {...history.first, ...patch},
              history.last,
            ],
            periodStart: DateTime(2026, 8, 21),
            periodEnd: DateTime(2026, 8, 27),
          ),
          isEmpty,
        );
      }
    },
  );
  test(
    'cross-period enjoyment consumes advance once, in chronological order',
    () {
      final rows = [
        history.first,
        event(
          'spanning',
          'vacaciones_disfrutadas',
          '2026-08-26',
          '2026-08-29',
          4,
        ),
      ];
      expect(
        hrPrepaidVacationDays(
          events: rows,
          periodStart: DateTime(2026, 8, 21),
          periodEnd: DateTime(2026, 8, 27),
        )['spanning'],
        2,
      );
      expect(
        hrPrepaidVacationDays(
          events: rows,
          periodStart: DateTime(2026, 8, 28),
          periodEnd: DateTime(2026, 9, 3),
        )['spanning'],
        2,
      );
    },
  );
  test(
    'ordinary salary only: three prepaid days preserve four days and bonus; save/reload is idempotent',
    () {
      final employee = {
        'id': '8',
        'nombre': 'COLABORADORA DE PRUEBA',
        'salario': 2100,
        'salario_real_percibido': 3500,
      };
      Map<String, dynamic>? draft = {
        'id': 'draft',
        'employee_id': '8',
        'period_label': period,
        'fiscal_net_amount': 2100,
        'cash_salary_amount': 1400,
        'cash_salary_is_manual': true,
        'manual_bonus_amount': 200,
        'fiscal_vacation_amount': 1125,
        'cash_vacation_amount': 750,
        'source_snapshot': {'preserve': 'yes'},
      };
      for (var i = 0; i < 3; i++) {
        final result = hrPrenominaPrepaidProjectionForTesting(
          period: period,
          employee: employee,
          vacations: history,
          draft: draft,
        );
        expect(result['days'], 3);
        expect(result['deduction'], 1500);
        expect(result['vacation'], 0);
        expect(result['total'], 2200);
        expect(result['fiscal'], 1200);
        draft = Map<String, dynamic>.from(result['payload'] as Map);
        expect(draft['fiscal_net_amount'], 1200);
        expect(draft['cash_salary_amount'], 800);
        expect(draft['fiscal_vacation_amount'] ?? 0, 0);
        expect(draft['cash_vacation_amount'] ?? 0, 0);
        expect((draft['source_snapshot'] as Map)['preserve'], 'yes');
      }
    },
  );
  test(
    'compensation never exceeds ordinary salary or subtracts premium again',
    () {
      final deduction = HrPrepaidVacationDeduction.calculate(
        days: 14,
        perceivedWeekly: 3500,
        fiscalAvailable: 2100,
        flowAvailable: 1400,
      );
      expect(deduction.total, 3500);
      expect(deduction.fiscal, 2100);
      expect(deduction.flow, 1400);
    },
  );
  test(
    'published amounts remain frozen and automatic flow survives repeated saves',
    () {
      final employee = {
        'id': '8',
        'nombre': 'TEST',
        'salario': 2205.40,
        'salario_real_percibido': 2500,
      };
      Map<String, dynamic> draft = {
        'id': 'draft',
        'employee_id': '8',
        'period_label': period,
        'fiscal_net_amount': 2205.40,
        'cash_salary_is_manual': false,
        'draft_status': 'listo',
      };
      double? expected;
      for (var i = 0; i < 3; i++) {
        final result = hrPrenominaPrepaidProjectionForTesting(
          period: period,
          employee: employee,
          vacations: history,
          draft: draft,
        );
        expected ??= result['total'] as double;
        expect(result['total'], closeTo(expected, 0.00001));
        draft = Map<String, dynamic>.from(result['payload'] as Map);
      }
      final published = {...draft, 'draft_status': 'publicado'};
      final frozen = hrPrenominaPrepaidProjectionForTesting(
        period: period,
        employee: employee,
        vacations: [],
        draft: published,
      );
      expect(frozen['total'], closeTo(expected!, 0.00001));
      expect(frozen['days'], 3);
      final historical = hrPrenominaPrepaidProjectionForTesting(
        period: period,
        employee: employee,
        vacations: history,
        draft: {
          'employee_id': '8',
          'period_label': period,
          'fiscal_net_amount': 2205.40,
          'draft_status': 'publicado',
          'fiscal_vacation_amount': 0,
          'cash_vacation_amount': 0,
        },
      );
      expect(historical['total'], 2500);
      expect(historical['deduction'], 0);
    },
  );
}
