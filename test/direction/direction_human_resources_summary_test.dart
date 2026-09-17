import 'dart:convert';

import 'package:dicsa_operacion/app/direction/direction_human_resources_summary.dart';
import 'package:dicsa_operacion/app/hr/human_resources_nomina_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../hr/human_resources_nomina_test.dart' as nomina;

const period = 'Periodo 38 semanal · 14/09/2026 - 20/09/2026';
const previous = 'Periodo 37 semanal · 07/09/2026 - 13/09/2026';
final today = DateTime(2026, 9, 15);
final profiles = [
  {
    'id': '1',
    'nombre': 'ANA MARTÍNEZ',
    'empresa': 'DICSA',
    'employment_status': 'activo',
    'fiscal_payment_mode': 'deposito',
  },
  {
    'id': '2',
    'nombre': 'LUIS GARCÍA',
    'empresa': 'MONROE',
    'employment_status': 'activo',
    'fiscal_payment_mode': 'cheque',
  },
  {'id': '3', 'nombre': 'COLABORADOR DE BAJA', 'employment_status': 'baja'},
];
Map<String, dynamic> event(
  String id,
  String start, {
  String employee = '1',
  String? end,
  String status = 'pendiente',
  String type = 'vacaciones_pendientes',
  String permission = 'permiso_con_goce',
  String label = period,
}) => {
  'id': id,
  'employee_id': employee,
  'employee_name': 'NOMBRE ANTERIOR',
  'start_date': start,
  'end_date': end ?? start,
  'status': status,
  'event_type': type,
  'permission_type': permission,
  'attendance_period_label': label,
};
Map<String, dynamic> absence(
  String date, {
  String employee = '1',
  String status = 'falto',
  String source = 'manual',
  String label = period,
}) => {
  'employee_id': employee,
  'source_date': date,
  'status': status,
  'source_mode': source,
  'period_label': label,
};
Map<String, dynamic> draft(
  String id, {
  String label = period,
  int fiscal = 2200,
  int cash = 300,
  String status = 'borrador',
  Map<String, dynamic> snapshot = const {},
}) => {
  'id': 'draft-$id-$label',
  'employee_id': id,
  'period_label': label,
  'draft_status': status,
  'fiscal_net_amount': fiscal,
  'cash_salary_amount': cash,
  'source_snapshot': snapshot,
};

DirectionHumanResourcesSummary summary({
  String selected = period,
  List<Map<String, dynamic>>? drafts,
  List<Map<String, dynamic>> vacations = const [],
  List<Map<String, dynamic>> permissions = const [],
  List<Map<String, dynamic>> attendance = const [],
  List<Map<String, dynamic>> closures = const [],
}) => DirectionHumanResourcesSummary.fromRows(
  selectedPeriod: selected,
  periodOptions: [previous, period],
  profiles: profiles,
  drafts: drafts ?? [draft('1'), draft('2')],
  vacations: vacations,
  permissions: permissions,
  attendance: attendance,
  closures: closures,
  now: today,
);

void main() {
  test(
    'executive money exactly matches Nómina, including cheque in flow once',
    () {
      final result = HrPayrollPeriodSummary.fromRows(
        drafts: nomina.drafts,
        periodLabel: nomina.period,
        isPeriodClosed: true,
      );
      expect(result.employees, 45);
      expect(result.fiscal, 98100);
      expect(result.deposit, 93600);
      expect(result.cheque, 4500);
      expect(result.flow, 26550);
      expect(result.deposit + result.flow, 120150);
      expect(result.published, 1);
      expect(result.ready, 43);
    },
  );

  test(
    'open cheque follows Personal; closed and published payroll retain delivery',
    () {
      final open = summary(
        drafts: [
          draft('2'),
          draft('1', label: previous),
        ],
      );
      expect(open.payroll.fiscal, 2200);
      expect(open.payroll.flow, 2500);
      expect(open.payroll.deposit, 0);
      final frozen = summary(
        drafts: [draft('2')],
        closures: [
          {'period_label': period, 'status': 'cerrado'},
        ],
      );
      expect(frozen.closed, isTrue);
      expect(frozen.payroll.deposit, 2200);
      expect(frozen.payroll.flow, 300);
      expect(
        summary(drafts: [draft('2', status: 'publicado')]).payroll.flow,
        300,
      );
    },
  );

  test(
    'does not silently select the newest period or report missing payroll as a zero payroll',
    () {
      final result = summary(selected: '');
      expect(result.hasPeriod, isFalse);
      expect(result.periodOptions, [period, previous]);
      expect(result.payroll.employees, 0);
      expect(summary(drafts: []).hasPeriod, isTrue);
      expect(summary(drafts: []).payroll.employees, 0);
    },
  );

  test(
    'vacations cover tomorrow through day fifteen and exclude paid-only, cancelled and inactive',
    () {
      final result = summary(
        vacations: [
          event('today', '2026-09-15'),
          event('tomorrow', '2026-09-16', end: '2026-09-18'),
          event('limit', '2026-09-30', employee: '2'),
          event('beyond', '2026-10-01'),
          event('paid', '2026-09-16', type: 'vacaciones_pagadas'),
          event('cancelled', '2026-09-16', status: 'cancelado'),
          event('inactive', '2026-09-16', employee: '3'),
        ],
      );
      expect(result.vacations.map((e) => e.id), ['tomorrow', 'limit']);
      expect(result.vacations.first.name, 'ANA MARTÍNEZ');
      expect(result.vacations.first.end, DateTime(2026, 9, 18));
    },
  );

  test(
    'permissions use overlap dates and preserve types without counting cancellations',
    () {
      final result = summary(
        permissions: [
          event('across', '2026-09-13', end: '2026-09-15', label: previous),
          event(
            'later',
            '2026-09-18',
            employee: '2',
            permission: 'permiso_sin_goce',
            status: 'aplicado',
          ),
          event('past', '2026-09-12'),
          event('future', '2026-09-21'),
          event('cancelled', '2026-09-17', status: 'cancelado'),
          event('inactive', '2026-09-17', employee: '3'),
        ],
      );
      expect(result.permissions.map((e) => e.id), ['later', 'across']);
      expect(result.permissions.first.label, 'Permiso sin goce');
      expect(result.pendingPermissions, 1);
    },
  );

  test(
    'absence days are operational, unique by employee/date, and bounded to period',
    () {
      final result = summary(
        attendance: [
          absence('2026-09-14'),
          absence('2026-09-14'),
          absence('2026-09-16'),
          absence('2026-09-15', employee: '2'),
          absence('2026-09-19', source: 'importado'),
          absence('2026-09-18', status: 'permiso'),
          absence('2026-09-14', employee: '3'),
          absence('2026-09-21'),
          absence('2026-09-12', label: previous),
        ],
      );
      expect(result.absenceDays, 3);
      expect(result.absences.map((a) => a.employeeId), ['1', '2']);
      expect(result.absences.first.dates, [
        DateTime(2026, 9, 16),
        DateTime(2026, 9, 14),
      ]);
    },
  );

  test(
    'store paginates, scopes period details and remains read-only',
    () async {
      final requests = <Uri>[];
      final client = SupabaseClient(
        'https://hr-dashboard-test.invalid',
        'test',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          requests.add(request.url);
          final q = request.url.queryParameters;
          final table = request.url.pathSegments.last;
          List<Map<String, dynamic>> rows;
          switch (table) {
            case 'hr_employee_profiles':
              rows = profiles;
            case 'hr_attendance_operational_periods':
              rows = [
                {'period_label': period},
              ];
            case 'hr_payroll_period_closures':
              rows = [];
            case 'hr_employee_vacation_events':
              expect(q['start_date'], isNotNull);
              expect(request.url.queryParametersAll['start_date'], [
                'gt.2026-09-15',
                'lte.2026-09-30',
              ]);
              rows = [event('v1', '2026-09-16')];
            case 'hr_prenomina_draft_rows':
              if (q['select'] == 'period_label') {
                rows = q['offset'] == '0'
                    ? List.generate(1000, (_) => {'period_label': period})
                    : [
                        {'period_label': previous},
                      ];
              } else {
                expect(q['period_label'], 'eq.$period');
                rows = [draft('1'), draft('2')];
              }
            case 'hr_attendance_daily_records':
              expect(q['period_label'], 'eq.$period');
              expect(q['status'], 'eq.falto');
              rows = [absence('2026-09-15')];
            case 'hr_employee_permission_events':
              expect(q['start_date'], 'lte.2026-09-20');
              expect(q['end_date'], 'gte.2026-09-14');
              rows = [event('p1', '2026-09-15')];
            default:
              throw StateError('Unexpected table: $table');
          }
          return http.Response(
            jsonEncode(rows),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final result = await DirectionHumanResourcesStore(
        client: client,
      ).load(selectedPeriod: period, now: today);
      expect(
        requests.where((q) => q.queryParameters['offset'] == '1000'),
        hasLength(1),
      );
      expect(result.payroll.fiscal, 4400);
      expect(result.payroll.flow, 2800);
      expect(result.vacations, hasLength(1));
      expect(result.permissions, hasLength(1));
      expect(result.absenceDays, 1);
    },
  );

  test('store failures propagate instead of becoming zero totals', () async {
    final client = SupabaseClient(
      'https://hr-dashboard-test.invalid',
      'test',
      httpClient: MockClient(
        (request) async =>
            http.Response('{"message":"unavailable"}', 503, request: request),
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      DirectionHumanResourcesStore(
        client: client,
      ).load(selectedPeriod: period, now: today),
      throwsA(isA<PostgrestException>()),
    );
  });
}
