import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/utils/fetch_all_supabase_rows.dart';
import 'logistics_diesel_store.dart';
import 'logistics_gasoline_store.dart';
import 'logistics_fuel_cost.dart';
import 'logistics_performance_store.dart';
import 'logistics_resource_profile_store.dart';

class PerformanceFuel {
  final double diesel;
  final double gasoline;
  const PerformanceFuel({this.diesel = 0, this.gasoline = 0});
  double get total => diesel + gasoline;
  bool get mixed => diesel > 0 && gasoline > 0;
  PerformanceFuel operator +(PerformanceFuel other) => PerformanceFuel(
    diesel: diesel + other.diesel,
    gasoline: gasoline + other.gasoline,
  );
}

class PerformanceService {
  final String id;
  final String company;
  final String movement;
  final String driver;
  const PerformanceService(this.id, this.company, this.movement, this.driver);
}

class PerformanceLoad {
  final String? id;
  final String? vehicleId;
  final String vehicleLabel;
  final bool diesel;
  final double liters;
  final String driver;
  final String origin;
  final bool litersEstimated;
  const PerformanceLoad({
    required this.id,
    required this.vehicleId,
    required this.vehicleLabel,
    required this.diesel,
    required this.liters,
    required this.driver,
    required this.origin,
    this.litersEstimated = false,
  });
}

class PerformanceDay {
  final DateTime date;
  final String vehicleKey;
  final String vehicleLabel;
  final String? vehicleId;
  final double? tankCapacityLiters;
  LogisticsVehicleMileageRecord? mileage;
  final List<PerformanceService> services = [];
  final List<PerformanceLoad> loads = [];

  PerformanceDay({
    required this.date,
    required this.vehicleKey,
    required this.vehicleLabel,
    required this.vehicleId,
    required this.tankCapacityLiters,
  });

  double get kilometers => mileage?.kilometers ?? 0;
  double? get dieselPrice => mileage?.dieselPricePerLiter;
  double? get gasolinePrice => mileage?.gasolinePricePerLiter;
  int get trips => services.length;
  PerformanceFuel get fuel => loads.fold(
    const PerformanceFuel(),
    (sum, load) =>
        sum +
        PerformanceFuel(
          diesel: load.diesel ? load.liters : 0,
          gasoline: load.diesel ? 0 : load.liters,
        ),
  );
  LogisticsFuelCost get cost => LogisticsFuelCost.calculate(
    dieselLiters: fuel.diesel,
    gasolineLiters: fuel.gasoline,
    dieselPrice: dieselPrice,
    gasolinePrice: gasolinePrice,
  );
  bool get missingMileage =>
      mileage == null && (loads.isNotEmpty || services.isNotEmpty);
}

/// One unit over the entire selected period. No daily fuel matching is required.
class PerformanceUnit {
  final List<PerformanceDay> days;
  PerformanceUnit(Iterable<PerformanceDay> source)
    : days = source.toList()..sort((a, b) => b.date.compareTo(a.date));
  String get vehicleKey => days.first.vehicleKey;
  String get vehicleLabel => days.first.vehicleLabel;
  double? get tankCapacityLiters => days.first.tankCapacityLiters;
  double get kilometers => days.fold(0, (sum, day) => sum + day.kilometers);
  int get trips => days.fold(0, (sum, day) => sum + day.trips);
  int get mileageDays => days.where((d) => d.mileage != null).length;
  int get missingMileageDays => days.where((d) => d.missingMileage).length;
  PerformanceFuel get fuel =>
      days.fold(const PerformanceFuel(), (sum, day) => sum + day.fuel);
  LogisticsFuelCost get cost =>
      days.fold(const LogisticsFuelCost(), (sum, day) => sum + day.cost);
  double? get performance =>
      mileageDays == 0 ||
          missingMileageDays > 0 ||
          fuel.total <= 0 ||
          fuel.mixed
      ? null
      : kilometers / fuel.total;
  String get kilometerLabel => mileageDays == 0
      ? 'Sin kilometraje'
      : '${kilometers.toStringAsFixed(1)} km${missingMileageDays > 0 ? ' (parcial)' : ''}';
  String get performanceLabel => performance == null
      ? 'Sin estimación'
      : '${performance!.toStringAsFixed(2)} km/L';
  List<String> get warnings => [
    if (days.any((d) => d.loads.any((l) => l.litersEstimated)))
      'Incluye litros estimados',
    if (days.any((d) => d.vehicleId == null)) 'Unidad sin vincular',
    if (missingMileageDays > 0)
      'Falta kilometraje ($missingMileageDays ${missingMileageDays == 1 ? 'día' : 'días'})',
    if (fuel.total == 0 && (kilometers > 0 || trips > 0))
      'Sin carga registrada',
    if (!cost.isComplete) 'Falta precio',
    if (fuel.mixed) 'Combustibles mezclados',
  ];
  Set<String> get destinations => {
    for (final day in days)
      for (final service in day.services) service.company,
  };
}

List<PerformanceUnit> groupPerformanceUnits(Iterable<PerformanceDay> days) {
  final groups = <String, List<PerformanceDay>>{};
  for (final day in days) {
    (groups[day.vehicleKey] ??= []).add(day);
  }
  return groups.values.map(PerformanceUnit.new).toList()
    ..sort((a, b) => a.vehicleLabel.compareTo(b.vehicleLabel));
}

class LogisticsPerformanceData {
  static Future<List<PerformanceDay>> load() async {
    final client = Supabase.instance.client;
    final results = await Future.wait<dynamic>([
      LogisticsVehicleMileageStore.loadEntries(),
      LogisticsDieselConsumptionStore.loadEntries(),
      LogisticsGasolineControlStore.loadEntries(),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('vehicles')
            .select('id,code')
            .order('id')
            .range(from, to),
      ),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('services')
            .select(
              'id,service_date,due_date,vehicle_id,client_id,client_name,direction,status,driver_employee_id',
            )
            .eq('area', 'LOGISTICA')
            .eq('status', 'completado')
            .order('id')
            .range(from, to),
      ),
      fetchAllSupabaseRows(
        (from, to) =>
            client.from('sites').select('id,name').order('id').range(from, to),
      ),
      LogisticsVehicleProfileStore.loadTankCapacities(),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('employees')
            .select('id,full_name')
            .order('id')
            .range(from, to),
      ),
    ]);
    return consolidate(
      mileage: results[0] as List<LogisticsVehicleMileageRecord>,
      diesel: results[1] as List<LogisticsDieselConsumptionRecord>,
      gasoline: results[2] as List<LogisticsGasolineControlRecord>,
      vehicles: results[3] as List<Map<String, dynamic>>,
      services: results[4] as List<Map<String, dynamic>>,
      sites: results[5] as List<Map<String, dynamic>>,
      tanks: results[6] as Map<String, double?>,
      employees: results[7] as List<Map<String, dynamic>>,
    );
  }

  static List<PerformanceDay> consolidate({
    required List<LogisticsVehicleMileageRecord> mileage,
    required List<LogisticsDieselConsumptionRecord> diesel,
    required List<LogisticsGasolineControlRecord> gasoline,
    required List<Map<String, dynamic>> vehicles,
    required List<Map<String, dynamic>> services,
    required List<Map<String, dynamic>> sites,
    required Map<String, double?> tanks,
    required List<Map<String, dynamic>> employees,
  }) {
    final vehiclesById = {for (final v in vehicles) v['id'].toString(): v};
    final vehiclesByKey = {
      for (final v in vehicles) logisticsVehicleKey(_text(v['code'])): v,
    };
    final names = {for (final s in sites) s['id'].toString(): _text(s['name'])};
    final drivers = {
      for (final e in employees) e['id'].toString(): _text(e['full_name']),
    };
    final days = <String, PerformanceDay>{};

    PerformanceDay day(DateTime date, String? id, String label) {
      final vehicle =
          vehiclesById[id] ?? vehiclesByKey[logisticsVehicleKey(label)];
      final code = _text(vehicle?['code']);
      final display = code.isNotEmpty
          ? code
          : label.trim().isNotEmpty
          ? label.trim()
          : 'Sin unidad';
      final key = vehicle != null
          ? 'id:${vehicle['id']}'
          : 'label:${logisticsVehicleKey(display)}';
      final dateOnly = DateTime(date.year, date.month, date.day);
      return days.putIfAbsent(
        '${dateOnly.toIso8601String()}|$key',
        () => PerformanceDay(
          date: dateOnly,
          vehicleKey: key,
          vehicleLabel: display,
          vehicleId: vehicle?['id']?.toString(),
          tankCapacityLiters: tanks[vehicle?['id']],
        ),
      );
    }

    String driver(String? id, [String fallback = '']) {
      final name = drivers[id] ?? fallback.trim();
      return name.isEmpty ? 'Sin chofer registrado' : name;
    }

    for (final reading in mileage) {
      day(reading.entryDate, reading.vehicleId, reading.vehicleLabel).mileage =
          reading;
    }
    for (final load in diesel) {
      // Bulk tank purchases are not fuel loaded into a unit.
      if (load.litersRequested <= 0) continue;
      day(load.entryDate, load.vehicleId, load.vehicleLabel).loads.add(
        PerformanceLoad(
          id: load.id,
          vehicleId: load.vehicleId,
          vehicleLabel: load.vehicleLabel,
          diesel: true,
          liters: load.litersRequested,
          driver: driver(load.operatorEmployeeId, load.operatorName),
          origin: load.loadOrigin,
          litersEstimated: load.litersEstimated,
        ),
      );
    }
    for (final load in gasoline) {
      if (load.litersLoaded <= 0) continue;
      day(load.entryDate, load.vehicleId, load.vehicleLabel).loads.add(
        PerformanceLoad(
          id: load.id,
          vehicleId: load.vehicleId,
          vehicleLabel: load.vehicleLabel,
          diesel: false,
          liters: load.litersLoaded,
          driver: driver(load.operatorEmployeeId, load.operatorName),
          origin: load.loadOrigin,
          litersEstimated: load.litersEstimated,
        ),
      );
    }
    for (final service in services) {
      if (_text(service['status']).toLowerCase() != 'completado') continue;
      final date = DateTime.tryParse(
        _text(service['due_date'] ?? service['service_date']).split('T').first,
      );
      if (date == null) continue;
      final name = names[service['client_id']] ?? _text(service['client_name']);
      day(date, service['vehicle_id']?.toString(), '').services.add(
        PerformanceService(
          _text(service['id']),
          name.isEmpty ? 'Sin empresa' : name,
          _text(service['direction']) == 'entrega' ? 'Entrega' : 'Recolección',
          driver(service['driver_employee_id']?.toString()),
        ),
      );
    }
    return days.values.toList()..sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : a.vehicleLabel.compareTo(b.vehicleLabel);
    });
  }
}

String _text(dynamic value) => (value ?? '').toString().trim();
