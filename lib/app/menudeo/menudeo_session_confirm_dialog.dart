import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/ui_contract_core/dialogs/confirm_dialog_key_handler.dart';
import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import 'menudeo_theme.dart';

Future<bool?> showMenudeoSessionConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      return AreaThemeScope(
        tokens: menudeoAreaTokens,
        child: const _MenudeoSessionConfirmDialog(),
      );
    },
  );
}

class _MenudeoSessionConfirmDialog extends StatelessWidget {
  const _MenudeoSessionConfirmDialog();

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
            constraints: const BoxConstraints(maxWidth: 430),
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
                          color: const Color(0xFFF3D9CF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(
                              0xFF8E3F2A,
                            ).withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFF8E3F2A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cerrar sesión',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: tokens.primaryStrong,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Confirma la salida de la sesión activa.',
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
                  const Text(
                    '¿Seguro que deseas cerrar tu sesión? Tendrás que volver a iniciar sesión para seguir usando Menudeo.',
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.35,
                      color: Color(0xFF5A5552),
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
                          Icons.info_outline_rounded,
                          size: 18,
                          color: tokens.primaryStrong,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'La sesión actual se cerrará de inmediato.',
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
                        child: const Text('Cerrar sesión'),
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
