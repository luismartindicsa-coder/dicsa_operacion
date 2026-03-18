import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/archetypes/auxiliary_surfaces/auxiliary_surfaces.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'inventory_movements_grid.dart';

const double _kTrDateColW = 92;
const double _kTrShiftColW = 96;
const double _kTrSourceColW = 110;
const double _kTrCommercialColW = 250;
const double _kTrOutputColW = 120;
const double _kTrUnitsColW = 140;
const double _kTrInputColW = 120;
const double _kTrNotesColW = 260;
const double _kTrActionsColW = 180;
const double _kTrCellGap = 8;
const double _kTrActionsGap = 10;
const double _kTrActionButtonW = 34;
const Color _kTrFilterAccent = Color(0xFF5D7F9E);
const Color _kTrFilterAccentSoft = Color(0xFFDCE7F2);
const double _kTrFixedColsW =
    _kTrDateColW +
    _kTrShiftColW +
    _kTrSourceColW +
    _kTrCommercialColW +
    _kTrOutputColW +
    _kTrUnitsColW +
    _kTrInputColW +
    _kTrActionsColW +
    (_kTrCellGap * 7) +
    _kTrActionsGap;

double _trNotesColWFor(double availableWidth) =>
    math.max(_kTrNotesColW, availableWidth - _kTrFixedColsW);

double _trTableContentWFor(double availableWidth) =>
    _kTrFixedColsW + _trNotesColWFor(availableWidth);

class InventoryTransformationGrid extends StatefulWidget {
  final String sourceGeneralCode;
  final String title;
  final IconData metricIcon;
  final Future<void> Function()? onChanged;
  final ValueChanged<InventoryGridTopBarData>? onTopBarChanged;

  const InventoryTransformationGrid({
    super.key,
    required this.sourceGeneralCode,
    required this.title,
    required this.metricIcon,
    this.onChanged,
    this.onTopBarChanged,
  });

  @override
  State<InventoryTransformationGrid> createState() =>
      _InventoryTransformationGridState();
}

class _InventoryTransformationGridState
    extends State<InventoryTransformationGrid> {
  final SupabaseClient supa = Supabase.instance.client;
  final FocusNode _insertFocusNode = FocusNode(
    debugLabel: 'transformation_insert_row_focus',
  );
  final FocusNode _rowsFocusNode = FocusNode(
    debugLabel: 'transformation_rows_focus',
  );

  bool _loading = true;
  bool _saving = false;
  bool _exporting = false;
  String? _generalMaterialId;
  List<_CommercialMaterialV2> _commercialOptions = <_CommercialMaterialV2>[];
  List<_TransformationRowVm> _rows = <_TransformationRowVm>[];

  DateTime _opDate = DateUtils.dateOnly(DateTime.now());
  String _shift = 'DAY';
  String _sourceMode = 'MIXED';
  String? _commercialId;
  final TextEditingController _inputKgC = TextEditingController();
  final TextEditingController _outputKgC = TextEditingController();
  final TextEditingController _unitsC = TextEditingController();
  final TextEditingController _notesC = TextEditingController();
  final FocusNode _dateFocusNode = FocusNode();
  final FocusNode _shiftFocusNode = FocusNode();
  final FocusNode _sourceModeFocusNode = FocusNode();
  final FocusNode _commercialFocusNode = FocusNode();
  final FocusNode _outputKgFocusNode = FocusNode();
  final FocusNode _unitsFocusNode = FocusNode();
  final FocusNode _inputKgFocusNode = FocusNode();
  final FocusNode _notesFocusNode = FocusNode();
  bool _hoverInsertAddButton = false;
  bool _bulkDeleting = false;
  bool _dragSelectingRows = false;
  int? _dragSelectionAnchorIndex;
  final Set<String> _selectedRowKeys = <String>{};
  final Map<String, GlobalKey<_TransformationDataRowState>> _rowKeys =
      <String, GlobalKey<_TransformationDataRowState>>{};
  final Map<String, Set<String>> _columnValueFilters = <String, Set<String>>{};
  final Map<String, DateTimeRange> _columnDateRangeFilters =
      <String, DateTimeRange>{};
  int? _selectedRowIndex;
  int? _hoveredRowIndex;
  int _activeGridColumn = 0;
  int _activeInsertColumn = 0;

  @override
  void initState() {
    super.initState();
    _insertFocusNode.addListener(_syncInsertRowFocusState);
    _rowsFocusNode.addListener(_syncInsertRowFocusState);
    _outputKgFocusNode.addListener(_syncInsertRowFocusState);
    _unitsFocusNode.addListener(_syncInsertRowFocusState);
    _inputKgFocusNode.addListener(_syncInsertRowFocusState);
    _notesFocusNode.addListener(_syncInsertRowFocusState);
    unawaited(_loadAll());
  }

  @override
  void dispose() {
    _insertFocusNode.removeListener(_syncInsertRowFocusState);
    _rowsFocusNode.removeListener(_syncInsertRowFocusState);
    _outputKgFocusNode.removeListener(_syncInsertRowFocusState);
    _unitsFocusNode.removeListener(_syncInsertRowFocusState);
    _inputKgFocusNode.removeListener(_syncInsertRowFocusState);
    _notesFocusNode.removeListener(_syncInsertRowFocusState);
    _insertFocusNode.dispose();
    _rowsFocusNode.dispose();
    _inputKgC.dispose();
    _outputKgC.dispose();
    _unitsC.dispose();
    _notesC.dispose();
    _dateFocusNode.dispose();
    _shiftFocusNode.dispose();
    _sourceModeFocusNode.dispose();
    _commercialFocusNode.dispose();
    _outputKgFocusNode.dispose();
    _unitsFocusNode.dispose();
    _inputKgFocusNode.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  void _syncInsertRowFocusState() {
    if (!mounted) return;
    setState(() {});
  }

  void _setActiveInsertColumn(int value, {bool requestFocus = true}) {
    final normalized = ((value % 9) + 9) % 9;
    if (mounted) {
      setState(() => _activeInsertColumn = normalized);
    } else {
      _activeInsertColumn = normalized;
    }
    if (!requestFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (_activeInsertColumn) {
        case 4:
          FocusScope.of(context).requestFocus(_outputKgFocusNode);
          break;
        case 5:
          FocusScope.of(context).requestFocus(_unitsFocusNode);
          break;
        case 6:
          FocusScope.of(context).requestFocus(_inputKgFocusNode);
          break;
        case 7:
          FocusScope.of(context).requestFocus(_notesFocusNode);
          break;
        default:
          FocusManager.instance.primaryFocus?.unfocus();
          _insertFocusNode.requestFocus();
      }
    });
  }

  void _moveInsertColumn(int delta) =>
      _setActiveInsertColumn(_activeInsertColumn + delta);

  bool get _isInsertTextFocused =>
      _outputKgFocusNode.hasFocus ||
      _unitsFocusNode.hasFocus ||
      _inputKgFocusNode.hasFocus ||
      _notesFocusNode.hasFocus;

  bool get _insertRowActive =>
      _insertFocusNode.hasFocus ||
      _outputKgFocusNode.hasFocus ||
      _unitsFocusNode.hasFocus ||
      _inputKgFocusNode.hasFocus ||
      _notesFocusNode.hasFocus;

  List<_TransformationRowVm> get _filteredRows =>
      _rows.where((row) => _matchesFilters(row)).toList();

  void _selectRow(int index, {bool requestFocus = true}) {
    final visibleRows = _filteredRows;
    if (visibleRows.isEmpty) return;
    final normalized = index.clamp(0, visibleRows.length - 1);
    final rowKey = visibleRows[normalized].selectionKey;
    if (mounted) {
      setState(() {
        _selectedRowIndex = normalized;
        _selectedRowKeys
          ..clear()
          ..add(rowKey);
      });
    } else {
      _selectedRowIndex = normalized;
      _selectedRowKeys
        ..clear()
        ..add(rowKey);
    }
    _notifyTopBar();
    if (!requestFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      _rowsFocusNode.requestFocus();
    });
  }

  void _moveSelectedRow(int delta) {
    if (_filteredRows.isEmpty) return;
    _selectRow((_selectedRowIndex ?? 0) + delta);
  }

  bool _isAdditiveSelectionPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  void _toggleRowSelection(int index, {required bool additive}) {
    final visibleRows = _filteredRows;
    if (visibleRows.isEmpty) return;
    final normalized = index.clamp(0, visibleRows.length - 1);
    final rowKey = visibleRows[normalized].selectionKey;
    setState(() {
      if (!additive) {
        _selectedRowIndex = normalized;
        _selectedRowKeys
          ..clear()
          ..add(rowKey);
        return;
      }
      if (_selectedRowKeys.contains(rowKey)) {
        if (_selectedRowKeys.length == 1) {
          _selectedRowIndex = normalized;
          return;
        }
        _selectedRowKeys.remove(rowKey);
        final fallbackKey = _selectedRowKeys.last;
        _selectedRowIndex = visibleRows.indexWhere(
          (row) => row.selectionKey == fallbackKey,
        );
      } else {
        _selectedRowKeys.add(rowKey);
        _selectedRowIndex = normalized;
      }
    });
    _notifyTopBar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      _rowsFocusNode.requestFocus();
    });
  }

  Future<void> _deleteSelectedRows() async {
    if (_selectedRowKeys.isEmpty || _bulkDeleting) return;
    final selectedRows = _rows
        .where((row) => _selectedRowKeys.contains(row.selectionKey))
        .toList();
    if (selectedRows.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar selección'),
        content: Text(
          '¿Eliminar ${selectedRows.length} registro${selectedRows.length == 1 ? '' : 's'} de transformación?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _bulkDeleting = true);
    try {
      for (final row in selectedRows) {
        await supa
            .from('material_transformation_runs_v2')
            .delete()
            .eq('id', row.runId);
      }
      if (!mounted) return;
      setState(() {
        _selectedRowKeys.clear();
        _selectedRowIndex = null;
      });
      _notifyTopBar();
      await _loadRows();
      _notifyTopBar();
      await widget.onChanged?.call();
      _toast('Transformaciones eliminadas');
    } on PostgrestException catch (e) {
      _toast(
        _friendlyPostgrestMessage(
          e,
          fallbackAction: 'No se pudo eliminar la selección.',
        ),
      );
    } catch (e) {
      _toast('No se pudo eliminar selección: $e');
    } finally {
      if (mounted) setState(() => _bulkDeleting = false);
    }
  }

  Future<void> _openRowContextMenu(
    _TransformationRowVm row,
    Offset globalPosition,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final selectedStates = _selectedRowStates();
    final anyEditing = selectedStates.any((state) => state.isEditing);
    final multiSelection = _selectedRowKeys.length > 1;
    const menuTextStyle = TextStyle(
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
      color: Color(0xFF223D5A),
    );
    final media = MediaQuery.of(context).size;
    final action = await showMenu<String>(
      context: context,
      color: const Color(0xFFF3F8FD),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        media.width - globalPosition.dx,
        media.height - globalPosition.dy,
      ),
      items: [
        if (multiSelection && !anyEditing)
          const PopupMenuItem<String>(
            value: 'multi_edit',
            child: Text('EDITAR SELECCIÓN', style: menuTextStyle),
          ),
        if (multiSelection && anyEditing)
          const PopupMenuItem<String>(
            value: 'multi_save',
            child: Text('GUARDAR SELECCIÓN', style: menuTextStyle),
          ),
        if (multiSelection && anyEditing)
          const PopupMenuItem<String>(
            value: 'multi_cancel',
            child: Text('CANCELAR EDICIÓN', style: menuTextStyle),
          ),
        if (!multiSelection && !anyEditing)
          const PopupMenuItem<String>(
            value: 'edit',
            child: Text('EDITAR', style: menuTextStyle),
          ),
        if (!multiSelection && anyEditing)
          const PopupMenuItem<String>(
            value: 'save',
            child: Text('GUARDAR', style: menuTextStyle),
          ),
        if (!multiSelection && anyEditing)
          const PopupMenuItem<String>(
            value: 'cancel',
            child: Text('CANCELAR', style: menuTextStyle),
          ),
        const PopupMenuDivider(),
        if (multiSelection && _editingRowStates().isNotEmpty)
          const PopupMenuItem<String>(
            value: 'multi_delete',
            child: Text('ELIMINAR SELECCIÓN', style: menuTextStyle),
          )
        else
          PopupMenuItem<String>(
            value: 'delete',
            child: Text(
              multiSelection ? 'ELIMINAR SELECCIÓN' : 'ELIMINAR',
              style: menuTextStyle,
            ),
          ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _editRow(row);
        return;
      case 'save':
        await Future.wait(
          selectedStates.map((state) => state.saveFromKeyboard()),
        );
        _notifyTopBar();
        return;
      case 'cancel':
        for (final state in selectedStates) {
          state.cancelEditingFromKeyboard();
        }
        _notifyTopBar();
        return;
      case 'multi_edit':
        for (final state in selectedStates) {
          state.startEditingFromKeyboard();
        }
        setState(() => _activeGridColumn = 0);
        _notifyTopBar();
        return;
      case 'multi_save':
        await Future.wait(
          _editingRowStates().map((state) => state.saveFromKeyboard()),
        );
        _notifyTopBar();
        return;
      case 'multi_cancel':
        for (final state in _editingRowStates()) {
          state.cancelEditingFromKeyboard();
        }
        _notifyTopBar();
        return;
      case 'multi_delete':
        await _deleteSelectedRows();
        return;
      case 'delete':
        await _deleteRow(row);
        return;
    }
  }

  void _focusRowsFromInsert() {
    if (_filteredRows.isEmpty) return;
    _selectRow(_selectedRowIndex ?? 0);
  }

  void _focusInsertFromRows() {
    FocusManager.instance.primaryFocus?.unfocus();
    _insertFocusNode.requestFocus();
  }

  void _clearRowSelection({bool notifyTopBar = true}) {
    if (_selectedRowKeys.isEmpty && _selectedRowIndex == null) return;
    setState(() {
      _selectedRowKeys.clear();
      _selectedRowIndex = null;
      _hoveredRowIndex = null;
    });
    if (notifyTopBar) _notifyTopBar();
  }

  GlobalKey<_TransformationDataRowState> _rowKey(String selectionKey) {
    return _rowKeys.putIfAbsent(
      selectionKey,
      () => GlobalKey<_TransformationDataRowState>(
        debugLabel: 'tr_row_$selectionKey',
      ),
    );
  }

  _TransformationDataRowState? _selectedRowState() {
    final visibleRows = _filteredRows;
    final index = _selectedRowIndex;
    if (index == null || index < 0 || index >= visibleRows.length) return null;
    return _rowKeys[visibleRows[index].selectionKey]?.currentState;
  }

  List<_TransformationDataRowState> _selectedRowStates() {
    final states = <_TransformationDataRowState>[];
    for (final row in _filteredRows) {
      if (!_selectedRowKeys.contains(row.selectionKey)) continue;
      final state = _rowKeys[row.selectionKey]?.currentState;
      if (state != null) states.add(state);
    }
    return states;
  }

  List<_TransformationDataRowState> _editingRowStates() {
    return _selectedRowStates().where((state) => state.isEditing).toList();
  }

  void _moveGridColumn(int delta) {
    _activeGridColumn = ((_activeGridColumn + delta) % 8 + 8) % 8;
    if (!mounted) return;
    setState(() {});
    _selectedRowState()?.focusTextIfNeeded(_activeGridColumn);
    _notifyTopBar();
  }

  int? _rowIndexAtGlobalPosition(Offset globalPosition) {
    final visibleRows = _filteredRows;
    for (var i = 0; i < visibleRows.length; i++) {
      final key = _rowKeys[visibleRows[i].selectionKey];
      final context = key?.currentContext;
      if (context == null) continue;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final origin = box.localToGlobal(Offset.zero);
      final rect = origin & box.size;
      if (rect.contains(globalPosition)) return i;
    }
    return null;
  }

  void _selectDraggedRange(int currentIndex) {
    final anchor = _dragSelectionAnchorIndex;
    final visibleRows = _filteredRows;
    if (anchor == null || visibleRows.isEmpty) return;
    final start = math.min(anchor, currentIndex);
    final end = math.max(anchor, currentIndex);
    setState(() {
      _selectedRowIndex = currentIndex;
      _selectedRowKeys
        ..clear()
        ..addAll(
          visibleRows.sublist(start, end + 1).map((row) => row.selectionKey),
        );
    });
    _notifyTopBar();
  }

  void _handleRowsPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse ||
        event.buttons != kPrimaryButton) {
      return;
    }
    if (_isAdditiveSelectionPressed()) return;
    final rowIndex = _rowIndexAtGlobalPosition(event.position);
    if (rowIndex == null) return;
    _dragSelectingRows = true;
    _dragSelectionAnchorIndex = rowIndex;
    _selectDraggedRange(rowIndex);
  }

  void _handleRowsPointerMove(PointerMoveEvent event) {
    if (!_dragSelectingRows) return;
    final rowIndex = _rowIndexAtGlobalPosition(event.position);
    if (rowIndex == null) return;
    _selectDraggedRange(rowIndex);
  }

  void _finishRowsPointerSelection() {
    _dragSelectingRows = false;
    _dragSelectionAnchorIndex = null;
  }

  bool _caretAtStart(TextEditingController c, FocusNode f) {
    if (!f.hasFocus) return false;
    final s = c.selection;
    return s.isValid &&
        s.isCollapsed &&
        s.baseOffset == 0 &&
        s.extentOffset == 0;
  }

  bool _caretAtEnd(TextEditingController c, FocusNode f) {
    if (!f.hasFocus) return false;
    final s = c.selection;
    final end = c.text.length;
    return s.isValid &&
        s.isCollapsed &&
        s.baseOffset == end &&
        s.extentOffset == end;
  }

  Future<void> _activateInsertCellFromKeyboard() async {
    switch (_activeInsertColumn) {
      case 0:
        final picked = await _showTrKeyboardDatePickerDialog(
          context: context,
          initialDate: _opDate,
          firstDate: DateTime(2024, 1, 1),
          lastDate: DateTime(2035, 12, 31),
        );
        if (!mounted || picked == null) return;
        setState(() => _opDate = DateUtils.dateOnly(picked));
        return;
      case 1:
        final shift = await showSearchablePickerDialog<String>(
          context,
          title: 'Selecciona turno',
          options: const [
            SearchablePickerOption(value: 'DAY', label: 'Día'),
            SearchablePickerOption(value: 'NIGHT', label: 'Noche'),
          ],
          initialValue: _shift,
        );
        if (!mounted || shift == null) return;
        setState(() => _shift = shift);
        return;
      case 2:
        final mode = await showSearchablePickerDialog<String>(
          context,
          title: 'Selecciona origen',
          options: const [
            SearchablePickerOption(value: 'MIXED', label: 'Mezclado'),
            SearchablePickerOption(value: 'DIRECT', label: 'Directo'),
          ],
          initialValue: _sourceMode,
        );
        if (!mounted || mode == null) return;
        setState(() => _sourceMode = mode);
        return;
      case 3:
        final selected = await showSearchablePickerDialog<String>(
          context,
          title: 'Selecciona material clasificado',
          options: _commercialOptions
              .map(
                (item) =>
                    SearchablePickerOption(value: item.id, label: item.name),
              )
              .toList(),
          initialValue: _commercialId,
        );
        if (!mounted || selected == null) return;
        setState(() => _commercialId = selected);
        return;
      case 8:
        await _insert();
        return;
      default:
        return;
    }
  }

  void _clearActiveInsertCell() {
    switch (_activeInsertColumn) {
      case 1:
        setState(() => _shift = 'DAY');
        return;
      case 2:
        setState(() => _sourceMode = 'MIXED');
        return;
      case 3:
        setState(() => _commercialId = null);
        return;
      default:
        return;
    }
  }

  bool _hasActiveFilter(String columnId) {
    return (_columnValueFilters[columnId]?.isNotEmpty ?? false) ||
        _columnDateRangeFilters.containsKey(columnId);
  }

  bool _isDateFilterColumn(String columnId) => columnId == 'fecha';

  bool _matchesFilters(_TransformationRowVm row, {String? excludeColumn}) {
    for (final entry in _columnDateRangeFilters.entries) {
      if (entry.key == excludeColumn) continue;
      final date = DateUtils.dateOnly(row.opDate);
      final start = DateUtils.dateOnly(entry.value.start);
      final end = DateUtils.dateOnly(entry.value.end);
      if (date.isBefore(start) || date.isAfter(end)) return false;
    }
    for (final entry in _columnValueFilters.entries) {
      if (entry.key == excludeColumn) continue;
      if (entry.value.isEmpty) continue;
      final value = _filterValueForColumn(entry.key, row);
      if (!entry.value.contains(value)) return false;
    }
    return true;
  }

  String _filterValueForColumn(String columnId, _TransformationRowVm row) {
    switch (columnId) {
      case 'fecha':
        return _fmtUiDate(row.opDate);
      case 'turno':
        return row.shift == 'NIGHT' ? 'Noche' : 'Día';
      case 'origen':
        return _sourceModeLabel(row.sourceMode);
      case 'commercial':
        return _commercialName(row.commercialMaterialId);
      case 'kg':
        return row.outputWeightKg.toStringAsFixed(2);
      case 'unidades':
        return row.outputUnitCount?.toString() ?? '—';
      case 'consumo':
        return row.inputWeightKg.toStringAsFixed(2);
      case 'notes':
        final notes = row.notes.trim();
        return notes.isEmpty ? 'Sin notas' : notes;
      default:
        return '';
    }
  }

  List<String> _filterOptionsForColumn(String columnId) {
    final values = <String>{};
    for (final row in _rows) {
      if (!_matchesFilters(row, excludeColumn: columnId)) continue;
      final value = _filterValueForColumn(columnId, row);
      if (value.isNotEmpty) values.add(value);
    }
    final ordered = values.toList()..sort((a, b) => a.compareTo(b));
    return ordered;
  }

  void _syncSelectionWithVisibleRows() {
    final visibleRows = _filteredRows;
    final visibleKeys = visibleRows.map((row) => row.selectionKey).toSet();
    _selectedRowKeys.removeWhere((key) => !visibleKeys.contains(key));
    if (visibleRows.isEmpty || _selectedRowKeys.isEmpty) {
      _selectedRowIndex = null;
      return;
    }
    final currentIndex = _selectedRowIndex;
    if (currentIndex != null &&
        currentIndex >= 0 &&
        currentIndex < visibleRows.length &&
        _selectedRowKeys.contains(visibleRows[currentIndex].selectionKey)) {
      return;
    }
    final nextIndex = visibleRows.indexWhere(
      (row) => _selectedRowKeys.contains(row.selectionKey),
    );
    _selectedRowIndex = nextIndex >= 0 ? nextIndex : null;
  }

  Future<void> _openColumnFilter(String columnId, String label) async {
    if (_isDateFilterColumn(columnId)) {
      if (_rows.isEmpty) return;
      final orderedDates =
          _rows.map((row) => DateUtils.dateOnly(row.opDate)).toList()
            ..sort((a, b) => a.compareTo(b));
      final result = await _showTrDateRangeFilterDialog(
        context,
        label: label,
        bounds: DateTimeRange(
          start: orderedDates.first,
          end: orderedDates.last,
        ),
        initialRange: _columnDateRangeFilters[columnId],
      );
      if (!mounted || result == null) return;
      setState(() {
        if (result.clear || result.range == null) {
          _columnDateRangeFilters.remove(columnId);
        } else {
          _columnDateRangeFilters[columnId] = result.range!;
        }
        _columnValueFilters.remove(columnId);
        _syncSelectionWithVisibleRows();
      });
      _notifyTopBar();
      return;
    }

    final result = await _showTrValueFilterDialog(
      context,
      label: label,
      options: _filterOptionsForColumn(columnId),
      initialSelected: {...(_columnValueFilters[columnId] ?? <String>{})},
    );
    if (!mounted || result == null) return;
    setState(() {
      if (result.selectedValues.isEmpty) {
        _columnValueFilters.remove(columnId);
      } else {
        _columnValueFilters[columnId] = result.selectedValues;
      }
      _columnDateRangeFilters.remove(columnId);
      _syncSelectionWithVisibleRows();
    });
    _notifyTopBar();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      await _loadCatalogs();
      await _loadRows();
      _notifyTopBar();
    } catch (e) {
      _toast('No se pudo cargar transformación: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCatalogs() async {
    final generalRows = await supa
        .from('material_general_catalog_v2')
        .select('id,code,name')
        .eq('is_active', true)
        .order('sort_order')
        .order('name');
    final generalOptions = (generalRows as List)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => _GeneralMaterialV2(
            id: (row['id'] ?? '').toString(),
            code: (row['code'] ?? '').toString(),
            name: (row['name'] ?? '').toString(),
          ),
        )
        .where((row) => row.id.isNotEmpty && row.code.isNotEmpty)
        .toList();
    final general = generalOptions.firstWhere(
      (row) => row.code == widget.sourceGeneralCode,
      orElse: () => const _GeneralMaterialV2(id: '', code: '', name: ''),
    );
    if (general.id.isEmpty) {
      throw StateError(
        'No existe material general v2 para ${widget.sourceGeneralCode}',
      );
    }

    final commercialRows = await supa
        .from('material_commercial_catalog_v2')
        .select(
          'id,code,name,family,general_material_id,tracks_patio_stock,allows_sale,allows_transformation_output',
        )
        .eq('is_active', true)
        .eq('general_material_id', general.id)
        .eq('tracks_patio_stock', true)
        .eq('allows_transformation_output', true)
        .order('sort_order')
        .order('name');
    final commercialOptions = (commercialRows as List)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => _CommercialMaterialV2(
            id: (row['id'] ?? '').toString(),
            code: (row['code'] ?? '').toString(),
            name: (row['name'] ?? '').toString(),
            family: (row['family'] ?? '').toString(),
          ),
        )
        .where((row) => row.id.isNotEmpty && row.code.isNotEmpty)
        .toList();

    if (!mounted) return;
    setState(() {
      _generalMaterialId = general.id;
      _commercialOptions = commercialOptions;
      _commercialId = commercialOptions.any((row) => row.id == _commercialId)
          ? _commercialId
          : (commercialOptions.isEmpty ? null : commercialOptions.first.id);
    });
  }

  Future<void> _loadRows() async {
    if (_generalMaterialId == null) return;
    final data = await supa
        .from('material_transformation_runs_v2')
        .select(
          'id,op_date,shift,source_mode,input_weight_kg,site,notes,created_at,'
          'outputs:material_transformation_run_outputs_v2(id,commercial_material_id,output_weight_kg,output_unit_count,notes)',
        )
        .eq('source_general_material_id', _generalMaterialId!)
        .order('op_date', ascending: false)
        .order('created_at', ascending: false);

    final rows = <_TransformationRowVm>[];
    for (final raw in (data as List).cast<Map<String, dynamic>>()) {
      final outputs = (raw['outputs'] as List? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>();
      if (outputs.isEmpty) {
        rows.add(
          _TransformationRowVm(
            runId: (raw['id'] ?? '').toString(),
            outputId: null,
            opDate: _parseDate(raw['op_date']),
            shift: (raw['shift'] ?? '').toString(),
            sourceMode: (raw['source_mode'] ?? 'MIXED').toString(),
            inputWeightKg: _toDouble(raw['input_weight_kg']) ?? 0,
            commercialMaterialId: null,
            outputWeightKg: 0,
            outputUnitCount: null,
            notes: (raw['notes'] ?? '').toString(),
          ),
        );
        continue;
      }
      for (final output in outputs) {
        rows.add(
          _TransformationRowVm(
            runId: (raw['id'] ?? '').toString(),
            outputId: (output['id'] ?? '').toString(),
            opDate: _parseDate(raw['op_date']),
            shift: (raw['shift'] ?? '').toString(),
            sourceMode: (raw['source_mode'] ?? 'MIXED').toString(),
            inputWeightKg: _toDouble(raw['input_weight_kg']) ?? 0,
            commercialMaterialId: (output['commercial_material_id'] ?? '')
                .toString(),
            outputWeightKg: _toDouble(output['output_weight_kg']) ?? 0,
            outputUnitCount: output['output_unit_count'] as int?,
            notes: ((output['notes'] ?? raw['notes']) ?? '').toString(),
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _rowKeys.removeWhere(
        (key, _) => !rows.any((row) => row.selectionKey == key),
      );
      _selectedRowKeys.removeWhere(
        (key) => !rows.any((row) => row.selectionKey == key),
      );
      _syncSelectionWithVisibleRows();
    });
  }

  Future<void> _insert() async {
    if (_saving) return;
    if (_generalMaterialId == null || _commercialId == null) {
      _toast('Falta material comercial de salida.');
      return;
    }
    final inputKg = _toDouble(_inputKgC.text);
    final outputKg = _toDouble(_outputKgC.text);
    final units = int.tryParse(_unitsC.text.trim());
    final validationError = _validateTransformationValues(
      inputKg: inputKg,
      outputKg: outputKg,
      units: units,
    );
    if (validationError != null) {
      _toast(validationError);
      return;
    }

    setState(() => _saving = true);
    try {
      final effectiveInputKg = inputKg ?? outputKg!;
      final runInsert = await supa
          .from('material_transformation_runs_v2')
          .insert({
            'op_date': _fmtDbDate(_opDate),
            'shift': _shift,
            'source_general_material_id': _generalMaterialId,
            'source_mode': _sourceMode,
            'input_weight_kg': effectiveInputKg,
            'site': 'DICSA_CELAYA',
            'notes': _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
          })
          .select('id')
          .single();
      final runId = (runInsert['id'] ?? '').toString();
      await supa.from('material_transformation_run_outputs_v2').insert({
        'run_id': runId,
        'commercial_material_id': _commercialId,
        'output_weight_kg': outputKg,
        'output_unit_count': units,
        'notes': _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
      });

      _resetDraft();
      await _loadRows();
      _notifyTopBar();
      await widget.onChanged?.call();
      _toast('Transformación agregada');
    } on PostgrestException catch (e) {
      _toast(
        _friendlyPostgrestMessage(
          e,
          fallbackAction: 'No se pudo guardar la transformación.',
        ),
      );
    } catch (e) {
      _toast('No se pudo guardar transformación: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateRow(
    _TransformationRowVm row, {
    required DateTime opDate,
    required String shift,
    required String sourceMode,
    required String? commercialId,
    required double? inputKg,
    required double? outputKg,
    required int? units,
    required String notes,
  }) async {
    if (commercialId == null) {
      _toast('Completa los datos obligatorios.');
      return;
    }
    final validationError = _validateTransformationValues(
      inputKg: inputKg,
      outputKg: outputKg,
      units: units,
    );
    if (validationError != null) {
      _toast(validationError);
      return;
    }
    try {
      final effectiveInputKg = inputKg ?? outputKg!;
      await supa
          .from('material_transformation_runs_v2')
          .update({
            'op_date': _fmtDbDate(opDate),
            'shift': shift,
            'source_mode': sourceMode,
            'input_weight_kg': effectiveInputKg,
            'notes': notes.trim().isEmpty ? null : notes.trim(),
          })
          .eq('id', row.runId);
      if (row.outputId != null) {
        await supa
            .from('material_transformation_run_outputs_v2')
            .update({
              'commercial_material_id': commercialId,
              'output_weight_kg': outputKg,
              'output_unit_count': units,
              'notes': notes.trim().isEmpty ? null : notes.trim(),
            })
            .eq('id', row.outputId!);
      }
      await _loadRows();
      _notifyTopBar();
      await widget.onChanged?.call();
      _toast('Transformación actualizada');
    } on PostgrestException catch (e) {
      _toast(
        _friendlyPostgrestMessage(
          e,
          fallbackAction: 'No se pudo actualizar la transformación.',
        ),
      );
      rethrow;
    } catch (e) {
      _toast('No se pudo actualizar: $e');
      rethrow;
    }
  }

  Future<void> _editRow(_TransformationRowVm row) async {
    final commercialOptions = _commercialOptions;
    String? commercialId = row.commercialMaterialId ?? _commercialId;
    DateTime opDate = row.opDate;
    String shift = row.shift;
    String sourceMode = row.sourceMode;
    final inputC = TextEditingController(
      text: row.inputWeightKg == 0 ? '' : row.inputWeightKg.toStringAsFixed(2),
    );
    final outputC = TextEditingController(
      text: row.outputWeightKg == 0
          ? ''
          : row.outputWeightKg.toStringAsFixed(2),
    );
    final unitsC = TextEditingController(
      text: row.outputUnitCount?.toString() ?? '',
    );
    final notesC = TextEditingController(text: row.notes);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar transformación'),
          content: StatefulBuilder(
            builder: (context, setLocal) {
              return SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Fecha'),
                        subtitle: Text(_fmtUiDate(opDate)),
                        trailing: const Icon(Icons.calendar_month_rounded),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: opDate,
                            firstDate: DateTime(2024, 1, 1),
                            lastDate: DateTime(2035, 12, 31),
                          );
                          if (picked == null) return;
                          setLocal(() => opDate = DateUtils.dateOnly(picked));
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: shift,
                        decoration: const InputDecoration(labelText: 'Turno'),
                        items: const [
                          DropdownMenuItem(value: 'DAY', child: Text('Día')),
                          DropdownMenuItem(
                            value: 'NIGHT',
                            child: Text('Noche'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setLocal(() => shift = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: sourceMode,
                        decoration: const InputDecoration(labelText: 'Origen'),
                        items: const [
                          DropdownMenuItem(
                            value: 'MIXED',
                            child: Text('Mezclado'),
                          ),
                          DropdownMenuItem(
                            value: 'DIRECT',
                            child: Text('Directo'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setLocal(() => sourceMode = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: commercialId,
                        decoration: const InputDecoration(
                          labelText: 'Material comercial',
                        ),
                        items: commercialOptions
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setLocal(() => commercialId = value),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: inputC,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Consumo real kg (opcional)',
                          helperText:
                              'Si lo dejas vacío, se usa el mismo valor que kg salida.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: outputC,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Kg salida',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: unitsC,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Unidades / pacas',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesC,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Notas'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final inputKg = _toDouble(inputC.text);
                final outputKg = _toDouble(outputC.text);
                final units = int.tryParse(unitsC.text.trim());
                if (commercialId == null) {
                  _toast('Completa los datos obligatorios.');
                  return;
                }
                final validationError = _validateTransformationValues(
                  inputKg: inputKg,
                  outputKg: outputKg,
                  units: units,
                );
                if (validationError != null) {
                  _toast(validationError);
                  return;
                }
                try {
                  final effectiveInputKg = inputKg ?? outputKg!;
                  await supa
                      .from('material_transformation_runs_v2')
                      .update({
                        'op_date': _fmtDbDate(opDate),
                        'shift': shift,
                        'source_mode': sourceMode,
                        'input_weight_kg': effectiveInputKg,
                        'notes': notesC.text.trim().isEmpty
                            ? null
                            : notesC.text.trim(),
                      })
                      .eq('id', row.runId);
                  if (row.outputId != null) {
                    await supa
                        .from('material_transformation_run_outputs_v2')
                        .update({
                          'commercial_material_id': commercialId,
                          'output_weight_kg': outputKg,
                          'output_unit_count': units,
                          'notes': notesC.text.trim().isEmpty
                              ? null
                              : notesC.text.trim(),
                        })
                        .eq('id', row.outputId!);
                  }
                  if (!mounted) return;
                  Navigator.of(this.context).pop();
                  await _loadRows();
                  _notifyTopBar();
                  await widget.onChanged?.call();
                } on PostgrestException catch (e) {
                  _toast(
                    _friendlyPostgrestMessage(
                      e,
                      fallbackAction:
                          'No se pudo actualizar la transformación.',
                    ),
                  );
                } catch (e) {
                  _toast('No se pudo actualizar: $e');
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    inputC.dispose();
    outputC.dispose();
    unitsC.dispose();
    notesC.dispose();
  }

  Future<void> _deleteRow(_TransformationRowVm row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar transformación'),
        content: const Text('¿Eliminar este registro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await supa
          .from('material_transformation_runs_v2')
          .delete()
          .eq('id', row.runId);
      await _loadRows();
      _notifyTopBar();
      await widget.onChanged?.call();
      _toast('Transformación eliminada');
    } on PostgrestException catch (e) {
      _toast(
        _friendlyPostgrestMessage(
          e,
          fallbackAction: 'No se pudo eliminar la transformación.',
        ),
      );
    } catch (e) {
      _toast('No se pudo eliminar: $e');
    }
  }

  Future<void> _exportCsv() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final sb = StringBuffer()
        ..write('\uFEFF')
        ..writeln(
          'fecha,turno,origen,material_general,material_comercial,kg_entrada,kg_salida,unidades,notas',
        );
      for (final row in _rows) {
        sb.writeln(
          [
            _fmtDbDate(row.opDate),
            row.shift,
            row.sourceMode,
            widget.sourceGeneralCode,
            _commercialName(row.commercialMaterialId),
            row.inputWeightKg.toStringAsFixed(2),
            row.outputWeightKg.toStringAsFixed(2),
            row.outputUnitCount?.toString() ?? '',
            row.notes,
          ].map(_csvEscape).join(','),
        );
      }
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '')
          .replaceAll('-', '')
          .split('.')
          .first;
      final path = await _writeDownloadsFile(
        'transformacion_${widget.sourceGeneralCode.toLowerCase()}_$stamp.csv',
        sb.toString(),
      );
      _toast(
        path == null ? 'No se pudo guardar CSV' : 'CSV exportado en: $path',
      );
    } catch (e) {
      _toast('No se pudo exportar CSV: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _resetDraft() {
    if (!mounted) return;
    setState(() {
      _opDate = DateUtils.dateOnly(DateTime.now());
      _shift = 'DAY';
      _sourceMode = 'MIXED';
      _commercialId = _commercialOptions.isEmpty
          ? null
          : _commercialOptions.first.id;
      _inputKgC.clear();
      _outputKgC.clear();
      _unitsC.clear();
      _notesC.clear();
    });
  }

  void _notifyTopBar() {
    final totalOutputKg = _rows.fold<double>(
      0,
      (sum, row) => sum + row.outputWeightKg,
    );
    final selectedRows = _rows
        .where((row) => _selectedRowKeys.contains(row.selectionKey))
        .toList();
    final selectedKgSum = selectedRows.fold<double>(
      0,
      (sum, row) => sum + row.outputWeightKg,
    );
    final selectedCount = _selectedRowKeys.length;
    final activeCell = _editingRowStates().isNotEmpty
        ? _activeGridColumnLabel
        : null;
    widget.onTopBarChanged?.call(
      InventoryGridTopBarData(
        metricIcon: widget.metricIcon,
        metricLabel: 'KG ${widget.title.toUpperCase()} CLASIFICADO',
        metricValue: _fmtCount(totalOutputKg),
        metricSubtitle: '${_rows.length} registros',
        exportingCsv: _exporting,
        gridEditMode: false,
        canToggleGridEdit: false,
        canDeleteSelection: selectedCount > 0,
        deletingSelection: _bulkDeleting,
        selectedCount: selectedCount,
        selectedKgSumLabel: selectedCount == 0
            ? null
            : '${_fmtCount(selectedKgSum)} kg',
        selectedKgAvgLabel: selectedCount == 0
            ? null
            : '${_fmtCount(selectedKgSum / selectedCount)} kg',
        activeCellLabel: activeCell,
        onExportCsv: _exporting ? null : _exportCsv,
        onDeleteSelection: _bulkDeleting ? null : _deleteSelectedRows,
      ),
    );
  }

  String get _activeGridColumnLabel {
    switch (_activeGridColumn) {
      case 0:
        return 'Fecha';
      case 1:
        return 'Turno';
      case 2:
        return 'Origen';
      case 3:
        return 'Clasificado';
      case 4:
        return 'Kg salida';
      case 5:
        return 'Unidades';
      case 6:
        return 'Consumo';
      case 7:
        return 'Comentario';
      default:
        return 'Celda';
    }
  }

  String _commercialName(String? id) {
    for (final option in _commercialOptions) {
      if (option.id == id) return option.name;
    }
    return '—';
  }

  String? _validateTransformationValues({
    required double? inputKg,
    required double? outputKg,
    required int? units,
  }) {
    if (outputKg == null || outputKg <= 0) {
      return 'Kg salida debe ser mayor a 0.';
    }
    if (inputKg != null && inputKg <= 0) {
      return 'Consumo real debe ser mayor a 0 cuando se captura.';
    }
    if (inputKg != null && outputKg > inputKg) {
      return 'Kg salida no puede ser mayor que kg entrada.';
    }
    if (units != null && units < 0) {
      return 'Unidades / pacas no puede ser negativo.';
    }
    return null;
  }

  String _fmtUiDate(DateTime date) {
    final yy = (date.year % 100).toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$dd/$mm/$yy';
  }

  String _fmtDbDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
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
    return DateUtils.dateOnly(DateTime.now());
  }

  double? _toDouble(dynamic value) {
    final raw = value?.toString().trim().replaceAll(',', '') ?? '';
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  String _fmtCount(double value) => value.toStringAsFixed(2);

  String _sourceModeLabel(String value) =>
      value == 'DIRECT' ? 'Directo' : 'Mezclado';

  Future<String?> _writeDownloadsFile(String fileName, String content) async {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return null;
    final dirs = <Directory>[
      Directory('$home/Downloads'),
      Directory('$home/Descargas'),
    ];
    for (final dir in dirs) {
      try {
        if (!dir.existsSync()) dir.createSync(recursive: true);
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(content, encoding: utf8);
        return file.path;
      } catch (_) {}
    }
    return null;
  }

  String _csvEscape(Object? value) {
    if (value == null) return '';
    final text = value.toString().replaceAll('"', '""');
    if (text.contains(',') || text.contains('\n') || text.contains('"')) {
      return '"$text"';
    }
    return text;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyPostgrestMessage(
    PostgrestException error, {
    required String fallbackAction,
  }) {
    final message = error.message.trim();
    final details = (error.details ?? '').toString().trim();
    final hint = (error.hint ?? '').toString().trim();
    if (error.code == 'P0001' && message.isNotEmpty) {
      return message;
    }
    if (message.contains('Inventario insuficiente')) {
      return message;
    }
    if (message.contains('unique') || message.contains('duplicate')) {
      return 'Ya existe una salida para ese material en esta misma transformación.';
    }
    if (message.contains('foreign key') ||
        message.contains('violates foreign key')) {
      return 'El material seleccionado ya no es válido en catálogo.';
    }
    if (message.contains('weight_chk') ||
        message.contains('input_weight_chk')) {
      return 'Los kilogramos capturados no son válidos.';
    }
    final raw = <String>[
      message,
      details,
      hint,
    ].where((part) => part.isNotEmpty).join(' ');
    return raw.isEmpty ? fallbackAction : raw;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TransformationHeaderRow(
          hasActiveFilter: _hasActiveFilter,
          onOpenFilter: _openColumnFilter,
        ),
        const SizedBox(height: 8),
        _buildFormCard(context),
        const SizedBox(height: 12),
        Expanded(child: _buildRowsCard(context)),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: _insertRowActive
            ? [
                BoxShadow(
                  color: const Color(0xFF7FAFD3).withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Card(
        elevation: 0.4,
        color: _insertRowActive
            ? const Color(0xFFD6E9FB)
            : const Color(0xFFD8EAFB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _insertRowActive
                ? const Color(0xFF4E86B5).withValues(alpha: 0.70)
                : const Color(0xFF6F93B3).withValues(alpha: 0.55),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tableContentWidth = _trTableContentWFor(
                constraints.maxWidth,
              );
              final notesColWidth = _trNotesColWFor(constraints.maxWidth);
              Widget frame(int col, Widget child) {
                final active = _activeInsertColumn == col;
                return DecoratedBox(
                  position: DecorationPosition.background,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: active
                        ? const Color(0xFFDCEAF7).withValues(alpha: 0.72)
                        : Colors.transparent,
                  ),
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active
                            ? const Color(0xFF0B72FF).withValues(alpha: 0.86)
                            : Colors.transparent,
                        width: active ? 1.1 : 1.0,
                      ),
                    ),
                    child: child,
                  ),
                );
              }

              return SizedBox(
                width: constraints.maxWidth,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: tableContentWidth,
                    child: Focus(
                      focusNode: _insertFocusNode,
                      onKeyEvent: (_, event) {
                        if (event is! KeyDownEvent) {
                          return KeyEventResult.ignored;
                        }
                        final key = event.logicalKey;
                        if (key == LogicalKeyboardKey.arrowLeft) {
                          if (_outputKgFocusNode.hasFocus &&
                              !_caretAtStart(_outputKgC, _outputKgFocusNode)) {
                            return KeyEventResult.ignored;
                          }
                          if (_unitsFocusNode.hasFocus &&
                              !_caretAtStart(_unitsC, _unitsFocusNode)) {
                            return KeyEventResult.ignored;
                          }
                          if (_inputKgFocusNode.hasFocus &&
                              !_caretAtStart(_inputKgC, _inputKgFocusNode)) {
                            return KeyEventResult.ignored;
                          }
                          if (_notesFocusNode.hasFocus &&
                              !_caretAtStart(_notesC, _notesFocusNode)) {
                            return KeyEventResult.ignored;
                          }
                          _moveInsertColumn(-1);
                          return KeyEventResult.handled;
                        }
                        if (key == LogicalKeyboardKey.arrowRight) {
                          if (_outputKgFocusNode.hasFocus &&
                              !_caretAtEnd(_outputKgC, _outputKgFocusNode)) {
                            return KeyEventResult.ignored;
                          }
                          if (_unitsFocusNode.hasFocus &&
                              !_caretAtEnd(_unitsC, _unitsFocusNode)) {
                            return KeyEventResult.ignored;
                          }
                          if (_inputKgFocusNode.hasFocus &&
                              !_caretAtEnd(_inputKgC, _inputKgFocusNode)) {
                            return KeyEventResult.ignored;
                          }
                          if (_notesFocusNode.hasFocus &&
                              !_caretAtEnd(_notesC, _notesFocusNode)) {
                            return KeyEventResult.ignored;
                          }
                          _moveInsertColumn(1);
                          return KeyEventResult.handled;
                        }
                        if (key == LogicalKeyboardKey.escape) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          _insertFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                        if (key == LogicalKeyboardKey.arrowUp) {
                          return KeyEventResult.handled;
                        }
                        if (key == LogicalKeyboardKey.arrowDown) {
                          _focusRowsFromInsert();
                          return KeyEventResult.handled;
                        }
                        if (key == LogicalKeyboardKey.delete ||
                            key == LogicalKeyboardKey.backspace) {
                          if (_isInsertTextFocused) {
                            return KeyEventResult.ignored;
                          }
                          _clearActiveInsertCell();
                          return KeyEventResult.handled;
                        }
                        if (key == LogicalKeyboardKey.space) {
                          if (_isInsertTextFocused) {
                            return KeyEventResult.ignored;
                          }
                          unawaited(_activateInsertCellFromKeyboard());
                          return KeyEventResult.handled;
                        }
                        if (key == LogicalKeyboardKey.enter ||
                            key == LogicalKeyboardKey.numpadEnter) {
                          if (_isInsertTextFocused &&
                              _activeInsertColumn >= 4 &&
                              _activeInsertColumn <= 7) {
                            unawaited(_insert());
                            return KeyEventResult.handled;
                          }
                          unawaited(_activateInsertCellFromKeyboard());
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Row(
                        children: [
                          _TransformationFieldShell(
                            width: _kTrDateColW,
                            child: frame(
                              0,
                              _TransformationInlineDateField(
                                value: _opDate,
                                active: _activeInsertColumn == 0,
                                onTap: () async {
                                  _setActiveInsertColumn(0);
                                  final picked =
                                      await _showTrKeyboardDatePickerDialog(
                                        context: context,
                                        initialDate: _opDate,
                                        firstDate: DateTime(2024, 1, 1),
                                        lastDate: DateTime(2035, 12, 31),
                                      );
                                  if (picked == null || !mounted) return;
                                  setState(
                                    () => _opDate = DateUtils.dateOnly(picked),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: _kTrCellGap),
                          _TransformationFieldShell(
                            width: _kTrShiftColW,
                            child: frame(
                              1,
                              _TransformationInlinePickerField(
                                label: _shift == 'DAY' ? 'Día' : 'Noche',
                                active: _activeInsertColumn == 1,
                                onTap: () async {
                                  _setActiveInsertColumn(1);
                                  final value =
                                      await showSearchablePickerDialog(
                                        context,
                                        title: 'Selecciona turno',
                                        options: const [
                                          SearchablePickerOption(
                                            value: 'DAY',
                                            label: 'Día',
                                          ),
                                          SearchablePickerOption(
                                            value: 'NIGHT',
                                            label: 'Noche',
                                          ),
                                        ],
                                        initialValue: _shift,
                                      );
                                  if (value == null || !mounted) return;
                                  setState(() => _shift = value);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: _kTrCellGap),
                          _TransformationFieldShell(
                            width: _kTrSourceColW,
                            child: frame(
                              2,
                              _TransformationInlinePickerField(
                                label: _sourceModeLabel(_sourceMode),
                                active: _activeInsertColumn == 2,
                                onTap: () async {
                                  _setActiveInsertColumn(2);
                                  final value =
                                      await showSearchablePickerDialog(
                                        context,
                                        title: 'Selecciona origen',
                                        options: const [
                                          SearchablePickerOption(
                                            value: 'MIXED',
                                            label: 'Mezclado',
                                          ),
                                          SearchablePickerOption(
                                            value: 'DIRECT',
                                            label: 'Directo',
                                          ),
                                        ],
                                        initialValue: _sourceMode,
                                      );
                                  if (value == null || !mounted) return;
                                  setState(() => _sourceMode = value);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: _kTrCellGap),
                          _TransformationFieldShell(
                            width: _kTrCommercialColW,
                            child: frame(
                              3,
                              _TransformationInlinePickerField(
                                label: _commercialName(_commercialId),
                                active: _activeInsertColumn == 3,
                                onTap: () async {
                                  _setActiveInsertColumn(3);
                                  final value =
                                      await showSearchablePickerDialog(
                                        context,
                                        title:
                                            'Selecciona material clasificado',
                                        options: _commercialOptions
                                            .map(
                                              (item) => SearchablePickerOption(
                                                value: item.id,
                                                label: item.name,
                                              ),
                                            )
                                            .toList(),
                                        initialValue: _commercialId,
                                      );
                                  if (value == null || !mounted) return;
                                  setState(() => _commercialId = value);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: _kTrCellGap),
                          _TransformationFieldShell(
                            width: _kTrOutputColW,
                            child: frame(
                              4,
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: TextField(
                                  controller: _outputKgC,
                                  focusNode: _outputKgFocusNode,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _trGlassFieldDecoration(
                                    hintText: 'Kg salida',
                                    suppressFocusedBorder: true,
                                    hideBorder: _activeInsertColumn == 4,
                                  ),
                                  onTap: () => _setActiveInsertColumn(
                                    4,
                                    requestFocus: false,
                                  ),
                                  onSubmitted: (_) => _insert(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: _kTrCellGap),
                          _TransformationFieldShell(
                            width: _kTrUnitsColW,
                            child: frame(
                              5,
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: TextField(
                                  controller: _unitsC,
                                  focusNode: _unitsFocusNode,
                                  keyboardType: TextInputType.number,
                                  decoration: _trGlassFieldDecoration(
                                    hintText: 'Pacas / unidades',
                                    suppressFocusedBorder: true,
                                    hideBorder: _activeInsertColumn == 5,
                                  ),
                                  onTap: () => _setActiveInsertColumn(
                                    5,
                                    requestFocus: false,
                                  ),
                                  onSubmitted: (_) => _insert(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: _kTrCellGap),
                          _TransformationFieldShell(
                            width: _kTrInputColW,
                            child: frame(
                              6,
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: TextField(
                                  controller: _inputKgC,
                                  focusNode: _inputKgFocusNode,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _trGlassFieldDecoration(
                                    hintText: 'Consumo',
                                    suppressFocusedBorder: true,
                                    hideBorder: _activeInsertColumn == 6,
                                  ),
                                  onTap: () => _setActiveInsertColumn(
                                    6,
                                    requestFocus: false,
                                  ),
                                  onSubmitted: (_) => _insert(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: _kTrCellGap),
                          _TransformationFieldShell(
                            width: notesColWidth,
                            child: frame(
                              7,
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: TextField(
                                  controller: _notesC,
                                  focusNode: _notesFocusNode,
                                  decoration: _trGlassFieldDecoration(
                                    hintText: 'Comentario / notas',
                                    suppressFocusedBorder: true,
                                    hideBorder: _activeInsertColumn == 7,
                                  ),
                                  onTap: () => _setActiveInsertColumn(
                                    7,
                                    requestFocus: false,
                                  ),
                                  onSubmitted: (_) => _insert(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: _kTrActionsGap),
                          SizedBox(
                            width: _kTrActionsColW,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: frame(
                                8,
                                SizedBox(
                                  width: _kTrActionButtonW,
                                  height: 34,
                                  child: Tooltip(
                                    message: 'AGREGAR',
                                    child: MouseRegion(
                                      onEnter: (_) => setState(
                                        () => _hoverInsertAddButton = true,
                                      ),
                                      onExit: (_) => setState(
                                        () => _hoverInsertAddButton = false,
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: _saving
                                            ? null
                                            : () {
                                                _setActiveInsertColumn(8);
                                                unawaited(_insert());
                                              },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 120,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          decoration: BoxDecoration(
                                            color: _saving
                                                ? Colors.white.withValues(
                                                    alpha: 0.35,
                                                  )
                                                : const Color(
                                                    0xFF19C37D,
                                                  ).withValues(alpha: 0.92),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.52,
                                              ),
                                            ),
                                            boxShadow:
                                                _hoverInsertAddButton &&
                                                    !_saving
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.16,
                                                          ),
                                                      blurRadius: 14,
                                                      offset: const Offset(
                                                        0,
                                                        7,
                                                      ),
                                                    ),
                                                  ]
                                                : [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.08,
                                                          ),
                                                      blurRadius: 8,
                                                      offset: const Offset(
                                                        0,
                                                        4,
                                                      ),
                                                    ),
                                                  ],
                                          ),
                                          child: Center(
                                            child: _saving
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : Icon(
                                                    Icons.add,
                                                    size: 18,
                                                    color: _hoverInsertAddButton
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFFF6FEFB,
                                                          ),
                                                  ),
                                          ),
                                        ),
                                      ),
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
          ),
        ),
      ),
    );
  }

  Widget _buildRowsCard(BuildContext context) {
    if (_rows.isEmpty) {
      return ContractGlassCard(
        child: const Center(
          child: Text('Sin transformaciones registradas para esta familia'),
        ),
      );
    }

    return TapRegion(
      onTapOutside: (_) => _clearRowSelection(),
      child: Focus(
        focusNode: _rowsFocusNode,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          final key = event.logicalKey;
          final selectedState = _selectedRowState();
          final editing = selectedState?.isEditing ?? false;
          final inTextEditing =
              selectedState?.isTextCellFocused(_activeGridColumn) ?? false;
          if (key == LogicalKeyboardKey.arrowDown) {
            _moveSelectedRow(1);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp) {
            if ((_selectedRowIndex ?? 0) <= 0) {
              _focusInsertFromRows();
            } else {
              _moveSelectedRow(-1);
            }
            return KeyEventResult.handled;
          }
          if (editing && key == LogicalKeyboardKey.arrowLeft) {
            if (inTextEditing &&
                !(selectedState?.activeTextCaretAtStart(_activeGridColumn) ??
                    false)) {
              return KeyEventResult.ignored;
            }
            _moveGridColumn(-1);
            return KeyEventResult.handled;
          }
          if (editing && key == LogicalKeyboardKey.arrowRight) {
            if (inTextEditing &&
                !(selectedState?.activeTextCaretAtEnd(_activeGridColumn) ??
                    false)) {
              return KeyEventResult.ignored;
            }
            _moveGridColumn(1);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.space) {
            if (editing && inTextEditing) return KeyEventResult.ignored;
            selectedState?.activateGridCell(_activeGridColumn);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter) {
            final states = _editingRowStates().isNotEmpty
                ? _editingRowStates()
                : _selectedRowStates();
            if (editing) {
              unawaited(
                Future.wait(states.map((state) => state.saveFromKeyboard())),
              );
              return KeyEventResult.handled;
            }
            for (final state in states) {
              state.startEditingFromKeyboard();
            }
            _notifyTopBar();
            selectedState?.activateGridCell(_activeGridColumn);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.delete ||
              key == LogicalKeyboardKey.backspace) {
            if (_selectedRowKeys.length > 1) {
              unawaited(_deleteSelectedRows());
              return KeyEventResult.handled;
            }
            final selectedIndex = _selectedRowIndex;
            final visibleRows = _filteredRows;
            if (selectedIndex == null || selectedIndex >= visibleRows.length) {
              return KeyEventResult.handled;
            }
            unawaited(_deleteRow(visibleRows[selectedIndex]));
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.escape) {
            if (editing) {
              for (final state in _editingRowStates()) {
                state.cancelEditingFromKeyboard();
              }
              _notifyTopBar();
              return KeyEventResult.handled;
            }
            if (_selectedRowKeys.isNotEmpty) {
              _clearRowSelection();
              FocusManager.instance.primaryFocus?.unfocus();
              return KeyEventResult.handled;
            }
            _focusInsertFromRows();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            _handleRowsPointerDown(event);
            if (_rowIndexAtGlobalPosition(event.position) == null &&
                _selectedRowKeys.isNotEmpty) {
              _clearRowSelection();
            }
          },
          onPointerMove: _handleRowsPointerMove,
          onPointerUp: (_) => _finishRowsPointerSelection(),
          onPointerCancel: (_) => _finishRowsPointerSelection(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final notesColumnWidth = _trNotesColWFor(
                      constraints.maxWidth,
                    );
                    final visibleRows = _filteredRows;
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: visibleRows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final row = visibleRows[index];
                        return _TransformationDataRow(
                          key: _rowKey(row.selectionKey),
                          row: row,
                          selected:
                              _selectedRowKeys.contains(row.selectionKey) &&
                              _selectedRowIndex == index,
                          checked: _selectedRowKeys.contains(row.selectionKey),
                          selectedCount: _selectedRowKeys.length,
                          hovering: _hoveredRowIndex == index,
                          activeGridColumn: _activeGridColumn,
                          notesColumnWidth: notesColumnWidth,
                          commercialOptions: _commercialOptions,
                          onHoverChanged: (hovering) {
                            setState(() {
                              _hoveredRowIndex = hovering ? index : null;
                            });
                          },
                          onActivateColumn: (col) {
                            setState(() => _activeGridColumn = col);
                            _notifyTopBar();
                          },
                          onEditStateChanged: _notifyTopBar,
                          onTap: () => _toggleRowSelection(
                            index,
                            additive: _isAdditiveSelectionPressed(),
                          ),
                          onDoubleTap: () {
                            _toggleRowSelection(index, additive: false);
                            setState(() => _activeGridColumn = 0);
                          },
                          onSecondaryTapDown: (details) {
                            final alreadySelected = _selectedRowKeys.contains(
                              row.selectionKey,
                            );
                            if (!alreadySelected) {
                              _toggleRowSelection(index, additive: false);
                            }
                            unawaited(
                              _openRowContextMenu(row, details.globalPosition),
                            );
                          },
                          onOpenActions: (position) {
                            final alreadySelected = _selectedRowKeys.contains(
                              row.selectionKey,
                            );
                            if (!alreadySelected) {
                              _toggleRowSelection(index, additive: false);
                            }
                            unawaited(_openRowContextMenu(row, position));
                          },
                          onEdit: () async {
                            _toggleRowSelection(index, additive: false);
                            setState(() => _activeGridColumn = 0);
                            final state = _rowKey(
                              row.selectionKey,
                            ).currentState;
                            state?.startEditingFromKeyboard();
                            await state?.activateGridCell(0);
                          },
                          onDelete: () => _deleteRow(row),
                          onUpdate:
                              (
                                opDate,
                                shift,
                                sourceMode,
                                commercialId,
                                inputKg,
                                outputKg,
                                units,
                                notes,
                              ) => _updateRow(
                                row,
                                opDate: opDate,
                                shift: shift,
                                sourceMode: sourceMode,
                                commercialId: commercialId,
                                inputKg: inputKg,
                                outputKg: outputKg,
                                units: units,
                                notes: notes,
                              ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransformationFieldShell extends StatelessWidget {
  final double width;
  final Widget child;

  const _TransformationFieldShell({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: child);
  }
}

class _TransformationInlineDateField extends StatelessWidget {
  final DateTime value;
  final bool active;
  final Future<void> Function() onTap;

  const _TransformationInlineDateField({
    required this.value,
    required this.active,
    required this.onTap,
  });

  String _fmtUiDate(DateTime date) {
    final yy = (date.year % 100).toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$dd/$mm/$yy';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => unawaited(onTap()),
        child: InputDecorator(
          decoration: _trGlassFieldDecoration(
            suppressFocusedBorder: true,
            hideBorder: active,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _fmtUiDate(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.calendar_month, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransformationInlinePickerField extends StatelessWidget {
  final String label;
  final bool active;
  final Future<void> Function() onTap;

  const _TransformationInlinePickerField({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => unawaited(onTap()),
        child: InputDecorator(
          decoration: _trGlassFieldDecoration(
            suppressFocusedBorder: true,
            hideBorder: active,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label.trim().isEmpty ? '—' : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _trGlassFieldDecoration({
  String? hintText,
  bool suppressFocusedBorder = false,
  bool hideBorder = false,
  Color? fillColorOverride,
}) {
  final baseSide = hideBorder
      ? BorderSide(color: Colors.transparent, width: 0.9)
      : BorderSide(
          color: const Color(0xFF90AFC8).withValues(alpha: 0.55),
          width: 1,
        );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: baseSide,
  );
  final focused = suppressFocusedBorder
      ? border
      : border.copyWith(
          borderSide: BorderSide(
            color: const Color(0xFF00A3FF).withValues(alpha: 0.8),
            width: 1.2,
          ),
        );

  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(
      color: const Color(0xFF0B2B2B).withValues(alpha: 0.42),
      fontWeight: FontWeight.w400,
    ),
    isDense: true,
    filled: true,
    fillColor:
        fillColorOverride ?? const Color(0xFFEAF2F9).withValues(alpha: 0.90),
    border: border,
    enabledBorder: border,
    focusedBorder: focused,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  );
}

Future<DateTime?> _showTrKeyboardDatePickerDialog({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  DateTime tempDate = DateUtils.dateOnly(initialDate);

  DateTime clampDate(DateTime value) {
    if (value.isBefore(firstDate)) return firstDate;
    if (value.isAfter(lastDate)) return lastDate;
    return value;
  }

  void moveDateByDays(void Function(void Function()) setInnerState, int days) {
    setInnerState(() {
      tempDate = DateUtils.dateOnly(
        clampDate(tempDate.add(Duration(days: days))),
      );
    });
  }

  void deferredPop(BuildContext ctx, [DateTime? value]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ctx.mounted) return;
      Navigator.of(ctx).pop(value);
    });
  }

  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (innerContext, setInnerState) {
          return FocusScope(
            autofocus: true,
            child: Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                final key = event.logicalKey;
                if (key == LogicalKeyboardKey.escape) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  deferredPop(dialogContext);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowLeft) {
                  moveDateByDays(setInnerState, -1);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowRight) {
                  moveDateByDays(setInnerState, 1);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowUp) {
                  moveDateByDays(setInnerState, -7);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowDown) {
                  moveDateByDays(setInnerState, 7);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.enter ||
                    key == LogicalKeyboardKey.numpadEnter) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  deferredPop(dialogContext, DateUtils.dateOnly(tempDate));
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Theme(
                data: Theme.of(innerContext).copyWith(
                  colorScheme: Theme.of(innerContext).colorScheme.copyWith(
                    primary: const Color(0xFF6A99C7),
                    onPrimary: Colors.white,
                    surface: const Color(0xFFEAF2F9),
                  ),
                ),
                child: AlertDialog(
                  backgroundColor: const Color(
                    0xFFEAF2F9,
                  ).withValues(alpha: 0.98),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: const Color(0xFF8AA9C2).withValues(alpha: 0.42),
                    ),
                  ),
                  title: const Text('Selecciona fecha'),
                  content: SizedBox(
                    width: 320,
                    child: CalendarDatePicker(
                      key: ValueKey<DateTime>(tempDate),
                      initialDate: tempDate,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      onDateChanged: (d) {
                        setInnerState(() {
                          tempDate = DateUtils.dateOnly(d);
                        });
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2D5478),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6A99C7),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(
                        dialogContext,
                      ).pop(DateUtils.dateOnly(tempDate)),
                      child: const Text('Aceptar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _TransformationTableHeader extends StatelessWidget {
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;
  final double notesColumnWidth;

  const _TransformationTableHeader({
    required this.hasActiveFilter,
    required this.onOpenFilter,
    required this.notesColumnWidth,
  });

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12, fontWeight: FontWeight.w800);
    return Row(
      children: [
        _TransformationHeaderCell(
          'FECHA',
          _kTrDateColW,
          style,
          active: hasActiveFilter('fecha'),
          onFilter: () => onOpenFilter('fecha', 'FECHA'),
        ),
        const SizedBox(width: _kTrCellGap),
        _TransformationHeaderCell(
          'TURNO',
          _kTrShiftColW,
          style,
          active: hasActiveFilter('turno'),
          onFilter: () => onOpenFilter('turno', 'TURNO'),
        ),
        const SizedBox(width: _kTrCellGap),
        _TransformationHeaderCell(
          'ORIGEN',
          _kTrSourceColW,
          style,
          active: hasActiveFilter('origen'),
          onFilter: () => onOpenFilter('origen', 'ORIGEN'),
        ),
        const SizedBox(width: _kTrCellGap),
        _TransformationHeaderCell(
          'CLASIFICADO',
          _kTrCommercialColW,
          style,
          active: hasActiveFilter('commercial'),
          onFilter: () => onOpenFilter('commercial', 'CLASIFICADO'),
        ),
        const SizedBox(width: _kTrCellGap),
        _TransformationHeaderCell(
          'KG SALIDA',
          _kTrOutputColW,
          style,
          active: hasActiveFilter('kg'),
          onFilter: () => onOpenFilter('kg', 'KG SALIDA'),
        ),
        const SizedBox(width: _kTrCellGap),
        _TransformationHeaderCell(
          'UNIDADES',
          _kTrUnitsColW,
          style,
          active: hasActiveFilter('unidades'),
          onFilter: () => onOpenFilter('unidades', 'UNIDADES'),
        ),
        const SizedBox(width: _kTrCellGap),
        _TransformationHeaderCell(
          'CONSUMO',
          _kTrInputColW,
          style,
          active: hasActiveFilter('consumo'),
          onFilter: () => onOpenFilter('consumo', 'CONSUMO'),
        ),
        const SizedBox(width: _kTrCellGap),
        _TransformationHeaderCell(
          'COMENTARIO',
          notesColumnWidth,
          style,
          active: hasActiveFilter('notes'),
          onFilter: () => onOpenFilter('notes', 'COMENTARIO'),
        ),
        const SizedBox(width: _kTrActionsGap),
        const SizedBox(width: _kTrActionsColW),
      ],
    );
  }
}

class _TransformationHeaderRow extends StatelessWidget {
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;

  const _TransformationHeaderRow({
    required this.hasActiveFilter,
    required this.onOpenFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.black.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tableContentWidth = _trTableContentWFor(constraints.maxWidth);
            final notesColumnWidth = _trNotesColWFor(constraints.maxWidth);
            return SizedBox(
              width: constraints.maxWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: tableContentWidth,
                  child: _TransformationTableHeader(
                    hasActiveFilter: hasActiveFilter,
                    onOpenFilter: onOpenFilter,
                    notesColumnWidth: notesColumnWidth,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TransformationHeaderCell extends StatelessWidget {
  final String label;
  final double width;
  final TextStyle style;
  final bool active;
  final VoidCallback onFilter;

  const _TransformationHeaderCell(
    this.label,
    this.width,
    this.style, {
    required this.active,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onFilter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: active
                    ? _kTrFilterAccent
                    : _kTrFilterAccentSoft.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active
                      ? _kTrFilterAccent.withValues(alpha: 0.55)
                      : const Color(0xFF0B2B2B).withValues(alpha: 0.15),
                ),
              ),
              child: Icon(
                active ? Icons.filter_alt : Icons.filter_alt_outlined,
                size: 15,
                color: active ? Colors.white : const Color(0xFF2A4B49),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label, style: style, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _TransformationDataRow extends StatefulWidget {
  final _TransformationRowVm row;
  final bool selected;
  final bool checked;
  final int selectedCount;
  final bool hovering;
  final int activeGridColumn;
  final double notesColumnWidth;
  final List<_CommercialMaterialV2> commercialOptions;
  final ValueChanged<bool> onHoverChanged;
  final ValueChanged<int> onActivateColumn;
  final VoidCallback onEditStateChanged;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final ValueChanged<TapDownDetails> onSecondaryTapDown;
  final ValueChanged<Offset> onOpenActions;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function(
    DateTime opDate,
    String shift,
    String sourceMode,
    String? commercialId,
    double? inputKg,
    double? outputKg,
    int? units,
    String notes,
  )
  onUpdate;

  const _TransformationDataRow({
    super.key,
    required this.row,
    required this.selected,
    required this.checked,
    required this.selectedCount,
    required this.hovering,
    required this.activeGridColumn,
    required this.notesColumnWidth,
    required this.commercialOptions,
    required this.onHoverChanged,
    required this.onActivateColumn,
    required this.onEditStateChanged,
    required this.onTap,
    required this.onDoubleTap,
    required this.onSecondaryTapDown,
    required this.onOpenActions,
    required this.onEdit,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<_TransformationDataRow> createState() => _TransformationDataRowState();
}

class _TransformationDataRowState extends State<_TransformationDataRow> {
  bool _editing = false;
  int? _hoveredEditableColumn;
  late DateTime _opDate;
  late String _shift;
  late String _sourceMode;
  String? _commercialId;
  final TextEditingController _outputKgC = TextEditingController();
  final TextEditingController _unitsC = TextEditingController();
  final TextEditingController _inputKgC = TextEditingController();
  final TextEditingController _notesC = TextEditingController();
  final FocusNode _outputKgFocusNode = FocusNode();
  final FocusNode _unitsFocusNode = FocusNode();
  final FocusNode _inputKgFocusNode = FocusNode();
  final FocusNode _notesFocusNode = FocusNode();

  bool get isEditing => _editing;

  @override
  void initState() {
    super.initState();
    _syncFromRow();
  }

  @override
  void didUpdateWidget(covariant _TransformationDataRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row != widget.row && !_editing) {
      _syncFromRow();
    }
  }

  @override
  void dispose() {
    _outputKgC.dispose();
    _unitsC.dispose();
    _inputKgC.dispose();
    _notesC.dispose();
    _outputKgFocusNode.dispose();
    _unitsFocusNode.dispose();
    _inputKgFocusNode.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  void _syncFromRow() {
    _opDate = widget.row.opDate;
    _shift = widget.row.shift;
    _sourceMode = widget.row.sourceMode;
    _commercialId = widget.row.commercialMaterialId;
    _outputKgC.text = widget.row.outputWeightKg == 0
        ? ''
        : widget.row.outputWeightKg.toStringAsFixed(2);
    _unitsC.text = widget.row.outputUnitCount?.toString() ?? '';
    _inputKgC.text = widget.row.inputWeightKg == 0
        ? ''
        : widget.row.inputWeightKg.toStringAsFixed(2);
    _notesC.text = widget.row.notes;
  }

  String _fmtUiDate(DateTime date) {
    final yy = (date.year % 100).toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$dd/$mm/$yy';
  }

  String _commercialName(String? id) {
    for (final option in widget.commercialOptions) {
      if (option.id == id) return option.name;
    }
    return '—';
  }

  String _sourceModeLabel(String value) =>
      value == 'DIRECT' ? 'Directo' : 'Mezclado';

  ({Color bg, Color fg}) _shiftChipColors() {
    return _shift == 'NIGHT'
        ? (bg: const Color(0xFFD9E8FF), fg: const Color(0xFF1D3C58))
        : (bg: const Color(0xFFD8FBF3), fg: const Color(0xFF1D3C58));
  }

  ({Color bg, Color fg}) _sourceModeChipColors() {
    return _sourceMode == 'DIRECT'
        ? (bg: const Color(0xFFE7E9FF), fg: const Color(0xFF324A88))
        : (bg: const Color(0xFFE7F6EC), fg: const Color(0xFF2C6B46));
  }

  ({Color bg, Color fg}) _commercialChipColors() {
    return (bg: const Color(0xFFE8EEF6), fg: const Color(0xFF2A4B49));
  }

  double? _toDouble(String value) {
    final raw = value.trim().replaceAll(',', '');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  bool isTextCellFocused(int col) => switch (col) {
    4 => _outputKgFocusNode.hasFocus,
    5 => _unitsFocusNode.hasFocus,
    6 => _inputKgFocusNode.hasFocus,
    7 => _notesFocusNode.hasFocus,
    _ => false,
  };

  bool activeTextCaretAtStart(int col) => switch (col) {
    4 => _caretAtStart(_outputKgC, _outputKgFocusNode),
    5 => _caretAtStart(_unitsC, _unitsFocusNode),
    6 => _caretAtStart(_inputKgC, _inputKgFocusNode),
    7 => _caretAtStart(_notesC, _notesFocusNode),
    _ => true,
  };

  bool activeTextCaretAtEnd(int col) => switch (col) {
    4 => _caretAtEnd(_outputKgC, _outputKgFocusNode),
    5 => _caretAtEnd(_unitsC, _unitsFocusNode),
    6 => _caretAtEnd(_inputKgC, _inputKgFocusNode),
    7 => _caretAtEnd(_notesC, _notesFocusNode),
    _ => true,
  };

  bool _caretAtStart(TextEditingController c, FocusNode f) {
    if (!f.hasFocus) return false;
    final s = c.selection;
    return s.isValid &&
        s.isCollapsed &&
        s.baseOffset == 0 &&
        s.extentOffset == 0;
  }

  bool _caretAtEnd(TextEditingController c, FocusNode f) {
    if (!f.hasFocus) return false;
    final s = c.selection;
    final e = c.text.length;
    return s.isValid &&
        s.isCollapsed &&
        s.baseOffset == e &&
        s.extentOffset == e;
  }

  void startEditingFromKeyboard() {
    if (!_editing) {
      setState(() => _editing = true);
      widget.onEditStateChanged();
    }
  }

  void cancelEditingFromKeyboard() {
    _syncFromRow();
    if (mounted) {
      setState(() => _editing = false);
      widget.onEditStateChanged();
    }
  }

  Future<void> saveFromKeyboard() async {
    if (_editing) await _save();
  }

  void focusTextIfNeeded(int col) {
    if (!_editing) return;
    switch (col) {
      case 4:
        FocusScope.of(context).requestFocus(_outputKgFocusNode);
        return;
      case 5:
        FocusScope.of(context).requestFocus(_unitsFocusNode);
        return;
      case 6:
        FocusScope.of(context).requestFocus(_inputKgFocusNode);
        return;
      case 7:
        FocusScope.of(context).requestFocus(_notesFocusNode);
        return;
    }
  }

  Future<void> activateGridCell(int col) async {
    if (!_editing) return;
    switch (col) {
      case 0:
        final d = await _showTrKeyboardDatePickerDialog(
          context: context,
          initialDate: _opDate,
          firstDate: DateTime(2024, 1, 1),
          lastDate: DateTime(2035, 12, 31),
        );
        if (d != null) setState(() => _opDate = DateUtils.dateOnly(d));
        return;
      case 1:
        final shift = await showSearchablePickerDialog<String>(
          context,
          title: 'Turno',
          initialValue: _shift,
          options: const [
            SearchablePickerOption(value: 'DAY', label: 'Día'),
            SearchablePickerOption(value: 'NIGHT', label: 'Noche'),
          ],
        );
        if (shift != null) setState(() => _shift = shift);
        return;
      case 2:
        final mode = await showSearchablePickerDialog<String>(
          context,
          title: 'Origen',
          initialValue: _sourceMode,
          options: const [
            SearchablePickerOption(value: 'MIXED', label: 'Mezclado'),
            SearchablePickerOption(value: 'DIRECT', label: 'Directo'),
          ],
        );
        if (mode != null) setState(() => _sourceMode = mode);
        return;
      case 3:
        final selected = await showSearchablePickerDialog<String>(
          context,
          title: 'Material clasificado',
          initialValue: _commercialId,
          options: widget.commercialOptions
              .map(
                (item) =>
                    SearchablePickerOption(value: item.id, label: item.name),
              )
              .toList(),
        );
        if (selected != null) setState(() => _commercialId = selected);
        return;
      case 4:
        FocusScope.of(context).requestFocus(_outputKgFocusNode);
        return;
      case 5:
        FocusScope.of(context).requestFocus(_unitsFocusNode);
        return;
      case 6:
        FocusScope.of(context).requestFocus(_inputKgFocusNode);
        return;
      case 7:
        FocusScope.of(context).requestFocus(_notesFocusNode);
        return;
    }
  }

  void _previewEditableCellTap(int col) {
    widget.onTap();
    widget.onActivateColumn(col);
  }

  Future<void> _save() async {
    await widget.onUpdate(
      _opDate,
      _shift,
      _sourceMode,
      _commercialId,
      _toDouble(_inputKgC.text),
      _toDouble(_outputKgC.text),
      int.tryParse(_unitsC.text.trim()),
      _notesC.text,
    );
    if (mounted) {
      setState(() => _editing = false);
      widget.onEditStateChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: const Color(0xFF0B2B2B),
    );
    final subtleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: const Color(0xFF2A4B49),
    );
    final shiftLabel = _shift == 'DAY' ? 'Día' : 'Noche';
    final hasSelection = widget.selected || widget.checked;
    final multiContext = widget.selectedCount > 1 && hasSelection;
    final hoverOnly = widget.hovering && !hasSelection;
    final rowBg = _editing
        ? const Color(0xFFDCECF9)
        : hasSelection
        ? const Color(
            0xFF00A3FF,
          ).withValues(alpha: widget.selected ? 0.16 : 0.13)
        : hoverOnly
        ? const Color(0xFFE9F7EE)
        : Colors.white;
    final hoverLift = hasSelection
        ? -1.4
        : widget.hovering
        ? -1.15
        : 0.0;
    final elevation = hasSelection
        ? 3.2
        : widget.checked
        ? 3.0
        : hoverOnly
        ? 2.7
        : 0.5;

    Widget frame(int col, Widget child) {
      final active =
          _editing && widget.selected && widget.activeGridColumn == col;
      final hoveredEditable = !_editing && _hoveredEditableColumn == col;
      return DecoratedBox(
        position: DecorationPosition.background,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: hoveredEditable
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (hasSelection
                            ? const Color(0xFFD9E8F6)
                            : const Color(0xFFE5F2EC))
                        .withValues(alpha: 0.78),
                    (hasSelection
                            ? const Color(0xFFCCE0F2)
                            : const Color(0xFFD4E7DE))
                        .withValues(alpha: 0.64),
                  ],
                )
              : null,
          color: active
              ? const Color(0xFFDCEAF7).withValues(alpha: 0.72)
              : Colors.transparent,
          border: Border.all(
            color: active
                ? const Color(0xFF0B72FF).withValues(alpha: 0.84)
                : Colors.transparent,
            width: active ? 1.05 : 1.0,
          ),
          boxShadow: hoveredEditable
              ? [
                  BoxShadow(
                    color:
                        (hasSelection
                                ? const Color(0xFF6A8FAE)
                                : const Color(0xFF6C8F84))
                            .withValues(alpha: 0.18),
                    blurRadius: 2.2,
                    spreadRadius: -3.0,
                    offset: const Offset(0, 0.8),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.22),
                    blurRadius: 1.1,
                    spreadRadius: -3.1,
                    offset: const Offset(0, -0.5),
                  ),
                ]
              : null,
        ),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? const Color(0xFF0B72FF).withValues(alpha: 0.84)
                  : Colors.transparent,
              width: active ? 1.05 : 1.0,
            ),
          ),
          child: child,
        ),
      );
    }

    Widget previewEditableCell({required int col, required Widget child}) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (_editing) return;
          if (_hoveredEditableColumn != col) {
            setState(() => _hoveredEditableColumn = col);
          }
        },
        onExit: (_) {
          if (_hoveredEditableColumn == col) {
            setState(() => _hoveredEditableColumn = null);
          }
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _previewEditableCellTap(col),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () {
              widget.onDoubleTap();
              widget.onActivateColumn(col);
              if (!_editing) {
                setState(() => _editing = true);
                widget.onEditStateChanged();
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                unawaited(activateGridCell(col));
              });
            },
            child: child,
          ),
        ),
      );
    }

    return TapRegion(
      onTapOutside: (_) {
        if (_editing) cancelEditingFromKeyboard();
      },
      child: MouseRegion(
        onEnter: (_) => widget.onHoverChanged(true),
        onExit: (_) => widget.onHoverChanged(false),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          onSecondaryTapDown: widget.onSecondaryTapDown,
          child: AnimatedContainer(
            duration: Duration.zero,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, hoverLift, 0),
            child: Card(
              elevation: elevation,
              color: rowBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: widget.selected
                      ? const Color(0xFF00A3FF).withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.0),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tableContentWidth = _trTableContentWFor(
                      constraints.maxWidth,
                    );
                    final notesColumnWidth = _trNotesColWFor(
                      constraints.maxWidth,
                    );
                    return SizedBox(
                      width: constraints.maxWidth,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: tableContentWidth,
                          child: Row(
                            children: [
                              frame(
                                0,
                                SizedBox(
                                  width: _kTrDateColW,
                                  child: _editing
                                      ? _TransformationInlineDateField(
                                          value: _opDate,
                                          active: widget.activeGridColumn == 0,
                                          onTap: () async {
                                            widget.onActivateColumn(0);
                                            await activateGridCell(0);
                                          },
                                        )
                                      : previewEditableCell(
                                          col: 0,
                                          child: _TransformationReadonlyCell(
                                            width: _kTrDateColW,
                                            child: Text(
                                              _fmtUiDate(_opDate),
                                              style: bodyStyle,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: _kTrCellGap),
                              frame(
                                1,
                                SizedBox(
                                  width: _kTrShiftColW,
                                  child: _editing
                                      ? _TransformationInlinePickerField(
                                          label: shiftLabel,
                                          active: widget.activeGridColumn == 1,
                                          onTap: () async {
                                            widget.onActivateColumn(1);
                                            await activateGridCell(1);
                                          },
                                        )
                                      : previewEditableCell(
                                          col: 1,
                                          child: _TransformationReadonlyCell(
                                            width: _kTrShiftColW,
                                            child: Builder(
                                              builder: (_) {
                                                final palette =
                                                    _shiftChipColors();
                                                return _TransformationPillTag(
                                                  label: shiftLabel,
                                                  background: palette.bg,
                                                  foreground: palette.fg,
                                                  horizontalPadding: 10,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: _kTrCellGap),
                              frame(
                                2,
                                SizedBox(
                                  width: _kTrSourceColW,
                                  child: _editing
                                      ? _TransformationInlinePickerField(
                                          label: _sourceModeLabel(_sourceMode),
                                          active: widget.activeGridColumn == 2,
                                          onTap: () async {
                                            widget.onActivateColumn(2);
                                            await activateGridCell(2);
                                          },
                                        )
                                      : previewEditableCell(
                                          col: 2,
                                          child: _TransformationReadonlyCell(
                                            width: _kTrSourceColW,
                                            child: Builder(
                                              builder: (_) {
                                                final palette =
                                                    _sourceModeChipColors();
                                                return _TransformationPillTag(
                                                  label: _sourceModeLabel(
                                                    _sourceMode,
                                                  ),
                                                  background: palette.bg,
                                                  foreground: palette.fg,
                                                  horizontalPadding: 10,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: _kTrCellGap),
                              frame(
                                3,
                                SizedBox(
                                  width: _kTrCommercialColW,
                                  child: _editing
                                      ? _TransformationInlinePickerField(
                                          label: _commercialName(_commercialId),
                                          active: widget.activeGridColumn == 3,
                                          onTap: () async {
                                            widget.onActivateColumn(3);
                                            await activateGridCell(3);
                                          },
                                        )
                                      : previewEditableCell(
                                          col: 3,
                                          child: _TransformationReadonlyCell(
                                            width: _kTrCommercialColW,
                                            child: Builder(
                                              builder: (_) {
                                                final palette =
                                                    _commercialChipColors();
                                                return Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: _TransformationPillTag(
                                                    label: _commercialName(
                                                      _commercialId,
                                                    ),
                                                    background: palette.bg,
                                                    foreground: palette.fg,
                                                    horizontalPadding: 10,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: _kTrCellGap),
                              frame(
                                4,
                                SizedBox(
                                  width: _kTrOutputColW,
                                  child: _editing
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: TextField(
                                            controller: _outputKgC,
                                            focusNode: _outputKgFocusNode,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration: _trGlassFieldDecoration(
                                              hintText: 'Kg salida',
                                              suppressFocusedBorder: true,
                                              hideBorder:
                                                  widget.activeGridColumn == 4,
                                            ),
                                            onTap: () =>
                                                widget.onActivateColumn(4),
                                            onSubmitted: (_) =>
                                                unawaited(_save()),
                                          ),
                                        )
                                      : previewEditableCell(
                                          col: 4,
                                          child: _TransformationReadonlyCell(
                                            width: _kTrOutputColW,
                                            child: Text(
                                              '${(_toDouble(_outputKgC.text) ?? 0).toStringAsFixed(2)} kg',
                                              style: bodyStyle,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: _kTrCellGap),
                              frame(
                                5,
                                SizedBox(
                                  width: _kTrUnitsColW,
                                  child: _editing
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: TextField(
                                            controller: _unitsC,
                                            focusNode: _unitsFocusNode,
                                            keyboardType: TextInputType.number,
                                            decoration: _trGlassFieldDecoration(
                                              hintText: 'Unidades',
                                              suppressFocusedBorder: true,
                                              hideBorder:
                                                  widget.activeGridColumn == 5,
                                            ),
                                            onTap: () =>
                                                widget.onActivateColumn(5),
                                            onSubmitted: (_) =>
                                                unawaited(_save()),
                                          ),
                                        )
                                      : previewEditableCell(
                                          col: 5,
                                          child: _TransformationReadonlyCell(
                                            width: _kTrUnitsColW,
                                            child: _TransformationPillTag(
                                              label: _unitsC.text.trim().isEmpty
                                                  ? '—'
                                                  : _unitsC.text.trim(),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: _kTrCellGap),
                              frame(
                                6,
                                SizedBox(
                                  width: _kTrInputColW,
                                  child: _editing
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: TextField(
                                            controller: _inputKgC,
                                            focusNode: _inputKgFocusNode,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration: _trGlassFieldDecoration(
                                              hintText: 'Consumo',
                                              suppressFocusedBorder: true,
                                              hideBorder:
                                                  widget.activeGridColumn == 6,
                                            ),
                                            onTap: () =>
                                                widget.onActivateColumn(6),
                                            onSubmitted: (_) =>
                                                unawaited(_save()),
                                          ),
                                        )
                                      : previewEditableCell(
                                          col: 6,
                                          child: _TransformationReadonlyCell(
                                            width: _kTrInputColW,
                                            child: Text(
                                              '${(_toDouble(_inputKgC.text) ?? 0).toStringAsFixed(2)} kg',
                                              style: subtleStyle,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: _kTrCellGap),
                              frame(
                                7,
                                SizedBox(
                                  width: notesColumnWidth,
                                  child: _editing
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: TextField(
                                            controller: _notesC,
                                            focusNode: _notesFocusNode,
                                            decoration: _trGlassFieldDecoration(
                                              hintText: 'Comentario / notas',
                                              suppressFocusedBorder: true,
                                              hideBorder:
                                                  widget.activeGridColumn == 7,
                                            ),
                                            onTap: () =>
                                                widget.onActivateColumn(7),
                                            onSubmitted: (_) =>
                                                unawaited(_save()),
                                          ),
                                        )
                                      : previewEditableCell(
                                          col: 7,
                                          child: _TransformationReadonlyCell(
                                            width: notesColumnWidth,
                                            showDivider: false,
                                            child: Text(
                                              _notesC.text.trim().isEmpty
                                                  ? 'Sin notas'
                                                  : _notesC.text.trim(),
                                              style: subtleStyle,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: _kTrActionsGap),
                              SizedBox(
                                width: _kTrActionsColW,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (_editing)
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF6A99C7,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        onPressed: _save,
                                        child: const Text('ACTUALIZAR'),
                                      )
                                    else
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          SizedBox(
                                            width: _kTrActionsColW - 36,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.42),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    '${(_toDouble(_outputKgC.text) ?? 0).toStringAsFixed(1)} kg',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Builder(
                                            builder: (menuContext) {
                                              return _TransformationActionsButton(
                                                iconColor: multiContext
                                                    ? const Color(0xFF2D5478)
                                                    : const Color(0xFF20364E),
                                                onOpen: () {
                                                  final box =
                                                      menuContext
                                                              .findRenderObject()
                                                          as RenderBox?;
                                                  if (box == null) return;
                                                  final origin = box
                                                      .localToGlobal(
                                                        Offset.zero,
                                                      );
                                                  widget.onOpenActions(
                                                    Offset(
                                                      origin.dx,
                                                      origin.dy +
                                                          box.size.height +
                                                          4,
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransformationReadonlyCell extends StatelessWidget {
  final double width;
  final Widget child;
  final bool showDivider;

  const _TransformationReadonlyCell({
    required this.width,
    required this.child,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Expanded(child: child),
            if (showDivider)
              Container(
                width: 1,
                height: 30,
                margin: const EdgeInsets.only(left: 8, right: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9D5E2).withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TransformationPillTag extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final double horizontalPadding;

  const _TransformationPillTag({
    required this.label,
    this.background = const Color(0xFFDCE4F0),
    this.foreground = const Color(0xFF2E445E),
    this.horizontalPadding = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

class _TrFilterDialogResult {
  final Set<String> selectedValues;

  const _TrFilterDialogResult({required this.selectedValues});
}

class _TrDateFilterDialogResult {
  final DateTimeRange? range;
  final bool clear;

  const _TrDateFilterDialogResult({this.range, this.clear = false});
}

Future<_TrFilterDialogResult?> _showTrValueFilterDialog(
  BuildContext context, {
  required String label,
  required List<String> options,
  required Set<String> initialSelected,
}) {
  return showDialog<_TrFilterDialogResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          final localSelected = <String>{...initialSelected};
          String localSearch = '';

          return Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  width: 420,
                  constraints: const BoxConstraints(maxHeight: 560),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  decoration: _trFilterDialogDecoration(),
                  child: StatefulBuilder(
                    builder: (context, innerSetState) {
                      final visibleOptions = options
                          .where(
                            (value) => value.toLowerCase().contains(
                              localSearch.toLowerCase(),
                            ),
                          )
                          .toList();
                      final allVisibleSelected =
                          visibleOptions.isNotEmpty &&
                          visibleOptions.every(localSelected.contains);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtro: $label',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0B2B2B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            autofocus: true,
                            onChanged: (value) =>
                                innerSetState(() => localSearch = value),
                            decoration: _trGlassFieldDecoration(
                              hintText: 'Buscar',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF2A4B49),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                onPressed: () {
                                  innerSetState(() {
                                    if (allVisibleSelected) {
                                      localSelected.removeAll(visibleOptions);
                                    } else {
                                      localSelected.addAll(visibleOptions);
                                    }
                                  });
                                },
                                child: Text(
                                  allVisibleSelected
                                      ? 'Deseleccionar visibles'
                                      : 'Seleccionar visibles',
                                ),
                              ),
                              Text(
                                '${localSelected.length} seleccionados',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          Expanded(
                            child: visibleOptions.isEmpty
                                ? const Center(
                                    child: Text('Sin valores para mostrar'),
                                  )
                                : ListView.builder(
                                    itemCount: visibleOptions.length,
                                    itemBuilder: (_, i) {
                                      final value = visibleOptions[i];
                                      final checked = localSelected.contains(
                                        value,
                                      );
                                      return CheckboxListTile(
                                        dense: true,
                                        value: checked,
                                        activeColor: const Color(0xFF2D7A73),
                                        checkColor: Colors.white,
                                        hoverColor: const Color(
                                          0xFFE9F7EE,
                                        ).withValues(alpha: 0.95),
                                        title: Text(
                                          value,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onChanged: (nextValue) {
                                          innerSetState(() {
                                            if (nextValue ?? false) {
                                              localSelected.add(value);
                                            } else {
                                              localSelected.remove(value);
                                            }
                                          });
                                        },
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                style: _trFilterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancelar'),
                              ),
                              OutlinedButton(
                                style: _trFilterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(
                                  dialogContext,
                                  const _TrFilterDialogResult(
                                    selectedValues: <String>{},
                                  ),
                                ),
                                child: const Text('Limpiar'),
                              ),
                              FilledButton(
                                style: _trFilterFilledButtonStyle(),
                                onPressed: () => Navigator.pop(
                                  dialogContext,
                                  _TrFilterDialogResult(
                                    selectedValues: localSelected,
                                  ),
                                ),
                                child: const Text('Aplicar'),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<_TrDateFilterDialogResult?> _showTrDateRangeFilterDialog(
  BuildContext context, {
  required String label,
  required DateTimeRange bounds,
  DateTimeRange? initialRange,
}) {
  return showDialog<_TrDateFilterDialogResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      DateTime displayMonth = DateTime(
        (initialRange?.start ?? bounds.start).year,
        (initialRange?.start ?? bounds.start).month,
      );
      DateTime? start = initialRange?.start;
      DateTime? end = initialRange?.end;
      DateTime? hover;

      bool isSameDay(DateTime a, DateTime b) =>
          a.year == b.year && a.month == b.month && a.day == b.day;
      DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

      return StatefulBuilder(
        builder: (context, setLocalState) {
          final monthFirst = DateTime(displayMonth.year, displayMonth.month, 1);
          final leading = (monthFirst.weekday + 6) % 7;
          final gridStart = monthFirst.subtract(Duration(days: leading));
          final previewEnd = end ?? hover;

          bool withinBounds(DateTime day) {
            final d = dateOnly(day);
            return !d.isBefore(dateOnly(bounds.start)) &&
                !d.isAfter(dateOnly(bounds.end));
          }

          bool inPreviewRange(DateTime day) {
            if (start == null || previewEnd == null) return false;
            final a = dateOnly(start!);
            final b = dateOnly(previewEnd);
            final from = a.isBefore(b) ? a : b;
            final to = a.isBefore(b) ? b : a;
            final d = dateOnly(day);
            return !d.isBefore(from) && !d.isAfter(to);
          }

          _TrDateFilterDialogResult? buildResult() {
            if (start == null) return null;
            final s = dateOnly(start!);
            final e = dateOnly(end ?? start!);
            final from = s.isBefore(e) ? s : e;
            final to = s.isBefore(e) ? e : s;
            return _TrDateFilterDialogResult(
              range: DateTimeRange(start: from, end: to),
            );
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    decoration: _trFilterDialogDecoration(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filtro: $label',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Color(0xFF0B2B2B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setLocalState(
                                () => displayMonth = DateTime(
                                  displayMonth.year,
                                  displayMonth.month - 1,
                                ),
                              ),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  '${_trMonthNameEs(monthFirst.month)} ${monthFirst.year}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setLocalState(
                                () => displayMonth = DateTime(
                                  displayMonth.year,
                                  displayMonth.month + 1,
                                ),
                              ),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            Expanded(child: Center(child: Text('L'))),
                            Expanded(child: Center(child: Text('M'))),
                            Expanded(child: Center(child: Text('M'))),
                            Expanded(child: Center(child: Text('J'))),
                            Expanded(child: Center(child: Text('V'))),
                            Expanded(child: Center(child: Text('S'))),
                            Expanded(child: Center(child: Text('D'))),
                          ],
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          height: 250,
                          child: Column(
                            children: List.generate(6, (row) {
                              return Expanded(
                                child: Row(
                                  children: List.generate(7, (col) {
                                    final day = gridStart.add(
                                      Duration(days: row * 7 + col),
                                    );
                                    final allowed = withinBounds(day);
                                    final active =
                                        (start != null &&
                                            isSameDay(day, start!)) ||
                                        (end != null && isSameDay(day, end!));
                                    final inRange =
                                        inPreviewRange(day) && allowed;
                                    return Expanded(
                                      child: MouseRegion(
                                        onHover: (_) {
                                          if (start != null &&
                                              end == null &&
                                              allowed) {
                                            setLocalState(
                                              () => hover = dateOnly(day),
                                            );
                                          }
                                        },
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: !allowed
                                              ? null
                                              : () {
                                                  final picked = dateOnly(day);
                                                  setLocalState(() {
                                                    if (start == null ||
                                                        end != null) {
                                                      start = picked;
                                                      end = null;
                                                      hover = null;
                                                    } else if (picked.isBefore(
                                                      start!,
                                                    )) {
                                                      start = picked;
                                                      hover = null;
                                                    } else {
                                                      end = picked;
                                                      hover = null;
                                                    }
                                                  });
                                                },
                                          child: Container(
                                            margin: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: active
                                                  ? _kTrFilterAccent
                                                  : inRange
                                                  ? _kTrFilterAccentSoft
                                                        .withValues(alpha: 0.8)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${day.day}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: active
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                  color: active
                                                      ? Colors.white
                                                      : allowed
                                                      ? const Color(0xFF0B2B2B)
                                                      : Colors.black38,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          start == null
                              ? 'Selecciona fecha inicial'
                              : end == null
                              ? 'Selecciona fecha final'
                              : '${_trFmtDateLabel(start!)} - ${_trFmtDateLabel(end!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2A4B49),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              style: _trFilterOutlinedButtonStyle(),
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: _trFilterOutlinedButtonStyle(),
                              onPressed: () => Navigator.pop(
                                dialogContext,
                                const _TrDateFilterDialogResult(clear: true),
                              ),
                              child: const Text('Limpiar'),
                            ),
                            const SizedBox(width: 6),
                            FilledButton(
                              style: _trFilterFilledButtonStyle(),
                              onPressed: start == null
                                  ? null
                                  : () => Navigator.pop(
                                      dialogContext,
                                      buildResult(),
                                    ),
                              child: const Text('Aplicar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

BoxDecoration _trFilterDialogDecoration() {
  return BoxDecoration(
    color: const Color(0xFFE8F0F7).withValues(alpha: 0.92),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: const Color(0xFF92ABC1).withValues(alpha: 0.50)),
  );
}

ButtonStyle _trFilterOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF1E3C5A),
    side: BorderSide(color: const Color(0xFF6E8CAA).withValues(alpha: 0.35)),
    backgroundColor: const Color(0xFFDDE9F4).withValues(alpha: 0.70),
  );
}

ButtonStyle _trFilterFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: _kTrFilterAccent,
    foregroundColor: Colors.white,
  );
}

String _trMonthNameEs(int month) {
  const months = <String>[
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  return months[(month - 1).clamp(0, 11)];
}

String _trFmtDateLabel(DateTime date) {
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final yyyy = date.year.toString();
  return '$dd/$mm/$yyyy';
}

class _TransformationActionsButton extends StatefulWidget {
  final VoidCallback onOpen;
  final Color? iconColor;

  const _TransformationActionsButton({required this.onOpen, this.iconColor});

  @override
  State<_TransformationActionsButton> createState() =>
      _TransformationActionsButtonState();
}

class _TransformationActionsButtonState
    extends State<_TransformationActionsButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Acciones',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => widget.onOpen(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.62)
                  : Colors.white.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hovered ? 0.15 : 0.08),
                  blurRadius: _hovered ? 14 : 8,
                  offset: Offset(0, _hovered ? 7 : 4),
                ),
              ],
            ),
            child: Icon(Icons.more_horiz, size: 20, color: widget.iconColor),
          ),
        ),
      ),
    );
  }
}

class _GeneralMaterialV2 {
  final String id;
  final String code;
  final String name;

  const _GeneralMaterialV2({
    required this.id,
    required this.code,
    required this.name,
  });
}

class _CommercialMaterialV2 {
  final String id;
  final String code;
  final String name;
  final String family;

  const _CommercialMaterialV2({
    required this.id,
    required this.code,
    required this.name,
    required this.family,
  });
}

class _TransformationRowVm {
  final String runId;
  final String? outputId;
  final DateTime opDate;
  final String shift;
  final String sourceMode;
  final double inputWeightKg;
  final String? commercialMaterialId;
  final double outputWeightKg;
  final int? outputUnitCount;
  final String notes;

  const _TransformationRowVm({
    required this.runId,
    required this.outputId,
    required this.opDate,
    required this.shift,
    required this.sourceMode,
    required this.inputWeightKg,
    required this.commercialMaterialId,
    required this.outputWeightKg,
    required this.outputUnitCount,
    required this.notes,
  });

  String get selectionKey => outputId == null ? 'run:$runId' : 'out:$outputId';
}
