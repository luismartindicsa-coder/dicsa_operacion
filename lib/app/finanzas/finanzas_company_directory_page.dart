import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../compras/compras_dashboard_page.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/archetypes/grid_editable/row/editable_row_actions_button.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/contract_menu_surface.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import 'finanzas_bank_accounts_page.dart';
import 'finanzas_catalog_page.dart';
import 'finanzas_fixed_payments_page.dart';
import 'finanzas_company_directory_store.dart';
import 'finanzas_dashboard_page.dart';
import 'finanzas_payment_center_page.dart';
import 'finanzas_provider_accounts_page.dart';
import 'finanzas_theme.dart';

const double _kFinDirActionsW = 96;
const double _kFinDirCompanyW = 260;
const double _kFinDirSourceW = 130;
const double _kFinDirLinkedNameW = 220;
const double _kFinDirContactW = 180;
const double _kFinDirPhoneW = 160;
const double _kFinDirLocationW = 200;
const double _kFinDirContainersW = 120;
const double _kFinDirContainerCountW = 96;
const double _kFinDirCreditDaysW = 110;
const double _kFinDirPaymentStageW = 150;
const double _kFinDirNotesW = 260;
const double _kFinDirContentW =
    _kFinDirCompanyW +
    _kFinDirSourceW +
    _kFinDirLinkedNameW +
    _kFinDirContactW +
    _kFinDirPhoneW +
    _kFinDirLocationW +
    _kFinDirContainersW +
    _kFinDirContainerCountW +
    _kFinDirCreditDaysW +
    _kFinDirPaymentStageW +
    _kFinDirNotesW;

const List<String> _kFinPaymentStageOptions = <String>[
  'AL_CORRIENTE',
  'ATRASADO',
  'CONVENIO',
  'PAGO_SEMANAL',
];

String _finPaymentStageLabel(String stage) {
  switch (stage) {
    case 'ATRASADO':
      return 'Atrasado';
    case 'CONVENIO':
      return 'Convenio';
    case 'PAGO_SEMANAL':
      return 'Pago semanal';
    default:
      return 'Al corriente';
  }
}

Color _finPaymentStageTone(String stage) {
  switch (stage) {
    case 'ATRASADO':
      return const Color(0xFFB42318);
    case 'CONVENIO':
      return const Color(0xFF7A1914);
    case 'PAGO_SEMANAL':
      return const Color(0xFF8B5E00);
    default:
      return const Color(0xFF0F766E);
  }
}

class FinanzasCompanyDirectoryPage extends StatefulWidget {
  final bool instantOpen;

  const FinanzasCompanyDirectoryPage({super.key, this.instantOpen = false});

  @override
  State<FinanzasCompanyDirectoryPage> createState() =>
      _FinanzasCompanyDirectoryPageState();
}

class _FinanzasCompanyDirectoryPageState
    extends State<FinanzasCompanyDirectoryPage> {
  bool _canReturnToDirection = false;
  bool _canAccessComprasArea = false;
  bool _menuOpen = false;
  bool _loading = true;
  bool _exportingCsv = false;
  final ScrollController _rowsScrollController = ScrollController();
  final GlobalKey _rowsViewportKey = GlobalKey(
    debugLabel: 'fin_directory_rows_viewport',
  );
  final Map<String, GlobalKey> _rowItemKeys = <String, GlobalKey>{};
  final FocusNode _gridRowsFocusNode = FocusNode(
    debugLabel: 'fin_directory_grid_rows',
  );
  Set<String> _companyNameFilters = <String>{};
  Set<String> _companySourceFilters = <String>{};
  Set<String> _linkedNameFilters = <String>{};
  Set<String> _contactFilters = <String>{};
  Set<String> _phoneFilters = <String>{};
  Set<String> _locationFilters = <String>{};
  bool? _hasContainersFilter;
  Set<String> _containerCountFilters = <String>{};
  Set<String> _creditDaysFilters = <String>{};
  String? _paymentStageFilter;
  Set<String> _paymentNotesFilters = <String>{};
  String? _selectedRowKey;
  String? _selectionAnchorRowKey;
  final Set<String> _bulkSelectedRowKeys = <String>{};
  bool _dragSelectionActive = false;
  List<String> _dragSelectionKeys = const <String>[];
  String? _dragSelectionAnchorKey;
  Offset? _dragPointerGlobal;
  double _dragAutoScrollVelocity = 0;
  Timer? _dragAutoScrollTimer;
  List<FinanzasCompanyDirectoryRecord> _rows =
      <FinanzasCompanyDirectoryRecord>[];

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadDirectory());
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
      _canAccessComprasArea = AuthAccess.canAccessComprasArea(profile);
    });
  }

  Future<void> _loadDirectory() async {
    setState(() => _loading = true);
    final rows = await FinanzasCompanyDirectoryStore.loadDirectory();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
      _pruneSelectionKeys();
    });
  }

  Future<void> _logout() async {
    await signOutAndRouteToLogin(context);
  }

  Future<void> _openDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openCatalog() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasCatalogPage(instantOpen: true)),
    );
  }

  Future<void> _openComprasDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const ComprasDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openProviderAccounts() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasProviderAccountsPage(instantOpen: true)),
    );
  }

  Future<void> _openBankAccounts() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasBankAccountsPage(instantOpen: true)),
    );
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openFixedPayments() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasFixedPaymentsPage(instantOpen: true)),
    );
  }

  Future<void> _openPaymentCenter() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasPaymentCenterPage(instantOpen: true)),
    );
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Dirección':
        unawaited(_openDirectionDashboard());
        return;
      case 'Dashboard Finanzas':
        unawaited(_openDashboard());
        return;
      case 'Catálogo Finanzas':
        unawaited(_openCatalog());
        return;
      case 'Dashboard Compras':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openComprasDashboard());
        return;
      case 'Directorio Empresas':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      case 'Cuentas por Proveedor':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openProviderAccounts());
        return;
      case 'Cuentas Bancarias':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openBankAccounts());
        return;
      case 'Pagos fijos':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openFixedPayments());
        return;
      case 'Centro de pagos':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openPaymentCenter());
        return;
    }
  }

  List<FinanzasCompanyDirectoryRecord> get _visibleRows {
    return _rows
        .where((row) {
          if (_companyNameFilters.isNotEmpty &&
              !_companyNameFilters.contains(row.companyName)) {
            return false;
          }
          if (_companySourceFilters.isNotEmpty &&
              !_companySourceFilters.contains(row.source)) {
            return false;
          }
          final linkedName = row.linkedName.isEmpty ? '—' : row.linkedName;
          if (_linkedNameFilters.isNotEmpty &&
              !_linkedNameFilters.contains(linkedName)) {
            return false;
          }
          final contact = row.operationalContact.isEmpty
              ? '—'
              : row.operationalContact;
          if (_contactFilters.isNotEmpty &&
              !_contactFilters.contains(contact)) {
            return false;
          }
          final phone = row.phone.isEmpty ? '—' : row.phone;
          if (_phoneFilters.isNotEmpty && !_phoneFilters.contains(phone)) {
            return false;
          }
          final location = row.location.isEmpty ? '—' : row.location;
          if (_locationFilters.isNotEmpty &&
              !_locationFilters.contains(location)) {
            return false;
          }
          if (_hasContainersFilter != null &&
              row.hasContainers != _hasContainersFilter) {
            return false;
          }
          final count = row.hasContainers ? '${row.containerCount}' : '0';
          if (_containerCountFilters.isNotEmpty &&
              !_containerCountFilters.contains(count)) {
            return false;
          }
          final credit = row.creditDays > 0
              ? '${row.creditDays} días'
              : 'Sin crédito';
          if (_creditDaysFilters.isNotEmpty &&
              !_creditDaysFilters.contains(credit)) {
            return false;
          }
          if (_paymentStageFilter != null &&
              row.paymentStage != _paymentStageFilter) {
            return false;
          }
          final notes = row.paymentNotes.isEmpty ? '—' : row.paymentNotes;
          if (_paymentNotesFilters.isNotEmpty &&
              !_paymentNotesFilters.contains(notes)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  String _rowKey(FinanzasCompanyDirectoryRecord row) => 'fd:${row.companyId}';

  List<String> get _visibleRowKeys =>
      _visibleRows.map(_rowKey).toList(growable: false);

  FinanzasCompanyDirectoryRecord? _rowByKey(String rowKey) {
    final id = rowKey.split(':').last;
    for (final row in _rows) {
      if (row.companyId == id) return row;
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
      () => GlobalKey(debugLabel: 'fin_directory_row_$rowKey'),
    );
  }

  bool _isRowSelected(String rowKey) => _bulkSelectedRowKeys.contains(rowKey);

  int get _selectedCount => _bulkSelectedRowKeys.length;

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

  void _focusGridRows() {
    final rowKeys = _visibleRowKeys;
    if (rowKeys.isEmpty) return;
    _gridRowsFocusNode.requestFocus();
    if (_selectedRowKey != null) return;
    setState(() => _setSingleSelection(rowKeys.first));
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
        return;
      }
      _setSingleSelection(rowKey);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureRowVisible(rowKey);
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
      final rowKey = _selectedRowKey;
      if (rowKey == null) return KeyEventResult.handled;
      final row = _rowByKey(rowKey);
      if (row != null) unawaited(_editRow(row));
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

  Future<void> _pickCompanyNameFilter() async {
    final selected = await _showFinDirectoryMultiSelectDialog<String>(
      context,
      title: 'Filtrar empresa',
      options:
          _rows.map((row) => row.companyName).toSet().toList(growable: false)
            ..sort(),
      initialValues: _companyNameFilters,
    );
    if (selected == null || !mounted) return;
    setState(() => _companyNameFilters = selected);
  }

  Future<void> _pickCompanySourceFilter() async {
    final selected = await _showFinDirectoryMultiSelectDialog<String>(
      context,
      title: 'Filtrar origen',
      options: _rows.map((row) => row.source).toSet().toList(growable: false)
        ..sort(),
      initialValues: _companySourceFilters,
    );
    if (selected == null || !mounted) return;
    setState(() => _companySourceFilters = selected);
  }

  Future<void> _pickLinkedNameFilter() async {
    final selected = await _showFinDirectoryMultiSelectDialog<String>(
      context,
      title: 'Filtrar vínculo',
      options:
          _rows
              .map((row) => row.linkedName.isEmpty ? '—' : row.linkedName)
              .toSet()
              .toList(growable: false)
            ..sort(),
      initialValues: _linkedNameFilters,
    );
    if (selected == null || !mounted) return;
    setState(() => _linkedNameFilters = selected);
  }

  Future<void> _pickContactFilter() async {
    final selected = await _showFinDirectoryMultiSelectDialog<String>(
      context,
      title: 'Filtrar contacto',
      options:
          _rows
              .map(
                (row) => row.operationalContact.isEmpty
                    ? '—'
                    : row.operationalContact,
              )
              .toSet()
              .toList(growable: false)
            ..sort(),
      initialValues: _contactFilters,
    );
    if (selected == null || !mounted) return;
    setState(() => _contactFilters = selected);
  }

  Future<void> _pickPhoneFilter() async {
    final selected = await _showFinDirectoryMultiSelectDialog<String>(
      context,
      title: 'Filtrar teléfono',
      options:
          _rows
              .map((row) => row.phone.isEmpty ? '—' : row.phone)
              .toSet()
              .toList(growable: false)
            ..sort(),
      initialValues: _phoneFilters,
    );
    if (selected == null || !mounted) return;
    setState(() => _phoneFilters = selected);
  }

  Future<void> _pickLocationFilter() async {
    final selected = await _showFinDirectoryMultiSelectDialog<String>(
      context,
      title: 'Filtrar ubicación',
      options:
          _rows
              .map((row) => row.location.isEmpty ? '—' : row.location)
              .toSet()
              .toList(growable: false)
            ..sort(),
      initialValues: _locationFilters,
    );
    if (selected == null || !mounted) return;
    setState(() => _locationFilters = selected);
  }

  Future<void> _pickContainersFilter() async {
    final value = await _showFinDirectorySingleSelectDialog<bool?>(
      context,
      title: 'Filtrar contenedores',
      initialValue: _hasContainersFilter,
      allowClear: true,
      options: const [
        _FinDirectoryPickerOption(value: true, label: 'Con contenedores'),
        _FinDirectoryPickerOption(value: false, label: 'Sin contenedores'),
      ],
    );
    if (!mounted) return;
    setState(() => _hasContainersFilter = value);
  }

  Future<void> _pickPaymentStageFilter() async {
    final value = await _showFinDirectorySingleSelectDialog<String?>(
      context,
      title: 'Filtrar situación de pago',
      initialValue: _paymentStageFilter,
      allowClear: true,
      options: [
        for (final option in _kFinPaymentStageOptions)
          _FinDirectoryPickerOption(
            value: option,
            label: _finPaymentStageLabel(option),
          ),
      ],
    );
    if (!mounted) return;
    setState(() => _paymentStageFilter = value);
  }

  Future<void> _pickContainerCountFilter() async {
    final selected = await _showFinDirectoryMultiSelectDialog<String>(
      context,
      title: 'Filtrar cantidad',
      options:
          _rows
              .map((row) => row.hasContainers ? '${row.containerCount}' : '0')
              .toSet()
              .toList(growable: false)
            ..sort(),
      initialValues: _containerCountFilters,
    );
    if (selected == null || !mounted) return;
    setState(() => _containerCountFilters = selected);
  }

  Future<void> _pickCreditDaysFilter() async {
    final selected = await _showFinDirectoryMultiSelectDialog<String>(
      context,
      title: 'Filtrar crédito',
      options:
          _rows
              .map(
                (row) => row.creditDays > 0
                    ? '${row.creditDays} días'
                    : 'Sin crédito',
              )
              .toSet()
              .toList(growable: false)
            ..sort(),
      initialValues: _creditDaysFilters,
    );
    if (selected == null || !mounted) return;
    setState(() => _creditDaysFilters = selected);
  }

  Future<void> _pickPaymentNotesFilter() async {
    final selected = await _showFinDirectoryMultiSelectDialog<String>(
      context,
      title: 'Filtrar notas',
      options:
          _rows
              .map((row) => row.paymentNotes.isEmpty ? '—' : row.paymentNotes)
              .toSet()
              .toList(growable: false)
            ..sort(),
      initialValues: _paymentNotesFilters,
    );
    if (selected == null || !mounted) return;
    setState(() => _paymentNotesFilters = selected);
  }

  void _clearAllFilters() {
    setState(() {
      _companyNameFilters = <String>{};
      _companySourceFilters = <String>{};
      _linkedNameFilters = <String>{};
      _contactFilters = <String>{};
      _phoneFilters = <String>{};
      _locationFilters = <String>{};
      _hasContainersFilter = null;
      _containerCountFilters = <String>{};
      _creditDaysFilters = <String>{};
      _paymentStageFilter = null;
      _paymentNotesFilters = <String>{};
    });
  }

  List<String> get _activeFilterLabels => <String>[
    for (final name in _companyNameFilters) 'Empresa: $name',
    for (final source in _companySourceFilters) 'Origen: $source',
    for (final linkedName in _linkedNameFilters) 'Vínculo: $linkedName',
    for (final contact in _contactFilters) 'Contacto: $contact',
    for (final phone in _phoneFilters) 'Teléfono: $phone',
    for (final location in _locationFilters) 'Ubicación: $location',
    if (_hasContainersFilter == true) 'Contenedores: Sí',
    if (_hasContainersFilter == false) 'Contenedores: No',
    for (final count in _containerCountFilters) 'Cantidad: $count',
    for (final credit in _creditDaysFilters) 'Crédito: $credit',
    if (_paymentStageFilter != null)
      'Situación: ${_finPaymentStageLabel(_paymentStageFilter!)}',
    for (final notes in _paymentNotesFilters) 'Notas: $notes',
  ];

  Future<void> _editRow(FinanzasCompanyDirectoryRecord row) async {
    final saved = await showDialog<FinanzasCompanyDirectoryRecord>(
      context: context,
      builder: (_) => AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: _FinDirectoryEditDialog(row: row),
      ),
    );
    if (saved == null) return;
    await _saveRow(saved);
  }

  Future<void> _saveRow(FinanzasCompanyDirectoryRecord row) async {
    final previous = _rows;
    setState(() {
      _rows = [
        for (final current in _rows)
          if (current.companyId == row.companyId) row else current,
      ];
      _setSingleSelection(_rowKey(row));
    });
    try {
      await FinanzasCompanyDirectoryStore.saveDirectoryRow(row);
    } catch (_) {
      if (!mounted) return;
      setState(() => _rows = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar el directorio. Se restauró el estado anterior.',
          ),
        ),
      );
    } finally {
      if (mounted) _focusGridRows();
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _exportingCsv = true);
    final rows = <String>[
      'empresa,origen,vinculo,contacto,telefono,ubicacion,contenedores,cantidad_contenedores,dias_credito,situacion_pago,notas_pago',
      for (final row in _visibleRows)
        [
          row.companyName,
          row.source,
          row.linkedName,
          row.operationalContact,
          row.phone,
          row.location,
          row.hasContainers ? 'SI' : 'NO',
          row.containerCount.toString(),
          row.creditDays.toString(),
          row.paymentStage,
          row.paymentNotes,
        ].map(_csvCell).join(','),
    ];
    try {
      await saveCsvFile(
        fileName: 'finanzas_directorio_empresas.csv',
        content: rows.join('\n'),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingCsv = false);
      }
    }
  }

  String _csvCell(String value) =>
      '"${value.replaceAll('"', '""').replaceAll('\n', ' ')}"';

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: finanzasAreaTokens,
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
          background: const _FinDirectoryBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => _FinDirectoryHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => const _FinDirectoryHeaderBrand(),
          trailingBuilder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FinDirectoryHeaderButton(
                label: 'Cerrar sesión',
                icon: Icons.logout_rounded,
                onTap: _logout,
              ),
            ],
          ),
          child: Stack(
            children: [
              _buildBody(),
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
                  child: _FinDirectorySidePanel(
                    canReturnToDirection: _canReturnToDirection,
                    canAccessComprasArea: _canAccessComprasArea,
                    onNavigate: _handleNavigationAction,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final visibleRows = _visibleRows;
    final visibleRowKeys = visibleRows.map(_rowKey).toList(growable: false);
    final selectedRow = _selectedRowKey == null
        ? null
        : _rowByKey(_selectedRowKey!);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(56, 0, 6, 0),
          child: Focus(
            focusNode: _gridRowsFocusNode,
            autofocus: true,
            onKeyEvent: (_, event) =>
                _handleGridKeyEvent(event, visibleRowKeys),
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
                    child: _FinDirectoryTopBar(
                      exportingCsv: _exportingCsv,
                      selectedCount: _selectedCount,
                      creditConfiguredCount: _rows
                          .where((row) => row.creditDays > 0)
                          .length,
                      totalCount: _rows.length,
                      activeLabel: selectedRow?.companyName,
                      onExportCsv: _exportCsv,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FinDirectorySurface(
                    child: Column(
                      children: [
                        _FinDirectoryFilterSummary(
                          labels: _activeFilterLabels,
                          onClearAll: _activeFilterLabels.isEmpty
                              ? null
                              : _clearAllFilters,
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : visibleRows.isEmpty
                              ? _FinDirectoryEmptyState(
                                  onReload: _loadDirectory,
                                )
                              : Column(
                                  children: [
                                    _FinDirectoryHeaderRow(
                                      contentWidth: _kFinDirContentW,
                                      columns: [
                                        _FinDirectoryHeaderColumn(
                                          'EMPRESA',
                                          _kFinDirCompanyW,
                                          onFilter: _pickCompanyNameFilter,
                                          active:
                                              _companyNameFilters.isNotEmpty,
                                        ),
                                        _FinDirectoryHeaderColumn(
                                          'ORIGEN',
                                          _kFinDirSourceW,
                                          onFilter: _pickCompanySourceFilter,
                                          active:
                                              _companySourceFilters.isNotEmpty,
                                        ),
                                        _FinDirectoryHeaderColumn(
                                          'VINCULO',
                                          _kFinDirLinkedNameW,
                                          onFilter: _pickLinkedNameFilter,
                                          active: _linkedNameFilters.isNotEmpty,
                                        ),
                                        _FinDirectoryHeaderColumn(
                                          'CONTACTO',
                                          _kFinDirContactW,
                                          onFilter: _pickContactFilter,
                                          active: _contactFilters.isNotEmpty,
                                        ),
                                        _FinDirectoryHeaderColumn(
                                          'TELÉFONO',
                                          _kFinDirPhoneW,
                                          onFilter: _pickPhoneFilter,
                                          active: _phoneFilters.isNotEmpty,
                                        ),
                                        _FinDirectoryHeaderColumn(
                                          'UBICACIÓN',
                                          _kFinDirLocationW,
                                          onFilter: _pickLocationFilter,
                                          active: _locationFilters.isNotEmpty,
                                        ),
                                        _FinDirectoryHeaderColumn(
                                          'CONTENEDORES',
                                          _kFinDirContainersW,
                                          onFilter: _pickContainersFilter,
                                          active: _hasContainersFilter != null,
                                        ),
                                        _FinDirectoryHeaderColumn(
                                          'CANTIDAD',
                                          _kFinDirContainerCountW,
                                          onFilter: _pickContainerCountFilter,
                                          active:
                                              _containerCountFilters.isNotEmpty,
                                        ),
                                        _FinDirectoryHeaderColumn(
                                          'CRÉDITO',
                                          _kFinDirCreditDaysW,
                                          onFilter: _pickCreditDaysFilter,
                                          active: _creditDaysFilters.isNotEmpty,
                                        ),
                                        _FinDirectoryHeaderColumn(
                                          'SITUACIÓN PAGO',
                                          _kFinDirPaymentStageW,
                                          onFilter: _pickPaymentStageFilter,
                                          active: _paymentStageFilter != null,
                                        ),
                                        _FinDirectoryHeaderColumn(
                                          'NOTAS DE PAGO',
                                          _kFinDirNotesW,
                                          onFilter: _pickPaymentNotesFilter,
                                          active:
                                              _paymentNotesFilters.isNotEmpty,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: Listener(
                                        onPointerMove: (event) =>
                                            _handleRowsPointerMove(
                                              event,
                                              visibleRowKeys,
                                            ),
                                        onPointerUp: (_) => _endDragSelection(),
                                        onPointerCancel: (_) =>
                                            _endDragSelection(),
                                        child: ListView.separated(
                                          key: _rowsViewportKey,
                                          controller: _rowsScrollController,
                                          itemCount: visibleRows.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 8),
                                          itemBuilder: (context, index) {
                                            final row = visibleRows[index];
                                            final rowKey = _rowKey(row);
                                            return KeyedSubtree(
                                              key: _rowItemKey(rowKey),
                                              child: _FinDirectoryDataRow(
                                                row: row,
                                                selected: _isRowSelected(
                                                  rowKey,
                                                ),
                                                onTap: () =>
                                                    _handleRowSelection(
                                                      rowKey,
                                                      visibleRowKeys,
                                                    ),
                                                onPrimaryPointerDown: () =>
                                                    _beginDragSelection(
                                                      rowKey,
                                                      visibleRowKeys,
                                                    ),
                                                onDragEnter: () =>
                                                    _updateDragSelection(
                                                      rowKey,
                                                    ),
                                                onPointerEnd: _endDragSelection,
                                                onSecondarySelection: () =>
                                                    _handleRowSecondarySelection(
                                                      rowKey,
                                                      visibleRowKeys,
                                                    ),
                                                onEdit: () => _editRow(row),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FinDirectoryEditDialog extends StatefulWidget {
  final FinanzasCompanyDirectoryRecord row;

  const _FinDirectoryEditDialog({required this.row});

  @override
  State<_FinDirectoryEditDialog> createState() =>
      _FinDirectoryEditDialogState();
}

class _FinDirectoryEditDialogState extends State<_FinDirectoryEditDialog> {
  late final TextEditingController _contactC;
  late final TextEditingController _phoneC;
  late final TextEditingController _locationC;
  late final TextEditingController _containerCountC;
  late final TextEditingController _creditDaysC;
  late final TextEditingController _paymentNotesC;
  late bool _hasContainers;
  late String _paymentStage;

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    _contactC = TextEditingController(text: row.operationalContact);
    _phoneC = TextEditingController(text: row.phone);
    _locationC = TextEditingController(text: row.location);
    _containerCountC = TextEditingController(
      text: row.containerCount == 0 ? '' : row.containerCount.toString(),
    );
    _creditDaysC = TextEditingController(
      text: row.creditDays == 0 ? '' : row.creditDays.toString(),
    );
    _paymentNotesC = TextEditingController(text: row.paymentNotes);
    _hasContainers = row.hasContainers;
    _paymentStage = row.paymentStage;
  }

  @override
  void dispose() {
    _contactC.dispose();
    _phoneC.dispose();
    _locationC.dispose();
    _containerCountC.dispose();
    _creditDaysC.dispose();
    _paymentNotesC.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      widget.row.copyWith(
        operationalContact: _contactC.text.trim(),
        phone: _phoneC.text.trim(),
        location: _locationC.text.trim(),
        hasContainers: _hasContainers,
        containerCount: _hasContainers
            ? int.tryParse(_containerCountC.text.trim()) ?? 0
            : 0,
        creditDays: int.tryParse(_creditDaysC.text.trim()) ?? 0,
        paymentStage: _paymentStage,
        paymentNotes: _paymentNotesC.text.trim(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: ContractGlassCard(
          borderRadius: BorderRadius.circular(34),
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.companyName,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              color: Color(0xFFFF8A3D),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ficha operativa para pagos, crédito y seguimiento financiero.',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.74),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    _FinDirectoryDialogCloseButton(
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: finanzasAreaTokens.primaryStrong.withValues(
                      alpha: 0.36,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: [
                    _FinDirectoryDialogField(
                      width: 430,
                      label: 'Origen',
                      icon: Icons.shopping_bag_outlined,
                      initialValue: row.source,
                      readOnly: true,
                      trailingIcon: Icons.keyboard_arrow_down_rounded,
                    ),
                    _FinDirectoryDialogField(
                      width: 430,
                      label: 'Vínculo catálogo',
                      icon: Icons.menu_book_outlined,
                      initialValue: row.linkedName,
                      readOnly: true,
                      trailingIcon: Icons.keyboard_arrow_down_rounded,
                    ),
                    _FinDirectoryDialogField(
                      width: 430,
                      label: 'Contacto',
                      icon: Icons.person_outline_rounded,
                      controller: _contactC,
                      hintText: 'Escribe el nombre del contacto',
                    ),
                    _FinDirectoryDialogField(
                      width: 430,
                      label: 'Teléfono',
                      icon: Icons.call_outlined,
                      controller: _phoneC,
                      keyboardType: TextInputType.phone,
                      hintText: 'Escribe el teléfono',
                    ),
                    _FinDirectoryDialogField(
                      width: 430,
                      label: 'Ubicación',
                      icon: Icons.place_outlined,
                      controller: _locationC,
                      hintText: 'Escribe la ubicación',
                    ),
                    _FinDirectoryDialogField(
                      width: 430,
                      label: 'Días de crédito',
                      icon: Icons.calendar_month_outlined,
                      controller: _creditDaysC,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      hintText: 'Ej. 30, 45, 60',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _FinDirectoryDialogSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Usa contenedores',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: _hasContainers,
                                  activeThumbColor: Colors.white,
                                  activeTrackColor: const Color(0xFFB12720),
                                  inactiveThumbColor: Colors.white,
                                  inactiveTrackColor: const Color(0xFFD3D5DA),
                                  onChanged: (value) {
                                    setState(() {
                                      _hasContainers = value;
                                      if (!value) _containerCountC.text = '';
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Útil para empresas ligadas a operación física.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _FinDirectoryDialogField(
                              width: double.infinity,
                              label: 'Cantidad',
                              icon: Icons.inventory_2_outlined,
                              controller: _containerCountC,
                              enabled: _hasContainers,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              hintText: 'Ingresa la cantidad',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(left: 18),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Situación de pago',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final option in _kFinPaymentStageOptions)
                                  _FinPaymentStageChoiceChip(
                                    stage: option,
                                    label: _finPaymentStageLabel(option),
                                    selected: _paymentStage == option,
                                    onTap: () =>
                                        setState(() => _paymentStage = option),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _FinDirectoryDialogField(
                  width: double.infinity,
                  label: 'Notas de pago / convenio / urgencia',
                  icon: Icons.description_outlined,
                  controller: _paymentNotesC,
                  hintText: 'Escribe las notas relevantes aquí...',
                  minLines: 3,
                  maxLines: 5,
                ),
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _FinDirectoryDialogTextButton(
                      label: 'Cancelar',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    _FinDirectoryDialogPrimaryButton(
                      label: 'Guardar',
                      icon: Icons.save_outlined,
                      onTap: _save,
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

class _FinDirectoryDialogField extends StatelessWidget {
  final double width;
  final String label;
  final IconData icon;
  final IconData? trailingIcon;
  final TextEditingController? controller;
  final String? initialValue;
  final bool readOnly;
  final bool enabled;
  final String? hintText;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _FinDirectoryDialogField({
    required this.width,
    required this.label,
    required this.icon,
    this.trailingIcon,
    this.controller,
    this.initialValue,
    this.readOnly = false,
    this.enabled = true,
    this.hintText,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  }) : assert(controller != null || initialValue != null);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: controller != null
          ? TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              cursorColor: finanzasAreaTokens.primaryStrong,
              readOnly: readOnly,
              enabled: enabled,
              minLines: minLines,
              maxLines: maxLines,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              decoration: _finDirectoryFieldDecoration(
                label: label,
                icon: icon,
                trailingIcon: trailingIcon,
                hintText: hintText,
              ),
            )
          : TextFormField(
              initialValue: initialValue,
              style: const TextStyle(color: Colors.white),
              readOnly: readOnly,
              enabled: enabled,
              minLines: minLines,
              maxLines: maxLines,
              decoration: _finDirectoryFieldDecoration(
                label: label,
                icon: icon,
                trailingIcon: trailingIcon,
                hintText: hintText,
              ),
            ),
    );
  }
}

InputDecoration _finDirectoryFieldDecoration({
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
    fillColor: finanzasAreaTokens.fieldSurface.withValues(alpha: 0.92),
    prefixIcon: Icon(icon, color: finanzasAreaTokens.primaryStrong, size: 28),
    suffixIcon: trailingIcon == null
        ? null
        : Icon(
            trailingIcon,
            color: finanzasAreaTokens.primaryStrong.withValues(alpha: 0.8),
            size: 28,
          ),
    hintStyle: TextStyle(
      color: Colors.white.withValues(alpha: 0.46),
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    labelStyle: TextStyle(
      color: Colors.white.withValues(alpha: 0.82),
      fontSize: 13,
      fontWeight: FontWeight.w900,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: 0.12),
        width: 1.35,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(
        color: finanzasAreaTokens.primaryStrong,
        width: 1.6,
      ),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: 0.08),
        width: 1.2,
      ),
    ),
  );
}

class _FinDirectoryDialogCloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _FinDirectoryDialogCloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: finanzasAreaTokens.fieldSurface.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                offset: const Offset(0, 8),
                color: Colors.black.withValues(alpha: 0.14),
              ),
            ],
          ),
          child: Icon(
            Icons.close_rounded,
            size: 34,
            color: finanzasAreaTokens.onGlass.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }
}

class _FinDirectoryDialogSectionCard extends StatelessWidget {
  final Widget child;

  const _FinDirectoryDialogSectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _FinDirectoryDialogTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FinDirectoryDialogTextButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: contractSecondaryButtonStyle(context).copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(150, 58)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ),
      child: Text(label),
    );
  }
}

class _FinDirectoryDialogPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _FinDirectoryDialogPrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: contractPrimaryButtonStyle(context).copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(180, 58)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _FinDirectorySurface extends StatelessWidget {
  final Widget child;
  const _FinDirectorySurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ContractGlassCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: child,
      ),
    );
  }
}

class _FinPaymentStageChoiceChip extends StatelessWidget {
  final String stage;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FinPaymentStageChoiceChip({
    required this.stage,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = _finPaymentStageTone(stage);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? tone
                : finanzasAreaTokens.fieldSurface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? tone : tone.withValues(alpha: 0.42),
              width: 1.4,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                      color: tone.withValues(alpha: 0.18),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : tone,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FinDirectoryFilterSummary extends StatelessWidget {
  final List<String> labels;
  final VoidCallback? onClearAll;

  const _FinDirectoryFilterSummary({required this.labels, this.onClearAll});

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
              color: finanzasAreaTokens.badgeBackground.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: finanzasAreaTokens.border.withValues(alpha: 0.46),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: finanzasAreaTokens.onGlass,
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

class _FinDirectoryHeaderRow extends StatelessWidget {
  final List<_FinDirectoryHeaderColumn> columns;
  final double contentWidth;

  const _FinDirectoryHeaderRow({
    required this.columns,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w800);
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            child: ContractGridScaledRow(
              child: SizedBox(
                width: contentWidth + _kFinDirActionsW,
                child: Row(
                  children: [
                    for (final column in columns)
                      SizedBox(
                        width: column.width,
                        child: Row(
                          children: [
                            if (column.onFilter != null) ...[
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: column.onFilter,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: column.active
                                        ? tokens.primary.withValues(alpha: 0.86)
                                        : tokens.badgeBackground.withValues(
                                            alpha: 0.18,
                                          ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: column.active
                                          ? tokens.primaryStrong
                                          : tokens.border.withValues(
                                              alpha: 0.64,
                                            ),
                                    ),
                                  ),
                                  child: Icon(
                                    column.active
                                        ? Icons.filter_alt
                                        : Icons.filter_alt_outlined,
                                    size: 15,
                                    color: column.active
                                        ? Colors.white
                                        : tokens.onGlass.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Text(
                                  column.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: textStyle.copyWith(
                                    color: tokens.onGlass.withValues(
                                      alpha: 0.92,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: _kFinDirActionsW),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FinDirectoryHeaderColumn {
  final String label;
  final double width;
  final VoidCallback? onFilter;
  final bool active;

  const _FinDirectoryHeaderColumn(
    this.label,
    this.width, {
    this.onFilter,
    this.active = false,
  });
}

class _FinDirectoryDataRow extends StatefulWidget {
  final FinanzasCompanyDirectoryRecord row;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onPrimaryPointerDown;
  final VoidCallback? onDragEnter;
  final VoidCallback? onPointerEnd;
  final VoidCallback? onSecondarySelection;
  final Future<void> Function() onEdit;

  const _FinDirectoryDataRow({
    required this.row,
    required this.selected,
    required this.onTap,
    this.onPrimaryPointerDown,
    this.onDragEnter,
    this.onPointerEnd,
    this.onSecondarySelection,
    required this.onEdit,
  });

  @override
  State<_FinDirectoryDataRow> createState() => _FinDirectoryDataRowState();
}

class _FinDirectoryDataRowState extends State<_FinDirectoryDataRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final selected = widget.selected;
    final fill = selected
        ? tokens.primary.withValues(alpha: 0.78)
        : _hovering
        ? const Color(0xE2171B23)
        : const Color(0xCC171B23);
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
                  color: selected
                      ? tokens.primaryStrong.withValues(alpha: 0.96)
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: ContractGridScaledRow(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onSecondaryTapDown: (_) =>
                      widget.onSecondarySelection?.call(),
                  child: SizedBox(
                    width: _kFinDirContentW + _kFinDirActionsW,
                    child: Row(
                      children: [
                        _FinDirectoryCell(
                          width: _kFinDirCompanyW,
                          text: widget.row.companyName,
                          bold: true,
                        ),
                        _FinDirectoryCell(
                          width: _kFinDirSourceW,
                          text: widget.row.source,
                        ),
                        _FinDirectoryCell(
                          width: _kFinDirLinkedNameW,
                          text: widget.row.linkedName.isEmpty
                              ? '—'
                              : widget.row.linkedName,
                        ),
                        _FinDirectoryCell(
                          width: _kFinDirContactW,
                          text: widget.row.operationalContact.isEmpty
                              ? '—'
                              : widget.row.operationalContact,
                        ),
                        _FinDirectoryCell(
                          width: _kFinDirPhoneW,
                          text: widget.row.phone.isEmpty
                              ? '—'
                              : widget.row.phone,
                        ),
                        _FinDirectoryCell(
                          width: _kFinDirLocationW,
                          text: widget.row.location.isEmpty
                              ? '—'
                              : widget.row.location,
                        ),
                        _FinDirectoryCell(
                          width: _kFinDirContainersW,
                          child: _FinDirectoryBadge(
                            label: widget.row.hasContainers ? 'SI' : 'NO',
                            active: widget.row.hasContainers,
                          ),
                        ),
                        _FinDirectoryCell(
                          width: _kFinDirContainerCountW,
                          text: widget.row.hasContainers
                              ? '${widget.row.containerCount}'
                              : '0',
                          alignEnd: true,
                        ),
                        _FinDirectoryCell(
                          width: _kFinDirCreditDaysW,
                          text: widget.row.creditDays > 0
                              ? '${widget.row.creditDays} días'
                              : 'Sin crédito',
                        ),
                        _FinDirectoryCell(
                          width: _kFinDirPaymentStageW,
                          child: _FinDirectoryBadge(
                            label: _finPaymentStageLabel(
                              widget.row.paymentStage,
                            ),
                            active: widget.row.paymentStage != 'AL_CORRIENTE',
                            tone: _finPaymentStageTone(widget.row.paymentStage),
                          ),
                        ),
                        _FinDirectoryCell(
                          width: _kFinDirNotesW,
                          text: widget.row.paymentNotes.isEmpty
                              ? '—'
                              : widget.row.paymentNotes,
                        ),
                        SizedBox(
                          width: _kFinDirActionsW,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.black.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? Colors.white.withValues(alpha: 0.22)
                                      : Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: EditableRowActionsButton<String>(
                                tooltip: 'Acciones',
                                iconColor: selected
                                    ? Colors.white
                                    : tokens.onGlass.withValues(alpha: 0.96),
                                entries: const [
                                  ContractMenuEntry<String>(
                                    value: 'edit',
                                    label: 'Editar',
                                    icon: Icons.edit_rounded,
                                  ),
                                ],
                                onSelected: (value) {
                                  widget.onSecondarySelection?.call();
                                  if (value == 'edit') {
                                    unawaited(widget.onEdit());
                                  }
                                },
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

class _FinDirectoryCell extends StatelessWidget {
  final double width;
  final String? text;
  final Widget? child;
  final bool alignEnd;
  final bool bold;
  const _FinDirectoryCell({
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
            color: Colors.white,
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

class _FinDirectoryBadge extends StatelessWidget {
  final String label;
  final bool active;
  final Color? tone;
  const _FinDirectoryBadge({
    required this.label,
    required this.active,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final resolvedTone = tone ?? tokens.primaryStrong;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? resolvedTone.withValues(alpha: 0.10)
            : tokens.badgeBackground.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? resolvedTone.withValues(alpha: 0.24)
              : tokens.border.withValues(alpha: 0.40),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: active ? resolvedTone : tokens.badgeText,
        ),
      ),
    );
  }
}

class _FinDirectoryEmptyState extends StatelessWidget {
  final Future<void> Function() onReload;
  const _FinDirectoryEmptyState({required this.onReload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_outlined,
              size: 44,
              color: kFinanzasMutedInk,
            ),
            const SizedBox(height: 12),
            const Text(
              'No hay empresas visibles todavía.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kFinanzasInk,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sincroniza catálogo o agrega empresas desde Catálogo Finanzas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => unawaited(onReload()),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Recargar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinDirectoryPickerOption<T> {
  final T value;
  final String label;

  const _FinDirectoryPickerOption({required this.value, required this.label});
}

Future<T?> _showFinDirectorySingleSelectDialog<T>(
  BuildContext context, {
  required String title,
  required T initialValue,
  required List<_FinDirectoryPickerOption<T>> options,
  bool allowClear = false,
}) {
  final searchC = TextEditingController();
  int? hoveredIndex;
  return showDialog<T>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          final query = searchC.text.trim().toLowerCase();
          final filtered = options
              .where(
                (option) =>
                    query.isEmpty || option.label.toLowerCase().contains(query),
              )
              .toList(growable: false);
          return AreaThemeScope(
            tokens: finanzasAreaTokens,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                  maxHeight: 520,
                ),
                child: FinanzasGlassPanel(
                  borderRadius: BorderRadius.circular(28),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  fillColor: const Color(0x1813171F),
                  borderColor: Colors.white.withValues(alpha: 0.22),
                  edgeHighlightColor: Colors.white.withValues(alpha: 0.18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF8A3D),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Builder(
                        builder: (themedContext) => TextField(
                          controller: searchC,
                          onChanged: (_) =>
                              setLocalState(() => hoveredIndex = null),
                          style: const TextStyle(color: Colors.white),
                          cursorColor: finanzasAreaTokens.primaryStrong,
                          decoration: contractGlassFieldDecoration(
                            themedContext,
                            hintText: 'Buscar opción',
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Colors.white.withValues(alpha: 0.56),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            if (allowClear)
                              _FinDirectoryPickerOptionTile(
                                title: 'Limpiar filtro',
                                hovered: hoveredIndex == -1,
                                onHoverChanged: (hovered) => setLocalState(
                                  () => hoveredIndex = hovered ? -1 : null,
                                ),
                                onTap: () =>
                                    Navigator.of(dialogContext).pop(null),
                              ),
                            if (allowClear) const SizedBox(height: 8),
                            for (var i = 0; i < filtered.length; i++) ...[
                              _FinDirectoryPickerOptionTile(
                                title: filtered[i].label,
                                selected: filtered[i].value == initialValue,
                                hovered: hoveredIndex == i,
                                onHoverChanged: (hovered) => setLocalState(
                                  () => hoveredIndex = hovered ? i : null,
                                ),
                                onTap: () => Navigator.of(
                                  dialogContext,
                                ).pop(filtered[i].value),
                              ),
                              if (i != filtered.length - 1)
                                const SizedBox(height: 8),
                            ],
                          ],
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
    },
  );
}

Future<Set<T>?> _showFinDirectoryMultiSelectDialog<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required Set<T> initialValues,
}) {
  final searchC = TextEditingController();
  int? hoveredIndex;
  return showDialog<Set<T>>(
    context: context,
    builder: (dialogContext) {
      final selected = <T>{...initialValues};
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final query = searchC.text.trim().toLowerCase();
          final filtered = options
              .where(
                (option) =>
                    query.isEmpty ||
                    option.toString().toLowerCase().contains(query),
              )
              .toList(growable: false);
          return AreaThemeScope(
            tokens: finanzasAreaTokens,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 440,
                  maxHeight: 520,
                ),
                child: FinanzasGlassPanel(
                  borderRadius: BorderRadius.circular(28),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  fillColor: const Color(0x1813171F),
                  borderColor: Colors.white.withValues(alpha: 0.22),
                  edgeHighlightColor: Colors.white.withValues(alpha: 0.18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF8A3D),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (themedContext) => TextField(
                          controller: searchC,
                          onChanged: (_) =>
                              setDialogState(() => hoveredIndex = null),
                          style: const TextStyle(color: Colors.white),
                          cursorColor: finanzasAreaTokens.primaryStrong,
                          decoration: contractGlassFieldDecoration(
                            themedContext,
                            hintText: 'Buscar opción',
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Colors.white.withValues(alpha: 0.56),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (var i = 0; i < filtered.length; i++) ...[
                              _FinDirectoryPickerOptionTile(
                                title: filtered[i].toString(),
                                selected: selected.contains(filtered[i]),
                                hovered: hoveredIndex == i,
                                onHoverChanged: (hovered) => setDialogState(
                                  () => hoveredIndex = hovered ? i : null,
                                ),
                                onTap: () {
                                  setDialogState(() {
                                    if (selected.contains(filtered[i])) {
                                      selected.remove(filtered[i]);
                                    } else {
                                      selected.add(filtered[i]);
                                    }
                                  });
                                },
                              ),
                              if (i != filtered.length - 1)
                                const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (themedContext) => Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(null),
                              style: contractSecondaryButtonStyle(
                                themedContext,
                              ),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 10),
                            TextButton(
                              onPressed: () {
                                setDialogState(() => selected.clear());
                              },
                              style: contractGhostButtonStyle(themedContext),
                              child: const Text('Limpiar'),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(selected),
                              style: contractPrimaryButtonStyle(themedContext),
                              child: const Text('Aplicar'),
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
        },
      );
    },
  );
}

class _FinDirectoryBackground extends StatelessWidget {
  const _FinDirectoryBackground();

  @override
  Widget build(BuildContext context) => const FinanzasAreaBackground();
}

class _FinDirectoryPickerOptionTile extends StatefulWidget {
  final String title;
  final bool selected;
  final bool hovered;
  final ValueChanged<bool>? onHoverChanged;
  final VoidCallback onTap;

  const _FinDirectoryPickerOptionTile({
    required this.title,
    required this.onTap,
    this.selected = false,
    this.hovered = false,
    this.onHoverChanged,
  });

  @override
  State<_FinDirectoryPickerOptionTile> createState() =>
      _FinDirectoryPickerOptionTileState();
}

class _FinDirectoryPickerOptionTileState
    extends State<_FinDirectoryPickerOptionTile> {
  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final selected = widget.selected;
    final hovered = widget.hovered;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => widget.onHoverChanged?.call(true),
      onExit: (_) => widget.onHoverChanged?.call(false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? tokens.primaryStrong.withValues(alpha: 0.16)
                  : hovered
                  ? tokens.primaryStrong.withValues(alpha: 0.12)
                  : const Color(0xCC171C24),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? tokens.primaryStrong.withValues(alpha: 0.54)
                    : hovered
                    ? tokens.primaryStrong.withValues(alpha: 0.42)
                    : Colors.white.withValues(alpha: 0.14),
              ),
              boxShadow: selected || hovered
                  ? [
                      BoxShadow(
                        color: tokens.primaryStrong.withValues(
                          alpha: selected ? 0.16 : 0.10,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: selected || hovered
                          ? tokens.primaryStrong
                          : kFinanzasInk,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 10),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: tokens.primaryStrong,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinDirectoryTopBar extends StatelessWidget {
  final bool exportingCsv;
  final int selectedCount;
  final int creditConfiguredCount;
  final int totalCount;
  final String? activeLabel;
  final Future<void> Function() onExportCsv;

  const _FinDirectoryTopBar({
    required this.exportingCsv,
    required this.selectedCount,
    required this.creditConfiguredCount,
    required this.totalCount,
    required this.activeLabel,
    required this.onExportCsv,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          _FinDirectoryTopActionButton(
            label: exportingCsv ? 'Exportando CSV...' : 'Descargar CSV',
            icon: exportingCsv
                ? Icons.downloading_rounded
                : Icons.download_rounded,
            enabled: !exportingCsv,
            onTap: onExportCsv,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DIRECTORIO $totalCount',
                  style: TextStyle(
                    color: tokens.primaryStrong,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$creditConfiguredCount con crédito definido'
                  '${activeLabel == null ? '' : ' • Activa: $activeLabel'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.onGlass.withValues(alpha: 0.72),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            selectedCount == 1
                ? '1 seleccionada'
                : '$selectedCount seleccionadas',
            style: TextStyle(
              color: tokens.onGlass,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinDirectoryTopActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final Future<void> Function() onTap;

  const _FinDirectoryTopActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return FilledButton.icon(
      onPressed: enabled ? () => unawaited(onTap()) : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.primaryStrong,
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.26)),
        disabledForegroundColor: tokens.badgeText.withValues(alpha: 0.55),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _FinDirectoryHeaderBrand extends StatelessWidget {
  const _FinDirectoryHeaderBrand();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.44)),
            boxShadow: [
              BoxShadow(
                color: tokens.primaryStrong.withValues(alpha: 0.16),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(child: DicsaLogoD(size: 40, progress: 1)),
        ),
        const SizedBox(width: 20),
        const Text(
          'Directorio Empresas',
          maxLines: 1,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.25,
            height: 1.0,
            color: kFinanzasInk,
          ),
        ),
      ],
    );
  }
}

class _FinDirectorySidePanel extends StatelessWidget {
  final bool canReturnToDirection;
  final bool canAccessComprasArea;
  final ValueChanged<String> onNavigate;
  const _FinDirectorySidePanel({
    required this.canReturnToDirection,
    required this.canAccessComprasArea,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return FinanzasAreaSidePanel(
      currentLabel: 'Directorio Empresas',
      canReturnToDirection: canReturnToDirection,
      canAccessComprasArea: canAccessComprasArea,
      onNavigate: onNavigate,
    );
  }
}

class _FinDirectoryHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  const _FinDirectoryHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_FinDirectoryHeaderButton> createState() =>
      _FinDirectoryHeaderButtonState();
}

class _FinDirectoryHeaderButtonState extends State<_FinDirectoryHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final enabled = widget.onTap != null || widget.onTapSync != null;
    final highlighted = enabled && _hovered;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: highlighted ? 1.026 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            onTap: !enabled
                ? null
                : () async {
                    if (widget.onTap != null) {
                      await widget.onTap!();
                    } else {
                      widget.onTapSync?.call();
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(
                0,
                highlighted ? -2.5 : 0,
                0,
              ),
              width: 176,
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: highlighted ? 0.32 : 0.22),
                    tokens.surfaceTint.withValues(
                      alpha: highlighted ? 0.42 : 0.26,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: highlighted
                      ? Colors.white.withValues(alpha: 0.76)
                      : Colors.white.withValues(alpha: 0.48),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: highlighted ? 28 : 16,
                    color: Colors.black.withValues(
                      alpha: highlighted ? 0.16 : 0.08,
                    ),
                    offset: Offset(0, highlighted ? 14 : 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: tokens.primaryStrong, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.primaryStrong,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
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
