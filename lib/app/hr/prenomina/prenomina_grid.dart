part of '../human_resources_prenomina_page.dart';

class _HrPrenominaWorkspace extends StatelessWidget {
  final List<_HrPrenominaSummaryRow> periodRows;
  final Map<String, _PrenominaAttendanceDiagnostic> diagnostics;
  final String search;
  final String? company;
  final bool incidencesOnly;
  final Set<String> selectedStatuses;
  final bool hasFilters;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onCompany;
  final ValueChanged<bool> onIncidences;
  final ValueChanged<Set<String>> onStatuses;
  final VoidCallback onClearFilters;
  final List<_HrPrenominaSummaryRow> allRows;
  final List<_HrPrenominaSummaryRow> rows;
  final int totalRows;
  final int selectedCount;
  final String activePeriodLabel;
  final List<String> periodOptions;
  final bool isPeriodClosed;
  final int publishedDraftCount;
  final int pendingDraftCount;
  final String? hoveredRowId;
  final GridNavigationController navigationController;
  final GridSelectionController selectionController;
  final ScrollController rowsScrollController;
  final GridScrollVisibilityCoordinator visibilityCoordinator;
  final GlobalKey rowsViewportKey;
  final FocusNode rowsFocusNode;
  final String? selectedRowId;
  final GlobalKey Function(String rowId) rowKeyForId;
  final void Function(PointerMoveEvent event, List<String> visibleIds)
  onRowsPointerMove;
  final void Function(_HrPrenominaSummaryRow row, int rowIndex) onTapRow;
  final void Function(_HrPrenominaSummaryRow row, int rowIndex)
  onPrepareRowActions;
  final void Function(
    String rowId,
    List<String> visibleIds, {
    required bool additive,
  })
  onBeginDragSelection;
  final void Function(String rowId) onUpdateDragSelection;
  final VoidCallback onEndDragSelection;
  final Future<void> Function(
    TapDownDetails details,
    _HrPrenominaSummaryRow row,
    int rowIndex,
  )
  onRowContextMenu;
  final Future<void> Function(_HrPrenominaSummaryRow row) onOpenRow;
  final void Function(
    _HrPrenominaSummaryRow row,
    _HrPrenominaDraftStatus status,
  )
  onChangeStatus;
  final String? changingStatusEmployeeId;
  final GlobalKey<PopupMenuButtonState<_HrPrenominaDraftStatus>> Function(
    String,
  )
  statusMenuKey;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<int> onPageSizeChanged;
  final Future<void> Function() onOpenSelectedRow;
  final Future<void> Function() onClosePeriod;
  final Future<void> Function()? onPublishAll;
  final Future<void> Function() onExportCashEnvelopes;
  final ValueChanged<String> onSelectPeriod;
  final VoidCallback onEscape;
  final VoidCallback onOpenActiveCell;
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;
  final ValueChanged<String?> onHoverRowChanged;

  const _HrPrenominaWorkspace({
    required this.periodRows,
    required this.diagnostics,
    required this.search,
    required this.company,
    required this.incidencesOnly,
    required this.selectedStatuses,
    required this.hasFilters,
    required this.onSearch,
    required this.onCompany,
    required this.onIncidences,
    required this.onStatuses,
    required this.onClearFilters,
    required this.allRows,
    required this.rows,
    required this.totalRows,
    required this.selectedCount,
    required this.activePeriodLabel,
    required this.periodOptions,
    required this.isPeriodClosed,
    required this.publishedDraftCount,
    required this.pendingDraftCount,
    required this.hoveredRowId,
    required this.navigationController,
    required this.selectionController,
    required this.rowsScrollController,
    required this.visibilityCoordinator,
    required this.rowsViewportKey,
    required this.rowsFocusNode,
    required this.selectedRowId,
    required this.rowKeyForId,
    required this.onRowsPointerMove,
    required this.onTapRow,
    required this.onPrepareRowActions,
    required this.onBeginDragSelection,
    required this.onUpdateDragSelection,
    required this.onEndDragSelection,
    required this.onRowContextMenu,
    required this.onOpenRow,
    required this.onChangeStatus,
    required this.changingStatusEmployeeId,
    required this.statusMenuKey,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPageSizeChanged,
    required this.onOpenSelectedRow,
    required this.onClosePeriod,
    required this.onPublishAll,
    required this.onExportCashEnvelopes,
    required this.onSelectPeriod,
    required this.onEscape,
    required this.onOpenActiveCell,
    required this.hasActiveFilter,
    required this.onOpenFilter,
    required this.onHoverRowChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: GridKeyboardShell(
          navigationController: navigationController,
          focusNode: rowsFocusNode,
          onEscape: onEscape,
          onConfirm: onOpenActiveCell,
          onOpenActiveCell: onOpenActiveCell,
          onNavigated: (position) {
            if (position.zone != GridNavigationZone.grid) return;
            unawaited(
              visibilityCoordinator.ensureGridRowVisible(
                position.rowIndex,
                alignment: 0.5,
                allowSkipIfFullyVisible: false,
              ),
            );
          },
          child: GridEditableShell(
            topBar: _HrPrenominaModuleTopBar(
              rows: periodRows,
              totalRows: totalRows,
              selectedCount: selectedCount,
              activeCellLabel: null,
              activePeriodLabel: activePeriodLabel,
              periodOptions: periodOptions,
              isPeriodClosed: isPeriodClosed,
              publishedDraftCount: publishedDraftCount,
              pendingDraftCount: pendingDraftCount,
              onOpenSelectedRow: () => unawaited(onOpenSelectedRow()),
              onClosePeriod: () => unawaited(onClosePeriod()),
              onPublishAll: onPublishAll == null
                  ? null
                  : () => unawaited(onPublishAll!()),
              onExportCashEnvelopes: () => unawaited(onExportCashEnvelopes()),
              onSelectPeriod: onSelectPeriod,
            ),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 218,
                  child: _PrenominaFilters(
                    rows: periodRows,
                    diagnostics: diagnostics,
                    search: search,
                    company: company,
                    incidencesOnly: incidencesOnly,
                    statuses: selectedStatuses,
                    hasFilters: hasFilters,
                    onSearch: onSearch,
                    onCompany: onCompany,
                    onIncidences: onIncidences,
                    onStatuses: onStatuses,
                    onClear: onClearFilters,
                    hasActiveFilter: hasActiveFilter,
                    onOpenFilter: onOpenFilter,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PrenominaGridCaption(
                        count: totalRows,
                        selected: selectedCount,
                        filtered: hasFilters,
                      ),
                      Expanded(
                        child: _HrPrenominaGrid(
                          rows: rows,
                          diagnostics: diagnostics,
                          hoveredRowId: hoveredRowId,
                          selectedRowId: selectedRowId,
                          navigationController: navigationController,
                          selectionController: selectionController,
                          rowsScrollController: rowsScrollController,
                          visibilityCoordinator: visibilityCoordinator,
                          rowsViewportKey: rowsViewportKey,
                          rowKeyForId: rowKeyForId,
                          onRowsPointerMove: onRowsPointerMove,
                          onTapRow: onTapRow,
                          onPrepareRowActions: onPrepareRowActions,
                          onBeginDragSelection: onBeginDragSelection,
                          onUpdateDragSelection: onUpdateDragSelection,
                          onEndDragSelection: onEndDragSelection,
                          onRowContextMenu: onRowContextMenu,
                          onOpenRow: onOpenRow,
                          onChangeStatus: onChangeStatus,
                          isPeriodClosed: isPeriodClosed,
                          changingStatusEmployeeId: changingStatusEmployeeId,
                          statusMenuKey: statusMenuKey,
                          hasActiveFilter: hasActiveFilter,
                          onOpenFilter: onOpenFilter,
                          onHoverRowChanged: onHoverRowChanged,
                        ),
                      ),
                      _HrPrenominaGridFooter(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HrPrenominaGrid extends StatelessWidget {
  final bool isPeriodClosed;
  final Map<String, _PrenominaAttendanceDiagnostic> diagnostics;
  final List<_HrPrenominaSummaryRow> rows;
  final String? hoveredRowId;
  final String? selectedRowId;
  final GridNavigationController navigationController;
  final GridSelectionController selectionController;
  final ScrollController rowsScrollController;
  final GridScrollVisibilityCoordinator visibilityCoordinator;
  final GlobalKey rowsViewportKey;
  final GlobalKey Function(String rowId) rowKeyForId;
  final void Function(PointerMoveEvent event, List<String> visibleIds)
  onRowsPointerMove;
  final void Function(_HrPrenominaSummaryRow row, int rowIndex) onTapRow;
  final void Function(_HrPrenominaSummaryRow row, int rowIndex)
  onPrepareRowActions;
  final void Function(
    String rowId,
    List<String> visibleIds, {
    required bool additive,
  })
  onBeginDragSelection;
  final void Function(String rowId) onUpdateDragSelection;
  final VoidCallback onEndDragSelection;
  final Future<void> Function(_HrPrenominaSummaryRow row) onOpenRow;
  final void Function(
    _HrPrenominaSummaryRow row,
    _HrPrenominaDraftStatus status,
  )
  onChangeStatus;
  final String? changingStatusEmployeeId;
  final GlobalKey<PopupMenuButtonState<_HrPrenominaDraftStatus>> Function(
    String,
  )
  statusMenuKey;
  final Future<void> Function(
    TapDownDetails details,
    _HrPrenominaSummaryRow row,
    int rowIndex,
  )
  onRowContextMenu;
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;
  final ValueChanged<String?> onHoverRowChanged;

  const _HrPrenominaGrid({
    required this.isPeriodClosed,
    required this.rows,
    required this.diagnostics,
    required this.hoveredRowId,
    required this.selectedRowId,
    required this.navigationController,
    required this.selectionController,
    required this.rowsScrollController,
    required this.visibilityCoordinator,
    required this.rowsViewportKey,
    required this.rowKeyForId,
    required this.onRowsPointerMove,
    required this.onTapRow,
    required this.onPrepareRowActions,
    required this.onBeginDragSelection,
    required this.onUpdateDragSelection,
    required this.onEndDragSelection,
    required this.onOpenRow,
    required this.onChangeStatus,
    required this.changingStatusEmployeeId,
    required this.statusMenuKey,
    required this.onRowContextMenu,
    required this.hasActiveFilter,
    required this.onOpenFilter,
    required this.onHoverRowChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xDDF0E7FF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x66B084FF)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(1220, constraints.maxWidth),
                height: constraints.maxHeight,
                child: Column(
                  children: [
                    _HrPrenominaGridHeader(
                      hasActiveFilter: hasActiveFilter,
                      onOpenFilter: onOpenFilter,
                    ),
                    Expanded(
                      child: Listener(
                        onPointerMove: (event) => onRowsPointerMove(
                          event,
                          rows
                              .map((row) => row.employeeId)
                              .toList(growable: false),
                        ),
                        onPointerUp: (_) => onEndDragSelection(),
                        onPointerCancel: (_) => onEndDragSelection(),
                        child: Container(
                          key: rowsViewportKey,
                          child: SingleChildScrollView(
                            controller: rowsScrollController,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: math.max(
                                  0,
                                  constraints.maxHeight - 68,
                                ),
                              ),
                              child: Column(
                                children: [
                                  if (rows.isEmpty)
                                    const _HrPrenominaEmptyState()
                                  else
                                    for (
                                      var index = 0;
                                      index < rows.length;
                                      index++
                                    )
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          6,
                                          index == 0 ? 8 : 2,
                                          6,
                                          index == rows.length - 1 ? 8 : 2,
                                        ),
                                        child: KeyedSubtree(
                                          key: rowKeyForId(
                                            rows[index].employeeId,
                                          ),
                                          child: _HrPrenominaGridRow(
                                            key: visibilityCoordinator
                                                .keyForCell(
                                                  zone: GridNavigationZone.grid,
                                                  rowIndex: index,
                                                  columnIndex: 0,
                                                ),
                                            row: rows[index],
                                            diagnostic:
                                                diagnostics[rows[index]
                                                    .employeeId] ??
                                                const _PrenominaAttendanceDiagnostic(),
                                            statusMenuKey: statusMenuKey(
                                              rows[index].employeeId,
                                            ),
                                            statusEnabled:
                                                !isPeriodClosed &&
                                                changingStatusEmployeeId ==
                                                    null,
                                            statusSaving:
                                                changingStatusEmployeeId ==
                                                rows[index].employeeId,
                                            periodClosed: isPeriodClosed,
                                            onChangeStatus: (status) =>
                                                onChangeStatus(
                                                  rows[index],
                                                  status,
                                                ),
                                            rowIndex: index,
                                            hovered:
                                                hoveredRowId ==
                                                rows[index].employeeId,
                                            active:
                                                navigationController
                                                        .active
                                                        .zone ==
                                                    GridNavigationZone.grid &&
                                                navigationController
                                                        .active
                                                        .rowIndex ==
                                                    index,
                                            selected:
                                                selectedRowId ==
                                                    rows[index].employeeId ||
                                                selectionController.isSelected(
                                                  rows[index].employeeId,
                                                ),
                                            onTap: () =>
                                                onTapRow(rows[index], index),
                                            onOpen: () =>
                                                onOpenRow(rows[index]),
                                            onPrepareActionsMenu: () =>
                                                onPrepareRowActions(
                                                  rows[index],
                                                  index,
                                                ),
                                            onPrimaryPointerDown: (additive) =>
                                                onBeginDragSelection(
                                                  rows[index].employeeId,
                                                  rows
                                                      .map(
                                                        (item) =>
                                                            item.employeeId,
                                                      )
                                                      .toList(growable: false),
                                                  additive: additive,
                                                ),
                                            onDragEnter: () =>
                                                onUpdateDragSelection(
                                                  rows[index].employeeId,
                                                ),
                                            onPointerEnd: onEndDragSelection,
                                            onSecondaryTapDown: (details) =>
                                                onRowContextMenu(
                                                  details,
                                                  rows[index],
                                                  index,
                                                ),
                                            onHoverChanged: onHoverRowChanged,
                                          ),
                                        ),
                                      ),
                                ],
                              ),
                            ),
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
      },
    );
  }
}

class _HrPrenominaEmptyState extends StatelessWidget {
  const _HrPrenominaEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: const BoxDecoration(color: Color(0xDDF0E7FF)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F3FF).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x66B68CFF)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.payments_outlined,
              size: 34,
              color: Color(0xFFB68CFF),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sin coincidencias',
              style: TextStyle(
                color: Color(0xFF24103D),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajusta filtros o consolida fuentes RH para comenzar el borrador semanal de prenómina.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF6E47A8).withValues(alpha: 0.92),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrPrenominaGridRow extends StatelessWidget {
  final _PrenominaAttendanceDiagnostic diagnostic;
  final _HrPrenominaSummaryRow row;
  final int rowIndex;
  final bool hovered;
  final bool active;
  final bool selected;
  final VoidCallback onTap;
  final GlobalKey<PopupMenuButtonState<_HrPrenominaDraftStatus>> statusMenuKey;
  final bool statusEnabled;
  final bool statusSaving;
  final bool periodClosed;
  final ValueChanged<_HrPrenominaDraftStatus> onChangeStatus;
  final Future<void> Function() onOpen;
  final VoidCallback onPrepareActionsMenu;
  final ValueChanged<bool>? onPrimaryPointerDown;
  final VoidCallback? onDragEnter;
  final VoidCallback? onPointerEnd;
  final GestureTapDownCallback? onSecondaryTapDown;
  final ValueChanged<String?> onHoverChanged;

  const _HrPrenominaGridRow({
    super.key,
    required this.row,
    required this.diagnostic,
    required this.rowIndex,
    required this.hovered,
    required this.active,
    required this.selected,
    required this.onTap,
    required this.statusMenuKey,
    required this.statusEnabled,
    required this.statusSaving,
    required this.periodClosed,
    required this.onChangeStatus,
    required this.onOpen,
    required this.onPrepareActionsMenu,
    this.onPrimaryPointerDown,
    this.onDragEnter,
    this.onPointerEnd,
    this.onSecondaryTapDown,
    required this.onHoverChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = active || selected;
    final hoverOnly = hovered && !hasSelection;
    final rowBg = hasSelection
        ? const Color(0xFF9F6BFF).withValues(alpha: 0.18)
        : hoverOnly
        ? const Color(0xFFF6F0FF)
        : Colors.white;
    final hoverLift = hasSelection
        ? -1.4
        : hovered
        ? -1.15
        : 0.0;
    final hoverElevation = hasSelection
        ? 3.2
        : hovered
        ? 2.7
        : 0.5;

    return MouseRegion(
      onEnter: (_) {
        onHoverChanged(row.employeeId);
        onDragEnter?.call();
      },
      onExit: (_) => onHoverChanged(null),
      child: Listener(
        onPointerDown: (event) {
          if ((event.buttons & kPrimaryMouseButton) != 0) {
            // Selecting/scrolling the row on pointer-down can move the status
            // button before pointer-up and cancel its first click. The menu
            // prepares the selection itself once the click has completed.
            final statusBox = statusMenuKey.currentContext?.findRenderObject();
            if (statusBox is RenderBox &&
                (Offset.zero & statusBox.size).contains(
                  statusBox.globalToLocal(event.position),
                )) {
              return;
            }
            final pressed = HardwareKeyboard.instance.logicalKeysPressed;
            final additive =
                pressed.contains(LogicalKeyboardKey.controlLeft) ||
                pressed.contains(LogicalKeyboardKey.controlRight) ||
                pressed.contains(LogicalKeyboardKey.metaLeft) ||
                pressed.contains(LogicalKeyboardKey.metaRight);
            onPrimaryPointerDown?.call(additive);
          }
        },
        onPointerUp: (_) => onPointerEnd?.call(),
        onPointerCancel: (_) => onPointerEnd?.call(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onDoubleTap: () async => onOpen(),
            onSecondaryTapDown: onSecondaryTapDown,
            child: AnimatedContainer(
              duration: Duration.zero,
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, hoverLift, 0),
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                elevation: hoverElevation,
                color: rowBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: hasSelection
                        ? const Color(0xFF9F6BFF).withValues(alpha: 0.72)
                        : Colors.white.withValues(alpha: 0.0),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: _PrenominaGridColumns(
                    children: [
                      for (final column in _kPrenominaGridColumns)
                        column.id == 'acciones'
                            ? Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  color: hasSelection
                                      ? humanResourcesAreaTokens.surfaceTint
                                      : humanResourcesAreaTokens.primarySoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child:
                                    EditableRowActionsButton<
                                      _HrPrenominaRowAction
                                    >(
                                      tooltip: 'Acciones de prenómina',
                                      iconColor: hasSelection
                                          ? Colors.white
                                          : const Color(0xFF6E47A8),
                                      onBeforeOpen: onPrepareActionsMenu,
                                      entries: const [
                                        ContractMenuEntry(
                                          value: _HrPrenominaRowAction.open,
                                          label: 'Editar borrador',
                                          icon: Icons.payments_outlined,
                                        ),
                                      ],
                                      onSelected: (_) async => onOpen(),
                                    ),
                              )
                            : column.id == 'estado'
                            ? _PrenominaStatusMenu(
                                row: row,
                                menuKey: statusMenuKey,
                                enabled: statusEnabled,
                                saving: statusSaving,
                                periodClosed: periodClosed,
                                onOpened: onPrepareActionsMenu,
                                onSelected: onChangeStatus,
                              )
                            : _PrenominaRowValue(
                                row: row,
                                diagnostic: diagnostic,
                                column: column.id,
                                selected: selected,
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

class _PrenominaStatusMenu extends StatelessWidget {
  final _HrPrenominaSummaryRow row;
  final GlobalKey<PopupMenuButtonState<_HrPrenominaDraftStatus>> menuKey;
  final bool enabled;
  final bool saving;
  final bool periodClosed;
  final VoidCallback onOpened;
  final ValueChanged<_HrPrenominaDraftStatus> onSelected;

  const _PrenominaStatusMenu({
    required this.row,
    required this.menuKey,
    required this.enabled,
    required this.saving,
    required this.periodClosed,
    required this.onOpened,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = humanResourcesAreaTokens;
    return Center(
      key: ValueKey('prenomina-status-${row.employeeId}'),
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        child: PopupMenuButton<_HrPrenominaDraftStatus>(
          key: menuKey,
          enabled: enabled,
          requestFocus: true,
          tooltip: periodClosed
              ? 'Periodo cerrado · ${row.statusLabel}'
              : 'Cambiar estado de ${row.displayName}',
          position: PopupMenuPosition.under,
          color: tokens.fieldSurface.withValues(alpha: 1),
          borderRadius: BorderRadius.circular(999),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: tokens.border),
          ),
          onOpened: onOpened,
          onSelected: onSelected,
          itemBuilder: (_) => [
            for (final status in _HrPrenominaDraftStatus.values)
              PopupMenuItem(
                key: ValueKey('prenomina-status-option-${status.name}'),
                value: status,
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 20,
                      child: status == row.draftStatus
                          ? Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: tokens.onGlass,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(status.label, style: TextStyle(color: tokens.onGlass)),
                  ],
                ),
              ),
          ],
          child: _HrPrenominaStatusBadge(
            label: row.statusLabel,
            interactive: !periodClosed,
            saving: saving,
          ),
        ),
      ),
    );
  }
}

// Header and rows share the same column widths and gaps.
const _prenominaColumnWidths = <String, double>{
  'id': 45,
  'sueldo': 92,
  'asistencia': 108,
  'vacaciones': 105,
  'permisos': 105,
  'fiscal': 105,
  'flujo': 105,
  'total': 105,
  'estado': 118,
  'acciones': 64,
};

class _PrenominaGridColumns extends StatelessWidget {
  final List<Widget> children;
  const _PrenominaGridColumns({required this.children});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        if (_kPrenominaGridColumns[i].id == 'nombre')
          Expanded(child: children[i])
        else
          SizedBox(
            width: _prenominaColumnWidths[_kPrenominaGridColumns[i].id],
            child: children[i],
          ),
      ],
    ],
  );
}

class _HrPrenominaGridHeader extends StatelessWidget {
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;
  const _HrPrenominaGridHeader({
    required this.hasActiveFilter,
    required this.onOpenFilter,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Card(
      elevation: 0,
      color: humanResourcesAreaTokens.primarySoft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: _PrenominaGridColumns(
          children: [
            for (final column in _kPrenominaGridColumns)
              Tooltip(
                message: switch (column.id) {
                  'asistencia' =>
                    'Trabajados · Faltas · Retardos; horas de retardo y extra',
                  'vacaciones' => 'Pagadas · Disfrutadas · Reservadas (días)',
                  'permisos' =>
                    'Con goce · Sin goce · Incapacidad (días y horas)',
                  _ => column.label,
                },
                child: InkWell(
                  onTap:
                      [
                        'fiscal',
                        'flujo',
                        'total',
                        'acciones',
                      ].contains(column.id)
                      ? null
                      : () => onOpenFilter(column.id, column.label),
                  child: Column(
                    children: [
                      Text(
                        column.id == 'sueldo'
                            ? 'SUELDO SEMANAL'
                            : column.label.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: humanResourcesAreaTokens.primaryStrong,
                        ),
                      ),
                      if ([
                        'asistencia',
                        'vacaciones',
                        'permisos',
                      ].contains(column.id))
                        Text(
                          switch (column.id) {
                            'asistencia' => 'Trab · Falt · Ret',
                            'vacaciones' => 'Pag · Disf · Res',
                            _ => 'Goce · Sin · Incap',
                          },
                          style: TextStyle(
                            fontSize: 9,
                            color: humanResourcesAreaTokens.surfaceTint,
                          ),
                        ),
                      if (hasActiveFilter(column.id))
                        Icon(
                          Icons.filter_alt,
                          size: 12,
                          color: humanResourcesAreaTokens.primary,
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

class _PrenominaRowValue extends StatelessWidget {
  final _HrPrenominaSummaryRow row;
  final _PrenominaAttendanceDiagnostic diagnostic;
  final String column;
  final bool selected;
  const _PrenominaRowValue({
    required this.row,
    required this.diagnostic,
    required this.column,
    required this.selected,
  });
  Widget _value(String primary, [String? secondary]) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        primary,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: column == 'total' ? FontWeight.w900 : FontWeight.w700,
          color: humanResourcesAreaTokens.primaryStrong,
        ),
      ),
      if (secondary != null)
        Text(
          secondary,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: humanResourcesAreaTokens.surfaceTint,
          ),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => switch (column) {
    'id' => _value(row.employeeId),
    'nombre' => Tooltip(
      message: '${row.displayName}\n${row.empresa}',
      child: Row(
        children: [
          if (_prenominaHasIncidences(row, diagnostic))
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Tooltip(
                message: 'Con incidencias · revisar detalle',
                child: Icon(
                  Icons.info_outline,
                  size: 15,
                  color: humanResourcesAreaTokens.surfaceTint,
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: humanResourcesAreaTokens.primaryStrong,
                  ),
                ),
                Text(
                  row.empresa.isEmpty ? 'Empresa pendiente' : row.empresa,
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
        ],
      ),
    ),
    'sueldo' => _value(_formatPrenominaMoney(row.salaryWeekly)),
    'asistencia' => _value(
      '${diagnostic.worked} · ${diagnostic.absent} · ${diagnostic.late}',
      '${_formatPrenominaMinutesAsHourRatio(row.lateMinutesSum)}${row.overtimeMinutesSum > 0 ? ' · +${_formatPrenominaMinutesAsHourRatio(row.overtimeMinutesSum)}' : ''}',
    ),
    'vacaciones' => _value(
      '${_prenominaCount(row.vacationPaidDays)} · ${_prenominaCount(row.vacationEnjoyedDays)} · ${_prenominaCount(row.vacationReservedDays)}',
    ),
    'permisos' => _value(
      '${_prenominaCount(row.permissionWithPayDays)} · ${_prenominaCount(row.permissionWithoutPayDays)} · ${_prenominaCount(row.disabilityDays)}',
      row.permissionWithPayHours +
                  row.permissionWithoutPayHours +
                  row.disabilityHours ==
              0
          ? null
          : '${_prenominaCount(row.permissionWithPayHours)} · ${_prenominaCount(row.permissionWithoutPayHours)} · ${_prenominaCount(row.disabilityHours)} h',
    ),
    'fiscal' => _value(
      _formatPrenominaMoneyZero(row.fiscalDepositedAmount),
      row.fiscalDeliveryLabel,
    ),
    'flujo' => _value(
      _formatPrenominaMoneyZero(row.flowDeliveryAmount),
      row.fiscalCashAmount > 0
          ? 'Cheque ${_formatPrenominaMoneyZero(row.fiscalCashAmount)}'
          : null,
    ),
    'total' => _value(
      _formatPrenominaMoneyZero(row.weeklyPaymentVisibleAmount),
    ),
    'estado' => Center(child: _HrPrenominaStatusBadge(label: row.statusLabel)),
    _ => const SizedBox.shrink(),
  };
}
