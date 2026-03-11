import 'package:flutter/material.dart';

import '../../../ui_contract_core/dialogs/contract_menu_surface.dart';

Future<T?> showEditableGridContextMenu<T>({
  required BuildContext context,
  required Offset globalPosition,
  required List<ContractMenuEntry<T>> entries,
}) {
  final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
  if (overlay is! RenderBox) {
    return Future<T?>.value(null);
  }

  final position = RelativeRect.fromLTRB(
    globalPosition.dx,
    globalPosition.dy,
    overlay.size.width - globalPosition.dx,
    overlay.size.height - globalPosition.dy,
  );

  return showContractContextMenu<T>(
    context: context,
    position: position,
    entries: entries,
  );
}
