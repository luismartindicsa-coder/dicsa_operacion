import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../compras/compras_dashboard_page.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/archetypes/auxiliary_surfaces/confirmation_dialog.dart';
import '../shared/archetypes/grid_editable/filters/grid_filter_dialog.dart';
import '../shared/archetypes/grid_editable/filters/grid_filter_state.dart';
import '../shared/archetypes/grid_editable/grid_keyboard_shell.dart';
import '../shared/archetypes/grid_editable/grid_navigation_controller.dart';
import '../shared/archetypes/grid_editable/grid_scroll_visibility_coordinator.dart';
import '../shared/archetypes/grid_editable/grid_selection_controller.dart';
import '../shared/archetypes/grid_editable/row/editable_grid_context_menu.dart';
import '../shared/archetypes/grid_editable/row/editable_row_actions_button.dart';
import '../shared/ui_contract_core/dialogs/contract_menu_surface.dart';
import '../shared/ui_contract_core/dialogs/contract_popup_surface.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/editable_hover_capsule.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import '../shared/utils/date_picker_defaults.dart';
import '../shared/utils/number_formatters.dart';
import 'finanzas_bank_accounts_page.dart';
import 'finanzas_catalog_page.dart';
import 'finanzas_company_directory_page.dart';
import 'finanzas_dashboard_page.dart';
import 'finanzas_data_store.dart';
import 'finanzas_fixed_payments_store.dart';
import 'finanzas_payment_center_page.dart';
import 'finanzas_provider_accounts_page.dart';
import 'finanzas_theme.dart';

const double _kFixedReceivedDateW = 136;
const double _kFixedCompanyW = 264;
const double _kFixedBranchW = 146;
const double _kFixedSucursalW = 146;
const double _kFixedAmountW = 164;
const double _kFixedPaymentDateW = 136;
const double _kFixedStatusW = 150;
const double _kFixedNotesW = 320;
const double _kFixedActionsW = 72;
final DateTimeRange _kClearedFixedDateRange = DateTimeRange(
  start: DateTime(1900),
  end: DateTime(1900),
);

void _syncFixedPickerOptionKeys(List<GlobalKey> keys, int count) {
  while (keys.length < count) {
    keys.add(GlobalKey());
  }
  while (keys.length > count) {
    keys.removeLast();
  }
}

void _ensureFixedPickerHighlightVisible({
  required List<GlobalKey> keys,
  required int highlightedIndex,
  required int rowCount,
}) {
  if (rowCount <= 0) return;
  _syncFixedPickerOptionKeys(keys, rowCount);
  final safeIndex = highlightedIndex.clamp(0, rowCount - 1);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = keys[safeIndex].currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      alignment: 0.38,
    );
  });
}

class FinanzasFixedPaymentsPage extends StatefulWidget {
  final bool instantOpen;
  final String? initialSelectedPaymentId;

  const FinanzasFixedPaymentsPage({
    super.key,
    this.instantOpen = false,
    this.initialSelectedPaymentId,
  });

  @override
  State<FinanzasFixedPaymentsPage> createState() =>
      _FinanzasFixedPaymentsPageState();
}

class _FinanzasFixedPaymentsPageState extends State<FinanzasFixedPaymentsPage> {
  bool _menuOpen = false;
  bool _loading = true;
  bool _exportingCsv = false;
  bool _canReturnToDirection = false;
  bool _canAccessComprasArea = false;
  final FocusNode _rowsFocusNode = FocusNode(debugLabel: 'fixedPaymentsRows');
  final GridNavigationController _gridNavigationController =
      GridNavigationController();
  final GridSelectionController _gridSelectionController =
      GridSelectionController();
  final GridScrollVisibilityCoordinator _gridVisibilityCoordinator =
      GridScrollVisibilityCoordinator();

  DateTimeRange? _receivedDateRangeFilter;
  DateTimeRange? _paymentDateRangeFilter;
  Set<String> _companyFilters = <String>{};
  Set<String> _accountFilters = <String>{};
  Set<String> _branchFilters = <String>{};
  Set<String> _amountFilters = <String>{};
  Set<String> _statusFilters = <String>{};
  Set<String> _selectedRowIds = <String>{};
  String? _selectedRowId;
  String? _selectionAnchorRowId;
  bool _dragSelectionActive = false;
  bool _dragSelectionAdditive = false;
  bool _dragSelectionMoved = false;
  bool _suppressNextRowTap = false;
  Set<String> _dragSelectionBaseIds = <String>{};
  int _currentPage = 0;
  int _pageSize = 40;

  List<FinanzasFixedPaymentRecord> _rows = const <FinanzasFixedPaymentRecord>[];
  List<FinanzasCatalogCompanyRecord> _directCompanies =
      const <FinanzasCatalogCompanyRecord>[];

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadPage());
  }

  @override
  void dispose() {
    _rowsFocusNode.dispose();
    _gridNavigationController.dispose();
    _gridSelectionController.dispose();
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

  Future<void> _loadPage() async {
    setState(() => _loading = true);
    final results = await Future.wait<dynamic>([
      FinanzasFixedPaymentsStore.loadPayments(),
      FinanzasDataStore.loadCatalogSnapshot(),
    ]);
    if (!mounted) return;
    final payments = results[0] as List<FinanzasFixedPaymentRecord>;
    final snapshot = results[1] as FinanzasCatalogSnapshot;
    final companies = snapshot.companies
        .where(
          (row) => row.active && row.source.trim().toUpperCase() == 'DIRECTO',
        )
        .toList(growable: false);
    setState(() {
      _rows = payments;
      _directCompanies = companies;
      _syncSelection();
      _syncPageToSelectedRow();
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_gridRows.isNotEmpty && _selectedRowId == null) {
        final firstRow = _gridRows.first;
        _gridSelectionController.selectSingle(firstRow.id, rowIndex: 0);
        _syncSelectionFromController(preferredRowId: firstRow.id);
      }
      _requestGridFocus();
    });
  }

  void _syncSelection() {
    final visible = _visibleRows;
    if (visible.isEmpty) {
      _selectedRowId = null;
      _selectedRowIds = <String>{};
      _selectionAnchorRowId = null;
      _gridSelectionController.clear();
      return;
    }
    final visibleIds = visible.map((row) => row.id).toSet();
    _selectedRowIds = _selectedRowIds.intersection(visibleIds);
    final presetId = widget.initialSelectedPaymentId;
    if (_selectedRowIds.isEmpty &&
        presetId != null &&
        visible.any((row) => row.id == presetId)) {
      _selectedRowId = presetId;
      _selectedRowIds = <String>{presetId};
      _selectionAnchorRowId = presetId;
    } else if (_selectedRowId == null ||
        !_selectedRowIds.contains(_selectedRowId) ||
        !visible.any((row) => row.id == _selectedRowId)) {
      if (_selectedRowIds.isNotEmpty) {
        _selectedRowId = visible
            .firstWhere((row) => _selectedRowIds.contains(row.id))
            .id;
      } else {
        _selectedRowId = visible.first.id;
        _selectedRowIds = <String>{_selectedRowId!};
      }
    } else if (_selectedRowIds.isEmpty && _selectedRowId != null) {
      _selectedRowIds = <String>{_selectedRowId!};
    }
    _selectionAnchorRowId ??= _selectedRowId;
    _gridSelectionController.selectedIds
      ..clear()
      ..addAll(_selectedRowIds);
    final anchorIndex = _selectionAnchorRowId == null
        ? -1
        : visible.indexWhere((row) => row.id == _selectionAnchorRowId);
    _gridSelectionController.anchorIndex = anchorIndex >= 0
        ? anchorIndex
        : (_selectedRowId == null
              ? null
              : visible.indexWhere((row) => row.id == _selectedRowId));
    if (_selectedRowId == null) {
      _selectedRowId = visible.first.id;
      _selectedRowIds = <String>{_selectedRowId!};
      _selectionAnchorRowId = _selectedRowId;
    }
    _clampCurrentPage();
  }

  void _syncSelectionFromController({String? preferredRowId}) {
    final selected = _gridSelectionController.selectedIds.toSet();
    final fallback = selected.isEmpty ? null : selected.first;
    final preferred =
        preferredRowId != null && selected.contains(preferredRowId)
        ? preferredRowId
        : null;
    setState(() {
      _selectedRowIds = selected;
      _selectedRowId = preferred ?? fallback;
      _selectionAnchorRowId = _selectedRowId;
    });
    _syncPageToSelectedRow();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<String> _sortedDistinct(Iterable<String> values) {
    final items = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    items.sort();
    return items;
  }

  bool _matchesDateRange(DateTime date, DateTimeRange range) {
    final current = DateTime(date.year, date.month, date.day);
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return !current.isBefore(start) && !current.isAfter(end);
  }

  String _dateRangeLabel(DateTimeRange range) =>
      '${_dateLabel(range.start)} - ${_dateLabel(range.end)}';

  Future<Set<String>?> _showGridMultiFilterDialog({
    required String title,
    required List<_SimpleOption> options,
    required Set<String> selectedValues,
  }) async {
    final result = await showDialog<GridFilterState>(
      context: context,
      builder: (_) => AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: GridFilterDialog(
          title: 'Filtro: ${title.replaceFirst('Filtrar ', '').toUpperCase()}',
          initialState: GridFilterState(
            options: options
                .map(
                  (option) => GridFilterOption(
                    value: option.id,
                    label: option.label,
                    selected: selectedValues.contains(option.id),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
    if (result == null) return null;
    return result.selectedValues;
  }

  Future<void> _pickReceivedDateFilter() async {
    final availableDates =
        _rows
            .map((row) => DateUtils.dateOnly(row.receivedDate))
            .toSet()
            .toList()
          ..sort();
    final picked = await _showFixedDateRangeDialog(
      context,
      initialRange: _receivedDateRangeFilter,
      firstDate: availableDates.isNotEmpty
          ? availableDates.first
          : DateTime(2024),
      lastDate: availableDates.isNotEmpty
          ? availableDates.last
          : DateTime(2035),
      title: 'Filtrar fecha recibido',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _receivedDateRangeFilter = picked == _kClearedFixedDateRange
          ? null
          : picked;
      _syncSelection();
    });
    _requestGridFocus();
  }

  Future<void> _pickCompanyFilter() async {
    final selected = await _showGridMultiFilterDialog(
      title: 'Filtrar empresa',
      selectedValues: _companyFilters,
      options: _sortedDistinct(_rows.map((row) => row.companyNameSnapshot))
          .map((value) => _SimpleOption(id: value, label: value, subtitle: ''))
          .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _companyFilters = selected;
      _syncSelection();
    });
    _requestGridFocus();
  }

  Future<void> _pickAccountFilter() async {
    final selected = await _showGridMultiFilterDialog(
      title: 'Filtrar cuenta',
      selectedValues: _accountFilters,
      options:
          _sortedDistinct(
                _rows.map(
                  (row) => finFixedPaymentTargetCompanyLabel(row.targetCompany),
                ),
              )
              .map(
                (value) => _SimpleOption(id: value, label: value, subtitle: ''),
              )
              .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _accountFilters = selected;
      _syncSelection();
    });
    _requestGridFocus();
  }

  Future<void> _pickBranchFilter() async {
    final selected = await _showGridMultiFilterDialog(
      title: 'Filtrar sucursal',
      selectedValues: _branchFilters,
      options:
          _sortedDistinct(
                _rows.map((row) => finFixedPaymentBranchLabel(row.branch)),
              )
              .map(
                (value) => _SimpleOption(id: value, label: value, subtitle: ''),
              )
              .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _branchFilters = selected;
      _syncSelection();
    });
    _requestGridFocus();
  }

  Future<void> _pickAmountFilter() async {
    final selected = await _showGridMultiFilterDialog(
      title: 'Filtrar monto',
      selectedValues: _amountFilters,
      options: _sortedDistinct(_rows.map((row) => _money(row.amount)))
          .map((value) => _SimpleOption(id: value, label: value, subtitle: ''))
          .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _amountFilters = selected;
      _syncSelection();
    });
    _requestGridFocus();
  }

  Future<void> _pickPaymentDateFilter() async {
    final availableDates =
        _rows.map((row) => DateUtils.dateOnly(row.paymentDate)).toSet().toList()
          ..sort();
    final picked = await _showFixedDateRangeDialog(
      context,
      initialRange: _paymentDateRangeFilter,
      firstDate: availableDates.isNotEmpty
          ? availableDates.first
          : DateTime(2024),
      lastDate: availableDates.isNotEmpty
          ? availableDates.last
          : DateTime(2035),
      title: 'Filtrar fecha pago',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _paymentDateRangeFilter = picked == _kClearedFixedDateRange
          ? null
          : picked;
      _syncSelection();
    });
    _requestGridFocus();
  }

  Future<void> _pickStatusFilter() async {
    final selected = await _showGridMultiFilterDialog(
      title: 'Filtrar estado',
      selectedValues: _statusFilters,
      options: kFinFixedPaymentStatuses
          .map(
            (value) => _SimpleOption(
              id: value,
              label: finFixedPaymentStatusLabel(value),
              subtitle: '',
            ),
          )
          .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _statusFilters = selected;
      _syncSelection();
    });
    _requestGridFocus();
  }

  List<FinanzasFixedPaymentRecord> get _visibleRows {
    return _rows
        .where((row) {
          if (_receivedDateRangeFilter != null &&
              !_matchesDateRange(row.receivedDate, _receivedDateRangeFilter!)) {
            return false;
          }
          if (_companyFilters.isNotEmpty &&
              !_companyFilters.contains(row.companyNameSnapshot)) {
            return false;
          }
          if (_accountFilters.isNotEmpty &&
              !_accountFilters.contains(
                finFixedPaymentTargetCompanyLabel(row.targetCompany),
              )) {
            return false;
          }
          if (_branchFilters.isNotEmpty &&
              !_branchFilters.contains(
                finFixedPaymentBranchLabel(row.branch),
              )) {
            return false;
          }
          if (_amountFilters.isNotEmpty &&
              !_amountFilters.contains(_money(row.amount))) {
            return false;
          }
          if (_paymentDateRangeFilter != null &&
              !_matchesDateRange(row.paymentDate, _paymentDateRangeFilter!)) {
            return false;
          }
          if (_statusFilters.isNotEmpty &&
              !_statusFilters.contains(row.status)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<FinanzasFixedPaymentRecord> get _gridRows {
    final rows = _visibleRows;
    if (rows.isEmpty) return rows;
    final safePage = _effectiveCurrentPage(rows.length);
    final start = safePage * _pageSize;
    final end = math.min(start + _pageSize, rows.length);
    return rows.sublist(start, end);
  }

  int get _totalPages => _totalPagesForCount(_visibleRows.length);

  int _totalPagesForCount(int totalRows) {
    return math.max(1, (totalRows / _pageSize).ceil());
  }

  int _effectiveCurrentPage(int totalRows) {
    final totalPages = _totalPagesForCount(totalRows);
    return _currentPage.clamp(0, totalPages - 1);
  }

  void _clampCurrentPage() {
    _currentPage = _effectiveCurrentPage(_visibleRows.length);
  }

  void _syncPageToSelectedRow() {
    final selectedRowId = _selectedRowId;
    if (selectedRowId == null) {
      _clampCurrentPage();
      return;
    }
    final selectedIndex = _visibleRows.indexWhere(
      (row) => row.id == selectedRowId,
    );
    if (selectedIndex < 0) {
      _clampCurrentPage();
      return;
    }
    _currentPage = selectedIndex ~/ _pageSize;
  }

  void _focusFirstRowOnCurrentPage() {
    final pageRows = _gridRows;
    if (pageRows.isEmpty) {
      _gridSelectionController.clear();
      _selectedRowId = null;
      _selectedRowIds = <String>{};
      _selectionAnchorRowId = null;
      return;
    }
    final firstRow = pageRows.first;
    _gridSelectionController.selectSingle(firstRow.id, rowIndex: 0);
    _syncSelectionFromController(preferredRowId: firstRow.id);
  }

  void _goToPreviousPage() {
    if (_currentPage <= 0) return;
    setState(() {
      _currentPage -= 1;
    });
    _focusFirstRowOnCurrentPage();
    _requestGridFocus();
  }

  void _goToNextPage() {
    if (_currentPage >= _totalPages - 1) return;
    setState(() {
      _currentPage += 1;
    });
    _focusFirstRowOnCurrentPage();
    _requestGridFocus();
  }

  void _setPageSize(int value) {
    if (_pageSize == value) return;
    setState(() {
      _pageSize = value;
      _syncPageToSelectedRow();
    });
    if (_gridRows.isEmpty) {
      _focusFirstRowOnCurrentPage();
    }
    _requestGridFocus();
  }

  void _requestGridFocus() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rows = _gridRows;
      if (rows.isNotEmpty) {
        final targetIndex = _selectedRowId == null
            ? 0
            : rows.indexWhere((row) => row.id == _selectedRowId);
        _gridNavigationController.focusGridCell(
          rowIndex: targetIndex >= 0 ? targetIndex : 0,
          columnIndex: 0,
        );
      }
      _rowsFocusNode.requestFocus();
    });
  }

  void _handleRowTap(String rowId, int rowIndex) {
    if (_suppressNextRowTap) {
      _syncSelectionFromController(preferredRowId: rowId);
      setState(() {
        _dragSelectionMoved = false;
        _suppressNextRowTap = false;
      });
      _rowsFocusNode.requestFocus();
      return;
    }
    _gridSelectionController.handlePointerSelection(
      id: rowId,
      rowIndex: rowIndex,
      resolveRangeIds: (start, end) =>
          _gridRows.getRange(start, end + 1).map((row) => row.id),
      visibilityCoordinator: _gridVisibilityCoordinator,
    );
    _syncSelectionFromController(preferredRowId: rowId);
    _gridNavigationController.focusGridCell(rowIndex: rowIndex, columnIndex: 0);
    setState(() => _dragSelectionMoved = false);
    _rowsFocusNode.requestFocus();
  }

  void _handleGridNavigation(GridCellPosition position) {
    if (position.zone != GridNavigationZone.grid) return;
    final rows = _gridRows;
    if (position.rowIndex < 0 || position.rowIndex >= rows.length) return;
    final row = rows[position.rowIndex];
    _gridSelectionController.selectSingle(row.id, rowIndex: position.rowIndex);
    _syncSelectionFromController(preferredRowId: row.id);
    unawaited(
      _gridVisibilityCoordinator.ensureGridRowVisible(position.rowIndex),
    );
  }

  void _beginDragSelection(String rowId, {required bool additive}) {
    final rowIndex = _gridRows.indexWhere((row) => row.id == rowId);
    final baseIds = additive ? {..._selectedRowIds} : <String>{};
    final nextIds = additive ? baseIds : <String>{rowId};
    setState(() {
      _dragSelectionActive = true;
      _dragSelectionAdditive = additive;
      _dragSelectionMoved = false;
      _suppressNextRowTap = false;
      _dragSelectionBaseIds = baseIds;
      _selectedRowId = rowId;
      _selectionAnchorRowId = rowId;
      _selectedRowIds = nextIds;
    });
    if (rowIndex >= 0) {
      _gridNavigationController.focusGridCell(
        rowIndex: rowIndex,
        columnIndex: 0,
      );
      _gridSelectionController.selectedIds
        ..clear()
        ..addAll(_selectedRowIds);
      _gridSelectionController.anchorIndex = rowIndex;
    }
    _rowsFocusNode.requestFocus();
  }

  void _extendDragSelection(String rowId) {
    if (!_dragSelectionActive) return;
    final rowIndex = _gridRows.indexWhere((row) => row.id == rowId);
    final anchorRowId = _selectionAnchorRowId;
    final anchorIndex = anchorRowId == null
        ? -1
        : _gridRows.indexWhere((row) => row.id == anchorRowId);
    if (rowIndex < 0 || anchorIndex < 0) return;
    final start = math.min(anchorIndex, rowIndex);
    final end = math.max(anchorIndex, rowIndex);
    final rangeIds = _gridRows
        .getRange(start, end + 1)
        .map((row) => row.id)
        .toSet();
    final nextIds = _dragSelectionAdditive
        ? {..._dragSelectionBaseIds, ...rangeIds}
        : rangeIds;
    setState(() {
      _selectedRowId = rowId;
      _selectedRowIds = nextIds;
      _dragSelectionMoved = rowIndex != anchorIndex || nextIds.length > 1;
    });
    _gridSelectionController.selectedIds
      ..clear()
      ..addAll(_selectedRowIds);
    _gridSelectionController.anchorIndex = anchorIndex;
    _gridVisibilityCoordinator.ensureGridRowVisible(rowIndex);
    _gridNavigationController.focusGridCell(rowIndex: rowIndex, columnIndex: 0);
  }

  void _endDragSelection() {
    if (!_dragSelectionActive) return;
    setState(() {
      _dragSelectionActive = false;
      _dragSelectionAdditive = false;
      _suppressNextRowTap = _dragSelectionMoved;
    });
  }

  void _clearSelection() {
    _gridSelectionController.clear();
    setState(() {
      _selectedRowId = null;
      _selectedRowIds = <String>{};
      _selectionAnchorRowId = null;
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

  Future<void> _openDirectory() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasCompanyDirectoryPage(instantOpen: true)),
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

  Future<void> _openPaymentCenter() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasPaymentCenterPage(instantOpen: true)),
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

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
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
      case 'Directorio Empresas':
        unawaited(_openDirectory());
        return;
      case 'Cuentas por Proveedor':
        unawaited(_openProviderAccounts());
        return;
      case 'Cuentas Bancarias':
        unawaited(_openBankAccounts());
        return;
      case 'Centro de pagos':
        unawaited(_openPaymentCenter());
        return;
      case 'Dashboard Compras':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openComprasDashboard());
        return;
      case 'Pagos fijos':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
    }
  }

  Future<void> _createPayment() async {
    final draft = await showDialog<_FixedPaymentDraft>(
      context: context,
      builder: (_) => _FixedPaymentDialog(companies: _directCompanies),
    );
    if (draft == null) return;
    final company = _directCompanies.firstWhere(
      (row) => row.id == draft.companyId,
      orElse: () => FinanzasCatalogCompanyRecord(
        id: draft.companyId,
        name: draft.companyNameSnapshot,
        source: 'DIRECTO',
        linkedName: draft.companyNameSnapshot,
        active: true,
        notes: '',
      ),
    );
    final row = FinanzasFixedPaymentRecord(
      id: 'fin-fixed-${DateTime.now().microsecondsSinceEpoch}',
      receivedDate: draft.receivedDate,
      companyId: company.id,
      companyNameSnapshot: company.name,
      targetCompany: draft.targetCompany,
      branch: draft.branch,
      amount: draft.amount,
      paymentDate: draft.paymentDate,
      status: draft.status,
      notes: draft.notes,
      executionMethod: null,
      linkedBankMovementId: null,
      settledAt: null,
      createdAt: null,
      updatedAt: null,
    );
    try {
      await FinanzasFixedPaymentsStore.savePayment(row);
      if (!mounted) return;
      _toast('Pago fijo registrado.');
      await _loadPage();
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo registrar el pago fijo. $error');
    }
  }

  Future<void> _editPayment(FinanzasFixedPaymentRecord row) async {
    final draft = await showDialog<_FixedPaymentDraft>(
      context: context,
      builder: (_) =>
          _FixedPaymentDialog(companies: _directCompanies, initialRow: row),
    );
    if (draft == null) return;
    final company = _directCompanies.firstWhere(
      (item) => item.id == draft.companyId,
      orElse: () => FinanzasCatalogCompanyRecord(
        id: draft.companyId,
        name: draft.companyNameSnapshot,
        source: 'DIRECTO',
        linkedName: draft.companyNameSnapshot,
        active: true,
        notes: '',
      ),
    );
    final updated = row.copyWith(
      receivedDate: draft.receivedDate,
      companyId: company.id,
      companyNameSnapshot: company.name,
      targetCompany: draft.targetCompany,
      branch: draft.branch,
      amount: draft.amount,
      paymentDate: draft.paymentDate,
      status: draft.status,
      notes: draft.notes,
    );
    try {
      await FinanzasFixedPaymentsStore.savePayment(updated);
      if (!mounted) return;
      _toast('Pago fijo actualizado.');
      await _loadPage();
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo actualizar el pago fijo. $error');
    }
  }

  Future<void> _deletePayment(FinanzasFixedPaymentRecord row) async {
    final confirmed = await showContractConfirmationDialog(
      context,
      title: 'Eliminar pago fijo',
      content:
          'Se eliminará el pago fijo de ${row.companyNameSnapshot}. Esta acción no se puede deshacer.',
      confirmText: 'Eliminar',
      destructive: true,
      tokens: finanzasAreaTokens,
    );
    if (confirmed != true) return;
    try {
      await FinanzasFixedPaymentsStore.deletePayment(row.id);
      if (!mounted) return;
      _toast('Pago fijo eliminado.');
      await _loadPage();
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo eliminar el pago fijo. $error');
    }
  }

  Future<void> _deleteSelectedPayments() async {
    final selected = _visibleRows
        .where((row) => _selectedRowIds.contains(row.id))
        .toList(growable: false);
    if (selected.isEmpty) return;
    final confirmed = await showContractConfirmationDialog(
      context,
      title: 'Eliminar pagos fijos',
      content:
          'Se eliminarán ${selected.length} pago(s) fijo(s) seleccionado(s). Esta acción no se puede deshacer.',
      confirmText: 'Eliminar',
      destructive: true,
      tokens: finanzasAreaTokens,
    );
    if (confirmed != true) return;
    try {
      for (final row in selected) {
        await FinanzasFixedPaymentsStore.deletePayment(row.id);
      }
      if (!mounted) return;
      _toast('${selected.length} pago(s) fijo(s) eliminado(s).');
      await _loadPage();
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudieron eliminar los pagos fijos. $error');
    }
  }

  Future<void> _markPaymentPaidInCash(FinanzasFixedPaymentRecord row) async {
    final confirmed = await showContractConfirmationDialog(
      context,
      title: 'Pagar en efectivo',
      content:
          'Se marcará como pagado en efectivo el compromiso de ${row.companyNameSnapshot} por ${_money(row.amount)}.',
      confirmText: 'Confirmar pago',
      tokens: finanzasAreaTokens,
    );
    if (confirmed != true) return;
    try {
      await FinanzasFixedPaymentsStore.markPaidByCash(row: row);
      if (!mounted) return;
      _toast('Pago fijo liquidado en efectivo.');
      await _loadPage();
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo liquidar en efectivo. $error');
    }
  }

  Future<void> _exportCsv() async {
    if (_exportingCsv) return;
    setState(() => _exportingCsv = true);
    try {
      final rows = <List<String>>[
        <String>[
          'Fecha recibido',
          'Empresa',
          'Cuenta',
          'Sucursal',
          'Monto',
          'Fecha pago',
          'Estado',
          'Comentario',
        ],
        for (final row in _visibleRows)
          <String>[
            _dateLabel(row.receivedDate),
            row.companyNameSnapshot,
            finFixedPaymentTargetCompanyLabel(row.targetCompany),
            finFixedPaymentBranchLabel(row.branch),
            row.amount.toStringAsFixed(2),
            _dateLabel(row.paymentDate),
            finFixedPaymentStatusLabel(row.status),
            row.notes,
          ],
      ];
      final content = rows
          .map(
            (row) =>
                row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','),
          )
          .join('\n');
      await saveCsvFile(fileName: 'finanzas_pagos_fijos.csv', content: content);
      if (!mounted) return;
      _toast('CSV exportado.');
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo exportar el CSV. $error');
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _money(double value) => formatMoney(value);

  Color _statusTone(String value) {
    switch (value) {
      case 'PAGADO':
        return const Color(0xFF0F766E);
      case 'VENCIDO':
        return const Color(0xFFB42318);
      default:
        return const Color(0xFF8B5E00);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleRows = _visibleRows;
    final selectedCount = _selectedRowIds.length;
    final totalAmount = visibleRows.fold<double>(
      0,
      (sum, row) => sum + row.amount,
    );
    final pendingAmount = visibleRows
        .where((row) => row.status == 'PENDIENTE')
        .fold<double>(0, (sum, row) => sum + row.amount);
    final paidAmount = visibleRows
        .where((row) => row.status == 'PAGADO')
        .fold<double>(0, (sum, row) => sum + row.amount);
    final overdueAmount = visibleRows
        .where((row) => row.status == 'VENCIDO')
        .fold<double>(0, (sum, row) => sum + row.amount);

    return AreaThemeScope(
      tokens: finanzasAreaTokens,
      child: Focus(
        autofocus: false,
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape && _menuOpen) {
            setState(() => _menuOpen = false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AppShell(
          background: const _FixedPaymentsBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => _HeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => const _HeaderBrand(title: 'Pagos fijos'),
          trailingBuilder: (_, _) => _HeaderButton(
            label: 'Cerrar sesión',
            icon: Icons.logout_rounded,
            onTap: _logout,
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1540),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(56, 0, 6, 0),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Builder(
                                builder: (_) {
                                  _gridNavigationController.configure(
                                    insertColumnCount: 1,
                                    gridColumnCount: 1,
                                    rowCount: _gridRows.length,
                                  );
                                  return const SizedBox.shrink();
                                },
                              ),
                              _FixedTopBar(
                                selectedCount: selectedCount,
                                onExport: _exportCsv,
                                onCreate: _createPayment,
                                exporting: _exportingCsv,
                              ),
                              const SizedBox(height: 14),
                              _FixedMetricsRow(
                                cards: [
                                  _FixedMetricCardData(
                                    label: 'Mes',
                                    value: _money(totalAmount),
                                    tone: finanzasAreaTokens.primaryStrong,
                                    icon: Icons.calendar_month_outlined,
                                    footerTitle: 'Total del mes',
                                    footerSubtitle: 'Importe programado',
                                    footerIcon: Icons.query_stats_rounded,
                                  ),
                                  _FixedMetricCardData(
                                    label: 'Pendiente',
                                    value: _money(pendingAmount),
                                    tone: const Color(0xFFFF8A2B),
                                    icon: Icons.hourglass_empty_rounded,
                                    footerTitle: 'Aun no pagado',
                                    footerSubtitle: 'Importe por cubrir',
                                    footerIcon: Icons.circle_rounded,
                                  ),
                                  _FixedMetricCardData(
                                    label: 'Pagado',
                                    value: _money(paidAmount),
                                    tone: const Color(0xFF48B7A9),
                                    icon: Icons.check_circle_outline_rounded,
                                    footerTitle: 'Total pagado',
                                    footerSubtitle: 'Importe completado',
                                    footerIcon:
                                        Icons.account_balance_wallet_outlined,
                                  ),
                                  _FixedMetricCardData(
                                    label: 'Vencido',
                                    value: _money(overdueAmount),
                                    tone: const Color(0xFFF45F4E),
                                    icon: Icons.calendar_month_outlined,
                                    footerTitle: 'Pagos vencidos',
                                    footerSubtitle: 'Importe en atraso',
                                    footerIcon: Icons.error_outline_rounded,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Expanded(
                                child: _FixedTabSurface(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _FixedFilterSummaryRow(
                                        labels: [
                                          if (_receivedDateRangeFilter != null)
                                            'Fecha recibido: ${_dateRangeLabel(_receivedDateRangeFilter!)}',
                                          for (final value in _companyFilters)
                                            'Empresa: $value',
                                          for (final value in _accountFilters)
                                            'Cuenta: $value',
                                          for (final value in _branchFilters)
                                            'Sucursal: $value',
                                          for (final value in _amountFilters)
                                            'Monto: $value',
                                          if (_paymentDateRangeFilter != null)
                                            'Fecha pago: ${_dateRangeLabel(_paymentDateRangeFilter!)}',
                                          for (final value in _statusFilters)
                                            'Estado: ${finFixedPaymentStatusLabel(value)}',
                                        ],
                                        onClearAll:
                                            _receivedDateRangeFilter == null &&
                                                _companyFilters.isEmpty &&
                                                _accountFilters.isEmpty &&
                                                _branchFilters.isEmpty &&
                                                _amountFilters.isEmpty &&
                                                _paymentDateRangeFilter ==
                                                    null &&
                                                _statusFilters.isEmpty
                                            ? null
                                            : () {
                                                setState(() {
                                                  _receivedDateRangeFilter =
                                                      null;
                                                  _companyFilters.clear();
                                                  _accountFilters.clear();
                                                  _branchFilters.clear();
                                                  _amountFilters.clear();
                                                  _paymentDateRangeFilter =
                                                      null;
                                                  _statusFilters.clear();
                                                  _syncSelection();
                                                });
                                                _requestGridFocus();
                                              },
                                      ),
                                      const SizedBox(height: 10),
                                      _FixedHeaderRow(
                                        receivedDateFilterActive:
                                            _receivedDateRangeFilter != null,
                                        companyFilterActive:
                                            _companyFilters.isNotEmpty,
                                        accountFilterActive:
                                            _accountFilters.isNotEmpty,
                                        branchFilterActive:
                                            _branchFilters.isNotEmpty,
                                        amountFilterActive:
                                            _amountFilters.isNotEmpty,
                                        paymentDateFilterActive:
                                            _paymentDateRangeFilter != null,
                                        statusFilterActive:
                                            _statusFilters.isNotEmpty,
                                        onReceivedDateFilter:
                                            _pickReceivedDateFilter,
                                        onCompanyFilter: _pickCompanyFilter,
                                        onAccountFilter: _pickAccountFilter,
                                        onBranchFilter: _pickBranchFilter,
                                        onAmountFilter: _pickAmountFilter,
                                        onPaymentDateFilter:
                                            _pickPaymentDateFilter,
                                        onStatusFilter: _pickStatusFilter,
                                      ),
                                      const SizedBox(height: 10),
                                      Expanded(
                                        child: GridKeyboardShell(
                                          focusNode: _rowsFocusNode,
                                          navigationController:
                                              _gridNavigationController,
                                          onEscape: _clearSelection,
                                          onDelete: _deleteSelectedPayments,
                                          onConfirm: () {
                                            final active =
                                                _gridNavigationController
                                                    .active;
                                            if (active.zone !=
                                                    GridNavigationZone.grid ||
                                                active.rowIndex < 0 ||
                                                active.rowIndex >=
                                                    _gridRows.length) {
                                              return;
                                            }
                                            unawaited(
                                              _editPayment(
                                                _gridRows[active.rowIndex],
                                              ),
                                            );
                                          },
                                          onNavigated: _handleGridNavigation,
                                          child: _gridRows.isEmpty
                                              ? const _FixedEmptyPane()
                                              : _FixedPaymentsGrid(
                                                  rows: _gridRows,
                                                  selectedRowIds:
                                                      _selectedRowIds,
                                                  activeRowId: _selectedRowId,
                                                  dragSelectionActive:
                                                      _dragSelectionActive,
                                                  moneyFormatter: _money,
                                                  dateFormatter: _dateLabel,
                                                  statusTone: _statusTone,
                                                  visibilityCoordinator:
                                                      _gridVisibilityCoordinator,
                                                  onRowTap: _handleRowTap,
                                                  onDragStart:
                                                      _beginDragSelection,
                                                  onDragEnter:
                                                      _extendDragSelection,
                                                  onDragEnd: _endDragSelection,
                                                  onPrepareMenuSelection:
                                                      (rowId, rowIndex) =>
                                                          _handleRowTap(
                                                            rowId,
                                                            rowIndex,
                                                          ),
                                                  onEdit: _editPayment,
                                                  onDelete: _deletePayment,
                                                  onPayCash:
                                                      (
                                                        FinanzasFixedPaymentRecord
                                                        row,
                                                      ) {
                                                        if (row.status ==
                                                            'PAGADO') {
                                                          return;
                                                        }
                                                        unawaited(
                                                          _markPaymentPaidInCash(
                                                            row,
                                                          ),
                                                        );
                                                      },
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _FinanzasGridPager(
                                        currentPage: _effectiveCurrentPage(
                                          _visibleRows.length,
                                        ),
                                        totalPages: _totalPages,
                                        pageSize: _pageSize,
                                        totalRows: _visibleRows.length,
                                        onPrevious: _currentPage > 0
                                            ? _goToPreviousPage
                                            : null,
                                        onNext: _currentPage < _totalPages - 1
                                            ? _goToNextPage
                                            : null,
                                        onPageSizeChanged: _setPageSize,
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
              Positioned(
                left: 0,
                top: 2,
                bottom: 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  offset: _menuOpen ? Offset.zero : const Offset(-1.08, 0),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: _menuOpen ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_menuOpen,
                      child: _SidePanel(
                        canReturnToDirection: _canReturnToDirection,
                        canAccessComprasArea: _canAccessComprasArea,
                        onNavigate: _handleNavigationAction,
                      ),
                    ),
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

class _FixedPaymentDraft {
  final DateTime receivedDate;
  final String companyId;
  final String companyNameSnapshot;
  final String targetCompany;
  final String branch;
  final double amount;
  final DateTime paymentDate;
  final String status;
  final String notes;

  const _FixedPaymentDraft({
    required this.receivedDate,
    required this.companyId,
    required this.companyNameSnapshot,
    required this.targetCompany,
    required this.branch,
    required this.amount,
    required this.paymentDate,
    required this.status,
    required this.notes,
  });
}

class _FixedPaymentDialog extends StatefulWidget {
  final List<FinanzasCatalogCompanyRecord> companies;
  final FinanzasFixedPaymentRecord? initialRow;

  const _FixedPaymentDialog({required this.companies, this.initialRow});

  @override
  State<_FixedPaymentDialog> createState() => _FixedPaymentDialogState();
}

class _FixedPaymentDialogState extends State<_FixedPaymentDialog> {
  late final TextEditingController _amountC;
  late final TextEditingController _notesC;
  late DateTime _receivedDate;
  late DateTime _paymentDate;
  late String _companyId;
  late String _targetCompany;
  late String _branch;
  late String _status;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRow;
    _amountC = TextEditingController(
      text: initial == null ? '' : initial.amount.toStringAsFixed(2),
    );
    _notesC = TextEditingController(text: initial?.notes ?? '');
    _receivedDate = DateUtils.dateOnly(initial?.receivedDate ?? DateTime.now());
    _paymentDate = DateUtils.dateOnly(initial?.paymentDate ?? DateTime.now());
    _companyId =
        initial?.companyId ??
        (widget.companies.isEmpty ? '' : widget.companies.first.id);
    _targetCompany =
        initial?.targetCompany ?? kFinFixedPaymentTargetCompanies.first;
    _branch = initial?.branch ?? kFinFixedPaymentBranches.first;
    _status = initial?.status ?? 'PENDIENTE';
    _amountC.addListener(_refresh);
    _notesC.addListener(_refresh);
  }

  @override
  void dispose() {
    _amountC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  double _parseAmount() {
    final cleaned = _amountC.text
        .replaceAll(',', '')
        .replaceAll('\$', '')
        .trim();
    return double.tryParse(cleaned) ?? 0;
  }

  bool get _canSave => _companyId.isNotEmpty && _parseAmount() > 0;

  String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  Future<void> _pickReceivedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: defaultDatePickerOpenDate(
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      currentDate: defaultDatePickerOpenDate(
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      ),
      builder: _buildThemedDatePicker,
    );
    if (picked == null || !mounted) return;
    setState(() => _receivedDate = DateUtils.dateOnly(picked));
  }

  Future<void> _pickPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: defaultDatePickerOpenDate(
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      currentDate: defaultDatePickerOpenDate(
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      ),
      builder: _buildThemedDatePicker,
    );
    if (picked == null || !mounted) return;
    setState(() => _paymentDate = DateUtils.dateOnly(picked));
  }

  Widget _buildThemedDatePicker(BuildContext context, Widget? child) {
    return AreaThemeScope(
      tokens: finanzasAreaTokens,
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: finanzasAreaTokens.primaryStrong,
            onPrimary: Colors.white,
            surface: const Color(0xFF171C24),
            onSurface: kFinanzasInk,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFF171C24),
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: const Color(0xFF171C24),
            surfaceTintColor: Colors.transparent,
            headerBackgroundColor: const Color(0xFF171C24),
            headerForegroundColor: kFinanzasInk,
            weekdayStyle: const TextStyle(color: kFinanzasMutedInk),
            dayForegroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              return kFinanzasInk;
            }),
            dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return finanzasAreaTokens.primaryStrong;
              }
              return Colors.transparent;
            }),
            todayForegroundColor: WidgetStateProperty.all(
              finanzasAreaTokens.primarySoft,
            ),
            cancelButtonStyle: TextButton.styleFrom(
              foregroundColor: finanzasAreaTokens.primarySoft,
            ),
            confirmButtonStyle: TextButton.styleFrom(
              foregroundColor: finanzasAreaTokens.primaryStrong,
            ),
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCompany = widget.companies.where(
      (row) => row.id == _companyId,
    );
    final companyName = selectedCompany.isEmpty
        ? 'Seleccionar empresa'
        : selectedCompany.first.name;
    final isEditing = widget.initialRow != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: Builder(
          builder: (context) {
            final tokens = AreaThemeScope.of(context);
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.dark(
                  primary: tokens.primaryStrong,
                  onPrimary: Colors.white,
                  secondary: tokens.primarySoft,
                  onSecondary: tokens.onGlass,
                  surface: const Color(0xFF171C24),
                  onSurface: kFinanzasInk,
                ),
              ),
              child: FinanzasGlassPanel(
                borderRadius: BorderRadius.circular(34),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                fillColor: const Color(0x1813171F),
                borderColor: Colors.white.withValues(alpha: 0.22),
                edgeHighlightColor: Colors.white.withValues(alpha: 0.18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1080,
                    maxHeight: 820,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing
                                      ? 'Editar pago fijo'
                                      : 'Nuevo pago fijo',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: kFinanzasInk,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Captura el compromiso mensual con empresa directa, monto y fecha objetivo de pago.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: kFinanzasMutedInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FinanzasGlassPanel(
                            width: 54,
                            height: 54,
                            padding: EdgeInsets.zero,
                            borderRadius: BorderRadius.circular(999),
                            fillColor: const Color(0x14161B23),
                            borderColor: Colors.white.withValues(alpha: 0.20),
                            child: Center(
                              child: IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 54,
                                  height: 54,
                                ),
                                iconSize: 30,
                                alignment: Alignment.center,
                                splashRadius: 24,
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Flexible(
                        fit: FlexFit.loose,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _FixedDialogSectionTitle(
                                step: '1',
                                title: 'Recepción',
                                subtitle:
                                    'Registra fecha de recibido y la empresa responsable del compromiso.',
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _FixedChoiceField(
                                      label: 'Fecha recibido',
                                      value: _dateLabel(_receivedDate),
                                      onTap: () {
                                        unawaited(_pickReceivedDate());
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _FixedChoiceField(
                                      label: 'Empresa',
                                      value: companyName,
                                      onTap: () async {
                                        final selected =
                                            await _showSimpleOptionsDialog(
                                              context: context,
                                              title: 'Seleccionar empresa',
                                              options: widget.companies
                                                  .map(
                                                    (row) => _SimpleOption(
                                                      id: row.id,
                                                      label: row.name,
                                                      subtitle: row.source,
                                                    ),
                                                  )
                                                  .toList(growable: false),
                                            );
                                        if (selected == null || !mounted) {
                                          return;
                                        }
                                        setState(
                                          () => _companyId = selected.id,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              const _FixedDialogSectionTitle(
                                step: '2',
                                title: 'Programación',
                                subtitle:
                                    'Define cuenta, monto, fecha objetivo de pago y el estado operativo.',
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _FixedChoiceField(
                                      label: 'Cuenta',
                                      value: finFixedPaymentTargetCompanyLabel(
                                        _targetCompany,
                                      ),
                                      onTap: () async {
                                        final selected =
                                            await _showSimpleOptionsDialog(
                                              context: context,
                                              title: 'Seleccionar cuenta',
                                              options:
                                                  kFinFixedPaymentTargetCompanies
                                                      .map(
                                                        (row) => _SimpleOption(
                                                          id: row,
                                                          label:
                                                              finFixedPaymentTargetCompanyLabel(
                                                                row,
                                                              ),
                                                          subtitle: '',
                                                        ),
                                                      )
                                                      .toList(growable: false),
                                            );
                                        if (selected == null || !mounted) {
                                          return;
                                        }
                                        setState(
                                          () => _targetCompany = selected.id,
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _FixedChoiceField(
                                      label: 'Sucursal',
                                      value: finFixedPaymentBranchLabel(
                                        _branch,
                                      ),
                                      onTap: () async {
                                        final selected =
                                            await _showSimpleOptionsDialog(
                                              context: context,
                                              title: 'Seleccionar sucursal',
                                              options: kFinFixedPaymentBranches
                                                  .map(
                                                    (row) => _SimpleOption(
                                                      id: row,
                                                      label:
                                                          finFixedPaymentBranchLabel(
                                                            row,
                                                          ),
                                                      subtitle: '',
                                                    ),
                                                  )
                                                  .toList(growable: false),
                                            );
                                        if (selected == null || !mounted) {
                                          return;
                                        }
                                        setState(() => _branch = selected.id);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _amountC,
                                      style: const TextStyle(
                                        color: kFinanzasInk,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      cursorColor:
                                          finanzasAreaTokens.primaryStrong,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: const [
                                        _FixedMoneyInputFormatter(),
                                      ],
                                      decoration: _fixedDialogFieldDecoration(
                                        context,
                                        hintText: 'Monto',
                                        prefixIcon: const Icon(
                                          Icons.payments_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _FixedChoiceField(
                                      label: 'Fecha pago',
                                      value: _dateLabel(_paymentDate),
                                      onTap: () {
                                        unawaited(_pickPaymentDate());
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _FixedChoiceField(
                                      label: 'Estado',
                                      value: finFixedPaymentStatusLabel(
                                        _status,
                                      ),
                                      onTap: () async {
                                        final selected =
                                            await _showSimpleOptionsDialog(
                                              context: context,
                                              title: 'Seleccionar estado',
                                              options: kFinFixedPaymentStatuses
                                                  .map(
                                                    (row) => _SimpleOption(
                                                      id: row,
                                                      label:
                                                          finFixedPaymentStatusLabel(
                                                            row,
                                                          ),
                                                      subtitle: '',
                                                    ),
                                                  )
                                                  .toList(growable: false),
                                            );
                                        if (selected == null || !mounted) {
                                          return;
                                        }
                                        setState(() => _status = selected.id);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              const _FixedDialogSectionTitle(
                                step: '3',
                                title: 'Comentario',
                                subtitle:
                                    'Agrega el detalle operativo del compromiso o del recibo.',
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _notesC,
                                minLines: 3,
                                maxLines: 4,
                                style: const TextStyle(
                                  color: kFinanzasInk,
                                  fontWeight: FontWeight.w700,
                                ),
                                cursorColor: finanzasAreaTokens.primaryStrong,
                                decoration: _fixedDialogFieldDecoration(
                                  context,
                                  hintText: 'Comentario o detalle del recibo',
                                  prefixIcon: const Icon(
                                    Icons.note_alt_outlined,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: tokens.primaryStrong,
                              backgroundColor: tokens.fieldSurface.withValues(
                                alpha: 0.72,
                              ),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              minimumSize: const Size(148, 52),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 16,
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: tokens.primaryStrong,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: tokens.primarySoft
                                  .withValues(alpha: 0.46),
                              disabledForegroundColor: Colors.white.withValues(
                                alpha: 0.82,
                              ),
                              minimumSize: const Size(220, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 16,
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onPressed: !_canSave
                                ? null
                                : () {
                                    Navigator.of(context).pop(
                                      _FixedPaymentDraft(
                                        receivedDate: _receivedDate,
                                        companyId: _companyId,
                                        companyNameSnapshot: companyName,
                                        targetCompany: _targetCompany,
                                        branch: _branch,
                                        amount: _parseAmount(),
                                        paymentDate: _paymentDate,
                                        status: _status,
                                        notes: _notesC.text.trim(),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              isEditing ? 'Guardar cambios' : 'Guardar pago',
                            ),
                          ),
                        ],
                      ),
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

class _FixedTopBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onExport;
  final VoidCallback onCreate;
  final bool exporting;

  const _FixedTopBar({
    required this.selectedCount,
    required this.onExport,
    required this.onCreate,
    required this.exporting,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return FinanzasGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: BorderRadius.circular(26),
      fillColor: const Color(0x12161A22),
      borderColor: Colors.white.withValues(alpha: 0.24),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.primaryStrong,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.26)),
                  disabledForegroundColor: tokens.badgeText.withValues(
                    alpha: 0.55,
                  ),
                ),
                onPressed: exporting ? null : onExport,
                icon: const Icon(Icons.download_rounded),
                label: Text(exporting ? 'Exportando...' : 'Descargar CSV'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.primaryStrong,
                  foregroundColor: Colors.white,
                ),
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo pago fijo'),
              ),
            ],
          );
          final selected = Text(
            '$selectedCount seleccionadas',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: tokens.badgeText,
            ),
            textAlign: TextAlign.right,
          );
          if (constraints.maxWidth < 820) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                actions,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: selected),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: actions),
              const SizedBox(width: 12),
              selected,
            ],
          );
        },
      ),
    );
  }
}

class _FinanzasGridPager extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final int totalRows;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onPageSizeChanged;

  const _FinanzasGridPager({
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.totalRows,
    required this.onPrevious,
    required this.onNext,
    required this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final secondaryStyle = OutlinedButton.styleFrom(
      foregroundColor: tokens.badgeText,
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    );
    return Align(
      alignment: Alignment.center,
      child: UnconstrainedBox(
        constrainedAxis: Axis.vertical,
        child: FinanzasGlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          borderRadius: BorderRadius.circular(22),
          fillColor: const Color(0x12161A22),
          borderColor: Colors.white.withValues(alpha: 0.18),
          edgeHighlightColor: Colors.white.withValues(alpha: 0.16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                style: secondaryStyle,
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Anterior'),
              ),
              Text(
                'Página ${currentPage + 1} de $totalPages',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: tokens.badgeText,
                ),
              ),
              OutlinedButton.icon(
                style: secondaryStyle,
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Siguiente'),
              ),
              Text(
                'Filas/pág:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: tokens.onGlass.withValues(alpha: 0.72),
                ),
              ),
              SizedBox(
                width: 92,
                child: DropdownButtonFormField<int>(
                  initialValue: pageSize,
                  isDense: true,
                  dropdownColor: const Color(0xFF171C24),
                  iconEnabledColor: tokens.badgeText,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.badgeText,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xCC171C24),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: tokens.primaryStrong.withValues(alpha: 0.78),
                        width: 1.3,
                      ),
                    ),
                  ),
                  items: const [20, 40, 80]
                      .map(
                        (value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) onPageSizeChanged(value);
                  },
                ),
              ),
              Text(
                'Total: $totalRows',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: tokens.badgeText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FixedMetricCardData {
  final String label;
  final String value;
  final Color tone;
  final IconData icon;
  final String footerTitle;
  final String footerSubtitle;
  final IconData footerIcon;

  const _FixedMetricCardData({
    required this.label,
    required this.value,
    required this.tone,
    required this.icon,
    required this.footerTitle,
    required this.footerSubtitle,
    required this.footerIcon,
  });
}

class _FixedMetricsRow extends StatelessWidget {
  final List<_FixedMetricCardData> cards;

  const _FixedMetricsRow({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = cards.isEmpty
            ? 250.0
            : ((constraints.maxWidth - ((cards.length - 1) * 12)) /
                      cards.length)
                  .clamp(220.0, 360.0);
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: _FixedMetricCard(data: card),
              ),
          ],
        );
      },
    );
  }
}

class _FixedMetricCard extends StatelessWidget {
  final _FixedMetricCardData data;

  const _FixedMetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final tone = data.tone;
    return FinanzasGlassPanel(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      borderRadius: BorderRadius.circular(26),
      fillColor: const Color(0x14161A21),
      borderColor: Colors.white.withValues(alpha: 0.24),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.20),
      glowColor: tone.withValues(alpha: 0.12),
      child: SizedBox(
        height: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tone.withValues(alpha: 0.10),
                border: Border.all(color: tone.withValues(alpha: 0.26)),
                boxShadow: [
                  BoxShadow(
                    color: tone.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(data.icon, color: tone, size: 36),
            ),
            const Spacer(flex: 2),
            Text(
              data.label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kFinanzasInk,
              ),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                data.value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: tone,
                ),
              ),
            ),
            const Spacer(),
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: tone.withValues(alpha: 0.14),
                    border: Border.all(color: tone.withValues(alpha: 0.22)),
                    boxShadow: [
                      BoxShadow(
                        color: tone.withValues(alpha: 0.16),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(data.footerIcon, color: tone, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.footerTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: kFinanzasInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.footerSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kFinanzasMutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FixedTabSurface extends StatelessWidget {
  final Widget child;

  const _FixedTabSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return FinanzasGlassPanel(
      borderRadius: BorderRadius.circular(32),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      fillColor: const Color(0x14141920),
      borderColor: Colors.white.withValues(alpha: 0.28),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.18),
      glowColor: const Color(0x1FFF7A1F),
      child: child,
    );
  }
}

class _FixedFilterSummaryRow extends StatelessWidget {
  final List<String> labels;
  final VoidCallback? onClearAll;

  const _FixedFilterSummaryRow({required this.labels, this.onClearAll});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    if (labels.isEmpty && onClearAll == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: tokens.badgeText,
              ),
            ),
          ),
        if (onClearAll != null)
          TextButton.icon(
            onPressed: onClearAll,
            icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
            label: const Text('Limpiar filtros'),
            style: TextButton.styleFrom(foregroundColor: tokens.primarySoft),
          ),
      ],
    );
  }
}

class _FixedHeaderColumn {
  final String label;
  final double width;
  final VoidCallback? onFilter;
  final bool active;

  const _FixedHeaderColumn(
    this.label,
    this.width, {
    this.onFilter,
    this.active = false,
  });
}

class _FixedHeaderRow extends StatelessWidget {
  final VoidCallback onReceivedDateFilter;
  final VoidCallback onCompanyFilter;
  final VoidCallback onAccountFilter;
  final VoidCallback onBranchFilter;
  final VoidCallback onAmountFilter;
  final VoidCallback onPaymentDateFilter;
  final VoidCallback onStatusFilter;
  final bool receivedDateFilterActive;
  final bool companyFilterActive;
  final bool accountFilterActive;
  final bool branchFilterActive;
  final bool amountFilterActive;
  final bool paymentDateFilterActive;
  final bool statusFilterActive;

  const _FixedHeaderRow({
    required this.onReceivedDateFilter,
    required this.onCompanyFilter,
    required this.onAccountFilter,
    required this.onBranchFilter,
    required this.onAmountFilter,
    required this.onPaymentDateFilter,
    required this.onStatusFilter,
    required this.receivedDateFilterActive,
    required this.companyFilterActive,
    required this.accountFilterActive,
    required this.branchFilterActive,
    required this.amountFilterActive,
    required this.paymentDateFilterActive,
    required this.statusFilterActive,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final columns = <_FixedHeaderColumn>[
      _FixedHeaderColumn(
        'FECHA RECIBIDO',
        _kFixedReceivedDateW,
        onFilter: onReceivedDateFilter,
        active: receivedDateFilterActive,
      ),
      _FixedHeaderColumn(
        'EMPRESA',
        _kFixedCompanyW,
        onFilter: onCompanyFilter,
        active: companyFilterActive,
      ),
      _FixedHeaderColumn(
        'CUENTA',
        _kFixedBranchW,
        onFilter: onAccountFilter,
        active: accountFilterActive,
      ),
      _FixedHeaderColumn(
        'SUCURSAL',
        _kFixedSucursalW,
        onFilter: onBranchFilter,
        active: branchFilterActive,
      ),
      _FixedHeaderColumn(
        'MONTO',
        _kFixedAmountW,
        onFilter: onAmountFilter,
        active: amountFilterActive,
      ),
      _FixedHeaderColumn(
        'FECHA PAGO',
        _kFixedPaymentDateW,
        onFilter: onPaymentDateFilter,
        active: paymentDateFilterActive,
      ),
      _FixedHeaderColumn(
        'ESTADO',
        _kFixedStatusW,
        onFilter: onStatusFilter,
        active: statusFilterActive,
      ),
      const _FixedHeaderColumn('COMENTARIO', _kFixedNotesW),
    ];
    return FinanzasGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: BorderRadius.circular(18),
      fillColor: const Color(0x10151A22),
      borderColor: Colors.white.withValues(alpha: 0.16),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = columns.fold<double>(
            _kFixedActionsW,
            (sum, column) => sum + column.width,
          );
          return SizedBox(
            width: constraints.maxWidth,
            child: ContractGridScaledRow(
              child: SizedBox(
                width: totalWidth,
                child: Row(
                  children: [
                    for (final column in columns)
                      SizedBox(
                        width: column.width,
                        child: SizedBox(
                          height: 34,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
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
                                          ? tokens.primaryStrong.withValues(
                                              alpha: 0.92,
                                            )
                                          : Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: column.active
                                            ? tokens.primarySoft.withValues(
                                                alpha: 0.82,
                                              )
                                            : Colors.white.withValues(
                                                alpha: 0.16,
                                              ),
                                      ),
                                    ),
                                    child: Icon(
                                      column.active
                                          ? Icons.filter_alt
                                          : Icons.filter_alt_outlined,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        column.label,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: tokens.badgeText,
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
                    const SizedBox(width: _kFixedActionsW),
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

class _FixedPaymentsGrid extends StatelessWidget {
  final List<FinanzasFixedPaymentRecord> rows;
  final Set<String> selectedRowIds;
  final String? activeRowId;
  final bool dragSelectionActive;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime value) dateFormatter;
  final Color Function(String status) statusTone;
  final void Function(String rowId, int rowIndex) onRowTap;
  final void Function(String rowId, {required bool additive}) onDragStart;
  final ValueChanged<String> onDragEnter;
  final VoidCallback onDragEnd;
  final void Function(String rowId, int rowIndex) onPrepareMenuSelection;
  final ValueChanged<FinanzasFixedPaymentRecord> onEdit;
  final ValueChanged<FinanzasFixedPaymentRecord> onDelete;
  final ValueChanged<FinanzasFixedPaymentRecord> onPayCash;
  final GridScrollVisibilityCoordinator visibilityCoordinator;

  const _FixedPaymentsGrid({
    required this.rows,
    required this.selectedRowIds,
    required this.activeRowId,
    required this.dragSelectionActive,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.statusTone,
    required this.onRowTap,
    required this.onDragStart,
    required this.onDragEnter,
    required this.onDragEnd,
    required this.onPrepareMenuSelection,
    required this.onEdit,
    required this.onDelete,
    required this.onPayCash,
    required this.visibilityCoordinator,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final row = rows[index];
        final scrollKey = visibilityCoordinator.keyForCell(
          zone: GridNavigationZone.grid,
          rowIndex: index,
          columnIndex: 0,
        );
        return KeyedSubtree(
          key: scrollKey,
          child: _FixedPaymentRow(
            rowKey: row.id,
            row: row,
            selected: selectedRowIds.contains(row.id),
            active: activeRowId == row.id,
            dragSelectionActive: dragSelectionActive,
            moneyFormatter: moneyFormatter,
            dateFormatter: dateFormatter,
            statusTone: statusTone,
            onTap: () => onRowTap(row.id, index),
            onDragStart: (additive) => onDragStart(row.id, additive: additive),
            onDragEnter: () => onDragEnter(row.id),
            onDragEnd: onDragEnd,
            onDoubleTap: () => onEdit(row),
            onPrepareMenuSelection: () => onPrepareMenuSelection(row.id, index),
            onEdit: () => onEdit(row),
            onPayCash: row.status == 'PAGADO' ? null : () => onPayCash(row),
            onDelete: () => onDelete(row),
          ),
        );
      },
    );
  }
}

class _FixedPaymentRow extends StatefulWidget {
  final String rowKey;
  final FinanzasFixedPaymentRecord row;
  final bool selected;
  final bool active;
  final bool dragSelectionActive;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime value) dateFormatter;
  final Color Function(String status) statusTone;
  final VoidCallback onTap;
  final ValueChanged<bool> onDragStart;
  final VoidCallback onDragEnter;
  final VoidCallback onDragEnd;
  final VoidCallback? onDoubleTap;
  final VoidCallback onPrepareMenuSelection;
  final VoidCallback onEdit;
  final VoidCallback? onPayCash;
  final VoidCallback onDelete;

  const _FixedPaymentRow({
    required this.rowKey,
    required this.row,
    required this.selected,
    this.active = false,
    required this.dragSelectionActive,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.statusTone,
    required this.onTap,
    required this.onDragStart,
    required this.onDragEnter,
    required this.onDragEnd,
    this.onDoubleTap,
    required this.onPrepareMenuSelection,
    required this.onEdit,
    required this.onPayCash,
    required this.onDelete,
  });

  @override
  State<_FixedPaymentRow> createState() => _FixedPaymentRowState();
}

class _FixedPaymentRowState extends State<_FixedPaymentRow> {
  bool _hovering = false;
  int? _hoveredEditableColumn;

  Future<void> _openContextMenuAt(Offset globalPosition) async {
    final menuItems = <_FixedRowMenuAction>[
      _FixedRowMenuAction(label: 'Editar', onTap: widget.onEdit),
      if (widget.onPayCash != null)
        _FixedRowMenuAction(
          label: 'Pagar en efectivo',
          onTap: widget.onPayCash!,
        ),
      _FixedRowMenuAction(label: 'Eliminar', onTap: widget.onDelete),
    ];
    final action = await showEditableGridContextMenu<_FixedRowMenuAction>(
      context: context,
      globalPosition: globalPosition,
      entries: [
        for (final item in menuItems)
          ContractMenuEntry<_FixedRowMenuAction>(
            value: item,
            label: item.label,
          ),
      ],
    );
    action?.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.statusTone(widget.row.status);
    final tokens = AreaThemeScope.of(context);
    final softenDividers = _hoveredEditableColumn != null;
    final rowContentWidth =
        _kFixedReceivedDateW +
        _kFixedCompanyW +
        _kFixedBranchW +
        _kFixedSucursalW +
        _kFixedAmountW +
        _kFixedPaymentDateW +
        _kFixedStatusW +
        _kFixedNotesW +
        _kFixedActionsW;
    final menuItems = <_FixedRowMenuAction>[
      _FixedRowMenuAction(label: 'Editar', onTap: widget.onEdit),
      if (widget.onPayCash != null)
        _FixedRowMenuAction(
          label: 'Pagar en efectivo',
          onTap: widget.onPayCash!,
        ),
      _FixedRowMenuAction(label: 'Eliminar', onTap: widget.onDelete),
    ];

    Widget buildCell(
      int index,
      double width,
      Widget child, {
      bool editable = false,
      bool showDivider = true,
    }) {
      final hoveredEditable = editable && _hoveredEditableColumn == index;
      final content = Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ContractEditableHoverCapsule(
              hovered: hoveredEditable,
              selectedContext: false,
              child: child,
            ),
          ),
          if (showDivider)
            Positioned(
              right: 4,
              top: 2,
              bottom: 2,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 110),
                opacity: softenDividers ? 0.0 : 1.0,
                child: Container(
                  width: 1,
                  decoration: BoxDecoration(
                    color: tokens.border.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
        ],
      );
      final cellChild = SizedBox(width: width, child: content);
      if (!editable) return cellChild;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredEditableColumn = index),
        onExit: (_) {
          if (_hoveredEditableColumn == index) {
            setState(() => _hoveredEditableColumn = null);
          }
        },
        child: cellChild,
      );
    }

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovering = true);
        if (widget.dragSelectionActive) {
          widget.onDragEnter();
        }
      },
      onExit: (_) => setState(() => _hovering = false),
      child: Card(
        elevation: 0,
        color: widget.selected
            ? finanzasAreaTokens.primaryStrong.withValues(
                alpha: widget.active ? 0.24 : 0.18,
              )
            : _hovering
            ? const Color(0xE01D222B)
            : const Color(0xCC171B23),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: widget.active
                ? tokens.primaryStrong.withValues(alpha: 0.82)
                : widget.selected
                ? tokens.primaryStrong.withValues(alpha: 0.64)
                : tokens.primaryStrong.withValues(alpha: 0.10),
            width: widget.active
                ? 1.5
                : widget.selected
                ? 1.2
                : 1,
          ),
        ),
        shadowColor: widget.selected
            ? tokens.primaryStrong.withValues(
                alpha: widget.active ? 0.18 : 0.10,
              )
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: constraints.maxWidth,
                child: ContractGridScaledRow(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onSecondaryTapDown: (details) {
                      widget.onPrepareMenuSelection();
                      unawaited(_openContextMenuAt(details.globalPosition));
                    },
                    child: Listener(
                      onPointerDown: (event) {
                        if (event.buttons == 0) return;
                        final pressed =
                            HardwareKeyboard.instance.logicalKeysPressed;
                        final additive =
                            pressed.contains(LogicalKeyboardKey.controlLeft) ||
                            pressed.contains(LogicalKeyboardKey.controlRight) ||
                            pressed.contains(LogicalKeyboardKey.metaLeft) ||
                            pressed.contains(LogicalKeyboardKey.metaRight);
                        widget.onDragStart(additive);
                      },
                      onPointerUp: (_) => widget.onDragEnd(),
                      onPointerCancel: (_) => widget.onDragEnd(),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onTap,
                          onDoubleTap: widget.onDoubleTap,
                          borderRadius: BorderRadius.circular(22),
                          child: DefaultTextStyle(
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: kFinanzasInk,
                            ),
                            child: SizedBox(
                              width: rowContentWidth,
                              child: Row(
                                children: [
                                  buildCell(
                                    0,
                                    _kFixedReceivedDateW,
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(
                                        widget.dateFormatter(
                                          widget.row.receivedDate,
                                        ),
                                      ),
                                    ),
                                  ),
                                  buildCell(
                                    1,
                                    _kFixedCompanyW,
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        widget.row.companyNameSnapshot,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    editable: true,
                                  ),
                                  buildCell(
                                    2,
                                    _kFixedBranchW,
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        finFixedPaymentTargetCompanyLabel(
                                          widget.row.targetCompany,
                                        ),
                                      ),
                                    ),
                                    editable: true,
                                  ),
                                  buildCell(
                                    3,
                                    _kFixedSucursalW,
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        finFixedPaymentBranchLabel(
                                          widget.row.branch,
                                        ),
                                      ),
                                    ),
                                    editable: true,
                                  ),
                                  buildCell(
                                    4,
                                    _kFixedAmountW,
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(
                                        widget.moneyFormatter(
                                          widget.row.amount,
                                        ),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: tokens.primaryStrong,
                                        ),
                                      ),
                                    ),
                                  ),
                                  buildCell(
                                    5,
                                    _kFixedPaymentDateW,
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(
                                        widget.dateFormatter(
                                          widget.row.paymentDate,
                                        ),
                                      ),
                                    ),
                                    editable: true,
                                  ),
                                  buildCell(
                                    6,
                                    _kFixedStatusW,
                                    _MiniToneChip(
                                      label: finFixedPaymentStatusLabel(
                                        widget.row.status,
                                      ),
                                      tone: tone,
                                    ),
                                    editable: true,
                                  ),
                                  buildCell(
                                    7,
                                    _kFixedNotesW,
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        widget.row.notes.trim().isEmpty
                                            ? '—'
                                            : widget.row.notes,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    editable: true,
                                    showDivider: false,
                                  ),
                                  SizedBox(
                                    width: _kFixedActionsW,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: AnchoredActionSlot(
                                        width: _kFixedActionsW,
                                        trailingWidth: 36,
                                        leading: const SizedBox.shrink(),
                                        trailing: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: widget.selected
                                                ? const Color(0xCC1D2129)
                                                : Colors.white.withValues(
                                                    alpha: 0.06,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: widget.selected
                                                  ? tokens.primaryStrong
                                                        .withValues(alpha: 0.62)
                                                  : tokens.border.withValues(
                                                      alpha: 0.24,
                                                    ),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                                color: Colors.black.withValues(
                                                  alpha: 0.06,
                                                ),
                                              ),
                                            ],
                                          ),
                                          child:
                                              EditableRowActionsButton<
                                                _FixedRowMenuAction
                                              >(
                                                tooltip: 'Acciones',
                                                iconColor: widget.selected
                                                    ? Colors.white.withValues(
                                                        alpha: 0.96,
                                                      )
                                                    : null,
                                                entries: [
                                                  for (final item in menuItems)
                                                    ContractMenuEntry<
                                                      _FixedRowMenuAction
                                                    >(
                                                      value: item,
                                                      label: item.label,
                                                    ),
                                                ],
                                                onSelected: (item) {
                                                  widget
                                                      .onPrepareMenuSelection();
                                                  item.onTap();
                                                },
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
            },
          ),
        ),
      ),
    );
  }
}

class _FixedRowMenuAction {
  final String label;
  final VoidCallback onTap;

  const _FixedRowMenuAction({required this.label, required this.onTap});
}

class _MiniToneChip extends StatelessWidget {
  final String label;
  final Color tone;

  const _MiniToneChip({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: tone,
        ),
      ),
    );
  }
}

class _FixedEmptyPane extends StatelessWidget {
  const _FixedEmptyPane();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Center(
      child: FinanzasGlassPanel(
        width: 420,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        borderRadius: BorderRadius.circular(24),
        fillColor: const Color(0x12161A22),
        borderColor: Colors.white.withValues(alpha: 0.18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 34,
              color: tokens.primaryStrong,
            ),
            const SizedBox(height: 12),
            Text(
              'Sin pagos fijos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Captura los compromisos del mes para alimentar la planeación de pagos desde esta pantalla.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderBrand extends StatelessWidget {
  final String title;

  const _HeaderBrand({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
          ),
          alignment: Alignment.center,
          child: const DicsaLogoD(size: 42),
        ),
        const SizedBox(width: 18),
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: kFinanzasInk,
          ),
        ),
      ],
    );
  }
}

class _HeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _HeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
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
                    Colors.white.withValues(alpha: highlighted ? 0.36 : 0.24),
                    tokens.surfaceTint.withValues(
                      alpha: highlighted ? 0.46 : 0.28,
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
                  BoxShadow(
                    blurRadius: highlighted ? 20 : 10,
                    color: tokens.glow.withValues(
                      alpha: highlighted ? 0.12 : 0.05,
                    ),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.icon, size: 20, color: tokens.primaryStrong),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: tokens.primaryStrong,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
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
    );
  }
}

class _FixedPaymentsBackground extends StatelessWidget {
  const _FixedPaymentsBackground();

  @override
  Widget build(BuildContext context) => const FinanzasAreaBackground();
}

class _SidePanel extends StatelessWidget {
  final bool canReturnToDirection;
  final bool canAccessComprasArea;
  final ValueChanged<String> onNavigate;

  const _SidePanel({
    required this.canReturnToDirection,
    required this.canAccessComprasArea,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 56, 0, 28),
        child: FinanzasAreaSidePanel(
          currentLabel: 'Pagos fijos',
          canReturnToDirection: canReturnToDirection,
          canAccessComprasArea: canAccessComprasArea,
          onNavigate: onNavigate,
        ),
      ),
    );
  }
}

class _SimpleOption {
  final String id;
  final String label;
  final String subtitle;

  const _SimpleOption({
    required this.id,
    required this.label,
    required this.subtitle,
  });
}

Future<_SimpleOption?> _showSimpleOptionsDialog({
  required BuildContext context,
  required String title,
  required List<_SimpleOption> options,
}) {
  final searchC = TextEditingController();
  final optionKeys = <GlobalKey>[];
  var highlightedIndex = -1;
  int? hoveredIndex;
  return showDialog<_SimpleOption>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setLocalState) {
        final query = searchC.text.trim().toLowerCase();
        final filtered = options
            .where((row) {
              if (query.isEmpty) return true;
              return row.label.toLowerCase().contains(query) ||
                  row.subtitle.toLowerCase().contains(query);
            })
            .toList(growable: false);
        _syncFixedPickerOptionKeys(optionKeys, filtered.length);
        if (highlightedIndex >= 0) {
          _ensureFixedPickerHighlightVisible(
            keys: optionKeys,
            highlightedIndex: highlightedIndex,
            rowCount: filtered.length,
          );
        }

        void selectHighlighted() {
          if (filtered.isEmpty || highlightedIndex < 0) return;
          Navigator.of(
            context,
          ).pop(filtered[highlightedIndex.clamp(0, filtered.length - 1)]);
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          child: AreaThemeScope(
            tokens: finanzasAreaTokens,
            child: Builder(
              builder: (dialogContext) => Focus(
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                      filtered.isNotEmpty) {
                    setLocalState(() {
                      highlightedIndex = highlightedIndex < 0
                          ? 0
                          : (highlightedIndex + 1).clamp(
                              0,
                              filtered.length - 1,
                            );
                    });
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                      filtered.isNotEmpty) {
                    setLocalState(() {
                      highlightedIndex = highlightedIndex < 0
                          ? filtered.length - 1
                          : (highlightedIndex - 1).clamp(
                              0,
                              filtered.length - 1,
                            );
                    });
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.enter) {
                    selectHighlighted();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: FinanzasGlassPanel(
                  borderRadius: BorderRadius.circular(28),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  fillColor: const Color(0x1813171F),
                  borderColor: Colors.white.withValues(alpha: 0.18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 520,
                      maxHeight: 560,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: kFinanzasInk,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: searchC,
                          autofocus: true,
                          onChanged: (_) => setLocalState(() {
                            highlightedIndex = -1;
                          }),
                          style: const TextStyle(
                            color: kFinanzasInk,
                            fontWeight: FontWeight.w700,
                          ),
                          cursorColor: finanzasAreaTokens.primaryStrong,
                          decoration: _fixedDialogFieldDecoration(
                            dialogContext,
                            hintText: 'Buscar opción',
                            prefixIcon: const Icon(Icons.search_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              final row = filtered[index];
                              final selected =
                                  index == highlightedIndex &&
                                  (hoveredIndex == null ||
                                      hoveredIndex == index);
                              return KeyedSubtree(
                                key: optionKeys[index],
                                child: _FixedPickerOptionTile(
                                  title: row.label,
                                  subtitle: row.subtitle,
                                  selected: selected,
                                  hovered: hoveredIndex == index,
                                  onHoverChanged: (hovered) {
                                    setLocalState(() {
                                      hoveredIndex = hovered ? index : null;
                                    });
                                  },
                                  onTap: () => Navigator.of(context).pop(row),
                                ),
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
          ),
        );
      },
    ),
  );
}

class _FixedDialogSectionTitle extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;

  const _FixedDialogSectionTitle({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: tokens.primaryStrong.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: tokens.primaryStrong.withValues(alpha: 0.24),
            ),
          ),
          child: Center(
            child: Text(
              step,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: kFinanzasInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kFinanzasMutedInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FixedChoiceField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _FixedChoiceField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return FinanzasGlassPanel(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(20),
      fillColor: const Color(0x18161A22),
      borderColor: Colors.white.withValues(alpha: 0.22),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.22),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: tokens.badgeText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: tokens.primaryStrong,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.expand_more_rounded, color: tokens.primaryStrong),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FixedPickerOptionTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final bool hovered;
  final ValueChanged<bool>? onHoverChanged;
  final VoidCallback onTap;

  const _FixedPickerOptionTile({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.hovered = false,
    this.onHoverChanged,
  });

  @override
  State<_FixedPickerOptionTile> createState() => _FixedPickerOptionTileState();
}

class _FixedPickerOptionTileState extends State<_FixedPickerOptionTile> {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
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
                if (widget.subtitle != null &&
                    widget.subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected || hovered
                          ? tokens.onGlass
                          : kFinanzasMutedInk,
                      fontWeight: FontWeight.w600,
                    ),
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

Future<DateTimeRange?> _showFixedDateRangeDialog(
  BuildContext context, {
  required String title,
  DateTimeRange? initialRange,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDialog<DateTimeRange?>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      DateTime displayMonth = defaultDatePickerOpenMonth(
        firstDate: firstDate,
        lastDate: lastDate,
      );
      DateTime? start = initialRange?.start;
      DateTime? end = initialRange?.end;
      DateTime? hover;

      bool isSameDay(DateTime a, DateTime b) =>
          a.year == b.year && a.month == b.month && a.day == b.day;
      DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

      return AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            final tokens = AreaThemeScope.of(context);
            final theme = Theme.of(context);
            final monthFirst = DateTime(
              displayMonth.year,
              displayMonth.month,
              1,
            );
            final leading = (monthFirst.weekday + 6) % 7;
            final gridStart = monthFirst.subtract(Duration(days: leading));
            final previewEnd = end ?? hover;

            bool withinBounds(DateTime day) {
              final d = dateOnly(day);
              return !d.isBefore(dateOnly(firstDate)) &&
                  !d.isAfter(dateOnly(lastDate));
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

            DateTimeRange? buildResult() {
              if (start == null) return null;
              final s = dateOnly(start!);
              final e = dateOnly(end ?? start!);
              final from = s.isBefore(e) ? s : e;
              final to = s.isBefore(e) ? e : s;
              return DateTimeRange(start: from, end: to);
            }

            final colorScheme = theme.colorScheme.copyWith(
              primary: tokens.primaryStrong,
              secondary: tokens.primary,
              surface: tokens.surfaceTint,
              onSurface: tokens.badgeText,
            );

            return Theme(
              data: theme.copyWith(
                colorScheme: colorScheme,
                splashColor: tokens.primaryStrong.withValues(alpha: 0.12),
                highlightColor: tokens.primaryStrong.withValues(alpha: 0.08),
                hoverColor: tokens.primarySoft.withValues(alpha: 0.12),
                focusColor: tokens.primarySoft.withValues(alpha: 0.16),
                iconTheme: IconThemeData(color: tokens.primaryStrong),
                iconButtonTheme: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    foregroundColor: tokens.primaryStrong,
                    hoverColor: tokens.primarySoft.withValues(alpha: 0.12),
                    highlightColor: tokens.primaryStrong.withValues(
                      alpha: 0.08,
                    ),
                  ),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.primaryStrong,
                    overlayColor: tokens.primaryStrong.withValues(alpha: 0.08),
                  ),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.primaryStrong,
                    overlayColor: tokens.primaryStrong.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 24,
                ),
                child: ContractPopupSurface(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                    maxHeight: 516,
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: tokens.primaryStrong,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            color: tokens.primaryStrong,
                            onPressed: () => setLocalState(
                              () => displayMonth = DateTime(
                                displayMonth.year,
                                displayMonth.month - 1,
                              ),
                            ),
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '${_fixedMonthNameEs(monthFirst.month)} ${monthFirst.year}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: tokens.badgeText,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            color: tokens.primaryStrong,
                            onPressed: () => setLocalState(
                              () => displayMonth = DateTime(
                                displayMonth.year,
                                displayMonth.month + 1,
                              ),
                            ),
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (final dayLabel in const [
                            'L',
                            'M',
                            'M',
                            'J',
                            'V',
                            'S',
                            'D',
                          ])
                            Expanded(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    dayLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: tokens.badgeText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 42,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                              childAspectRatio: 1.08,
                            ),
                        itemBuilder: (_, index) {
                          final day = gridStart.add(Duration(days: index));
                          final inMonth = day.month == monthFirst.month;
                          final allowed = withinBounds(day);
                          final active =
                              (start != null && isSameDay(day, start!)) ||
                              (end != null && isSameDay(day, end!));
                          final inRange = inPreviewRange(day) && allowed;
                          return MouseRegion(
                            onEnter: (_) {
                              if (start != null && end == null && allowed) {
                                setLocalState(() => hover = dateOnly(day));
                              }
                            },
                            child: GestureDetector(
                              onTap: !allowed
                                  ? null
                                  : () {
                                      final picked = dateOnly(day);
                                      setLocalState(() {
                                        if (start == null || end != null) {
                                          start = picked;
                                          end = null;
                                          hover = null;
                                        } else {
                                          end = picked;
                                          hover = null;
                                        }
                                      });
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                decoration: BoxDecoration(
                                  color: active
                                      ? tokens.primaryStrong.withValues(
                                          alpha: 0.18,
                                        )
                                      : inRange
                                      ? tokens.primarySoft.withValues(
                                          alpha: 0.24,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: active
                                        ? tokens.primaryStrong.withValues(
                                            alpha: 0.46,
                                          )
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: active
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      color: !allowed
                                          ? tokens.badgeText.withValues(
                                              alpha: 0.28,
                                            )
                                          : inMonth
                                          ? tokens.primaryStrong
                                          : tokens.badgeText.withValues(
                                              alpha: 0.55,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        start == null
                            ? 'Selecciona fecha inicial'
                            : end == null
                            ? 'Selecciona fecha final'
                            : '${_formatFixedFilterDate(start!)} - ${_formatFixedFilterDate(end!)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: tokens.badgeText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => Navigator.of(
                              dialogContext,
                            ).pop(_kClearedFixedDateRange),
                            child: const Text('Limpiar'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: start == null
                                ? null
                                : () => Navigator.of(
                                    dialogContext,
                                  ).pop(buildResult()),
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
        ),
      );
    },
  );
}

String _fixedMonthNameEs(int month) {
  const names = <String>[
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
  return names[month - 1];
}

String _formatFixedFilterDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _FixedMoneyInputFormatter extends TextInputFormatter {
  const _FixedMoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final cents = int.parse(digitsOnly);
    final value = cents / 100;
    final formatted = formatDecimal(value, decimals: 2);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

InputDecoration _fixedDialogFieldDecoration(
  BuildContext context, {
  String? hintText,
  Widget? prefixIcon,
}) {
  final tokens = AreaThemeScope.of(context);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
  );
  return contractGlassFieldDecoration(
    context,
    hintText: hintText,
    prefixIcon: prefixIcon,
  ).copyWith(
    filled: true,
    fillColor: const Color(0xCC171C24),
    hintStyle: TextStyle(color: tokens.onGlass.withValues(alpha: 0.54)),
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(
        color: tokens.primaryStrong.withValues(alpha: 0.80),
        width: 1.4,
      ),
    ),
  );
}
