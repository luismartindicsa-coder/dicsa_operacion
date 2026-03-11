import 'package:flutter/material.dart';

import '../../ui_contract_core/focus/focus_utils.dart';
import '../../ui_contract_core/keyboard/editable_input_key_guard.dart';
import '../../ui_contract_core/keyboard/shortcut_maps.dart';
import 'grid_navigation_controller.dart';

class GridKeyboardShell extends StatelessWidget {
  final GridNavigationController navigationController;
  final Widget child;
  final VoidCallback? onConfirm;
  final VoidCallback? onEscape;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenActiveCell;
  final bool Function()? isEditingText;
  final ValueChanged<GridCellPosition>? onNavigated;

  const GridKeyboardShell({
    super.key,
    required this.navigationController,
    required this.child,
    this.onConfirm,
    this.onEscape,
    this.onDelete,
    this.onOpenActiveCell,
    this.isEditingText,
    this.onNavigated,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        return guardEditableInputKeys(
          editableTextFocused: isEditingText?.call() ?? isEditableTextFocused(),
          event: event,
          onEscape: () {
            onEscape?.call();
            return KeyEventResult.handled;
          },
          onEnter: () {
            onConfirm?.call();
            return KeyEventResult.handled;
          },
          onDeleteOutsideInput: () {
            onDelete?.call();
            return KeyEventResult.handled;
          },
        );
      },
      child: Shortcuts(
        shortcuts: buildGridShortcutMap(),
        child: Actions(
          actions: <Type, Action<Intent>>{
            ContractEscapeIntent: CallbackAction<ContractEscapeIntent>(
              onInvoke: (_) {
                onEscape?.call();
                return null;
              },
            ),
            ContractConfirmIntent: CallbackAction<ContractConfirmIntent>(
              onInvoke: (_) {
                onConfirm?.call();
                return null;
              },
            ),
            ContractDeleteIntent: CallbackAction<ContractDeleteIntent>(
              onInvoke: (_) {
                onDelete?.call();
                return null;
              },
            ),
            ContractOpenCellIntent: CallbackAction<ContractOpenCellIntent>(
              onInvoke: (_) {
                onOpenActiveCell?.call();
                return null;
              },
            ),
            ContractMoveHorizontalIntent:
                CallbackAction<ContractMoveHorizontalIntent>(
                  onInvoke: (intent) {
                    switch (intent.direction) {
                      case TraversalDirection.left:
                        navigationController.moveLeft();
                        onNavigated?.call(navigationController.active);
                        break;
                      case TraversalDirection.right:
                        navigationController.moveRight();
                        onNavigated?.call(navigationController.active);
                        break;
                      default:
                        break;
                    }
                    return null;
                  },
                ),
            ContractMoveVerticalIntent:
                CallbackAction<ContractMoveVerticalIntent>(
                  onInvoke: (intent) {
                    switch (intent.direction) {
                      case TraversalDirection.up:
                        navigationController.moveUp();
                        onNavigated?.call(navigationController.active);
                        break;
                      case TraversalDirection.down:
                        navigationController.moveDown();
                        onNavigated?.call(navigationController.active);
                        break;
                      default:
                        break;
                    }
                    return null;
                  },
                ),
          },
          child: child,
        ),
      ),
    );
  }
}
