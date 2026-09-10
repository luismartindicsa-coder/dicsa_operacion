import 'package:dicsa_operacion/app/hr/human_resources_dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const profiles = [
  {'id': '1', 'nombre': 'PERSONA UNO', 'empresa': 'PRUEBA'},
  {'id': '2', 'nombre': 'PERSONA DOS', 'empresa': 'PRUEBA'},
];

Map<String, dynamic> event(
  String employee,
  String start,
  String end, {
  String type = 'vacaciones_disfrutadas',
  String status = 'aplicado',
}) => {
  'employee_id': employee,
  'event_type': type,
  'status': status,
  'start_date': start,
  'end_date': end,
  'days_applied': 1,
};

void main() {
  test(
    'past enjoyment and payments do not become active or upcoming vacations',
    () {
      final data = hrDashboardVacationsForTesting(
        profiles: profiles,
        today: DateTime(2026, 9, 9),
        events: [
          event('1', '2026-08-21', '2026-09-04'),
          event('1', '2026-09-09', '2026-09-09', type: 'vacaciones_pagadas'),
          event('2', '2026-09-12', '2026-09-12', type: 'vacaciones_pagadas'),
        ],
      );
      expect(data['active'], 0);
      expect(data['upcoming'], 0);
      expect(data['active_trend'], [1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
    },
  );

  test(
    'active chart counts people throughout their stay and includes today',
    () {
      final data = hrDashboardVacationsForTesting(
        profiles: profiles,
        today: DateTime(2026, 9, 9, 18),
        events: [
          event('1', '2026-08-30', '2026-09-11'),
          event('2', '2026-09-08', '2026-09-09'),
          event('1', '2026-09-08', '2026-09-09'),
          event('not-in-active-profiles', '2026-09-03', '2026-09-11'),
          event('2', '2026-09-03', '2026-09-11', status: 'cancelado'),
        ],
      );
      expect(data['active'], 2);
      expect(data['active_trend'], [1.0, 1.0, 1.0, 1.0, 1.0, 2.0, 2.0]);
      expect(data['upcoming'], 0);
    },
  );

  test(
    'upcoming chart covers all 15 future days with the same events as the card',
    () {
      final data = hrDashboardVacationsForTesting(
        profiles: profiles,
        today: DateTime(2026, 9, 9),
        events: [
          event('1', '2026-09-10', '2026-09-12', status: 'aprobado'),
          event(
            '2',
            '2026-09-24',
            '2026-09-26',
            type: 'vacaciones_pendientes',
            status: 'pendiente',
          ),
          event('1', '2026-09-25', '2026-09-26'),
          event('2', '2026-09-10', '2026-09-11', status: 'cancelado'),
        ],
      );
      expect(data['upcoming'], 2);
      final trend = data['upcoming_trend'] as List<double>;
      expect(trend, [1.0, ...List<double>.filled(13, 0), 1.0]);
      expect(trend.reduce((a, b) => a + b), data['upcoming']);
    },
  );

  testWidgets(
    '15 days fit the existing compact card without dropping empty dates',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: hrDashboardVacationChartForTesting([
                1.0,
                ...List<double>.filled(13, 0),
                2.0,
              ]),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final bars = find.descendant(
        of: find.byType(Row),
        matching: find.byType(Container),
      );
      expect(bars, findsNWidgets(15));
      expect(tester.getSize(bars.at(1)).height, 0);
      expect(tester.getSize(bars.last).height, 54);
    },
  );
}
