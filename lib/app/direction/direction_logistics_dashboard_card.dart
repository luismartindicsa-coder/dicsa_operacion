import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/utils/number_formatters.dart';
import 'direction_logistics_summary.dart';
import 'direction_theme.dart';

class DirectionLogisticsDashboardCard extends StatefulWidget {
  final Future<void> Function() onOpenLogistics;
  final Future<void> Function(DirectionFuelType fuel, DateTime weekStart)
  onOpenControl;
  final Future<DirectionLogisticsWeeklySummary> Function(DateTime)? loadSummary;
  final DateTime Function()? now;

  const DirectionLogisticsDashboardCard({
    super.key,
    required this.onOpenLogistics,
    required this.onOpenControl,
    this.loadSummary,
    this.now,
  });

  @override
  State<DirectionLogisticsDashboardCard> createState() =>
      _DirectionLogisticsDashboardCardState();
}

class _DirectionLogisticsDashboardCardState
    extends State<DirectionLogisticsDashboardCard> {
  final _scrollController = ScrollController();
  late DateTime _weekStart;
  DirectionFuelType _fuel = DirectionFuelType.diesel;
  DirectionLogisticsWeeklySummary? _summary;
  bool _followCurrentWeek = true;
  bool _refreshing = false;
  bool _pendingReload = false;
  bool _loading = true;
  bool _failed = false;
  bool _hovering = false;
  Timer? _timer;
  RealtimeChannel? _channel;

  DateTime get _currentWeek => DirectionLogisticsWeeklySummary.startOfWeek(
    (widget.now ?? DateTime.now)(),
  );

  @override
  void initState() {
    super.initState();
    _weekStart = _currentWeek;
    _requestReload();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _requestReload(),
    );
    if (widget.loadSummary == null) {
      _channel = Supabase.instance.client
          .channel('direction-logistics-${identityHashCode(this)}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'logistics_diesel_consumption',
            callback: (_) => _requestReload(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'logistics_gasoline_control',
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
    if (_followCurrentWeek && _weekStart != _currentWeek) {
      setState(() {
        _weekStart = _currentWeek;
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
    final week = _weekStart;
    try {
      final summary =
          await (widget.loadSummary ??
              const DirectionLogisticsStore().loadWeek)(week);
      if (!mounted || week != _weekStart) return;
      setState(() {
        _summary = summary;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || week != _weekStart) return;
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

  void _changeWeek(DateTime week) {
    if (week == _weekStart) return;
    setState(() {
      _weekStart = week;
      _followCurrentWeek = week == _currentWeek;
      _summary = null;
      _loading = true;
      _failed = false;
    });
    _resetScroll();
    _requestReload();
  }

  void _resetScroll() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _openControl() async {
    await widget.onOpenControl(_fuel, _weekStart);
    _requestReload();
  }

  Future<void> _openLogistics() async {
    await widget.onOpenLogistics();
    _requestReload();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final diesel = _fuel == DirectionFuelType.diesel;
    final rows =
        (diesel ? summary?.dieselDrivers : summary?.gasolineDrivers) ??
        const <DirectionFuelDriverSummary>[];
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
                      Icons.local_gas_station_rounded,
                      color: kDirectionOliveGlow,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Logística',
                            style: TextStyle(
                              color: kDirectionSurfaceText,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Combustibles · Resumen semanal',
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
                      tooltip: 'Abrir Logística',
                      onPressed: _openLogistics,
                      color: kDirectionOliveGlow,
                      icon: const Icon(Icons.arrow_outward_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
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
                        _weekLabel(_weekStart),
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
                      _weekStart.isBefore(_currentWeek)
                          ? () => _changeWeek(
                              _weekStart.add(const Duration(days: 7)),
                            )
                          : null,
                    ),
                    if (_weekStart != _currentWeek)
                      _weekButton(
                        'Semana actual',
                        Icons.today_rounded,
                        () => _changeWeek(_currentWeek),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _fuelTab(
                        DirectionFuelType.diesel,
                        'Diésel',
                        'Solicitados',
                        summary?.dieselRequested,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _fuelTab(
                        DirectionFuelType.gasoline,
                        'Gasolina',
                        'Cargados',
                        summary?.gasolineLoaded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        summary == null
                            ? '—'
                            : diesel
                            ? 'Comprados: ${_liters(summary.dieselPurchased)}'
                            : '${summary.gasolineEntries} registros de carga',
                        style: const TextStyle(
                          color: kDirectionMutedText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('direction-logistics-open-control'),
                      onPressed: _openControl,
                      style: TextButton.styleFrom(
                        foregroundColor: kDirectionOliveGlow,
                        textStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      icon: const Icon(Icons.arrow_outward_rounded, size: 14),
                      label: const Text('Ver control'),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'LITROS POR CHOFER',
                        style: TextStyle(
                          color: kDirectionOliveMist,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Text(
                      'Mayor a menor',
                      style: TextStyle(
                        color: kDirectionMutedText,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: kDirectionOliveGlow,
                            strokeWidth: 2,
                          ),
                        )
                      : summary == null
                      ? _empty(
                          'No se pudieron cargar los controles de combustible.',
                        )
                      : rows.isEmpty
                      ? _empty(
                          diesel
                              ? 'Sin litros solicitados en esta semana.'
                              : 'Sin cargas de gasolina en esta semana.',
                        )
                      : Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          child: ListView.separated(
                            key: const ValueKey('direction-logistics-drivers'),
                            controller: _scrollController,
                            padding: const EdgeInsets.only(right: 10),
                            itemCount: rows.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 4),
                            itemBuilder: (_, index) => _driverRow(rows[index]),
                          ),
                        ),
                ),
                if (_failed && summary != null) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'No se pudo actualizar. Se conservan los últimos datos.',
                    style: TextStyle(color: kDirectionWarning, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fuelTab(
    DirectionFuelType fuel,
    String label,
    String detail,
    double? value,
  ) {
    final selected = _fuel == fuel;
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        key: ValueKey('direction-logistics-${fuel.name}'),
        onPressed: () {
          setState(() => _fuel = fuel);
          _resetScroll();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: kDirectionSurfaceText,
          backgroundColor: selected
              ? kDirectionInteractiveSelected.withValues(alpha: 0.50)
              : kDirectionInteractiveSurface.withValues(alpha: 0.45),
          side: BorderSide(
            color: kDirectionOliveGlow.withValues(
              alpha: selected ? 0.65 : 0.18,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: Theme.of(context).textTheme.labelLarge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value == null ? '—' : _liters(value),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Text(
              detail,
              style: const TextStyle(color: kDirectionMutedText, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _driverRow(DirectionFuelDriverSummary row) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: kDirectionInteractiveSurface.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: Tooltip(
            message: row.name,
            child: Text(
              row.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kDirectionSurfaceText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _liters(row.liters),
          style: const TextStyle(
            color: kDirectionIvory,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _empty(String text) => Center(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: kDirectionMutedText, fontSize: 12),
    ),
  );

  Widget _weekButton(String tooltip, IconData icon, VoidCallback? onPressed) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        color: kDirectionOliveGlow,
        disabledColor: kDirectionSubtleText,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 20),
      );
}

String _liters(double value) =>
    '${formatDecimal(value, decimals: value == value.roundToDouble() ? 0 : 2)} L';

String _weekLabel(DateTime start) {
  final end = start.add(const Duration(days: 6));
  String date(DateTime day) =>
      '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}';
  return '${date(start)} – ${date(end)} · ${end.year}';
}
