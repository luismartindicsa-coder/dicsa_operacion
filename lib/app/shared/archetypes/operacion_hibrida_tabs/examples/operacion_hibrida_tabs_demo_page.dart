import 'package:flutter/material.dart';

import '../../../ui_contract_core/permissions/action_permission.dart';
import '../../../ui_contract_core/permissions/visibility_guard.dart';
import '../../../ui_contract_core/refresh/lifecycle_refresh_scope.dart';
import '../../../ui_contract_core/theme/area_theme_scope.dart';
import '../../../ui_contract_core/theme/contract_buttons.dart';
import '../../../ui_contract_core/theme/contract_tokens.dart';
import '../operacion_hibrida_tabs.dart';

class OperacionHibridaTabsDemoPage extends StatefulWidget {
  const OperacionHibridaTabsDemoPage({super.key});

  @override
  State<OperacionHibridaTabsDemoPage> createState() =>
      _OperacionHibridaTabsDemoPageState();
}

class _OperacionHibridaTabsDemoPageState
    extends State<OperacionHibridaTabsDemoPage> {
  late final OperacionHibridaTabsController _controller =
      OperacionHibridaTabsController(initialTabId: 'resumen');
  final OperacionRefreshController _refreshController =
      OperacionRefreshController();
  bool _refreshing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      ('resumen', 'Resumen'),
      ('inventario', 'Inventario'),
      ('movimientos', 'Movimientos'),
      ('reportes', 'Reportes'),
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
                  child: OperacionHibridaTabsShell(
                    topBar: Text(
                      'Demo operación híbrida',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    summary: const OperacionTabSummaryStrip(
                      children: [
                        OperacionTabMetricCard(
                          icon: Icons.inventory_2_outlined,
                          label: 'Existencia',
                          value: '12.4 t',
                        ),
                        OperacionTabMetricCard(
                          icon: Icons.event_note_outlined,
                          label: 'Cortes',
                          value: '1',
                        ),
                        OperacionTabMetricCard(
                          icon: Icons.warning_amber_rounded,
                          label: 'Alertas',
                          value: '0',
                        ),
                      ],
                    ),
                    actionsBar: OperacionTabActionsBar(
                      actions: [
                        VisibilityGuard(
                          permission: const ActionPermission.allowed(),
                          child: ElevatedButton.icon(
                            style: contractPrimaryButtonStyle(context),
                            onPressed: () {},
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Nuevo movimiento'),
                          ),
                        ),
                        EnabledActionGuard(
                          permission: const ActionPermission.denied(
                            'Solo supervisor puede exportar',
                          ),
                          builder: (context, enabled, _) {
                            return OutlinedButton.icon(
                              style: contractSecondaryButtonStyle(context),
                              onPressed: enabled ? () {} : null,
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Exportar'),
                            );
                          },
                        ),
                        OutlinedButton.icon(
                          style: contractSecondaryButtonStyle(context),
                          onPressed: _refreshing
                              ? null
                              : () async {
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
                                },
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(
                            _refreshing ? 'Actualizando...' : 'Refrescar',
                          ),
                        ),
                        OutlinedButton.icon(
                          style: contractSecondaryButtonStyle(context),
                          onPressed: () => showOperacionTabDetailOverlay(
                            context,
                            title: 'Detalle del tab activo',
                            child: Center(
                              child: Text(
                                'Detalle contextual de ${_controller.activeTabId}',
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Detalle'),
                        ),
                      ],
                    ),
                    tabs: Wrap(
                      spacing: 8,
                      children: [
                        for (final (id, label) in tabs)
                          ChoiceChip(
                            label: Text(label),
                            selected: _controller.activeTabId == id,
                            onSelected: (_) {
                              _controller.activateTab(id);
                              _controller.setTabContext(id, 'visited');
                            },
                          ),
                      ],
                    ),
                    body: OperacionTabViewHost(
                      activeTabId: _controller.activeTabId,
                      tabViews: {
                        'resumen': const OperacionTabWorkspacePanel(
                          key: ValueKey('operacion_resumen'),
                          title: 'Resumen operativo',
                          child: Center(
                            child: Text('KPIs y resumen del módulo anfitrión'),
                          ),
                        ),
                        'inventario': const OperacionTabWorkspacePanel(
                          key: ValueKey('operacion_inventario'),
                          title: 'Inventario',
                          child: Center(
                            child: Text('Superficie de inventario reusable'),
                          ),
                        ),
                        'movimientos': const OperacionTabWorkspacePanel(
                          key: ValueKey('operacion_movimientos'),
                          title: 'Movimientos',
                          child: Center(
                            child: Text('Superficie de movimientos reusable'),
                          ),
                        ),
                        'reportes': OperacionTabWorkspacePanel(
                          key: const ValueKey('operacion_reportes'),
                          title: 'Reportes',
                          trailing: OperacionTabContextBadge(
                            label: 'Contexto',
                            value:
                                '${_controller.contextFor(_controller.activeTabId) ?? 'nuevo'}',
                          ),
                          child: const Center(
                            child: Text('Reportes y exportes del módulo'),
                          ),
                        ),
                      },
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
