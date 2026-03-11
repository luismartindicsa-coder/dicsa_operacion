import 'package:flutter/material.dart';

import '../../../ui_contract_core/theme/contract_buttons.dart';
import '../../../ui_contract_core/theme/glass_styles.dart';

class DateRangeFilterBar extends StatelessWidget {
  final DateTimeRange? value;
  final Future<DateTimeRange?> Function(BuildContext context)? onPickRange;
  final ValueChanged<DateTimeRange?>? onChanged;
  final String label;

  const DateRangeFilterBar({
    super.key,
    this.value,
    this.onPickRange,
    this.onChanged,
    this.label = 'Rango de fechas',
  });

  String _formatRange(BuildContext context) {
    final value = this.value;
    if (value == null) return 'Sin filtro';
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatCompactDate(value.start)} - ${localizations.formatCompactDate(value.end)}';
  }

  Future<void> _pick(BuildContext context) async {
    if (onPickRange == null) return;
    final picked = await onPickRange!(context);
    onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: Row(
        children: [
          const Icon(Icons.date_range_rounded, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF35565D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatRange(context),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF14373B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            style: contractSecondaryButtonStyle(context),
            onPressed: () => _pick(context),
            child: const Text('Seleccionar'),
          ),
          if (value != null) ...[
            const SizedBox(width: 8),
            TextButton(
              style: contractGhostButtonStyle(context),
              onPressed: () => onChanged?.call(null),
              child: const Text('Limpiar'),
            ),
          ],
        ],
      ),
    );
  }
}
