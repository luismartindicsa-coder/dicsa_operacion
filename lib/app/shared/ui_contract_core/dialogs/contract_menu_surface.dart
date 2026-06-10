import 'package:flutter/material.dart';

import '../theme/area_theme_scope.dart';

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
  final inheritedTokens = AreaThemeScope.of(context);
  return showDialog<T>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AreaThemeScope(
        tokens: inheritedTokens,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const width = 236.0;
            final estimatedHeight = (entries.length * 58.0) + 20.0;
            final left = position.left.clamp(
              12.0,
              (constraints.maxWidth - width - 12).clamp(12.0, double.infinity),
            );
            final top = position.top.clamp(
              12.0,
              (constraints.maxHeight - estimatedHeight - 12).clamp(
                12.0,
                double.infinity,
              ),
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
                Positioned(
                  left: left,
                  top: top,
                  width: width,
                  child: Material(
                    color: Colors.transparent,
                    elevation: 8,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.84),
                            Colors.white.withValues(alpha: 0.78),
                            inheritedTokens.primarySoft.withValues(alpha: 0.18),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.68),
                          width: 1.3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < entries.length; i++) ...[
                            _ContractMenuRow<T>(
                              entry: entries[i],
                              onTap: entries[i].enabled
                                  ? () => Navigator.of(
                                      dialogContext,
                                    ).pop(entries[i].value)
                                  : null,
                            ),
                            if (i < entries.length - 1)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: inheritedTokens.border.withValues(
                                  alpha: 0.26,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

class _ContractMenuRow<T> extends StatefulWidget {
  final ContractMenuEntry<T> entry;
  final VoidCallback? onTap;

  const _ContractMenuRow({required this.entry, this.onTap});

  @override
  State<_ContractMenuRow<T>> createState() => _ContractMenuRowState<T>();
}

class _ContractMenuRowState<T> extends State<_ContractMenuRow<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final foreground = widget.entry.enabled
        ? const Color(0xFF173248)
        : const Color(0xFF173248).withValues(alpha: 0.45);
    final active = widget.entry.enabled && _hovered;
    return MouseRegion(
      cursor: widget.entry.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 1),
            curve: Curves.linear,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFFE9F7EE).withValues(alpha: 0.95)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: active
                  ? Border.all(
                      color: const Color(0xFFBFD8D3).withValues(alpha: 0.62),
                    )
                  : null,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: const Color(0xFFBFD8D3).withValues(alpha: 0.48),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.entry.label,
                style: TextStyle(
                  color: active ? const Color(0xFF215A56) : foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
