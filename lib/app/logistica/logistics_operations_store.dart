import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/friendly_error_message.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'logistics_resource_profile_store.dart';

const logisticsIncidentTypes = {
  'ACCESO': 'Acceso complicado',
  'CAMBIO_UNIDAD': 'Cambio de unidad',
  'FALLA_MECANICA': 'Falla mecánica',
  'FALTA_CHOFER': 'Falta de chofer',
  'MATERIAL_NO_LISTO': 'Material no listo',
  'OTRA': 'Otra',
  'REPROGRAMACION': 'Reprogramación',
  'RETRASO': 'Retraso',
};
const logisticsIncidentStatuses = {
  'ABIERTA': 'Abierta',
  'EN_SEGUIMIENTO': 'En seguimiento',
  'RESUELTA': 'Resuelta',
};
const logisticsIncidentImpacts = {
  'ALTA': 'Alta',
  'MEDIA': 'Media',
  'BAJA': 'Baja',
};
String logisticsDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _text(Map<String, dynamic> row, String key) =>
    (row[key] ?? '').toString();
String _key(String value) => value.trim().toUpperCase();

class LogisticsIncident {
  final String id,
      serviceId,
      vehicleId,
      driverId,
      serviceLabel,
      vehicleCode,
      driverName;
  final String type, impact, status, summary, action, responsible, notes;
  final DateTime reportedAt;
  final String updatedAt;
  final DateTime? resolvedAt;
  bool get open => status != 'RESUELTA';
  const LogisticsIncident({
    required this.id,
    required this.serviceId,
    required this.vehicleId,
    required this.driverId,
    required this.serviceLabel,
    required this.vehicleCode,
    required this.driverName,
    required this.type,
    required this.impact,
    required this.status,
    required this.summary,
    required this.action,
    required this.responsible,
    required this.notes,
    required this.reportedAt,
    required this.updatedAt,
    this.resolvedAt,
  });
  factory LogisticsIncident.fromRow(Map<String, dynamic> row) =>
      LogisticsIncident(
        id: _text(row, 'id'),
        serviceId: _text(row, 'service_id'),
        vehicleId: _text(row, 'vehicle_id'),
        driverId: _text(row, 'driver_employee_id'),
        serviceLabel: _text(row, 'service_label'),
        vehicleCode: _text(row, 'vehicle_code'),
        driverName: _text(row, 'driver_name'),
        type: _text(row, 'incident_type'),
        impact: _text(row, 'impact_level'),
        status: _text(row, 'resolution_status'),
        summary: _text(row, 'summary'),
        action: _text(row, 'action_taken'),
        responsible: _text(row, 'responsible_name'),
        notes: _text(row, 'notes'),
        reportedAt: DateTime.parse(row['reported_at'].toString()).toLocal(),
        updatedAt: _text(row, 'updated_at'),
        resolvedAt: DateTime.tryParse(_text(row, 'resolved_at'))?.toLocal(),
      );
}

class LogisticsServiceSnapshot {
  final String id, client, vehicleId, driverId, status, time;
  final DateTime? date;
  const LogisticsServiceSnapshot({
    required this.id,
    required this.client,
    required this.vehicleId,
    required this.driverId,
    required this.status,
    required this.time,
    required this.date,
  });
  bool get open => !['completado', 'cancelado'].contains(status);
  bool get inRoute => ['en_ruta', 'en_sitio'].contains(status);
  String get label =>
      '${date == null ? 'Sin fecha' : logisticsDate(date!)}${time.isEmpty ? '' : ' · $time'} · $client';
  factory LogisticsServiceSnapshot.fromRow(Map<String, dynamic> row) =>
      LogisticsServiceSnapshot(
        id: _text(row, 'id'),
        client: _text(row, 'client_name'),
        vehicleId: _text(row, 'vehicle_id'),
        driverId: _text(row, 'driver_employee_id'),
        status: _text(row, 'status').trim().toLowerCase(),
        time: _text(row, 'scheduled_time'),
        date: DateTime.tryParse(
          _text(row, 'due_date').isEmpty
              ? _text(row, 'service_date')
              : _text(row, 'due_date'),
        ),
      );
}

const logisticsUnitStatuses = {
  'DISPONIBLE': 'Disponible',
  'ASIGNADA': 'Asignada',
  'EN_RUTA': 'En ruta',
  'EN_REVISION': 'En revisión',
  'EN_MANTENIMIENTO': 'En mantenimiento',
  'FUERA_DE_SERVICIO': 'Fuera de servicio',
};

class LogisticsManualUnitState {
  final String vehicleId, status, notes, updatedAt;
  const LogisticsManualUnitState({
    required this.vehicleId,
    required this.status,
    required this.notes,
    required this.updatedAt,
  });
  factory LogisticsManualUnitState.fromRow(Map<String, dynamic> row) =>
      LogisticsManualUnitState(
        vehicleId: _text(row, 'vehicle_id'),
        status: _text(row, 'operational_status'),
        notes: _text(row, 'notes'),
        updatedAt: _text(row, 'updated_at'),
      );
  bool get warning =>
      ['EN_REVISION', 'EN_MANTENIMIENTO', 'FUERA_DE_SERVICIO'].contains(status);
}

class LogisticsSourceIssue implements Exception {
  final String source;
  final Object cause;
  const LogisticsSourceIssue(this.source, this.cause);
  bool get missingTable =>
      cause is PostgrestException &&
      ['42P01', 'PGRST205'].contains((cause as PostgrestException).code);
  String get message {
    final label = switch (source) {
      'vehicles' => 'el catálogo de unidades',
      'logistics_unit_states' => 'los estados manuales de las unidades',
      'logistics_trip_incidents' => 'las incidencias',
      'services' => 'los servicios para vincular',
      'employees' => 'los choferes para vincular',
      _ => 'los datos de Logística',
    };
    if (missingTable && source == 'logistics_trip_incidents') {
      return 'Incidencias aún no está habilitado en la base de datos. Falta aplicar su actualización.';
    }
    if (missingTable && source == 'logistics_unit_states') {
      return 'Los estados manuales aún no están habilitados en la base de datos. Falta aplicar su actualización.';
    }
    if (cause is PostgrestException &&
        [
          '42501',
          'PGRST301',
          'PGRST302',
        ].contains((cause as PostgrestException).code)) {
      return 'No tienes acceso a $label. Revisa los permisos de tu sesión.';
    }
    if (isNetworkError(cause)) {
      return 'No se pudo conectar para cargar $label. Intenta de nuevo.';
    }
    return 'No se pudieron cargar $label. Intenta de nuevo.';
  }

  @override
  String toString() => message;
}

class LogisticsOperationsBundle {
  final List<LogisticsVehicleProfileRecord> vehicles;
  final Map<String, String> drivers;
  final List<LogisticsServiceSnapshot> services;
  final List<LogisticsIncident> incidents;
  final Map<String, LogisticsManualUnitState> unitStates;
  final Map<String, LogisticsSourceIssue> issues;
  const LogisticsOperationsBundle({
    this.vehicles = const [],
    this.drivers = const {},
    this.services = const [],
    this.incidents = const [],
    this.unitStates = const {},
    this.issues = const {},
  });
  bool available(String source) => !issues.containsKey(source);
}

class LogisticsOperationsStore {
  static final _client = Supabase.instance.client;
  static Future<List<Map<String, dynamic>>> _rows(
    String table,
    String columns,
    String order,
  ) => fetchAllSupabaseRows(
    (from, to) =>
        _client.from(table).select(columns).order(order).range(from, to),
  );

  static List<LogisticsVehicleProfileRecord> _vehicles(
    List<Map<String, dynamic>> rows,
  ) =>
      rows
          .map(
            (row) => LogisticsVehicleProfileRecord.fromRemoteRow({
              'vehicle_id': row['id'],
              'vehicle_code': row['code'],
              'serial_number': row['serial_number'],
              'source_vehicle_type': row['type'],
              'source_status': row['status'],
              'logistics_unit_type': inferLogisticsUnitTypeFromVehicleSource(
                _text(row, 'type'),
              ),
            }, active: _key(_text(row, 'status')) == 'ACTIVO'),
          )
          .toList()
        ..sort((a, b) => _key(a.vehicleCode).compareTo(_key(b.vehicleCode)));

  // Each page loads only its own data. Neither depends on Maintenance or Services.
  static Future<LogisticsOperationsBundle> load({required bool fleet}) async {
    final issues = <String, LogisticsSourceIssue>{};
    Future<List<T>> read<T>(
      String source,
      String columns,
      String order,
      T Function(Map<String, dynamic>) parse,
    ) async {
      try {
        return (await _rows(source, columns, order)).map(parse).toList();
      } catch (error) {
        issues[source] = LogisticsSourceIssue(source, error);
        return [];
      }
    }

    if (fleet) {
      final results = await Future.wait([
        read(
          'vehicles',
          'id,code,serial_number,status,type',
          'code',
          (row) => row,
        ),
        read('logistics_unit_states', '*', 'vehicle_id', (row) => row),
      ]);
      return LogisticsOperationsBundle(
        vehicles: _vehicles(results[0]),
        unitStates: {
          for (final row in results[1])
            _text(row, 'vehicle_id'): LogisticsManualUnitState.fromRow(row),
        },
        issues: issues,
      );
    }
    final incidents = await read(
      'logistics_trip_incidents',
      '*',
      'id',
      LogisticsIncident.fromRow,
    );
    incidents.sort((a, b) {
      final date = b.reportedAt.compareTo(a.reportedAt);
      return date != 0 ? date : a.id.compareTo(b.id);
    });
    return LogisticsOperationsBundle(incidents: incidents, issues: issues);
  }

  // Optional links are loaded only when opening a capture form. Their failure
  // cannot hide the incident history or prevent a general incident being saved.
  static Future<LogisticsOperationsBundle> loadIncidentFormSources(
    LogisticsOperationsBundle current,
  ) async {
    final issues = <String, LogisticsSourceIssue>{};
    Future<List<Map<String, dynamic>>> read(
      String source,
      String columns,
      String order,
    ) async {
      try {
        return await _rows(source, columns, order);
      } catch (error) {
        issues[source] = LogisticsSourceIssue(source, error);
        return [];
      }
    }

    final rows = await Future.wait([
      current.vehicles.isNotEmpty
          ? Future.value(<Map<String, dynamic>>[])
          : read('vehicles', 'id,code,serial_number,status,type', 'code'),
      read(
        'services',
        'id,service_date,due_date,scheduled_time,client_name,vehicle_id,driver_employee_id,status',
        'id',
      ),
      read('employees', 'id,full_name', 'full_name'),
    ]);
    final services = rows[1].map(LogisticsServiceSnapshot.fromRow).toList()
      ..sort((a, b) {
        final date = (b.date ?? DateTime(1900)).compareTo(
          a.date ?? DateTime(1900),
        );
        return date != 0 ? date : a.client.compareTo(b.client);
      });
    return LogisticsOperationsBundle(
      vehicles: current.vehicles.isNotEmpty
          ? current.vehicles
          : _vehicles(rows[0]),
      services: services,
      drivers: {
        for (final row in rows[2]) _text(row, 'id'): _text(row, 'full_name'),
      },
      issues: issues,
    );
  }

  static Future<void> saveUnitState({
    required String vehicleId,
    required String status,
    required String notes,
    LogisticsManualUnitState? original,
  }) async {
    if (vehicleId.isEmpty || !logisticsUnitStatuses.containsKey(status)) {
      throw ArgumentError('Selecciona una unidad y un estado válido.');
    }
    final payload = {
      'vehicle_id': vehicleId,
      'operational_status': status,
      'notes': notes.trim(),
    };
    try {
      if (original == null) {
        await _client.from('logistics_unit_states').insert(payload);
        return;
      }
      final saved = await _client
          .from('logistics_unit_states')
          .update(payload)
          .eq('vehicle_id', vehicleId)
          .eq('updated_at', original.updatedAt)
          .select('vehicle_id');
      if (saved.isEmpty) {
        throw StateError(
          'El estado cambió. Cierra el formulario y vuelve a abrirlo para editar la versión actual.',
        );
      }
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw StateError(
          'Otra persona ya capturó el estado. Cierra el formulario y vuelve a abrirlo.',
        );
      }
      throw LogisticsSourceIssue('logistics_unit_states', error);
    }
  }

  static Future<String> saveIncident(
    Map<String, dynamic> draft, {
    LogisticsIncident? original,
  }) async {
    final fields = [
      'service_id',
      'vehicle_id',
      'driver_employee_id',
      'service_label',
      'vehicle_code',
      'driver_name',
      'incident_type',
      'impact_level',
      'resolution_status',
      'summary',
      'action_taken',
      'responsible_name',
      'notes',
      'reported_at',
    ];
    final payload = {for (final field in fields) field: draft[field]};
    if (!logisticsIncidentTypes.containsKey(payload['incident_type']) ||
        !logisticsIncidentImpacts.containsKey(payload['impact_level']) ||
        !logisticsIncidentStatuses.containsKey(payload['resolution_status']) ||
        _text(payload, 'summary').trim().isEmpty ||
        (payload['resolution_status'] == 'RESUELTA' &&
            _text(payload, 'action_taken').trim().isEmpty)) {
      throw ArgumentError(
        'Captura la descripción y la acción realizada para resolver la incidencia.',
      );
    }
    try {
      if (original == null) {
        final row = await _client
            .from('logistics_trip_incidents')
            .insert(payload)
            .select('id')
            .single();
        return row['id'].toString();
      }
      final saved = await _client
          .from('logistics_trip_incidents')
          .update(payload)
          .eq('id', original.id)
          .eq('updated_at', original.updatedAt)
          .select('id');
      if (saved.isEmpty) {
        throw StateError(
          'La incidencia cambió. Cierra el formulario y vuelve a abrirla para editar la versión actual.',
        );
      }
      return original.id;
    } on PostgrestException catch (error) {
      throw LogisticsSourceIssue('logistics_trip_incidents', error);
    }
  }
}
