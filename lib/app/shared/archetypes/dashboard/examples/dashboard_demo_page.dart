import 'package:flutter/material.dart';

import '../../../ui_contract_core/permissions/action_permission.dart';
import '../../../ui_contract_core/permissions/visibility_guard.dart';
import '../../../ui_contract_core/refresh/lifecycle_refresh_scope.dart';
import '../../../ui_contract_core/theme/area_theme_scope.dart';
import '../../../ui_contract_core/theme/contract_tokens.dart';
import '../dashboard.dart';

class DashboardDemoPage extends StatefulWidget {
  const DashboardDemoPage({super.key});

  @override
  State<DashboardDemoPage> createState() => _DashboardDemoPageState();
}

class _DashboardDemoPageState extends State<DashboardDemoPage> {
  final DashboardRefreshController _refreshController =
      DashboardRefreshController();
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    final widgetData = const [
      ('Pacas en patio', '24'),
      ('Entradas del día', '12'),
      ('Producción', '8'),
      ('Salidas', '3'),
    ];

    return AreaThemeScope(
      tokens: ContractAreaTokens.fallback(),
      child: LifecycleRefreshScope(
        onResume: () => _refreshController.requestRefresh(() async {}),
        child: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DashboardShell(
                topBar: Text(
                  'Demo dashboard',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                summaryBar: Row(
                  children: [
                    const Expanded(
                      child: DashboardWidgetCard(
                        title: 'Resumen',
                        child: Center(child: Text('Vista general reusable')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    EnabledActionGuard(
                      permission: const ActionPermission.allowed(),
                      builder: (context, enabled, _) {
                        return OutlinedButton.icon(
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
                widgets: widgetData.map((item) {
                  return DashboardWidgetCard(
                    title: item.$1,
                    onTap: () => showDashboardDetailOverlay(
                      context,
                      title: item.$1,
                      child: Center(child: Text(item.$2)),
                    ),
                    child: Center(child: Text(item.$2)),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
