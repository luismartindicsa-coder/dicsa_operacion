import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../menudeo/menudeo_filter_widgets.dart';
import '../../../shared/utils/number_formatters.dart';
import '../../direction_theme.dart';
import 'menudeo_analysis_models.dart';
import 'menudeo_analysis_state.dart';

class MenudeoMarketTab extends StatelessWidget {
  final MenudeoAnalysisState state;

  const MenudeoMarketTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final view = state.marketView;
    if (state.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (state.error != null) {
      return DirectionGlassPanel(
        child: Text(
          'No se pudo cargar el análisis de mercado: ${state.error}',
          style: const TextStyle(
            color: kDirectionSurfaceText,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (view == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MarketFiltersBar(state: state),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            DirectionMetricCard(
              icon: Icons.query_stats_rounded,
              title: 'PRECIOS ACTIVOS',
              value: '${view.snapshot.activePrices}',
              detail: 'Filtrados con datos reales',
              accent: directionAreaTokens.primary,
            ),
            DirectionMetricCard(
              icon: Icons.flash_on_rounded,
              title: 'OPORTUNIDADES',
              value: '${view.snapshot.actionablePrices}',
              detail: 'Ajustes con acción sugerida',
              accent: directionAreaTokens.accent,
            ),
            DirectionMetricCard(
              icon: Icons.show_chart_rounded,
              title: 'IMPACTO POTENCIAL',
              value: formatMoney(view.snapshot.potentialImpact),
              detail: 'Delta estimado por volumen reciente',
              accent: const Color(0xFF7CE0FF),
            ),
            DirectionMetricCard(
              icon: Icons.warning_amber_rounded,
              title: 'SPREADS EN PRESIÓN',
              value: '${view.snapshot.pressuredMaterials}',
              detail: 'Materiales con spread crítico',
              accent: const Color(0xFFFFB468),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _MarketInsightsCard(view: view),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 1180;
            if (stacked) {
              return Column(
                children: [
                  _SpreadChartCard(state: state, view: view),
                  const SizedBox(height: 14),
                  _AlertsCard(view: view),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 8,
                  child: _SpreadChartCard(state: state, view: view),
                ),
                const SizedBox(width: 14),
                Expanded(flex: 4, child: _AlertsCard(view: view)),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 1180;
            if (stacked) {
              return Column(
                children: [
                  _PositioningCard(state: state, view: view),
                  const SizedBox(height: 14),
                  _AdjustmentTimelineCard(state: state, view: view),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: _PositioningCard(state: state, view: view),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 5,
                  child: _AdjustmentTimelineCard(state: state, view: view),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _OpportunitiesCard(state: state, view: view),
      ],
    );
  }
}

class _MarketFiltersBar extends StatelessWidget {
  final MenudeoAnalysisState state;

  const _MarketFiltersBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final dataset = state.dataset;
    return DirectionToolbarPanel(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _DateRangeFilterButton(
            label: 'Ventana',
            range: state.filters.dateRange,
            onTap: () => _openDateRange(context),
          ),
          _FilterDropdown<MenudeoAnalysisFlow>(
            label: 'Flujo',
            width: 132,
            value: state.filters.flow,
            items: MenudeoAnalysisFlow.values,
            itemLabel: (value) =>
                value == null ? 'Ambos' : menudeoFlowLabel(value),
            onChanged: (value) {
              if (value != null) state.setFlow(value);
            },
          ),
          _FilterDropdown<String?>(
            label: 'Material',
            width: 220,
            value: state.filters.material,
            items: <String?>[null, ...(dataset?.materials ?? const <String>[])],
            itemLabel: (value) => value ?? 'Todos',
            onChanged: state.setMaterial,
          ),
          _FilterDropdown<String?>(
            label: 'Contraparte',
            width: 240,
            value: state.filters.counterparty,
            items: <String?>[
              null,
              ...(dataset?.counterparties ?? const <String>[]),
            ],
            itemLabel: (value) => value ?? 'Todas',
            onChanged: state.setCounterparty,
          ),
          _FilterDropdown<String?>(
            label: 'Grupo',
            width: 170,
            value: state.filters.groupCode,
            items: <String?>[
              null,
              ...(dataset?.groupCodes ?? const <String>[]),
            ],
            itemLabel: (value) => value ?? 'Todos',
            onChanged: state.setGroupCode,
          ),
          _FilterDropdown<MenudeoOpportunitySeverity>(
            label: 'Estado',
            width: 170,
            value: state.filters.severity,
            items: MenudeoOpportunitySeverity.values,
            itemLabel: (value) =>
                value == null ? 'Todos' : menudeoSeverityLabel(value),
            onChanged: (value) {
              if (value != null) state.setSeverity(value);
            },
          ),
          _ExecutiveToggleChip(
            label: 'Solo accionables',
            selected: state.filters.actionableOnly,
            onTap: () => state.setActionableOnly(!state.filters.actionableOnly),
          ),
          _ExecutiveToggleChip(
            label: 'Alto impacto',
            selected: state.filters.highImpactOnly,
            onTap: () => state.setHighImpactOnly(!state.filters.highImpactOnly),
          ),
          _ExecutiveToggleChip(
            label: 'Cambios recientes',
            selected: state.filters.recentChangesOnly,
            onTap: () =>
                state.setRecentChangesOnly(!state.filters.recentChangesOnly),
          ),
        ],
      ),
    );
  }

  Future<void> _openDateRange(BuildContext context) async {
    final result = await showMenudeoDateRangeFilterDialog(
      context,
      label: 'VENTANA',
      bounds: DateTimeRange(start: DateTime(2024, 1, 1), end: DateTime.now()),
      initialRange: state.filters.dateRange,
    );
    if (result == null) return;
    if (result.clear) {
      state.setDateRange(null);
      return;
    }
    state.setDateRange(result.range);
  }
}

class _DateRangeFilterButton extends StatelessWidget {
  final String label;
  final DateTimeRange? range;
  final VoidCallback onTap;

  const _DateRangeFilterButton({
    required this.label,
    required this.range,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 208,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF10274E).withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: kDirectionMutedText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.date_range_rounded,
                    color: kDirectionSurfaceText,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      range == null
                          ? 'Últimos 30 días'
                          : _formatDateRange(range!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kDirectionSurfaceText,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExecutiveToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ExecutiveToggleChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? const Color(0xFF66D5FF).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.34)
                : Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? kDirectionSurfaceText : kDirectionMutedText,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final double width;
  final T? value;
  final List<T?> items;
  final String Function(T? value) itemLabel;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.width,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isDense: true,
        isExpanded: true,
        dropdownColor: const Color(0xFF153160),
        iconEnabledColor: kDirectionSurfaceText,
        style: const TextStyle(
          color: kDirectionSurfaceText,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: kDirectionMutedText,
            fontWeight: FontWeight.w700,
          ),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFF10274E).withValues(alpha: 0.82),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: directionAreaTokens.primary.withValues(alpha: 0.76),
              width: 1.2,
            ),
          ),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(growable: false),
        onChanged: onChanged,
      ),
    );
  }
}

class _SpreadChartCard extends StatelessWidget {
  final MenudeoAnalysisState state;
  final MenudeoMarketViewData view;

  const _SpreadChartCard({required this.state, required this.view});

  @override
  Widget build(BuildContext context) {
    final rows = view.spreads.take(8).toList(growable: false);
    final maxValue = rows.fold<double>(
      1,
      (max, row) =>
          math.max(max, math.max(row.purchasePrice ?? 0, row.salePrice ?? 0)),
    );
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spread por material',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Click en un material para cruzar la tabla de oportunidades con ese frente de mercado.',
            style: TextStyle(
              color: kDirectionMutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            const Text(
              'No hay materiales con precios vigentes para la selección actual.',
              style: TextStyle(color: kDirectionMutedText),
            )
          else
            Column(
              children: rows
                  .map(
                    (row) => _SpreadChartRow(
                      row: row,
                      maxValue: maxValue,
                      selected: state.filters.material == row.material,
                      onTap: () => state.setMaterial(
                        state.filters.material == row.material
                            ? null
                            : row.material,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _SpreadChartRow extends StatefulWidget {
  final MenudeoSpreadRow row;
  final double maxValue;
  final bool selected;
  final VoidCallback onTap;

  const _SpreadChartRow({
    required this.row,
    required this.maxValue,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SpreadChartRow> createState() => _SpreadChartRowState();
}

class _SpreadChartRowState extends State<_SpreadChartRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final purchaseFactor = (row.purchasePrice ?? 0) / widget.maxValue;
    final saleFactor = (row.salePrice ?? 0) / widget.maxValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: widget.selected
                  ? const Color(0xFF74D8FF).withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: _hovered ? 0.08 : 0.04),
              border: Border.all(
                color: widget.selected
                    ? Colors.white.withValues(alpha: 0.42)
                    : Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.material,
                        style: const TextStyle(
                          color: kDirectionSurfaceText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      'Spread ${row.spread >= 0 ? '+' : ''}${row.spread.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: row.isPressured
                            ? const Color(0xFFFF9A8B)
                            : const Color(0xFF99EAFF),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SpreadBar(
                  label: 'Compra',
                  value: row.purchasePrice ?? 0,
                  factor: purchaseFactor,
                  color: const Color(0xFF6EB6FF),
                ),
                const SizedBox(height: 8),
                _SpreadBar(
                  label: 'Venta',
                  value: row.salePrice ?? 0,
                  factor: saleFactor,
                  color: const Color(0xFF64F0DD),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpreadBar extends StatelessWidget {
  final String label;
  final double value;
  final double factor;
  final Color color;

  const _SpreadBar({
    required this.label,
    required this.value,
    required this.factor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 54,
          child: Text(
            label,
            style: const TextStyle(
              color: kDirectionMutedText,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: factor.clamp(0, 1),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 76,
          child: Text(
            value > 0 ? value.toStringAsFixed(2) : '—',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: kDirectionSurfaceText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _AlertsCard extends StatelessWidget {
  final MenudeoMarketViewData view;

  const _AlertsCard({required this.view});

  @override
  Widget build(BuildContext context) {
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alertas de mercado',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (view.alerts.isEmpty)
            const Text(
              'No hay alertas para los filtros actuales.',
              style: TextStyle(color: kDirectionMutedText),
            )
          else
            Column(
              children: view.alerts
                  .map(
                    (alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        height: 104,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: menudeoSeverityColor(
                              alert.severity,
                            ).withValues(alpha: 0.12),
                            border: Border.all(
                              color: menudeoSeverityColor(
                                alert.severity,
                              ).withValues(alpha: 0.22),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: kDirectionSurfaceText,
                                  fontWeight: FontWeight.w800,
                                  height: 1.18,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Text(
                                  alert.detail,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: kDirectionMutedText,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _MarketInsightsCard extends StatelessWidget {
  final MenudeoMarketViewData view;

  const _MarketInsightsCard({required this.view});

  @override
  Widget build(BuildContext context) {
    final insights = _buildInsights(view);
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recomendaciones ejecutivas',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Lectura sintetizada de qué mover, dónde está la presión y qué ajustes recientes siguen sin dar tranquilidad.',
            style: TextStyle(
              color: kDirectionMutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: insights
                .map(
                  (item) => SizedBox(
                    width: 300,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: item.color.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: kDirectionSurfaceText,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.detail,
                            style: const TextStyle(
                              color: kDirectionMutedText,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _InsightItem {
  final String title;
  final String detail;
  final Color color;

  const _InsightItem({
    required this.title,
    required this.detail,
    required this.color,
  });
}

List<_InsightItem> _buildInsights(MenudeoMarketViewData view) {
  final insights = <_InsightItem>[];
  final raise = view.opportunities
      .where((row) => row.action == MenudeoOpportunityAction.raisePrice)
      .cast<MenudeoPriceOpportunity?>()
      .firstWhere((row) => row != null, orElse: () => null);
  final lower = view.opportunities
      .where((row) => row.action == MenudeoOpportunityAction.lowerPrice)
      .cast<MenudeoPriceOpportunity?>()
      .firstWhere((row) => row != null, orElse: () => null);
  final pressured = view.spreads
      .where((row) => row.isPressured)
      .cast<MenudeoSpreadRow?>()
      .firstWhere((row) => row != null, orElse: () => null);
  final recent = view.history.cast<MenudeoMarketHistoryEvent?>().firstWhere(
    (row) => row != null && row.reason.isNotEmpty,
    orElse: () => null,
  );

  if (raise != null) {
    insights.add(
      _InsightItem(
        title: 'Espacio claro para subir',
        detail:
            '${raise.counterparty} en ${raise.material} todavía está ${(raise.deviationPercent.abs() * 100).toStringAsFixed(1)}% por debajo de referencia. Ajuste sugerido: +${raise.suggestedDelta.toStringAsFixed(2)}.',
        color: const Color(0xFF66F0DC),
      ),
    );
  }
  if (lower != null) {
    insights.add(
      _InsightItem(
        title: 'Compra con sobrepago visible',
        detail:
            '${lower.counterparty} en ${lower.material} está arriba de referencia y arrastra un impacto estimado de ${formatMoney(lower.impactEstimate)}. Ajuste sugerido: ${lower.suggestedDelta.toStringAsFixed(2)}.',
        color: const Color(0xFFFFC86B),
      ),
    );
  }
  if (pressured != null) {
    insights.add(
      _InsightItem(
        title: 'Material en presión comercial',
        detail:
            '${pressured.material} trae spread de ${pressured.spread.toStringAsFixed(2)} con volumen reciente de ${pressured.saleWeight.toStringAsFixed(0)} kg venta y ${pressured.purchaseWeight.toStringAsFixed(0)} kg compra.',
        color: const Color(0xFFFF9A8B),
      ),
    );
  }
  if (recent != null) {
    insights.add(
      _InsightItem(
        title: 'Cambio reciente a vigilar',
        detail:
            '${recent.counterparty} en ${recent.material} movió ${recent.previousPrice.toStringAsFixed(2)} → ${recent.newPrice.toStringAsFixed(2)}. Motivo: ${recent.reason}.',
        color: const Color(0xFF7CCEFF),
      ),
    );
  }
  if (insights.isEmpty) {
    insights.add(
      const _InsightItem(
        title: 'Sin hallazgos fuertes',
        detail:
            'Con los filtros actuales no aparecen desviaciones claras, spreads presionados ni cambios recientes que requieran intervención inmediata.',
        color: Color(0xFF7CCEFF),
      ),
    );
  }
  return insights.take(4).toList(growable: false);
}

class _PositioningCard extends StatelessWidget {
  final MenudeoAnalysisState state;
  final MenudeoMarketViewData view;

  const _PositioningCard({required this.state, required this.view});

  @override
  Widget build(BuildContext context) {
    final points = view.opportunities.take(14).toList(growable: false);
    final impactRows = [...view.opportunities]
      ..sort((a, b) => b.impactEstimate.compareTo(a.impactEstimate));
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Posición de precios',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            view.selectedOpportunity == null
                ? 'Vista ejecutiva por desviación y volumen reciente. Click en un punto para fijar esa relación contraparte-material.'
                : 'Enfoque activo: ${view.selectedOpportunity!.counterparty} · ${view.selectedOpportunity!.material}.',
            style: const TextStyle(
              color: kDirectionMutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _MarketLegendChip(
                label: 'Eje X: volumen reciente',
                color: Color(0xFF7CCEFF),
              ),
              _MarketLegendChip(
                label: 'Eje Y: desviación vs referencia',
                color: Color(0xFFFFC86B),
              ),
              _MarketLegendChip(
                label: 'Tamaño: impacto estimado',
                color: Color(0xFFFF9A8B),
              ),
              _MarketLegendChip(
                label: 'Cyan venta · ámbar compra',
                color: Color(0xFF66F0DC),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (points.isEmpty)
            const Text(
              'No hay posiciones suficientes para la selección actual.',
              style: TextStyle(color: kDirectionMutedText),
            )
          else
            SizedBox(
              height: 280,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _MarketGridPainter()),
                  ),
                  Positioned(
                    left: 48,
                    top: 34,
                    child: _QuadrantLabel(
                      title: 'Alta desviación',
                      subtitle: 'Bajo volumen',
                      alignRight: false,
                    ),
                  ),
                  Positioned(
                    right: 18,
                    top: 34,
                    child: _QuadrantLabel(
                      title: 'Alta prioridad',
                      subtitle: 'Alta desviación + volumen',
                      alignRight: true,
                      emphasized: true,
                    ),
                  ),
                  Positioned(
                    left: 48,
                    bottom: 24,
                    child: _QuadrantLabel(
                      title: 'Menor urgencia',
                      subtitle: 'Bajo volumen + baja desviación',
                      alignRight: false,
                    ),
                  ),
                  Positioned(
                    right: 18,
                    bottom: 24,
                    child: _QuadrantLabel(
                      title: 'Volumen fuerte',
                      subtitle: 'Baja desviación',
                      alignRight: true,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'Menor volumen',
                          style: TextStyle(
                            color: kDirectionMutedText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Mayor volumen',
                          style: TextStyle(
                            color: kDirectionMutedText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 120,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        'Desviación contra referencia',
                        style: TextStyle(
                          color: kDirectionMutedText.withValues(alpha: 0.78),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  ..._buildPoints(points),
                ],
              ),
            ),
          const SizedBox(height: 18),
          _ImpactRankingSection(
            state: state,
            rows: impactRows.take(6).toList(growable: false),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPoints(List<MenudeoPriceOpportunity> points) {
    final maxWeight = points.fold<double>(
      1,
      (max, row) => math.max(max, row.recentWeight.abs()),
    );
    final maxDeviation = points.fold<double>(
      0.01,
      (max, row) => math.max(max, row.deviationPercent.abs()),
    );

    return points
        .map((row) {
          final xFactor = (row.recentWeight.abs() / maxWeight).clamp(0.0, 1.0);
          final deviation = row.deviationPercent;
          final yNormalized = ((maxDeviation - deviation) / (maxDeviation * 2))
              .clamp(0.0, 1.0);
          final size = (18 + (row.impactEstimate.abs() / 8000).clamp(0, 1) * 20)
              .toDouble();
          final color = menudeoSeverityColor(row.severity);

          return Positioned(
            left: 32 + xFactor * 420,
            top: 28 + yNormalized * 190,
            child: Tooltip(
              preferBelow: false,
              decoration: BoxDecoration(
                color: const Color(0xFF0F264A).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              textStyle: const TextStyle(
                color: kDirectionSurfaceText,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              message:
                  '${row.counterparty}\n${row.material}\n${menudeoFlowLabel(row.flow)} · ${(row.deviationPercent * 100).toStringAsFixed(1)}%\nVolumen ${row.recentWeight.toStringAsFixed(0)} kg',
              child: GestureDetector(
                onTap: () => state.selectOpportunity(
                  state.selectedOpportunityId == row.id ? null : row.id,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        (row.flow == MenudeoAnalysisFlow.purchase
                                ? const Color(0xFFFFC86B)
                                : color)
                            .withValues(alpha: 0.88),
                      ],
                    ),
                    border: Border.all(
                      color: state.selectedOpportunityId == row.id
                          ? Colors.white.withValues(alpha: 0.92)
                          : color.withValues(alpha: 0.42),
                      width: state.selectedOpportunityId == row.id ? 1.8 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.36),
                        blurRadius: state.selectedOpportunityId == row.id
                            ? 22
                            : 16,
                        spreadRadius: state.selectedOpportunityId == row.id
                            ? 2
                            : 0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        })
        .toList(growable: false);
  }
}

class _MarketLegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MarketLegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: kDirectionSurfaceText,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuadrantLabel extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool alignRight;
  final bool emphasized;

  const _QuadrantLabel({
    required this.title,
    required this.subtitle,
    required this.alignRight,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = emphasized
        ? const Color(0xFF8DEBFF)
        : Colors.white.withValues(alpha: 0.78);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: alignRight
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: kDirectionMutedText,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactRankingSection extends StatelessWidget {
  final MenudeoAnalysisState state;
  final List<MenudeoPriceOpportunity> rows;

  const _ImpactRankingSection({required this.state, required this.rows});

  @override
  Widget build(BuildContext context) {
    final maxImpact = rows.isEmpty
        ? 1.0
        : math.max(rows.first.impactEstimate, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Impacto estimado por oportunidad',
          style: TextStyle(
            color: kDirectionSurfaceText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Visual más directa para ver qué relación merece atención primero según impacto económico estimado.',
          style: TextStyle(
            color: kDirectionMutedText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const Text(
            'Sin oportunidades para rankear.',
            style: TextStyle(color: kDirectionMutedText),
          )
        else
          Column(
            children: rows
                .map((row) {
                  final color = row.flow == MenudeoAnalysisFlow.purchase
                      ? const Color(0xFFFFC86B)
                      : const Color(0xFF66F0DC);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => state.selectOpportunity(
                        state.selectedOpportunityId == row.id ? null : row.id,
                      ),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: state.selectedOpportunityId == row.id
                              ? color.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.04),
                          border: Border.all(
                            color: state.selectedOpportunityId == row.id
                                ? Colors.white.withValues(alpha: 0.34)
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${row.counterparty} · ${row.material}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: kDirectionSurfaceText,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  formatMoney(row.impactEstimate),
                                  style: const TextStyle(
                                    color: kDirectionSurfaceText,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 10,
                                value: (row.impactEstimate / maxImpact).clamp(
                                  0,
                                  1,
                                ),
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.08,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  '${menudeoActionLabel(row.action)} · ${(row.deviationPercent * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${row.recentWeight.toStringAsFixed(0)} kg',
                                  style: const TextStyle(
                                    color: kDirectionMutedText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _AdjustmentTimelineCard extends StatelessWidget {
  final MenudeoAnalysisState state;
  final MenudeoMarketViewData view;

  const _AdjustmentTimelineCard({required this.state, required this.view});

  @override
  Widget build(BuildContext context) {
    final events = view.history.take(8).toList(growable: false);
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timeline de ajustes',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            view.selectedOpportunity == null
                ? 'Histórico reciente de movimientos de precio dentro del filtro activo.'
                : 'Histórico enfocado a la oportunidad activa. Puedes deseleccionar la fila para volver a vista amplia.',
            style: const TextStyle(
              color: kDirectionMutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (events.isEmpty)
            const Text(
              'No hay ajustes recientes para la selección actual.',
              style: TextStyle(color: kDirectionMutedText),
            )
          else
            Column(
              children: events
                  .map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TimelineEventTile(
                        event: event,
                        selected:
                            view.selectedOpportunity?.id == event.priceId ||
                            (view.selectedOpportunity != null &&
                                view.selectedOpportunity!.material ==
                                    event.material &&
                                view.selectedOpportunity!.counterparty ==
                                    event.counterparty),
                        onTap: () {
                          state.setFlow(event.flow);
                          state.setMaterial(event.material);
                          state.setCounterparty(event.counterparty);
                        },
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _TimelineEventTile extends StatelessWidget {
  final MenudeoMarketHistoryEvent event;
  final bool selected;
  final VoidCallback onTap;

  const _TimelineEventTile({
    required this.event,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final delta = event.delta;
    final deltaColor = delta >= 0
        ? const Color(0xFF76F5D6)
        : const Color(0xFFFFB468);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.30)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: event.flow == MenudeoAnalysisFlow.purchase
                    ? const Color(0xFFFFC86B)
                    : const Color(0xFF66F0DC),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${event.counterparty} · ${event.material}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kDirectionSurfaceText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimelineDate(event.createdAt),
                        style: const TextStyle(
                          color: kDirectionMutedText,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${event.previousPrice.toStringAsFixed(2)} → ${event.newPrice.toStringAsFixed(2)} · ${menudeoFlowLabel(event.flow)}',
                    style: TextStyle(
                      color: deltaColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  if (event.reason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kDirectionMutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    final accentPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1.2;

    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(30, y), Offset(size.width - 10, y), linePaint);
    }
    for (var i = 1; i < 5; i++) {
      final x = 30 + (size.width - 40) * i / 5;
      canvas.drawLine(Offset(x, 20), Offset(x, size.height - 20), linePaint);
    }
    final midY = size.height / 2;
    canvas.drawLine(
      Offset(30, midY),
      Offset(size.width - 10, midY),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _formatTimelineDate(DateTime? value) {
  if (value == null) return 'Sin fecha';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}

String _formatDateRange(DateTimeRange range) {
  final startDay = range.start.day.toString().padLeft(2, '0');
  final startMonth = range.start.month.toString().padLeft(2, '0');
  final endDay = range.end.day.toString().padLeft(2, '0');
  final endMonth = range.end.month.toString().padLeft(2, '0');
  return '$startDay/$startMonth/${range.start.year} - $endDay/$endMonth/${range.end.year}';
}

class _OpportunitiesCard extends StatelessWidget {
  final MenudeoAnalysisState state;
  final MenudeoMarketViewData view;

  const _OpportunitiesCard({required this.state, required this.view});

  @override
  Widget build(BuildContext context) {
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Oportunidades de ajuste',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Haz click en una fila para fijar la oportunidad activa. Esta primera versión ya cruza con los filtros globales y con la visual de materiales.',
            style: TextStyle(
              color: kDirectionMutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OpportunityHeader(),
                  const SizedBox(height: 8),
                  if (view.opportunities.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 22),
                      child: Text(
                        'No hay oportunidades para los filtros actuales.',
                        style: TextStyle(color: kDirectionMutedText),
                      ),
                    )
                  else
                    Column(
                      children: view.opportunities
                          .take(12)
                          .map(
                            (row) => _OpportunityRow(
                              row: row,
                              selected: state.selectedOpportunityId == row.id,
                              onTap: () => state.selectOpportunity(
                                state.selectedOpportunityId == row.id
                                    ? null
                                    : row.id,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpportunityHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      color: kDirectionMutedText,
      fontWeight: FontWeight.w800,
      fontSize: 12,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(width: 190, child: Text('CONTRAPARTE', style: headerStyle)),
        SizedBox(width: 140, child: Text('MATERIAL', style: headerStyle)),
        SizedBox(width: 80, child: Text('FLUJO', style: headerStyle)),
        SizedBox(width: 94, child: Text('ACTUAL', style: headerStyle)),
        SizedBox(width: 94, child: Text('REFER.', style: headerStyle)),
        SizedBox(width: 90, child: Text('DELTA', style: headerStyle)),
        SizedBox(width: 100, child: Text('IMPACTO', style: headerStyle)),
        SizedBox(width: 180, child: Text('ESTADO', style: headerStyle)),
      ],
    );
  }
}

class _OpportunityRow extends StatefulWidget {
  final MenudeoPriceOpportunity row;
  final bool selected;
  final VoidCallback onTap;

  const _OpportunityRow({
    required this.row,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_OpportunityRow> createState() => _OpportunityRowState();
}

class _OpportunityRowState extends State<_OpportunityRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final severityColor = menudeoSeverityColor(row.severity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: widget.selected
                  ? severityColor.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: _hovered ? 0.06 : 0.03),
              border: Border.all(
                color: widget.selected
                    ? Colors.white.withValues(alpha: 0.38)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 190,
                  child: Text(
                    row.counterparty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kDirectionSurfaceText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: Text(
                    row.material,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kDirectionSurfaceText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    menudeoFlowLabel(row.flow),
                    style: const TextStyle(
                      color: kDirectionMutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 94,
                  child: Text(
                    row.currentPrice.toStringAsFixed(2),
                    style: const TextStyle(
                      color: kDirectionSurfaceText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(
                  width: 94,
                  child: Text(
                    row.referencePrice.toStringAsFixed(2),
                    style: const TextStyle(
                      color: kDirectionMutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    '${row.suggestedDelta >= 0 ? '+' : ''}${row.suggestedDelta.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: row.action == MenudeoOpportunityAction.hold
                          ? kDirectionMutedText
                          : severityColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    formatMoney(row.impactEstimate),
                    style: const TextStyle(
                      color: kDirectionSurfaceText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: severityColor.withValues(alpha: 0.14),
                        border: Border.all(
                          color: severityColor.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        '${menudeoSeverityLabel(row.severity)} · ${menudeoActionLabel(row.action)}',
                        style: TextStyle(
                          color: severityColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
