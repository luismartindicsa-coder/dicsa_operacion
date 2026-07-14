import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_navigation.dart';
import '../commercial/commercial_dashboard_page.dart';
import '../commercial/commercial_store.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/archetypes/auxiliary_surfaces/date_picker_surface.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/utils/file_download_save.dart';
import '../shared/utils/number_formatters.dart';
import '../shared/utils/simple_xlsx_builder.dart';
import 'direction_menudeo_analysis_page.dart';
import 'direction_theme.dart';

class DirectionTradeAnalysisPage extends StatefulWidget {
  final bool instantOpen;

  const DirectionTradeAnalysisPage({super.key, this.instantOpen = false});

  @override
  State<DirectionTradeAnalysisPage> createState() =>
      _DirectionTradeAnalysisPageState();
}

class _DirectionTradeAnalysisPageState
    extends State<DirectionTradeAnalysisPage> {
  bool _menuOpen = false;
  bool _loading = true;
  String? _error;
  _TradeChannelFilter _channel = _TradeChannelFilter.todos;
  int? _rangeDays = 30;
  DateTimeRange? _customRange;
  CommercialDashboardBundle? _bundle;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bundle = await CommercialStore.loadDashboard();
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _openDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openMenudeoAnalysis() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(page: const DirectionMenudeoAnalysisPage(instantOpen: true)),
    );
  }

  Future<void> _openCommercialRadar() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(page: const CommercialDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _logout() async {
    await signOutAndRouteToLogin(context);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDateRange() async {
    final bundle = _bundle;
    if (bundle == null || bundle.marketEvents.isEmpty || !mounted) return;
    final dated =
        bundle.marketEvents
            .map((row) => row.eventAt)
            .whereType<DateTime>()
            .toList(growable: false)
          ..sort();
    if (dated.isEmpty) return;
    final bounds = DateTimeRange(start: dated.first, end: dated.last);
    final picked = await showContractDateRangePickerSurface(
      context,
      firstDate: bounds.start,
      lastDate: bounds.end,
      initialDateRange: _effectiveDateRange(bundle.marketEvents),
      title: 'Selecciona el rango de fechas',
      tokens: directionAreaTokens,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = picked;
      _rangeDays = null;
    });
  }

  DateTimeRange? _effectiveDateRange(List<CommercialMarketEventRecord> events) {
    final dated =
        events.map((row) => row.eventAt).whereType<DateTime>().toList()..sort();
    if (dated.isEmpty) return null;
    if (_customRange != null) return _customRange;
    final end = dated.last;
    final days = _rangeDays ?? 30;
    final rawStart = end.subtract(Duration(days: days - 1));
    final start = rawStart.isBefore(dated.first) ? dated.first : rawStart;
    return DateTimeRange(start: start, end: end);
  }

  List<CommercialMarketEventRecord> _filteredMarketEvents() {
    final bundle = _bundle;
    if (bundle == null) return const <CommercialMarketEventRecord>[];
    final allChannelEvents = bundle.marketEvents
        .where(
          (row) => _matchesChannel(
            _resolveEventChannel(row.channel, row.sourceArea),
            _channel,
          ),
        )
        .toList(growable: false);
    final effectiveRange = _effectiveDateRange(allChannelEvents);
    if (effectiveRange == null) return allChannelEvents;
    return allChannelEvents
        .where((row) {
          final eventAt = row.eventAt;
          if (eventAt == null) return false;
          return !eventAt.isBefore(effectiveRange.start) &&
              !eventAt.isAfter(
                effectiveRange.end.add(
                  const Duration(hours: 23, minutes: 59, seconds: 59),
                ),
              );
        })
        .toList(growable: false);
  }

  Future<void> _exportChartDataXlsx() async {
    final events = _filteredMarketEvents()
      ..sort((a, b) {
        final left = a.eventAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.eventAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final byDate = left.compareTo(right);
        if (byDate != 0) return byDate;
        return a.generalMaterialLabel.compareTo(b.generalMaterialLabel);
      });
    if (events.isEmpty) {
      _showMessage('No hay datos en el filtro actual para exportar.');
      return;
    }

    try {
      final bytes = buildSimpleXlsx(
        sheetName: 'CompraVenta',
        headers: const <String>['Fecha', 'Material', 'Kg', 'Fuente'],
        rows: events
            .map((event) {
              return <String>[
                event.eventAt == null
                    ? 'Sin fecha'
                    : _exportDate(event.eventAt!),
                event.generalMaterialLabel.trim().isEmpty
                    ? 'Sin material'
                    : event.generalMaterialLabel.trim(),
                formatDecimal(event.volumeKg, decimals: 2),
                _eventSourceLabel(event),
              ];
            })
            .toList(growable: false),
      );
      final path = await saveBytesAs(
        bytes: bytes,
        suggestedFileName: _tradeExportFileName(),
        dialogTitle: 'Guardar Excel compra-venta...',
      );
      if (path == null) return;
      _showMessage('Excel guardado en $path');
    } catch (error) {
      _showMessage('No se pudo exportar el Excel: $error');
    }
  }

  String _tradeExportFileName() {
    final channel = switch (_channel) {
      _TradeChannelFilter.todos => 'todos',
      _TradeChannelFilter.menudeo => 'menudeo',
      _TradeChannelFilter.mayoreo => 'mayoreo',
    };
    final bundle = _bundle;
    final range = bundle == null
        ? null
        : _effectiveDateRange(_filteredMarketEvents());
    final suffix = range == null
        ? 'sin_rango'
        : '${_compactDate(range.start)}_${_compactDate(range.end)}';
    return 'compra_venta_${channel}_$suffix.xlsx';
  }

  @override
  Widget build(BuildContext context) {
    final proposal = _buildProposal();
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
            title: 'Compra-Venta',
          ),
          trailingBuilder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DirectionHeaderButton(
                label: 'Recargar',
                icon: Icons.refresh_rounded,
                width: 132,
                onTap: _load,
              ),
              const SizedBox(width: 10),
              DirectionHeaderButton(
                label: 'Cerrar sesión',
                icon: Icons.logout_rounded,
                onTap: _logout,
              ),
            ],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1480),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 56, right: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            DirectionMetricCard(
                              icon: Icons.swap_horiz_rounded,
                              title: 'ÁREA',
                              value: 'COMPRA-VENTA',
                              detail: 'Propuesta ejecutiva para Dirección',
                              accent: directionAreaTokens.primary,
                            ),
                            DirectionMetricCard(
                              icon: Icons.calendar_month_rounded,
                              title: 'VENTANA',
                              value: proposal.rangeLabel.toUpperCase(),
                              detail: 'Filtro activo para compra y venta',
                              accent: directionAreaTokens.accent,
                            ),
                            DirectionMetricCard(
                              icon: Icons.category_rounded,
                              title: 'MATERIALES',
                              value: '${proposal.activeMaterials}',
                              detail: 'Con movimiento reciente comparable',
                              accent: directionAreaTokens.primarySoft,
                            ),
                            DirectionMetricCard(
                              icon: Icons.radar_rounded,
                              title: 'SPREADS',
                              value: '${proposal.opportunities.length}',
                              detail: 'Oportunidades detectadas',
                              accent: kDirectionSuccess,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: DirectionGlassPanel(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                            borderRadius: BorderRadius.circular(28),
                            blurSigma: 30,
                            fillColor: kDirectionOliveDeep.withValues(
                              alpha: 0.30,
                            ),
                            borderColor: Colors.white.withValues(alpha: 0.24),
                            shadowColor: Colors.black.withValues(alpha: 0.10),
                            edgeHighlightColor: Colors.white.withValues(
                              alpha: 0.34,
                            ),
                            bevelShadowColor: Colors.black.withValues(
                              alpha: 0.16,
                            ),
                            glowColor: kDirectionOliveGlow.withValues(
                              alpha: 0.04,
                            ),
                            child: _loading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _error != null
                                ? _TradeErrorState(
                                    message: _error!,
                                    onRetry: _load,
                                  )
                                : _TradeAnalysisBody(
                                    proposal: proposal,
                                    channel: _channel,
                                    selectedRangeDays: _rangeDays,
                                    onChannelChanged: (value) {
                                      setState(() => _channel = value);
                                    },
                                    onPickDateRange: _pickDateRange,
                                    onSetLast7Days: () {
                                      setState(() {
                                        _rangeDays = 7;
                                        _customRange = null;
                                      });
                                    },
                                    onSetLast30Days: () {
                                      setState(() {
                                        _rangeDays = 30;
                                        _customRange = null;
                                      });
                                    },
                                    onSetLast90Days: () {
                                      setState(() {
                                        _rangeDays = 90;
                                        _customRange = null;
                                      });
                                    },
                                    onExportXlsx: _exportChartDataXlsx,
                                    onOpenCommercialRadar: _openCommercialRadar,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: _menuOpen ? 0 : -332,
                top: 0,
                width: 320,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: !_menuOpen,
                  child: SingleChildScrollView(
                    child: _DirectionTradeAnalysisMenu(
                      onOpenDashboard: _openDashboard,
                      onOpenMenudeoAnalysis: _openMenudeoAnalysis,
                      onOpenCommercialRadar: _openCommercialRadar,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _TradeProposal _buildProposal() {
    final bundle = _bundle;
    if (bundle == null) return const _TradeProposal.empty();
    final allChannelEvents = bundle.marketEvents
        .where(
          (row) => _matchesChannel(
            _resolveEventChannel(row.channel, row.sourceArea),
            _channel,
          ),
        )
        .toList(growable: false);
    final effectiveRange = _effectiveDateRange(allChannelEvents);
    final marketEvents = _filteredMarketEvents();
    final alerts = bundle.alerts
        .where((row) => _matchesChannel(row.channel, _channel))
        .toList(growable: false);

    final materialMap = <String, _TradeMaterialRow>{};
    for (final event in marketEvents) {
      final key = event.generalMaterialKey.trim().isEmpty
          ? _normalizeTrendKey(event.generalMaterialLabel)
          : event.generalMaterialKey.trim().toUpperCase();
      final current = materialMap[key];
      final next =
          (current ??
                  _TradeMaterialRow.empty(
                    label: event.generalMaterialLabel,
                    channel: _resolveEventChannel(
                      event.channel,
                      event.sourceArea,
                    ),
                  ))
              .mergeEvent(event);
      materialMap[key] = next;
    }

    final materialRows = materialMap.values.toList(growable: false)
      ..sort((a, b) => b.totalVolume.compareTo(a.totalVolume));

    final opportunities =
        materialRows
            .where((row) => row.spread != null && row.spread! > 0)
            .map(
              (row) => _TradeOpportunityRow(
                materialLabel: row.label,
                segment: row.businessMixLabel,
                channel: row.channelKeyForDisplay,
                buyPrice: row.avgBuyPrice ?? 0,
                sellPrice: row.avgSellPrice ?? 0,
                spread: row.spread ?? 0,
                volume: row.totalVolume,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final rightScore = b.spread * (b.volume <= 0 ? 1 : b.volume);
            final leftScore = a.spread * (a.volume <= 0 ? 1 : a.volume);
            return rightScore.compareTo(leftScore);
          });

    final biggestGap = materialRows.isEmpty
        ? null
        : (materialRows.toList()..sort(
                (a, b) => b.volumeGap.abs().compareTo(a.volumeGap.abs()),
              ))
              .first;

    final topSuppliers = const <CommercialGeneralCounterpartyActivityRecord>[];
    final topCustomers = const <CommercialGeneralCounterpartyActivityRecord>[];

    final buyVolume = materialRows.fold<double>(
      0,
      (sum, row) => sum + row.buyVolume,
    );
    final sellVolume = materialRows.fold<double>(
      0,
      (sum, row) => sum + row.sellVolume,
    );
    final buyAmount = materialRows.fold<double>(
      0,
      (sum, row) => sum + row.buyAmount,
    );
    final sellAmount = materialRows.fold<double>(
      0,
      (sum, row) => sum + row.sellAmount,
    );
    final avgBuyPrice = buyVolume > 0 ? buyAmount / buyVolume : null;
    final avgSellPrice = sellVolume > 0 ? sellAmount / sellVolume : null;
    final avgSpread = avgBuyPrice != null && avgSellPrice != null
        ? avgSellPrice - avgBuyPrice
        : null;
    final fastestRotation = const <_TradeMaterialRow>[];
    final lowestCoverage = const <_TradeMaterialRow>[];
    final actionRows =
        materialRows
            .where((row) => row.spread != null || row.volumeGap.abs() > 0)
            .map(_TradeActionRow.fromMaterial)
            .toList(growable: false)
          ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    final overboughtRows =
        materialRows.where((row) => row.isOverbought).toList(growable: false)
          ..sort((a, b) => b.overboughtScore.compareTo(a.overboughtScore));
    final noBenchmarkRows =
        materialRows
            .where((row) => row.missingBenchmark)
            .toList(growable: false)
          ..sort((a, b) => b.totalVolume.compareTo(a.totalVolume));
    final stoplight = const _TradeStoplightSummary.empty();
    final weeklyAgenda = const <_TradeWeeklyAgendaRow>[];
    final weeklyTrendRows = const <_TradeWeeklyTrendRow>[];
    final simpleTrend = const <_TradeTrendPoint>[];
    final barRows = materialRows.take(8).toList(growable: false);
    final priceRows =
        materialRows
            .where(
              (row) =>
                  row.avgBuyPrice != null &&
                  row.avgSellPrice != null &&
                  row.totalVolume > 0,
            )
            .map(_TradePriceRow.fromMaterial)
            .toList(growable: false)
          ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    return _TradeProposal(
      activeMaterials: materialRows.length,
      buyVolume: buyVolume,
      sellVolume: sellVolume,
      buyAmount: buyAmount,
      sellAmount: sellAmount,
      avgBuyPrice: avgBuyPrice,
      avgSellPrice: avgSellPrice,
      avgSpread: avgSpread,
      topMaterials: barRows,
      priceRows: priceRows.take(6).toList(growable: false),
      opportunities: opportunities.take(6).toList(growable: false),
      alerts: alerts.take(5).toList(growable: false),
      topSuppliers: topSuppliers.take(5).toList(growable: false),
      topCustomers: topCustomers.take(5).toList(growable: false),
      biggestGap: biggestGap,
      fastestRotation: fastestRotation.take(5).toList(growable: false),
      lowestCoverage: lowestCoverage.take(5).toList(growable: false),
      actionRows: actionRows.take(6).toList(growable: false),
      overboughtRows: overboughtRows.take(5).toList(growable: false),
      noBenchmarkRows: noBenchmarkRows.take(5).toList(growable: false),
      weeklyAgenda: weeklyAgenda.take(5).toList(growable: false),
      weeklyTrendRows: weeklyTrendRows.take(6).toList(growable: false),
      simpleTrend: simpleTrend,
      rangeLabel: _formatRangeLabel(effectiveRange),
      stoplight: stoplight,
      mainInsight: _buildMainInsight(
        opportunities: opportunities,
        biggestGap: biggestGap,
      ),
      secondaryInsight: _buildSecondaryInsight(
        buyVolume: buyVolume,
        sellVolume: sellVolume,
        buyAmount: buyAmount,
        sellAmount: sellAmount,
      ),
    );
  }
}

enum _TradeChannelFilter { todos, menudeo, mayoreo }

class _TradeAnalysisBody extends StatelessWidget {
  final _TradeProposal proposal;
  final _TradeChannelFilter channel;
  final int? selectedRangeDays;
  final ValueChanged<_TradeChannelFilter> onChannelChanged;
  final Future<void> Function() onPickDateRange;
  final VoidCallback onSetLast7Days;
  final VoidCallback onSetLast30Days;
  final VoidCallback onSetLast90Days;
  final Future<void> Function() onExportXlsx;
  final Future<void> Function() onOpenCommercialRadar;

  const _TradeAnalysisBody({
    required this.proposal,
    required this.channel,
    required this.selectedRangeDays,
    required this.onChannelChanged,
    required this.onPickDateRange,
    required this.onSetLast7Days,
    required this.onSetLast30Days,
    required this.onSetLast90Days,
    required this.onExportXlsx,
    required this.onOpenCommercialRadar,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TradeToolbar(
            channel: channel,
            selectedRangeDays: selectedRangeDays,
            onChannelChanged: onChannelChanged,
            rangeLabel: proposal.rangeLabel,
            onPickDateRange: onPickDateRange,
            onSetLast7Days: onSetLast7Days,
            onSetLast30Days: onSetLast30Days,
            onSetLast90Days: onSetLast90Days,
            onExportXlsx: onExportXlsx,
            onOpenCommercialRadar: onOpenCommercialRadar,
          ),
          const SizedBox(height: 16),
          _ExecutiveSummaryCard(proposal: proposal),
          const SizedBox(height: 14),
          _SimplePriceCard(proposal: proposal),
          const SizedBox(height: 14),
          _SimpleBarChartCard(
            rows: proposal.topMaterials,
            rangeLabel: proposal.rangeLabel,
          ),
          const SizedBox(height: 14),
          _SimpleMaterialsCard(rows: proposal.topMaterials),
          Offstage(
            offstage: true,
            child: Column(
              children: [
                _DecisionSignalsCard(proposal: proposal),
                _StoplightCard(summary: proposal.stoplight),
                _InventoryCoverageCard(proposal: proposal),
                _AgendaCard(rows: proposal.weeklyAgenda),
                _ActionBoardCard(rows: proposal.actionRows),
                _MissingBenchmarkCard(rows: proposal.noBenchmarkRows),
                _WeeklyTrendCard(
                  rows: proposal.weeklyTrendRows,
                  trendWeeks: 12,
                ),
                _MaterialsTableCard(rows: proposal.topMaterials),
                _OpportunitiesCard(rows: proposal.opportunities),
                _RotationCard(
                  title: 'Rotación fuerte',
                  subtitle: 'Materiales con salida rápida contra stock actual.',
                  icon: Icons.autorenew_rounded,
                  rows: proposal.fastestRotation,
                  emptyMessage:
                      'Todavía no hay materiales con rotación calculable.',
                ),
                _RotationCard(
                  title: 'Sobrecompra / salida lenta',
                  subtitle:
                      'Materiales con entrada arriba de salida o stock presionado.',
                  icon: Icons.slow_motion_video_rounded,
                  rows: proposal.overboughtRows,
                  emptyMessage:
                      'No se detecta sobrecompra relevante en este filtro.',
                ),
                _CounterpartyCard(
                  title: 'Proveedores clave',
                  icon: Icons.south_west_rounded,
                  rows: proposal.topSuppliers,
                  flowLabel: 'Compra',
                ),
                _CounterpartyCard(
                  title: 'Clientes clave',
                  icon: Icons.north_east_rounded,
                  rows: proposal.topCustomers,
                  flowLabel: 'Venta',
                ),
                _AlertsCard(rows: proposal.alerts),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeToolbar extends StatelessWidget {
  final _TradeChannelFilter channel;
  final int? selectedRangeDays;
  final ValueChanged<_TradeChannelFilter> onChannelChanged;
  final String rangeLabel;
  final Future<void> Function() onPickDateRange;
  final VoidCallback onSetLast7Days;
  final VoidCallback onSetLast30Days;
  final VoidCallback onSetLast90Days;
  final Future<void> Function() onExportXlsx;
  final Future<void> Function() onOpenCommercialRadar;

  const _TradeToolbar({
    required this.channel,
    required this.selectedRangeDays,
    required this.onChannelChanged,
    required this.rangeLabel,
    required this.onPickDateRange,
    required this.onSetLast7Days,
    required this.onSetLast30Days,
    required this.onSetLast90Days,
    required this.onExportXlsx,
    required this.onOpenCommercialRadar,
  });

  @override
  Widget build(BuildContext context) {
    return DirectionToolbarPanel(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Propuesta de lectura ejecutiva',
                style: TextStyle(
                  color: kDirectionSurfaceText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _FilterChipButton(
                label: 'Todos',
                selected: channel == _TradeChannelFilter.todos,
                onTap: () => onChannelChanged(_TradeChannelFilter.todos),
              ),
              _FilterChipButton(
                label: 'Menudeo',
                selected: channel == _TradeChannelFilter.menudeo,
                onTap: () => onChannelChanged(_TradeChannelFilter.menudeo),
              ),
              _FilterChipButton(
                label: 'Mayoreo',
                selected: channel == _TradeChannelFilter.mayoreo,
                onTap: () => onChannelChanged(_TradeChannelFilter.mayoreo),
              ),
              const SizedBox(width: 10),
              _FilterChipButton(
                label: '7d',
                selected: selectedRangeDays == 7,
                onTap: onSetLast7Days,
              ),
              _FilterChipButton(
                label: '30d',
                selected: selectedRangeDays == 30,
                onTap: onSetLast30Days,
              ),
              _FilterChipButton(
                label: '90d',
                selected: selectedRangeDays == 90,
                onTap: onSetLast90Days,
              ),
              DirectionHeaderButton(
                label: rangeLabel,
                icon: Icons.date_range_rounded,
                width: 186,
                onTap: onPickDateRange,
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              DirectionHeaderButton(
                label: 'Exportar XLSX',
                icon: Icons.download_rounded,
                width: 180,
                onTap: onExportXlsx,
              ),
              DirectionHeaderButton(
                label: 'Abrir Radar Comercial',
                icon: Icons.open_in_new_rounded,
                width: 220,
                onTap: onOpenCommercialRadar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExecutiveSummaryCard extends StatelessWidget {
  final _TradeProposal proposal;

  const _ExecutiveSummaryCard({required this.proposal});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Resumen ejecutivo',
      subtitle: 'Qué entra, qué sale y dónde se ve espacio de decisión.',
      icon: Icons.assessment_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MiniMetric(
                label: 'Compra',
                value: '${formatDecimal(proposal.buyVolume, decimals: 0)} kg',
                detail: formatMoney(proposal.buyAmount),
                accent: const Color(0xFF91D6FF),
              ),
              _MiniMetric(
                label: 'Venta',
                value: '${formatDecimal(proposal.sellVolume, decimals: 0)} kg',
                detail: formatMoney(proposal.sellAmount),
                accent: const Color(0xFF86FFE5),
              ),
              _MiniMetric(
                label: 'Balance kg',
                value:
                    '${formatDecimal(proposal.sellVolume - proposal.buyVolume, decimals: 0)} kg',
                detail: 'Salida menos entrada',
                accent: const Color(0xFFFFD58A),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InsightCallout(
            title: 'Lectura principal',
            message: proposal.mainInsight,
          ),
          const SizedBox(height: 10),
          _InsightCallout(
            title: 'Lectura de volumen e importe',
            message:
                '${proposal.secondaryInsight} Rango: ${proposal.rangeLabel}.',
          ),
        ],
      ),
    );
  }
}

class _SimpleBarChartCard extends StatelessWidget {
  final List<_TradeMaterialRow> rows;
  final String rangeLabel;

  const _SimpleBarChartCard({required this.rows, required this.rangeLabel});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Compra, venta y diferencial',
      subtitle:
          'Barras por material dentro del rango $rangeLabel. Hover sobre cada barra para ver kg.',
      icon: Icons.bar_chart_rounded,
      child: rows.isEmpty
          ? const _EmptyLine(
              message:
                  'Todavía no hay datos suficientes para construir la gráfica.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...rows.map(
                  (row) =>
                      _BarChartMaterialRow(row: row, maxKg: _maxBarValue(rows)),
                ),
              ],
            ),
    );
  }
}

class _SimplePriceCard extends StatelessWidget {
  final _TradeProposal proposal;

  const _SimplePriceCard({required this.proposal});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Estudio rapido de precios',
      subtitle:
          'Lectura simple para decidir si conviene subir, corregir o sostener precio.',
      icon: Icons.sell_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MiniMetric(
                label: 'Compra prom.',
                value: proposal.avgBuyPrice == null
                    ? 'N/D'
                    : formatMoney(proposal.avgBuyPrice!),
                detail: 'Promedio ponderado por kg',
                accent: const Color(0xFF91D6FF),
              ),
              _MiniMetric(
                label: 'Venta prom.',
                value: proposal.avgSellPrice == null
                    ? 'N/D'
                    : formatMoney(proposal.avgSellPrice!),
                detail: 'Promedio ponderado por kg',
                accent: const Color(0xFF86FFE5),
              ),
              _MiniMetric(
                label: 'Spread prom.',
                value: proposal.avgSpread == null
                    ? 'N/D'
                    : formatMoney(proposal.avgSpread!),
                detail: 'Venta menos compra',
                accent: proposal.avgSpread == null
                    ? const Color(0xFFB7C3FF)
                    : proposal.avgSpread! >= 0
                    ? const Color(0xFFFFD58A)
                    : const Color(0xFFFFA98A),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (proposal.priceRows.isEmpty)
            const _EmptyLine(
              message:
                  'Todavia no hay suficientes comparables de precio para sugerir movimientos.',
            )
          else
            Column(
              children: proposal.priceRows
                  .map((row) => _SimplePriceLine(row: row))
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _SimplePriceLine extends StatelessWidget {
  final _TradePriceRow row;

  const _SimplePriceLine({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.materialLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: row.tone.withValues(alpha: 0.16),
                  border: Border.all(color: row.tone.withValues(alpha: 0.32)),
                ),
                child: Text(
                  row.actionLabel,
                  style: TextStyle(
                    color: row.tone,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Compra ${formatMoney(row.buyPrice)} · Venta ${formatMoney(row.sellPrice)} · Spread ${formatMoney(row.spread)}',
            style: const TextStyle(
              color: kDirectionMutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            row.message,
            style: const TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleMaterialsCard extends StatelessWidget {
  final List<_TradeMaterialRow> rows;

  const _SimpleMaterialsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final totals = _TradeMaterialTotals.fromRows(rows);
    return _SectionCard(
      title: 'Materiales',
      subtitle:
          'Lectura simple por material: compra, venta y balance en kg y en \$.',
      icon: Icons.category_outlined,
      child: rows.isEmpty
          ? const _EmptyLine(message: 'No hay materiales con movimiento.')
          : Column(
              children: [
                const _SimpleMaterialsHeader(),
                const SizedBox(height: 8),
                ...rows.map((row) => _SimpleMaterialLine(row: row)),
                const SizedBox(height: 4),
                _SimpleMaterialsTotalsLine(totals: totals),
              ],
            ),
    );
  }
}

double _maxBarValue(List<_TradeMaterialRow> rows) {
  if (rows.isEmpty) return 1;
  return rows
      .map(
        (row) => max(row.buyVolume, max(row.sellVolume, row.balanceKg.abs())),
      )
      .reduce(max)
      .clamp(1, double.infinity)
      .toDouble();
}

class _BarChartMaterialRow extends StatelessWidget {
  final _TradeMaterialRow row;
  final double maxKg;

  const _BarChartMaterialRow({required this.row, required this.maxKg});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _BarMetricLine(
            label: 'Compra',
            color: const Color(0xFF7FD7FF),
            value: row.buyVolume,
            maxKg: maxKg,
          ),
          const SizedBox(height: 8),
          _BarMetricLine(
            label: 'Venta',
            color: const Color(0xFF89FFE4),
            value: row.sellVolume,
            maxKg: maxKg,
          ),
          const SizedBox(height: 8),
          _BarMetricLine(
            label: 'Dif.',
            color: row.balanceKg >= 0
                ? const Color(0xFFFFD58A)
                : const Color(0xFFFFA98A),
            value: row.balanceKg.abs(),
            maxKg: maxKg,
            suffix: row.balanceKg >= 0
                ? '+${formatDecimal(row.balanceKg, decimals: 0)} kg'
                : '${formatDecimal(row.balanceKg, decimals: 0)} kg',
          ),
        ],
      ),
    );
  }
}

class _BarMetricLine extends StatelessWidget {
  final String label;
  final Color color;
  final double value;
  final double maxKg;
  final String? suffix;

  const _BarMetricLine({
    required this.label,
    required this.color,
    required this.value,
    required this.maxKg,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final widthFactor = maxKg <= 0 ? 0.0 : (value / maxKg).clamp(0.0, 1.0);
    final valueLabel = suffix ?? '${formatDecimal(value, decimals: 0)} kg';
    return Row(
      children: [
        SizedBox(
          width: 54,
          child: Text(
            label,
            style: const TextStyle(
              color: kDirectionMutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Tooltip(
            message: valueLabel,
            child: Container(
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.06),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: widthFactor,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 82,
          child: Text(
            valueLabel,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _DecisionSignalsCard extends StatelessWidget {
  final _TradeProposal proposal;

  const _DecisionSignalsCard({required this.proposal});

  @override
  Widget build(BuildContext context) {
    final biggestGap = proposal.biggestGap;
    final bestSpread = proposal.opportunities.isEmpty
        ? null
        : proposal.opportunities.first;
    return _SectionCard(
      title: 'Decisiones sugeridas',
      subtitle: 'Cómo usar esta lectura en compra, venta y volumen.',
      icon: Icons.tips_and_updates_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SignalTile(
            title: 'Volumen a revisar',
            subtitle: biggestGap == null
                ? 'Todavía no hay material con gap relevante.'
                : '${biggestGap.label} muestra un desbalance de ${formatDecimal(biggestGap.volumeGap.abs(), decimals: 0)} kg entre entrada y salida.',
            badge: biggestGap == null
                ? 'Sin señal'
                : biggestGap.volumeGap > 0
                ? 'Venta arriba'
                : 'Compra arriba',
          ),
          const SizedBox(height: 10),
          _SignalTile(
            title: 'Precio a empujar',
            subtitle: bestSpread == null
                ? 'Aún no hay spread claro con benchmark comparable.'
                : '${bestSpread.materialLabel} en ${bestSpread.channelLabel} deja un spread observado de ${formatMoney(bestSpread.spread)} por kg.',
            badge: bestSpread == null ? 'Sin spread' : 'Oportunidad',
          ),
          const SizedBox(height: 10),
          _SignalTile(
            title: 'Abasto / rotación',
            subtitle:
                'Esta pantalla ya no cruza inventario. La prioridad aquí es leer flujo real de compra contra venta por material.',
            badge: 'Solo flujo',
          ),
        ],
      ),
    );
  }
}

class _InventoryCoverageCard extends StatelessWidget {
  final _TradeProposal proposal;

  const _InventoryCoverageCard({required this.proposal});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Cobertura e inventario',
      subtitle:
          'La pantalla ya no mezcla flujo comercial con inventario operativo.',
      icon: Icons.inventory_rounded,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InsightCallout(
            title: 'Ajuste aplicado',
            message:
                'El analisis de compra-venta ahora se construye solo con eventos de menudeo, compras mayoreo y ventas mayoreo. No usa stock operativo ni cruces de cobertura.',
          ),
        ],
      ),
    );
  }
}

class _StoplightCard extends StatelessWidget {
  final _TradeStoplightSummary summary;

  const _StoplightCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Semáforos',
      subtitle: 'Lectura ejecutiva rápida para abrir la junta.',
      icon: Icons.traffic_rounded,
      child: Column(
        children: [
          _StoplightTile(
            color: const Color(0xFFFF866E),
            label: 'Rojo',
            count: summary.redCount,
            description:
                'Cobertura crítica, sobrecompra fuerte o demasiadas alertas.',
          ),
          _StoplightTile(
            color: const Color(0xFFFFD98A),
            label: 'Ámbar',
            count: summary.amberCount,
            description:
                'Benchmark faltante, gaps de volumen o seguimiento comercial.',
          ),
          _StoplightTile(
            color: const Color(0xFF8EFFD5),
            label: 'Verde',
            count: summary.greenCount,
            description:
                'Materiales con balance razonable o spread ya entendido.',
          ),
        ],
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  final List<_TradeWeeklyAgendaRow> rows;

  const _AgendaCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Agenda semanal',
      subtitle: 'Prioridades listas para junta de Dirección.',
      icon: Icons.today_rounded,
      child: rows.isEmpty
          ? const _EmptyLine(
              message: 'Todavía no hay temas suficientes para agenda semanal.',
            )
          : Column(
              children: rows
                  .map(
                    (row) => _SignalTile(
                      title: '${row.headline} · ${row.owner}',
                      subtitle: row.detail,
                      badge: row.priority,
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _ActionBoardCard extends StatelessWidget {
  final List<_TradeActionRow> rows;

  const _ActionBoardCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Tablero de acción',
      subtitle:
          'Qué conviene revisar primero en precio, abasto o desplazamiento.',
      icon: Icons.fact_check_rounded,
      child: rows.isEmpty
          ? const _EmptyLine(
              message:
                  'Todavía no hay materiales suficientes para sugerir acciones.',
            )
          : Column(
              children: rows
                  .map(
                    (row) => _SignalTile(
                      title: '${row.materialLabel} · ${row.actionTitle}',
                      subtitle: row.actionBody,
                      badge: row.priorityLabel,
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _MissingBenchmarkCard extends StatelessWidget {
  final List<_TradeMaterialRow> rows;

  const _MissingBenchmarkCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Sin benchmark comparable',
      subtitle:
          'Materiales con volumen pero sin lectura limpia de compra vs venta.',
      icon: Icons.rule_folder_outlined,
      child: rows.isEmpty
          ? const _EmptyLine(
              message: 'No hay materiales relevantes sin benchmark comparable.',
            )
          : Column(
              children: rows
                  .map(
                    (row) => _SignalTile(
                      title: row.label,
                      subtitle:
                          'Movimiento total ${formatDecimal(row.totalVolume, decimals: 0)} kg · Compra ${formatDecimal(row.buyVolume, decimals: 0)} kg · Venta ${formatDecimal(row.sellVolume, decimals: 0)} kg · ${row.businessMixLabel}',
                      badge: 'Sin benchmark',
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _WeeklyTrendCard extends StatelessWidget {
  final List<_TradeWeeklyTrendRow> rows;
  final int trendWeeks;

  const _WeeklyTrendCard({required this.rows, required this.trendWeeks});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Tendencia semanal',
      subtitle:
          'Spread, cobertura y riesgo compuesto en una ventana de $trendWeeks semanas.',
      icon: Icons.timeline_rounded,
      child: rows.isEmpty
          ? const _EmptyLine(
              message:
                  'Todavía no hay suficientes eventos semanales para construir tendencia.',
            )
          : Column(
              children: [
                const _WeeklyTrendHeader(),
                const SizedBox(height: 8),
                ...rows.map((row) => _WeeklyTrendLine(row: row)),
              ],
            ),
    );
  }
}

class _MaterialsTableCard extends StatelessWidget {
  final List<_TradeMaterialRow> rows;

  const _MaterialsTableCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Materiales generales',
      subtitle:
          'Consolidado para comparar entrada y salida sin perder lectura de precio.',
      icon: Icons.category_outlined,
      child: Column(
        children: [
          const _TableHeaderRow(),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const _EmptyLine(
              message: 'No hay materiales con movimiento en este filtro.',
            )
          else
            ...rows.map((row) => _MaterialLine(row: row)),
        ],
      ),
    );
  }
}

class _RotationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_TradeMaterialRow> rows;
  final String emptyMessage;

  const _RotationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.rows,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      child: rows.isEmpty
          ? _EmptyLine(message: emptyMessage)
          : Column(
              children: rows
                  .map(
                    (row) => _SignalTile(
                      title: row.label,
                      subtitle:
                          'Compra 30d ${formatDecimal(row.buyVolume, decimals: 0)} kg · Venta 30d ${formatDecimal(row.sellVolume, decimals: 0)} kg · ${row.businessMixLabel}',
                      badge: row.reading,
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _StoplightTile extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final String description;

  const _StoplightTile({
    required this.color,
    required this.label,
    required this.count,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label · $count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: kDirectionMutedText,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyTrendHeader extends StatelessWidget {
  const _WeeklyTrendHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: kDirectionSubtleText,
      fontSize: 11,
      fontWeight: FontWeight.w800,
    );
    return const Row(
      children: [
        Expanded(flex: 22, child: Text('Material', style: style)),
        Expanded(flex: 18, child: Text('Spread', style: style)),
        Expanded(flex: 18, child: Text('Cobertura', style: style)),
        Expanded(flex: 18, child: Text('Riesgo', style: style)),
        Expanded(flex: 12, child: Text('Última', style: style)),
        Expanded(flex: 12, child: Text('Lectura', style: style)),
      ],
    );
  }
}

class _WeeklyTrendLine extends StatelessWidget {
  final _TradeWeeklyTrendRow row;

  const _WeeklyTrendLine({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 22,
            child: Text(
              row.materialLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 18,
            child: SizedBox(
              height: 30,
              child: _MiniSparkline(
                values: row.spreadValues,
                color: row.spreadTone,
              ),
            ),
          ),
          Expanded(
            flex: 18,
            child: SizedBox(
              height: 30,
              child: _MiniSparkline(
                values: row.coverageValues,
                color: row.coverageTone,
              ),
            ),
          ),
          Expanded(
            flex: 18,
            child: SizedBox(
              height: 30,
              child: _MiniSparkline(
                values: row.riskValues,
                color: row.riskTone,
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.latestSpreadLabel,
                  style: TextStyle(
                    color: row.spreadTone,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.latestCoverageLabel,
                  style: TextStyle(
                    color: row.coverageTone,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              row.reading,
              style: TextStyle(
                color: row.riskTone,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;

  const _MiniSparkline({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(values: values, color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minValue = values.reduce(min);
    final maxValue = values.reduce(max);
    final span = (maxValue - minValue).abs() < 0.0001
        ? 1.0
        : maxValue - minValue;
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final dx = (size.width / (values.length - 1)) * index;
      final normalized = (values[index] - minValue) / span;
      final dy = size.height - (normalized * (size.height - 4)) - 2;
      if (index == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.24), color.withValues(alpha: 0.02)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.values != values;
  }
}

class _OpportunitiesCard extends StatelessWidget {
  final List<_TradeOpportunityRow> rows;

  const _OpportunitiesCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Oportunidades de spread',
      subtitle: 'Sólo se muestran cuando hay compra y venta comparables.',
      icon: Icons.show_chart_rounded,
      child: rows.isEmpty
          ? const _EmptyLine(
              message:
                  'Todavía no hay segmentos comparables suficientes para proponer spread.',
            )
          : Column(
              children: rows
                  .map(
                    (row) => _SignalTile(
                      title: '${row.materialLabel} · ${row.channelLabel}',
                      subtitle:
                          'Compra ${formatMoney(row.buyPrice)} · Venta ${formatMoney(row.sellPrice)} · Volumen ${formatDecimal(row.volume, decimals: 0)} kg · ${row.segment}',
                      badge: formatMoney(row.spread),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _CounterpartyCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<CommercialGeneralCounterpartyActivityRecord> rows;
  final String flowLabel;

  const _CounterpartyCard({
    required this.title,
    required this.icon,
    required this.rows,
    required this.flowLabel,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      subtitle: 'Quién está moviendo más valor en el periodo.',
      icon: icon,
      child: rows.isEmpty
          ? const _EmptyLine(
              message: 'Sin contrapartes activas en este filtro.',
            )
          : Column(
              children: rows
                  .map(
                    (row) => _SignalTile(
                      title: row.name,
                      subtitle:
                          '$flowLabel · ${row.generalMaterialLabel} · ${formatDecimal(row.volume30d, decimals: 0)} kg · ${formatMoney(row.amount30d)}',
                      badge: _formatLastActivity(row.lastActivityAt),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  final List<CommercialAlertRecord> rows;

  const _AlertsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Alertas y seguimiento',
      subtitle:
          'Señales que deben convertirse en llamada, visita o ajuste de volumen.',
      icon: Icons.notification_important_rounded,
      child: rows.isEmpty
          ? const _EmptyLine(
              message: 'Sin alertas activas para el filtro actual.',
            )
          : Column(
              children: rows
                  .map(
                    (row) => _SignalTile(
                      title: row.entityLabel,
                      subtitle:
                          '${row.materialLabel} · ${row.message} · ${row.suggestedAction}',
                      badge: row.severity.toUpperCase(),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      fillColor: kDirectionOliveDeep.withValues(alpha: 0.22),
      borderColor: Colors.white.withValues(alpha: 0.10),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.26),
      glowColor: kDirectionOliveGlow.withValues(alpha: 0.03),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: directionAreaTokens.primaryStrong),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: kDirectionSurfaceText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: kDirectionMutedText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SignalTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;

  const _SignalTile({
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: kDirectionSurfaceText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: kDirectionMutedText,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final Color accent;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.detail,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 206,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: accent.withValues(alpha: 0.05),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: const TextStyle(
              color: kDirectionMutedText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCallout extends StatelessWidget {
  final String title;
  final String message;

  const _InsightCallout({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: kDirectionOliveDeep.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            style: const TextStyle(
              color: kDirectionMutedText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected ? kDirectionSelectionGradient : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 0.24 : 0.10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : kDirectionMutedText,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SimpleMaterialsHeader extends StatelessWidget {
  const _SimpleMaterialsHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: kDirectionSubtleText,
      fontSize: 11,
      fontWeight: FontWeight.w800,
    );
    return const Row(
      children: [
        Expanded(flex: 24, child: Text('Material', style: style)),
        Expanded(flex: 12, child: Text('Compra kg', style: style)),
        Expanded(flex: 12, child: Text('Venta kg', style: style)),
        Expanded(flex: 12, child: Text('Balance kg', style: style)),
        Expanded(flex: 14, child: Text('Compra \$', style: style)),
        Expanded(flex: 14, child: Text('Venta \$', style: style)),
        Expanded(flex: 12, child: Text('Utilidad bruta', style: style)),
      ],
    );
  }
}

class _SimpleMaterialLine extends StatelessWidget {
  final _TradeMaterialRow row;

  const _SimpleMaterialLine({required this.row});

  @override
  Widget build(BuildContext context) {
    final balance = row.sellVolume - row.buyVolume;
    final amountBalance = row.sellAmount - row.buyAmount;
    const muted = TextStyle(
      color: kDirectionMutedText,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.channelMixLabel,
                  style: const TextStyle(
                    color: kDirectionSubtleText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              formatDecimal(row.buyVolume, decimals: 0),
              style: muted,
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              formatDecimal(row.sellVolume, decimals: 0),
              style: muted,
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              formatDecimal(balance, decimals: 0),
              style: TextStyle(
                color: balance >= 0
                    ? const Color(0xFF8EFFD5)
                    : const Color(0xFFFFB18E),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 14,
            child: Text(formatMoney(row.buyAmount), style: muted),
          ),
          Expanded(
            flex: 14,
            child: Text(formatMoney(row.sellAmount), style: muted),
          ),
          Expanded(
            flex: 12,
            child: Text(
              formatMoney(amountBalance),
              style: TextStyle(
                color: amountBalance >= 0
                    ? const Color(0xFF8EFFD5)
                    : const Color(0xFFFFB18E),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleMaterialsTotalsLine extends StatelessWidget {
  final _TradeMaterialTotals totals;

  const _SimpleMaterialsTotalsLine({required this.totals});

  @override
  Widget build(BuildContext context) {
    final grossProfit = totals.sellAmount - totals.buyAmount;
    const baseStyle = TextStyle(
      color: Colors.white,
      fontSize: 12.5,
      fontWeight: FontWeight.w800,
    );
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Expanded(flex: 24, child: Text('TOTAL', style: baseStyle)),
          Expanded(
            flex: 12,
            child: Text(
              formatDecimal(totals.buyVolume, decimals: 0),
              style: baseStyle,
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              formatDecimal(totals.sellVolume, decimals: 0),
              style: baseStyle,
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              formatDecimal(totals.sellVolume - totals.buyVolume, decimals: 0),
              style: TextStyle(
                color: totals.sellVolume - totals.buyVolume >= 0
                    ? const Color(0xFF8EFFD5)
                    : const Color(0xFFFFB18E),
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            flex: 14,
            child: Text(formatMoney(totals.buyAmount), style: baseStyle),
          ),
          Expanded(
            flex: 14,
            child: Text(formatMoney(totals.sellAmount), style: baseStyle),
          ),
          Expanded(
            flex: 12,
            child: Text(
              formatMoney(grossProfit),
              style: TextStyle(
                color: grossProfit >= 0
                    ? const Color(0xFF8EFFD5)
                    : const Color(0xFFFFB18E),
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow();

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: kDirectionSubtleText,
      fontSize: 11,
      fontWeight: FontWeight.w800,
    );
    return const Row(
      children: [
        Expanded(flex: 22, child: Text('Material', style: textStyle)),
        Expanded(flex: 15, child: Text('Compra kg', style: textStyle)),
        Expanded(flex: 15, child: Text('Venta kg', style: textStyle)),
        Expanded(flex: 14, child: Text('P. compra', style: textStyle)),
        Expanded(flex: 14, child: Text('P. venta', style: textStyle)),
        Expanded(flex: 10, child: Text('Spread', style: textStyle)),
        Expanded(flex: 10, child: Text('Lectura', style: textStyle)),
      ],
    );
  }
}

class _MaterialLine extends StatelessWidget {
  final _TradeMaterialRow row;

  const _MaterialLine({required this.row});

  @override
  Widget build(BuildContext context) {
    const cellStyle = TextStyle(
      color: kDirectionMutedText,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    );
    final spread = row.spread;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 22,
            child: Text(
              row.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 15,
            child: Text(
              formatDecimal(row.buyVolume, decimals: 0),
              style: cellStyle,
            ),
          ),
          Expanded(
            flex: 15,
            child: Text(
              formatDecimal(row.sellVolume, decimals: 0),
              style: cellStyle,
            ),
          ),
          Expanded(
            flex: 14,
            child: Text(
              row.avgBuyPrice == null ? 'N/D' : formatMoney(row.avgBuyPrice!),
              style: cellStyle,
            ),
          ),
          Expanded(
            flex: 14,
            child: Text(
              row.avgSellPrice == null ? 'N/D' : formatMoney(row.avgSellPrice!),
              style: cellStyle,
            ),
          ),
          Expanded(
            flex: 10,
            child: Text(
              spread == null ? 'N/D' : formatMoney(spread),
              style: TextStyle(
                color: spread == null
                    ? kDirectionMutedText
                    : spread >= 0
                    ? const Color(0xFF8FFFE1)
                    : const Color(0xFFFFC690),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(flex: 10, child: Text(row.reading, style: cellStyle)),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String message;

  const _EmptyLine({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: kDirectionMutedText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TradeErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _TradeErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: Color(0xFFFFC690),
            ),
            const SizedBox(height: 12),
            const Text(
              'No se pudo cargar la propuesta de compra-venta.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kDirectionMutedText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            DirectionHeaderButton(
              label: 'Reintentar',
              icon: Icons.refresh_rounded,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionTradeAnalysisMenu extends StatelessWidget {
  final Future<void> Function() onOpenDashboard;
  final Future<void> Function() onOpenMenudeoAnalysis;
  final Future<void> Function() onOpenCommercialRadar;

  const _DirectionTradeAnalysisMenu({
    required this.onOpenDashboard,
    required this.onOpenMenudeoAnalysis,
    required this.onOpenCommercialRadar,
  });

  @override
  Widget build(BuildContext context) {
    return DirectionModuleMenuPanel(
      entries: [
        DirectionModuleMenuEntry(
          icon: Icons.home_work_rounded,
          title: 'Dashboard Dirección',
          subtitle: 'Vista general del área',
          onTap: () => unawaited(onOpenDashboard()),
        ),
        const DirectionModuleMenuEntry(
          icon: Icons.swap_horiz_rounded,
          title: 'Compra-Venta',
          subtitle: 'Propuesta ejecutiva consolidada',
          current: true,
        ),
        DirectionModuleMenuEntry(
          icon: Icons.storefront_rounded,
          title: 'Análisis Menudeo',
          subtitle: 'Mercado, efectivo y operación',
          onTap: () => unawaited(onOpenMenudeoAnalysis()),
        ),
        DirectionModuleMenuEntry(
          icon: Icons.radar_rounded,
          title: 'Radar Comercial',
          subtitle: 'Detalle segmentado por cuenta y material',
          onTap: () => unawaited(onOpenCommercialRadar()),
        ),
      ],
    );
  }
}

class _TradeProposal {
  final int activeMaterials;
  final double buyVolume;
  final double sellVolume;
  final double buyAmount;
  final double sellAmount;
  final double? avgBuyPrice;
  final double? avgSellPrice;
  final double? avgSpread;
  final List<_TradeMaterialRow> topMaterials;
  final List<_TradePriceRow> priceRows;
  final List<_TradeOpportunityRow> opportunities;
  final List<CommercialAlertRecord> alerts;
  final List<CommercialGeneralCounterpartyActivityRecord> topSuppliers;
  final List<CommercialGeneralCounterpartyActivityRecord> topCustomers;
  final _TradeMaterialRow? biggestGap;
  final List<_TradeMaterialRow> fastestRotation;
  final List<_TradeMaterialRow> lowestCoverage;
  final List<_TradeMaterialRow> overboughtRows;
  final List<_TradeMaterialRow> noBenchmarkRows;
  final List<_TradeActionRow> actionRows;
  final List<_TradeWeeklyAgendaRow> weeklyAgenda;
  final List<_TradeWeeklyTrendRow> weeklyTrendRows;
  final List<_TradeTrendPoint> simpleTrend;
  final String rangeLabel;
  final _TradeStoplightSummary stoplight;
  final String mainInsight;
  final String secondaryInsight;

  const _TradeProposal({
    required this.activeMaterials,
    required this.buyVolume,
    required this.sellVolume,
    required this.buyAmount,
    required this.sellAmount,
    required this.avgBuyPrice,
    required this.avgSellPrice,
    required this.avgSpread,
    required this.topMaterials,
    required this.priceRows,
    required this.opportunities,
    required this.alerts,
    required this.topSuppliers,
    required this.topCustomers,
    required this.biggestGap,
    required this.fastestRotation,
    required this.lowestCoverage,
    required this.overboughtRows,
    required this.noBenchmarkRows,
    required this.actionRows,
    required this.weeklyAgenda,
    required this.weeklyTrendRows,
    required this.simpleTrend,
    required this.rangeLabel,
    required this.stoplight,
    required this.mainInsight,
    required this.secondaryInsight,
  });

  const _TradeProposal.empty()
    : activeMaterials = 0,
      buyVolume = 0,
      sellVolume = 0,
      buyAmount = 0,
      sellAmount = 0,
      avgBuyPrice = null,
      avgSellPrice = null,
      avgSpread = null,
      topMaterials = const <_TradeMaterialRow>[],
      priceRows = const <_TradePriceRow>[],
      opportunities = const <_TradeOpportunityRow>[],
      alerts = const <CommercialAlertRecord>[],
      topSuppliers = const <CommercialGeneralCounterpartyActivityRecord>[],
      topCustomers = const <CommercialGeneralCounterpartyActivityRecord>[],
      biggestGap = null,
      fastestRotation = const <_TradeMaterialRow>[],
      lowestCoverage = const <_TradeMaterialRow>[],
      overboughtRows = const <_TradeMaterialRow>[],
      noBenchmarkRows = const <_TradeMaterialRow>[],
      actionRows = const <_TradeActionRow>[],
      weeklyAgenda = const <_TradeWeeklyAgendaRow>[],
      weeklyTrendRows = const <_TradeWeeklyTrendRow>[],
      simpleTrend = const <_TradeTrendPoint>[],
      rangeLabel = 'Sin rango',
      stoplight = const _TradeStoplightSummary.empty(),
      mainInsight =
          'Todavía no hay lectura suficiente para construir propuesta.',
      secondaryInsight =
          'La vista queda lista para consolidar compras y ventas por material general.';
}

class _TradeMaterialRow {
  final String label;
  final String channel;
  final Set<String> channels;
  final double buyVolume;
  final double sellVolume;
  final double buyAmount;
  final double sellAmount;
  final Set<String> businessMixes;

  const _TradeMaterialRow({
    required this.label,
    required this.channel,
    required this.channels,
    required this.buyVolume,
    required this.sellVolume,
    required this.buyAmount,
    required this.sellAmount,
    required this.businessMixes,
  });

  const _TradeMaterialRow.empty({required this.label, required this.channel})
    : buyVolume = 0,
      sellVolume = 0,
      buyAmount = 0,
      sellAmount = 0,
      channels = const <String>{},
      businessMixes = const <String>{};

  _TradeMaterialRow merge({
    required double buyVolume,
    required double sellVolume,
    required double buyAmount,
    required double sellAmount,
    required String businessMix,
  }) {
    return _TradeMaterialRow(
      label: label,
      channel: channel,
      channels: channels,
      buyVolume: this.buyVolume + buyVolume,
      sellVolume: this.sellVolume + sellVolume,
      buyAmount: this.buyAmount + buyAmount,
      sellAmount: this.sellAmount + sellAmount,
      businessMixes: {
        ...businessMixes,
        if (businessMix.trim().isNotEmpty) businessMix.trim(),
      },
    );
  }

  _TradeMaterialRow mergeEvent(CommercialMarketEventRecord event) {
    if (event.flow == 'purchase') {
      return _TradeMaterialRow(
        label: label,
        channel: channel,
        channels: {
          ...channels,
          _resolveEventChannel(event.channel, event.sourceArea),
        },
        buyVolume: buyVolume + event.volumeKg,
        sellVolume: sellVolume,
        buyAmount: buyAmount + event.amountTotal,
        sellAmount: sellAmount,
        businessMixes: businessMixes,
      );
    }
    return _TradeMaterialRow(
      label: label,
      channel: channel,
      channels: {
        ...channels,
        _resolveEventChannel(event.channel, event.sourceArea),
      },
      buyVolume: buyVolume,
      sellVolume: sellVolume + event.volumeKg,
      buyAmount: buyAmount,
      sellAmount: sellAmount + event.amountTotal,
      businessMixes: businessMixes,
    );
  }

  double get totalVolume => buyVolume + sellVolume;
  double get balanceKg => sellVolume - buyVolume;
  double get volumeGap => sellVolume - buyVolume;
  double? get avgBuyPrice => buyVolume > 0 ? buyAmount / buyVolume : null;
  double? get avgSellPrice => sellVolume > 0 ? sellAmount / sellVolume : null;
  bool get missingBenchmark => avgBuyPrice == null || avgSellPrice == null;
  bool get isOverbought =>
      buyVolume > sellVolume * 1.25 ||
      volumeGap < -max(150, totalVolume * 0.15);
  double get overboughtScore => volumeGap < 0 ? volumeGap.abs() : 0;
  double? get spread => avgBuyPrice != null && avgSellPrice != null
      ? avgSellPrice! - avgBuyPrice!
      : null;
  String get businessMixLabel =>
      businessMixes.isEmpty ? 'Sin segmento' : businessMixes.join(' · ');
  String get channelKeyForDisplay {
    if (channels.length > 1) return 'consolidado';
    if (channels.contains('mayoreo')) return 'mayoreo';
    if (channels.contains('menudeo')) return 'menudeo';
    return _normalizeChannelValue(channel);
  }

  String get channelMixLabel {
    if (channels.length > 1) return 'Menudeo + Mayoreo';
    if (channels.contains('mayoreo')) return 'Mayoreo';
    if (channels.contains('menudeo')) return 'Menudeo';
    return 'Sin canal';
  }

  String get reading {
    if (buyVolume <= 0 && sellVolume <= 0) return 'Sin movimiento';
    if (spread == null) return 'Sin benchmark';
    if (spread!.abs() < 0.01) return 'Muy parejo';
    if (volumeGap > 0) return 'Sale más';
    if (volumeGap < 0) return 'Entra más';
    return 'Balanceado';
  }
}

class _TradeMaterialTotals {
  final double buyVolume;
  final double sellVolume;
  final double buyAmount;
  final double sellAmount;

  const _TradeMaterialTotals({
    required this.buyVolume,
    required this.sellVolume,
    required this.buyAmount,
    required this.sellAmount,
  });

  factory _TradeMaterialTotals.fromRows(List<_TradeMaterialRow> rows) {
    return _TradeMaterialTotals(
      buyVolume: rows.fold<double>(0, (sum, row) => sum + row.buyVolume),
      sellVolume: rows.fold<double>(0, (sum, row) => sum + row.sellVolume),
      buyAmount: rows.fold<double>(0, (sum, row) => sum + row.buyAmount),
      sellAmount: rows.fold<double>(0, (sum, row) => sum + row.sellAmount),
    );
  }
}

class _TradeWeeklyAgendaRow {
  final String headline;
  final String owner;
  final String priority;
  final String detail;
  final double score;

  const _TradeWeeklyAgendaRow({
    required this.headline,
    required this.owner,
    required this.priority,
    required this.detail,
    required this.score,
  });
}

class _TradeStoplightSummary {
  final int redCount;
  final int amberCount;
  final int greenCount;

  const _TradeStoplightSummary({
    required this.redCount,
    required this.amberCount,
    required this.greenCount,
  });

  const _TradeStoplightSummary.empty()
    : redCount = 0,
      amberCount = 0,
      greenCount = 0;
}

class _TradeWeeklyTrendRow {
  final String materialLabel;
  final List<double> spreadValues;
  final List<double> coverageValues;
  final List<double> riskValues;
  final double latestSpread;
  final double latestCoverage;
  final double latestRisk;
  final double priorSpread;
  final double priorCoverage;
  final double priorRisk;
  final String reading;

  const _TradeWeeklyTrendRow({
    required this.materialLabel,
    required this.spreadValues,
    required this.coverageValues,
    required this.riskValues,
    required this.latestSpread,
    required this.latestCoverage,
    required this.latestRisk,
    required this.priorSpread,
    required this.priorCoverage,
    required this.priorRisk,
    required this.reading,
  });

  String get latestSpreadLabel =>
      latestSpread == 0 ? 'N/D' : formatMoney(latestSpread);
  String get latestCoverageLabel => latestCoverage <= 0
      ? 'N/D'
      : '${formatDecimal(latestCoverage, decimals: 1)} d';

  Color get spreadTone {
    final delta = latestSpread - priorSpread;
    if (latestSpread <= 0) return const Color(0xFFFFA98A);
    if (delta.abs() < 0.01) return const Color(0xFFFFD98A);
    return delta > 0 ? const Color(0xFF8EFFD5) : const Color(0xFFFFA98A);
  }

  Color get coverageTone {
    final delta = latestCoverage - priorCoverage;
    if (latestCoverage <= 0) return const Color(0xFFFFA98A);
    if (delta.abs() < 0.01) return const Color(0xFFFFD98A);
    return delta > 0 ? const Color(0xFF8EFFD5) : const Color(0xFFFFA98A);
  }

  Color get riskTone {
    final delta = latestRisk - priorRisk;
    if (delta.abs() < 0.01) return const Color(0xFFFFD98A);
    return delta < 0 ? const Color(0xFF8EFFD5) : const Color(0xFFFFA98A);
  }
}

class _TradeTrendPoint {
  final DateTime date;
  final String materialLabel;
  final double kg;
  final bool isSale;
  final Color color;

  const _TradeTrendPoint({
    required this.date,
    required this.materialLabel,
    required this.kg,
    required this.isSale,
    required this.color,
  });
}

String _normalizeTrendKey(String value) {
  return value.trim().toUpperCase();
}

String _shortDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month';
}

String _exportDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString().padLeft(4, '0');
  return '$year-$month-$day';
}

String _compactDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString().padLeft(4, '0');
  return '$year$month$day';
}

String _formatRangeLabel(DateTimeRange? range) {
  if (range == null) return 'Sin rango';
  return '${_shortDate(range.start)} - ${_shortDate(range.end)}';
}

class _TradeOpportunityRow {
  final String materialLabel;
  final String segment;
  final String channel;
  final double buyPrice;
  final double sellPrice;
  final double spread;
  final double volume;

  const _TradeOpportunityRow({
    required this.materialLabel,
    required this.segment,
    required this.channel,
    required this.buyPrice,
    required this.sellPrice,
    required this.spread,
    required this.volume,
  });

  String get channelLabel {
    switch (channel) {
      case 'menudeo':
        return 'Menudeo';
      case 'mayoreo':
        return 'Mayoreo';
      case 'consolidado':
        return 'Consolidado';
      default:
        return 'Sin canal';
    }
  }
}

class _TradePriceRow {
  final String materialLabel;
  final double buyPrice;
  final double sellPrice;
  final double spread;
  final String actionLabel;
  final String message;
  final Color tone;
  final double priorityScore;

  const _TradePriceRow({
    required this.materialLabel,
    required this.buyPrice,
    required this.sellPrice,
    required this.spread,
    required this.actionLabel,
    required this.message,
    required this.tone,
    required this.priorityScore,
  });

  factory _TradePriceRow.fromMaterial(_TradeMaterialRow row) {
    final buyPrice = row.avgBuyPrice ?? 0;
    final sellPrice = row.avgSellPrice ?? 0;
    final spread = row.spread ?? 0;
    final spreadRatio = sellPrice <= 0 ? 0.0 : spread / sellPrice;
    final flowPressure =
        row.volumeGap < -max(120, row.totalVolume * 0.15) || row.isOverbought;

    if (spread <= 0) {
      return _TradePriceRow(
        materialLabel: row.label,
        buyPrice: buyPrice,
        sellPrice: sellPrice,
        spread: spread,
        actionLabel: 'Corregir',
        message:
            'La venta ya no cubre la compra promedio. Conviene subir venta, bajar compra o pausar volumen sin margen.',
        tone: const Color(0xFFFFA98A),
        priorityScore: spread.abs() + row.totalVolume,
      );
    }
    if (flowPressure) {
      return _TradePriceRow(
        materialLabel: row.label,
        buyPrice: buyPrice,
        sellPrice: sellPrice,
        spread: spread,
        actionLabel: 'Bajar / mover',
        message:
            'Hay presion de entrada contra salida. Aunque existe margen, conviene mover venta antes de seguir cargando volumen.',
        tone: const Color(0xFFFFD58A),
        priorityScore: row.volumeGap.abs() + row.totalVolume,
      );
    }
    if (spreadRatio >= 0.18 && row.sellVolume > 0) {
      return _TradePriceRow(
        materialLabel: row.label,
        buyPrice: buyPrice,
        sellPrice: sellPrice,
        spread: spread,
        actionLabel: 'Subir / sostener',
        message:
            'El margen se ve sano para sostener precio o probar un ajuste al alza sin perder la referencia.',
        tone: const Color(0xFF8EFFD5),
        priorityScore: (spreadRatio * 100) + row.sellVolume,
      );
    }
    return _TradePriceRow(
      materialLabel: row.label,
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      spread: spread,
      actionLabel: 'Mantener',
      message:
          'La relacion compra-venta se ve razonable. Conviene vigilar movimiento antes de tocar precio.',
      tone: const Color(0xFFB7C3FF),
      priorityScore: row.totalVolume,
    );
  }
}

class _TradeActionRow {
  final String materialLabel;
  final String actionTitle;
  final String actionBody;
  final String priorityLabel;
  final double priorityScore;

  const _TradeActionRow({
    required this.materialLabel,
    required this.actionTitle,
    required this.actionBody,
    required this.priorityLabel,
    required this.priorityScore,
  });

  factory _TradeActionRow.fromMaterial(_TradeMaterialRow row) {
    final spread = row.spread;
    if (spread != null && spread > 0) {
      return _TradeActionRow(
        materialLabel: row.label,
        actionTitle: 'Empujar precio / venta',
        actionBody:
            'Spread observado de ${formatMoney(spread)} por kg con salida de ${formatDecimal(row.sellVolume, decimals: 0)} kg. Vale la pena vigilar demanda y mezcla de clientes.',
        priorityLabel: 'Comercial',
        priorityScore: 60 + spread,
      );
    }
    if (row.volumeGap < 0) {
      return _TradeActionRow(
        materialLabel: row.label,
        actionTitle: 'Desplazar inventario',
        actionBody:
            'Entró más de lo que salió por ${formatDecimal(row.volumeGap.abs(), decimals: 0)} kg. Conviene revisar precio, clientes o velocidad de salida.',
        priorityLabel: 'Flujo',
        priorityScore: 40 + row.volumeGap.abs(),
      );
    }
    return _TradeActionRow(
      materialLabel: row.label,
      actionTitle: 'Seguir observando',
      actionBody:
          'La lectura actual no prende una alerta mayor, pero el material ya tiene volumen suficiente para seguimiento ejecutivo.',
      priorityLabel: 'Media',
      priorityScore: row.totalVolume,
    );
  }
}

bool _matchesChannel(String source, _TradeChannelFilter channel) {
  final normalized = _normalizeChannelValue(source);
  return switch (channel) {
    _TradeChannelFilter.todos => true,
    _TradeChannelFilter.menudeo => normalized == 'menudeo',
    _TradeChannelFilter.mayoreo => normalized == 'mayoreo',
  };
}

String _resolveEventChannel(String channel, String sourceArea) {
  final normalizedChannel = _normalizeChannelValue(channel);
  if (normalizedChannel == 'menudeo' || normalizedChannel == 'mayoreo') {
    return normalizedChannel;
  }
  return _normalizeChannelValue(sourceArea);
}

String _eventSourceLabel(CommercialMarketEventRecord event) {
  final source = event.sourceArea.trim().toLowerCase();
  if (source == 'menudeo') return 'Menudeo';
  if (source == 'mayoreo_compras') return 'Mayoreo compras';
  if (source == 'mayoreo_ventas') return 'Mayoreo ventas';
  final resolved = _resolveEventChannel(event.channel, event.sourceArea);
  if (resolved == 'mayoreo') return 'Mayoreo';
  if (resolved == 'menudeo') return 'Menudeo';
  return event.sourceArea.trim().isEmpty ? 'Sin fuente' : event.sourceArea;
}

String _normalizeChannelValue(String source) {
  final normalized = source.trim().toLowerCase();
  if (normalized.contains('mayoreo')) return 'mayoreo';
  if (normalized.contains('menudeo')) return 'menudeo';
  return normalized;
}

String _buildMainInsight({
  required List<_TradeOpportunityRow> opportunities,
  required _TradeMaterialRow? biggestGap,
}) {
  if (opportunities.isNotEmpty) {
    final top = opportunities.first;
    return '${top.materialLabel} aparece como la mejor oportunidad inicial: compra promedio en ${formatMoney(top.buyPrice)} y venta promedio en ${formatMoney(top.sellPrice)} dentro de ${top.channelLabel.toLowerCase()}.';
  }
  if (biggestGap != null) {
    final side = biggestGap.volumeGap > 0 ? 'salida' : 'entrada';
    return '${biggestGap.label} concentra el mayor desbalance de volumen; conviene revisar ritmo de $side antes de mover precio.';
  }
  return 'La página ya queda estructurada para tomar decisiones por material general cuando entren más comparables.';
}

String _buildSecondaryInsight({
  required double buyVolume,
  required double sellVolume,
  required double buyAmount,
  required double sellAmount,
}) {
  final volumeDelta = sellVolume - buyVolume;
  final amountDelta = sellAmount - buyAmount;
  final volumeText = volumeDelta.abs() < 0.01
      ? 'volumen equilibrado'
      : volumeDelta > 0
      ? 'sale más volumen del que entra'
      : 'entra más volumen del que sale';
  final amountText = amountDelta.abs() < 0.01
      ? 'importe parejo'
      : amountDelta > 0
      ? 'el valor de venta supera al de compra'
      : 'el valor de compra supera al de venta';
  return 'En la ventana reciente $volumeText y $amountText. Esa combinación sirve para decidir si urge asegurar abasto, empujar venta o corregir precio.';
}

String _formatLastActivity(DateTime? value) {
  if (value == null) return 'Sin fecha';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month';
}
