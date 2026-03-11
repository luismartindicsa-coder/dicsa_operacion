import 'package:flutter/material.dart';

import 'contract_popup_surface.dart';

@immutable
class ContractMenuEntry<T> {
  final T value;
  final String label;
  final IconData? icon;
  final bool enabled;

  const ContractMenuEntry({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
  });
}

Future<T?> showContractContextMenu<T>({
  required BuildContext context,
  required RelativeRect position,
  required List<ContractMenuEntry<T>> entries,
}) {
  return showMenu<T>(
    context: context,
    position: position,
    color: Colors.transparent,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    menuPadding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
    items: entries
        .map(
          (entry) => PopupMenuItem<T>(
            value: entry.value,
            enabled: entry.enabled,
            padding: EdgeInsets.zero,
            child: ContractPopupSurface(
              padding: EdgeInsets.zero,
              child: _ContractMenuRow(entry: entry),
            ),
          ),
        )
        .toList(),
  );
}

class _ContractMenuRow<T> extends StatelessWidget {
  final ContractMenuEntry<T> entry;

  const _ContractMenuRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final foreground = entry.enabled
        ? const Color(0xFF14373B)
        : const Color(0xFF14373B).withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.icon != null) ...[
            Icon(entry.icon, size: 18, color: foreground),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              entry.label,
              style: TextStyle(
                color: foreground,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
