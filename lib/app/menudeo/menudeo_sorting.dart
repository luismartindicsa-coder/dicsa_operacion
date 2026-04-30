String normalizeMenudeoSortText(String value) {
  return value
      .trim()
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll(RegExp(r'\s+'), ' ');
}

int compareMenudeoAlpha(String left, String right) {
  final normalizedLeft = normalizeMenudeoSortText(left);
  final normalizedRight = normalizeMenudeoSortText(right);
  final compare = normalizedLeft.compareTo(normalizedRight);
  if (compare != 0) return compare;
  return left.compareTo(right);
}

String firstMenudeoSortValue(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

int compareMenudeoDateDescThenIdAsc({
  required DateTime leftDate,
  required DateTime rightDate,
  required Iterable<String?> leftKeys,
  required Iterable<String?> rightKeys,
  required String leftFallbackId,
  required String rightFallbackId,
}) {
  final dateCompare = rightDate.compareTo(leftDate);
  if (dateCompare != 0) return dateCompare;
  final primaryCompare = compareMenudeoAlpha(
    firstMenudeoSortValue(leftKeys),
    firstMenudeoSortValue(rightKeys),
  );
  if (primaryCompare != 0) return primaryCompare;
  return compareMenudeoAlpha(leftFallbackId, rightFallbackId);
}

List<String> sortedMenudeoOptions(Iterable<String> options) {
  final values = options
      .map((option) => option.trim())
      .where((option) => option.isNotEmpty)
      .toSet()
      .toList(growable: false);
  values.sort(compareMenudeoAlpha);
  return values;
}
