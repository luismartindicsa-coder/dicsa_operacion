import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const period = 'Periodo 37 semanal · 04/09/2026 - 10/09/2026';
final employees = [
  for (var id = 1; id <= 45; id++)
    {
      'id': '$id',
      'nombre': 'COLABORADOR ${id.toString().padLeft(2, '0')}',
      'empresa': id <= 2 ? 'DICSA' : 'KS',
      'salario': 2205.28,
      'salario_flujo': 0,
      'fiscal_payment_mode': id == 1 ? 'cheque' : 'deposito',
    },
];
final drafts = [
  for (var id = 1; id <= 45; id++)
    {
      'id': 'draft-$id',
      'employee_id': '$id',
      'period_label': period,
      'draft_status': 'listo',
      'fiscal_net_amount': 1800,
      'fiscal_manual_deduction_amount': id == 1 ? 200 : 0,
      'cash_salary_amount': id == 2 || id == 45 ? 0 : 300,
      'cash_salary_is_manual': true,
      'payment_outside_amount': id == 45 ? 0 : 50,
      'manual_adjustment_amount': id == 2 || id == 45 ? 0 : -20,
      'loan_deduction_amount': id == 1 ? 100 : 0,
      'check_amount': id >= 3 && id <= 44 ? 100 : 0,
      'source_snapshot': {
        'contpaq_official_net': 1800,
        'incidences_informational': true,
      },
    },
];

List<List<String>> readEnvelopeXlsx(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final xml = XmlDocument.parse(
    utf8.decode(archive.findFile('xl/worksheets/sheet1.xml')!.content),
  );
  return xml
      .findAllElements('row')
      .map(
        (row) =>
            row.findAllElements('t').map((cell) => cell.innerText).toList(),
      )
      .toList();
}

void main() {
  test(
    'envelope includes outside pay with cheque, adjustments and deductions',
    () {
      final rows = hrPrenominaPeriodProjectionForTesting(
        period: period,
        employees: employees,
        drafts: drafts,
      );
      expect(rows.first['flow_delivery'], 1830);
      expect(rows[1]['flow_delivery'], 50);
      expect(rows[2]['flow_delivery'], 430);
      for (final row in rows) {
        expect(
          row['envelope'],
          row['flow_delivery'],
          reason: 'Employee ${row['id']}',
        );
      }
      expect(rows.last['envelope'], 0);
    },
  );

  test('negative balances never produce a payable envelope', () {
    final row = hrPrenominaPrepaidProjectionForTesting(
      period: period,
      employee: employees[1],
      draft: {...drafts[1], 'loan_deduction_amount': 100},
      vacations: [],
    );
    expect(row['flow_delivery'], -50);
    expect(row['envelope'], 0);
  });

  testWidgets(
    'actual export respects search and company filters across all matching pages',
    (tester) async {
      tester.view.physicalSize = const Size(1555, 1012);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic> snapshot = {};
      Uint8List? exported;
      await tester.pumpWidget(
        MaterialApp(
          home: hrPrenominaGridForTesting(
            period: period,
            employees: employees,
            drafts: drafts,
            onSnapshot: (value) => snapshot = value,
            onAction: (_) {},
            onExportBytes: (bytes) => exported = bytes,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(snapshot['visible_ids'], hasLength(40));
      final periodFlow = snapshot['flow'];
      await tester.tap(find.text('Exportar sobres'));
      await tester.pumpAndSettle();
      final unfiltered = readEnvelopeXlsx(exported!);
      expect(unfiltered.first, ['NO.', 'NOMBRE', 'TOTAL']);
      expect(unfiltered, hasLength(45)); // Header + 44 positive payments.
      expect(unfiltered[1], ['1', 'COLABORADOR 01', '1830.00']);
      expect(unfiltered[2], ['2', 'COLABORADOR 02', '50.00']);
      expect(unfiltered[3], ['3', 'COLABORADOR 03', '430.00']);
      expect(unfiltered.last.first, '44');
      final total = unfiltered
          .skip(1)
          .fold<double>(0, (sum, row) => sum + double.parse(row[2]));
      expect(total, periodFlow);

      await tester.enterText(
        find.byKey(const ValueKey('employee-search')),
        'COLABORADOR 01',
      );
      await tester.pumpAndSettle();
      expect(snapshot['count'], 1);
      exported = null;
      await tester.tap(find.text('Exportar sobres'));
      await tester.pumpAndSettle();
      expect(readEnvelopeXlsx(exported!), [unfiltered.first, unfiltered[1]]);

      await tester.enterText(find.byKey(const ValueKey('employee-search')), '');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Todas las empresas'));
      await tester.tap(find.text('Todas las empresas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('KS').last);
      await tester.pumpAndSettle();
      expect(snapshot['count'], 43);
      expect(snapshot['visible_ids'], hasLength(40));
      exported = null;
      await tester.tap(find.text('Exportar sobres'));
      await tester.pumpAndSettle();
      final companyExport = readEnvelopeXlsx(exported!);
      expect(companyExport, [unfiltered.first, ...unfiltered.skip(3)]);
      expect(companyExport, hasLength(43)); // Header + 42 KS envelopes.
      expect(companyExport.last.first, '44'); // Includes the next page.
      expect(
        companyExport
            .skip(1)
            .fold<double>(0, (sum, row) => sum + double.parse(row[2])),
        snapshot['flow'],
      );

      // Company and search filters compose; DICSA employee 1 stays excluded.
      await tester.enterText(
        find.byKey(const ValueKey('employee-search')),
        'COLABORADOR 0',
      );
      await tester.pumpAndSettle();
      exported = null;
      await tester.tap(find.text('Exportar sobres'));
      await tester.pumpAndSettle();
      expect(readEnvelopeXlsx(exported!), [
        unfiltered.first,
        ...unfiltered.skip(3).take(7),
      ]);

      await tester.enterText(
        find.byKey(const ValueKey('employee-search')),
        'SIN COINCIDENCIAS',
      );
      await tester.pumpAndSettle();
      expect(snapshot['count'], 0);
      exported = null;
      await tester.tap(find.text('Exportar sobres'));
      await tester.pumpAndSettle();
      expect(exported, isNull);
      expect(
        tester
            .widget<OutlinedButton>(
              find.ancestor(
                of: find.text('Exportar sobres'),
                matching: find.byType(OutlinedButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
