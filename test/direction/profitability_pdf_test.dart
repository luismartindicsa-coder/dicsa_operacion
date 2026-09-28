import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_pdf.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_models.dart';
import 'profitability_account_test.dart' show accountFixture, operational;
import 'profitability_payroll_allocation_test.dart' show payrollFixture;
import 'expected_income_pdf_test.dart' show OldIncomeAssets;

int pages(List<int> bytes) =>
    RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;

ProfitRow snapshot() => operational(accountFixture()).snapshot();
ProfitRow firstAccount(ProfitRow s) => (s['companies'] as List).singleWhere(
  (c) => c['key'] == 'site:s1',
)['account'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'selected account preserves displayed totals and is frozen for export',
    () {
      final analysis = operational(accountFixture());
      final s = analysis.snapshot();
      final data = ProfitabilityPdfData.fromSnapshot(s, 'site:s1');
      final a = analysis.companies
          .singleWhere((c) => c.entity.key == 'site:s1')
          .account!;
      expect(data.companyName, 'PLANTA A');
      expect(data.costs, a.costs);
      expect(data.generated, a.generated);
      expect(data.contribution, a.contribution);
      expect(data.materialCosts + data.companyCosts, closeTo(data.costs, .001));
      expect(data.sharedSupport, closeTo(a.sharedSupport, .001));
      expect(data.fileName, 'rentabilidad_planta_a_2026-09-11_2026-09-17.pdf');
      firstAccount(s)['costs'] = 123;
      expect(data.costs, a.costs);
    },
  );

  test('different company and custom period are used exactly', () {
    final s = snapshot()
      ..['start'] = '2026-08-03'
      ..['end'] = '2026-09-18';
    (s['companies'] as List).add({
      'key': 'site:s2',
      'name': 'PLANTA B',
      'account': firstAccount(s),
    });
    final data = ProfitabilityPdfData.fromSnapshot(s, 'site:s2');
    expect(data.companyName, 'PLANTA B');
    expect(data.fileName, 'rentabilidad_planta_b_2026-08-03_2026-09-18.pdf');
    expect(data.periodLabel, '03/08/2026 al 18/09/2026');
    expect(
      () => ProfitabilityPdfData.fromSnapshot(s, 'unknown'),
      throwsStateError,
    );
  });
  test(
    'provisional reconciliation is frozen into the exported report',
    () async {
      final s = snapshot();
      (s['reporting_scope'] as Map)['unclassified_costs'] = 465920;
      final data = ProfitabilityPdfData.fromSnapshot(s, 'site:s1');
      (s['reporting_scope'] as Map)['unclassified_costs'] = 0;
      expect(data.globalUnclassifiedCosts, 465920);
      final bytes = await buildProfitabilityPdf(data);
      expect(pages(bytes), inInclusiveRange(4, 20));
      if (Platform.environment['DICSA_PROFIT_QA'] == '1') {
        await File(
          '/private/tmp/dicsa_residual_provisional.pdf',
        ).writeAsBytes(bytes);
      }
    },
  );

  for (final field in ['costs', 'generated', 'contribution']) {
    test('inconsistent $field cannot be exported', () {
      final s = snapshot();
      firstAccount(s)[field] += 10;
      expect(
        () => ProfitabilityPdfData.fromSnapshot(s, 'site:s1'),
        throwsStateError,
      );
    });
  }
  test('line-level totals must reconcile as well as account totals', () {
    final s = snapshot();
    firstAccount(s)['lines'][0]['value'] += 1;
    expect(
      () => ProfitabilityPdfData.fromSnapshot(s, 'site:s1'),
      throwsStateError,
    );
  });

  test(
    'bases retain formulas without exporting internal ticket identifiers',
    () {
      expect(
        profitPdfReadableBasis('100 × 1.23456789; men:abc,men:def'),
        '100 x 1.2346; 2 registro(s) comparable(s)',
      );
    },
  );

  test(
    'PDF works with bundled fonts and older offline asset manifests',
    () async {
      final data = ProfitabilityPdfData.fromSnapshot(snapshot(), 'site:s1');
      for (final assets in [null, OldIncomeAssets()]) {
        final bytes = await buildProfitabilityPdf(data, assetBundle: assets);
        expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
        expect(pages(bytes), inInclusiveRange(4, 20));
      }
    },
  );

  test('long company names and 100 material rows paginate completely', () async {
    final s = snapshot()
      ..['start'] = '2026-01-01'
      ..['end'] = '2026-12-31';
    final company = (s['companies'] as List).singleWhere(
      (c) => c['key'] == 'site:s1',
    );
    company['name'] =
        'COMPAÑÍA INDUSTRIAL DE RECUPERACIÓN Y APROVECHAMIENTO DE MATERIALES DEL BAJÍO, S.A. DE C.V.';
    final a = firstAccount(s);
    final original = a['lines'] as List;
    a['lines'] = [
      for (var i = 0; i < 100; i++)
        for (final line in original)
          {...line as Map, 'label': '${line['label']} material $i'},
    ];
    for (final key in [
      'generated',
      'costs',
      'contribution',
      'kg',
      'services',
      'kilometers',
    ]) {
      a[key] *= 100;
    }
    final data = ProfitabilityPdfData.fromSnapshot(s, 'site:s1');
    final bytes = await buildProfitabilityPdf(data);
    expect(pages(bytes), greaterThan(8));
    if (Platform.environment['DICSA_PROFIT_PDF_QA'] == '1') {
      final file = File('tmp/pdfs/rentabilidad_stress.pdf');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    }
  });

  test(
    'proportional payroll remains reconciled in transport and direct-delivery PDFs',
    () async {
      final path = Platform.environment['DICSA_PROFIT_PDF_ALLOCATION_INPUT'];
      final s = path == null
          ? operational(payrollFixture()).snapshot()
          : Map<String, dynamic>.from(
              (jsonDecode(await File(path).readAsString()) as Map)['analysis']
                  as Map,
            );
      final names = path == null
          ? ['PLANTA A', 'PLANTA B']
          : ['LICBOX', 'ADRIAN CARDENAS'];
      for (var i = 0; i < names.length; i++) {
        final company = (s['companies'] as List).singleWhere(
          (c) => c['name'] == names[i],
        );
        final data = ProfitabilityPdfData.fromSnapshot(
          s,
          company['key'] as String,
        );
        final transport = data.components
            .where((c) => c['line'] == 'Nómina de transporte compartida')
            .fold<double>(0, (total, c) => total + data.number(c, 'amount'));
        expect(transport, i == 0 ? greaterThan(0) : 0);
        expect(
          data.materialCosts + data.companyCosts,
          closeTo(data.costs, .001),
        );
        expect(
          data
              .bases('administration')
              .any((b) => b.basis.contains('proporciones con igual peso')),
          isTrue,
        );
        final bytes = await buildProfitabilityPdf(data);
        expect(pages(bytes), inInclusiveRange(4, 20));
        if (path != null) {
          final output = File('tmp/pdfs/proportional_${data.fileName}');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes);
        }
      }
    },
  );

  test(
    'real LICBOX cut matches the screen and generates the review PDF',
    () async {
      final path = Platform.environment['DICSA_PROFIT_PDF_INPUT'];
      if (path == null) return;
      final input =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      final s = Map<String, dynamic>.from(input['analysis'] as Map);
      final data = ProfitabilityPdfData.fromSnapshot(
        s,
        'site:ed2972bd-44ee-4ec5-8266-abef691d2b50',
      );
      expect(data.companyName, 'LICBOX');
      expect(data.generated, 50125);
      expect(data.materialCosts, closeTo(40965.22, .005));
      expect(data.costs, closeTo(42216.45, .005));
      expect(data.contribution, closeTo(7908.55, .005));
      expect(data.companyCosts, closeTo(1251.23, .005));
      expect(
        data.sourceAmount('purchase', 'estimated'),
        closeTo(33936.31, .005),
      );
      final bytes = await buildProfitabilityPdf(data);
      final output = File('output/pdf/${data.fileName}');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes);
      expect(pages(bytes), inInclusiveRange(4, 12));
    },
  );
}
