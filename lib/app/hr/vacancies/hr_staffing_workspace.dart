import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/archetypes/grid_editable/grid_editable.dart';
import '../../shared/ui_contract_core/dialogs/contract_menu_surface.dart';
import '../../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../../shared/ui_contract_core/theme/contract_buttons.dart';
import '../../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../../shared/ui_contract_core/theme/editable_hover_capsule.dart';
import '../../shared/ui_contract_core/theme/glass_styles.dart';
import '../personnel/hr_job_positions.dart';
import '../human_resources_theme.dart';
import 'hr_staffing.dart';

/// Personal's read-grid / expediente capture flow, using the shared
/// Entradas/Salidas keyboard, selection, filters and scaled-row contracts.
class HrStaffingWorkspace extends StatefulWidget {
  final HrStaffingSnapshot snapshot;
  final Future<void> Function(List<HrStaffingTarget>)? onEdit;
  final Widget pendingButton;
  const HrStaffingWorkspace({
    super.key,
    required this.snapshot,
    this.onEdit,
    required this.pendingButton,
  });
  @override
  State<HrStaffingWorkspace> createState() => _HrStaffingWorkspaceState();
}

class _HrStaffingWorkspaceState extends State<HrStaffingWorkspace> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _nav = GridNavigationController();
  final _selection = GridSelectionController();
  final _drag = DragSelectionController();
  final _scroll = ScrollController();
  final _visibility = GridScrollVisibilityCoordinator();
  final _viewport = GlobalKey();
  final _keys = <String, GlobalKey>{};
  Set<String> _companies = {}, _positions = {};
  bool _onlyPending = false;
  String? _hovered;
  List<HrStaffingTarget> get _rows => widget.snapshot.targets
      .where(
        (r) =>
            (_companies.isEmpty || _companies.contains(r.company)) &&
            (_positions.isEmpty || _positions.contains(r.position)) &&
            (!_onlyPending || r.vacant > 0) &&
            hrJobPositionKey(
              '${r.company} ${r.position}',
            ).contains(hrJobPositionKey(_search.text)),
      )
      .toList();
  @override
  void initState() {
    super.initState();
    _selection.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant HrStaffingWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selection.selectedIds.retainAll(_rows.map((row) => row.id));
    _selection.anchorIndex = null;
  }

  @override
  void dispose() {
    _selection.removeListener(_rebuild);
    _selection.dispose();
    _nav.dispose();
    _drag.dispose();
    _scroll.dispose();
    _focus.dispose();
    _search.dispose();
    super.dispose();
  }

  void _clearSelection() {
    _selection.clear();
    _focus.requestFocus();
  }

  void _select(HrStaffingTarget row, int index) {
    _selection.handlePointerSelection(
      id: row.id,
      rowIndex: index,
      resolveRangeIds: (start, end) =>
          _rows.getRange(start, end + 1).map((r) => r.id),
      visibilityCoordinator: _visibility,
    );
    _nav.focusGridCell(rowIndex: index, columnIndex: 2);
    _focus.requestFocus();
  }

  void _prepare(HrStaffingTarget row, int index) {
    if (!_selection.isSelected(row.id)) {
      _selection.selectSingle(row.id, rowIndex: index);
    }
    _nav.focusGridCell(rowIndex: index, columnIndex: 2);
  }

  Future<void> _edit([HrStaffingTarget? row, int? index]) async {
    if (row != null) _prepare(row, index!);
    final rows = _rows.where((r) => _selection.isSelected(r.id)).toList();
    if (rows.isEmpty &&
        _rows.isNotEmpty &&
        _nav.active.zone == GridNavigationZone.grid) {
      rows.add(_rows[_nav.active.rowIndex.clamp(0, _rows.length - 1)]);
    }
    if (rows.isNotEmpty) await widget.onEdit?.call(rows);
  }

  List<ContractMenuEntry<String>> get _actions => [
    ContractMenuEntry(
      value: 'edit',
      label: _selection.selectedIds.length > 1
          ? 'Editar plantillas seleccionadas'
          : 'Editar plantilla',
      icon: Icons.edit_outlined,
    ),
  ];
  Future<void> _context(
    TapDownDetails details,
    HrStaffingTarget row,
    int index,
  ) async {
    if (widget.onEdit == null) return;
    _prepare(row, index);
    final action = await showEditableGridContextMenu<String>(
      context: context,
      globalPosition: details.globalPosition,
      entries: _actions,
    );
    if (action != null && mounted) await _edit();
  }

  Future<void> _filter(bool company) async {
    final options =
        (company
                ? widget.snapshot.targets.map((r) => r.company)
                : widget.snapshot.targets.map((r) => r.position))
            .toSet()
            .toList()
          ..sort();
    final selected = company ? _companies : _positions;
    final state = await showDialog<GridFilterState>(
      context: context,
      builder: (_) => AreaThemeScope(
        tokens: humanResourcesAreaTokens,
        child: GridFilterDialog(
          title: company ? 'Empresa' : 'Puesto',
          keyboardNavigation: true,
          initialState: GridFilterState(
            options: [
              for (final name in options)
                GridFilterOption(
                  value: name,
                  label: name,
                  selected: selected.contains(name),
                ),
            ],
          ),
        ),
      ),
    );
    if (state != null && mounted) {
      setState(() {
        if (company) {
          _companies = state.selectedValues;
        } else {
          _positions = state.selectedValues;
        }
      });
      _clearSelection();
    }
  }

  List<MarqueeRowHit> _hits() {
    final box = _viewport.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return [];
    final hits = <MarqueeRowHit>[];
    final rows = _rows;
    for (var i = 0; i < rows.length; i++) {
      final child =
          _keys[rows[i].id]?.currentContext?.findRenderObject() as RenderBox?;
      if (child != null && child.attached) {
        hits.add(
          MarqueeRowHit(
            id: rows[i].id,
            rowIndex: i,
            rect:
                box.globalToLocal(child.localToGlobal(Offset.zero)) &
                child.size,
          ),
        );
      }
    }
    return hits;
  }

  void _navigated(GridCellPosition p) {
    setState(() {});
    if (p.zone != GridNavigationZone.grid) return;
    // Reveal lazy rows first, then let the shared coordinator align the cell.
    if (_scroll.hasClients) {
      final y = p.rowIndex * 70.0;
      if (y < _scroll.offset ||
          y > _scroll.offset + _scroll.position.viewportDimension - 70) {
        _scroll.jumpTo(y.clamp(0, _scroll.position.maxScrollExtent));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _visibility.ensureGridRowVisible(p.rowIndex, alignment: .5);
    });
  }

  Widget _rowFrame(
    List<Widget> cells, {
    bool selected = false,
    bool active = false,
  }) {
    final t = AreaThemeScope.of(context);
    const widths = [270.0, 320.0, 155.0, 140.0, 145.0, 90.0];
    return Card(
      margin: EdgeInsets.zero,
      color: selected ? t.surfaceTint.withValues(alpha: .6) : t.glassSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: active ? t.accent : t.border.withValues(alpha: .22),
          width: active ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final total = widths.reduce((a, b) => a + b);
            final scale = constraints.maxWidth > total
                ? constraints.maxWidth / total
                : 1.0;
            return ContractGridScaledRow(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < cells.length; i++)
                    SizedBox(
                      width: widths[i] * scale,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: cells[i],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context), rows = _rows;
    _nav.configure(
      insertColumnCount: 0,
      gridColumnCount: 6,
      rowCount: rows.length,
    );
    Widget text(String s, {bool strong = false}) => Text(
      s,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: t.onGlass,
        fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
      ),
    );
    Widget header(String s, [bool? company]) => Row(
      children: [
        if (company != null)
          IconButton(
            tooltip: 'Filtrar $s',
            onPressed: () => _filter(company),
            icon: Icon(
              Icons.filter_alt_outlined,
              color: (company ? _companies : _positions).isNotEmpty
                  ? t.onGlass
                  : t.accent,
              size: 20,
            ),
          ),
        Expanded(child: text(s, strong: true)),
      ],
    );
    return GridKeyboardShell(
      navigationController: _nav,
      focusNode: _focus,
      onNavigated: _navigated,
      onConfirm: () => unawaited(_edit()),
      onOpenActiveCell: () => unawaited(_edit()),
      onEscape: _clearSelection,
      child: ContractGlassCard(
        padding: const EdgeInsets.all(18),
        child: GridEditableShell(
          topBar: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Vacantes',
                    style: TextStyle(
                      color: t.onGlass,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${widget.snapshot.vacancyCount} por cubrir',
                    style: TextStyle(
                      color: t.badgeText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  widget.pendingButton,
                  ElevatedButton.icon(
                    style: contractPrimaryButtonStyle(context),
                    onPressed: widget.onEdit == null
                        ? null
                        : () => widget.onEdit!([]),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar plantilla'),
                  ),
                  if (_selection.selectedIds.isNotEmpty)
                    OutlinedButton.icon(
                      style: contractSecondaryButtonStyle(context),
                      onPressed: widget.onEdit == null ? null : () => _edit(),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(
                        'Editar ${_selection.selectedIds.length} seleccionadas',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 340,
                    child: TextField(
                      key: const ValueKey('staffingSearch'),
                      controller: _search,
                      style: TextStyle(color: t.onGlass),
                      onChanged: (_) {
                        _selection.clear();
                        setState(() {});
                      },
                      decoration: contractGlassFieldDecoration(
                        context,
                        hintText: 'Buscar empresa o puesto',
                        prefixIcon: Icon(Icons.search, color: t.accent),
                      ),
                    ),
                  ),
                  FilterChip(
                    label: const Text('Solo por cubrir'),
                    selected: _onlyPending,
                    selectedColor: t.surfaceTint,
                    backgroundColor: t.fieldSurface,
                    labelStyle: TextStyle(color: t.onGlass),
                    checkmarkColor: t.onGlass,
                    onSelected: (v) {
                      setState(() => _onlyPending = v);
                      _selection.clear();
                    },
                  ),
                  if (_companies.isNotEmpty || _positions.isNotEmpty)
                    TextButton(
                      style: contractSecondaryButtonStyle(context),
                      onPressed: () {
                        setState(() {
                          _companies = {};
                          _positions = {};
                        });
                        _clearSelection();
                      },
                      child: const Text('Limpiar filtros'),
                    ),
                ],
              ),
              if (widget.snapshot.unassignedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '${widget.snapshot.unassignedCount} colaboradores activos aún no tienen puesto asignado en Personal.',
                    style: TextStyle(color: t.badgeText),
                  ),
                ),
              const SizedBox(height: 14),
              _rowFrame([
                header('EMPRESA', true),
                header('PUESTO', false),
                header('REQUERIDOS'),
                header('ACTIVOS'),
                header('POR CUBRIR'),
                header('ACCIONES'),
              ]),
            ],
          ),
          body: rows.isEmpty
              ? Center(
                  child: text(
                    widget.snapshot.targets.isEmpty
                        ? 'Agrega la plantilla necesaria por empresa y puesto.'
                        : 'No hay plantillas con esos filtros.',
                  ),
                )
              : MarqueeSelectionOverlay(
                  key: _viewport,
                  controller: _drag,
                  selectionColor: t.accent,
                  scrollController: _scroll,
                  resolveRows: _hits,
                  onSelectionChanged: (hits) {
                    if (hits.isNotEmpty) {
                      _selection.selectRange(
                        hits.map((h) => h.id),
                        anchorRowIndex: hits.first.rowIndex,
                      );
                    }
                  },
                  child: ListView.separated(
                    controller: _scroll,
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final row = rows[index],
                          selected = _selection.isSelected(row.id);
                      final active =
                          _nav.active.zone == GridNavigationZone.grid &&
                          _nav.active.rowIndex == index;
                      return SizedBox(
                        height: 62,
                        child: KeyedSubtree(
                          key: _keys.putIfAbsent(row.id, GlobalKey.new),
                          child: GestureDetector(
                            key: _visibility.keyForCell(
                              zone: GridNavigationZone.grid,
                              rowIndex: index,
                              columnIndex: 0,
                            ),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _select(row, index),
                            onSecondaryTapDown: (d) => _context(d, row, index),
                            child: _rowFrame(
                              [
                                text(row.company, strong: true),
                                text(row.position),
                                MouseRegion(
                                  onEnter: (_) =>
                                      setState(() => _hovered = row.id),
                                  onExit: (_) =>
                                      setState(() => _hovered = null),
                                  child: ContractEditableHoverCapsule(
                                    hovered:
                                        _hovered == row.id &&
                                        widget.onEdit != null,
                                    selectedContext: selected,
                                    padding: const EdgeInsets.all(8),
                                    child: InkWell(
                                      key: ValueKey('staffing-edit-${row.id}'),
                                      onTap: widget.onEdit == null
                                          ? null
                                          : () => _edit(row, index),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: text(
                                              '${row.requiredCount}',
                                              strong: true,
                                            ),
                                          ),
                                          Icon(
                                            Icons.edit_outlined,
                                            color: t.accent,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                text('${row.filled}'),
                                text('${row.vacant}', strong: row.vacant > 0),
                                AnchoredActionSlot(
                                  width: 74,
                                  trailingWidth: 38,
                                  leading: const SizedBox.shrink(),
                                  trailing: SizedBox(
                                    height: 40,
                                    child: EditableRowActionsButton<String>(
                                      entries: widget.onEdit == null
                                          ? []
                                          : _actions,
                                      iconColor: t.accent,
                                      onBeforeOpen: () => _prepare(row, index),
                                      onSelected: (_) => _edit(),
                                    ),
                                  ),
                                ),
                              ],
                              selected: selected,
                              active: active,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          footer: Text(
            '${rows.length} plantillas · ${_selection.selectedIds.length} seleccionadas',
            style: TextStyle(color: t.badgeText),
          ),
        ),
      ),
    );
  }
}
