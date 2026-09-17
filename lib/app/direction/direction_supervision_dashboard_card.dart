import 'package:flutter/material.dart';

import '../management_reports/management_reports_history_store.dart';
import '../management_reports/management_reports_pdf_export.dart';
import '../management_reports/management_reports_registry.dart';
import '../shared/app_error_reporter.dart';
import 'direction_theme.dart';

typedef DirectionSupervisionExporter =
    Future<ManagementReportRunRecord?> Function({
      required ManagementAreaDefinition area,
      required ManagementReportFrequency frequency,
    });

class DirectionSupervisionDashboardCard extends StatefulWidget {
  final Future<void> Function() onOpenSupervision;
  final DirectionSupervisionExporter? exportReport;

  const DirectionSupervisionDashboardCard({
    super.key,
    required this.onOpenSupervision,
    this.exportReport,
  });

  @override
  State<DirectionSupervisionDashboardCard> createState() =>
      _DirectionSupervisionDashboardCardState();
}

class _DirectionSupervisionDashboardCardState
    extends State<DirectionSupervisionDashboardCard> {
  final _scrollController = ScrollController();
  final _areas = [...managementAreaCatalog]
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  ManagementAreaKey? _exporting;
  String? _message;
  bool _failed = false;
  bool _hovering = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _generateFriday(ManagementAreaDefinition area) async {
    if (_exporting != null) return;
    setState(() {
      _exporting = area.key;
      _failed = false;
      _message = 'Generando viernes · ${area.title}…';
    });
    try {
      final record = await (widget.exportReport ?? exportManagementReportPdf)(
        area: area,
        frequency: ManagementReportFrequency.weeklyFriday,
      );
      if (!mounted) return;
      setState(() {
        _message = record == null
            ? 'Guardado cancelado · ${area.title}.'
            : 'PDF guardado · ${area.title}: ${record.fileName}';
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      final message =
          'No se pudo generar el PDF de ${area.title}. Intenta de nuevo.';
      setState(() {
        _failed = true;
        _message = message;
      });
      AppErrorReporter.report(error, stackTrace, fallbackMessage: message);
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message =
        _message ?? '${_areas.length} áreas · Reporte semanal en PDF';
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
                      Icons.fact_check_rounded,
                      color: kDirectionOliveGlow,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Supervisión',
                            style: TextStyle(
                              color: kDirectionSurfaceText,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Reportes por área · Junta de viernes',
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
                      tooltip: 'Abrir Supervisión',
                      onPressed: _exporting == null
                          ? widget.onOpenSupervision
                          : null,
                      color: kDirectionOliveGlow,
                      disabledColor: kDirectionSubtleText,
                      icon: const Icon(Icons.arrow_outward_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: ListView.separated(
                      key: const ValueKey('direction-supervision-areas'),
                      controller: _scrollController,
                      padding: const EdgeInsets.only(right: 10),
                      itemCount: _areas.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) => _areaRow(_areas[index]),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Tooltip(
                    message: message,
                    child: Text(
                      message,
                      key: const ValueKey('direction-supervision-message'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _failed ? kDirectionDanger : kDirectionMutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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

  Widget _areaRow(ManagementAreaDefinition area) {
    final generating = _exporting == area.key;
    return Container(
      key: ValueKey('direction-supervision-row-${area.key.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: kDirectionInteractiveSurface.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDirectionOliveMist.withValues(alpha: 0.16)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Row(
            children: [
              Icon(area.icon, color: kDirectionOliveGlow, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: area.title,
                  child: Text(
                    area.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kDirectionSurfaceText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          );
          final button = Tooltip(
            message: 'Generar reporte de viernes · ${area.title}',
            child: OutlinedButton(
              key: ValueKey('direction-supervision-generate-${area.key.name}'),
              onPressed: _exporting == null
                  ? () => _generateFriday(area)
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: kDirectionIvory,
                disabledForegroundColor: kDirectionSubtleText,
                backgroundColor: kDirectionOliveGlow.withValues(alpha: 0.10),
                side: BorderSide(
                  color: kDirectionOliveGlow.withValues(alpha: 0.38),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 36),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (generating) ...[
                    const SizedBox.square(
                      dimension: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kDirectionOliveGlow,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(generating ? 'Generando…' : 'Generar viernes'),
                ],
              ),
            ),
          );
          if (constraints.maxWidth < 300) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerRight, child: button),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 8),
              button,
            ],
          );
        },
      ),
    );
  }
}
