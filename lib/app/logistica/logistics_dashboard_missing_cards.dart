import 'dart:async';

import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'logistics_dashboard_summary.dart';
import 'logistics_theme.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';

const _modules = <LogisticsDashboardModule, (String, IconData)>{
  LogisticsDashboardModule.units: (
    'Estado de Unidades',
    Icons.local_shipping_outlined,
  ),
  LogisticsDashboardModule.incidents: (
    'Incidencias',
    Icons.report_problem_outlined,
  ),
  LogisticsDashboardModule.performance: ('Rendimiento', Icons.speed_rounded),
  LogisticsDashboardModule.savings: (
    'Ahorro y Planeación',
    Icons.route_outlined,
  ),
  LogisticsDashboardModule.catalogs: (
    'Catálogos Operativos',
    Icons.inventory_2_outlined,
  ),
};

class LogisticsDashboardMissingCards extends StatefulWidget {
  final Map<LogisticsDashboardModule, Future<void> Function()> onOpen;
  final Future<LogisticsDashboardSnapshot> Function()? load;
  const LogisticsDashboardMissingCards({
    super.key,
    required this.onOpen,
    this.load,
  });

  @override
  State<LogisticsDashboardMissingCards> createState() =>
      _LogisticsDashboardMissingCardsState();
}

class _LogisticsDashboardMissingCardsState
    extends State<LogisticsDashboardMissingCards>
    with WidgetsBindingObserver {
  LogisticsDashboardSnapshot? _snapshot;
  Timer? _timer;
  bool _refreshing = false, _pending = false, _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_reload());
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (ModalRoute.of(context)?.isCurrent != false && !_opening) {
        unawaited(_reload());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_reload());
  }

  Future<void> _reload() async {
    if (!mounted) return;
    if (_refreshing) {
      _pending = true;
      return;
    }
    _refreshing = true;
    try {
      final snapshot = await (widget.load ?? LogisticsDashboardStore.load)();
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'No se pudo actualizar. Se reintentará automáticamente.',
        );
      }
    } finally {
      _refreshing = false;
      if (_pending && mounted) {
        _pending = false;
        unawaited(_reload());
      }
    }
  }

  Future<void> _open(LogisticsDashboardModule module) async {
    final action = widget.onOpen[module];
    if (_opening || action == null) return;
    _opening = true;
    try {
      await action();
    } finally {
      _opening = false;
      if (mounted) unawaited(_reload());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 930
                ? 3
                : constraints.maxWidth >= 590
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
            // Uniform rows, with enough room for larger accessibility text.
            final height =
                308.0 +
                (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(0, 30) *
                    9;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final module in _modules.keys)
                  SizedBox(
                    width: width,
                    height: height,
                    child: _SummaryCard(
                      key: ValueKey('logistics-summary-${module.name}'),
                      title: _modules[module]!.$1,
                      icon: _modules[module]!.$2,
                      summary: _snapshot?.summaries[module],
                      error: _error,
                      onTap: () => unawaited(_open(module)),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SummaryCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final LogisticsDashboardSummary? summary;
  final String? error;
  final VoidCallback onTap;
  const _SummaryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.summary,
    required this.error,
    required this.onTap,
  });
  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  bool _hover = false, _focused = false;
  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final active = _hover || _focused;
    final summary = widget.summary;
    final error = widget.error ?? summary?.error;
    final muted = tokens.onGlass.withValues(alpha: .68);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, active ? -3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: kLogisticsModuleGradient,
          border: Border.all(
            color: active
                ? tokens.primary
                : tokens.border.withValues(alpha: .55),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: active ? .28 : .16),
              blurRadius: active ? 24 : 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ContractGlassCard(
          padding: EdgeInsets.zero,
          blurSigma: 7,
          elevation: active ? 24 : 18,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onFocusChange: (value) => setState(() => _focused = value),
              borderRadius: BorderRadius.circular(24),
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              splashColor: tokens.primary.withValues(alpha: .12),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(widget.icon, size: 21, color: tokens.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 2,
                            style: TextStyle(
                              color: tokens.onGlass,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                          color: tokens.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary?.period ?? ' ',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                    const SizedBox(height: 16),
                    if (error != null) ...[
                      Icon(Icons.cloud_off_outlined, color: tokens.primary),
                      const SizedBox(height: 10),
                      Text(
                        'Datos no disponibles',
                        style: TextStyle(
                          color: tokens.onGlass,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error,
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Abrir ${widget.title}',
                        style: TextStyle(color: tokens.primary, fontSize: 12),
                      ),
                    ] else if (summary == null) ...[
                      const Spacer(),
                      LinearProgressIndicator(
                        color: tokens.primary,
                        backgroundColor: tokens.surfaceTint,
                      ),
                      const SizedBox(height: 12),
                      Text('Cargando…', style: TextStyle(color: muted)),
                      const Spacer(),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                summary.value,
                                style: TextStyle(
                                  color: tokens.onGlass,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                              ),
                            ),
                          ),
                          if (summary.attention)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: tokens.primary,
                                size: 21,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.label,
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      for (final detail in summary.details)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  detail.$1,
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                detail.$2,
                                style: TextStyle(
                                  color: tokens.onGlass,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      if (summary.note.isNotEmpty)
                        Text(
                          summary.note,
                          style: TextStyle(
                            color: muted,
                            fontSize: 10.5,
                            height: 1.3,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
