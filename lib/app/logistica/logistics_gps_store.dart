import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'logistics_geofence_store.dart';
import 'logistics_gps_visit_store.dart';
import 'logistics_gps_stop_store.dart';
import 'logistics_gps_curation_store.dart';

enum LogisticsGpsPositionStatus {
  recent,
  delayed,
  missing,
  unavailable,
  future,
}

class LogisticsGpsUnit {
  final String providerId, providerName;
  final String? vehicleId, vehicleCode;
  final double? latitude, longitude;
  final DateTime? positionAt, observedAt;
  final bool visible;
  const LogisticsGpsUnit({
    required this.providerId,
    required this.providerName,
    this.vehicleId,
    this.vehicleCode,
    this.latitude,
    this.longitude,
    this.positionAt,
    this.observedAt,
    this.visible = false,
  });

  factory LogisticsGpsUnit.fromRow(Map<String, dynamic> row) {
    final vehicle = row['vehicles'] as Map?;
    return LogisticsGpsUnit(
      providerId: row['provider_unit_id'].toString(),
      providerName: row['provider_name']?.toString() ?? '',
      vehicleId: row['vehicle_id']?.toString(),
      vehicleCode: vehicle?['code']?.toString(),
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      positionAt: DateTime.tryParse(
        row['position_at']?.toString() ?? '',
      )?.toUtc(),
      observedAt: DateTime.tryParse(
        row['observed_at']?.toString() ?? '',
      )?.toUtc(),
      visible: row['provider_visible'] == true,
    );
  }
  String get label => vehicleCode ?? providerName;
  bool get hasPosition =>
      visible &&
      latitude != null &&
      longitude != null &&
      positionAt != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;

  LogisticsGpsPositionStatus status(DateTime now) {
    if (!visible && observedAt != null) {
      return LogisticsGpsPositionStatus.unavailable;
    }
    if (!hasPosition) return LogisticsGpsPositionStatus.missing;
    final age = now.toUtc().difference(positionAt!);
    if (age < const Duration(minutes: -1)) {
      return LogisticsGpsPositionStatus.future;
    }
    return age <= const Duration(minutes: 15)
        ? LogisticsGpsPositionStatus.recent
        : LogisticsGpsPositionStatus.delayed;
  }
}

class LogisticsGpsBundle {
  final GpsCuration curation;
  final LogisticsGpsStopBundle stops;
  final LogisticsGpsVisitBundle visits;
  final LogisticsGeofenceBundle geofences;
  final List<LogisticsGpsUnit> units;
  final DateTime? lastSuccessAt, tokenExpiresAt;
  final String state;
  final String? errorCode;
  const LogisticsGpsBundle({
    this.curation = const GpsCuration(),
    this.stops = const LogisticsGpsStopBundle(),
    this.visits = const LogisticsGpsVisitBundle(),
    this.geofences = const LogisticsGeofenceBundle(),
    required this.units,
    required this.state,
    this.lastSuccessAt,
    this.tokenExpiresAt,
    this.errorCode,
  });

  String? connectionNotice(DateTime now) {
    if (state == 'pending' || errorCode == 'not_configured') {
      return 'Conexión con EPCOM pendiente de activar.';
    }
    if (errorCode == 'authorization') {
      return 'EPCOM no autorizó la consulta. Se necesita renovar o revisar el acceso.';
    }
    if (state == 'error') {
      return 'No se pudo actualizar desde EPCOM. Se muestran las últimas posiciones recibidas.';
    }
    if (lastSuccessAt == null ||
        now.toUtc().difference(lastSuccessAt!) > const Duration(minutes: 3)) {
      return 'Conexión sin actualizar. Las posiciones mostradas pueden haber cambiado.';
    }
    return null;
  }
}

class LogisticsGpsAccessDenied implements Exception {}

class LogisticsGpsStore {
  static Future<LogisticsGpsBundle> load() async {
    final client = Supabase.instance.client;
    if (await client.rpc('can_view_logistics_gps') != true) {
      throw LogisticsGpsAccessDenied();
    }
    final results = await Future.wait([
      fetchAllSupabaseRows(
        (from, to) => client
            .from('logistics_gps_units')
            .select(
              'provider_unit_id,provider_name,vehicle_id,latitude,longitude,position_at,observed_at,provider_visible,vehicles(code)',
            )
            .order('provider_unit_id')
            .range(from, to),
      ),
      client
          .from('logistics_gps_sync_state')
          .select('status,last_success_at,error_code,token_expires_at')
          .eq('singleton', true),
    ]);
    final stateRows = results[1];
    if (stateRows.isEmpty) throw LogisticsGpsAccessDenied();
    final state = stateRows.single;
    final units = results[0].map(LogisticsGpsUnit.fromRow).toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return LogisticsGpsBundle(
      curation: await GpsCurationStore.load(),
      stops: await LogisticsGpsStopStore.load(),
      visits: await LogisticsGpsVisitStore.load(),
      geofences: await LogisticsGeofenceStore.load(),
      units: units,
      state: state['status'].toString(),
      lastSuccessAt: DateTime.tryParse(
        state['last_success_at']?.toString() ?? '',
      )?.toUtc(),
      tokenExpiresAt: DateTime.tryParse(
        state['token_expires_at']?.toString() ?? '',
      )?.toUtc(),
      errorCode: state['error_code']?.toString(),
    );
  }
}
