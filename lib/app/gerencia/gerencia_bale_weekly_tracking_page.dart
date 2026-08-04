import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/archetypes/dashboard/empty_area_dashboard.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/utils/number_formatters.dart';
import 'gerencia_area_chrome.dart';
import 'gerencia_bale_weekly_tracking_store.dart';
import 'gerencia_dashboard_page.dart';
import 'gerencia_theme.dart';

class GerenciaBaleWeeklyTrackingPage extends StatefulWidget {
  final bool instantOpen;
  final DateTime? initialWeekStartDate;

  const GerenciaBaleWeeklyTrackingPage({
    super.key,
    this.instantOpen = false,
    this.initialWeekStartDate,
  });

  @override
  State<GerenciaBaleWeeklyTrackingPage> createState() =>
      _GerenciaBaleWeeklyTrackingPageState();
}

class _GerenciaBaleWeeklyTrackingPageState
    extends State<GerenciaBaleWeeklyTrackingPage> {
  static const Duration _kSilentReloadInterval = Duration(seconds: 60);

  bool _menuOpen = false;
  bool _loading = true;
  bool _canReturnToDirection = false;
  bool _refreshing = false;
  late DateTime _visibleWeekStartDate;
  GerenciaBaleWeeklyTrackingBundle? _bundle;
  Timer? _reloadTimer;
  RealtimeChannel? _weeklyTrackingChannel;

  @override
  void initState() {
    super.initState();
    _visibleWeekStartDate =
        GerenciaBaleWeeklyTrackingStore.normalizeWeekStartDate(
          widget.initialWeekStartDate ??
              GerenciaBaleWeeklyTrackingStore.currentWeekStartDate(),
        );
    unawaited(_resolveNavigationAccess());
    unawaited(_load());
    _reloadTimer = Timer.periodic(_kSilentReloadInterval, (_) {
      unawaited(_load(silent: true, forceRefresh: true));
    });
    _weeklyTrackingChannel = Supabase.instance.client
        .channel('gerencia-weekly-tracking-refresh')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_movements_v2',
          callback: (_) => unawaited(_load(silent: true, forceRefresh: true)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'gerencia_bale_weekly_plan_lines',
          callback: (_) => unawaited(_load(silent: true, forceRefresh: true)),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _weeklyTrackingChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
    });
  }

  Future<void> _load({bool silent = false, bool forceRefresh = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent || _bundle == null) {
      setState(() => _loading = true);
    }
    try {
      final bundle = await GerenciaBaleWeeklyTrackingStore.loadWeek(
        _visibleWeekStartDate,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (!silent || _bundle == null) {
        setState(() => _loading = false);
      }
    } finally {
      _refreshing = false;
    }
  }

  bool get _isViewingCurrentWeek =>
      _visibleWeekStartDate ==
      GerenciaBaleWeeklyTrackingStore.currentWeekStartDate();

  bool get _canGoToNextWeek => _visibleWeekStartDate.isBefore(
    GerenciaBaleWeeklyTrackingStore.currentWeekStartDate(),
  );

  Future<void> _changeVisibleWeek(DateTime nextWeekStartDate) async {
    final normalized = GerenciaBaleWeeklyTrackingStore.normalizeWeekStartDate(
      nextWeekStartDate,
    );
    if (normalized == _visibleWeekStartDate) return;
    if (mounted) {
      setState(() {
        _visibleWeekStartDate = normalized;
      });
    } else {
      _visibleWeekStartDate = normalized;
    }
    await _load(forceRefresh: true);
  }

  Future<void> _openPreviousWeek() async {
    await _changeVisibleWeek(
      _visibleWeekStartDate.subtract(const Duration(days: 7)),
    );
  }

  Future<void> _openCurrentWeek() async {
    await _changeVisibleWeek(
      GerenciaBaleWeeklyTrackingStore.currentWeekStartDate(),
    );
  }

  Future<void> _openNextWeek() async {
    if (!_canGoToNextWeek) return;
    await _changeVisibleWeek(
      _visibleWeekStartDate.add(const Duration(days: 7)),
    );
  }

  Future<void> _logout() async {
    await signOutAndRouteToLogin(context);
  }

  Future<void> _openDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GerenciaDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _createPlan() async {
    final bundle = _bundle;
    if (bundle == null) return;
    await GerenciaBaleWeeklyTrackingStore.createCurrentWeekPlan(
      weekStartDate: bundle.weekStartDate,
      weekEndDate: bundle.weekEndDate,
      baleTypes: bundle.baleTypes,
    );
    await _load();
  }

  Future<void> _editLine(GerenciaBaleWeeklyPlanLineRecord line) async {
    final productionController = TextEditingController(
      text: line.productionTargetBales.toString(),
    );
    final shipmentController = TextEditingController(
      text: line.shipmentTargetBales.toString(),
    );
    final notesController = TextEditingController(text: line.notes);
    final productionFocusNode = FocusNode(debugLabel: 'gerencia_prod_target');
    final shipmentFocusNode = FocusNode(debugLabel: 'gerencia_ship_target');
    final notesFocusNode = FocusNode(debugLabel: 'gerencia_notes');
    final cancelFocusNode = FocusNode(debugLabel: 'gerencia_cancel');
    final saveFocusNode = FocusNode(debugLabel: 'gerencia_save');
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AreaThemeScope(
          tokens: gerenciaAreaTokens,
          child: Shortcuts(
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
              SingleActivator(LogicalKeyboardKey.arrowLeft):
                  _PreviousDialogFocusIntent(),
              SingleActivator(LogicalKeyboardKey.arrowRight):
                  _NextDialogFocusIntent(),
              SingleActivator(LogicalKeyboardKey.enter): _SubmitDialogIntent(),
              SingleActivator(LogicalKeyboardKey.numpadEnter):
                  _SubmitDialogIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                DismissIntent: CallbackAction<DismissIntent>(
                  onInvoke: (_) {
                    Navigator.of(dialogContext).pop(false);
                    return null;
                  },
                ),
                _PreviousDialogFocusIntent:
                    CallbackAction<_PreviousDialogFocusIntent>(
                      onInvoke: (_) {
                        FocusScope.of(dialogContext).previousFocus();
                        return null;
                      },
                    ),
                _NextDialogFocusIntent: CallbackAction<_NextDialogFocusIntent>(
                  onInvoke: (_) {
                    FocusScope.of(dialogContext).nextFocus();
                    return null;
                  },
                ),
                _SubmitDialogIntent: CallbackAction<_SubmitDialogIntent>(
                  onInvoke: (_) {
                    Navigator.of(dialogContext).pop(true);
                    return null;
                  },
                ),
              },
              child: Focus(
                autofocus: true,
                child: ContractDialogShell(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Editar ${_labelForType(line.baleTypeKey)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          focusNode: productionFocusNode,
                          controller: productionController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Meta producción',
                            hintText: 'Pacas de producción',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          focusNode: shipmentFocusNode,
                          controller: shipmentController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Meta embarque',
                            hintText: 'Pacas de embarque',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          focusNode: notesFocusNode,
                          controller: notesController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Nota',
                            hintText: 'Comentario ejecutivo opcional',
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              focusNode: cancelFocusNode,
                              style: contractSecondaryButtonStyle(
                                dialogContext,
                              ),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              focusNode: saveFocusNode,
                              style: contractPrimaryButtonStyle(dialogContext),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Guardar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    productionFocusNode.dispose();
    shipmentFocusNode.dispose();
    notesFocusNode.dispose();
    cancelFocusNode.dispose();
    saveFocusNode.dispose();
    if (result != true) return;
    final productionTarget = int.tryParse(productionController.text.trim());
    final shipmentTarget = int.tryParse(shipmentController.text.trim());
    if (productionTarget == null ||
        productionTarget < 0 ||
        shipmentTarget == null ||
        shipmentTarget < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Captura metas válidas de producción y embarque.'),
        ),
      );
      return;
    }
    await GerenciaBaleWeeklyTrackingStore.updatePlanLine(
      line,
      productionTargetBales: productionTarget,
      shipmentTargetBales: shipmentTarget,
      notes: notesController.text,
    );
    await _load();
  }

  String _labelForType(String key) {
    final bundle = _bundle;
    if (bundle == null) return key;
    for (final type in bundle.baleTypes) {
      if (type.key == key) return type.label;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: gerenciaAreaTokens,
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
          background: const _GerenciaTrackingBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => _GerenciaHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => const _GerenciaTrackingHeaderBrand(),
          trailingBuilder: (_, _) => _GerenciaHeaderButton(
            label: 'Cerrar sesión',
            icon: Icons.logout_rounded,
            onTap: _logout,
          ),
          child: Stack(
            children: [
              _GerenciaTrackingBody(
                loading: _loading,
                bundle: _bundle,
                isViewingCurrentWeek: _isViewingCurrentWeek,
                canGoToNextWeek: _canGoToNextWeek,
                onOpenPreviousWeek: _openPreviousWeek,
                onOpenCurrentWeek: _openCurrentWeek,
                onOpenNextWeek: _openNextWeek,
                onCreatePlan: _createPlan,
                onEditLine: _editLine,
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_menuOpen,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _menuOpen ? 1 : 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _menuOpen = false),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: _menuOpen ? 0 : -332,
                top: 0,
                bottom: 0,
                width: 320,
                child: IgnorePointer(
                  ignoring: !_menuOpen,
                  child: _GerenciaSidePanel(
                    label: 'Gerencia',
                    canReturnToDirection: _canReturnToDirection,
                    onOpenDashboard: () async {
                      setState(() => _menuOpen = false);
                      await _openDashboard();
                    },
                    onOpenDirectionDashboard: _canReturnToDirection
                        ? () async {
                            setState(() => _menuOpen = false);
                            await _openDirectionDashboard();
                          }
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GerenciaTrackingBody extends StatelessWidget {
  final bool loading;
  final GerenciaBaleWeeklyTrackingBundle? bundle;
  final bool isViewingCurrentWeek;
  final bool canGoToNextWeek;
  final Future<void> Function() onOpenPreviousWeek;
  final Future<void> Function() onOpenCurrentWeek;
  final Future<void> Function() onOpenNextWeek;
  final Future<void> Function() onCreatePlan;
  final Future<void> Function(GerenciaBaleWeeklyPlanLineRecord line) onEditLine;

  const _GerenciaTrackingBody({
    required this.loading,
    required this.bundle,
    required this.isViewingCurrentWeek,
    required this.canGoToNextWeek,
    required this.onOpenPreviousWeek,
    required this.onOpenCurrentWeek,
    required this.onOpenNextWeek,
    required this.onCreatePlan,
    required this.onEditLine,
  });

  @override
  Widget build(BuildContext context) {
    final plan = bundle?.currentPlan;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GerenciaHeroCard(
                bundle: bundle,
                hasPlan: plan != null,
                isViewingCurrentWeek: isViewingCurrentWeek,
                canGoToNextWeek: canGoToNextWeek,
                onOpenPreviousWeek: onOpenPreviousWeek,
                onOpenCurrentWeek: onOpenCurrentWeek,
                onOpenNextWeek: onOpenNextWeek,
              ),
              const SizedBox(height: 18),
              if (!loading &&
                  bundle != null &&
                  isViewingCurrentWeek &&
                  bundle!.totalProductionActual <= 0 &&
                  bundle!.totalShipmentActual <= 0) ...[
                _GerenciaWeekHintCard(onOpenPreviousWeek: onOpenPreviousWeek),
                const SizedBox(height: 18),
              ],
              if (loading)
                const _GerenciaLoadingPanel()
              else if (bundle == null)
                const _GerenciaErrorPanel()
              else ...[
                if (plan == null) ...[
                  _GerenciaEmptyPlanPanel(
                    bundle: bundle!,
                    onCreatePlan: onCreatePlan,
                  ),
                  const SizedBox(height: 18),
                ],
                _GerenciaKpiRow(bundle: bundle!, plan: plan),
                const SizedBox(height: 18),
                _GerenciaVisualSummary(bundle: bundle!),
                const SizedBox(height: 18),
                _GerenciaPlanBoard(bundle: bundle!, onEditLine: onEditLine),
                const SizedBox(height: 18),
                _GerenciaDailyBreakdown(bundle: bundle!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GerenciaHeroCard extends StatelessWidget {
  final GerenciaBaleWeeklyTrackingBundle? bundle;
  final bool hasPlan;
  final bool isViewingCurrentWeek;
  final bool canGoToNextWeek;
  final Future<void> Function() onOpenPreviousWeek;
  final Future<void> Function() onOpenCurrentWeek;
  final Future<void> Function() onOpenNextWeek;

  const _GerenciaHeroCard({
    required this.bundle,
    required this.hasPlan,
    required this.isViewingCurrentWeek,
    required this.canGoToNextWeek,
    required this.onOpenPreviousWeek,
    required this.onOpenCurrentWeek,
    required this.onOpenNextWeek,
  });

  @override
  Widget build(BuildContext context) {
    final start = bundle?.weekStartDate;
    final end = bundle?.weekEndDate;
    final weekLabel = start == null || end == null
        ? 'Semana actual'
        : 'Semana ${_isoWeekNumber(start)} · ${_shortDate(start)} - ${_shortDate(end)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B1623), Color(0xFF25080F)],
        ),
        border: Border.all(color: const Color(0x40FF9FA7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SEGUIMIENTO SEMANAL DE PACAS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                    color: const Color(0xFFFFC8CF).withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Plan semanal manual de Gerencia con base lista para conectar producción y embarques reales desde Operación.',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  weekLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFDDE1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatusCapsule(
                label: hasPlan ? 'Plan activo' : 'Sin plan',
                tone: hasPlan
                    ? const Color(0xFFB23346)
                    : const Color(0xFF784B12),
              ),
              const SizedBox(height: 14),
              _GerenciaWeekNavigator(
                isViewingCurrentWeek: isViewingCurrentWeek,
                canGoToNextWeek: canGoToNextWeek,
                onOpenPreviousWeek: onOpenPreviousWeek,
                onOpenCurrentWeek: onOpenCurrentWeek,
                onOpenNextWeek: onOpenNextWeek,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GerenciaKpiRow extends StatelessWidget {
  final GerenciaBaleWeeklyTrackingBundle bundle;
  final GerenciaBaleWeeklyPlanRecord? plan;

  const _GerenciaKpiRow({required this.bundle, required this.plan});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _KpiCard(
          title: 'Meta producción',
          value:
              '${formatDecimal(plan?.totalProductionTarget ?? 0, decimals: 0)} pacas',
          subtitle:
              'Real ${formatDecimal(bundle.totalProductionActual, decimals: 0)} · Est ${formatDecimal(bundle.totalProductionEstimated, decimals: 0)}',
          icon: Icons.precision_manufacturing_rounded,
        ),
        _KpiCard(
          title: 'Meta embarque',
          value:
              '${formatDecimal(plan?.totalShipmentTarget ?? 0, decimals: 0)} pacas',
          subtitle:
              'Real ${formatDecimal(bundle.totalShipmentActual, decimals: 0)} · Est ${formatDecimal(bundle.totalShipmentEstimated, decimals: 0)}',
          icon: Icons.local_shipping_rounded,
        ),
        _KpiCard(
          title: 'Necesidad restante',
          value:
              'Prod ${formatDecimal(bundle.totalProductionNeed, decimals: 0)} · Emb ${formatDecimal(bundle.totalShipmentNeed, decimals: 0)}',
          subtitle: 'Faltante contra el plan actual',
          icon: Icons.flag_outlined,
        ),
      ],
    );
  }
}

class _GerenciaVisualSummary extends StatelessWidget {
  final GerenciaBaleWeeklyTrackingBundle bundle;

  const _GerenciaVisualSummary({required this.bundle});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final summary in bundle.lineSummaries)
          _VisualTypeCard(summary: summary),
      ],
    );
  }
}

class _GerenciaPlanBoard extends StatelessWidget {
  final GerenciaBaleWeeklyTrackingBundle bundle;
  final Future<void> Function(GerenciaBaleWeeklyPlanLineRecord line) onEditLine;

  const _GerenciaPlanBoard({required this.bundle, required this.onEditLine});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xCC19070D),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x40FF9AA6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan semanal base',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Lectura ejecutiva homologada sin scroll horizontal. Cada tarjeta resume plan, real, estimación y faltante por tipo.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xCCFFE7EA),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final summary in bundle.lineSummaries)
                _GerenciaTypeExecutionCard(
                  summary: summary,
                  note: summary.planLine?.notes.isEmpty ?? true
                      ? 'Sin nota'
                      : summary.planLine!.notes,
                  onEdit: summary.planLine == null
                      ? null
                      : () => onEditLine(summary.planLine!),
                ),
            ],
          ),
          if (bundle.unmappedProductionCodes.isNotEmpty ||
              bundle.unmappedShipmentCodes.isNotEmpty) ...[
            const SizedBox(height: 14),
            _UnmappedWarning(
              productionCodes: bundle.unmappedProductionCodes,
              shipmentCodes: bundle.unmappedShipmentCodes,
            ),
          ],
        ],
      ),
    );
  }
}

class _GerenciaWeekNavigator extends StatelessWidget {
  final bool isViewingCurrentWeek;
  final bool canGoToNextWeek;
  final Future<void> Function() onOpenPreviousWeek;
  final Future<void> Function() onOpenCurrentWeek;
  final Future<void> Function() onOpenNextWeek;

  const _GerenciaWeekNavigator({
    required this.isViewingCurrentWeek,
    required this.canGoToNextWeek,
    required this.onOpenPreviousWeek,
    required this.onOpenCurrentWeek,
    required this.onOpenNextWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        _GerenciaWeekNavButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Semana anterior',
          onPressed: onOpenPreviousWeek,
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(
              color: isViewingCurrentWeek
                  ? Colors.white.withValues(alpha: 0.18)
                  : const Color(0x66FFE4E8),
            ),
            backgroundColor: isViewingCurrentWeek
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            minimumSize: const Size(0, 44),
          ),
          onPressed: isViewingCurrentWeek ? null : onOpenCurrentWeek,
          icon: const Icon(Icons.today_rounded, size: 18),
          label: Text(isViewingCurrentWeek ? 'Semana actual' : 'Ir a actual'),
        ),
        _GerenciaWeekNavButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Semana siguiente',
          onPressed: canGoToNextWeek ? onOpenNextWeek : null,
        ),
      ],
    );
  }
}

class _GerenciaWeekNavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Future<void> Function()? onPressed;

  const _GerenciaWeekNavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.03),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          minimumSize: const Size(44, 44),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _GerenciaWeekHintCard extends StatelessWidget {
  final Future<void> Function() onOpenPreviousWeek;

  const _GerenciaWeekHintCard({required this.onOpenPreviousWeek});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xCC19070D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x40FF9AA6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: Color(0xFFFFC07A)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Esta semana todavía no tiene producción ni embarques. Si buscas capturas anteriores, abre la semana pasada con la navegación.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xCCFFE4E8),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: contractSecondaryButtonStyle(context),
            onPressed: onOpenPreviousWeek,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Semana anterior'),
          ),
        ],
      ),
    );
  }
}

class _GerenciaEmptyPlanPanel extends StatelessWidget {
  final GerenciaBaleWeeklyTrackingBundle bundle;
  final Future<void> Function() onCreatePlan;

  const _GerenciaEmptyPlanPanel({
    required this.bundle,
    required this.onCreatePlan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xCC19070D),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x40FF9AA6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aún no existe plan semanal',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea la semana ${_isoWeekNumber(bundle.weekStartDate)} para empezar a capturar metas de producción y embarque por tipo de paca.',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xCCFFE7EA),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: contractPrimaryButtonStyle(context),
            onPressed: onCreatePlan,
            icon: const Icon(Icons.playlist_add_rounded),
            label: const Text('Crear plan base de la semana'),
          ),
        ],
      ),
    );
  }
}

class _GerenciaLoadingPanel extends StatelessWidget {
  const _GerenciaLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _GerenciaErrorPanel extends StatelessWidget {
  const _GerenciaErrorPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xCC19070D),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x40FF9AA6)),
      ),
      child: const Text(
        'No fue posible cargar esta superficie. Revisa que la migración de Gerencia esté aplicada y vuelve a intentar.',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _GerenciaDailyBreakdown extends StatelessWidget {
  final GerenciaBaleWeeklyTrackingBundle bundle;

  const _GerenciaDailyBreakdown({required this.bundle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xCC19070D),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x40FF9AA6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Desglose diario de la semana',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Producción y embarque real por día a partir de Operación.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xCCFFE7EA),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final summary in bundle.lineSummaries)
                _DailyTypeCard(summary: summary),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyTypeCard extends StatelessWidget {
  final GerenciaBaleWeeklyLineSummary summary;

  const _DailyTypeCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xD9230B12),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x40FF9FA7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.baleType.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            for (final day in summary.dailyActuals)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _weekdayShort(day.opDate),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFFC7CF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _DailyMetricRow(
                        label: 'Producción',
                        dayValue: day.productionBales,
                        actualCumulative: day.actualProductionCumulativeBales,
                        expectedCumulative:
                            day.expectedProductionCumulativeBales,
                        delta: day.productionDeltaBales,
                      ),
                      const SizedBox(height: 6),
                      _DailyMetricRow(
                        label: 'Embarque',
                        dayValue: day.shipmentBales,
                        actualCumulative: day.actualShipmentCumulativeBales,
                        expectedCumulative: day.expectedShipmentCumulativeBales,
                        delta: day.shipmentDeltaBales,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DailyMetricRow extends StatelessWidget {
  final String label;
  final int dayValue;
  final int actualCumulative;
  final int expectedCumulative;
  final int delta;

  const _DailyMetricRow({
    required this.label,
    required this.dayValue,
    required this.actualCumulative,
    required this.expectedCumulative,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final status = _dailyDeltaStatus(
      delta: delta,
      expectedCumulative: expectedCumulative,
    );
    final deltaColor = status.color;
    final deltaLabel = delta > 0
        ? '+${formatDecimal(delta, decimals: 0)}'
        : formatDecimal(delta, decimals: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$label · día ${formatDecimal(dayValue, decimals: 0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFFE4E8),
                ),
              ),
            ),
            _DeltaStatusChip(status: status),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Acum ${formatDecimal(actualCumulative, decimals: 0)} vs esp ${formatDecimal(expectedCumulative, decimals: 0)}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xCCFFE4E8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Delta $deltaLabel',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: deltaColor,
          ),
        ),
      ],
    );
  }
}

class _DeltaStatusChip extends StatelessWidget {
  final _DailyDeltaStatus status;

  const _DeltaStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: 0.42)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: status.color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _DailyDeltaStatus {
  final String label;
  final Color color;

  const _DailyDeltaStatus({required this.label, required this.color});
}

class _PreviousDialogFocusIntent extends Intent {
  const _PreviousDialogFocusIntent();
}

class _NextDialogFocusIntent extends Intent {
  const _NextDialogFocusIntent();
}

class _SubmitDialogIntent extends Intent {
  const _SubmitDialogIntent();
}

_DailyDeltaStatus _dailyDeltaStatus({
  required int delta,
  required int expectedCumulative,
}) {
  final tolerance = expectedCumulative <= 0
      ? 2
      : ((expectedCumulative * 0.08).round() < 2
            ? 2
            : (expectedCumulative * 0.08).round());
  if (delta > tolerance) {
    return const _DailyDeltaStatus(
      label: 'ADELANTADO',
      color: Color(0xFF89E8A8),
    );
  }
  if (delta < -tolerance) {
    return const _DailyDeltaStatus(label: 'ATRASADO', color: Color(0xFFFFA0AA));
  }
  return const _DailyDeltaStatus(label: 'EN LINEA', color: Color(0xFFFFD89E));
}

class _WeeklyLaneStatus {
  final String label;
  final String shortLabel;
  final String description;
  final Color color;
  final int severity;

  const _WeeklyLaneStatus({
    required this.label,
    required this.shortLabel,
    required this.description,
    required this.color,
    required this.severity,
  });
}

_WeeklyLaneStatus _weeklyLaneStatus({
  required int actual,
  required int expected,
  required int need,
}) {
  if (need <= 0 && actual > 0) {
    return const _WeeklyLaneStatus(
      label: 'CUMPLE',
      shortLabel: 'cumple',
      description: 'La meta ya se cumplió o quedó cubierta.',
      color: Color(0xFF89E8A8),
      severity: 0,
    );
  }
  if (expected <= 0) {
    return const _WeeklyLaneStatus(
      label: 'SIN META',
      shortLabel: 'sin meta',
      description: 'No existe meta suficiente para evaluar el ritmo.',
      color: Color(0xFFFFD89E),
      severity: 1,
    );
  }
  final delta = actual - expected;
  final tolerance = ((expected * 0.08).round() < 2)
      ? 2
      : (expected * 0.08).round();
  if (delta > tolerance) {
    return const _WeeklyLaneStatus(
      label: 'ADELANTADO',
      shortLabel: 'adelantado',
      description: 'Va por encima del ritmo esperado.',
      color: Color(0xFF89E8A8),
      severity: 0,
    );
  }
  if (delta < -tolerance) {
    return const _WeeklyLaneStatus(
      label: 'ATRASADO',
      shortLabel: 'atrasado',
      description: 'Va por debajo del ritmo esperado.',
      color: Color(0xFFFFA0AA),
      severity: 2,
    );
  }
  return const _WeeklyLaneStatus(
    label: 'EN LINEA',
    shortLabel: 'en línea',
    description: 'Va dentro del rango esperado.',
    color: Color(0xFFFFD89E),
    severity: 1,
  );
}

_WeeklyLaneStatus _mergeWeeklyStatuses(
  _WeeklyLaneStatus production,
  _WeeklyLaneStatus shipment,
) {
  return production.severity >= shipment.severity ? production : shipment;
}

class _VisualTypeCard extends StatelessWidget {
  final GerenciaBaleWeeklyLineSummary summary;

  const _VisualTypeCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final productionStatus = _weeklyLaneStatus(
      actual: summary.productionActualBales,
      expected: summary.productionEstimatedBales,
      need: summary.productionNeedBales,
    );
    final shipmentStatus = _weeklyLaneStatus(
      actual: summary.shipmentActualBales,
      expected: summary.shipmentEstimatedBales,
      need: summary.shipmentNeedBales,
    );
    final overallStatus = _mergeWeeklyStatuses(
      productionStatus,
      shipmentStatus,
    );
    return SizedBox(
      width: 420,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xD9230B12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x40FF9FA7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary.baleType.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                _WeeklyStatusChip(status: overallStatus),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Producción ${productionStatus.shortLabel} · Embarque ${shipmentStatus.shortLabel}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xCCFFE4E8),
              ),
            ),
            const SizedBox(height: 14),
            _ProgressLane(
              label: 'Producción',
              actual: summary.productionActualBales,
              target: summary.productionTargetBales,
              ratio: summary.productionProgressRatio,
              accent: const Color(0xFFFF7C89),
            ),
            const SizedBox(height: 12),
            _ProgressLane(
              label: 'Embarque',
              actual: summary.shipmentActualBales,
              target: summary.shipmentTargetBales,
              ratio: summary.shipmentProgressRatio,
              accent: const Color(0xFFFFB36A),
            ),
          ],
        ),
      ),
    );
  }
}

class _GerenciaTypeExecutionCard extends StatelessWidget {
  final GerenciaBaleWeeklyLineSummary summary;
  final String note;
  final VoidCallback? onEdit;

  const _GerenciaTypeExecutionCard({
    required this.summary,
    required this.note,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final productionStatus = _weeklyLaneStatus(
      actual: summary.productionActualBales,
      expected: summary.productionEstimatedBales,
      need: summary.productionNeedBales,
    );
    final shipmentStatus = _weeklyLaneStatus(
      actual: summary.shipmentActualBales,
      expected: summary.shipmentEstimatedBales,
      need: summary.shipmentNeedBales,
    );
    final overallStatus = _mergeWeeklyStatuses(
      productionStatus,
      shipmentStatus,
    );
    return SizedBox(
      width: 430,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xD9230B12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x40FF9FA7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary.baleType.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                _WeeklyStatusChip(status: overallStatus),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: contractSecondaryButtonStyle(context),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MetricSection(
              title: 'Producción',
              target: summary.productionTargetBales,
              actual: summary.productionActualBales,
              estimated: summary.productionEstimatedBales,
              need: summary.productionNeedBales,
              ratio: summary.productionProgressRatio,
              estimatedRatio: summary.productionEstimatedRatio,
              accent: const Color(0xFFFF7C89),
              status: productionStatus,
            ),
            const SizedBox(height: 14),
            _MetricSection(
              title: 'Embarque',
              target: summary.shipmentTargetBales,
              actual: summary.shipmentActualBales,
              estimated: summary.shipmentEstimatedBales,
              need: summary.shipmentNeedBales,
              ratio: summary.shipmentProgressRatio,
              estimatedRatio: summary.shipmentEstimatedRatio,
              accent: const Color(0xFFFFB36A),
              status: shipmentStatus,
            ),
            const SizedBox(height: 12),
            Text(
              note,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xCCFFE4E8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricSection extends StatelessWidget {
  final String title;
  final int target;
  final int actual;
  final int estimated;
  final int need;
  final double? ratio;
  final double? estimatedRatio;
  final Color accent;
  final _WeeklyLaneStatus status;

  const _MetricSection({
    required this.title,
    required this.target,
    required this.actual,
    required this.estimated,
    required this.need,
    required this.ratio,
    required this.estimatedRatio,
    required this.accent,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xCC17070C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status.description,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: status.color,
            ),
          ),
          const SizedBox(height: 12),
          _MetricFacts(
            target: target,
            actual: actual,
            estimated: estimated,
            need: need,
          ),
          const SizedBox(height: 12),
          _ProgressLane(
            label: 'Real',
            actual: actual,
            target: target,
            ratio: ratio,
            accent: accent,
          ),
          const SizedBox(height: 10),
          _ProgressLane(
            label: 'Estimación',
            actual: estimated,
            target: target,
            ratio: estimatedRatio,
            accent: accent.withValues(alpha: 0.72),
          ),
        ],
      ),
    );
  }
}

class _WeeklyStatusChip extends StatelessWidget {
  final _WeeklyLaneStatus status;

  const _WeeklyStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: 0.42)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: status.color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _MetricFacts extends StatelessWidget {
  final int target;
  final int actual;
  final int estimated;
  final int need;

  const _MetricFacts({
    required this.target,
    required this.actual,
    required this.estimated,
    required this.need,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _FactChip(label: 'Meta', value: target),
        _FactChip(label: 'Real', value: actual),
        _FactChip(label: 'Est', value: estimated),
        _FactChip(label: 'Faltan', value: need),
      ],
    );
  }
}

class _FactChip extends StatelessWidget {
  final String label;
  final int value;

  const _FactChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xCCFFDCE1),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatDecimal(value, decimals: 0),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLane extends StatelessWidget {
  final String label;
  final int actual;
  final int target;
  final double? ratio;
  final Color accent;

  const _ProgressLane({
    required this.label,
    required this.actual,
    required this.target,
    required this.ratio,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final hasTarget = target > 0;
    final safeRatio = hasTarget
        ? (ratio == null ? 0.0 : ratio!.clamp(0.0, 1.4))
        : (actual > 0 ? 1.0 : 0.0);
    final headline = hasTarget
        ? '$label · ${formatDecimal(actual, decimals: 0)} / ${formatDecimal(target, decimals: 0)}'
        : '$label · ${formatDecimal(actual, decimals: 0)} real${actual == 1 ? '' : 'es'}';
    final ratioLabel = hasTarget
        ? (ratio == null ? '—' : '${(ratio! * 100).toStringAsFixed(0)}%')
        : 'Sin meta';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                headline,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFFE4E8),
                ),
              ),
            ),
            Text(
              ratioLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 10,
            color: Colors.white.withValues(alpha: 0.08),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: safeRatio,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.68)],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GerenciaSidePanel extends StatelessWidget {
  final String label;
  final bool canReturnToDirection;
  final Future<void> Function() onOpenDashboard;
  final Future<void> Function()? onOpenDirectionDashboard;

  const _GerenciaSidePanel({
    required this.label,
    required this.canReturnToDirection,
    required this.onOpenDashboard,
    required this.onOpenDirectionDashboard,
  });

  @override
  Widget build(BuildContext context) {
    final accessItems = <DashboardNavAction>[
      if (canReturnToDirection && onOpenDirectionDashboard != null)
        DashboardNavAction(
          title: 'Dashboard Dirección',
          subtitle: 'Vista ejecutiva multiarea',
          icon: Icons.assessment_outlined,
          onTap: onOpenDirectionDashboard!,
        ),
    ];
    final areaItems = <DashboardNavAction>[
      DashboardNavAction(
        title: 'Dashboard Gerencia',
        subtitle: 'Pulso ejecutivo semanal',
        icon: Icons.space_dashboard_rounded,
        onTap: onOpenDashboard,
      ),
      DashboardNavAction(
        title: 'Seguimiento Semanal de Pacas',
        subtitle: 'Plan, real y detalle diario',
        icon: Icons.stacked_line_chart_rounded,
        current: true,
        onTap: _noop,
      ),
    ];
    return GerenciaAreaSidePanel(
      label: label,
      canReturnToDirection: canReturnToDirection,
      areaItems: areaItems,
      accessItems: accessItems,
    );
  }
}

class _UnmappedWarning extends StatelessWidget {
  final List<String> productionCodes;
  final List<String> shipmentCodes;

  const _UnmappedWarning({
    required this.productionCodes,
    required this.shipmentCodes,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (productionCodes.isNotEmpty)
        'Producción sin mapear: ${productionCodes.join(', ')}',
      if (shipmentCodes.isNotEmpty)
        'Embarque sin mapear: ${shipmentCodes.join(', ')}',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0x335E3C04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x66FFBF5D)),
      ),
      child: Text(
        parts.join(' · '),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFFFFD89E),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xD9240B12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x40FF9FA7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFFFB4BC)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFE4E8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xCCFFDCE1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCapsule extends StatelessWidget {
  final String label;
  final Color tone;

  const _StatusCapsule({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.66)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _GerenciaTrackingHeaderBrand extends StatelessWidget {
  const _GerenciaTrackingHeaderBrand();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.44)),
            boxShadow: [
              BoxShadow(
                color: tokens.primaryStrong.withValues(alpha: 0.16),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(child: DicsaLogoD(size: 40, progress: 1)),
        ),
        const SizedBox(width: 14),
        Container(
          width: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: tokens.primaryStrong.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seguimiento Semanal de Pacas',
              maxLines: 1,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
                height: 1.0,
                color: Color(0xFFF6E8EB),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gerencia · plan semanal, producción y embarque',
              style: TextStyle(
                color: tokens.badgeText.withValues(alpha: 0.9),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GerenciaHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _GerenciaHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_GerenciaHeaderButton> createState() => _GerenciaHeaderButtonState();
}

class _GerenciaHeaderButtonState extends State<_GerenciaHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final enabled = widget.onTap != null || widget.onTapSync != null;
    final highlighted = enabled && _hovered;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: highlighted ? 1.026 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            onTap: !enabled
                ? null
                : () async {
                    if (widget.onTap != null) {
                      await widget.onTap!();
                    } else {
                      widget.onTapSync?.call();
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(
                0,
                highlighted ? -2.5 : 0,
                0,
              ),
              width: 186,
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: highlighted ? 0.18 : 0.10),
                    tokens.surfaceTint.withValues(
                      alpha: highlighted ? 0.22 : 0.14,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: highlighted
                      ? Colors.white.withValues(alpha: 0.76)
                      : Colors.white.withValues(alpha: 0.48),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: highlighted ? 28 : 16,
                    color: Colors.black.withValues(
                      alpha: highlighted ? 0.16 : 0.08,
                    ),
                    offset: Offset(0, highlighted ? 14 : 8),
                  ),
                  BoxShadow(
                    blurRadius: highlighted ? 20 : 10,
                    color: tokens.glow.withValues(
                      alpha: highlighted ? 0.14 : 0.05,
                    ),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(widget.icon, size: 20, color: tokens.onGlass),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: tokens.onGlass,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GerenciaTrackingBackground extends StatelessWidget {
  const _GerenciaTrackingBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12060A), Color(0xFF2E0C15), Color(0xFF5D1824)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -90,
            child: _GlowBlob(
              size: 300,
              colors: [Color(0x663A0F17), Color(0x2216070B)],
            ),
          ),
          Positioned(
            top: 40,
            right: -110,
            child: _GlowBlob(
              size: 320,
              colors: [Color(0x66D65767), Color(0x11220B10)],
            ),
          ),
          Positioned(
            bottom: -140,
            left: 120,
            child: _GlowBlob(
              size: 360,
              colors: [Color(0x33B93D50), Color(0x11FFD7DD)],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _GlowBlob({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
        ),
      ),
    );
  }
}

String _shortDate(DateTime date) {
  const months = <String>[
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

int _isoWeekNumber(DateTime date) {
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstThursday = DateTime(thursday.year, 1, 4);
  return 1 + ((thursday.difference(firstThursday).inDays) ~/ 7);
}

Future<void> _noop() async {}

String _weekdayShort(DateTime date) {
  const labels = <String>['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  return labels[date.weekday - 1];
}
