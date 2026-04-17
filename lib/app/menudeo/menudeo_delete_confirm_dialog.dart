import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/ui_contract_core/dialogs/confirm_dialog_key_handler.dart';
import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import 'menudeo_theme.dart';

Future<bool?> showMenudeoDeleteConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String impactLabel,
  String confirmLabel = 'Eliminar',
  String subtitle = 'Confirma la baja del registro visible.',
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      return AreaThemeScope(
        tokens: menudeoAreaTokens,
        child: _MenudeoDeleteConfirmDialog(
          title: title,
          message: message,
          impactLabel: impactLabel,
          confirmLabel: confirmLabel,
          subtitle: subtitle,
        ),
      );
    },
  );
}

class _MenudeoDeleteConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String impactLabel;
  final String confirmLabel;
  final String subtitle;

  const _MenudeoDeleteConfirmDialog({
    required this.title,
    required this.message,
    required this.impactLabel,
    required this.confirmLabel,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractConfirmDialogKeyHandler(
      onCancel: () => Navigator.of(context).pop(false),
      onConfirm: () => Navigator.of(context).pop(true),
      child: Focus(
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
        child: ContractDialogShell(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 438),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: tokens.badgeBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: tokens.primaryStrong.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: tokens.primaryStrong,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: tokens.primaryStrong,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: tokens.badgeText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.35,
                      color: kMenudeoMutedText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: tokens.badgeBackground.withValues(alpha: 0.92),
                      border: Border.all(
                        color: tokens.primaryStrong.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: tokens.primaryStrong,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            impactLabel,
                            style: TextStyle(
                              fontSize: 12.8,
                              fontWeight: FontWeight.w800,
                              color: tokens.primaryStrong,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: contractSecondaryButtonStyle(context),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: contractPrimaryButtonStyle(context),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(confirmLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
