import 'package:supabase_flutter/supabase_flutter.dart';

import 'human_resources_period_context.dart';

const String hrEventPeriodImpactsTable = 'hr_employee_event_period_impacts';

/// Impacto operativo de una vacacion, permiso o incapacidad dentro de un
/// periodo semanal. El evento fuente conserva sus fechas originales.
class HrEventPeriodImpactRecord {
  final String id;
  final String eventKind;
  final String parentEventId;
  final String employeeId;
  final String periodLabel;
  final DateTime periodStartDate;
  final DateTime periodEndDate;
  final double daysApplied;
  final double additionalPaidDays;
  final double quantityHours;
  final bool impactPrenomina;
  final String prenominaSyncStatus;
  final String payrollSettlementStatus;

  const HrEventPeriodImpactRecord({
    required this.id,
    required this.eventKind,
    required this.parentEventId,
    required this.employeeId,
    required this.periodLabel,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.daysApplied,
    required this.additionalPaidDays,
    required this.quantityHours,
    required this.impactPrenomina,
    required this.prenominaSyncStatus,
    required this.payrollSettlementStatus,
  });

  factory HrEventPeriodImpactRecord.fromRow(Map<String, dynamic> row) {
    final kind = (row['event_kind'] ?? '').toString();
    final parentId = kind == 'vacacion'
        ? (row['vacation_event_id'] ?? '').toString()
        : (row['permission_event_id'] ?? '').toString();
    return HrEventPeriodImpactRecord(
      id: (row['id'] ?? '').toString(),
      eventKind: kind,
      parentEventId: parentId,
      employeeId: (row['employee_id'] ?? '').toString(),
      periodLabel: (row['period_label'] ?? '').toString(),
      periodStartDate:
          DateTime.tryParse((row['period_start_date'] ?? '').toString()) ??
          DateTime(1970),
      periodEndDate:
          DateTime.tryParse((row['period_end_date'] ?? '').toString()) ??
          DateTime(1970),
      daysApplied: _asDouble(row['days_applied']),
      additionalPaidDays: _asDouble(row['additional_paid_days']),
      quantityHours: _asDouble(row['quantity_hours']),
      impactPrenomina: row['impact_prenomina'] == true,
      prenominaSyncStatus: (row['prenomina_sync_status'] ?? '').toString(),
      payrollSettlementStatus: (row['payroll_settlement_status'] ?? '')
          .toString(),
    );
  }

  bool matchesPeriod(String label) {
    final range = HumanResourcesPeriodRange.tryParse(label);
    if (range == null) return periodLabel == label;
    return periodStartDate == range.start && periodEndDate == range.end;
  }

  bool get isLiquidated => payrollSettlementStatus == 'liquidado';
}

class HrEventPeriodImpactSource {
  final String eventId;
  final String employeeId;
  final DateTime startDate;
  final DateTime endDate;
  final double daysApplied;
  final double additionalPaidDays;
  final double quantityHours;
  final bool impactAttendance;
  final bool impactPrenomina;
  final bool isCancelled;

  const HrEventPeriodImpactSource({
    required this.eventId,
    required this.employeeId,
    required this.startDate,
    required this.endDate,
    required this.daysApplied,
    required this.additionalPaidDays,
    required this.quantityHours,
    required this.impactAttendance,
    required this.impactPrenomina,
    required this.isCancelled,
  });
}

/// Reparte cada evento exclusivamente entre semanas operativas ya creadas.
/// Un expediente puede existir antes que su periodo: se conserva por fecha y
/// se conciliará cuando RH cree la semana que se traslape.
Future<void> syncHrEventPeriodImpacts({
  required SupabaseClient client,
  required String eventKind,
  required List<HrEventPeriodImpactSource> sources,
  required Iterable<String> knownPeriodLabels,
  required String activePeriodLabel,
}) async {
  final sourcesWithId = sources
      .where((source) => source.eventId.trim().isNotEmpty)
      .toList(growable: false);
  if (sourcesWithId.isEmpty) return;

  final candidateRanges = _resolveCandidateRanges(
    knownPeriodLabels: knownPeriodLabels,
    activePeriodLabel: activePeriodLabel,
  );
  if (candidateRanges.isEmpty) return;

  final parentColumn = eventKind == 'vacacion'
      ? 'vacation_event_id'
      : 'permission_event_id';
  final eventIds = sourcesWithId.map((source) => source.eventId).toList();
  final rawExisting = await client
      .from(hrEventPeriodImpactsTable)
      .select()
      .eq('event_kind', eventKind)
      .inFilter(parentColumn, eventIds);
  final existing = (rawExisting as List)
      .map(
        (row) => HrEventPeriodImpactRecord.fromRow(
          Map<String, dynamic>.from(row as Map),
        ),
      )
      .toList(growable: false);
  final existingByKey = <String, HrEventPeriodImpactRecord>{
    for (final item in existing)
      '${item.parentEventId}|${_dateKey(item.periodStartDate)}|${_dateKey(item.periodEndDate)}':
          item,
  };
  final desiredKeys = <String>{};

  for (final source in sourcesWithId) {
    if (source.isCancelled ||
        (!source.impactAttendance && !source.impactPrenomina)) {
      continue;
    }
    final segments = _segmentsForSource(source, candidateRanges);
    final allocatedDays = _allocate(source, source.daysApplied, segments);
    final allocatedAdditional = _allocate(
      source,
      source.additionalPaidDays,
      segments,
    );
    final allocatedHours = _allocate(source, source.quantityHours, segments);
    for (var index = 0; index < segments.length; index += 1) {
      final segment = segments[index];
      final key =
          '${source.eventId}|${_dateKey(segment.start)}|${_dateKey(segment.end)}';
      desiredKeys.add(key);
      final payload = <String, dynamic>{
        'event_kind': eventKind,
        parentColumn: source.eventId,
        'employee_id': source.employeeId,
        'period_label': segment.label,
        'period_start_date': _dateKey(segment.start),
        'period_end_date': _dateKey(segment.end),
        'days_applied': allocatedDays[index],
        'additional_paid_days': allocatedAdditional[index],
        'quantity_hours': allocatedHours[index],
        'impact_attendance': source.impactAttendance,
        'impact_prenomina': source.impactPrenomina,
        'source_snapshot': <String, dynamic>{
          'allocation_basis': 'calendar_days',
          'source_start_date': _dateKey(source.startDate),
          'source_end_date': _dateKey(source.endDate),
        },
      };
      final current = existingByKey[key];
      if (current == null) {
        await client.from(hrEventPeriodImpactsTable).insert(payload);
      } else if (!current.isLiquidated) {
        await client
            .from(hrEventPeriodImpactsTable)
            .update(payload)
            .eq('id', current.id);
      }
    }
  }

  for (final current in existing) {
    final key =
        '${current.parentEventId}|${_dateKey(current.periodStartDate)}|${_dateKey(current.periodEndDate)}';
    if (!desiredKeys.contains(key) && !current.isLiquidated) {
      await client
          .from(hrEventPeriodImpactsTable)
          .delete()
          .eq('id', current.id);
    }
  }
}

class _PeriodSegment {
  final String label;
  final DateTime start;
  final DateTime end;

  const _PeriodSegment({
    required this.label,
    required this.start,
    required this.end,
  });
}

List<_PeriodSegment> _resolveCandidateRanges({
  required Iterable<String> knownPeriodLabels,
  required String activePeriodLabel,
}) {
  final labels = <String>{...knownPeriodLabels, activePeriodLabel};
  final output = <_PeriodSegment>[];
  final seenRanges = <String>{};
  for (final label in labels) {
    final range = HumanResourcesPeriodRange.tryParse(label);
    if (range == null) continue;
    final key = '${_dateKey(range.start)}|${_dateKey(range.end)}';
    if (!seenRanges.add(key)) continue;
    output.add(
      _PeriodSegment(label: label, start: range.start, end: range.end),
    );
  }
  output.sort((a, b) => a.start.compareTo(b.start));
  return output;
}

List<_PeriodSegment> _segmentsForSource(
  HrEventPeriodImpactSource source,
  List<_PeriodSegment> candidates,
) {
  return candidates
      .where(
        (candidate) =>
            !candidate.end.isBefore(source.startDate) &&
            !candidate.start.isAfter(source.endDate),
      )
      .toList(growable: false);
}

List<double> _allocate(
  HrEventPeriodImpactSource source,
  double total,
  List<_PeriodSegment> segments,
) {
  if (segments.isEmpty) return const <double>[];
  final totalDays = segments.fold<int>(
    0,
    (sum, segment) =>
        sum + _overlapDays(source.startDate, source.endDate, segment),
  );
  var allocated = 0.0;
  return List<double>.generate(segments.length, (index) {
    if (index == segments.length - 1) return _round(total - allocated);
    final ratio =
        _overlapDays(source.startDate, source.endDate, segments[index]) /
        totalDays;
    final value = _round(total * ratio);
    allocated += value;
    return value;
  });
}

int _overlapDays(DateTime start, DateTime end, _PeriodSegment segment) {
  final overlapStart = start.isAfter(segment.start) ? start : segment.start;
  final overlapEnd = end.isBefore(segment.end) ? end : segment.end;
  if (overlapEnd.isBefore(overlapStart)) return 0;
  return overlapEnd.difference(overlapStart).inDays + 1;
}

double _round(double value) => double.parse(value.toStringAsFixed(2));

double _asDouble(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse((raw ?? '').toString()) ?? 0;
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
