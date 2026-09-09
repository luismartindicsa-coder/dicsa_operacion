part of '../human_resources_nomina_page.dart';

class _HrNominaWorkspace extends StatelessWidget {
  final List<_HrNominaSummaryRow> rows;
  final List<_HrNominaSummaryRow> periodRows;
  final List<_HrNominaDraftRecord> draftRows;
  final Widget filters;
  final int totalRows;
  final int selectedCount;
  final String activePeriodLabel;
  final List<String> periodOptions;
  final bool isPeriodClosed;
  final _HrNominaMetrics metrics;
  final String? selectedRowId;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<int> onPageSizeChanged;
  final Future<void> Function() onOpenPrenomina;
  final Future<void> Function() onExportPeriodReport;
  final ValueChanged<String> onSelectPeriod;
  final ValueChanged<_HrNominaSummaryRow> onSelectRow;
  final ValueChanged<_HrNominaSummaryRow> onOpenRow;

  const _HrNominaWorkspace({
    required this.rows,
    required this.periodRows,
    required this.draftRows,
    required this.filters,
    required this.totalRows,
    required this.selectedCount,
    required this.activePeriodLabel,
    required this.periodOptions,
    required this.isPeriodClosed,
    required this.metrics,
    required this.selectedRowId,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPageSizeChanged,
    required this.onOpenPrenomina,
    required this.onExportPeriodReport,
    required this.onSelectPeriod,
    required this.onSelectRow,
    required this.onOpenRow,
  });

  @override
  Widget build(BuildContext context) {
    final ready = periodRows.where((r) => r.statusLabel == 'Listo').length;
    final published = periodRows.where((r) => r.isPublished).length;
    return ContractGlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: humanResourcesAreaTokens.onGlass.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nómina',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: humanResourcesAreaTokens.onGlass,
              ),
            ),
            Text(
              'Validación final de la corrida antes de publicar pagos.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: humanResourcesAreaTokens.badgeText,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                HumanResourcesPeriodSelector(
                  selectedLabel: activePeriodLabel,
                  options: periodOptions,
                  onSelected: onSelectPeriod,
                ),
                OutlinedButton.icon(
                  onPressed: periodRows.isEmpty ? null : onExportPeriodReport,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF del periodo'),
                  style: _nominaOutlinedStyle(context, dark: true),
                ),
                FilledButton.icon(
                  style: _nominaFilledStyle(context),
                  onPressed: onOpenPrenomina,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver a prenómina'),
                ),
                Text(
                  isPeriodClosed ? 'Periodo cerrado' : 'Periodo sin cerrar',
                  style: TextStyle(
                    color: humanResourcesAreaTokens.badgeText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _NominaCards(
              fiscalPayment: HrFiscalPayment(
                total: metrics.fiscal,
                cheque: metrics.fiscalCash,
              ),
              items: [
                ('Colaboradores', '${periodRows.length}', 'En este periodo'),
                ('Listos', '$ready', '$published publicados'),
                (
                  'Pendientes',
                  '${periodRows.length - ready - published}',
                  'Borrador / revisión RH',
                ),
                (
                  'Fiscal',
                  _fmtHrNominaMoney(metrics.fiscal),
                  'Resultado fiscal',
                ),
                (
                  'Flujo',
                  _fmtHrNominaMoney(metrics.total - metrics.fiscal),
                  'Deducciones ya aplicadas',
                ),
                (
                  'Total a pagar',
                  _fmtHrNominaMoney(metrics.total),
                  'Fiscal + Flujo',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 218, child: _NominaSurface(child: filters)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NominaSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Colaboradores ($totalRows)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) => SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: constraints.maxWidth < 1010
                                      ? 1010
                                      : constraints.maxWidth,
                                  height: constraints.maxHeight,
                                  child: Column(
                                    children: [
                                      const _NominaFinancialRow(),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: rows.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  'No hay colaboradores para estos filtros.',
                                                ),
                                              )
                                            : ListView.separated(
                                                itemCount: rows.length,
                                                separatorBuilder: (_, _) =>
                                                    const SizedBox(height: 4),
                                                itemBuilder: (context, index) {
                                                  final row = rows[index];
                                                  return _NominaFinancialRow(
                                                    row: row,
                                                    selected:
                                                        row.employeeId ==
                                                        selectedRowId,
                                                    createdAt: draftRows
                                                        .where(
                                                          (d) =>
                                                              d.id ==
                                                              row.draftId,
                                                        )
                                                        .firstOrNull
                                                        ?.createdAt,
                                                    onTap: () =>
                                                        onSelectRow(row),
                                                    onOpen: () =>
                                                        onOpenRow(row),
                                                  );
                                                },
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _HrNominaGridFooter(
                            rows: rows.length,
                            totalRows: totalRows,
                            selectedCount: selectedCount,
                            currentPage: currentPage,
                            totalPages: totalPages,
                            pageSize: pageSize,
                            onPreviousPage: onPreviousPage,
                            onNextPage: onNextPage,
                            onPageSizeChanged: onPageSizeChanged,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrNominaFilters extends StatelessWidget {
  final List<_HrNominaSummaryRow> rows;
  final TextEditingController controller;
  final Set<String> statuses;
  final String? company;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatus, onCompany;
  final VoidCallback onClear;
  const _HrNominaFilters({
    required this.rows,
    required this.controller,
    required this.statuses,
    required this.company,
    required this.onSearch,
    required this.onStatus,
    required this.onCompany,
    required this.onClear,
  });
  @override
  Widget build(BuildContext context) {
    final companies =
        rows.map((r) => r.empresa).where((v) => v.isNotEmpty).toSet().toList()
          ..sort();
    return ListView(
      children: [
        Row(
          children: [
            const Icon(Icons.filter_alt_outlined, size: 22),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Filtros',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ),
            TextButton(
              onPressed: onClear,
              child: const Text('Limpiar', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DefaultTextEditingShortcuts(
          child: TextField(
            key: const ValueKey('nomina-search'),
            controller: controller,
            onChanged: onSearch,
            style: TextStyle(
              fontSize: 12,
              color: humanResourcesAreaTokens.primaryStrong,
            ),
            decoration: const InputDecoration(
              hintText: 'Buscar colaborador',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Estado', style: TextStyle(fontWeight: FontWeight.w900)),
        for (final status in <String?>[
          null,
          'Listo',
          'Borrador',
          'Revisión RH',
          'Publicado',
        ])
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: const VisualDensity(horizontal: -4, vertical: -2),
            controlAffinity: ListTileControlAffinity.leading,
            value: status == null
                ? statuses.isEmpty
                : statuses.contains(status),
            onChanged: (_) => onStatus(status),
            title: Text(
              status ?? 'Todos',
              style: const TextStyle(fontSize: 12),
            ),
            secondary: Text(
              '${status == null ? rows.length : rows.where((r) => r.statusLabel == status).length}',
              style: TextStyle(
                fontSize: 11,
                color: humanResourcesAreaTokens.surfaceTint,
              ),
            ),
          ),
        const SizedBox(height: 20),
        const Text('Empresa', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: humanResourcesAreaTokens.border.withValues(alpha: .45),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: companies.contains(company) ? company : null,
              hint: Text(
                'Todas las empresas',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Todas las empresas'),
                ),
                for (final c in companies)
                  DropdownMenuItem(
                    value: c,
                    child: Text(c, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: onCompany,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: humanResourcesAreaTokens.primaryStrong,
                fontSize: 12,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

class _NominaFinancialRow extends StatelessWidget {
  final _HrNominaSummaryRow? row;
  final DateTime? createdAt;
  final bool selected;
  final VoidCallback? onTap, onOpen;
  const _NominaFinancialRow({
    this.row,
    this.createdAt,
    this.selected = false,
    this.onTap,
    this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final r = row;
    Widget cell(
      String heading,
      String? value,
      int flex, {
      bool money = false,
      String? subtitle,
    }) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: money
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value ?? heading,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: r == null ? 11 : 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null && subtitle.isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: humanResourcesAreaTokens.surfaceTint,
                ),
              ),
          ],
        ),
      ),
    );
    return Material(
      color: selected
          ? humanResourcesAreaTokens.primary.withValues(alpha: .18)
          : humanResourcesAreaTokens.onGlass.withValues(
              alpha: r == null ? .35 : .95,
            ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: humanResourcesAreaTokens.border.withValues(
            alpha: selected ? .72 : 0,
          ),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        hoverColor: humanResourcesAreaTokens.primarySoft.withValues(alpha: .5),
        child: SizedBox(
          height: r == null ? 34 : 58,
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  r?.employeeId ?? 'ID',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              cell('NOMBRE', r?.employeeName, 25, subtitle: r?.empresa),
              cell(
                'FISCAL',
                r == null ? null : _fmtHrNominaMoney(r.fiscalAmount),
                13,
                money: true,
                subtitle: r?.fiscalDeliveryLabel,
              ),
              cell(
                'FLUJO',
                r == null ? null : _fmtHrNominaMoney(_nominaFlow(r)),
                13,
                money: true,
              ),
              cell(
                'DEDUCCIONES',
                r == null ? null : _fmtHrNominaMoney(r.deductionsAmount),
                13,
                money: true,
                subtitle: r == null ? null : 'Incluidas en flujo',
              ),
              cell(
                'TOTAL A PAGAR',
                r == null ? null : _fmtHrNominaMoney(r.totalAmount),
                14,
                money: true,
              ),
              Expanded(
                flex: 14,
                child: r == null
                    ? const Center(
                        child: Text(
                          'ESTADO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _HrNominaStatusBadge(label: r.statusLabel),
                        ),
                      ),
              ),
              cell('REGISTRO', r == null ? null : _nominaDate(createdAt), 12),
              SizedBox(
                width: 48,
                child: r == null
                    ? const Icon(Icons.more_horiz, size: 18)
                    : IconButton(
                        tooltip: 'Ver detalle',
                        onPressed: onOpen,
                        style: IconButton.styleFrom(
                          backgroundColor: selected
                              ? humanResourcesAreaTokens.surfaceTint
                              : humanResourcesAreaTokens.primarySoft,
                          foregroundColor: selected
                              ? humanResourcesAreaTokens.onGlass
                              : humanResourcesAreaTokens.surfaceTint,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.more_horiz),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
