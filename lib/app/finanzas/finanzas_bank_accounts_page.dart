import 'dart:async';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../compras/compras_dashboard_page.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/archetypes/grid_editable/filters/grid_filter_dialog.dart';
import '../shared/archetypes/grid_editable/filters/grid_filter_state.dart';
import '../shared/archetypes/grid_editable/grid_keyboard_shell.dart';
import '../shared/archetypes/grid_editable/grid_navigation_controller.dart';
import '../shared/archetypes/grid_editable/grid_scroll_visibility_coordinator.dart';
import '../shared/archetypes/grid_editable/grid_selection_controller.dart';
import '../shared/archetypes/grid_editable/row/editable_grid_context_menu.dart';
import '../shared/archetypes/grid_editable/row/editable_row_actions_button.dart';
import '../shared/archetypes/auxiliary_surfaces/auxiliary_surfaces.dart';
import '../shared/utils/file_download_save.dart';
import '../shared/ui_contract_core/dialogs/contract_menu_surface.dart';
import '../shared/ui_contract_core/dialogs/contract_popup_surface.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/editable_hover_capsule.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import '../shared/utils/date_picker_defaults.dart';
import '../shared/utils/number_formatters.dart';
import 'finanzas_bank_accounts_store.dart';
import 'finanzas_catalog_page.dart';
import 'finanzas_company_directory_page.dart';
import 'finanzas_data_store.dart';
import 'finanzas_dashboard_page.dart';
import 'finanzas_evidence_store.dart';
import 'finanzas_fixed_payments_store.dart';
import 'finanzas_fixed_payments_page.dart';
import 'finanzas_payment_center_page.dart';
import 'finanzas_provider_accounts_page.dart';
import 'finanzas_provider_accounts_store.dart';
import 'finanzas_theme.dart';

const double _kBankDateW = 110;
const double _kBankCompanyW = 128;
const double _kBankBranchW = 110;
const double _kBankNameW = 220;
const double _kBankCategoryW = 210;
const double _kBankCommentW = 220;
const double _kBankReferenceW = 170;
const double _kBankCreditW = 120;
const double _kBankDebitW = 120;
const double _kBankActionsW = 72;
final DateTimeRange _kClearedBankDateRange = DateTimeRange(
  start: DateTime(1900),
  end: DateTime(1900),
);

void _syncPickerOptionKeys(List<GlobalKey> keys, int count) {
  while (keys.length < count) {
    keys.add(GlobalKey());
  }
  while (keys.length > count) {
    keys.removeLast();
  }
}

void _ensurePickerHighlightVisible({
  required List<GlobalKey> keys,
  required int highlightedIndex,
  required int rowCount,
}) {
  if (rowCount <= 0) return;
  _syncPickerOptionKeys(keys, rowCount);
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

class FinanzasBankMovementLaunchPreset {
  final String sourceType;
  final String? linkedSupplierInvoiceId;
  final String? linkedClientAccountId;
  final String? linkedFixedPaymentId;
  final String company;
  final String branch;
  final String? counterpartyCompanyId;
  final String counterpartyName;
  final String category;
  final String reference;
  final String comment;
  final double creditAmount;
  final double debitAmount;

  const FinanzasBankMovementLaunchPreset({
    required this.sourceType,
    required this.company,
    required this.branch,
    required this.counterpartyName,
    required this.category,
    required this.reference,
    required this.comment,
    required this.creditAmount,
    required this.debitAmount,
    this.linkedSupplierInvoiceId,
    this.linkedClientAccountId,
    this.linkedFixedPaymentId,
    this.counterpartyCompanyId,
  });
}

class FinanzasBankAccountsPage extends StatefulWidget {
  final bool instantOpen;
  final FinanzasBankMovementLaunchPreset? launchPreset;

  const FinanzasBankAccountsPage({
    super.key,
    this.instantOpen = false,
    this.launchPreset,
  });

  @override
  State<FinanzasBankAccountsPage> createState() =>
      _FinanzasBankAccountsPageState();
}

class _FinanzasBankAccountsPageState extends State<FinanzasBankAccountsPage> {
  bool _menuOpen = false;
  bool _loading = true;
  bool _exportingCsv = false;
  bool _canReturnToDirection = false;
  bool _canAccessComprasArea = false;
  bool _handledLaunchPreset = false;
  final FocusNode _rowsFocusNode = FocusNode(debugLabel: 'bankRows');
  final GridNavigationController _gridNavigationController =
      GridNavigationController();
  final GridSelectionController _gridSelectionController =
      GridSelectionController();
  final GridScrollVisibilityCoordinator _gridVisibilityCoordinator =
      GridScrollVisibilityCoordinator();
  DateTimeRange? _dateRangeFilter;
  Set<String> _companyFilters = <String>{};
  Set<String> _branchFilters = <String>{};
  Set<String> _nameFilters = <String>{};
  Set<String> _categoryFilters = <String>{};
  Set<String> _referenceFilters = <String>{};
  Set<String> _creditFilters = <String>{};
  Set<String> _debitFilters = <String>{};
  String? _selectedRowId;
  Set<String> _selectedRowIds = <String>{};
  String? _selectionAnchorRowId;
  bool _dragSelectionActive = false;
  bool _dragSelectionAdditive = false;
  bool _dragSelectionMoved = false;
  bool _pointerDownAdditiveSelection = false;
  bool _suppressNextRowTap = false;
  Set<String> _dragSelectionBaseIds = <String>{};
  int _currentPage = 0;
  int _pageSize = 40;
  List<FinanzasBankMovementRecord> _rows = const <FinanzasBankMovementRecord>[];
  List<FinanzasEvidenceRecord> _movementEvidences =
      const <FinanzasEvidenceRecord>[];
  List<FinanzasCatalogCompanyRecord> _companies =
      const <FinanzasCatalogCompanyRecord>[];
  List<FinanzasCatalogConceptRecord> _concepts =
      const <FinanzasCatalogConceptRecord>[];
  List<FinanzasSupplierInvoiceRecord> _supplierInvoices =
      const <FinanzasSupplierInvoiceRecord>[];
  List<FinanzasClientPaymentAccountRecord> _clientAccounts =
      const <FinanzasClientPaymentAccountRecord>[];
  List<FinanzasFixedPaymentRecord> _fixedPayments =
      const <FinanzasFixedPaymentRecord>[];

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
      FinanzasBankAccountsStore.loadMovements(),
      FinanzasDataStore.loadCatalogSnapshot(),
      FinanzasProviderAccountsStore.loadInvoices(),
      FinanzasBankAccountsStore.loadOpenClientAccounts(),
      FinanzasBankAccountsStore.loadOpenFixedPayments(),
      FinanzasEvidenceStore.loadByOwnerType(
        kFinanzasEvidenceOwnerTypeBankMovement,
      ),
    ]);
    if (!mounted) return;
    final movements = results[0] as List<FinanzasBankMovementRecord>;
    final snapshot = results[1] as FinanzasCatalogSnapshot;
    final invoices = results[2] as List<FinanzasSupplierInvoiceRecord>;
    final clientAccounts =
        results[3] as List<FinanzasClientPaymentAccountRecord>;
    final fixedPayments = results[4] as List<FinanzasFixedPaymentRecord>;
    final movementEvidences = results[5] as List<FinanzasEvidenceRecord>;
    setState(() {
      _rows = movements;
      _movementEvidences = movementEvidences;
      _companies = snapshot.companies
          .where((row) => row.active)
          .toList(growable: false);
      _concepts = snapshot.concepts
          .where((row) => row.active)
          .toList(growable: false);
      _supplierInvoices = invoices
          .where((row) => row.status != 'PAGADA')
          .toList(growable: false);
      _clientAccounts = clientAccounts;
      _fixedPayments = fixedPayments;
      _syncSelectionWithVisibleRows();
      _syncPageToSelectedRow();
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_gridRows.isNotEmpty) {
        if (_selectedRowId == null) {
          final firstRow = _gridRows.first;
          _gridSelectionController.selectSingle(firstRow.id, rowIndex: 0);
          _syncSelectionFromController(preferredRowId: firstRow.id);
        }
      }
      _requestGridFocus();
    });
    await _maybeHandleLaunchPreset();
  }

  Future<void> _maybeHandleLaunchPreset() async {
    if (_handledLaunchPreset || widget.launchPreset == null || !mounted) {
      return;
    }
    _handledLaunchPreset = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_openNewMovementDialog(preset: widget.launchPreset));
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<FinanzasBankMovementRecord> get _visibleRows {
    return _filteredRows;
  }

  List<FinanzasBankMovementRecord> get _gridRows {
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

  List<FinanzasBankMovementRecord> get _filteredRows {
    return _rows
        .where((row) {
          if (_dateRangeFilter != null &&
              !_matchesDateRange(row.date, _dateRangeFilter!)) {
            return false;
          }
          if (_companyFilters.isNotEmpty &&
              !_companyFilters.contains(row.company)) {
            return false;
          }
          if (_branchFilters.isNotEmpty &&
              !_branchFilters.contains(row.branch)) {
            return false;
          }
          if (_nameFilters.isNotEmpty &&
              !_nameFilters.contains(row.counterpartyNameSnapshot)) {
            return false;
          }
          if (_categoryFilters.isNotEmpty &&
              !_categoryFilters.contains(row.category)) {
            return false;
          }
          if (_referenceFilters.isNotEmpty &&
              !_referenceFilters.contains(row.reference)) {
            return false;
          }
          if (_creditFilters.isNotEmpty &&
              !_creditFilters.contains(row.creditAmount.toStringAsFixed(2))) {
            return false;
          }
          if (_debitFilters.isNotEmpty &&
              !_debitFilters.contains(row.debitAmount.toStringAsFixed(2))) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
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

  Future<void> _openPaymentCenter() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasPaymentCenterPage(instantOpen: true)),
    );
  }

  Future<void> _openFixedPayments() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasFixedPaymentsPage(instantOpen: true)),
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
      case 'Centro de pagos':
        unawaited(_openPaymentCenter());
        return;
      case 'Pagos fijos':
        unawaited(_openFixedPayments());
        return;
      case 'Dashboard Compras':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openComprasDashboard());
        return;
      case 'Cuentas Bancarias':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
    }
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

  Future<void> _pickCompanyFilter() async {
    final selected = await _showGridMultiFilterDialog(
      title: 'Filtrar empresa',
      selectedValues: _companyFilters,
      options: _sortedDistinct(_rows.map((row) => row.company))
          .map((value) => _SimpleOption(id: value, label: value, subtitle: ''))
          .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _companyFilters = selected;
      _syncSelectionWithVisibleRows();
      _syncPageToSelectedRow();
    });
    _requestGridFocus();
  }

  Future<void> _pickDateFilter() async {
    final availableDates =
        _rows.map((row) => DateUtils.dateOnly(row.date)).toSet().toList()
          ..sort();
    final picked = await _showFinBankDateRangeDialog(
      context,
      initialRange: _dateRangeFilter,
      firstDate: availableDates.isNotEmpty
          ? availableDates.first
          : DateTime(2024),
      lastDate: availableDates.isNotEmpty
          ? availableDates.last
          : DateTime(2035),
    );
    if (picked == null || !mounted) return;
    if (picked == _kClearedBankDateRange) {
      setState(() {
        _dateRangeFilter = null;
        _syncSelectionWithVisibleRows();
        _syncPageToSelectedRow();
      });
      _requestGridFocus();
      return;
    }
    setState(() {
      _dateRangeFilter = picked;
      _syncSelectionWithVisibleRows();
      _syncPageToSelectedRow();
    });
    _requestGridFocus();
  }

  Future<void> _pickBranchFilter() async {
    final selected = await _showGridMultiFilterDialog(
      title: 'Filtrar cuenta',
      selectedValues: _branchFilters,
      options: _sortedDistinct(_rows.map((row) => row.branch))
          .map((value) => _SimpleOption(id: value, label: value, subtitle: ''))
          .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _branchFilters = selected;
      _syncSelectionWithVisibleRows();
      _syncPageToSelectedRow();
    });
    _requestGridFocus();
  }

  Future<void> _pickNameFilter() async {
    final selected = await _showGridMultiFilterDialog(
      title: 'Filtrar nombre',
      selectedValues: _nameFilters,
      options: _sortedDistinct(_rows.map((row) => row.counterpartyNameSnapshot))
          .map((value) => _SimpleOption(id: value, label: value, subtitle: ''))
          .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _nameFilters = selected;
      _syncSelectionWithVisibleRows();
      _syncPageToSelectedRow();
    });
    _requestGridFocus();
  }

  Future<void> _pickCategoryFilter() async {
    final selected = await _showGridMultiFilterDialog(
      title: 'Filtrar categoría',
      selectedValues: _categoryFilters,
      options: _sortedDistinct(_rows.map((row) => row.category))
          .map((value) => _SimpleOption(id: value, label: value, subtitle: ''))
          .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _categoryFilters = selected;
      _syncSelectionWithVisibleRows();
      _syncPageToSelectedRow();
    });
    _requestGridFocus();
  }

  Future<void> _pickReferenceFilter() async {
    final selected = await _showGridMultiFilterDialog(
      title: 'Filtrar referencia',
      selectedValues: _referenceFilters,
      options: _sortedDistinct(_rows.map((row) => row.reference))
          .map((value) => _SimpleOption(id: value, label: value, subtitle: ''))
          .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _referenceFilters = selected;
      _syncSelectionWithVisibleRows();
      _syncPageToSelectedRow();
    });
    _requestGridFocus();
  }

  Future<void> _pickCreditFilter() async {
    final selected = await _showGridMultiFilterDialog(
      title: 'Filtrar abono',
      selectedValues: _creditFilters,
      options:
          _sortedDistinct(
                _rows.map((row) => row.creditAmount.toStringAsFixed(2)),
              )
              .map(
                (value) => _SimpleOption(
                  id: value,
                  label: _money(double.tryParse(value) ?? 0),
                  subtitle: '',
                ),
              )
              .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _creditFilters = selected;
      _syncSelectionWithVisibleRows();
      _syncPageToSelectedRow();
    });
    _requestGridFocus();
  }

  Future<void> _pickDebitFilter() async {
    final selected = await _showGridMultiFilterDialog(
      title: 'Filtrar cargo',
      selectedValues: _debitFilters,
      options:
          _sortedDistinct(
                _rows.map((row) => row.debitAmount.toStringAsFixed(2)),
              )
              .map(
                (value) => _SimpleOption(
                  id: value,
                  label: _money(double.tryParse(value) ?? 0),
                  subtitle: '',
                ),
              )
              .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _debitFilters = selected;
      _syncSelectionWithVisibleRows();
      _syncPageToSelectedRow();
    });
    _requestGridFocus();
  }

  Future<void> _openNewMovementDialog({
    FinanzasBankMovementLaunchPreset? preset,
  }) async {
    final draft = await showDialog<_BankMovementDraft>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _NewBankMovementDialog(
        companies: _companies,
        supplierInvoices: _supplierInvoices,
        clientAccounts: _clientAccounts,
        fixedPayments: _fixedPayments,
        availableCompanies: _bankAccountCompanies,
        availableBranches: _bankAccountBranches,
        availableCategories: _bankCategoryOptions,
        launchPreset: preset,
      ),
    );
    if (draft == null) return;
    await _saveDraft(draft);
  }

  Future<void> _openEditMovementDialog(FinanzasBankMovementRecord row) async {
    final draft = await showDialog<_BankMovementDraft>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _NewBankMovementDialog(
        companies: _companies,
        supplierInvoices: _supplierInvoices,
        clientAccounts: _clientAccounts,
        fixedPayments: _fixedPayments,
        availableCompanies: _bankAccountCompanies,
        availableBranches: _bankAccountBranches,
        availableCategories: _bankCategoryOptions,
        existingRow: row,
        evidences: _evidencesForMovement(row.id),
        onOpenEvidence: _openEvidenceFile,
        onUploadEvidence: () => _addMovementEvidence(row),
      ),
    );
    if (draft == null) return;
    await _saveDraft(draft, existingRow: row);
  }

  Future<void> _saveDraft(
    _BankMovementDraft draft, {
    FinanzasBankMovementRecord? existingRow,
  }) async {
    final movement = FinanzasBankMovementRecord(
      id:
          existingRow?.id ??
          'fin-bank-mov-${DateTime.now().microsecondsSinceEpoch}',
      date: draft.date,
      company: draft.company,
      branch: draft.branch,
      accountKey: buildFinBankAccountKey(
        company: draft.company,
        branch: draft.branch,
      ),
      counterpartyCompanyId: draft.counterpartyCompanyId,
      counterpartyNameSnapshot: draft.counterpartyName,
      category: draft.category,
      comment: draft.comment,
      reference: draft.reference,
      creditAmount: draft.creditAmount,
      debitAmount: draft.debitAmount,
      sourceType: draft.sourceType,
      linkedSupplierInvoiceId:
          draft.linkedSupplierInvoice?.id ??
          existingRow?.linkedSupplierInvoiceId,
      linkedFixedPaymentId:
          draft.linkedFixedPayment?.id ?? existingRow?.linkedFixedPaymentId,
      linkedExternalRef:
          draft.linkedClientAccount?.id ?? existingRow?.linkedExternalRef,
      createdAt: existingRow?.createdAt,
      updatedAt: null,
    );
    try {
      if (existingRow != null) {
        await FinanzasBankAccountsStore.saveMovement(movement);
      } else {
        await FinanzasBankAccountsStore.createMovementAndApply(
          movement: movement,
          linkedSupplierInvoice: draft.linkedSupplierInvoice,
          linkedClientAccount: draft.linkedClientAccount,
          linkedFixedPayment: draft.linkedFixedPayment,
        );
      }
      if (!mounted) return;
      _toast(
        existingRow == null
            ? 'Movimiento guardado.'
            : 'Movimiento actualizado.',
      );
      await _loadPage();
    } catch (error) {
      if (!mounted) return;
      _toast(
        existingRow == null
            ? 'No se pudo guardar el movimiento. $error'
            : 'No se pudo actualizar el movimiento. $error',
      );
    }
  }

  Future<void> _exportCsv() async {
    if (_exportingCsv) return;
    setState(() => _exportingCsv = true);
    try {
      final rows = <List<Object?>>[
        const [
          'Fecha',
          'Empresa',
          'Cuenta',
          'Nombre',
          'Categoria',
          'Comentario',
          'Referencia',
          'Abono',
          'Cargo',
        ],
        for (final row in _visibleRows)
          [
            _dateLabel(row.date),
            row.company,
            row.branch,
            row.counterpartyNameSnapshot,
            row.category,
            row.comment,
            row.reference,
            row.creditAmount.toStringAsFixed(2),
            row.debitAmount.toStringAsFixed(2),
          ],
      ];
      final csv = _rowsToCsv(rows);
      final path = await saveCsvFile(
        fileName:
            'cuentas_bancarias_${DateTime.now().toIso8601String().substring(0, 10)}.csv',
        content: csv,
        dialogTitle: 'Guardar movimientos bancarios',
      );
      if (!mounted) return;
      if (path == null) {
        _toast('Exportación cancelada.');
      } else {
        _toast('CSV guardado en $path');
      }
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo exportar CSV. $error');
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  String _rowsToCsv(List<List<Object?>> rows) {
    return rows
        .map(
          (row) => row
              .map((cell) {
                final value = (cell ?? '').toString();
                final escaped = value.replaceAll('"', '""');
                if (escaped.contains(',') ||
                    escaped.contains('"') ||
                    escaped.contains('\n')) {
                  return '"$escaped"';
                }
                return escaped;
              })
              .join(','),
        )
        .join('\n');
  }

  void _requestGridFocus({bool preserveSelectedRow = true}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_gridRows.isNotEmpty) {
        final targetRowId = preserveSelectedRow ? _selectedRowId : null;
        final targetIndex = targetRowId == null
            ? 0
            : _gridRows.indexWhere((row) => row.id == targetRowId);
        _gridNavigationController.focusGridCell(
          rowIndex: targetIndex >= 0 ? targetIndex : 0,
          columnIndex: 0,
        );
      }
      _rowsFocusNode.requestFocus();
    });
  }

  void _syncSelectionFromController({String? preferredRowId}) {
    final visibleRows = _visibleRows;
    final nextSelectedIds = _gridSelectionController.selectedIds.intersection(
      visibleRows.map((row) => row.id).toSet(),
    );
    String? nextSelectedRowId;
    if (preferredRowId != null && nextSelectedIds.contains(preferredRowId)) {
      nextSelectedRowId = preferredRowId;
    } else if (_selectedRowId != null &&
        nextSelectedIds.contains(_selectedRowId)) {
      nextSelectedRowId = _selectedRowId;
    } else if (nextSelectedIds.isNotEmpty) {
      nextSelectedRowId = visibleRows
          .firstWhere((row) => nextSelectedIds.contains(row.id))
          .id;
    }
    final anchorIndex = _gridSelectionController.anchorIndex;
    final nextAnchorRowId =
        anchorIndex != null &&
            anchorIndex >= 0 &&
            anchorIndex < visibleRows.length
        ? visibleRows[anchorIndex].id
        : nextSelectedRowId;
    setState(() {
      _selectedRowId = nextSelectedRowId;
      _selectedRowIds = nextSelectedIds;
      _selectionAnchorRowId = nextAnchorRowId;
    });
  }

  void _handleRowTap(String rowId, int rowIndex) {
    if (_suppressNextRowTap) {
      setState(() {
        _suppressNextRowTap = false;
        _dragSelectionMoved = false;
        _pointerDownAdditiveSelection = false;
      });
      return;
    }
    if (_pointerDownAdditiveSelection) {
      _gridSelectionController.toggle(rowId, rowIndex: rowIndex);
      _gridNavigationController.focusGridCell(
        rowIndex: rowIndex,
        columnIndex: 0,
      );
      _syncSelectionFromController(preferredRowId: rowId);
      setState(() {
        _pointerDownAdditiveSelection = false;
        _dragSelectionMoved = false;
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
    _gridNavigationController.focusGridCell(rowIndex: rowIndex, columnIndex: 0);
    _syncSelectionFromController(preferredRowId: rowId);
    setState(() => _dragSelectionMoved = false);
    _rowsFocusNode.requestFocus();
  }

  void _clearRowSelection() {
    if (_selectedRowId == null && _selectedRowIds.isEmpty) return;
    _gridSelectionController.clear();
    setState(() {
      _selectedRowId = null;
      _selectedRowIds = <String>{};
      _selectionAnchorRowId = null;
    });
  }

  FinanzasBankMovementRecord? get _selectedRow {
    final id = _selectedRowId;
    if (id == null) return null;
    for (final row in _visibleRows) {
      if (row.id == id) return row;
    }
    return null;
  }

  void _syncSelectionWithVisibleRows() {
    final visibleIds = _visibleRows.map((row) => row.id).toSet();
    _selectedRowIds = _selectedRowIds.intersection(visibleIds);
    _gridSelectionController.selectedIds
      ..clear()
      ..addAll(_selectedRowIds);
    final id = _selectedRowId;
    if (id != null && !visibleIds.contains(id)) {
      _selectedRowId = _selectedRowIds.isEmpty ? null : _selectedRowIds.first;
    }
    final anchor = _selectionAnchorRowId;
    if (anchor != null && !visibleIds.contains(anchor)) {
      _selectionAnchorRowId = _selectedRowId;
    }
    _clampCurrentPage();
    _syncPageToSelectedRow();
    final anchorIndex = _selectionAnchorRowId == null
        ? -1
        : _gridRows.indexWhere((row) => row.id == _selectionAnchorRowId);
    _gridSelectionController.anchorIndex = anchorIndex >= 0
        ? anchorIndex
        : null;
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
      _pointerDownAdditiveSelection = additive;
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
    if (rowIndex >= 0) {
      _gridVisibilityCoordinator.ensureGridRowVisible(rowIndex);
      _gridNavigationController.focusGridCell(
        rowIndex: rowIndex,
        columnIndex: 0,
      );
    }
  }

  void _endDragSelection() {
    if (!_dragSelectionActive) return;
    setState(() {
      _dragSelectionActive = false;
      _dragSelectionAdditive = false;
      _suppressNextRowTap = _dragSelectionMoved;
      if (_dragSelectionMoved) {
        _pointerDownAdditiveSelection = false;
      }
    });
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

  void _openSelectedRowForEdit() {
    final activePosition = _gridNavigationController.active;
    FinanzasBankMovementRecord? row;
    if (activePosition.zone == GridNavigationZone.grid &&
        activePosition.rowIndex >= 0 &&
        activePosition.rowIndex < _gridRows.length) {
      row = _gridRows[activePosition.rowIndex];
      _gridSelectionController.selectSingle(
        row.id,
        rowIndex: activePosition.rowIndex,
      );
      _syncSelectionFromController(preferredRowId: row.id);
    } else {
      row = _selectedRow;
    }
    if (row != null) {
      unawaited(_openEditMovementDialog(row));
    }
  }

  Future<void> _deleteSelectedRows() async {
    final selected = _visibleRows
        .where((row) => _selectedRowIds.contains(row.id))
        .toList(growable: false);
    if (selected.isEmpty) return;
    final selectedCount = selected.length;
    final sourceTypes = selected.map((row) => row.sourceType).toSet().toList()
      ..sort();
    final content =
        'Se eliminarán $selectedCount movimiento(s) seleccionado(s), incluyendo registros de origen ${sourceTypes.join(', ')}. '
        'Si alguno está ligado a facturas proveedor, pagos fijos o ventas, el sistema revertirá esos vínculos antes de borrar el asiento. '
        'Esta acción no se puede deshacer.';
    final confirmed = await showContractConfirmationDialog(
      context,
      title: 'Eliminar movimientos',
      content: content,
      confirmText: 'Eliminar',
      destructive: true,
      tokens: finanzasAreaTokens,
    );
    if (confirmed != true || !mounted) return;
    for (final row in selected) {
      await FinanzasBankAccountsStore.deleteMovementAndReverse(row);
    }
    _toast('${selected.length} movimiento(s) eliminado(s).');
    await _loadPage();
  }

  Future<void> _deleteSingleRow(FinanzasBankMovementRecord row) async {
    final targetLabel = row.counterpartyNameSnapshot.trim().isEmpty
        ? '${row.company} ${row.branch}'
        : row.counterpartyNameSnapshot;
    final confirmed = await showContractConfirmationDialog(
      context,
      title: 'Eliminar movimiento',
      content:
          'Se eliminará el movimiento de $targetLabel con origen ${_bankSourceTypeLabel(row.sourceType)}. '
          'Si está ligado a facturas proveedor, pagos fijos o ventas, el sistema revertirá esos vínculos antes de borrar el asiento. '
          'Esta acción no se puede deshacer.',
      confirmText: 'Eliminar',
      destructive: true,
      tokens: finanzasAreaTokens,
    );
    if (confirmed != true || !mounted) return;
    await FinanzasBankAccountsStore.deleteMovementAndReverse(row);
    _toast('Movimiento eliminado.');
    await _loadPage();
  }

  List<FinanzasEvidenceRecord> _evidencesForMovement(String movementId) =>
      _movementEvidences
          .where((row) => row.ownerId == movementId)
          .toList(growable: false);

  Future<FinanzasEvidenceRecord?> _addMovementEvidence(
    FinanzasBankMovementRecord row,
  ) async {
    final uploaded = await _pickAndUploadEvidence(
      ownerType: kFinanzasEvidenceOwnerTypeBankMovement,
      ownerId: row.id,
      title: 'Subir evidencia del movimiento',
    );
    if (uploaded == null || !mounted) return uploaded;
    _toast('Evidencia subida.');
    await _loadPage();
    return uploaded;
  }

  Future<FinanzasEvidenceRecord?> _pickAndUploadEvidence({
    required String ownerType,
    required String ownerId,
    required String title,
  }) async {
    PlatformFile? picked;
    final commentC = TextEditingController();
    try {
      final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setLocalState) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 26,
                ),
                child: AreaThemeScope(
                  tokens: finanzasAreaTokens,
                  child: FinanzasGlassPanel(
                    borderRadius: BorderRadius.circular(28),
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                    fillColor: const Color(0x1813171F),
                    borderColor: Colors.white.withValues(alpha: 0.22),
                    edgeHighlightColor: Colors.white.withValues(alpha: 0.18),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
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
                                      title,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: kFinanzasInk,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Adjunta PDF o imagen para respaldar este movimiento.',
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
                                width: 46,
                                height: 46,
                                padding: EdgeInsets.zero,
                                borderRadius: BorderRadius.circular(999),
                                fillColor: const Color(0x14161B23),
                                borderColor: Colors.white.withValues(
                                  alpha: 0.18,
                                ),
                                child: IconButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: Colors.white.withValues(alpha: 0.88),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final result = await FilePicker.platform
                                    .pickFiles(
                                      allowMultiple: false,
                                      withData: true,
                                      lockParentWindow: true,
                                      type: FileType.custom,
                                      allowedExtensions: const [
                                        'pdf',
                                        'jpg',
                                        'jpeg',
                                        'png',
                                        'webp',
                                        'heic',
                                      ],
                                    );
                                if (result == null || result.files.isEmpty) {
                                  return;
                                }
                                setLocalState(
                                  () => picked = result.files.first,
                                );
                              } catch (error) {
                                _toast(
                                  'No se pudo abrir selector de archivos. $error',
                                );
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: finanzasAreaTokens.primaryStrong,
                              side: BorderSide(
                                color: finanzasAreaTokens.primaryStrong
                                    .withValues(alpha: 0.32),
                              ),
                              minimumSize: const Size.fromHeight(52),
                            ),
                            icon: const Icon(Icons.attach_file_rounded),
                            label: Text(
                              picked == null
                                  ? 'Seleccionar PDF o foto'
                                  : 'Archivo: ${picked!.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: commentC,
                            minLines: 2,
                            maxLines: 3,
                            style: const TextStyle(
                              color: kFinanzasInk,
                              fontWeight: FontWeight.w700,
                            ),
                            cursorColor: finanzasAreaTokens.primaryStrong,
                            decoration: _bankDialogFieldDecoration(
                              context,
                              hintText: 'Comentario de la evidencia',
                              prefixIcon: const Icon(Icons.note_alt_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      finanzasAreaTokens.primaryStrong,
                                  side: BorderSide(
                                    color: finanzasAreaTokens.primaryStrong
                                        .withValues(alpha: 0.32),
                                  ),
                                ),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 10),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      finanzasAreaTokens.primaryStrong,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                child: const Text('Guardar'),
                              ),
                            ],
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
      if (save != true || picked == null) return null;
      return await FinanzasEvidenceStore.createUploadedEvidence(
        ownerType: ownerType,
        ownerId: ownerId,
        file: picked!,
        comment: commentC.text.trim(),
      );
    } catch (error) {
      if (mounted) {
        _toast('No se pudo subir evidencia. $error');
      }
      return null;
    } finally {
      commentC.dispose();
    }
  }

  Future<void> _openEvidenceFile(String url, String fileName) async {
    try {
      final path = await saveRemoteFileAs(
        url: url,
        suggestedFileName: fileName,
        dialogTitle: 'Descargar evidencia',
      );
      if (!mounted) return;
      if (path == null) {
        _toast('Descarga cancelada.');
      } else {
        _toast('Evidencia guardada en $path');
      }
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo descargar la evidencia. $error');
    }
  }

  String _money(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts.first;
    final fraction = parts[1];
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final reverseIndex = whole.length - i;
      buffer.write(whole[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }
    return '\$${buffer.toString()}.$fraction';
  }

  String _dateLabel(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  Map<String, _BankAccountTotals> get _accountTotals {
    final totals = <String, _BankAccountTotals>{};
    for (final row in _visibleRows) {
      final key = row.accountKey;
      final current =
          totals[key] ?? _BankAccountTotals.empty(row.company, row.branch);
      totals[key] = current.add(
        credit: row.creditAmount,
        debit: row.debitAmount,
      );
    }
    for (final company in _bankAccountCompanies) {
      for (final branch in _bankAccountBranches) {
        final key = buildFinBankAccountKey(company: company, branch: branch);
        totals.putIfAbsent(
          key,
          () => _BankAccountTotals.empty(company, branch),
        );
      }
    }
    return totals;
  }

  List<String> get _bankAccountCompanies {
    final values = <String>{
      ...kFinBankCompanies,
      for (final row in _rows) row.company,
      for (final row in _supplierInvoices) row.targetCompany,
      if (_selectedRow case final row?) row.company,
    }..removeWhere((value) => value.trim().isEmpty);
    final list = values.toList()..sort();
    return list;
  }

  List<String> get _bankAccountBranches {
    final values = <String>{
      ...kFinBankBranches,
      for (final row in _rows) row.branch,
      if (_selectedRow case final row?) row.branch,
      for (final row in _supplierInvoices) row.targetBranch,
      for (final row in _fixedPayments) row.branch,
    }..removeWhere((value) => value.trim().isEmpty);
    final list = values.toList()..sort();
    return list;
  }

  List<String> get _bankCategoryOptions {
    final values = <String>{
      ...kFinBankCategories,
      for (final row in _concepts) row.name,
      for (final row in _rows) row.category,
      if (_selectedRow case final row?) row.category,
    }..removeWhere((value) => value.trim().isEmpty);
    final list = values.toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
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
          background: const _FinBankBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => _FinBankHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => const _FinBankHeaderBrand(),
          trailingBuilder: (_, _) => _FinBankHeaderButton(
            label: 'Cerrar sesión',
            icon: Icons.logout_rounded,
            onTap: _logout,
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1520),
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
                              Padding(
                                padding: const EdgeInsets.fromLTRB(2, 2, 2, 12),
                                child: _BankTopBar(
                                  exportingCsv: _exportingCsv,
                                  selectedCount: _selectedRowIds.length,
                                  onExportCsv: _exportingCsv
                                      ? null
                                      : _exportCsv,
                                  onCreate: _openNewMovementDialog,
                                ),
                              ),
                              _BankAccountsTotalsRow(
                                totals: _accountTotals.values.toList(
                                  growable: false,
                                ),
                                moneyFormatter: _money,
                              ),
                              const SizedBox(height: 14),
                              Expanded(
                                child: _BankTabSurface(
                                  child: Column(
                                    children: [
                                      _BankFilterSummaryRow(
                                        labels: [
                                          if (_dateRangeFilter != null)
                                            'Fecha: ${_dateRangeLabel(_dateRangeFilter!)}',
                                          for (final value in _companyFilters)
                                            'Empresa: $value',
                                          for (final value in _branchFilters)
                                            'Cuenta: $value',
                                          for (final value in _nameFilters)
                                            'Nombre: $value',
                                          for (final value in _categoryFilters)
                                            'Categoría: $value',
                                          for (final value in _referenceFilters)
                                            'Referencia: $value',
                                          for (final value in _creditFilters)
                                            'Abono: ${_money(double.tryParse(value) ?? 0)}',
                                          for (final value in _debitFilters)
                                            'Cargo: ${_money(double.tryParse(value) ?? 0)}',
                                        ],
                                        onClearAll:
                                            _dateRangeFilter == null &&
                                                _companyFilters.isEmpty &&
                                                _branchFilters.isEmpty &&
                                                _nameFilters.isEmpty &&
                                                _categoryFilters.isEmpty &&
                                                _referenceFilters.isEmpty &&
                                                _creditFilters.isEmpty &&
                                                _debitFilters.isEmpty
                                            ? null
                                            : () => setState(() {
                                                _dateRangeFilter = null;
                                                _companyFilters = <String>{};
                                                _branchFilters = <String>{};
                                                _nameFilters = <String>{};
                                                _categoryFilters = <String>{};
                                                _referenceFilters = <String>{};
                                                _creditFilters = <String>{};
                                                _debitFilters = <String>{};
                                                _syncSelectionWithVisibleRows();
                                                _syncPageToSelectedRow();
                                              }),
                                      ),
                                      const SizedBox(height: 10),
                                      _BankHeaderRow(
                                        onDateFilter: _pickDateFilter,
                                        onCompanyFilter: _pickCompanyFilter,
                                        onBranchFilter: _pickBranchFilter,
                                        onNameFilter: _pickNameFilter,
                                        onCategoryFilter: _pickCategoryFilter,
                                        onReferenceFilter: _pickReferenceFilter,
                                        onCreditFilter: _pickCreditFilter,
                                        onDebitFilter: _pickDebitFilter,
                                        dateFilterActive:
                                            _dateRangeFilter != null,
                                        companyFilterActive:
                                            _companyFilters.isNotEmpty,
                                        branchFilterActive:
                                            _branchFilters.isNotEmpty,
                                        nameFilterActive:
                                            _nameFilters.isNotEmpty,
                                        categoryFilterActive:
                                            _categoryFilters.isNotEmpty,
                                        referenceFilterActive:
                                            _referenceFilters.isNotEmpty,
                                        creditFilterActive:
                                            _creditFilters.isNotEmpty,
                                        debitFilterActive:
                                            _debitFilters.isNotEmpty,
                                      ),
                                      const SizedBox(height: 10),
                                      Expanded(
                                        child: GridKeyboardShell(
                                          focusNode: _rowsFocusNode,
                                          navigationController:
                                              _gridNavigationController,
                                          onEscape: _clearRowSelection,
                                          onConfirm: _openSelectedRowForEdit,
                                          onDelete: _deleteSelectedRows,
                                          onNavigated: _handleGridNavigation,
                                          child: _visibleRows.isEmpty
                                              ? const _FinBankEmptyPane()
                                              : _gridRows.isEmpty
                                              ? const _FinBankEmptyPane()
                                              : _BankMovementsGrid(
                                                  rows: _gridRows,
                                                  selectedRowId: _selectedRowId,
                                                  selectedRowIds:
                                                      _selectedRowIds,
                                                  activeRowId: _selectedRowId,
                                                  dragSelectionActive:
                                                      _dragSelectionActive,
                                                  moneyFormatter: _money,
                                                  dateFormatter: _dateLabel,
                                                  visibilityCoordinator:
                                                      _gridVisibilityCoordinator,
                                                  onRowTap: _handleRowTap,
                                                  onDragStart:
                                                      _beginDragSelection,
                                                  onDragEnter:
                                                      _extendDragSelection,
                                                  onDragEnd: _endDragSelection,
                                                  onDelete: _deleteSingleRow,
                                                  onPrepareMenuSelection:
                                                      (rowId, rowIndex) =>
                                                          _handleRowTap(
                                                            rowId,
                                                            rowIndex,
                                                          ),
                                                  onEdit:
                                                      _openEditMovementDialog,
                                                  onUploadEvidence:
                                                      _addMovementEvidence,
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
                      child: _FinBankSidePanel(
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

class _BankMovementsGrid extends StatelessWidget {
  final List<FinanzasBankMovementRecord> rows;
  final String? selectedRowId;
  final Set<String> selectedRowIds;
  final String? activeRowId;
  final bool dragSelectionActive;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime value) dateFormatter;
  final void Function(String rowId, int rowIndex) onRowTap;
  final void Function(String rowId, {required bool additive}) onDragStart;
  final ValueChanged<String> onDragEnter;
  final VoidCallback onDragEnd;
  final ValueChanged<FinanzasBankMovementRecord> onEdit;
  final ValueChanged<FinanzasBankMovementRecord> onDelete;
  final void Function(String rowId, int rowIndex) onPrepareMenuSelection;
  final ValueChanged<FinanzasBankMovementRecord> onUploadEvidence;
  final GridScrollVisibilityCoordinator visibilityCoordinator;

  const _BankMovementsGrid({
    required this.rows,
    required this.selectedRowId,
    required this.selectedRowIds,
    required this.activeRowId,
    required this.dragSelectionActive,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onRowTap,
    required this.onDragStart,
    required this.onDragEnter,
    required this.onDragEnd,
    required this.onEdit,
    required this.onDelete,
    required this.onPrepareMenuSelection,
    required this.onUploadEvidence,
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
          child: _BankTableRow(
            rowKey: row.id,
            selected: selectedRowIds.contains(row.id),
            active: activeRowId == row.id,
            dragSelectionActive: dragSelectionActive,
            onTap: () => onRowTap(row.id, index),
            onDragStart: (additive) => onDragStart(row.id, additive: additive),
            onDragEnter: () => onDragEnter(row.id),
            onDragEnd: onDragEnd,
            onDoubleTap: () => onEdit(row),
            onPrepareMenuSelection: () => onPrepareMenuSelection(row.id, index),
            menuItems: [
              if (row.sourceType == 'MANUAL')
                _BankRowMenuAction(
                  label: 'EDITAR',
                  icon: Icons.edit_outlined,
                  onTap: () => onEdit(row),
                ),
              _BankRowMenuAction(
                label: 'SUBIR EVIDENCIA',
                icon: Icons.attach_file_rounded,
                onTap: () => onUploadEvidence(row),
              ),
              _BankRowMenuAction(
                label: 'ELIMINAR',
                icon: Icons.delete_outline_rounded,
                onTap: () => onDelete(row),
              ),
            ],
            editableColumns: const <int>{2, 3, 4, 5, 6},
            cells: [
              _BankTableCell.text(
                width: _kBankDateW,
                text: dateFormatter(row.date),
              ),
              _BankTableCell.text(
                width: _kBankCompanyW,
                text: row.company,
                bold: true,
              ),
              _BankTableCell.text(width: _kBankBranchW, text: row.branch),
              _BankTableCell.text(
                width: _kBankNameW,
                text: row.counterpartyNameSnapshot,
              ),
              _BankTableCell.text(width: _kBankCategoryW, text: row.category),
              _BankTableCell.text(width: _kBankCommentW, text: row.comment),
              _BankTableCell.text(width: _kBankReferenceW, text: row.reference),
              _BankTableCell.money(
                width: _kBankCreditW,
                text: row.creditAmount > 0
                    ? moneyFormatter(row.creditAmount)
                    : '',
                positive: true,
                selectedContext: selectedRowIds.contains(row.id),
              ),
              _BankTableCell.money(
                width: _kBankDebitW,
                text: row.debitAmount > 0
                    ? moneyFormatter(row.debitAmount)
                    : '',
                positive: false,
                selectedContext: selectedRowIds.contains(row.id),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BankMovementDraft {
  final DateTime date;
  final String company;
  final String branch;
  final String? counterpartyCompanyId;
  final String counterpartyName;
  final String category;
  final String comment;
  final String reference;
  final double creditAmount;
  final double debitAmount;
  final String sourceType;
  final FinanzasSupplierInvoiceRecord? linkedSupplierInvoice;
  final FinanzasClientPaymentAccountRecord? linkedClientAccount;
  final FinanzasFixedPaymentRecord? linkedFixedPayment;

  const _BankMovementDraft({
    required this.date,
    required this.company,
    required this.branch,
    required this.counterpartyCompanyId,
    required this.counterpartyName,
    required this.category,
    required this.comment,
    required this.reference,
    required this.creditAmount,
    required this.debitAmount,
    required this.sourceType,
    required this.linkedSupplierInvoice,
    required this.linkedClientAccount,
    required this.linkedFixedPayment,
  });
}

class _NewBankMovementDialog extends StatefulWidget {
  final List<FinanzasCatalogCompanyRecord> companies;
  final List<FinanzasSupplierInvoiceRecord> supplierInvoices;
  final List<FinanzasClientPaymentAccountRecord> clientAccounts;
  final List<FinanzasFixedPaymentRecord> fixedPayments;
  final List<String> availableCompanies;
  final List<String> availableBranches;
  final List<String> availableCategories;
  final List<FinanzasEvidenceRecord> evidences;
  final Future<void> Function(String url, String fileName)? onOpenEvidence;
  final Future<FinanzasEvidenceRecord?> Function()? onUploadEvidence;
  final FinanzasBankMovementRecord? existingRow;
  final FinanzasBankMovementLaunchPreset? launchPreset;

  const _NewBankMovementDialog({
    required this.companies,
    required this.supplierInvoices,
    required this.clientAccounts,
    required this.fixedPayments,
    required this.availableCompanies,
    required this.availableBranches,
    required this.availableCategories,
    this.evidences = const <FinanzasEvidenceRecord>[],
    this.onOpenEvidence,
    this.onUploadEvidence,
    this.existingRow,
    this.launchPreset,
  });

  @override
  State<_NewBankMovementDialog> createState() => _NewBankMovementDialogState();
}

class _NewBankMovementDialogState extends State<_NewBankMovementDialog> {
  late final TextEditingController _commentC;
  late final TextEditingController _referenceC;
  late final TextEditingController _creditC;
  late final TextEditingController _debitC;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  String _sourceType = 'MANUAL';
  String _company = 'DICSA';
  String _branch = 'CELAYA';
  String? _counterpartyCompanyId;
  String _counterpartyName = '';
  String _category = 'OTROS';
  String? _selectedSupplierInvoiceId;
  String? _selectedClientAccountId;
  String? _selectedFixedPaymentId;
  late List<FinanzasEvidenceRecord> _evidences;

  String _resolvePreferredCategory(String fallback) {
    if (_categoryOptions.contains(fallback)) return fallback;
    final normalizedFallback = fallback.trim().toUpperCase();
    for (final option in _categoryOptions) {
      if (option.trim().toUpperCase() == normalizedFallback) return option;
    }
    if (_categoryOptions.isNotEmpty) return _categoryOptions.first;
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _commentC = TextEditingController();
    _referenceC = TextEditingController();
    _creditC = TextEditingController();
    _debitC = TextEditingController();
    _evidences = List<FinanzasEvidenceRecord>.from(widget.evidences);
    if (widget.availableCompanies.isNotEmpty) {
      _company = widget.availableCompanies.first;
    }
    if (widget.availableBranches.isNotEmpty) {
      _branch = widget.availableBranches.first;
    }
    if (widget.availableCategories.isNotEmpty) {
      _category = _resolvePreferredCategory(widget.availableCategories.first);
    }
    final existing = widget.existingRow;
    if (existing != null) {
      _date = DateUtils.dateOnly(existing.date);
      _sourceType = existing.sourceType;
      _company = existing.company;
      _branch = existing.branch;
      _counterpartyCompanyId = existing.counterpartyCompanyId;
      _counterpartyName = existing.counterpartyNameSnapshot;
      _category = existing.category;
      _selectedSupplierInvoiceId = existing.linkedSupplierInvoiceId;
      _selectedClientAccountId = existing.linkedExternalRef;
      _selectedFixedPaymentId = existing.linkedFixedPaymentId;
      _commentC.text = existing.comment;
      _referenceC.text = existing.reference;
      _creditC.text = existing.creditAmount > 0
          ? formatDecimal(existing.creditAmount, decimals: 2)
          : '';
      _debitC.text = existing.debitAmount > 0
          ? formatDecimal(existing.debitAmount, decimals: 2)
          : '';
    } else if (widget.launchPreset != null) {
      _applyLaunchPreset(widget.launchPreset!);
    }
    _commentC.addListener(_refresh);
    _referenceC.addListener(_refresh);
    _creditC.addListener(_refresh);
    _debitC.addListener(_refresh);
  }

  @override
  void dispose() {
    _commentC.dispose();
    _referenceC.dispose();
    _creditC.dispose();
    _debitC.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  List<String> get _companyOptions {
    final values = <String>{...widget.availableCompanies, _company}
      ..removeWhere((value) => value.trim().isEmpty);
    final list = values.toList()..sort();
    return list;
  }

  List<String> get _branchOptions {
    final values = <String>{
      ...widget.availableBranches,
      _branch,
      for (final row in widget.supplierInvoices) row.targetBranch,
      for (final row in widget.fixedPayments) row.branch,
    }..removeWhere((value) => value.trim().isEmpty);
    final list = values.toList()..sort();
    return list;
  }

  List<String> get _categoryOptions {
    final values = <String>{...widget.availableCategories, _category}
      ..removeWhere((value) => value.trim().isEmpty);
    final list = values.toList()..sort();
    return list;
  }

  Future<void> _pickDate() async {
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
      builder: (context, child) {
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
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _date = DateUtils.dateOnly(picked));
  }

  FinanzasSupplierInvoiceRecord? get _selectedSupplierInvoice {
    final id = _selectedSupplierInvoiceId;
    if (id == null) return null;
    for (final row in widget.supplierInvoices) {
      if (row.id == id) return row;
    }
    return null;
  }

  FinanzasClientPaymentAccountRecord? get _selectedClientAccount {
    final id = _selectedClientAccountId;
    if (id == null) return null;
    for (final row in widget.clientAccounts) {
      if (row.id == id) return row;
    }
    return null;
  }

  FinanzasFixedPaymentRecord? get _selectedFixedPayment {
    final id = _selectedFixedPaymentId;
    if (id == null) return null;
    for (final row in widget.fixedPayments) {
      if (row.id == id) return row;
    }
    return null;
  }

  double _parseAmount(String raw) {
    final cleaned = raw.replaceAll(',', '').replaceAll('\$', '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  bool get _canSave {
    if (_counterpartyName.trim().isEmpty) return false;
    final credit = _parseAmount(_creditC.text);
    final debit = _parseAmount(_debitC.text);
    if (credit <= 0 && debit <= 0) return false;
    if (credit > 0 && debit > 0) return false;
    if (_sourceType == 'COMPRA_FACTURA' &&
        !_isEditing &&
        _selectedSupplierInvoice == null) {
      return false;
    }
    if (_sourceType == 'VENTA_FACTURA' &&
        !_isEditing &&
        _selectedClientAccount == null) {
      return false;
    }
    if (_sourceType == 'PAGO_FIJO' &&
        !_isEditing &&
        _selectedFixedPayment == null) {
      return false;
    }
    if (_sourceType == 'COMPRA_FACTURA' && !_isEditing) {
      final invoice = _selectedSupplierInvoice;
      if (invoice == null) return false;
      if (credit > 0) return false;
      if ((debit - invoice.balanceAmount).abs() > 0.009) return false;
    }
    return true;
  }

  void _handleSourceChanged(String value) {
    setState(() {
      _sourceType = value;
      if (value == 'COMPRA_FACTURA') {
        _category = _resolvePreferredCategory('COMPRA DE MATERIAL');
      } else if (value == 'VENTA_FACTURA') {
        _category = _resolvePreferredCategory('VENTAS');
      } else if (value == 'PAGO_FIJO') {
        _category = _resolvePreferredCategory('GASTOS OPERATIVOS');
      } else {
        _selectedSupplierInvoiceId = null;
        _selectedClientAccountId = null;
        _selectedFixedPaymentId = null;
      }
    });
    if (value == 'MANUAL') {
      _counterpartyCompanyId = null;
      _counterpartyName = '';
      _referenceC.clear();
      _creditC.clear();
      _debitC.clear();
    }
    if (value != 'COMPRA_FACTURA') {
      _selectedSupplierInvoiceId = null;
    }
    if (value != 'VENTA_FACTURA') {
      _selectedClientAccountId = null;
    }
    if (value != 'PAGO_FIJO') {
      _selectedFixedPaymentId = null;
    }
  }

  void _applySupplierInvoice(FinanzasSupplierInvoiceRecord invoice) {
    setState(() {
      _selectedSupplierInvoiceId = invoice.id;
      _selectedClientAccountId = null;
      _company = invoice.targetCompany;
      _branch = invoice.targetBranch;
      _counterpartyCompanyId = invoice.providerId;
      _counterpartyName = invoice.providerNameSnapshot;
      _category = _resolvePreferredCategory('COMPRA DE MATERIAL');
      _referenceC.text = invoice.folio;
      _creditC.text = '';
      _debitC.text = invoice.balanceAmount.toStringAsFixed(2);
    });
  }

  void _applyClientAccount(FinanzasClientPaymentAccountRecord account) {
    setState(() {
      _selectedClientAccountId = account.id;
      _selectedSupplierInvoiceId = null;
      _selectedFixedPaymentId = null;
      _counterpartyCompanyId = account.clientId;
      _counterpartyName = account.clientName;
      _category = _resolvePreferredCategory('VENTAS');
      _referenceC.text = account.documentNumber;
      _creditC.text = account.pendingBalance.toStringAsFixed(2);
      _debitC.text = '';
    });
  }

  void _applyFixedPayment(FinanzasFixedPaymentRecord payment) {
    setState(() {
      _selectedFixedPaymentId = payment.id;
      _selectedSupplierInvoiceId = null;
      _selectedClientAccountId = null;
      _company = payment.targetCompany;
      _counterpartyCompanyId = payment.companyId;
      _counterpartyName = payment.companyNameSnapshot;
      _branch = payment.branch;
      _category = _resolvePreferredCategory('GASTOS OPERATIVOS');
      _referenceC.text = 'Pago fijo';
      _creditC.text = '';
      _debitC.text = payment.amount.toStringAsFixed(2);
    });
  }

  void _applyLaunchPreset(FinanzasBankMovementLaunchPreset preset) {
    _sourceType = preset.sourceType;
    _company = preset.company;
    _branch = preset.branch;
    _counterpartyCompanyId = preset.counterpartyCompanyId;
    _counterpartyName = preset.counterpartyName;
    _category = _resolvePreferredCategory(preset.category);
    _referenceC.text = preset.reference;
    _commentC.text = preset.comment;
    _creditC.text = preset.creditAmount > 0
        ? formatDecimal(preset.creditAmount, decimals: 2)
        : '';
    _debitC.text = preset.debitAmount > 0
        ? formatDecimal(preset.debitAmount, decimals: 2)
        : '';
    if (preset.sourceType == 'COMPRA_FACTURA' &&
        preset.linkedSupplierInvoiceId != null) {
      _selectedSupplierInvoiceId = preset.linkedSupplierInvoiceId;
      FinanzasSupplierInvoiceRecord? invoice;
      for (final row in widget.supplierInvoices) {
        if (row.id == preset.linkedSupplierInvoiceId) {
          invoice = row;
          break;
        }
      }
      if (invoice != null) {
        _selectedClientAccountId = null;
        _selectedFixedPaymentId = null;
        _company = invoice.targetCompany;
        _branch = invoice.targetBranch;
        _counterpartyCompanyId = invoice.providerId;
        _counterpartyName = invoice.providerNameSnapshot;
        _category = _resolvePreferredCategory('COMPRA DE MATERIAL');
        _referenceC.text = invoice.folio;
        _creditC.text = '';
        _debitC.text = invoice.balanceAmount.toStringAsFixed(2);
        if (preset.debitAmount > 0) {
          _debitC.text = formatDecimal(preset.debitAmount, decimals: 2);
        }
        if (preset.reference.trim().isNotEmpty) {
          _referenceC.text = preset.reference;
        }
        if (preset.comment.trim().isNotEmpty) {
          _commentC.text = preset.comment;
        }
      }
    } else if (preset.sourceType == 'VENTA_FACTURA' &&
        preset.linkedClientAccountId != null) {
      _selectedClientAccountId = preset.linkedClientAccountId;
      FinanzasClientPaymentAccountRecord? account;
      for (final row in widget.clientAccounts) {
        if (row.id == preset.linkedClientAccountId) {
          account = row;
          break;
        }
      }
      if (account != null) {
        _selectedSupplierInvoiceId = null;
        _selectedFixedPaymentId = null;
        _counterpartyCompanyId = account.clientId;
        _counterpartyName = account.clientName;
        _category = _resolvePreferredCategory('VENTAS');
        _referenceC.text = account.documentNumber;
        _creditC.text = account.pendingBalance.toStringAsFixed(2);
        _debitC.text = '';
        if (preset.creditAmount > 0) {
          _creditC.text = formatDecimal(preset.creditAmount, decimals: 2);
        }
        if (preset.reference.trim().isNotEmpty) {
          _referenceC.text = preset.reference;
        }
        if (preset.comment.trim().isNotEmpty) {
          _commentC.text = preset.comment;
        }
      }
    } else if (preset.sourceType == 'PAGO_FIJO' &&
        preset.linkedFixedPaymentId != null) {
      _selectedFixedPaymentId = preset.linkedFixedPaymentId;
      FinanzasFixedPaymentRecord? payment;
      for (final row in widget.fixedPayments) {
        if (row.id == preset.linkedFixedPaymentId) {
          payment = row;
          break;
        }
      }
      if (payment != null) {
        _selectedSupplierInvoiceId = null;
        _selectedClientAccountId = null;
        _company = payment.targetCompany;
        _counterpartyCompanyId = payment.companyId;
        _counterpartyName = payment.companyNameSnapshot;
        _branch = payment.branch;
        _category = _resolvePreferredCategory('GASTOS OPERATIVOS');
        _referenceC.text = 'Pago fijo';
        _creditC.text = '';
        _debitC.text = payment.amount.toStringAsFixed(2);
        if (preset.debitAmount > 0) {
          _debitC.text = formatDecimal(preset.debitAmount, decimals: 2);
        }
        if (preset.reference.trim().isNotEmpty) {
          _referenceC.text = preset.reference;
        }
        if (preset.comment.trim().isNotEmpty) {
          _commentC.text = preset.comment;
        }
      }
    }
  }

  Future<void> _pickCounterparty() async {
    final selected = await showDialog<FinanzasCatalogCompanyRecord>(
      context: context,
      builder: (_) =>
          _CounterpartyPickerDialog(companies: widget.companies, maxWidth: 780),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _counterpartyCompanyId = selected.id;
      _counterpartyName = selected.name;
    });
  }

  String _dateLabel(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  bool get _isEditing => widget.existingRow != null;
  bool get _isManualMovement => _sourceType == 'MANUAL';
  bool get _hasLockedLinkedFields => _isEditing && !_isManualMovement;

  String get _supplierInvoiceValue {
    final invoice = _selectedSupplierInvoice;
    if (invoice != null) {
      return '${invoice.providerNameSnapshot} · ${invoice.folio}';
    }
    if (_hasLockedLinkedFields) {
      final fallbackRef = _referenceC.text.trim();
      return fallbackRef.isEmpty
          ? (_counterpartyName.trim().isEmpty
                ? 'Factura vinculada'
                : _counterpartyName)
          : '${_counterpartyName.trim()} · $fallbackRef';
    }
    return 'Seleccionar factura';
  }

  String get _clientAccountValue {
    final account = _selectedClientAccount;
    if (account != null) {
      return '${account.clientName} · ${account.documentNumber}';
    }
    if (_hasLockedLinkedFields) {
      final fallbackRef = _referenceC.text.trim();
      return fallbackRef.isEmpty
          ? (_counterpartyName.trim().isEmpty
                ? 'Cuenta vinculada'
                : _counterpartyName)
          : '${_counterpartyName.trim()} · $fallbackRef';
    }
    return 'Seleccionar cuenta por cobrar';
  }

  String get _fixedPaymentValue {
    final payment = _selectedFixedPayment;
    if (payment != null) {
      return '${payment.companyNameSnapshot} · ${_dateLabel(payment.paymentDate)} · ${_formatBankMoney(payment.amount)}';
    }
    if (_hasLockedLinkedFields) {
      final amount = _parseAmount(_debitC.text);
      final amountLabel = amount > 0 ? _formatBankMoney(amount) : 'Monto fijo';
      return '${_counterpartyName.trim().isEmpty ? 'Pago fijo' : _counterpartyName.trim()} · ${_dateLabel(_date)} · $amountLabel';
    }
    return 'Seleccionar pago fijo';
  }

  String get _editingSubtitle {
    if (!_isEditing) {
      return 'Captura un movimiento libre, pago a proveedor o cobro de cliente.';
    }
    if (_isManualMovement) {
      return 'Ajusta los datos del movimiento libre seleccionado.';
    }
    return 'Revisa el movimiento y ajusta solo fecha, empresa, cuenta, categoría, comentario y evidencias.';
  }

  Future<void> _uploadEvidenceFromDialog() async {
    final upload = widget.onUploadEvidence;
    if (upload == null) return;
    final uploaded = await upload();
    if (uploaded == null || !mounted) return;
    setState(() {
      _evidences = <FinanzasEvidenceRecord>[uploaded, ..._evidences];
    });
  }

  @override
  Widget build(BuildContext context) {
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
                                  _isEditing
                                      ? 'Editar movimiento'
                                      : 'Nuevo movimiento',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: kFinanzasInk,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _editingSubtitle,
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
                      if (_hasLockedLinkedFields) ...[
                        const SizedBox(height: 14),
                        FinanzasGlassPanel(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          borderRadius: BorderRadius.circular(20),
                          fillColor: tokens.primaryStrong.withValues(
                            alpha: 0.10,
                          ),
                          borderColor: tokens.primaryStrong.withValues(
                            alpha: 0.24,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: tokens.primaryStrong,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Este movimiento proviene de otra operación. Aquí solo puedes ajustar fecha, empresa, cuenta, categoría, comentario y evidencias.',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: kFinanzasInk,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Flexible(
                        fit: FlexFit.loose,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _BankDialogSectionTitle(
                                step: '1',
                                title: 'Identidad',
                                subtitle:
                                    'Define origen, fecha y cuenta bancaria.',
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ChoiceChipField(
                                      label: 'Origen',
                                      value: _bankSourceTypeLabel(_sourceType),
                                      enabled: !_isEditing,
                                      onTap: _isEditing
                                          ? () {}
                                          : () {
                                              unawaited(() async {
                                                final selected = await _showSimpleOptionsDialog(
                                                  context: context,
                                                  title: 'Seleccionar origen',
                                                  options: const <_SimpleOption>[
                                                    _SimpleOption(
                                                      id: 'MANUAL',
                                                      label: 'Movimiento libre',
                                                      subtitle:
                                                          'Movimiento que no nace de compras o ventas',
                                                    ),
                                                    _SimpleOption(
                                                      id: 'COMPRA_FACTURA',
                                                      label:
                                                          'Factura proveedor',
                                                      subtitle:
                                                          'Paga una factura de compras mayoreo',
                                                    ),
                                                    _SimpleOption(
                                                      id: 'VENTA_FACTURA',
                                                      label: 'Pago cliente',
                                                      subtitle:
                                                          'Registra el cobro de una cuenta de ventas mayoreo',
                                                    ),
                                                    _SimpleOption(
                                                      id: 'PAGO_FIJO',
                                                      label: 'Pago fijo',
                                                      subtitle:
                                                          'Liquida una obligación fija del mes',
                                                    ),
                                                  ],
                                                );
                                                if (selected == null) return;
                                                _handleSourceChanged(
                                                  selected.id,
                                                );
                                              }());
                                            },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _DatePickerField(
                                      label: 'Fecha',
                                      value: _dateLabel(_date),
                                      onTap: () {
                                        unawaited(_pickDate());
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _ChoiceChipField(
                                      label: 'Empresa',
                                      value: _company,
                                      onTap: () {
                                        unawaited(() async {
                                          final selected =
                                              await _showSimpleOptionsDialog(
                                                context: context,
                                                title: 'Seleccionar empresa',
                                                options: _companyOptions
                                                    .map(
                                                      (row) => _SimpleOption(
                                                        id: row,
                                                        label: row,
                                                        subtitle:
                                                            'Titular de la cuenta',
                                                      ),
                                                    )
                                                    .toList(growable: false),
                                              );
                                          if (selected == null) return;
                                          setState(
                                            () => _company = selected.id,
                                          );
                                        }());
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _ChoiceChipField(
                                      label: 'Cuenta',
                                      value: _branch,
                                      onTap: () {
                                        unawaited(() async {
                                          final selected =
                                              await _showSimpleOptionsDialog(
                                                context: context,
                                                title: 'Seleccionar cuenta',
                                                options: _branchOptions
                                                    .map(
                                                      (row) => _SimpleOption(
                                                        id: row,
                                                        label: row,
                                                        subtitle:
                                                            'Sucursal bancaria',
                                                      ),
                                                    )
                                                    .toList(growable: false),
                                              );
                                          if (selected == null) return;
                                          setState(() => _branch = selected.id);
                                        }());
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              _BankDialogSectionTitle(
                                step: '2',
                                title: 'Contraparte',
                                subtitle:
                                    'Relaciona a quién pertenece el movimiento y cómo clasificarlo.',
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _sourceType == 'COMPRA_FACTURA'
                                        ? _ChoiceChipField(
                                            label: 'Factura proveedor',
                                            value: _supplierInvoiceValue,
                                            enabled: !_hasLockedLinkedFields,
                                            onTap: () {
                                              unawaited(() async {
                                                final selected =
                                                    await showDialog<
                                                      FinanzasSupplierInvoiceRecord
                                                    >(
                                                      context: context,
                                                      builder: (_) =>
                                                          _SupplierInvoicePickerDialog(
                                                            invoices: widget
                                                                .supplierInvoices,
                                                          ),
                                                    );
                                                if (selected == null) return;
                                                _applySupplierInvoice(selected);
                                              }());
                                            },
                                          )
                                        : _sourceType == 'VENTA_FACTURA'
                                        ? _ChoiceChipField(
                                            label: 'Pago cliente',
                                            value: _clientAccountValue,
                                            enabled: !_hasLockedLinkedFields,
                                            onTap: () {
                                              unawaited(() async {
                                                final selected =
                                                    await showDialog<
                                                      FinanzasClientPaymentAccountRecord
                                                    >(
                                                      context: context,
                                                      builder: (_) =>
                                                          _ClientPaymentPickerDialog(
                                                            accounts: widget
                                                                .clientAccounts,
                                                          ),
                                                    );
                                                if (selected == null) return;
                                                _applyClientAccount(selected);
                                              }());
                                            },
                                          )
                                        : _sourceType == 'PAGO_FIJO'
                                        ? _ChoiceChipField(
                                            label: 'Pago fijo',
                                            value: _fixedPaymentValue,
                                            enabled: !_hasLockedLinkedFields,
                                            onTap: () {
                                              unawaited(() async {
                                                final selected =
                                                    await showDialog<
                                                      FinanzasFixedPaymentRecord
                                                    >(
                                                      context: context,
                                                      builder: (_) =>
                                                          _FixedPaymentPickerDialog(
                                                            payments: widget
                                                                .fixedPayments,
                                                          ),
                                                    );
                                                if (selected == null) return;
                                                _applyFixedPayment(selected);
                                              }());
                                            },
                                          )
                                        : _ChoiceChipField(
                                            label: 'Nombre',
                                            value: _counterpartyName.isEmpty
                                                ? 'Seleccionar nombre'
                                                : _counterpartyName,
                                            enabled: !_hasLockedLinkedFields,
                                            onTap: _pickCounterparty,
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _ChoiceChipField(
                                      label: 'Categoría',
                                      value: _category,
                                      onTap: () {
                                        unawaited(() async {
                                          final selected =
                                              await _showSimpleOptionsDialog(
                                                context: context,
                                                title: 'Seleccionar categoría',
                                                options: _categoryOptions
                                                    .map(
                                                      (row) => _SimpleOption(
                                                        id: row,
                                                        label: row,
                                                        subtitle: '',
                                                      ),
                                                    )
                                                    .toList(growable: false),
                                              );
                                          if (selected == null) return;
                                          setState(
                                            () => _category = selected.id,
                                          );
                                        }());
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              if (_sourceType == 'COMPRA_FACTURA' &&
                                  _selectedSupplierInvoice != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    12,
                                    14,
                                    12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.66),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color:
                                          _company ==
                                                  _selectedSupplierInvoice!
                                                      .targetCompany &&
                                              _branch ==
                                                  _selectedSupplierInvoice!
                                                      .targetBranch
                                          ? tokens.primaryStrong.withValues(
                                              alpha: 0.18,
                                            )
                                          : const Color(
                                              0xFF8B5E00,
                                            ).withValues(alpha: 0.28),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        _company ==
                                                    _selectedSupplierInvoice!
                                                        .targetCompany &&
                                                _branch ==
                                                    _selectedSupplierInvoice!
                                                        .targetBranch
                                            ? Icons.track_changes_rounded
                                            : Icons.warning_amber_rounded,
                                        size: 18,
                                        color:
                                            _company ==
                                                    _selectedSupplierInvoice!
                                                        .targetCompany &&
                                                _branch ==
                                                    _selectedSupplierInvoice!
                                                        .targetBranch
                                            ? tokens.primaryStrong
                                            : const Color(0xFF8B5E00),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _company ==
                                                      _selectedSupplierInvoice!
                                                          .targetCompany &&
                                                  _branch ==
                                                      _selectedSupplierInvoice!
                                                          .targetBranch
                                              ? 'Objetivo precargado desde factura: ${_selectedSupplierInvoice!.targetCompany} ${_selectedSupplierInvoice!.targetBranch}.'
                                              : 'La ejecución quedó distinta al objetivo de la factura: ${_selectedSupplierInvoice!.targetCompany} ${_selectedSupplierInvoice!.targetBranch}.',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: kFinanzasMutedInk,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              _BankDialogSectionTitle(
                                step: '3',
                                title: 'Monto',
                                subtitle:
                                    'Registra referencia y define si entra como abono o cargo.',
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _referenceC,
                                      readOnly: _hasLockedLinkedFields,
                                      style: const TextStyle(
                                        color: kFinanzasInk,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      cursorColor:
                                          finanzasAreaTokens.primaryStrong,
                                      decoration: _bankDialogFieldDecoration(
                                        context,
                                        hintText: 'No. factura o cheque',
                                        prefixIcon: const Icon(
                                          Icons.confirmation_num_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _creditC,
                                      readOnly: _hasLockedLinkedFields,
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
                                      inputFormatters: _hasLockedLinkedFields
                                          ? const <TextInputFormatter>[]
                                          : const [_BankMoneyInputFormatter()],
                                      decoration: _bankDialogFieldDecoration(
                                        context,
                                        hintText: 'Abono',
                                        prefixIcon: const Icon(
                                          Icons.south_west_rounded,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _debitC,
                                      style: const TextStyle(
                                        color: kFinanzasInk,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      cursorColor:
                                          finanzasAreaTokens.primaryStrong,
                                      readOnly:
                                          _hasLockedLinkedFields ||
                                          _sourceType == 'COMPRA_FACTURA',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters:
                                          _sourceType == 'COMPRA_FACTURA'
                                          ? const <TextInputFormatter>[]
                                          : const [_BankMoneyInputFormatter()],
                                      decoration: _bankDialogFieldDecoration(
                                        context,
                                        hintText:
                                            _sourceType == 'COMPRA_FACTURA'
                                            ? 'Factura completa'
                                            : 'Cargo',
                                        prefixIcon: const Icon(
                                          Icons.north_east_rounded,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              _BankDialogSectionTitle(
                                step: '4',
                                title: 'Comentario',
                                subtitle:
                                    'Agrega el contexto operativo del movimiento.',
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _commentC,
                                style: const TextStyle(
                                  color: kFinanzasInk,
                                  fontWeight: FontWeight.w700,
                                ),
                                cursorColor: finanzasAreaTokens.primaryStrong,
                                minLines: 3,
                                maxLines: 4,
                                decoration: _bankDialogFieldDecoration(
                                  context,
                                  hintText: 'Comentario del movimiento',
                                  prefixIcon: const Icon(
                                    Icons.note_alt_outlined,
                                  ),
                                ),
                              ),
                              if (_isEditing) ...[
                                const SizedBox(height: 18),
                                _BankDialogSectionTitle(
                                  step: '5',
                                  title: 'Evidencias',
                                  subtitle:
                                      'Consulta o adjunta respaldos del movimiento desde aquí.',
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed: widget.onUploadEvidence == null
                                        ? null
                                        : () => unawaited(
                                            _uploadEvidenceFromDialog(),
                                          ),
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Subir evidencia'),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _BankDetailsEvidenceBlock(
                                  evidences: _evidences,
                                  dateFormatter: _dateLabel,
                                  onOpenEvidence:
                                      widget.onOpenEvidence ??
                                      (ignoredUrl, ignoredFileName) async {},
                                ),
                              ],
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
                                      _BankMovementDraft(
                                        date: _date,
                                        company: _company,
                                        branch: _branch,
                                        counterpartyCompanyId:
                                            _counterpartyCompanyId,
                                        counterpartyName: _counterpartyName
                                            .trim(),
                                        category: _category,
                                        comment: _commentC.text.trim(),
                                        reference: _referenceC.text.trim(),
                                        creditAmount: _parseAmount(
                                          _creditC.text,
                                        ),
                                        debitAmount: _parseAmount(_debitC.text),
                                        sourceType: _sourceType,
                                        linkedSupplierInvoice:
                                            _selectedSupplierInvoice,
                                        linkedClientAccount:
                                            _selectedClientAccount,
                                        linkedFixedPayment:
                                            _selectedFixedPayment,
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              _isEditing
                                  ? 'Guardar cambios'
                                  : 'Guardar movimiento',
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

class _BankMoneyInputFormatter extends TextInputFormatter {
  const _BankMoneyInputFormatter();

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

InputDecoration _bankDialogFieldDecoration(
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

class _CounterpartyPickerDialog extends StatefulWidget {
  final List<FinanzasCatalogCompanyRecord> companies;
  final double maxWidth;

  const _CounterpartyPickerDialog({
    required this.companies,
    this.maxWidth = 560,
  });

  @override
  State<_CounterpartyPickerDialog> createState() =>
      _CounterpartyPickerDialogState();
}

class _CounterpartyPickerDialogState extends State<_CounterpartyPickerDialog> {
  final TextEditingController _searchC = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  int _highlightedIndex = -1;
  int? _hoveredIndex;
  final List<GlobalKey> _optionKeys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    _searchC.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchC.removeListener(_refresh);
    _searchC.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _highlightedIndex = -1);

  @override
  Widget build(BuildContext context) {
    final query = _searchC.text.trim().toLowerCase();
    final rows = widget.companies
        .where((row) {
          if (query.isEmpty) return true;
          return row.name.toLowerCase().contains(query) ||
              row.source.toLowerCase().contains(query);
        })
        .toList(growable: false);
    _syncPickerOptionKeys(_optionKeys, rows.length);
    if (_highlightedIndex >= 0) {
      _ensurePickerHighlightVisible(
        keys: _optionKeys,
        highlightedIndex: _highlightedIndex,
        rowCount: rows.length,
      );
    }
    void selectHighlighted() {
      if (rows.isEmpty || _highlightedIndex < 0) return;
      Navigator.of(
        context,
      ).pop(rows[_highlightedIndex.clamp(0, rows.length - 1)]);
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
                  rows.isNotEmpty) {
                setState(() {
                  _highlightedIndex = _highlightedIndex < 0
                      ? 0
                      : (_highlightedIndex + 1).clamp(0, rows.length - 1);
                });
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                  rows.isNotEmpty) {
                setState(() {
                  _highlightedIndex = _highlightedIndex < 0
                      ? rows.length - 1
                      : (_highlightedIndex - 1).clamp(0, rows.length - 1);
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
                constraints: BoxConstraints(
                  maxWidth: widget.maxWidth,
                  maxHeight: 620,
                ),
                child: Column(
                  children: [
                    TextField(
                      focusNode: _searchFocusNode,
                      controller: _searchC,
                      autofocus: true,
                      style: const TextStyle(
                        color: kFinanzasInk,
                        fontWeight: FontWeight.w700,
                      ),
                      cursorColor: finanzasAreaTokens.primaryStrong,
                      decoration: _bankDialogFieldDecoration(
                        dialogContext,
                        hintText: 'Buscar nombre',
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final row = rows[index];
                          final selected =
                              index == _highlightedIndex &&
                              (_hoveredIndex == null || _hoveredIndex == index);
                          return KeyedSubtree(
                            key: _optionKeys[index],
                            child: _BankPickerOptionTile(
                              title: row.name,
                              subtitle: row.source,
                              selected: selected,
                              hovered: _hoveredIndex == index,
                              onHoverChanged: (hovered) {
                                setState(() {
                                  _hoveredIndex = hovered ? index : null;
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
  }
}

class _SupplierInvoicePickerDialog extends StatefulWidget {
  final List<FinanzasSupplierInvoiceRecord> invoices;

  const _SupplierInvoicePickerDialog({required this.invoices});

  @override
  State<_SupplierInvoicePickerDialog> createState() =>
      _SupplierInvoicePickerDialogState();
}

class _FixedPaymentPickerDialog extends StatefulWidget {
  final List<FinanzasFixedPaymentRecord> payments;

  const _FixedPaymentPickerDialog({required this.payments});

  @override
  State<_FixedPaymentPickerDialog> createState() =>
      _FixedPaymentPickerDialogState();
}

class _FixedPaymentPickerDialogState extends State<_FixedPaymentPickerDialog> {
  final TextEditingController _searchC = TextEditingController();
  int _highlightedIndex = -1;
  int? _hoveredIndex;
  final List<GlobalKey> _optionKeys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    _searchC.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchC.removeListener(_refresh);
    _searchC.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _highlightedIndex = -1);

  @override
  Widget build(BuildContext context) {
    final query = _searchC.text.trim().toLowerCase();
    final rows = widget.payments
        .where((row) {
          if (query.isEmpty) return true;
          return row.companyNameSnapshot.toLowerCase().contains(query) ||
              row.notes.toLowerCase().contains(query) ||
              row.branch.toLowerCase().contains(query);
        })
        .toList(growable: false);
    _syncPickerOptionKeys(_optionKeys, rows.length);
    if (_highlightedIndex >= 0) {
      _ensurePickerHighlightVisible(
        keys: _optionKeys,
        highlightedIndex: _highlightedIndex,
        rowCount: rows.length,
      );
    }
    void selectHighlighted() {
      if (rows.isEmpty || _highlightedIndex < 0) return;
      Navigator.of(
        context,
      ).pop(rows[_highlightedIndex.clamp(0, rows.length - 1)]);
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
                  rows.isNotEmpty) {
                setState(() {
                  _highlightedIndex = _highlightedIndex < 0
                      ? 0
                      : (_highlightedIndex + 1).clamp(0, rows.length - 1);
                });
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                  rows.isNotEmpty) {
                setState(() {
                  _highlightedIndex = _highlightedIndex < 0
                      ? rows.length - 1
                      : (_highlightedIndex - 1).clamp(0, rows.length - 1);
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
                  maxWidth: 660,
                  maxHeight: 640,
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchC,
                      autofocus: true,
                      style: const TextStyle(
                        color: kFinanzasInk,
                        fontWeight: FontWeight.w700,
                      ),
                      cursorColor: finanzasAreaTokens.primaryStrong,
                      onChanged: (_) => setState(() => _highlightedIndex = -1),
                      decoration: _bankDialogFieldDecoration(
                        dialogContext,
                        hintText: 'Buscar empresa, cuenta o comentario',
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final row = rows[index];
                          return KeyedSubtree(
                            key: _optionKeys[index],
                            child: _BankPickerOptionTile(
                              title: row.companyNameSnapshot,
                              subtitle:
                                  '${finFixedPaymentTargetCompanyLabel(row.targetCompany)} ${finFixedPaymentBranchLabel(row.branch)} · ${_formatBankMoney(row.amount)} · vence ${row.paymentDate.day.toString().padLeft(2, '0')}/${row.paymentDate.month.toString().padLeft(2, '0')}/${row.paymentDate.year}',
                              selected:
                                  index == _highlightedIndex &&
                                  (_hoveredIndex == null ||
                                      _hoveredIndex == index),
                              hovered: _hoveredIndex == index,
                              onHoverChanged: (hovered) {
                                setState(() {
                                  _hoveredIndex = hovered ? index : null;
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
  }
}

class _ClientPaymentPickerDialog extends StatefulWidget {
  final List<FinanzasClientPaymentAccountRecord> accounts;

  const _ClientPaymentPickerDialog({required this.accounts});

  @override
  State<_ClientPaymentPickerDialog> createState() =>
      _ClientPaymentPickerDialogState();
}

class _ClientPaymentPickerDialogState
    extends State<_ClientPaymentPickerDialog> {
  final TextEditingController _searchC = TextEditingController();
  int _highlightedIndex = -1;
  int? _hoveredIndex;
  final List<GlobalKey> _optionKeys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    _searchC.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchC.removeListener(_refresh);
    _searchC.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _highlightedIndex = -1);

  @override
  Widget build(BuildContext context) {
    final query = _searchC.text.trim().toLowerCase();
    final rows = widget.accounts
        .where((row) {
          if (query.isEmpty) return true;
          return row.clientName.toLowerCase().contains(query) ||
              row.documentNumber.toLowerCase().contains(query);
        })
        .toList(growable: false);
    _syncPickerOptionKeys(_optionKeys, rows.length);
    if (_highlightedIndex >= 0) {
      _ensurePickerHighlightVisible(
        keys: _optionKeys,
        highlightedIndex: _highlightedIndex,
        rowCount: rows.length,
      );
    }
    void selectHighlighted() {
      if (rows.isEmpty || _highlightedIndex < 0) return;
      Navigator.of(
        context,
      ).pop(rows[_highlightedIndex.clamp(0, rows.length - 1)]);
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
                  rows.isNotEmpty) {
                setState(() {
                  _highlightedIndex = _highlightedIndex < 0
                      ? 0
                      : (_highlightedIndex + 1).clamp(0, rows.length - 1);
                });
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                  rows.isNotEmpty) {
                setState(() {
                  _highlightedIndex = _highlightedIndex < 0
                      ? rows.length - 1
                      : (_highlightedIndex - 1).clamp(0, rows.length - 1);
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
                  maxWidth: 640,
                  maxHeight: 640,
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchC,
                      autofocus: true,
                      style: const TextStyle(
                        color: kFinanzasInk,
                        fontWeight: FontWeight.w700,
                      ),
                      cursorColor: finanzasAreaTokens.primaryStrong,
                      onChanged: (_) => setState(() => _highlightedIndex = -1),
                      decoration: _bankDialogFieldDecoration(
                        dialogContext,
                        hintText: 'Buscar cliente o referencia',
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final row = rows[index];
                          return KeyedSubtree(
                            key: _optionKeys[index],
                            child: _BankPickerOptionTile(
                              title: row.clientName,
                              subtitle:
                                  '${row.documentNumber.isEmpty ? 'Sin referencia' : row.documentNumber} · ${_formatBankMoney(row.pendingBalance)} por cobrar',
                              selected:
                                  index == _highlightedIndex &&
                                  (_hoveredIndex == null ||
                                      _hoveredIndex == index),
                              hovered: _hoveredIndex == index,
                              onHoverChanged: (hovered) {
                                setState(() {
                                  _hoveredIndex = hovered ? index : null;
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
  }
}

class _SupplierInvoicePickerDialogState
    extends State<_SupplierInvoicePickerDialog> {
  final TextEditingController _searchC = TextEditingController();
  int _highlightedIndex = -1;
  int? _hoveredIndex;
  final List<GlobalKey> _optionKeys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    _searchC.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchC.removeListener(_refresh);
    _searchC.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _highlightedIndex = -1);

  String _money(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts.first;
    final fraction = parts[1];
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final reverseIndex = whole.length - i;
      buffer.write(whole[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }
    return '\$${buffer.toString()}.$fraction';
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchC.text.trim().toLowerCase();
    final rows = widget.invoices
        .where((row) {
          if (query.isEmpty) return true;
          return row.providerNameSnapshot.toLowerCase().contains(query) ||
              row.folio.toLowerCase().contains(query);
        })
        .toList(growable: false);
    _syncPickerOptionKeys(_optionKeys, rows.length);
    if (_highlightedIndex >= 0) {
      _ensurePickerHighlightVisible(
        keys: _optionKeys,
        highlightedIndex: _highlightedIndex,
        rowCount: rows.length,
      );
    }
    void selectHighlighted() {
      if (rows.isEmpty || _highlightedIndex < 0) return;
      Navigator.of(
        context,
      ).pop(rows[_highlightedIndex.clamp(0, rows.length - 1)]);
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
                  rows.isNotEmpty) {
                setState(() {
                  _highlightedIndex = _highlightedIndex < 0
                      ? 0
                      : (_highlightedIndex + 1).clamp(0, rows.length - 1);
                });
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                  rows.isNotEmpty) {
                setState(() {
                  _highlightedIndex = _highlightedIndex < 0
                      ? rows.length - 1
                      : (_highlightedIndex - 1).clamp(0, rows.length - 1);
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
                  maxWidth: 640,
                  maxHeight: 640,
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchC,
                      autofocus: true,
                      style: const TextStyle(
                        color: kFinanzasInk,
                        fontWeight: FontWeight.w700,
                      ),
                      cursorColor: finanzasAreaTokens.primaryStrong,
                      onChanged: (_) => setState(() => _highlightedIndex = -1),
                      decoration: _bankDialogFieldDecoration(
                        dialogContext,
                        hintText: 'Buscar proveedor o folio',
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final row = rows[index];
                          return KeyedSubtree(
                            key: _optionKeys[index],
                            child: _BankPickerOptionTile(
                              title:
                                  '${row.providerNameSnapshot} · ${row.folio}',
                              subtitle:
                                  '${finSupplierInvoiceStatusLabel(row.status)} · saldo ${_money(row.balanceAmount)}',
                              selected:
                                  index == _highlightedIndex &&
                                  (_hoveredIndex == null ||
                                      _hoveredIndex == index),
                              hovered: _hoveredIndex == index,
                              onHoverChanged: (hovered) {
                                setState(() {
                                  _hoveredIndex = hovered ? index : null;
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

class _BankPickerOptionTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final bool hovered;
  final ValueChanged<bool>? onHoverChanged;
  final VoidCallback onTap;

  const _BankPickerOptionTile({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.hovered = false,
    this.onHoverChanged,
  });

  @override
  State<_BankPickerOptionTile> createState() => _BankPickerOptionTileState();
}

class _BankPickerOptionTileState extends State<_BankPickerOptionTile> {
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
        _syncPickerOptionKeys(optionKeys, filtered.length);
        if (highlightedIndex >= 0) {
          _ensurePickerHighlightVisible(
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
                          decoration: _bankDialogFieldDecoration(
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
                                child: _BankPickerOptionTile(
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

Future<DateTimeRange?> _showFinBankDateRangeDialog(
  BuildContext context, {
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
                        'Filtrar fecha',
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
                                '${_finBankMonthNameEs(monthFirst.month)} ${monthFirst.year}',
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
                            : '${_formatFinBankFilterDate(start!)} - ${_formatFinBankFilterDate(end!)}',
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
                            ).pop(_kClearedBankDateRange),
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

String _finBankMonthNameEs(int month) {
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

String _formatFinBankFilterDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _ChoiceChipField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool enabled;

  const _ChoiceChipField({
    required this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
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
          onTap: enabled ? onTap : null,
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
                          color: enabled
                              ? tokens.primaryStrong
                              : tokens.primaryStrong.withValues(alpha: 0.58),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.expand_more_rounded,
                  color: enabled
                      ? tokens.primaryStrong
                      : tokens.primaryStrong.withValues(alpha: 0.42),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ChoiceChipField(label: label, value: value, onTap: onTap);
  }
}

class _BankDialogSectionTitle extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;

  const _BankDialogSectionTitle({
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

class _BankTabSurface extends StatelessWidget {
  final Widget child;

  const _BankTabSurface({required this.child});

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

class _BankFilterSummaryRow extends StatelessWidget {
  final List<String> labels;
  final VoidCallback? onClearAll;

  const _BankFilterSummaryRow({required this.labels, this.onClearAll});

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

class _BankHeaderColumn {
  final String label;
  final double width;
  final VoidCallback? onFilter;
  final bool active;

  const _BankHeaderColumn(
    this.label,
    this.width, {
    this.onFilter,
    this.active = false,
  });
}

class _BankHeaderRow extends StatelessWidget {
  final VoidCallback onDateFilter;
  final VoidCallback onCompanyFilter;
  final VoidCallback onBranchFilter;
  final VoidCallback onNameFilter;
  final VoidCallback onCategoryFilter;
  final VoidCallback onReferenceFilter;
  final VoidCallback onCreditFilter;
  final VoidCallback onDebitFilter;
  final bool dateFilterActive;
  final bool companyFilterActive;
  final bool branchFilterActive;
  final bool nameFilterActive;
  final bool categoryFilterActive;
  final bool referenceFilterActive;
  final bool creditFilterActive;
  final bool debitFilterActive;

  const _BankHeaderRow({
    required this.onDateFilter,
    required this.onCompanyFilter,
    required this.onBranchFilter,
    required this.onNameFilter,
    required this.onCategoryFilter,
    required this.onReferenceFilter,
    required this.onCreditFilter,
    required this.onDebitFilter,
    required this.dateFilterActive,
    required this.companyFilterActive,
    required this.branchFilterActive,
    required this.nameFilterActive,
    required this.categoryFilterActive,
    required this.referenceFilterActive,
    required this.creditFilterActive,
    required this.debitFilterActive,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final columns = <_BankHeaderColumn>[
      _BankHeaderColumn(
        'FECHA',
        _kBankDateW,
        onFilter: onDateFilter,
        active: dateFilterActive,
      ),
      _BankHeaderColumn(
        'EMPRESA',
        _kBankCompanyW,
        onFilter: onCompanyFilter,
        active: companyFilterActive,
      ),
      _BankHeaderColumn(
        'CUENTA',
        _kBankBranchW,
        onFilter: onBranchFilter,
        active: branchFilterActive,
      ),
      _BankHeaderColumn(
        'NOMBRE',
        _kBankNameW,
        onFilter: onNameFilter,
        active: nameFilterActive,
      ),
      _BankHeaderColumn(
        'CATEGORÍA',
        _kBankCategoryW,
        onFilter: onCategoryFilter,
        active: categoryFilterActive,
      ),
      const _BankHeaderColumn('COMENTARIO', _kBankCommentW),
      _BankHeaderColumn(
        'REFERENCIA',
        _kBankReferenceW,
        onFilter: onReferenceFilter,
        active: referenceFilterActive,
      ),
      _BankHeaderColumn(
        'ABONO',
        _kBankCreditW,
        onFilter: onCreditFilter,
        active: creditFilterActive,
      ),
      _BankHeaderColumn(
        'CARGO',
        _kBankDebitW,
        onFilter: onDebitFilter,
        active: debitFilterActive,
      ),
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
            _kBankActionsW,
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
                    const SizedBox(width: _kBankActionsW),
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

class _BankAccountsTotalsRow extends StatelessWidget {
  final List<_BankAccountTotals> totals;
  final String Function(double value) moneyFormatter;

  const _BankAccountsTotalsRow({
    required this.totals,
    required this.moneyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = totals.isEmpty
            ? 250.0
            : ((constraints.maxWidth - ((totals.length - 1) * 12)) /
                      totals.length)
                  .clamp(220.0, 360.0);
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final total in totals)
              SizedBox(
                width: cardWidth,
                child: _BankAccountTotalCard(
                  total: total,
                  moneyFormatter: moneyFormatter,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BankTopBar extends StatelessWidget {
  final bool exportingCsv;
  final int selectedCount;
  final VoidCallback? onExportCsv;
  final Future<void> Function() onCreate;

  const _BankTopBar({
    required this.exportingCsv,
    required this.selectedCount,
    required this.onExportCsv,
    required this.onCreate,
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
                onPressed: exportingCsv ? null : onExportCsv,
                icon: const Icon(Icons.download_rounded),
                label: Text(exportingCsv ? 'Exportando...' : 'Descargar CSV'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.primaryStrong,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => unawaited(onCreate()),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo movimiento'),
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
    return FinanzasGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: BorderRadius.circular(22),
      fillColor: const Color(0x12161A22),
      borderColor: Colors.white.withValues(alpha: 0.18),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.16),
      child: Wrap(
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
              items: const [40, 80, 120]
                  .map(
                    (size) => DropdownMenuItem<int>(
                      value: size,
                      child: Text('$size'),
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
    );
  }
}

class _BankAccountTotalCard extends StatelessWidget {
  final _BankAccountTotals total;
  final String Function(double value) moneyFormatter;

  const _BankAccountTotalCard({
    required this.total,
    required this.moneyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final net = total.credit - total.debit;
    return FinanzasGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(26),
      fillColor: const Color(0x14161A21),
      borderColor: Colors.white.withValues(alpha: 0.24),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.20),
      child: SizedBox(
        height: 144,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${total.company} ${total.branch}',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Abonos ${moneyFormatter(total.credit)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF48B7A9),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cargos ${moneyFormatter(total.debit)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF45F4E),
              ),
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Neto ${moneyFormatter(net)}',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: net >= 0
                      ? const Color(0xFF48B7A9)
                      : tokens.primaryStrong,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankAccountTotals {
  final String company;
  final String branch;
  final double credit;
  final double debit;

  const _BankAccountTotals({
    required this.company,
    required this.branch,
    required this.credit,
    required this.debit,
  });

  factory _BankAccountTotals.empty(String company, String branch) =>
      _BankAccountTotals(company: company, branch: branch, credit: 0, debit: 0);

  _BankAccountTotals add({required double credit, required double debit}) {
    return _BankAccountTotals(
      company: company,
      branch: branch,
      credit: this.credit + credit,
      debit: this.debit + debit,
    );
  }
}

class _BankTableCell {
  final double width;
  final Widget child;

  const _BankTableCell._({required this.width, required this.child});

  factory _BankTableCell.text({
    required double width,
    required String text,
    bool bold = false,
  }) {
    return _BankTableCell._(
      width: width,
      child: Text(
        text.isEmpty ? '—' : text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          color: kFinanzasInk,
        ),
      ),
    );
  }

  factory _BankTableCell.money({
    required double width,
    required String text,
    required bool positive,
    bool selectedContext = false,
  }) {
    final color = selectedContext
        ? Colors.white
        : (positive ? const Color(0xFF0F766E) : const Color(0xFFB42318));
    return _BankTableCell._(
      width: width,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _BankTableRow extends StatefulWidget {
  final String rowKey;
  final bool selected;
  final bool active;
  final bool dragSelectionActive;
  final VoidCallback onTap;
  final ValueChanged<bool> onDragStart;
  final VoidCallback onDragEnter;
  final VoidCallback onDragEnd;
  final VoidCallback? onDoubleTap;
  final VoidCallback onPrepareMenuSelection;
  final List<_BankTableCell> cells;
  final List<_BankRowMenuAction> menuItems;
  final Set<int> editableColumns;

  const _BankTableRow({
    required this.rowKey,
    required this.selected,
    this.active = false,
    required this.dragSelectionActive,
    required this.onTap,
    required this.onDragStart,
    required this.onDragEnter,
    required this.onDragEnd,
    this.onDoubleTap,
    required this.onPrepareMenuSelection,
    required this.cells,
    required this.menuItems,
    this.editableColumns = const <int>{},
  });

  @override
  State<_BankTableRow> createState() => _BankTableRowState();
}

class _BankTableRowState extends State<_BankTableRow> {
  bool _hovering = false;
  int? _hoveredEditableColumn;

  Future<void> _openContextMenuAt(Offset globalPosition) async {
    final action = await showEditableGridContextMenu<_BankRowMenuAction>(
      context: context,
      globalPosition: globalPosition,
      entries: [
        for (final item in widget.menuItems)
          ContractMenuEntry<_BankRowMenuAction>(value: item, label: item.label),
      ],
    );
    action?.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final softenDividers = _hoveredEditableColumn != null;
    final rowContentWidth = widget.cells.fold<double>(
      _kBankActionsW,
      (sum, cell) => sum + cell.width,
    );
    final background = widget.selected
        ? tokens.primaryStrong.withValues(alpha: widget.active ? 0.26 : 0.20)
        : _hovering
        ? const Color(0xE01D222B)
        : const Color(0xCC171B23);

    Widget buildCell(int index, _BankTableCell cell) {
      final editable = widget.editableColumns.contains(index);
      final hoveredEditable = editable && _hoveredEditableColumn == index;
      final content = Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ContractEditableHoverCapsule(
              hovered: hoveredEditable,
              selectedContext: false,
              child: cell.child,
            ),
          ),
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
      final cellChild = SizedBox(width: cell.width, child: content);
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
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: widget.active
                ? tokens.primaryStrong.withValues(alpha: 0.90)
                : widget.selected
                ? tokens.primaryStrong.withValues(alpha: 0.74)
                : Colors.white.withValues(alpha: 0.14),
            width: widget.active
                ? 1.7
                : widget.selected
                ? 1.3
                : 1,
          ),
        ),
        shadowColor: widget.selected
            ? tokens.primaryStrong.withValues(alpha: 0.22)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          borderRadius: BorderRadius.circular(18),
                          onTap: widget.onTap,
                          onDoubleTap: widget.onDoubleTap,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: rowContentWidth,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < widget.cells.length; i++)
                                    buildCell(i, widget.cells[i]),
                                  AnchoredActionSlot(
                                    width: _kBankActionsW,
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
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: widget.selected
                                              ? tokens.primaryStrong.withValues(
                                                  alpha: 0.62,
                                                )
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
                                            _BankRowMenuAction
                                          >(
                                            tooltip: 'Acciones',
                                            iconColor: widget.selected
                                                ? Colors.white.withValues(
                                                    alpha: 0.96,
                                                  )
                                                : null,
                                            entries: [
                                              for (final item
                                                  in widget.menuItems)
                                                ContractMenuEntry<
                                                  _BankRowMenuAction
                                                >(
                                                  value: item,
                                                  label: item.label,
                                                ),
                                            ],
                                            onSelected: (item) {
                                              widget.onPrepareMenuSelection();
                                              item.onTap();
                                            },
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

class _BankRowMenuAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _BankRowMenuAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class _BankDetailsEvidenceBlock extends StatelessWidget {
  final List<FinanzasEvidenceRecord> evidences;
  final String Function(DateTime value) dateFormatter;
  final Future<void> Function(String url, String fileName) onOpenEvidence;

  const _BankDetailsEvidenceBlock({
    required this.evidences,
    required this.dateFormatter,
    required this.onOpenEvidence,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return FinanzasGlassPanel(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      borderRadius: BorderRadius.circular(20),
      fillColor: const Color(0x14161A22),
      borderColor: Colors.white.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evidencias',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: tokens.badgeText,
            ),
          ),
          const SizedBox(height: 10),
          if (evidences.isEmpty)
            const Text(
              'Sin evidencias.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kFinanzasInk,
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < evidences.length; i++) ...[
                  Row(
                    children: [
                      Icon(
                        evidences[i].fileName.toLowerCase().endsWith('.pdf')
                            ? Icons.picture_as_pdf_outlined
                            : Icons.photo_library_outlined,
                        size: 18,
                        color: tokens.primaryStrong,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              evidences[i].fileName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: kFinanzasInk,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${dateFormatter(evidences[i].uploadedAt)} · ${evidences[i].uploadedByName.isEmpty ? 'Usuario' : evidences[i].uploadedByName}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kFinanzasMutedInk,
                              ),
                            ),
                            if (evidences[i].comment.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  evidences[i].comment.trim(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: kFinanzasMutedInk,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => unawaited(
                          onOpenEvidence(
                            evidences[i].fileUrl,
                            evidences[i].fileName,
                          ),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Descargar'),
                      ),
                    ],
                  ),
                  if (i != evidences.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _FinBankEmptyPane extends StatelessWidget {
  const _FinBankEmptyPane();

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
              Icons.account_balance_outlined,
              size: 34,
              color: tokens.primaryStrong,
            ),
            const SizedBox(height: 12),
            Text(
              'Sin movimientos bancarios',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra el primer movimiento libre, pago a proveedor o cobro de cliente desde aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinBankBackground extends StatelessWidget {
  const _FinBankBackground();

  @override
  Widget build(BuildContext context) => const FinanzasAreaBackground();
}

String _bankSourceTypeLabel(String value) {
  switch (value) {
    case 'COMPRA_FACTURA':
      return 'Factura proveedor';
    case 'VENTA_FACTURA':
      return 'Pago cliente';
    case 'PAGO_FIJO':
      return 'Pago fijo';
    case 'MANUAL':
    default:
      return 'Movimiento libre';
  }
}

String _formatBankMoney(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts.first;
  final fraction = parts[1];
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final reverseIndex = whole.length - i;
    buffer.write(whole[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return '\$${buffer.toString()}.$fraction';
}

class _FinBankHeaderBrand extends StatelessWidget {
  const _FinBankHeaderBrand();

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
          'Cuentas Bancarias',
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

class _FinBankHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _FinBankHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_FinBankHeaderButton> createState() => _FinBankHeaderButtonState();
}

class _FinBankHeaderButtonState extends State<_FinBankHeaderButton> {
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

class _FinBankSidePanel extends StatelessWidget {
  final bool canReturnToDirection;
  final bool canAccessComprasArea;
  final ValueChanged<String> onNavigate;

  const _FinBankSidePanel({
    required this.canReturnToDirection,
    required this.canAccessComprasArea,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return FinanzasAreaSidePanel(
      currentLabel: 'Cuentas Bancarias',
      canReturnToDirection: canReturnToDirection,
      canAccessComprasArea: canAccessComprasArea,
      onNavigate: onNavigate,
    );
  }
}
