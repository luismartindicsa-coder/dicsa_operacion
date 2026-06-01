import 'dart:async';

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
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/editable_hover_capsule.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
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

const double _kFixedReceivedDateW = 120;
const double _kFixedCompanyW = 240;
const double _kFixedBranchW = 120;
const double _kFixedAmountW = 150;
const double _kFixedPaymentDateW = 120;
const double _kFixedStatusW = 130;
const double _kFixedNotesW = 260;
const double _kFixedActionsW = 72;

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

  Set<String> _companyFilters = <String>{};
  Set<String> _statusFilters = <String>{};
  String? _selectedRowId;

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
      _loading = false;
    });
  }

  void _syncSelection() {
    final visible = _visibleRows;
    if (visible.isEmpty) {
      _selectedRowId = null;
      return;
    }
    final presetId = widget.initialSelectedPaymentId;
    if (presetId != null && visible.any((row) => row.id == presetId)) {
      _selectedRowId = presetId;
      return;
    }
    if (_selectedRowId == null ||
        !visible.any((row) => row.id == _selectedRowId)) {
      _selectedRowId = visible.first.id;
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<FinanzasFixedPaymentRecord> get _visibleRows {
    return _rows
        .where((row) {
          if (_companyFilters.isNotEmpty &&
              !_companyFilters.contains(row.companyNameSnapshot)) {
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

  FinanzasFixedPaymentRecord? get _selectedRow {
    final selectedId = _selectedRowId;
    if (selectedId == null) return null;
    for (final row in _visibleRows) {
      if (row.id == selectedId) return row;
    }
    return null;
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar pago fijo'),
        content: Text(
          'Se eliminará el pago fijo de ${row.companyNameSnapshot}. ¿Continuar?',
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

  Future<void> _markPaymentPaidInCash(FinanzasFixedPaymentRecord row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pagar en efectivo'),
        content: Text(
          'Se marcará como pagado en efectivo el compromiso de ${row.companyNameSnapshot} por ${_money(row.amount)}. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar pago'),
          ),
        ],
      ),
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
          'Monto',
          'Fecha pago',
          'Estado',
          'Comentario',
        ],
        for (final row in _visibleRows)
          <String>[
            _dateLabel(row.receivedDate),
            row.companyNameSnapshot,
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

  int _selectedIndex() {
    final selectedId = _selectedRowId;
    if (selectedId == null) return -1;
    return _visibleRows.indexWhere((row) => row.id == selectedId);
  }

  void _moveSelection(int delta) {
    final rows = _visibleRows;
    if (rows.isEmpty) return;
    final currentIndex = _selectedIndex();
    final nextIndex = currentIndex < 0
        ? 0
        : (currentIndex + delta).clamp(0, rows.length - 1);
    setState(() => _selectedRowId = rows[nextIndex].id);
  }

  @override
  Widget build(BuildContext context) {
    final visibleRows = _visibleRows;
    final selectedCount = _selectedRow == null ? 0 : 1;
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
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape && _menuOpen) {
            setState(() => _menuOpen = false);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _moveSelection(1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _moveSelection(-1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            final row = _selectedRow;
            if (row != null) {
              unawaited(_editPayment(row));
              return KeyEventResult.handled;
            }
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
                              _ActionBand(
                                selectedCount: selectedCount,
                                onExport: _exportCsv,
                                onCreate: _createPayment,
                                exporting: _exportingCsv,
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _MetricCard(
                                    label: 'Mes',
                                    value: _money(totalAmount),
                                  ),
                                  _MetricCard(
                                    label: 'Pendiente',
                                    value: _money(pendingAmount),
                                  ),
                                  _MetricCard(
                                    label: 'Pagado',
                                    value: _money(paidAmount),
                                  ),
                                  _MetricCard(
                                    label: 'Vencido',
                                    value: _money(overdueAmount),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Expanded(
                                child: ContractGlassCard(
                                  borderRadius: BorderRadius.circular(30),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          _HeaderFilterChip(
                                            label: 'Empresa',
                                            active: _companyFilters.isNotEmpty,
                                            onTap: () async {
                                              final selected =
                                                  await _showMultiSelectDialog(
                                                    context: context,
                                                    title:
                                                        'Filtrar por empresa',
                                                    options:
                                                        _directCompanies
                                                            .map((e) => e.name)
                                                            .toSet()
                                                            .toList(
                                                              growable: false,
                                                            )
                                                          ..sort(),
                                                    selected: _companyFilters
                                                        .toSet(),
                                                  );
                                              if (selected == null ||
                                                  !mounted) {
                                                return;
                                              }
                                              setState(() {
                                                _companyFilters = selected;
                                                _syncSelection();
                                              });
                                            },
                                          ),
                                          _HeaderFilterChip(
                                            label: 'Estado',
                                            active: _statusFilters.isNotEmpty,
                                            onTap: () async {
                                              final selected =
                                                  await _showMultiSelectDialog(
                                                    context: context,
                                                    title: 'Filtrar por estado',
                                                    options:
                                                        kFinFixedPaymentStatuses,
                                                    selected: _statusFilters
                                                        .toSet(),
                                                    labelBuilder:
                                                        finFixedPaymentStatusLabel,
                                                  );
                                              if (selected == null ||
                                                  !mounted) {
                                                return;
                                              }
                                              setState(() {
                                                _statusFilters = selected;
                                                _syncSelection();
                                              });
                                            },
                                          ),
                                          if (_companyFilters.isNotEmpty ||
                                              _statusFilters.isNotEmpty)
                                            TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  _companyFilters.clear();
                                                  _statusFilters.clear();
                                                  _syncSelection();
                                                });
                                              },
                                              child: const Text(
                                                'Limpiar filtros',
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _GridHeaderRow(
                                        cells: const [
                                          _GridHeaderCell(
                                            width: _kFixedReceivedDateW,
                                            label: 'FECHA RECIBIDO',
                                          ),
                                          _GridHeaderCell(
                                            width: _kFixedCompanyW,
                                            label: 'EMPRESA',
                                          ),
                                          _GridHeaderCell(
                                            width: _kFixedBranchW,
                                            label: 'CUENTA',
                                          ),
                                          _GridHeaderCell(
                                            width: _kFixedAmountW,
                                            label: 'MONTO',
                                            alignEnd: true,
                                          ),
                                          _GridHeaderCell(
                                            width: _kFixedPaymentDateW,
                                            label: 'FECHA PAGO',
                                          ),
                                          _GridHeaderCell(
                                            width: _kFixedStatusW,
                                            label: 'ESTADO',
                                          ),
                                          _GridHeaderCell(
                                            width: _kFixedNotesW,
                                            label: 'COMENTARIO',
                                          ),
                                          _GridHeaderCell(
                                            width: _kFixedActionsW,
                                            label: '',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Expanded(
                                        child: visibleRows.isEmpty
                                            ? const _EmptyGridState()
                                            : Focus(
                                                focusNode: _rowsFocusNode,
                                                child: ListView.separated(
                                                  itemCount: visibleRows.length,
                                                  separatorBuilder: (_, _) =>
                                                      const SizedBox(height: 8),
                                                  itemBuilder: (_, index) {
                                                    final row =
                                                        visibleRows[index];
                                                    final selected =
                                                        row.id ==
                                                        _selectedRowId;
                                                    return _FixedPaymentRow(
                                                      row: row,
                                                      selected: selected,
                                                      moneyFormatter: _money,
                                                      dateFormatter: _dateLabel,
                                                      statusTone: _statusTone,
                                                      onTap: () => setState(
                                                        () => _selectedRowId =
                                                            row.id,
                                                      ),
                                                      onEdit: () =>
                                                          _editPayment(row),
                                                      onPayCash:
                                                          row.status == 'PAGADO'
                                                          ? null
                                                          : () =>
                                                                _markPaymentPaidInCash(
                                                                  row,
                                                                ),
                                                      onDelete: () =>
                                                          _deletePayment(row),
                                                    );
                                                  },
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
  final String branch;
  final double amount;
  final DateTime paymentDate;
  final String status;
  final String notes;

  const _FixedPaymentDraft({
    required this.receivedDate,
    required this.companyId,
    required this.companyNameSnapshot,
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
      initialDate: _receivedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: _buildThemedDatePicker,
    );
    if (picked == null || !mounted) return;
    setState(() => _receivedDate = DateUtils.dateOnly(picked));
  }

  Future<void> _pickPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
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
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ContractPopupSurface(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
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
                            isEditing ? 'Editar pago fijo' : 'Nuevo pago fijo',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: finanzasAreaTokens.primaryStrong,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Captura el compromiso del mes con empresa directa, monto y fecha objetivo de pago.',
                            style: TextStyle(
                              fontSize: 14,
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _InlineChoiceField(
                        label: 'Fecha recibido',
                        value: _dateLabel(_receivedDate),
                        onTap: () {
                          unawaited(_pickReceivedDate());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InlineChoiceField(
                        label: 'Empresa',
                        value: companyName,
                        onTap: () async {
                          final selected = await _showSimpleOptionsDialog(
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
                          if (selected == null || !mounted) return;
                          setState(() => _companyId = selected.id);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _InlineChoiceField(
                        label: 'Cuenta',
                        value: finFixedPaymentBranchLabel(_branch),
                        onTap: () async {
                          final selected = await _showSimpleOptionsDialog(
                            context: context,
                            title: 'Seleccionar cuenta',
                            options: kFinFixedPaymentBranches
                                .map(
                                  (row) => _SimpleOption(
                                    id: row,
                                    label: finFixedPaymentBranchLabel(row),
                                    subtitle: '',
                                  ),
                                )
                                .toList(growable: false),
                          );
                          if (selected == null || !mounted) return;
                          setState(() => _branch = selected.id);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _amountC,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: contractGlassFieldDecoration(
                          context,
                          hintText: 'Monto',
                          prefixIcon: const Icon(Icons.payments_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InlineChoiceField(
                        label: 'Fecha pago',
                        value: _dateLabel(_paymentDate),
                        onTap: () {
                          unawaited(_pickPaymentDate());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InlineChoiceField(
                        label: 'Estado',
                        value: finFixedPaymentStatusLabel(_status),
                        onTap: () async {
                          final selected = await _showSimpleOptionsDialog(
                            context: context,
                            title: 'Seleccionar estado',
                            options: kFinFixedPaymentStatuses
                                .map(
                                  (row) => _SimpleOption(
                                    id: row,
                                    label: finFixedPaymentStatusLabel(row),
                                    subtitle: '',
                                  ),
                                )
                                .toList(growable: false),
                          );
                          if (selected == null || !mounted) return;
                          setState(() => _status = selected.id);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesC,
                  minLines: 3,
                  maxLines: 4,
                  decoration: contractGlassFieldDecoration(
                    context,
                    hintText: 'Comentario o detalle del recibo',
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: !_canSave
                          ? null
                          : () {
                              Navigator.of(context).pop(
                                _FixedPaymentDraft(
                                  receivedDate: _receivedDate,
                                  companyId: _companyId,
                                  companyNameSnapshot: companyName,
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
      ),
    );
  }
}

class _ActionBand extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onExport;
  final VoidCallback onCreate;
  final bool exporting;

  const _ActionBand({
    required this.selectedCount,
    required this.onExport,
    required this.onCreate,
    required this.exporting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: exporting ? null : onExport,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Descargar CSV'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuevo pago fijo'),
          ),
          const Spacer(),
          Text(
            '$selectedCount seleccionadas',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.primaryStrong.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: tokens.badgeText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _HeaderFilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? tokens.primaryStrong.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.64),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? tokens.primaryStrong.withValues(alpha: 0.38)
                : tokens.border.withValues(alpha: 0.9),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_outlined,
              size: 16,
              color: active ? tokens.primaryStrong : tokens.badgeText,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: active ? tokens.primaryStrong : tokens.badgeText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridHeaderCell {
  final double width;
  final String label;
  final bool alignEnd;

  const _GridHeaderCell({
    required this.width,
    required this.label,
    this.alignEnd = false,
  });
}

class _GridHeaderRow extends StatelessWidget {
  final List<_GridHeaderCell> cells;

  const _GridHeaderRow({required this.cells});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ContractGridScaledRow(
        child: Row(
          children: [
            for (final cell in cells)
              SizedBox(
                width: cell.width,
                child: Align(
                  alignment: cell.alignEnd
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Text(
                    cell.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AreaThemeScope.of(context).badgeText,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FixedPaymentRow extends StatelessWidget {
  final FinanzasFixedPaymentRecord row;
  final bool selected;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime value) dateFormatter;
  final Color Function(String status) statusTone;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onPayCash;
  final VoidCallback onDelete;

  const _FixedPaymentRow({
    required this.row,
    required this.selected,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.statusTone,
    required this.onTap,
    required this.onEdit,
    required this.onPayCash,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tone = statusTone(row.status);
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? tokens.primaryStrong.withValues(alpha: 0.28)
                  : tokens.primaryStrong.withValues(alpha: 0.10),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: tokens.primaryStrong.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: ContractGridScaledRow(
            child: Row(
              children: [
                _FieldCell(
                  width: _kFixedReceivedDateW,
                  child: Text(dateFormatter(row.receivedDate)),
                ),
                _FieldCell(
                  width: _kFixedCompanyW,
                  child: ContractEditableHoverCapsule(
                    hovered: selected,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      row.companyNameSnapshot,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                _FieldCell(
                  width: _kFixedBranchW,
                  child: ContractEditableHoverCapsule(
                    hovered: selected,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(finFixedPaymentBranchLabel(row.branch)),
                  ),
                ),
                _FieldCell(
                  width: _kFixedAmountW,
                  alignEnd: true,
                  child: Text(
                    moneyFormatter(row.amount),
                    textAlign: TextAlign.right,
                  ),
                ),
                _FieldCell(
                  width: _kFixedPaymentDateW,
                  child: Text(dateFormatter(row.paymentDate)),
                ),
                _FieldCell(
                  width: _kFixedStatusW,
                  child: _MiniToneChip(
                    label: finFixedPaymentStatusLabel(row.status),
                    tone: tone,
                  ),
                ),
                _FieldCell(
                  width: _kFixedNotesW,
                  child: ContractEditableHoverCapsule(
                    hovered: selected,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      row.notes.trim().isEmpty ? '—' : row.notes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(
                  width: _kFixedActionsW,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AnchoredActionSlot(
                      width: _kFixedActionsW,
                      trailingWidth: 36,
                      leading: const SizedBox.shrink(),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Acciones',
                        icon: const Icon(Icons.more_horiz_rounded),
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit();
                          } else if (value == 'pay_cash') {
                            onPayCash?.call();
                          } else if (value == 'delete') {
                            onDelete();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Editar'),
                          ),
                          if (onPayCash != null)
                            const PopupMenuItem<String>(
                              value: 'pay_cash',
                              child: Text('Pagar en efectivo'),
                            ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Eliminar'),
                          ),
                        ],
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
  }
}

class _FieldCell extends StatelessWidget {
  final double width;
  final bool alignEnd;
  final Widget child;

  const _FieldCell({
    required this.width,
    required this.child,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: DefaultTextStyle(
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AreaThemeScope.of(context).primaryStrong,
          ),
          child: child,
        ),
      ),
    );
  }
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

class _EmptyGridState extends StatelessWidget {
  const _EmptyGridState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 34,
            color: AreaThemeScope.of(context).primaryStrong,
          ),
          const SizedBox(height: 12),
          Text(
            'Todavía no hay pagos fijos registrados.',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AreaThemeScope.of(context).primaryStrong,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Captura los compromisos del mes para empezar a alimentar la planeación de pagos.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kFinanzasMutedInk,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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

class _HeaderButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        if (onTapSync != null) {
          onTapSync!();
          return;
        }
        if (onTap != null) {
          await onTap!();
        }
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kFinanzasInk),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: kFinanzasInk,
              ),
            ),
          ],
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
      width: 390,
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
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
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
                        subtitle: row.subtitle.isEmpty
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

Future<Set<String>?> _showMultiSelectDialog({
  required BuildContext context,
  required String title,
  required List<String> options,
  required Set<String> selected,
  String Function(String value)? labelBuilder,
}) {
  return showDialog<Set<String>>(
    context: context,
    builder: (_) => _MultiSelectDialog(
      title: title,
      options: options,
      selected: selected,
      labelBuilder: labelBuilder,
    ),
  );
}

class _MultiSelectDialog extends StatefulWidget {
  final String title;
  final List<String> options;
  final Set<String> selected;
  final String Function(String value)? labelBuilder;

  const _MultiSelectDialog({
    required this.title,
    required this.options,
    required this.selected,
    this.labelBuilder,
  });

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: ContractGlassCard(
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: kFinanzasInk,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: widget.options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final option = widget.options[index];
                      final selected = _selected.contains(option);
                      return CheckboxListTile(
                        value: selected,
                        activeColor: finanzasAreaTokens.primaryStrong,
                        checkColor: Colors.white,
                        tileColor: Colors.white.withValues(alpha: 0.72),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        title: Text(
                          widget.labelBuilder?.call(option) ?? option,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        onChanged: (_) {
                          setState(() {
                            if (selected) {
                              _selected.remove(option);
                            } else {
                              _selected.add(option);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(_selected),
                      child: const Text('Aplicar'),
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

class _InlineChoiceField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _InlineChoiceField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AreaThemeScope.of(context).border.withValues(alpha: 0.9),
            ),
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
                        color: AreaThemeScope.of(context).badgeText,
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
                        color: AreaThemeScope.of(context).primaryStrong,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AreaThemeScope.of(context).badgeText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
