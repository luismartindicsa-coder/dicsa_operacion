import 'package:flutter/material.dart';

import '../shared/ui_contract_core/dialogs/contract_popup_surface.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'mayoreo_theme.dart';

/// Auxiliary surfaces: Menudeo cash-cut dialog controls and Cuentas Mayoreo
/// detail header/summary cards, with the shared glass and Mayoreo area tokens.
class MayoreoDialogTheme extends StatelessWidget {
  final Widget child;
  const MayoreoDialogTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    const tokens = mayoreoAreaTokens;
    return AreaThemeScope(
      tokens: tokens,
      child: Theme(
        data: base.copyWith(
          colorScheme: base.colorScheme.copyWith(
            primary: tokens.primaryStrong,
            onPrimary: Colors.white,
            primaryContainer: tokens.primarySoft,
            onPrimaryContainer: tokens.primaryStrong,
            secondary: tokens.primary,
            onSecondary: kMayoreoInk,
            secondaryContainer: tokens.badgeBackground,
            onSecondaryContainer: tokens.badgeText,
            tertiary: tokens.accent,
            surface: tokens.surfaceTint,
            onSurface: kMayoreoInk,
            onSurfaceVariant: tokens.badgeText,
            surfaceContainerHighest: tokens.primarySoft,
            outline: tokens.border,
            outlineVariant: tokens.border.withValues(alpha: 0.72),
            surfaceTint: tokens.surfaceTint,
          ),
          textTheme: base.textTheme.apply(
            bodyColor: kMayoreoInk,
            displayColor: kMayoreoInk,
          ),
          iconTheme: IconThemeData(color: tokens.primaryStrong),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: tokens.primaryStrong,
            selectionColor: tokens.primary.withValues(alpha: 0.24),
            selectionHandleColor: tokens.primaryStrong,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: tokens.primaryStrong,
              foregroundColor: Colors.white,
              disabledBackgroundColor: tokens.primaryStrong.withValues(
                alpha: 0.34,
              ),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.78),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: base.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.primaryStrong,
              backgroundColor: Colors.white.withValues(alpha: 0.74),
              side: BorderSide(color: tokens.border.withValues(alpha: 0.92)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: base.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: tokens.primaryStrong,
              textStyle: base.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              foregroundColor: tokens.primaryStrong,
              hoverColor: tokens.primarySoft.withValues(alpha: 0.65),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          segmentedButtonTheme: SegmentedButtonThemeData(
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              foregroundColor: tokens.primaryStrong,
              selectedForegroundColor: tokens.primaryStrong,
              selectedBackgroundColor: tokens.badgeBackground.withValues(
                alpha: 0.92,
              ),
              backgroundColor: Colors.white.withValues(alpha: 0.72),
              side: BorderSide(color: tokens.border.withValues(alpha: 0.72)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: base.textTheme.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            labelStyle: TextStyle(
              color: tokens.badgeText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            floatingLabelStyle: TextStyle(
              color: tokens.primaryStrong,
              fontWeight: FontWeight.w800,
            ),
            prefixIconColor: tokens.primaryStrong,
            suffixIconColor: tokens.primaryStrong,
          ),
          expansionTileTheme: ExpansionTileThemeData(
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            iconColor: tokens.primaryStrong,
            collapsedIconColor: tokens.primaryStrong,
            textColor: kMayoreoInk,
            collapsedTextColor: kMayoreoInk,
            shape: const RoundedRectangleBorder(),
            collapsedShape: const RoundedRectangleBorder(),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          ),
          listTileTheme: ListTileThemeData(
            textColor: kMayoreoInk,
            iconColor: tokens.primaryStrong,
            titleTextStyle: base.textTheme.titleMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: kMayoreoInk,
            ),
            subtitleTextStyle: base.textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tokens.badgeText,
              height: 1.4,
            ),
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.white
                  : tokens.badgeText,
            ),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? tokens.primaryStrong.withValues(
                      alpha: states.contains(WidgetState.disabled) ? 0.34 : 1,
                    )
                  : tokens.primarySoft.withValues(alpha: 0.6),
            ),
            trackOutlineColor: WidgetStatePropertyAll(tokens.border),
          ),
          dividerTheme: DividerThemeData(
            color: tokens.border.withValues(alpha: 0.65),
            thickness: 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

InputDecoration mayoreoDialogFieldDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  IconData? icon,
}) {
  final decoration = contractGlassFieldDecoration(
    context,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
  );
  return decoration.copyWith(
    labelText: label,
    border: decoration.enabledBorder,
    disabledBorder: decoration.enabledBorder,
    errorBorder: decoration.enabledBorder?.copyWith(
      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
    ),
    focusedErrorBorder: decoration.focusedBorder?.copyWith(
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.error,
        width: 1.4,
      ),
    ),
    hintStyle: TextStyle(
      color: mayoreoAreaTokens.badgeText.withValues(alpha: 0.65),
    ),
  );
}

class MayoreoDialogHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onClose;
  const MayoreoDialogHeader({
    super.key,
    required this.title,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: kMayoreoPanelGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.18),
          ),
        ),
        child: Icon(
          Icons.receipt_long_outlined,
          color: mayoreoAreaTokens.primaryStrong,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kMayoreoInk,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Ventas Mayoreo / Cuentas',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: mayoreoAreaTokens.badgeText,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Cerrar',
        onPressed: onClose,
        icon: const Icon(Icons.close_rounded),
      ),
    ],
  );
}

class MayoreoDialogSummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const MayoreoDialogSummaryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      gradient: kMayoreoPanelGradient,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: mayoreoAreaTokens.border.withValues(alpha: 0.8),
      ),
    ),
    child: Row(
      children: [
        Icon(icon, color: mayoreoAreaTokens.primaryStrong),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: kMayoreoInk,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: kMayoreoInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class MayoreoDialogRecordCard extends StatelessWidget {
  final Widget child;
  const MayoreoDialogRecordCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: ContractGlassCard(
      padding: EdgeInsets.zero,
      elevation: 8,
      child: child,
    ),
  );
}

/// Glass options surface; retains RawAutocomplete's keyboard highlight/Enter
/// handling and keeps highlighted options in view without taking input focus.
class MayoreoDialogOptions<T extends Object> extends StatefulWidget {
  final Iterable<T> options;
  final String Function(T) label;
  final ValueChanged<T> onSelected;
  final double width;
  const MayoreoDialogOptions({
    super.key,
    required this.options,
    required this.label,
    required this.onSelected,
    required this.width,
  });

  @override
  State<MayoreoDialogOptions<T>> createState() =>
      _MayoreoDialogOptionsState<T>();
}

class _MayoreoDialogOptionsState<T extends Object>
    extends State<MayoreoDialogOptions<T>> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final highlighted = AutocompleteHighlightedOption.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final top = highlighted * 44.0;
      final viewport = _scroll.position.viewportDimension;
      if (top < _scroll.offset || top + 44 > _scroll.offset + viewport) {
        _scroll.jumpTo(
          (top < _scroll.offset ? top : top + 44 - viewport).clamp(
            0.0,
            _scroll.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.options.toList();
    final highlighted = AutocompleteHighlightedOption.of(context);
    return Align(
      alignment: Alignment.topLeft,
      child: ContractPopupSurface(
        padding: const EdgeInsets.all(6),
        constraints: BoxConstraints(maxWidth: widget.width, maxHeight: 252),
        child: ListView.builder(
          controller: _scroll,
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemExtent: 44,
          itemCount: options.length,
          itemBuilder: (context, index) => Material(
            color: index == highlighted
                ? mayoreoAreaTokens.badgeBackground
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => widget.onSelected(options[index]),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.label(options[index]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: mayoreoAreaTokens.primaryStrong,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
