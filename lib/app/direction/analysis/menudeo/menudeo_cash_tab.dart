import 'package:flutter/material.dart';

import '../../../menudeo/menudeo_filter_widgets.dart';
import '../../../shared/utils/number_formatters.dart';
import '../../direction_theme.dart';
import 'menudeo_analysis_models.dart';
import 'menudeo_analysis_state.dart';

class MenudeoCashTab extends StatefulWidget {
  final MenudeoAnalysisState state;

  const MenudeoCashTab({super.key, required this.state});

  @override
  State<MenudeoCashTab> createState() => _MenudeoCashTabState();
}

class _MenudeoCashTabState extends State<MenudeoCashTab> {
  MenudeoCashMovementFilter _movement = MenudeoCashMovementFilter.all;
  String? _rubric;
  String? _person;
  DateTime? _selectedCashDate;
  String? _selectedUnitLabel;

  @override
  Widget build(BuildContext context) {
    final dataset = widget.state.cashDataset;
    if (widget.state.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (widget.state.error != null) {
      return DirectionGlassPanel(
        child: Text(
          'No se pudo cargar el análisis de efectivo: ${widget.state.error}',
          style: const TextStyle(
            color: kDirectionSurfaceText,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (dataset == null) return const SizedBox.shrink();

    final baseRows = _movement == MenudeoCashMovementFilter.deposits
        ? const <MenudeoCashBreakdownRow>[]
        : dataset.rubricRows;
    final rubricRows = _rubric == null
        ? baseRows
        : baseRows.where((row) => row.label == _rubric).toList(growable: false);
    final conceptRows = dataset.conceptRows;
    final subconceptRows = dataset.subconceptRows;
    final personRows = _person == null
        ? dataset.personRows
        : dataset.personRows
              .where((row) => row.label == _person)
              .toList(growable: false);
    final selectedTimelinePoint = _resolveTimelineSelection(dataset.timeline);
    final selectedUnitRow = _resolveUnitSelection(dataset.logisticsUnitRows);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CashFiltersBar(
          state: widget.state,
          movement: _movement,
          rubric: _rubric,
          person: _person,
          rubrics: dataset.rubrics,
          people: dataset.people,
          onMovementChanged: (value) => setState(() => _movement = value),
          onRubricChanged: (value) => setState(() => _rubric = value),
          onPersonChanged: (value) => setState(() => _person = value),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            DirectionMetricCard(
              icon: Icons.south_west_rounded,
              title: 'DEPÓSITOS',
              value: formatMoney(dataset.snapshot.deposits),
              detail: 'Entradas capturadas en caja',
              accent: kDirectionSuccess,
            ),
            DirectionMetricCard(
              icon: Icons.north_east_rounded,
              title: 'GASTOS',
              value: formatMoney(dataset.snapshot.expenses),
              detail: 'Salidas capturadas en caja',
              accent: kDirectionWarning,
            ),
            DirectionMetricCard(
              icon: Icons.account_balance_wallet_rounded,
              title: 'FLUJO NETO',
              value: formatMoney(dataset.snapshot.netFlow),
              detail: 'Depósitos menos gastos',
              accent: kDirectionOliveMist,
            ),
            DirectionMetricCard(
              icon: Icons.rule_folder_rounded,
              title: 'CONTROL',
              value:
                  '${dataset.snapshot.cutsWithDifference} cortes · ${dataset.snapshot.pendingChecks} checks',
              detail: 'Descuadres y conciliaciones pendientes',
              accent: kDirectionDanger,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _CashTimelineCard(
          movement: _movement,
          timeline: dataset.timeline,
          selectedPoint: selectedTimelinePoint,
          onSelectPoint: (point) {
            setState(() {
              _selectedCashDate = _sameDate(_selectedCashDate, point.date)
                  ? null
                  : point.date;
            });
          },
        ),
        const SizedBox(height: 14),
        if (_movement != MenudeoCashMovementFilter.deposits)
          _CashFocusedBreakdownsCard(
            fuel: dataset.fuelBreakdown,
            maintenance: dataset.maintenanceBreakdown,
            travel: dataset.travelBreakdown,
            byUnit: dataset.logisticsUnitBreakdown,
            unitRows: dataset.logisticsUnitRows,
            selectedUnitRow: selectedUnitRow,
            onSelectUnit: (row) {
              setState(() {
                _selectedUnitLabel = _selectedUnitLabel == row.label
                    ? null
                    : row.label;
              });
            },
          ),
        if (_movement != MenudeoCashMovementFilter.deposits)
          const SizedBox(height: 14),
        _CashInsightsCard(
          rubricRows: rubricRows,
          conceptRows: conceptRows,
          subconceptRows: subconceptRows,
          personRows: personRows,
          movement: _movement,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 1180;
            final breakdowns = _CashBreakdownCard(
              rubricRows: rubricRows,
              conceptRows: conceptRows,
              subconceptRows: subconceptRows,
              personRows: personRows,
            );
            final alerts = _CashAlertsCard(alerts: dataset.alerts);
            if (stacked) {
              return Column(
                children: [
                  breakdowns,
                  const SizedBox(height: 14),
                  alerts,
                  const SizedBox(height: 14),
                  _CashConcentrationCard(
                    rubricRows: rubricRows,
                    conceptRows: conceptRows,
                    subconceptRows: subconceptRows,
                    personRows: personRows,
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 8, child: breakdowns),
                const SizedBox(width: 14),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      alerts,
                      const SizedBox(height: 14),
                      _CashConcentrationCard(
                        rubricRows: rubricRows,
                        conceptRows: conceptRows,
                        subconceptRows: subconceptRows,
                        personRows: personRows,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  MenudeoCashTimelinePoint? _resolveTimelineSelection(
    List<MenudeoCashTimelinePoint> timeline,
  ) {
    if (timeline.isEmpty) return null;
    if (_selectedCashDate == null) return timeline.last;
    for (final point in timeline) {
      if (_sameDate(point.date, _selectedCashDate!)) return point;
    }
    return timeline.last;
  }

  MenudeoCashLogisticsRow? _resolveUnitSelection(
    List<MenudeoCashLogisticsRow> rows,
  ) {
    if (rows.isEmpty) return null;
    if (_selectedUnitLabel == null) return rows.first;
    for (final row in rows) {
      if (row.label == _selectedUnitLabel) return row;
    }
    return rows.first;
  }

  bool _sameDate(DateTime? left, DateTime right) {
    if (left == null) return false;
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class _CashFiltersBar extends StatelessWidget {
  final MenudeoAnalysisState state;
  final MenudeoCashMovementFilter movement;
  final String? rubric;
  final String? person;
  final List<String> rubrics;
  final List<String> people;
  final ValueChanged<MenudeoCashMovementFilter> onMovementChanged;
  final ValueChanged<String?> onRubricChanged;
  final ValueChanged<String?> onPersonChanged;

  const _CashFiltersBar({
    required this.state,
    required this.movement,
    required this.rubric,
    required this.person,
    required this.rubrics,
    required this.people,
    required this.onMovementChanged,
    required this.onRubricChanged,
    required this.onPersonChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DirectionToolbarPanel(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _CashDateRangeButton(
            label: 'Ventana',
            range: state.filters.dateRange,
            onTap: () => _openDateRange(context),
          ),
          _CashDropdown<MenudeoCashMovementFilter>(
            label: 'Movimiento',
            width: 150,
            value: movement,
            items: MenudeoCashMovementFilter.values,
            itemLabel: (value) =>
                value == null ? 'Ambos' : menudeoCashMovementLabel(value),
            onChanged: (value) {
              if (value != null) onMovementChanged(value);
            },
          ),
          _CashDropdown<String?>(
            label: 'Rubro',
            width: 220,
            value: rubric,
            items: <String?>[null, ...rubrics],
            itemLabel: (value) => value ?? 'Todos',
            onChanged: onRubricChanged,
          ),
          _CashDropdown<String?>(
            label: 'Persona',
            width: 220,
            value: person,
            items: <String?>[null, ...people],
            itemLabel: (value) => value ?? 'Todas',
            onChanged: onPersonChanged,
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
      tokens: directionAreaTokens,
    );
    if (result == null) return;
    if (result.clear) {
      state.setDateRange(null);
      return;
    }
    state.setDateRange(result.range);
  }
}

class _CashDateRangeButton extends StatelessWidget {
  final String label;
  final DateTimeRange? range;
  final VoidCallback onTap;

  const _CashDateRangeButton({
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
            color: kDirectionInteractiveSurfaceStrong.withValues(alpha: 0.82),
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
                          : _formatCashDateRange(range!),
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

class _CashDropdown<T> extends StatelessWidget {
  final String label;
  final double width;
  final T? value;
  final List<T?> items;
  final String Function(T? value) itemLabel;
  final ValueChanged<T?> onChanged;

  const _CashDropdown({
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
        dropdownColor: kDirectionMenuSurface,
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
          fillColor: kDirectionInteractiveSurfaceStrong.withValues(alpha: 0.82),
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

class _CashBreakdownCard extends StatelessWidget {
  final List<MenudeoCashBreakdownRow> rubricRows;
  final List<MenudeoCashBreakdownRow> conceptRows;
  final List<MenudeoCashBreakdownRow> subconceptRows;
  final List<MenudeoCashBreakdownRow> personRows;

  const _CashBreakdownCard({
    required this.rubricRows,
    required this.conceptRows,
    required this.subconceptRows,
    required this.personRows,
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
            'Mapa de efectivo',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Desglose real por rubro, concepto, subconcepto y persona con base en vouchers y líneas capturadas.',
            style: TextStyle(
              color: kDirectionMutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _CashBreakdownSection(
            title: 'Rubros',
            rows: rubricRows.take(6).toList(growable: false),
            color: kDirectionOliveGlow,
          ),
          const SizedBox(height: 16),
          _CashBreakdownSection(
            title: 'Conceptos',
            rows: conceptRows.take(6).toList(growable: false),
            color: const Color(0xFF66F0DC),
          ),
          const SizedBox(height: 16),
          _CashBreakdownSection(
            title: 'Subconceptos',
            rows: subconceptRows.take(6).toList(growable: false),
            color: kDirectionOliveMist,
          ),
          const SizedBox(height: 16),
          _CashBreakdownSection(
            title: 'Personas',
            rows: personRows.take(6).toList(growable: false),
            color: const Color(0xFFFFC86B),
          ),
        ],
      ),
    );
  }
}

class _CashInsightsCard extends StatelessWidget {
  final List<MenudeoCashBreakdownRow> rubricRows;
  final List<MenudeoCashBreakdownRow> conceptRows;
  final List<MenudeoCashBreakdownRow> subconceptRows;
  final List<MenudeoCashBreakdownRow> personRows;
  final MenudeoCashMovementFilter movement;

  const _CashInsightsCard({
    required this.rubricRows,
    required this.conceptRows,
    required this.subconceptRows,
    required this.personRows,
    required this.movement,
  });

  @override
  Widget build(BuildContext context) {
    final items = _buildCashInsights(
      rubricRows: rubricRows,
      conceptRows: conceptRows,
      subconceptRows: subconceptRows,
      personRows: personRows,
      movement: movement,
    );
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lectura ejecutiva de efectivo',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Resumen accionable de concentración y presión de salida para no depender solo del ranking.',
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
            children: items
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

class _CashFocusedBreakdownsCard extends StatelessWidget {
  final MenudeoCashFocusedBreakdown fuel;
  final MenudeoCashFocusedBreakdown maintenance;
  final MenudeoCashFocusedBreakdown travel;
  final MenudeoCashFocusedBreakdown byUnit;
  final List<MenudeoCashLogisticsRow> unitRows;
  final MenudeoCashLogisticsRow? selectedUnitRow;
  final ValueChanged<MenudeoCashLogisticsRow> onSelectUnit;

  const _CashFocusedBreakdownsCard({
    required this.fuel,
    required this.maintenance,
    required this.travel,
    required this.byUnit,
    required this.unitRows,
    required this.selectedUnitRow,
    required this.onSelectUnit,
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
            'Frentes específicos de gasto',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Totales puntuales para mantenimiento, viajes y combustible, con desglose principal por unidad.',
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
            children: [
              _FocusedExpenseSummaryChip(
                breakdown: maintenance,
                color: const Color(0xFFFFC86B),
              ),
              _FocusedExpenseSummaryChip(
                breakdown: travel,
                color: kDirectionOliveGlow,
              ),
              _FocusedExpenseSummaryChip(
                breakdown: fuel,
                color: const Color(0xFF66F0DC),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _FocusedExpenseStackedUnitChart(
            breakdown: byUnit,
            rows: unitRows,
            selectedRow: selectedUnitRow,
            onSelectRow: onSelectUnit,
          ),
        ],
      ),
    );
  }
}

class _FocusedExpenseStackedUnitChart extends StatelessWidget {
  final MenudeoCashFocusedBreakdown breakdown;
  final List<MenudeoCashLogisticsRow> rows;
  final MenudeoCashLogisticsRow? selectedRow;
  final ValueChanged<MenudeoCashLogisticsRow> onSelectRow;

  const _FocusedExpenseStackedUnitChart({
    required this.breakdown,
    required this.rows,
    required this.selectedRow,
    required this.onSelectRow,
  });

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.take(5).toList(growable: false);
    final maxTotal = visibleRows.isEmpty
        ? 1.0
        : (visibleRows.first.total <= 0 ? 1.0 : visibleRows.first.total);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: kDirectionOliveGlow.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            breakdown.title,
            style: const TextStyle(
              color: kDirectionSurfaceText,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(breakdown.total),
            style: const TextStyle(
              color: kDirectionOliveGlow,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _ExpenseLegendChip(
                label: 'Combustible',
                color: Color(0xFF66F0DC),
              ),
              _ExpenseLegendChip(
                label: 'Mantenimiento',
                color: Color(0xFFFFC86B),
              ),
              _ExpenseLegendChip(label: 'Viajes', color: kDirectionOliveGlow),
            ],
          ),
          const SizedBox(height: 10),
          if (selectedRow != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: kDirectionOliveGlow.withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unidad enfocada: ${selectedRow!.label}',
                    style: const TextStyle(
                      color: kDirectionSurfaceText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Total ${formatMoney(selectedRow!.total)} · ${selectedRow!.count} movimientos',
                    style: const TextStyle(
                      color: kDirectionMutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ExpenseCompositionChip(
                        label: 'Combustible',
                        value: selectedRow!.fuelTotal,
                        color: const Color(0xFF66F0DC),
                      ),
                      _ExpenseCompositionChip(
                        label: 'Mantenimiento',
                        value: selectedRow!.maintenanceTotal,
                        color: const Color(0xFFFFC86B),
                      ),
                      _ExpenseCompositionChip(
                        label: 'Viajes',
                        value: selectedRow!.travelTotal,
                        color: kDirectionOliveGlow,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (visibleRows.isEmpty)
            const Text(
              'Sin movimientos en este corte.',
              style: TextStyle(color: kDirectionMutedText),
            )
          else
            Column(
              children: visibleRows
                  .map((row) {
                    final isSelected = selectedRow?.label == row.label;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onSelectRow(row),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: isSelected
                                ? const Color(
                                    0xFFD8E38A,
                                  ).withValues(alpha: 0.10)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(
                                      0xFFD8E38A,
                                    ).withValues(alpha: 0.32)
                                  : Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      row.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: kDirectionSurfaceText,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatMoney(row.total),
                                    style: const TextStyle(
                                      color: kDirectionSurfaceText,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: SizedBox(
                                        height: 14,
                                        child: Stack(
                                          children: [
                                            Container(
                                              color: Colors.white.withValues(
                                                alpha: 0.06,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                if (row.total > 0 &&
                                                    row.fuelTotal > 0)
                                                  Flexible(
                                                    flex: _segmentFlex(
                                                      row.fuelTotal,
                                                      row.total,
                                                    ),
                                                    child: Container(
                                                      color: const Color(
                                                        0xFF66F0DC,
                                                      ),
                                                    ),
                                                  ),
                                                if (row.total > 0 &&
                                                    row.maintenanceTotal > 0)
                                                  Flexible(
                                                    flex: _segmentFlex(
                                                      row.maintenanceTotal,
                                                      row.total,
                                                    ),
                                                    child: Container(
                                                      color: const Color(
                                                        0xFFFFC86B,
                                                      ),
                                                    ),
                                                  ),
                                                if (row.total > 0 &&
                                                    row.travelTotal > 0)
                                                  Flexible(
                                                    flex: _segmentFlex(
                                                      row.travelTotal,
                                                      row.total,
                                                    ),
                                                    child: Container(
                                                      color: const Color(
                                                        0xFFD8E38A,
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
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 52,
                                    child: Text(
                                      _percentOf(row.total, maxTotal),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        color: kDirectionMutedText,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _ExpenseCompositionChip(
                                    label: 'Combustible',
                                    value: row.fuelTotal,
                                    color: const Color(0xFF66F0DC),
                                  ),
                                  _ExpenseCompositionChip(
                                    label: 'Mantenimiento',
                                    value: row.maintenanceTotal,
                                    color: const Color(0xFFFFC86B),
                                  ),
                                  _ExpenseCompositionChip(
                                    label: 'Viajes',
                                    value: row.travelTotal,
                                    color: kDirectionOliveGlow,
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
      ),
    );
  }

  int _segmentFlex(double value, double total) {
    if (total <= 0 || value <= 0) return 1;
    return ((value / total) * 1000).round().clamp(1, 1000);
  }

  String _percentOf(double value, double total) {
    if (total <= 0 || value <= 0) return '0%';
    return '${((value / total) * 100).toStringAsFixed(0)}%';
  }
}

class _ExpenseLegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ExpenseLegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseCompositionChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ExpenseCompositionChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (value <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        '$label ${formatMoney(value)}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _CashTimelineCard extends StatelessWidget {
  final MenudeoCashMovementFilter movement;
  final List<MenudeoCashTimelinePoint> timeline;
  final MenudeoCashTimelinePoint? selectedPoint;
  final ValueChanged<MenudeoCashTimelinePoint> onSelectPoint;

  const _CashTimelineCard({
    required this.movement,
    required this.timeline,
    required this.selectedPoint,
    required this.onSelectPoint,
  });

  @override
  Widget build(BuildContext context) {
    final points = timeline.take(18).toList(growable: false);
    final maxValue = points.fold<double>(
      1,
      (max, point) => [
        max,
        point.deposits.abs(),
        point.expenses.abs(),
        point.net.abs(),
      ].reduce((a, b) => a > b ? a : b),
    );
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tendencia de efectivo',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            movement == MenudeoCashMovementFilter.deposits
                ? 'Lectura temporal de depósitos analizados por fecha.'
                : movement == MenudeoCashMovementFilter.expenses
                ? 'Lectura temporal de gastos analizados por fecha.'
                : 'Comparativo temporal de depósitos, gastos y neto analizado.',
            style: const TextStyle(
              color: kDirectionMutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (selectedPoint != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  Text(
                    'Fecha enfocada: ${_formatTimelineLongDate(selectedPoint!.date)}',
                    style: const TextStyle(
                      color: kDirectionSurfaceText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  _TimelineInfoPill(
                    label: 'Depósitos',
                    value: formatMoney(selectedPoint!.deposits),
                    color: const Color(0xFF66F0DC),
                  ),
                  _TimelineInfoPill(
                    label: 'Gastos',
                    value: formatMoney(selectedPoint!.expenses),
                    color: const Color(0xFFFFC86B),
                  ),
                  _TimelineInfoPill(
                    label: 'Neto',
                    value: formatMoney(selectedPoint!.net),
                    color: selectedPoint!.net >= 0
                        ? kDirectionOliveGlow
                        : const Color(0xFFFF9A8B),
                  ),
                ],
              ),
            ),
          const _TimelineLegend(),
          const SizedBox(height: 12),
          if (points.isEmpty)
            const Text(
              'Sin movimiento suficiente en la ventana seleccionada.',
              style: TextStyle(color: kDirectionMutedText),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TimelineAxis(maxValue: maxValue),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: points
                          .map(
                            (point) => Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: _TimelineDayColumn(
                                point: point,
                                maxValue: maxValue,
                                movement: movement,
                                selected:
                                    selectedPoint != null &&
                                    _sameTimelineDate(
                                      selectedPoint!.date,
                                      point.date,
                                    ),
                                onTap: () => onSelectPoint(point),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TimelineDayColumn extends StatelessWidget {
  final MenudeoCashTimelinePoint point;
  final double maxValue;
  final MenudeoCashMovementFilter movement;
  final bool selected;
  final VoidCallback onTap;

  const _TimelineDayColumn({
    required this.point,
    required this.maxValue,
    required this.movement,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showDeposits = movement != MenudeoCashMovementFilter.expenses;
    final showExpenses = movement != MenudeoCashMovementFilter.deposits;
    final showNet = movement == MenudeoCashMovementFilter.all;
    return Tooltip(
      message:
          '${_formatTimelineLongDate(point.date)}\nDepósitos ${formatMoney(point.deposits)}\nGastos ${formatMoney(point.expenses)}\nNeto ${formatMoney(point.net)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 72,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? kDirectionOliveGlow.withValues(alpha: 0.30)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 156,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (showDeposits)
                      _TimelineBar(
                        value: point.deposits,
                        maxValue: maxValue,
                        color: const Color(0xFF66F0DC),
                      ),
                    if (showDeposits && (showExpenses || showNet))
                      const SizedBox(width: 4),
                    if (showExpenses)
                      _TimelineBar(
                        value: point.expenses,
                        maxValue: maxValue,
                        color: const Color(0xFFFFC86B),
                      ),
                    if (showExpenses && showNet) const SizedBox(width: 4),
                    if (showNet)
                      _TimelineBar(
                        value: point.net.abs(),
                        maxValue: maxValue,
                        color: point.net >= 0
                            ? kDirectionOliveGlow
                            : const Color(0xFFFF9A8B),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _formatTimelineDate(point.date),
                style: TextStyle(
                  color: selected ? kDirectionSurfaceText : kDirectionMutedText,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineBar extends StatelessWidget {
  final double value;
  final double maxValue;
  final Color color;

  const _TimelineBar({
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final height = ((value / safeMax) * 132).clamp(8, 132).toDouble();
    return Container(
      width: 14,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.96),
            color.withValues(alpha: 0.38),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _TimelineLegend extends StatelessWidget {
  const _TimelineLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _TimelineInfoPill(
          label: 'Depósitos',
          value: 'Entrada',
          color: Color(0xFF66F0DC),
        ),
        _TimelineInfoPill(
          label: 'Gastos',
          value: 'Salida',
          color: Color(0xFFFFC86B),
        ),
        _TimelineInfoPill(
          label: 'Neto',
          value: 'Balance',
          color: kDirectionOliveGlow,
        ),
      ],
    );
  }
}

class _TimelineInfoPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TimelineInfoPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        '$label · $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _TimelineAxis extends StatelessWidget {
  final double maxValue;

  const _TimelineAxis({required this.maxValue});

  @override
  Widget build(BuildContext context) {
    final midValue = maxValue / 2;
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          _TimelineAxisLabel(value: formatMoney(maxValue)),
          const SizedBox(height: 53),
          _TimelineAxisLabel(value: formatMoney(midValue)),
          const SizedBox(height: 53),
          const _TimelineAxisLabel(value: '\$0'),
        ],
      ),
    );
  }
}

class _TimelineAxisLabel extends StatelessWidget {
  final String value;

  const _TimelineAxisLabel({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: kDirectionMutedText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 8,
          height: 1,
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ],
    );
  }
}

String _formatTimelineDate(DateTime date) {
  const months = <int, String>{
    1: 'ene',
    2: 'feb',
    3: 'mar',
    4: 'abr',
    5: 'may',
    6: 'jun',
    7: 'jul',
    8: 'ago',
    9: 'sep',
    10: 'oct',
    11: 'nov',
    12: 'dic',
  };
  final month = months[date.month] ?? '';
  return '${date.day.toString().padLeft(2, '0')} $month';
}

String _formatTimelineLongDate(DateTime date) {
  const months = <int, String>{
    1: 'enero',
    2: 'febrero',
    3: 'marzo',
    4: 'abril',
    5: 'mayo',
    6: 'junio',
    7: 'julio',
    8: 'agosto',
    9: 'septiembre',
    10: 'octubre',
    11: 'noviembre',
    12: 'diciembre',
  };
  final month = months[date.month] ?? '';
  return '${date.day} de $month';
}

bool _sameTimelineDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

class _FocusedExpenseSummaryChip extends StatelessWidget {
  final MenudeoCashFocusedBreakdown breakdown;
  final Color color;

  const _FocusedExpenseSummaryChip({
    required this.breakdown,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            breakdown.title,
            style: const TextStyle(
              color: kDirectionSurfaceText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(breakdown.total),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashConcentrationCard extends StatelessWidget {
  final List<MenudeoCashBreakdownRow> rubricRows;
  final List<MenudeoCashBreakdownRow> conceptRows;
  final List<MenudeoCashBreakdownRow> subconceptRows;
  final List<MenudeoCashBreakdownRow> personRows;

  const _CashConcentrationCard({
    required this.rubricRows,
    required this.conceptRows,
    required this.subconceptRows,
    required this.personRows,
  });

  @override
  Widget build(BuildContext context) {
    final lanes = <_CashConcentrationLane>[
      _CashConcentrationLane(
        title: 'Rubro líder',
        row: rubricRows.isEmpty ? null : rubricRows.first,
        color: kDirectionOliveGlow,
      ),
      _CashConcentrationLane(
        title: 'Concepto líder',
        row: conceptRows.isEmpty ? null : conceptRows.first,
        color: const Color(0xFF66F0DC),
      ),
      _CashConcentrationLane(
        title: 'Subconcepto líder',
        row: subconceptRows.isEmpty ? null : subconceptRows.first,
        color: kDirectionOliveMist,
      ),
      _CashConcentrationLane(
        title: 'Persona líder',
        row: personRows.isEmpty ? null : personRows.first,
        color: const Color(0xFFFFC86B),
      ),
    ];
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Concentración de efectivo',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Lectura rápida de dónde se está acumulando la salida analizada.',
            style: TextStyle(
              color: kDirectionMutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ...lanes.map((lane) => lane),
        ],
      ),
    );
  }
}

class _CashConcentrationLane extends StatelessWidget {
  final String title;
  final MenudeoCashBreakdownRow? row;
  final Color color;

  const _CashConcentrationLane({
    required this.title,
    required this.row,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final current = row;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kDirectionSurfaceText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          if (current == null)
            const Text(
              'Sin datos para este corte.',
              style: TextStyle(color: kDirectionMutedText),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    current.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kDirectionSurfaceText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(current.share * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: kDirectionSurfaceText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: current.share.clamp(0, 1),
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CashBreakdownSection extends StatelessWidget {
  final String title;
  final List<MenudeoCashBreakdownRow> rows;
  final Color color;

  const _CashBreakdownSection({
    required this.title,
    required this.rows,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final maxTotal = rows.isEmpty
        ? 1.0
        : rows.first.total <= 0
        ? 1.0
        : rows.first.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: kDirectionSurfaceText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const Text(
            'Sin datos para este corte.',
            style: TextStyle(color: kDirectionMutedText),
          )
        else
          Column(
            children: rows
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                row.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: kDirectionSurfaceText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              formatMoney(row.total),
                              style: const TextStyle(
                                color: kDirectionSurfaceText,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value: (row.total / maxTotal).clamp(0, 1),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _CashAlertsCard extends StatelessWidget {
  final List<MenudeoCashAlert> alerts;

  const _CashAlertsCard({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alertas de efectivo',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            const Text(
              'No hay alertas para el periodo actual.',
              style: TextStyle(color: kDirectionMutedText),
            )
          else
            Column(
              children: alerts
                  .map(
                    (alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: double.infinity,
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
                              style: const TextStyle(
                                color: kDirectionSurfaceText,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              alert.detail,
                              style: const TextStyle(
                                color: kDirectionMutedText,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
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

class _CashInsightItem {
  final String title;
  final String detail;
  final Color color;

  const _CashInsightItem({
    required this.title,
    required this.detail,
    required this.color,
  });
}

List<_CashInsightItem> _buildCashInsights({
  required List<MenudeoCashBreakdownRow> rubricRows,
  required List<MenudeoCashBreakdownRow> conceptRows,
  required List<MenudeoCashBreakdownRow> subconceptRows,
  required List<MenudeoCashBreakdownRow> personRows,
  required MenudeoCashMovementFilter movement,
}) {
  final items = <_CashInsightItem>[];
  if (rubricRows.isNotEmpty) {
    items.add(
      _CashInsightItem(
        title: 'Rubro dominante',
        detail:
            '${rubricRows.first.label} concentra ${(rubricRows.first.share * 100).toStringAsFixed(1)}% del flujo analizado en ${movement == MenudeoCashMovementFilter.deposits
                ? 'depósitos'
                : movement == MenudeoCashMovementFilter.expenses
                ? 'gastos'
                : 'movimientos'} .',
        color: kDirectionOliveGlow,
      ),
    );
  }
  if (conceptRows.isNotEmpty) {
    items.add(
      _CashInsightItem(
        title: 'Concepto que más pesa',
        detail:
            '${conceptRows.first.label} suma ${formatMoney(conceptRows.first.total)} y aparece ${conceptRows.first.count} veces en el periodo.',
        color: const Color(0xFF66F0DC),
      ),
    );
  }
  if (subconceptRows.isNotEmpty) {
    items.add(
      _CashInsightItem(
        title: 'Subconcepto a vigilar',
        detail:
            '${subconceptRows.first.label} ya representa ${(subconceptRows.first.share * 100).toStringAsFixed(1)}% del efectivo depurado.',
        color: kDirectionOliveMist,
      ),
    );
  }
  if (personRows.isNotEmpty) {
    items.add(
      _CashInsightItem(
        title: 'Concentración por persona',
        detail:
            '${personRows.first.label} acumula ${formatMoney(personRows.first.total)} en ${personRows.first.count} movimientos.',
        color: const Color(0xFFFFC86B),
      ),
    );
  }
  if (items.isEmpty) {
    items.add(
      const _CashInsightItem(
        title: 'Sin hallazgos fuertes',
        detail:
            'Con los filtros actuales no hay concentración suficiente para disparar una lectura ejecutiva relevante.',
        color: kDirectionOliveGlow,
      ),
    );
  }
  return items.take(4).toList(growable: false);
}

String _formatCashDateRange(DateTimeRange range) {
  final startDay = range.start.day.toString().padLeft(2, '0');
  final startMonth = range.start.month.toString().padLeft(2, '0');
  final endDay = range.end.day.toString().padLeft(2, '0');
  final endMonth = range.end.month.toString().padLeft(2, '0');
  return '$startDay/$startMonth/${range.start.year} - $endDay/$endMonth/${range.end.year}';
}
