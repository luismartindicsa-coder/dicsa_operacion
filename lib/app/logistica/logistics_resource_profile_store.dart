import 'package:supabase_flutter/supabase_flutter.dart';

const String _kLogisticsDriverProfilesTable = 'logistics_driver_profiles';
const String _kLogisticsVehicleProfilesTable = 'logistics_vehicle_profiles';

const List<String> kLogisticsPlanningStatusOptions = <String>[
  'ACTIVO',
  'RESTRINGIDO',
  'NO_PROGRAMAR',
];

const List<String> kLogisticsUnitTypeOptions = <String>[
  'POR_DEFINIR',
  'CAMIONETA',
  'CAMION',
  'PICK_UP',
  'GRUA',
  'TRAILER',
];

const List<String> kLogisticsLoadTypeOptions = <String>[
  'CONTENEDOR_CHICO',
  'CONTENEDOR_GRANDE',
  'PLATAFORMA',
  'JAULA',
  'CARGA_GENERAL',
];

String logisticsPlanningStatusLabel(String value) {
  switch (value) {
    case 'RESTRINGIDO':
      return 'Restringido';
    case 'NO_PROGRAMAR':
      return 'No programar';
    default:
      return 'Activo';
  }
}

String logisticsUnitTypeLabel(String value) {
  switch (value) {
    case 'CAMIONETA':
      return 'Camioneta';
    case 'CAMION':
      return 'Camion';
    case 'PICK_UP':
      return 'Pick up';
    case 'GRUA':
      return 'Grua';
    case 'TRAILER':
      return 'Trailer';
    default:
      return 'Por definir';
  }
}

String logisticsLoadTypeLabel(String value) {
  switch (value) {
    case 'CONTENEDOR_CHICO':
      return 'Contenedor chico';
    case 'CONTENEDOR_GRANDE':
      return 'Contenedor grande';
    case 'PLATAFORMA':
      return 'Plataforma';
    case 'JAULA':
      return 'Jaula';
    case 'CARGA_GENERAL':
      return 'Carga general';
    default:
      return 'Por definir';
  }
}

String inferLogisticsUnitTypeFromVehicleSource(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.contains('camioneta')) return 'CAMIONETA';
  if (normalized.contains('camion')) return 'CAMION';
  if (normalized.contains('pick')) return 'PICK_UP';
  if (normalized.contains('grua')) return 'GRUA';
  if (normalized.contains('trailer')) return 'TRAILER';
  return 'POR_DEFINIR';
}

List<String> suggestedLoadTypesForUnitType(String value) {
  switch (value) {
    case 'CAMIONETA':
      return const <String>['CONTENEDOR_CHICO', 'CARGA_GENERAL'];
    case 'CAMION':
      return const <String>['CONTENEDOR_GRANDE', 'CARGA_GENERAL'];
    case 'PICK_UP':
      return const <String>['CARGA_GENERAL'];
    case 'GRUA':
      return const <String>['JAULA'];
    case 'TRAILER':
      return const <String>['PLATAFORMA'];
    default:
      return const <String>[];
  }
}

class LogisticsDriverProfileRecord {
  final String employeeId;
  final String driverName;
  final List<String> compatibleUnitTypes;
  final String planningStatus;
  final String coverageNote;
  final String notes;
  final bool active;
  final DateTime? updatedAt;

  const LogisticsDriverProfileRecord({
    required this.employeeId,
    required this.driverName,
    required this.compatibleUnitTypes,
    required this.planningStatus,
    required this.coverageNote,
    required this.notes,
    required this.active,
    required this.updatedAt,
  });

  LogisticsDriverProfileRecord copyWith({
    String? employeeId,
    String? driverName,
    List<String>? compatibleUnitTypes,
    String? planningStatus,
    String? coverageNote,
    String? notes,
    bool? active,
    DateTime? updatedAt,
  }) {
    return LogisticsDriverProfileRecord(
      employeeId: employeeId ?? this.employeeId,
      driverName: driverName ?? this.driverName,
      compatibleUnitTypes: compatibleUnitTypes ?? this.compatibleUnitTypes,
      planningStatus: planningStatus ?? this.planningStatus,
      coverageNote: coverageNote ?? this.coverageNote,
      notes: notes ?? this.notes,
      active: active ?? this.active,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'employee_id': employeeId,
    'driver_name': driverName.trim(),
    'compatible_unit_types': compatibleUnitTypes,
    'planning_status': planningStatus,
    'coverage_note': coverageNote.trim().isEmpty ? null : coverageNote.trim(),
    'notes': notes.trim().isEmpty ? null : notes.trim(),
  };

  factory LogisticsDriverProfileRecord.fromRemoteRow(
    Map<String, dynamic> row, {
    bool active = true,
  }) {
    return LogisticsDriverProfileRecord(
      employeeId: (row['employee_id'] ?? '').toString(),
      driverName: (row['driver_name'] ?? '').toString(),
      compatibleUnitTypes: _normalizeStringList(row['compatible_unit_types']),
      planningStatus: (row['planning_status'] ?? 'ACTIVO').toString(),
      coverageNote: (row['coverage_note'] ?? '').toString(),
      notes: (row['notes'] ?? '').toString(),
      active: active,
      updatedAt: _tryParseDateTime(row['updated_at']?.toString()),
    );
  }
}

class LogisticsDriverProfileStore {
  static Future<List<LogisticsDriverProfileRecord>> loadProfiles() async {
    final client = Supabase.instance.client;
    final responses = await Future.wait<dynamic>([
      client
          .from('employees')
          .select('id,full_name,is_active')
          .eq('is_driver', true)
          .order('full_name'),
      _loadRemoteByEmployeeId(),
    ]);

    final employees = (responses[0] as List).cast<Map<String, dynamic>>();
    final remoteByEmployeeId =
        responses[1] as Map<String, LogisticsDriverProfileRecord>;
    final rowsToSync = <LogisticsDriverProfileRecord>[];

    final merged = employees
        .map((employee) {
          final employeeId = (employee['id'] ?? '').toString();
          final driverName = (employee['full_name'] ?? '').toString();
          final active = employee['is_active'] as bool? ?? true;
          final remote = remoteByEmployeeId[employeeId];
          final record = LogisticsDriverProfileRecord(
            employeeId: employeeId,
            driverName: driverName,
            compatibleUnitTypes: remote?.compatibleUnitTypes ?? const [],
            planningStatus: remote?.planningStatus ?? 'ACTIVO',
            coverageNote: remote?.coverageNote ?? '',
            notes: remote?.notes ?? '',
            active: active,
            updatedAt: remote?.updatedAt,
          );
          if (_needsDriverSync(record, remote)) {
            rowsToSync.add(record);
          }
          return record;
        })
        .where((record) => record.active)
        .toList(growable: false);

    if (rowsToSync.isNotEmpty) {
      try {
        await saveProfileRows(rowsToSync);
      } catch (_) {}
    }

    return merged;
  }

  static Future<void> saveProfileRow(
    LogisticsDriverProfileRecord record,
  ) async {
    await Supabase.instance.client.from(_kLogisticsDriverProfilesTable).upsert(
      <Map<String, dynamic>>[record.toUpsertJson()],
      onConflict: 'employee_id',
    );
  }

  static Future<void> saveProfileRows(
    List<LogisticsDriverProfileRecord> records,
  ) async {
    if (records.isEmpty) return;
    await Supabase.instance.client
        .from(_kLogisticsDriverProfilesTable)
        .upsert(
          records.map((row) => row.toUpsertJson()).toList(growable: false),
          onConflict: 'employee_id',
        );
  }

  static Future<Map<String, LogisticsDriverProfileRecord>>
  _loadRemoteByEmployeeId() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kLogisticsDriverProfilesTable)
          .select()
          .order('driver_name');
      final records = <String, LogisticsDriverProfileRecord>{};
      for (final raw in rows as List) {
        final record = LogisticsDriverProfileRecord.fromRemoteRow(
          Map<String, dynamic>.from(raw as Map),
        );
        records[record.employeeId] = record;
      }
      return records;
    } catch (_) {
      return <String, LogisticsDriverProfileRecord>{};
    }
  }
}

class LogisticsVehicleProfileRecord {
  final String vehicleId;
  final String vehicleCode;
  final String serialNumber;
  final String sourceVehicleType;
  final String sourceStatus;
  final String logisticsUnitType;
  final List<String> compatibleLoadTypes;
  final String planningStatus;
  final String capacityNote;
  final String notes;
  final bool active;
  final DateTime? updatedAt;

  const LogisticsVehicleProfileRecord({
    required this.vehicleId,
    required this.vehicleCode,
    required this.serialNumber,
    required this.sourceVehicleType,
    required this.sourceStatus,
    required this.logisticsUnitType,
    required this.compatibleLoadTypes,
    required this.planningStatus,
    required this.capacityNote,
    required this.notes,
    required this.active,
    required this.updatedAt,
  });

  LogisticsVehicleProfileRecord copyWith({
    String? vehicleId,
    String? vehicleCode,
    String? serialNumber,
    String? sourceVehicleType,
    String? sourceStatus,
    String? logisticsUnitType,
    List<String>? compatibleLoadTypes,
    String? planningStatus,
    String? capacityNote,
    String? notes,
    bool? active,
    DateTime? updatedAt,
  }) {
    return LogisticsVehicleProfileRecord(
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleCode: vehicleCode ?? this.vehicleCode,
      serialNumber: serialNumber ?? this.serialNumber,
      sourceVehicleType: sourceVehicleType ?? this.sourceVehicleType,
      sourceStatus: sourceStatus ?? this.sourceStatus,
      logisticsUnitType: logisticsUnitType ?? this.logisticsUnitType,
      compatibleLoadTypes: compatibleLoadTypes ?? this.compatibleLoadTypes,
      planningStatus: planningStatus ?? this.planningStatus,
      capacityNote: capacityNote ?? this.capacityNote,
      notes: notes ?? this.notes,
      active: active ?? this.active,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'vehicle_id': vehicleId,
    'vehicle_code': vehicleCode.trim(),
    'serial_number': serialNumber.trim().isEmpty ? null : serialNumber.trim(),
    'source_vehicle_type': sourceVehicleType.trim().isEmpty
        ? null
        : sourceVehicleType.trim(),
    'source_status': sourceStatus.trim().isEmpty ? 'activo' : sourceStatus,
    'logistics_unit_type': logisticsUnitType,
    'compatible_load_types': compatibleLoadTypes,
    'planning_status': planningStatus,
    'capacity_note': capacityNote.trim().isEmpty ? null : capacityNote.trim(),
    'notes': notes.trim().isEmpty ? null : notes.trim(),
  };

  factory LogisticsVehicleProfileRecord.fromRemoteRow(
    Map<String, dynamic> row, {
    bool active = true,
  }) {
    return LogisticsVehicleProfileRecord(
      vehicleId: (row['vehicle_id'] ?? '').toString(),
      vehicleCode: (row['vehicle_code'] ?? '').toString(),
      serialNumber: (row['serial_number'] ?? '').toString(),
      sourceVehicleType: (row['source_vehicle_type'] ?? '').toString(),
      sourceStatus: (row['source_status'] ?? 'activo').toString(),
      logisticsUnitType: (row['logistics_unit_type'] ?? 'POR_DEFINIR')
          .toString(),
      compatibleLoadTypes: _normalizeStringList(row['compatible_load_types']),
      planningStatus: (row['planning_status'] ?? 'ACTIVO').toString(),
      capacityNote: (row['capacity_note'] ?? '').toString(),
      notes: (row['notes'] ?? '').toString(),
      active: active,
      updatedAt: _tryParseDateTime(row['updated_at']?.toString()),
    );
  }
}

class LogisticsVehicleProfileStore {
  static Future<List<LogisticsVehicleProfileRecord>> loadProfiles() async {
    final client = Supabase.instance.client;
    final responses = await Future.wait<dynamic>([
      client
          .from('vehicles')
          .select('id,code,serial_number,status,type')
          .order('code'),
      _loadRemoteByVehicleId(),
    ]);

    final vehicles = (responses[0] as List).cast<Map<String, dynamic>>();
    final remoteByVehicleId =
        responses[1] as Map<String, LogisticsVehicleProfileRecord>;
    final rowsToSync = <LogisticsVehicleProfileRecord>[];

    final merged = vehicles
        .map((vehicle) {
          final vehicleId = (vehicle['id'] ?? '').toString();
          final vehicleCode = (vehicle['code'] ?? '').toString();
          final serialNumber = (vehicle['serial_number'] ?? '').toString();
          final sourceStatus = (vehicle['status'] ?? '').toString();
          final sourceType = (vehicle['type'] ?? '').toString();
          final active = sourceStatus.trim().toLowerCase() == 'activo';
          final remote = remoteByVehicleId[vehicleId];
          final record = LogisticsVehicleProfileRecord(
            vehicleId: vehicleId,
            vehicleCode: vehicleCode,
            serialNumber: serialNumber,
            sourceVehicleType: sourceType,
            sourceStatus: sourceStatus,
            logisticsUnitType:
                remote?.logisticsUnitType ??
                inferLogisticsUnitTypeFromVehicleSource(sourceType),
            compatibleLoadTypes: remote?.compatibleLoadTypes ?? const [],
            planningStatus: remote?.planningStatus ?? 'ACTIVO',
            capacityNote: remote?.capacityNote ?? '',
            notes: remote?.notes ?? '',
            active: active,
            updatedAt: remote?.updatedAt,
          );
          if (_needsVehicleSync(record, remote)) {
            rowsToSync.add(record);
          }
          return record;
        })
        .where((record) => record.active)
        .toList(growable: false);

    if (rowsToSync.isNotEmpty) {
      try {
        await saveProfileRows(rowsToSync);
      } catch (_) {}
    }

    return merged;
  }

  static Future<void> saveProfileRow(
    LogisticsVehicleProfileRecord record,
  ) async {
    await Supabase.instance.client.from(_kLogisticsVehicleProfilesTable).upsert(
      <Map<String, dynamic>>[record.toUpsertJson()],
      onConflict: 'vehicle_id',
    );
  }

  static Future<void> saveProfileRows(
    List<LogisticsVehicleProfileRecord> records,
  ) async {
    if (records.isEmpty) return;
    await Supabase.instance.client
        .from(_kLogisticsVehicleProfilesTable)
        .upsert(
          records.map((row) => row.toUpsertJson()).toList(growable: false),
          onConflict: 'vehicle_id',
        );
  }

  static Future<Map<String, LogisticsVehicleProfileRecord>>
  _loadRemoteByVehicleId() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kLogisticsVehicleProfilesTable)
          .select()
          .order('vehicle_code');
      final records = <String, LogisticsVehicleProfileRecord>{};
      for (final raw in rows as List) {
        final record = LogisticsVehicleProfileRecord.fromRemoteRow(
          Map<String, dynamic>.from(raw as Map),
        );
        records[record.vehicleId] = record;
      }
      return records;
    } catch (_) {
      return <String, LogisticsVehicleProfileRecord>{};
    }
  }
}

bool _needsDriverSync(
  LogisticsDriverProfileRecord merged,
  LogisticsDriverProfileRecord? remote,
) {
  if (remote == null) return true;
  return remote.driverName.trim() != merged.driverName.trim();
}

bool _needsVehicleSync(
  LogisticsVehicleProfileRecord merged,
  LogisticsVehicleProfileRecord? remote,
) {
  if (remote == null) return true;
  return remote.vehicleCode.trim() != merged.vehicleCode.trim() ||
      remote.serialNumber.trim() != merged.serialNumber.trim() ||
      remote.sourceStatus.trim() != merged.sourceStatus.trim() ||
      remote.sourceVehicleType.trim() != merged.sourceVehicleType.trim();
}

List<String> _normalizeStringList(dynamic raw) {
  final values = <String>[];
  if (raw is List) {
    for (final item in raw) {
      final normalized = item.toString().trim().toUpperCase();
      if (normalized.isNotEmpty && !values.contains(normalized)) {
        values.add(normalized);
      }
    }
    return values;
  }
  return const <String>[];
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
