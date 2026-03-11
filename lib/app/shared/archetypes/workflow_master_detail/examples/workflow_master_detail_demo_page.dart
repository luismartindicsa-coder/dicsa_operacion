import 'package:flutter/material.dart';

import '../../../ui_contract_core/dialogs/contract_menu_surface.dart';
import '../../../ui_contract_core/permissions/action_permission.dart';
import '../../../ui_contract_core/permissions/visibility_guard.dart';
import '../../../ui_contract_core/refresh/lifecycle_refresh_scope.dart';
import '../../../ui_contract_core/theme/contract_buttons.dart';
import '../../../ui_contract_core/theme/area_theme_scope.dart';
import '../../../ui_contract_core/theme/contract_tokens.dart';
import '../workflow_master_detail.dart';

class WorkflowMasterDetailDemoPage extends StatefulWidget {
  const WorkflowMasterDetailDemoPage({super.key});

  @override
  State<WorkflowMasterDetailDemoPage> createState() =>
      _WorkflowMasterDetailDemoPageState();
}

class _WorkflowMasterDetailDemoPageState
    extends State<WorkflowMasterDetailDemoPage> {
  late final WorkflowMasterDetailController _controller =
      WorkflowMasterDetailController();
  final WorkflowRefreshController _refreshController =
      WorkflowRefreshController();
  final items = const ['OT-1001', 'OT-1002', 'OT-1003'];
  bool _refreshing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  child: WorkflowMasterDetailShell(
                    topBar: Row(
                      children: [
                        Text(
                          'Demo workflow',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const Spacer(),
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
                    summary: const WorkflowStatusSummaryCard(
                      title: 'OT activas',
                      value: '3',
                    ),
                    master: Column(
                      children: [
                        WorkflowItemActionsBar(
                          actions: [
                            ElevatedButton.icon(
                              style: contractPrimaryButtonStyle(context),
                              onPressed: () {},
                              icon: const Icon(Icons.add_task_rounded),
                              label: const Text('Nueva OT'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Card(
                            child: ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (_, index) {
                                final id = items[index];
                                return GestureDetector(
                                  onSecondaryTapDown: (details) async {
                                    final action =
                                        await showWorkflowItemContextMenu<
                                          String
                                        >(
                                          context: context,
                                          globalPosition:
                                              details.globalPosition,
                                          entries: const [
                                            ContractMenuEntry(
                                              value: 'open',
                                              label: 'Abrir',
                                              icon: Icons.open_in_new_rounded,
                                            ),
                                            ContractMenuEntry(
                                              value: 'close',
                                              label: 'Cerrar',
                                              icon: Icons.check_circle_outline,
                                            ),
                                          ],
                                        );
                                    if (action == 'open') {
                                      _controller.select(id);
                                    }
                                  },
                                  child: ListTile(
                                    selected: _controller.selectedId == id,
                                    title: Text(id),
                                    trailing: VisibilityGuard(
                                      permission:
                                          const ActionPermission.allowed(),
                                      child: const Icon(
                                        Icons.chevron_right_rounded,
                                      ),
                                    ),
                                    onTap: () => _controller.select(id),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    detail: WorkflowDetailPanel(
                      title: 'Detalle OT',
                      child: Center(
                        child: Text(
                          _controller.selectedId == null
                              ? 'Selecciona una OT'
                              : 'Detalle de ${_controller.selectedId}',
                        ),
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
