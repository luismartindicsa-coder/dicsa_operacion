// ignore_for_file: unused_element, unused_element_parameter

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../finanzas/finanzas_dashboard_page.dart';
import '../services/inventory_movements_grid.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import 'compras_area_chrome.dart';
import 'compras_dashboard_page.dart';
import 'compras_catalog_page.dart';
import 'compras_data_store.dart';
import 'compras_price_adjustments_page.dart';
import 'compras_provider_directory_page.dart';
import 'compras_theme.dart';
import 'compras_tickets_store.dart';

const double _kTicketActionsW = 96;
const double _kTicketDateW = 120;
const double _kTicketNumberW = 110;
const double _kTicketProviderW = 220;
const double _kTicketMaterialW = 170;
const double _kTicketGrossW = 90;
const double _kTicketTareW = 90;
const double _kTicketNetW = 90;
const double _kTicketHumidityW = 95;
const double _kTicketTrashW = 95;
const double _kTicketWeightW = 90;
const double _kTicketPriceW = 100;
const double _kTicketPremiumW = 105;
const double _kTicketAmountW = 120;
const double _kTicketFacturaW = 160;
const double _kTicketPagoW = 160;
const double _kTicketContentW =
    _kTicketDateW +
    _kTicketNumberW +
    _kTicketProviderW +
    _kTicketMaterialW +
    _kTicketGrossW +
    _kTicketTareW +
    _kTicketNetW +
    _kTicketHumidityW +
    _kTicketTrashW +
    _kTicketWeightW +
    _kTicketPriceW +
    _kTicketPremiumW +
    _kTicketAmountW +
    _kTicketFacturaW +
    _kTicketPagoW;

class ComprasTicketsPage extends StatefulWidget {
  final bool instantOpen;

  const ComprasTicketsPage({super.key, this.instantOpen = false});

  @override
  State<ComprasTicketsPage> createState() => _ComprasTicketsPageState();
}

class _ComprasTicketsPageState extends State<ComprasTicketsPage> {
  bool _canReturnToDirection = false;
  bool _canAccessFinanzasArea = false;
  bool _menuOpen = false;
  bool _loading = true;
  bool _exportingCsv = false;
  bool _deletingSelection = false;
  final ScrollController _rowsScrollController = ScrollController();
  final GlobalKey _rowsViewportKey = GlobalKey(
    debugLabel: 'compras_tickets_rows_viewport',
  );
  final Map<String, GlobalKey> _rowItemKeys = <String, GlobalKey>{};
  final FocusNode _gridRowsFocusNode = FocusNode(
    debugLabel: 'compras_tickets_grid_rows',
  );
  List<ComprasTicketRecord> _rows = <ComprasTicketRecord>[];
  List<ComprasCatalogProviderRecord> _providers =
      <ComprasCatalogProviderRecord>[];
  List<ComprasCatalogMaterialRecord> _materials =
      <ComprasCatalogMaterialRecord>[];
  List<ComprasCatalogPriceRecord> _prices = <ComprasCatalogPriceRecord>[];
  Set<String> _dateFilters = <String>{};
  Set<String> _ticketFilters = <String>{};
  Set<String> _providerFilters = <String>{};
  Set<String> _materialFilters = <String>{};
  Set<String> _facturaFilters = <String>{};
  Set<String> _pagoFilters = <String>{};
  String? _selectedRowKey;
  String? _selectionAnchorRowKey;
  final Set<String> _bulkSelectedRowKeys = <String>{};
  bool _dragSelectionActive = false;
  List<String> _dragSelectionKeys = const <String>[];
  String? _dragSelectionAnchorKey;
  Offset? _dragPointerGlobal;
  double _dragAutoScrollVelocity = 0;
  Timer? _dragAutoScrollTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadPage());
  }

  @override
  void dispose() {
    _rowsScrollController.dispose();
    _gridRowsFocusNode.dispose();
    _dragAutoScrollTimer?.cancel();
    super.dispose();
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
      _canAccessFinanzasArea = AuthAccess.canAccessFinanzasArea(profile);
    });
  }

  Future<void> _loadPage() async {
    setState(() => _loading = true);
    final results = await Future.wait<dynamic>([
      ComprasTicketsStore.loadTickets(),
      ComprasTicketsStore.loadReferenceData(),
    ]);
    if (!mounted) return;
    final tickets = results[0] as List<ComprasTicketRecord>;
    final reference = results[1] as ComprasTicketsReferenceData;
    setState(() {
      _rows = tickets;
      _providers = reference.providers;
      _materials = reference.materials;
      _prices = reference.prices;
      _loading = false;
      _pruneSelectionKeys();
    });
  }

  List<ComprasTicketRecord> get _visibleRows {
    return _rows
        .where((row) {
          if (_dateFilters.isNotEmpty &&
              !_dateFilters.contains(_dateLabel(row.date))) {
            return false;
          }
          if (_ticketFilters.isNotEmpty &&
              !_ticketFilters.contains(row.ticket)) {
            return false;
          }
          if (_providerFilters.isNotEmpty &&
              !_providerFilters.contains(row.providerNameSnapshot)) {
            return false;
          }
          if (_materialFilters.isNotEmpty &&
              !_materialFilters.contains(row.materialNameSnapshot)) {
            return false;
          }
          if (_facturaFilters.isNotEmpty &&
              !_facturaFilters.contains(
                comprasFacturaStatusLabel(row.facturaStatus),
              )) {
            return false;
          }
          if (_pagoFilters.isNotEmpty &&
              !_pagoFilters.contains(comprasPagoStatusLabel(row.pagoStatus))) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<String> get _visibleRowKeys =>
      _visibleRows.map((row) => _rowKey(row)).toList(growable: false);

  String _rowKey(ComprasTicketRecord row) => 'ct:${row.id}';

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _weight(double value) => value.toStringAsFixed(2);

  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  ComprasTicketRecord? _rowByKey(String rowKey) {
    final id = rowKey.split(':').last;
    for (final row in _rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  bool _isCtrlOrCmdPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
  }

  bool _isShiftPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
  }

  bool _isEditableTextFocused() {
    final widget = FocusManager.instance.primaryFocus?.context?.widget;
    return widget is EditableText;
  }

  GlobalKey _rowItemKey(String rowKey) {
    return _rowItemKeys.putIfAbsent(
      rowKey,
      () => GlobalKey(debugLabel: 'compras_ticket_row_$rowKey'),
    );
  }

  void _setSingleSelection(String rowKey) {
    _selectedRowKey = rowKey;
    _selectionAnchorRowKey = rowKey;
    _bulkSelectedRowKeys
      ..clear()
      ..add(rowKey);
  }

  void _clearSelection() {
    _selectedRowKey = null;
    _selectionAnchorRowKey = null;
    _bulkSelectedRowKeys.clear();
  }

  void _pruneSelectionKeys() {
    final validKeys = _rows.map(_rowKey).toSet();
    _bulkSelectedRowKeys.removeWhere((key) => !validKeys.contains(key));
    if (_selectedRowKey != null && !validKeys.contains(_selectedRowKey)) {
      _selectedRowKey = _bulkSelectedRowKeys.isEmpty
          ? null
          : _bulkSelectedRowKeys.last;
    }
    if (_selectionAnchorRowKey != null &&
        !validKeys.contains(_selectionAnchorRowKey)) {
      _selectionAnchorRowKey = _selectedRowKey;
    }
  }

  void _selectRange(String targetRowKey, List<String> visibleKeys) {
    final anchor = _selectionAnchorRowKey ?? _selectedRowKey ?? targetRowKey;
    final start = visibleKeys.indexOf(anchor);
    final end = visibleKeys.indexOf(targetRowKey);
    if (start == -1 || end == -1) {
      _setSingleSelection(targetRowKey);
      return;
    }
    final range = visibleKeys.sublist(
      start < end ? start : end,
      start < end ? end + 1 : start + 1,
    );
    _selectedRowKey = targetRowKey;
    _bulkSelectedRowKeys
      ..clear()
      ..addAll(range);
  }

  void _handleRowSelection(String rowKey, List<String> visibleKeys) {
    _gridRowsFocusNode.requestFocus();
    setState(() {
      if (_isShiftPressed()) {
        _selectRange(rowKey, visibleKeys);
        return;
      }
      if (_isCtrlOrCmdPressed()) {
        if (_bulkSelectedRowKeys.contains(rowKey)) {
          _bulkSelectedRowKeys.remove(rowKey);
          _selectedRowKey = _bulkSelectedRowKeys.isEmpty
              ? null
              : _bulkSelectedRowKeys.last;
        } else {
          _bulkSelectedRowKeys.add(rowKey);
          _selectedRowKey = rowKey;
        }
        _selectionAnchorRowKey ??= rowKey;
        return;
      }
      _setSingleSelection(rowKey);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureRowVisible(rowKey);
    });
  }

  void _handleRowSecondarySelection(String rowKey, List<String> visibleKeys) {
    _gridRowsFocusNode.requestFocus();
    setState(() {
      if (_bulkSelectedRowKeys.contains(rowKey)) {
        _selectedRowKey = rowKey;
        _selectionAnchorRowKey ??= rowKey;
      } else {
        _setSingleSelection(rowKey);
      }
    });
  }

  void _beginDragSelection(String rowKey, List<String> visibleKeys) {
    if (_isCtrlOrCmdPressed() || _isShiftPressed()) return;
    _gridRowsFocusNode.requestFocus();
    setState(() {
      _dragSelectionActive = true;
      _dragSelectionKeys = visibleKeys;
      _dragSelectionAnchorKey = rowKey;
      _dragPointerGlobal = null;
      _setSingleSelection(rowKey);
    });
  }

  void _updateDragSelection(String rowKey) {
    if (!_dragSelectionActive || _dragSelectionAnchorKey == null) return;
    final visibleKeys = _dragSelectionKeys;
    final start = visibleKeys.indexOf(_dragSelectionAnchorKey!);
    final end = visibleKeys.indexOf(rowKey);
    if (start == -1 || end == -1) return;
    setState(() {
      final range = visibleKeys.sublist(
        start < end ? start : end,
        start < end ? end + 1 : start + 1,
      );
      _selectedRowKey = rowKey;
      _selectionAnchorRowKey = _dragSelectionAnchorKey;
      _bulkSelectedRowKeys
        ..clear()
        ..addAll(range);
    });
  }

  void _endDragSelection() {
    if (!_dragSelectionActive) return;
    setState(() {
      _dragSelectionActive = false;
      _dragSelectionKeys = const <String>[];
      _dragSelectionAnchorKey = null;
      _dragPointerGlobal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
    });
  }

  void _ensureRowVisible(String rowKey) {
    final rowContext = _rowItemKey(rowKey).currentContext;
    if (rowContext == null) return;
    Scrollable.ensureVisible(
      rowContext,
      alignment: 0.45,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  int? _visibleRowIndexAtGlobalPosition(
    Offset globalPosition,
    List<String> visibleKeys,
  ) {
    for (var i = 0; i < visibleKeys.length; i++) {
      final box =
          _rowItemKey(visibleKeys[i]).currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(globalPosition)) return i;
    }
    return null;
  }

  int? _mountedEdgeRowIndex(List<String> visibleKeys, {required bool last}) {
    final indexes = <int>[];
    for (var i = 0; i < visibleKeys.length; i++) {
      final box =
          _rowItemKey(visibleKeys[i]).currentContext?.findRenderObject()
              as RenderBox?;
      if (box != null && box.hasSize) indexes.add(i);
    }
    if (indexes.isEmpty) return null;
    return last ? indexes.last : indexes.first;
  }

  void _handleRowsPointerMove(
    PointerMoveEvent event,
    List<String> visibleKeys,
  ) {
    if (!_dragSelectionActive) return;
    _dragPointerGlobal = event.position;
    _updateDragAutoScroll(visibleKeys);
    final visibleIndex = _visibleRowIndexAtGlobalPosition(
      event.position,
      visibleKeys,
    );
    if (visibleIndex == null) return;
    _updateDragSelection(visibleKeys[visibleIndex]);
  }

  void _updateDragAutoScroll(List<String> visibleKeys) {
    if (!_dragSelectionActive || _dragPointerGlobal == null) {
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final box =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    const edge = 36.0;
    const maxStep = 18.0;
    final local = box.globalToLocal(_dragPointerGlobal!);
    final y = local.dy;
    if (y < edge) {
      _dragAutoScrollVelocity = -((edge - y) / edge).clamp(0.0, 1.0) * maxStep;
    } else if (y > box.size.height - edge) {
      _dragAutoScrollVelocity =
          ((y - (box.size.height - edge)) / edge).clamp(0.0, 1.0) * maxStep;
    } else {
      _dragAutoScrollVelocity = 0;
    }
    if (_dragAutoScrollVelocity == 0) {
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    _dragAutoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _performDragAutoScroll(visibleKeys),
    );
  }

  void _performDragAutoScroll(List<String> visibleKeys) {
    if (!_dragSelectionActive ||
        _dragAutoScrollVelocity == 0 ||
        !_rowsScrollController.hasClients) {
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final position = _rowsScrollController.position;
    final next = (position.pixels + _dragAutoScrollVelocity).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((next - position.pixels).abs() < 0.5) return;
    _rowsScrollController.jumpTo(next);
    final pointer = _dragPointerGlobal;
    final viewportBox =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (pointer == null || viewportBox == null || !viewportBox.hasSize) return;
    final visibleIndex = _visibleRowIndexAtGlobalPosition(pointer, visibleKeys);
    int? targetIndex = visibleIndex;
    if (targetIndex == null) {
      final local = viewportBox.globalToLocal(pointer);
      if (local.dy < 0) {
        targetIndex = _mountedEdgeRowIndex(visibleKeys, last: false);
      } else if (local.dy > viewportBox.size.height) {
        targetIndex = _mountedEdgeRowIndex(visibleKeys, last: true);
      }
    }
    if (targetIndex == null) return;
    _updateDragSelection(visibleKeys[targetIndex]);
  }

  KeyEventResult _handleGridKeyEvent(KeyEvent event, List<String> visibleKeys) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_isEditableTextFocused()) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_menuOpen) {
        setState(() => _menuOpen = false);
        return KeyEventResult.handled;
      }
      if (_bulkSelectedRowKeys.isNotEmpty) {
        setState(_clearSelection);
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final row = _selectedRowKey == null ? null : _rowByKey(_selectedRowKey!);
      if (row != null) unawaited(_editRow(row));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      if (_bulkSelectedRowKeys.isEmpty) return KeyEventResult.ignored;
      unawaited(_deleteSelectedRows());
      return KeyEventResult.handled;
    }
    if (visibleKeys.isEmpty) return KeyEventResult.ignored;
    final currentKey = _selectedRowKey ?? visibleKeys.first;
    final currentIndex = visibleKeys
        .indexOf(currentKey)
        .clamp(0, visibleKeys.length - 1);
    if (key == LogicalKeyboardKey.arrowDown) {
      final target =
          visibleKeys[(currentIndex + 1).clamp(0, visibleKeys.length - 1)];
      setState(() {
        if (_isShiftPressed()) {
          _selectRange(target, visibleKeys);
        } else {
          _setSingleSelection(target);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureRowVisible(target);
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      final target =
          visibleKeys[(currentIndex - 1).clamp(0, visibleKeys.length - 1)];
      setState(() {
        if (_isShiftPressed()) {
          _selectRange(target, visibleKeys);
        } else {
          _setSingleSelection(target);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureRowVisible(target);
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _saveRow(ComprasTicketRecord row) async {
    final previous = _rows;
    setState(() {
      final index = _rows.indexWhere((current) => current.id == row.id);
      if (index == -1) {
        _rows = <ComprasTicketRecord>[row, ..._rows];
      } else {
        _rows = [
          for (final current in _rows)
            if (current.id == row.id) row else current,
        ];
      }
      _setSingleSelection(_rowKey(row));
    });
    try {
      await ComprasTicketsStore.saveTicket(row);
    } catch (_) {
      if (!mounted) return;
      setState(() => _rows = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar el ticket. Se restauró el estado anterior.',
          ),
        ),
      );
    }
  }

  Future<void> _createRow() async {
    final saved = await showDialog<ComprasTicketRecord>(
      context: context,
      builder: (_) => _ComprasTicketEditDialog(
        providers: _providers,
        materials: _materials,
        prices: _prices,
      ),
    );
    if (saved == null) return;
    await _saveRow(saved);
  }

  Future<void> _editRow(ComprasTicketRecord row) async {
    final saved = await showDialog<ComprasTicketRecord>(
      context: context,
      builder: (_) => _ComprasTicketEditDialog(
        row: row,
        providers: _providers,
        materials: _materials,
        prices: _prices,
      ),
    );
    if (saved == null) return;
    await _saveRow(saved);
  }

  Future<void> _deleteSelectedRows() async {
    if (_bulkSelectedRowKeys.isEmpty || _deletingSelection) return;
    setState(() => _deletingSelection = true);
    final previous = _rows;
    final ids = _bulkSelectedRowKeys.map((key) => key.split(':').last).toSet();
    setState(() {
      _rows = _rows
          .where((row) => !ids.contains(row.id))
          .toList(growable: false);
      _clearSelection();
    });
    try {
      await ComprasTicketsStore.deleteTickets(ids);
    } catch (_) {
      if (!mounted) return;
      setState(() => _rows = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudieron eliminar los tickets. Se restauró el estado anterior.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingSelection = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _exportingCsv = true);
    final lines = <String>[
      'fecha,ticket,proveedor,material,bruto,tara,neto,humedad,basura,peso,precio,sobreprecio,importe,factura,pago,cobertura',
      for (final row in _visibleRows)
        [
          _dateLabel(row.date),
          row.ticket,
          row.providerNameSnapshot,
          row.materialNameSnapshot,
          row.grossWeight.toStringAsFixed(2),
          row.tareWeight.toStringAsFixed(2),
          row.netWeight.toStringAsFixed(2),
          row.humidityPercent.toStringAsFixed(2),
          row.trashPercent.toStringAsFixed(2),
          row.payableWeight.toStringAsFixed(2),
          row.price.toStringAsFixed(2),
          row.premium.toStringAsFixed(2),
          row.amount.toStringAsFixed(2),
          comprasFacturaStatusLabel(row.facturaStatus),
          comprasPagoStatusLabel(row.pagoStatus),
          comprasCoverageStatusLabel(row.coverageStatus),
        ].map(_csvCell).join(','),
    ];
    try {
      await saveCsvFile(
        fileName: 'compras_tickets.csv',
        content: lines.join('\n'),
      );
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  String _csvCell(String value) =>
      '"${value.replaceAll('"', '""').replaceAll('\n', ' ')}"';

  Future<void> _pickMultiFilter({
    required String title,
    required List<String> options,
    required Set<String> initialValues,
    required ValueChanged<Set<String>> onSelected,
  }) async {
    final result = await _showTicketsMultiSelectDialog<String>(
      context,
      title: title,
      options: options,
      initialValues: initialValues,
    );
    if (result == null || !mounted) return;
    setState(() => onSelected(result));
  }

  Future<void> _pickDateFilter() => _pickMultiFilter(
    title: 'Filtrar fecha',
    options: _rows.map((row) => _dateLabel(row.date)).toSet().toList()..sort(),
    initialValues: _dateFilters,
    onSelected: (value) => _dateFilters = value,
  );

  Future<void> _pickTicketFilter() => _pickMultiFilter(
    title: 'Filtrar ticket',
    options: _rows.map((row) => row.ticket).toSet().toList()..sort(),
    initialValues: _ticketFilters,
    onSelected: (value) => _ticketFilters = value,
  );

  Future<void> _pickProviderFilter() => _pickMultiFilter(
    title: 'Filtrar proveedor',
    options: _rows.map((row) => row.providerNameSnapshot).toSet().toList()
      ..sort(),
    initialValues: _providerFilters,
    onSelected: (value) => _providerFilters = value,
  );

  Future<void> _pickMaterialFilter() => _pickMultiFilter(
    title: 'Filtrar material',
    options: _rows.map((row) => row.materialNameSnapshot).toSet().toList()
      ..sort(),
    initialValues: _materialFilters,
    onSelected: (value) => _materialFilters = value,
  );

  Future<void> _pickFacturaFilter() => _pickMultiFilter(
    title: 'Filtrar factura',
    options: kComprasFacturaStatuses.map(comprasFacturaStatusLabel).toList(),
    initialValues: _facturaFilters,
    onSelected: (value) => _facturaFilters = value,
  );

  Future<void> _pickPagoFilter() => _pickMultiFilter(
    title: 'Filtrar pago',
    options: kComprasPagoStatuses.map(comprasPagoStatusLabel).toList(),
    initialValues: _pagoFilters,
    onSelected: (value) => _pagoFilters = value,
  );

  List<String> get _activeFilterLabels => <String>[
    for (final value in _dateFilters) 'Fecha: $value',
    for (final value in _ticketFilters) 'Ticket: $value',
    for (final value in _providerFilters) 'Proveedor: $value',
    for (final value in _materialFilters) 'Material: $value',
    for (final value in _facturaFilters) 'Factura: $value',
    for (final value in _pagoFilters) 'Pago: $value',
  ];

  void _clearAllFilters() {
    setState(() {
      _dateFilters.clear();
      _ticketFilters.clear();
      _providerFilters.clear();
      _materialFilters.clear();
      _facturaFilters.clear();
      _pagoFilters.clear();
    });
  }

  Future<void> _logout() async {
    await signOutAndRouteToLogin(context);
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openComprasDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ComprasDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openCatalog() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ComprasCatalogPage(instantOpen: true)),
    );
  }

  Future<void> _openPriceAdjustments() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ComprasPriceAdjustmentsPage(instantOpen: true)),
    );
  }

  Future<void> _openProviderDirectory() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ComprasProviderDirectoryPage(instantOpen: true)),
    );
  }

  Future<void> _openFinanzas() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const FinanzasDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Dirección':
        unawaited(_openDirectionDashboard());
        return;
      case 'Dashboard Compras':
        unawaited(_openComprasDashboard());
        return;
      case 'Catálogo Compras':
        unawaited(_openCatalog());
        return;
      case 'Ajuste de precios':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openPriceAdjustments());
        return;
      case 'Directorio Proveedores':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openProviderDirectory());
        return;
      case 'Tickets Compras':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      case 'Dashboard Finanzas':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openFinanzas());
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleRows = _visibleRows;
    final selectedRow = _selectedRowKey == null
        ? null
        : _rowByKey(_selectedRowKey!);
    return AreaThemeScope(
      tokens: comprasAreaTokens,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape && _menuOpen) {
            setState(() => _menuOpen = false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AppShell(
          background: const _ComprasTicketsBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => ComprasAreaHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => const _ComprasTicketsHeaderBrand(),
          trailingBuilder: (_, _) => ComprasAreaHeaderButton(
            label: 'Cerrar sesión',
            icon: Icons.logout_rounded,
            onTap: _logout,
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1480),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(56, 0, 6, 0),
                    child: Focus(
                      focusNode: _gridRowsFocusNode,
                      autofocus: true,
                      onKeyEvent: (_, event) =>
                          _handleGridKeyEvent(event, _visibleRowKeys),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (_bulkSelectedRowKeys.isNotEmpty) {
                            setState(_clearSelection);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
                              child: InventoryGridTopBar(
                                data: InventoryGridTopBarData(
                                  metricIcon:
                                      Icons.confirmation_number_outlined,
                                  metricLabel: 'TICKETS',
                                  metricValue: '${visibleRows.length}',
                                  metricSubtitle:
                                      '${_rows.length} registrados · ${visibleRows.where((row) => row.pagoStatus != 'PAGADO').length} abiertos',
                                  exportingCsv: _exportingCsv,
                                  gridEditMode: false,
                                  canToggleGridEdit: false,
                                  canDeleteSelection:
                                      _bulkSelectedRowKeys.isNotEmpty,
                                  deletingSelection: _deletingSelection,
                                  selectedCount: _bulkSelectedRowKeys.length,
                                  activeCellLabel: selectedRow?.ticket,
                                  onExportCsv: _exportCsv,
                                  onDeleteSelection: _deleteSelectedRows,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ContractGlassCard(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  14,
                                  14,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _ComprasTicketsFilterSummary(
                                            labels: _activeFilterLabels,
                                            onClearAll:
                                                _activeFilterLabels.isEmpty
                                                ? null
                                                : _clearAllFilters,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        FilledButton.icon(
                                          onPressed: _createRow,
                                          icon: const Icon(Icons.add_rounded),
                                          label: const Text('Nuevo ticket'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Expanded(
                                      child: _loading
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          : visibleRows.isEmpty
                                          ? _ComprasTicketsEmptyState(
                                              onCreate: _createRow,
                                            )
                                          : Column(
                                              children: [
                                                _ComprasTicketsHeaderRow(
                                                  contentWidth:
                                                      _kTicketContentW,
                                                  columns: [
                                                    _ComprasTicketsHeaderColumn(
                                                      'FECHA',
                                                      _kTicketDateW,
                                                      onFilter: _pickDateFilter,
                                                      active: _dateFilters
                                                          .isNotEmpty,
                                                    ),
                                                    _ComprasTicketsHeaderColumn(
                                                      'TICKET',
                                                      _kTicketNumberW,
                                                      onFilter:
                                                          _pickTicketFilter,
                                                      active: _ticketFilters
                                                          .isNotEmpty,
                                                    ),
                                                    _ComprasTicketsHeaderColumn(
                                                      'PROVEEDOR',
                                                      _kTicketProviderW,
                                                      onFilter:
                                                          _pickProviderFilter,
                                                      active: _providerFilters
                                                          .isNotEmpty,
                                                    ),
                                                    _ComprasTicketsHeaderColumn(
                                                      'MATERIAL',
                                                      _kTicketMaterialW,
                                                      onFilter:
                                                          _pickMaterialFilter,
                                                      active: _materialFilters
                                                          .isNotEmpty,
                                                    ),
                                                    const _ComprasTicketsHeaderColumn(
                                                      'BRUTO',
                                                      _kTicketGrossW,
                                                    ),
                                                    const _ComprasTicketsHeaderColumn(
                                                      'TARA',
                                                      _kTicketTareW,
                                                    ),
                                                    const _ComprasTicketsHeaderColumn(
                                                      'NETO',
                                                      _kTicketNetW,
                                                    ),
                                                    const _ComprasTicketsHeaderColumn(
                                                      'HUMEDAD',
                                                      _kTicketHumidityW,
                                                    ),
                                                    const _ComprasTicketsHeaderColumn(
                                                      'BASURA',
                                                      _kTicketTrashW,
                                                    ),
                                                    const _ComprasTicketsHeaderColumn(
                                                      'PESO',
                                                      _kTicketWeightW,
                                                    ),
                                                    const _ComprasTicketsHeaderColumn(
                                                      'PRECIO',
                                                      _kTicketPriceW,
                                                    ),
                                                    const _ComprasTicketsHeaderColumn(
                                                      'SOBREPRECIO',
                                                      _kTicketPremiumW,
                                                    ),
                                                    const _ComprasTicketsHeaderColumn(
                                                      'IMPORTE',
                                                      _kTicketAmountW,
                                                    ),
                                                    _ComprasTicketsHeaderColumn(
                                                      'FACTURA',
                                                      _kTicketFacturaW,
                                                      onFilter:
                                                          _pickFacturaFilter,
                                                      active: _facturaFilters
                                                          .isNotEmpty,
                                                    ),
                                                    _ComprasTicketsHeaderColumn(
                                                      'PAGO',
                                                      _kTicketPagoW,
                                                      onFilter: _pickPagoFilter,
                                                      active: _pagoFilters
                                                          .isNotEmpty,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Expanded(
                                                  child: Listener(
                                                    onPointerMove: (event) =>
                                                        _handleRowsPointerMove(
                                                          event,
                                                          _visibleRowKeys,
                                                        ),
                                                    onPointerUp: (_) =>
                                                        _endDragSelection(),
                                                    onPointerCancel: (_) =>
                                                        _endDragSelection(),
                                                    child: ListView.separated(
                                                      key: _rowsViewportKey,
                                                      controller:
                                                          _rowsScrollController,
                                                      itemCount:
                                                          visibleRows.length,
                                                      separatorBuilder:
                                                          (_, _) =>
                                                              const SizedBox(
                                                                height: 8,
                                                              ),
                                                      itemBuilder: (context, index) {
                                                        final row =
                                                            visibleRows[index];
                                                        final rowKey = _rowKey(
                                                          row,
                                                        );
                                                        return KeyedSubtree(
                                                          key: _rowItemKey(
                                                            rowKey,
                                                          ),
                                                          child: _ComprasTicketDataRow(
                                                            row: row,
                                                            dateLabel:
                                                                _dateLabel(
                                                                  row.date,
                                                                ),
                                                            weightFormatter:
                                                                _weight,
                                                            moneyFormatter:
                                                                _money,
                                                            selected:
                                                                _bulkSelectedRowKeys
                                                                    .contains(
                                                                      rowKey,
                                                                    ),
                                                            onTap: () =>
                                                                _handleRowSelection(
                                                                  rowKey,
                                                                  _visibleRowKeys,
                                                                ),
                                                            onPrimaryPointerDown: () =>
                                                                _beginDragSelection(
                                                                  rowKey,
                                                                  _visibleRowKeys,
                                                                ),
                                                            onDragEnter: () =>
                                                                _updateDragSelection(
                                                                  rowKey,
                                                                ),
                                                            onPointerEnd:
                                                                _endDragSelection,
                                                            onSecondarySelection: () =>
                                                                _handleRowSecondarySelection(
                                                                  rowKey,
                                                                  _visibleRowKeys,
                                                                ),
                                                            onEdit: () =>
                                                                _editRow(row),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ],
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
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_menuOpen,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _menuOpen ? 1 : 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _menuOpen = false),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: _menuOpen ? 0 : -332,
                top: 0,
                bottom: 0,
                width: 320,
                child: IgnorePointer(
                  ignoring: !_menuOpen,
                  child: ComprasAreaSidePanel(
                    label: 'Compras Mayoreo',
                    canReturnToDirection: _canReturnToDirection,
                    areaItems: [
                      ComprasAreaNavEntry(
                        icon: Icons.shopping_cart_checkout_rounded,
                        title: 'Dashboard Compras',
                        subtitle: 'Tickets y operación de compra',
                        onTap: () async =>
                            _handleNavigationAction('Dashboard Compras'),
                      ),
                      ComprasAreaNavEntry(
                        icon: Icons.price_check_rounded,
                        title: 'Catálogo Compras',
                        subtitle: 'Proveedores, materiales y precios',
                        onTap: () async =>
                            _handleNavigationAction('Catálogo Compras'),
                      ),
                      const ComprasAreaNavEntry(
                        icon: Icons.confirmation_number_outlined,
                        title: 'Tickets Compras',
                        subtitle: 'Captura y seguimiento operativo',
                        accented: true,
                      ),
                      ComprasAreaNavEntry(
                        icon: Icons.tune_rounded,
                        title: 'Ajuste de precios',
                        subtitle: 'Vigentes e historial operativo',
                        onTap: () async =>
                            _handleNavigationAction('Ajuste de precios'),
                      ),
                      ComprasAreaNavEntry(
                        icon: Icons.badge_rounded,
                        title: 'Directorio Proveedores',
                        subtitle: 'Crédito, contacto y operación',
                        onTap: () async =>
                            _handleNavigationAction('Directorio Proveedores'),
                      ),
                    ],
                    accessItems: [
                      if (_canReturnToDirection)
                        ComprasAreaNavEntry(
                          icon: Icons.assessment_outlined,
                          title: 'Dashboard Dirección',
                          subtitle: 'Vista ejecutiva multiarea',
                          onTap: () async =>
                              _handleNavigationAction('Dashboard Dirección'),
                        ),
                      if (_canAccessFinanzasArea)
                        ComprasAreaNavEntry(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Dashboard Finanzas',
                          subtitle: 'Pagos, liquidez y compromisos',
                          onTap: () async =>
                              _handleNavigationAction('Dashboard Finanzas'),
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

class _ComprasTicketEditDialog extends StatefulWidget {
  final ComprasTicketRecord? row;
  final List<ComprasCatalogProviderRecord> providers;
  final List<ComprasCatalogMaterialRecord> materials;
  final List<ComprasCatalogPriceRecord> prices;

  const _ComprasTicketEditDialog({
    this.row,
    required this.providers,
    required this.materials,
    required this.prices,
  });

  @override
  State<_ComprasTicketEditDialog> createState() =>
      _ComprasTicketEditDialogState();
}

class _ComprasTicketEditDialogState extends State<_ComprasTicketEditDialog> {
  late final TextEditingController _ticketC;
  late final TextEditingController _grossC;
  late final TextEditingController _tareC;
  late final TextEditingController _humidityC;
  late final TextEditingController _trashC;
  late final TextEditingController _priceC;
  late final TextEditingController _premiumC;
  late DateTime _date;
  String? _providerId;
  String? _materialId;
  late String _facturaStatus;
  late final String? _initialProviderId;
  late final String? _initialMaterialId;

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    _ticketC = TextEditingController(text: row?.ticket ?? '');
    _grossC = TextEditingController(
      text: row == null ? '' : row.grossWeight.toStringAsFixed(2),
    );
    _tareC = TextEditingController(
      text: row == null ? '' : row.tareWeight.toStringAsFixed(2),
    );
    _humidityC = TextEditingController(
      text: row == null ? '0' : row.humidityPercent.toStringAsFixed(2),
    );
    _trashC = TextEditingController(
      text: row == null ? '0' : row.trashPercent.toStringAsFixed(2),
    );
    _priceC = TextEditingController(
      text: row == null ? '' : row.price.toStringAsFixed(2),
    );
    _premiumC = TextEditingController(
      text: row == null ? '0' : row.premium.toStringAsFixed(2),
    );
    _date = row?.date ?? DateTime.now();
    _providerId = row?.providerId;
    _materialId = row?.materialId;
    _initialProviderId = row?.providerId;
    _initialMaterialId = row?.materialId;
    _facturaStatus = row?.facturaStatus ?? 'PENDIENTE_DE_FACTURAR';
    if (row == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncPriceFromSelection(force: true);
      });
    }
  }

  @override
  void dispose() {
    _ticketC.dispose();
    _grossC.dispose();
    _tareC.dispose();
    _humidityC.dispose();
    _trashC.dispose();
    _priceC.dispose();
    _premiumC.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  void _save() {
    final provider = _selectedProvider;
    final material = _selectedMaterial;
    if (_ticketC.text.trim().isEmpty || provider == null || material == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa ticket, proveedor y material.')),
      );
      return;
    }
    if (_priceC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Primero define un precio vigente en Ajuste de precios para ese proveedor y material.',
          ),
        ),
      );
      return;
    }
    final record = buildComprasTicketDraft(
      id:
          widget.row?.id ??
          'compras-ticket-${DateTime.now().microsecondsSinceEpoch}',
      date: _date,
      ticket: _ticketC.text.trim(),
      providerId: provider.id,
      providerNameSnapshot: provider.name,
      materialId: material.id,
      materialNameSnapshot: material.name,
      grossWeight: _parseDouble(_grossC.text),
      tareWeight: _parseDouble(_tareC.text),
      humidityPercent: _parseDouble(_humidityC.text),
      trashPercent: _parseDouble(_trashC.text),
      price: _parseDouble(_priceC.text),
      premium: _parseDouble(_premiumC.text),
      facturaStatus: _facturaStatus,
      pagoStatus: widget.row?.pagoStatus ?? 'PENDIENTE_DE_PAGO',
      coverageStatus: widget.row?.coverageStatus ?? 'SIN_CUBRIR',
    ).copyWith(createdAt: widget.row?.createdAt, updatedAt: DateTime.now());
    Navigator.of(context).pop(record);
  }

  double _parseDouble(String value) =>
      double.tryParse(value.replaceAll(',', '.').trim()) ?? 0;

  bool get _selectionMatchesOriginal =>
      _providerId == _initialProviderId && _materialId == _initialMaterialId;

  void _syncPriceFromSelection({bool force = false}) {
    final providerId = _providerId;
    final materialId = _materialId;
    if (providerId == null || materialId == null) return;
    if (!force && widget.row != null && _selectionMatchesOriginal) return;
    final currentPrice = resolveComprasCurrentPrice(
      prices: widget.prices,
      providerId: providerId,
      materialId: materialId,
    );
    _priceC.text = currentPrice?.toStringAsFixed(2) ?? '';
  }

  ComprasCatalogProviderRecord? get _selectedProvider {
    for (final row in widget.providers) {
      if (row.id == _providerId) return row;
    }
    return null;
  }

  ComprasCatalogMaterialRecord? get _selectedMaterial {
    for (final row in widget.materials) {
      if (row.id == _materialId) return row;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _selectedProvider;
    final material = _selectedMaterial;
    final preview = buildComprasTicketDraft(
      id: widget.row?.id ?? 'preview',
      date: _date,
      ticket: _ticketC.text.trim(),
      providerId: provider?.id ?? '',
      providerNameSnapshot: provider?.name ?? '',
      materialId: material?.id ?? '',
      materialNameSnapshot: material?.name ?? '',
      grossWeight: _parseDouble(_grossC.text),
      tareWeight: _parseDouble(_tareC.text),
      humidityPercent: _parseDouble(_humidityC.text),
      trashPercent: _parseDouble(_trashC.text),
      price: _parseDouble(_priceC.text),
      premium: _parseDouble(_premiumC.text),
      facturaStatus: _facturaStatus,
      pagoStatus: widget.row?.pagoStatus ?? 'PENDIENTE_DE_PAGO',
      coverageStatus: widget.row?.coverageStatus ?? 'SIN_CUBRIR',
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: ContractGlassCard(
          borderRadius: BorderRadius.circular(30),
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.row == null
                                ? 'Nuevo ticket'
                                : widget.row!.ticket,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF7A1914),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'El precio se toma del vigente configurado por proveedor y material, y queda congelado dentro del ticket.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kComprasMutedInk.withValues(alpha: 0.90),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _TicketDialogField(
                      width: 200,
                      label: 'Fecha',
                      icon: Icons.calendar_month_outlined,
                      value:
                          '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                      trailingIcon: Icons.keyboard_arrow_down_rounded,
                      onTap: _pickDate,
                      readOnly: true,
                    ),
                    _TicketDialogField(
                      width: 260,
                      label: 'Ticket',
                      icon: Icons.confirmation_number_outlined,
                      controller: _ticketC,
                      hintText: 'Escribe el ticket',
                    ),
                    _TicketPickerField<ComprasCatalogProviderRecord>(
                      width: 320,
                      label: 'Proveedor',
                      icon: Icons.storefront_outlined,
                      value: provider,
                      items: widget.providers,
                      hintText: 'Selecciona proveedor',
                      labelBuilder: (item) => item.name,
                      onChanged: (item) => setState(() {
                        _providerId = item?.id;
                        _syncPriceFromSelection();
                      }),
                    ),
                    _TicketPickerField<ComprasCatalogMaterialRecord>(
                      width: 320,
                      label: 'Material',
                      icon: Icons.precision_manufacturing_outlined,
                      value: material,
                      items: widget.materials,
                      hintText: 'Selecciona material',
                      labelBuilder: (item) => item.name,
                      onChanged: (item) => setState(() {
                        _materialId = item?.id;
                        _syncPriceFromSelection();
                      }),
                    ),
                    _TicketDialogField(
                      width: 160,
                      label: 'Precio',
                      icon: Icons.attach_money_rounded,
                      controller: _priceC,
                      hintText: 'Vigente por proveedor y material',
                      readOnly: true,
                    ),
                    _TicketDialogField(
                      width: 170,
                      label: 'Sobreprecio',
                      icon: Icons.trending_up_rounded,
                      controller: _premiumC,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    _TicketDialogField(
                      width: 150,
                      label: 'Bruto',
                      icon: Icons.scale_outlined,
                      controller: _grossC,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    _TicketDialogField(
                      width: 150,
                      label: 'Tara',
                      icon: Icons.line_weight_rounded,
                      controller: _tareC,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    _TicketDialogField(
                      width: 150,
                      label: 'Humedad %',
                      icon: Icons.water_drop_outlined,
                      controller: _humidityC,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    _TicketDialogField(
                      width: 150,
                      label: 'Basura %',
                      icon: Icons.delete_sweep_outlined,
                      controller: _trashC,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    _TicketPickerField<String>(
                      width: 240,
                      label: 'Factura',
                      icon: Icons.receipt_long_outlined,
                      value: _facturaStatus,
                      items: const ['SIN_FACTURA', 'PENDIENTE_DE_FACTURAR'],
                      hintText: 'Selecciona estatus',
                      labelBuilder: comprasFacturaStatusLabel,
                      onChanged: (item) => setState(
                        () => _facturaStatus = item ?? _facturaStatus,
                      ),
                    ),
                    _TicketDialogField(
                      width: 240,
                      label: 'Pago',
                      icon: Icons.account_balance_wallet_outlined,
                      value: comprasPagoStatusLabel(
                        widget.row?.pagoStatus ?? 'PENDIENTE_DE_PAGO',
                      ),
                      readOnly: true,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _TicketPreviewCard(preview: preview),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComprasTicketsHeaderBrand extends StatelessWidget {
  const _ComprasTicketsHeaderBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DicsaLogoD(size: 42, progress: 1),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tickets Compras',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFE6DBD8),
              ),
            ),
            Text(
              'Control operativo de compra mayoreo',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFD1C0BC),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ComprasTicketsHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _ComprasTicketsHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_ComprasTicketsHeaderButton> createState() =>
      _ComprasTicketsHeaderButtonState();
}

class _ComprasTicketsHeaderButtonState
    extends State<_ComprasTicketsHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: _hovered ? 1.026 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            onTap:
                widget.onTapSync ??
                (widget.onTap == null
                    ? null
                    : () => unawaited(widget.onTap!())),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _hovered ? -2.5 : 0, 0),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: _hovered ? 0.32 : 0.22),
                    tokens.surfaceTint.withValues(
                      alpha: _hovered ? 0.42 : 0.26,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _hovered
                      ? Colors.white.withValues(alpha: 0.76)
                      : Colors.white.withValues(alpha: 0.48),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: _hovered ? 28 : 16,
                    color: Colors.black.withValues(
                      alpha: _hovered ? 0.16 : 0.08,
                    ),
                    offset: Offset(0, _hovered ? 14 : 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 2),
                  Icon(widget.icon, size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComprasTicketsFilterSummary extends StatelessWidget {
  final List<String> labels;
  final VoidCallback? onClearAll;

  const _ComprasTicketsFilterSummary({required this.labels, this.onClearAll});

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty && onClearAll == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: comprasAreaTokens.badgeBackground.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: comprasAreaTokens.border.withValues(alpha: 0.70),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: kComprasInk,
              ),
            ),
          ),
        if (onClearAll != null)
          TextButton.icon(
            onPressed: onClearAll,
            icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
            label: const Text('Limpiar filtros'),
          ),
      ],
    );
  }
}

class _ComprasTicketsHeaderRow extends StatelessWidget {
  final List<_ComprasTicketsHeaderColumn> columns;
  final double contentWidth;

  const _ComprasTicketsHeaderRow({
    required this.columns,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w800);
    final tokens = AreaThemeScope.of(context);
    return Card(
      elevation: 0,
      color: Colors.black.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              child: ContractGridScaledRow(
                child: SizedBox(
                  width: contentWidth + _kTicketActionsW,
                  child: Row(
                    children: [
                      for (final column in columns)
                        SizedBox(
                          width: column.width,
                          child: Row(
                            children: [
                              if (column.onFilter != null) ...[
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: column.onFilter,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 140),
                                    curve: Curves.easeOutCubic,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: column.active
                                          ? tokens.primary
                                          : tokens.badgeBackground,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: column.active
                                            ? tokens.primaryStrong
                                            : tokens.border,
                                      ),
                                    ),
                                    child: Icon(
                                      column.active
                                          ? Icons.filter_alt
                                          : Icons.filter_alt_outlined,
                                      size: 15,
                                      color: column.active
                                          ? Colors.white
                                          : tokens.badgeText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Text(
                                    column.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: textStyle.copyWith(
                                      color: tokens.badgeText,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: _kTicketActionsW),
                    ],
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

class _ComprasTicketsHeaderColumn {
  final String label;
  final double width;
  final VoidCallback? onFilter;
  final bool active;

  const _ComprasTicketsHeaderColumn(
    this.label,
    this.width, {
    this.onFilter,
    this.active = false,
  });
}

class _ComprasTicketDataRow extends StatefulWidget {
  final ComprasTicketRecord row;
  final String dateLabel;
  final String Function(double value) weightFormatter;
  final String Function(double value) moneyFormatter;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onPrimaryPointerDown;
  final VoidCallback? onDragEnter;
  final VoidCallback? onPointerEnd;
  final VoidCallback? onSecondarySelection;
  final Future<void> Function() onEdit;

  const _ComprasTicketDataRow({
    required this.row,
    required this.dateLabel,
    required this.weightFormatter,
    required this.moneyFormatter,
    required this.selected,
    required this.onTap,
    this.onPrimaryPointerDown,
    this.onDragEnter,
    this.onPointerEnd,
    this.onSecondarySelection,
    required this.onEdit,
  });

  @override
  State<_ComprasTicketDataRow> createState() => _ComprasTicketDataRowState();
}

class _ComprasTicketDataRowState extends State<_ComprasTicketDataRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final fill = widget.selected
        ? tokens.primarySoft.withValues(alpha: 0.92)
        : _hovering
        ? Colors.white.withValues(alpha: 0.84)
        : Colors.white.withValues(alpha: 0.86);
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovering = true);
        widget.onDragEnter?.call();
      },
      onExit: (_) => setState(() => _hovering = false),
      child: Listener(
        onPointerDown: (event) {
          if ((event.buttons & kPrimaryMouseButton) != 0) {
            widget.onPrimaryPointerDown?.call();
          }
        },
        onPointerUp: (_) => widget.onPointerEnd?.call(),
        onPointerCancel: (_) => widget.onPointerEnd?.call(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            onDoubleTap: () => unawaited(widget.onEdit()),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.selected
                      ? tokens.primaryStrong.withValues(alpha: 0.30)
                      : Colors.white.withValues(alpha: 0.72),
                ),
              ),
              child: ContractGridScaledRow(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onSecondaryTapDown: (_) =>
                      widget.onSecondarySelection?.call(),
                  child: SizedBox(
                    width: _kTicketContentW + _kTicketActionsW,
                    child: Row(
                      children: [
                        _TicketCell(
                          width: _kTicketDateW,
                          text: widget.dateLabel,
                        ),
                        _TicketCell(
                          width: _kTicketNumberW,
                          text: widget.row.ticket,
                          bold: true,
                        ),
                        _TicketCell(
                          width: _kTicketProviderW,
                          text: widget.row.providerNameSnapshot,
                        ),
                        _TicketCell(
                          width: _kTicketMaterialW,
                          text: widget.row.materialNameSnapshot,
                        ),
                        _TicketCell(
                          width: _kTicketGrossW,
                          text: widget.weightFormatter(widget.row.grossWeight),
                          alignEnd: true,
                        ),
                        _TicketCell(
                          width: _kTicketTareW,
                          text: widget.weightFormatter(widget.row.tareWeight),
                          alignEnd: true,
                        ),
                        _TicketCell(
                          width: _kTicketNetW,
                          text: widget.weightFormatter(widget.row.netWeight),
                          alignEnd: true,
                        ),
                        _TicketCell(
                          width: _kTicketHumidityW,
                          text:
                              '${widget.row.humidityPercent.toStringAsFixed(2)}%',
                          alignEnd: true,
                        ),
                        _TicketCell(
                          width: _kTicketTrashW,
                          text:
                              '${widget.row.trashPercent.toStringAsFixed(2)}%',
                          alignEnd: true,
                        ),
                        _TicketCell(
                          width: _kTicketWeightW,
                          text: widget.weightFormatter(
                            widget.row.payableWeight,
                          ),
                          alignEnd: true,
                        ),
                        _TicketCell(
                          width: _kTicketPriceW,
                          text: widget.moneyFormatter(widget.row.price),
                          alignEnd: true,
                        ),
                        _TicketCell(
                          width: _kTicketPremiumW,
                          text: widget.moneyFormatter(widget.row.premium),
                          alignEnd: true,
                        ),
                        _TicketCell(
                          width: _kTicketAmountW,
                          text: widget.moneyFormatter(widget.row.amount),
                          alignEnd: true,
                          bold: true,
                        ),
                        _TicketCell(
                          width: _kTicketFacturaW,
                          child: _TicketBadge(
                            label: comprasFacturaStatusLabel(
                              widget.row.facturaStatus,
                            ),
                            tone: _facturaTone(widget.row.facturaStatus),
                          ),
                        ),
                        _TicketCell(
                          width: _kTicketPagoW,
                          child: _TicketBadge(
                            label: comprasPagoStatusLabel(
                              widget.row.pagoStatus,
                            ),
                            tone: _pagoTone(widget.row.pagoStatus),
                          ),
                        ),
                        SizedBox(
                          width: _kTicketActionsW,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: PopupMenuButton<String>(
                              tooltip: 'Acciones',
                              padding: EdgeInsets.zero,
                              onOpened: widget.onSecondarySelection,
                              onSelected: (value) {
                                if (value == 'edit') unawaited(widget.onEdit());
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, size: 18),
                                      SizedBox(width: 10),
                                      Text('Editar'),
                                    ],
                                  ),
                                ),
                              ],
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: widget.selected
                                      ? tokens.primarySoft.withValues(
                                          alpha: 0.42,
                                        )
                                      : Colors.white.withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: widget.selected
                                        ? tokens.primaryStrong.withValues(
                                            alpha: 0.36,
                                          )
                                        : comprasAreaTokens.border.withValues(
                                            alpha: 0.82,
                                          ),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.more_horiz_rounded,
                                  size: 18,
                                  color: kComprasInk,
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
            ),
          ),
        ),
      ),
    );
  }
}

Color _facturaTone(String status) {
  switch (status) {
    case 'FACTURADO':
      return const Color(0xFF0F766E);
    case 'PENDIENTE_DE_FACTURAR':
      return const Color(0xFF8B5E00);
    default:
      return const Color(0xFF6B7280);
  }
}

Color _pagoTone(String status) {
  switch (status) {
    case 'PAGADO':
      return const Color(0xFF0F766E);
    case 'ABONO':
      return const Color(0xFF8B5E00);
    default:
      return const Color(0xFFB42318);
  }
}

class _TicketCell extends StatelessWidget {
  final double width;
  final String? text;
  final Widget? child;
  final bool alignEnd;
  final bool bold;

  const _TicketCell({
    required this.width,
    this.text,
    this.child,
    this.alignEnd = false,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final content =
        child ??
        Text(
          text ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: kComprasInk,
            height: 1.15,
          ),
        );
    return SizedBox(
      width: width,
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: content,
        ),
      ),
    );
  }
}

class _TicketBadge extends StatelessWidget {
  final String label;
  final Color tone;

  const _TicketBadge({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: tone,
        ),
      ),
    );
  }
}

class _TicketDialogField extends StatelessWidget {
  final double width;
  final String label;
  final IconData icon;
  final IconData? trailingIcon;
  final TextEditingController? controller;
  final String? value;
  final bool readOnly;
  final String? hintText;
  final TextInputType? keyboardType;
  final VoidCallback? onTap;

  const _TicketDialogField({
    required this.width,
    required this.label,
    required this.icon,
    this.trailingIcon,
    this.controller,
    this.value,
    this.readOnly = false,
    this.hintText,
    this.keyboardType,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = _ticketDialogFieldDecoration(
      label: label,
      icon: icon,
      trailingIcon: trailingIcon,
      hintText: hintText,
    );
    return SizedBox(
      width: width,
      child: controller != null
          ? TextField(
              controller: controller,
              readOnly: readOnly || onTap != null,
              onTap: onTap,
              keyboardType: keyboardType,
              decoration: decoration,
            )
          : TextField(
              readOnly: true,
              controller: TextEditingController(text: value ?? ''),
              onTap: onTap,
              decoration: decoration,
            ),
    );
  }
}

class _TicketPickerField<T> extends StatelessWidget {
  final double width;
  final String label;
  final IconData icon;
  final T? value;
  final List<T> items;
  final String hintText;
  final String Function(T item) labelBuilder;
  final ValueChanged<T?> onChanged;

  const _TicketPickerField({
    required this.width,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.hintText,
    required this.labelBuilder,
    required this.onChanged,
  });

  Future<void> _openPicker(BuildContext context) async {
    final selected = await _showTicketsSingleSelectDialog<T>(
      context,
      title: label,
      initialValue: value,
      options: items
          .map(
            (item) =>
                _TicketsPickerOption<T>(value: item, label: labelBuilder(item)),
          )
          .toList(growable: false),
      allowClear: false,
    );
    if (selected == null) return;
    onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return _TicketDialogField(
      width: width,
      label: label,
      icon: icon,
      value: value == null ? '' : labelBuilder(value as T),
      hintText: hintText,
      trailingIcon: Icons.keyboard_arrow_down_rounded,
      readOnly: true,
      onTap: () => _openPicker(context),
    );
  }
}

InputDecoration _ticketDialogFieldDecoration({
  required String label,
  required IconData icon,
  IconData? trailingIcon,
  String? hintText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.94),
    prefixIcon: Icon(icon, color: const Color(0xFFB12720), size: 24),
    suffixIcon: trailingIcon == null
        ? null
        : Icon(trailingIcon, color: const Color(0xFFB48680), size: 24),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(
        color: const Color(0xFFD8B1AB).withValues(alpha: 0.56),
        width: 1.35,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: Color(0xFFB12720), width: 1.6),
    ),
  );
}

class _TicketPreviewCard extends StatelessWidget {
  final ComprasTicketRecord preview;

  const _TicketPreviewCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 18,
        children: [
          _PreviewMetric(
            label: 'Neto',
            value: preview.netWeight.toStringAsFixed(2),
          ),
          _PreviewMetric(
            label: 'Peso pagable',
            value: preview.payableWeight.toStringAsFixed(2),
          ),
          _PreviewMetric(
            label: 'Tarifa final',
            value: '\$${(preview.price + preview.premium).toStringAsFixed(2)}',
          ),
          _PreviewMetric(
            label: 'Importe',
            value: '\$${preview.amount.toStringAsFixed(2)}',
          ),
          _PreviewMetric(
            label: 'Factura',
            value: comprasFacturaStatusLabel(preview.facturaStatus),
          ),
          _PreviewMetric(
            label: 'Pago',
            value: comprasPagoStatusLabel(preview.pagoStatus),
          ),
        ],
      ),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: kComprasMutedInk.withValues(alpha: 0.80),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: kComprasInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComprasTicketsEmptyState extends StatelessWidget {
  final Future<void> Function() onCreate;

  const _ComprasTicketsEmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.confirmation_number_outlined,
              size: 44,
              color: kComprasMutedInk,
            ),
            const SizedBox(height: 12),
            const Text(
              'Todavía no hay tickets registrados.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kComprasInk,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Captura el primer ticket para empezar a construir cuenta por proveedor, facturación y pagos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kComprasMutedInk,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => unawaited(onCreate()),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo ticket'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComprasTicketsSidePanel extends StatelessWidget {
  final bool canReturnToDirection;
  final bool canAccessFinanzasArea;
  final ValueChanged<String> onNavigate;

  const _ComprasTicketsSidePanel({
    required this.canReturnToDirection,
    required this.canAccessFinanzasArea,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ContractGlassCard(
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Compras Mayoreo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              if (canReturnToDirection) ...[
                _ComprasTicketsNavItem(
                  icon: Icons.arrow_back_rounded,
                  title: 'Volver a Dirección',
                  onTap: () async => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 10),
              ],
              const _ComprasTicketsSectionHeader(label: 'AREA'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.primarySoft.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: tokens.primaryStrong.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  children: [
                    _ComprasTicketsNavItem(
                      icon: Icons.shopping_cart_checkout_rounded,
                      title: 'Dashboard Compras',
                      subtitle: 'Vista general del área',
                      onTap: () async => onNavigate('Dashboard Compras'),
                    ),
                    const SizedBox(height: 8),
                    _ComprasTicketsNavItem(
                      icon: Icons.price_check_rounded,
                      title: 'Catálogo Compras',
                      subtitle: 'Proveedores, materiales y precios',
                      onTap: () async => onNavigate('Catálogo Compras'),
                    ),
                    const SizedBox(height: 8),
                    _ComprasTicketsNavItem(
                      icon: Icons.confirmation_number_outlined,
                      title: 'Tickets Compras',
                      subtitle: 'Captura y seguimiento operativo',
                      accented: true,
                      onTap: () async {},
                    ),
                    const SizedBox(height: 8),
                    _ComprasTicketsNavItem(
                      icon: Icons.tune_rounded,
                      title: 'Ajuste de precios',
                      subtitle: 'Vigentes e historial',
                      onTap: () async => onNavigate('Ajuste de precios'),
                    ),
                    const SizedBox(height: 8),
                    _ComprasTicketsNavItem(
                      icon: Icons.badge_rounded,
                      title: 'Directorio Proveedores',
                      subtitle: 'Crédito, contacto y operación',
                      onTap: () async => onNavigate('Directorio Proveedores'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _ComprasTicketsSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              if (canReturnToDirection) ...[
                _ComprasTicketsNavItem(
                  icon: Icons.assessment_outlined,
                  title: 'Dashboard Dirección',
                  subtitle: 'Vista ejecutiva multiarea',
                  onTap: () async => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 8),
              ],
              if (canAccessFinanzasArea)
                _ComprasTicketsNavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Dashboard Finanzas',
                  subtitle: 'Pagos, liquidez y compromisos',
                  onTap: () async => onNavigate('Dashboard Finanzas'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComprasTicketsNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool accented;
  final Future<void> Function() onTap;

  const _ComprasTicketsNavItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.accented = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => unawaited(onTap()),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: accented
                ? tokens.primaryStrong.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accented
                  ? tokens.primaryStrong.withValues(alpha: 0.28)
                  : tokens.border.withValues(alpha: 0.46),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: accented ? tokens.primaryStrong : kComprasInk),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: accented ? tokens.primaryStrong : kComprasInk,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: kComprasMutedInk,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComprasTicketsSectionHeader extends StatelessWidget {
  final String label;

  const _ComprasTicketsSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.4,
        color: comprasAreaTokens.primaryStrong.withValues(alpha: 0.74),
      ),
    );
  }
}

class _ComprasTicketsBackground extends StatelessWidget {
  const _ComprasTicketsBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF181010), Color(0xFF241515), Color(0xFF3A2020)],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}

class _TicketsPickerOption<T> {
  final T value;
  final String label;

  const _TicketsPickerOption({required this.value, required this.label});
}

Future<T?> _showTicketsSingleSelectDialog<T>(
  BuildContext context, {
  required String title,
  required T? initialValue,
  required List<_TicketsPickerOption<T>> options,
  bool allowClear = false,
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(dialogContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      if (allowClear)
                        ListTile(
                          title: const Text('Limpiar filtro'),
                          onTap: () => Navigator.of(dialogContext).pop(null),
                        ),
                      for (final option in options)
                        ListTile(
                          title: Text(option.label),
                          trailing: option.value == initialValue
                              ? const Icon(Icons.check_rounded)
                              : null,
                          onTap: () =>
                              Navigator.of(dialogContext).pop(option.value),
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
  );
}

Future<Set<T>?> _showTicketsMultiSelectDialog<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required Set<T> initialValues,
}) {
  return showDialog<Set<T>>(
    context: context,
    builder: (dialogContext) {
      final selected = <T>{...initialValues};
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(dialogContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final option in options)
                            CheckboxListTile(
                              value: selected.contains(option),
                              title: Text(option.toString()),
                              onChanged: (checked) {
                                setDialogState(() {
                                  if (checked == true) {
                                    selected.add(option);
                                  } else {
                                    selected.remove(option);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(null),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () =>
                              setDialogState(() => selected.clear()),
                          child: const Text('Limpiar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(selected),
                          child: const Text('Aplicar'),
                        ),
                      ],
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
