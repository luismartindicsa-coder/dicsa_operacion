import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';

const String _kLogisticsFixedServicesTable = 'logistics_fixed_services';

const List<int> kLogisticsWeekdayOrder = <int>[
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
  DateTime.sunday,
];

String logisticsFixedServicePlanningKindLabel(String value) {
  switch (value.trim().toUpperCase()) {
    case 'FIJO':
      return 'Fija';
    default:
      return 'Variante';
  }
}

String logisticsFixedServiceMovementLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'entrega':
      return 'Entrega';
    default:
      return 'Recolección';
  }
}

String logisticsWeekdayShortLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Lun';
    case DateTime.tuesday:
      return 'Mar';
    case DateTime.wednesday:
      return 'Mié';
    case DateTime.thursday:
      return 'Jue';
    case DateTime.friday:
      return 'Vie';
    case DateTime.saturday:
      return 'Sáb';
    case DateTime.sunday:
      return 'Dom';
    default:
      return '—';
  }
}

String logisticsWeekdayLongLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Lunes';
    case DateTime.tuesday:
      return 'Martes';
    case DateTime.wednesday:
      return 'Miércoles';
    case DateTime.thursday:
      return 'Jueves';
    case DateTime.friday:
      return 'Viernes';
    case DateTime.saturday:
      return 'Sábado';
    case DateTime.sunday:
      return 'Domingo';
    default:
      return 'Sin día';
  }
}

String logisticsWeekdayListLabel(Iterable<int> weekdays) {
  final values = weekdays.toSet().toList()..sort((a, b) => a.compareTo(b));
  if (values.isEmpty) return 'Sin días';
  return values.map(logisticsWeekdayShortLabel).join(' · ');
}

TimeOfDay? logisticsParseFixedServiceTime(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(value);
  if (match == null) return null;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String logisticsFormatFixedServiceTimeUi(String raw) {
  final time = logisticsParseFixedServiceTime(raw);
  if (time == null) return raw.trim().isEmpty ? 'Sin horario fijo' : raw.trim();
  final hh = time.hour.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String logisticsFormatFixedServiceTimeDb(TimeOfDay value) {
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  return '$hh:$mm:00';
}

class LogisticsFixedServiceRecord {
  final String? id;
  final String siteId;
  final String siteName;
  final String? materialId;
  final String materialName;
  final String movement;
  final String scheduledTime;
  final List<int> weekdays;
  final String? defaultDriverEmployeeId;
  final String? defaultVehicleId;
  final bool isActive;
  final String notes;
  final int visitsPerDay;
  final DateTime? effectiveFrom;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LogisticsFixedServiceRecord({
    required this.id,
    required this.siteId,
    required this.siteName,
    required this.materialId,
    required this.materialName,
    required this.movement,
    required this.scheduledTime,
    required this.weekdays,
    required this.defaultDriverEmployeeId,
    required this.defaultVehicleId,
    required this.isActive,
    required this.notes,
    this.visitsPerDay = 1,
    this.effectiveFrom,
    required this.createdAt,
    required this.updatedAt,
  });

  bool appliesTo(DateTime date) {
    return (effectiveFrom == null ||
            !DateUtils.dateOnly(date).isBefore(effectiveFrom!)) &&
        weekdays.contains(DateUtils.dateOnly(date).weekday);
  }

  LogisticsFixedServiceRecord copyWith({
    Object? id = _unset,
    String? siteId,
    String? siteName,
    Object? materialId = _unset,
    String? materialName,
    String? movement,
    String? scheduledTime,
    List<int>? weekdays,
    Object? defaultDriverEmployeeId = _unset,
    Object? defaultVehicleId = _unset,
    bool? isActive,
    String? notes,
    int? visitsPerDay,
    DateTime? effectiveFrom,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
  }) {
    return LogisticsFixedServiceRecord(
      id: id == _unset ? this.id : id as String?,
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      materialId: materialId == _unset
          ? this.materialId
          : materialId as String?,
      materialName: materialName ?? this.materialName,
      movement: movement ?? this.movement,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      weekdays: weekdays ?? this.weekdays,
      defaultDriverEmployeeId: defaultDriverEmployeeId == _unset
          ? this.defaultDriverEmployeeId
          : defaultDriverEmployeeId as String?,
      defaultVehicleId: defaultVehicleId == _unset
          ? this.defaultVehicleId
          : defaultVehicleId as String?,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      visitsPerDay: visitsPerDay ?? this.visitsPerDay,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      createdAt: createdAt == _unset ? this.createdAt : createdAt as DateTime?,
      updatedAt: updatedAt == _unset ? this.updatedAt : updatedAt as DateTime?,
    );
  }

  Map<String, dynamic> toUpsertJson() {
    return <String, dynamic>{
      if (id != null && id!.trim().isNotEmpty) 'id': id,
      'site_id': siteId,
      'site_name': siteName.trim(),
      'material_id': materialId,
      'material_name': materialName.trim(),
      'movement': movement.trim().toLowerCase(),
      'scheduled_time': scheduledTime.trim().isEmpty ? null : scheduledTime,
      'visits_per_day': visitsPerDay,
      'weekdays': weekdays,
      'default_driver_employee_id': defaultDriverEmployeeId,
      'default_vehicle_id': defaultVehicleId,
      'is_active': isActive,
      'notes': notes.trim().isEmpty ? null : notes.trim(),
    };
  }

  factory LogisticsFixedServiceRecord.fromRemoteRow(Map<String, dynamic> row) {
    return LogisticsFixedServiceRecord(
      id: row['id']?.toString(),
      siteId: (row['site_id'] ?? '').toString(),
      siteName: (row['site_name'] ?? '').toString(),
      materialId: row['material_id']?.toString(),
      materialName: (row['material_name'] ?? '').toString(),
      movement: ((row['movement'] ?? 'recoleccion').toString()).toLowerCase(),
      scheduledTime: (row['scheduled_time'] ?? '').toString(),
      weekdays: _parseWeekdays(row['weekdays']),
      defaultDriverEmployeeId: row['default_driver_employee_id']?.toString(),
      defaultVehicleId: row['default_vehicle_id']?.toString(),
      isActive: row['is_active'] as bool? ?? true,
      notes: (row['notes'] ?? '').toString(),
      visitsPerDay: (row['visits_per_day'] as num?)?.toInt() ?? 1,
      effectiveFrom: _tryParseDateTime(row['effective_from']?.toString()),
      createdAt: _tryParseDateTime(row['created_at']?.toString()),
      updatedAt: _tryParseDateTime(row['updated_at']?.toString()),
    );
  }

  static const Object _unset = Object();
}

class LogisticsFixedServicesStore {
  static Future<void> ensureUpcoming() async {
    await Supabase.instance.client.rpc('sync_logistics_recurring_services');
  }

  static Future<List<LogisticsFixedServiceRecord>> loadRecords() async {
    final rows = await fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from(_kLogisticsFixedServicesTable)
          .select()
          .isFilter('effective_until', null)
          .order('site_name', ascending: true)
          .order('id', ascending: true)
          .range(from, to),
    );
    return rows.map(LogisticsFixedServiceRecord.fromRemoteRow).toList();
  }

  static Future<LogisticsFixedServiceRecord> saveRecord(
    LogisticsFixedServiceRecord record, {
    DateTime? fromDate,
  }) async {
    final row = await Supabase.instance.client.rpc(
      'save_logistics_recurrence',
      params: {
        'p_record': record.toUpsertJson(),
        if (fromDate != null) 'p_from': _fmtDbDate(fromDate),
      },
    );
    return LogisticsFixedServiceRecord.fromRemoteRow(
      Map<String, dynamic>.from(row as Map),
    );
  }

  static Future<void> changeFromVisit(
    String id,
    Map<String, dynamic> patch,
  ) async {
    await Supabase.instance.client.rpc(
      'change_logistics_recurrence_from_visit',
      params: {'p_service_id': id, 'p_patch': patch},
    );
  }

  static Future<List<Map<String, dynamic>>> loadWeek(DateTime start) {
    return fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('services')
          .select()
          .eq('area', 'LOGISTICA')
          .gte('service_date', _fmtDbDate(start))
          .lt('service_date', _fmtDbDate(start.add(const Duration(days: 7))))
          .order('service_date', ascending: true)
          .order('scheduled_time', ascending: true, nullsFirst: false)
          .order('id', ascending: true)
          .range(from, to),
    );
  }

  static Future<void> addExtraVisit(
    Map<String, dynamic> source,
    DateTime date,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    if (DateUtils.dateOnly(date).isBefore(today)) {
      throw const FormatException('Selecciona hoy o una fecha futura.');
    }
    await Supabase.instance.client.from('services').insert({
      'service_date': _fmtDbDate(date),
      'due_date': _fmtDbDate(date),
      'client_id': source['client_id'],
      'client_name': source['client_name'],
      'direction': source['direction'],
      'material_type': source['material_type'] ?? 'SIN_MATERIAL',
      'material_id': null,
      'driver_employee_id': source['driver_employee_id'],
      'vehicle_id': source['vehicle_id'],
      'status': 'programado',
      'planning_kind': 'VARIANTE',
      'area': 'LOGISTICA',
      'notes': 'Vuelta adicional de ${source['client_name']}.',
    });
  }
}

List<int> _parseWeekdays(dynamic raw) {
  if (raw is List) {
    final values = <int>{};
    for (final item in raw) {
      final value = item is num ? item.toInt() : int.tryParse('$item');
      if (value != null &&
          value >= DateTime.monday &&
          value <= DateTime.sunday) {
        values.add(value);
      }
    }
    final ordered = values.toList()..sort((a, b) => a.compareTo(b));
    return ordered;
  }
  return const <int>[];
}

String _fmtDbDate(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}

/// One observation per company, movement and date; repeated geofence entries
/// never increase the proposed daily visit count.
List<LogisticsFixedServiceRecord> logisticsRecurrenceSuggestions(
  List<Map<String, dynamic>> history,
  List<LogisticsFixedServiceRecord> records,
  DateTime month,
) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final row in history) {
    final date = DateTime.tryParse('${row['service_date']}');
    if (date == null ||
        date.year != month.year ||
        date.month != month.month ||
        row['area'] != 'LOGISTICA' ||
        row['status'] != 'completado' ||
        row['client_id'] == null) {
      continue;
    }
    final key = '${row['client_id']}|${row['direction']}';
    groups.putIfAbsent(key, () => []).add(row);
  }
  final suggestions = <LogisticsFixedServiceRecord>[];
  for (final rows in groups.values) {
    final dates = rows.map((r) => '${r['service_date']}').toSet();
    final weekdays = <int, int>{};
    for (final date in dates) {
      final day = DateTime.parse(date).weekday;
      weekdays[day] = (weekdays[day] ?? 0) + 1;
    }
    final days =
        weekdays.entries.where((e) => e.value >= 3).map((e) => e.key).toList()
          ..sort();
    if (days.isEmpty) continue;
    final row = rows.first;
    final matches = records
        .where(
          (r) => r.siteId == row['client_id'] && r.movement == row['direction'],
        )
        .toList();
    if (matches.length > 1) continue;
    final existing = matches.firstOrNull;
    if (existing != null &&
        existing.isActive &&
        existing.weekdays.length == days.length &&
        existing.weekdays.toSet().containsAll(days)) {
      continue;
    }
    final draft =
        existing ??
        LogisticsFixedServiceRecord(
          id: null,
          siteId: '${row['client_id']}',
          siteName: '${row['client_name']}',
          materialId: null,
          materialName: 'SIN_MATERIAL',
          movement: '${row['direction']}',
          scheduledTime: '',
          weekdays: days,
          defaultDriverEmployeeId: null,
          defaultVehicleId: null,
          isActive: true,
          notes: '',
          createdAt: null,
          updatedAt: null,
        );
    suggestions.add(
      draft.copyWith(
        weekdays: days,
        isActive: true,
        notes:
            'Días sugeridos desde ${month.month}/${month.year}: ${dates.length} fechas distintas. Revisar frecuencia y vueltas. ${draft.notes}'
                .trim(),
      ),
    );
  }
  suggestions.sort((a, b) => a.siteName.compareTo(b.siteName));
  return suggestions;
}
