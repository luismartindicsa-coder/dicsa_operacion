part of '../human_resources_prenomina_page.dart';

class _PrenominaClosureIssue {
  final _HrPrenominaSummaryRow row;
  final HrLoanPayrollPlan savedLoans;
  final HrLoanPayrollPlan currentLoans;
  final bool loansChanged;
  final bool unpublished;
  final bool hasSavedDraft;

  const _PrenominaClosureIssue({
    required this.row,
    required this.savedLoans,
    required this.currentLoans,
    required this.loansChanged,
    required this.unpublished,
    required this.hasSavedDraft,
  });

  _PrenominaSection get section => loansChanged
      ? _PrenominaSection.descuentos
      : row.attendanceReviewDays > 0
      ? _PrenominaSection.asistencia
      : row.permissionPendingPrenominaCount > 0
      ? _PrenominaSection.vacaciones
      : _PrenominaSection.notas;

  List<String> get steps => [
    if (loansChanged)
      'Los préstamos guardados tienen cuotas o abonos diferentes a los actuales. En Descuentos, revisa Préstamos del fondo y guarda el detalle.',
    if (unpublished) ...[
      if (!hasSavedDraft) 'Este colaborador aún no tiene un borrador guardado.',
      if (row.attendanceReviewDays > 0)
        'Asistencia: ${row.attendanceReviewDays} día(s) en revisión RH. Revisa los días señalados y corrige su captura en Asistencia.',
      if (row.permissionPendingPrenominaCount > 0)
        'Permisos: ${row.permissionPendingPrenominaCount} movimiento(s) pendiente(s) de aplicar. Valida su estado en Permisos y su detalle en Vacaciones y permisos.',
      'Valida los importes y elige Publicado en el estado de la tabla. También puedes publicarlo desde Notas del detalle. Listo todavía no es una publicación.',
    ],
  ];
}

List<_PrenominaClosureIssue> _buildPrenominaClosureIssues({
  required List<_HrPrenominaSummaryRow> rows,
  required List<_HrPrenominaDraftRowRecord> drafts,
  required String period,
  bool checkLoans = true,
}) {
  final savedByEmployee = {
    for (final draft in drafts.where((draft) => draft.periodLabel == period))
      draft.employeeId: draft,
  };
  final issues = <_PrenominaClosureIssue>[];
  for (final row in rows) {
    final saved = savedByEmployee[row.employeeId];
    final currentLoans = HrLoanPayrollPlan.fromSnapshot(row.sourceSnapshot);
    final savedLoans = HrLoanPayrollPlan.fromSnapshot(
      saved?.sourceSnapshot ?? const {},
    );
    // Keep the existing closure guard: include removed/repaid allocations too.
    final loansChanged =
        checkLoans &&
        (currentLoans.requestedCents > 0 || savedLoans.recoveredCents > 0) &&
        jsonEncode(currentLoans.toJson()) != jsonEncode(savedLoans.toJson());
    final unpublished = saved?.draftStatus != _HrPrenominaDraftStatus.publicado;
    if (!loansChanged && !unpublished) continue;
    issues.add(
      _PrenominaClosureIssue(
        row: row,
        savedLoans: savedLoans,
        currentLoans: currentLoans,
        loansChanged: loansChanged,
        unpublished: unpublished,
        hasSavedDraft: saved != null,
      ),
    );
  }
  issues.sort((a, b) {
    if (a.loansChanged != b.loansChanged) return a.loansChanged ? -1 : 1;
    final name = a.row.displayName.compareTo(b.row.displayName);
    return name != 0 ? name : a.row.employeeId.compareTo(b.row.employeeId);
  });
  return issues;
}

class _PrenominaClosureReviewDialog extends StatefulWidget {
  final String period;
  final List<_PrenominaClosureIssue> issues;
  final String? message;

  const _PrenominaClosureReviewDialog({
    required this.period,
    required this.issues,
    this.message,
  });

  @override
  State<_PrenominaClosureReviewDialog> createState() =>
      _PrenominaClosureReviewDialogState();
}

class _PrenominaClosureReviewDialogState
    extends State<_PrenominaClosureReviewDialog> {
  String _query = '';
  String _filter = 'todos';
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = humanResourcesAreaTokens;
    final visible = widget.issues.where((issue) {
      if (_filter == 'prestamos' && !issue.loansChanged) return false;
      if (_filter == 'publicar' && !issue.unpublished) return false;
      return '${issue.row.employeeId} ${issue.row.displayName} ${issue.row.empresa}'
          .toLowerCase()
          .contains(_query.trim().toLowerCase());
    }).toList();
    final loans = widget.issues.where((issue) => issue.loansChanged).length;
    final pending = widget.issues.where((issue) => issue.unpublished).length;
    return AreaThemeScope(
      tokens: tokens,
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        },
        child: Actions(
          actions: {
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                Navigator.of(context).pop();
                return null;
              },
            ),
          },
          child: ContractDialogShell(
            insetPadding: const EdgeInsets.all(24),
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: tokens.primaryStrong,
                  surface: tokens.primarySoft,
                  onSurface: tokens.primaryStrong,
                ),
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: tokens.primaryStrong, fontSize: 13),
                child: Container(
                  key: const ValueKey('closure-review-dialog'),
                  width: 920,
                  height: math.min(820, MediaQuery.sizeOf(context).height - 48),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: tokens.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.issues.isEmpty
                                  ? 'Revisión de cierre'
                                  : 'Pendientes para cerrar',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar revisión',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close, color: tokens.surfaceTint),
                          ),
                        ],
                      ),
                      Text(
                        widget.period,
                        style: TextStyle(color: tokens.surfaceTint),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.message ??
                            'Para cerrar, los préstamos deben estar actualizados y todos los colaboradores deben estar publicados. Esta revisión abarca todo el periodo, aunque la tabla tenga filtros.',
                      ),
                      if (widget.issues.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final item in [
                              ('todos', 'Todos (${widget.issues.length})'),
                              (
                                'prestamos',
                                'Préstamos por actualizar ($loans)',
                              ),
                              ('publicar', 'Por publicar ($pending)'),
                            ])
                              ChoiceChip(
                                key: ValueKey('closure-filter-${item.$1}'),
                                label: Text(item.$2),
                                selected: _filter == item.$1,
                                selectedColor: tokens.accent,
                                onSelected: (_) =>
                                    setState(() => _filter = item.$1),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          key: const ValueKey('closure-search'),
                          autofocus: true,
                          style: TextStyle(color: tokens.primaryStrong),
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre, ID o empresa',
                            prefixIcon: Icon(
                              Icons.search,
                              color: tokens.surfaceTint,
                            ),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) => setState(() => _query = value),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Expanded(
                        child: visible.isEmpty
                            ? Center(
                                child: Text(
                                  widget.issues.isEmpty
                                      ? 'No se realizó ningún cierre.'
                                      : 'No hay pendientes que coincidan con esta búsqueda.',
                                ),
                              )
                            : Scrollbar(
                                controller: _scrollController,
                                thumbVisibility: true,
                                child: ListView.separated(
                                  key: const ValueKey('closure-issues-list'),
                                  controller: _scrollController,
                                  padding: const EdgeInsets.only(right: 10),
                                  itemCount: visible.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, index) =>
                                      _PrenominaClosureIssueCard(
                                        issue: visible[index],
                                        canReview: widget.message == null,
                                      ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cerrar revisión'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrenominaClosureIssueCard extends StatelessWidget {
  final _PrenominaClosureIssue issue;
  final bool canReview;
  const _PrenominaClosureIssueCard({
    required this.issue,
    required this.canReview,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = humanResourcesAreaTokens;
    return Container(
      key: ValueKey('closure-employee-${issue.row.employeeId}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.onGlass.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border.withValues(alpha: .6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            issue.row.displayName,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 3),
          Text(
            'ID #${issue.row.employeeId} · ${issue.row.empresa} · ${issue.row.statusLabel}',
            style: TextStyle(color: tokens.surfaceTint),
          ),
          const SizedBox(height: 8),
          for (final step in issue.steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(step),
            ),
          if (issue.loansChanged) ...[
            const SizedBox(height: 6),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
              },
              children: [
                TableRow(
                  children: [
                    const Text(
                      'Préstamos',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Text('Guardado', textAlign: TextAlign.right),
                    const Text('Actual', textAlign: TextAlign.right),
                  ],
                ),
                for (final item in [
                  (
                    'Cuotas y vencidos',
                    issue.savedLoans.requestedCents,
                    issue.currentLoans.requestedCents,
                  ),
                  (
                    'Cobro en Flujo',
                    issue.savedLoans.cents,
                    issue.currentLoans.cents,
                  ),
                  (
                    'Fiscal · incluido en CONTPAQ',
                    issue.savedLoans.fiscalCents,
                    issue.currentLoans.fiscalCents,
                  ),
                  (
                    'Pendiente de cobro',
                    issue.savedLoans.pendingCents,
                    issue.currentLoans.pendingCents,
                  ),
                ])
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(item.$1),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _formatPrenominaMoneyZero(item.$2 / 100),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _formatPrenominaMoneyZero(item.$3 / 100),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final item in [
              ('Guardado', issue.savedLoans),
              ('Actual', issue.currentLoans),
            ])
              Text(
                '${item.$1}: ${item.$2.dues.isEmpty ? 'sin cuotas' : item.$2.dues.map((due) => 'PR-${due.folio} · ${due.channel == 'fiscal' ? 'Fiscal' : 'Flujo'} ${_formatPrenominaMoneyZero(due.cents / 100)}').join(' / ')}',
                style: TextStyle(color: tokens.surfaceTint, fontSize: 12),
              ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: ValueKey('closure-review-${issue.row.employeeId}'),
              onPressed: canReview
                  ? () => Navigator.of(context).pop(issue)
                  : null,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text('Revisar ${issue.section.label}'),
            ),
          ),
        ],
      ),
    );
  }
}
