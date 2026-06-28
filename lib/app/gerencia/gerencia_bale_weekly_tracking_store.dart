import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/app_error_reporter.dart';

const String _kGerenciaBaleTypeCatalogTable = 'gerencia_bale_type_catalog';
const String _kGerenciaBaleWeeklyPlansTable = 'gerencia_bale_weekly_plans';
const String _kGerenciaBaleWeeklyPlanLinesTable =
    'gerencia_bale_weekly_plan_lines';

class GerenciaBaleTypeRecord {
  final String key;
  final String label;
  final int sortOrder;
  final bool isActive;

  const GerenciaBaleTypeRecord({
    required this.key,
    required this.label,
    required this.sortOrder,
    required this.isActive,
  });

  factory GerenciaBaleTypeRecord.fromRow(Map<String, dynamic> row) {
    return GerenciaBaleTypeRecord(
      key: (row['key'] ?? '').toString(),
      label: (row['label'] ?? '').toString(),
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 100,
      isActive: (row['is_active'] as bool?) ?? true,
    );
  }
}

class GerenciaBaleWeeklyPlanLineRecord {
  final String id;
  final String baleTypeKey;
  final int sortOrder;
  final int productionTargetBales;
  final int shipmentTargetBales;
  final String notes;

  const GerenciaBaleWeeklyPlanLineRecord({
    required this.id,
    required this.baleTypeKey,
    required this.sortOrder,
    required this.productionTargetBales,
    required this.shipmentTargetBales,
    required this.notes,
  });

  factory GerenciaBaleWeeklyPlanLineRecord.fromRow(Map<String, dynamic> row) {
    return GerenciaBaleWeeklyPlanLineRecord(
      id: (row['id'] ?? '').toString(),
      baleTypeKey: (row['bale_type_key'] ?? '').toString(),
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 100,
      productionTargetBales:
          (row['production_target_bales'] as num?)?.toInt() ?? 0,
      shipmentTargetBales: (row['shipment_target_bales'] as num?)?.toInt() ?? 0,
      notes: ((row['notes'] ?? '') as String).trim(),
    );
  }

  GerenciaBaleWeeklyPlanLineRecord copyWith({
    int? productionTargetBales,
    int? shipmentTargetBales,
    String? notes,
  }) {
    return GerenciaBaleWeeklyPlanLineRecord(
      id: id,
      baleTypeKey: baleTypeKey,
      sortOrder: sortOrder,
      productionTargetBales:
          productionTargetBales ?? this.productionTargetBales,
      shipmentTargetBales: shipmentTargetBales ?? this.shipmentTargetBales,
      notes: notes ?? this.notes,
    );
  }
}

class GerenciaBaleWeeklyPlanRecord {
  final String id;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final String status;
  final String notes;
  final DateTime? closedAt;
  final List<GerenciaBaleWeeklyPlanLineRecord> lines;

  const GerenciaBaleWeeklyPlanRecord({
    required this.id,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.status,
    required this.notes,
    required this.closedAt,
    required this.lines,
  });

  factory GerenciaBaleWeeklyPlanRecord.fromRow(
    Map<String, dynamic> row, {
    required List<GerenciaBaleWeeklyPlanLineRecord> lines,
  }) {
    return GerenciaBaleWeeklyPlanRecord(
      id: (row['id'] ?? '').toString(),
      weekStartDate: _parseDate(row['week_start_date']),
      weekEndDate: _parseDate(row['week_end_date']),
      status: (row['status'] ?? 'planeada').toString(),
      notes: ((row['notes'] ?? '') as String).trim(),
      closedAt: _tryParseDateTime(row['closed_at'] as String?),
      lines: lines,
    );
  }

  int get totalProductionTarget =>
      lines.fold(0, (sum, line) => sum + line.productionTargetBales);

  int get totalShipmentTarget =>
      lines.fold(0, (sum, line) => sum + line.shipmentTargetBales);
}

class GerenciaBaleDailyActualRecord {
  final DateTime opDate;
  final int productionBales;
  final int shipmentBales;
  final int expectedProductionCumulativeBales;
  final int expectedShipmentCumulativeBales;
  final int actualProductionCumulativeBales;
  final int actualShipmentCumulativeBales;

  const GerenciaBaleDailyActualRecord({
    required this.opDate,
    required this.productionBales,
    required this.shipmentBales,
    required this.expectedProductionCumulativeBales,
    required this.expectedShipmentCumulativeBales,
    required this.actualProductionCumulativeBales,
    required this.actualShipmentCumulativeBales,
  });

  int get productionDeltaBales =>
      actualProductionCumulativeBales - expectedProductionCumulativeBales;

  int get shipmentDeltaBales =>
      actualShipmentCumulativeBales - expectedShipmentCumulativeBales;
}

class GerenciaBaleWeeklyLineSummary {
  final GerenciaBaleTypeRecord baleType;
  final GerenciaBaleWeeklyPlanLineRecord? planLine;
  final int productionActualBales;
  final int shipmentActualBales;
  final int productionEstimatedBales;
  final int shipmentEstimatedBales;
  final int productionNeedBales;
  final int shipmentNeedBales;
  final List<GerenciaBaleDailyActualRecord> dailyActuals;

  const GerenciaBaleWeeklyLineSummary({
    required this.baleType,
    required this.planLine,
    required this.productionActualBales,
    required this.shipmentActualBales,
    required this.productionEstimatedBales,
    required this.shipmentEstimatedBales,
    required this.productionNeedBales,
    required this.shipmentNeedBales,
    required this.dailyActuals,
  });

  int get productionTargetBales => planLine?.productionTargetBales ?? 0;
  int get shipmentTargetBales => planLine?.shipmentTargetBales ?? 0;

  double? get productionProgressRatio =>
      _safeRatio(productionActualBales, productionTargetBales);
  double? get shipmentProgressRatio =>
      _safeRatio(shipmentActualBales, shipmentTargetBales);
  double? get productionEstimatedRatio =>
      _safeRatio(productionEstimatedBales, productionTargetBales);
  double? get shipmentEstimatedRatio =>
      _safeRatio(shipmentEstimatedBales, shipmentTargetBales);
}

class GerenciaBaleWeeklyTrackingBundle {
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final List<GerenciaBaleTypeRecord> baleTypes;
  final GerenciaBaleWeeklyPlanRecord? currentPlan;
  final List<GerenciaBaleWeeklyLineSummary> lineSummaries;
  final List<String> unmappedProductionCodes;
  final List<String> unmappedShipmentCodes;

  const GerenciaBaleWeeklyTrackingBundle({
    required this.weekStartDate,
    required this.weekEndDate,
    required this.baleTypes,
    required this.currentPlan,
    required this.lineSummaries,
    required this.unmappedProductionCodes,
    required this.unmappedShipmentCodes,
  });

  bool get hasPlan => currentPlan != null;

  int get totalProductionActual =>
      lineSummaries.fold(0, (sum, line) => sum + line.productionActualBales);

  int get totalShipmentActual =>
      lineSummaries.fold(0, (sum, line) => sum + line.shipmentActualBales);

  int get totalProductionEstimated =>
      lineSummaries.fold(0, (sum, line) => sum + line.productionEstimatedBales);

  int get totalShipmentEstimated =>
      lineSummaries.fold(0, (sum, line) => sum + line.shipmentEstimatedBales);

  int get totalProductionNeed =>
      lineSummaries.fold(0, (sum, line) => sum + line.productionNeedBales);

  int get totalShipmentNeed =>
      lineSummaries.fold(0, (sum, line) => sum + line.shipmentNeedBales);
}

class GerenciaBaleWeeklyHistorySnapshot {
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final int productionActualBales;
  final int productionTargetBales;
  final int shipmentActualBales;
  final int shipmentTargetBales;

  const GerenciaBaleWeeklyHistorySnapshot({
    required this.weekStartDate,
    required this.weekEndDate,
    required this.productionActualBales,
    required this.productionTargetBales,
    required this.shipmentActualBales,
    required this.shipmentTargetBales,
  });

  double? get productionRatio =>
      _safeRatio(productionActualBales, productionTargetBales);

  double? get shipmentRatio =>
      _safeRatio(shipmentActualBales, shipmentTargetBales);
}

class GerenciaBaleWeeklyTrackingStore {
  static final SupabaseClient _supa = Supabase.instance.client;

  static Future<GerenciaBaleWeeklyTrackingBundle> loadCurrentWeek() async {
    final weekStartDate = _weekStartMonday(DateTime.now());
    return loadWeek(weekStartDate);
  }

  static Future<GerenciaBaleWeeklyTrackingBundle> loadWeek(
    DateTime weekStartDate,
  ) async {
    final normalizedWeekStart = _weekStartMonday(weekStartDate);
    final weekEndDate = normalizedWeekStart.add(const Duration(days: 5));
    try {
      final typeRows = await _supa
          .from(_kGerenciaBaleTypeCatalogTable)
          .select('key,label,sort_order,is_active')
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('label', ascending: true);
      final baleTypes = (typeRows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(GerenciaBaleTypeRecord.fromRow)
          .toList(growable: false);

      final planRow = await _supa
          .from(_kGerenciaBaleWeeklyPlansTable)
          .select('id,week_start_date,week_end_date,status,notes,closed_at')
          .eq('week_start_date', _fmtDate(normalizedWeekStart))
          .maybeSingle();

      GerenciaBaleWeeklyPlanRecord? currentPlan;
      if (planRow != null) {
        final lineRows = await _supa
            .from(_kGerenciaBaleWeeklyPlanLinesTable)
            .select(
              'id,bale_type_key,sort_order,production_target_bales,shipment_target_bales,notes',
            )
            .eq('plan_id', planRow['id'].toString())
            .order('sort_order', ascending: true)
            .order('bale_type_key', ascending: true);
        final lines = (lineRows as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(GerenciaBaleWeeklyPlanLineRecord.fromRow)
            .toList(growable: false);
        currentPlan = GerenciaBaleWeeklyPlanRecord.fromRow(
          planRow,
          lines: lines,
        );
      }

      final cartonGeneralRow = await _supa
          .from('material_general_catalog_v2')
          .select('id')
          .eq('code', 'CARTON')
          .maybeSingle();

      final transformationRows = cartonGeneralRow == null
          ? const <dynamic>[]
          : await _supa
                .from('material_transformation_runs_v2')
                .select(
                  'op_date,'
                  'outputs:material_transformation_run_outputs_v2('
                  'output_unit_count,'
                  'commercial_material:commercial_material_id(code,name)'
                  ')',
                )
                .eq('source_general_material_id', cartonGeneralRow['id'])
                .gte('op_date', _fmtDate(normalizedWeekStart))
                .lte('op_date', _fmtDate(weekEndDate));

      final legacyProductionRows = await _supa
          .from('production_runs')
          .select('op_date,bale_material,bale_count')
          .gte('op_date', _fmtDate(normalizedWeekStart))
          .lte('op_date', _fmtDate(weekEndDate));

      final shipmentRows = await _supa
          .from('inventory_movements_v2')
          .select(
            'op_date,unit_count,commercial_material:commercial_material_id(code,name)',
          )
          .eq('flow', 'OUT')
          .eq('inventory_level', 'COMMERCIAL')
          .gte('op_date', _fmtDate(normalizedWeekStart))
          .lte('op_date', _fmtDate(weekEndDate));

      final productionByType = <String, int>{};
      final shipmentByType = <String, int>{};
      final dailyProductionByType = <String, Map<DateTime, int>>{};
      final dailyShipmentByType = <String, Map<DateTime, int>>{};
      final unmappedProductionCodes = <String>{};
      final unmappedShipmentCodes = <String>{};

      for (final raw in transformationRows.cast<Map<String, dynamic>>()) {
        final outputs = (raw['outputs'] as List? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();
        for (final output in outputs) {
          final commercial = (output['commercial_material'] as Map?)
              ?.cast<String, dynamic>();
          final rawCode = (commercial?['code'] ?? '').toString();
          final typeKey = _mapExecutiveBaleTypeKey(rawCode);
          final count = (output['output_unit_count'] as num?)?.toInt() ?? 0;
          if (count <= 0) {
            continue;
          }
          if (typeKey == null) {
            if (rawCode.trim().isNotEmpty) {
              unmappedProductionCodes.add(rawCode.trim());
            }
            continue;
          }
          final opDate = _parseDate(raw['op_date']);
          productionByType.update(
            typeKey,
            (value) => value + count,
            ifAbsent: () => count,
          );
          final bucket = dailyProductionByType.putIfAbsent(
            typeKey,
            () => <DateTime, int>{},
          );
          bucket.update(
            opDate,
            (value) => value + count,
            ifAbsent: () => count,
          );
        }
      }

      for (final row
          in (legacyProductionRows as List<dynamic>)
              .cast<Map<String, dynamic>>()) {
        final typeKey = _mapExecutiveBaleTypeKey(
          row['bale_material']?.toString(),
        );
        final count = (row['bale_count'] as num?)?.toInt() ?? 0;
        if (count <= 0) continue;
        if (typeKey == null) {
          final raw = (row['bale_material'] ?? '').toString().trim();
          if (raw.isNotEmpty) unmappedProductionCodes.add(raw);
          continue;
        }
        final opDate = _parseDate(row['op_date']);
        productionByType.update(
          typeKey,
          (value) => value + count,
          ifAbsent: () => count,
        );
        final bucket = dailyProductionByType.putIfAbsent(
          typeKey,
          () => <DateTime, int>{},
        );
        bucket.update(opDate, (value) => value + count, ifAbsent: () => count);
      }

      for (final row
          in (shipmentRows as List<dynamic>).cast<Map<String, dynamic>>()) {
        final commercial = (row['commercial_material'] as Map?)
            ?.cast<String, dynamic>();
        final rawCode = (commercial?['code'] ?? '').toString();
        final typeKey = _mapExecutiveBaleTypeKey(rawCode);
        final count = (row['unit_count'] as num?)?.toInt() ?? 0;
        if (count <= 0) continue;
        if (typeKey == null) {
          if (rawCode.trim().isNotEmpty) {
            unmappedShipmentCodes.add(rawCode.trim());
          }
          continue;
        }
        final opDate = _parseDate(row['op_date']);
        shipmentByType.update(
          typeKey,
          (value) => value + count,
          ifAbsent: () => count,
        );
        final bucket = dailyShipmentByType.putIfAbsent(
          typeKey,
          () => <DateTime, int>{},
        );
        bucket.update(opDate, (value) => value + count, ifAbsent: () => count);
      }

      final effectiveEnd = _effectiveWeekProgressEnd(
        normalizedWeekStart,
        weekEndDate,
      );
      final daysElapsed = effectiveEnd.isBefore(normalizedWeekStart)
          ? 0
          : effectiveEnd.difference(normalizedWeekStart).inDays + 1;
      final totalWeekDays =
          weekEndDate.difference(normalizedWeekStart).inDays + 1;
      final linesByTypeKey = <String, GerenciaBaleWeeklyPlanLineRecord>{
        for (final line
            in currentPlan?.lines ?? const <GerenciaBaleWeeklyPlanLineRecord>[])
          line.baleTypeKey: line,
      };

      final lineSummaries = <GerenciaBaleWeeklyLineSummary>[
        for (final type in baleTypes)
          () {
            final productionActual = productionByType[type.key] ?? 0;
            final shipmentActual = shipmentByType[type.key] ?? 0;
            final productionEstimated = _projectWeeklyCount(
              actualCount: productionActual,
              daysElapsed: daysElapsed,
              totalWeekDays: totalWeekDays,
            );
            final shipmentEstimated = _projectWeeklyCount(
              actualCount: shipmentActual,
              daysElapsed: daysElapsed,
              totalWeekDays: totalWeekDays,
            );
            final planLine = linesByTypeKey[type.key];
            var productionRunningActual = 0;
            var shipmentRunningActual = 0;
            final dailyActuals = <GerenciaBaleDailyActualRecord>[
              for (
                var day = normalizedWeekStart;
                !day.isAfter(weekEndDate);
                day = day.add(const Duration(days: 1))
              ) ...[
                () {
                  final productionDay =
                      dailyProductionByType[type.key]?[day] ?? 0;
                  final shipmentDay = dailyShipmentByType[type.key]?[day] ?? 0;
                  productionRunningActual += productionDay;
                  shipmentRunningActual += shipmentDay;
                  final dayIndex =
                      day.difference(normalizedWeekStart).inDays + 1;
                  return GerenciaBaleDailyActualRecord(
                    opDate: day,
                    productionBales: productionDay,
                    shipmentBales: shipmentDay,
                    expectedProductionCumulativeBales: _expectedCumulativeCount(
                      target: planLine?.productionTargetBales ?? 0,
                      dayIndex: dayIndex,
                      totalWeekDays: totalWeekDays,
                    ),
                    expectedShipmentCumulativeBales: _expectedCumulativeCount(
                      target: planLine?.shipmentTargetBales ?? 0,
                      dayIndex: dayIndex,
                      totalWeekDays: totalWeekDays,
                    ),
                    actualProductionCumulativeBales: productionRunningActual,
                    actualShipmentCumulativeBales: shipmentRunningActual,
                  );
                }(),
              ],
            ];
            return GerenciaBaleWeeklyLineSummary(
              baleType: type,
              planLine: planLine,
              productionActualBales: productionActual,
              shipmentActualBales: shipmentActual,
              productionEstimatedBales: productionEstimated,
              shipmentEstimatedBales: shipmentEstimated,
              productionNeedBales: _needCount(
                target: planLine?.productionTargetBales ?? 0,
                actual: productionActual,
              ),
              shipmentNeedBales: _needCount(
                target: planLine?.shipmentTargetBales ?? 0,
                actual: shipmentActual,
              ),
              dailyActuals: dailyActuals,
            );
          }(),
      ];

      return GerenciaBaleWeeklyTrackingBundle(
        weekStartDate: normalizedWeekStart,
        weekEndDate: weekEndDate,
        baleTypes: baleTypes,
        currentPlan: currentPlan,
        lineSummaries: lineSummaries,
        unmappedProductionCodes: unmappedProductionCodes.toList()..sort(),
        unmappedShipmentCodes: unmappedShipmentCodes.toList()..sort(),
      );
    } catch (e, st) {
      AppErrorReporter.report(
        e,
        st,
        fallbackMessage:
            'No se pudo cargar el seguimiento semanal de pacas de Gerencia.',
      );
      rethrow;
    }
  }

  static Future<List<GerenciaBaleWeeklyHistorySnapshot>> loadRecentHistory({
    int limit = 6,
  }) async {
    try {
      final planRows = await _supa
          .from(_kGerenciaBaleWeeklyPlansTable)
          .select('week_start_date,week_end_date')
          .order('week_start_date', ascending: false)
          .limit(limit);
      final snapshots = <GerenciaBaleWeeklyHistorySnapshot>[];
      for (final row
          in (planRows as List<dynamic>).cast<Map<String, dynamic>>()) {
        final bundle = await loadWeek(_parseDate(row['week_start_date']));
        snapshots.add(
          GerenciaBaleWeeklyHistorySnapshot(
            weekStartDate: bundle.weekStartDate,
            weekEndDate: bundle.weekEndDate,
            productionActualBales: bundle.totalProductionActual,
            productionTargetBales:
                bundle.currentPlan?.totalProductionTarget ?? 0,
            shipmentActualBales: bundle.totalShipmentActual,
            shipmentTargetBales: bundle.currentPlan?.totalShipmentTarget ?? 0,
          ),
        );
      }
      snapshots.sort((a, b) => a.weekStartDate.compareTo(b.weekStartDate));
      return snapshots;
    } catch (e, st) {
      AppErrorReporter.report(
        e,
        st,
        fallbackMessage:
            'No se pudo cargar el histórico del seguimiento semanal de Gerencia.',
      );
      rethrow;
    }
  }

  static Future<void> createCurrentWeekPlan({
    required DateTime weekStartDate,
    required DateTime weekEndDate,
    required List<GerenciaBaleTypeRecord> baleTypes,
  }) async {
    try {
      final insertedPlan = await _supa
          .from(_kGerenciaBaleWeeklyPlansTable)
          .insert({
            'week_start_date': _fmtDate(weekStartDate),
            'week_end_date': _fmtDate(weekEndDate),
            'status': 'planeada',
          })
          .select('id')
          .single();
      final planId = insertedPlan['id'].toString();
      final linePayload = [
        for (final type in baleTypes)
          {
            'plan_id': planId,
            'bale_type_key': type.key,
            'sort_order': type.sortOrder,
            'production_target_bales': 0,
            'shipment_target_bales': 0,
          },
      ];
      if (linePayload.isNotEmpty) {
        await _supa
            .from(_kGerenciaBaleWeeklyPlanLinesTable)
            .insert(linePayload);
      }
    } catch (e, st) {
      AppErrorReporter.report(
        e,
        st,
        fallbackMessage: 'No se pudo crear el plan semanal de Gerencia.',
      );
      rethrow;
    }
  }

  static Future<void> updatePlanLine(
    GerenciaBaleWeeklyPlanLineRecord line, {
    required int productionTargetBales,
    required int shipmentTargetBales,
    required String notes,
  }) async {
    try {
      await _supa
          .from(_kGerenciaBaleWeeklyPlanLinesTable)
          .update({
            'production_target_bales': productionTargetBales,
            'shipment_target_bales': shipmentTargetBales,
            'notes': notes.trim().isEmpty ? null : notes.trim(),
          })
          .eq('id', line.id);
    } catch (e, st) {
      AppErrorReporter.report(
        e,
        st,
        fallbackMessage: 'No se pudo actualizar la meta semanal de Gerencia.',
      );
      rethrow;
    }
  }
}

DateTime _weekStartMonday(DateTime dateTime) {
  final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

String _fmtDate(DateTime dateTime) {
  final year = dateTime.year.toString().padLeft(4, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime _parseDate(dynamic value) {
  final raw = (value ?? '').toString();
  if (raw.length >= 10) {
    final year = int.tryParse(raw.substring(0, 4));
    final month = int.tryParse(raw.substring(5, 7));
    final day = int.tryParse(raw.substring(8, 10));
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

String? _mapExecutiveBaleTypeKey(String? rawCode) {
  final code = (rawCode ?? '').trim().toUpperCase();
  switch (code) {
    case 'PACA_LIMPIA':
    case 'BALE_CLEAN':
    case 'LIMPIO':
      return 'limpio';
    case 'PACA_NACIONAL':
    case 'BALE_NATIONAL':
    case 'PACA_BASURA':
    case 'BALE_TRASH':
    case 'NACIONAL':
    case 'REVUELTO':
    case 'BASURA':
      return 'revuelto';
    case 'PACA_AMERICANA':
    case 'BALE_AMERICAN':
    case 'AMERICANO':
      return 'americano';
    default:
      return null;
  }
}

DateTime _effectiveWeekProgressEnd(
  DateTime weekStartDate,
  DateTime weekEndDate,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (today.isBefore(weekStartDate)) {
    return weekStartDate.subtract(const Duration(days: 1));
  }
  if (today.isAfter(weekEndDate)) {
    return weekEndDate;
  }
  return today;
}

int _projectWeeklyCount({
  required int actualCount,
  required int daysElapsed,
  required int totalWeekDays,
}) {
  if (actualCount <= 0 || daysElapsed <= 0 || totalWeekDays <= 0) {
    return actualCount;
  }
  return ((actualCount / daysElapsed) * totalWeekDays).round();
}

int _needCount({required int target, required int actual}) {
  final diff = target - actual;
  return diff > 0 ? diff : 0;
}

int _expectedCumulativeCount({
  required int target,
  required int dayIndex,
  required int totalWeekDays,
}) {
  if (target <= 0 || dayIndex <= 0 || totalWeekDays <= 0) {
    return 0;
  }
  final boundedDayIndex = dayIndex > totalWeekDays ? totalWeekDays : dayIndex;
  return ((target / totalWeekDays) * boundedDayIndex).round();
}

double? _safeRatio(int numerator, int denominator) {
  if (denominator <= 0) return null;
  return numerator / denominator;
}
