import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/utils/number_formatters.dart';
import 'direction_shipments_store.dart';
import 'direction_shipments_summary.dart';
import 'direction_theme.dart';

class DirectionShipmentsDashboardCard extends StatefulWidget {
  final Future<void> Function(DateTime weekStart) onOpenShipments;
  final DateTime? initialWeekStart;
  final Future<DirectionShipmentsWeeklySummary> Function(DateTime)? loadSummary;

  const DirectionShipmentsDashboardCard({
    super.key,
    required this.onOpenShipments,
    this.initialWeekStart,
    this.loadSummary,
  });

  @override
  State<DirectionShipmentsDashboardCard> createState() =>
      _DirectionShipmentsDashboardCardState();
}

class _DirectionShipmentsDashboardCardState
    extends State<DirectionShipmentsDashboardCard> {
  late DateTime _weekStart;
  late bool _followCurrentWeek;
  DirectionShipmentsWeeklySummary? _summary;
  bool _loading = true;
  bool _refreshing = false;
  bool _pendingReload = false;
  bool _failed = false;
  bool _hovering = false;
  Timer? _timer;
  RealtimeChannel? _channel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final currentWeek = DirectionShipmentsStore.currentWeekStartDate();
    _weekStart = DirectionShipmentsStore.normalizeWeekStartDate(
      widget.initialWeekStart ?? currentWeek,
    );
    _followCurrentWeek = _weekStart == currentWeek;
    _requestReload();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _requestReload(),
    );
    if (widget.loadSummary == null) {
      _channel = Supabase.instance.client
          .channel('direction-dashboard-shipments-${identityHashCode(this)}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'direction_shipment_plans',
            callback: (_) => _requestReload(),
          )
          .subscribe();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _channel?.unsubscribe();
    _scrollController.dispose();
    super.dispose();
  }

  void _requestReload() {
    if (!mounted) return;
    final currentWeek = DirectionShipmentsStore.currentWeekStartDate();
    if (_followCurrentWeek && _weekStart != currentWeek) {
      setState(() {
        _weekStart = currentWeek;
        _summary = null;
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
    final requestedWeek = _weekStart;
    try {
      final summary =
          await (widget.loadSummary ??
              DirectionShipmentsWeeklySummary.loadWeek)(requestedWeek);
      if (!mounted || requestedWeek != _weekStart) return;
      setState(() {
        _summary = summary;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || requestedWeek != _weekStart) return;
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

  void _changeWeek(DateTime date) {
    final next = DirectionShipmentsStore.normalizeWeekStartDate(date);
    if (next == _weekStart) return;
    setState(() {
      _weekStart = next;
      _followCurrentWeek =
          next == DirectionShipmentsStore.currentWeekStartDate();
      _summary = null;
      _loading = true;
      _failed = false;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _requestReload();
  }

  Future<void> _openShipments() async {
    await widget.onOpenShipments(_weekStart);
    _requestReload();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final currentWeek = DirectionShipmentsStore.currentWeekStartDate();
    final isCurrentWeek = _weekStart == currentWeek;
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
                      Icons.local_shipping_rounded,
                      color: kDirectionOliveGlow,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Embarques',
                            style: TextStyle(
                              color: kDirectionSurfaceText,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Planeación semanal · Pacas',
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
                      tooltip: 'Abrir Embarques',
                      onPressed: _openShipments,
                      color: kDirectionOliveGlow,
                      icon: const Icon(Icons.arrow_outward_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _weekButton(
                      'Semana anterior',
                      Icons.chevron_left_rounded,
                      () => _changeWeek(
                        _weekStart.subtract(const Duration(days: 7)),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _weekRange(_weekStart),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: kDirectionSurfaceText,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _weekButton(
                      'Semana siguiente',
                      Icons.chevron_right_rounded,
                      _weekStart.isBefore(currentWeek)
                          ? () => _changeWeek(
                              _weekStart.add(const Duration(days: 7)),
                            )
                          : null,
                    ),
                    _weekButton(
                      'Semana actual',
                      Icons.today_rounded,
                      isCurrentWeek ? null : () => _changeWeek(currentWeek),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ShipmentMetric(
                        label: 'Pacas semana',
                        value: summary?.totalBales,
                        accent: kDirectionOliveGlow,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ShipmentMetric(
                        label: 'Por embarcar',
                        value: summary?.pendingBales,
                        accent: kDirectionWarning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ShipmentMetric(
                        label: 'Embarcadas',
                        value: summary?.shippedBales,
                        accent: kDirectionSuccess,
                      ),
                    ),
                  ],
                ),
                if (_failed && summary != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'No se pudo actualizar. Se muestra el último resumen.',
                      style: TextStyle(color: kDirectionWarning, fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      SizedBox(width: 46, child: _ShipmentColumnLabel('Día')),
                      Expanded(
                        child: _ShipmentColumnLabel('Tipo de paca / Destino'),
                      ),
                      SizedBox(
                        width: 80,
                        child: _ShipmentColumnLabel(
                          'Pacas / Estado',
                          align: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: kDirectionOliveGlow.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: kDirectionOliveMist.withValues(alpha: 0.18),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: kDirectionOliveGlow,
                            ),
                          )
                        : summary == null
                        ? const _ShipmentMessage(
                            'No se pudieron cargar los embarques de esta semana.',
                          )
                        : summary.rows.isEmpty
                        ? const _ShipmentMessage(
                            'Sin embarques de pacas programados o embarcados en esta semana.',
                          )
                        : Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: summary.rows.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: kDirectionOliveMist.withValues(
                                  alpha: 0.14,
                                ),
                              ),
                              itemBuilder: (_, index) =>
                                  _ShipmentRow(row: summary.rows[index]),
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

  Widget _weekButton(String tooltip, IconData icon, VoidCallback? onPressed) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: kDirectionOliveGlow,
      disabledColor: kDirectionSubtleText.withValues(alpha: 0.4),
      constraints: const BoxConstraints.tightFor(width: 30, height: 32),
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 19),
    );
  }
}

class _ShipmentMetric extends StatelessWidget {
  final String label;
  final int? value;
  final Color accent;

  const _ShipmentMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value == null ? '—' : formatDecimal(value!, decimals: 0),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShipmentColumnLabel extends StatelessWidget {
  final String text;
  final TextAlign align;
  const _ShipmentColumnLabel(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    style: const TextStyle(
      color: kDirectionMutedText,
      fontSize: 10,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _ShipmentRow extends StatelessWidget {
  final DirectionShipmentSummaryRow row;
  const _ShipmentRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final accent = row.isShipped ? kDirectionSuccess : kDirectionWarning;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dayLabels[row.date.weekday - 1],
                  style: const TextStyle(
                    color: kDirectionOliveGlow,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${row.date.day}',
                  style: const TextStyle(
                    color: kDirectionMutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.materialLabel,
                  style: const TextStyle(
                    color: kDirectionSurfaceText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  row.destination,
                  style: const TextStyle(
                    color: kDirectionMutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatDecimal(row.bales, decimals: 0),
                  style: const TextStyle(
                    color: kDirectionSurfaceText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  row.statusLabel,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
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

class _ShipmentMessage extends StatelessWidget {
  final String text;
  const _ShipmentMessage(this.text);

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: kDirectionMutedText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

const _dayLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _monthLabels = [
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

String _weekRange(DateTime start) {
  final end = start.add(const Duration(days: 5));
  final startMonth = _monthLabels[start.month - 1];
  final endMonth = _monthLabels[end.month - 1];
  if (start.year != end.year) {
    return '${start.day} $startMonth ${start.year} – ${end.day} $endMonth ${end.year}';
  }
  final first = start.month == end.month
      ? '${start.day}'
      : '${start.day} $startMonth';
  return '$first – ${end.day} $endMonth ${end.year}';
}
