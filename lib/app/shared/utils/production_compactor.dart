/// Recognizes current labels and the compactadora variants in historical runs.
/// Conflicting or unsupported machine numbers stay unassigned.
int? productionCompactorNumberFromNotes(String? notes) {
  final normalized = (notes ?? '').trim().toUpperCase();
  final numbers = RegExp(
    r'\b(?:COMPACTR?ADORA\s*|C\s*)([12])\b',
  ).allMatches(normalized).map((match) => int.parse(match.group(1)!)).toSet();
  return numbers.length == 1 ? numbers.single : null;
}
