import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../maintenance/maintenance_statuses.dart';
import '../shared/app_error_reporter.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';

const String _kDirectionShipmentPlansTable = 'direction_shipment_plans';
const String _kDirectionCapacityImpactsTable =
    'direction_production_capacity_impacts';

enum DirectionShipmentMaterialScope { commercial, general }

enum DirectionShipmentQuantityUnit { bales, kilograms }

class DirectionShipmentMaterialOption {
  final String code;
  final String label;
  final DirectionShipmentMaterialScope scope;
  final DirectionShipmentQuantityUnit quantityUnit;
  final int sortOrder;

  const DirectionShipmentMaterialOption({
    required this.code,
    required this.label,
    required this.scope,
    required this.quantityUnit,
    required this.sortOrder,
  });

  bool get isBulk => quantityUnit == DirectionShipmentQuantityUnit.kilograms;

  bool get isPacked => !isBulk;

  String get scopeLabel => isBulk ? 'Granel' : 'Empacado';

  String get quantityLabel => isBulk ? 'Kg' : 'Pacas';

  String get shortUnitLabel => isBulk ? 'kg' : 'pacas';

  String get sourceKind => scope == DirectionShipmentMaterialScope.general
      ? 'operational_material'
      : 'commercial_material';
}

const List<DirectionShipmentMaterialOption> kDirectionShipmentMaterials =
    <DirectionShipmentMaterialOption>[
      DirectionShipmentMaterialOption(
        code: 'PACA_NACIONAL',
        label: 'Paca nacional',
        scope: DirectionShipmentMaterialScope.commercial,
        quantityUnit: DirectionShipmentQuantityUnit.bales,
        sortOrder: 10,
      ),
      DirectionShipmentMaterialOption(
        code: 'PACA_AMERICANA',
        label: 'Paca americana',
        scope: DirectionShipmentMaterialScope.commercial,
        quantityUnit: DirectionShipmentQuantityUnit.bales,
        sortOrder: 20,
      ),
      DirectionShipmentMaterialOption(
        code: 'PACA_LIMPIA',
        label: 'Paca limpia',
        scope: DirectionShipmentMaterialScope.commercial,
        quantityUnit: DirectionShipmentQuantityUnit.bales,
        sortOrder: 30,
      ),
      DirectionShipmentMaterialOption(
        code: 'PACA_BASURA',
        label: 'Paca basura',
        scope: DirectionShipmentMaterialScope.commercial,
        quantityUnit: DirectionShipmentQuantityUnit.bales,
        sortOrder: 40,
      ),
      DirectionShipmentMaterialOption(
        code: 'CAPLE',
        label: 'Caple',
        scope: DirectionShipmentMaterialScope.commercial,
        quantityUnit: DirectionShipmentQuantityUnit.bales,
        sortOrder: 50,
      ),
      DirectionShipmentMaterialOption(
        code: 'CHATARRA',
        label: 'Chatarra',
        scope: DirectionShipmentMaterialScope.general,
        quantityUnit: DirectionShipmentQuantityUnit.kilograms,
        sortOrder: 60,
      ),
      DirectionShipmentMaterialOption(
        code: 'METAL',
        label: 'Metal',
        scope: DirectionShipmentMaterialScope.general,
        quantityUnit: DirectionShipmentQuantityUnit.kilograms,
        sortOrder: 70,
      ),
      DirectionShipmentMaterialOption(
        code: 'PAPEL',
        label: 'Papel',
        scope: DirectionShipmentMaterialScope.general,
        quantityUnit: DirectionShipmentQuantityUnit.kilograms,
        sortOrder: 80,
      ),
      DirectionShipmentMaterialOption(
        code: 'PLASTICO',
        label: 'Plástico',
        scope: DirectionShipmentMaterialScope.general,
        quantityUnit: DirectionShipmentQuantityUnit.kilograms,
        sortOrder: 90,
      ),
      DirectionShipmentMaterialOption(
        code: 'MADERA',
        label: 'Madera',
        scope: DirectionShipmentMaterialScope.general,
        quantityUnit: DirectionShipmentQuantityUnit.kilograms,
        sortOrder: 100,
      ),
    ];

enum DirectionShipmentRisk {
  good,
  tight,
  atRisk,
  overdue,
  shipped,
  cancelled,
  unknown,
}

enum DirectionFloorCountFreshness { fresh, aging, stale, missing }

class DirectionShipmentPlanRecord {
  final String id;
  final DateTime shipDate;
  final String clientName;
  final String materialCode;
  final DirectionShipmentMaterialScope materialScope;
  final DirectionShipmentQuantityUnit quantityUnit;
  final int plannedQuantity;
  final String priority;
  final String status;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DirectionShipmentPlanRecord({
    required this.id,
    required this.shipDate,
    required this.clientName,
    required this.materialCode,
    required this.materialScope,
    required this.quantityUnit,
    required this.plannedQuantity,
    required this.priority,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DirectionShipmentPlanRecord.fromRow(Map<String, dynamic> row) {
    final materialCode = _normalizePlanningMaterialCode(
      row['planning_material_code']?.toString() ??
          row['commercial_material_code']?.toString(),
    );
    final materialOption = materialCode == null
        ? null
        : directionShipmentMaterialByCode(materialCode);
    return DirectionShipmentPlanRecord(
      id: (row['id'] ?? '').toString(),
      shipDate: _parseDate(row['ship_date']),
      clientName: (row['client_name'] ?? '').toString().trim(),
      materialCode: materialCode ?? '',
      materialScope: _parseMaterialScope(
        row['material_scope']?.toString(),
        fallback: materialOption?.scope,
      ),
      quantityUnit: _parseQuantityUnit(
        row['quantity_unit']?.toString(),
        fallback: materialOption?.quantityUnit,
      ),
      plannedQuantity: ((row['planned_units'] as num?) ?? 0).toInt(),
      priority: (row['priority'] ?? 'normal').toString().trim().toLowerCase(),
      status: (row['status'] ?? 'planeado').toString().trim().toLowerCase(),
      notes: (row['notes'] ?? '').toString().trim(),
      createdAt: _tryParseDateTime(row['created_at']) ?? DateTime.now(),
      updatedAt: _tryParseDateTime(row['updated_at']) ?? DateTime.now(),
    );
  }

  String get commercialMaterialCode => materialCode;

  int get plannedUnits => plannedQuantity;

  bool get isShipped => status == 'embarcado';

  bool get isCancelled => status == 'cancelado';

  bool get isActive => !isShipped && !isCancelled;
}

class DirectionProductionCapacityImpactRecord {
  final String id;
  final String machineKey;
  final DateTime startDate;
  final DateTime endDate;
  final int impactPercent;
  final String notes;
  final String source;
  final String? linkedMaintenanceOrderId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DirectionProductionCapacityImpactRecord({
    required this.id,
    required this.machineKey,
    required this.startDate,
    required this.endDate,
    required this.impactPercent,
    required this.notes,
    required this.source,
    required this.linkedMaintenanceOrderId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DirectionProductionCapacityImpactRecord.fromRow(
    Map<String, dynamic> row,
  ) {
    return DirectionProductionCapacityImpactRecord(
      id: (row['id'] ?? '').toString(),
      machineKey: (row['machine_key'] ?? '').toString().trim().toLowerCase(),
      startDate: _parseDate(row['start_date']),
      endDate: _parseDate(row['end_date']),
      impactPercent: ((row['impact_percent'] as num?) ?? 100).toInt(),
      notes: (row['notes'] ?? '').toString().trim(),
      source: (row['source'] ?? 'manual').toString().trim().toLowerCase(),
      linkedMaintenanceOrderId: row['linked_maintenance_order_id']?.toString(),
      isActive: (row['is_active'] as bool?) ?? true,
      createdAt: _tryParseDateTime(row['created_at']) ?? DateTime.now(),
      updatedAt: _tryParseDateTime(row['updated_at']) ?? DateTime.now(),
    );
  }

  bool overlaps(DateTime date) {
    return !date.isBefore(startDate) && !date.isAfter(endDate);
  }
}

class DirectionCompactorMaintenanceAlert {
  final String id;
  final String folio;
  final String machineKey;
  final String status;
  final String equipmentLabel;
  final String areaLabel;
  final DateTime requestedAt;
  final String problemSummary;
  final bool confirmedByManualImpact;

  const DirectionCompactorMaintenanceAlert({
    required this.id,
    required this.folio,
    required this.machineKey,
    required this.status,
    required this.equipmentLabel,
    required this.areaLabel,
    required this.requestedAt,
    required this.problemSummary,
    required this.confirmedByManualImpact,
  });

  DirectionCompactorMaintenanceAlert copyWith({bool? confirmedByManualImpact}) {
    return DirectionCompactorMaintenanceAlert(
      id: id,
      folio: folio,
      machineKey: machineKey,
      status: status,
      equipmentLabel: equipmentLabel,
      areaLabel: areaLabel,
      requestedAt: requestedAt,
      problemSummary: problemSummary,
      confirmedByManualImpact:
          confirmedByManualImpact ?? this.confirmedByManualImpact,
    );
  }
}

class DirectionProductionExpectationDay {
  final DateTime date;
  final Map<String, int> expectedByMaterial;
  final Map<String, int> lossByMaterial;

  const DirectionProductionExpectationDay({
    required this.date,
    required this.expectedByMaterial,
    required this.lossByMaterial,
  });

  int expectedForMaterial(String materialCode) {
    return expectedByMaterial[materialCode] ?? 0;
  }

  int lossForMaterial(String materialCode) {
    return lossByMaterial[materialCode] ?? 0;
  }

  int get projectedMaterialCount =>
      expectedByMaterial.values.where((value) => value > 0).length;

  int get adjustedMaterialCount =>
      lossByMaterial.values.where((value) => value > 0).length;
}

class DirectionCapacityImpactSummary {
  final DirectionProductionCapacityImpactRecord impact;
  final Map<DateTime, Map<String, int>> dailyLossByMaterial;

  const DirectionCapacityImpactSummary({
    required this.impact,
    required this.dailyLossByMaterial,
  });

  List<String> get impactedMaterialCodes {
    final codes = <String>{};
    for (final dayLoss in dailyLossByMaterial.values) {
      for (final entry in dayLoss.entries) {
        if (entry.value > 0) codes.add(entry.key);
      }
    }
    final sorted = codes.toList(growable: false)
      ..sort((a, b) => _materialSortOrder(a).compareTo(_materialSortOrder(b)));
    return sorted;
  }

  int get impactedDaysCount => dailyLossByMaterial.length;
}

class DirectionShipmentPlanProjection {
  final DirectionShipmentPlanRecord plan;
  final int projectedAvailableBeforeQuantity;
  final int projectedRemainingAfterQuantity;
  final int expectedFutureQuantity;
  final int priorCommittedQuantity;
  final DirectionShipmentRisk risk;

  const DirectionShipmentPlanProjection({
    required this.plan,
    required this.projectedAvailableBeforeQuantity,
    required this.projectedRemainingAfterQuantity,
    required this.expectedFutureQuantity,
    required this.priorCommittedQuantity,
    required this.risk,
  });

  int get projectedAvailableBeforeUnits => projectedAvailableBeforeQuantity;

  int get projectedRemainingAfterUnits => projectedRemainingAfterQuantity;

  int get expectedFutureUnits => expectedFutureQuantity;

  int get priorCommittedUnits => priorCommittedQuantity;
}

class DirectionShipmentPlanningBundle {
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final List<DirectionShipmentPlanRecord> shipments;
  final List<DirectionShipmentPlanProjection> projections;
  final Map<String, int> floorCountByMaterial;
  final DateTime? floorCountUpdatedAt;
  final List<DirectionProductionExpectationDay> expectedDays;
  final List<DirectionProductionCapacityImpactRecord> activeCapacityImpacts;
  final List<DirectionCapacityImpactSummary> impactSummaries;
  final List<DirectionCompactorMaintenanceAlert> maintenanceAlerts;

  const DirectionShipmentPlanningBundle({
    required this.weekStartDate,
    required this.weekEndDate,
    required this.shipments,
    required this.projections,
    required this.floorCountByMaterial,
    required this.floorCountUpdatedAt,
    required this.expectedDays,
    required this.activeCapacityImpacts,
    required this.impactSummaries,
    required this.maintenanceAlerts,
  });

  int get activeFloorMaterialCount =>
      floorCountByMaterial.values.where((value) => value > 0).length;

  int get pendingShipmentCount => shipments.where((row) => row.isActive).length;

  int get highPriorityShipmentCount =>
      shipments.where((row) => row.isActive && row.priority == 'alta').length;

  int get confirmedShipmentCount => shipments
      .where((row) => row.isActive && row.status == 'confirmado')
      .length;

  int get atRiskShipmentCount => projections
      .where((row) => row.risk == DirectionShipmentRisk.atRisk)
      .length;

  int get tightShipmentCount => projections
      .where((row) => row.risk == DirectionShipmentRisk.tight)
      .length;

  int get projectedMaterialCount {
    final codes = <String>{};
    for (final day in expectedDays) {
      for (final entry in day.expectedByMaterial.entries) {
        if (entry.value > 0) codes.add(entry.key);
      }
    }
    return codes.length;
  }

  DirectionFloorCountFreshness get floorCountFreshness {
    final updatedAt = floorCountUpdatedAt;
    if (updatedAt == null || floorCountByMaterial.isEmpty) {
      return DirectionFloorCountFreshness.missing;
    }
    final age = DateTime.now().difference(updatedAt);
    if (age <= const Duration(hours: 4)) {
      return DirectionFloorCountFreshness.fresh;
    }
    if (age <= const Duration(hours: 12)) {
      return DirectionFloorCountFreshness.aging;
    }
    return DirectionFloorCountFreshness.stale;
  }
}

class DirectionShipmentsStore {
  static final SupabaseClient _supa = Supabase.instance.client;

  static DateTime currentWeekStartDate() => _weekStartMonday(DateTime.now());

  static DateTime normalizeWeekStartDate(DateTime weekDate) =>
      _weekStartMonday(weekDate);

  static Future<DirectionShipmentPlanningBundle> loadWeek(
    DateTime weekStartDate,
  ) async {
    final weekStart = _weekStartMonday(weekStartDate);
    final weekEnd = weekStart.add(const Duration(days: 5));
    final historyStart = weekStart.subtract(const Duration(days: 42));
    try {
      final results = await Future.wait<dynamic>([
        _loadShipmentRows(weekStart, weekEnd),
        _loadCapacityImpactRows(weekStart, weekEnd),
        _loadFloorCounts(),
        _loadProductionEvents(historyStart, weekEnd),
        _loadMaintenanceAlerts(weekStart),
      ]);

      final shipments = results[0] as List<DirectionShipmentPlanRecord>;
      final impacts =
          results[1] as List<DirectionProductionCapacityImpactRecord>;
      final floorData = results[2] as _FloorCountLoad;
      final events = results[3] as List<_ProductionEvent>;
      final maintenanceAlerts =
          results[4] as List<DirectionCompactorMaintenanceAlert>;

      final quantityByDateMaterial = _buildQuantityByDateMaterial(events);
      final quantityByDateMaterialMachine = _buildQuantityByDateMaterialMachine(
        events,
      );
      final expectedDays = _buildExpectedDays(
        weekStart: weekStart,
        weekEnd: weekEnd,
        impacts: impacts,
        quantityByDateMaterial: quantityByDateMaterial,
        quantityByDateMaterialMachine: quantityByDateMaterialMachine,
      );
      final impactSummaries = _buildImpactSummaries(
        weekStart: weekStart,
        weekEnd: weekEnd,
        impacts: impacts,
        quantityByDateMaterialMachine: quantityByDateMaterialMachine,
      );
      final alertCoverage = _buildManualImpactCoverage(impacts);
      final alerts = maintenanceAlerts
          .map(
            (alert) => alert.copyWith(
              confirmedByManualImpact: _isAlertCoveredByImpact(
                alert: alert,
                manualCoverage: alertCoverage,
              ),
            ),
          )
          .toList(growable: false);

      final projections = _buildProjections(
        shipments: shipments,
        floorCounts: floorData.countsByMaterial,
        expectedDays: expectedDays,
      );

      return DirectionShipmentPlanningBundle(
        weekStartDate: weekStart,
        weekEndDate: weekEnd,
        shipments: shipments,
        projections: projections,
        floorCountByMaterial: floorData.countsByMaterial,
        floorCountUpdatedAt: floorData.latestUpdatedAt,
        expectedDays: expectedDays,
        activeCapacityImpacts: impacts,
        impactSummaries: impactSummaries,
        maintenanceAlerts: alerts,
      );
    } catch (e, st) {
      AppErrorReporter.report(
        e,
        st,
        fallbackMessage:
            'No se pudo cargar la planeación ejecutiva de embarques.',
      );
      rethrow;
    }
  }

  static Future<void> createShipmentPlan({
    required DateTime shipDate,
    required String clientName,
    required String materialCode,
    required DirectionShipmentMaterialScope materialScope,
    required DirectionShipmentQuantityUnit quantityUnit,
    required int plannedQuantity,
    required String priority,
    required String status,
    required String notes,
  }) async {
    final normalizedCode = _normalizePlanningMaterialCode(materialCode) ?? '';
    await _supa.from(_kDirectionShipmentPlansTable).insert({
      'ship_date': _fmtDate(shipDate),
      'client_name': clientName.trim(),
      'commercial_material_code': normalizedCode,
      'planning_material_code': normalizedCode,
      'material_scope': _materialScopeDbValue(materialScope),
      'quantity_unit': _quantityUnitDbValue(quantityUnit),
      'planned_units': plannedQuantity,
      'priority': priority.trim().toLowerCase(),
      'status': status.trim().toLowerCase(),
      'notes': notes.trim().isEmpty ? null : notes.trim(),
    });
  }

  static Future<void> updateShipmentPlan(
    DirectionShipmentPlanRecord plan, {
    required DateTime shipDate,
    required String clientName,
    required String materialCode,
    required DirectionShipmentMaterialScope materialScope,
    required DirectionShipmentQuantityUnit quantityUnit,
    required int plannedQuantity,
    required String priority,
    required String status,
    required String notes,
  }) async {
    final normalizedCode = _normalizePlanningMaterialCode(materialCode) ?? '';
    await _supa
        .from(_kDirectionShipmentPlansTable)
        .update({
          'ship_date': _fmtDate(shipDate),
          'client_name': clientName.trim(),
          'commercial_material_code': normalizedCode,
          'planning_material_code': normalizedCode,
          'material_scope': _materialScopeDbValue(materialScope),
          'quantity_unit': _quantityUnitDbValue(quantityUnit),
          'planned_units': plannedQuantity,
          'priority': priority.trim().toLowerCase(),
          'status': status.trim().toLowerCase(),
          'notes': notes.trim().isEmpty ? null : notes.trim(),
        })
        .eq('id', plan.id);
  }

  static Future<void> deleteShipmentPlan(String id) async {
    await _supa.from(_kDirectionShipmentPlansTable).delete().eq('id', id);
  }

  static Future<void> createCapacityImpact({
    required String machineKey,
    required DateTime startDate,
    required DateTime endDate,
    required int impactPercent,
    required String notes,
  }) async {
    await _supa.from(_kDirectionCapacityImpactsTable).insert({
      'machine_key': machineKey.trim().toLowerCase(),
      'start_date': _fmtDate(startDate),
      'end_date': _fmtDate(endDate),
      'impact_percent': impactPercent,
      'notes': notes.trim().isEmpty ? null : notes.trim(),
      'source': 'manual',
      'is_active': true,
    });
  }

  static Future<void> updateCapacityImpact(
    DirectionProductionCapacityImpactRecord impact, {
    required String machineKey,
    required DateTime startDate,
    required DateTime endDate,
    required int impactPercent,
    required String notes,
    required bool isActive,
  }) async {
    await _supa
        .from(_kDirectionCapacityImpactsTable)
        .update({
          'machine_key': machineKey.trim().toLowerCase(),
          'start_date': _fmtDate(startDate),
          'end_date': _fmtDate(endDate),
          'impact_percent': impactPercent,
          'notes': notes.trim().isEmpty ? null : notes.trim(),
          'is_active': isActive,
        })
        .eq('id', impact.id);
  }

  static Future<void> deleteCapacityImpact(String id) async {
    await _supa.from(_kDirectionCapacityImpactsTable).delete().eq('id', id);
  }

  static Future<List<DirectionShipmentPlanRecord>> _loadShipmentRows(
    DateTime weekStart,
    DateTime weekEnd,
  ) async {
    final rows = await _supa
        .from(_kDirectionShipmentPlansTable)
        .select(
          'id,ship_date,client_name,commercial_material_code,'
          'planning_material_code,material_scope,quantity_unit,planned_units,'
          'priority,status,notes,created_at,updated_at',
        )
        .gte('ship_date', _fmtDate(weekStart))
        .lte('ship_date', _fmtDate(weekEnd))
        .order('ship_date', ascending: true)
        .order('created_at', ascending: true);
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(DirectionShipmentPlanRecord.fromRow)
        .toList(growable: false);
  }

  static Future<List<DirectionProductionCapacityImpactRecord>>
  _loadCapacityImpactRows(DateTime weekStart, DateTime weekEnd) async {
    final rows = await _supa
        .from(_kDirectionCapacityImpactsTable)
        .select(
          'id,machine_key,start_date,end_date,impact_percent,notes,source,'
          'linked_maintenance_order_id,is_active,created_at,updated_at',
        )
        .eq('is_active', true)
        .lte('start_date', _fmtDate(weekEnd))
        .gte('end_date', _fmtDate(weekStart))
        .order('start_date', ascending: true)
        .order('created_at', ascending: true);
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(DirectionProductionCapacityImpactRecord.fromRow)
        .toList(growable: false);
  }

  static Future<_FloorCountLoad> _loadFloorCounts() async {
    final rows = await _supa
        .from('dashboard_yard_manual_counts')
        .select(
          'source_kind,material,commercial_material_code,count_units,weight_kg,'
          'counted_at,updated_at',
        )
        .inFilter('source_kind', const [
          'commercial_material',
          'operational_material',
        ]);

    final countsByMaterial = <String, int>{};
    DateTime? latestUpdatedAt;
    for (final row in (rows as List<dynamic>).cast<Map<String, dynamic>>()) {
      final sourceKind = (row['source_kind'] ?? '').toString().trim();
      String? materialCode;
      int quantity = 0;
      if (sourceKind == 'commercial_material') {
        materialCode = _normalizePlanningMaterialCode(
          row['commercial_material_code']?.toString(),
        );
        final option = materialCode == null
            ? null
            : directionShipmentMaterialByCode(materialCode);
        if (option == null ||
            option.scope != DirectionShipmentMaterialScope.commercial) {
          continue;
        }
        quantity = ((row['count_units'] as num?) ?? 0).toInt();
      } else if (sourceKind == 'operational_material') {
        materialCode = _normalizePlanningMaterialCode(
          row['material']?.toString(),
        );
        final option = materialCode == null
            ? null
            : directionShipmentMaterialByCode(materialCode);
        if (option == null ||
            option.scope != DirectionShipmentMaterialScope.general) {
          continue;
        }
        final weightKg = (row['weight_kg'] as num?)?.toDouble() ?? 0;
        quantity = weightKg.round();
      }
      if (materialCode == null) continue;
      countsByMaterial.update(
        materialCode,
        (value) => value + quantity,
        ifAbsent: () => quantity,
      );
      final countedAt = _tryParseDateTime(row['counted_at']);
      final updatedAt = _tryParseDateTime(row['updated_at']);
      final candidate = updatedAt == null
          ? countedAt
          : countedAt == null
          ? updatedAt
          : (updatedAt.isAfter(countedAt) ? updatedAt : countedAt);
      if (candidate != null &&
          (latestUpdatedAt == null || candidate.isAfter(latestUpdatedAt))) {
        latestUpdatedAt = candidate;
      }
    }
    return _FloorCountLoad(
      countsByMaterial: countsByMaterial,
      latestUpdatedAt: latestUpdatedAt,
    );
  }

  static Future<List<_ProductionEvent>> _loadProductionEvents(
    DateTime historyStart,
    DateTime weekEnd,
  ) async {
    final rows = await fetchAllSupabaseRows(
      (from, to) => _supa
          .from('material_transformation_run_outputs_v2')
          .select(
            'output_weight_kg,output_unit_count,notes,'
            'commercial_material:commercial_material_id('
            'code,general_material:general_material_id(code)'
            '),'
            'run:run_id(op_date,notes,source_general_material:source_general_material_id(code))',
          )
          .gte('run.op_date', _fmtDate(historyStart))
          .lte('run.op_date', _fmtDate(weekEnd))
          .range(from, to),
    );

    final events = <_ProductionEvent>[];
    for (final row in rows) {
      final run = (row['run'] as Map?)?.cast<String, dynamic>();
      if (run == null) continue;
      final opDate = _parseDate(run['op_date']);
      final outputNotes = (row['notes'] ?? '').toString().trim();
      final runNotes = (run['notes'] ?? '').toString().trim();
      final notes = '$outputNotes $runNotes'.trim();
      final commercial = (row['commercial_material'] as Map?)
          ?.cast<String, dynamic>();
      final commercialCode = _normalizePlanningMaterialCode(
        commercial?['code']?.toString(),
      );
      final generalCode = _normalizePlanningMaterialCode(
        (((commercial?['general_material'] as Map?) ?? const {})['code'] ??
                ((run['source_general_material'] as Map?) ?? const {})['code'])
            .toString(),
      );
      final outputUnits = ((row['output_unit_count'] as num?) ?? 0).toInt();
      final outputKg = ((row['output_weight_kg'] as num?) ?? 0).toDouble();
      final machineKey = _compactadoraKeyFromText(notes);

      final commercialOption = commercialCode == null
          ? null
          : directionShipmentMaterialByCode(commercialCode);
      if (commercialOption != null &&
          commercialOption.quantityUnit ==
              DirectionShipmentQuantityUnit.bales &&
          outputUnits > 0) {
        events.add(
          _ProductionEvent(
            date: opDate,
            materialCode: commercialOption.code,
            quantity: outputUnits,
            compactadoraKey: machineKey,
          ),
        );
      }

      final generalOption = generalCode == null
          ? null
          : directionShipmentMaterialByCode(generalCode);
      if (generalOption != null &&
          generalOption.quantityUnit ==
              DirectionShipmentQuantityUnit.kilograms &&
          outputKg > 0) {
        events.add(
          _ProductionEvent(
            date: opDate,
            materialCode: generalOption.code,
            quantity: outputKg.round(),
            compactadoraKey: machineKey,
          ),
        );
      }
    }

    if (events.isNotEmpty) {
      return events;
    }

    final legacyRows = await fetchAllSupabaseRows(
      (from, to) => _supa
          .from('production_runs')
          .select('op_date,bale_material,bale_count,notes')
          .gte('op_date', _fmtDate(historyStart))
          .lte('op_date', _fmtDate(weekEnd))
          .order('op_date', ascending: true)
          .range(from, to),
    );
    final legacyEvents = <_ProductionEvent>[];
    for (final row in legacyRows) {
      final count = ((row['bale_count'] as num?) ?? 0).toInt();
      if (count <= 0) continue;
      final materialCode = _normalizePlanningMaterialCode(
        row['bale_material']?.toString(),
      );
      final option = materialCode == null
          ? null
          : directionShipmentMaterialByCode(materialCode);
      if (option == null ||
          option.quantityUnit != DirectionShipmentQuantityUnit.bales) {
        continue;
      }
      legacyEvents.add(
        _ProductionEvent(
          date: _parseDate(row['op_date']),
          materialCode: option.code,
          quantity: count,
          compactadoraKey: _compactadoraKeyFromText(row['notes']?.toString()),
        ),
      );
    }
    return legacyEvents;
  }

  static Future<List<DirectionCompactorMaintenanceAlert>>
  _loadMaintenanceAlerts(DateTime weekStart) async {
    final rows = await fetchAllSupabaseRows(
      (from, to) => _supa
          .from('maintenance_orders')
          .select(
            'id,ot_folio,status,requested_at,updated_at,area_label,'
            'equipment_label,problem_description,diagnosis',
          )
          .gte(
            'requested_at',
            _fmtDate(weekStart.subtract(const Duration(days: 21))),
          )
          .order('requested_at', ascending: false)
          .range(from, to),
    );

    final alerts = <DirectionCompactorMaintenanceAlert>[];
    for (final row in rows) {
      if (isMaintenanceClosedStatus(row['status'])) continue;
      final equipment = (row['equipment_label'] ?? '').toString().trim();
      final area = (row['area_label'] ?? '').toString().trim();
      final problem = (row['problem_description'] ?? '').toString().trim();
      final diagnosis = (row['diagnosis'] ?? '').toString().trim();
      final haystack = '$equipment $area $problem $diagnosis';
      if (!_mentionsCompactor(haystack)) continue;
      final machineKey = _compactadoraKeyFromText(haystack) ?? 'ambas';
      alerts.add(
        DirectionCompactorMaintenanceAlert(
          id: (row['id'] ?? '').toString(),
          folio: (row['ot_folio'] ?? '').toString().trim(),
          machineKey: machineKey,
          status: (row['status'] ?? '').toString().trim(),
          equipmentLabel: equipment,
          areaLabel: area,
          requestedAt: _tryParseDateTime(row['requested_at']) ?? DateTime.now(),
          problemSummary: problem.isNotEmpty ? problem : diagnosis,
          confirmedByManualImpact: false,
        ),
      );
    }
    return alerts;
  }

  static List<DirectionProductionExpectationDay> _buildExpectedDays({
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<DirectionProductionCapacityImpactRecord> impacts,
    required Map<DateTime, Map<String, int>> quantityByDateMaterial,
    required Map<DateTime, Map<String, Map<String, int>>>
    quantityByDateMaterialMachine,
  }) {
    final days = <DirectionProductionExpectationDay>[];
    for (
      var day = weekStart;
      !day.isAfter(weekEnd);
      day = day.add(const Duration(days: 1))
    ) {
      final historyDates = <DateTime>[
        for (var offset = 1; offset <= 6; offset++)
          day.subtract(Duration(days: 7 * offset)),
      ];
      final expectedByMaterial = <String, int>{};
      final lossByMaterial = <String, int>{};
      final c1Percent = _impactPercentForMachineOnDate(
        impacts: impacts,
        machineKey: 'c1',
        date: day,
      );
      final c2Percent = _impactPercentForMachineOnDate(
        impacts: impacts,
        machineKey: 'c2',
        date: day,
      );

      for (final material in kDirectionShipmentMaterials) {
        final base = _averageQuantity(
          historyDates
              .map((date) => quantityByDateMaterial[date]?[material.code] ?? 0)
              .toList(growable: false),
        );
        final c1Base = _averageQuantity(
          historyDates
              .map(
                (date) =>
                    quantityByDateMaterialMachine[date]?[material
                        .code]?['c1'] ??
                    0,
              )
              .toList(growable: false),
        );
        final c2Base = _averageQuantity(
          historyDates
              .map(
                (date) =>
                    quantityByDateMaterialMachine[date]?[material
                        .code]?['c2'] ??
                    0,
              )
              .toList(growable: false),
        );
        final loss =
            _applyPercent(c1Base, c1Percent) + _applyPercent(c2Base, c2Percent);
        expectedByMaterial[material.code] = math.max(0, base - loss);
        if (loss > 0) {
          lossByMaterial[material.code] = loss;
        }
      }

      days.add(
        DirectionProductionExpectationDay(
          date: day,
          expectedByMaterial: Map<String, int>.unmodifiable(expectedByMaterial),
          lossByMaterial: Map<String, int>.unmodifiable(lossByMaterial),
        ),
      );
    }
    return days;
  }

  static List<DirectionCapacityImpactSummary> _buildImpactSummaries({
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<DirectionProductionCapacityImpactRecord> impacts,
    required Map<DateTime, Map<String, Map<String, int>>>
    quantityByDateMaterialMachine,
  }) {
    return impacts
        .map((impact) {
          final dailyLossByMaterial = <DateTime, Map<String, int>>{};
          for (
            var day = weekStart;
            !day.isAfter(weekEnd);
            day = day.add(const Duration(days: 1))
          ) {
            if (!impact.overlaps(day)) continue;
            final historyDates = <DateTime>[
              for (var offset = 1; offset <= 6; offset++)
                day.subtract(Duration(days: 7 * offset)),
            ];
            final materialLoss = <String, int>{};
            for (final material in kDirectionShipmentMaterials) {
              var loss = 0;
              if (impact.machineKey == 'c1' || impact.machineKey == 'ambas') {
                final c1Base = _averageQuantity(
                  historyDates
                      .map(
                        (date) =>
                            quantityByDateMaterialMachine[date]?[material
                                .code]?['c1'] ??
                            0,
                      )
                      .toList(growable: false),
                );
                loss += _applyPercent(c1Base, impact.impactPercent);
              }
              if (impact.machineKey == 'c2' || impact.machineKey == 'ambas') {
                final c2Base = _averageQuantity(
                  historyDates
                      .map(
                        (date) =>
                            quantityByDateMaterialMachine[date]?[material
                                .code]?['c2'] ??
                            0,
                      )
                      .toList(growable: false),
                );
                loss += _applyPercent(c2Base, impact.impactPercent);
              }
              if (loss > 0) {
                materialLoss[material.code] = loss;
              }
            }
            if (materialLoss.isNotEmpty) {
              dailyLossByMaterial[day] = Map<String, int>.unmodifiable(
                materialLoss,
              );
            }
          }
          return DirectionCapacityImpactSummary(
            impact: impact,
            dailyLossByMaterial: Map<DateTime, Map<String, int>>.unmodifiable(
              dailyLossByMaterial,
            ),
          );
        })
        .toList(growable: false);
  }

  static List<DirectionShipmentPlanProjection> _buildProjections({
    required List<DirectionShipmentPlanRecord> shipments,
    required Map<String, int> floorCounts,
    required List<DirectionProductionExpectationDay> expectedDays,
  }) {
    final today = _dateOnly(DateTime.now());
    final sorted = shipments.toList(growable: false)
      ..sort((a, b) {
        final dateCompare = a.shipDate.compareTo(b.shipDate);
        if (dateCompare != 0) return dateCompare;
        final priorityCompare = _priorityRank(
          a.priority,
        ).compareTo(_priorityRank(b.priority));
        if (priorityCompare != 0) return priorityCompare;
        final createdCompare = a.createdAt.compareTo(b.createdAt);
        if (createdCompare != 0) return createdCompare;
        return a.clientName.compareTo(b.clientName);
      });

    final runningCommittedByMaterial = <String, int>{};
    final projections = <DirectionShipmentPlanProjection>[];
    for (final plan in sorted) {
      final materialCode = plan.materialCode;
      final priorCommitted = runningCommittedByMaterial[materialCode] ?? 0;
      final baseFloor = floorCounts[materialCode] ?? 0;

      if (plan.isCancelled) {
        projections.add(
          DirectionShipmentPlanProjection(
            plan: plan,
            projectedAvailableBeforeQuantity: baseFloor,
            projectedRemainingAfterQuantity: baseFloor,
            expectedFutureQuantity: 0,
            priorCommittedQuantity: priorCommitted,
            risk: DirectionShipmentRisk.cancelled,
          ),
        );
        continue;
      }
      if (plan.isShipped) {
        projections.add(
          DirectionShipmentPlanProjection(
            plan: plan,
            projectedAvailableBeforeQuantity: baseFloor,
            projectedRemainingAfterQuantity: baseFloor,
            expectedFutureQuantity: 0,
            priorCommittedQuantity: priorCommitted,
            risk: DirectionShipmentRisk.shipped,
          ),
        );
        continue;
      }

      final expectedFuture = expectedDays
          .where(
            (day) =>
                day.date.isAfter(today) && !day.date.isAfter(plan.shipDate),
          )
          .fold<int>(
            0,
            (sum, day) => sum + day.expectedForMaterial(materialCode),
          );
      final projectedBefore = baseFloor + expectedFuture - priorCommitted;
      final projectedAfter = projectedBefore - plan.plannedQuantity;
      final risk = _riskForPlan(
        plan: plan,
        projectedAfter: projectedAfter,
        floorCounts: floorCounts,
      );
      projections.add(
        DirectionShipmentPlanProjection(
          plan: plan,
          projectedAvailableBeforeQuantity: projectedBefore,
          projectedRemainingAfterQuantity: projectedAfter,
          expectedFutureQuantity: expectedFuture,
          priorCommittedQuantity: priorCommitted,
          risk: risk,
        ),
      );
      runningCommittedByMaterial[materialCode] =
          priorCommitted + plan.plannedQuantity;
    }
    return projections;
  }

  static Map<String, List<DirectionProductionCapacityImpactRecord>>
  _buildManualImpactCoverage(
    List<DirectionProductionCapacityImpactRecord> impacts,
  ) {
    final coverage = <String, List<DirectionProductionCapacityImpactRecord>>{};
    for (final impact in impacts) {
      final keys = impact.machineKey == 'ambas'
          ? const <String>['c1', 'c2']
          : <String>[impact.machineKey];
      for (final key in keys) {
        coverage
            .putIfAbsent(key, () => <DirectionProductionCapacityImpactRecord>[])
            .add(impact);
      }
    }
    return coverage;
  }

  static bool _isAlertCoveredByImpact({
    required DirectionCompactorMaintenanceAlert alert,
    required Map<String, List<DirectionProductionCapacityImpactRecord>>
    manualCoverage,
  }) {
    final rows = manualCoverage[alert.machineKey] ?? const [];
    final requestedDate = _dateOnly(alert.requestedAt);
    final followUpDate = requestedDate.add(const Duration(days: 1));
    for (final row in rows) {
      if (row.overlaps(requestedDate) || row.overlaps(followUpDate)) {
        return true;
      }
    }
    return false;
  }
}

class _FloorCountLoad {
  final Map<String, int> countsByMaterial;
  final DateTime? latestUpdatedAt;

  const _FloorCountLoad({
    required this.countsByMaterial,
    required this.latestUpdatedAt,
  });
}

class _ProductionEvent {
  final DateTime date;
  final String materialCode;
  final int quantity;
  final String? compactadoraKey;

  const _ProductionEvent({
    required this.date,
    required this.materialCode,
    required this.quantity,
    required this.compactadoraKey,
  });
}

DirectionShipmentMaterialOption? directionShipmentMaterialByCode(String code) {
  final normalized = _normalizePlanningMaterialCode(code);
  if (normalized == null) return null;
  for (final material in kDirectionShipmentMaterials) {
    if (material.code == normalized) return material;
  }
  return null;
}

String directionShipmentMaterialLabel(String code) {
  return directionShipmentMaterialByCode(code)?.label ?? code;
}

String directionShipmentMaterialScopeLabel(String code) {
  return directionShipmentMaterialByCode(code)?.scopeLabel ?? 'Material';
}

String directionShipmentMaterialUnitShortLabel(String code) {
  return directionShipmentMaterialByCode(code)?.shortUnitLabel ?? 'u';
}

String directionMachineKeyLabel(String machineKey) {
  switch (machineKey.trim().toLowerCase()) {
    case 'c1':
      return 'Compactadora 1';
    case 'c2':
      return 'Compactadora 2';
    case 'ambas':
      return 'Compactadoras 1 y 2';
    default:
      return machineKey;
  }
}

int _priorityRank(String priority) {
  switch (priority.trim().toLowerCase()) {
    case 'alta':
      return 0;
    case 'normal':
      return 1;
    case 'flexible':
      return 2;
    default:
      return 9;
  }
}

DirectionShipmentRisk _riskForPlan({
  required DirectionShipmentPlanRecord plan,
  required int projectedAfter,
  required Map<String, int> floorCounts,
}) {
  final today = _dateOnly(DateTime.now());
  if (!floorCounts.containsKey(plan.materialCode)) {
    return DirectionShipmentRisk.unknown;
  }
  if (plan.shipDate.isBefore(today)) {
    return projectedAfter < 0
        ? DirectionShipmentRisk.atRisk
        : DirectionShipmentRisk.overdue;
  }
  if (projectedAfter < 0) {
    return DirectionShipmentRisk.atRisk;
  }
  final margin = plan.quantityUnit == DirectionShipmentQuantityUnit.kilograms
      ? math.max(250, (plan.plannedQuantity * 0.12).round())
      : math.max(5, (plan.plannedQuantity * 0.15).round());
  if (projectedAfter < margin) {
    return DirectionShipmentRisk.tight;
  }
  return DirectionShipmentRisk.good;
}

int _impactPercentForMachineOnDate({
  required List<DirectionProductionCapacityImpactRecord> impacts,
  required String machineKey,
  required DateTime date,
}) {
  var percent = 0;
  for (final impact in impacts) {
    if (!impact.overlaps(date)) continue;
    if (impact.machineKey != machineKey && impact.machineKey != 'ambas') {
      continue;
    }
    percent += impact.impactPercent;
  }
  return percent.clamp(0, 100);
}

Map<DateTime, Map<String, int>> _buildQuantityByDateMaterial(
  List<_ProductionEvent> events,
) {
  final byDate = <DateTime, Map<String, int>>{};
  for (final event in events) {
    final bucket = byDate.putIfAbsent(event.date, () => <String, int>{});
    bucket.update(
      event.materialCode,
      (value) => value + event.quantity,
      ifAbsent: () => event.quantity,
    );
  }
  return byDate;
}

Map<DateTime, Map<String, Map<String, int>>>
_buildQuantityByDateMaterialMachine(List<_ProductionEvent> events) {
  final byDate = <DateTime, Map<String, Map<String, int>>>{};
  for (final event in events) {
    final shares = _machineSharesForEvent(event);
    if (shares.isEmpty) continue;
    final dateBucket = byDate.putIfAbsent(
      event.date,
      () => <String, Map<String, int>>{},
    );
    final materialBucket = dateBucket.putIfAbsent(
      event.materialCode,
      () => <String, int>{},
    );
    for (final entry in shares.entries) {
      materialBucket.update(
        entry.key,
        (value) => value + entry.value,
        ifAbsent: () => entry.value,
      );
    }
  }
  return byDate;
}

Map<String, int> _machineSharesForEvent(_ProductionEvent event) {
  switch (event.compactadoraKey) {
    case 'c1':
      return <String, int>{'c1': event.quantity};
    case 'c2':
      return <String, int>{'c2': event.quantity};
    case 'ambas':
      final c1 = (event.quantity / 2).round();
      final c2 = event.quantity - c1;
      return <String, int>{'c1': c1, 'c2': c2};
    default:
      return const <String, int>{};
  }
}

int _averageQuantity(List<int> values) {
  if (values.isEmpty) return 0;
  final total = values.fold<int>(0, (sum, value) => sum + value);
  return (total / values.length).round();
}

int _applyPercent(int value, int percent) {
  if (value <= 0 || percent <= 0) return 0;
  return ((value * percent) / 100).round();
}

bool _mentionsCompactor(String text) {
  final normalized = text.trim().toUpperCase();
  if (normalized.isEmpty) return false;
  return normalized.contains('COMPACTADORA') ||
      normalized.contains('EMPACADORA') ||
      normalized.contains('PRENSA') ||
      RegExp(r'(^|[^A-Z0-9])C1([^A-Z0-9]|$)').hasMatch(normalized) ||
      RegExp(r'(^|[^A-Z0-9])C2([^A-Z0-9]|$)').hasMatch(normalized);
}

String? _compactadoraKeyFromText(String? text) {
  final normalized = (text ?? '').trim().toUpperCase();
  if (normalized.isEmpty) return null;
  final hasC1 =
      normalized.contains('COMPACTADORA 1') ||
      normalized.contains('COMPACTADORA1') ||
      RegExp(r'(^|[^A-Z0-9])C1([^A-Z0-9]|$)').hasMatch(normalized);
  final hasC2 =
      normalized.contains('COMPACTADORA 2') ||
      normalized.contains('COMPACTADORA2') ||
      RegExp(r'(^|[^A-Z0-9])C2([^A-Z0-9]|$)').hasMatch(normalized);
  if (hasC1 && hasC2) return 'ambas';
  if (hasC1) return 'c1';
  if (hasC2) return 'c2';
  return null;
}

String? _normalizePlanningMaterialCode(String? rawCode) {
  final code = (rawCode ?? '').trim().toUpperCase();
  switch (code) {
    case 'BALE_NATIONAL':
    case 'PACA_NACIONAL':
      return 'PACA_NACIONAL';
    case 'BALE_AMERICAN':
    case 'PACA_AMERICANA':
      return 'PACA_AMERICANA';
    case 'BALE_CLEAN':
    case 'PACA_LIMPIA':
      return 'PACA_LIMPIA';
    case 'BALE_TRASH':
    case 'PACA_BASURA':
      return 'PACA_BASURA';
    case 'BALE_CAPLE':
    case 'PACA CAPLE':
    case 'PACA_CAPLE':
    case 'CAPLE':
      return 'CAPLE';
    case 'SCRAP':
    case 'CHATARRA':
      return 'CHATARRA';
    case 'PAPER':
    case 'PAPEL':
      return 'PAPEL';
    case 'PLASTIC':
    case 'PLASTICO':
      return 'PLASTICO';
    case 'WOOD':
    case 'MADERA':
      return 'MADERA';
    case 'METAL':
      return 'METAL';
    default:
      return code.isEmpty ? null : code;
  }
}

DirectionShipmentMaterialScope _parseMaterialScope(
  String? raw, {
  DirectionShipmentMaterialScope? fallback,
}) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'general':
      return DirectionShipmentMaterialScope.general;
    case 'commercial':
      return DirectionShipmentMaterialScope.commercial;
    default:
      return fallback ?? DirectionShipmentMaterialScope.commercial;
  }
}

DirectionShipmentQuantityUnit _parseQuantityUnit(
  String? raw, {
  DirectionShipmentQuantityUnit? fallback,
}) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case 'KG':
      return DirectionShipmentQuantityUnit.kilograms;
    case 'PACAS':
      return DirectionShipmentQuantityUnit.bales;
    default:
      return fallback ?? DirectionShipmentQuantityUnit.bales;
  }
}

String _materialScopeDbValue(DirectionShipmentMaterialScope scope) {
  return scope == DirectionShipmentMaterialScope.general
      ? 'general'
      : 'commercial';
}

String _quantityUnitDbValue(DirectionShipmentQuantityUnit unit) {
  return unit == DirectionShipmentQuantityUnit.kilograms ? 'KG' : 'PACAS';
}

int _materialSortOrder(String materialCode) {
  return directionShipmentMaterialByCode(materialCode)?.sortOrder ?? 999;
}

DateTime _weekStartMonday(DateTime date) {
  final normalized = _dateOnly(date);
  return normalized.subtract(
    Duration(days: normalized.weekday - DateTime.monday),
  );
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _parseDate(dynamic value) {
  if (value is DateTime) return _dateOnly(value);
  final parsed = DateTime.tryParse((value ?? '').toString());
  if (parsed != null) return _dateOnly(parsed);
  return _dateOnly(DateTime.now());
}

DateTime? _tryParseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String _fmtDate(DateTime date) {
  final normalized = _dateOnly(date);
  final mm = normalized.month.toString().padLeft(2, '0');
  final dd = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$mm-$dd';
}
