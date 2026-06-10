import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui_contract_core/dialogs/contract_popup_surface.dart';
import '../../ui_contract_core/theme/contract_buttons.dart';
import '../../ui_contract_core/theme/area_theme_scope.dart';
import '../../ui_contract_core/theme/contract_tokens.dart';

Future<bool?> showContractConfirmationDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmText = 'Aceptar',
  bool destructive = false,
  ContractAreaTokens? tokens,
}) {
  final inheritedTokens = tokens ?? AreaThemeScope.of(context);
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (_) => AreaThemeScope(
      tokens: inheritedTokens,
      child: _ConfirmationDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        destructive: destructive,
      ),
    ),
  );
}

class _ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final bool destructive;

  const _ConfirmationDialog({
    required this.title,
    required this.content,
    required this.confirmText,
    required this.destructive,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop(false);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          Navigator.of(context).pop(true);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: ContractPopupSurface(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ConfirmationDialogTitle(
                      icon: destructive
                          ? Icons.delete_outline_rounded
                          : Icons.info_outline_rounded,
                      title: title,
                      subtitle: destructive
                          ? 'Esta acción elimina información y no se puede deshacer.'
                          : 'Confirma la acción para continuar.',
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: Icon(
                      Icons.close_rounded,
                      color: tokens.onGlass.withValues(alpha: 0.76),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                content,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: tokens.onGlass.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: contractSecondaryButtonStyle(context),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: destructive
                        ? contractDestructiveButtonStyle(context)
                        : contractPrimaryButtonStyle(context),
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: Icon(
                      destructive ? Icons.delete_rounded : Icons.check_rounded,
                    ),
                    label: Text(confirmText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmationDialogTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ConfirmationDialogTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: tokens.fieldSurface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tokens.primaryStrong.withValues(alpha: 0.34),
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.glow.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: tokens.primaryStrong),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tokens.badgeText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
