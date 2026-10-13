import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/utils/fetch_all_supabase_rows.dart';
import 'logistics_operations_store.dart';
import 'logistics_performance_store.dart';

enum LogisticsDashboardModule {
  daily,
  units,
  incidents,
  diesel,
  gasoline,
  performance,
  savings,
  catalogs,
}

class LogisticsDashboardSummary {
  final String value, label, period, note;
  final List<(String, String)> details;
  final bool attention;
  final String? error;

  const LogisticsDashboardSummary({
    required this.value,
    required this.label,
    required this.period,
    this.details = const [],
    this.note = '',
    this.attention = false,
    this.error,
  });
}

typedef LogisticsDashboardRows = Map<String, List<Map<String, dynamic>>>;

class LogisticsDashboardSnapshot {
  final DateTime loadedAt;
  final Map<LogisticsDashboardModule, LogisticsDashboardSummary> summaries;
  const LogisticsDashboardSnapshot(this.loadedAt, this.summaries);

  factory LogisticsDashboardSnapshot.fromRows({
    required DateTime now,
    required LogisticsDashboardRows rows,
    Set<String> failedSources = const {},
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final week = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = week.add(const Duration(days: 7));
    final planningEnd = today.add(const Duration(days: 7));
    final weekLabel =
        '${_short(week)}–${_short(weekEnd.subtract(const Duration(days: 1)))}';
    List<Map<String, dynamic>> source(String table) => rows[table] ?? const [];
    final summaries = <LogisticsDashboardModule, LogisticsDashboardSummary>{};
    void add(
      LogisticsDashboardModule module,
      List<String> sources,
      LogisticsDashboardSummary Function() build,
    ) {
      summaries[module] = sources.any(failedSources.contains)
          ? const LogisticsDashboardSummary(
              value: '—',
              label: 'Datos no disponibles',
              period: '',
              error:
                  'No se pudo actualizar este resumen. Se reintentará automáticamente.',
            )
          : build();
    }

    final services = source('services');
    final vehicles = source(
      'vehicles',
    ).where((r) => _key(r['status']) == 'ACTIVO').toList();
    final diesel = source(
      'logistics_diesel_consumption',
    ).where((r) => _within(r['entry_date'], week, weekEnd)).toList();
    final gasoline = source(
      'logistics_gasoline_control',
    ).where((r) => _within(r['entry_date'], week, weekEnd)).toList();
    final companies = source(
      'sites',
    ).where((r) => r['is_active'] != false && r['type'] == 'cliente').toList();

    add(LogisticsDashboardModule.daily, ['services'], () {
      final daily = services.where((r) => _serviceDate(r) == today).toList();
      final pending = daily.where(_open).toList();
      final unassigned = pending
          .where(
            (r) =>
                _text(r['vehicle_id']).isEmpty ||
                _text(r['driver_employee_id']).isEmpty,
          )
          .length;
      return LogisticsDashboardSummary(
        value: '${pending.length}',
        label: 'servicios pendientes',
        period: 'Hoy · ${_short(today)}',
        details: [
          (
            'Programados',
            '${daily.where((r) => _key(r['status']) != 'CANCELADO').length}',
          ),
          (
            'Completados',
            '${daily.where((r) => _key(r['status']) == 'COMPLETADO').length}',
          ),
          ('Sin chofer o unidad', '$unassigned'),
        ],
        attention: unassigned > 0,
        note: daily.isEmpty ? 'Sin servicios para hoy' : '',
      );
    });
    add(
      LogisticsDashboardModule.units,
      ['vehicles', 'logistics_unit_states'],
      () {
        final states = {
          for (final r in source('logistics_unit_states'))
            _text(r['vehicle_id']): LogisticsManualUnitState.fromRow(r),
        };
        final available = vehicles
            .where((r) => states[_text(r['id'])]?.status == 'DISPONIBLE')
            .length;
        final warnings = vehicles
            .where((r) => states[_text(r['id'])]?.warning == true)
            .length;
        final missing = vehicles
            .where((r) => !states.containsKey(_text(r['id'])))
            .length;
        return LogisticsDashboardSummary(
          value: '$available',
          label: 'unidades disponibles',
          period: 'Estado manual actual',
          details: [
            ('Unidades activas', '${vehicles.length}'),
            ('Con advertencia', '$warnings'),
            ('Sin estado capturado', '$missing'),
          ],
          attention: warnings > 0 || missing > 0,
          note: 'Las advertencias no bloquean asignaciones',
        );
      },
    );
    add(LogisticsDashboardModule.incidents, ['logistics_trip_incidents'], () {
      final open = source(
        'logistics_trip_incidents',
      ).where((r) => _key(r['resolution_status']) != 'RESUELTA').toList();
      final high = open.where((r) => _key(r['impact_level']) == 'ALTA').length;
      return LogisticsDashboardSummary(
        value: '${open.length}',
        label: 'incidencias por resolver',
        period: 'Pendientes actuales',
        details: [
          (
            'Abiertas',
            '${open.where((r) => _key(r['resolution_status']) == 'ABIERTA').length}',
          ),
          (
            'En seguimiento',
            '${open.where((r) => _key(r['resolution_status']) == 'EN_SEGUIMIENTO').length}',
          ),
          ('Impacto alto', '$high'),
        ],
        attention: open.isNotEmpty,
        note: open.isEmpty ? 'Sin incidencias pendientes' : '',
      );
    });
    add(
      LogisticsDashboardModule.diesel,
      ['logistics_diesel_consumption', 'diesel_latest'],
      () {
        final latest = source('diesel_latest');
        final balance = latest.isEmpty
            ? null
            : _number(latest.first['balance_liters']);
        return LogisticsDashboardSummary(
          value: balance == null ? '—' : '${_numberText(balance)} L',
          label: 'saldo del tanque',
          period: 'Semana · $weekLabel',
          details: [
            (
              'Comprados en la semana',
              '${_numberText(_sum(diesel, 'liters_purchased'))} L',
            ),
            (
              'Solicitados en la semana',
              '${_numberText(_sum(diesel, 'liters_requested'))} L',
            ),
            (
              'Estado del tanque',
              balance == null
                  ? 'Sin lectura'
                  : balance > 600
                  ? 'Suficiente'
                  : balance >= 300
                  ? 'Solicitar'
                  : 'Crítico',
            ),
          ],
          attention: balance != null && balance <= 600,
          note: latest.isEmpty
              ? 'Sin movimientos registrados'
              : 'Saldo al ${_short(_date(latest.first['entry_date'])!)}',
        );
      },
    );
    add(LogisticsDashboardModule.gasoline, ['logistics_gasoline_control'], () {
      final loads = gasoline
          .where((r) => _number(r['liters_loaded']) > 0)
          .toList();
      return LogisticsDashboardSummary(
        value: '${_numberText(_sum(loads, 'liters_loaded'))} L',
        label: 'gasolina cargada',
        period: 'Semana · $weekLabel',
        details: [
          ('Cargas registradas', '${loads.length}'),
          (
            'Unidades con carga',
            '${loads.map(_fuelVehicle).where((v) => v.isNotEmpty).toSet().length}',
          ),
          (
            'Sin unidad vinculada',
            '${loads.where((r) => _fuelVehicle(r).isEmpty).length}',
          ),
        ],
        note: loads.isEmpty ? 'Sin cargas esta semana' : '',
      );
    });
    add(
      LogisticsDashboardModule.performance,
      [
        'logistics_vehicle_mileage',
        'logistics_diesel_consumption',
        'logistics_gasoline_control',
        'vehicles',
      ],
      () {
        final mileage = source(
          'logistics_vehicle_mileage',
        ).where((r) => _within(r['entry_date'], week, weekEnd)).toList();
        final keys = {
          for (final v in source('vehicles'))
            _text(v['id']): logisticsVehicleKey(_text(v['code'])),
        };
        final fuel = <String, double>{};
        void addFuel(Map<String, dynamic> r, String field) {
          final key =
              keys[_text(r['vehicle_id'])] ??
              logisticsVehicleKey(_text(r['vehicle_label']));
          if (key.isEmpty) return;
          final bucket = '${_db(_date(r['entry_date'])!)}|$key';
          fuel[bucket] = (fuel[bucket] ?? 0) + _number(r[field]);
        }

        for (final r in diesel) {
          addFuel(r, 'liters_requested');
        }
        for (final r in gasoline) {
          addFuel(r, 'liters_loaded');
        }
        double pairedKm = 0, pairedLiters = 0;
        var missing = 0;
        for (final r in mileage) {
          final bucket = '${_db(_date(r['entry_date'])!)}|${r['vehicle_key']}';
          final liters = fuel[bucket] ?? 0;
          if (liters <= 0) {
            missing++;
            continue;
          }
          pairedKm += _number(r['kilometers']);
          pairedLiters += liters;
        }
        return LogisticsDashboardSummary(
          value: '${_numberText(_sum(mileage, 'kilometers'))} km',
          label: 'kilometraje registrado',
          period: 'Semana · $weekLabel',
          details: [
            (
              'Unidades con lectura',
              '${mileage.map((r) => _text(r['vehicle_key'])).where((s) => s.isNotEmpty).toSet().length}',
            ),
            (
              'Rendimiento con carga',
              pairedLiters > 0
                  ? '${(pairedKm / pairedLiters).toStringAsFixed(2)} km/L'
                  : 'Sin datos',
            ),
            ('Lecturas sin carga vinculada', '$missing'),
          ],
          note: 'km/L: misma unidad y día con carga',
        );
      },
    );
    add(
      LogisticsDashboardModule.savings,
      ['services', 'sites', 'logistics_company_profiles', 'logistics_zones'],
      () {
        final next = services.where((r) {
          final date = _serviceDate(r);
          return _open(r) &&
              date != null &&
              !date.isBefore(today) &&
              date.isBefore(planningEnd);
        }).toList();
        final byId = {for (final c in companies) _text(c['id']): c};
        final byName = {for (final c in companies) _key(c['name']): c};
        final profiles = {
          for (final p in source('logistics_company_profiles'))
            _text(p['site_id']): p,
        };
        final zones = source('logistics_zones')
            .where((r) => r['is_active'] != false)
            .map((r) => _text(r['id']))
            .toSet();
        final groups = <String, int>{};
        final unzoned = <String>{};
        for (final r in next) {
          final company =
              byId[_text(r['client_id'])] ?? byName[_key(r['client_name'])];
          final id = company == null
              ? _text(r['client_id'])
              : _text(company['id']);
          final zone = _text(profiles[id]?['zone_id']);
          if (!zones.contains(zone)) {
            unzoned.add(
              id.isNotEmpty
                  ? id
                  : _key(r['client_name']).isEmpty
                  ? 'servicio:${r['id']}'
                  : _key(r['client_name']),
            );
          } else {
            final key = '${_db(_serviceDate(r)!)}|$zone';
            groups[key] = (groups[key] ?? 0) + 1;
          }
        }
        return LogisticsDashboardSummary(
          value: '${next.length}',
          label: 'servicios próximos',
          period:
              '${_short(today)}–${_short(planningEnd.subtract(const Duration(days: 1)))} · 7 días',
          details: [
            (
              'Grupos para combinar rutas',
              '${groups.values.where((n) => n > 1).length}',
            ),
            ('Empresas por zonificar', '${unzoned.length}'),
            ('Zonas activas', '${zones.length}'),
          ],
          note: 'Agrupación sugerida por zona y fecha',
          attention: unzoned.isNotEmpty,
        );
      },
    );
    add(
      LogisticsDashboardModule.catalogs,
      ['sites', 'employees', 'vehicles', 'logistics_containers'],
      () {
        final drivers = source('employees')
            .where((r) => r['is_active'] != false && r['is_driver'] == true)
            .length;
        return LogisticsDashboardSummary(
          value: '$drivers',
          label: 'choferes activos',
          period: 'Catálogos actuales',
          details: [
            ('Empresas activas', '${companies.length}'),
            ('Unidades activas', '${vehicles.length}'),
            (
              'Contenedores activos',
              '${source('logistics_containers').where((r) => r['is_active'] != false).length}',
            ),
          ],
        );
      },
    );
    return LogisticsDashboardSnapshot(now, summaries);
  }
}

/// Reads only the columns needed for summaries. Never synchronizes or writes
/// catalogs; pagination and per-source errors keep totals complete and honest.
class LogisticsDashboardStore {
  static Future<LogisticsDashboardSnapshot> load({
    SupabaseClient? client,
    DateTime? now,
  }) async {
    final db = client ?? Supabase.instance.client;
    final stamp = now ?? DateTime.now();
    final today = DateTime(stamp.year, stamp.month, stamp.day);
    final week = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = week.add(const Duration(days: 7));
    final end = today.add(const Duration(days: 7));
    final rows = <String, List<Map<String, dynamic>>>{};
    final failures = <String>{};
    Future<void> read(
      String key,
      Future<List<Map<String, dynamic>>> Function() fetch,
    ) async {
      try {
        rows[key] = await fetch().timeout(const Duration(seconds: 20));
      } catch (_) {
        failures.add(key);
      }
    }

    Future<List<Map<String, dynamic>>> all(String table, String columns) =>
        fetchAllSupabaseRows(
          (from, to) =>
              db.from(table).select(columns).order('id').range(from, to),
        );
    Future<List<Map<String, dynamic>>> weekly(String table, String columns) =>
        fetchAllSupabaseRows(
          (from, to) => db
              .from(table)
              .select(columns)
              .gte('entry_date', _db(week))
              .lt('entry_date', _db(weekEnd))
              .order('id')
              .range(from, to),
        );
    await Future.wait([
      read(
        'services',
        () => fetchAllSupabaseRows(
          (from, to) => db
              .from('services')
              .select(
                'id,service_date,due_date,status,vehicle_id,driver_employee_id,client_id,client_name',
              )
              .or(
                'and(due_date.gte.${_db(today)},due_date.lt.${_db(end)}),and(due_date.is.null,service_date.gte.${_db(today)},service_date.lt.${_db(end)})',
              )
              .order('id')
              .range(from, to),
        ),
      ),
      read('vehicles', () => all('vehicles', 'id,code,status')),
      read(
        'logistics_unit_states',
        () => fetchAllSupabaseRows(
          (from, to) => db
              .from('logistics_unit_states')
              .select('vehicle_id,operational_status')
              .order('vehicle_id')
              .range(from, to),
        ),
      ),
      read(
        'logistics_trip_incidents',
        () => fetchAllSupabaseRows(
          (from, to) => db
              .from('logistics_trip_incidents')
              .select('id,resolution_status,impact_level')
              .neq('resolution_status', 'RESUELTA')
              .order('id')
              .range(from, to),
        ),
      ),
      read(
        'logistics_diesel_consumption',
        () => weekly(
          'logistics_diesel_consumption',
          'id,entry_date,vehicle_id,vehicle_label,liters_purchased,liters_requested',
        ),
      ),
      read(
        'diesel_latest',
        () => db
            .from('logistics_diesel_consumption')
            .select('entry_date,balance_liters')
            .order('entry_date', ascending: false)
            .order('created_at', ascending: false)
            .order('id')
            .limit(1),
      ),
      read(
        'logistics_gasoline_control',
        () => weekly(
          'logistics_gasoline_control',
          'id,entry_date,vehicle_id,vehicle_label,liters_loaded',
        ),
      ),
      read(
        'logistics_vehicle_mileage',
        () => weekly(
          'logistics_vehicle_mileage',
          'id,entry_date,vehicle_key,kilometers',
        ),
      ),
      read('sites', () => all('sites', 'id,name,type,is_active')),
      read(
        'employees',
        () => fetchAllSupabaseRows(
          (from, to) => db
              .from('employees')
              .select('id,is_active,is_driver')
              .eq('is_driver', true)
              .order('id')
              .range(from, to),
        ),
      ),
      read(
        'logistics_containers',
        () => all('logistics_containers', 'id,is_active'),
      ),
      read(
        'logistics_company_profiles',
        () => fetchAllSupabaseRows(
          (from, to) => db
              .from('logistics_company_profiles')
              .select('site_id,zone_id')
              .order('site_id')
              .range(from, to),
        ),
      ),
      read('logistics_zones', () => all('logistics_zones', 'id,is_active')),
    ]);
    return LogisticsDashboardSnapshot.fromRows(
      now: stamp,
      rows: rows,
      failedSources: failures,
    );
  }
}

String _text(Object? value) => (value ?? '').toString().trim();
String _key(Object? value) => _text(value).toUpperCase();
double _number(Object? value) => double.tryParse(_text(value)) ?? 0;
double _sum(Iterable<Map<String, dynamic>> rows, String field) =>
    rows.fold(0, (sum, r) => sum + _number(r[field]));
String _numberText(num value) {
  final parts = value.toStringAsFixed(2).split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final decimals = parts.last.replaceFirst(RegExp(r'0+$'), '');
  return decimals.isEmpty ? whole : '$whole.$decimals';
}

DateTime? _date(Object? value) =>
    DateTime.tryParse(_text(value).split('T').first);
DateTime? _serviceDate(Map<String, dynamic> r) =>
    _date(r['due_date']) ?? _date(r['service_date']);
bool _open(Map<String, dynamic> r) =>
    !['COMPLETADO', 'CANCELADO'].contains(_key(r['status']));
bool _within(Object? value, DateTime start, DateTime end) {
  final date = _date(value);
  return date != null && !date.isBefore(start) && date.isBefore(end);
}

String _db(DateTime date) => date.toIso8601String().substring(0, 10);
String _short(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
String _fuelVehicle(Map<String, dynamic> r) => _text(r['vehicle_id']).isNotEmpty
    ? 'id:${r['vehicle_id']}'
    : logisticsVehicleKey(_text(r['vehicle_label']));
