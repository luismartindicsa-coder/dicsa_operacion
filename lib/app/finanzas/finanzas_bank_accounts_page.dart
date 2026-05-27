import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../compras/compras_dashboard_page.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/contract_popup_surface.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/editable_hover_capsule.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import '../shared/utils/number_formatters.dart';
import 'finanzas_bank_accounts_store.dart';
import 'finanzas_company_directory_page.dart';
import 'finanzas_data_store.dart';
import 'finanzas_dashboard_page.dart';
import 'finanzas_provider_accounts_page.dart';
import 'finanzas_provider_accounts_store.dart';
import 'finanzas_theme.dart';

const double _kBankDateW = 110;
const double _kBankCompanyW = 100;
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

class FinanzasBankAccountsPage extends StatefulWidget {
  final bool instantOpen;

  const FinanzasBankAccountsPage({super.key, this.instantOpen = false});

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
  final FocusNode _rowsFocusNode = FocusNode(debugLabel: 'bankRows');
  DateTimeRange? _dateRangeFilter;
  Set<String> _companyFilters = <String>{};
  Set<String> _branchFilters = <String>{};
  Set<String> _nameFilters = <String>{};
  Set<String> _categoryFilters = <String>{};
  Set<String> _referenceFilters = <String>{};
  Set<String> _creditFilters = <String>{};
  Set<String> _debitFilters = <String>{};
  String? _selectedRowId;
  List<FinanzasBankMovementRecord> _rows = const <FinanzasBankMovementRecord>[];
  List<FinanzasCatalogCompanyRecord> _companies =
      const <FinanzasCatalogCompanyRecord>[];
  List<FinanzasSupplierInvoiceRecord> _supplierInvoices =
      const <FinanzasSupplierInvoiceRecord>[];
  List<FinanzasClientPaymentAccountRecord> _clientAccounts =
      const <FinanzasClientPaymentAccountRecord>[];

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadPage());
  }

  @override
  void dispose() {
    _rowsFocusNode.dispose();
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
    ]);
    if (!mounted) return;
    final movements = results[0] as List<FinanzasBankMovementRecord>;
    final snapshot = results[1] as FinanzasCatalogSnapshot;
    final invoices = results[2] as List<FinanzasSupplierInvoiceRecord>;
    final clientAccounts =
        results[3] as List<FinanzasClientPaymentAccountRecord>;
    setState(() {
      _rows = movements;
      _companies = snapshot.companies
          .where((row) => row.active)
          .toList(growable: false);
      _supplierInvoices = invoices
          .where((row) => row.status != 'PAGADA')
          .toList(growable: false);
      _clientAccounts = clientAccounts;
      _syncSelectionWithVisibleRows();
      _loading = false;
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
      case 'Directorio Empresas':
        unawaited(_openDirectory());
        return;
      case 'Cuentas por Proveedor':
        unawaited(_openProviderAccounts());
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

  Future<void> _pickCompanyFilter() async {
    final options = [
      const _SimpleOption(
        id: '__all__',
        label: 'Todas',
        subtitle: 'Quitar filtro',
      ),
      ..._sortedDistinct(
        _rows.map((row) => row.company),
      ).map((value) => _SimpleOption(id: value, label: value, subtitle: '')),
    ];
    final selected = await _showSimpleOptionsDialog(
      context: context,
      title: 'Filtrar empresa',
      options: options,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _companyFilters = selected.id == '__all__'
          ? <String>{}
          : <String>{selected.id};
      _syncSelectionWithVisibleRows();
    });
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
      });
      return;
    }
    setState(() {
      _dateRangeFilter = picked;
      _syncSelectionWithVisibleRows();
    });
  }

  Future<void> _pickBranchFilter() async {
    final options = [
      const _SimpleOption(
        id: '__all__',
        label: 'Todas',
        subtitle: 'Quitar filtro',
      ),
      ..._sortedDistinct(
        _rows.map((row) => row.branch),
      ).map((value) => _SimpleOption(id: value, label: value, subtitle: '')),
    ];
    final selected = await _showSimpleOptionsDialog(
      context: context,
      title: 'Filtrar cuenta',
      options: options,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _branchFilters = selected.id == '__all__'
          ? <String>{}
          : <String>{selected.id};
      _syncSelectionWithVisibleRows();
    });
  }

  Future<void> _pickNameFilter() async {
    final options = [
      const _SimpleOption(
        id: '__all__',
        label: 'Todos',
        subtitle: 'Quitar filtro',
      ),
      ..._sortedDistinct(
        _rows.map((row) => row.counterpartyNameSnapshot),
      ).map((value) => _SimpleOption(id: value, label: value, subtitle: '')),
    ];
    final selected = await _showSimpleOptionsDialog(
      context: context,
      title: 'Filtrar nombre',
      options: options,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _nameFilters = selected.id == '__all__'
          ? <String>{}
          : <String>{selected.id};
      _syncSelectionWithVisibleRows();
    });
  }

  Future<void> _pickCategoryFilter() async {
    final options = [
      const _SimpleOption(
        id: '__all__',
        label: 'Todas',
        subtitle: 'Quitar filtro',
      ),
      ..._sortedDistinct(
        _rows.map((row) => row.category),
      ).map((value) => _SimpleOption(id: value, label: value, subtitle: '')),
    ];
    final selected = await _showSimpleOptionsDialog(
      context: context,
      title: 'Filtrar categoría',
      options: options,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _categoryFilters = selected.id == '__all__'
          ? <String>{}
          : <String>{selected.id};
      _syncSelectionWithVisibleRows();
    });
  }

  Future<void> _pickReferenceFilter() async {
    final options = [
      const _SimpleOption(
        id: '__all__',
        label: 'Todas',
        subtitle: 'Quitar filtro',
      ),
      ..._sortedDistinct(
        _rows.map((row) => row.reference),
      ).map((value) => _SimpleOption(id: value, label: value, subtitle: '')),
    ];
    final selected = await _showSimpleOptionsDialog(
      context: context,
      title: 'Filtrar referencia',
      options: options,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _referenceFilters = selected.id == '__all__'
          ? <String>{}
          : <String>{selected.id};
      _syncSelectionWithVisibleRows();
    });
  }

  Future<void> _pickCreditFilter() async {
    final options = [
      const _SimpleOption(
        id: '__all__',
        label: 'Todos',
        subtitle: 'Quitar filtro',
      ),
      ..._sortedDistinct(
        _rows.map((row) => row.creditAmount.toStringAsFixed(2)),
      ).map(
        (value) => _SimpleOption(
          id: value,
          label: _money(double.tryParse(value) ?? 0),
          subtitle: '',
        ),
      ),
    ];
    final selected = await _showSimpleOptionsDialog(
      context: context,
      title: 'Filtrar abono',
      options: options,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _creditFilters = selected.id == '__all__'
          ? <String>{}
          : <String>{selected.id};
      _syncSelectionWithVisibleRows();
    });
  }

  Future<void> _pickDebitFilter() async {
    final options = [
      const _SimpleOption(
        id: '__all__',
        label: 'Todos',
        subtitle: 'Quitar filtro',
      ),
      ..._sortedDistinct(
        _rows.map((row) => row.debitAmount.toStringAsFixed(2)),
      ).map(
        (value) => _SimpleOption(
          id: value,
          label: _money(double.tryParse(value) ?? 0),
          subtitle: '',
        ),
      ),
    ];
    final selected = await _showSimpleOptionsDialog(
      context: context,
      title: 'Filtrar cargo',
      options: options,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _debitFilters = selected.id == '__all__'
          ? <String>{}
          : <String>{selected.id};
      _syncSelectionWithVisibleRows();
    });
  }

  Future<void> _openNewMovementDialog() async {
    final draft = await showDialog<_BankMovementDraft>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _NewBankMovementDialog(
        companies: _companies,
        supplierInvoices: _supplierInvoices,
        clientAccounts: _clientAccounts,
      ),
    );
    if (draft == null) return;
    await _saveDraft(draft);
  }

  Future<void> _openEditMovementDialog(FinanzasBankMovementRecord row) async {
    if (row.sourceType != 'MANUAL') {
      _toast('Solo los movimientos libres se pueden editar.');
      return;
    }
    final draft = await showDialog<_BankMovementDraft>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _NewBankMovementDialog(
        companies: _companies,
        supplierInvoices: _supplierInvoices,
        clientAccounts: _clientAccounts,
        existingRow: row,
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
      linkedSupplierInvoiceId: draft.linkedSupplierInvoice?.id,
      linkedExternalRef: draft.linkedClientAccount?.id,
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

  void _handleRowTap(String rowId) {
    setState(() => _selectedRowId = rowId);
    _rowsFocusNode.requestFocus();
  }

  void _clearRowSelection() {
    if (_selectedRowId == null) return;
    setState(() => _selectedRowId = null);
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
    final id = _selectedRowId;
    if (id == null) return;
    final exists = _visibleRows.any((row) => row.id == id);
    if (!exists) _selectedRowId = null;
  }

  KeyEventResult _handleRowsKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final rows = _visibleRows;
    if (rows.isEmpty) return KeyEventResult.ignored;
    final currentIndex = _selectedRowId == null
        ? -1
        : rows.indexWhere((row) => row.id == _selectedRowId);
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final nextIndex = currentIndex < 0
          ? 0
          : (currentIndex + 1).clamp(0, rows.length - 1);
      setState(() => _selectedRowId = rows[nextIndex].id);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final nextIndex = currentIndex <= 0 ? 0 : currentIndex - 1;
      setState(() => _selectedRowId = rows[nextIndex].id);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _clearRowSelection();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final row = _selectedRow;
      if (row != null) {
        unawaited(_openMovementDetails(row));
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _openMovementDetails(FinanzasBankMovementRecord row) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _BankMovementDetailsDialog(
        row: row,
        moneyFormatter: _money,
        dateFormatter: _dateLabel,
      ),
    );
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
    for (final company in kFinBankCompanies) {
      for (final branch in kFinBankBranches) {
        final key = buildFinBankAccountKey(company: company, branch: branch);
        totals.putIfAbsent(
          key,
          () => _BankAccountTotals.empty(company, branch),
        );
      }
    }
    return totals;
  }

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
                        : ContractGlassCard(
                            borderRadius: BorderRadius.circular(30),
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    2,
                                    2,
                                    2,
                                    10,
                                  ),
                                  child: _BankTopBar(
                                    exportingCsv: _exportingCsv,
                                    selectedCount: _selectedRow == null ? 0 : 1,
                                    onExportCsv: _exportingCsv
                                        ? null
                                        : _exportCsv,
                                    onCreate: _openNewMovementDialog,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _BankAccountsTotalsRow(
                                  totals: _accountTotals.values.toList(
                                    growable: false,
                                  ),
                                  moneyFormatter: _money,
                                ),
                                const SizedBox(height: 12),
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
                                            for (final value
                                                in _categoryFilters)
                                              'Categoría: $value',
                                            for (final value
                                                in _referenceFilters)
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
                                                  _referenceFilters =
                                                      <String>{};
                                                  _creditFilters = <String>{};
                                                  _debitFilters = <String>{};
                                                  _syncSelectionWithVisibleRows();
                                                }),
                                        ),
                                        const SizedBox(height: 10),
                                        _BankHeaderRow(
                                          onDateFilter: _pickDateFilter,
                                          onCompanyFilter: _pickCompanyFilter,
                                          onBranchFilter: _pickBranchFilter,
                                          onNameFilter: _pickNameFilter,
                                          onCategoryFilter: _pickCategoryFilter,
                                          onReferenceFilter:
                                              _pickReferenceFilter,
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
                                          child: Focus(
                                            focusNode: _rowsFocusNode,
                                            onKeyEvent: (_, event) =>
                                                _handleRowsKeyEvent(event),
                                            child: _visibleRows.isEmpty
                                                ? const _FinBankEmptyPane()
                                                : _BankMovementsGrid(
                                                    rows: _visibleRows,
                                                    selectedRowId:
                                                        _selectedRowId,
                                                    moneyFormatter: _money,
                                                    dateFormatter: _dateLabel,
                                                    onRowTap: _handleRowTap,
                                                    onOpenDetails:
                                                        _openMovementDetails,
                                                    onCopyReference: (value) {
                                                      Clipboard.setData(
                                                        ClipboardData(
                                                          text: value,
                                                        ),
                                                      );
                                                      _toast(
                                                        'Referencia copiada.',
                                                      );
                                                    },
                                                    onCopyName: (value) {
                                                      Clipboard.setData(
                                                        ClipboardData(
                                                          text: value,
                                                        ),
                                                      );
                                                      _toast('Nombre copiado.');
                                                    },
                                                    onEdit:
                                                        _openEditMovementDialog,
                                                  ),
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
  final String Function(double value) moneyFormatter;
  final String Function(DateTime value) dateFormatter;
  final ValueChanged<String> onRowTap;
  final ValueChanged<FinanzasBankMovementRecord> onOpenDetails;
  final ValueChanged<String> onCopyReference;
  final ValueChanged<String> onCopyName;
  final ValueChanged<FinanzasBankMovementRecord> onEdit;

  const _BankMovementsGrid({
    required this.rows,
    required this.selectedRowId,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onRowTap,
    required this.onOpenDetails,
    required this.onCopyReference,
    required this.onCopyName,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final row = rows[index];
        return _BankTableRow(
          rowKey: row.id,
          selected: selectedRowId == row.id,
          onTap: () => onRowTap(row.id),
          onDoubleTap: () => onOpenDetails(row),
          menuItems: [
            if (row.sourceType == 'MANUAL')
              _BankRowMenuAction(
                label: 'Editar',
                icon: Icons.edit_outlined,
                onTap: () => onEdit(row),
              ),
            _BankRowMenuAction(
              label: 'Ver detalle',
              icon: Icons.visibility_outlined,
              onTap: () => onOpenDetails(row),
            ),
            _BankRowMenuAction(
              label: 'Copiar nombre',
              icon: Icons.badge_outlined,
              onTap: () => onCopyName(row.counterpartyNameSnapshot),
            ),
            _BankRowMenuAction(
              label: 'Copiar referencia',
              icon: Icons.copy_rounded,
              onTap: () => onCopyReference(row.reference),
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
              text: moneyFormatter(row.creditAmount),
              positive: true,
            ),
            _BankTableCell.money(
              width: _kBankDebitW,
              text: moneyFormatter(row.debitAmount),
              positive: false,
            ),
          ],
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
  });
}

class _NewBankMovementDialog extends StatefulWidget {
  final List<FinanzasCatalogCompanyRecord> companies;
  final List<FinanzasSupplierInvoiceRecord> supplierInvoices;
  final List<FinanzasClientPaymentAccountRecord> clientAccounts;
  final FinanzasBankMovementRecord? existingRow;

  const _NewBankMovementDialog({
    required this.companies,
    required this.supplierInvoices,
    required this.clientAccounts,
    this.existingRow,
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

  @override
  void initState() {
    super.initState();
    _commentC = TextEditingController();
    _referenceC = TextEditingController();
    _creditC = TextEditingController();
    _debitC = TextEditingController();
    final existing = widget.existingRow;
    if (existing != null) {
      _date = DateUtils.dateOnly(existing.date);
      _sourceType = existing.sourceType;
      _company = existing.company;
      _branch = existing.branch;
      _counterpartyCompanyId = existing.counterpartyCompanyId;
      _counterpartyName = existing.counterpartyNameSnapshot;
      _category = existing.category;
      _commentC.text = existing.comment;
      _referenceC.text = existing.reference;
      _creditC.text = existing.creditAmount > 0
          ? formatDecimal(existing.creditAmount, decimals: 2)
          : '';
      _debitC.text = existing.debitAmount > 0
          ? formatDecimal(existing.debitAmount, decimals: 2)
          : '';
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return AreaThemeScope(
          tokens: finanzasAreaTokens,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: finanzasAreaTokens.primaryStrong,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: kFinanzasInk,
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
    if (_sourceType == 'COMPRA_FACTURA' && _selectedSupplierInvoice == null) {
      return false;
    }
    if (_sourceType == 'VENTA_FACTURA' && _selectedClientAccount == null) {
      return false;
    }
    return true;
  }

  void _handleSourceChanged(String value) {
    setState(() {
      _sourceType = value;
      if (value == 'COMPRA_FACTURA') {
        _category = 'COMPRA DE MATERIAL';
      } else if (value == 'VENTA_FACTURA') {
        _category = 'VENTAS';
      } else {
        _selectedSupplierInvoiceId = null;
        _selectedClientAccountId = null;
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
  }

  void _applySupplierInvoice(FinanzasSupplierInvoiceRecord invoice) {
    setState(() {
      _selectedSupplierInvoiceId = invoice.id;
      _selectedClientAccountId = null;
      _counterpartyCompanyId = invoice.providerId;
      _counterpartyName = invoice.providerNameSnapshot;
      _category = 'COMPRA DE MATERIAL';
      _referenceC.text = invoice.folio;
      _creditC.text = '';
      _debitC.text = invoice.balanceAmount.toStringAsFixed(2);
    });
  }

  void _applyClientAccount(FinanzasClientPaymentAccountRecord account) {
    setState(() {
      _selectedClientAccountId = account.id;
      _selectedSupplierInvoiceId = null;
      _counterpartyCompanyId = account.clientId;
      _counterpartyName = account.clientName;
      _category = 'VENTAS';
      _referenceC.text = account.documentNumber;
      _creditC.text = account.pendingBalance.toStringAsFixed(2);
      _debitC.text = '';
    });
  }

  Future<void> _pickCounterparty() async {
    final selected = await showDialog<FinanzasCatalogCompanyRecord>(
      context: context,
      builder: (_) => _CounterpartyPickerDialog(companies: widget.companies),
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

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: ContractGlassCard(
          borderRadius: BorderRadius.circular(30),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 820),
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
                            _isEditing
                                ? 'Ajusta los datos del movimiento libre seleccionado.'
                                : 'Captura un movimiento libre, pago a proveedor o cobro de cliente.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kFinanzasMutedInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tokens.border.withValues(alpha: 0.82),
                        ),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: tokens.primaryStrong,
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
                        _BankDialogSectionTitle(
                          step: '1',
                          title: 'Identidad',
                          subtitle: 'Define origen, fecha y cuenta bancaria.',
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _ChoiceChipField(
                                label: 'Origen',
                                value: _bankSourceTypeLabel(_sourceType),
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
                                                label: 'Factura proveedor',
                                                subtitle:
                                                    'Paga una factura de compras mayoreo',
                                              ),
                                              _SimpleOption(
                                                id: 'VENTA_FACTURA',
                                                label: 'Pago cliente',
                                                subtitle:
                                                    'Registra el cobro de una cuenta de ventas mayoreo',
                                              ),
                                            ],
                                          );
                                          if (selected == null) return;
                                          _handleSourceChanged(selected.id);
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
                                          options: kFinBankCompanies
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
                                    setState(() => _company = selected.id);
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
                                          options: kFinBankBranches
                                              .map(
                                                (row) => _SimpleOption(
                                                  id: row,
                                                  label: row,
                                                  subtitle: 'Sucursal bancaria',
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
                                      value: _selectedSupplierInvoice == null
                                          ? 'Seleccionar factura'
                                          : '${_selectedSupplierInvoice!.providerNameSnapshot} · ${_selectedSupplierInvoice!.folio}',
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
                                      value: _selectedClientAccount == null
                                          ? 'Seleccionar cuenta por cobrar'
                                          : '${_selectedClientAccount!.clientName} · ${_selectedClientAccount!.documentNumber}',
                                      onTap: () {
                                        unawaited(() async {
                                          final selected =
                                              await showDialog<
                                                FinanzasClientPaymentAccountRecord
                                              >(
                                                context: context,
                                                builder: (_) =>
                                                    _ClientPaymentPickerDialog(
                                                      accounts:
                                                          widget.clientAccounts,
                                                    ),
                                              );
                                          if (selected == null) return;
                                          _applyClientAccount(selected);
                                        }());
                                      },
                                    )
                                  : _ChoiceChipField(
                                      label: 'Nombre',
                                      value: _counterpartyName.isEmpty
                                          ? 'Seleccionar nombre'
                                          : _counterpartyName,
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
                                          options: kFinBankCategories
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
                                    setState(() => _category = selected.id);
                                  }());
                                },
                              ),
                            ),
                          ],
                        ),
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
                                decoration: contractGlassFieldDecoration(
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: const [
                                  _BankMoneyInputFormatter(),
                                ],
                                decoration: contractGlassFieldDecoration(
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: const [
                                  _BankMoneyInputFormatter(),
                                ],
                                decoration: contractGlassFieldDecoration(
                                  context,
                                  hintText: 'Cargo',
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
                          minLines: 3,
                          maxLines: 4,
                          decoration: contractGlassFieldDecoration(
                            context,
                            hintText: 'Comentario del movimiento',
                            prefixIcon: const Icon(Icons.note_alt_outlined),
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
                        side: BorderSide(
                          color: tokens.primaryStrong.withValues(alpha: 0.42),
                        ),
                        minimumSize: const Size(148, 52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
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
                        disabledBackgroundColor: tokens.primarySoft.withValues(
                          alpha: 0.46,
                        ),
                        disabledForegroundColor: Colors.white.withValues(
                          alpha: 0.82,
                        ),
                        minimumSize: const Size(220, 52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
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
                                  counterpartyCompanyId: _counterpartyCompanyId,
                                  counterpartyName: _counterpartyName.trim(),
                                  category: _category,
                                  comment: _commentC.text.trim(),
                                  reference: _referenceC.text.trim(),
                                  creditAmount: _parseAmount(_creditC.text),
                                  debitAmount: _parseAmount(_debitC.text),
                                  sourceType: _sourceType,
                                  linkedSupplierInvoice:
                                      _selectedSupplierInvoice,
                                  linkedClientAccount: _selectedClientAccount,
                                ),
                              );
                            },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar movimiento'),
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

class _CounterpartyPickerDialog extends StatefulWidget {
  final List<FinanzasCatalogCompanyRecord> companies;

  const _CounterpartyPickerDialog({required this.companies});

  @override
  State<_CounterpartyPickerDialog> createState() =>
      _CounterpartyPickerDialogState();
}

class _CounterpartyPickerDialogState extends State<_CounterpartyPickerDialog> {
  final TextEditingController _searchC = TextEditingController();

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

  void _refresh() => setState(() {});

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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: ContractGlassCard(
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
            child: Column(
              children: [
                TextField(
                  controller: _searchC,
                  autofocus: true,
                  decoration: contractGlassFieldDecoration(
                    context,
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
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        tileColor: Colors.white.withValues(alpha: 0.72),
                        title: Text(
                          row.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(row.source),
                        onTap: () => Navigator.of(context).pop(row),
                      );
                    },
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

class _SupplierInvoicePickerDialog extends StatefulWidget {
  final List<FinanzasSupplierInvoiceRecord> invoices;

  const _SupplierInvoicePickerDialog({required this.invoices});

  @override
  State<_SupplierInvoicePickerDialog> createState() =>
      _SupplierInvoicePickerDialogState();
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

  void _refresh() => setState(() {});

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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: ContractGlassCard(
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
            child: Column(
              children: [
                TextField(
                  controller: _searchC,
                  autofocus: true,
                  decoration: contractGlassFieldDecoration(
                    context,
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
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        tileColor: Colors.white.withValues(alpha: 0.72),
                        title: Text(
                          row.clientName,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${row.documentNumber.isEmpty ? 'Sin referencia' : row.documentNumber} · ${_formatBankMoney(row.pendingBalance)} por cobrar',
                        ),
                        onTap: () => Navigator.of(context).pop(row),
                      );
                    },
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

class _SupplierInvoicePickerDialogState
    extends State<_SupplierInvoicePickerDialog> {
  final TextEditingController _searchC = TextEditingController();

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

  void _refresh() => setState(() {});

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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: ContractGlassCard(
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
            child: Column(
              children: [
                TextField(
                  controller: _searchC,
                  autofocus: true,
                  decoration: contractGlassFieldDecoration(
                    context,
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
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        tileColor: Colors.white.withValues(alpha: 0.72),
                        title: Text(
                          '${row.providerNameSnapshot} · ${row.folio}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${finSupplierInvoiceStatusLabel(row.status)} · saldo ${_money(row.balanceAmount)}',
                        ),
                        onTap: () => Navigator.of(context).pop(row),
                      );
                    },
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
  return showDialog<_SimpleOption>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: ContractGlassCard(
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
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
                Expanded(
                  child: ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final row = options[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        tileColor: Colors.white.withValues(alpha: 0.72),
                        title: Text(
                          row.label,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: row.subtitle.trim().isEmpty
                            ? null
                            : Text(row.subtitle),
                        onTap: () => Navigator.of(context).pop(row),
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
      DateTime displayMonth = DateTime(
        (initialRange?.start ?? firstDate).year,
        (initialRange?.start ?? firstDate).month,
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

  const _ChoiceChipField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 250,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.border.withValues(alpha: 0.9)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: tokens.badgeText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 2,
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
    final tokens = AreaThemeScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.82),
                tokens.surfaceTint.withValues(alpha: 0.48),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: child,
          ),
        ),
      ),
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
              color: tokens.badgeBackground.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tokens.border.withValues(alpha: 0.70)),
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
    return Card(
      elevation: 0,
      color: Colors.black.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: tokens.badgeText,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final total in totals)
          _BankAccountTotalCard(total: total, moneyFormatter: moneyFormatter),
      ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.primaryStrong,
                  backgroundColor: Colors.white.withValues(alpha: 0.44),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
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
    return Container(
      width: 250,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.border.withValues(alpha: 0.84)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${total.company} ${total.branch}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Abonos ${moneyFormatter(total.credit)}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F766E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cargos ${moneyFormatter(total.debit)}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFFB42318),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Neto ${moneyFormatter(net)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: net >= 0 ? const Color(0xFF0F766E) : tokens.primaryStrong,
            ),
          ),
        ],
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
        maxLines: 2,
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
  }) {
    return _BankTableCell._(
      width: width,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          color: positive ? const Color(0xFF0F766E) : const Color(0xFFB42318),
        ),
      ),
    );
  }
}

class _BankTableRow extends StatefulWidget {
  final String rowKey;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final List<_BankTableCell> cells;
  final List<_BankRowMenuAction> menuItems;
  final Set<int> editableColumns;

  const _BankTableRow({
    required this.rowKey,
    required this.selected,
    required this.onTap,
    this.onDoubleTap,
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
    final tokens = AreaThemeScope.of(context);
    final action = await showMenu<_BankRowMenuAction>(
      context: context,
      color: finanzasAreaTokens.surfaceTint.withValues(alpha: 0.98),
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.70)),
      ),
      items: [
        for (final item in widget.menuItems)
          PopupMenuItem<_BankRowMenuAction>(
            value: item,
            child: Row(
              children: [
                Icon(item.icon, color: tokens.primaryStrong, size: 18),
                const SizedBox(width: 10),
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kFinanzasInk,
                  ),
                ),
              ],
            ),
          ),
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
        ? tokens.badgeBackground.withValues(alpha: 0.94)
        : _hovering
        ? Colors.white.withValues(alpha: 0.84)
        : Colors.white.withValues(alpha: 0.66);

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
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Card(
        elevation: 0,
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: widget.selected
                ? tokens.primaryStrong.withValues(alpha: 0.52)
                : tokens.border.withValues(alpha: 0.72),
          ),
        ),
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
                      unawaited(_openContextMenuAt(details.globalPosition));
                    },
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
                                  trailing: PopupMenuButton<_BankRowMenuAction>(
                                    tooltip: 'Acciones',
                                    padding: EdgeInsets.zero,
                                    color: finanzasAreaTokens.surfaceTint
                                        .withValues(alpha: 0.98),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.70,
                                        ),
                                      ),
                                    ),
                                    onSelected: (item) => item.onTap(),
                                    itemBuilder: (context) => [
                                      for (final item in widget.menuItems)
                                        PopupMenuItem<_BankRowMenuAction>(
                                          value: item,
                                          child: Row(
                                            children: [
                                              Icon(
                                                item.icon,
                                                color: tokens.primaryStrong,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                item.label,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: kFinanzasInk,
                                                ),
                                              ),
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
                                            : Colors.white.withValues(
                                                alpha: 0.88,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: widget.selected
                                              ? tokens.primaryStrong.withValues(
                                                  alpha: 0.36,
                                                )
                                              : tokens.border.withValues(
                                                  alpha: 0.82,
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
                                      child: Center(
                                        child: Icon(
                                          Icons.more_horiz_rounded,
                                          color: tokens.primaryStrong,
                                          size: 20,
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

class _BankMovementDetailsDialog extends StatelessWidget {
  final FinanzasBankMovementRecord row;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime value) dateFormatter;

  const _BankMovementDetailsDialog({
    required this.row,
    required this.moneyFormatter,
    required this.dateFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: ContractGlassCard(
          borderRadius: BorderRadius.circular(30),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
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
                            row.counterpartyNameSnapshot,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: tokens.primaryStrong,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Detalle del movimiento bancario',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: kFinanzasMutedInk,
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
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _BankDetailsStat(
                      label: 'Fecha',
                      value: dateFormatter(row.date),
                    ),
                    _BankDetailsStat(label: 'Empresa', value: row.company),
                    _BankDetailsStat(label: 'Cuenta', value: row.branch),
                    _BankDetailsStat(label: 'Categoría', value: row.category),
                    _BankDetailsStat(
                      label: 'Abono',
                      value: moneyFormatter(row.creditAmount),
                    ),
                    _BankDetailsStat(
                      label: 'Cargo',
                      value: moneyFormatter(row.debitAmount),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _BankDetailsBlock(label: 'Referencia', value: row.reference),
                const SizedBox(height: 12),
                _BankDetailsBlock(label: 'Comentario', value: row.comment),
                const SizedBox(height: 12),
                _BankDetailsBlock(
                  label: 'Origen',
                  value: _bankSourceTypeLabel(row.sourceType),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
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

class _BankDetailsStat extends StatelessWidget {
  final String label;
  final String value;

  const _BankDetailsStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      width: 160,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.border.withValues(alpha: 0.84)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: tokens.badgeText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _BankDetailsBlock extends StatelessWidget {
  final String label;
  final String value;

  const _BankDetailsBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.border.withValues(alpha: 0.84)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: tokens.badgeText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value.trim().isEmpty ? '—' : value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kFinanzasInk,
              height: 1.4,
            ),
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
      child: Container(
        width: 420,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: tokens.primaryStrong.withValues(alpha: 0.10),
          ),
        ),
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
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF7E5E2), Color(0xFFD45A52), Color(0xFF241313)],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: -260,
          top: -130,
          child: _FinBankBackgroundCircle(760, [
            const Color(0xFFFFF6F4),
            const Color(0xFFF2C0BC),
          ]),
        ),
        Positioned(
          right: -180,
          top: -70,
          child: _FinBankBackgroundCircle(580, [
            const Color(0xFFBC2D25),
            const Color(0x33241313),
          ]),
        ),
        Positioned(
          left: 20,
          bottom: -260,
          child: _FinBankBackgroundCircle(640, [
            const Color(0x66241313),
            const Color(0xFFFBE8E6),
          ]),
        ),
        Positioned(
          right: -105,
          bottom: -120,
          child: IgnorePointer(
            child: Container(
              width: 320,
              height: 500,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(220),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF241313), Color(0xFFBC2D25)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _bankSourceTypeLabel(String value) {
  switch (value) {
    case 'COMPRA_FACTURA':
      return 'Factura proveedor';
    case 'VENTA_FACTURA':
      return 'Pago cliente';
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

class _FinBankBackgroundCircle extends StatelessWidget {
  final double diameter;
  final List<Color> colors;

  const _FinBankBackgroundCircle(this.diameter, this.colors);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: colors),
          boxShadow: [
            BoxShadow(
              blurRadius: diameter * 0.10,
              spreadRadius: diameter * 0.015,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: SizedBox(width: diameter, height: diameter),
      ),
    );
  }
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
        const SizedBox(width: 10),
        Container(
          width: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: tokens.primaryStrong.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
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
    final tokens = AreaThemeScope.of(context);
    return SizedBox(
      width: 372,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: ContractGlassCard(
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Finanzas',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: tokens.primaryStrong,
                  ),
                ),
                const SizedBox(height: 16),
                if (canReturnToDirection) ...[
                  _FinBankNavItem(
                    icon: Icons.arrow_back_rounded,
                    title: 'Volver a Dirección',
                    onTap: () async => onNavigate('Dashboard Dirección'),
                  ),
                  const SizedBox(height: 10),
                ],
                const _FinBankSectionHeader(label: 'AREA'),
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
                      _FinBankNavItem(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Dashboard Finanzas',
                        subtitle: 'Pagos, liquidez y compromisos',
                        onTap: () async => onNavigate('Dashboard Finanzas'),
                      ),
                      const SizedBox(height: 8),
                      _FinBankNavItem(
                        icon: Icons.account_balance_rounded,
                        title: 'Directorio Empresas',
                        subtitle: 'Crédito, contacto y operación',
                        onTap: () async => onNavigate('Directorio Empresas'),
                      ),
                      const SizedBox(height: 8),
                      _FinBankNavItem(
                        icon: Icons.view_list_rounded,
                        title: 'Cuentas por Proveedor',
                        subtitle: 'Saldo vivo, tickets y seguimiento',
                        onTap: () async => onNavigate('Cuentas por Proveedor'),
                      ),
                      const SizedBox(height: 8),
                      _FinBankNavItem(
                        icon: Icons.account_balance_outlined,
                        title: 'Cuentas Bancarias',
                        subtitle: 'Entradas, salidas y bancos',
                        accented: true,
                        onTap: () async {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const _FinBankSectionHeader(label: 'ACCESOS'),
                const SizedBox(height: 8),
                if (canReturnToDirection) ...[
                  _FinBankNavItem(
                    icon: Icons.assessment_outlined,
                    title: 'Dashboard Dirección',
                    subtitle: 'Vista ejecutiva multiarea',
                    onTap: () async => onNavigate('Dashboard Dirección'),
                  ),
                  const SizedBox(height: 8),
                ],
                if (canAccessComprasArea)
                  _FinBankNavItem(
                    icon: Icons.shopping_cart_checkout_rounded,
                    title: 'Dashboard Compras',
                    subtitle: 'Tickets y operación de compra',
                    onTap: () async => onNavigate('Dashboard Compras'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinBankSectionHeader extends StatelessWidget {
  final String label;
  const _FinBankSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.4,
        color: tokens.badgeText,
      ),
    );
  }
}

class _FinBankNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool accented;
  final Future<void> Function()? onTap;

  const _FinBankNavItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.accented = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap == null ? null : () async => onTap!.call(),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: accented
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tokens.primaryStrong.withValues(alpha: 0.92),
                      tokens.primary.withValues(alpha: 0.94),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.70),
                      tokens.surfaceTint.withValues(alpha: 0.42),
                    ],
                  ),
            border: Border.all(
              color: accented
                  ? Colors.white.withValues(alpha: 0.34)
                  : tokens.border.withValues(alpha: 0.62),
            ),
            boxShadow: accented
                ? [
                    BoxShadow(
                      color: tokens.glow.withValues(alpha: 0.16),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accented
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.66),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accented
                        ? Colors.white.withValues(alpha: 0.18)
                        : tokens.border.withValues(alpha: 0.54),
                  ),
                ),
                child: Icon(
                  icon,
                  color: accented ? Colors.white : tokens.primaryStrong,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: accented ? Colors.white : tokens.primaryStrong,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: accented
                              ? Colors.white.withValues(alpha: 0.86)
                              : tokens.badgeText,
                        ),
                      ),
                    ],
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
