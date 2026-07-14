import 'package:flutter/material.dart';

import '../../../menudeo/menudeo_filter_widgets.dart';
import '../../../shared/utils/number_formatters.dart';
import '../../direction_theme.dart';
import 'menudeo_analysis_models.dart';
import 'menudeo_analysis_state.dart';

class MenudeoOperationsTab extends StatefulWidget {
  final MenudeoAnalysisState state;

  const MenudeoOperationsTab({super.key, required this.state});

  @override
  State<MenudeoOperationsTab> createState() => _MenudeoOperationsTabState();
}

class _MenudeoOperationsTabState extends State<MenudeoOperationsTab> {
  MenudeoAnalysisFlow _flow = MenudeoAnalysisFlow.all;
  String? _material;
  String? _counterparty;
  DateTime? _selectedOperationDate;

  @override
  Widget build(BuildContext context) {
    final dataset = widget.state.operationDataset;
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
          'No se pudo cargar el análisis de operación: ${widget.state.error}',
          style: const TextStyle(
            color: kDirectionSurfaceText,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (dataset == null) return const SizedBox.shrink();

    final pendingRows = dataset.pendingRows
        .where((row) {
          if (_flow != MenudeoAnalysisFlow.all && row.flow != _flow) {
            return false;
          }
          if (_material != null && row.material != _material) return false;
          if (_counterparty != null && row.counterparty != _counterparty) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    final materialRows = dataset.materialRows
        .where((row) {
          if (_material != null && row.label != _material) return false;
          return true;
        })
        .toList(growable: false);

    final counterpartyRows = dataset.counterpartyRows
        .where((row) {
          if (_counterparty != null && row.label != _counterparty) return false;
          return true;
        })
        .toList(growable: false);
    final selectedTimelinePoint = _resolveTimelineSelection(dataset.timeline);
    final selectedMaterialRow = _resolveSelectedBreakdown(
      materialRows,
      _material,
    );
    final selectedCounterpartyRow = _resolveSelectedBreakdown(
      counterpartyRows,
      _counterparty,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OperationsFiltersBar(
          state: widget.state,
          flow: _flow,
          material: _material,
          counterparty: _counterparty,
          materials: dataset.materials,
          counterparties: dataset.counterparties,
          onFlowChanged: (value) => setState(() => _flow = value),
          onMaterialChanged: (value) => setState(() => _material = value),
          onCounterpartyChanged: (value) =>
              setState(() => _counterparty = value),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            DirectionMetricCard(
              icon: Icons.shopping_cart_checkout_rounded,
              title: 'COMPRAS PAGADAS',
              value: formatMoney(dataset.snapshot.purchaseAmount),
              detail: 'Flujo pagado de compra',
              accent: kDirectionWarning,
            ),
            DirectionMetricCard(
              icon: Icons.point_of_sale_rounded,
              title: 'VENTAS PAGADAS',
              value: formatMoney(dataset.snapshot.saleAmount),
              detail: 'Flujo pagado de venta',
              accent: kDirectionSuccess,
            ),
            DirectionMetricCard(
              icon: Icons.swap_vert_circle_rounded,
              title: 'FLUJO COMERCIAL',
              value: formatMoney(dataset.snapshot.netCommercialFlow),
              detail: 'Ventas menos compras',
              accent: kDirectionOliveMist,
            ),
            DirectionMetricCard(
              icon: Icons.fact_check_rounded,
              title: 'CONTROL OPERATIVO',
              value:
                  '${dataset.snapshot.paidTickets} pagados · ${dataset.snapshot.pendingTickets} pendientes',
              detail:
                  '${dataset.snapshot.pendingChecks} checks con observación en cortes',
              accent: kDirectionDanger,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _OperationTimelineCard(
          flow: _flow,
          timeline: dataset.timeline,
          selectedPoint: selectedTimelinePoint,
          onSelectPoint: (point) {
            setState(() {
              _selectedOperationDate =
                  _sameDate(_selectedOperationDate, point.date)
                  ? null
                  : point.date;
            });
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 1180;
            final mix = _OperationMixCard(
              materialRows: materialRows,
              counterpartyRows: counterpartyRows,
              selectedMaterialRow: selectedMaterialRow,
              selectedCounterpartyRow: selectedCounterpartyRow,
              onSelectMaterial: (row) {
                setState(() {
                  _material = _material == row.label ? null : row.label;
                });
              },
              onSelectCounterparty: (row) {
                setState(() {
                  _counterparty = _counterparty == row.label ? null : row.label;
                });
              },
            );
            final alerts = _OperationAlertsCard(alerts: dataset.alerts);
            if (stacked) {
              return Column(
                children: [mix, const SizedBox(height: 14), alerts],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 8, child: mix),
                const SizedBox(width: 14),
                Expanded(flex: 4, child: alerts),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _PendingTicketsCard(rows: pendingRows),
      ],
    );
  }

  MenudeoOperationTimelinePoint? _resolveTimelineSelection(
    List<MenudeoOperationTimelinePoint> timeline,
  ) {
    if (timeline.isEmpty) return null;
    if (_selectedOperationDate == null) return timeline.last;
    for (final point in timeline) {
      if (_sameDate(point.date, _selectedOperationDate!)) return point;
    }
    return timeline.last;
  }

  MenudeoOperationBreakdownRow? _resolveSelectedBreakdown(
    List<MenudeoOperationBreakdownRow> rows,
    String? selectedLabel,
  ) {
    if (rows.isEmpty) return null;
    if (selectedLabel == null) return rows.first;
    for (final row in rows) {
      if (row.label == selectedLabel) return row;
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

class _OperationsFiltersBar extends StatelessWidget {
  final MenudeoAnalysisState state;
  final MenudeoAnalysisFlow flow;
  final String? material;
  final String? counterparty;
  final List<String> materials;
  final List<String> counterparties;
  final ValueChanged<MenudeoAnalysisFlow> onFlowChanged;
  final ValueChanged<String?> onMaterialChanged;
  final ValueChanged<String?> onCounterpartyChanged;

  const _OperationsFiltersBar({
    required this.state,
    required this.flow,
    required this.material,
    required this.counterparty,
    required this.materials,
    required this.counterparties,
    required this.onFlowChanged,
    required this.onMaterialChanged,
    required this.onCounterpartyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DirectionToolbarPanel(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _OperationsDateRangeButton(
            label: 'Ventana',
            range: state.filters.dateRange,
            onTap: () => _openDateRange(context),
          ),
          _OperationsDropdown<MenudeoAnalysisFlow>(
            label: 'Flujo',
            width: 160,
            value: flow,
            items: MenudeoAnalysisFlow.values,
            itemLabel: (value) =>
                value == null ? 'Ambos' : menudeoFlowLabel(value),
            onChanged: (value) {
              if (value != null) onFlowChanged(value);
            },
          ),
          _OperationsDropdown<String?>(
            label: 'Material',
            width: 220,
            value: material,
            items: <String?>[null, ...materials],
            itemLabel: (value) => value ?? 'Todos',
            onChanged: onMaterialChanged,
          ),
          _OperationsDropdown<String?>(
            label: 'Contraparte',
            width: 240,
            value: counterparty,
            items: <String?>[null, ...counterparties],
            itemLabel: (value) => value ?? 'Todas',
            onChanged: onCounterpartyChanged,
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

class _OperationsDateRangeButton extends StatelessWidget {
  final String label;
  final DateTimeRange? range;
  final VoidCallback onTap;

  const _OperationsDateRangeButton({
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
                          : _formatOperationDateRange(range!),
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

class _OperationsDropdown<T> extends StatelessWidget {
  final String label;
  final double width;
  final T? value;
  final List<T?> items;
  final String Function(T? value) itemLabel;
  final ValueChanged<T?> onChanged;

  const _OperationsDropdown({
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

class _OperationMixCard extends StatelessWidget {
  final List<MenudeoOperationBreakdownRow> materialRows;
  final List<MenudeoOperationBreakdownRow> counterpartyRows;
  final MenudeoOperationBreakdownRow? selectedMaterialRow;
  final MenudeoOperationBreakdownRow? selectedCounterpartyRow;
  final ValueChanged<MenudeoOperationBreakdownRow> onSelectMaterial;
  final ValueChanged<MenudeoOperationBreakdownRow> onSelectCounterparty;

  const _OperationMixCard({
    required this.materialRows,
    required this.counterpartyRows,
    required this.selectedMaterialRow,
    required this.selectedCounterpartyRow,
    required this.onSelectMaterial,
    required this.onSelectCounterparty,
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
            'Mix operativo',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Lectura inicial de materiales y contrapartes con tickets pagados dentro de la ventana analizada.',
            style: TextStyle(
              color: kDirectionMutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _OperationFocusSummary(
            materialRow: selectedMaterialRow,
            counterpartyRow: selectedCounterpartyRow,
          ),
          const SizedBox(height: 16),
          _OperationBreakdownSection(
            title: 'Materiales',
            rows: materialRows.take(6).toList(growable: false),
            color: kDirectionOliveGlow,
            selectedRow: selectedMaterialRow,
            onSelectRow: onSelectMaterial,
          ),
          const SizedBox(height: 16),
          _OperationBreakdownSection(
            title: 'Contrapartes',
            rows: counterpartyRows.take(6).toList(growable: false),
            color: const Color(0xFF66F0DC),
            selectedRow: selectedCounterpartyRow,
            onSelectRow: onSelectCounterparty,
          ),
        ],
      ),
    );
  }
}

class _OperationFocusSummary extends StatelessWidget {
  final MenudeoOperationBreakdownRow? materialRow;
  final MenudeoOperationBreakdownRow? counterpartyRow;

  const _OperationFocusSummary({
    required this.materialRow,
    required this.counterpartyRow,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (materialRow != null)
          _OperationFocusPill(
            title: 'Material enfocado',
            label: materialRow!.label,
            amount: materialRow!.amount,
            weight: materialRow!.weight,
            count: materialRow!.count,
            color: kDirectionOliveGlow,
          ),
        if (counterpartyRow != null)
          _OperationFocusPill(
            title: 'Contraparte enfocada',
            label: counterpartyRow!.label,
            amount: counterpartyRow!.amount,
            weight: counterpartyRow!.weight,
            count: counterpartyRow!.count,
            color: const Color(0xFF66F0DC),
          ),
      ],
    );
  }
}

class _OperationFocusPill extends StatelessWidget {
  final String title;
  final String label;
  final double amount;
  final double weight;
  final int count;
  final Color color;

  const _OperationFocusPill({
    required this.title,
    required this.label,
    required this.amount,
    required this.weight,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kDirectionMutedText,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kDirectionSurfaceText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatMoney(amount)} · ${weight.toStringAsFixed(0)} kg · $count tickets',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationBreakdownSection extends StatelessWidget {
  final String title;
  final List<MenudeoOperationBreakdownRow> rows;
  final Color color;
  final MenudeoOperationBreakdownRow? selectedRow;
  final ValueChanged<MenudeoOperationBreakdownRow> onSelectRow;

  const _OperationBreakdownSection({
    required this.title,
    required this.rows,
    required this.color,
    required this.selectedRow,
    required this.onSelectRow,
  });

  @override
  Widget build(BuildContext context) {
    final maxAmount = rows.isEmpty
        ? 1.0
        : (rows.first.amount <= 0 ? 1.0 : rows.first.amount);
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
                .map((row) {
                  final isSelected = selectedRow?.label == row.label;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onSelectRow(row),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isSelected
                              ? color.withValues(alpha: 0.10)
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? color.withValues(alpha: 0.30)
                                : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
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
                                  formatMoney(row.amount),
                                  style: const TextStyle(
                                    color: kDirectionSurfaceText,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '${row.count} tickets',
                                  style: const TextStyle(
                                    color: kDirectionMutedText,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${row.weight.toStringAsFixed(0)} kg',
                                  style: const TextStyle(
                                    color: kDirectionMutedText,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 10,
                                value: (row.amount / maxAmount).clamp(0, 1),
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.08,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  color,
                                ),
                              ),
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

class _OperationTimelineCard extends StatelessWidget {
  final MenudeoAnalysisFlow flow;
  final List<MenudeoOperationTimelinePoint> timeline;
  final MenudeoOperationTimelinePoint? selectedPoint;
  final ValueChanged<MenudeoOperationTimelinePoint> onSelectPoint;

  const _OperationTimelineCard({
    required this.flow,
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
        point.purchaseAmount.abs(),
        point.saleAmount.abs(),
        point.netAmount.abs(),
      ].reduce((a, b) => a > b ? a : b),
    );
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tendencia operativa',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            flow == MenudeoAnalysisFlow.purchase
                ? 'Lectura temporal de compras pagadas por fecha.'
                : flow == MenudeoAnalysisFlow.sale
                ? 'Lectura temporal de ventas pagadas por fecha.'
                : 'Comparativo temporal de compras, ventas y flujo comercial neto.',
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
                    'Fecha enfocada: ${_formatOperationLongDate(selectedPoint!.date)}',
                    style: const TextStyle(
                      color: kDirectionSurfaceText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  _OperationLegendPill(
                    label: 'Compras',
                    value: formatMoney(selectedPoint!.purchaseAmount),
                    color: const Color(0xFFFFC86B),
                  ),
                  _OperationLegendPill(
                    label: 'Ventas',
                    value: formatMoney(selectedPoint!.saleAmount),
                    color: const Color(0xFF66F0DC),
                  ),
                  _OperationLegendPill(
                    label: 'Neto',
                    value: formatMoney(selectedPoint!.netAmount),
                    color: selectedPoint!.netAmount >= 0
                        ? kDirectionOliveGlow
                        : const Color(0xFFFF9A8B),
                  ),
                ],
              ),
            ),
          const _OperationLegend(),
          const SizedBox(height: 12),
          if (points.isEmpty)
            const Text(
              'Sin flujo operativo pagado en la ventana seleccionada.',
              style: TextStyle(color: kDirectionMutedText),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OperationAxis(maxValue: maxValue),
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
                              child: _OperationDayColumn(
                                point: point,
                                maxValue: maxValue,
                                flow: flow,
                                selected:
                                    selectedPoint != null &&
                                    _sameOperationDate(
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

class _OperationDayColumn extends StatelessWidget {
  final MenudeoOperationTimelinePoint point;
  final double maxValue;
  final MenudeoAnalysisFlow flow;
  final bool selected;
  final VoidCallback onTap;

  const _OperationDayColumn({
    required this.point,
    required this.maxValue,
    required this.flow,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showPurchase = flow != MenudeoAnalysisFlow.sale;
    final showSale = flow != MenudeoAnalysisFlow.purchase;
    final showNet = flow == MenudeoAnalysisFlow.all;
    return Tooltip(
      message:
          '${_formatOperationLongDate(point.date)}\nCompras ${formatMoney(point.purchaseAmount)}\nVentas ${formatMoney(point.saleAmount)}\nNeto ${formatMoney(point.netAmount)}\n${point.paidTickets} tickets',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 76,
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
            children: [
              SizedBox(
                height: 156,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (showPurchase)
                      _OperationBar(
                        value: point.purchaseAmount,
                        maxValue: maxValue,
                        color: const Color(0xFFFFC86B),
                      ),
                    if (showPurchase && (showSale || showNet))
                      const SizedBox(width: 4),
                    if (showSale)
                      _OperationBar(
                        value: point.saleAmount,
                        maxValue: maxValue,
                        color: const Color(0xFF66F0DC),
                      ),
                    if (showSale && showNet) const SizedBox(width: 4),
                    if (showNet)
                      _OperationBar(
                        value: point.netAmount.abs(),
                        maxValue: maxValue,
                        color: point.netAmount >= 0
                            ? kDirectionOliveGlow
                            : const Color(0xFFFF9A8B),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _formatOperationDate(point.date),
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

class _OperationBar extends StatelessWidget {
  final double value;
  final double maxValue;
  final Color color;

  const _OperationBar({
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

class _OperationLegend extends StatelessWidget {
  const _OperationLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _OperationLegendPill(
          label: 'Compras',
          value: 'Pagado',
          color: Color(0xFFFFC86B),
        ),
        _OperationLegendPill(
          label: 'Ventas',
          value: 'Pagado',
          color: Color(0xFF66F0DC),
        ),
        _OperationLegendPill(
          label: 'Neto',
          value: 'Flujo',
          color: kDirectionOliveGlow,
        ),
      ],
    );
  }
}

class _OperationLegendPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _OperationLegendPill({
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

class _OperationAxis extends StatelessWidget {
  final double maxValue;

  const _OperationAxis({required this.maxValue});

  @override
  Widget build(BuildContext context) {
    final midValue = maxValue / 2;
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          _OperationAxisLabel(value: formatMoney(maxValue)),
          const SizedBox(height: 53),
          _OperationAxisLabel(value: formatMoney(midValue)),
          const SizedBox(height: 53),
          const _OperationAxisLabel(value: '\$0'),
        ],
      ),
    );
  }
}

class _OperationAxisLabel extends StatelessWidget {
  final String value;

  const _OperationAxisLabel({required this.value});

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

class _OperationAlertsCard extends StatelessWidget {
  final List<MenudeoOperationAlert> alerts;

  const _OperationAlertsCard({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alertas operativas',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            const Text(
              'Sin alertas relevantes en la ventana actual.',
              style: TextStyle(color: kDirectionMutedText),
            )
          else
            Column(
              children: alerts
                  .map((alert) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                            color: _severityColor(
                              alert.severity,
                            ).withValues(alpha: 0.42),
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
                                height: 1.35,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
}

class _PendingTicketsCard extends StatelessWidget {
  final List<MenudeoPendingTicketRow> rows;

  const _PendingTicketsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pendientes y riesgo',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tickets que siguen abiertos o en conciliación dentro de la ventana activa.',
            style: TextStyle(
              color: kDirectionMutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            const Text(
              'No hay tickets pendientes en este corte.',
              style: TextStyle(color: kDirectionMutedText),
            )
          else
            Column(
              children: rows
                  .take(8)
                  .map((row) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: row.flow == MenudeoAnalysisFlow.purchase
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFFFD18A),
                                        Color(0xFFB78231),
                                      ],
                                    )
                                  : const LinearGradient(
                                      colors: [
                                        Color(0xFF8AF6E2),
                                        Color(0xFF2E9F8D),
                                      ],
                                    ),
                            ),
                            child: Text(
                              row.flow == MenudeoAnalysisFlow.purchase
                                  ? 'Compra'
                                  : 'Venta',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ticket ${row.ticketNumber.isEmpty ? row.id : row.ticketNumber}',
                                  style: const TextStyle(
                                    color: kDirectionSurfaceText,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${row.counterparty.isEmpty ? 'Sin contraparte' : row.counterparty} · ${row.material.isEmpty ? 'Sin material' : row.material}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: kDirectionMutedText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatMoney(row.amount),
                                style: const TextStyle(
                                  color: kDirectionSurfaceText,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                row.status,
                                style: TextStyle(
                                  color: _statusColor(row.status),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

Color _severityColor(MenudeoOpportunitySeverity severity) {
  switch (severity) {
    case MenudeoOpportunitySeverity.critical:
      return const Color(0xFFFF8C8C);
    case MenudeoOpportunitySeverity.outOfRange:
      return const Color(0xFFFFC86B);
    case MenudeoOpportunitySeverity.watch:
      return kDirectionOliveGlow;
    case MenudeoOpportunitySeverity.healthy:
    case MenudeoOpportunitySeverity.all:
      return const Color(0xFF66F0DC);
  }
}

Color _statusColor(String status) {
  switch (status.toUpperCase()) {
    case 'PAGADO':
      return const Color(0xFF66F0DC);
    case 'PENDIENTE':
      return const Color(0xFFFFC86B);
    case 'EN_CONCILIACION':
      return const Color(0xFFFF9A8B);
    default:
      return kDirectionMutedText;
  }
}

String _formatOperationDateRange(DateTimeRange range) {
  return '${_formatOperationDate(range.start)} - ${_formatOperationDate(range.end)}';
}

String _formatOperationDate(DateTime date) {
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

String _formatOperationLongDate(DateTime date) {
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

bool _sameOperationDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
