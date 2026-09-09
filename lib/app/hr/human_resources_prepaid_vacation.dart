import 'dart:math' as math;

/// Applied payments are consumed chronologically by enjoyment in the same
/// employee/exercise. A payment made later cannot cover earlier enjoyment.
Map<String, double> hrPrepaidVacationDays({
  required List<Map<String, dynamic>> events,
  required DateTime periodStart,
  required DateTime periodEnd,
  Map<String, double>? eligibleDaysByEvent,
}) {
  final applied = events.where((e) => e['status'] == 'aplicado').toList()
    ..sort((a, b) {
      final date = '${a['start_date']}'.compareTo('${b['start_date']}');
      if (date != 0) return date;
      final kind = (a['event_type'] == 'vacaciones_pagadas' ? 0 : 1).compareTo(
        b['event_type'] == 'vacaciones_pagadas' ? 0 : 1,
      );
      return kind != 0 ? kind : '${a['id']}'.compareTo('${b['id']}');
    });
  final balances = <String, double>{};
  final result = <String, double>{};
  for (final e in applied) {
    final start = DateTime.tryParse('${e['start_date']}');
    final end = DateTime.tryParse('${e['end_date']}');
    final days = double.tryParse('${e['days_applied']}') ?? 0;
    if (start == null || end == null || days <= 0 || end.isBefore(start)) {
      continue;
    }
    final key = '${e['employee_id']}|${e['exercise_year'] ?? start.year}';
    if (e['event_type'] == 'vacaciones_pagadas') {
      balances[key] = (balances[key] ?? 0) + days;
      continue;
    }
    if (e['event_type'] != 'vacaciones_disfrutadas') continue;
    final covered = math.min(days, balances[key] ?? 0);
    balances[key] = (balances[key] ?? 0) - covered;
    if (covered <= 0) continue;
    final dates = <DateTime>[];
    for (
      var date = start;
      !date.isAfter(end);
      date = DateTime(date.year, date.month, date.day + 1)
    ) {
      dates.add(date);
    }
    if (dates.isEmpty) dates.add(start);
    var remaining = covered;
    var current = 0.0;
    final units = days / dates.length;
    for (final date in dates) {
      final used = math.min(units, remaining);
      remaining -= used;
      if (!date.isBefore(periodStart) && !date.isAfter(periodEnd)) {
        // Vacation-bank units can exclude rest days. Salary coverage follows
        // the dated absence, so a fully prepaid event covers each calendar day.
        current += used / units;
      }
    }
    if (eligibleDaysByEvent != null) {
      current = math.min(current, eligibleDaysByEvent['${e['id']}'] ?? 0);
    }
    if (current > 0) {
      result['${e['id']}'] = double.parse(current.toStringAsFixed(2));
    }
  }
  return result;
}

class HrPrepaidVacationDeduction {
  final double days, fiscal, flow;
  const HrPrepaidVacationDeduction({
    this.days = 0,
    this.fiscal = 0,
    this.flow = 0,
  });
  double get total => fiscal + flow;
  factory HrPrepaidVacationDeduction.calculate({
    required double days,
    required double perceivedWeekly,
    required double fiscalAvailable,
    required double flowAvailable,
  }) {
    final target =
        (perceivedWeekly > 0 ? perceivedWeekly / 7 : 0) * days.clamp(0, 7);
    final available = math.max(fiscalAvailable, 0) + math.max(flowAvailable, 0);
    double money(double value) => double.parse(value.toStringAsFixed(2));
    final amount = money(math.min(target, available).toDouble());
    final fiscal = available > 0
        ? money(amount * math.max(fiscalAvailable, 0) / available)
        : 0.0;
    return HrPrepaidVacationDeduction(
      days: days,
      fiscal: fiscal,
      flow: money(amount - fiscal),
    );
  }
  factory HrPrepaidVacationDeduction.fromSnapshot(
    Map<String, dynamic> snapshot,
  ) {
    final raw = snapshot['prepaid_vacation'];
    if (raw is! Map) return const HrPrepaidVacationDeduction();
    double value(String key) => double.tryParse('${raw[key]}') ?? 0;
    return HrPrepaidVacationDeduction(
      days: value('days'),
      fiscal: value('fiscal'),
      flow: value('flow'),
    );
  }
  Map<String, dynamic> toJson() => {
    'days': days,
    'fiscal': fiscal,
    'flow': flow,
    'total': total,
  };
}
