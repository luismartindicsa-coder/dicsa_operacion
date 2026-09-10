import 'dart:convert';
import 'dart:io';
import 'package:dicsa_operacion/app/hr/human_resources_vacations_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const period = 'Periodo 1 semanal · 26/12/2025 - 01/01/2026';
const eventId = '00000000-0000-4000-8000-000000000003';
const employee = {
  'id': '174',
  'nombre': 'PRUEBA AYALA',
  'salario': 2205.28,
  'salario_real_percibido': 3000,
  'fecha_ingreso': '2023-01-02',
};
Map<String, dynamic> importedPayment() => {
  'id': eventId,
  'employee_id': '174',
  'exercise_year': 2026,
  'event_type': 'vacaciones_pagadas',
  'status': 'aplicado',
  'start_date': '2026-01-02',
  'end_date': '2026-01-02',
  'days_applied': 16,
  'additional_paid_days': 0,
  'attendance_period_label': period,
  'impact_attendance': false,
  'impact_prenomina': false,
  'generate_receipt': true,
  'attendance_sync_status': 'omitido',
  'prenomina_sync_status': 'omitido',
  'import_source': {
    'source_key': 'fixture:paid-2026',
    'amount': null,
    'amount_basis': 'app_calculation',
  },
  'notes': 'Pago importado; cálculo normal con datos del expediente.',
};

void main() {
  test(
    'imported paid days calculate like + Pago even without workbook amount',
    () {
      final e = importedPayment();
      final loaded = hrVacationReloadForTesting(e);
      expect(loaded['paid'], 16);
      expect(loaded['enjoyed'], 0);
      expect(loaded['period'], period);
      expect(loaded['payroll_payment'], true);
      final c = hrVacationCalculationsForTesting(e, employee: employee).single;
      expect(c['vacation_pay'], closeTo(6857.14, .005));
      expect(c['vacation_bonus_pay'], closeTo(1714.29, .005));
      expect(
        (c['transfer_component'] as double) + (c['cash_component'] as double),
        closeTo(8571.43, .005),
      );
      expect(c['isr_method'], 'tarifa_semanal');
      expect(c['is_final'], false);
      final manual = hrVacationCalculationsForTesting({
        ...e,
        'import_source': <String, dynamic>{},
      }, employee: employee);
      expect(manual, [c]);
    },
  );

  testWidgets(
    'imported payment uses editable standard controls and receipt action',
    (tester) async {
      tester.view.physicalSize = const Size(1555, 1012);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: hrVacationTabsForTesting(
              events: [importedPayment()],
              periods: [period],
              employee: employee,
              balance: {
                'employee_id': '174',
                'exercise_year': 2026,
                'base_date_policy': 'manual_rh',
                'base_manual_date': '2023-01-02',
                'manual_override': true,
                'manual_override_reason': 'Fecha del archivo',
                'days_entitled': 16,
              },
              onSave: (v) => saved = v,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir expediente'));
      await tester.pumpAndSettle();
      expect(find.text('Sin importe'), findsNothing);
      expect(find.text('Componentes de pago'), findsOneWidget);
      final days = find.byKey(const ValueKey('vacation-days-$eventId'));
      await tester.ensureVisible(days);
      await tester.pumpAndSettle();
      await tester.enterText(days, '12');
      final extra = find.byKey(const ValueKey('vacation-extra-days-$eventId'));
      await tester.ensureVisible(extra);
      await tester.pumpAndSettle();
      await tester.enterText(extra, '2');
      await tester.pumpAndSettle();
      final receipt = find.byKey(const ValueKey('vacation-receipt-$eventId'));
      await tester.ensureVisible(receipt);
      await tester.pumpAndSettle();
      await tester.tap(receipt);
      await tester.pumpAndSettle();
      expect(saved!['action'], 'receipt');
      expect(saved!['paid'], 12);
      expect(saved!['enjoyed'], 0);
      expect(saved!['manual_date'], '2023-01-02');
      final row = (saved!['events'] as List).single as Map<String, dynamic>;
      expect(row['generate_receipt'], true);
      expect(row['impact_prenomina'], false);
      expect(row['attendance_period_label'], period);
      expect(row.containsKey('import_source'), false);
      expect(
        (saved!['import_sources'] as Map)[eventId],
        importedPayment()['import_source'],
      );
      final c = hrVacationCalculationsForTesting(
        row,
        employee: employee,
      ).single;
      expect(c['vacation_pay'], closeTo(6000, .005));
      expect(c['vacation_bonus_pay'], closeTo(1285.71, .005));
      expect(tester.takeException(), isNull);
    },
  );

  final input = Platform.environment['VACATION_CALC_INPUT'];
  if (input != null) {
    test('export exact app calculations for the backed-up import', () {
      final snapshot = jsonDecode(File(input).readAsStringSync()) as Map;
      final profiles = {
        for (final p in snapshot['profiles'] as List) p['id']: p,
      };
      final balances = {
        for (final b in snapshot['balances'] as List) b['id']: b,
      };
      final output = <Map<String, dynamic>>[];
      for (final raw in snapshot['events'] as List) {
        if (raw['historical_payment_without_amount'] != true) continue;
        final e = Map<String, dynamic>.from(raw as Map);
        final p = Map<String, dynamic>.from(profiles[e['employee_id']] as Map);
        final b = Map<String, dynamic>.from(balances[e['balance_id']] as Map);
        final c = hrVacationCalculationsForTesting(
          e,
          employee: p,
          balance: b,
        ).single;
        expect(c['vacation_pay'], greaterThan(0));
        expect(c['vacation_bonus_pay'], greaterThan(0));
        output.add({
          'event_id': e['id'],
          'balance_id': e['balance_id'],
          'employee_id': e['employee_id'],
          'base_weekly': double.parse('${p['salario']}'),
          'perceived_weekly': double.parse('${p['salario_real_percibido']}'),
          'calculation': c,
        });
      }
      expect(output.length, 35);
      File(
        Platform.environment['VACATION_CALC_OUTPUT']!,
      ).writeAsStringSync(jsonEncode(output));
    });
  }
}
