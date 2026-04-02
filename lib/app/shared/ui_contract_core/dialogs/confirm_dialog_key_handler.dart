import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _DialogConfirmIntent extends Intent {
  const _DialogConfirmIntent();
}

class _DialogCancelIntent extends Intent {
  const _DialogCancelIntent();
}

class ContractConfirmDialogKeyHandler extends StatelessWidget {
  final Widget child;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ContractConfirmDialogKeyHandler({
    super.key,
    required this.child,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      autofocus: true,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): _DialogConfirmIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter):
              _DialogConfirmIntent(),
          SingleActivator(LogicalKeyboardKey.escape): _DialogCancelIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _DialogConfirmIntent: CallbackAction<_DialogConfirmIntent>(
              onInvoke: (_) {
                onConfirm();
                return null;
              },
            ),
            _DialogCancelIntent: CallbackAction<_DialogCancelIntent>(
              onInvoke: (_) {
                onCancel();
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
