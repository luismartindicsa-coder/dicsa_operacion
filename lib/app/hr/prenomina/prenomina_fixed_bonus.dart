part of '../human_resources_prenomina_page.dart';

// Stored in the existing draft snapshot, atomically with manual_bonus_amount.
// False is an explicit stop; older snapshots without this key are not settings.
const _kPrenominaFixedBonus = 'manual_bonus_fixed';

Map<String, _HrPrenominaDraftRowRecord> _prenominaFixedBonusesBefore(
  List<_HrPrenominaDraftRowRecord> drafts,
  HumanResourcesPeriodRange? activeRange,
) {
  if (activeRange == null) return {};
  final candidates =
      <(_HrPrenominaDraftRowRecord, HumanResourcesPeriodRange)>[];
  for (final draft in drafts) {
    if (draft.sourceSnapshot[_kPrenominaFixedBonus] is! bool) continue;
    final range = HumanResourcesPeriodRange.tryParse(draft.periodLabel);
    if (range != null && range.end.isBefore(activeRange.start)) {
      candidates.add((draft, range));
    }
  }
  candidates.sort((a, b) {
    final byEnd = a.$2.end.compareTo(b.$2.end);
    if (byEnd != 0) return byEnd;
    final byStart = a.$2.start.compareTo(b.$2.start);
    return byStart != 0
        ? byStart
        : a.$1.periodLabel.compareTo(b.$1.periodLabel);
  });
  return {
    for (final candidate in candidates) candidate.$1.employeeId: candidate.$1,
  };
}
