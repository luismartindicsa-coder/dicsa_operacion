import 'human_resources_period_context.dart';

/// Returns existing operational periods only; an import never invents a week.
List<String> matchingHrImportPeriods({
  required Iterable<String> existingPeriodLabels,
  required bool isNgteco,
  required String filePeriodLabel,
  required Iterable<DateTime> punchDates,
}) {
  final fileRange = HumanResourcesPeriodRange.tryParse(filePeriodLabel);
  final dates = punchDates
      .map((d) => DateTime(d.year, d.month, d.day))
      .toList();
  return existingPeriodLabels
      .where((label) {
        final range = HumanResourcesPeriodRange.tryParse(label);
        if (range == null) return false;
        if (!isNgteco) {
          return fileRange != null &&
              range.start == fileRange.start &&
              range.end == fileRange.end;
        }
        return dates.any(
          (date) => !date.isBefore(range.start) && !date.isAfter(range.end),
        );
      })
      .toSet()
      .toList()
    ..sort();
}
