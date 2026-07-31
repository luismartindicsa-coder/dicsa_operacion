import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dashboard/general_dashboard_page.dart';
import '../maintenance/maintenance_page.dart';
import '../maintenance/maintenance_statuses.dart';
import '../shared/app_shell.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/utils/number_formatters.dart';
import 'direction_cash_entries_exits_page.dart';
import 'direction_menudeo_analysis_page.dart';
import 'direction_operations_repository.dart';
import 'direction_purchase_orders_page.dart';
import 'direction_theme.dart';

String _fmtDirectionMaintenanceMoney(num value) => formatMoney(value);

class DirectionMaintenancePage extends StatefulWidget {
  final bool instantOpen;

  const DirectionMaintenancePage({super.key, this.instantOpen = false});

  @override
  State<DirectionMaintenancePage> createState() =>
      _DirectionMaintenancePageState();
}

class _DirectionMaintenancePageState extends State<DirectionMaintenancePage> {
  final DirectionOperationsRepository _repo = DirectionOperationsRepository();
  bool _menuOpen = false;
  bool _loading = true;
  String? _error;
  DirectionMaintenanceSummary? _summary;
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
        .channel('direction-maintenance-followup')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_orders',
          callback: (_) => unawaited(_load(silent: true)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_status_log',
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
      final summary = await _repo.loadMaintenanceSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar Mantenimiento OT: $e';
        _loading = false;
      });
    }
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

  Future<void> _openPurchaseOrdersFollowup() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const DirectionPurchaseOrdersPage(instantOpen: true),
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

  Future<void> _openMaintenanceWorkspace({String? orderId}) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: MaintenancePage(initialOrderId: orderId),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
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
            title: 'Mantenimiento OT Dirección',
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
                icon: Icons.build_circle_outlined,
                title: 'OT ABIERTAS',
                value: '${summary.openCount}',
                detail: 'Órdenes activas en operación',
                accent: directionAreaTokens.primary,
              ),
              DirectionMetricCard(
                icon: Icons.priority_high_rounded,
                title: 'CRÍTICAS',
                value: '${summary.criticalCount}',
                detail: 'Paro total o alta prioridad',
                accent: kDirectionDanger,
              ),
              DirectionMetricCard(
                icon: Icons.timelapse_rounded,
                title: 'SIN MOVIMIENTO',
                value: '${summary.staleCount}',
                detail: 'Más de 48h sin actualización',
                accent: kDirectionWarning,
              ),
              DirectionMetricCard(
                icon: Icons.rule_folder_outlined,
                title: 'EN COTIZACIÓN',
                value: '${summary.waitingDirectionCount}',
                detail: 'Cotización o autorización financiera',
                accent: directionAreaTokens.accent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          DirectionToolbarPanel(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Esta vista concentra recordatorios ejecutivos para que Dirección detecte OT estancadas, críticas o esperando seguimiento.',
                    style: const TextStyle(
                      color: kDirectionMutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _openMaintenanceWorkspace,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir Mantenimiento'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1100;
              final alertsCard = _DirectionMaintenanceAlertsCard(
                alerts: summary.alerts,
              );
              final listCard = _DirectionMaintenancePendingListCard(
                items: summary.pendingItems,
                onOpenMaintenance: _openMaintenanceWorkspace,
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
              DirectionModuleMenuEntry(
                icon: Icons.shopping_cart_checkout_rounded,
                title: 'Compras OT',
                subtitle: 'Autorización y rechazo rápido',
                onTap: _openPurchaseOrdersFollowup,
              ),
              const DirectionModuleMenuEntry(
                icon: Icons.build_circle_outlined,
                title: 'Mantenimiento OT',
                subtitle: 'Seguimiento y alertas',
                current: true,
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

class _DirectionMaintenanceAlertsCard extends StatelessWidget {
  final List<DirectionFollowupAlert> alerts;

  const _DirectionMaintenanceAlertsCard({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alertas y seguimiento',
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
              DirectionFollowupSeverity.info => kDirectionOliveGlow,
              DirectionFollowupSeverity.warning => kDirectionWarning,
              DirectionFollowupSeverity.critical => kDirectionDanger,
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
                    Icon(Icons.warning_amber_rounded, color: color),
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

class _DirectionMaintenancePendingListCard extends StatelessWidget {
  final List<DirectionMaintenancePendingItem> items;
  final Future<void> Function({String? orderId}) onOpenMaintenance;

  const _DirectionMaintenancePendingListCard({
    required this.items,
    required this.onOpenMaintenance,
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
            'OT que requieren seguimiento',
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
                'No hay OT críticas o estancadas para seguimiento.',
                style: TextStyle(color: kDirectionMutedText),
              ),
            ),
          ...items.map((item) {
            final critical =
                item.impact == 'paro_total' ||
                (item.priority == 'alta' && item.ageHours >= 24);
            final warning = item.ageHours >= 48 || item.waitingDirection;
            final accent = critical
                ? kDirectionDanger
                : warning
                ? kDirectionWarning
                : kDirectionOliveGlow;
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
                    '${item.areaLabel.isEmpty ? '-' : item.areaLabel} · ${item.equipmentLabel.isEmpty ? 'Sin equipo' : item.equipmentLabel}',
                    style: const TextStyle(
                      color: kDirectionMutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${maintenanceStatusLabel(item.status)} · ${item.priority} · ${item.impact}',
                    style: const TextStyle(
                      color: kDirectionMutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Estimado: ${_fmtDirectionMaintenanceMoney(item.estimatedTotal)} · Real: ${_fmtDirectionMaintenanceMoney(item.actualTotal)}',
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
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => onOpenMaintenance(orderId: item.id),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Abrir OT'),
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
