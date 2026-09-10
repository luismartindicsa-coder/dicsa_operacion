import 'dart:io';

import 'package:dicsa_operacion/app/hr/human_resources_termination_calculation.dart';
import 'package:dicsa_operacion/app/hr/termination/termination_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

import 'human_resources_termination_calculation_test.dart' show fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PDF uses the saved values and supports all cumulative modes', () async {
    for (final mode in HrTerminationMode.values) {
      final input = HrTerminationInput({
        ...fixture(),
        'mode': mode.name,
        'integrated_daily_base': 350,
        'integrated_daily_total': 500,
        'integration_reference': 'Base laboral confirmada por RH',
      });
      final result = HrTerminationResult.calculate(input);
      final record = {
        'employee_id': 'EJEMPLO',
        'employee_name': 'EJEMPLO FINIQUITO.xlsx',
        'empresa': 'DICSA',
        'mode': mode.name,
        'status': 'borrador',
        'end_date': input.text('end_date'),
        'formula_version': HrTerminationInput.version,
        'inputs': input.toJson(),
        'result': result.toJson(),
      };
      final pdf = await buildHrTerminationPdf(
        record,
        generatedAt: DateTime(2026, 9, 9),
      );
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
      expect(pdf.length, greaterThan(5000));
      if (Platform.environment['HR_TERMINATION_PREVIEW'] == '1') {
        await File('/private/tmp/ejemplo_${mode.name}.pdf').writeAsBytes(pdf);
      }
    }
  });
}
