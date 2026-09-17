import 'package:supabase_flutter/supabase_flutter.dart';

import '../hr/human_resources_attendance_source.dart';
import '../hr/human_resources_employee_status.dart';
import '../hr/human_resources_nomina_page.dart';
import '../hr/human_resources_period_context.dart';
import '../hr/human_resources_permission_type.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
DateTime? _date(Object? raw) {
  final parsed = DateTime.tryParse((raw ?? '').toString());
  return parsed == null ? null : _day(parsed);
}

String _dateKey(DateTime date) => date.toIso8601String().substring(0, 10);

class DirectionHrEvent {
  final String id, employeeId, name, company, label, status;
  final DateTime start, end;
  const DirectionHrEvent({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.company,
    required this.label,
    required this.status,
    required this.start,
    required this.end,
  });
}

class DirectionHrAbsences {
  final String employeeId, name, company;
  final List<DateTime> dates;
  const DirectionHrAbsences({
    required this.employeeId,
    required this.name,
    required this.company,
    required this.dates,
  });
}

class DirectionHumanResourcesSummary {
  final List<String> periodOptions;
  final String periodLabel;
  final bool closed;
  final HrPayrollPeriodSummary payroll;
  final DateTime asOf;
  final List<DirectionHrEvent> vacations, permissions;
  final List<DirectionHrAbsences> absences;
  bool get hasPeriod => periodLabel.isNotEmpty;
  int get absenceDays => absences.fold(0, (sum, row) => sum + row.dates.length);
  int get pendingPermissions =>
      permissions.where((p) => p.status == 'pendiente').length;

  const DirectionHumanResourcesSummary({
    required this.periodOptions,
    required this.periodLabel,
    required this.closed,
    required this.payroll,
    required this.asOf,
    required this.vacations,
    required this.permissions,
    required this.absences,
  });

  factory DirectionHumanResourcesSummary.fromRows({
    required String selectedPeriod,
    required List<String> periodOptions,
    required List<Map<String, dynamic>> profiles,
    required List<Map<String, dynamic>> drafts,
    required List<Map<String, dynamic>> closures,
    required List<Map<String, dynamic>> vacations,
    required List<Map<String, dynamic>> permissions,
    required List<Map<String, dynamic>> attendance,
    DateTime? now,
  }) {
    final today = _day(now ?? DateTime.now());
    final options = HumanResourcesPeriodContext.normalizedOptions(
      periodOptions,
    );
    final selected = HumanResourcesPeriodContext.resolveSelected(
      selectedLabel: selectedPeriod,
      availableLabels: options,
    );
    final range = HumanResourcesPeriodRange.tryParse(selected);
    final closed = closures.any(
      (r) => r['period_label'] == selected && r['status'] == 'cerrado',
    );
    final activePeople = {
      for (final p in profiles)
        if (isHrEmployeeOperationalStatus(p['employment_status']))
          p['id'].toString(): p,
    };
    String name(String id, Map<String, dynamic> row) {
      final value = (activePeople[id]?['nombre'] ?? row['employee_name'] ?? '')
          .toString()
          .trim();
      return value.isEmpty ? 'Colaborador $id' : value;
    }

    String company(String id) =>
        (activePeople[id]?['empresa'] ?? '').toString();
    DirectionHrEvent? event(Map<String, dynamic> row, String label) {
      final id = (row['employee_id'] ?? '').toString();
      final start = _date(row['start_date']);
      final end = _date(row['end_date']) ?? start;
      if (!activePeople.containsKey(id) ||
          row['status'] == 'cancelado' ||
          start == null ||
          end == null ||
          end.isBefore(start)) {
        return null;
      }
      return DirectionHrEvent(
        id: (row['id'] ?? '').toString(),
        employeeId: id,
        name: name(id, row),
        company: company(id),
        label: label,
        status: (row['status'] ?? '').toString(),
        start: start,
        end: end,
      );
    }

    final upcoming = <DirectionHrEvent>[];
    for (final row in vacations) {
      if (![
        'vacaciones_disfrutadas',
        'vacaciones_pendientes',
      ].contains(row['event_type'])) {
        continue;
      }
      final item = event(row, 'Vacaciones');
      if (item != null &&
          item.start.isAfter(today) &&
          !item.start.isAfter(today.add(const Duration(days: 15)))) {
        upcoming.add(item);
      }
    }
    upcoming.sort((a, b) {
      final byDate = a.start.compareTo(b.start);
      return byDate != 0 ? byDate : a.name.compareTo(b.name);
    });
    final periodPermissions = <DirectionHrEvent>[];
    if (selected.isNotEmpty) {
      for (final row in permissions) {
        final item = event(
          row,
          HrPermissionType.fromDb(row['permission_type']).label,
        );
        if (item == null) continue;
        final belongs = range == null
            ? row['attendance_period_label'] == selected
            : !item.end.isBefore(range.start) && !item.start.isAfter(range.end);
        if (belongs) periodPermissions.add(item);
      }
    }
    periodPermissions.sort((a, b) {
      final byDate = b.start.compareTo(a.start);
      return byDate != 0 ? byDate : a.name.compareTo(b.name);
    });
    final absenceDates = <String, Set<DateTime>>{};
    for (final row in attendance) {
      final id = (row['employee_id'] ?? '').toString();
      final date = _date(row['source_date']);
      if (selected.isEmpty ||
          row['period_label'] != selected ||
          !isHrOperationalAttendanceRow(row) ||
          row['status'] != 'falto' ||
          !activePeople.containsKey(id) ||
          date == null ||
          (range != null &&
              (date.isBefore(range.start) || date.isAfter(range.end)))) {
        continue;
      }
      absenceDates.putIfAbsent(id, () => {}).add(date);
    }
    final absences = [
      for (final entry in absenceDates.entries)
        DirectionHrAbsences(
          employeeId: entry.key,
          name: name(entry.key, const {}),
          company: company(entry.key),
          dates: entry.value.toList()..sort((a, b) => b.compareTo(a)),
        ),
    ];
    absences.sort((a, b) {
      final byDate = b.dates.first.compareTo(a.dates.first);
      return byDate != 0 ? byDate : a.name.compareTo(b.name);
    });
    return DirectionHumanResourcesSummary(
      periodOptions: options,
      periodLabel: selected,
      closed: closed,
      asOf: today,
      payroll: HrPayrollPeriodSummary.fromRows(
        drafts: drafts,
        periodLabel: selected,
        personalFiscalModes: {
          for (final p in profiles)
            if (p['fiscal_payment_mode'] != null)
              p['id'].toString(): p['fiscal_payment_mode'].toString(),
        },
        isPeriodClosed: closed,
      ),
      vacations: upcoming,
      permissions: periodPermissions,
      absences: absences,
    );
  }
}

class DirectionHumanResourcesStore {
  final SupabaseClient client;
  DirectionHumanResourcesStore({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  Future<DirectionHumanResourcesSummary> load({
    String? selectedPeriod,
    DateTime? now,
  }) async {
    final selected =
        selectedPeriod ?? await HumanResourcesPeriodContext.readSelectedLabel();
    final today = _day(now ?? DateTime.now());
    final catalog = await Future.wait<List<Map<String, dynamic>>>([
      fetchAllSupabaseRows(
        (from, to) => client
            .from('hr_employee_profiles')
            .select('id,nombre,empresa,employment_status,fiscal_payment_mode')
            .order('id')
            .range(from, to),
      ),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('hr_attendance_operational_periods')
            .select('period_label')
            .order('id')
            .range(from, to),
      ),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('hr_prenomina_draft_rows')
            .select('period_label')
            .order('id')
            .range(from, to),
      ),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('hr_payroll_period_closures')
            .select('period_label,status')
            .order('id')
            .range(from, to),
      ),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('hr_employee_vacation_events')
            .select(
              'id,employee_id,employee_name,event_type,status,start_date,end_date',
            )
            .gt('start_date', _dateKey(today))
            .lte('start_date', _dateKey(today.add(const Duration(days: 15))))
            .order('start_date')
            .order('id')
            .range(from, to),
      ),
    ]);
    final options = HumanResourcesPeriodContext.normalizedOptions([
      for (final rows in [catalog[1], catalog[2], catalog[3]])
        for (final row in rows) (row['period_label'] ?? '').toString(),
    ]);
    final period = HumanResourcesPeriodContext.resolveSelected(
      selectedLabel: selected,
      availableLabels: options,
    );
    final range = HumanResourcesPeriodRange.tryParse(period);
    final details = period.isEmpty
        ? <List<Map<String, dynamic>>>[[], [], []]
        : await Future.wait<List<Map<String, dynamic>>>([
            fetchAllSupabaseRows(
              (from, to) => client
                  .from('hr_prenomina_draft_rows')
                  .select()
                  .eq('period_label', period)
                  .order('id')
                  .range(from, to),
            ),
            fetchAllSupabaseRows(
              (from, to) => client
                  .from('hr_attendance_daily_records')
                  .select(
                    'employee_id,period_label,source_date,source_mode,status',
                  )
                  .eq('period_label', period)
                  .eq('status', 'falto')
                  .order('id')
                  .range(from, to),
            ),
            fetchAllSupabaseRows((from, to) {
              final query = client
                  .from('hr_employee_permission_events')
                  .select(
                    'id,employee_id,employee_name,attendance_period_label,permission_type,status,start_date,end_date',
                  );
              return (range == null
                      ? query.eq('attendance_period_label', period)
                      : query
                            .lte('start_date', _dateKey(range.end))
                            .gte('end_date', _dateKey(range.start)))
                  .order('start_date', ascending: false)
                  .order('id')
                  .range(from, to);
            }),
          ]);
    return DirectionHumanResourcesSummary.fromRows(
      selectedPeriod: period,
      periodOptions: options,
      profiles: catalog[0],
      closures: catalog[3],
      vacations: catalog[4],
      drafts: details[0],
      attendance: details[1],
      permissions: details[2],
      now: today,
    );
  }
}
