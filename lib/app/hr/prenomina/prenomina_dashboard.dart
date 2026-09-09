part of '../human_resources_prenomina_page.dart';

class _PrenominaAttendanceDiagnostic {
  final int worked;
  final int absent;
  final int late;
  const _PrenominaAttendanceDiagnostic({
    this.worked = 0,
    this.absent = 0,
    this.late = 0,
  });
}

Map<String, _PrenominaAttendanceDiagnostic> _prenominaAttendanceDiagnostics(
  List<_HrPrenominaAttendanceRecord> records,
  String period,
) {
  final result = <String, _PrenominaAttendanceDiagnostic>{};
  for (final record in records.where(
    (record) => record.periodLabel == period,
  )) {
    final previous =
        result[record.employeeId] ?? const _PrenominaAttendanceDiagnostic();
    result[record.employeeId] = _PrenominaAttendanceDiagnostic(
      worked:
          previous.worked +
          (record.status == _HrPrenominaAttendanceStatus.laboro ? 1 : 0),
      absent:
          previous.absent +
          (record.status == _HrPrenominaAttendanceStatus.falto ? 1 : 0),
      late: previous.late + (record.lateMinutes > 0 ? 1 : 0),
    );
  }
  return result;
}

bool _prenominaHasIncidences(
  _HrPrenominaSummaryRow row,
  _PrenominaAttendanceDiagnostic? attendance,
) =>
    (attendance?.absent ?? 0) > 0 ||
    row.lateMinutesSum > 0 ||
    row.overtimeMinutesSum > 0 ||
    row.attendanceReviewDays > 0 ||
    row.statusLabel == 'Revisión RH' ||
    row.vacationTotalDays != 0 ||
    row.permissionWithPayDays != 0 ||
    row.permissionWithoutPayDays != 0 ||
    row.permissionWithPayHours != 0 ||
    row.permissionWithoutPayHours != 0 ||
    row.disabilityDays != 0 ||
    row.disabilityHours != 0 ||
    row.permissionPendingPrenominaCount > 0;

bool _prenominaMatchesDashboardFilters(
  _HrPrenominaSummaryRow row,
  _PrenominaAttendanceDiagnostic? attendance, {
  required String query,
  required String? company,
  required bool incidencesOnly,
}) {
  final term = query.trim().toLowerCase();
  return (term.isEmpty ||
          '${row.employeeId} ${row.displayName} ${row.empresa}'
              .toLowerCase()
              .contains(term)) &&
      (company == null || row.empresa == company) &&
      (!incidencesOnly || _prenominaHasIncidences(row, attendance));
}

class _PrenominaKpis extends StatelessWidget {
  final List<_HrPrenominaSummaryRow> rows;
  final String period;
  const _PrenominaKpis({required this.rows, required this.period});
  @override
  Widget build(BuildContext context) {
    final fiscal = rows.fold<double>(
      0,
      (sum, row) => sum + row.fiscalTotalAmount,
    );
    final total = rows.fold<double>(
      0,
      (sum, row) => sum + row.weeklyPaymentVisibleAmount,
    );
    final flow = rows.fold<double>(
      0,
      (sum, row) =>
          sum + (row.weeklyPaymentVisibleAmount - row.fiscalTotalAmount),
    );
    final range = _extractPrenominaDateRangeFromPeriodLabel(period);
    String date(DateTime date) =>
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    final cards = <(String, String, String, IconData)>[
      (
        'Colaboradores',
        '${rows.length}',
        '${rows.where((r) => r.statusLabel == 'Listo').length} listos · ${rows.where((r) => r.statusLabel == 'Revisión RH').length} en revisión',
        Icons.people_outline,
      ),
      (
        'Días del periodo',
        range == null ? '—' : '${range.duration.inDays + 1}',
        range == null
            ? 'Sin fechas disponibles'
            : '${date(range.start)} – ${date(range.end)}',
        Icons.calendar_month_outlined,
      ),
      (
        'Horas extra',
        _formatPrenominaMinutesAsHourRatio(
          rows.fold<int>(0, (sum, r) => sum + r.overtimeMinutesSum),
        ),
        'En ${rows.where((r) => r.overtimeMinutesSum > 0).length} colaboradores',
        Icons.schedule,
      ),
      (
        'Vacaciones',
        '${_prenominaCount(rows.fold<double>(0, (sum, r) => sum + r.vacationTotalDays))} d',
        'Pagadas · disfrutadas · reservadas',
        Icons.beach_access_outlined,
      ),
      (
        'Permisos',
        '${_prenominaCount(rows.fold<double>(0, (sum, r) => sum + r.permissionImpactDays))} d',
        '${_prenominaCount(rows.fold<double>(0, (sum, r) => sum + r.permissionWithPayHours + r.permissionWithoutPayHours + r.disabilityHours))} h · incluye incapacidades',
        Icons.assignment_outlined,
      ),
      (
        'Fiscal',
        _formatPrenominaMoneyZero(fiscal),
        'Total fiscal',
        Icons.account_balance_outlined,
      ),
      (
        'Flujo',
        _formatPrenominaMoneyZero(flow),
        'Complementos y ajustes',
        Icons.payments_outlined,
      ),
      (
        'Total a pagar',
        _formatPrenominaMoneyZero(total),
        'Fiscal + Flujo',
        Icons.account_balance_wallet_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(1180, constraints.maxWidth),
          height: 110,
          child: Row(
            children: [
              for (final item in cards)
                Expanded(
                  child: item.$1 == 'Fiscal'
                      ? Padding(
                          key: const ValueKey('kpi-Fiscal'),
                          padding: const EdgeInsets.only(right: 8),
                          child: HrFiscalPaymentCard(
                            payment: HrFiscalPayment(
                              total: fiscal,
                              cheque: rows.fold<double>(
                                0,
                                (sum, row) => sum + row.fiscalCashAmount,
                              ),
                            ),
                            formatMoney: _formatPrenominaMoneyZero,
                          ),
                        )
                      : Container(
                          key: ValueKey('kpi-${item.$1}'),
                          margin: EdgeInsets.only(
                            right: item == cards.last ? 0 : 8,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: item == cards.last
                                ? humanResourcesAreaTokens.accent
                                : humanResourcesAreaTokens.primarySoft,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: humanResourcesAreaTokens.border.withValues(
                                alpha: .45,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    item.$4,
                                    size: 20,
                                    color: humanResourcesAreaTokens.surfaceTint,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.$1,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: humanResourcesAreaTokens
                                            .surfaceTint,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 9),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  item.$2,
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    color:
                                        humanResourcesAreaTokens.primaryStrong,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                item.$3,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: humanResourcesAreaTokens.surfaceTint,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrenominaFilters extends StatefulWidget {
  final List<_HrPrenominaSummaryRow> rows;
  final Map<String, _PrenominaAttendanceDiagnostic> diagnostics;
  final String search;
  final String? company;
  final bool incidencesOnly;
  final Set<String> statuses;
  final bool hasFilters;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onCompany;
  final ValueChanged<bool> onIncidences;
  final ValueChanged<Set<String>> onStatuses;
  final VoidCallback onClear;
  final bool Function(String) hasActiveFilter;
  final Future<void> Function(String, String) onOpenFilter;
  const _PrenominaFilters({
    required this.rows,
    required this.diagnostics,
    required this.search,
    required this.company,
    required this.incidencesOnly,
    required this.statuses,
    required this.hasFilters,
    required this.onSearch,
    required this.onCompany,
    required this.onIncidences,
    required this.onStatuses,
    required this.onClear,
    required this.hasActiveFilter,
    required this.onOpenFilter,
  });
  @override
  State<_PrenominaFilters> createState() => _PrenominaFiltersState();
}

class _PrenominaFiltersState extends State<_PrenominaFilters> {
  late final TextEditingController _search = TextEditingController(
    text: widget.search,
  );
  @override
  void didUpdateWidget(covariant _PrenominaFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_search.text != widget.search) _search.text = widget.search;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _choice(String label, int count, bool selected, VoidCallback onTap) =>
      InkWell(
        key: ValueKey('filter-$label'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_box : Icons.check_box_outline_blank,
                size: 21,
                color: humanResourcesAreaTokens.surfaceTint,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 12)),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  color: humanResourcesAreaTokens.surfaceTint,
                ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: humanResourcesAreaTokens.primarySoft,
      borderRadius: BorderRadius.circular(18),
    ),
    padding: const EdgeInsets.all(14),
    child: DefaultTextStyle.merge(
      style: TextStyle(color: humanResourcesAreaTokens.primaryStrong),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_alt_outlined),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Filtros',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton(
                  onPressed: widget.hasFilters ? widget.onClear : null,
                  child: const Text('Limpiar', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Restore native text-editing shortcuts inside the grid's shortcut scope.
            DefaultTextEditingShortcuts(
              child: TextField(
                key: const ValueKey('employee-search'),
                controller: _search,
                style: TextStyle(
                  fontSize: 12,
                  color: humanResourcesAreaTokens.primaryStrong,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar colaborador…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: widget.onSearch,
              ),
            ),
            const SizedBox(height: 18),
            const Text('Estado', style: TextStyle(fontWeight: FontWeight.w800)),
            _choice(
              'Todos',
              widget.rows.length,
              widget.statuses.isEmpty,
              () => widget.onStatuses({}),
            ),
            for (final status in [
              'Listo',
              'Revisión RH',
              'Borrador',
              'Publicado',
            ])
              _choice(
                status,
                widget.rows.where((r) => r.statusLabel == status).length,
                widget.statuses.contains(status),
                () {
                  final selected = {...widget.statuses};
                  if (!selected.add(status)) selected.remove(status);
                  widget.onStatuses(selected);
                },
              ),
            const Divider(),
            _choice(
              'Con incidencias',
              widget.rows
                  .where(
                    (r) => _prenominaHasIncidences(
                      r,
                      widget.diagnostics[r.employeeId],
                    ),
                  )
                  .length,
              widget.incidencesOnly,
              () => widget.onIncidences(!widget.incidencesOnly),
            ),
            const SizedBox(height: 14),
            const Text(
              'Empresa',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final companies =
                    widget.rows
                        .map((r) => r.empresa)
                        .where((s) => s.isNotEmpty)
                        .toSet()
                        .toList()
                      ..sort();
                final selected = await showSearchablePickerDialog<String>(
                  context,
                  title: 'Empresa',
                  initialValue: widget.company ?? '',
                  options: [
                    const SearchablePickerOption(
                      value: '',
                      label: 'Todas las empresas',
                    ),
                    for (final company in companies)
                      SearchablePickerOption(value: company, label: company),
                  ],
                );
                if (selected != null && mounted) {
                  widget.onCompany(selected.isEmpty ? null : selected);
                }
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.company ?? 'Todas las empresas',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Filtros por columna',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              children: [
                for (final column in _kPrenominaGridColumns.where(
                  (c) =>
                      !['fiscal', 'flujo', 'total', 'acciones'].contains(c.id),
                ))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      column.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Icon(
                      widget.hasActiveFilter(column.id)
                          ? Icons.filter_alt
                          : Icons.filter_alt_outlined,
                      size: 18,
                    ),
                    onTap: () => widget.onOpenFilter(column.id, column.label),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _PrenominaGridCaption extends StatelessWidget {
  final int count;
  final int selected;
  final bool filtered;
  const _PrenominaGridCaption({
    required this.count,
    required this.selected,
    required this.filtered,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: humanResourcesAreaTokens.primarySoft,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
    ),
    child: Wrap(
      spacing: 16,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Colaboradores ($count)',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: humanResourcesAreaTokens.primaryStrong,
          ),
        ),
        Text(
          filtered
              ? 'Vista filtrada · totales de los resultados'
              : 'Todos los colaboradores del periodo',
          style: TextStyle(
            fontSize: 11,
            color: humanResourcesAreaTokens.surfaceTint,
          ),
        ),
        if (selected > 0)
          Text(
            'Seleccionados: $selected',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: humanResourcesAreaTokens.surfaceTint,
            ),
          ),
      ],
    ),
  );
}

class _HrPrenominaModuleTopBar extends StatelessWidget {
  final List<_HrPrenominaSummaryRow> rows;
  final int totalRows;
  final int selectedCount;
  final String? activeCellLabel;
  final String activePeriodLabel;
  final List<String> periodOptions;
  final bool isPeriodClosed;
  final int publishedDraftCount;
  final int pendingDraftCount;
  final VoidCallback onOpenSelectedRow;
  final VoidCallback onClosePeriod;
  final VoidCallback onExportCashEnvelopes;
  final ValueChanged<String> onSelectPeriod;

  const _HrPrenominaModuleTopBar({
    required this.rows,
    required this.totalRows,
    required this.selectedCount,
    required this.activeCellLabel,
    required this.activePeriodLabel,
    required this.periodOptions,
    required this.isPeriodClosed,
    required this.publishedDraftCount,
    required this.pendingDraftCount,
    required this.onOpenSelectedRow,
    required this.onClosePeriod,
    required this.onExportCashEnvelopes,
    required this.onSelectPeriod,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const SizedBox(
              width: 310,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prenómina',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Consolidado semanal previo a nómina final y validación RH.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xD9D9C7FF),
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                HumanResourcesPeriodSelector(
                  selectedLabel: activePeriodLabel,
                  options: periodOptions,
                  onSelected: onSelectPeriod,
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFB794FF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  onPressed:
                      totalRows == 0 ||
                          activePeriodLabel.isEmpty ||
                          isPeriodClosed
                      ? null
                      : onClosePeriod,
                  icon: Icon(
                    isPeriodClosed
                        ? Icons.lock_rounded
                        : Icons.lock_outline_rounded,
                  ),
                  label: Text(
                    isPeriodClosed ? 'Periodo cerrado' : 'Cerrar periodo',
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF4ECFF),
                    side: const BorderSide(color: Color(0xFFB794FF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  onPressed: totalRows == 0 || activePeriodLabel.isEmpty
                      ? null
                      : onExportCashEnvelopes,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Exportar sobres'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB794FF),
                    foregroundColor: const Color(0xFF24103D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  onPressed:
                      totalRows == 0 ||
                          activePeriodLabel.isEmpty ||
                          isPeriodClosed
                      ? null
                      : onOpenSelectedRow,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Editar borrador'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PrenominaKpis(rows: rows, period: activePeriodLabel),
      ],
    );
  }
}

class _HrPrenominaGridFooter extends StatelessWidget {
  final int rows;
  final int totalRows;
  final int selectedCount;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<int> onPageSizeChanged;

  const _HrPrenominaGridFooter({
    required this.rows,
    required this.totalRows,
    required this.selectedCount,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        elevation: 0,
        color: const Color(0xFFF0E6FF).withValues(alpha: 0.56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                style: _hrPrenominaActionOutlinedButtonStyle().copyWith(
                  textStyle: WidgetStatePropertyAll(
                    Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                onPressed: onPreviousPage,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Anterior'),
              ),
              Text(
                'Página ${_fmtPrenominaInt(currentPage + 1)} de ${_fmtPrenominaInt(totalPages)}',
              ),
              OutlinedButton.icon(
                style: _hrPrenominaActionOutlinedButtonStyle().copyWith(
                  textStyle: WidgetStatePropertyAll(
                    Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                onPressed: onNextPage,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Siguiente'),
              ),
              const Text('Filas/pág:'),
              SizedBox(
                width: 90,
                child: DropdownButtonFormField<int>(
                  initialValue: pageSize,
                  isDense: true,
                  isExpanded: true,
                  decoration: _hrPrenominaFieldDecoration(),
                  items: const [40, 80, 120]
                      .map(
                        (e) =>
                            DropdownMenuItem<int>(value: e, child: Text('$e')),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onPageSizeChanged(value);
                  },
                ),
              ),
              Text(
                'Mostrando ${totalRows == 0 ? 0 : currentPage * pageSize + 1}–${currentPage * pageSize + rows} de $totalRows',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
