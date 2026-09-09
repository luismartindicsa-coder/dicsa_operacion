import 'package:dicsa_operacion/app/hr/human_resources_lateness.dart';
import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('five minute arrival tolerance includes exactly five minutes', () {
    for (final minutes in [-1, 0, 1, 4, 5]) {
      expect(hrEligibleLateMinutes(minutes), 0);
    }
    expect(hrEligibleLateMinutes(6), 6);
    expect(hrEligibleLateMinutes(30), 30);
  });
  test(
    'tolerance applies before period sum and does not reduce official net',
    () {
      const period = 'Periodo 35 semanal · 21/08/2026 - 27/08/2026';
      for (final minutes in [
        [3, 4, 5],
        [5, 6, 30],
      ]) {
        final result = hrPrenominaPrepaidProjectionForTesting(
          period: period,
          employee: {
            'id': 'test',
            'salario': 2800,
            'salario_real_percibido': 2800,
          },
          contpaq: {'employee_id': 'test', 'net': 2100},
          vacations: [],
          attendance: [
            for (var i = 0; i < minutes.length; i++)
              {
                'employee_id': 'test',
                'period_label': period,
                'source_date': '${21 + i}/08/2026',
                'source_mode': 'manual',
                'status': 'laboro',
                'late_minutes': minutes[i],
              },
          ],
        );
        final expected = minutes.last == 5 ? 0 : 36;
        final payload = result['payload'] as Map;
        final snapshot = payload['source_snapshot'] as Map;
        expect(snapshot['attendance_late_reference'], expected / 60 * 50);
        expect(result['fiscal'], 2100);
        expect(result['total'], 2100);
      }
    },
  );
}
