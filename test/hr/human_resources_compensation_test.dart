import 'package:dicsa_operacion/app/hr/human_resources_compensation.dart';
import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:dicsa_operacion/app/hr/human_resources_nomina_page.dart';
import 'package:flutter_test/flutter_test.dart';

const period = 'Periodo 35 semanal · 21/08/2026 - 27/08/2026';
Map<String, dynamic> project({
  double flow = 2694.72,
  double rate = 60,
  bool cheque = false,
  double net = 1890.20,
  Map<String, dynamic>? draft,
  List<Map<String, dynamic>> vacations = const [],
  List<Map<String, dynamic>> attendance = const [],
}) => hrPrenominaPrepaidProjectionForTesting(
  period: period,
  employee: {
    'id': 'test', 'salario': 2205.28,
    // Intentionally inconsistent legacy field: the explicit flow must win.
    'salario_real_percibido': 9999, 'salario_flujo': flow,
    'overtime_hourly_rate': rate,
    'fiscal_payment_mode': cheque ? 'cheque' : 'deposito',
  },
  contpaq: {'employee_id': 'test', 'net': net},
  vacations: vacations,
  attendance: attendance,
  draft: draft,
);
Map<String, dynamic> payload(Map<String, dynamic> result) =>
    Map<String, dynamic>.from(result['payload'] as Map);

void main() {
  test('Personal total is base plus explicit flow, including zero', () {
    for (final flow in [0.0, 2694.72, 3009.76]) {
      final pay = HrEmployeeCompensation.fromRow({
        'salario': 2205.28,
        'salario_flujo': flow,
        'salario_real_percibido': 9999,
        'overtime_hourly_rate': 80,
        'fiscal_payment_mode': 'cheque',
      });
      expect(pay.flow, flow);
      expect(pay.total, closeTo(2205.28 + flow, .001));
      final reopened = HrEmployeeCompensation.fromRow(pay.toRow());
      expect(reopened.total, pay.total);
      expect(reopened.fiscalByCheck, true);
      expect(reopened.overtimeHourlyRate, 80);
    }
  });
  test('legacy profiles preserve existing complement and defaults', () {
    final pay = HrEmployeeCompensation.fromRow({
      'salario': 2205.28,
      'salario_real_percibido': 4900,
    });
    expect(pay.flow, 2694.72);
    expect(pay.overtimeHourlyRate, 60);
    expect(pay.fiscalByCheck, false);
  });
  test('explicit flow never compensates reduced or zero CONTPAQ net', () {
    for (final net in [0.0, 1530.50, 1890.20, 2500.0]) {
      for (final flow in [0.0, 2694.72, 3009.76]) {
        final result = project(flow: flow, net: net);
        expect(result['fiscal'], net);
        expect(result['cash_salary'], flow);
        expect(result['total'], closeTo(net + flow, .001));
      }
    }
  });
  test('manual zero stays zero through repeated saves, publish and receipt', () {
    Map<String, dynamic> draft = {
      'employee_id': 'test',
      'period_label': period,
      'cash_salary_amount': 0,
      'cash_salary_is_manual': true,
    };
    for (var i = 0; i < 3; i++) {
      final result = project(draft: draft);
      expect(result['cash_salary'], 0);
      expect(result['total'], 1890.20);
      draft = payload(result);
      expect(draft['cash_salary_amount'], 0);
      final payroll = hrNominaOfficialNetForTesting({
        ...draft,
        'draft_status': 'publicado',
      });
      expect(payroll['total'], 1890.20);
      expect(payroll['receipt_total'], 1890.20);
    }
    // Older saves converted manual zero into null; the manual flag still wins.
    expect(
      project(draft: {...draft, 'cash_salary_amount': null})['cash_salary'],
      0,
    );
  });
  test(
    'automatic draft follows Personal while manual and published flow stay fixed',
    () {
      var draft = payload(project(flow: 100));
      expect(project(flow: 200, draft: draft)['cash_salary'], 200);
      draft = {...draft, 'cash_salary_is_manual': true};
      expect(project(flow: 200, draft: draft)['cash_salary'], 100);
      expect(
        project(
          flow: 200,
          draft: {...draft, 'draft_status': 'publicado'},
        )['cash_salary'],
        100,
      );
    },
  );
  test('cheque distributes fiscal into envelope without duplicating total', () {
    for (final flow in [0.0, 500.0]) {
      var result = project(flow: flow, cheque: true);
      for (var i = 0; i < 3; i++) {
        expect(result['fiscal_cash'], 1890.20);
        expect(result['fiscal_deposit'], 0);
        expect(result['total'], closeTo(1890.20 + flow, .001));
        expect(result['envelope'], result['total']);
        expect(result['channel'], flow == 0 ? 'cheque' : 'mixto');
        result = project(flow: flow, cheque: true, draft: payload(result));
      }
      final deposit = project(
        flow: flow,
        cheque: false,
        draft: payload(result),
      );
      expect(deposit['fiscal_cash'], 0);
      expect(deposit['fiscal_deposit'], 1890.20);
      expect(deposit['envelope'], flow);
    }
  });
  test(
    'manual fiscal delivery zero overrides cheque profile and survives saves',
    () {
      var draft = payload(project(cheque: true));
      draft['check_amount'] = 0;
      draft['source_snapshot'] = {
        ...draft['source_snapshot'] as Map,
        'fiscal_payment_is_manual': true,
      };
      for (var i = 0; i < 3; i++) {
        final result = project(cheque: true, draft: draft);
        expect(result['fiscal_cash'], 0);
        expect(result['fiscal_deposit'], 1890.20);
        draft = payload(result);
      }
    },
  );
  final attendance = [
    for (final (day, minutes) in [(21, 15), (24, 16), (25, 60)])
      {
        'employee_id': 'test',
        'period_label': period,
        'source_date': '$day/08/2026',
        'source_mode': 'manual',
        'status': 'laboro',
        'overtime_minutes': minutes,
      },
  ];
  test(
    'overtime uses individual 60/80 rate after the daily >15 minute rule',
    () {
      final sixty = project(rate: 60, attendance: attendance);
      expect(sixty['extra_minutes'], 76);
      expect(sixty['extra_amount'], 76);
      final eighty = project(
        rate: 80,
        attendance: attendance,
        draft: payload(sixty),
      );
      expect(eighty['extra_amount'], 101.33);
      var manual = payload(eighty);
      manual['overtime_monetized_amount'] = 80;
      manual['source_snapshot'] = {
        ...manual['source_snapshot'] as Map,
        'overtime_is_manual': true,
      };
      expect(
        project(
          rate: 60,
          attendance: attendance,
          draft: manual,
        )['extra_amount'],
        80,
      );
      expect(
        project(
          rate: 60,
          attendance: attendance,
          draft: {...payload(eighty), 'draft_status': 'publicado'},
        )['extra_amount'],
        101.33,
      );
    },
  );
  test('fully prepaid vacation has no cheque, deposit or ordinary flow', () {
    final result = project(
      cheque: true,
      vacations: [
        {
          'id': 'paid',
          'employee_id': 'test',
          'exercise_year': 2026,
          'event_type': 'vacaciones_pagadas',
          'days_applied': 14,
          'start_date': '2026-05-20',
          'end_date': '2026-05-20',
          'status': 'aplicado',
          'impact_prenomina': true,
        },
        {
          'id': 'used',
          'employee_id': 'test',
          'exercise_year': 2026,
          'event_type': 'vacaciones_disfrutadas',
          'days_applied': 14,
          'start_date': '2026-08-21',
          'end_date': '2026-09-04',
          'status': 'aplicado',
          'impact_prenomina': true,
        },
      ],
    );
    expect(result['fiscal'], 0);
    expect(result['total'], 0);
    expect(result['fiscal_cash'], 0);
    expect(payload(result)['check_amount'], 0);
  });
}
