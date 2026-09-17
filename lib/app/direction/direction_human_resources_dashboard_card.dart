import 'dart:async';

import 'package:flutter/material.dart';

import '../hr/human_resources_period_context.dart';
import '../shared/utils/number_formatters.dart';
import 'direction_human_resources_summary.dart';
import 'direction_theme.dart';

class DirectionHumanResourcesDashboardCard extends StatefulWidget {
  final Future<void> Function() onOpenHumanResources;
  final Future<DirectionHumanResourcesSummary> Function()? loadSummary;

  const DirectionHumanResourcesDashboardCard({
    super.key,
    required this.onOpenHumanResources,
    this.loadSummary,
  });

  @override
  State<DirectionHumanResourcesDashboardCard> createState() =>
      _DirectionHumanResourcesDashboardCardState();
}

class _DirectionHumanResourcesDashboardCardState
    extends State<DirectionHumanResourcesDashboardCard> {
  DirectionHumanResourcesSummary? _summary;
  bool _refreshing = false,
      _pendingReload = false,
      _failed = false,
      _hovered = false;
  int _revision = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _requestReload();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _requestReload(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _requestReload() {
    if (!mounted) return;
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    _refreshing = true;
    final revision = _revision;
    try {
      final summary =
          await (widget.loadSummary?.call() ??
              DirectionHumanResourcesStore().load());
      if (!mounted || revision != _revision) return;
      setState(() {
        _summary = summary;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || revision != _revision) return;
      setState(() => _failed = true);
    } finally {
      _refreshing = false;
      if (_pendingReload && mounted) {
        _pendingReload = false;
        _requestReload();
      }
    }
  }

  Future<void> _selectPeriod(String label) async {
    try {
      await HumanResourcesPeriodContext.select(label);
      if (!mounted) return;
      setState(() {
        _revision++;
        _summary = null;
        _failed = false;
      });
      _requestReload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo seleccionar el periodo de RH.'),
        ),
      );
    }
  }

  Future<void> _open() async {
    await widget.onOpenHumanResources();
    _requestReload();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        offset: _hovered ? const Offset(0, -.008) : Offset.zero,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          scale: _hovered ? 1.005 : 1,
          child: DirectionGlassPanel(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(28),
            blurSigma: 30,
            fillColor: kDirectionOliveDeep.withValues(alpha: .24),
            borderColor: Colors.white.withValues(alpha: _hovered ? .34 : .28),
            shadowColor: Colors.black.withValues(alpha: _hovered ? .18 : .14),
            edgeHighlightColor: Colors.white.withValues(alpha: .70),
            bevelShadowColor: Colors.black.withValues(alpha: .14),
            glowColor: kDirectionOliveGlow.withValues(
              alpha: _hovered ? .18 : .12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.badge_rounded,
                      color: kDirectionOliveGlow,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recursos Humanos',
                            style: TextStyle(
                              color: kDirectionSurfaceText,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Resumen del periodo',
                            style: TextStyle(
                              color: kDirectionMutedText,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Abrir Recursos Humanos',
                      onPressed: _open,
                      color: kDirectionOliveGlow,
                      icon: const Icon(Icons.arrow_outward_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (summary == null)
                  SizedBox(
                    height: 300,
                    child: Center(
                      child: _failed
                          ? const Text(
                              'No se pudo consultar el resumen de RH.',
                              style: TextStyle(color: kDirectionIvory),
                            )
                          : const CircularProgressIndicator(
                              color: kDirectionOliveGlow,
                            ),
                    ),
                  )
                else ...[
                  _periodHeader(summary),
                  if (_failed)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'No se pudo actualizar RH. Se muestran los últimos datos consultados.',
                        style: TextStyle(color: kDirectionIvory, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 14),
                  _money(summary),
                  const SizedBox(height: 16),
                  _details(summary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _periodHeader(DirectionHumanResourcesSummary summary) => Wrap(
    spacing: 12,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      PopupMenuButton<String>(
        key: const ValueKey('direction-rh-period'),
        tooltip: 'Elegir periodo de RH',
        enabled: summary.periodOptions.isNotEmpty,
        color: kDirectionOliveDeep,
        onSelected: _selectPeriod,
        itemBuilder: (_) => [
          for (final period in summary.periodOptions)
            PopupMenuItem(
              value: period,
              child: Text(
                period,
                style: const TextStyle(color: kDirectionSurfaceText),
              ),
            ),
        ],
        child: Container(
          constraints: const BoxConstraints(maxWidth: 540),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: _decoration(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 18,
                color: kDirectionOliveGlow,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  summary.hasPeriod
                      ? summary.periodLabel
                      : summary.periodOptions.isEmpty
                      ? 'Sin periodos registrados'
                      : 'Seleccionar periodo',
                  style: const TextStyle(
                    color: kDirectionSurfaceText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.expand_more,
                size: 18,
                color: kDirectionOliveGlow,
              ),
            ],
          ),
        ),
      ),
      if (summary.hasPeriod)
        Text(
          summary.closed ? 'Periodo cerrado' : 'Periodo abierto',
          style: const TextStyle(
            color: kDirectionOliveGlow,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      if (summary.hasPeriod && summary.payroll.employees > 0)
        Text(
          '${summary.payroll.employees} colaboradores · '
          '${summary.payroll.published} ${summary.payroll.published == 1 ? 'publicado' : 'publicados'} · '
          '${summary.payroll.ready} ${summary.payroll.ready == 1 ? 'listo' : 'listos'}',
          style: const TextStyle(color: kDirectionMutedText, fontSize: 12),
        ),
    ],
  );

  Widget _money(DirectionHumanResourcesSummary summary) {
    final hasPayroll = summary.hasPeriod && summary.payroll.employees > 0;
    final empty = summary.hasPeriod
        ? 'Sin prenómina guardada'
        : 'Selecciona un periodo';
    final cards = [
      _moneyTile(
        'Total fiscal',
        hasPayroll ? formatMoney(summary.payroll.fiscal) : '—',
        hasPayroll
            ? 'Depósito ${formatMoney(summary.payroll.deposit)} · Cheque ${formatMoney(summary.payroll.cheque)}'
            : empty,
        Icons.account_balance_outlined,
        'direction-rh-fiscal',
      ),
      _moneyTile(
        'Total flujo',
        hasPayroll ? formatMoney(summary.payroll.flow) : '—',
        hasPayroll
            ? 'A entregar · incluye ${formatMoney(summary.payroll.cheque)} de cheque fiscal'
            : empty,
        Icons.payments_outlined,
        'direction-rh-flow',
      ),
    ];
    return LayoutBuilder(
      builder: (_, constraints) => constraints.maxWidth >= 570
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [cards[0], const SizedBox(height: 10), cards[1]],
            ),
    );
  }

  Widget _moneyTile(
    String title,
    String amount,
    String detail,
    IconData icon,
    String key,
  ) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _decoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: kDirectionOliveGlow),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: kDirectionSurfaceText,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              key: ValueKey(key),
              style: const TextStyle(
                color: kDirectionSurfaceText,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          detail,
          style: const TextStyle(
            color: kDirectionMutedText,
            fontSize: 11.5,
            height: 1.35,
          ),
        ),
      ],
    ),
  );

  Widget _details(DirectionHumanResourcesSummary summary) {
    final panels = [
      _HrDetailPanel(
        title: 'Vacaciones próximas',
        icon: Icons.beach_access_outlined,
        count: '${summary.vacations.length}',
        caption:
            'Próximos 15 días · ${_dateLabel(summary.asOf.add(const Duration(days: 1)))} al ${_dateLabel(summary.asOf.add(const Duration(days: 15)))}',
        empty: 'Sin vacaciones próximas',
        children: [for (final event in summary.vacations) _eventRow(event)],
      ),
      _HrDetailPanel(
        title: 'Permisos',
        icon: Icons.assignment_outlined,
        count: summary.hasPeriod ? '${summary.permissions.length}' : '—',
        caption: summary.hasPeriod
            ? 'Del periodo · ${summary.pendingPermissions} ${summary.pendingPermissions == 1 ? 'pendiente' : 'pendientes'}'
            : 'Eventos registrados en RH',
        empty: summary.hasPeriod
            ? 'Sin permisos registrados'
            : 'Selecciona un periodo',
        children: [for (final event in summary.permissions) _eventRow(event)],
      ),
      _HrDetailPanel(
        title: 'Faltas',
        icon: Icons.person_off_outlined,
        count: summary.hasPeriod ? '${summary.absenceDays}' : '—',
        caption: summary.hasPeriod
            ? 'Días del periodo · ${summary.absences.length} ${summary.absences.length == 1 ? 'colaborador' : 'colaboradores'}'
            : 'Días registrados en Asistencia',
        empty: summary.hasPeriod
            ? 'Sin faltas registradas'
            : 'Selecciona un periodo',
        children: [
          for (final row in summary.absences)
            _detailRow(
              row.name,
              row.company,
              '${row.dates.length} ${row.dates.length == 1 ? 'día' : 'días'}',
              row.dates.map(_dateLabel).join(' · '),
            ),
        ],
      ),
    ];
    return LayoutBuilder(
      builder: (_, constraints) {
        final columns = constraints.maxWidth >= 900 ? 3 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final panel in panels) SizedBox(width: width, child: panel),
          ],
        );
      },
    );
  }

  Widget _eventRow(DirectionHrEvent event) => _detailRow(
    event.name,
    event.company,
    event.status == 'pendiente' ? 'Pendiente' : '',
    '${event.label} · ${_dateLabel(event.start)}${event.end == event.start ? '' : ' al ${_dateLabel(event.end)}'}',
  );

  Widget _detailRow(String name, String company, String badge, String detail) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: name,
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kDirectionSurfaceText,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (badge.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    badge,
                    style: const TextStyle(
                      color: kDirectionOliveGlow,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            if (company.isNotEmpty)
              Text(
                company,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kDirectionMutedText,
                  fontSize: 10.5,
                ),
              ),
            const SizedBox(height: 3),
            Text(
              detail,
              style: const TextStyle(
                color: kDirectionMutedText,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
}

class _HrDetailPanel extends StatefulWidget {
  final String title, count, caption, empty;
  final IconData icon;
  final List<Widget> children;
  const _HrDetailPanel({
    required this.title,
    required this.count,
    required this.caption,
    required this.empty,
    required this.icon,
    required this.children,
  });
  @override
  State<_HrDetailPanel> createState() => _HrDetailPanelState();
}

class _HrDetailPanelState extends State<_HrDetailPanel> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
    decoration: _decoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(widget.icon, size: 20, color: kDirectionOliveGlow),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: kDirectionSurfaceText,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              widget.count,
              style: const TextStyle(
                color: kDirectionOliveGlow,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          widget.caption,
          style: const TextStyle(color: kDirectionMutedText, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Divider(height: 1, color: kDirectionOliveMist.withValues(alpha: .25)),
        SizedBox(
          height: 195,
          child: widget.children.isEmpty
              ? Center(
                  child: Text(
                    widget.empty,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: kDirectionMutedText,
                      fontSize: 12,
                    ),
                  ),
                )
              : Scrollbar(
                  controller: _scroll,
                  child: ListView.separated(
                    controller: _scroll,
                    primary: false,
                    padding: EdgeInsets.zero,
                    itemCount: widget.children.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: kDirectionOliveMist.withValues(alpha: .14),
                    ),
                    itemBuilder: (_, index) => widget.children[index],
                  ),
                ),
        ),
      ],
    ),
  );
}

BoxDecoration _decoration() => BoxDecoration(
  color: kDirectionOliveDeep.withValues(alpha: .16),
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: kDirectionOliveMist.withValues(alpha: .28)),
);
String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
