import 'package:flutter/material.dart';

import 'contract_tokens.dart';

class AreaThemeScope extends InheritedWidget {
  final ContractAreaTokens tokens;

  const AreaThemeScope({super.key, required this.tokens, required super.child});

  static ContractAreaTokens of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AreaThemeScope>();
    return scope?.tokens ?? ContractAreaTokens.fallback();
  }

  @override
  bool updateShouldNotify(AreaThemeScope oldWidget) {
    return tokens != oldWidget.tokens;
  }
}
