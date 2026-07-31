import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  if (time == null) return raw.trim();
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
    required this.createdAt,
    required this.updatedAt,
  });

  bool appliesTo(DateTime date) {
    return weekdays.contains(DateUtils.dateOnly(date).weekday);
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
      'scheduled_time': scheduledTime,
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
      createdAt: _tryParseDateTime(row['created_at']?.toString()),
      updatedAt: _tryParseDateTime(row['updated_at']?.toString()),
    );
  }

  static const Object _unset = Object();
}

class LogisticsFixedServiceScheduleResult {
  final int inserted;
  final int skippedExisting;
  final int skippedInactive;
  final int skippedWeekday;

  const LogisticsFixedServiceScheduleResult({
    required this.inserted,
    required this.skippedExisting,
    required this.skippedInactive,
    required this.skippedWeekday,
  });
}

class LogisticsFixedServicesStore {
  static Future<List<LogisticsFixedServiceRecord>> loadRecords() async {
    final rows = await Supabase.instance.client
        .from(_kLogisticsFixedServicesTable)
        .select()
        .order('site_name')
        .order('scheduled_time');
    return (rows as List)
        .map(
          (row) => LogisticsFixedServiceRecord.fromRemoteRow(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  static Future<LogisticsFixedServiceRecord> saveRecord(
    LogisticsFixedServiceRecord record,
  ) async {
    final row = await Supabase.instance.client
        .from(_kLogisticsFixedServicesTable)
        .upsert(record.toUpsertJson())
        .select()
        .single();
    return LogisticsFixedServiceRecord.fromRemoteRow(
      Map<String, dynamic>.from(row),
    );
  }

  static Future<void> deleteRecord(String id) async {
    await Supabase.instance.client
        .from(_kLogisticsFixedServicesTable)
        .delete()
        .eq('id', id);
  }

  static Future<LogisticsFixedServiceScheduleResult> scheduleForDate(
    DateTime date, {
    required List<LogisticsFixedServiceRecord> records,
  }) async {
    final serviceDate = DateUtils.dateOnly(date);
    final active = records.where((record) => record.isActive).toList();
    final applicable = active
        .where((record) => record.appliesTo(serviceDate))
        .toList();
    final skippedInactive = records.length - active.length;
    final skippedWeekday = active.length - applicable.length;
    final templateIds = applicable
        .map((record) => record.id)
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toList(growable: false);

    if (templateIds.isEmpty) {
      return LogisticsFixedServiceScheduleResult(
        inserted: 0,
        skippedExisting: 0,
        skippedInactive: skippedInactive,
        skippedWeekday: skippedWeekday,
      );
    }

    final existingRows = await Supabase.instance.client
        .from('services')
        .select('fixed_service_id')
        .eq('area', 'LOGISTICA')
        .eq('service_date', _fmtDbDate(serviceDate))
        .inFilter('fixed_service_id', templateIds);

    final existingIds = (existingRows as List)
        .map((row) => (row as Map)['fixed_service_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final inserts = <Map<String, dynamic>>[];
    for (final record in applicable) {
      final fixedId = record.id;
      if (fixedId == null || fixedId.trim().isEmpty) continue;
      if (existingIds.contains(fixedId)) continue;
      inserts.add(<String, dynamic>{
        'service_date': _fmtDbDate(serviceDate),
        'due_date': _fmtDbDate(serviceDate),
        'scheduled_time': record.scheduledTime,
        'direction': record.movement,
        'status': 'programado',
        'planning_kind': 'FIJO',
        'fixed_service_id': fixedId,
        'client_id': record.siteId,
        'client_name': record.siteName,
        'material_id': record.materialId,
        'material_type': record.materialName,
        'driver_employee_id': record.defaultDriverEmployeeId,
        'vehicle_id': record.defaultVehicleId,
        'area': 'LOGISTICA',
        'notes': record.notes.trim().isEmpty ? null : record.notes.trim(),
      });
    }

    if (inserts.isNotEmpty) {
      await Supabase.instance.client.from('services').insert(inserts);
    }

    return LogisticsFixedServiceScheduleResult(
      inserted: inserts.length,
      skippedExisting: applicable.length - inserts.length,
      skippedInactive: skippedInactive,
      skippedWeekday: skippedWeekday,
    );
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
