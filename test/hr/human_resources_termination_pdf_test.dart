import 'dart:convert';
import 'dart:io';

import 'package:dicsa_operacion/app/hr/human_resources_termination_calculation.dart';
import 'package:dicsa_operacion/app/hr/termination/termination_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

import 'human_resources_termination_calculation_test.dart' show fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> verifyPdf(String name, Map<String, dynamic> record) async {
    final original = jsonEncode(record);
    final pdf = await buildHrTerminationPdf(
      record,
      generatedAt: DateTime(2026, 9, 17),
    );
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    expect(pdf.length, greaterThan(5000));
    // Page dictionaries stay uncompressed in the PDF writer. Count pages, not
    // the /Pages root or the footer's display text.
    expect(
      RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(pdf)),
      hasLength(1),
    );
    expect(
      jsonEncode(record),
      original,
      reason:
          'Export must preserve the saved calculation and its internal review list.',
    );
    if (const bool.fromEnvironment('HR_TERMINATION_PREVIEW') ||
        Platform.environment['HR_TERMINATION_PREVIEW'] == '1') {
      final directory = Directory('/private/tmp/dicsa_termination_pdf_qa');
      await directory.create(recursive: true);
      await File('${directory.path}/$name.pdf').writeAsBytes(pdf);
    }
  }

  for (final mode in HrTerminationMode.values) {
    test('${mode.name} exports one page with saved values', () async {
      await verifyPdf(mode.name, _record(mode));
    });
    test(
      '${mode.name} keeps every concept and long observations on one page',
      () async {
        await verifyPdf('${mode.name}_completo', _record(mode, full: true));
      },
    );
  }

  test(
    'draft with unknown ISR remains one page without modifying review warnings',
    () async {
      final record = _record(
        HrTerminationMode.indemnizacion,
        full: true,
        unknownIsr: true,
      );
      expect((record['result'] as Map)['net'], isNull);
      await verifyPdf('indemnizacion_isr_pendiente', record);
    },
  );

  test('exceptionally long free text still fits on one page', () async {
    final record = _record(HrTerminationMode.indemnizacion, full: true);
    (record['inputs'] as Map)['notes'] =
        '${List.filled(40, 'Observación extensa capturada por Recursos Humanos para comprobar que el contenido completo se conserva.').join(' ')} FIN DE OBSERVACIONES.';
    await verifyPdf('indemnizacion_observaciones_extensas', record);
  });
}

Map<String, dynamic> _record(
  HrTerminationMode mode, {
  bool full = false,
  bool unknownIsr = false,
}) {
  final input = HrTerminationInput({
    ...fixture(),
    'mode': mode.name,
    'integrated_daily_base': 350,
    'integrated_daily_total': 700,
    'integration_reference': 'Base laboral confirmada por RH',
    if (full) ...{
      'weekly_flow': 2694.8,
      'unpaid_days': 4,
      'prior_vacation_days': 6,
      'savings_base': 2100,
      'savings_flow': 1400,
      'commissions_base': 400,
      'commissions_flow': 650,
      'night_bonus_base': 200,
      'night_bonus_flow': 150,
      'attendance_bonus_base': 350,
      'attendance_bonus_flow': 300,
      'paid_aguinaldo_base': 500,
      'paid_aguinaldo_flow': 400,
      'paid_vacation_base': 150,
      'paid_vacation_flow': 100,
      'paid_premium_base': 50,
      'paid_premium_flow': 25,
      'imss': 110,
      'other_fiscal_deductions': 80,
      'flow_deductions': 225,
      'salary_reference':
          'Salario semanal confirmado en el expediente de Personal.',
      'deductions_reference':
          'Deducciones confirmadas por RH en la revisión de separación.',
      'prior_payment_reference':
          'Recibos de aguinaldo, vacaciones y prima del periodo vigente.',
      'notes':
          '${List.filled(5, 'Observación de ejemplo: se conservan los importes y antecedentes capturados por Recursos Humanos.').join(' ')} FIN DE OBSERVACIONES.',
    },
    if (unknownIsr) 'official_isr': '',
  });
  final result = HrTerminationResult.calculate(input).toJson();
  // The export removes this section, not the stored warnings or net validation.
  result['pending'] = [
    ...result['pending'] as List,
    for (var i = 0; i < 20; i++) 'PENDIENTE_INTERNO_NO_IMPRIMIR_$i',
  ];
  return {
    'id': full && !unknownIsr ? 'ejemplo-${mode.name}-completo' : null,
    'revision': full && !unknownIsr ? 3 : null,
    'employee_id': 'EJEMPLO-001',
    'employee_name': full
        ? 'MARIA ELENA LOPEZ MARTINEZ DE LA TORRE - EJEMPLO DE NOMBRE EXTENSO'
        : 'MARIA ELENA LOPEZ MARTINEZ',
    'empresa': 'DICSA',
    'mode': mode.name,
    'status': full && !unknownIsr ? 'revisado' : 'borrador',
    'end_date': input.text('end_date'),
    'formula_version': HrTerminationInput.version,
    'inputs': input.toJson(),
    'result': result,
  };
}
