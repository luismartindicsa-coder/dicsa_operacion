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

const List<String> _kPriorityShipmentClients = <String>[
  'El Palomar',
  'San Pablo',
  'San Luis',
  'Queretana',
  'Bio Papel',
  'Majose',
  'Ricardo Mendieta',
];

const Map<String, List<String>> _kPriorityShipmentClientAliases =
    <String, List<String>>{
      'El Palomar': <String>['EL PALOMAR', 'CUENTA EL PALOMAR'],
      'San Pablo': <String>['SAN PABLO'],
      'San Luis': <String>['SAN LUIS'],
      'Queretana': <String>[
        'QUERETANA',
        'QUERETANIA',
        'DESPERDICIOS QUERETANA',
      ],
      'Bio Papel': <String>['BIO PAPEL', 'BIOPAPEL'],
      'Majose': <String>['MAJOSE'],
      'Ricardo Mendieta': <String>['RICARDO MENDIETA', 'MENDIETA'],
    };

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
  final Map<String, int> dayShiftExpectedByMaterial;
  final Map<String, int> lossByMaterial;

  const DirectionProductionExpectationDay({
    required this.date,
    required this.expectedByMaterial,
    required this.dayShiftExpectedByMaterial,
    required this.lossByMaterial,
  });

  int expectedForMaterial(String materialCode) {
    return expectedByMaterial[materialCode] ?? 0;
  }

  int dayShiftExpectedForMaterial(String materialCode) {
    return dayShiftExpectedByMaterial[materialCode] ?? 0;
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

class DirectionSuggestedShipmentRecord {
  final DateTime suggestedDate;
  final String clientName;
  final String materialCode;
  final DirectionShipmentMaterialScope materialScope;
  final DirectionShipmentQuantityUnit quantityUnit;
  final int suggestedQuantity;
  final int projectedAvailableBeforeQuantity;
  final int projectedRemainingAfterQuantity;
  final int expectedFutureQuantity;
  final int currentFloorQuantity;
  final int remainingGerenciaTargetQuantity;
  final int historicalAverageQuantity;
  final int historicalShipmentCount;
  final DateTime? lastShipmentDate;
  final DirectionShipmentRisk risk;
  final String gerenciaBaleTypeKey;
  final String explanation;
  final bool noteMatched;

  const DirectionSuggestedShipmentRecord({
    required this.suggestedDate,
    required this.clientName,
    required this.materialCode,
    required this.materialScope,
    required this.quantityUnit,
    required this.suggestedQuantity,
    required this.projectedAvailableBeforeQuantity,
    required this.projectedRemainingAfterQuantity,
    required this.expectedFutureQuantity,
    required this.currentFloorQuantity,
    required this.remainingGerenciaTargetQuantity,
    required this.historicalAverageQuantity,
    required this.historicalShipmentCount,
    required this.lastShipmentDate,
    required this.risk,
    required this.gerenciaBaleTypeKey,
    required this.explanation,
    required this.noteMatched,
  });
}

class DirectionShipmentPlanningBundle {
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final List<DirectionShipmentPlanRecord> shipments;
  final List<DirectionShipmentPlanProjection> projections;
  final List<DirectionSuggestedShipmentRecord> suggestedShipments;
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
    required this.suggestedShipments,
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
        _loadGerenciaShipmentTargets(weekStart),
        _loadShipmentHistory(
          weekStart.subtract(const Duration(days: 112)),
          weekEnd,
        ),
      ]);

      final shipments = results[0] as List<DirectionShipmentPlanRecord>;
      final impacts =
          results[1] as List<DirectionProductionCapacityImpactRecord>;
      final floorData = results[2] as _FloorCountLoad;
      final events = results[3] as List<_ProductionEvent>;
      final maintenanceAlerts =
          results[4] as List<DirectionCompactorMaintenanceAlert>;
      final gerenciaTargets = results[5] as List<_GerenciaShipmentTargetLine>;
      final shipmentHistory = results[6] as List<_ShipmentHistoryEvent>;

      final quantityByDateMaterial = _buildQuantityByDateMaterial(events);
      final quantityByDateMaterialShift = _buildQuantityByDateMaterialShift(
        events,
      );
      final quantityByDateMaterialMachine = _buildQuantityByDateMaterialMachine(
        events,
      );
      final quantityByDateMaterialMachineShift =
          _buildQuantityByDateMaterialMachineShift(events);
      final expectedDays = _buildExpectedDays(
        weekStart: weekStart,
        weekEnd: weekEnd,
        impacts: impacts,
        quantityByDateMaterial: quantityByDateMaterial,
        quantityByDateMaterialShift: quantityByDateMaterialShift,
        quantityByDateMaterialMachine: quantityByDateMaterialMachine,
        quantityByDateMaterialMachineShift: quantityByDateMaterialMachineShift,
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
      final suggestedShipments = _buildSuggestedShipments(
        weekStart: weekStart,
        weekEnd: weekEnd,
        shipments: shipments,
        floorCounts: floorData.countsByMaterial,
        expectedDays: expectedDays,
        gerenciaTargets: gerenciaTargets,
        shipmentHistory: shipmentHistory,
      );

      return DirectionShipmentPlanningBundle(
        weekStartDate: weekStart,
        weekEndDate: weekEnd,
        shipments: shipments,
        projections: projections,
        suggestedShipments: suggestedShipments,
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

  static Future<List<_GerenciaShipmentTargetLine>> _loadGerenciaShipmentTargets(
    DateTime weekStart,
  ) async {
    final planRow = await _supa
        .from('gerencia_bale_weekly_plans')
        .select('id')
        .eq('week_start_date', _fmtDate(weekStart))
        .maybeSingle();
    if (planRow == null) {
      return const <_GerenciaShipmentTargetLine>[];
    }
    final lineRows = await _supa
        .from('gerencia_bale_weekly_plan_lines')
        .select('bale_type_key,sort_order,shipment_target_bales,notes')
        .eq('plan_id', planRow['id'].toString())
        .order('sort_order', ascending: true)
        .order('bale_type_key', ascending: true);
    return (lineRows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_GerenciaShipmentTargetLine.fromRow)
        .where((line) => line.shipmentTargetBales > 0)
        .toList(growable: false);
  }

  static Future<_FloorCountLoad> _loadFloorCounts() async {
    final responses = await Future.wait<dynamic>([
      _supa
          .from('dashboard_yard_manual_counts')
          .select(
            'source_kind,material,commercial_material_code,count_units,weight_kg,'
            'counted_at,updated_at',
          )
          .inFilter('source_kind', const [
            'commercial_material',
            'operational_material',
          ]),
      _supa
          .from('material_commercial_catalog_v2')
          .select('code,general_material:general_material_id(code)')
          .eq('is_active', true),
    ]);

    final rows = responses[0] as List<dynamic>;
    final catalogRows = (responses[1] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final generalMaterialByCommercial = <String, String>{};
    for (final row in catalogRows) {
      final commercialCode = _normalizePlanningMaterialCode(
        row['code']?.toString(),
      );
      final generalCode = _normalizePlanningMaterialCode(
        ((row['general_material'] as Map?) ?? const <String, dynamic>{})['code']
            ?.toString(),
      );
      if (commercialCode == null || generalCode == null) continue;
      generalMaterialByCommercial[commercialCode] = generalCode;
    }

    final countsByMaterial = <String, int>{};
    DateTime? latestUpdatedAt;
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final sourceKind = (row['source_kind'] ?? '').toString().trim();
      String? materialCode;
      int quantity = 0;
      if (sourceKind == 'commercial_material') {
        final commercialCode = _normalizePlanningMaterialCode(
          row['commercial_material_code']?.toString(),
        );
        final option = commercialCode == null
            ? null
            : directionShipmentMaterialByCode(commercialCode);
        if (option != null &&
            option.scope == DirectionShipmentMaterialScope.commercial) {
          materialCode = option.code;
          quantity = ((row['count_units'] as num?) ?? 0).toInt();
        } else {
          final generalCode =
              generalMaterialByCommercial[commercialCode] ??
              (option?.scope == DirectionShipmentMaterialScope.general
                  ? option?.code
                  : null);
          final generalOption = generalCode == null
              ? null
              : directionShipmentMaterialByCode(generalCode);
          if (generalOption == null ||
              generalOption.scope != DirectionShipmentMaterialScope.general) {
            continue;
          }
          materialCode = generalOption.code;
          final weightKg = (row['weight_kg'] as num?)?.toDouble() ?? 0;
          quantity = weightKg.round();
        }
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

  static Future<List<_ShipmentHistoryEvent>> _loadShipmentHistory(
    DateTime historyStart,
    DateTime weekEnd,
  ) async {
    final rows = await fetchAllSupabaseRows(
      (from, to) => _supa
          .from('inventory_movements_v2')
          .select(
            'op_date,unit_count,counterparty,'
            'commercial_material:commercial_material_id(code)',
          )
          .eq('flow', 'OUT')
          .eq('inventory_level', 'COMMERCIAL')
          .gte('op_date', _fmtDate(historyStart))
          .lte('op_date', _fmtDate(weekEnd))
          .order('op_date', ascending: true)
          .range(from, to),
    );

    final history = <_ShipmentHistoryEvent>[];
    for (final row in rows) {
      final quantity = ((row['unit_count'] as num?) ?? 0).toInt();
      if (quantity <= 0) continue;
      final clientName = _canonicalPriorityClientName(
        row['counterparty']?.toString(),
      );
      if (clientName == null) continue;
      final commercial = (row['commercial_material'] as Map?)
          ?.cast<String, dynamic>();
      final materialCode = _normalizePlanningMaterialCode(
        commercial?['code']?.toString(),
      );
      final option = materialCode == null
          ? null
          : directionShipmentMaterialByCode(materialCode);
      final baleTypeKey = materialCode == null
          ? null
          : _gerenciaBaleTypeKeyForMaterial(materialCode);
      if (option == null || !option.isPacked || baleTypeKey == null) continue;
      history.add(
        _ShipmentHistoryEvent(
          date: _parseDate(row['op_date']),
          clientName: clientName,
          materialCode: option.code,
          baleTypeKey: baleTypeKey,
          quantity: quantity,
        ),
      );
    }
    return history;
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
            'run:run_id(op_date,shift,notes,source_general_material:source_general_material_id(code))',
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
      final shiftKey = _normalizeShiftKey(run['shift']?.toString());

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
            shiftKey: shiftKey,
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
            shiftKey: shiftKey,
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
          .select('op_date,shift,bale_material,bale_count,notes')
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
          shiftKey: _normalizeShiftKey(row['shift']?.toString()),
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
    quantityByDateMaterialShift,
    required Map<DateTime, Map<String, Map<String, int>>>
    quantityByDateMaterialMachine,
    required Map<DateTime, Map<String, Map<String, Map<String, int>>>>
    quantityByDateMaterialMachineShift,
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
      final dayShiftExpectedByMaterial = <String, int>{};
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
        final dayBase = _averageQuantity(
          historyDates
              .map(
                (date) =>
                    quantityByDateMaterialShift[date]?[material.code]?['DAY'] ??
                    0,
              )
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
        final c1DayBase = _averageQuantity(
          historyDates
              .map(
                (date) =>
                    quantityByDateMaterialMachineShift[date]?[material
                        .code]?['c1']?['DAY'] ??
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
        final c2DayBase = _averageQuantity(
          historyDates
              .map(
                (date) =>
                    quantityByDateMaterialMachineShift[date]?[material
                        .code]?['c2']?['DAY'] ??
                    0,
              )
              .toList(growable: false),
        );
        final loss =
            _applyPercent(c1Base, c1Percent) + _applyPercent(c2Base, c2Percent);
        final dayLoss =
            _applyPercent(c1DayBase, c1Percent) +
            _applyPercent(c2DayBase, c2Percent);
        final expectedTotal = math.max(0, base - loss);
        final expectedDay = math.min(
          expectedTotal,
          math.max(0, dayBase - dayLoss),
        );
        expectedByMaterial[material.code] = expectedTotal;
        dayShiftExpectedByMaterial[material.code] = expectedDay;
        if (loss > 0) {
          lossByMaterial[material.code] = loss;
        }
      }

      days.add(
        DirectionProductionExpectationDay(
          date: day,
          expectedByMaterial: Map<String, int>.unmodifiable(expectedByMaterial),
          dayShiftExpectedByMaterial: Map<String, int>.unmodifiable(
            dayShiftExpectedByMaterial,
          ),
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
                !day.date.isBefore(today) && !day.date.isAfter(plan.shipDate),
          )
          .fold<int>(
            0,
            (sum, day) =>
                sum +
                _expectedShipmentUsableQuantityForDay(
                  day: day,
                  materialCode: materialCode,
                  shipDate: plan.shipDate,
                ),
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

  static List<DirectionSuggestedShipmentRecord> _buildSuggestedShipments({
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<DirectionShipmentPlanRecord> shipments,
    required Map<String, int> floorCounts,
    required List<DirectionProductionExpectationDay> expectedDays,
    required List<_GerenciaShipmentTargetLine> gerenciaTargets,
    required List<_ShipmentHistoryEvent> shipmentHistory,
  }) {
    final today = _dateOnly(DateTime.now());
    if (weekEnd.isBefore(today) || gerenciaTargets.isEmpty) {
      return const <DirectionSuggestedShipmentRecord>[];
    }

    final candidateDates = <DateTime>[
      for (
        var day = today.isAfter(weekStart) ? today : weekStart;
        !day.isAfter(weekEnd);
        day = day.add(const Duration(days: 1))
      )
        day,
    ];
    if (candidateDates.isEmpty) {
      return const <DirectionSuggestedShipmentRecord>[];
    }

    final actualByType = <String, int>{};
    for (final event in shipmentHistory) {
      if (event.date.isBefore(weekStart) || event.date.isAfter(weekEnd)) {
        continue;
      }
      actualByType.update(
        event.baleTypeKey,
        (value) => value + event.quantity,
        ifAbsent: () => event.quantity,
      );
    }

    final activeShipments = shipments
        .where((plan) => plan.isActive)
        .toList(growable: false);
    final plannedByType = <String, int>{};
    for (final plan in activeShipments) {
      final baleTypeKey = _gerenciaBaleTypeKeyForMaterial(plan.materialCode);
      if (baleTypeKey == null) continue;
      plannedByType.update(
        baleTypeKey,
        (value) => value + plan.plannedQuantity,
        ifAbsent: () => plan.plannedQuantity,
      );
    }

    final materialStats = _buildShipmentHistoryStatsByMaterial(shipmentHistory);
    final typeStats = _buildShipmentHistoryStatsByType(shipmentHistory);
    final suggestions = <DirectionSuggestedShipmentRecord>[];

    for (final target in gerenciaTargets) {
      var remainingTarget = math.max(
        0,
        target.shipmentTargetBales -
            (actualByType[target.baleTypeKey] ?? 0) -
            (plannedByType[target.baleTypeKey] ?? 0),
      );
      if (remainingTarget <= 0) continue;
      final materialChoices = _candidateMaterialsForGerenciaType(
        target.baleTypeKey,
      );
      if (materialChoices.isEmpty) continue;

      final candidates = _buildSuggestionCandidates(
        baleTypeKey: target.baleTypeKey,
        targetNotes: target.notes,
        materialChoices: materialChoices,
        floorCounts: floorCounts,
        expectedDays: expectedDays,
        materialStats: materialStats,
        typeStats: typeStats,
      );
      if (candidates.isEmpty) continue;

      for (var pass = 0; pass < 2 && remainingTarget > 0; pass++) {
        for (final candidate in candidates) {
          if (remainingTarget <= 0 || suggestions.length >= 8) {
            break;
          }
          final desiredQuantity = _desiredSuggestedBaleQuantity(
            remainingTarget: remainingTarget,
            historicalAverageQuantity: candidate.historicalAverageQuantity,
          );
          final dateFit = _selectSuggestionDateFit(
            materialCode: candidate.materialCode,
            quantityUnit: DirectionShipmentQuantityUnit.bales,
            desiredQuantity: desiredQuantity,
            candidateDates: candidateDates,
            floorCounts: floorCounts,
            expectedDays: expectedDays,
            activeShipments: activeShipments,
            acceptedSuggestions: suggestions,
          );
          if (dateFit == null) continue;
          final suggestedQuantity = math.min(
            remainingTarget,
            dateFit.maxRecommendedQuantity > 0
                ? math.min(desiredQuantity, dateFit.maxRecommendedQuantity)
                : math.min(desiredQuantity, dateFit.maxPossibleQuantity),
          );
          if (suggestedQuantity < 8) continue;
          final projectedAfter =
              dateFit.projectedAvailableBeforeQuantity - suggestedQuantity;
          final risk = _riskForSuggestedQuantity(
            materialCode: candidate.materialCode,
            quantityUnit: DirectionShipmentQuantityUnit.bales,
            plannedQuantity: suggestedQuantity,
            shipDate: dateFit.date,
            projectedAfter: projectedAfter,
            floorCounts: floorCounts,
          );
          suggestions.add(
            DirectionSuggestedShipmentRecord(
              suggestedDate: dateFit.date,
              clientName: candidate.clientName,
              materialCode: candidate.materialCode,
              materialScope: DirectionShipmentMaterialScope.commercial,
              quantityUnit: DirectionShipmentQuantityUnit.bales,
              suggestedQuantity: suggestedQuantity,
              projectedAvailableBeforeQuantity:
                  dateFit.projectedAvailableBeforeQuantity,
              projectedRemainingAfterQuantity: projectedAfter,
              expectedFutureQuantity: dateFit.expectedFutureQuantity,
              currentFloorQuantity: floorCounts[candidate.materialCode] ?? 0,
              remainingGerenciaTargetQuantity: remainingTarget,
              historicalAverageQuantity: candidate.historicalAverageQuantity,
              historicalShipmentCount: candidate.historicalShipmentCount,
              lastShipmentDate: candidate.lastShipmentDate,
              risk: risk,
              gerenciaBaleTypeKey: target.baleTypeKey,
              explanation: _buildSuggestionExplanation(
                targetBaleTypeKey: target.baleTypeKey,
                noteMatched: candidate.noteMatched,
                historicalShipmentCount: candidate.historicalShipmentCount,
                expectedFutureQuantity: dateFit.expectedFutureQuantity,
                projectedBeforeQuantity:
                    dateFit.projectedAvailableBeforeQuantity,
              ),
              noteMatched: candidate.noteMatched,
            ),
          );
          remainingTarget -= suggestedQuantity;
        }
      }
    }

    suggestions.sort((a, b) {
      final dateCompare = a.suggestedDate.compareTo(b.suggestedDate);
      if (dateCompare != 0) return dateCompare;
      final clientCompare = _priorityClientRank(
        a.clientName,
      ).compareTo(_priorityClientRank(b.clientName));
      if (clientCompare != 0) return clientCompare;
      return _materialSortOrder(
        a.materialCode,
      ).compareTo(_materialSortOrder(b.materialCode));
    });
    return suggestions;
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

class _GerenciaShipmentTargetLine {
  final String baleTypeKey;
  final int sortOrder;
  final int shipmentTargetBales;
  final String notes;

  const _GerenciaShipmentTargetLine({
    required this.baleTypeKey,
    required this.sortOrder,
    required this.shipmentTargetBales,
    required this.notes,
  });

  factory _GerenciaShipmentTargetLine.fromRow(Map<String, dynamic> row) {
    return _GerenciaShipmentTargetLine(
      baleTypeKey: (row['bale_type_key'] ?? '').toString().trim(),
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 100,
      shipmentTargetBales: (row['shipment_target_bales'] as num?)?.toInt() ?? 0,
      notes: (row['notes'] ?? '').toString().trim(),
    );
  }
}

class _ProductionEvent {
  final DateTime date;
  final String materialCode;
  final int quantity;
  final String shiftKey;
  final String? compactadoraKey;

  const _ProductionEvent({
    required this.date,
    required this.materialCode,
    required this.quantity,
    required this.shiftKey,
    required this.compactadoraKey,
  });
}

class _ShipmentHistoryEvent {
  final DateTime date;
  final String clientName;
  final String materialCode;
  final String baleTypeKey;
  final int quantity;

  const _ShipmentHistoryEvent({
    required this.date,
    required this.clientName,
    required this.materialCode,
    required this.baleTypeKey,
    required this.quantity,
  });
}

class _ShipmentHistoryStats {
  final String clientName;
  final String key;
  final int shipmentCount;
  final int totalQuantity;
  final DateTime? lastShipmentDate;
  final Map<int, int> weekdayCounts;

  const _ShipmentHistoryStats({
    required this.clientName,
    required this.key,
    required this.shipmentCount,
    required this.totalQuantity,
    required this.lastShipmentDate,
    required this.weekdayCounts,
  });

  int get averageQuantity =>
      shipmentCount <= 0 ? 0 : (totalQuantity / shipmentCount).round();
}

class _SuggestionCandidate {
  final String clientName;
  final String materialCode;
  final int historicalAverageQuantity;
  final int historicalShipmentCount;
  final DateTime? lastShipmentDate;
  final bool noteMatched;
  final double score;

  const _SuggestionCandidate({
    required this.clientName,
    required this.materialCode,
    required this.historicalAverageQuantity,
    required this.historicalShipmentCount,
    required this.lastShipmentDate,
    required this.noteMatched,
    required this.score,
  });
}

class _SuggestionDateFit {
  final DateTime date;
  final int projectedAvailableBeforeQuantity;
  final int expectedFutureQuantity;
  final int maxRecommendedQuantity;
  final int maxPossibleQuantity;

  const _SuggestionDateFit({
    required this.date,
    required this.projectedAvailableBeforeQuantity,
    required this.expectedFutureQuantity,
    required this.maxRecommendedQuantity,
    required this.maxPossibleQuantity,
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
  return _riskForSuggestedQuantity(
    materialCode: plan.materialCode,
    quantityUnit: plan.quantityUnit,
    plannedQuantity: plan.plannedQuantity,
    shipDate: plan.shipDate,
    projectedAfter: projectedAfter,
    floorCounts: floorCounts,
  );
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

Map<DateTime, Map<String, Map<String, int>>> _buildQuantityByDateMaterialShift(
  List<_ProductionEvent> events,
) {
  final byDate = <DateTime, Map<String, Map<String, int>>>{};
  for (final event in events) {
    final dateBucket = byDate.putIfAbsent(
      event.date,
      () => <String, Map<String, int>>{},
    );
    final materialBucket = dateBucket.putIfAbsent(
      event.materialCode,
      () => <String, int>{},
    );
    materialBucket.update(
      event.shiftKey,
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

Map<DateTime, Map<String, Map<String, Map<String, int>>>>
_buildQuantityByDateMaterialMachineShift(List<_ProductionEvent> events) {
  final byDate = <DateTime, Map<String, Map<String, Map<String, int>>>>{};
  for (final event in events) {
    final shares = _machineSharesForEvent(event);
    if (shares.isEmpty) continue;
    final dateBucket = byDate.putIfAbsent(
      event.date,
      () => <String, Map<String, Map<String, int>>>{},
    );
    final materialBucket = dateBucket.putIfAbsent(
      event.materialCode,
      () => <String, Map<String, int>>{},
    );
    for (final entry in shares.entries) {
      final machineBucket = materialBucket.putIfAbsent(
        entry.key,
        () => <String, int>{},
      );
      machineBucket.update(
        event.shiftKey,
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

int _expectedShipmentUsableQuantityForDay({
  required DirectionProductionExpectationDay day,
  required String materialCode,
  required DateTime shipDate,
}) {
  return day.date == shipDate
      ? day.dayShiftExpectedForMaterial(materialCode)
      : day.expectedForMaterial(materialCode);
}

Map<String, _ShipmentHistoryStats> _buildShipmentHistoryStatsByMaterial(
  List<_ShipmentHistoryEvent> history,
) {
  final totals = <String, int>{};
  final counts = <String, int>{};
  final lastDates = <String, DateTime>{};
  final weekdayCounts = <String, Map<int, int>>{};
  final clientNames = <String, String>{};
  for (final event in history) {
    final key = '${event.clientName}|${event.materialCode}';
    totals.update(
      key,
      (value) => value + event.quantity,
      ifAbsent: () => event.quantity,
    );
    counts.update(key, (value) => value + 1, ifAbsent: () => 1);
    clientNames[key] = event.clientName;
    final lastDate = lastDates[key];
    if (lastDate == null || event.date.isAfter(lastDate)) {
      lastDates[key] = event.date;
    }
    final weekdayBucket = weekdayCounts.putIfAbsent(key, () => <int, int>{});
    weekdayBucket.update(
      event.date.weekday,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }
  return {
    for (final key in counts.keys)
      key: _ShipmentHistoryStats(
        clientName: clientNames[key] ?? '',
        key: key,
        shipmentCount: counts[key] ?? 0,
        totalQuantity: totals[key] ?? 0,
        lastShipmentDate: lastDates[key],
        weekdayCounts: Map<int, int>.unmodifiable(
          weekdayCounts[key] ?? const {},
        ),
      ),
  };
}

Map<String, _ShipmentHistoryStats> _buildShipmentHistoryStatsByType(
  List<_ShipmentHistoryEvent> history,
) {
  final totals = <String, int>{};
  final counts = <String, int>{};
  final lastDates = <String, DateTime>{};
  final weekdayCounts = <String, Map<int, int>>{};
  final clientNames = <String, String>{};
  for (final event in history) {
    final key = '${event.clientName}|${event.baleTypeKey}';
    totals.update(
      key,
      (value) => value + event.quantity,
      ifAbsent: () => event.quantity,
    );
    counts.update(key, (value) => value + 1, ifAbsent: () => 1);
    clientNames[key] = event.clientName;
    final lastDate = lastDates[key];
    if (lastDate == null || event.date.isAfter(lastDate)) {
      lastDates[key] = event.date;
    }
    final weekdayBucket = weekdayCounts.putIfAbsent(key, () => <int, int>{});
    weekdayBucket.update(
      event.date.weekday,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }
  return {
    for (final key in counts.keys)
      key: _ShipmentHistoryStats(
        clientName: clientNames[key] ?? '',
        key: key,
        shipmentCount: counts[key] ?? 0,
        totalQuantity: totals[key] ?? 0,
        lastShipmentDate: lastDates[key],
        weekdayCounts: Map<int, int>.unmodifiable(
          weekdayCounts[key] ?? const {},
        ),
      ),
  };
}

List<_SuggestionCandidate> _buildSuggestionCandidates({
  required String baleTypeKey,
  required String targetNotes,
  required List<String> materialChoices,
  required Map<String, int> floorCounts,
  required List<DirectionProductionExpectationDay> expectedDays,
  required Map<String, _ShipmentHistoryStats> materialStats,
  required Map<String, _ShipmentHistoryStats> typeStats,
}) {
  final candidates = <_SuggestionCandidate>[];
  for (final clientName in _kPriorityShipmentClients) {
    final noteMatched = _notesMentionClient(targetNotes, clientName);
    _SuggestionCandidate? bestCandidate;
    for (final materialCode in materialChoices) {
      final directStats = materialStats['$clientName|$materialCode'];
      final familyStats = typeStats['$clientName|$baleTypeKey'];
      if (directStats == null && familyStats == null && !noteMatched) {
        continue;
      }
      final projectedAtWeekEnd = _expectedFutureQuantityThroughDate(
        expectedDays: expectedDays,
        materialCode: materialCode,
        shipDate: expectedDays.isEmpty
            ? _dateOnly(DateTime.now())
            : expectedDays.last.date,
      );
      final historyCount =
          directStats?.shipmentCount ?? familyStats?.shipmentCount ?? 0;
      final historyAverage =
          directStats?.averageQuantity ?? familyStats?.averageQuantity ?? 0;
      final lastShipmentDate =
          directStats?.lastShipmentDate ?? familyStats?.lastShipmentDate;
      final availability =
          (floorCounts[materialCode] ?? 0) + projectedAtWeekEnd;
      final score =
          (_kPriorityShipmentClients.length - _priorityClientRank(clientName)) *
              100 +
          (noteMatched ? 40 : 0) +
          (historyCount * 6) +
          historyAverage +
          availability;
      final candidate = _SuggestionCandidate(
        clientName: clientName,
        materialCode: materialCode,
        historicalAverageQuantity: historyAverage,
        historicalShipmentCount: historyCount,
        lastShipmentDate: lastShipmentDate,
        noteMatched: noteMatched,
        score: score.toDouble(),
      );
      if (bestCandidate == null || candidate.score > bestCandidate.score) {
        bestCandidate = candidate;
      }
    }
    if (bestCandidate != null) {
      candidates.add(bestCandidate);
    }
  }
  candidates.sort((a, b) {
    final clientCompare = _priorityClientRank(
      a.clientName,
    ).compareTo(_priorityClientRank(b.clientName));
    if (clientCompare != 0) return clientCompare;
    return b.score.compareTo(a.score);
  });
  return candidates;
}

_SuggestionDateFit? _selectSuggestionDateFit({
  required String materialCode,
  required DirectionShipmentQuantityUnit quantityUnit,
  required int desiredQuantity,
  required List<DateTime> candidateDates,
  required Map<String, int> floorCounts,
  required List<DirectionProductionExpectationDay> expectedDays,
  required List<DirectionShipmentPlanRecord> activeShipments,
  required List<DirectionSuggestedShipmentRecord> acceptedSuggestions,
}) {
  _SuggestionDateFit? bestFit;
  for (final date in candidateDates) {
    final priorCommitted = _committedQuantityThroughDate(
      materialCode: materialCode,
      shipDate: date,
      activeShipments: activeShipments,
      acceptedSuggestions: acceptedSuggestions,
    );
    final expectedFuture = _expectedFutureQuantityThroughDate(
      expectedDays: expectedDays,
      materialCode: materialCode,
      shipDate: date,
    );
    final projectedBefore =
        (floorCounts[materialCode] ?? 0) + expectedFuture - priorCommitted;
    final maxPossible = math.max(0, projectedBefore);
    final safetyMargin = quantityUnit == DirectionShipmentQuantityUnit.kilograms
        ? 250
        : 5;
    final maxRecommended = math.max(0, projectedBefore - safetyMargin);
    final fit = _SuggestionDateFit(
      date: date,
      projectedAvailableBeforeQuantity: projectedBefore,
      expectedFutureQuantity: expectedFuture,
      maxRecommendedQuantity: maxRecommended,
      maxPossibleQuantity: maxPossible,
    );
    if (maxRecommended >= desiredQuantity) {
      return fit;
    }
    if (bestFit == null ||
        fit.maxRecommendedQuantity > bestFit.maxRecommendedQuantity ||
        (fit.maxRecommendedQuantity == bestFit.maxRecommendedQuantity &&
            fit.maxPossibleQuantity > bestFit.maxPossibleQuantity) ||
        (fit.maxRecommendedQuantity == bestFit.maxRecommendedQuantity &&
            fit.maxPossibleQuantity == bestFit.maxPossibleQuantity &&
            fit.date.isBefore(bestFit.date))) {
      bestFit = fit;
    }
  }
  if (bestFit == null || bestFit.maxPossibleQuantity <= 0) {
    return null;
  }
  return bestFit;
}

int _committedQuantityThroughDate({
  required String materialCode,
  required DateTime shipDate,
  required List<DirectionShipmentPlanRecord> activeShipments,
  required List<DirectionSuggestedShipmentRecord> acceptedSuggestions,
}) {
  var committed = 0;
  for (final plan in activeShipments) {
    if (plan.materialCode != materialCode || plan.shipDate.isAfter(shipDate)) {
      continue;
    }
    committed += plan.plannedQuantity;
  }
  for (final suggestion in acceptedSuggestions) {
    if (suggestion.materialCode != materialCode ||
        suggestion.suggestedDate.isAfter(shipDate)) {
      continue;
    }
    committed += suggestion.suggestedQuantity;
  }
  return committed;
}

int _expectedFutureQuantityThroughDate({
  required List<DirectionProductionExpectationDay> expectedDays,
  required String materialCode,
  required DateTime shipDate,
}) {
  final today = _dateOnly(DateTime.now());
  return expectedDays
      .where((day) => !day.date.isBefore(today) && !day.date.isAfter(shipDate))
      .fold<int>(
        0,
        (sum, day) =>
            sum +
            _expectedShipmentUsableQuantityForDay(
              day: day,
              materialCode: materialCode,
              shipDate: shipDate,
            ),
      );
}

int _desiredSuggestedBaleQuantity({
  required int remainingTarget,
  required int historicalAverageQuantity,
}) {
  if (remainingTarget <= 0) return 0;
  if (historicalAverageQuantity > 0) {
    return math.max(8, math.min(remainingTarget, historicalAverageQuantity));
  }
  if (remainingTarget >= 34) return 36;
  if (remainingTarget >= 17) return 18;
  return math.max(8, remainingTarget);
}

DirectionShipmentRisk _riskForSuggestedQuantity({
  required String materialCode,
  required DirectionShipmentQuantityUnit quantityUnit,
  required int plannedQuantity,
  required DateTime shipDate,
  required int projectedAfter,
  required Map<String, int> floorCounts,
}) {
  final today = _dateOnly(DateTime.now());
  if (!floorCounts.containsKey(materialCode)) {
    return DirectionShipmentRisk.unknown;
  }
  if (shipDate.isBefore(today)) {
    return projectedAfter < 0
        ? DirectionShipmentRisk.atRisk
        : DirectionShipmentRisk.overdue;
  }
  if (projectedAfter < 0) {
    return DirectionShipmentRisk.atRisk;
  }
  final margin = quantityUnit == DirectionShipmentQuantityUnit.kilograms
      ? math.max(250, (plannedQuantity * 0.12).round())
      : math.max(5, (plannedQuantity * 0.15).round());
  if (projectedAfter < margin) {
    return DirectionShipmentRisk.tight;
  }
  return DirectionShipmentRisk.good;
}

List<String> _candidateMaterialsForGerenciaType(String baleTypeKey) {
  switch (baleTypeKey.trim().toLowerCase()) {
    case 'limpio':
      return const <String>['PACA_LIMPIA'];
    case 'americano':
      return const <String>['PACA_AMERICANA'];
    case 'revuelto':
      return const <String>['PACA_NACIONAL', 'PACA_BASURA'];
    default:
      return const <String>[];
  }
}

String _buildSuggestionExplanation({
  required String targetBaleTypeKey,
  required bool noteMatched,
  required int historicalShipmentCount,
  required int expectedFutureQuantity,
  required int projectedBeforeQuantity,
}) {
  final parts = <String>[
    'Meta ${_gerenciaBaleTypeLabel(targetBaleTypeKey)} pendiente',
    'proyección ${projectedBeforeQuantity.toString()} pacas',
  ];
  if (expectedFutureQuantity > 0) {
    parts.add('+${expectedFutureQuantity.toString()} pacas futuras');
  }
  if (historicalShipmentCount > 0) {
    parts.add('$historicalShipmentCount salidas históricas');
  }
  if (noteMatched) {
    parts.add('mencionado en nota de Gerencia');
  }
  return parts.join(' · ');
}

String _gerenciaBaleTypeLabel(String baleTypeKey) {
  switch (baleTypeKey.trim().toLowerCase()) {
    case 'limpio':
      return 'Limpio';
    case 'americano':
      return 'Americano';
    case 'revuelto':
      return 'Revuelto';
    default:
      return baleTypeKey;
  }
}

String? _gerenciaBaleTypeKeyForMaterial(String materialCode) {
  switch (_normalizePlanningMaterialCode(materialCode)) {
    case 'PACA_LIMPIA':
      return 'limpio';
    case 'PACA_AMERICANA':
      return 'americano';
    case 'PACA_NACIONAL':
    case 'PACA_BASURA':
      return 'revuelto';
    default:
      return null;
  }
}

int _priorityClientRank(String clientName) {
  final normalized = _canonicalPriorityClientName(clientName) ?? clientName;
  final index = _kPriorityShipmentClients.indexOf(normalized);
  return index == -1 ? _kPriorityShipmentClients.length + 1 : index;
}

bool _notesMentionClient(String notes, String clientName) {
  final normalizedNotes = _normalizeSearchText(notes);
  if (normalizedNotes.isEmpty) return false;
  final aliases = _kPriorityShipmentClientAliases[clientName] ?? <String>[];
  return aliases.any(
    (alias) => normalizedNotes.contains(_normalizeSearchText(alias)),
  );
}

String? _canonicalPriorityClientName(String? rawClientName) {
  final normalized = _normalizeSearchText(rawClientName);
  if (normalized.isEmpty) return null;
  for (final entry in _kPriorityShipmentClientAliases.entries) {
    for (final alias in entry.value) {
      if (normalized.contains(_normalizeSearchText(alias))) {
        return entry.key;
      }
    }
  }
  return null;
}

String _normalizeSearchText(String? raw) {
  final upper = (raw ?? '').trim().toUpperCase();
  if (upper.isEmpty) return '';
  return upper
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('Ü', 'U')
      .replaceAll('Ñ', 'N')
      .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _normalizeShiftKey(String? rawShift) {
  return (rawShift ?? '').trim().toUpperCase() == 'NIGHT' ? 'NIGHT' : 'DAY';
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
