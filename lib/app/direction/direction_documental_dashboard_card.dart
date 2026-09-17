import 'package:flutter/material.dart';

import '../gestion_documental/gestion_documental_catalog.dart';
import '../gestion_documental/gestion_documental_live_overview.dart';
import '../gestion_documental/gestion_documental_records.dart';
import '../gestion_documental/gestion_documental_store.dart';
import '../shared/ui_contract_core/refresh/lifecycle_refresh_scope.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'direction_documental_summary.dart';
import 'direction_theme.dart';

class DirectionDocumentalDashboardCard extends StatefulWidget {
  final Future<void> Function() onOpenManagement;

  const DirectionDocumentalDashboardCard({
    super.key,
    required this.onOpenManagement,
  });

  @override
  State<DirectionDocumentalDashboardCard> createState() =>
      _DirectionDocumentalDashboardCardState();
}

class _DirectionDocumentalDashboardCardState
    extends State<DirectionDocumentalDashboardCard> {
  final _scrollController = ScrollController();
  DocumentalRepository? _repository;
  DocumentalLiveOverview<DirectionDocumentalSummary>? _live;
  bool _showProcedures = false;
  bool _hovering = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = DocumentalRepositoryScope.of(context);
    if (identical(repository, _repository)) return;
    _live?.dispose();
    _repository = repository;
    _live = DocumentalLiveOverview(
      repository: repository,
      load: DirectionDocumentalSummaryStore(repository).load,
      contextOf: (data) => data.context,
    )..addListener(_updated);
    _live!.refresh();
  }

  void _updated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _live?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openManagement() async {
    await widget.onOpenManagement();
    await _live?.refresh();
  }

  void _selectTab(bool procedures) {
    setState(() => _showProcedures = procedures);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final live = _live;
    final data = live?.data;
    final rows =
        (_showProcedures ? data?.procedures : data?.expiring) ??
        const <DocumentalRecord>[];
    final error = live?.error ?? live?.actionError;
    return AreaThemeScope(
      tokens: directionAreaTokens,
      child: LifecycleRefreshScope(
        onResume: () async => _live?.refresh(),
        child: MouseRegion(
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
                          Icons.folder_copy_rounded,
                          color: kDirectionOliveGlow,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gestión Documental',
                                style: TextStyle(
                                  color: kDirectionSurfaceText,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Vencimientos y trámites',
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
                          tooltip: 'Abrir Gestión Documental',
                          onPressed: live?.editing == true
                              ? null
                              : _openManagement,
                          color: kDirectionOliveGlow,
                          disabledColor: kDirectionSubtleText,
                          icon: const Icon(
                            Icons.arrow_outward_rounded,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _tab(
                            false,
                            'Por vencer',
                            'Próximos 15 días',
                            data?.expiring.length,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _tab(
                            true,
                            'En proceso',
                            'Permisos y trámites',
                            data?.procedures.length,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data == null
                          ? (live?.loading == true
                                ? 'Consultando Gestión Documental'
                                : 'Datos no disponibles')
                          : 'Al ${_date(data.context.today)}',
                      style: const TextStyle(
                        color: kDirectionMutedText,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 2,
                      child: live?.loading == true && data != null
                          ? const LinearProgressIndicator(
                              color: kDirectionOliveGlow,
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: data == null
                          ? Center(
                              child: live?.loading == true
                                  ? const CircularProgressIndicator(
                                      color: kDirectionOliveGlow,
                                      strokeWidth: 2,
                                    )
                                  : Text(
                                      error ??
                                          'No se pudo cargar Gestión Documental.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: kDirectionMutedText,
                                        fontSize: 12,
                                      ),
                                    ),
                            )
                          : rows.isEmpty
                          ? Center(
                              child: Text(
                                _showProcedures
                                    ? 'No hay trámites en proceso.'
                                    : 'No hay documentos por vencer en los próximos 15 días.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: kDirectionMutedText,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : Scrollbar(
                              controller: _scrollController,
                              thumbVisibility: true,
                              child: ListView.separated(
                                key: const ValueKey(
                                  'direction-documental-records',
                                ),
                                controller: _scrollController,
                                padding: const EdgeInsets.only(right: 10),
                                itemCount: rows.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) =>
                                    _record(context, rows[index], data.context),
                              ),
                            ),
                    ),
                    if (data != null && error != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        error,
                        style: const TextStyle(
                          color: kDirectionWarning,
                          fontSize: 10,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      live?.editing == true
                          ? 'Abriendo expediente…'
                          : 'Selecciona un registro para ver su expediente.',
                      style: const TextStyle(
                        color: kDirectionMutedText,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(bool procedures, String title, String subtitle, int? count) {
    final selected = _showProcedures == procedures;
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        key: ValueKey(
          procedures
              ? 'direction-documental-procedures'
              : 'direction-documental-expiring',
        ),
        onPressed: () => _selectTab(procedures),
        style: OutlinedButton.styleFrom(
          foregroundColor: kDirectionSurfaceText,
          backgroundColor:
              (selected
                      ? kDirectionInteractiveSelected
                      : kDirectionInteractiveSurface)
                  .withValues(alpha: 0.45),
          side: BorderSide(
            color: kDirectionOliveGlow.withValues(
              alpha: selected ? 0.65 : 0.18,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: Theme.of(context).textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            Text(
              count?.toString() ?? '—',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: kDirectionMutedText, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _record(
    BuildContext context,
    DocumentalRecord row,
    DocumentalContext metadata,
  ) {
    final expiration = row.expiration;
    final days = expiration == null
        ? null
        : documentalDaysRemaining(expiration, metadata.today);
    final color = days == null || days > 15
        ? kDirectionOliveGlow
        : days <= 5
        ? kDirectionDanger
        : kDirectionWarning;
    final category = documentalCategories.firstWhere(
      (category) => category.key == row.kind.key,
    );
    final due = days == null
        ? 'Sin vencimiento'
        : days < 0
        ? 'Vencido · ${_date(expiration!)}'
        : days == 0
        ? 'Vence hoy'
        : '${_date(expiration!)} · ${days == 1 ? '1 día' : '$days días'}';
    return Tooltip(
      message: 'Abrir ${row.title}',
      child: OutlinedButton(
        key: ValueKey('direction-documental-record-${row.id}'),
        onPressed: _live?.editing == true
            ? null
            : () => _live?.openRecord(context, row),
        style: OutlinedButton.styleFrom(
          foregroundColor: kDirectionSurfaceText,
          backgroundColor: kDirectionInteractiveSurface.withValues(alpha: 0.55),
          side: BorderSide(color: kDirectionOliveMist.withValues(alpha: 0.16)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(10),
          textStyle: Theme.of(context).textTheme.labelLarge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_showProcedures)
                  Text(
                    '${row.progress}%',
                    style: const TextStyle(
                      color: kDirectionIvory,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                else
                  Icon(
                    days != null && days <= 5
                        ? Icons.priority_high_rounded
                        : Icons.event_available_rounded,
                    color: color,
                    size: 18,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _showProcedures && row.authority.isNotEmpty
                  ? row.authority
                  : category.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kDirectionOliveMist, fontSize: 10),
            ),
            const SizedBox(height: 3),
            Text(
              'Resp. ${metadata.responsibleName(row.responsibleId)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kDirectionMutedText, fontSize: 10),
            ),
            const SizedBox(height: 4),
            Text(
              due,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
