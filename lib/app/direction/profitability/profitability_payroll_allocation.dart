import 'profitability_models.dart';

/// Catalog names are used transiently to infer a role, never retained in the
/// analysis. Unique multiword abbreviations are evidence, not a verified job.
void inferProfitPayrollRoles(Map<String, List<ProfitRow>> tables) {
  final profiles = tables['hr_employee_profiles'] ?? [];
  final drivers = (tables['employees'] ?? [])
      .where((r) => r['is_driver'] == true)
      .toList();
  Set<String> tokens(Object? raw) => profitKey(raw)
      .replaceAll('Ñ', 'N')
      .replaceAll(RegExp('[^A-Z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where(
        (t) => t.isNotEmpty && !['DE', 'DEL', 'LA', 'LAS', 'LOS'].contains(t),
      )
      .toSet();
  final candidates = <String, List<String>>{};
  for (final driver in drivers) {
    final name = tokens(driver['full_name']);
    if (name.length < 2) continue;
    final matches = profiles.where((p) {
      final other = tokens(p['nombre']);
      return other.containsAll(name);
    }).toList();
    if (matches.length == 1) {
      (candidates[profitText(matches.single['id'])] ??= []).add(
        profitText(driver['id']),
      );
    }
  }
  tables['hr_employee_profiles'] = [
    for (final p in profiles)
      {...p}
        ..remove('nombre')
        ..['profit_payroll_role'] = candidates[profitText(p['id'])]?.length == 1
            ? 'driver'
            : 'unclassified'
        ..['profit_role_basis'] = candidates[profitText(p['id'])]?.length == 1
            ? 'unique_catalog_name_inference'
            : 'no_unambiguous_role',
  ];
  // Keep catalog counts/evidence without personal names in snapshots or hashes.
  tables['employees'] = [
    for (final d in drivers) {'id': d['id'], 'is_driver': true},
  ];
}

class ProfitPayrollActivity {
  final String company;
  final double kg, movements, trips, kilometers;
  const ProfitPayrollActivity(
    this.company, {
    required this.kg,
    required this.movements,
    required this.trips,
    required this.kilometers,
  });
}

class ProfitPayrollShare {
  final double share;
  final String rule;
  final bool fallback;
  const ProfitPayrollShare(this.share, this.rule, {this.fallback = false});
}

/// Average of normalized proportions, never kg + km or kg + document counts.
/// Each available measure contributes equally. No permanent customer category
/// excludes an account: its activity in the selected period sets the share.
Map<String, ProfitPayrollShare> profitPayrollShares(
  List<ProfitPayrollActivity> activity, {
  required bool drivers,
}) {
  if (activity.isEmpty) return {};
  for (final a in activity) {
    if ([
      a.kg,
      a.movements,
      a.trips,
      a.kilometers,
    ].any((v) => !v.isFinite || v < 0)) {
      throw StateError(
        'La base de reparto de nómina debe ser finita y no negativa.',
      );
    }
  }
  double first(ProfitPayrollActivity a) => drivers ? a.trips : a.kg;
  double second(ProfitPayrollActivity a) =>
      drivers ? a.kilometers : a.movements;
  final sumFirst = activity.fold<double>(0, (s, a) => s + first(a));
  final sumSecond = activity.fold<double>(0, (s, a) => s + second(a));
  if (sumFirst <= 0 && sumSecond <= 0) {
    return {
      for (final a in activity)
        a.company: ProfitPayrollShare(
          0,
          'Sin ${drivers ? 'viajes ni km' : 'kg ni movimientos'}: capacidad sin actividad atribuida; se conserva como costo de estructura fuera de las cuentas.',
          fallback: true,
        ),
    };
  }
  final measures = (sumFirst > 0 ? 1 : 0) + (sumSecond > 0 ? 1 : 0);
  String n(double v) => v.toStringAsFixed(2);
  return {
    for (final a in activity)
      a.company: ProfitPayrollShare(
        ((sumFirst > 0 ? first(a) / sumFirst : 0) +
                (sumSecond > 0 ? second(a) / sumSecond : 0)) /
            measures,
        '${drivers ? 'Transporte' : 'Patio y soporte sin puesto desglosado'}: '
        '${measures == 2 ? 'promedio de dos proporciones con igual peso' : 'única base disponible'}; '
        '${[if (sumFirst > 0) '${n(first(a))} / ${n(sumFirst)} ${drivers ? 'viajes' : 'kg'}', if (sumSecond > 0) '${n(second(a))} / ${n(sumSecond)} ${drivers ? 'km' : 'movimientos'}'].join('; ')}. '
        'Base operativa inferida; no son horas medidas.',
      ),
  };
}
