String normalizeMayoreoSortText(String value) {
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

int compareMayoreoAlpha(String left, String right) {
  final normalizedLeft = normalizeMayoreoSortText(left);
  final normalizedRight = normalizeMayoreoSortText(right);
  final compare = normalizedLeft.compareTo(normalizedRight);
  if (compare != 0) return compare;
  return left.compareTo(right);
}

String firstMayoreoSortValue(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

int compareMayoreoDateDescThenIdAsc({
  required DateTime leftDate,
  required DateTime rightDate,
  required Iterable<String?> leftKeys,
  required Iterable<String?> rightKeys,
  required String leftFallbackId,
  required String rightFallbackId,
}) {
  final dateCompare = rightDate.compareTo(leftDate);
  if (dateCompare != 0) return dateCompare;
  final primaryCompare = compareMayoreoAlpha(
    firstMayoreoSortValue(leftKeys),
    firstMayoreoSortValue(rightKeys),
  );
  if (primaryCompare != 0) return primaryCompare;
  return compareMayoreoAlpha(leftFallbackId, rightFallbackId);
}

List<String> sortedMayoreoOptions(Iterable<String> options) {
  final values = options
      .map((option) => option.trim())
      .where((option) => option.isNotEmpty)
      .toSet()
      .toList(growable: false);
  values.sort(compareMayoreoAlpha);
  return values;
}
