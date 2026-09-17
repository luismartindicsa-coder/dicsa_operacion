import 'dart:async';

import 'package:flutter/material.dart';

import '../contabilidad/contabilidad_income_statement_store.dart';
import '../shared/archetypes/auxiliary_surfaces/date_picker_surface.dart';
import '../shared/utils/number_formatters.dart';
import 'direction_theme.dart';

class DirectionAccountingDashboardCard extends StatefulWidget {
  final Future<void> Function(DateTimeRange range) onOpenStatement;
  final Future<ContabilidadIncomeStatementDataset> Function(DateTimeRange)?
  loadStatement;
  final DateTime Function()? now;

  const DirectionAccountingDashboardCard({
    super.key,
    required this.onOpenStatement,
    this.loadStatement,
    this.now,
  });

  @override
  State<DirectionAccountingDashboardCard> createState() =>
      _DirectionAccountingDashboardCardState();
}

class _DirectionAccountingDashboardCardState
    extends State<DirectionAccountingDashboardCard> {
  final _scrollController = ScrollController();
  int _windowDays = 7;
  DateTimeRange? _customRange;
  late DateTimeRange _range;
  ContabilidadIncomeStatementDataset? _dataset;
  bool _refreshing = false;
  bool _pendingReload = false;
  bool _loading = true;
  bool _failed = false;
  bool _hovering = false;
  int _revision = 0;
  Timer? _timer;

  DateTime get _now => (widget.now ?? DateTime.now)();

  DateTimeRange _resolveRange() {
    if (_customRange != null) return _customRange!;
    final today = DateUtils.dateOnly(_now);
    return DateTimeRange(
      start: today.subtract(Duration(days: _windowDays - 1)),
      end: today,
    );
  }

  @override
  void initState() {
    super.initState();
    _range = _resolveRange();
    _requestReload();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _requestReload(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _requestReload() {
    if (!mounted) return;
    final nextRange = _resolveRange();
    if (nextRange != _range) {
      setState(() {
        _range = nextRange;
        _revision++;
        _dataset = null;
        _loading = true;
        _failed = false;
      });
    }
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    _refreshing = true;
    final revision = _revision;
    try {
      final dataset = await (widget.loadStatement ?? _loadStatement)(_range);
      if (!mounted || revision != _revision) return;
      setState(() {
        _dataset = dataset;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || revision != _revision) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    } finally {
      _refreshing = false;
      if (_pendingReload && mounted) {
        _pendingReload = false;
        _requestReload();
      }
    }
  }

  Future<ContabilidadIncomeStatementDataset> _loadStatement(
    DateTimeRange range,
  ) => const ContabilidadIncomeStatementStore().loadSimplified(
    windowDays: range.duration.inDays + 1,
    dateRange: range,
    migrateLegacyVouchers: false,
  );

  Future<void> _selectPeriod(int days) async {
    DateTimeRange? custom;
    if (days == 0) {
      custom = await showContractDateRangePickerSurface(
        context,
        firstDate: DateTime(2024, 1, 1),
        lastDate: DateTime(_now.year + 1, 12, 31),
        initialDateRange: _range,
        title: 'Periodo del Estado de Resultados',
        tokens: directionAreaTokens,
      );
      if (custom == null || !mounted) return;
    }
    setState(() {
      if (days != 0) _windowDays = days;
      _customRange = custom;
      _range = _resolveRange();
      _revision++;
      _dataset = null;
      _loading = true;
      _failed = false;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _requestReload();
  }

  Future<void> _openStatement() async {
    await widget.onOpenStatement(_range);
    _requestReload();
  }

  @override
  Widget build(BuildContext context) {
    final dataset = _dataset;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        offset: _hovering ? const Offset(0, -0.014) : Offset.zero,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: _hovering ? 1.01 : 1,
          child: DirectionGlassPanel(
            padding: const EdgeInsets.all(18),
            borderRadius: BorderRadius.circular(28),
            blurSigma: 30,
            fillColor: kDirectionOliveDeep.withValues(alpha: 0.24),
            borderColor: Colors.white.withValues(
              alpha: _hovering ? 0.34 : 0.28,
            ),
            shadowColor: Colors.black.withValues(
              alpha: _hovering ? 0.18 : 0.14,
            ),
            edgeHighlightColor: Colors.white.withValues(alpha: 0.70),
            bevelShadowColor: Colors.black.withValues(alpha: 0.14),
            glowColor: kDirectionOliveGlow.withValues(
              alpha: _hovering ? 0.18 : 0.12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_rounded,
                      color: kDirectionOliveGlow,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contabilidad',
                            style: TextStyle(
                              color: kDirectionSurfaceText,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Estado de Resultados',
                            style: TextStyle(
                              color: kDirectionMutedText,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ver Estado de Resultados',
                      onPressed: _openStatement,
                      color: kDirectionOliveGlow,
                      icon: const Icon(Icons.arrow_outward_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PopupMenuButton<int>(
                    key: const ValueKey('direction-accounting-period'),
                    tooltip: 'Seleccionar periodo',
                    initialValue: _customRange == null ? _windowDays : 0,
                    color: kDirectionMenuSurface,
                    onSelected: _selectPeriod,
                    itemBuilder: (_) => [
                      for (final days in [7, 30, 90, 0])
                        PopupMenuItem(
                          value: days,
                          child: Text(
                            days == 0
                                ? 'Seleccionar fechas'
                                : 'Últimos $days días',
                            style: const TextStyle(
                              color: kDirectionSurfaceText,
                            ),
                          ),
                        ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: kDirectionInteractiveSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: kDirectionOliveMist.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _customRange == null
                                ? 'Últimos $_windowDays días'
                                : 'Periodo personalizado',
                            style: const TextStyle(
                              color: kDirectionSurfaceText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.expand_more_rounded,
                            color: kDirectionOliveGlow,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _rangeLabel(_range),
                  style: const TextStyle(
                    color: kDirectionMutedText,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: kDirectionOliveGlow,
                            strokeWidth: 2,
                          ),
                        )
                      : dataset == null
                      ? const Center(
                          child: Text(
                            'No se pudo cargar el Estado de Resultados.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: kDirectionMutedText,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          child: ListView.separated(
                            key: const ValueKey('direction-accounting-lines'),
                            controller: _scrollController,
                            padding: const EdgeInsets.only(right: 10),
                            itemCount: dataset.lines.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 3),
                            itemBuilder: (_, index) => _line(
                              dataset.lines[index],
                              index == dataset.lines.length - 1,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                if (_failed && dataset != null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text(
                      'No se pudo actualizar. Se conservan los últimos datos.',
                      style: TextStyle(color: kDirectionWarning, fontSize: 10),
                    ),
                  ),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Base de caja · Bancos, Bóveda y Menudeo',
                        style: TextStyle(
                          color: kDirectionMutedText,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    if (dataset != null && dataset.warnings.isNotEmpty)
                      Tooltip(
                        message: dataset.warnings.join('\n'),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: kDirectionOliveGlow,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(ContabilidadIncomeStatementLine line, bool finalResult) {
    final color = switch (line.tone) {
      ColorTone.positive => kDirectionSuccess,
      ColorTone.negative => kDirectionDanger,
      ColorTone.caution => kDirectionWarning,
      ColorTone.neutral => kDirectionSurfaceText,
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: finalResult ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: line.emphasis
            ? kDirectionInteractiveSelected.withValues(alpha: 0.38)
            : kDirectionInteractiveSurface.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(12),
        border: line.emphasis
            ? Border.all(color: color.withValues(alpha: 0.35))
            : null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final label = Text(
            line.label,
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 12,
              fontWeight: line.emphasis ? FontWeight.w800 : FontWeight.w600,
            ),
          );
          final amount = Text(
            formatMoney(line.amount),
            key: finalResult
                ? const ValueKey('direction-accounting-net-result')
                : null,
            style: TextStyle(
              color: color,
              fontSize: finalResult ? 21 : 13,
              fontWeight: line.emphasis ? FontWeight.w900 : FontWeight.w700,
            ),
          );
          if (finalResult || constraints.maxWidth < 300) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label,
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(fit: BoxFit.scaleDown, child: amount),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(fit: BoxFit.scaleDown, child: amount),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _rangeLabel(DateTimeRange range) {
  String date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  return '${date(range.start)} – ${date(range.end)}';
}
