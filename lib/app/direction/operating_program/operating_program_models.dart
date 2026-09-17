import 'dart:convert';
import 'dart:math' as math;

import '../direction_shipments_store.dart';

const programMaterials = ['PACA_NACIONAL', 'PACA_LIMPIA', 'PACA_AMERICANA'];
const programMaterialNames = ['Nacional', 'Limpio', 'Americano'];
const programDayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];
const programShifts = ['DAY', 'NIGHT'];
String programDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class ProgramDemand {
  final String id, destination, material, priority;
  final DateTime date;
  final int quantity;
  const ProgramDemand({
    required this.id,
    required this.destination,
    required this.material,
    required this.date,
    required this.quantity,
    this.priority = 'normal',
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': programDate(date),
    'destination': destination,
    'material': material,
    'quantity': quantity,
    'priority': priority,
  };
  factory ProgramDemand.fromJson(Map<String, dynamic> json) => ProgramDemand(
    id: json['id'] as String,
    destination: json['destination'] as String,
    material: json['material'] as String,
    date: DateTime.parse(json['date'] as String),
    quantity: (json['quantity'] as num).toInt(),
    priority: json['priority'] as String,
  );
  static List<ProgramDemand> fromShipments(
    DateTime week,
    Iterable<DirectionShipmentPlanRecord> shipments,
  ) => shipments
      .where(
        (s) =>
            s.status == 'confirmado' &&
            s.quantityUnit == DirectionShipmentQuantityUnit.bales &&
            programMaterials.contains(s.materialCode) &&
            !s.shipDate.isBefore(week) &&
            s.shipDate.isBefore(week.add(const Duration(days: 5))),
      )
      .map(
        (s) => ProgramDemand(
          id: s.id,
          destination: s.clientName,
          material: s.materialCode,
          date: s.shipDate,
          quantity: s.plannedQuantity,
          priority: s.priority,
        ),
      )
      .toList();
}

String programDemandFingerprint(List<ProgramDemand> demands) {
  final ordered = [...demands]..sort((a, b) => a.id.compareTo(b.id));
  return jsonEncode(ordered.map((d) => d.toJson()).toList());
}

class ProgramDayCondition {
  final bool working, dayAvailable, nightAvailable;
  final int lossPercent;
  final String machineryNote;
  const ProgramDayCondition({
    this.working = true,
    this.dayAvailable = true,
    this.nightAvailable = true,
    this.lossPercent = 0,
    this.machineryNote = '',
  });
  ProgramDayCondition copyWith({
    bool? working,
    bool? dayAvailable,
    bool? nightAvailable,
  }) => ProgramDayCondition(
    working: working ?? this.working,
    dayAvailable: dayAvailable ?? this.dayAvailable,
    nightAvailable: nightAvailable ?? this.nightAvailable,
    lossPercent: lossPercent,
    machineryNote: machineryNote,
  );
  Map<String, dynamic> toJson() => {
    'working': working,
    'day_available': dayAvailable,
    'night_available': nightAvailable,
    'loss_percent': lossPercent,
    'machinery_note': machineryNote,
  };
  factory ProgramDayCondition.fromJson(Map<String, dynamic> j) =>
      ProgramDayCondition(
        working: j['working'] as bool,
        dayAvailable: j['day_available'] as bool,
        nightAvailable: j['night_available'] as bool,
        lossPercent: (j['loss_percent'] as num).toInt(),
        machineryNote: j['machinery_note'] as String? ?? '',
      );
}

/// A frozen reference from the six completed weeks preceding the program.
/// Quantities here are observations, never additional shipment requirements.
class ProgramProductionHistory {
  final DateTime start, end;
  final List<String> observedWeeks;
  final List<ProgramLine> totals;
  final int recordCount, legacyRecordCount, unknownShiftCount;
  const ProgramProductionHistory({
    required this.start,
    required this.end,
    required this.observedWeeks,
    required this.totals,
    required this.recordCount,
    this.legacyRecordCount = 0,
    this.unknownShiftCount = 0,
  });

  bool get hasData => observedWeeks.isNotEmpty && recordCount > 0;
  int total({int? day, int? shift, String? material}) => totals
      .where(
        (l) =>
            (day == null || l.day == day) &&
            (shift == null || l.shift == shift) &&
            (material == null || l.material == material),
      )
      .fold(0, (sum, line) => sum + line.quantity);
  double average({int? day, int? shift, String? material}) => hasData
      ? total(day: day, shift: shift, material: material) / observedWeeks.length
      : 0;
  int get dayShare => hasData ? (100 * total(shift: 0) / total()).round() : 50;

  // Prefer the observed cell, then the same material's shift across weekdays.
  // A material absent from history uses the overall production pattern and is
  // explicitly reported as having no material-specific reference.
  double preference(int day, int shift, String material) {
    if (total(material: material) == 0) {
      return math.max(0.001, average(day: day, shift: shift));
    }
    return math.max(
      0.001,
      average(day: day, shift: shift, material: material) * 0.8 +
          average(shift: shift, material: material) / 5 * 0.2,
    );
  }

  factory ProgramProductionHistory.fromRecords(
    DateTime week,
    List<DirectionProductionHistoryRecord> records,
  ) {
    final start = week.subtract(const Duration(days: 42));
    final totals = <String, int>{};
    final weeks = <String>{};
    var count = 0, legacy = 0, unknown = 0;
    for (final record in records) {
      if (record.date.isBefore(start) ||
          !record.date.isBefore(week) ||
          record.date.weekday > 5 ||
          record.quantity <= 0 ||
          !programMaterials.contains(record.materialCode)) {
        continue;
      }
      final shift = programShifts.indexOf(record.shiftKey);
      if (shift < 0) {
        unknown++;
        continue;
      }
      final day = record.date.weekday - 1;
      weeks.add(programDate(record.date.subtract(Duration(days: day))));
      final key = '$day:$shift:${record.materialCode}';
      totals[key] = (totals[key] ?? 0) + record.quantity;
      count++;
      if (record.source == 'production_runs') legacy++;
    }
    return ProgramProductionHistory(
      start: start,
      end: week.subtract(const Duration(days: 1)),
      observedWeeks: weeks.toList()..sort(),
      recordCount: count,
      legacyRecordCount: legacy,
      unknownShiftCount: unknown,
      totals: [
        for (var d = 0; d < 5; d++)
          for (var s = 0; s < 2; s++)
            for (final m in programMaterials)
              ProgramLine(d, s, m, totals['$d:$s:$m'] ?? 0),
      ],
    );
  }
  Map<String, dynamic> toJson() => {
    'start': programDate(start),
    'end': programDate(end),
    'observed_weeks': observedWeeks,
    'record_count': recordCount,
    'legacy_record_count': legacyRecordCount,
    'unknown_shift_count': unknownShiftCount,
    'totals': totals.map((l) => l.toJson()).toList(),
  };
  factory ProgramProductionHistory.fromJson(Map<String, dynamic> j) =>
      ProgramProductionHistory(
        start: DateTime.parse(j['start'] as String),
        end: DateTime.parse(j['end'] as String),
        observedWeeks: List<String>.from(j['observed_weeks'] as List),
        recordCount: (j['record_count'] as num).toInt(),
        legacyRecordCount: (j['legacy_record_count'] as num?)?.toInt() ?? 0,
        unknownShiftCount: (j['unknown_shift_count'] as num?)?.toInt() ?? 0,
        totals: (j['totals'] as List)
            .map(
              (l) => ProgramLine.fromJson(Map<String, dynamic>.from(l as Map)),
            )
            .toList(),
      );
}

class ProgramConditions {
  final int dailyCapacity, dayShare;
  final Map<String, int> yard;
  final List<ProgramDayCondition> days;
  final ProgramProductionHistory? history;
  const ProgramConditions({
    required this.yard,
    required this.days,
    this.dailyCapacity = 100,
    this.dayShare = 50,
    this.history,
  });
  ProgramConditions copyWith({
    int? dailyCapacity,
    int? dayShare,
    Map<String, int>? yard,
    List<ProgramDayCondition>? days,
    ProgramProductionHistory? history,
  }) => ProgramConditions(
    yard: yard ?? this.yard,
    days: days ?? this.days,
    dailyCapacity: dailyCapacity ?? this.dailyCapacity,
    dayShare: dayShare ?? this.dayShare,
    history: history ?? this.history,
  );
  int machineCapacity(int day) =>
      (dailyCapacity * (100 - days[day].lossPercent) / 100).floor();
  int slotCapacity(int day, int shift) {
    final condition = days[day];
    if (!condition.working ||
        (shift == 0 ? !condition.dayAvailable : !condition.nightAvailable)) {
      return 0;
    }
    final capacity = machineCapacity(day);
    final dayCapacity = (capacity * dayShare / 100).round();
    return shift == 0 ? dayCapacity : capacity - dayCapacity;
  }

  int available(int day) => slotCapacity(day, 0) + slotCapacity(day, 1);
  int get totalAvailable =>
      List.generate(5, available).fold(0, (a, b) => a + b);
  Map<String, dynamic> toJson() => {
    'daily_capacity': dailyCapacity,
    'day_share': dayShare,
    'yard': {for (final m in programMaterials) m: yard[m] ?? 0},
    'days': days.map((d) => d.toJson()).toList(),
    if (history != null) 'production_history': history!.toJson(),
  };
  factory ProgramConditions.fromJson(Map<String, dynamic> j) =>
      ProgramConditions(
        dailyCapacity: (j['daily_capacity'] as num).toInt(),
        dayShare: (j['day_share'] as num).toInt(),
        history: j['production_history'] is Map
            ? ProgramProductionHistory.fromJson(
                Map<String, dynamic>.from(j['production_history'] as Map),
              )
            : null,
        yard: (j['yard'] as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ),
        days: (j['days'] as List)
            .map(
              (d) => ProgramDayCondition.fromJson(
                Map<String, dynamic>.from(d as Map),
              ),
            )
            .toList(),
      );
  void validate() {
    if (dailyCapacity < 1 ||
        dailyCapacity > 10000 ||
        dayShare < 0 ||
        dayShare > 100 ||
        days.length != 5 ||
        programMaterials.any((m) => (yard[m] ?? -1) < 0) ||
        days.any((d) => d.lossPercent < 0 || d.lossPercent > 100)) {
      throw ArgumentError(
        'Revisa capacidad, patio y condiciones de los cinco días.',
      );
    }
  }

  factory ProgramConditions.fromReference(
    DirectionShipmentPlanningBundle bundle,
  ) {
    final history = ProgramProductionHistory.fromRecords(
      bundle.weekStartDate,
      bundle.productionHistory,
    );
    return ProgramConditions(
      yard: {for (final m in programMaterials) m: 0},
      dayShare: history.dayShare,
      history: history,
      days: List.generate(5, (d) {
        final date = bundle.weekStartDate.add(Duration(days: d));
        final impacts = bundle.activeCapacityImpacts.where(
          (i) => i.isActive && i.overlaps(date),
        );
        var c1 = 0, c2 = 0;
        for (final impact in impacts) {
          if (impact.machineKey == 'c1' || impact.machineKey == 'ambas') {
            c1 += impact.impactPercent;
          }
          if (impact.machineKey == 'c2' || impact.machineKey == 'ambas') {
            c2 += impact.impactPercent;
          }
        }
        // Nominal capacity is shared equally by the two compactors. The
        // historical output is a reference, never the shipment requirement.
        return ProgramDayCondition(
          lossPercent: ((math.min(100, c1) + math.min(100, c2)) / 2).ceil(),
          machineryNote: impacts
              .map(
                (i) =>
                    '${directionMachineKeyLabel(i.machineKey)}: ${i.impactPercent}%',
              )
              .join(' · '),
        );
      }),
    );
  }
}

class ProgramLine {
  final int day, shift, quantity;
  final String material;
  const ProgramLine(this.day, this.shift, this.material, this.quantity);
  String get key => '$day:$shift:$material';
  Map<String, dynamic> toJson() => {
    'day_index': day,
    'shift': programShifts[shift],
    'material_code': material,
    'quantity': quantity,
  };
  factory ProgramLine.fromJson(Map<String, dynamic> j) => ProgramLine(
    (j['day_index'] as num).toInt(),
    programShifts.indexOf(j['shift'] as String),
    j['material_code'] as String,
    (j['quantity'] as num).toInt(),
  );
}

class OperatingProgram {
  final String id, status;
  final DateTime week;
  final int version;
  final bool operational;
  final ProgramConditions conditions;
  final List<ProgramDemand> demands;
  final List<ProgramLine> lines;
  final String createdAt;
  const OperatingProgram({
    required this.id,
    required this.week,
    required this.version,
    required this.status,
    required this.conditions,
    required this.demands,
    required this.lines,
    this.operational = false,
    this.createdAt = '',
  });
  String get statusLabel => switch (status) {
    'approved' => 'Aprobado',
    'executing' => 'En ejecución',
    _ => 'Borrador',
  };
  factory OperatingProgram.fromJson(Map<String, dynamic> j) => OperatingProgram(
    id: j['id'] as String,
    week: DateTime.parse(j['week_start'] as String),
    version: (j['version'] as num).toInt(),
    status: j['status'] as String,
    operational: j['is_operational'] as bool? ?? false,
    createdAt: j['created_at'] as String? ?? '',
    conditions: ProgramConditions.fromJson(
      Map<String, dynamic>.from(j['conditions'] as Map),
    ),
    demands: (j['shipments'] as List)
        .map((d) => ProgramDemand.fromJson(Map<String, dynamic>.from(d as Map)))
        .toList(),
    lines: (j['lines'] as List)
        .map((d) => ProgramLine.fromJson(Map<String, dynamic>.from(d as Map)))
        .toList(),
  );
}
