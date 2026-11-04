import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/utils/fetch_all_supabase_rows.dart';

const String _kLogisticsDriverProfilesTable = 'logistics_driver_profiles';
const String _kLogisticsVehicleProfilesTable = 'logistics_vehicle_profiles';

const _unchangedTankCapacity = Object();
const _unchangedAssignedDriver = Object();
const _unchangedModelYear = Object();

int? parseLogisticsModelYear(String input) {
  final value = input.trim();
  if (value.isEmpty) return null;
  final year = int.tryParse(value);
  if (!RegExp(r'^\d{4}$').hasMatch(value) ||
      year == null ||
      year < 1900 ||
      year > 2100) {
    throw const FormatException(
      'Captura un año de 4 dígitos entre 1900 y 2100.',
    );
  }
  return year;
}

String logisticsAssignedDriverLabel(
  String? employeeId,
  List<LogisticsDriverProfileRecord> drivers,
) {
  if (employeeId == null) return 'Sin chofer asignado';
  for (final driver in drivers) {
    if (driver.employeeId == employeeId) return driver.driverName;
  }
  return 'Chofer no disponible';
}

String logisticsTankCapacityInput(double? liters) => liters == null
    ? ''
    : liters.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

String logisticsTankCapacityLabel(double? liters) =>
    liters == null ? 'Sin capturar' : '${logisticsTankCapacityInput(liters)} L';

double? parseLogisticsTankCapacity(String input) {
  final value = input.trim().replaceAll(',', '.');
  if (value.isEmpty) return null;
  final liters = double.tryParse(value);
  if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(value) ||
      liters == null ||
      !liters.isFinite ||
      liters <= 0 ||
      liters > 999999.99) {
    throw const FormatException(
      'Captura litros mayores a 0, con máximo 2 decimales.',
    );
  }
  return liters;
}

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

class LogisticsDriverCompany {
  final String siteId;
  final String siteName;
  final bool active;

  const LogisticsDriverCompany({
    required this.siteId,
    required this.siteName,
    this.active = true,
  });

  factory LogisticsDriverCompany.fromRemoteRow(Map<String, dynamic> row) {
    final site = row['sites'] as Map?;
    return LogisticsDriverCompany(
      siteId: row['site_id'].toString(),
      siteName: site?['name']?.toString() ?? 'Empresa no disponible',
      active: site?['is_active'] as bool? ?? false,
    );
  }
}

class LogisticsDriverProfileRecord {
  final String employeeId;
  final String driverName;
  final List<String> compatibleUnitTypes;
  final String planningStatus;
  final String coverageNote;
  final List<LogisticsDriverCompany> assignedCompanies;
  final List<String> coverageImportPending;
  final String notes;
  final bool active;
  final DateTime? updatedAt;

  const LogisticsDriverProfileRecord({
    required this.employeeId,
    required this.driverName,
    required this.compatibleUnitTypes,
    required this.planningStatus,
    required this.coverageNote,
    this.assignedCompanies = const [],
    this.coverageImportPending = const [],
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
    List<LogisticsDriverCompany>? assignedCompanies,
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
      assignedCompanies: assignedCompanies ?? this.assignedCompanies,
      coverageImportPending: coverageImportPending,
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
    'coverage_note': coverageNote.isEmpty ? null : coverageNote,
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
      assignedCompanies:
          ((row['logistics_driver_companies'] as List?) ?? const [])
              .map(
                (raw) => LogisticsDriverCompany.fromRemoteRow(
                  Map<String, dynamic>.from(raw as Map),
                ),
              )
              .toList()
            ..sort(
              (a, b) =>
                  a.siteName.toLowerCase().compareTo(b.siteName.toLowerCase()),
            ),
      coverageImportPending:
          ((row['coverage_import_pending'] as List?) ?? const [])
              .map((value) => value.toString())
              .toList(),
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
            assignedCompanies: remote?.assignedCompanies ?? const [],
            coverageImportPending: remote?.coverageImportPending ?? const [],
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
    LogisticsDriverProfileRecord record, {
    required List<String> expectedCompanyIds,
  }) async {
    await Supabase.instance.client.rpc(
      'save_logistics_driver_with_companies',
      params: {
        'p_profile': record.toUpsertJson(),
        'p_site_ids': record.assignedCompanies
            .map((company) => company.siteId)
            .toList(),
        'p_expected_site_ids': expectedCompanyIds,
      },
    );
  }

  static Future<void> saveProfileRows(
    List<LogisticsDriverProfileRecord> records,
  ) async {
    if (records.isEmpty) return;
    await Supabase.instance.client
        .from(_kLogisticsDriverProfilesTable)
        .upsert(
          records
              .map(
                (row) => <String, dynamic>{
                  'employee_id': row.employeeId,
                  'driver_name': row.driverName,
                },
              )
              .toList(growable: false),
          onConflict: 'employee_id',
        );
  }

  static Future<Map<String, LogisticsDriverProfileRecord>>
  _loadRemoteByEmployeeId() async {
    final rows = await Supabase.instance.client
        .from(_kLogisticsDriverProfilesTable)
        .select('*,logistics_driver_companies(site_id,sites(name,is_active))')
        .order('driver_name');
    final records = <String, LogisticsDriverProfileRecord>{};
    for (final raw in rows as List) {
      final record = LogisticsDriverProfileRecord.fromRemoteRow(
        Map<String, dynamic>.from(raw as Map),
      );
      records[record.employeeId] = record;
    }
    return records;
  }
}

class LogisticsVehicleProfileRecord {
  final String vehicleId;
  final String vehicleCode;
  final String serialNumber;
  final int? modelYear;
  final String modelName;
  final String sourceVehicleType;
  final String sourceStatus;
  final String logisticsUnitType;
  final List<String> compatibleLoadTypes;
  final String planningStatus;
  final String capacityNote;
  final double? tankCapacityLiters;
  final String? assignedDriverEmployeeId;
  final String notes;
  final bool active;
  final DateTime? updatedAt;

  const LogisticsVehicleProfileRecord({
    required this.vehicleId,
    required this.vehicleCode,
    required this.serialNumber,
    this.modelYear,
    this.modelName = '',
    required this.sourceVehicleType,
    required this.sourceStatus,
    required this.logisticsUnitType,
    required this.compatibleLoadTypes,
    required this.planningStatus,
    required this.capacityNote,
    this.tankCapacityLiters,
    this.assignedDriverEmployeeId,
    required this.notes,
    required this.active,
    required this.updatedAt,
  });

  LogisticsVehicleProfileRecord copyWith({
    String? vehicleId,
    String? vehicleCode,
    String? serialNumber,
    Object? modelYear = _unchangedModelYear,
    String? modelName,
    String? sourceVehicleType,
    String? sourceStatus,
    String? logisticsUnitType,
    List<String>? compatibleLoadTypes,
    String? planningStatus,
    String? capacityNote,
    Object? tankCapacityLiters = _unchangedTankCapacity,
    Object? assignedDriverEmployeeId = _unchangedAssignedDriver,
    String? notes,
    bool? active,
    DateTime? updatedAt,
  }) {
    return LogisticsVehicleProfileRecord(
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleCode: vehicleCode ?? this.vehicleCode,
      serialNumber: serialNumber ?? this.serialNumber,
      modelYear: identical(modelYear, _unchangedModelYear)
          ? this.modelYear
          : modelYear as int?,
      modelName: modelName ?? this.modelName,
      sourceVehicleType: sourceVehicleType ?? this.sourceVehicleType,
      sourceStatus: sourceStatus ?? this.sourceStatus,
      logisticsUnitType: logisticsUnitType ?? this.logisticsUnitType,
      compatibleLoadTypes: compatibleLoadTypes ?? this.compatibleLoadTypes,
      planningStatus: planningStatus ?? this.planningStatus,
      capacityNote: capacityNote ?? this.capacityNote,
      tankCapacityLiters: identical(tankCapacityLiters, _unchangedTankCapacity)
          ? this.tankCapacityLiters
          : tankCapacityLiters as double?,
      assignedDriverEmployeeId:
          identical(assignedDriverEmployeeId, _unchangedAssignedDriver)
          ? this.assignedDriverEmployeeId
          : assignedDriverEmployeeId as String?,
      notes: notes ?? this.notes,
      active: active ?? this.active,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'vehicle_id': vehicleId,
    'vehicle_code': vehicleCode.trim(),
    'serial_number': serialNumber.trim().isEmpty ? null : serialNumber.trim(),
    'model_year': modelYear,
    'model_name': modelName.trim().isEmpty ? null : modelName.trim(),
    'source_vehicle_type': sourceVehicleType.trim().isEmpty
        ? null
        : sourceVehicleType.trim(),
    'source_status': sourceStatus.trim().isEmpty ? 'activo' : sourceStatus,
    'logistics_unit_type': logisticsUnitType,
    'compatible_load_types': compatibleLoadTypes,
    'planning_status': planningStatus,
    'capacity_note': capacityNote.trim().isEmpty ? null : capacityNote.trim(),
    'tank_capacity_liters': tankCapacityLiters,
    'assigned_driver_employee_id': assignedDriverEmployeeId,
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
      modelYear: int.tryParse('${row['model_year'] ?? ''}'),
      modelName: (row['model_name'] ?? '').toString(),
      sourceVehicleType: (row['source_vehicle_type'] ?? '').toString(),
      sourceStatus: (row['source_status'] ?? 'activo').toString(),
      logisticsUnitType: (row['logistics_unit_type'] ?? 'POR_DEFINIR')
          .toString(),
      compatibleLoadTypes: _normalizeStringList(row['compatible_load_types']),
      planningStatus: (row['planning_status'] ?? 'ACTIVO').toString(),
      capacityNote: (row['capacity_note'] ?? '').toString(),
      tankCapacityLiters: double.tryParse(
        '${row['tank_capacity_liters'] ?? ''}',
      ),
      assignedDriverEmployeeId: row['assigned_driver_employee_id'] as String?,
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
            modelYear: remote?.modelYear,
            modelName: remote?.modelName ?? '',
            sourceVehicleType: sourceType,
            sourceStatus: sourceStatus,
            logisticsUnitType:
                remote?.logisticsUnitType ??
                inferLogisticsUnitTypeFromVehicleSource(sourceType),
            compatibleLoadTypes: remote?.compatibleLoadTypes ?? const [],
            planningStatus: remote?.planningStatus ?? 'ACTIVO',
            capacityNote: remote?.capacityNote ?? '',
            tankCapacityLiters: remote?.tankCapacityLiters,
            assignedDriverEmployeeId: remote?.assignedDriverEmployeeId,
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
        // Master-data synchronization must preserve manually captured details,
        // including concurrent changes to year, model, tank and driver.
        await client
            .from(_kLogisticsVehicleProfilesTable)
            .upsert(
              rowsToSync
                  .map(
                    (row) => row.toUpsertJson()
                      ..remove('model_year')
                      ..remove('model_name')
                      ..remove('tank_capacity_liters')
                      ..remove('assigned_driver_employee_id'),
                  )
                  .toList(),
              onConflict: 'vehicle_id',
            );
      } catch (_) {}
    }

    return merged;
  }

  static Future<void> saveProfileRow(
    LogisticsVehicleProfileRecord record,
  ) async {
    _validateProfile(record);
    await Supabase.instance.client.from(_kLogisticsVehicleProfilesTable).upsert(
      <Map<String, dynamic>>[record.toUpsertJson()],
      onConflict: 'vehicle_id',
    );
  }

  static Future<void> saveProfileRows(
    List<LogisticsVehicleProfileRecord> records,
  ) async {
    if (records.isEmpty) return;
    for (final record in records) {
      _validateProfile(record);
    }
    await Supabase.instance.client
        .from(_kLogisticsVehicleProfilesTable)
        .upsert(
          records.map((row) => row.toUpsertJson()).toList(growable: false),
          onConflict: 'vehicle_id',
        );
  }

  static void _validateProfile(LogisticsVehicleProfileRecord record) {
    if (record.modelYear != null) {
      parseLogisticsModelYear(record.modelYear.toString());
    }
    final liters = record.tankCapacityLiters;
    if (liters != null &&
        (!liters.isFinite || liters <= 0 || liters > 999999.99)) {
      throw ArgumentError('La capacidad del tanque debe ser mayor a 0 litros.');
    }
  }

  static Future<Map<String, double?>> loadTankCapacities() async {
    final rows = await fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from(_kLogisticsVehicleProfilesTable)
          .select('vehicle_id,tank_capacity_liters')
          .order('vehicle_id')
          .range(from, to),
    );
    return {
      for (final row in rows)
        row['vehicle_id'].toString(): double.tryParse(
          '${row['tank_capacity_liters'] ?? ''}',
        ),
    };
  }

  static Future<Map<String, LogisticsVehicleProfileRecord>>
  _loadRemoteByVehicleId() async {
    // A failed read is not an empty profile: showing editable defaults could
    // overwrite captured details on the next save.
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
