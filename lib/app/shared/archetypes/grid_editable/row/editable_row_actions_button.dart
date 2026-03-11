import 'package:flutter/material.dart';

import '../../../ui_contract_core/dialogs/contract_menu_surface.dart';

class EditableRowActionsButton<T> extends StatelessWidget {
  final List<ContractMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final String tooltip;

  const EditableRowActionsButton({
    super.key,
    required this.entries,
    required this.onSelected,
    this.tooltip = 'Acciones',
  });

  Future<void> _openMenu(BuildContext context) async {
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    final box = context.findRenderObject() as RenderBox?;
    if (overlay is! RenderBox || box == null) return;
    final offset = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + box.size.height,
      overlay.size.width - offset.dx - box.size.width,
      overlay.size.height - offset.dy,
    );
    final selected = await showContractContextMenu<T>(
      context: context,
      position: position,
      entries: entries,
    );
    if (selected != null) {
      onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.more_horiz_rounded),
      onPressed: () => _openMenu(context),
    );
  }
}
