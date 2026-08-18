import 'dart:async';

import 'package:flutter/material.dart';

import '../shared/app_error_reporter.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'management_reports_history_store.dart';
import 'management_reports_pdf_export.dart';
import 'management_reports_registry.dart';

class ManagementAreaReportPanel extends StatefulWidget {
  final ManagementAreaKey areaKey;
  final String? titleOverride;
  final String? subtitleOverride;
  final Future<void> Function()? onOpenSupervisionHub;
  final bool showOpenHubButton;
  final bool showReportActions;

  const ManagementAreaReportPanel({
    super.key,
    required this.areaKey,
    this.titleOverride,
    this.subtitleOverride,
    this.onOpenSupervisionHub,
    this.showOpenHubButton = false,
    this.showReportActions = true,
  });

  @override
  State<ManagementAreaReportPanel> createState() =>
      _ManagementAreaReportPanelState();
}

class _ManagementAreaReportPanelState extends State<ManagementAreaReportPanel> {
  ManagementReportRunRecord? _lastDaily;
  ManagementReportRunRecord? _lastWeekly;
  bool _loadingHistory = true;
  ManagementReportFrequency? _exporting;

  ManagementAreaDefinition get _area =>
      managementAreaDefinition(widget.areaKey);

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
  }

  Future<void> _loadHistory() async {
    final daily = await ManagementReportsHistoryStore.latestFor(
      widget.areaKey,
      ManagementReportFrequency.daily,
    );
    final weekly = await ManagementReportsHistoryStore.latestFor(
      widget.areaKey,
      ManagementReportFrequency.weeklyFriday,
    );
    if (!mounted) return;
    setState(() {
      _lastDaily = daily;
      _lastWeekly = weekly;
      _loadingHistory = false;
    });
  }

  Future<void> _export(ManagementReportFrequency frequency) async {
    if (_exporting != null) return;
    setState(() => _exporting = frequency);
    try {
      final record = await exportManagementReportPdf(
        area: _area,
        frequency: frequency,
      );
      if (!mounted) return;
      if (record != null) {
        await _loadHistory();
        AppErrorReporter.showMessage(
          'Reporte ${managementFrequencyLabel(frequency).toLowerCase()} guardado para ${_area.title}.',
        );
      }
    } catch (error, stackTrace) {
      AppErrorReporter.report(
        error,
        stackTrace,
        fallbackMessage:
            'No se pudo generar el reporte de supervisión de ${_area.title}.',
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = null);
      }
    }
  }

  Future<void> _openHistory() async {
    final rows = await ManagementReportsHistoryStore.loadForArea(
      widget.areaKey,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Historial · ${_area.title}'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cortes disponibles: ${_area.hasDailyReports ? 'diario y viernes' : 'viernes'}',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Últimas corridas',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (rows.isEmpty)
                    const Text(
                      'Todavía no hay corridas guardadas para esta área.',
                    )
                  else
                    for (final row in rows.take(8))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '• ${managementFrequencyLabel(row.frequency)} · ${_formatDateTime(row.generatedAt)} · ${row.generatedBy} · ${row.fileName}',
                        ),
                      ),
                  const SizedBox(height: 16),
                  Text(
                    'Catálogo del área',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final report in _area.reports)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '• ${managementFrequencyLabel(report.frequency)} · ${report.title} · ${managementStatusLabel(report.dataStatus)}',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final areaTitle = widget.titleOverride ?? _area.title;
    final areaSubtitle = widget.subtitleOverride ?? _area.subtitle;
    final dailyReports = _area.reportsFor(ManagementReportFrequency.daily);
    final weeklyReports = _area.reportsFor(
      ManagementReportFrequency.weeklyFriday,
    );
    final canGenerateDaily = dailyReports.isNotEmpty;
    final showActions = widget.showReportActions;
    final accentBase = _area.accent;
    final accent = _managementAccentInk(accentBase);
    final accentOn = _managementAccentForeground(accentBase);

    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentBase.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accentBase.withValues(alpha: 0.28)),
                ),
                child: Icon(_area.icon, color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      areaTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: tokens.onGlass,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _area.ownerLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      areaSubtitle,
                      style: TextStyle(
                        fontSize: 12.8,
                        fontWeight: FontWeight.w700,
                        color: tokens.onGlass.withValues(alpha: 0.74),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showOpenHubButton &&
                  widget.onOpenSupervisionHub != null)
                const SizedBox(width: 10),
              if (widget.showOpenHubButton &&
                  widget.onOpenSupervisionHub != null)
                OutlinedButton.icon(
                  onPressed: widget.onOpenSupervisionHub,
                  icon: const Icon(Icons.hub_rounded, size: 18),
                  label: const Text('Hub'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.onGlass,
                    side: BorderSide(color: accent.withValues(alpha: 0.42)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                label:
                    '${_area.countByStatus(ManagementReportFrequency.weeklyFriday, ManagementReportDataStatus.ready)} listas viernes',
                color: managementStatusColor(ManagementReportDataStatus.ready),
              ),
              _StatusChip(
                label:
                    '${_area.countByStatus(ManagementReportFrequency.weeklyFriday, ManagementReportDataStatus.partial)} parciales viernes',
                color: managementStatusColor(
                  ManagementReportDataStatus.partial,
                ),
              ),
              _StatusChip(
                label:
                    '${_area.countByStatus(ManagementReportFrequency.weeklyFriday, ManagementReportDataStatus.pending)} pendientes viernes',
                color: managementStatusColor(
                  ManagementReportDataStatus.pending,
                ),
              ),
              if (canGenerateDaily)
                _StatusChip(
                  label: '${dailyReports.length} reportes diarios',
                  color: accentBase,
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (showActions) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final canSplit = constraints.maxWidth >= 760;
                final cardWidth = canSplit
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (canGenerateDaily)
                      SizedBox(
                        width: cardWidth,
                        child: _CutCard(
                          title: 'Corte diario',
                          countLabel: '${dailyReports.length} reportes',
                          lastGenerated: _loadingHistory
                              ? 'Cargando historial...'
                              : _latestLabel(_lastDaily),
                          primaryLabel:
                              _exporting == ManagementReportFrequency.daily
                              ? 'Generando...'
                              : 'Generar diario',
                          onPrimaryTap: _exporting == null
                              ? () => _export(ManagementReportFrequency.daily)
                              : null,
                          accent: accentBase,
                          accentInk: accent,
                          accentOn: accentOn,
                          reportTitles: dailyReports
                              .map((row) => row.title)
                              .toList(growable: false),
                        ),
                      ),
                    SizedBox(
                      width: cardWidth,
                      child: _CutCard(
                        title: 'Junta de viernes',
                        countLabel: '${weeklyReports.length} reportes',
                        lastGenerated: _loadingHistory
                            ? 'Cargando historial...'
                            : _latestLabel(_lastWeekly),
                        primaryLabel:
                            _exporting == ManagementReportFrequency.weeklyFriday
                            ? 'Generando...'
                            : 'Generar viernes',
                        onPrimaryTap: _exporting == null
                            ? () => _export(
                                ManagementReportFrequency.weeklyFriday,
                              )
                            : null,
                        accent: accentBase,
                        accentInk: accent,
                        accentOn: accentOn,
                        reportTitles: weeklyReports
                            .map((row) => row.title)
                            .toList(growable: false),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _openHistory,
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('Ver historial'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.onGlass,
                  side: BorderSide(color: accent.withValues(alpha: 0.34)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: 0.22)),
              ),
              child: Text(
                'La generación y descarga de reportes vive solo en Supervisión por Áreas. Desde este dashboard se conserva contexto del corte y acceso al hub central.',
                style: TextStyle(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w700,
                  color: tokens.onGlass.withValues(alpha: 0.78),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _latestLabel(ManagementReportRunRecord? record) {
    if (record == null) return 'Aún no se ha generado';
    return '${_formatDateTime(record.generatedAt)} · ${record.generatedBy}';
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }
}

class _CutCard extends StatelessWidget {
  final String title;
  final String countLabel;
  final String lastGenerated;
  final String primaryLabel;
  final VoidCallback? onPrimaryTap;
  final Color accent;
  final Color accentInk;
  final Color accentOn;
  final List<String> reportTitles;

  const _CutCard({
    required this.title,
    required this.countLabel,
    required this.lastGenerated,
    required this.primaryLabel,
    required this.onPrimaryTap,
    required this.accent,
    required this.accentInk,
    required this.accentOn,
    required this.reportTitles,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: tokens.onGlass,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            countLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: accentInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lastGenerated,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tokens.onGlass.withValues(alpha: 0.70),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          for (final title in reportTitles.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $title',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tokens.onGlass.withValues(alpha: 0.82),
                ),
              ),
            ),
          if (reportTitles.length > 3)
            Text(
              '+ ${reportTitles.length - 3} más',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: tokens.onGlass.withValues(alpha: 0.62),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onPrimaryTap,
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: Text(primaryLabel),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: accentOn,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final ink = _managementAccentInk(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ink.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: ink,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Color _managementAccentInk(Color color) {
  return color;
}

Color _managementAccentForeground(Color color) {
  return color.computeLuminance() > 0.58
      ? const Color(0xFF4A3600)
      : Colors.white;
}
