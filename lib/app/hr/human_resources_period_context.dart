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
    return availableLabels.map((item) => item.trim()).contains(selected)
        ? selected
        : '';
  }

  static List<String> normalizedOptions(Iterable<String> labels) {
    final unique = <String>{};
    for (final rawLabel in labels) {
      final label = rawLabel.trim();
      if (label.isNotEmpty) unique.add(label);
    }
    final options = unique.toList(growable: false)
      ..sort((a, b) => b.compareTo(a));
    return options;
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
    final hasSelection = selectedLabel.trim().isNotEmpty;
    final hasOptions = options.isNotEmpty;
    return PopupMenuButton<String>(
      enabled: hasOptions,
      tooltip: 'Elegir periodo operativo',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in options)
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
