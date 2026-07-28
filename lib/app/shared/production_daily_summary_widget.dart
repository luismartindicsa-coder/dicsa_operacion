import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductionDailySummaryPalette {
  final Color surface;
  final Color border;
  final Color accent;
  final Color accentSoft;
  final Color text;
  final Color mutedText;
  final Color gridLine;
  final Color highlightSurface;

  const ProductionDailySummaryPalette({
    required this.surface,
    required this.border,
    required this.accent,
    required this.accentSoft,
    required this.text,
    required this.mutedText,
    required this.gridLine,
    required this.highlightSurface,
  });
}

class ProductionDailySummaryWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final ProductionDailySummaryPalette palette;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const ProductionDailySummaryWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.palette,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 18),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  @override
  State<ProductionDailySummaryWidget> createState() =>
      _ProductionDailySummaryWidgetState();
}

class _ProductionDailySummaryWidgetState
    extends State<ProductionDailySummaryWidget> {
  static const Duration _kReloadInterval = Duration(seconds: 90);

  bool _loading = true;
  bool _refreshing = false;
  bool _pendingReload = false;
  ProductionDailySummaryBundle? _bundle;
  late DateTime _selectedWeekStart;
  Timer? _reloadTimer;
  RealtimeChannel? _productionChannel;
  RealtimeChannel? _transformationChannel;

  @override
  void initState() {
    super.initState();
    _selectedWeekStart = _weekStartMonday(DateTime.now());
    _requestReload(showLoader: true);
    _reloadTimer = Timer.periodic(_kReloadInterval, (_) => _requestReload());
    final supa = Supabase.instance.client;
    _productionChannel = supa
        .channel('production-daily-summary-production')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'production_runs',
          callback: (_) => _requestReload(),
        )
        .subscribe();
    _transformationChannel = supa
        .channel('production-daily-summary-transformations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'material_transformation_runs_v2',
          callback: (_) => _requestReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'material_transformation_run_outputs_v2',
          callback: (_) => _requestReload(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _productionChannel?.unsubscribe();
    _transformationChannel?.unsubscribe();
    super.dispose();
  }

  void _requestReload({bool showLoader = false}) {
    if (!mounted) return;
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(_load(silent: !showLoader));
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    _refreshing = true;
    if (!silent || _bundle == null) {
      setState(() => _loading = true);
    }
    try {
      final bundle = await ProductionDailySummaryStore.loadWeek(
        _selectedWeekStart,
      );
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _selectedWeekStart = bundle.weekStart;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _refreshing = false;
      if (_pendingReload && mounted) {
        _pendingReload = false;
        unawaited(_load(silent: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final bundle = _bundle;
    final currentWeekStart = _weekStartMonday(DateTime.now());
    final canGoForward = _selectedWeekStart.isBefore(currentWeekStart);
    final isCurrentWeek = _selectedWeekStart == currentWeekStart;
    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: widget.borderRadius,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: palette.accent.withValues(alpha: 0.12),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  _weekLabel(bundle),
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              if (bundle != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: palette.highlightSurface,
                  ),
                  child: Text(
                    '${bundle.totalBales} pacas',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.subtitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: palette.mutedText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _ProductionSummaryWeekNavigator(
            palette: palette,
            weekStart: _selectedWeekStart,
            weekEnd: _selectedWeekStart.add(const Duration(days: 4)),
            isCurrentWeek: isCurrentWeek,
            canGoForward: canGoForward,
            onPrevious: () => _changeWeek(-7),
            onCurrent: isCurrentWeek ? null : _goToCurrentWeek,
            onNext: canGoForward ? () => _changeWeek(7) : null,
          ),
          const SizedBox(height: 16),
          if (_loading)
            const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (bundle == null)
            _ProductionSummaryMessage(
              palette: palette,
              title: 'No fue posible cargar la producción',
              body:
                  'No se pudo construir el resumen semanal en tiempo real. Revisa la conexión y vuelve a intentar.',
            )
          else ...[
            _ProductionSummaryTotals(bundle: bundle, palette: palette),
            const SizedBox(height: 14),
            _ProductionSummaryTable(bundle: bundle, palette: palette),
            if (bundle.unassignedNationalCount > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Hay ${bundle.unassignedNationalCount} pacas nacionales sin C1/C2 reconocible en comentario.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.accentSoft,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _weekLabel(ProductionDailySummaryBundle? bundle) {
    if (bundle == null) return 'SEMANA ACTUAL';
    return 'SEMANA ${_shortDate(bundle.weekStart)} - ${_shortDate(bundle.weekEnd)}';
  }

  void _changeWeek(int dayDelta) {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.add(Duration(days: dayDelta));
    });
    unawaited(_load());
  }

  void _goToCurrentWeek() {
    setState(() {
      _selectedWeekStart = _weekStartMonday(DateTime.now());
    });
    unawaited(_load());
  }
}

class _ProductionSummaryWeekNavigator extends StatelessWidget {
  final ProductionDailySummaryPalette palette;
  final DateTime weekStart;
  final DateTime weekEnd;
  final bool isCurrentWeek;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback? onCurrent;
  final VoidCallback? onNext;

  const _ProductionSummaryWeekNavigator({
    required this.palette,
    required this.weekStart,
    required this.weekEnd,
    required this.isCurrentWeek,
    required this.canGoForward,
    required this.onPrevious,
    required this.onCurrent,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _WeekNavButton(
          label: 'Semana anterior',
          icon: Icons.chevron_left_rounded,
          palette: palette,
          onTap: onPrevious,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: palette.highlightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.gridLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCurrentWeek ? 'Semana actual' : 'Histórico semanal',
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_fullDate(weekStart)} - ${_fullDate(weekEnd)}',
                style: TextStyle(
                  color: palette.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        _WeekNavButton(
          label: 'Semana actual',
          icon: Icons.today_rounded,
          palette: palette,
          onTap: onCurrent,
        ),
        _WeekNavButton(
          label: 'Semana siguiente',
          icon: Icons.chevron_right_rounded,
          palette: palette,
          onTap: canGoForward ? onNext : null,
        ),
      ],
    );
  }
}

class _WeekNavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final ProductionDailySummaryPalette palette;
  final VoidCallback? onTap;

  const _WeekNavButton({
    required this.label,
    required this.icon,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: enabled
              ? palette.accent.withValues(alpha: 0.10)
              : palette.highlightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled ? palette.border : palette.gridLine,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: enabled ? palette.accent : palette.mutedText,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: enabled ? palette.text : palette.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductionSummaryTotals extends StatelessWidget {
  final ProductionDailySummaryBundle bundle;
  final ProductionDailySummaryPalette palette;

  const _ProductionSummaryTotals({required this.bundle, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final day in bundle.days)
          Container(
            width: 118,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: palette.highlightSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.gridLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.label.toUpperCase(),
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${day.total}',
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Día ${day.dayShiftTotal} · Noche ${day.nightShiftTotal}',
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProductionSummaryTable extends StatelessWidget {
  final ProductionDailySummaryBundle bundle;
  final ProductionDailySummaryPalette palette;

  const _ProductionSummaryTable({required this.bundle, required this.palette});

  @override
  Widget build(BuildContext context) {
    final rows = <TableRow>[
      TableRow(
        children: [
          _headerCell('Tipo de paca', alignLeft: true),
          for (final day in bundle.days) ...[
            _headerCell(day.label),
            _headerCell(day.label),
          ],
        ],
      ),
      TableRow(
        children: [
          _subHeaderCell(''),
          for (final day in bundle.days) ...[
            _subHeaderCell(_shiftLabel(day.dayShiftKey)),
            _subHeaderCell(_shiftLabel(day.nightShiftKey)),
          ],
        ],
      ),
      for (final row in bundle.rows)
        TableRow(
          children: [
            _labelCell(row.label),
            for (final day in bundle.days) ...[
              _valueCell(row.countFor(day.date, day.dayShiftKey)),
              _valueCell(row.countFor(day.date, day.nightShiftKey)),
            ],
          ],
        ),
      TableRow(
        children: [
          _footerLabelCell('Total pacas'),
          for (final day in bundle.days) ...[
            _footerValueCell(day.dayShiftTotal),
            _footerValueCell(day.nightShiftTotal),
          ],
        ],
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(78),
          border: TableBorder.all(color: palette.gridLine, width: 0.85),
          children: rows,
        ),
      ),
    );
  }

  Widget _headerCell(String label, {bool alignLeft = false}) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: palette.accent.withValues(alpha: 0.18),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
      child: alignLeft
          ? SizedBox(
              width: 130,
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: palette.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.text,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }

  Widget _subHeaderCell(String label) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      color: palette.highlightSurface,
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: palette.mutedText,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _labelCell(String label) {
    return Container(
      width: 150,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: palette.accent.withValues(alpha: 0.12),
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: palette.text,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _valueCell(int value) {
    return Container(
      height: 42,
      alignment: Alignment.center,
      color: palette.surface,
      child: Text(
        '$value',
        style: TextStyle(
          color: palette.text,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _footerLabelCell(String label) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: palette.accent.withValues(alpha: 0.18),
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: palette.text,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _footerValueCell(int value) {
    return Container(
      height: 44,
      alignment: Alignment.center,
      color: palette.highlightSurface,
      child: Text(
        '$value',
        style: TextStyle(
          color: palette.accentSoft,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProductionSummaryMessage extends StatelessWidget {
  final ProductionDailySummaryPalette palette;
  final String title;
  final String body;

  const _ProductionSummaryMessage({
    required this.palette,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 220),
      decoration: BoxDecoration(
        color: palette.highlightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.gridLine),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 36,
                color: palette.accent,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductionDailySummaryStore {
  static final SupabaseClient _supa = Supabase.instance.client;
  static const Duration _kCacheTtl = Duration(seconds: 20);
  static final Map<String, ProductionDailySummaryBundle> _cachedBundles =
      <String, ProductionDailySummaryBundle>{};
  static final Map<String, DateTime> _cachedAtByWeek = <String, DateTime>{};
  static final Map<String, Future<ProductionDailySummaryBundle>> _inFlight =
      <String, Future<ProductionDailySummaryBundle>>{};

  static Future<ProductionDailySummaryBundle> loadCurrentWeek() async {
    return loadWeek(DateTime.now());
  }

  static Future<ProductionDailySummaryBundle> loadWeek(
    DateTime weekDate,
  ) async {
    final weekStart = _weekStartMonday(weekDate);
    final cacheKey = _fmtDate(weekStart);
    final now = DateTime.now();
    final cachedBundle = _cachedBundles[cacheKey];
    final cachedAt = _cachedAtByWeek[cacheKey];
    if (cachedBundle != null &&
        cachedAt != null &&
        now.difference(cachedAt) <= _kCacheTtl) {
      return cachedBundle;
    }
    final inFlight = _inFlight[cacheKey];
    if (inFlight != null) return inFlight;
    final future = _loadWeekUncached(weekStart);
    _inFlight[cacheKey] = future;
    try {
      final bundle = await future;
      _cachedBundles[cacheKey] = bundle;
      _cachedAtByWeek[cacheKey] = DateTime.now();
      return bundle;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  static Future<ProductionDailySummaryBundle> _loadWeekUncached(
    DateTime weekStart,
  ) async {
    final weekEnd = weekStart.add(const Duration(days: 4));

    final dayBuckets = <_SummaryRowKey, Map<_SummaryCellKey, int>>{
      for (final key in _kSummaryRowOrder) key: <_SummaryCellKey, int>{},
    };

    int unassignedNationalCount = 0;

    final cartonGeneral = await _supa
        .from('material_general_catalog_v2')
        .select('id')
        .eq('code', 'CARTON')
        .maybeSingle();

    var hasCartonTransformationData = false;
    if (cartonGeneral != null) {
      final cartonRows = await _supa
          .from('material_transformation_runs_v2')
          .select(
            'op_date,shift,notes,'
            'outputs:material_transformation_run_outputs_v2('
            'output_unit_count,notes,'
            'commercial_material:commercial_material_id(code)'
            ')',
          )
          .eq('source_general_material_id', cartonGeneral['id'])
          .gte('op_date', _fmtDate(weekStart))
          .lte('op_date', _fmtDate(weekEnd));

      for (final row
          in (cartonRows as List<dynamic>).cast<Map<String, dynamic>>()) {
        final opDate = _parseDate(row['op_date']);
        final shiftKey = _normalizeShift(row['shift']?.toString());
        final outputs = (row['outputs'] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();
        for (final output in outputs) {
          final count = (output['output_unit_count'] as num?)?.toInt() ?? 0;
          if (count <= 0) continue;
          final commercial = (output['commercial_material'] as Map?)
              ?.cast<String, dynamic>();
          final summaryKey = _mapProductionRowKey(
            baleMaterial: commercial?['code']?.toString(),
            notes: (output['notes'] ?? row['notes'])?.toString(),
          );
          if (summaryKey == null) {
            final commercialCode = (commercial?['code'] ?? '')
                .toString()
                .trim()
                .toUpperCase();
            final outputNotes = (output['notes'] ?? row['notes'])?.toString();
            if (commercialCode == 'BALE_NATIONAL' ||
                commercialCode == 'PACA_NACIONAL') {
              if (_compactadoraFromNotes(outputNotes) == null) {
                unassignedNationalCount += count;
              }
            }
            continue;
          }
          hasCartonTransformationData = true;
          final bucket = dayBuckets.putIfAbsent(
            summaryKey,
            () => <_SummaryCellKey, int>{},
          );
          final key = _SummaryCellKey(opDate, shiftKey);
          bucket.update(key, (value) => value + count, ifAbsent: () => count);
        }
      }
    }

    if (!hasCartonTransformationData) {
      final productionRows = await _supa
          .from('production_runs')
          .select('op_date,shift,bale_material,bale_count,notes')
          .gte('op_date', _fmtDate(weekStart))
          .lte('op_date', _fmtDate(weekEnd));

      for (final row
          in (productionRows as List<dynamic>).cast<Map<String, dynamic>>()) {
        final opDate = _parseDate(row['op_date']);
        final shiftKey = _normalizeShift(row['shift']?.toString());
        final count = (row['bale_count'] as num?)?.toInt() ?? 0;
        if (count <= 0) continue;
        final summaryKey = _mapProductionRowKey(
          baleMaterial: row['bale_material']?.toString(),
          notes: row['notes']?.toString(),
        );
        if (summaryKey == null) {
          final code = (row['bale_material'] ?? '')
              .toString()
              .trim()
              .toUpperCase();
          if ((code == 'BALE_NATIONAL' || code == 'PACA_NACIONAL') &&
              _compactadoraFromNotes(row['notes']?.toString()) == null) {
            unassignedNationalCount += count;
          }
          continue;
        }
        final bucket = dayBuckets.putIfAbsent(
          summaryKey,
          () => <_SummaryCellKey, int>{},
        );
        final key = _SummaryCellKey(opDate, shiftKey);
        bucket.update(key, (value) => value + count, ifAbsent: () => count);
      }
    }

    final paperGeneral = await _supa
        .from('material_general_catalog_v2')
        .select('id')
        .eq('code', 'PAPEL')
        .maybeSingle();
    if (paperGeneral != null) {
      final paperRows = await _supa
          .from('material_transformation_runs_v2')
          .select(
            'op_date,shift,outputs:material_transformation_run_outputs_v2(output_unit_count)',
          )
          .eq('source_general_material_id', paperGeneral['id'])
          .gte('op_date', _fmtDate(weekStart))
          .lte('op_date', _fmtDate(weekEnd));
      for (final row
          in (paperRows as List<dynamic>).cast<Map<String, dynamic>>()) {
        final opDate = _parseDate(row['op_date']);
        final shiftKey = _normalizeShift(row['shift']?.toString());
        final outputs = (row['outputs'] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();
        final units = outputs.fold<int>(
          0,
          (sum, output) =>
              sum + ((output['output_unit_count'] as num?)?.toInt() ?? 0),
        );
        if (units <= 0) continue;
        final key = _SummaryCellKey(opDate, shiftKey);
        dayBuckets[_SummaryRowKey.papel]!.update(
          key,
          (value) => value + units,
          ifAbsent: () => units,
        );
      }
    }

    final days = <ProductionDailySummaryDay>[
      for (var offset = 0; offset < 5; offset++)
        () {
          final date = weekStart.add(Duration(days: offset));
          final dayKey = _SummaryCellKey(date, 'DAY');
          final nightKey = _SummaryCellKey(date, 'NIGHT');
          final dayShiftTotal = dayBuckets.values.fold<int>(
            0,
            (sum, bucket) => sum + (bucket[dayKey] ?? 0),
          );
          final nightShiftTotal = dayBuckets.values.fold<int>(
            0,
            (sum, bucket) => sum + (bucket[nightKey] ?? 0),
          );
          return ProductionDailySummaryDay(
            date: date,
            label: _weekdayLabel(date.weekday),
            dayShiftKey: 'DAY',
            nightShiftKey: 'NIGHT',
            dayShiftTotal: dayShiftTotal,
            nightShiftTotal: nightShiftTotal,
          );
        }(),
    ];

    final rows = _kSummaryRowOrder
        .map(
          (key) => ProductionDailySummaryRow._(
            key: key.name,
            label: _summaryRowLabel(key),
            counts: Map<_SummaryCellKey, int>.unmodifiable(dayBuckets[key]!),
          ),
        )
        .toList(growable: false);

    return ProductionDailySummaryBundle(
      weekStart: weekStart,
      weekEnd: weekEnd,
      days: days,
      rows: rows,
      unassignedNationalCount: unassignedNationalCount,
    );
  }
}

class ProductionDailySummaryBundle {
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<ProductionDailySummaryDay> days;
  final List<ProductionDailySummaryRow> rows;
  final int unassignedNationalCount;

  const ProductionDailySummaryBundle({
    required this.weekStart,
    required this.weekEnd,
    required this.days,
    required this.rows,
    required this.unassignedNationalCount,
  });

  int get totalBales => days.fold<int>(0, (sum, day) => sum + day.total);
}

class ProductionDailySummaryDay {
  final DateTime date;
  final String label;
  final String dayShiftKey;
  final String nightShiftKey;
  final int dayShiftTotal;
  final int nightShiftTotal;

  const ProductionDailySummaryDay({
    required this.date,
    required this.label,
    required this.dayShiftKey,
    required this.nightShiftKey,
    required this.dayShiftTotal,
    required this.nightShiftTotal,
  });

  int get total => dayShiftTotal + nightShiftTotal;
}

class ProductionDailySummaryRow {
  final String key;
  final String label;
  final Map<_SummaryCellKey, int> _counts;

  const ProductionDailySummaryRow._({
    required this.key,
    required this.label,
    required Map<_SummaryCellKey, int> counts,
  }) : _counts = counts;

  int countFor(DateTime date, String shiftKey) {
    return _counts[_SummaryCellKey(date, shiftKey)] ?? 0;
  }
}

enum _SummaryRowKey {
  limpia,
  revueltaC1,
  revueltaC2,
  americana,
  caple,
  papel,
  basura,
}

const List<_SummaryRowKey> _kSummaryRowOrder = <_SummaryRowKey>[
  _SummaryRowKey.limpia,
  _SummaryRowKey.revueltaC1,
  _SummaryRowKey.revueltaC2,
  _SummaryRowKey.americana,
  _SummaryRowKey.caple,
  _SummaryRowKey.papel,
  _SummaryRowKey.basura,
];

class _SummaryCellKey {
  final DateTime date;
  final String shiftKey;

  const _SummaryCellKey(this.date, this.shiftKey);

  @override
  bool operator ==(Object other) {
    return other is _SummaryCellKey &&
        other.date.year == date.year &&
        other.date.month == date.month &&
        other.date.day == date.day &&
        other.shiftKey == shiftKey;
  }

  @override
  int get hashCode => Object.hash(date.year, date.month, date.day, shiftKey);
}

_SummaryRowKey? _mapProductionRowKey({
  required String? baleMaterial,
  required String? notes,
}) {
  final code = (baleMaterial ?? '').trim().toUpperCase();
  switch (code) {
    case 'BALE_CLEAN':
    case 'PACA_LIMPIA':
      return _SummaryRowKey.limpia;
    case 'BALE_NATIONAL':
    case 'PACA_NACIONAL':
      final compactadora = _compactadoraFromNotes(notes);
      if (compactadora == 1) return _SummaryRowKey.revueltaC1;
      if (compactadora == 2) return _SummaryRowKey.revueltaC2;
      return null;
    case 'BALE_AMERICAN':
    case 'PACA_AMERICANA':
      return _SummaryRowKey.americana;
    case 'CAPLE':
    case 'PACA_CAPLE':
      return _SummaryRowKey.caple;
    case 'BALE_TRASH':
    case 'PACA_BASURA':
      return _SummaryRowKey.basura;
    default:
      return null;
  }
}

int? _compactadoraFromNotes(String? notes) {
  final normalized = (notes ?? '').trim().toUpperCase();
  if (normalized.isEmpty) return null;
  // La captura real ya usa variantes como "C1", "COMPACTADORA 1" y "compactadora 2".
  if (normalized.contains('COMPACTADORA 1') ||
      RegExp(r'(^|[^A-Z0-9])C1([^A-Z0-9]|$)').hasMatch(normalized)) {
    return 1;
  }
  if (normalized.contains('COMPACTADORA 2') ||
      RegExp(r'(^|[^A-Z0-9])C2([^A-Z0-9]|$)').hasMatch(normalized)) {
    return 2;
  }
  return null;
}

String _summaryRowLabel(_SummaryRowKey key) {
  switch (key) {
    case _SummaryRowKey.limpia:
      return 'Limpia';
    case _SummaryRowKey.revueltaC1:
      return 'Revuelta C1';
    case _SummaryRowKey.revueltaC2:
      return 'Revuelta C2';
    case _SummaryRowKey.americana:
      return 'Americana';
    case _SummaryRowKey.caple:
      return 'Caple';
    case _SummaryRowKey.papel:
      return 'Papel';
    case _SummaryRowKey.basura:
      return 'Basura';
  }
}

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Lunes';
    case DateTime.tuesday:
      return 'Martes';
    case DateTime.wednesday:
      return 'Miércoles';
    case DateTime.thursday:
      return 'Jueves';
    case DateTime.friday:
      return 'Viernes';
    case DateTime.saturday:
      return 'Sábado';
    default:
      return '—';
  }
}

String _shiftLabel(String shiftKey) {
  return shiftKey == 'NIGHT' ? 'Noche' : 'Día';
}

String _normalizeShift(String? rawShift) {
  final normalized = (rawShift ?? '').trim().toUpperCase();
  if (normalized == 'NIGHT' || normalized == 'NOCHE') return 'NIGHT';
  return 'DAY';
}

DateTime _weekStartMonday(DateTime dateTime) {
  final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

DateTime _parseDate(dynamic value) {
  final raw = (value ?? '').toString();
  if (raw.length >= 10) {
    final year = int.tryParse(raw.substring(0, 4));
    final month = int.tryParse(raw.substring(5, 7));
    final day = int.tryParse(raw.substring(8, 10));
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

String _fmtDate(DateTime dateTime) {
  final year = dateTime.year.toString().padLeft(4, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
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

String _fullDate(DateTime date) {
  return '${date.day} ${_monthLabel(date.month)} ${date.year}';
}

String _monthLabel(int month) {
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
  return months[month - 1];
}
