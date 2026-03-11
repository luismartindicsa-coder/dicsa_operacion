import 'package:flutter/material.dart';

import '../../ui_contract_core/dialogs/contract_dialog_shell.dart';

class AuxiliaryModalShell extends StatelessWidget {
  final Widget child;

  const AuxiliaryModalShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ContractDialogShell(child: child);
  }
}
