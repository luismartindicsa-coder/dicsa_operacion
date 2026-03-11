import 'package:flutter/material.dart';

import '../../../ui_contract_core/permissions/action_permission.dart';
import '../../../ui_contract_core/permissions/visibility_guard.dart';
import '../../../ui_contract_core/refresh/lifecycle_refresh_scope.dart';
import '../../../ui_contract_core/theme/area_theme_scope.dart';
import '../../../ui_contract_core/theme/contract_buttons.dart';
import '../../../ui_contract_core/theme/contract_tokens.dart';
import '../grid_editable_tabbed.dart';

class GridEditableTabbedDemoPage extends StatefulWidget {
  const GridEditableTabbedDemoPage({super.key});

  @override
  State<GridEditableTabbedDemoPage> createState() =>
      _GridEditableTabbedDemoPageState();
}

class _GridEditableTabbedDemoPageState
    extends State<GridEditableTabbedDemoPage> {
  late final GridTabbedController _controller = GridTabbedController(
    initialTabId: 'produccion',
  );
  final GridTabbedRefreshController _refreshController =
      GridTabbedRefreshController();
  bool _refreshing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      ('produccion', 'Producción', Icons.inventory_2_outlined),
      ('separacion', 'Separación', Icons.category_outlined),
    ];

    return AreaThemeScope(
      tokens: ContractAreaTokens.fallback(),
      child: LifecycleRefreshScope(
        onResume: () => _refreshController.flushPending(() async {}),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridTabbedShell(
                    topBar: Row(
                      children: [
                        Text(
                          'Demo tabulado',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    tabs: Wrap(
                      spacing: 8,
                      children: [
                        for (final (id, label, icon) in tabs)
                          ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 18),
                                const SizedBox(width: 6),
                                Text(label),
                              ],
                            ),
                            selected: _controller.activeTabId == id,
                            onSelected: (_) {
                              _controller.activateTab(id);
                              _controller.setTabContext(id, 'visited');
                            },
                          ),
                      ],
                    ),
                    actionsBar: GridTabbedActionsBar(
                      actions: [
                        VisibilityGuard(
                          permission: const ActionPermission.allowed(),
                          child: ElevatedButton.icon(
                            style: contractPrimaryButtonStyle(context),
                            onPressed: () {},
                            icon: const Icon(Icons.add_rounded),
                            label: Text(
                              _controller.activeTabId == 'produccion'
                                  ? 'Nueva producción'
                                  : 'Nueva separación',
                            ),
                          ),
                        ),
                        EnabledActionGuard(
                          permission: const ActionPermission.allowed(),
                          builder: (context, enabled, _) {
                            return OutlinedButton.icon(
                              style: contractSecondaryButtonStyle(context),
                              onPressed: enabled && !_refreshing
                                  ? () async {
                                      setState(() => _refreshing = true);
                                      await _refreshController.requestRefresh(
                                        () async {
                                          await Future<void>.delayed(
                                            const Duration(milliseconds: 120),
                                          );
                                        },
                                      );
                                      if (mounted) {
                                        setState(() => _refreshing = false);
                                      }
                                    }
                                  : null,
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(
                                _refreshing ? 'Actualizando...' : 'Refrescar',
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    metrics: GridTabbedMetricHeader(
                      icon: Icons.inventory_2_outlined,
                      label: _controller.activeTabId == 'produccion'
                          ? 'Pacas producidas'
                          : 'Separaciones',
                      value: _controller.activeTabId == 'produccion'
                          ? '24'
                          : '8',
                      subtitle: 'Demo reusable tabbed',
                    ),
                    body: Card(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            _controller.activeTabId == 'produccion'
                                ? 'Grid tabulado de producción'
                                : 'Grid tabulado de separación',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Contexto del tab: ${_controller.contextFor(_controller.activeTabId) ?? 'sin contexto'}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
