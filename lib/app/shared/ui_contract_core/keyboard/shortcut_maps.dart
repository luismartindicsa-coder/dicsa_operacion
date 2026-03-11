import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ContractEscapeIntent extends Intent {
  const ContractEscapeIntent();
}

class ContractConfirmIntent extends Intent {
  const ContractConfirmIntent();
}

class ContractDeleteIntent extends Intent {
  const ContractDeleteIntent();
}

class ContractOpenCellIntent extends Intent {
  const ContractOpenCellIntent();
}

class ContractMoveHorizontalIntent extends Intent {
  final TraversalDirection direction;

  const ContractMoveHorizontalIntent(this.direction);
}

class ContractMoveVerticalIntent extends Intent {
  final TraversalDirection direction;

  const ContractMoveVerticalIntent(this.direction);
}

Map<ShortcutActivator, Intent> buildGridShortcutMap() {
  return <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.escape):
        const ContractEscapeIntent(),
    const SingleActivator(LogicalKeyboardKey.enter):
        const ContractConfirmIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter):
        const ContractConfirmIntent(),
    const SingleActivator(LogicalKeyboardKey.delete):
        const ContractDeleteIntent(),
    const SingleActivator(LogicalKeyboardKey.backspace):
        const ContractDeleteIntent(),
    const SingleActivator(LogicalKeyboardKey.space):
        const ContractOpenCellIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowLeft):
        const ContractMoveHorizontalIntent(TraversalDirection.left),
    const SingleActivator(LogicalKeyboardKey.arrowRight):
        const ContractMoveHorizontalIntent(TraversalDirection.right),
    const SingleActivator(LogicalKeyboardKey.arrowUp):
        const ContractMoveVerticalIntent(TraversalDirection.up),
    const SingleActivator(LogicalKeyboardKey.arrowDown):
        const ContractMoveVerticalIntent(TraversalDirection.down),
  };
}
