import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../compras/compras_dashboard_page.dart';
import '../compras/compras_tickets_store.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'finanzas_bank_accounts_store.dart';
import 'finanzas_bank_accounts_page.dart';
import 'finanzas_catalog_page.dart';
import 'finanzas_company_directory_page.dart';
import 'finanzas_company_directory_store.dart';
import 'finanzas_dashboard_page.dart';
import 'finanzas_provider_accounts_store.dart';
import 'finanzas_theme.dart';

enum _ProviderAccountsTab {
  resumen('Resumen'),
  tickets('Tickets'),
  facturas('Facturas'),
  movimientos('Movimientos'),
  convenios('Convenios');

  final String label;
  const _ProviderAccountsTab(this.label);
}

class FinanzasProviderAccountsPage extends StatefulWidget {
  final bool instantOpen;

  const FinanzasProviderAccountsPage({super.key, this.instantOpen = false});

  @override
  State<FinanzasProviderAccountsPage> createState() =>
      _FinanzasProviderAccountsPageState();
}

class _FinanzasProviderAccountsPageState
    extends State<FinanzasProviderAccountsPage> {
  bool _menuOpen = false;
  bool _loading = true;
  bool _canReturnToDirection = false;
  bool _canAccessComprasArea = false;
  final TextEditingController _searchC = TextEditingController();
  _ProviderAccountsTab _activeTab = _ProviderAccountsTab.resumen;
  String? _selectedCompanyId;
  List<_ProviderAccountView> _accounts = const <_ProviderAccountView>[];

  @override
  void initState() {
    super.initState();
    _searchC.addListener(_handleSearchChanged);
    unawaited(_resolveNavigationAccess());
    unawaited(_loadPage());
  }

  @override
  void dispose() {
    _searchC.removeListener(_handleSearchChanged);
    _searchC.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    setState(() {});
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
      FinanzasCompanyDirectoryStore.loadDirectory(),
      ComprasTicketsStore.loadTickets(),
      FinanzasProviderAccountsStore.loadInvoices(),
      FinanzasProviderAccountsStore.loadInvoiceTickets(),
      FinanzasBankAccountsStore.loadMovements(),
      ComprasTicketsStore.loadProviderMovements(),
      FinanzasProviderAccountsStore.loadAgreements(),
      FinanzasProviderAccountsStore.loadAgreementInstallments(),
    ]);
    if (!mounted) return;
    final directory = results[0] as List<FinanzasCompanyDirectoryRecord>;
    final tickets = results[1] as List<ComprasTicketRecord>;
    final invoices = results[2] as List<FinanzasSupplierInvoiceRecord>;
    final invoiceTickets =
        results[3] as List<FinanzasSupplierInvoiceTicketRecord>;
    final bankMovements = results[4] as List<FinanzasBankMovementRecord>;
    final providerCashMovements =
        results[5] as List<ComprasProviderMovementRecord>;
    final agreements = results[6] as List<FinanzasSupplierAgreementRecord>;
    final agreementInstallments =
        results[7] as List<FinanzasSupplierAgreementInstallmentRecord>;
    final accounts = _buildAccounts(
      directory,
      tickets,
      invoices,
      invoiceTickets,
      bankMovements,
      providerCashMovements,
      agreements,
      agreementInstallments,
    );
    setState(() {
      _accounts = accounts;
      _selectedCompanyId = accounts.isEmpty
          ? null
          : accounts.any((row) => row.company.companyId == _selectedCompanyId)
          ? _selectedCompanyId
          : accounts.first.company.companyId;
      _loading = false;
    });
  }

  List<_ProviderAccountView> _buildAccounts(
    List<FinanzasCompanyDirectoryRecord> directory,
    List<ComprasTicketRecord> tickets,
    List<FinanzasSupplierInvoiceRecord> invoices,
    List<FinanzasSupplierInvoiceTicketRecord> invoiceTickets,
    List<FinanzasBankMovementRecord> bankMovements,
    List<ComprasProviderMovementRecord> providerCashMovements,
    List<FinanzasSupplierAgreementRecord> agreements,
    List<FinanzasSupplierAgreementInstallmentRecord> agreementInstallments,
  ) {
    final providerDirectory = directory
        .where(
          (company) =>
              company.active && company.source.trim().toUpperCase() != 'VENTAS',
        )
        .toList(growable: false);
    final byProviderId = <String, List<ComprasTicketRecord>>{};
    for (final row in tickets) {
      byProviderId
          .putIfAbsent(row.providerId, () => <ComprasTicketRecord>[])
          .add(row);
    }
    final ticketsById = <String, ComprasTicketRecord>{
      for (final ticket in tickets) ticket.id: ticket,
    };
    final invoiceTicketsByInvoiceId = <String, List<ComprasTicketRecord>>{};
    for (final link in invoiceTickets) {
      final ticket = ticketsById[link.ticketId];
      if (ticket == null) continue;
      invoiceTicketsByInvoiceId
          .putIfAbsent(link.invoiceId, () => <ComprasTicketRecord>[])
          .add(ticket);
    }
    final invoicesByProviderId =
        <String, List<FinanzasSupplierInvoiceRecord>>{};
    for (final invoice in invoices) {
      invoicesByProviderId
          .putIfAbsent(
            invoice.providerId,
            () => <FinanzasSupplierInvoiceRecord>[],
          )
          .add(invoice);
    }
    final bankMovementByInvoiceId = <String, FinanzasBankMovementRecord>{};
    for (final movement in bankMovements) {
      final invoiceId = movement.linkedSupplierInvoiceId;
      if (invoiceId == null || invoiceId.isEmpty) continue;
      bankMovementByInvoiceId.putIfAbsent(invoiceId, () => movement);
    }
    final agreementInstallmentsByAgreementId =
        <String, List<FinanzasSupplierAgreementInstallmentRecord>>{};
    for (final row in agreementInstallments) {
      agreementInstallmentsByAgreementId
          .putIfAbsent(
            row.agreementId,
            () => <FinanzasSupplierAgreementInstallmentRecord>[],
          )
          .add(row);
    }
    final agreementsByProviderId =
        <String, List<FinanzasSupplierAgreementRecord>>{};
    for (final agreement in agreements) {
      agreementsByProviderId
          .putIfAbsent(
            agreement.providerId,
            () => <FinanzasSupplierAgreementRecord>[],
          )
          .add(agreement);
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final accounts =
        providerDirectory
            .map((company) {
              final comprasProviderId = _resolveComprasProviderId(company);
              final companyTickets =
                  byProviderId[comprasProviderId]?.toList(growable: false) ??
                  <ComprasTicketRecord>[];
              companyTickets.sort((a, b) => b.date.compareTo(a.date));
              final rows = companyTickets;
              final providerInvoices =
                  invoicesByProviderId[company.companyId]?.toList(
                    growable: false,
                  ) ??
                  <FinanzasSupplierInvoiceRecord>[];
              providerInvoices.sort(
                (a, b) => b.invoiceDate.compareTo(a.invoiceDate),
              );
              final providerInvoiceIds = providerInvoices
                  .map((invoice) => invoice.id)
                  .toSet();
              final providerMovements =
                  bankMovements
                      .where((movement) {
                        final counterpartyId = movement.counterpartyCompanyId;
                        final byCounterparty =
                            counterpartyId == company.companyId ||
                            counterpartyId == comprasProviderId;
                        final byInvoice =
                            movement.linkedSupplierInvoiceId != null &&
                            providerInvoiceIds.contains(
                              movement.linkedSupplierInvoiceId,
                            );
                        final byName =
                            counterpartyId == null &&
                            movement.counterpartyNameSnapshot
                                    .trim()
                                    .toLowerCase() ==
                                company.companyName.trim().toLowerCase();
                        return byCounterparty || byInvoice || byName;
                      })
                      .toList(growable: false)
                    ..sort((a, b) => b.date.compareTo(a.date));
              final providerCashMovementRows =
                  providerCashMovements
                      .where(
                        (movement) => movement.providerId == comprasProviderId,
                      )
                      .toList(growable: false)
                    ..sort((a, b) => b.date.compareTo(a.date));
              final providerAgreements =
                  agreementsByProviderId[company.companyId]
                      ?.map(
                        (agreement) => _ProviderAgreementView(
                          agreement: agreement,
                          installments:
                              agreementInstallmentsByAgreementId[agreement.id]
                                  ?.toList(growable: false) ??
                              <FinanzasSupplierAgreementInstallmentRecord>[],
                        ),
                      )
                      .toList(growable: false) ??
                  <_ProviderAgreementView>[];
              providerAgreements.sort(
                (a, b) =>
                    b.agreement.startDate.compareTo(a.agreement.startDate),
              );
              double total = 0;
              double open = 0;
              double facturado = 0;
              double sinFactura = 0;
              double pendienteFacturar = 0;
              double pagado = 0;
              double vencido = 0;
              var abiertos = 0;
              DateTime? nextCommitment;
              for (final ticket in rows) {
                total += ticket.amount;
                final dueDate = DateUtils.dateOnly(
                  ticket.date.add(Duration(days: company.creditDays)),
                );
                if (ticket.pagoStatus == 'PAGADO') {
                  pagado += ticket.amount;
                  continue;
                }
                abiertos += 1;
                open += ticket.amount;
                if (ticket.facturaStatus == 'FACTURADO') {
                  facturado += ticket.amount;
                } else if (ticket.facturaStatus == 'SIN_FACTURA') {
                  sinFactura += ticket.amount;
                } else {
                  pendienteFacturar += ticket.amount;
                }
                if (company.creditDays > 0 &&
                    (dueDate.isBefore(today) || dueDate == today)) {
                  vencido += ticket.amount;
                }
                if (nextCommitment == null ||
                    dueDate.isBefore(nextCommitment)) {
                  nextCommitment = dueDate;
                }
              }
              for (final invoice in providerInvoices) {
                if (invoice.status == 'PAGADA') continue;
                final dueDate = invoice.dueDate;
                if (dueDate == null) continue;
                if (nextCommitment == null ||
                    dueDate.isBefore(nextCommitment)) {
                  nextCommitment = dueDate;
                }
              }
              final urgency = _buildUrgency(
                paymentStage: company.paymentStage,
                openAmount: open,
                overdueAmount: vencido,
              );
              final recommendation = _buildRecommendation(
                paymentStage: company.paymentStage,
                openAmount: open,
                overdueAmount: vencido,
                hasFacturado: facturado > 0,
              );
              return _ProviderAccountView(
                company: company,
                tickets: rows,
                invoices: providerInvoices
                    .map(
                      (invoice) => _ProviderInvoiceView(
                        invoice: invoice,
                        bankMovement: bankMovementByInvoiceId[invoice.id],
                        tickets:
                            invoiceTicketsByInvoiceId[invoice.id]?.toList(
                              growable: false,
                            ) ??
                            const <ComprasTicketRecord>[],
                      ),
                    )
                    .toList(growable: false),
                movements: providerMovements,
                cashMovements: providerCashMovementRows,
                agreements: providerAgreements,
                totalAmount: total,
                openAmount: open,
                facturadoAmount: facturado,
                sinFacturaAmount: sinFactura,
                pendienteFacturarAmount: pendienteFacturar,
                paidAmount: pagado,
                overdueAmount: vencido,
                openTicketsCount: abiertos,
                nextCommitmentDate: nextCommitment,
                urgencyLabel: urgency.$1,
                urgencyTone: urgency.$2,
                recommendation: recommendation,
              );
            })
            .toList(growable: false)
          ..sort((a, b) {
            final diff = b.openAmount.compareTo(a.openAmount);
            if (diff != 0) return diff;
            return a.company.companyName.compareTo(b.company.companyName);
          });
    return accounts;
  }

  String _resolveComprasProviderId(FinanzasCompanyDirectoryRecord company) {
    if (company.source.trim().toUpperCase() == 'COMPRAS' &&
        company.companyId.startsWith('compras_')) {
      return company.companyId.substring('compras_'.length);
    }
    return company.companyId;
  }

  (String, Color) _buildUrgency({
    required String paymentStage,
    required double openAmount,
    required double overdueAmount,
  }) {
    if (openAmount <= 0) return ('Sin saldo', const Color(0xFF0F766E));
    if (paymentStage == 'CONVENIO') {
      return ('Convenio', const Color(0xFF8B5E00));
    }
    if (paymentStage == 'ATRASADO' || overdueAmount > 0) {
      return ('Urgente', const Color(0xFFB42318));
    }
    if (paymentStage == 'PAGO_SEMANAL') {
      return ('Semanal', const Color(0xFF7A1914));
    }
    return ('Normal', const Color(0xFF0F766E));
  }

  String _buildRecommendation({
    required String paymentStage,
    required double openAmount,
    required double overdueAmount,
    required bool hasFacturado,
  }) {
    if (openAmount <= 0) return 'Cuenta al corriente';
    if (paymentStage == 'CONVENIO') return 'Respetar convenio vigente';
    if (overdueAmount > 0) return 'Priorizar abono esta semana';
    if (hasFacturado) return 'Revisar factura y fecha compromiso';
    return 'Aplicar a saldo general del proveedor';
  }

  String _deriveInvoiceStatus({
    required DateTime? dueDate,
    required double balanceAmount,
  }) {
    if (balanceAmount <= 0) return 'PAGADA';
    if (dueDate != null) {
      final today = DateUtils.dateOnly(DateTime.now());
      final invoiceDueDate = DateUtils.dateOnly(dueDate);
      if (invoiceDueDate.isBefore(today)) {
        return 'VENCIDA';
      }
    }
    return 'PENDIENTE';
  }

  List<_ProviderAccountView> get _visibleAccounts {
    final query = _searchC.text.trim().toLowerCase();
    if (query.isEmpty) return _accounts;
    return _accounts
        .where((row) {
          return row.company.companyName.toLowerCase().contains(query) ||
              row.company.linkedName.toLowerCase().contains(query) ||
              row.company.operationalContact.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  _ProviderAccountView? get _selectedAccount {
    final id = _selectedCompanyId;
    if (id == null) return null;
    for (final row in _accounts) {
      if (row.company.companyId == id) return row;
    }
    return null;
  }

  Future<void> _logout() async {
    await signOutAndRouteToLogin(context);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _registerProviderCashMovementForSelectedProvider() async {
    final account = _selectedAccount;
    if (account == null) return;
    final comprasProviderId = _resolveComprasProviderId(account.company);
    final draft = await showDialog<_ProviderCashMovementDraft>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _RegisterProviderCashMovementDialog(
        providerName: account.company.companyName,
      ),
    );
    if (draft == null) return;
    final movement = ComprasProviderMovementRecord(
      id: 'compras-provider-mov-${DateTime.now().microsecondsSinceEpoch}',
      providerId: comprasProviderId,
      date: draft.date,
      type: draft.type,
      source: draft.source,
      amount: draft.amount,
      reference: draft.reference,
      notes: draft.notes,
      createdAt: null,
    );
    try {
      await ComprasTicketsStore.createProviderMovementAndAutoApply(
        movement: movement,
      );
      if (!mounted) return;
      _toast('Movimiento de proveedor registrado.');
      await _loadPage();
      if (!mounted) return;
      setState(() => _activeTab = _ProviderAccountsTab.movimientos);
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo registrar el movimiento. $error');
    }
  }

  Future<void> _editProviderCashMovementForSelectedProvider(
    ComprasProviderMovementRecord movement,
  ) async {
    final account = _selectedAccount;
    if (account == null) return;
    final draft = await showDialog<_ProviderCashMovementDraft>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _RegisterProviderCashMovementDialog(
        providerName: account.company.companyName,
        initialMovement: movement,
      ),
    );
    if (draft == null) return;
    final updatedMovement = ComprasProviderMovementRecord(
      id: movement.id,
      providerId: movement.providerId,
      date: draft.date,
      type: draft.type,
      source: draft.source,
      amount: draft.amount,
      reference: draft.reference,
      notes: draft.notes,
      createdAt: movement.createdAt,
    );
    try {
      await ComprasTicketsStore.updateProviderMovementAndAutoApply(
        movement: updatedMovement,
      );
      if (!mounted) return;
      _toast('Movimiento de proveedor actualizado.');
      await _loadPage();
      if (!mounted) return;
      setState(() => _activeTab = _ProviderAccountsTab.movimientos);
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo actualizar el movimiento. $error');
    }
  }

  Future<void> _deleteProviderCashMovementForSelectedProvider(
    ComprasProviderMovementRecord movement,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: Text(
          'Se eliminará este movimiento directo del proveedor y se recalculará su aplicación sobre tickets abiertos. ¿Continuar?',
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
      await ComprasTicketsStore.deleteProviderMovementAndRebuildApplications(
        movement: movement,
      );
      if (!mounted) return;
      _toast('Movimiento de proveedor eliminado.');
      await _loadPage();
      if (!mounted) return;
      setState(() => _activeTab = _ProviderAccountsTab.movimientos);
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo eliminar el movimiento. $error');
    }
  }

  Future<void> _registerAgreementForSelectedProvider() async {
    final account = _selectedAccount;
    if (account == null) return;
    final draft = await showDialog<_AgreementDraftResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _RegisterSupplierAgreementDialog(
        providerName: account.company.companyName,
        suggestedBalance: account.openAmount,
      ),
    );
    if (draft == null) return;
    final agreementId =
        'fin-agreement-${DateTime.now().microsecondsSinceEpoch}';
    final totalAmount = draft.installmentAmount * draft.installmentCount;
    final installments =
        List<FinanzasSupplierAgreementInstallmentRecord>.generate(
          draft.installmentCount,
          (index) {
            final dueDate = _agreementInstallmentDate(
              startDate: draft.startDate,
              frequency: draft.frequency,
              offset: index,
            );
            return FinanzasSupplierAgreementInstallmentRecord(
              id: '$agreementId-inst-${index + 1}',
              agreementId: agreementId,
              sequenceNumber: index + 1,
              dueDate: dueDate,
              amount: draft.installmentAmount,
              paidAmount: 0,
              status: 'PENDIENTE',
              createdAt: null,
              updatedAt: null,
            );
          },
          growable: false,
        );
    final agreement = FinanzasSupplierAgreementRecord(
      id: agreementId,
      providerId: account.company.companyId,
      providerNameSnapshot: account.company.companyName,
      startDate: draft.startDate,
      frequency: draft.frequency,
      installmentAmount: draft.installmentAmount,
      installmentCount: draft.installmentCount,
      totalAmount: totalAmount,
      remainingAmount: totalAmount,
      nextDueDate: installments.isEmpty
          ? draft.startDate
          : installments.first.dueDate,
      status: 'ACTIVO',
      notes: draft.notes,
      createdAt: null,
      updatedAt: null,
    );
    try {
      await FinanzasProviderAccountsStore.createAgreement(
        agreement: agreement,
        installments: installments,
      );
      if (!mounted) return;
      _toast('Convenio registrado.');
      await _loadPage();
      if (!mounted) return;
      setState(() => _activeTab = _ProviderAccountsTab.convenios);
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo registrar el convenio. $error');
    }
  }

  Future<void> _registerInvoiceForSelectedProvider() async {
    final account = _selectedAccount;
    if (account == null) return;
    final eligibleTickets = account.tickets
        .where((ticket) => ticket.facturaStatus == 'PENDIENTE_DE_FACTURAR')
        .toList(growable: false);
    if (eligibleTickets.isEmpty) {
      _toast('Este proveedor no tiene tickets pendientes de facturar.');
      return;
    }
    final draft = await showDialog<_InvoiceDraftResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _RegisterSupplierInvoiceDialog(
        companyName: account.company.companyName,
        tickets: eligibleTickets,
      ),
    );
    if (draft == null) return;
    final selectedTickets = eligibleTickets
        .where((ticket) => draft.selectedTicketIds.contains(ticket.id))
        .toList(growable: false);
    if (selectedTickets.isEmpty) {
      _toast('Selecciona al menos un ticket para registrar la factura.');
      return;
    }
    final total = selectedTickets.fold<double>(
      0,
      (sum, ticket) => sum + ticket.amount,
    );
    final status = _deriveInvoiceStatus(
      dueDate: draft.dueDate,
      balanceAmount: total,
    );
    final invoice = FinanzasSupplierInvoiceRecord(
      id: 'fin-invoice-${DateTime.now().microsecondsSinceEpoch}',
      providerId: account.company.companyId,
      providerNameSnapshot: account.company.companyName,
      folio: draft.folio.trim(),
      invoiceDate: draft.invoiceDate,
      dueDate: draft.dueDate,
      totalAmount: total,
      balanceAmount: total,
      status: status,
      notes: draft.notes.trim(),
      createdAt: null,
      updatedAt: null,
    );
    try {
      await FinanzasProviderAccountsStore.createInvoice(
        invoice: invoice,
        tickets: selectedTickets,
      );
      if (!mounted) return;
      _toast('Factura registrada y tickets relacionados.');
      await _loadPage();
      if (!mounted) return;
      setState(() => _activeTab = _ProviderAccountsTab.facturas);
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo registrar la factura. $error');
    }
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
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      case 'Dashboard Compras':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openComprasDashboard());
        return;
      case 'Cuentas Bancarias':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openBankAccounts());
        return;
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

  String _dateLabel(DateTime? value) {
    if (value == null) return '—';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedAccount;
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
          background: const _FinProviderAccountsBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => _FinHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => const _FinProviderAccountsHeaderBrand(),
          trailingBuilder: (_, _) => _FinHeaderButton(
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
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 360,
                                child: _ProviderAccountsListPane(
                                  searchController: _searchC,
                                  rows: _visibleAccounts,
                                  selectedCompanyId: _selectedCompanyId,
                                  moneyFormatter: _money,
                                  dateFormatter: _dateLabel,
                                  onSelect: (id) =>
                                      setState(() => _selectedCompanyId = id),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: selected == null
                                    ? const _ProviderAccountsEmptyDetail()
                                    : _ProviderAccountsDetailPane(
                                        account: selected,
                                        activeTab: _activeTab,
                                        moneyFormatter: _money,
                                        dateFormatter: _dateLabel,
                                        onTabSelected: (tab) =>
                                            setState(() => _activeTab = tab),
                                        onRegisterInvoice:
                                            _registerInvoiceForSelectedProvider,
                                        onOpenBankAccounts: _openBankAccounts,
                                        onRegisterCashMovement:
                                            _registerProviderCashMovementForSelectedProvider,
                                        onRegisterAgreement:
                                            _registerAgreementForSelectedProvider,
                                        onEditCashMovement:
                                            _editProviderCashMovementForSelectedProvider,
                                        onDeleteCashMovement:
                                            _deleteProviderCashMovementForSelectedProvider,
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
                      child: _FinProviderAccountsSidePanel(
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

class _ProviderAccountView {
  final FinanzasCompanyDirectoryRecord company;
  final List<ComprasTicketRecord> tickets;
  final List<_ProviderInvoiceView> invoices;
  final List<FinanzasBankMovementRecord> movements;
  final List<ComprasProviderMovementRecord> cashMovements;
  final List<_ProviderAgreementView> agreements;
  final double totalAmount;
  final double openAmount;
  final double facturadoAmount;
  final double sinFacturaAmount;
  final double pendienteFacturarAmount;
  final double paidAmount;
  final double overdueAmount;
  final int openTicketsCount;
  final DateTime? nextCommitmentDate;
  final String urgencyLabel;
  final Color urgencyTone;
  final String recommendation;

  const _ProviderAccountView({
    required this.company,
    required this.tickets,
    required this.invoices,
    required this.movements,
    required this.cashMovements,
    required this.agreements,
    required this.totalAmount,
    required this.openAmount,
    required this.facturadoAmount,
    required this.sinFacturaAmount,
    required this.pendienteFacturarAmount,
    required this.paidAmount,
    required this.overdueAmount,
    required this.openTicketsCount,
    required this.nextCommitmentDate,
    required this.urgencyLabel,
    required this.urgencyTone,
    required this.recommendation,
  });
}

class _ProviderInvoiceView {
  final FinanzasSupplierInvoiceRecord invoice;
  final FinanzasBankMovementRecord? bankMovement;
  final List<ComprasTicketRecord> tickets;

  const _ProviderInvoiceView({
    required this.invoice,
    required this.bankMovement,
    required this.tickets,
  });
}

class _ProviderAgreementView {
  final FinanzasSupplierAgreementRecord agreement;
  final List<FinanzasSupplierAgreementInstallmentRecord> installments;

  const _ProviderAgreementView({
    required this.agreement,
    required this.installments,
  });
}

class _ProviderAccountsListPane extends StatelessWidget {
  final TextEditingController searchController;
  final List<_ProviderAccountView> rows;
  final String? selectedCompanyId;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final ValueChanged<String> onSelect;

  const _ProviderAccountsListPane({
    required this.searchController,
    required this.rows,
    required this.selectedCompanyId,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Proveedores',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: tokens.badgeBackground.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${rows.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: tokens.badgeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            decoration: contractGlassFieldDecoration(
              context,
              hintText: 'Buscar proveedor',
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      'Sin proveedores para mostrar.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: tokens.badgeText,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final row = rows[index];
                      final selected =
                          row.company.companyId == selectedCompanyId;
                      return _ProviderAccountListCard(
                        row: row,
                        selected: selected,
                        moneyFormatter: moneyFormatter,
                        dateFormatter: dateFormatter,
                        onTap: () => onSelect(row.company.companyId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProviderAccountListCard extends StatelessWidget {
  final _ProviderAccountView row;
  final bool selected;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final VoidCallback onTap;

  const _ProviderAccountListCard({
    required this.row,
    required this.selected,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: selected
          ? tokens.badgeBackground.withValues(alpha: 0.92)
          : Colors.white.withValues(alpha: 0.74),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.company.companyName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: tokens.primaryStrong,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _MiniToneChip(label: row.urgencyLabel, tone: row.urgencyTone),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Saldo abierto ${moneyFormatter(row.openAmount)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: tokens.badgeText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Abiertos ${row.openTicketsCount} · Próximo ${dateFormatter(row.nextCommitmentDate)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kFinanzasMutedInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderAccountsDetailPane extends StatelessWidget {
  final _ProviderAccountView account;
  final _ProviderAccountsTab activeTab;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final ValueChanged<_ProviderAccountsTab> onTabSelected;
  final Future<void> Function() onRegisterInvoice;
  final Future<void> Function() onOpenBankAccounts;
  final Future<void> Function() onRegisterCashMovement;
  final Future<void> Function() onRegisterAgreement;
  final Future<void> Function(ComprasProviderMovementRecord movement)
  onEditCashMovement;
  final Future<void> Function(ComprasProviderMovementRecord movement)
  onDeleteCashMovement;

  const _ProviderAccountsDetailPane({
    required this.account,
    required this.activeTab,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onTabSelected,
    required this.onRegisterInvoice,
    required this.onOpenBankAccounts,
    required this.onRegisterCashMovement,
    required this.onRegisterAgreement,
    required this.onEditCashMovement,
    required this.onDeleteCashMovement,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      borderRadius: BorderRadius.circular(30),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
                      account.company.companyName,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: tokens.primaryStrong,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      account.recommendation,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kFinanzasMutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              _MiniToneChip(
                label: account.urgencyLabel,
                tone: account.urgencyTone,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryMetricCard(
                label: 'Saldo abierto',
                value: moneyFormatter(account.openAmount),
              ),
              _SummaryMetricCard(
                label: 'Vencido',
                value: moneyFormatter(account.overdueAmount),
              ),
              _SummaryMetricCard(
                label: 'Facturado',
                value: moneyFormatter(account.facturadoAmount),
              ),
              _SummaryMetricCard(
                label: 'Sin factura',
                value: moneyFormatter(account.sinFacturaAmount),
              ),
              _SummaryMetricCard(
                label: 'Pend. facturar',
                value: moneyFormatter(account.pendienteFacturarAmount),
              ),
              _SummaryMetricCard(
                label: 'Pagado',
                value: moneyFormatter(account.paidAmount),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tab in _ProviderAccountsTab.values) ...[
                  _DetailTabChip(
                    label: tab.label,
                    active: activeTab == tab,
                    onTap: () => onTabSelected(tab),
                  ),
                  if (tab != _ProviderAccountsTab.values.last)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: switch (activeTab) {
              _ProviderAccountsTab.resumen => _ProviderAccountSummaryView(
                account: account,
                moneyFormatter: moneyFormatter,
                dateFormatter: dateFormatter,
              ),
              _ProviderAccountsTab.tickets => _ProviderAccountTicketsView(
                account: account,
                moneyFormatter: moneyFormatter,
                dateFormatter: dateFormatter,
              ),
              _ProviderAccountsTab.facturas => _ProviderAccountInvoicesView(
                account: account,
                moneyFormatter: moneyFormatter,
                dateFormatter: dateFormatter,
                onRegisterInvoice: onRegisterInvoice,
              ),
              _ProviderAccountsTab.movimientos => _ProviderAccountMovementsView(
                account: account,
                moneyFormatter: moneyFormatter,
                dateFormatter: dateFormatter,
                onOpenBankAccounts: onOpenBankAccounts,
                onRegisterCashMovement: onRegisterCashMovement,
                onEditCashMovement: onEditCashMovement,
                onDeleteCashMovement: onDeleteCashMovement,
              ),
              _ProviderAccountsTab.convenios => _ProviderAccountAgreementsView(
                account: account,
                moneyFormatter: moneyFormatter,
                dateFormatter: dateFormatter,
                onRegisterAgreement: onRegisterAgreement,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _ProviderAccountSummaryView extends StatelessWidget {
  final _ProviderAccountView account;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;

  const _ProviderAccountSummaryView({
    required this.account,
    required this.moneyFormatter,
    required this.dateFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _LongInfoCard(
                title: 'Próximo compromiso',
                value: dateFormatter(account.nextCommitmentDate),
                subtitle: 'Calculado desde días de crédito y tickets abiertos.',
              ),
              _LongInfoCard(
                title: 'Etapa de pago',
                value: _finPaymentStageLabel(account.company.paymentStage),
                subtitle: account.company.paymentNotes.isEmpty
                    ? 'Sin nota operativa registrada.'
                    : account.company.paymentNotes,
              ),
              _LongInfoCard(
                title: 'Crédito proveedor',
                value: '${account.company.creditDays} días',
                subtitle:
                    'Contacto ${account.company.operationalContact.isEmpty ? 'sin capturar' : account.company.operationalContact}.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: tokens.primaryStrong.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lectura operativa',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: tokens.primaryStrong,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Saldo total histórico ${moneyFormatter(account.totalAmount)}. Abierto ${moneyFormatter(account.openAmount)}. Tickets abiertos ${account.openTicketsCount}.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kFinanzasMutedInk,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderAccountTicketsView extends StatelessWidget {
  final _ProviderAccountView account;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;

  const _ProviderAccountTicketsView({
    required this.account,
    required this.moneyFormatter,
    required this.dateFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    const tableWidth = 950.0;
    if (account.tickets.isEmpty) {
      return _ProviderAccountsPendingPane(
        label: 'Sin tickets',
        subtitle: 'Este proveedor todavía no tiene tickets relacionados.',
      );
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Row(
                children: [
                  _TicketHeaderCell(width: 108, label: 'FECHA'),
                  _TicketHeaderCell(width: 104, label: 'TICKET'),
                  _TicketHeaderCell(width: 170, label: 'MATERIAL'),
                  _TicketHeaderCell(width: 108, label: 'IMPORTE'),
                  _TicketHeaderCell(width: 170, label: 'FACTURA'),
                  _TicketHeaderCell(width: 160, label: 'PAGO'),
                  _TicketHeaderCell(width: 130, label: 'COBERTURA'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: account.tickets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final row = account.tickets[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: tokens.primaryStrong.withValues(alpha: 0.12),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Row(
                      children: [
                        _TicketValueCell(
                          width: 108,
                          text: dateFormatter(row.date),
                        ),
                        _TicketValueCell(
                          width: 104,
                          text: row.ticket,
                          bold: true,
                        ),
                        _TicketValueCell(
                          width: 170,
                          text: row.materialNameSnapshot,
                        ),
                        _TicketValueCell(
                          width: 108,
                          text: moneyFormatter(row.amount),
                        ),
                        _TicketBadgeCell(
                          width: 170,
                          label: comprasFacturaStatusLabel(row.facturaStatus),
                          tone: _facturaTone(row.facturaStatus),
                        ),
                        _TicketBadgeCell(
                          width: 160,
                          label: comprasPagoStatusLabel(row.pagoStatus),
                          tone: _pagoTone(row.pagoStatus),
                        ),
                        _TicketBadgeCell(
                          width: 130,
                          label: comprasCoverageStatusLabel(row.coverageStatus),
                          tone: _coverageTone(row.coverageStatus),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProviderAccountInvoicesView extends StatelessWidget {
  final _ProviderAccountView account;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final Future<void> Function() onRegisterInvoice;

  const _ProviderAccountInvoicesView({
    required this.account,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onRegisterInvoice,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final eligibleCount = account.tickets
        .where((ticket) => ticket.facturaStatus == 'PENDIENTE_DE_FACTURAR')
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Relaciona tickets del proveedor a una factura real.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kFinanzasMutedInk,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _ActionPillButton(
              label: 'Registrar factura',
              icon: Icons.receipt_long_rounded,
              onTap: onRegisterInvoice,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SummaryMetricCard(
              label: 'Facturas',
              value: '${account.invoices.length}',
            ),
            _SummaryMetricCard(
              label: 'Tickets elegibles',
              value: '$eligibleCount',
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (account.invoices.isEmpty)
          Expanded(
            child: _ProviderAccountsPendingPane(
              label: 'Sin facturas registradas',
              subtitle: eligibleCount > 0
                  ? 'Este proveedor tiene tickets pendientes de facturar. Registra la primera factura desde aquí.'
                  : 'Todavía no hay facturas relacionadas para este proveedor.',
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: account.invoices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final row = account.invoices[index];
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: tokens.primaryStrong.withValues(alpha: 0.12),
                    ),
                  ),
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
                                  row.invoice.folio,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: tokens.primaryStrong,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Factura ${dateFormatter(row.invoice.invoiceDate)} · límite ${dateFormatter(row.invoice.dueDate)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: kFinanzasMutedInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _MiniToneChip(
                            label: finSupplierInvoiceStatusLabel(
                              row.invoice.status,
                            ),
                            tone: _invoiceTone(row.invoice.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _SummaryMetricCard(
                            label: 'Total',
                            value: moneyFormatter(row.invoice.totalAmount),
                          ),
                          _SummaryMetricCard(
                            label: 'Saldo',
                            value: moneyFormatter(row.invoice.balanceAmount),
                          ),
                          _SummaryMetricCard(
                            label: 'Tickets',
                            value: '${row.tickets.length}',
                          ),
                        ],
                      ),
                      if (row.bankMovement != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          decoration: BoxDecoration(
                            color: tokens.primarySoft.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: tokens.primaryStrong.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 18,
                                color: tokens.primaryStrong,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Liquidada en bancos: ${dateFormatter(row.bankMovement!.date)} · ${row.bankMovement!.company} ${row.bankMovement!.branch} · ${moneyFormatter(row.bankMovement!.debitAmount > 0 ? row.bankMovement!.debitAmount : row.bankMovement!.creditAmount)} · ${row.bankMovement!.reference.isEmpty ? 'sin referencia' : row.bankMovement!.reference}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: kFinanzasMutedInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (row.tickets.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          row.tickets
                              .map((ticket) => ticket.ticket)
                              .toList(growable: false)
                              .join(' · '),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: kFinanzasMutedInk,
                          ),
                        ),
                      ],
                      if (row.invoice.notes.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          row.invoice.notes,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kFinanzasMutedInk,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ProviderAccountMovementsView extends StatelessWidget {
  final _ProviderAccountView account;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final Future<void> Function() onOpenBankAccounts;
  final Future<void> Function() onRegisterCashMovement;
  final Future<void> Function(ComprasProviderMovementRecord movement)
  onEditCashMovement;
  final Future<void> Function(ComprasProviderMovementRecord movement)
  onDeleteCashMovement;

  const _ProviderAccountMovementsView({
    required this.account,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onOpenBankAccounts,
    required this.onRegisterCashMovement,
    required this.onEditCashMovement,
    required this.onDeleteCashMovement,
  });

  @override
  Widget build(BuildContext context) {
    final timelineItems =
        <_ProviderMovementTimelineItem>[
          ...account.cashMovements.map(_ProviderMovementTimelineItem.cash),
          ...account.movements.map(_ProviderMovementTimelineItem.bank),
        ]..sort((a, b) {
          final aStamp = a.createdAt ?? a.date;
          final bStamp = b.createdAt ?? b.date;
          final createdCompare = bStamp.compareTo(aStamp);
          if (createdCompare != 0) return createdCompare;
          return b.date.compareTo(a.date);
        });
    final totalCredit =
        account.movements.fold<double>(
          0,
          (sum, row) => sum + row.creditAmount,
        ) +
        account.cashMovements.fold<double>(
          0,
          (sum, row) =>
              sum +
              ((row.type == 'ABONO' || row.type == 'PAGO') ? row.amount : 0),
        );
    final totalDebit =
        account.movements.fold<double>(0, (sum, row) => sum + row.debitAmount) +
        account.cashMovements.fold<double>(
          0,
          (sum, row) =>
              sum +
              ((row.type == 'CARGO' || row.type == 'AJUSTE') ? row.amount : 0),
        );
    final net = totalCredit - totalDebit;
    final totalItems = timelineItems.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Aquí ves bancos, efectivo y abonos directos en una sola línea de tiempo de creación real.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kFinanzasMutedInk,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _ActionPillButton(
              label: 'Registrar abono',
              icon: Icons.payments_outlined,
              onTap: onRegisterCashMovement,
            ),
            const SizedBox(width: 10),
            _ActionPillButton(
              label: 'Abrir bancos',
              icon: Icons.account_balance_outlined,
              onTap: onOpenBankAccounts,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SummaryMetricCard(label: 'Movimientos', value: '$totalItems'),
            _SummaryMetricCard(
              label: 'Abonos',
              value: moneyFormatter(totalCredit),
            ),
            _SummaryMetricCard(
              label: 'Cargos',
              value: moneyFormatter(totalDebit),
            ),
            _SummaryMetricCard(label: 'Neto', value: moneyFormatter(net)),
          ],
        ),
        const SizedBox(height: 14),
        if (totalItems == 0)
          Expanded(
            child: _ProviderAccountsPendingPane(
              label: 'Sin movimientos',
              subtitle:
                  'Todavía no hay pagos, abonos o cargos ligados a este proveedor.',
            ),
          )
        else
          Expanded(
            child: ListView(
              children: [
                for (final item in timelineItems) ...[
                  if (item.cashRow case final cashRow?)
                    _ProviderCashMovementCard(
                      row: cashRow,
                      moneyFormatter: moneyFormatter,
                      dateFormatter: dateFormatter,
                      onEdit: () => onEditCashMovement(cashRow),
                      onDelete: () => onDeleteCashMovement(cashRow),
                    )
                  else if (item.bankRow case final bankRow?)
                    _ProviderBankMovementCard(
                      row: bankRow,
                      moneyFormatter: moneyFormatter,
                      dateFormatter: dateFormatter,
                    ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ProviderAccountAgreementsView extends StatelessWidget {
  final _ProviderAccountView account;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final Future<void> Function() onRegisterAgreement;

  const _ProviderAccountAgreementsView({
    required this.account,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onRegisterAgreement,
  });

  @override
  Widget build(BuildContext context) {
    final totalItems = account.agreements.length;
    final totalCommitted = account.agreements.fold<double>(
      0,
      (sum, row) => sum + row.agreement.totalAmount,
    );
    final totalRemaining = account.agreements.fold<double>(
      0,
      (sum, row) => sum + row.agreement.remainingAmount,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Aquí vive el calendario de compromisos pactados con el proveedor.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kFinanzasMutedInk,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _ActionPillButton(
              label: 'Nuevo convenio',
              icon: Icons.event_note_outlined,
              onTap: onRegisterAgreement,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SummaryMetricCard(label: 'Convenios', value: '$totalItems'),
            _SummaryMetricCard(
              label: 'Comprometido',
              value: moneyFormatter(totalCommitted),
            ),
            _SummaryMetricCard(
              label: 'Restante',
              value: moneyFormatter(totalRemaining),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (account.agreements.isEmpty)
          Expanded(
            child: _ProviderAccountsPendingPane(
              label: 'Sin convenios',
              subtitle:
                  'Todavía no hay convenios registrados para este proveedor.',
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: account.agreements.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final row = account.agreements[index];
                final tone = _agreementTone(row.agreement.status);
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AreaThemeScope.of(
                        context,
                      ).primaryStrong.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${finSupplierAgreementFrequencyLabel(row.agreement.frequency)} · ${dateFormatter(row.agreement.startDate)}',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: AreaThemeScope.of(context).primaryStrong,
                              ),
                            ),
                          ),
                          _MiniToneChip(
                            label: finSupplierAgreementStatusLabel(
                              row.agreement.status,
                            ),
                            tone: tone,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _SummaryMetricCard(
                            label: 'Pago pactado',
                            value: moneyFormatter(
                              row.agreement.installmentAmount,
                            ),
                          ),
                          _SummaryMetricCard(
                            label: 'Pagos',
                            value: '${row.agreement.installmentCount}',
                          ),
                          _SummaryMetricCard(
                            label: 'Total',
                            value: moneyFormatter(row.agreement.totalAmount),
                          ),
                          _SummaryMetricCard(
                            label: 'Restante',
                            value: moneyFormatter(
                              row.agreement.remainingAmount,
                            ),
                          ),
                          _SummaryMetricCard(
                            label: 'Próximo',
                            value: dateFormatter(row.agreement.nextDueDate),
                          ),
                        ],
                      ),
                      if (row.installments.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Calendario',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AreaThemeScope.of(context).badgeText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final installment in row.installments)
                              Container(
                                width: 170,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.74),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _installmentTone(
                                      installment.status,
                                    ).withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pago ${installment.sequenceNumber}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: AreaThemeScope.of(
                                          context,
                                        ).primaryStrong,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      dateFormatter(installment.dueDate),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: kFinanzasMutedInk,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      moneyFormatter(installment.amount),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: AreaThemeScope.of(
                                          context,
                                        ).primaryStrong,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _MiniToneChip(
                                      label: _installmentStatusLabel(
                                        installment.status,
                                      ),
                                      tone: _installmentTone(
                                        installment.status,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (row.agreement.notes.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          row.agreement.notes,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: kFinanzasMutedInk,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ProviderMovementTimelineItem {
  final DateTime date;
  final DateTime? createdAt;
  final ComprasProviderMovementRecord? cashRow;
  final FinanzasBankMovementRecord? bankRow;

  const _ProviderMovementTimelineItem._({
    required this.date,
    required this.createdAt,
    this.cashRow,
    this.bankRow,
  });

  factory _ProviderMovementTimelineItem.cash(
    ComprasProviderMovementRecord row,
  ) {
    return _ProviderMovementTimelineItem._(
      date: row.date,
      createdAt: row.createdAt,
      cashRow: row,
    );
  }

  factory _ProviderMovementTimelineItem.bank(FinanzasBankMovementRecord row) {
    return _ProviderMovementTimelineItem._(
      date: row.date,
      createdAt: row.createdAt,
      bankRow: row,
    );
  }
}

class _ProviderBankMovementCard extends StatelessWidget {
  final FinanzasBankMovementRecord row;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;

  const _ProviderBankMovementCard({
    required this.row,
    required this.moneyFormatter,
    required this.dateFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final amount = row.creditAmount > 0 ? row.creditAmount : row.debitAmount;
    final tone = row.creditAmount > 0
        ? const Color(0xFF0F766E)
        : const Color(0xFFB42318);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.primaryStrong.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${row.company} ${row.branch}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: tokens.primaryStrong,
                  ),
                ),
              ),
              _MiniToneChip(
                label: row.creditAmount > 0 ? 'Abono' : 'Cargo',
                tone: tone,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryMetricCard(
                label: 'Fecha',
                value: dateFormatter(row.date),
              ),
              _SummaryMetricCard(label: 'Monto', value: moneyFormatter(amount)),
              _SummaryMetricCard(
                label: 'Origen',
                value: _bankMovementSourceLabel(row.sourceType),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            row.reference.trim().isEmpty ? 'Sin referencia' : row.reference,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: kFinanzasMutedInk,
            ),
          ),
          if (row.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              row.comment,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProviderCashMovementCard extends StatelessWidget {
  final ComprasProviderMovementRecord row;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;

  const _ProviderCashMovementCard({
    required this.row,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final positive = row.type == 'ABONO' || row.type == 'PAGO';
    final tone = positive ? const Color(0xFF0F766E) : const Color(0xFFB42318);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.primaryStrong.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.source,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: tokens.primaryStrong,
                  ),
                ),
              ),
              _MiniToneChip(
                label: _providerMovementTypeLabel(row.type),
                tone: tone,
              ),
              const SizedBox(width: 8),
              _MovementIconAction(
                icon: Icons.edit_outlined,
                color: tokens.primaryStrong,
                onTap: onEdit,
              ),
              const SizedBox(width: 8),
              _MovementIconAction(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFB42318),
                onTap: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryMetricCard(
                label: 'Fecha',
                value: dateFormatter(row.date),
              ),
              _SummaryMetricCard(
                label: 'Monto',
                value: moneyFormatter(row.amount),
              ),
              _SummaryMetricCard(label: 'Origen', value: row.source),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            row.reference.trim().isEmpty ? 'Sin referencia' : row.reference,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: kFinanzasMutedInk,
            ),
          ),
          if (row.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              row.notes,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MovementIconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;

  const _MovementIconAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async => onTap(),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _AgreementDraftResult {
  final DateTime startDate;
  final String frequency;
  final double installmentAmount;
  final int installmentCount;
  final String notes;

  const _AgreementDraftResult({
    required this.startDate,
    required this.frequency,
    required this.installmentAmount,
    required this.installmentCount,
    required this.notes,
  });
}

class _RegisterSupplierAgreementDialog extends StatefulWidget {
  final String providerName;
  final double suggestedBalance;

  const _RegisterSupplierAgreementDialog({
    required this.providerName,
    required this.suggestedBalance,
  });

  @override
  State<_RegisterSupplierAgreementDialog> createState() =>
      _RegisterSupplierAgreementDialogState();
}

class _RegisterSupplierAgreementDialogState
    extends State<_RegisterSupplierAgreementDialog> {
  late final TextEditingController _amountC;
  late final TextEditingController _countC;
  late final TextEditingController _notesC;
  DateTime _startDate = DateUtils.dateOnly(DateTime.now());
  String _frequency = 'SEMANAL';

  @override
  void initState() {
    super.initState();
    _amountC = TextEditingController();
    _countC = TextEditingController(text: '4');
    _notesC = TextEditingController();
    _amountC.addListener(_refresh);
    _countC.addListener(_refresh);
    _notesC.addListener(_refresh);
  }

  @override
  void dispose() {
    _amountC.dispose();
    _countC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  double _parseAmount(String raw) {
    final cleaned = raw.replaceAll(',', '').replaceAll('\$', '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  int _parseCount(String raw) {
    return int.tryParse(raw.trim()) ?? 0;
  }

  bool get _canSave =>
      _parseAmount(_amountC.text) > 0 && _parseCount(_countC.text) > 0;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => AreaThemeScope(
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
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _startDate = DateUtils.dateOnly(picked));
  }

  String _dateLabel(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final total = _parseAmount(_amountC.text) * _parseCount(_countC.text);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: ContractGlassCard(
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nuevo convenio',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AreaThemeScope.of(context).primaryStrong,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.providerName} · Saldo sugerido ${_moneyStatic(widget.suggestedBalance)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kFinanzasMutedInk,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _InlineChoiceField(
                        label: 'Inicio',
                        value: _dateLabel(_startDate),
                        onTap: () {
                          unawaited(_pickDate());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InlineChoiceField(
                        label: 'Frecuencia',
                        value: finSupplierAgreementFrequencyLabel(_frequency),
                        onTap: () {
                          unawaited(() async {
                            final selected = await _showSimpleOptionsDialog(
                              context: context,
                              title: 'Seleccionar frecuencia',
                              options: const [
                                _SimpleOption(
                                  id: 'SEMANAL',
                                  label: 'Semanal',
                                  subtitle: 'Cada 7 días',
                                ),
                                _SimpleOption(
                                  id: 'QUINCENAL',
                                  label: 'Quincenal',
                                  subtitle: 'Cada 15 días',
                                ),
                                _SimpleOption(
                                  id: 'MENSUAL',
                                  label: 'Mensual',
                                  subtitle: 'Cada mes',
                                ),
                              ],
                            );
                            if (selected == null) return;
                            setState(() => _frequency = selected.id);
                          }());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amountC,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: contractGlassFieldDecoration(
                          context,
                          hintText: 'Monto por pago',
                          prefixIcon: const Icon(Icons.payments_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _countC,
                        keyboardType: TextInputType.number,
                        decoration: contractGlassFieldDecoration(
                          context,
                          hintText: 'Número de pagos',
                          prefixIcon: const Icon(Icons.format_list_numbered),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SummaryMetricCard(
                      label: 'Total convenio',
                      value: _moneyStatic(total),
                    ),
                    _SummaryMetricCard(
                      label: 'Frecuencia',
                      value: finSupplierAgreementFrequencyLabel(_frequency),
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
                    hintText: 'Notas del convenio',
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                  ),
                ),
                const SizedBox(height: 16),
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
                                _AgreementDraftResult(
                                  startDate: _startDate,
                                  frequency: _frequency,
                                  installmentAmount: _parseAmount(
                                    _amountC.text,
                                  ),
                                  installmentCount: _parseCount(_countC.text),
                                  notes: _notesC.text.trim(),
                                ),
                              );
                            },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar convenio'),
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

class _ProviderAccountsPendingPane extends StatelessWidget {
  final String label;
  final String subtitle;

  const _ProviderAccountsPendingPane({
    required this.label,
    required this.subtitle,
  });

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
              Icons.space_dashboard_outlined,
              size: 34,
              color: tokens.primaryStrong,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
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

class _ProviderAccountsEmptyDetail extends StatelessWidget {
  const _ProviderAccountsEmptyDetail();

  @override
  Widget build(BuildContext context) {
    return const _ProviderAccountsPendingPane(
      label: 'Sin cuenta seleccionada',
      subtitle:
          'Selecciona un proveedor para revisar resumen, tickets y saldo abierto.',
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      width: 176,
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

class _LongInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _LongInfoCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      width: 260,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.border.withValues(alpha: 0.84)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
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
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kFinanzasMutedInk,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTabChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DetailTabChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: active
          ? tokens.primaryStrong.withValues(alpha: 0.92)
          : Colors.white.withValues(alpha: 0.66),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: active ? Colors.white : tokens.primaryStrong,
            ),
          ),
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
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: tone,
        ),
      ),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Future<void> Function() onTap;

  const _ActionPillButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async => onTap(),
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.primaryStrong.withValues(alpha: 0.96),
                tokens.primary.withValues(alpha: 0.92),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: tokens.glow.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketHeaderCell extends StatelessWidget {
  final double width;
  final String label;

  const _TicketHeaderCell({required this.width, required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: tokens.badgeText,
          ),
        ),
      ),
    );
  }
}

class _TicketValueCell extends StatelessWidget {
  final double width;
  final String text;
  final bool bold;

  const _TicketValueCell({
    required this.width,
    required this.text,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: kFinanzasInk,
          ),
        ),
      ),
    );
  }
}

class _TicketBadgeCell extends StatelessWidget {
  final double width;
  final String label;
  final Color tone;

  const _TicketBadgeCell({
    required this.width,
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerLeft,
        child: _MiniToneChip(label: label, tone: tone),
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

Color _coverageTone(String status) {
  switch (status) {
    case 'CUBIERTO':
      return const Color(0xFF0F766E);
    case 'PARCIAL':
      return const Color(0xFF8B5E00);
    default:
      return const Color(0xFF7A1914);
  }
}

Color _invoiceTone(String status) {
  switch (status) {
    case 'PAGADA':
      return const Color(0xFF0F766E);
    case 'PARCIAL':
      return const Color(0xFF8B5E00);
    case 'VENCIDA':
      return const Color(0xFFB42318);
    case 'CONVENIO':
      return const Color(0xFF7A1914);
    default:
      return const Color(0xFF7A1914);
  }
}

String _finPaymentStageLabel(String status) {
  switch (status) {
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

String _bankMovementSourceLabel(String status) {
  switch (status) {
    case 'COMPRA_FACTURA':
      return 'Factura proveedor';
    case 'VENTA_FACTURA':
      return 'Pago cliente';
    default:
      return 'Movimiento libre';
  }
}

String _providerMovementTypeLabel(String status) {
  switch (status) {
    case 'PAGO':
      return 'Pago';
    case 'CARGO':
      return 'Cargo';
    case 'AJUSTE':
      return 'Ajuste';
    default:
      return 'Abono';
  }
}

DateTime _agreementInstallmentDate({
  required DateTime startDate,
  required String frequency,
  required int offset,
}) {
  switch (frequency) {
    case 'QUINCENAL':
      return DateUtils.dateOnly(startDate.add(Duration(days: 15 * offset)));
    case 'MENSUAL':
      return DateTime(startDate.year, startDate.month + offset, startDate.day);
    default:
      return DateUtils.dateOnly(startDate.add(Duration(days: 7 * offset)));
  }
}

Color _agreementTone(String status) {
  switch (status) {
    case 'CUMPLIDO':
      return const Color(0xFF0F766E);
    case 'ATRASADO':
      return const Color(0xFFB42318);
    case 'CANCELADO':
      return const Color(0xFF6B7280);
    default:
      return const Color(0xFF8B5E00);
  }
}

Color _installmentTone(String status) {
  switch (status) {
    case 'PAGADO':
      return const Color(0xFF0F766E);
    case 'VENCIDO':
      return const Color(0xFFB42318);
    default:
      return const Color(0xFF8B5E00);
  }
}

String _installmentStatusLabel(String status) {
  switch (status) {
    case 'PAGADO':
      return 'Pagado';
    case 'VENCIDO':
      return 'Vencido';
    default:
      return 'Pendiente';
  }
}

String _moneyStatic(double value) {
  final negative = value < 0;
  final absolute = value.abs();
  final fixed = absolute.toStringAsFixed(2);
  final parts = fixed.split('.');
  final integer = parts.first;
  final decimal = parts.length > 1 ? parts[1] : '00';
  final buffer = StringBuffer();
  for (var i = 0; i < integer.length; i++) {
    final reversedIndex = integer.length - i;
    buffer.write(integer[i]);
    if (reversedIndex > 1 && reversedIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return '${negative ? '-' : ''}\$${buffer.toString()}.$decimal';
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

class _ProviderCashMovementDraft {
  final DateTime date;
  final String type;
  final String source;
  final double amount;
  final String reference;
  final String notes;

  const _ProviderCashMovementDraft({
    required this.date,
    required this.type,
    required this.source,
    required this.amount,
    required this.reference,
    required this.notes,
  });
}

class _RegisterProviderCashMovementDialog extends StatefulWidget {
  final String providerName;
  final ComprasProviderMovementRecord? initialMovement;

  const _RegisterProviderCashMovementDialog({
    required this.providerName,
    this.initialMovement,
  });

  @override
  State<_RegisterProviderCashMovementDialog> createState() =>
      _RegisterProviderCashMovementDialogState();
}

class _RegisterProviderCashMovementDialogState
    extends State<_RegisterProviderCashMovementDialog> {
  late final TextEditingController _amountC;
  late final TextEditingController _referenceC;
  late final TextEditingController _notesC;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  String _type = 'ABONO';
  String _source = 'EFECTIVO';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMovement;
    _amountC = TextEditingController(
      text: initial == null ? '' : initial.amount.toStringAsFixed(2),
    );
    _referenceC = TextEditingController(text: initial?.reference ?? '');
    _notesC = TextEditingController(text: initial?.notes ?? '');
    _date = DateUtils.dateOnly(initial?.date ?? DateTime.now());
    _type = initial?.type ?? 'ABONO';
    _source = initial?.source ?? 'EFECTIVO';
    _amountC.addListener(_refresh);
    _referenceC.addListener(_refresh);
    _notesC.addListener(_refresh);
  }

  @override
  void dispose() {
    _amountC.dispose();
    _referenceC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  double _parseAmount(String raw) {
    final cleaned = raw.replaceAll(',', '').replaceAll('\$', '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  bool get _canSave => _parseAmount(_amountC.text) > 0;

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

  String _dateLabel(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final isEditing = widget.initialMovement != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: ContractGlassCard(
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Editar movimiento' : 'Registrar abono',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: tokens.primaryStrong,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isEditing
                      ? '${widget.providerName} · Al guardar se recalculará la aplicación del movimiento en tickets abiertos.'
                      : '${widget.providerName} · Se aplicará por antigüedad al saldo abierto del proveedor.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kFinanzasMutedInk,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _InlineChoiceField(
                        label: 'Tipo',
                        value: _providerMovementTypeLabel(_type),
                        onTap: () {
                          unawaited(() async {
                            final selected = await _showSimpleOptionsDialog(
                              context: context,
                              title: 'Seleccionar tipo',
                              options: const [
                                _SimpleOption(
                                  id: 'ABONO',
                                  label: 'Abono',
                                  subtitle: 'Reduce saldo del proveedor',
                                ),
                                _SimpleOption(
                                  id: 'PAGO',
                                  label: 'Pago',
                                  subtitle: 'Liquida saldo del proveedor',
                                ),
                                _SimpleOption(
                                  id: 'CARGO',
                                  label: 'Cargo',
                                  subtitle: 'Aumenta saldo del proveedor',
                                ),
                                _SimpleOption(
                                  id: 'AJUSTE',
                                  label: 'Ajuste',
                                  subtitle: 'Corrección manual',
                                ),
                              ],
                            );
                            if (selected == null) return;
                            setState(() => _type = selected.id);
                          }());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InlineChoiceField(
                        label: 'Origen',
                        value: _source,
                        onTap: () {
                          unawaited(() async {
                            final selected = await _showSimpleOptionsDialog(
                              context: context,
                              title: 'Seleccionar origen',
                              options: const [
                                _SimpleOption(
                                  id: 'EFECTIVO',
                                  label: 'Efectivo',
                                  subtitle: 'Pago directo en efectivo',
                                ),
                                _SimpleOption(
                                  id: 'BOVEDA',
                                  label: 'Bóveda',
                                  subtitle: 'Sale de caja/bóveda',
                                ),
                                _SimpleOption(
                                  id: 'INTERNO',
                                  label: 'Interno',
                                  subtitle: 'Ajuste o movimiento interno',
                                ),
                                _SimpleOption(
                                  id: 'BANCO',
                                  label: 'Banco',
                                  subtitle: 'Registro manual desde banco',
                                ),
                              ],
                            );
                            if (selected == null) return;
                            setState(() => _source = selected.id);
                          }());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InlineChoiceField(
                        label: 'Fecha',
                        value: _dateLabel(_date),
                        onTap: () {
                          unawaited(_pickDate());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
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
                      child: TextField(
                        controller: _referenceC,
                        decoration: contractGlassFieldDecoration(
                          context,
                          hintText: 'Referencia',
                          prefixIcon: const Icon(
                            Icons.confirmation_num_outlined,
                          ),
                        ),
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
                    hintText: 'Notas del movimiento',
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                  ),
                ),
                const SizedBox(height: 16),
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
                                _ProviderCashMovementDraft(
                                  date: _date,
                                  type: _type,
                                  source: _source,
                                  amount: _parseAmount(_amountC.text),
                                  reference: _referenceC.text.trim(),
                                  notes: _notesC.text.trim(),
                                ),
                              );
                            },
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        isEditing ? 'Guardar cambios' : 'Guardar movimiento',
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AreaThemeScope.of(context).primaryStrong,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.expand_more_rounded,
                color: AreaThemeScope.of(context).primaryStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceDraftResult {
  final String folio;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final String notes;
  final Set<String> selectedTicketIds;

  const _InvoiceDraftResult({
    required this.folio,
    required this.invoiceDate,
    required this.dueDate,
    required this.notes,
    required this.selectedTicketIds,
  });
}

class _RegisterSupplierInvoiceDialog extends StatefulWidget {
  final String companyName;
  final List<ComprasTicketRecord> tickets;

  const _RegisterSupplierInvoiceDialog({
    required this.companyName,
    required this.tickets,
  });

  @override
  State<_RegisterSupplierInvoiceDialog> createState() =>
      _RegisterSupplierInvoiceDialogState();
}

class _RegisterSupplierInvoiceDialogState
    extends State<_RegisterSupplierInvoiceDialog> {
  late final TextEditingController _folioC;
  late final TextEditingController _notesC;
  late DateTime _invoiceDate;
  DateTime? _dueDate;
  late Set<String> _selectedTicketIds;

  @override
  void initState() {
    super.initState();
    _folioC = TextEditingController();
    _notesC = TextEditingController();
    _invoiceDate = DateUtils.dateOnly(DateTime.now());
    _selectedTicketIds = widget.tickets.map((ticket) => ticket.id).toSet();
  }

  @override
  void dispose() {
    _folioC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  double get _selectedTotal => widget.tickets
      .where((ticket) => _selectedTicketIds.contains(ticket.id))
      .fold<double>(0, (sum, ticket) => sum + ticket.amount);

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

  String _dateLabel(DateTime? value) {
    if (value == null) return 'Sin fecha';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  Future<void> _pickInvoiceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
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
    setState(() => _invoiceDate = DateUtils.dateOnly(picked));
  }

  Future<void> _pickDueDate() async {
    final initial = _dueDate ?? _invoiceDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
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
    setState(() => _dueDate = DateUtils.dateOnly(picked));
  }

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
            constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
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
                            'Registrar factura',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: tokens.primaryStrong,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.companyName,
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _folioC,
                        onChanged: (_) => setState(() {}),
                        decoration: contractGlassFieldDecoration(
                          context,
                          hintText: 'Folio de factura',
                          prefixIcon: const Icon(Icons.receipt_long_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateFieldButton(
                        label: 'Fecha factura',
                        value: _dateLabel(_invoiceDate),
                        onTap: _pickInvoiceDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateFieldButton(
                        label: 'Fecha límite',
                        value: _dateLabel(_dueDate),
                        onTap: _pickDueDate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesC,
                  minLines: 2,
                  maxLines: 3,
                  decoration: contractGlassFieldDecoration(
                    context,
                    hintText: 'Notas de factura o convenio',
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Tickets elegibles',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: tokens.primaryStrong,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_selectedTicketIds.length} seleccionados · ${_money(_selectedTotal)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: kFinanzasMutedInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: widget.tickets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final row = widget.tickets[index];
                      final selected = _selectedTicketIds.contains(row.id);
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedTicketIds.remove(row.id);
                              } else {
                                _selectedTicketIds.add(row.id);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Ink(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                            decoration: BoxDecoration(
                              color: selected
                                  ? tokens.badgeBackground.withValues(
                                      alpha: 0.86,
                                    )
                                  : Colors.white.withValues(alpha: 0.76),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected
                                    ? tokens.primaryStrong.withValues(
                                        alpha: 0.32,
                                      )
                                    : tokens.border.withValues(alpha: 0.70),
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: selected,
                                  onChanged: (_) {
                                    setState(() {
                                      if (selected) {
                                        _selectedTicketIds.remove(row.id);
                                      } else {
                                        _selectedTicketIds.add(row.id);
                                      }
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${row.ticket} · ${row.materialNameSnapshot}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: tokens.primaryStrong,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_dateLabel(row.date)} · ${row.providerNameSnapshot}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: kFinanzasMutedInk,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _money(row.amount),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: tokens.primaryStrong,
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed:
                          _folioC.text.trim().isEmpty ||
                              _selectedTicketIds.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).pop(
                                _InvoiceDraftResult(
                                  folio: _folioC.text.trim(),
                                  invoiceDate: _invoiceDate,
                                  dueDate: _dueDate,
                                  notes: _notesC.text.trim(),
                                  selectedTicketIds: _selectedTicketIds,
                                ),
                              );
                            },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar factura'),
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

class _DateFieldButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateFieldButton({
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
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.border.withValues(alpha: 0.9)),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: tokens.primaryStrong),
              const SizedBox(width: 10),
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
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: tokens.primaryStrong,
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

class _FinProviderAccountsBackground extends StatelessWidget {
  const _FinProviderAccountsBackground();

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
          child: _FinBackgroundCircle(760, [
            const Color(0xFFFFF6F4),
            const Color(0xFFF2C0BC),
          ]),
        ),
        Positioned(
          right: -180,
          top: -70,
          child: _FinBackgroundCircle(580, [
            const Color(0xFFBC2D25),
            const Color(0x33241313),
          ]),
        ),
        Positioned(
          left: 20,
          bottom: -260,
          child: _FinBackgroundCircle(640, [
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

class _FinBackgroundCircle extends StatelessWidget {
  final double diameter;
  final List<Color> colors;

  const _FinBackgroundCircle(this.diameter, this.colors);

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

class _FinProviderAccountsHeaderBrand extends StatelessWidget {
  const _FinProviderAccountsHeaderBrand();

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
          'Cuentas',
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

class _FinHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _FinHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_FinHeaderButton> createState() => _FinHeaderButtonState();
}

class _FinHeaderButtonState extends State<_FinHeaderButton> {
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

class _FinProviderAccountsSidePanel extends StatelessWidget {
  final bool canReturnToDirection;
  final bool canAccessComprasArea;
  final ValueChanged<String> onNavigate;

  const _FinProviderAccountsSidePanel({
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
                  _FinSideNavItem(
                    icon: Icons.arrow_back_rounded,
                    title: 'Volver a Dirección',
                    onTap: () async => onNavigate('Dashboard Dirección'),
                  ),
                  const SizedBox(height: 10),
                ],
                const _FinSideSectionHeader(label: 'AREA'),
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
                      _FinSideNavItem(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Dashboard Finanzas',
                        subtitle: 'Pagos, liquidez y compromisos',
                        onTap: () async => onNavigate('Dashboard Finanzas'),
                      ),
                      const SizedBox(height: 8),
                      _FinSideNavItem(
                        icon: Icons.price_check_rounded,
                        title: 'Catálogo Finanzas',
                        subtitle: 'Empresas, conceptos y relaciones',
                        onTap: () async => onNavigate('Catálogo Finanzas'),
                      ),
                      const SizedBox(height: 8),
                      _FinSideNavItem(
                        icon: Icons.account_balance_rounded,
                        title: 'Directorio Empresas',
                        subtitle: 'Crédito, contacto y operación',
                        onTap: () async => onNavigate('Directorio Empresas'),
                      ),
                      const SizedBox(height: 8),
                      _FinSideNavItem(
                        icon: Icons.view_list_rounded,
                        title: 'Cuentas por Proveedor',
                        subtitle: 'Resumen, tickets y saldo',
                        accented: true,
                        onTap: () async {},
                      ),
                      const SizedBox(height: 8),
                      _FinSideNavItem(
                        icon: Icons.account_balance_outlined,
                        title: 'Cuentas Bancarias',
                        subtitle: 'Entradas, salidas y bancos',
                        onTap: () async => onNavigate('Cuentas Bancarias'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const _FinSideSectionHeader(label: 'ACCESOS'),
                const SizedBox(height: 8),
                if (canReturnToDirection) ...[
                  _FinSideNavItem(
                    icon: Icons.assessment_outlined,
                    title: 'Dashboard Dirección',
                    subtitle: 'Vista ejecutiva multiarea',
                    onTap: () async => onNavigate('Dashboard Dirección'),
                  ),
                  const SizedBox(height: 8),
                ],
                if (canAccessComprasArea)
                  _FinSideNavItem(
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

class _FinSideSectionHeader extends StatelessWidget {
  final String label;
  const _FinSideSectionHeader({required this.label});

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

class _FinSideNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool accented;
  final Future<void> Function()? onTap;

  const _FinSideNavItem({
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
                      tokens.surfaceTint.withValues(alpha: 0.66),
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
