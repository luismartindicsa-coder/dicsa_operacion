import 'dart:convert';
import 'dart:io';

import 'package:dicsa_operacion/app/hr/human_resources_permissions_page.dart';
import 'package:dicsa_operacion/app/hr/human_resources_vacations_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> historicalPermission() => {
  'id': 'history-permission',
  'employee_id': 'test',
  'employee_name': 'COLABORADOR DE PRUEBA',
  'permission_type': 'permiso_sin_goce',
  'request_unit': 'hora',
  'start_date': '2026-02-20',
  'end_date': '2026-02-20',
  'quantity_hours': 2.5,
  'source_mode': 'importado',
  'status': 'aplicado',
  'impact_attendance': false,
  'impact_prenomina': false,
  'source_snapshot': {'source_key': 'history:fixture'},
};

void main() {
  final importPlan = Platform.environment['HR_EVENT_HISTORY_PLAN'];
  if (importPlan != null) {
    test(
      'planned history survives the app models without generating payments',
      () {
        final plan = jsonDecode(File(importPlan).readAsStringSync()) as Map;
        for (final entry in plan['inserts'] as List) {
          final row = Map<String, dynamic>.from(entry['values'] as Map);
          if (entry['table'] == 'hr_employee_permission_events') {
            final loaded = hrPermissionHistoryForTesting(row);
            expect(
              loaded['quantity_hours'],
              row['quantity_hours'],
              reason: row['id'],
            );
            expect(
              loaded['quantity_days'],
              row['quantity_days'],
              reason: row['id'],
            );
          } else {
            final loaded = hrVacationReloadForTesting(row);
            expect(loaded['enjoyed'], row['days_applied'], reason: row['id']);
            expect(loaded['paid'], 0);
            expect(loaded['payroll_payment'], false);
            expect(hrVacationCalculationsForTesting(row), isEmpty);
          }
        }
      },
    );
  }

  test(
    'opening and saving reported hours keeps duration and source metadata',
    () {
      final row = hrPermissionHistoryForTesting(historicalPermission());
      expect(row['quantity_hours'], 2.5);
      expect(row['quantity_days'], 0);
      expect(row['start_time'], '');
      expect(row['end_time'], '');
      expect(row.containsKey('source_snapshot'), false);
      expect(row['impact_attendance'], false);
      expect(row['impact_prenomina'], false);
    },
  );

  test('documented clock times still determine the duration', () {
    final row = hrPermissionHistoryForTesting({
      ...historicalPermission(),
      'start_time': '14:00',
      'end_time': '15:15',
    });
    expect(row['quantity_hours'], 1.25);
    final manual = hrPermissionHistoryForTesting({
      ...historicalPermission(),
      'source_mode': 'manual',
    });
    expect(manual['quantity_hours'], 0);
  });

  testWidgets('reported hours remain editable without invented clock times', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    double? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: hrPermissionHistoryCardForTesting(
            row: historicalPermission(),
            onChanged: (value) => saved = value,
          ),
        ),
      ),
    );
    final field = find.byKey(
      const ValueKey('permission-hours-history-permission'),
    );
    expect(tester.widget<TextFormField>(field).initialValue, '2.5');
    await tester.enterText(field, '1.5');
    await tester.pumpAndSettle();
    expect(saved, 1.5);
    expect(tester.takeException(), isNull);
  });
}
