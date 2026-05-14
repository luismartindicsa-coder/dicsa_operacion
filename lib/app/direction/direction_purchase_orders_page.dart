import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dashboard/general_dashboard_page.dart';
import '../maintenance/purchase_orders_page.dart';
import '../shared/app_shell.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/utils/number_formatters.dart';
import 'direction_cash_entries_exits_page.dart';
import 'direction_menudeo_analysis_page.dart';
import 'direction_maintenance_page.dart';
import 'direction_operations_repository.dart';
import 'direction_theme.dart';

String _fmtDirectionPurchaseMoney(num value) => formatMoney(value);

class DirectionPurchaseOrdersPage extends StatefulWidget {
  final bool instantOpen;

  const DirectionPurchaseOrdersPage({super.key, this.instantOpen = false});

  @override
  State<DirectionPurchaseOrdersPage> createState() =>
      _DirectionPurchaseOrdersPageState();
}

class _DirectionPurchaseOrdersPageState
    extends State<DirectionPurchaseOrdersPage> {
  final DirectionOperationsRepository _repo = DirectionOperationsRepository();
  bool _menuOpen = false;
  bool _loading = true;
  bool _runningAction = false;
  String? _error;
  DirectionPurchaseOrdersSummary? _summary;
  Timer? _refreshTimer;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_load(silent: true)),
    );
    _channel = Supabase.instance.client
        .channel('direction-purchase-orders-followup')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_purchase_orders',
          callback: (_) => unawaited(_load(silent: true)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_purchase_order_lines',
          callback: (_) => unawaited(_load(silent: true)),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final summary = await _repo.loadPurchaseOrdersSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar Compras OT: $e';
        _loading = false;
      });
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const GeneralDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openMaintenanceFollowup() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const DirectionMaintenancePage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openVault() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const DirectionCashEntriesExitsPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openMenudeoAnalysis() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const DirectionMenudeoAnalysisPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openFullPurchaseOrders() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const PurchaseOrdersPage(),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openPurchaseOrder(DirectionPurchasePendingItem item) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: PurchaseOrdersPage(initialOrderId: item.id),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _authorize(DirectionPurchasePendingItem item) async {
    if (_runningAction) return;
    final user = Supabase.instance.client.auth.currentUser;
    setState(() => _runningAction = true);
    try {
      await _repo.authorizePurchaseOrder(
        orderId: item.id,
        actorName: user?.email ?? 'direccion@dicsamx.com',
        actorUserId: user?.id,
      );
      _toast('Orden ${item.folio} autorizada.');
      await _load(silent: true);
    } catch (e) {
      _toast('No se pudo autorizar ${item.folio}: $e');
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  Future<void> _reject(DirectionPurchasePendingItem item) async {
    final comment = await _showCommentDialog();
    if (comment == null) return;
    setState(() => _runningAction = true);
    try {
      await _repo.rejectPurchaseOrder(orderId: item.id, comment: comment);
      _toast('Orden ${item.folio} rechazada.');
      await _load(silent: true);
    } catch (e) {
      _toast('No se pudo rechazar ${item.folio}: $e');
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  Future<String?> _showCommentDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Motivo del rechazo'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Comentario para Operación/Contabilidad',
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Rechazar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: directionAreaTokens,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape && _menuOpen) {
            setState(() => _menuOpen = false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AppShell(
          background: const DirectionExecutiveBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
          leadingBuilder: (_, _) => DirectionHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, contentAnim) => DirectionHeaderBrand(
            contentAnim: contentAnim,
            title: 'Compras OT Dirección',
          ),
          trailingBuilder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DirectionHeaderButton(
                label: 'Actualizar',
                icon: Icons.refresh_rounded,
                width: 138,
                onTap: () => _load(),
              ),
              const SizedBox(width: 10),
              DirectionHeaderButton(
                label: 'Dashboard',
                icon: Icons.space_dashboard_rounded,
                onTap: _openDashboard,
              ),
            ],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 56, right: 4),
                    child: _buildBody(),
                  ),
                ),
              ),
              _buildOverlayMenu(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _summary == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _summary == null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: kDirectionSurfaceText),
          textAlign: TextAlign.center,
        ),
      );
    }

    final summary = _summary!;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              DirectionMetricCard(
                icon: Icons.pending_actions_rounded,
                title: 'PENDIENTES',
                value: '${summary.pendingCount}',
                detail: 'Compras esperando autorización',
                accent: directionAreaTokens.primary,
              ),
              DirectionMetricCard(
                icon: Icons.warning_amber_rounded,
                title: 'CRÍTICAS',
                value: '${summary.criticalCount}',
                detail: 'Más de 48h sin resolución',
                accent: const Color(0xFFFF7B7B),
              ),
              DirectionMetricCard(
                icon: Icons.attach_money_rounded,
                title: 'MONTO PENDIENTE',
                value: _fmtDirectionPurchaseMoney(summary.pendingAmount),
                detail: 'Compras OT en espera',
                accent: directionAreaTokens.accent,
              ),
              DirectionMetricCard(
                icon: Icons.schedule_rounded,
                title: 'MÁS ANTIGUA',
                value: summary.oldestHours <= 0
                    ? '0 h'
                    : '${summary.oldestHours.round()} h',
                detail: 'Antigüedad máxima pendiente',
                accent: const Color(0xFFFFC36D),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DirectionToolbarPanel(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Dirección puede autorizar o rechazar compras desde esta vista para acelerar el flujo ejecutivo.',
                    style: const TextStyle(
                      color: kDirectionMutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _openFullPurchaseOrders,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir Compras OT'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1100;
              final alertsCard = _DirectionAlertsCard(alerts: summary.alerts);
              final listCard = _DirectionPurchasePendingListCard(
                items: summary.pendingItems,
                runningAction: _runningAction,
                onOpenOrder: _openPurchaseOrder,
                onAuthorize: _authorize,
                onReject: _reject,
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: alertsCard),
                    const SizedBox(width: 14),
                    Expanded(flex: 7, child: listCard),
                  ],
                );
              }
              return Column(
                children: [alertsCard, const SizedBox(height: 14), listCard],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayMenu() {
    const overlayWidth = 320.0;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: _menuOpen ? 0 : -(overlayWidth + 12),
      top: 0,
      width: overlayWidth,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !_menuOpen,
        child: SingleChildScrollView(
          child: DirectionModuleMenuPanel(
            entries: [
              DirectionModuleMenuEntry(
                icon: Icons.space_dashboard_rounded,
                title: 'Dashboard Dirección',
                subtitle: 'Resumen ejecutivo principal',
                onTap: _openDashboard,
              ),
              const DirectionModuleMenuEntry(
                icon: Icons.shopping_cart_checkout_rounded,
                title: 'Compras OT',
                subtitle: 'Autorización y rechazo rápido',
                current: true,
              ),
              DirectionModuleMenuEntry(
                icon: Icons.build_circle_outlined,
                title: 'Mantenimiento OT',
                subtitle: 'Seguimiento y alertas',
                onTap: _openMaintenanceFollowup,
              ),
              DirectionModuleMenuEntry(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Bóveda',
                subtitle: 'Entradas y salidas de Dirección',
                onTap: _openVault,
              ),
              DirectionModuleMenuEntry(
                icon: Icons.storefront_rounded,
                title: 'Análisis Menudeo',
                subtitle: 'Mercado, efectivo y operación',
                onTap: _openMenudeoAnalysis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionAlertsCard extends StatelessWidget {
  final List<DirectionFollowupAlert> alerts;

  const _DirectionAlertsCard({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alertas y recordatorios',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            const Text(
              'Sin alertas relevantes.',
              style: TextStyle(color: kDirectionMutedText),
            ),
          ...alerts.map((alert) {
            final color = switch (alert.severity) {
              DirectionFollowupSeverity.info => const Color(0xFF7FD7FF),
              DirectionFollowupSeverity.warning => const Color(0xFFFFC36D),
              DirectionFollowupSeverity.critical => const Color(0xFFFF7B7B),
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notifications_active_rounded, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.title,
                            style: const TextStyle(
                              color: kDirectionSurfaceText,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            alert.detail,
                            style: const TextStyle(
                              color: kDirectionMutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DirectionPurchasePendingListCard extends StatelessWidget {
  final List<DirectionPurchasePendingItem> items;
  final bool runningAction;
  final Future<void> Function(DirectionPurchasePendingItem item) onOpenOrder;
  final Future<void> Function(DirectionPurchasePendingItem item) onAuthorize;
  final Future<void> Function(DirectionPurchasePendingItem item) onReject;

  const _DirectionPurchasePendingListCard({
    required this.items,
    required this.runningAction,
    required this.onOpenOrder,
    required this.onAuthorize,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pendientes de Dirección',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No hay compras pendientes para autorizar.',
                style: TextStyle(color: kDirectionMutedText),
              ),
            ),
          ...items.map((item) {
            final critical = item.ageHours >= 48;
            final warning = item.ageHours >= 24 && item.ageHours < 48;
            final accent = critical
                ? const Color(0xFFFF7B7B)
                : warning
                ? const Color(0xFFFFC36D)
                : const Color(0xFF7FD7FF);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.folio,
                          style: const TextStyle(
                            color: kDirectionSurfaceText,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.30),
                          ),
                        ),
                        child: Text(
                          '${item.ageHours.round()} h',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${item.targetLabel} · ${item.vendorName.isEmpty ? 'Sin proveedor' : item.vendorName}',
                    style: const TextStyle(
                      color: kDirectionMutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Solicitó: ${item.requestedByName.isEmpty ? '-' : item.requestedByName} · Total: ${_fmtDirectionPurchaseMoney(item.total)}',
                    style: const TextStyle(
                      color: kDirectionMutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.missingReasons.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Le falta: ${item.missingReasons.join(', ')}',
                      style: const TextStyle(
                        color: kDirectionMutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (item.directionComment.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Comentario previo: ${item.directionComment}',
                      style: const TextStyle(
                        color: kDirectionMutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: runningAction
                            ? null
                            : () => onOpenOrder(item),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Abrir orden'),
                      ),
                      FilledButton.icon(
                        onPressed: runningAction
                            ? null
                            : () => onAuthorize(item),
                        icon: const Icon(Icons.verified_rounded),
                        label: const Text('Autorizar'),
                      ),
                      OutlinedButton.icon(
                        onPressed: runningAction ? null : () => onReject(item),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Rechazar'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
