import '../gerencia/gerencia_bale_weekly_tracking_store.dart';

class GerenciaWeeklyGoal {
  const GerenciaWeeklyGoal({
    required this.material,
    required this.front,
    required this.actual,
    required this.target,
    required this.daysElapsed,
    required this.totalDays,
    required this.notes,
  });
  final String material, front, notes;
  final int actual, daysElapsed, totalDays;
  final int? target;
  bool get hasTarget => target != null && target! > 0;
  int? get expected =>
      hasTarget ? (target! * daysElapsed / totalDays).round() : null;
  int? get gap => hasTarget ? actual - expected! : null;
  int? get remaining => hasTarget ? (target! - actual).clamp(0, target!) : null;
  double? get progress => hasTarget ? actual / target! * 100 : null;
  int get projected =>
      daysElapsed > 0 ? (actual / daysElapsed * totalDays).round() : actual;
  int? get requiredPerDay => hasTarget && totalDays > daysElapsed
      ? (remaining! / (totalDays - daysElapsed)).ceil()
      : null;
  String get state => !hasTarget
      ? 'Sin meta definida'
      : actual >= target!
      ? 'Meta alcanzada'
      : daysElapsed >= totalDays
      ? 'Meta no alcanzada'
      : gap! < 0
      ? 'Debajo del ritmo'
      : 'En ritmo';
  int get priority => !hasTarget
      ? 0
      : gap! < 0
      ? 1
      : 2;
}

class GerenciaWeeklyAnalysis {
  GerenciaWeeklyAnalysis(this.bundle, DateTime reference) {
    final referenceDay = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );
    cutoff = referenceDay.isAfter(bundle.weekEndDate)
        ? bundle.weekEndDate
        : referenceDay;
    final totalDays =
        bundle.weekEndDate.difference(bundle.weekStartDate).inDays + 1;
    final elapsed = (cutoff.difference(bundle.weekStartDate).inDays + 1).clamp(
      0,
      totalDays,
    );
    goals = [
      for (final line in bundle.lineSummaries) ...[
        for (final production in [true, false])
          GerenciaWeeklyGoal(
            material: line.baleType.label,
            front: production ? 'Produccion' : 'Embarque',
            actual: line.dailyActuals
                .where(
                  (d) =>
                      !d.opDate.isAfter(cutoff) &&
                      !d.opDate.isBefore(bundle.weekStartDate),
                )
                .fold<int>(
                  0,
                  (sum, d) =>
                      sum + (production ? d.productionBales : d.shipmentBales),
                ),
            target: line.planLine == null
                ? null
                : production
                ? line.productionTargetBales
                : line.shipmentTargetBales,
            daysElapsed: elapsed,
            totalDays: totalDays,
            notes: line.planLine?.notes ?? '',
          ),
      ],
    ];
  }
  final GerenciaBaleWeeklyTrackingBundle bundle;
  late final DateTime cutoff;
  late final List<GerenciaWeeklyGoal> goals;
  List<GerenciaWeeklyGoal> get priorities =>
      goals.where((g) => !g.hasTarget || g.gap! < 0).toList()..sort((a, b) {
        final p = a.priority.compareTo(b.priority);
        return p != 0 ? p : (a.gap ?? 0).compareTo(b.gap ?? 0);
      });
  int actual(String front) =>
      goals.where((g) => g.front == front).fold(0, (s, g) => s + g.actual);
}
