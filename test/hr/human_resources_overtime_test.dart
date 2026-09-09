import 'package:dicsa_operacion/app/hr/human_resources_overtime.dart';
import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'daily threshold is strictly greater than fifteen; eligible minutes count in full',
    () {
      for (final minutes in [-1, 0, 1, 14, 15]) {
        expect(hrEligibleOvertimeMinutes(minutes), 0);
      }
      expect(hrEligibleOvertimeMinutes(16), 16);
      expect(hrEligibleOvertimeMinutes(60), 60);
    },
  );
  test('separate short days do not combine into payable overtime', () {
    const period = 'Periodo 35 semanal · 21/08/2026 - 27/08/2026';
    Map<String, dynamic> project(List<int> minutes) =>
        hrPrenominaPrepaidProjectionForTesting(
          period: period,
          employee: {
            'id': 'test',
            'salario': 2205.28,
            'salario_real_percibido': 2205.28,
          },
          vacations: [],
          attendance: [
            for (var i = 0; i < minutes.length; i++)
              {
                'employee_id': 'test',
                'period_label': period,
                'source_date': '${21 + i}/08/2026',
                'source_mode': 'manual',
                'status': 'laboro',
                'overtime_minutes': minutes[i],
              },
          ],
        );
    final short = project([10, 10, 15]);
    expect(short['extra_minutes'], 0);
    expect(short['extra_amount'], 0);
    final mixed = project([10, 15, 16, 60]);
    expect(mixed['extra_minutes'], 76);
    expect(mixed['extra_amount'], project([76])['extra_amount']);
  });
}
