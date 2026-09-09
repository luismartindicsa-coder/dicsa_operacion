import 'dart:convert';
import 'dart:io';
import 'package:dicsa_operacion/app/hr/human_resources_nomina_page.dart';
import 'package:flutter_test/flutter_test.dart';

const period = 'Periodo 35 semanal · 21/08/2026 - 27/08/2026';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = [
    {
      'employee_id': '1',
      'employee_name': 'COLABORADOR CON INCIDENCIAS INFORMATIVAS',
      'empresa': 'EMPRESA A',
      'period_label': period,
      'draft_status': 'publicado',
      'fiscal_net_amount': 2200,
      'fiscal_late_deduction_amount': 25,
      'cash_salary_amount': 300,
      'cash_vacation_amount': 100,
      'transport_support_amount': 50,
      'holiday_amount': 30,
      'overtime_monetized_amount': 60,
      'manual_bonus_amount': 40,
      'manual_adjustment_amount': -10,
      'cash_isr_amount': 10,
      'cash_absence_deduction_amount': 20,
      'cash_infonavit_deduction_amount': 30,
      'cash_fonacot_deduction_amount': 40,
      'loan_deduction_amount': 50,
      'check_amount': 100,
      'payment_outside_amount': 70,
      'source_snapshot': {'incidences_informational': true},
    },
    {
      'employee_id': '2',
      'employee_name': 'COLABORADOR CON RETENCION DE CHEQUE',
      'empresa': 'EMPRESA B',
      'period_label': period,
      'draft_status': 'publicado',
      'fiscal_net_amount': 2000,
      'check_amount': 2000,
      'manual_adjustment_amount': -315,
      'source_snapshot': {'incidences_informational': true},
    },
    {
      'employee_id': '3',
      'employee_name': 'COLABORADOR CON CALCULO ANTERIOR',
      'empresa': 'EMPRESA C',
      'period_label': period,
      'draft_status': 'publicado',
      'fiscal_net_amount': 1000,
      'fiscal_late_deduction_amount': 25,
      'cash_salary_amount': 200,
      'cash_absence_deduction_amount': 10,
      'payment_outside_amount': 50,
    },
    {
      'employee_id': '4',
      'employee_name': 'COLABORADOR SIN PAGO',
      'period_label': period,
      'draft_status': 'publicado',
    },
  ];

  test(
    'PDF preserves official net, legacy incidence rules, negative flow and outside payment',
    () async {
      final before = jsonEncode(fixture);
      final totals = hrNominaFiscalTotalsForTesting(
        drafts: fixture,
        period: period,
        closed: true,
      );
      expect(totals['fiscal'], 5175);
      expect(totals['deposit'], 3075);
      expect(totals['cheque'], 2100);
      expect(totals['total'], 5610);
      final pdf = await hrNominaPeriodReportPdfForTesting(
        drafts: fixture,
        period: period,
        closed: true,
      );
      expect(pdf.take(4).toList(), [37, 80, 68, 70]);
      expect(jsonEncode(fixture), before);
      expect(
        hrNominaFiscalTotalsForTesting(
          drafts: fixture,
          period: period,
          closed: true,
        ),
        totals,
      );
      final folder = Platform.environment['NOMINA_PDF_QA'];
      if (folder != null) {
        await File('$folder/synthetic.pdf').writeAsBytes(pdf);
      }
    },
  );

  test(
    'long population paginates and preliminary report remains exportable',
    () async {
      final rows = [
        for (var i = 0; i < 110; i++)
          {...fixture[i % 4], 'employee_id': '${i + 1}'},
      ];
      final pdf = await hrNominaPeriodReportPdfForTesting(
        drafts: rows,
        period: period,
        closed: false,
      );
      expect(pdf.take(4).toList(), [37, 80, 68, 70]);
      final folder = Platform.environment['NOMINA_PDF_QA'];
      if (folder != null) {
        await File('$folder/preliminary.pdf').writeAsBytes(pdf);
      }
    },
  );

  final source = Platform.environment['NOMINA_PDF_DRAFTS'];
  final output = Platform.environment['NOMINA_PDF_OUTPUT'];
  if (source != null && output != null) {
    test(
      'generate actual complete period for independent old/new PDF comparison',
      () async {
        final rows = (jsonDecode(File(source).readAsStringSync()) as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        final totals = hrNominaFiscalTotalsForTesting(
          drafts: rows,
          period: period,
          closed: true,
        );
        expect((totals['rows'] as List).length, 78);
        expect(totals['fiscal'], closeTo(148725.80, .001));
        expect(totals['deposit'], closeTo(122888.40, .001));
        expect(totals['cheque'], closeTo(25837.40, .001));
        expect(totals['total'], closeTo(201793.04, .001));
        final pdf = await hrNominaPeriodReportPdfForTesting(
          drafts: rows,
          period: period,
          closed: true,
          generatedAt: DateTime.now(),
        );
        await File(output).writeAsBytes(pdf);
      },
    );
  }
}
