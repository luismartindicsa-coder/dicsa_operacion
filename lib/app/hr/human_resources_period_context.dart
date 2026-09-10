import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Periodo operativo compartido por los módulos transaccionales de RH.
/// Nunca resuelve automaticamente el ultimo lote: RH debe elegirlo.
class HumanResourcesPeriodContext {
  static const String _storageKey = 'human_resources_selected_period_label';

  static Future<String> readSelectedLabel() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getString(_storageKey) ?? '').trim();
  }

  static Future<void> select(String periodLabel) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, periodLabel.trim());
  }

  static String resolveSelected({
    required String selectedLabel,
    required Iterable<String> availableLabels,
  }) {
    final selected = selectedLabel.trim();
    if (selected.isEmpty) return '';
    final available = availableLabels.map((item) => item.trim()).toSet();
    if (available.contains(selected)) return selected;
    // Older imports appended their file time to the week. Reopen the original
    // operational period when that obsolete import-only option disappears.
    final withoutFileTime = selected.replaceFirst(
      RegExp(r'\s+·\s+Archivo\s+\d{2}:\d{2}:\d{2}(?::\d+)?$'),
      '',
    );
    return available.contains(withoutFileTime) ? withoutFileTime : '';
  }

  static List<String> normalizedOptions(Iterable<String> labels) {
    final unique = <String>{};
    for (final rawLabel in labels) {
      final label = rawLabel.trim();
      if (label.isNotEmpty) unique.add(label);
    }
    final options = unique.toList(growable: false)..sort(_compareNewestFirst);
    return options;
  }

  static int _compareNewestFirst(String a, String b) {
    final aRange = HumanResourcesPeriodRange.tryParse(a);
    final bRange = HumanResourcesPeriodRange.tryParse(b);
    if (aRange != null && bRange != null) {
      final byStart = bRange.start.compareTo(aRange.start);
      if (byStart != 0) return byStart;
      final byEnd = bRange.end.compareTo(aRange.end);
      if (byEnd != 0) return byEnd;
    } else if (aRange != null || bRange != null) {
      // Labels without a date cannot displace a known operational period.
      return aRange != null ? -1 : 1;
    }
    final numberPattern = RegExp(r'\bperiodo\s+(\d+)\b', caseSensitive: false);
    final aNumber = int.tryParse(numberPattern.firstMatch(a)?.group(1) ?? '');
    final bNumber = int.tryParse(numberPattern.firstMatch(b)?.group(1) ?? '');
    if (aNumber != null && bNumber != null) {
      final byNumber = bNumber.compareTo(aNumber);
      if (byNumber != 0) return byNumber;
    }
    return b.compareTo(a);
  }
}

class HumanResourcesPeriodRange {
  final DateTime start;
  final DateTime end;

  const HumanResourcesPeriodRange({required this.start, required this.end});

  static HumanResourcesPeriodRange? tryParse(String label) {
    final match = RegExp(
      r'(?:del\s+)?(\d{2}/\d{2}/\d{4})\s+(?:al|-)\s+(\d{2}/\d{2}/\d{4})',
      caseSensitive: false,
    ).firstMatch(label);
    if (match == null) return null;
    final start = _parse(match.group(1)!);
    final end = _parse(match.group(2)!);
    if (start == null || end == null) return null;
    return HumanResourcesPeriodRange(start: start, end: end);
  }

  static DateTime? _parse(String raw) {
    final parts = raw.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }
}

class HumanResourcesPeriodSelector extends StatelessWidget {
  final String selectedLabel;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const HumanResourcesPeriodSelector({
    super.key,
    required this.selectedLabel,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Sort here as well: detail dialogs can append their saved period to the
    // supplied options, and an already-open screen may retain an older list.
    final orderedOptions = HumanResourcesPeriodContext.normalizedOptions(
      options,
    );
    final hasSelection = selectedLabel.trim().isNotEmpty;
    final hasOptions = orderedOptions.isNotEmpty;
    return PopupMenuButton<String>(
      enabled: hasOptions,
      tooltip: 'Elegir periodo operativo',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in orderedOptions)
          PopupMenuItem<String>(
            value: option,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Text(
                option,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
      child: Opacity(
        opacity: hasOptions ? 1 : 0.55,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: hasSelection
                ? const Color(0xFFEFE3FF)
                : const Color(0xFFFFF4E6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasSelection
                  ? const Color(0xFFB794FF)
                  : const Color(0xFFE0B77E),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasSelection
                    ? Icons.calendar_month_rounded
                    : Icons.warning_amber_rounded,
                size: 18,
                color: const Color(0xFF5B3291),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  hasSelection
                      ? selectedLabel
                      : hasOptions
                      ? 'Selecciona periodo operativo'
                      : 'Sin periodos disponibles',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2B1946),
                  ),
                ),
              ),
              if (hasOptions) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Color(0xFF5B3291),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
