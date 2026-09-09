import 'package:dicsa_operacion/app/hr/human_resources_attendance_page.dart';
import 'package:dicsa_operacion/app/hr/human_resources_attendance_source.dart';
import 'package:dicsa_operacion/app/hr/human_resources_import_period.dart';
import 'package:dicsa_operacion/app/hr/human_resources_period_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const period = 'Periodo 35 semanal · 21/08/2026 - 27/08/2026';
const otherPeriod = 'Periodo 36 semanal · 28/08/2026 - 03/09/2026';
const workdays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];

Map<String, dynamic> saved(String status) => {
  'id': 'saved-rh-day',
  'period_label': period,
  'employee_id': '290',
  'source_date': '24/08/2026',
  'status': status,
  'source_mode': 'manual',
  'capture_origin': 'daily',
  'first_punch': '',
  'last_punch': '',
  'late_minutes': 30,
  'overtime_minutes': 90,
};

List<Map<String, dynamic>> punches(String start, String end) => [
  for (final time in [start, end])
    {'employee_id': '290', 'source_date': '08/24/2026', 'source_time': time},
];

void main() {
  for (final status in ['laboro', 'falto', 'no_aplica', 'pendiente']) {
    test('NGTeco reimport preserves RH status $status and captured totals', () {
      for (final reference in [
        punches('09:20', '21:00'),
        punches('06:00', '14:00'),
      ]) {
        final preview = hrAttendancePreviewForTesting(
          periodLabel: period,
          employeeId: '290',
          storedRows: [saved(status)],
          ngtecoEntries: reference,
          schedule: '08:00 - 18:00',
          workdays: workdays,
        );
        final day = preview.days.singleWhere(
          (d) => d['source_date'] == '24/08/2026',
        );
        expect(day['status'], status);
        expect(day['late_minutes'], 30);
        expect(day['overtime_minutes'], 90);
        expect(day['first_punch'], '');
        expect(day['last_punch'], '');
        expect(
          day['reference'],
          reference.map((r) => r['source_time']).toList(),
        );
      }
    });
  }

  test('NGTeco alone does not create worked days, lateness or overtime', () {
    final preview = hrAttendancePreviewForTesting(
      periodLabel: period,
      employeeId: '290',
      storedRows: [],
      ngtecoEntries: punches('09:20', '21:00'),
      schedule: '08:00 - 18:00',
      workdays: workdays,
    );
    expect(preview.days, isNotEmpty);
    for (final day in preview.days) {
      expect(day['status'], 'pendiente');
      expect(day['late_minutes'], 0);
      expect(day['overtime_minutes'], 0);
      expect(day['first_punch'], '');
      expect(day['last_punch'], '');
    }
  });

  test('old generated baselines are excluded from operational attendance', () {
    expect(isHrOperationalAttendanceRow(saved('laboro')), isTrue);
    expect(
      isHrOperationalAttendanceRow({
        ...saved('laboro'),
        'source_mode': 'ajuste',
      }),
      isTrue,
    );
    final generated = {...saved('laboro'), 'source_mode': 'importado'};
    expect(isHrOperationalAttendanceRow(generated), isFalse);
    final preview = hrAttendancePreviewForTesting(
      periodLabel: period,
      employeeId: '290',
      storedRows: [generated],
      ngtecoEntries: punches('09:20', '21:00'),
      schedule: '08:00 - 18:00',
      workdays: workdays,
    );
    expect(preview.days.every((d) => d['status'] == 'pendiente'), isTrue);
  });

  testWidgets(
    'opening the weekly editor preserves saved totals with blank punches',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final preview = hrAttendancePreviewForTesting(
        periodLabel: period,
        employeeId: '290',
        storedRows: [saved('laboro')],
        ngtecoEntries: punches('09:20', '21:00'),
        schedule: '08:00 - 18:00',
        workdays: workdays,
      );
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: preview.editor)),
      );
      await tester.pumpAndSettle();
      final values = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.controller?.text)
          .toList();
      expect(values, contains('0.50'));
      expect(values, contains('1.50'));
      expect(tester.takeException(), isNull);
    },
  );

  test('CONTPAQ file time cannot create a new period', () {
    expect(
      matchingHrImportPeriods(
        existingPeriodLabels: [period, otherPeriod],
        isNgteco: false,
        filePeriodLabel:
            'Periodo 35 al 35 Semanal del 21/08/2026 al 27/08/2026 · Hora: 12:48:09:842',
        punchDates: [],
      ),
      [period],
    );
    expect(
      matchingHrImportPeriods(
        existingPeriodLabels: [],
        isNgteco: false,
        filePeriodLabel: period,
        punchDates: [],
      ),
      isEmpty,
    );
  });

  test('NGTeco links only to an existing period containing its dates', () {
    expect(
      matchingHrImportPeriods(
        existingPeriodLabels: [period, otherPeriod],
        isNgteco: true,
        filePeriodLabel: '08/21/2026 → 08/27/2026',
        punchDates: [DateTime(2026, 8, 24)],
      ),
      [period],
    );
    expect(
      matchingHrImportPeriods(
        existingPeriodLabels: [otherPeriod],
        isNgteco: true,
        filePeriodLabel: '',
        punchDates: [DateTime(2026, 8, 24)],
      ),
      isEmpty,
    );
  });

  test('old file-based selection reopens the original manual period', () {
    expect(
      HumanResourcesPeriodContext.resolveSelected(
        selectedLabel: '$period · Archivo 12:48:09',
        availableLabels: [period],
      ),
      period,
    );
  });
}
