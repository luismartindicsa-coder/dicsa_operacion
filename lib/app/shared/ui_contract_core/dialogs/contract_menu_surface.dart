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
                          colors: inheritedTokens.darkGlass
                              ? [
                                  Colors.white.withValues(alpha: 0.08),
                                  inheritedTokens.fieldSurface.withValues(
                                    alpha: 0.98,
                                  ),
                                  inheritedTokens.glassSurface.withValues(
                                    alpha: 0.98,
                                  ),
                                ]
                              : [
                                  Colors.white.withValues(alpha: 0.84),
                                  Colors.white.withValues(alpha: 0.78),
                                  inheritedTokens.primarySoft.withValues(
                                    alpha: 0.18,
                                  ),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: inheritedTokens.darkGlass
                              ? Colors.white.withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.68),
                          width: 1.3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: inheritedTokens.darkGlass
                                ? inheritedTokens.glow.withValues(alpha: 0.14)
                                : Colors.black.withValues(alpha: 0.18),
                            blurRadius: inheritedTokens.darkGlass ? 28 : 24,
                            offset: const Offset(0, 10),
                          ),
                          if (inheritedTokens.darkGlass)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.24),
                              blurRadius: 22,
                              offset: const Offset(0, 14),
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
                                color: inheritedTokens.darkGlass
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : inheritedTokens.border.withValues(
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
    final tokens = AreaThemeScope.of(context);
    final foreground = widget.entry.enabled
        ? tokens.onGlass
        : tokens.onGlass.withValues(alpha: 0.44);
    final active = widget.entry.enabled && _hovered;
    final activeFill = tokens.darkGlass
        ? Color.lerp(
            tokens.fieldSurface,
            tokens.surfaceTint,
            0.62,
          )!.withValues(alpha: 0.92)
        : Color.lerp(tokens.primarySoft, Colors.white, 0.58)!;
    final activeText = tokens.darkGlass ? tokens.primaryStrong : tokens.onGlass;
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
              color: active ? activeFill : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: active
                  ? Border.all(
                      color: tokens.border.withValues(
                        alpha: tokens.darkGlass ? 0.28 : 0.62,
                      ),
                    )
                  : null,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: tokens.glow.withValues(
                          alpha: tokens.darkGlass ? 0.12 : 0.18,
                        ),
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
                  color: active ? activeText : foreground,
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
