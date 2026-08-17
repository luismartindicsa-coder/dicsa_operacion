import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../compras/compras_dashboard_page.dart';
import '../compras/compras_tickets_store.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/archetypes/auxiliary_surfaces/confirmation_dialog.dart';
import '../shared/page_routes.dart';
import '../shared/utils/csv_file_save.dart';
import '../shared/utils/file_download_save.dart';
import '../shared/ui_contract_core/dialogs/contract_popup_surface.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/date_picker_defaults.dart';
import 'finanzas_bank_accounts_store.dart';
import 'finanzas_bank_accounts_page.dart';
import 'finanzas_catalog_page.dart';
import 'finanzas_company_directory_page.dart';
import 'finanzas_company_directory_store.dart';
import 'finanzas_dashboard_page.dart';
import 'finanzas_evidence_store.dart';
import 'finanzas_fixed_payments_page.dart';
import 'finanzas_payment_center_page.dart';
import 'finanzas_provider_excel_templates.dart';
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

DateTime _agreementInvoiceAnchorDate(FinanzasSupplierInvoiceRecord invoice) {
  final anchor = invoice.dueDate ?? invoice.invoiceDate;
  return DateUtils.dateOnly(anchor);
}

int _compareAgreementInvoices(
  FinanzasSupplierInvoiceRecord a,
  FinanzasSupplierInvoiceRecord b,
) {
  final anchorCompare = _agreementInvoiceAnchorDate(
    a,
  ).compareTo(_agreementInvoiceAnchorDate(b));
  if (anchorCompare != 0) return anchorCompare;
  final invoiceDateCompare = DateUtils.dateOnly(
    a.invoiceDate,
  ).compareTo(DateUtils.dateOnly(b.invoiceDate));
  if (invoiceDateCompare != 0) return invoiceDateCompare;
  final folioCompare = a.folio.trim().toLowerCase().compareTo(
    b.folio.trim().toLowerCase(),
  );
  if (folioCompare != 0) return folioCompare;
  return a.id.compareTo(b.id);
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
      ComprasTicketsStore.loadTicketPaymentApplications(),
      FinanzasProviderAccountsStore.loadAgreements(),
      FinanzasProviderAccountsStore.loadAgreementInstallments(),
      FinanzasProviderAccountsStore.loadAgreementInvoices(),
      FinanzasEvidenceStore.loadByOwnerType(
        kFinanzasEvidenceOwnerTypeSupplierInvoice,
      ),
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
    final ticketApplications =
        results[6] as List<ComprasTicketPaymentApplicationRecord>;
    final agreements = results[7] as List<FinanzasSupplierAgreementRecord>;
    final agreementInstallments =
        results[8] as List<FinanzasSupplierAgreementInstallmentRecord>;
    final agreementInvoices =
        results[9] as List<FinanzasSupplierAgreementInvoiceRecord>;
    final invoiceEvidences = results[10] as List<FinanzasEvidenceRecord>;
    final accounts = _buildAccounts(
      directory,
      tickets,
      invoices,
      invoiceTickets,
      bankMovements,
      providerCashMovements,
      ticketApplications,
      agreements,
      agreementInstallments,
      agreementInvoices,
      invoiceEvidences,
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
    List<ComprasTicketPaymentApplicationRecord> ticketApplications,
    List<FinanzasSupplierAgreementRecord> agreements,
    List<FinanzasSupplierAgreementInstallmentRecord> agreementInstallments,
    List<FinanzasSupplierAgreementInvoiceRecord> agreementInvoices,
    List<FinanzasEvidenceRecord> invoiceEvidences,
  ) {
    final providerDirectory = directory
        .where(
          (company) =>
              company.active && company.source.trim().toUpperCase() != 'VENTAS',
        )
        .toList(growable: false);
    final comprasProviderIdByAlias = <String, String>{};
    final byProviderId = <String, List<ComprasTicketRecord>>{};
    for (final row in tickets) {
      byProviderId
          .putIfAbsent(row.providerId, () => <ComprasTicketRecord>[])
          .add(row);
      final aliasKey = _normalizedProviderAliasKey(row.providerNameSnapshot);
      if (aliasKey.isNotEmpty) {
        comprasProviderIdByAlias.putIfAbsent(aliasKey, () => row.providerId);
      }
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
    final invoicesByProviderNameKey =
        <String, List<FinanzasSupplierInvoiceRecord>>{};
    for (final invoice in invoices) {
      invoicesByProviderId
          .putIfAbsent(
            invoice.providerId,
            () => <FinanzasSupplierInvoiceRecord>[],
          )
          .add(invoice);
      final providerNameKey = _normalizedProviderAliasKey(
        invoice.providerNameSnapshot,
      );
      if (providerNameKey.isNotEmpty) {
        invoicesByProviderNameKey
            .putIfAbsent(
              providerNameKey,
              () => <FinanzasSupplierInvoiceRecord>[],
            )
            .add(invoice);
      }
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
    final agreementsByProviderNameKey =
        <String, List<FinanzasSupplierAgreementRecord>>{};
    for (final agreement in agreements) {
      agreementsByProviderId
          .putIfAbsent(
            agreement.providerId,
            () => <FinanzasSupplierAgreementRecord>[],
          )
          .add(agreement);
      final providerNameKey = _normalizedProviderAliasKey(
        agreement.providerNameSnapshot,
      );
      if (providerNameKey.isNotEmpty) {
        agreementsByProviderNameKey
            .putIfAbsent(
              providerNameKey,
              () => <FinanzasSupplierAgreementRecord>[],
            )
            .add(agreement);
      }
    }
    final invoicesById = <String, FinanzasSupplierInvoiceRecord>{
      for (final invoice in invoices) invoice.id: invoice,
    };
    final agreementInvoiceLinksByAgreementId =
        <String, List<FinanzasSupplierAgreementInvoiceRecord>>{};
    for (final link in agreementInvoices) {
      agreementInvoiceLinksByAgreementId
          .putIfAbsent(
            link.agreementId,
            () => <FinanzasSupplierAgreementInvoiceRecord>[],
          )
          .add(link);
    }
    for (final rows in agreementInvoiceLinksByAgreementId.values) {
      rows.sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
    }
    final evidencesByInvoiceId = <String, List<FinanzasEvidenceRecord>>{};
    for (final evidence in invoiceEvidences) {
      evidencesByInvoiceId
          .putIfAbsent(evidence.ownerId, () => <FinanzasEvidenceRecord>[])
          .add(evidence);
    }
    final providerMovementById = <String, ComprasProviderMovementRecord>{
      for (final row in providerCashMovements) row.id: row,
    };
    final ticketApplicationsByTicketId =
        <String, List<_ProviderTicketApplicationView>>{};
    for (final application in ticketApplications) {
      final movement = providerMovementById[application.providerMovementId];
      if (movement == null) continue;
      ticketApplicationsByTicketId
          .putIfAbsent(
            application.ticketId,
            () => <_ProviderTicketApplicationView>[],
          )
          .add(
            _ProviderTicketApplicationView(
              application: application,
              movement: movement,
            ),
          );
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final accounts =
        providerDirectory
            .map((company) {
              final comprasProviderId = _resolveComprasProviderId(
                company,
                comprasProviderIdByAlias,
              );
              final companyTickets =
                  byProviderId[comprasProviderId]?.toList(growable: false) ??
                  <ComprasTicketRecord>[];
              companyTickets.sort((a, b) => b.date.compareTo(a.date));
              final rows = companyTickets;
              final companyNameKey = _normalizedProviderAliasKey(
                company.linkedName.trim().isNotEmpty
                    ? company.linkedName
                    : company.companyName,
              );
              final providerInvoices =
                  <FinanzasSupplierInvoiceRecord>[
                        ...?invoicesByProviderId[company.companyId],
                        if (companyNameKey.isNotEmpty)
                          ...?invoicesByProviderNameKey[companyNameKey],
                      ]
                      .fold<Map<String, FinanzasSupplierInvoiceRecord>>(
                        <String, FinanzasSupplierInvoiceRecord>{},
                        (acc, invoice) {
                          acc[invoice.id] = invoice;
                          return acc;
                        },
                      )
                      .values
                      .toList(growable: false);
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
                  <FinanzasSupplierAgreementRecord>[
                        ...?agreementsByProviderId[company.companyId],
                        if (companyNameKey.isNotEmpty)
                          ...?agreementsByProviderNameKey[companyNameKey],
                      ]
                      .fold<Map<String, FinanzasSupplierAgreementRecord>>(
                        <String, FinanzasSupplierAgreementRecord>{},
                        (acc, agreement) {
                          acc[agreement.id] = agreement;
                          return acc;
                        },
                      )
                      .values
                      .map(
                        (agreement) => _ProviderAgreementView(
                          agreement: agreement,
                          installments:
                              agreementInstallmentsByAgreementId[agreement.id]
                                  ?.toList(growable: false) ??
                              <FinanzasSupplierAgreementInstallmentRecord>[],
                          invoiceLinks:
                              agreementInvoiceLinksByAgreementId[agreement.id]
                                  ?.map((link) {
                                    final invoice =
                                        invoicesById[link.invoiceId];
                                    if (invoice == null) return null;
                                    return _ProviderAgreementInvoiceLinkView(
                                      link: link,
                                      invoice: invoice,
                                    );
                                  })
                                  .whereType<
                                    _ProviderAgreementInvoiceLinkView
                                  >()
                                  .toList(growable: false) ??
                              <_ProviderAgreementInvoiceLinkView>[],
                        ),
                      )
                      .toList(growable: false);
              providerAgreements.sort(
                (a, b) =>
                    b.agreement.startDate.compareTo(a.agreement.startDate),
              );
              final providerInvoiceViews = providerInvoices
                  .map(
                    (invoice) => _ProviderInvoiceView(
                      invoice: invoice,
                      bankMovement: bankMovementByInvoiceId[invoice.id],
                      tickets:
                          invoiceTicketsByInvoiceId[invoice.id]?.toList(
                            growable: false,
                          ) ??
                          const <ComprasTicketRecord>[],
                      evidences:
                          evidencesByInvoiceId[invoice.id]?.toList(
                            growable: false,
                          ) ??
                          const <FinanzasEvidenceRecord>[],
                    ),
                  )
                  .toList(growable: false);
              final payableSummary = _computeProviderPayableSummary(
                invoices: providerInvoices,
                movements: providerMovements,
              );
              final reconciledTicketStatuses = _buildReconciledTicketStatuses(
                tickets: rows,
                invoices: providerInvoiceViews,
                ticketApplicationsByTicketId: ticketApplicationsByTicketId,
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
                final resolved =
                    reconciledTicketStatuses[ticket.id] ??
                    _ProviderTicketStatusView(
                      appliedAmount: 0,
                      pagoStatus: ticket.pagoStatus,
                      coverageStatus: ticket.coverageStatus,
                    );
                total += ticket.amount;
                if (ticket.amount <= 0.009) {
                  open += ticket.amount;
                  if (ticket.facturaStatus == 'FACTURADO') {
                    facturado += ticket.amount;
                  } else if (ticket.facturaStatus == 'SIN_FACTURA') {
                    sinFactura += ticket.amount;
                  } else {
                    pendienteFacturar += ticket.amount;
                  }
                  continue;
                }
                final dueDate = DateUtils.dateOnly(
                  ticket.date.add(Duration(days: company.creditDays)),
                );
                if (resolved.pagoStatus == 'PAGADO') {
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
              for (final invoiceRow in providerInvoiceViews) {
                if (!_isManualSupplierInvoice(invoiceRow)) continue;
                final invoice = invoiceRow.invoice;
                total += invoice.totalAmount;
                if (invoice.status == 'PAGADA') {
                  pagado += invoice.totalAmount;
                  continue;
                }
                open += invoice.balanceAmount;
                facturado += invoice.balanceAmount;
                if (invoice.balanceAmount > 0.009 && invoice.dueDate != null) {
                  final dueDate = DateUtils.dateOnly(invoice.dueDate!);
                  if (dueDate.isBefore(today) || dueDate == today) {
                    vencido += invoice.balanceAmount;
                  }
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
                reconciledTicketStatuses: reconciledTicketStatuses,
                invoices: providerInvoiceViews,
                movements: providerMovements,
                cashMovements: providerCashMovementRows,
                agreements: providerAgreements,
                ticketApplicationsByTicketId: ticketApplicationsByTicketId,
                totalAmount: total,
                openAmount: open,
                facturadoAmount: facturado,
                sinFacturaAmount: sinFactura,
                pendienteFacturarAmount: pendienteFacturar,
                paidAmount: pagado,
                overdueAmount: vencido,
                openTicketsCount: abiertos,
                nextCommitmentDate: nextCommitment,
                payableAmount: payableSummary.amount,
                openInvoicesCount: payableSummary.openInvoicesCount,
                nextPayableDate: payableSummary.nextDueDate,
                urgencyLabel: urgency.$1,
                urgencyTone: urgency.$2,
                recommendation: recommendation,
              );
            })
            .toList(growable: false)
          ..sort((a, b) {
            final diff = b.payableAmount.compareTo(a.payableAmount);
            if (diff != 0) return diff;
            return a.company.companyName.compareTo(b.company.companyName);
          });
    return accounts;
  }

  String _resolveComprasProviderId(
    FinanzasCompanyDirectoryRecord company,
    Map<String, String> comprasProviderIdByAlias,
  ) {
    if (company.source.trim().toUpperCase() == 'COMPRAS' &&
        company.companyId.startsWith('compras_')) {
      return company.companyId.substring('compras_'.length);
    }
    final aliasKey = _normalizedProviderAliasKey(
      company.linkedName.trim().isNotEmpty
          ? company.linkedName
          : company.companyName,
    );
    final aliasMatch = comprasProviderIdByAlias[aliasKey];
    if (aliasMatch != null && aliasMatch.trim().isNotEmpty) {
      return aliasMatch;
    }
    return company.companyId;
  }

  (String, String) _suggestTargetForProvider(
    FinanzasCompanyDirectoryRecord company,
  ) {
    final raw =
        '${company.companyName} ${company.linkedName} ${company.location} ${company.paymentNotes}'
            .toUpperCase();
    final targetCompany = raw.contains('VH') ? 'VH' : 'DICSA';
    final targetBranch = raw.contains('MAZATLAN') ? 'MAZATLAN' : 'CELAYA';
    return (targetCompany, targetBranch);
  }

  (String, Color) _buildUrgency({
    required String paymentStage,
    required double openAmount,
    required double overdueAmount,
  }) {
    if (openAmount <= 0) return ('Sin saldo', kFinanzasSage);
    if (paymentStage == 'CONVENIO') {
      return ('Convenio', kFinanzasBronze);
    }
    if (paymentStage == 'ATRASADO' || overdueAmount > 0) {
      return ('Urgente', kFinanzasBurnt);
    }
    if (paymentStage == 'PAGO_SEMANAL') {
      return ('Semanal', kFinanzasTaupe);
    }
    return ('Normal', kFinanzasAmber);
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

  Future<void> _printAccountReportFor(_ProviderAccountView account) async {
    if (account.tickets.isEmpty &&
        account.invoices.isEmpty &&
        account.movements.isEmpty &&
        account.cashMovements.isEmpty) {
      _toast('Esta cuenta todavía no tiene información para imprimir.');
      return;
    }
    final selection = await showDialog<_AccountReportSelectionResult>(
      context: context,
      builder: (dialogContext) {
        return AreaThemeScope(
          tokens: finanzasAreaTokens,
          child: Builder(
            builder: (_) => _ProviderAccountReportSelectionDialog(
              providerName: account.company.companyName,
              tickets: account.tickets,
              movements: _buildSelectableReportMovements(account),
            ),
          ),
        );
      },
    );
    if (selection == null) return;
    final selectedTickets = account.tickets
        .where((row) => selection.selectedTicketIds.contains(row.id))
        .toList(growable: false);
    final selectedMovements = _buildSelectableReportMovements(account)
        .where((row) => selection.selectedMovementIds.contains(row.id))
        .toList(growable: false);
    if (selectedTickets.isEmpty && selectedMovements.isEmpty) {
      _toast('Selecciona al menos un ticket o un movimiento.');
      return;
    }
    try {
      final pdfBytes = await _buildAccountReportPdfBytes(
        account,
        selectedTickets: selectedTickets,
        selectedMovements: selectedMovements,
        selectionLabel: _providerAccountReportSelectionLabel(
          selectedTickets: selectedTickets,
          selectedMovements: selectedMovements,
        ),
      );
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(
        '${Directory.systemTemp.path}/finanzas_cuenta_${account.company.companyName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_').toLowerCase()}_$stamp.pdf',
      );
      await file.writeAsBytes(pdfBytes, flush: true);
      await _openPdfFile(file.path);
    } catch (error) {
      _toast('No se pudo abrir la cuenta en PDF: $error');
    }
  }

  FinanzasProviderExcelTemplateKind? _providerExcelTemplateKindFor(
    _ProviderAccountView account,
  ) {
    final normalized = account.company.companyName.trim().toUpperCase();
    if (normalized == 'AVON') return FinanzasProviderExcelTemplateKind.avon;
    return FinanzasProviderExcelTemplateKind.genericMaterials;
  }

  Future<void> _exportProviderExcelTemplateFor(
    _ProviderAccountView account,
  ) async {
    final kind = _providerExcelTemplateKindFor(account);
    if (kind == null) return;
    if (account.tickets.isEmpty) {
      _toast('Este proveedor no tiene tickets para exportar.');
      return;
    }

    final selectedTickets = await showDialog<List<ComprasTicketRecord>>(
      context: context,
      builder: (dialogContext) {
        return AreaThemeScope(
          tokens: finanzasAreaTokens,
          child: Builder(
            builder: (_) => _ProviderExcelTicketSelectionDialog(
              providerName: account.company.companyName,
              tickets: account.tickets,
              moneyFormatter: _moneyStatic,
              dateFormatter: (value) =>
                  value == null ? 'Sin fecha' : _dateLabelStatic(value),
              kind: kind,
            ),
          ),
        );
      },
    );
    if (selectedTickets == null || selectedTickets.isEmpty) return;

    try {
      final bytes = await FinanzasProviderExcelTemplates.buildWorkbook(
        kind: kind,
        tickets: selectedTickets,
        providerName: account.company.companyName,
        providerLinkedName: account.company.linkedName,
      );
      final path = await saveBytesAs(
        bytes: bytes,
        suggestedFileName: _providerExcelFileName(
          account.company.companyName,
          selectedTickets,
        ),
        dialogTitle: 'Guardar Excel proveedor...',
      );
      if (path == null) return;
      _toast('Excel proveedor guardado en $path');
    } on FinanzasProviderExcelException catch (error) {
      _toast(error.message);
    } catch (error) {
      _toast('No se pudo generar el Excel del proveedor: $error');
    }
  }

  String _providerExcelFileName(
    String providerName,
    List<ComprasTicketRecord> tickets,
  ) {
    final ordered = tickets.toList(growable: false)
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.ticket.compareTo(b.ticket);
      });
    final first = ordered.first.date;
    final last = ordered.last.date;
    final range =
        '${first.day.toString().padLeft(2, '0')}-${first.month.toString().padLeft(2, '0')}_${last.day.toString().padLeft(2, '0')}-${last.month.toString().padLeft(2, '0')}_${last.year}';
    final normalizedProvider = providerName
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .toLowerCase();
    return '${normalizedProvider}_semana_$range.xlsx';
  }

  Future<void> _printInvoicesReportFor(_ProviderAccountView account) async {
    if (account.invoices.isEmpty) {
      _toast('Este proveedor todavía no tiene facturas para imprimir.');
      return;
    }
    final selection = await showDialog<_InvoiceReportSelectionResult>(
      context: context,
      builder: (dialogContext) {
        return AreaThemeScope(
          tokens: finanzasAreaTokens,
          child: Builder(
            builder: (_) => _ProviderInvoiceReportSelectionDialog(
              providerName: account.company.companyName,
              invoices: account.invoices,
            ),
          ),
        );
      },
    );
    if (selection == null) return;
    final selectedInvoices = account.invoices
        .where((row) => selection.selectedInvoiceIds.contains(row.invoice.id))
        .toList(growable: false);
    if (selectedInvoices.isEmpty) {
      _toast('Selecciona al menos una factura.');
      return;
    }
    try {
      final pdfBytes = await _buildInvoicesReportPdfBytes(
        account,
        selectedInvoices: selectedInvoices,
      );
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(
        '${Directory.systemTemp.path}/finanzas_facturas_${account.company.companyName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_').toLowerCase()}_$stamp.pdf',
      );
      await file.writeAsBytes(pdfBytes, flush: true);
      await _openPdfFile(file.path);
    } catch (error) {
      _toast('No se pudo abrir el PDF de facturas: $error');
    }
  }

  List<_ProviderReportMovementSelectionItem> _buildSelectableReportMovements(
    _ProviderAccountView account,
  ) {
    final items =
        <_ProviderReportMovementSelectionItem>[
          for (final row in account.cashMovements)
            _ProviderReportMovementSelectionItem.cash(row),
          for (final row in account.movements)
            _ProviderReportMovementSelectionItem.bank(row),
        ]..sort((a, b) {
          final aStamp = a.createdAt ?? a.date;
          final bStamp = b.createdAt ?? b.date;
          final byCreated = bStamp.compareTo(aStamp);
          if (byCreated != 0) return byCreated;
          return b.date.compareTo(a.date);
        });
    return items;
  }

  String _providerAccountReportSelectionLabel({
    required List<ComprasTicketRecord> selectedTickets,
    required List<_ProviderReportMovementSelectionItem> selectedMovements,
  }) {
    final parts = <String>[];
    if (selectedTickets.isNotEmpty) {
      parts.add('${selectedTickets.length} ticket(s)');
    }
    if (selectedMovements.isNotEmpty) {
      parts.add('${selectedMovements.length} movimiento(s)');
    }
    return parts.isEmpty ? 'Sin selección' : parts.join(' · ');
  }

  Future<Uint8List> _buildAccountReportPdfBytes(
    _ProviderAccountView account, {
    List<ComprasTicketRecord>? selectedTickets,
    List<_ProviderReportMovementSelectionItem>? selectedMovements,
    String? selectionLabel,
  }) async {
    final doc = pw.Document();
    final dicsaBlueSoft = PdfColor.fromHex('#E9F0FF');
    final dicsaBlueDeep = PdfColor.fromHex('#173A7A');
    final dicsaGreenSoft = PdfColor.fromHex('#EEF9F1');
    final dicsaInk = PdfColor.fromHex('#16202B');
    final dicsaMuted = PdfColor.fromHex('#5E6B78');
    final dicsaBorder = PdfColor.fromHex('#B8C7DD');
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo_dicsa.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final reportTickets = (selectedTickets ?? account.tickets).toList(
      growable: false,
    );
    final useExplicitMovements = selectedMovements != null;
    final selectedMovementItems =
        (selectedMovements ?? _buildSelectableReportMovements(account)).toList(
          growable: false,
        );
    final selectedCashMovementIds = selectedMovementItems
        .where((row) => row.cashMovement != null)
        .map((row) => row.cashMovement!.id)
        .toSet();
    final selectedBankMovementIds = selectedMovementItems
        .where((row) => row.bankMovement != null)
        .map((row) => row.bankMovement!.id)
        .toSet();
    final reportTicketIds = reportTickets.map((row) => row.id).toSet();
    final selectedInvoiceViews = account.invoices
        .where(
          (row) =>
              row.bankMovement != null &&
              selectedBankMovementIds.contains(row.bankMovement!.id),
        )
        .toList(growable: false);
    final reportManualInvoices =
        selectedInvoiceViews
            .where(_isManualSupplierInvoice)
            .toList(growable: false)
          ..sort(
            (a, b) => b.invoice.invoiceDate.compareTo(a.invoice.invoiceDate),
          );
    final now = DateTime.now();
    final printedAt =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final ticketTotal = reportTickets.fold<double>(
      0,
      (sum, row) => sum + row.amount,
    );
    final manualInvoiceTotal = reportManualInvoices.fold<double>(
      0,
      (sum, row) => sum + row.invoice.totalAmount,
    );
    final directApplicationsByTicketId =
        <String, List<_ProviderTicketSettlementView>>{};
    for (final ticket in reportTickets) {
      final applications =
          (account.ticketApplicationsByTicketId[ticket.id] ??
                  const <_ProviderTicketApplicationView>[])
              .where((row) => selectedCashMovementIds.contains(row.movement.id))
              .toList(growable: false);
      for (final item in applications) {
        directApplicationsByTicketId
            .putIfAbsent(ticket.id, () => <_ProviderTicketSettlementView>[])
            .add(
              _ProviderTicketSettlementView(
                date: item.application.appliedAt,
                reference: item.movement.reference,
                sourceLabel: _providerMovementSourceLabel(item.movement.source),
                amount: item.application.appliedAmount,
              ),
            );
      }
    }
    final bankApplicationsByTicketId = _buildBankApplicationsByTicket(
      selectedInvoiceViews,
      reportTicketIds,
    );

    final prioritizedTickets = <ComprasTicketRecord>[
      ...reportTickets.where(
        (row) => row.coverageStatus != 'CUBIERTO' || row.pagoStatus != 'PAGADO',
      ),
      ...reportTickets
          .where(
            (row) =>
                row.coverageStatus == 'CUBIERTO' && row.pagoStatus == 'PAGADO',
          )
          .take(30),
    ];
    final providerPaymentRowsById = <String, _ProviderAccountPaymentRow>{};
    double paymentTotal = 0;
    double openTotal = 0;
    for (final ticket in reportTickets) {
      final directApplications =
          directApplicationsByTicketId[ticket.id]?.toList(growable: false) ??
          const <_ProviderTicketSettlementView>[];
      final bankApplications =
          bankApplicationsByTicketId[ticket.id]?.toList(growable: false) ??
          const <_ProviderTicketSettlementView>[];
      final appliedFromCash = directApplications.fold<double>(
        0,
        (sum, item) => sum + item.amount,
      );
      if (!useExplicitMovements) {
        for (final item in directApplications) {
          final id =
              'cash-${ticket.id}-${item.date.microsecondsSinceEpoch}-${item.reference}-${item.amount}';
          providerPaymentRowsById.putIfAbsent(
            id,
            () => _ProviderAccountPaymentRow(
              id: id,
              date: item.date,
              sourceLabel: item.sourceLabel,
              reference: item.reference,
              typeLabel: 'Abono',
              amount: item.amount,
            ),
          );
        }
      }
      final bankCoverage = bankApplications.fold<double>(
        0,
        (sum, item) => sum + item.amount,
      );
      final cappedTicketAmount = ticket.amount < 0 ? 0.0 : ticket.amount;
      final appliedTotal = (appliedFromCash + bankCoverage).clamp(
        0,
        cappedTicketAmount,
      );
      if (!useExplicitMovements) {
        paymentTotal += appliedTotal;
      }
      openTotal += (cappedTicketAmount - appliedTotal).clamp(
        0,
        double.infinity,
      );
      if (!useExplicitMovements) {
        for (final item in bankApplications) {
          final id =
              'bank-${ticket.id}-${item.date.microsecondsSinceEpoch}-${item.reference}-${item.amount}';
          providerPaymentRowsById.putIfAbsent(
            id,
            () => _ProviderAccountPaymentRow(
              id: id,
              date: item.date,
              sourceLabel: item.sourceLabel,
              reference: item.reference,
              typeLabel: 'Factura proveedor',
              amount: item.amount,
            ),
          );
        }
      }
    }
    for (final row in reportManualInvoices) {
      final invoice = row.invoice;
      final paidPortion = (invoice.totalAmount - invoice.balanceAmount)
          .clamp(0, invoice.totalAmount)
          .toDouble();
      if (!useExplicitMovements) {
        paymentTotal += paidPortion;
      }
      openTotal += invoice.balanceAmount.clamp(0, double.infinity).toDouble();
      if (!useExplicitMovements) {
        final movement = row.bankMovement;
        if (movement == null || paidPortion <= 0.009) continue;
        final id =
            'manual-${invoice.id}-${movement.date.microsecondsSinceEpoch}-${movement.reference}-$paidPortion';
        providerPaymentRowsById.putIfAbsent(
          id,
          () => _ProviderAccountPaymentRow(
            id: id,
            date: movement.date,
            sourceLabel: '${movement.company} ${movement.branch}',
            reference: movement.reference,
            typeLabel: 'Factura manual',
            amount: paidPortion,
          ),
        );
      }
    }
    if (useExplicitMovements) {
      for (final movement in selectedMovementItems) {
        if (movement.cashMovement case final cashRow?) {
          final applications = account.ticketApplicationsByTicketId.values
              .expand((rows) => rows)
              .where(
                (row) =>
                    row.movement.id == cashRow.id &&
                    reportTicketIds.contains(row.application.ticketId),
              )
              .toList(growable: false);
          final scopedAmount = applications.fold<double>(
            0,
            (sum, row) => sum + row.application.appliedAmount,
          );
          final effectiveAmount = scopedAmount > 0.009
              ? scopedAmount
              : cashRow.amount;
          paymentTotal += effectiveAmount;
          providerPaymentRowsById.putIfAbsent(
            movement.id,
            () => _ProviderAccountPaymentRow(
              id: movement.id,
              date: cashRow.date,
              sourceLabel: _providerMovementSourceLabel(cashRow.source),
              reference: cashRow.reference,
              typeLabel: cashRow.type,
              amount: effectiveAmount,
            ),
          );
          continue;
        }
        if (movement.bankMovement case final bankRow?) {
          double scopedAmount = 0;
          for (final ticket in reportTickets) {
            final ticketApplications =
                bankApplicationsByTicketId[ticket.id]?.toList(
                  growable: false,
                ) ??
                const <_ProviderTicketSettlementView>[];
            for (final item in ticketApplications) {
              final sameDate =
                  item.date.microsecondsSinceEpoch ==
                  bankRow.date.microsecondsSinceEpoch;
              final sameReference = item.reference == bankRow.reference;
              if (sameDate && sameReference) {
                scopedAmount += item.amount;
              }
            }
          }
          for (final invoiceRow in reportManualInvoices) {
            if (invoiceRow.bankMovement?.id != bankRow.id) continue;
            final invoice = invoiceRow.invoice;
            scopedAmount += (invoice.totalAmount - invoice.balanceAmount)
                .clamp(0, invoice.totalAmount)
                .toDouble();
          }
          final effectiveAmount = scopedAmount > 0.009
              ? scopedAmount
              : bankRow.creditAmount > 0
              ? bankRow.creditAmount
              : bankRow.hasLinkedSupplierInvoice
              ? bankRow.effectiveSupplierAppliedAmount
              : bankRow.debitAmount;
          paymentTotal += effectiveAmount;
          providerPaymentRowsById.putIfAbsent(
            movement.id,
            () => _ProviderAccountPaymentRow(
              id: movement.id,
              date: bankRow.date,
              sourceLabel: '${bankRow.company} ${bankRow.branch}',
              reference: bankRow.reference,
              typeLabel:
                  bankRow.linkedSupplierInvoiceId != null &&
                      bankRow.linkedSupplierInvoiceId!.isNotEmpty
                  ? 'Factura proveedor'
                  : bankRow.creditAmount > 0
                  ? 'Abono banco'
                  : 'Cargo banco',
              amount: effectiveAmount,
            ),
          );
        }
      }
    }
    final paymentRows = providerPaymentRowsById.values.toList(growable: false)
      ..sort((a, b) => a.date.compareTo(b.date));
    if (reportTickets.isEmpty &&
        reportManualInvoices.isEmpty &&
        paymentRows.isEmpty) {
      throw Exception(
        'No hay tickets, movimientos ni facturas manuales en la selección.',
      );
    }

    pw.Widget summaryCard(String label, String value) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: pw.BoxDecoration(
            color: dicsaBlueSoft,
            borderRadius: pw.BorderRadius.circular(14),
            border: pw.Border.all(color: dicsaBorder),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 9.2,
                  fontWeight: pw.FontWeight.bold,
                  color: dicsaBlueDeep,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 15.5,
                  fontWeight: pw.FontWeight.bold,
                  color: dicsaInk,
                ),
              ),
            ],
          ),
        ),
      );
    }

    String ticketTrashLabel(ComprasTicketRecord row) {
      return row.trashCaptureMode == 'KG'
          ? '${row.trashKg.toStringAsFixed(2)} KG'
          : '${row.trashPercent.toStringAsFixed(2)}%';
    }

    double ticketHumidityKg(ComprasTicketRecord row) {
      return row.netWeight * (row.humidityPercent / 100);
    }

    double ticketTrashDiscountKg(ComprasTicketRecord row) {
      return row.trashCaptureMode == 'KG'
          ? row.trashKg
          : row.netWeight * (row.trashPercent / 100);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        maxPages: 200,
        build: (_) => [
          pw.Row(
            children: [
              if (logoImage != null)
                pw.SizedBox(
                  width: 42,
                  height: 28,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
              if (logoImage != null) pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'REPORTE',
                      style: pw.TextStyle(
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                        color: dicsaBlueDeep,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      account.company.companyName,
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                        color: dicsaMuted,
                      ),
                    ),
                    if (selectionLabel != null &&
                        selectionLabel.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        selectionLabel.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 9.4,
                          color: dicsaBlueDeep,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Text(printedAt, style: const pw.TextStyle(fontSize: 9.5)),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            children: [
              summaryCard('TICKETS TOTAL', _money(ticketTotal)),
              pw.SizedBox(width: 10),
              summaryCard('FACT. MANUALES', _money(manualInvoiceTotal)),
              pw.SizedBox(width: 10),
              summaryCard('ABONOS TOTAL', _money(paymentTotal)),
              pw.SizedBox(width: 10),
              summaryCard('SALDO PENDIENTE', _money(openTotal)),
            ],
          ),
          pw.SizedBox(height: 18),
          if (reportTickets.isNotEmpty) ...[
            pw.Text(
              'TICKETS',
              style: pw.TextStyle(
                fontSize: 12.5,
                fontWeight: pw.FontWeight.bold,
                color: dicsaBlueDeep,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: dicsaBorder),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.95),
                1: const pw.FlexColumnWidth(0.95),
                2: const pw.FlexColumnWidth(1.35),
                3: const pw.FlexColumnWidth(0.9),
                4: const pw.FlexColumnWidth(0.95),
                5: const pw.FlexColumnWidth(0.9),
                6: const pw.FlexColumnWidth(0.95),
                7: const pw.FlexColumnWidth(1.9),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: dicsaGreenSoft),
                  children:
                      [
                            'TICKET',
                            'FECHA',
                            'MATERIAL',
                            'IMPORTE',
                            'PAGO',
                            'COB.',
                            'APLICADO',
                            'ABONOS',
                          ]
                          .map(
                            (label) => pw.Padding(
                              padding: const pw.EdgeInsets.all(7),
                              child: pw.Text(
                                label,
                                style: pw.TextStyle(
                                  fontSize: 9.4,
                                  fontWeight: pw.FontWeight.bold,
                                  color: dicsaBlueDeep,
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                ),
                for (final row in prioritizedTickets)
                  pw.TableRow(
                    children: () {
                      final ticketApplications =
                          <_ProviderTicketSettlementView>[
                            ...?directApplicationsByTicketId[row.id],
                            ...?bankApplicationsByTicketId[row.id],
                          ]..sort((a, b) => a.date.compareTo(b.date));
                      final appliedAmount = ticketApplications.fold<double>(
                        0,
                        (sum, item) => sum + item.amount,
                      );
                      final fullyCovered = appliedAmount >= row.amount - 0.009;
                      final effectivePago = fullyCovered
                          ? 'PAGADO'
                          : appliedAmount > 0.009
                          ? 'ABONO'
                          : 'PENDIENTE_DE_PAGO';
                      final effectiveCoverage = fullyCovered
                          ? 'CUBIERTO'
                          : appliedAmount > 0.009
                          ? 'PARCIAL'
                          : 'SIN_CUBRIR';
                      final references = ticketApplications.isEmpty
                          ? 'SIN ABONOS'
                          : ticketApplications
                                .map((item) {
                                  final reference =
                                      item.reference.trim().isEmpty
                                      ? 'SIN REF'
                                      : item.reference.trim();
                                  return '$reference ${_money(item.amount)}';
                                })
                                .join(' | ');
                      return <String>[
                            row.ticket,
                            _dateLabel(row.date),
                            row.materialNameSnapshot,
                            _money(row.amount),
                            comprasPagoStatusLabel(effectivePago),
                            comprasCoverageStatusLabel(effectiveCoverage),
                            appliedAmount <= 0
                                ? _money(0)
                                : _money(appliedAmount),
                            references,
                          ]
                          .map(
                            (value) => pw.Padding(
                              padding: const pw.EdgeInsets.all(7),
                              child: pw.Text(
                                value,
                                style: const pw.TextStyle(fontSize: 9.2),
                              ),
                            ),
                          )
                          .toList(growable: false);
                    }(),
                  ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'DESGLOSE OPERATIVO Y DESCUENTOS',
              style: pw.TextStyle(
                fontSize: 12.5,
                fontWeight: pw.FontWeight.bold,
                color: dicsaBlueDeep,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Bruto, tara, neto, humedad, basura y peso pagable por ticket.',
              style: pw.TextStyle(fontSize: 9.2, color: dicsaMuted),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: dicsaBorder),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.8),
                1: const pw.FlexColumnWidth(0.85),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(0.9),
                4: const pw.FlexColumnWidth(0.9),
                5: const pw.FlexColumnWidth(0.9),
                6: const pw.FlexColumnWidth(0.75),
                7: const pw.FlexColumnWidth(0.9),
                8: const pw.FlexColumnWidth(0.9),
                9: const pw.FlexColumnWidth(1.0),
                10: const pw.FlexColumnWidth(0.75),
                11: const pw.FlexColumnWidth(0.75),
                12: const pw.FlexColumnWidth(0.9),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: dicsaGreenSoft),
                  children:
                      [
                            'TICKET',
                            'FECHA',
                            'MATERIAL',
                            'BRUTO',
                            'TARA',
                            'NETO',
                            'HUM %',
                            'HUM KG',
                            'BASURA',
                            'DESC. BAS',
                            'PAGABLE',
                            'PRECIO',
                            'IMPORTE',
                          ]
                          .map(
                            (label) => pw.Padding(
                              padding: const pw.EdgeInsets.all(7),
                              child: pw.Text(
                                label,
                                style: pw.TextStyle(
                                  fontSize: 8.8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: dicsaBlueDeep,
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                ),
                for (final row in reportTickets)
                  pw.TableRow(
                    children:
                        <String>[
                              row.ticket,
                              _dateLabel(row.date),
                              row.materialNameSnapshot,
                              row.grossWeight.toStringAsFixed(2),
                              row.tareWeight.toStringAsFixed(2),
                              row.netWeight.toStringAsFixed(2),
                              '${row.humidityPercent.toStringAsFixed(2)}%',
                              ticketHumidityKg(row).toStringAsFixed(2),
                              ticketTrashLabel(row),
                              ticketTrashDiscountKg(row).toStringAsFixed(2),
                              row.payableWeight.toStringAsFixed(2),
                              _money(row.price + row.premium),
                              _money(row.amount),
                            ]
                            .map(
                              (value) => pw.Padding(
                                padding: const pw.EdgeInsets.all(7),
                                child: pw.Text(
                                  value,
                                  style: const pw.TextStyle(fontSize: 8.6),
                                ),
                              ),
                            )
                            .toList(growable: false),
                  ),
              ],
            ),
            pw.SizedBox(height: 18),
          ],
          if (reportManualInvoices.isNotEmpty) ...[
            pw.Text(
              'FACTURAS MANUALES',
              style: pw.TextStyle(
                fontSize: 12.5,
                fontWeight: pw.FontWeight.bold,
                color: dicsaBlueDeep,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: dicsaBorder),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.15),
                1: const pw.FlexColumnWidth(0.95),
                2: const pw.FlexColumnWidth(0.95),
                3: const pw.FlexColumnWidth(0.95),
                4: const pw.FlexColumnWidth(0.95),
                5: const pw.FlexColumnWidth(1.6),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: dicsaGreenSoft),
                  children:
                      ['FOLIO', 'FECHA', 'LÍMITE', 'TOTAL', 'SALDO', 'NOTAS']
                          .map(
                            (label) => pw.Padding(
                              padding: const pw.EdgeInsets.all(7),
                              child: pw.Text(
                                label,
                                style: pw.TextStyle(
                                  fontSize: 9.4,
                                  fontWeight: pw.FontWeight.bold,
                                  color: dicsaBlueDeep,
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                ),
                for (final row in reportManualInvoices)
                  pw.TableRow(
                    children:
                        <String>[
                              row.invoice.folio.trim().isEmpty
                                  ? 'SIN FOLIO'
                                  : row.invoice.folio.trim(),
                              _dateLabel(row.invoice.invoiceDate),
                              row.invoice.dueDate == null
                                  ? 'SIN FECHA'
                                  : _dateLabel(row.invoice.dueDate!),
                              _money(row.invoice.totalAmount),
                              _money(row.invoice.balanceAmount),
                              row.invoice.notes.trim().isEmpty
                                  ? '—'
                                  : row.invoice.notes.trim(),
                            ]
                            .map(
                              (value) => pw.Padding(
                                padding: const pw.EdgeInsets.all(7),
                                child: pw.Text(
                                  value,
                                  style: const pw.TextStyle(fontSize: 9.2),
                                ),
                              ),
                            )
                            .toList(growable: false),
                  ),
              ],
            ),
            pw.SizedBox(height: 18),
          ],
          pw.Text(
            'ABONOS',
            style: pw.TextStyle(
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
              color: dicsaBlueDeep,
            ),
          ),
          pw.SizedBox(height: 8),
          paymentRows.isEmpty
              ? pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: dicsaBorder),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Text(
                    'Sin abonos relacionados en este alcance.',
                    style: pw.TextStyle(fontSize: 9.2, color: dicsaMuted),
                  ),
                )
              : pw.Table(
                  border: pw.TableBorder.all(color: dicsaBorder),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.0),
                    1: const pw.FlexColumnWidth(1.2),
                    2: const pw.FlexColumnWidth(1.1),
                    3: const pw.FlexColumnWidth(1.4),
                    4: const pw.FlexColumnWidth(1.0),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: dicsaGreenSoft),
                      children:
                          ['FECHA', 'ORIGEN', 'TIPO', 'REFERENCIA', 'IMPORTE']
                              .map(
                                (label) => pw.Padding(
                                  padding: const pw.EdgeInsets.all(7),
                                  child: pw.Text(
                                    label,
                                    style: pw.TextStyle(
                                      fontSize: 9.4,
                                      fontWeight: pw.FontWeight.bold,
                                      color: dicsaBlueDeep,
                                    ),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                    ),
                    for (final row in paymentRows)
                      pw.TableRow(
                        children:
                            <String>[
                                  _dateLabel(row.date),
                                  row.sourceLabel,
                                  row.typeLabel,
                                  row.reference.isEmpty
                                      ? 'SIN REFERENCIA'
                                      : row.reference,
                                  _money(row.amount),
                                ]
                                .map(
                                  (value) => pw.Padding(
                                    padding: const pw.EdgeInsets.all(7),
                                    child: pw.Text(
                                      value,
                                      style: const pw.TextStyle(fontSize: 9.2),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                      ),
                  ],
                ),
          pw.SizedBox(height: 54),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.SizedBox(height: 34),
                    pw.Container(height: 1, color: dicsaBorder),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'RECIBIDO',
                      style: pw.TextStyle(
                        fontSize: 9.6,
                        fontWeight: pw.FontWeight.bold,
                        color: dicsaBlueDeep,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Nombre y firma',
                      style: pw.TextStyle(fontSize: 8.8, color: dicsaMuted),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 36),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.SizedBox(height: 34),
                    pw.Container(height: 1, color: dicsaBorder),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'APROBADO',
                      style: pw.TextStyle(
                        fontSize: 9.6,
                        fontWeight: pw.FontWeight.bold,
                        color: dicsaBlueDeep,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Nombre y firma',
                      style: pw.TextStyle(fontSize: 8.8, color: dicsaMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<Uint8List> _buildInvoicesReportPdfBytes(
    _ProviderAccountView account, {
    required List<_ProviderInvoiceView> selectedInvoices,
  }) async {
    final doc = pw.Document();
    final dicsaBlueSoft = PdfColor.fromHex('#E9F0FF');
    final dicsaBlueDeep = PdfColor.fromHex('#173A7A');
    final dicsaGreenSoft = PdfColor.fromHex('#EEF9F1');
    final dicsaInk = PdfColor.fromHex('#16202B');
    final dicsaMuted = PdfColor.fromHex('#5E6B78');
    final dicsaBorder = PdfColor.fromHex('#B8C7DD');
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo_dicsa.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final orderedInvoices = selectedInvoices.toList(growable: false)
      ..sort((a, b) => b.invoice.invoiceDate.compareTo(a.invoice.invoiceDate));
    final now = DateTime.now();
    final printedAt =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    double totalAmount = 0;
    double balanceAmount = 0;
    int paidCount = 0;
    int pendingCount = 0;
    for (final row in orderedInvoices) {
      totalAmount += row.invoice.totalAmount;
      balanceAmount += row.invoice.balanceAmount;
      if (row.invoice.status == 'PAGADA') {
        paidCount += 1;
      } else {
        pendingCount += 1;
      }
    }

    pw.Widget summaryCard(String label, String value) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: pw.BoxDecoration(
            color: dicsaBlueSoft,
            borderRadius: pw.BorderRadius.circular(14),
            border: pw.Border.all(color: dicsaBorder),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 9.2,
                  fontWeight: pw.FontWeight.bold,
                  color: dicsaBlueDeep,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 15.5,
                  fontWeight: pw.FontWeight.bold,
                  color: dicsaInk,
                ),
              ),
            ],
          ),
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        maxPages: 300,
        build: (_) => [
          pw.Row(
            children: [
              if (logoImage != null)
                pw.SizedBox(
                  width: 42,
                  height: 28,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
              if (logoImage != null) pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'REPORTE FACTURAS',
                      style: pw.TextStyle(
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                        color: dicsaBlueDeep,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      account.company.companyName,
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                        color: dicsaMuted,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${orderedInvoices.length} factura(s) seleccionada(s)',
                      style: pw.TextStyle(fontSize: 9.4, color: dicsaBlueDeep),
                    ),
                  ],
                ),
              ),
              pw.Text(printedAt, style: const pw.TextStyle(fontSize: 9.5)),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            children: [
              summaryCard('FACTURAS', '${orderedInvoices.length}'),
              pw.SizedBox(width: 10),
              summaryCard('TOTAL', _money(totalAmount)),
              pw.SizedBox(width: 10),
              summaryCard('SALDO', _money(balanceAmount)),
              pw.SizedBox(width: 10),
              summaryCard('PAGADAS / PEND.', '$paidCount / $pendingCount'),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'FACTURAS SELECCIONADAS',
            style: pw.TextStyle(
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
              color: dicsaBlueDeep,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: dicsaBorder),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.1),
              1: const pw.FlexColumnWidth(0.9),
              2: const pw.FlexColumnWidth(0.9),
              3: const pw.FlexColumnWidth(1.1),
              4: const pw.FlexColumnWidth(1.0),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: dicsaGreenSoft),
                children: ['FOLIO', 'FECHA', 'ESTADO', 'TOTAL', 'SALDO']
                    .map(
                      (label) => pw.Padding(
                        padding: const pw.EdgeInsets.all(7),
                        child: pw.Text(
                          label,
                          style: pw.TextStyle(
                            fontSize: 9.4,
                            fontWeight: pw.FontWeight.bold,
                            color: dicsaBlueDeep,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              for (final row in orderedInvoices)
                pw.TableRow(
                  children:
                      <String>[
                            row.invoice.folio.trim().isEmpty
                                ? 'SIN FOLIO'
                                : row.invoice.folio.trim(),
                            _dateLabel(row.invoice.invoiceDate),
                            finSupplierInvoiceStatusLabel(row.invoice.status),
                            _money(row.invoice.totalAmount),
                            _money(row.invoice.balanceAmount),
                          ]
                          .map(
                            (value) => pw.Padding(
                              padding: const pw.EdgeInsets.all(7),
                              child: pw.Text(
                                value,
                                style: const pw.TextStyle(fontSize: 9.2),
                              ),
                            ),
                          )
                          .toList(growable: false),
                ),
            ],
          ),
          pw.SizedBox(height: 18),
          for (final row in orderedInvoices) ...[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.fromLTRB(12, 12, 12, 10),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(14),
                border: pw.Border.all(color: dicsaBorder),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          row.invoice.folio.trim().isEmpty
                              ? 'SIN FOLIO'
                              : row.invoice.folio.trim(),
                          style: pw.TextStyle(
                            fontSize: 12.5,
                            fontWeight: pw.FontWeight.bold,
                            color: dicsaBlueDeep,
                          ),
                        ),
                      ),
                      pw.Text(
                        _money(row.invoice.totalAmount),
                        style: pw.TextStyle(
                          fontSize: 11.5,
                          fontWeight: pw.FontWeight.bold,
                          color: dicsaInk,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Factura ${_dateLabel(row.invoice.invoiceDate)} · ${finSupplierInvoiceStatusLabel(row.invoice.status)}',
                    style: pw.TextStyle(fontSize: 9.2, color: dicsaMuted),
                  ),
                  if (row.invoice.notes.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(
                      row.invoice.notes.trim(),
                      style: const pw.TextStyle(fontSize: 9.1),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'RELACION FACTURA POR TICKETS',
              style: pw.TextStyle(
                fontSize: 10.2,
                fontWeight: pw.FontWeight.bold,
                color: dicsaBlueDeep,
              ),
            ),
            pw.SizedBox(height: 6),
            if (row.tickets.isEmpty)
              pw.Text(
                'Factura manual sin tickets relacionados.',
                style: pw.TextStyle(fontSize: 9.2, color: dicsaMuted),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: dicsaBorder),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.9),
                  1: const pw.FlexColumnWidth(0.9),
                  2: const pw.FlexColumnWidth(1.7),
                  3: const pw.FlexColumnWidth(0.9),
                  4: const pw.FlexColumnWidth(0.9),
                  5: const pw.FlexColumnWidth(0.9),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: dicsaBlueSoft),
                    children:
                        [
                              'TICKET',
                              'FECHA',
                              'MATERIAL',
                              'PESO',
                              'PRECIO',
                              'IMPORTE',
                            ]
                            .map(
                              (label) => pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  label,
                                  style: pw.TextStyle(
                                    fontSize: 8.8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: dicsaBlueDeep,
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                  ),
                  for (final ticket in row.tickets)
                    pw.TableRow(
                      children:
                          <String>[
                                ticket.ticket,
                                _dateLabel(ticket.date),
                                ticket.materialNameSnapshot,
                                ticket.payableWeight.toStringAsFixed(2),
                                _money(ticket.price + ticket.premium),
                                _money(ticket.amount),
                              ]
                              .map(
                                (value) => pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(
                                    value,
                                    style: const pw.TextStyle(fontSize: 8.7),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                    ),
                ],
              ),
            if (row.bankMovement != null) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                'Movimiento bancario: ${_dateLabel(row.bankMovement!.date)} · ${row.bankMovement!.company} ${row.bankMovement!.branch} · ${row.bankMovement!.reference.isEmpty ? 'SIN REFERENCIA' : row.bankMovement!.reference}',
                style: pw.TextStyle(fontSize: 9.1, color: dicsaMuted),
              ),
            ],
            pw.SizedBox(height: 10),
          ],
        ],
      ),
    );
    return doc.save();
  }

  Future<void> _openPdfFile(String path) async {
    ProcessResult result;
    if (Platform.isMacOS) {
      result = await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      result = await Process.run('cmd', ['/c', 'start', '', path]);
    } else if (Platform.isLinux) {
      result = await Process.run('xdg-open', [path]);
    } else {
      throw UnsupportedError('Plataforma no soportada para abrir PDF');
    }
    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString().trim());
    }
  }

  Future<void> _registerProviderCashMovementForSelectedProvider() async {
    final account = _selectedAccount;
    if (account == null) return;
    final comprasProviderIdByAlias = <String, String>{
      for (final row in account.tickets)
        if (_normalizedProviderAliasKey(row.providerNameSnapshot).isNotEmpty)
          _normalizedProviderAliasKey(row.providerNameSnapshot): row.providerId,
    };
    final comprasProviderId = _resolveComprasProviderId(
      account.company,
      comprasProviderIdByAlias,
    );
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
      await FinanzasProviderAccountsStore.syncAgreementStateForProvider(
        providerId: account.company.companyId,
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
      await FinanzasProviderAccountsStore.syncAgreementStateForProvider(
        providerId: account.company.companyId,
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
    final account = _selectedAccount;
    if (account == null) return;
    final confirmed = await showContractConfirmationDialog(
      context,
      title: 'Eliminar movimiento',
      content:
          'Se eliminará este movimiento directo del proveedor y se recalculará su aplicación sobre tickets abiertos. Esta acción no se puede deshacer.',
      confirmText: 'Eliminar',
      destructive: true,
      tokens: finanzasAreaTokens,
    );
    if (confirmed != true) return;
    try {
      await ComprasTicketsStore.deleteProviderMovementAndRebuildApplications(
        movement: movement,
      );
      await FinanzasProviderAccountsStore.syncAgreementStateForProvider(
        providerId: account.company.companyId,
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
    final metrics = _computeProviderAccountMetrics(account);
    final eligibleInvoices =
        account.invoices
            .map((row) => row.invoice)
            .where((invoice) => invoice.status != 'PAGADA')
            .toList(growable: false)
          ..sort(_compareAgreementInvoices);
    final draft = await showDialog<_AgreementDraftResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _RegisterSupplierAgreementDialog(
        providerName: account.company.companyName,
        suggestedBalance: metrics.openAmount,
        invoices: eligibleInvoices,
        initialTarget: _suggestTargetForProvider(account.company),
      ),
    );
    if (draft == null) return;
    final bundle = _buildAgreementBundle(
      account: account,
      draft: draft,
      eligibleInvoices: eligibleInvoices,
    );
    if (bundle == null) return;
    try {
      await FinanzasProviderAccountsStore.createAgreement(
        agreement: bundle.agreement,
        installments: bundle.installments,
        invoiceLinks: bundle.invoiceLinks,
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

  _AgreementSaveBundle? _buildAgreementBundle({
    required _ProviderAccountView account,
    required _AgreementDraftResult draft,
    required List<FinanzasSupplierInvoiceRecord> eligibleInvoices,
    String? agreementId,
  }) {
    final resolvedAgreementId =
        agreementId ?? 'fin-agreement-${DateTime.now().microsecondsSinceEpoch}';
    final installments = <FinanzasSupplierAgreementInstallmentRecord>[];
    final invoiceLinks = <FinanzasSupplierAgreementInvoiceRecord>[];
    double totalAmount = 0;
    if (draft.agreementType == 'POR_FACTURAS') {
      final selectedInvoices =
          eligibleInvoices
              .where((invoice) => draft.selectedInvoiceIds.contains(invoice.id))
              .toList(growable: false)
            ..sort(_compareAgreementInvoices);
      if (selectedInvoices.isEmpty) {
        _toast('Selecciona al menos una factura para este convenio.');
        return null;
      }
      final invoicesPerPeriod = draft.invoicesPerPeriod < 1
          ? 1
          : draft.invoicesPerPeriod;
      for (
        var start = 0, sequence = 1;
        start < selectedInvoices.length;
        start += invoicesPerPeriod, sequence++
      ) {
        final chunk = selectedInvoices
            .skip(start)
            .take(invoicesPerPeriod)
            .toList(growable: false);
        final installmentId = '$resolvedAgreementId-inst-$sequence';
        final dueDate = _agreementInstallmentDate(
          startDate: draft.startDate,
          frequency: draft.frequency,
          offset: sequence - 1,
        );
        final amount = chunk.fold<double>(
          0,
          (sum, invoice) => sum + invoice.balanceAmount,
        );
        totalAmount += amount;
        installments.add(
          FinanzasSupplierAgreementInstallmentRecord(
            id: installmentId,
            agreementId: resolvedAgreementId,
            sequenceNumber: sequence,
            dueDate: dueDate,
            commitmentType: 'FACTURAS',
            scheduledInvoiceCount: chunk.length,
            amount: amount,
            paidAmount: 0,
            status: 'PENDIENTE',
            createdAt: null,
            updatedAt: null,
          ),
        );
        for (var index = 0; index < chunk.length; index++) {
          final invoice = chunk[index];
          invoiceLinks.add(
            FinanzasSupplierAgreementInvoiceRecord(
              id: '$resolvedAgreementId-link-$sequence-${index + 1}',
              agreementId: resolvedAgreementId,
              installmentId: installmentId,
              invoiceId: invoice.id,
              sequenceNumber: start + index + 1,
              createdAt: null,
              updatedAt: null,
            ),
          );
        }
      }
    } else {
      totalAmount = draft.installmentAmount * draft.installmentCount;
      installments.addAll(
        List<FinanzasSupplierAgreementInstallmentRecord>.generate(
          draft.installmentCount,
          (index) {
            final dueDate = _agreementInstallmentDate(
              startDate: draft.startDate,
              frequency: draft.frequency,
              offset: index,
            );
            return FinanzasSupplierAgreementInstallmentRecord(
              id: '$resolvedAgreementId-inst-${index + 1}',
              agreementId: resolvedAgreementId,
              sequenceNumber: index + 1,
              dueDate: dueDate,
              commitmentType: 'MONTO',
              scheduledInvoiceCount: 0,
              amount: draft.installmentAmount,
              paidAmount: 0,
              status: 'PENDIENTE',
              createdAt: null,
              updatedAt: null,
            );
          },
          growable: false,
        ),
      );
    }
    final agreement = FinanzasSupplierAgreementRecord(
      id: resolvedAgreementId,
      providerId: account.company.companyId,
      providerNameSnapshot: account.company.companyName,
      targetCompany: draft.targetCompany,
      targetBranch: draft.targetBranch,
      startDate: draft.startDate,
      agreementType: draft.agreementType,
      frequency: draft.frequency,
      installmentAmount: draft.installmentAmount,
      installmentCount: installments.length,
      invoicesPerPeriod: draft.invoicesPerPeriod,
      scheduledInvoiceCount: draft.selectedInvoiceIds.length,
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
    return _AgreementSaveBundle(
      agreement: agreement,
      installments: installments,
      invoiceLinks: invoiceLinks,
    );
  }

  Future<void> _editAgreementForSelectedProvider(
    _ProviderAgreementView row,
  ) async {
    final account = _selectedAccount;
    if (account == null) return;
    if (row.installments.any((item) => item.status == 'PAGADO')) {
      _toast(
        'Este convenio ya tiene compromisos pagados. Para cuidar el historial, cancélalo y crea uno nuevo.',
      );
      return;
    }
    final metrics = _computeProviderAccountMetrics(account);
    final eligibleInvoices = account.invoices
        .map((invoiceRow) => invoiceRow.invoice)
        .where((invoice) => invoice.status != 'PAGADA')
        .toList(growable: false);
    final draft = await showDialog<_AgreementDraftResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _RegisterSupplierAgreementDialog(
        providerName: account.company.companyName,
        suggestedBalance: metrics.openAmount,
        invoices: eligibleInvoices,
        initialTarget: _suggestTargetForProvider(account.company),
        initialDraft: _AgreementDraftResult(
          startDate: row.agreement.startDate,
          agreementType: row.agreement.agreementType,
          frequency: row.agreement.frequency,
          targetCompany: row.agreement.targetCompany,
          targetBranch: row.agreement.targetBranch,
          installmentAmount: row.agreement.installmentAmount,
          installmentCount: row.agreement.installmentCount,
          invoicesPerPeriod: row.agreement.invoicesPerPeriod,
          selectedInvoiceIds: row.invoiceLinks
              .map((link) => link.invoice.id)
              .toList(growable: false),
          notes: row.agreement.notes,
        ),
      ),
    );
    if (draft == null) return;
    final bundle = _buildAgreementBundle(
      account: account,
      draft: draft,
      eligibleInvoices: eligibleInvoices,
      agreementId: row.agreement.id,
    );
    if (bundle == null) return;
    final updatedAgreement = FinanzasSupplierAgreementRecord(
      id: bundle.agreement.id,
      providerId: bundle.agreement.providerId,
      providerNameSnapshot: bundle.agreement.providerNameSnapshot,
      targetCompany: bundle.agreement.targetCompany,
      targetBranch: bundle.agreement.targetBranch,
      startDate: bundle.agreement.startDate,
      agreementType: bundle.agreement.agreementType,
      frequency: bundle.agreement.frequency,
      installmentAmount: bundle.agreement.installmentAmount,
      installmentCount: bundle.agreement.installmentCount,
      invoicesPerPeriod: bundle.agreement.invoicesPerPeriod,
      scheduledInvoiceCount: bundle.agreement.scheduledInvoiceCount,
      totalAmount: bundle.agreement.totalAmount,
      remainingAmount: bundle.agreement.remainingAmount,
      nextDueDate: bundle.agreement.nextDueDate,
      status: row.agreement.status == 'CANCELADO' ? 'CANCELADO' : 'ACTIVO',
      notes: bundle.agreement.notes,
      createdAt: row.agreement.createdAt,
      updatedAt: row.agreement.updatedAt,
    );
    try {
      await FinanzasProviderAccountsStore.replaceAgreementStructure(
        agreement: updatedAgreement,
        installments: bundle.installments,
        invoiceLinks: bundle.invoiceLinks,
      );
      if (!mounted) return;
      _toast('Convenio actualizado.');
      await _loadPage();
      if (!mounted) return;
      setState(() => _activeTab = _ProviderAccountsTab.convenios);
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo actualizar el convenio. $error');
    }
  }

  Future<void> _cancelAgreementForSelectedProvider(
    _ProviderAgreementView row,
  ) async {
    final confirmed = await showContractConfirmationDialog(
      context,
      title: 'Cancelar convenio',
      content:
          'Se cancelarán los compromisos pendientes, pero el historial permanecerá visible. ¿Continuar?',
      confirmText: 'Cancelar convenio',
      destructive: true,
    );
    if (confirmed != true) return;
    try {
      await FinanzasProviderAccountsStore.cancelAgreement(
        agreement: row.agreement,
        installments: row.installments,
      );
      if (!mounted) return;
      _toast('Convenio cancelado.');
      await _loadPage();
      if (!mounted) return;
      setState(() => _activeTab = _ProviderAccountsTab.convenios);
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo cancelar el convenio. $error');
    }
  }

  Future<void> _toggleAgreementInstallmentPaid(
    _ProviderAgreementView row,
    FinanzasSupplierAgreementInstallmentRecord installment,
  ) async {
    if (row.agreement.status == 'CANCELADO') {
      _toast(
        'Primero reactiva o reemplaza el convenio; este ya fue cancelado.',
      );
      return;
    }
    final updatedInstallment = FinanzasSupplierAgreementInstallmentRecord(
      id: installment.id,
      agreementId: installment.agreementId,
      sequenceNumber: installment.sequenceNumber,
      dueDate: installment.dueDate,
      commitmentType: installment.commitmentType,
      scheduledInvoiceCount: installment.scheduledInvoiceCount,
      amount: installment.amount,
      paidAmount: installment.status == 'PAGADO' ? 0 : installment.amount,
      status: installment.status == 'PAGADO' ? 'PENDIENTE' : 'PAGADO',
      createdAt: installment.createdAt,
      updatedAt: installment.updatedAt,
    );
    final recomputedAgreement = _recomputeAgreementFromInstallments(
      agreement: row.agreement,
      installments: row.installments
          .map((item) => item.id == installment.id ? updatedInstallment : item)
          .toList(growable: false),
    );
    try {
      await FinanzasProviderAccountsStore.saveAgreementInstallment(
        updatedInstallment,
      );
      await FinanzasProviderAccountsStore.saveAgreement(recomputedAgreement);
      if (!mounted) return;
      _toast(
        updatedInstallment.status == 'PAGADO'
            ? 'Compromiso marcado como pagado.'
            : 'Compromiso reabierto.',
      );
      await _loadPage();
      if (!mounted) return;
      setState(() => _activeTab = _ProviderAccountsTab.convenios);
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo actualizar el compromiso. $error');
    }
  }

  FinanzasSupplierAgreementRecord _recomputeAgreementFromInstallments({
    required FinanzasSupplierAgreementRecord agreement,
    required List<FinanzasSupplierAgreementInstallmentRecord> installments,
  }) {
    final today = DateUtils.dateOnly(DateTime.now());
    final ordered = installments.toList(growable: false)
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
    double remaining = 0;
    DateTime? nextDueDate;
    var hasOverdue = false;
    for (final installment in ordered) {
      if (installment.status == 'PAGADO' || installment.status == 'CANCELADO') {
        continue;
      }
      remaining += (installment.amount - installment.paidAmount)
          .clamp(0, double.infinity)
          .toDouble();
      nextDueDate ??= installment.dueDate;
      if (DateUtils.dateOnly(installment.dueDate).isBefore(today)) {
        hasOverdue = true;
      }
    }
    final status = agreement.status == 'CANCELADO'
        ? 'CANCELADO'
        : remaining <= 0.009
        ? 'CUMPLIDO'
        : hasOverdue
        ? 'ATRASADO'
        : 'ACTIVO';
    return FinanzasSupplierAgreementRecord(
      id: agreement.id,
      providerId: agreement.providerId,
      providerNameSnapshot: agreement.providerNameSnapshot,
      targetCompany: agreement.targetCompany,
      targetBranch: agreement.targetBranch,
      startDate: agreement.startDate,
      agreementType: agreement.agreementType,
      frequency: agreement.frequency,
      installmentAmount: agreement.installmentAmount,
      installmentCount: agreement.installmentCount,
      invoicesPerPeriod: agreement.invoicesPerPeriod,
      scheduledInvoiceCount: agreement.scheduledInvoiceCount,
      totalAmount: agreement.totalAmount,
      remainingAmount: remaining,
      nextDueDate: nextDueDate,
      status: status,
      notes: agreement.notes,
      createdAt: agreement.createdAt,
      updatedAt: agreement.updatedAt,
    );
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
        initialTarget: _suggestTargetForProvider(account.company),
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
      targetCompany: draft.targetCompany,
      targetBranch: draft.targetBranch,
      folio: draft.folio.trim(),
      originType: 'TICKETS',
      invoiceDate: draft.invoiceDate,
      dueDate: draft.dueDate,
      totalAmount: total,
      balanceAmount: total,
      status: status,
      notes: draft.notes.trim(),
      manualPriority: 'NORMAL',
      priorityNote: '',
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

  Future<void> _registerManualInvoiceForSelectedProvider() async {
    final account = _selectedAccount;
    if (account == null) return;
    final draft = await showDialog<_InvoiceDraftResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _RegisterManualSupplierInvoiceDialog(
        companyName: account.company.companyName,
        initialTarget: _suggestTargetForProvider(account.company),
      ),
    );
    if (draft == null) return;
    final total = (draft.manualAmount ?? 0)
        .clamp(0, double.infinity)
        .toDouble();
    if (total <= 0.009) {
      _toast('Captura un importe mayor a cero para la factura manual.');
      return;
    }
    final status = _deriveInvoiceStatus(
      dueDate: draft.dueDate,
      balanceAmount: total,
    );
    final invoice = FinanzasSupplierInvoiceRecord(
      id: 'fin-invoice-${DateTime.now().microsecondsSinceEpoch}',
      providerId: account.company.companyId,
      providerNameSnapshot: account.company.companyName,
      targetCompany: draft.targetCompany,
      targetBranch: draft.targetBranch,
      folio: draft.folio.trim(),
      originType: 'MANUAL',
      invoiceDate: draft.invoiceDate,
      dueDate: draft.dueDate,
      totalAmount: total,
      balanceAmount: total,
      status: status,
      notes: draft.notes.trim(),
      manualPriority: 'NORMAL',
      priorityNote: '',
      createdAt: null,
      updatedAt: null,
    );
    try {
      await FinanzasProviderAccountsStore.createInvoice(
        invoice: invoice,
        tickets: const <ComprasTicketRecord>[],
      );
      if (!mounted) return;
      _toast('Factura manual registrada.');
      await _loadPage();
      if (!mounted) return;
      setState(() => _activeTab = _ProviderAccountsTab.facturas);
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo registrar la factura manual. $error');
    }
  }

  Future<void> _editInvoiceForSelectedProvider(_ProviderInvoiceView row) async {
    final account = _selectedAccount;
    if (account == null) return;
    if (_canEditSupplierInvoiceFolioOnly(row)) {
      final nextFolio = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (_) => _EditSupplierInvoiceFolioDialog(
          companyName: account.company.companyName,
          currentFolio: row.invoice.folio,
          title: 'Editar número de factura',
          subtitle:
              'Solo se actualizará el número de factura y la referencia ligada en Cuentas Bancarias.',
        ),
      );
      if (nextFolio == null) return;
      final normalizedFolio = nextFolio.trim();
      if (normalizedFolio.isEmpty) {
        _toast('Captura un número de factura para guardar el cambio.');
        return;
      }
      if (normalizedFolio == row.invoice.folio.trim()) return;
      try {
        await FinanzasProviderAccountsStore.updateInvoiceFolioAndLinkedBankReferences(
          invoice: row.invoice,
          folio: normalizedFolio,
        );
        if (!mounted) return;
        _toast(
          'Número de factura actualizado y sincronizado con Cuentas Bancarias.',
        );
        await _loadPage();
      } catch (error) {
        if (!mounted) return;
        _toast('No se pudo actualizar el número de factura. $error');
      }
      return;
    }

    if (!_canEditSupplierInvoice(row)) {
      _toast(
        'Solo puedes editar facturas pendientes sin pagos aplicados ni movimientos bancarios ligados.',
      );
      return;
    }

    if (_isManualSupplierInvoice(row)) {
      final draft = await showDialog<_InvoiceDraftResult>(
        context: context,
        barrierDismissible: true,
        builder: (_) => _RegisterManualSupplierInvoiceDialog(
          companyName: account.company.companyName,
          initialTarget: _suggestTargetForProvider(account.company),
          initialDraft: _InvoiceDraftResult(
            folio: row.invoice.folio,
            originType: row.invoice.originType,
            invoiceDate: row.invoice.invoiceDate,
            dueDate: row.invoice.dueDate,
            targetCompany: row.invoice.targetCompany,
            targetBranch: row.invoice.targetBranch,
            manualAmount: row.invoice.totalAmount,
            notes: row.invoice.notes,
            selectedTicketIds: const <String>{},
          ),
          title: 'Editar factura manual',
          confirmLabel: 'Guardar cambios',
        ),
      );
      if (draft == null) return;
      final total = (draft.manualAmount ?? 0)
          .clamp(0, double.infinity)
          .toDouble();
      if (total <= 0.009) {
        _toast('Captura un importe mayor a cero para la factura manual.');
        return;
      }
      final updated = row.invoice.copyWith(
        folio: draft.folio.trim(),
        invoiceDate: draft.invoiceDate,
        dueDate: draft.dueDate,
        targetCompany: draft.targetCompany,
        targetBranch: draft.targetBranch,
        totalAmount: total,
        balanceAmount: total,
        status: _deriveInvoiceStatus(
          dueDate: draft.dueDate,
          balanceAmount: total,
        ),
        notes: draft.notes.trim(),
      );
      try {
        await FinanzasProviderAccountsStore.saveInvoice(updated);
        if (!mounted) return;
        _toast('Factura manual actualizada.');
        await _loadPage();
      } catch (error) {
        if (!mounted) return;
        _toast('No se pudo actualizar la factura manual. $error');
      }
      return;
    }

    final currentTicketIds = row.tickets.map((ticket) => ticket.id).toSet();
    final candidateTickets = account.tickets
        .where(
          (ticket) =>
              ticket.facturaStatus == 'PENDIENTE_DE_FACTURAR' ||
              currentTicketIds.contains(ticket.id),
        )
        .toList(growable: false);
    final draft = await showDialog<_InvoiceDraftResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _RegisterSupplierInvoiceDialog(
        companyName: account.company.companyName,
        tickets: candidateTickets,
        initialTarget: _suggestTargetForProvider(account.company),
        initialDraft: _InvoiceDraftResult(
          folio: row.invoice.folio,
          originType: row.invoice.originType,
          invoiceDate: row.invoice.invoiceDate,
          dueDate: row.invoice.dueDate,
          targetCompany: row.invoice.targetCompany,
          targetBranch: row.invoice.targetBranch,
          manualAmount: null,
          notes: row.invoice.notes,
          selectedTicketIds: currentTicketIds,
        ),
        title: 'Editar factura',
        confirmLabel: 'Guardar cambios',
      ),
    );
    if (draft == null) return;
    final selectedTickets = candidateTickets
        .where((ticket) => draft.selectedTicketIds.contains(ticket.id))
        .toList(growable: false);
    if (selectedTickets.isEmpty) {
      _toast('Selecciona al menos un ticket para la factura.');
      return;
    }
    final total = selectedTickets.fold<double>(
      0,
      (sum, ticket) => sum + ticket.amount,
    );
    final updated = row.invoice.copyWith(
      folio: draft.folio.trim(),
      invoiceDate: draft.invoiceDate,
      dueDate: draft.dueDate,
      targetCompany: draft.targetCompany,
      targetBranch: draft.targetBranch,
      totalAmount: total,
      balanceAmount: total,
      status: _deriveInvoiceStatus(
        dueDate: draft.dueDate,
        balanceAmount: total,
      ),
      notes: draft.notes.trim(),
    );
    try {
      await FinanzasProviderAccountsStore.updateInvoiceWithTickets(
        invoice: updated,
        tickets: selectedTickets,
      );
      if (!mounted) return;
      _toast('Factura actualizada.');
      await _loadPage();
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo actualizar la factura. $error');
    }
  }

  Future<void> _editProviderPriorityForSelectedProvider() async {
    final account = _selectedAccount;
    if (account == null) return;
    final draft = await showDialog<_ManualPriorityDraft>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ManualPriorityDialog(
        title: 'Prioridad del proveedor',
        subtitle: account.company.companyName,
        initialLevel: account.company.manualPriority,
        initialNote: account.company.priorityNote,
      ),
    );
    if (draft == null) return;
    try {
      await FinanzasCompanyDirectoryStore.saveDirectoryRow(
        account.company.copyWith(
          manualPriority: draft.level,
          priorityNote: draft.note,
        ),
      );
      if (!mounted) return;
      _toast('Prioridad del proveedor actualizada.');
      await _loadPage();
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo actualizar la prioridad del proveedor. $error');
    }
  }

  Future<void> _editInvoicePriority(_ProviderInvoiceView row) async {
    final draft = await showDialog<_ManualPriorityDraft>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ManualPriorityDialog(
        title: 'Prioridad de factura',
        subtitle: '${row.invoice.folio} · ${row.invoice.providerNameSnapshot}',
        initialLevel: row.invoice.manualPriority,
        initialNote: row.invoice.priorityNote,
      ),
    );
    if (draft == null) return;
    try {
      await FinanzasProviderAccountsStore.saveInvoice(
        row.invoice.copyWith(
          manualPriority: draft.level,
          priorityNote: draft.note,
        ),
      );
      if (!mounted) return;
      _toast('Prioridad de factura actualizada.');
      await _loadPage();
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo actualizar la prioridad de la factura. $error');
    }
  }

  Future<void> _deleteTicketForSelectedProvider(ComprasTicketRecord row) async {
    if (row.facturaStatus == 'FACTURADO') {
      _toast(
        'Este ticket está facturado. Primero elimina la factura relacionada para liberarlo.',
      );
      return;
    }
    final confirmed = await showContractConfirmationDialog(
      context,
      title: 'Eliminar ticket',
      content:
          'Se eliminará el ticket ${row.ticket} del proveedor. Esta acción no se puede deshacer.',
      confirmText: 'Eliminar',
      destructive: true,
      tokens: finanzasAreaTokens,
    );
    if (confirmed != true) return;
    try {
      await ComprasTicketsStore.deleteTickets(<String>{row.id});
      if (!mounted) return;
      _toast('Ticket eliminado.');
      await _loadPage();
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo eliminar el ticket. $error');
    }
  }

  Future<void> _deleteInvoiceForSelectedProvider(
    _ProviderInvoiceView row,
  ) async {
    final confirmed = await showContractConfirmationDialog(
      context,
      title: 'Eliminar factura',
      content:
          'Se eliminará la factura ${row.invoice.folio}, se soltarán sus tickets relacionados y se limpiarán evidencias y vínculos operativos. Esta acción no se puede deshacer.',
      confirmText: 'Eliminar',
      destructive: true,
      tokens: finanzasAreaTokens,
    );
    if (confirmed != true) return;
    try {
      await FinanzasProviderAccountsStore.deleteInvoice(row.invoice);
      if (!mounted) return;
      _toast('Factura eliminada.');
      await _loadPage();
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo eliminar la factura. $error');
    }
  }

  Future<void> _openInvoiceEvidenceDialog(_ProviderInvoiceView row) async {
    var localEvidences = row.evidences.toList(growable: true);
    var changed = false;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 28,
              ),
              child: AreaThemeScope(
                tokens: finanzasAreaTokens,
                child: Builder(
                  builder: (scopedContext) => ContractGlassCard(
                    borderRadius: BorderRadius.circular(30),
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
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
                                      'Evidencias de factura',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: AreaThemeScope.of(
                                          scopedContext,
                                        ).primaryStrong,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      row.invoice.folio,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: finanzasAreaTokens.badgeText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                style: contractPrimaryButtonStyle(
                                  scopedContext,
                                ),
                                onPressed: () async {
                                  final uploaded = await _pickAndUploadEvidence(
                                    ownerType:
                                        kFinanzasEvidenceOwnerTypeSupplierInvoice,
                                    ownerId: row.invoice.id,
                                    title: 'Subir evidencia de factura',
                                  );
                                  if (uploaded == null) return;
                                  changed = true;
                                  setLocalState(() {
                                    localEvidences = <FinanzasEvidenceRecord>[
                                      uploaded,
                                      ...localEvidences,
                                    ];
                                  });
                                },
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('Subir'),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                style: IconButton.styleFrom(
                                  backgroundColor: finanzasAreaTokens
                                      .fieldSurface
                                      .withValues(alpha: 0.92),
                                  foregroundColor:
                                      finanzasAreaTokens.primaryStrong,
                                ),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (localEvidences.isEmpty)
                            const _ProviderAccountsPendingPane(
                              label: 'Sin evidencias',
                              subtitle:
                                  'Todavía no hay PDF o fotos ligadas a esta factura.',
                            )
                          else
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 380),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: localEvidences.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, index) {
                                  final evidence = localEvidences[index];
                                  return Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      12,
                                      14,
                                      12,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: kFinanzasPanelGradient,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: finanzasAreaTokens.primaryStrong
                                            .withValues(alpha: 0.34),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: finanzasAreaTokens.glow
                                              .withValues(alpha: 0.10),
                                          blurRadius: 18,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: finanzasAreaTokens
                                                .primaryStrong
                                                .withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: finanzasAreaTokens
                                                  .primaryStrong
                                                  .withValues(alpha: 0.34),
                                            ),
                                          ),
                                          child: Icon(
                                            evidence.fileName
                                                    .toLowerCase()
                                                    .endsWith('.pdf')
                                                ? Icons.picture_as_pdf_outlined
                                                : Icons.photo_library_outlined,
                                            color: finanzasAreaTokens
                                                .primaryStrong,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                evidence.fileName,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${_dateLabelStatic(evidence.uploadedAt)} · ${evidence.uploadedByName.isEmpty ? 'Usuario' : evidence.uploadedByName}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: finanzasAreaTokens
                                                      .badgeText
                                                      .withValues(alpha: 0.78),
                                                ),
                                              ),
                                              if (evidence.comment
                                                  .trim()
                                                  .isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4,
                                                      ),
                                                  child: Text(
                                                    evidence.comment.trim(),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: finanzasAreaTokens
                                                          .badgeText
                                                          .withValues(
                                                            alpha: 0.78,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        FilledButton.icon(
                                          style: contractPrimaryButtonStyle(
                                            scopedContext,
                                          ),
                                          onPressed: () => unawaited(
                                            _openEvidenceFile(evidence),
                                          ),
                                          icon: const Icon(
                                            Icons.download_rounded,
                                            size: 18,
                                          ),
                                          label: const Text('Descargar'),
                                        ),
                                      ],
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
            );
          },
        );
      },
    );
    if (changed && mounted) {
      await _loadPage();
      _toast('Evidencia subida.');
    }
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
                child: AreaThemeScope(
                  tokens: finanzasAreaTokens,
                  child: Builder(
                    builder: (scopedContext) => ContractGlassCard(
                      borderRadius: BorderRadius.circular(28),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DialogHeader(
                              title: title,
                              subtitle: 'Adjunta PDF o evidencia fotográfica.',
                              popContext: dialogContext,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              style: contractPrimaryButtonStyle(scopedContext),
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
                              icon: const Icon(Icons.attach_file_rounded),
                              label: Text(
                                picked == null
                                    ? 'Seleccionar PDF o foto'
                                    : 'Archivo: ${picked!.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (picked != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: kFinanzasPanelGradient,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: finanzasAreaTokens.primaryStrong
                                        .withValues(alpha: 0.34),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: finanzasAreaTokens.primaryStrong
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: finanzasAreaTokens
                                              .primaryStrong
                                              .withValues(alpha: 0.34),
                                        ),
                                      ),
                                      child: Icon(
                                        picked!.name.toLowerCase().endsWith(
                                              '.pdf',
                                            )
                                            ? Icons.picture_as_pdf_outlined
                                            : Icons.photo_library_outlined,
                                        color: finanzasAreaTokens.primaryStrong,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        picked!.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextField(
                              controller: commentC,
                              minLines: 2,
                              maxLines: 3,
                              decoration: contractGlassFieldDecoration(
                                scopedContext,
                                hintText: 'Comentario de la evidencia',
                                prefixIcon: const Icon(Icons.note_alt_outlined),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _DialogActionsRow(
                              onCancel: () =>
                                  Navigator.of(dialogContext).pop(false),
                              onConfirm: () =>
                                  Navigator.of(dialogContext).pop(true),
                              confirmLabel: 'Guardar',
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

  Future<void> _openEvidenceFile(FinanzasEvidenceRecord evidence) async {
    try {
      final path = await saveRemoteFileAs(
        url: evidence.fileUrl,
        suggestedFileName: evidence.fileName,
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

  List<_GlobalPendingInvoiceReportRow> _buildGlobalPendingInvoiceReportRows() {
    final byInvoiceId = <String, _GlobalPendingInvoiceReportRow>{};
    for (final account in _accounts) {
      final appliedByInvoiceId = _buildAppliedSupplierAmountByInvoiceId(
        account.movements,
      );
      for (final row in account.invoices) {
        final pendingAmount = _effectiveSupplierInvoiceBalance(
          row.invoice,
          appliedByInvoiceId,
        );
        if (pendingAmount <= 0.009) continue;
        byInvoiceId[row.invoice.id] = _GlobalPendingInvoiceReportRow(
          invoiceId: row.invoice.id,
          date: row.invoice.dueDate ?? row.invoice.invoiceDate,
          companyName: account.company.companyName,
          folio: row.invoice.folio.trim().isEmpty
              ? 'SIN FOLIO'
              : row.invoice.folio.trim(),
          totalAmount: row.invoice.totalAmount,
          pendingAmount: pendingAmount,
        );
      }
    }
    final rows = byInvoiceId.values.toList(growable: false)
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        final byCompany = a.companyName.compareTo(b.companyName);
        if (byCompany != 0) return byCompany;
        return a.folio.compareTo(b.folio);
      });
    return rows;
  }

  _GlobalPendingBreakdownSummary _buildGlobalPendingBreakdownSummary() {
    final buckets = <String, _MutableGlobalPendingBreakdownBucket>{
      'facturado': _MutableGlobalPendingBreakdownBucket(),
      'sin_factura': _MutableGlobalPendingBreakdownBucket(),
      'pendiente_facturar': _MutableGlobalPendingBreakdownBucket(),
    };

    for (final account in _accounts) {
      for (final ticket in account.tickets) {
        final ticketAmount = ticket.amount.clamp(0.0, double.infinity);
        if (ticketAmount <= 0.009) continue;
        final resolved = _resolveProviderTicketStatus(account, ticket);
        final paidAmount = resolved.appliedAmount
            .clamp(0.0, ticketAmount)
            .toDouble();
        final dueAmount = (ticketAmount - paidAmount)
            .clamp(0.0, ticketAmount)
            .toDouble();
        final bucket = switch (ticket.facturaStatus) {
          'FACTURADO' => buckets['facturado']!,
          'SIN_FACTURA' => buckets['sin_factura']!,
          _ => buckets['pendiente_facturar']!,
        };
        bucket.dueAmount += dueAmount;
        bucket.paidAmount += paidAmount;
      }

      final appliedByInvoiceId = _buildAppliedSupplierAmountByInvoiceId(
        account.movements,
      );
      for (final invoiceRow in account.invoices) {
        if (!_isManualSupplierInvoice(invoiceRow) &&
            !_isOrphanTicketSupplierInvoice(invoiceRow)) {
          continue;
        }
        final totalAmount = invoiceRow.invoice.totalAmount.clamp(
          0.0,
          double.infinity,
        );
        if (totalAmount <= 0.009) continue;
        final dueAmount = _effectiveSupplierInvoiceBalance(
          invoiceRow.invoice,
          appliedByInvoiceId,
        );
        final paidAmount = (totalAmount - dueAmount)
            .clamp(0.0, totalAmount)
            .toDouble();
        final bucket = buckets['facturado']!;
        bucket.dueAmount += dueAmount;
        bucket.paidAmount += paidAmount;
      }
    }

    return _GlobalPendingBreakdownSummary(
      rows: <_GlobalPendingBreakdownRow>[
        _GlobalPendingBreakdownRow(
          label: 'Facturado',
          dueAmount: buckets['facturado']!.dueAmount,
          paidAmount: buckets['facturado']!.paidAmount,
        ),
        _GlobalPendingBreakdownRow(
          label: 'Sin factura',
          dueAmount: buckets['sin_factura']!.dueAmount,
          paidAmount: buckets['sin_factura']!.paidAmount,
        ),
        _GlobalPendingBreakdownRow(
          label: 'Pendiente por facturar',
          dueAmount: buckets['pendiente_facturar']!.dueAmount,
          paidAmount: buckets['pendiente_facturar']!.paidAmount,
        ),
      ],
    );
  }

  List<_GlobalPendingDetailRow> _buildGlobalPendingDetailRows(
    _GlobalPendingBreakdownSummary breakdown,
  ) {
    final detailRows = <_GlobalPendingDetailRow>[];
    for (final row in breakdown.rows) {
      if (row.dueAmount > 0.009) {
        detailRows.add(
          _GlobalPendingDetailRow(
            concept: row.label,
            status: 'Pendiente',
            amount: row.dueAmount,
          ),
        );
      }
      if (row.paidAmount > 0.009) {
        detailRows.add(
          _GlobalPendingDetailRow(
            concept: row.label,
            status: 'Pagado',
            amount: row.paidAmount,
          ),
        );
      }
    }
    return detailRows;
  }

  String _csvCell(String value) =>
      '"${value.replaceAll('"', '""').replaceAll('\n', ' ')}"';

  Future<void> _exportGlobalPendingInvoicesCsv() async {
    final rows = _buildGlobalPendingInvoiceReportRows();
    if (rows.isEmpty) {
      _toast('No hay facturas pendientes para exportar.');
      return;
    }
    final csv = StringBuffer()
      ..writeln(
        [
          'Fecha',
          'Empresa',
          'Factura',
          'Monto',
          'Importe pendiente',
        ].map(_csvCell).join(','),
      );
    for (final row in rows) {
      csv.writeln(
        <String>[
          _dateLabel(row.date),
          row.companyName,
          row.folio,
          row.totalAmount.toStringAsFixed(2),
          row.pendingAmount.toStringAsFixed(2),
        ].map(_csvCell).join(','),
      );
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = await saveCsvFile(
      fileName: 'finanzas_facturas_pendientes_global_$stamp.csv',
      content: csv.toString(),
      dialogTitle: 'Guardar reporte CSV de facturas pendientes',
    );
    if (!mounted || path == null) return;
    _toast('CSV guardado en $path');
  }

  Future<Uint8List> _buildGlobalPendingInvoicesPdfBytes(
    List<_GlobalPendingInvoiceReportRow> rows,
    _GlobalPendingBreakdownSummary breakdown,
  ) async {
    final doc = pw.Document();
    final dicsaBlueSoft = PdfColor.fromHex('#E9F0FF');
    final dicsaBlueDeep = PdfColor.fromHex('#173A7A');
    final dicsaGreenSoft = PdfColor.fromHex('#EEF9F1');
    final dicsaInk = PdfColor.fromHex('#16202B');
    final dicsaMuted = PdfColor.fromHex('#5E6B78');
    final dicsaBorder = PdfColor.fromHex('#B8C7DD');
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo_dicsa.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final now = DateTime.now();
    final printedAt =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final pendingAmount = rows.fold<double>(
      0,
      (sum, row) => sum + row.pendingAmount,
    );
    final detailRows = _buildGlobalPendingDetailRows(breakdown);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        build: (_) => [
          pw.Row(
            children: [
              if (logoImage != null)
                pw.SizedBox(
                  width: 42,
                  height: 28,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
              if (logoImage != null) pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'REPORTE GLOBAL DE FACTURAS PENDIENTES',
                      style: pw.TextStyle(
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                        color: dicsaBlueDeep,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Cuentas por Proveedor',
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                        color: dicsaMuted,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${rows.length} factura(s) pendiente(s) en todas las empresas · Importe pendiente ${_money(pendingAmount)}',
                      style: pw.TextStyle(fontSize: 9.4, color: dicsaBlueDeep),
                    ),
                  ],
                ),
              ),
              pw.Text(printedAt, style: const pw.TextStyle(fontSize: 9.5)),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'DESGLOSE OPERATIVO',
            style: pw.TextStyle(
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
              color: dicsaBlueDeep,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: dicsaBorder),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.0),
              1: const pw.FlexColumnWidth(1.15),
              2: const pw.FlexColumnWidth(1.15),
              3: const pw.FlexColumnWidth(1.15),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: dicsaBlueSoft),
                children: ['CONCEPTO', 'SE DEBE', 'PAGADO', 'DEBE + PAGADO']
                    .map(
                      (label) => pw.Padding(
                        padding: const pw.EdgeInsets.all(7),
                        child: pw.Text(
                          label,
                          style: pw.TextStyle(
                            fontSize: 9.4,
                            fontWeight: pw.FontWeight.bold,
                            color: dicsaBlueDeep,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              pw.TableRow(
                decoration: pw.BoxDecoration(color: dicsaGreenSoft),
                children:
                    <String>[
                          'TOTAL OPERATIVO',
                          _money(breakdown.totalDueAmount),
                          _money(breakdown.totalPaidAmount),
                          _money(breakdown.totalAmount),
                        ]
                        .map(
                          (value) => pw.Padding(
                            padding: const pw.EdgeInsets.all(7),
                            child: pw.Text(
                              value,
                              style: pw.TextStyle(
                                fontSize: 9.3,
                                fontWeight: pw.FontWeight.bold,
                                color: dicsaInk,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
              ),
              for (final row in breakdown.rows)
                pw.TableRow(
                  children:
                      <String>[
                            row.label,
                            _money(row.dueAmount),
                            _money(row.paidAmount),
                            _money(row.totalAmount),
                          ]
                          .map(
                            (value) => pw.Padding(
                              padding: const pw.EdgeInsets.all(7),
                              child: pw.Text(
                                value,
                                style: const pw.TextStyle(fontSize: 9.2),
                              ),
                            ),
                          )
                          .toList(growable: false),
                ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Facturado incluye tickets con factura y facturas manuales u huerfanas sin ticket ligado.',
            style: pw.TextStyle(fontSize: 8.6, color: dicsaMuted),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'DETALLE GLOBAL AGRUPADO',
            style: pw.TextStyle(
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
              color: dicsaBlueDeep,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: dicsaBorder),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.7),
              1: const pw.FlexColumnWidth(1.1),
              2: const pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: dicsaGreenSoft),
                children: ['CONCEPTO', 'ESTADO', 'IMPORTE']
                    .map(
                      (label) => pw.Padding(
                        padding: const pw.EdgeInsets.all(7),
                        child: pw.Text(
                          label,
                          style: pw.TextStyle(
                            fontSize: 9.4,
                            fontWeight: pw.FontWeight.bold,
                            color: dicsaBlueDeep,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              if (detailRows.isEmpty)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(7),
                      child: pw.Text(
                        'Sin movimientos para agrupar',
                        style: const pw.TextStyle(fontSize: 9.2),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(7),
                      child: pw.Text(
                        '',
                        style: const pw.TextStyle(fontSize: 9.2),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(7),
                      child: pw.Text(
                        _money(0),
                        style: const pw.TextStyle(fontSize: 9.2),
                      ),
                    ),
                  ],
                )
              else
                for (final row in detailRows)
                  pw.TableRow(
                    children:
                        <String>[row.concept, row.status, _money(row.amount)]
                            .map(
                              (value) => pw.Padding(
                                padding: const pw.EdgeInsets.all(7),
                                child: pw.Text(
                                  value,
                                  style: const pw.TextStyle(fontSize: 9.2),
                                ),
                              ),
                            )
                            .toList(growable: false),
                  ),
              pw.TableRow(
                decoration: pw.BoxDecoration(color: dicsaBlueSoft),
                children:
                    <String>[
                          'TOTAL PENDIENTE',
                          'Pendiente',
                          _money(breakdown.totalDueAmount),
                        ]
                        .map(
                          (value) => pw.Padding(
                            padding: const pw.EdgeInsets.all(7),
                            child: pw.Text(
                              value,
                              style: pw.TextStyle(
                                fontSize: 9.3,
                                fontWeight: pw.FontWeight.bold,
                                color: dicsaInk,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
              ),
              pw.TableRow(
                decoration: pw.BoxDecoration(color: dicsaBlueSoft),
                children:
                    <String>[
                          'TOTAL PAGADO',
                          'Pagado',
                          _money(breakdown.totalPaidAmount),
                        ]
                        .map(
                          (value) => pw.Padding(
                            padding: const pw.EdgeInsets.all(7),
                            child: pw.Text(
                              value,
                              style: pw.TextStyle(
                                fontSize: 9.3,
                                fontWeight: pw.FontWeight.bold,
                                color: dicsaInk,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
              ),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<void> _exportGlobalPendingInvoicesPdf() async {
    final rows = _buildGlobalPendingInvoiceReportRows();
    final breakdown = _buildGlobalPendingBreakdownSummary();
    if (rows.isEmpty && breakdown.totalAmount <= 0.009) {
      _toast('No hay facturas pendientes para exportar.');
      return;
    }
    try {
      final bytes = await _buildGlobalPendingInvoicesPdfBytes(rows, breakdown);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final path = await saveBytesAs(
        bytes: bytes,
        suggestedFileName: 'finanzas_facturas_pendientes_global_$stamp.pdf',
        dialogTitle: 'Guardar reporte PDF de facturas pendientes',
      );
      if (!mounted || path == null) return;
      _toast('PDF guardado en $path');
    } catch (error) {
      if (!mounted) return;
      _toast('No se pudo generar el PDF de pendientes. $error');
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
      case 'Centro de pagos':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openPaymentCenter());
        return;
      case 'Pagos fijos':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openFixedPayments());
        return;
      case 'Cuentas Bancarias':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openBankAccounts());
        return;
    }
  }

  String _money(double value) {
    final negative = value < 0;
    final fixed = value.abs().toStringAsFixed(2);
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
    return '${negative ? '-' : ''}\$${buffer.toString()}.$fraction';
  }

  String _providerMovementSourceLabel(String source) {
    return _providerMovementSourceLabelShared(source);
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return '—';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  Map<String, _ProviderTicketStatusView> _buildReconciledTicketStatuses({
    required List<ComprasTicketRecord> tickets,
    required List<_ProviderInvoiceView> invoices,
    required Map<String, List<_ProviderTicketApplicationView>>
    ticketApplicationsByTicketId,
  }) {
    final statusByTicketId = <String, _ProviderTicketStatusView>{};
    final bankApplicationsByTicketId = _buildBankApplicationsByTicket(
      invoices,
      tickets.map((row) => row.id).toSet(),
    );
    for (final ticket in tickets) {
      final cappedTicketAmount = ticket.amount < 0 ? 0.0 : ticket.amount;
      final directApplications =
          ticketApplicationsByTicketId[ticket.id]?.toList(growable: false) ??
          const <_ProviderTicketApplicationView>[];
      final directApplied = directApplications.fold<double>(
        0,
        (sum, item) => sum + item.application.appliedAmount,
      );
      final bankApplications =
          bankApplicationsByTicketId[ticket.id]?.toList(growable: false) ??
          const <_ProviderTicketSettlementView>[];
      final bankApplied = bankApplications.fold<double>(
        0,
        (sum, item) => sum + item.amount,
      );
      if (cappedTicketAmount <= 0.009) {
        statusByTicketId[ticket.id] = const _ProviderTicketStatusView(
          appliedAmount: 0,
          pagoStatus: 'PAGADO',
          coverageStatus: 'CUBIERTO',
        );
        continue;
      }
      final appliedAmount = (directApplied + bankApplied)
          .clamp(0, cappedTicketAmount)
          .toDouble();
      final fullyCovered = appliedAmount >= cappedTicketAmount - 0.009;
      final hasAbono = appliedAmount > 0.009 && !fullyCovered;
      statusByTicketId[ticket.id] = _ProviderTicketStatusView(
        appliedAmount: appliedAmount,
        pagoStatus: fullyCovered
            ? 'PAGADO'
            : hasAbono
            ? 'ABONO'
            : 'PENDIENTE_DE_PAGO',
        coverageStatus: fullyCovered
            ? 'CUBIERTO'
            : hasAbono
            ? 'PARCIAL'
            : 'SIN_CUBRIR',
      );
    }
    return statusByTicketId;
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
          trailingBuilder: (_, _) => Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _FinHeaderButton(
                label: 'PDF pendientes',
                icon: Icons.picture_as_pdf_rounded,
                onTap: _exportGlobalPendingInvoicesPdf,
                iconOnly: true,
              ),
              _FinHeaderButton(
                label: 'CSV pendientes',
                icon: Icons.table_chart_rounded,
                onTap: _exportGlobalPendingInvoicesCsv,
                iconOnly: true,
              ),
              _FinHeaderButton(
                label: 'Cerrar sesión',
                icon: Icons.logout_rounded,
                onTap: _logout,
                iconOnly: true,
              ),
            ],
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
                                  onPrintAccount: _printAccountReportFor,
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
                                        onRegisterManualInvoice:
                                            _registerManualInvoiceForSelectedProvider,
                                        onEditProviderPriority:
                                            _editProviderPriorityForSelectedProvider,
                                        onOpenBankAccounts: _openBankAccounts,
                                        onRegisterCashMovement:
                                            _registerProviderCashMovementForSelectedProvider,
                                        onRegisterAgreement:
                                            _registerAgreementForSelectedProvider,
                                        onEditAgreement:
                                            _editAgreementForSelectedProvider,
                                        onCancelAgreement:
                                            _cancelAgreementForSelectedProvider,
                                        onToggleInstallmentPaid:
                                            _toggleAgreementInstallmentPaid,
                                        onEditCashMovement:
                                            _editProviderCashMovementForSelectedProvider,
                                        onDeleteCashMovement:
                                            _deleteProviderCashMovementForSelectedProvider,
                                        onEditInvoice:
                                            _editInvoiceForSelectedProvider,
                                        onEditInvoicePriority:
                                            _editInvoicePriority,
                                        onOpenInvoiceEvidence:
                                            _openInvoiceEvidenceDialog,
                                        onDeleteTicket:
                                            _deleteTicketForSelectedProvider,
                                        onDeleteInvoice:
                                            _deleteInvoiceForSelectedProvider,
                                        onPrintAccount: _printAccountReportFor,
                                        onPrintInvoices:
                                            _printInvoicesReportFor,
                                        onExportProviderExcelTemplate:
                                            _exportProviderExcelTemplateFor,
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
                        color: const Color(0xFF8B4A1A).withValues(alpha: 0.08),
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

String _normalizedProviderAliasKey(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String _providerMovementSourceLabelShared(String source) {
  switch (source) {
    case 'BOVEDA':
      return 'Boveda';
    case 'INTERNO':
      return 'Interno';
    case 'BANCO':
      return 'Banco';
    default:
      return 'Efectivo';
  }
}

class _ProviderPayableSummary {
  final double amount;
  final int openInvoicesCount;
  final DateTime? nextDueDate;

  const _ProviderPayableSummary({
    required this.amount,
    required this.openInvoicesCount,
    required this.nextDueDate,
  });
}

_ProviderPayableSummary _computeProviderPayableSummary({
  required List<FinanzasSupplierInvoiceRecord> invoices,
  required List<FinanzasBankMovementRecord> movements,
}) {
  final appliedByInvoiceId = _buildAppliedSupplierAmountByInvoiceId(movements);

  double payableAmount = 0;
  var openInvoicesCount = 0;
  DateTime? nextDueDate;
  for (final invoice in invoices) {
    final effectiveBalance = _effectiveSupplierInvoiceBalance(
      invoice,
      appliedByInvoiceId,
    );
    if (effectiveBalance <= 0.009) continue;
    payableAmount += effectiveBalance;
    openInvoicesCount += 1;
    final dueDate = invoice.dueDate;
    if (dueDate == null) continue;
    if (nextDueDate == null || dueDate.isBefore(nextDueDate)) {
      nextDueDate = dueDate;
    }
  }

  return _ProviderPayableSummary(
    amount: payableAmount,
    openInvoicesCount: openInvoicesCount,
    nextDueDate: nextDueDate,
  );
}

Map<String, double> _buildAppliedSupplierAmountByInvoiceId(
  Iterable<FinanzasBankMovementRecord> movements,
) {
  final appliedByInvoiceId = <String, double>{};
  for (final movement in movements) {
    final invoiceId = movement.linkedSupplierInvoiceId;
    if (invoiceId == null || invoiceId.isEmpty) continue;
    final applied = movement.effectiveSupplierAppliedAmount.clamp(
      0.0,
      double.infinity,
    );
    if (applied <= 0.009) continue;
    appliedByInvoiceId.update(
      invoiceId,
      (sum) => sum + applied,
      ifAbsent: () => applied,
    );
  }
  return appliedByInvoiceId;
}

double _effectiveSupplierInvoiceBalance(
  FinanzasSupplierInvoiceRecord invoice,
  Map<String, double> appliedByInvoiceId,
) {
  final linkedPaid = appliedByInvoiceId[invoice.id];
  return linkedPaid == null
      ? invoice.balanceAmount.clamp(0.0, invoice.totalAmount).toDouble()
      : (invoice.totalAmount - linkedPaid)
            .clamp(0.0, invoice.totalAmount)
            .toDouble();
}

class _ProviderAccountView {
  final FinanzasCompanyDirectoryRecord company;
  final List<ComprasTicketRecord> tickets;
  final Map<String, _ProviderTicketStatusView> reconciledTicketStatuses;
  final List<_ProviderInvoiceView> invoices;
  final List<FinanzasBankMovementRecord> movements;
  final List<ComprasProviderMovementRecord> cashMovements;
  final List<_ProviderAgreementView> agreements;
  final Map<String, List<_ProviderTicketApplicationView>>
  ticketApplicationsByTicketId;
  final double totalAmount;
  final double openAmount;
  final double facturadoAmount;
  final double sinFacturaAmount;
  final double pendienteFacturarAmount;
  final double paidAmount;
  final double overdueAmount;
  final int openTicketsCount;
  final DateTime? nextCommitmentDate;
  final double payableAmount;
  final int openInvoicesCount;
  final DateTime? nextPayableDate;
  final String urgencyLabel;
  final Color urgencyTone;
  final String recommendation;

  const _ProviderAccountView({
    required this.company,
    required this.tickets,
    required this.reconciledTicketStatuses,
    required this.invoices,
    required this.movements,
    required this.cashMovements,
    required this.agreements,
    required this.ticketApplicationsByTicketId,
    required this.totalAmount,
    required this.openAmount,
    required this.facturadoAmount,
    required this.sinFacturaAmount,
    required this.pendienteFacturarAmount,
    required this.paidAmount,
    required this.overdueAmount,
    required this.openTicketsCount,
    required this.nextCommitmentDate,
    required this.payableAmount,
    required this.openInvoicesCount,
    required this.nextPayableDate,
    required this.urgencyLabel,
    required this.urgencyTone,
    required this.recommendation,
  });
}

class _ProviderInvoiceView {
  final FinanzasSupplierInvoiceRecord invoice;
  final FinanzasBankMovementRecord? bankMovement;
  final List<ComprasTicketRecord> tickets;
  final List<FinanzasEvidenceRecord> evidences;

  const _ProviderInvoiceView({
    required this.invoice,
    required this.bankMovement,
    required this.tickets,
    required this.evidences,
  });
}

class _GlobalPendingInvoiceReportRow {
  final String invoiceId;
  final DateTime date;
  final String companyName;
  final String folio;
  final double totalAmount;
  final double pendingAmount;

  const _GlobalPendingInvoiceReportRow({
    required this.invoiceId,
    required this.date,
    required this.companyName,
    required this.folio,
    required this.totalAmount,
    required this.pendingAmount,
  });
}

class _GlobalPendingBreakdownRow {
  final String label;
  final double dueAmount;
  final double paidAmount;

  const _GlobalPendingBreakdownRow({
    required this.label,
    required this.dueAmount,
    required this.paidAmount,
  });

  double get totalAmount => dueAmount + paidAmount;
}

class _GlobalPendingBreakdownSummary {
  final List<_GlobalPendingBreakdownRow> rows;

  const _GlobalPendingBreakdownSummary({required this.rows});

  double get totalDueAmount =>
      rows.fold<double>(0, (sum, row) => sum + row.dueAmount);

  double get totalPaidAmount =>
      rows.fold<double>(0, (sum, row) => sum + row.paidAmount);

  double get totalAmount => totalDueAmount + totalPaidAmount;
}

class _GlobalPendingDetailRow {
  final String concept;
  final String status;
  final double amount;

  const _GlobalPendingDetailRow({
    required this.concept,
    required this.status,
    required this.amount,
  });
}

class _MutableGlobalPendingBreakdownBucket {
  double dueAmount = 0;
  double paidAmount = 0;
}

bool _isManualSupplierInvoice(_ProviderInvoiceView row) {
  return row.invoice.originType == 'MANUAL';
}

bool _isOrphanTicketSupplierInvoice(_ProviderInvoiceView row) {
  return row.invoice.originType == 'TICKETS' && row.tickets.isEmpty;
}

bool _canEditSupplierInvoice(_ProviderInvoiceView row) {
  final untouchedBalance =
      (row.invoice.totalAmount - row.invoice.balanceAmount).abs() <= 0.009;
  final status = row.invoice.status.trim().toUpperCase();
  return row.bankMovement == null &&
      untouchedBalance &&
      (status == 'PENDIENTE' || status == 'VENCIDA');
}

bool _canEditSupplierInvoiceFolioOnly(_ProviderInvoiceView row) {
  return row.bankMovement != null;
}

class _ProviderTicketApplicationView {
  final ComprasTicketPaymentApplicationRecord application;
  final ComprasProviderMovementRecord movement;

  const _ProviderTicketApplicationView({
    required this.application,
    required this.movement,
  });
}

class _ProviderTicketStatusView {
  final double appliedAmount;
  final String pagoStatus;
  final String coverageStatus;

  const _ProviderTicketStatusView({
    required this.appliedAmount,
    required this.pagoStatus,
    required this.coverageStatus,
  });
}

class _ProviderAccountMetricsView {
  final double totalAmount;
  final double openAmount;
  final double facturadoAmount;
  final double sinFacturaAmount;
  final double pendienteFacturarAmount;
  final double paidAmount;
  final double overdueAmount;
  final int openTicketsCount;
  final DateTime? nextCommitmentDate;

  const _ProviderAccountMetricsView({
    required this.totalAmount,
    required this.openAmount,
    required this.facturadoAmount,
    required this.sinFacturaAmount,
    required this.pendienteFacturarAmount,
    required this.paidAmount,
    required this.overdueAmount,
    required this.openTicketsCount,
    required this.nextCommitmentDate,
  });
}

_ProviderAccountMetricsView _computeProviderAccountMetrics(
  _ProviderAccountView account,
) {
  final today = DateUtils.dateOnly(DateTime.now());
  double total = 0;
  double open = 0;
  double facturado = 0;
  double sinFactura = 0;
  double pendienteFacturar = 0;
  double pagado = 0;
  double vencido = 0;
  var abiertos = 0;
  DateTime? nextCommitment;

  for (final ticket in account.tickets) {
    final resolved = _resolveProviderTicketStatus(account, ticket);
    total += ticket.amount;
    if (ticket.amount <= 0.009) {
      open += ticket.amount;
      if (ticket.facturaStatus == 'FACTURADO') {
        facturado += ticket.amount;
      } else if (ticket.facturaStatus == 'SIN_FACTURA') {
        sinFactura += ticket.amount;
      } else {
        pendienteFacturar += ticket.amount;
      }
      continue;
    }
    final dueDate = DateUtils.dateOnly(
      ticket.date.add(Duration(days: account.company.creditDays)),
    );
    if (resolved.pagoStatus == 'PAGADO') {
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
    if (account.company.creditDays > 0 &&
        (dueDate.isBefore(today) || dueDate == today)) {
      vencido += ticket.amount;
    }
    if (nextCommitment == null || dueDate.isBefore(nextCommitment)) {
      nextCommitment = dueDate;
    }
  }

  for (final invoiceRow in account.invoices) {
    if (!_isManualSupplierInvoice(invoiceRow)) continue;
    final invoice = invoiceRow.invoice;
    total += invoice.totalAmount;
    if (invoice.status == 'PAGADA') {
      pagado += invoice.totalAmount;
      continue;
    }
    open += invoice.balanceAmount;
    facturado += invoice.balanceAmount;
    if (invoice.balanceAmount > 0.009 && invoice.dueDate != null) {
      final dueDate = DateUtils.dateOnly(invoice.dueDate!);
      if (dueDate.isBefore(today) || dueDate == today) {
        vencido += invoice.balanceAmount;
      }
    }
  }

  for (final invoice in account.invoices) {
    if (invoice.invoice.status == 'PAGADA') continue;
    final dueDate = invoice.invoice.dueDate;
    if (dueDate == null) continue;
    if (nextCommitment == null || dueDate.isBefore(nextCommitment)) {
      nextCommitment = dueDate;
    }
  }

  return _ProviderAccountMetricsView(
    totalAmount: total,
    openAmount: open,
    facturadoAmount: facturado,
    sinFacturaAmount: sinFactura,
    pendienteFacturarAmount: pendienteFacturar,
    paidAmount: pagado,
    overdueAmount: vencido,
    openTicketsCount: abiertos,
    nextCommitmentDate: nextCommitment,
  );
}

Map<String, List<_ProviderTicketSettlementView>> _buildBankApplicationsByTicket(
  List<_ProviderInvoiceView> invoices,
  Set<String> reportTicketIds,
) {
  final result = <String, List<_ProviderTicketSettlementView>>{};
  for (final invoice in invoices) {
    final movement = invoice.bankMovement;
    if (movement == null) continue;
    if (movement.debitAmount <= 0.009) continue;
    final invoiceTickets =
        invoice.tickets
            .where((ticket) => reportTicketIds.contains(ticket.id))
            .toList(growable: false)
          ..sort((a, b) {
            final dateCompare = a.date.compareTo(b.date);
            if (dateCompare != 0) return dateCompare;
            return a.ticket.compareTo(b.ticket);
          });
    if (invoiceTickets.isEmpty) continue;
    var remaining =
        (invoice.invoice.totalAmount - invoice.invoice.balanceAmount)
            .clamp(0, invoice.invoice.totalAmount)
            .toDouble();
    if (remaining <= 0.009) continue;
    for (final ticket in invoiceTickets) {
      if (remaining <= 0.009) break;
      if (ticket.amount <= 0.009) continue;
      final applied = remaining > ticket.amount ? ticket.amount : remaining;
      if (applied <= 0.009) continue;
      result
          .putIfAbsent(ticket.id, () => <_ProviderTicketSettlementView>[])
          .add(
            _ProviderTicketSettlementView(
              date: movement.date,
              reference: movement.reference,
              sourceLabel: '${movement.company} ${movement.branch}',
              amount: applied,
            ),
          );
      remaining = (remaining - applied).clamp(0, double.infinity).toDouble();
    }
  }
  return result;
}

_ProviderTicketStatusView _resolveProviderTicketStatus(
  _ProviderAccountView account,
  ComprasTicketRecord ticket,
) {
  final cappedTicketAmount = ticket.amount < 0 ? 0.0 : ticket.amount;
  final directApplications =
      account.ticketApplicationsByTicketId[ticket.id]?.toList(
        growable: false,
      ) ??
      const <_ProviderTicketApplicationView>[];
  final directApplied = directApplications.fold<double>(
    0,
    (sum, item) => sum + item.application.appliedAmount,
  );
  final bankApplications =
      _buildBankApplicationsByTicket(
        account.invoices,
        account.tickets.map((row) => row.id).toSet(),
      )[ticket.id]?.toList(growable: false) ??
      const <_ProviderTicketSettlementView>[];
  final bankApplied = bankApplications.fold<double>(
    0,
    (sum, item) => sum + item.amount,
  );
  if (cappedTicketAmount <= 0.009) {
    return const _ProviderTicketStatusView(
      appliedAmount: 0,
      pagoStatus: 'PAGADO',
      coverageStatus: 'CUBIERTO',
    );
  }
  final appliedAmount = (directApplied + bankApplied)
      .clamp(0, cappedTicketAmount)
      .toDouble();
  final fullyCovered = appliedAmount >= cappedTicketAmount - 0.009;
  final hasAbono = appliedAmount > 0.009 && !fullyCovered;
  return _ProviderTicketStatusView(
    appliedAmount: appliedAmount,
    pagoStatus: fullyCovered
        ? 'PAGADO'
        : hasAbono
        ? 'ABONO'
        : 'PENDIENTE_DE_PAGO',
    coverageStatus: fullyCovered
        ? 'CUBIERTO'
        : hasAbono
        ? 'PARCIAL'
        : 'SIN_CUBRIR',
  );
}

class _ProviderAgreementView {
  final FinanzasSupplierAgreementRecord agreement;
  final List<FinanzasSupplierAgreementInstallmentRecord> installments;
  final List<_ProviderAgreementInvoiceLinkView> invoiceLinks;

  const _ProviderAgreementView({
    required this.agreement,
    required this.installments,
    required this.invoiceLinks,
  });
}

class _ProviderAgreementInvoiceLinkView {
  final FinanzasSupplierAgreementInvoiceRecord link;
  final FinanzasSupplierInvoiceRecord invoice;

  const _ProviderAgreementInvoiceLinkView({
    required this.link,
    required this.invoice,
  });
}

class _ProviderAccountPaymentRow {
  final String id;
  final DateTime date;
  final String sourceLabel;
  final String reference;
  final String typeLabel;
  final double amount;

  const _ProviderAccountPaymentRow({
    required this.id,
    required this.date,
    required this.sourceLabel,
    required this.reference,
    required this.typeLabel,
    required this.amount,
  });
}

class _AccountReportSelectionResult {
  final Set<String> selectedTicketIds;
  final Set<String> selectedMovementIds;

  const _AccountReportSelectionResult({
    required this.selectedTicketIds,
    required this.selectedMovementIds,
  });
}

class _ProviderReportMovementSelectionItem {
  final String id;
  final DateTime date;
  final DateTime? createdAt;
  final String title;
  final String subtitle;
  final String reference;
  final double amount;
  final FinanzasBankMovementRecord? bankMovement;
  final ComprasProviderMovementRecord? cashMovement;

  const _ProviderReportMovementSelectionItem._({
    required this.id,
    required this.date,
    required this.createdAt,
    required this.title,
    required this.subtitle,
    required this.reference,
    required this.amount,
    this.bankMovement,
    this.cashMovement,
  });

  factory _ProviderReportMovementSelectionItem.cash(
    ComprasProviderMovementRecord row,
  ) {
    return _ProviderReportMovementSelectionItem._(
      id: 'cash-${row.id}',
      date: row.date,
      createdAt: row.createdAt,
      title: _providerMovementTypeLabel(row.type),
      subtitle: _providerMovementSourceLabelShared(row.source),
      reference: row.reference,
      amount: row.amount,
      cashMovement: row,
    );
  }

  factory _ProviderReportMovementSelectionItem.bank(
    FinanzasBankMovementRecord row,
  ) {
    final amount = row.creditAmount > 0 ? row.creditAmount : row.debitAmount;
    final title = row.creditAmount > 0 ? 'Abono banco' : 'Cargo banco';
    final subtitle =
        '${row.company} ${row.branch} · ${row.counterpartyNameSnapshot.isEmpty ? row.category : row.counterpartyNameSnapshot}';
    return _ProviderReportMovementSelectionItem._(
      id: 'bank-${row.id}',
      date: row.date,
      createdAt: row.createdAt,
      title: title,
      subtitle: subtitle,
      reference: row.reference,
      amount: amount,
      bankMovement: row,
    );
  }
}

class _ProviderTicketSettlementView {
  final DateTime date;
  final String reference;
  final String sourceLabel;
  final double amount;

  const _ProviderTicketSettlementView({
    required this.date,
    required this.reference,
    required this.sourceLabel,
    required this.amount,
  });
}

class _InvoiceReportSelectionResult {
  final Set<String> selectedInvoiceIds;

  const _InvoiceReportSelectionResult({required this.selectedInvoiceIds});
}

enum _InvoiceReportStatusFilter { ambas, pendientes, pagadas }

class _ProviderInvoiceReportSelectionDialog extends StatefulWidget {
  final String providerName;
  final List<_ProviderInvoiceView> invoices;

  const _ProviderInvoiceReportSelectionDialog({
    required this.providerName,
    required this.invoices,
  });

  @override
  State<_ProviderInvoiceReportSelectionDialog> createState() =>
      _ProviderInvoiceReportSelectionDialogState();
}

class _ProviderInvoiceReportSelectionDialogState
    extends State<_ProviderInvoiceReportSelectionDialog> {
  late final TextEditingController _searchC;
  final ScrollController _rowsScrollController = ScrollController();
  final GlobalKey _rowsViewportKey = GlobalKey();
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  final Set<String> _selectedInvoiceIds = <String>{};
  DateTimeRange? _dateRangeFilter;
  _InvoiceReportStatusFilter _statusFilter = _InvoiceReportStatusFilter.ambas;
  String? _dragSelectionAnchorId;
  bool _dragSelectionActive = false;
  Offset? _dragStartGlobal;
  Offset? _dragPointerGlobal;
  double _dragAutoScrollVelocity = 0;
  Timer? _dragAutoScrollTimer;

  @override
  void initState() {
    super.initState();
    _searchC = TextEditingController();
  }

  @override
  void dispose() {
    _dragAutoScrollTimer?.cancel();
    _searchC.dispose();
    _rowsScrollController.dispose();
    super.dispose();
  }

  List<_ProviderInvoiceView> get _filteredInvoices {
    final query = _searchC.text.trim().toLowerCase();
    return widget.invoices
        .where((row) {
          if (_statusFilter == _InvoiceReportStatusFilter.pendientes &&
              row.invoice.status == 'PAGADA') {
            return false;
          }
          if (_statusFilter == _InvoiceReportStatusFilter.pagadas &&
              row.invoice.status != 'PAGADA') {
            return false;
          }
          if (query.isNotEmpty) {
            final ticketNumbers = row.tickets
                .map((ticket) => ticket.ticket.toLowerCase())
                .join(' ');
            final haystack =
                '${row.invoice.folio} ${row.invoice.notes} $ticketNumbers'
                    .toLowerCase();
            if (!haystack.contains(query)) return false;
          }
          if (_dateRangeFilter != null) {
            final invoiceDay = DateUtils.dateOnly(row.invoice.invoiceDate);
            final start = DateUtils.dateOnly(_dateRangeFilter!.start);
            final end = DateUtils.dateOnly(_dateRangeFilter!.end);
            if (invoiceDay.isBefore(start) || invoiceDay.isAfter(end)) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);
  }

  String _money(double value) {
    final negative = value < 0;
    final fixed = value.abs().toStringAsFixed(2);
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
    return '${negative ? '-' : ''}\$${buffer.toString()}.$fraction';
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return 'Sin fecha';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  String _dateRangeLabel(DateTimeRange? value) {
    if (value == null) return 'Todas las fechas';
    return '${_dateLabel(value.start)} - ${_dateLabel(value.end)}';
  }

  Future<void> _pickDateRange() async {
    final picked = await _showProviderDateRangeDialog(
      context,
      title: 'Filtrar facturas',
      initialRange: _dateRangeFilter,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateRangeFilter = picked == _kClearedProviderDateRange ? null : picked;
    });
  }

  GlobalKey _rowItemKey(String rowId) => _rowKeys.putIfAbsent(
    rowId,
    () => GlobalObjectKey('provider-invoice-report-$rowId'),
  );

  void _beginDragSelection(String rowId) {
    setState(() {
      _dragSelectionAnchorId = rowId;
      _dragSelectionActive = false;
      _dragStartGlobal = null;
    });
  }

  void _activateDragSelection() {
    if (_dragSelectionActive || _dragSelectionAnchorId == null) return;
    _dragSelectionActive = true;
    _selectedInvoiceIds
      ..clear()
      ..add(_dragSelectionAnchorId!);
  }

  void _updateDragSelection(String rowId, List<_ProviderInvoiceView> rows) {
    if (!_dragSelectionActive || _dragSelectionAnchorId == null) return;
    final visibleIds = rows
        .map((row) => row.invoice.id)
        .toList(growable: false);
    final start = visibleIds.indexOf(_dragSelectionAnchorId!);
    final end = visibleIds.indexOf(rowId);
    if (start == -1 || end == -1) return;
    final range = visibleIds.sublist(
      start < end ? start : end,
      start < end ? end + 1 : start + 1,
    );
    setState(() {
      _selectedInvoiceIds
        ..clear()
        ..addAll(range);
    });
  }

  void _endDragSelection() {
    if (!_dragSelectionActive &&
        _dragSelectionAnchorId == null &&
        _dragStartGlobal == null) {
      return;
    }
    setState(() {
      _dragSelectionActive = false;
      _dragSelectionAnchorId = null;
      _dragStartGlobal = null;
      _dragPointerGlobal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
    });
  }

  int? _visibleRowIndexAtGlobalPosition(
    Offset globalPosition,
    List<_ProviderInvoiceView> rows,
  ) {
    for (var i = 0; i < rows.length; i++) {
      final box =
          _rowItemKey(rows[i].invoice.id).currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(globalPosition)) return i;
    }
    return null;
  }

  int? _mountedEdgeRowIndex(
    List<_ProviderInvoiceView> rows, {
    required bool last,
  }) {
    final indexes = <int>[];
    for (var i = 0; i < rows.length; i++) {
      final box =
          _rowItemKey(rows[i].invoice.id).currentContext?.findRenderObject()
              as RenderBox?;
      if (box != null && box.hasSize) indexes.add(i);
    }
    if (indexes.isEmpty) return null;
    return last ? indexes.last : indexes.first;
  }

  void _handleRowsPointerMove(
    PointerMoveEvent event,
    List<_ProviderInvoiceView> rows,
  ) {
    if (_dragSelectionAnchorId == null) return;
    _dragStartGlobal ??= event.position;
    if (!_dragSelectionActive) {
      final delta = (event.position - _dragStartGlobal!).distance;
      if (delta < 6) return;
      setState(_activateDragSelection);
    }
    _dragPointerGlobal = event.position;
    _updateDragAutoScroll(rows);
    final visibleIndex = _visibleRowIndexAtGlobalPosition(event.position, rows);
    if (visibleIndex == null) return;
    _updateDragSelection(rows[visibleIndex].invoice.id, rows);
  }

  void _updateDragAutoScroll(List<_ProviderInvoiceView> rows) {
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
    _dragAutoScrollTimer ??= Timer.periodic(const Duration(milliseconds: 16), (
      _,
    ) {
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
      if (pointer == null || viewportBox == null || !viewportBox.hasSize) {
        return;
      }
      final visibleIndex = _visibleRowIndexAtGlobalPosition(pointer, rows);
      int? targetIndex = visibleIndex;
      if (targetIndex == null) {
        final local = viewportBox.globalToLocal(pointer);
        if (local.dy < 0) {
          targetIndex = _mountedEdgeRowIndex(rows, last: false);
        } else if (local.dy > viewportBox.size.height) {
          targetIndex = _mountedEdgeRowIndex(rows, last: true);
        }
      }
      if (targetIndex == null) return;
      _updateDragSelection(rows[targetIndex].invoice.id, rows);
    });
  }

  Widget _buildStatusChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final tokens = AreaThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? tokens.primaryStrong.withValues(alpha: 0.88)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? tokens.primaryStrong
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.8,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : tokens.badgeText,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final filteredInvoices = _filteredInvoices;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: Builder(
          builder: (context) => ContractGlassCard(
            borderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: SizedBox(
              width: 940,
              height: 680,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DialogHeader(
                    title: 'Imprimir facturas',
                    subtitle:
                        '${widget.providerName} · ${_selectedInvoiceIds.length} factura(s) seleccionada(s)',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatusChip(
                        context,
                        label: 'Ambas',
                        selected:
                            _statusFilter == _InvoiceReportStatusFilter.ambas,
                        onTap: () => setState(
                          () =>
                              _statusFilter = _InvoiceReportStatusFilter.ambas,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(
                        context,
                        label: 'Pendientes',
                        selected:
                            _statusFilter ==
                            _InvoiceReportStatusFilter.pendientes,
                        onTap: () => setState(
                          () => _statusFilter =
                              _InvoiceReportStatusFilter.pendientes,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(
                        context,
                        label: 'Pagadas',
                        selected:
                            _statusFilter == _InvoiceReportStatusFilter.pagadas,
                        onTap: () => setState(
                          () => _statusFilter =
                              _InvoiceReportStatusFilter.pagadas,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchC,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          cursorColor: finanzasAreaTokens.primaryStrong,
                          decoration: contractGlassFieldDecoration(
                            context,
                            hintText: 'Filtrar por folio o ticket',
                            prefixIcon: const Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateFieldButton(
                          label: 'Rango de fechas',
                          value: _dateRangeLabel(_dateRangeFilter),
                          onTap: _pickDateRange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: contractSecondaryButtonStyle(context),
                        onPressed: () {
                          setState(() {
                            _searchC.clear();
                            _dateRangeFilter = null;
                            _statusFilter = _InvoiceReportStatusFilter.ambas;
                          });
                        },
                        child: const Text('Limpiar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _selectedInvoiceIds.addAll(
                            filteredInvoices.map((row) => row.invoice.id),
                          );
                        }),
                        style: contractSecondaryButtonStyle(context),
                        icon: const Icon(Icons.done_all_rounded, size: 18),
                        label: const Text('Seleccionar visibles'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => setState(_selectedInvoiceIds.clear),
                        style: contractGhostButtonStyle(context),
                        icon: const Icon(Icons.layers_clear_rounded, size: 18),
                        label: const Text('Limpiar selección'),
                      ),
                      const Spacer(),
                      Text(
                        '${filteredInvoices.length} visibles',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: tokens.badgeText.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Listener(
                      onPointerMove: (event) =>
                          _handleRowsPointerMove(event, filteredInvoices),
                      onPointerUp: (_) => _endDragSelection(),
                      onPointerCancel: (_) => _endDragSelection(),
                      child: Container(
                        key: _rowsViewportKey,
                        child: ListView.separated(
                          controller: _rowsScrollController,
                          itemCount: filteredInvoices.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final row = filteredInvoices[index];
                            final selected = _selectedInvoiceIds.contains(
                              row.invoice.id,
                            );
                            return KeyedSubtree(
                              key: _rowItemKey(row.invoice.id),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) => _updateDragSelection(
                                  row.invoice.id,
                                  filteredInvoices,
                                ),
                                child: Listener(
                                  onPointerDown: (event) {
                                    if (event.kind == PointerDeviceKind.mouse &&
                                        event.buttons == kPrimaryMouseButton) {
                                      _beginDragSelection(row.invoice.id);
                                    }
                                  },
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      if (selected) {
                                        _selectedInvoiceIds.remove(
                                          row.invoice.id,
                                        );
                                      } else {
                                        _selectedInvoiceIds.add(row.invoice.id);
                                      }
                                    }),
                                    child: FinanzasGlassPanel(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        14,
                                        16,
                                        14,
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                      fillColor: selected
                                          ? kFinanzasSelectionFill
                                          : kFinanzasPanelSurface,
                                      borderColor: selected
                                          ? kFinanzasAmber
                                          : Colors.white.withValues(
                                              alpha: 0.12,
                                            ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            selected
                                                ? Icons.check_circle_rounded
                                                : Icons.circle_outlined,
                                            color: selected
                                                ? Colors.white
                                                : Colors.white.withValues(
                                                    alpha: 0.74,
                                                  ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${row.invoice.folio.trim().isEmpty ? 'SIN FOLIO' : row.invoice.folio.trim()} · ${_dateLabel(row.invoice.invoiceDate)}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  _isManualSupplierInvoice(row)
                                                      ? 'Manual · ${finSupplierInvoiceStatusLabel(row.invoice.status)}'
                                                      : _isOrphanTicketSupplierInvoice(
                                                          row,
                                                        )
                                                      ? 'Tickets sin relación · ${finSupplierInvoiceStatusLabel(row.invoice.status)}'
                                                      : '${row.tickets.length} ticket(s) · ${row.tickets.map((ticket) => ticket.ticket).join(' · ')}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: selected
                                                        ? Colors.white
                                                              .withValues(
                                                                alpha: 0.94,
                                                              )
                                                        : kFinanzasMutedInk,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          SizedBox(
                                            width: 120,
                                            child: Text(
                                              _money(row.invoice.totalAmount),
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
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
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DialogActionsRow(
                    onCancel: () => Navigator.of(context).pop(),
                    confirmLabel: 'Generar PDF',
                    confirmIcon: Icons.picture_as_pdf_rounded,
                    onConfirm: _selectedInvoiceIds.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).pop(
                              _InvoiceReportSelectionResult(
                                selectedInvoiceIds: _selectedInvoiceIds.toSet(),
                              ),
                            );
                          },
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

String _providerMovementTypeLabel(String type) {
  switch (type.trim().toUpperCase()) {
    case 'PAGO':
      return 'Pago';
    case 'ABONO':
      return 'Abono';
    case 'CARGO':
      return 'Cargo';
    case 'AJUSTE':
      return 'Ajuste';
    default:
      return type.trim().isEmpty ? 'Movimiento' : type.trim();
  }
}

enum _ProviderAccountReportTab { tickets, movimientos }

class _ProviderAccountReportSelectionDialog extends StatefulWidget {
  final String providerName;
  final List<ComprasTicketRecord> tickets;
  final List<_ProviderReportMovementSelectionItem> movements;

  const _ProviderAccountReportSelectionDialog({
    required this.providerName,
    required this.tickets,
    required this.movements,
  });

  @override
  State<_ProviderAccountReportSelectionDialog> createState() =>
      _ProviderAccountReportSelectionDialogState();
}

class _ProviderAccountReportSelectionDialogState
    extends State<_ProviderAccountReportSelectionDialog> {
  late final TextEditingController _ticketNumberFilterC;
  late final TextEditingController _movementSearchFilterC;
  final ScrollController _ticketsScrollController = ScrollController();
  final ScrollController _movementsScrollController = ScrollController();
  final GlobalKey _ticketsViewportKey = GlobalKey();
  final GlobalKey _movementsViewportKey = GlobalKey();
  final Map<String, GlobalKey> _ticketRowKeys = <String, GlobalKey>{};
  final Map<String, GlobalKey> _movementRowKeys = <String, GlobalKey>{};
  final Set<String> _selectedTicketIds = <String>{};
  final Set<String> _selectedMovementIds = <String>{};
  DateTimeRange? _ticketDateRangeFilter;
  DateTimeRange? _movementDateRangeFilter;
  _ProviderAccountReportTab _activeTab = _ProviderAccountReportTab.tickets;
  String? _dragSelectionAnchorId;
  bool _dragSelectionActive = false;
  Offset? _dragStartGlobal;
  Offset? _dragPointerGlobal;
  double _dragAutoScrollVelocity = 0;
  Timer? _dragAutoScrollTimer;

  @override
  void initState() {
    super.initState();
    _ticketNumberFilterC = TextEditingController();
    _movementSearchFilterC = TextEditingController();
  }

  @override
  void dispose() {
    _dragAutoScrollTimer?.cancel();
    _ticketNumberFilterC.dispose();
    _movementSearchFilterC.dispose();
    _ticketsScrollController.dispose();
    _movementsScrollController.dispose();
    super.dispose();
  }

  List<ComprasTicketRecord> get _filteredTickets {
    final query = _ticketNumberFilterC.text.trim().toLowerCase();
    return widget.tickets
        .where((ticket) {
          if (query.isNotEmpty &&
              !ticket.ticket.toLowerCase().contains(query)) {
            return false;
          }
          final ticketDay = DateUtils.dateOnly(ticket.date);
          if (_ticketDateRangeFilter != null &&
              (ticketDay.isBefore(
                    DateUtils.dateOnly(_ticketDateRangeFilter!.start),
                  ) ||
                  ticketDay.isAfter(
                    DateUtils.dateOnly(_ticketDateRangeFilter!.end),
                  ))) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<_ProviderReportMovementSelectionItem> get _filteredMovements {
    final query = _movementSearchFilterC.text.trim().toLowerCase();
    return widget.movements
        .where((row) {
          if (query.isNotEmpty) {
            final haystack = '${row.title} ${row.subtitle} ${row.reference}'
                .toLowerCase();
            if (!haystack.contains(query)) return false;
          }
          final day = DateUtils.dateOnly(row.date);
          if (_movementDateRangeFilter != null &&
              (day.isBefore(
                    DateUtils.dateOnly(_movementDateRangeFilter!.start),
                  ) ||
                  day.isAfter(
                    DateUtils.dateOnly(_movementDateRangeFilter!.end),
                  ))) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  String _money(double value) {
    final negative = value < 0;
    final fixed = value.abs().toStringAsFixed(2);
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
    return '${negative ? '-' : ''}\$${buffer.toString()}.$fraction';
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return 'Sin fecha';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  String _dateRangeLabel(DateTimeRange? value) {
    if (value == null) return 'Todas las fechas';
    return '${_dateLabel(value.start)} - ${_dateLabel(value.end)}';
  }

  Future<void> _pickTicketDateRange() async {
    final picked = await _showProviderDateRangeDialog(
      context,
      title: 'Filtrar tickets',
      initialRange: _ticketDateRangeFilter,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _ticketDateRangeFilter = picked == _kClearedProviderDateRange
          ? null
          : picked;
    });
  }

  Future<void> _pickMovementDateRange() async {
    final picked = await _showProviderDateRangeDialog(
      context,
      title: 'Filtrar movimientos',
      initialRange: _movementDateRangeFilter,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _movementDateRangeFilter = picked == _kClearedProviderDateRange
          ? null
          : picked;
    });
  }

  GlobalKey _ticketRowKey(String rowId) => _ticketRowKeys.putIfAbsent(
    rowId,
    () => GlobalObjectKey('provider-report-ticket-$rowId'),
  );

  GlobalKey _movementRowKey(String rowId) => _movementRowKeys.putIfAbsent(
    rowId,
    () => GlobalObjectKey('provider-report-movement-$rowId'),
  );

  void _beginDragSelection(String rowId) {
    setState(() {
      _dragSelectionAnchorId = rowId;
      _dragSelectionActive = false;
      _dragStartGlobal = null;
    });
  }

  void _activateDragSelection() {
    if (_dragSelectionActive || _dragSelectionAnchorId == null) return;
    _dragSelectionActive = true;
    final targetSet = _activeTab == _ProviderAccountReportTab.tickets
        ? _selectedTicketIds
        : _selectedMovementIds;
    targetSet
      ..clear()
      ..add(_dragSelectionAnchorId!);
  }

  void _updateDragSelection<T>(
    String rowId,
    List<T> rows,
    String Function(T row) idOf,
  ) {
    if (!_dragSelectionActive || _dragSelectionAnchorId == null) return;
    final visibleIds = rows.map(idOf).toList(growable: false);
    final start = visibleIds.indexOf(_dragSelectionAnchorId!);
    final end = visibleIds.indexOf(rowId);
    if (start == -1 || end == -1) return;
    final range = visibleIds.sublist(
      start < end ? start : end,
      start < end ? end + 1 : start + 1,
    );
    setState(() {
      final targetSet = _activeTab == _ProviderAccountReportTab.tickets
          ? _selectedTicketIds
          : _selectedMovementIds;
      targetSet
        ..clear()
        ..addAll(range);
    });
  }

  void _endDragSelection() {
    if (!_dragSelectionActive &&
        _dragSelectionAnchorId == null &&
        _dragStartGlobal == null) {
      return;
    }
    setState(() {
      _dragSelectionActive = false;
      _dragSelectionAnchorId = null;
      _dragStartGlobal = null;
      _dragPointerGlobal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
    });
  }

  int? _visibleRowIndexAtGlobalPosition<T>(
    Offset globalPosition,
    List<T> rows,
    GlobalKey Function(String rowId) keyOf,
    String Function(T row) idOf,
  ) {
    for (var i = 0; i < rows.length; i++) {
      final box =
          keyOf(idOf(rows[i])).currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(globalPosition)) return i;
    }
    return null;
  }

  int? _mountedEdgeRowIndex<T>(
    List<T> rows, {
    required bool last,
    required GlobalKey Function(String rowId) keyOf,
    required String Function(T row) idOf,
  }) {
    final indexes = <int>[];
    for (var i = 0; i < rows.length; i++) {
      final box =
          keyOf(idOf(rows[i])).currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) indexes.add(i);
    }
    if (indexes.isEmpty) return null;
    return last ? indexes.last : indexes.first;
  }

  void _handleRowsPointerMove<T>(
    PointerMoveEvent event,
    List<T> rows, {
    required GlobalKey viewportKey,
    required ScrollController scrollController,
    required GlobalKey Function(String rowId) keyOf,
    required String Function(T row) idOf,
  }) {
    if (_dragSelectionAnchorId == null) return;
    _dragStartGlobal ??= event.position;
    if (!_dragSelectionActive) {
      final delta = (event.position - _dragStartGlobal!).distance;
      if (delta < 6) return;
      setState(_activateDragSelection);
    }
    _dragPointerGlobal = event.position;
    _updateDragAutoScroll(
      rows,
      viewportKey: viewportKey,
      scrollController: scrollController,
      keyOf: keyOf,
      idOf: idOf,
    );
    final visibleIndex = _visibleRowIndexAtGlobalPosition(
      event.position,
      rows,
      keyOf,
      idOf,
    );
    if (visibleIndex == null) return;
    _updateDragSelection(idOf(rows[visibleIndex]), rows, idOf);
  }

  void _updateDragAutoScroll<T>(
    List<T> rows, {
    required GlobalKey viewportKey,
    required ScrollController scrollController,
    required GlobalKey Function(String rowId) keyOf,
    required String Function(T row) idOf,
  }) {
    if (!_dragSelectionActive || _dragPointerGlobal == null) {
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final box = viewportKey.currentContext?.findRenderObject() as RenderBox?;
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
    _dragAutoScrollTimer ??= Timer.periodic(const Duration(milliseconds: 16), (
      _,
    ) {
      if (!_dragSelectionActive ||
          _dragAutoScrollVelocity == 0 ||
          !scrollController.hasClients) {
        _dragAutoScrollTimer?.cancel();
        _dragAutoScrollTimer = null;
        return;
      }
      final position = scrollController.position;
      final next = (position.pixels + _dragAutoScrollVelocity).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((next - position.pixels).abs() < 0.5) return;
      scrollController.jumpTo(next);
      final pointer = _dragPointerGlobal;
      final viewportBox =
          viewportKey.currentContext?.findRenderObject() as RenderBox?;
      if (pointer == null || viewportBox == null || !viewportBox.hasSize) {
        return;
      }
      final visibleIndex = _visibleRowIndexAtGlobalPosition(
        pointer,
        rows,
        keyOf,
        idOf,
      );
      int? targetIndex = visibleIndex;
      if (targetIndex == null) {
        final local = viewportBox.globalToLocal(pointer);
        if (local.dy < 0) {
          targetIndex = _mountedEdgeRowIndex(
            rows,
            last: false,
            keyOf: keyOf,
            idOf: idOf,
          );
        } else if (local.dy > viewportBox.size.height) {
          targetIndex = _mountedEdgeRowIndex(
            rows,
            last: true,
            keyOf: keyOf,
            idOf: idOf,
          );
        }
      }
      if (targetIndex == null) return;
      _updateDragSelection(idOf(rows[targetIndex]), rows, idOf);
    });
  }

  Widget _buildTabButton(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final tokens = AreaThemeScope.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? tokens.primaryStrong.withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? tokens.primaryStrong
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : tokens.badgeText,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTickets = _filteredTickets;
    final filteredMovements = _filteredMovements;
    final selectedTickets = widget.tickets
        .where((row) => _selectedTicketIds.contains(row.id))
        .toList(growable: false);
    final selectedMovements = widget.movements
        .where((row) => _selectedMovementIds.contains(row.id))
        .toList(growable: false);
    final summaryLabel =
        '${selectedTickets.length} ticket(s) · ${selectedMovements.length} movimiento(s)';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: Builder(
          builder: (context) => ContractGlassCard(
            borderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: SizedBox(
              width: 940,
              height: 680,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DialogHeader(
                    title: 'Imprimir cuenta',
                    subtitle: '${widget.providerName} · $summaryLabel',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildTabButton(
                        context,
                        label: 'Tickets',
                        selected:
                            _activeTab == _ProviderAccountReportTab.tickets,
                        onTap: () => setState(
                          () => _activeTab = _ProviderAccountReportTab.tickets,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildTabButton(
                        context,
                        label: 'Movimientos',
                        selected:
                            _activeTab == _ProviderAccountReportTab.movimientos,
                        onTap: () => setState(
                          () => _activeTab =
                              _ProviderAccountReportTab.movimientos,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_activeTab == _ProviderAccountReportTab.tickets) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ticketNumberFilterC,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            cursorColor: finanzasAreaTokens.primaryStrong,
                            decoration: contractGlassFieldDecoration(
                              context,
                              hintText: 'Filtrar por número de ticket',
                              prefixIcon: const Icon(Icons.tag_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateFieldButton(
                            label: 'Rango de fechas',
                            value: _dateRangeLabel(_ticketDateRangeFilter),
                            onTap: _pickTicketDateRange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          style: contractSecondaryButtonStyle(context),
                          onPressed: () {
                            setState(() {
                              _ticketNumberFilterC.clear();
                              _ticketDateRangeFilter = null;
                            });
                          },
                          child: const Text('Limpiar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => setState(() {
                            _selectedTicketIds.addAll(
                              filteredTickets.map((row) => row.id),
                            );
                          }),
                          style: contractSecondaryButtonStyle(context),
                          icon: const Icon(Icons.done_all_rounded, size: 18),
                          label: const Text('Seleccionar visibles'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => setState(_selectedTicketIds.clear),
                          style: contractGhostButtonStyle(context),
                          icon: const Icon(
                            Icons.layers_clear_rounded,
                            size: 18,
                          ),
                          label: const Text('Limpiar selección'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Listener(
                        onPointerMove: (event) => _handleRowsPointerMove(
                          event,
                          filteredTickets,
                          viewportKey: _ticketsViewportKey,
                          scrollController: _ticketsScrollController,
                          keyOf: _ticketRowKey,
                          idOf: (row) => row.id,
                        ),
                        onPointerUp: (_) => _endDragSelection(),
                        onPointerCancel: (_) => _endDragSelection(),
                        child: Container(
                          key: _ticketsViewportKey,
                          child: ListView.separated(
                            controller: _ticketsScrollController,
                            itemCount: filteredTickets.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final row = filteredTickets[index];
                              final selected = _selectedTicketIds.contains(
                                row.id,
                              );
                              return KeyedSubtree(
                                key: _ticketRowKey(row.id),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter: (_) => _updateDragSelection(
                                    row.id,
                                    filteredTickets,
                                    (item) => item.id,
                                  ),
                                  child: Listener(
                                    onPointerDown: (event) {
                                      if (event.kind ==
                                              PointerDeviceKind.mouse &&
                                          event.buttons ==
                                              kPrimaryMouseButton) {
                                        _beginDragSelection(row.id);
                                      }
                                    },
                                    child: GestureDetector(
                                      onTap: () => setState(() {
                                        if (selected) {
                                          _selectedTicketIds.remove(row.id);
                                        } else {
                                          _selectedTicketIds.add(row.id);
                                        }
                                      }),
                                      child: FinanzasGlassPanel(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          14,
                                          16,
                                          14,
                                        ),
                                        borderRadius: BorderRadius.circular(22),
                                        fillColor: selected
                                            ? kFinanzasSelectionFill
                                            : kFinanzasPanelSurface,
                                        borderColor: selected
                                            ? kFinanzasAmber
                                            : Colors.white.withValues(
                                                alpha: 0.12,
                                              ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              selected
                                                  ? Icons.check_circle_rounded
                                                  : Icons.circle_outlined,
                                              color: selected
                                                  ? Colors.white
                                                  : Colors.white.withValues(
                                                      alpha: 0.74,
                                                    ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${_dateLabel(row.date)} · Ticket ${row.ticket}',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    row.materialNameSnapshot,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: selected
                                                          ? Colors.white
                                                                .withValues(
                                                                  alpha: 0.94,
                                                                )
                                                          : kFinanzasMutedInk,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            SizedBox(
                                              width: 120,
                                              child: Text(
                                                _money(row.amount),
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
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
                            },
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _movementSearchFilterC,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            cursorColor: finanzasAreaTokens.primaryStrong,
                            decoration: contractGlassFieldDecoration(
                              context,
                              hintText: 'Filtrar por referencia o origen',
                              prefixIcon: const Icon(Icons.search_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateFieldButton(
                            label: 'Rango de fechas',
                            value: _dateRangeLabel(_movementDateRangeFilter),
                            onTap: _pickMovementDateRange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          style: contractSecondaryButtonStyle(context),
                          onPressed: () {
                            setState(() {
                              _movementSearchFilterC.clear();
                              _movementDateRangeFilter = null;
                            });
                          },
                          child: const Text('Limpiar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => setState(() {
                            _selectedMovementIds.addAll(
                              filteredMovements.map((row) => row.id),
                            );
                          }),
                          style: contractSecondaryButtonStyle(context),
                          icon: const Icon(Icons.done_all_rounded, size: 18),
                          label: const Text('Seleccionar visibles'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => setState(_selectedMovementIds.clear),
                          style: contractGhostButtonStyle(context),
                          icon: const Icon(
                            Icons.layers_clear_rounded,
                            size: 18,
                          ),
                          label: const Text('Limpiar selección'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Listener(
                        onPointerMove: (event) => _handleRowsPointerMove(
                          event,
                          filteredMovements,
                          viewportKey: _movementsViewportKey,
                          scrollController: _movementsScrollController,
                          keyOf: _movementRowKey,
                          idOf: (row) => row.id,
                        ),
                        onPointerUp: (_) => _endDragSelection(),
                        onPointerCancel: (_) => _endDragSelection(),
                        child: Container(
                          key: _movementsViewportKey,
                          child: ListView.separated(
                            controller: _movementsScrollController,
                            itemCount: filteredMovements.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final row = filteredMovements[index];
                              final selected = _selectedMovementIds.contains(
                                row.id,
                              );
                              return KeyedSubtree(
                                key: _movementRowKey(row.id),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter: (_) => _updateDragSelection(
                                    row.id,
                                    filteredMovements,
                                    (item) => item.id,
                                  ),
                                  child: Listener(
                                    onPointerDown: (event) {
                                      if (event.kind ==
                                              PointerDeviceKind.mouse &&
                                          event.buttons ==
                                              kPrimaryMouseButton) {
                                        _beginDragSelection(row.id);
                                      }
                                    },
                                    child: GestureDetector(
                                      onTap: () => setState(() {
                                        if (selected) {
                                          _selectedMovementIds.remove(row.id);
                                        } else {
                                          _selectedMovementIds.add(row.id);
                                        }
                                      }),
                                      child: FinanzasGlassPanel(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          14,
                                          16,
                                          14,
                                        ),
                                        borderRadius: BorderRadius.circular(22),
                                        fillColor: selected
                                            ? kFinanzasSelectionFill
                                            : kFinanzasPanelSurface,
                                        borderColor: selected
                                            ? kFinanzasAmber
                                            : Colors.white.withValues(
                                                alpha: 0.12,
                                              ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              selected
                                                  ? Icons.check_circle_rounded
                                                  : Icons.circle_outlined,
                                              color: selected
                                                  ? Colors.white
                                                  : Colors.white.withValues(
                                                      alpha: 0.74,
                                                    ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${_dateLabel(row.date)} · ${row.title}',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    row.subtitle,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: selected
                                                          ? Colors.white
                                                                .withValues(
                                                                  alpha: 0.94,
                                                                )
                                                          : kFinanzasMutedInk,
                                                    ),
                                                  ),
                                                  if (row.reference
                                                      .trim()
                                                      .isNotEmpty)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 4,
                                                          ),
                                                      child: Text(
                                                        row.reference.trim(),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.70,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            SizedBox(
                                              width: 120,
                                              child: Text(
                                                _money(row.amount),
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
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
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _DialogActionsRow(
                    onCancel: () => Navigator.of(context).pop(),
                    confirmLabel: 'Generar cuenta',
                    confirmIcon: Icons.picture_as_pdf_rounded,
                    onConfirm:
                        _selectedTicketIds.isEmpty &&
                            _selectedMovementIds.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).pop(
                              _AccountReportSelectionResult(
                                selectedTicketIds: _selectedTicketIds.toSet(),
                                selectedMovementIds: _selectedMovementIds
                                    .toSet(),
                              ),
                            );
                          },
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

class _ProviderAccountsListPane extends StatelessWidget {
  final TextEditingController searchController;
  final List<_ProviderAccountView> rows;
  final String? selectedCompanyId;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final ValueChanged<String> onSelect;
  final Future<void> Function(_ProviderAccountView row) onPrintAccount;

  const _ProviderAccountsListPane({
    required this.searchController,
    required this.rows,
    required this.selectedCompanyId,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onSelect,
    required this.onPrintAccount,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final totals = _computeProviderAccountsPaneTotals(rows);
    return ContractGlassCard(
      borderRadius: BorderRadius.circular(30),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
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
          _ProviderAccountsMiniTotalsGrid(
            moneyFormatter: moneyFormatter,
            totals: totals,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            cursorColor: finanzasAreaTokens.primaryStrong,
            decoration:
                contractGlassFieldDecoration(
                  context,
                  hintText: 'Buscar proveedor',
                  prefixIcon: const Icon(Icons.search_rounded),
                ).copyWith(
                  hintStyle: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontWeight: FontWeight.w700,
                  ),
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
                        onPrint: () => onPrintAccount(row),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProviderAccountsPaneTotals {
  final double facturadoAmount;
  final double pendienteFacturarAmount;
  final double sinFacturaAmount;

  const _ProviderAccountsPaneTotals({
    required this.facturadoAmount,
    required this.pendienteFacturarAmount,
    required this.sinFacturaAmount,
  });

  double get totalAmount =>
      facturadoAmount + pendienteFacturarAmount + sinFacturaAmount;
}

_ProviderAccountsPaneTotals _computeProviderAccountsPaneTotals(
  List<_ProviderAccountView> rows,
) {
  double facturado = 0;
  double pendienteFacturar = 0;
  double sinFactura = 0;
  for (final row in rows) {
    final metrics = _computeProviderAccountMetrics(row);
    facturado += metrics.facturadoAmount;
    pendienteFacturar += metrics.pendienteFacturarAmount;
    sinFactura += metrics.sinFacturaAmount;
  }
  return _ProviderAccountsPaneTotals(
    facturadoAmount: facturado,
    pendienteFacturarAmount: pendienteFacturar,
    sinFacturaAmount: sinFactura,
  );
}

class _ProviderAccountsMiniTotalsGrid extends StatelessWidget {
  final String Function(double value) moneyFormatter;
  final _ProviderAccountsPaneTotals totals;

  const _ProviderAccountsMiniTotalsGrid({
    required this.moneyFormatter,
    required this.totals,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        'Facturado',
        moneyFormatter(totals.facturadoAmount),
        Icons.receipt_long_outlined,
      ),
      (
        'Pend. facturar',
        moneyFormatter(totals.pendienteFacturarAmount),
        Icons.pending_actions_outlined,
      ),
      (
        'Sin factura',
        moneyFormatter(totals.sinFacturaAmount),
        Icons.description_outlined,
      ),
      ('Total', moneyFormatter(totals.totalAmount), Icons.summarize_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = math.max((constraints.maxWidth - 8) / 2, 0.0);
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, value, icon) in cards)
              SizedBox(
                width: itemWidth,
                child: _ProviderMiniTotalCard(
                  label: label,
                  value: value,
                  icon: icon,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProviderMiniTotalCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProviderMiniTotalCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return FinanzasGlassPanel(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      fillColor: kFinanzasPanelSurfaceLight,
      borderColor: Colors.white.withValues(alpha: 0.10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: tokens.primaryStrong.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: tokens.primaryStrong.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(icon, size: 16, color: tokens.primaryStrong),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: kFinanzasMutedInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.05,
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

class _ProviderAccountListCard extends StatelessWidget {
  final _ProviderAccountView row;
  final bool selected;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final VoidCallback onTap;
  final Future<void> Function() onPrint;

  const _ProviderAccountListCard({
    required this.row,
    required this.selected,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onTap,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final supportingLabel = row.openInvoicesCount <= 0
        ? 'Sin facturas abiertas'
        : 'Facturas ${row.openInvoicesCount} · Próximo ${dateFormatter(row.nextPayableDate)}';
    return FinanzasGlassPanel(
      borderRadius: BorderRadius.circular(20),
      padding: EdgeInsets.zero,
      fillColor: selected
          ? tokens.primaryStrong.withValues(alpha: 0.16)
          : kFinanzasPanelSurface,
      borderColor: selected
          ? tokens.primaryStrong.withValues(alpha: 0.58)
          : Colors.white.withValues(alpha: 0.12),
      child: Material(
        color: Colors.transparent,
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
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: tokens.primaryStrong,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MovementIconAction(
                      icon: Icons.picture_as_pdf_outlined,
                      color: tokens.primaryStrong,
                      onTap: onPrint,
                    ),
                    const SizedBox(width: 10),
                    _MiniToneChip(
                      label: row.urgencyLabel,
                      tone: row.urgencyTone,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 12),
                Text(
                  'Por pagar',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: kFinanzasMutedInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  moneyFormatter(row.payableAmount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  supportingLabel,
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
  final Future<void> Function() onRegisterManualInvoice;
  final Future<void> Function() onEditProviderPriority;
  final Future<void> Function() onOpenBankAccounts;
  final Future<void> Function() onRegisterCashMovement;
  final Future<void> Function() onRegisterAgreement;
  final Future<void> Function(_ProviderAgreementView agreement) onEditAgreement;
  final Future<void> Function(_ProviderAgreementView agreement)
  onCancelAgreement;
  final Future<void> Function(
    _ProviderAgreementView agreement,
    FinanzasSupplierAgreementInstallmentRecord installment,
  )
  onToggleInstallmentPaid;
  final Future<void> Function(ComprasProviderMovementRecord movement)
  onEditCashMovement;
  final Future<void> Function(ComprasProviderMovementRecord movement)
  onDeleteCashMovement;
  final Future<void> Function(_ProviderInvoiceView invoice) onEditInvoice;
  final Future<void> Function(_ProviderInvoiceView invoice)
  onEditInvoicePriority;
  final Future<void> Function(_ProviderInvoiceView invoice)
  onOpenInvoiceEvidence;
  final Future<void> Function(ComprasTicketRecord ticket) onDeleteTicket;
  final Future<void> Function(_ProviderInvoiceView invoice) onDeleteInvoice;
  final Future<void> Function(_ProviderAccountView account) onPrintAccount;
  final Future<void> Function(_ProviderAccountView account) onPrintInvoices;
  final Future<void> Function(_ProviderAccountView account)
  onExportProviderExcelTemplate;

  const _ProviderAccountsDetailPane({
    required this.account,
    required this.activeTab,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onTabSelected,
    required this.onRegisterInvoice,
    required this.onRegisterManualInvoice,
    required this.onEditProviderPriority,
    required this.onOpenBankAccounts,
    required this.onRegisterCashMovement,
    required this.onRegisterAgreement,
    required this.onEditAgreement,
    required this.onCancelAgreement,
    required this.onToggleInstallmentPaid,
    required this.onEditCashMovement,
    required this.onDeleteCashMovement,
    required this.onEditInvoice,
    required this.onEditInvoicePriority,
    required this.onOpenInvoiceEvidence,
    required this.onDeleteTicket,
    required this.onDeleteInvoice,
    required this.onPrintAccount,
    required this.onPrintInvoices,
    required this.onExportProviderExcelTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final metrics = _computeProviderAccountMetrics(account);
    return ContractGlassCard(
      borderRadius: BorderRadius.circular(32),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
                        fontSize: 28,
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
                    if (account.company.manualPriority != 'NORMAL') ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MiniToneChip(
                            label: finManualPriorityLabel(
                              account.company.manualPriority,
                            ),
                            tone: _manualPriorityTone(
                              account.company.manualPriority,
                            ),
                          ),
                          if (account.company.priorityNote.trim().isNotEmpty)
                            _MiniToneChip(
                              label: account.company.priorityNote.trim(),
                              tone: const Color(0xFF7A1914),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              _MiniToneChip(
                label: account.urgencyLabel,
                tone: account.urgencyTone,
              ),
              const SizedBox(width: 8),
              _ActionPillButton(
                label: 'Imprimir cuenta',
                icon: Icons.picture_as_pdf_outlined,
                onTap: () => onPrintAccount(account),
              ),
              const SizedBox(width: 8),
              _MovementIconAction(
                icon: Icons.flag_outlined,
                color: _manualPriorityTone(account.company.manualPriority),
                onTap: onEditProviderPriority,
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
                value: moneyFormatter(metrics.openAmount),
                icon: Icons.account_balance_wallet_outlined,
              ),
              _SummaryMetricCard(
                label: 'Vencido',
                value: moneyFormatter(metrics.overdueAmount),
                icon: Icons.event_busy_outlined,
              ),
              _SummaryMetricCard(
                label: 'Facturado',
                value: moneyFormatter(metrics.facturadoAmount),
                icon: Icons.receipt_long_outlined,
              ),
              _SummaryMetricCard(
                label: 'Sin factura',
                value: moneyFormatter(metrics.sinFacturaAmount),
                icon: Icons.description_outlined,
              ),
              _SummaryMetricCard(
                label: 'Pend. facturar',
                value: moneyFormatter(metrics.pendienteFacturarAmount),
                icon: Icons.pending_actions_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          FinanzasGlassPanel(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            borderRadius: BorderRadius.circular(22),
            fillColor: kFinanzasPanelSurfaceSubtle,
            borderColor: kFinanzasBorder.withValues(alpha: 0.34),
            child: SingleChildScrollView(
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
                onExportProviderExcelTemplate: () =>
                    onExportProviderExcelTemplate(account),
                canExportProviderExcelTemplate: true,
                onDeleteTicket: onDeleteTicket,
              ),
              _ProviderAccountsTab.facturas => _ProviderAccountInvoicesView(
                account: account,
                moneyFormatter: moneyFormatter,
                dateFormatter: dateFormatter,
                onRegisterInvoice: onRegisterInvoice,
                onRegisterManualInvoice: onRegisterManualInvoice,
                onPrintInvoices: () => onPrintInvoices(account),
                onEditInvoice: onEditInvoice,
                onEditInvoicePriority: onEditInvoicePriority,
                onOpenInvoiceEvidence: onOpenInvoiceEvidence,
                onDeleteInvoice: onDeleteInvoice,
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
                onEditAgreement: onEditAgreement,
                onCancelAgreement: onCancelAgreement,
                onToggleInstallmentPaid: onToggleInstallmentPaid,
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
    final metrics = _computeProviderAccountMetrics(account);
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
                value: dateFormatter(metrics.nextCommitmentDate),
                subtitle: 'Calculado desde días de crédito y tickets abiertos.',
                accent: AreaThemeScope.of(context).primaryStrong,
              ),
              _LongInfoCard(
                title: 'Etapa de pago',
                value: _finPaymentStageLabel(account.company.paymentStage),
                subtitle: account.company.paymentNotes.isEmpty
                    ? 'Sin nota operativa registrada.'
                    : account.company.paymentNotes,
                accent: AreaThemeScope.of(context).primaryStrong,
              ),
              _LongInfoCard(
                title: 'Crédito proveedor',
                value: '${account.company.creditDays} días',
                subtitle:
                    'Contacto ${account.company.operationalContact.isEmpty ? 'sin capturar' : account.company.operationalContact}.',
                accent: AreaThemeScope.of(context).primaryStrong,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: kFinanzasPanelSurfaceStrong,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: tokens.primaryStrong.withValues(alpha: 0.16),
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
                  'Saldo total histórico ${moneyFormatter(metrics.totalAmount)}. Abierto ${moneyFormatter(metrics.openAmount)}. Tickets abiertos ${metrics.openTicketsCount}.',
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
  final Future<void> Function() onExportProviderExcelTemplate;
  final bool canExportProviderExcelTemplate;
  final Future<void> Function(ComprasTicketRecord ticket) onDeleteTicket;

  const _ProviderAccountTicketsView({
    required this.account,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onExportProviderExcelTemplate,
    required this.canExportProviderExcelTemplate,
    required this.onDeleteTicket,
  });

  @override
  Widget build(BuildContext context) {
    const tableWidth = 1010.0;
    if (account.tickets.isEmpty) {
      return _ProviderAccountsPendingPane(
        label: 'Sin tickets',
        subtitle: 'Este proveedor todavía no tiene tickets relacionados.',
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Selecciona la semana operativa y exporta una plantilla exacta del proveedor sin tocar el PDF general de cuenta.',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kFinanzasMutedInk,
                ),
              ),
            ),
            if (canExportProviderExcelTemplate) ...[
              const SizedBox(width: 12),
              _ActionPillButton(
                label: 'Exportar Excel proveedor',
                icon: Icons.table_view_rounded,
                onTap: onExportProviderExcelTemplate,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
                  _TicketHeaderCell(width: 60, label: ''),
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
              final resolved = _resolveProviderTicketStatus(account, row);
              return FinanzasGlassPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                borderRadius: BorderRadius.circular(20),
                fillColor: kFinanzasPanelSurfaceStrong.withValues(alpha: 0.92),
                borderColor: kFinanzasBorder.withValues(alpha: 0.30),
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
                          label: comprasPagoStatusLabel(resolved.pagoStatus),
                          tone: _pagoTone(resolved.pagoStatus),
                        ),
                        _TicketBadgeCell(
                          width: 130,
                          label: comprasCoverageStatusLabel(
                            resolved.coverageStatus,
                          ),
                          tone: _coverageTone(resolved.coverageStatus),
                        ),
                        SizedBox(
                          width: 60,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _MovementIconAction(
                              icon: Icons.delete_outline_rounded,
                              color: const Color(0xFFEA6B5F),
                              onTap: () => onDeleteTicket(row),
                            ),
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
      ],
    );
  }
}

class _ProviderExcelTicketSelectionDialog extends StatefulWidget {
  final String providerName;
  final List<ComprasTicketRecord> tickets;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final FinanzasProviderExcelTemplateKind kind;

  const _ProviderExcelTicketSelectionDialog({
    required this.providerName,
    required this.tickets,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.kind,
  });

  @override
  State<_ProviderExcelTicketSelectionDialog> createState() =>
      _ProviderExcelTicketSelectionDialogState();
}

class _ProviderExcelTicketSelectionDialogState
    extends State<_ProviderExcelTicketSelectionDialog> {
  late final List<ComprasTicketRecord> _tickets;
  final Set<String> _selectedIds = <String>{};
  late final TextEditingController _ticketNumberFilterC;
  final ScrollController _rowsScrollController = ScrollController();
  final GlobalKey _rowsViewportKey = GlobalKey();
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  DateTimeRange? _ticketDateRangeFilter;
  bool _dragSelectionActive = false;
  String? _dragSelectionAnchorId;
  Offset? _dragStartGlobal;
  Offset? _dragPointerGlobal;
  double _dragAutoScrollVelocity = 0;
  Timer? _dragAutoScrollTimer;

  @override
  void initState() {
    super.initState();
    _ticketNumberFilterC = TextEditingController();
    _tickets = widget.tickets.toList(growable: false)
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.ticket.compareTo(b.ticket);
      });
  }

  @override
  void dispose() {
    _dragAutoScrollTimer?.cancel();
    _rowsScrollController.dispose();
    _ticketNumberFilterC.dispose();
    super.dispose();
  }

  List<ComprasTicketRecord> get _filteredTickets {
    final ticketQuery = _ticketNumberFilterC.text.trim().toLowerCase();
    return _tickets
        .where((ticket) {
          if (ticketQuery.isNotEmpty &&
              !ticket.ticket.toLowerCase().contains(ticketQuery)) {
            return false;
          }
          final ticketDay = DateUtils.dateOnly(ticket.date);
          if (_ticketDateRangeFilter != null &&
              (ticketDay.isBefore(
                    DateUtils.dateOnly(_ticketDateRangeFilter!.start),
                  ) ||
                  ticketDay.isAfter(
                    DateUtils.dateOnly(_ticketDateRangeFilter!.end),
                  ))) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  String _dateRangeLabel(DateTimeRange? value) {
    if (value == null) return 'Todas las fechas';
    return '${widget.dateFormatter(value.start)} - ${widget.dateFormatter(value.end)}';
  }

  Future<void> _pickTicketDateRange() async {
    final picked = await _showProviderDateRangeDialog(
      context,
      title: 'Filtrar fecha',
      initialRange: _ticketDateRangeFilter,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _ticketDateRangeFilter = picked == _kClearedProviderDateRange
          ? null
          : picked;
    });
  }

  GlobalKey _rowItemKey(String rowId) => _rowKeys.putIfAbsent(
    rowId,
    () => GlobalObjectKey('provider-excel-$rowId'),
  );

  void _beginDragSelection(String ticketId, List<ComprasTicketRecord> rows) {
    setState(() {
      _dragSelectionAnchorId = ticketId;
      _dragStartGlobal = null;
    });
  }

  void _activateDragSelection() {
    if (_dragSelectionActive || _dragSelectionAnchorId == null) return;
    _dragSelectionActive = true;
    _selectedIds
      ..clear()
      ..add(_dragSelectionAnchorId!);
  }

  void _updateDragSelection(String ticketId, List<ComprasTicketRecord> rows) {
    if (!_dragSelectionActive || _dragSelectionAnchorId == null) return;
    final visibleIds = rows.map((row) => row.id).toList(growable: false);
    final start = visibleIds.indexOf(_dragSelectionAnchorId!);
    final end = visibleIds.indexOf(ticketId);
    if (start == -1 || end == -1) return;
    final range = visibleIds.sublist(
      start < end ? start : end,
      start < end ? end + 1 : start + 1,
    );
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(range);
    });
  }

  void _endDragSelection() {
    if (!_dragSelectionActive &&
        _dragSelectionAnchorId == null &&
        _dragStartGlobal == null) {
      return;
    }
    setState(() {
      _dragSelectionActive = false;
      _dragSelectionAnchorId = null;
      _dragStartGlobal = null;
      _dragPointerGlobal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
    });
  }

  int? _visibleRowIndexAtGlobalPosition(
    Offset globalPosition,
    List<ComprasTicketRecord> rows,
  ) {
    for (var i = 0; i < rows.length; i++) {
      final box =
          _rowItemKey(rows[i].id).currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(globalPosition)) return i;
    }
    return null;
  }

  int? _mountedEdgeRowIndex(
    List<ComprasTicketRecord> rows, {
    required bool last,
  }) {
    final indexes = <int>[];
    for (var i = 0; i < rows.length; i++) {
      final box =
          _rowItemKey(rows[i].id).currentContext?.findRenderObject()
              as RenderBox?;
      if (box != null && box.hasSize) indexes.add(i);
    }
    if (indexes.isEmpty) return null;
    return last ? indexes.last : indexes.first;
  }

  void _handleRowsPointerMove(
    PointerMoveEvent event,
    List<ComprasTicketRecord> rows,
  ) {
    if (_dragSelectionAnchorId == null) return;
    _dragStartGlobal ??= event.position;
    if (!_dragSelectionActive) {
      final delta = (event.position - _dragStartGlobal!).distance;
      if (delta < 6) return;
      setState(_activateDragSelection);
    }
    _dragPointerGlobal = event.position;
    _updateDragAutoScroll(rows);
    final visibleIndex = _visibleRowIndexAtGlobalPosition(event.position, rows);
    if (visibleIndex == null) return;
    _updateDragSelection(rows[visibleIndex].id, rows);
  }

  void _updateDragAutoScroll(List<ComprasTicketRecord> rows) {
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
      (_) => _performDragAutoScroll(rows),
    );
  }

  void _performDragAutoScroll(List<ComprasTicketRecord> rows) {
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
    final visibleIndex = _visibleRowIndexAtGlobalPosition(pointer, rows);
    int? targetIndex = visibleIndex;
    if (targetIndex == null) {
      final local = viewportBox.globalToLocal(pointer);
      if (local.dy < 0) {
        targetIndex = _mountedEdgeRowIndex(rows, last: false);
      } else if (local.dy > viewportBox.size.height) {
        targetIndex = _mountedEdgeRowIndex(rows, last: true);
      }
    }
    if (targetIndex == null) return;
    _updateDragSelection(rows[targetIndex].id, rows);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: Builder(
          builder: (context) {
            final tokens = AreaThemeScope.of(context);
            final filteredTickets = _filteredTickets;
            final selectedTickets = _tickets
                .where((row) => _selectedIds.contains(row.id))
                .toList(growable: false);
            final rangeLabel = selectedTickets.isEmpty
                ? 'Selecciona los tickets de la semana que llenarán la plantilla.'
                : 'Semana ${_providerExcelSelectionRangeLabel(selectedTickets)}';
            return ContractGlassCard(
              borderRadius: BorderRadius.circular(30),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: SizedBox(
                width: 920,
                height: 640,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DialogHeader(
                      title: 'Exportar Excel proveedor',
                      subtitle:
                          '${widget.providerName} · $rangeLabel · ${_selectedIds.length} ticket(s) seleccionados.',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => setState(() {
                            _selectedIds
                              ..clear()
                              ..addAll(_filteredTickets.map((row) => row.id));
                          }),
                          style: contractSecondaryButtonStyle(context),
                          icon: const Icon(Icons.done_all_rounded, size: 18),
                          label: const Text('Seleccionar todos'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => setState(_selectedIds.clear),
                          style: contractGhostButtonStyle(context),
                          icon: const Icon(
                            Icons.layers_clear_rounded,
                            size: 18,
                          ),
                          label: const Text('Limpiar selección'),
                        ),
                        const Spacer(),
                        FinanzasGlassPanel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          fillColor: kFinanzasPanelSurfaceLight,
                          borderColor: Colors.white.withValues(alpha: 0.10),
                          child: Text(
                            widget.kind ==
                                    FinanzasProviderExcelTemplateKind.avon
                                ? 'Avon soporta hasta 50 tickets por exportación.'
                                : 'La plantilla genérica soporta hasta 12 materiales y 20 tickets por material.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: tokens.onGlass.withValues(alpha: 0.74),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ticketNumberFilterC,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            cursorColor: finanzasAreaTokens.primaryStrong,
                            decoration: contractGlassFieldDecoration(
                              context,
                              hintText: 'Filtrar por número de ticket',
                              prefixIcon: const Icon(Icons.tag_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateFieldButton(
                            label: 'Rango de fechas',
                            value: _dateRangeLabel(_ticketDateRangeFilter),
                            onTap: _pickTicketDateRange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          style: contractSecondaryButtonStyle(context),
                          onPressed: () {
                            setState(() {
                              _ticketNumberFilterC.clear();
                              _ticketDateRangeFilter = null;
                            });
                          },
                          child: const Text('Limpiar filtros'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Listener(
                        onPointerMove: (event) =>
                            _handleRowsPointerMove(event, filteredTickets),
                        onPointerUp: (_) => _endDragSelection(),
                        onPointerCancel: (_) => _endDragSelection(),
                        child: Container(
                          key: _rowsViewportKey,
                          child: ListView.separated(
                            controller: _rowsScrollController,
                            itemCount: filteredTickets.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final row = filteredTickets[index];
                              final selected = _selectedIds.contains(row.id);
                              return KeyedSubtree(
                                key: _rowItemKey(row.id),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter: (_) => _updateDragSelection(
                                    row.id,
                                    filteredTickets,
                                  ),
                                  child: Listener(
                                    onPointerDown: (event) {
                                      if (event.kind ==
                                              PointerDeviceKind.mouse &&
                                          event.buttons ==
                                              kPrimaryMouseButton) {
                                        _beginDragSelection(
                                          row.id,
                                          filteredTickets,
                                        );
                                      }
                                    },
                                    child: GestureDetector(
                                      onTap: () => setState(() {
                                        if (selected) {
                                          _selectedIds.remove(row.id);
                                        } else {
                                          _selectedIds.add(row.id);
                                        }
                                      }),
                                      child: FinanzasGlassPanel(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          14,
                                          16,
                                          14,
                                        ),
                                        borderRadius: BorderRadius.circular(22),
                                        fillColor: selected
                                            ? kFinanzasSelectionFill
                                            : kFinanzasPanelSurface,
                                        borderColor: selected
                                            ? kFinanzasAmber
                                            : Colors.white.withValues(
                                                alpha: 0.12,
                                              ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              selected
                                                  ? Icons.check_circle_rounded
                                                  : Icons.circle_outlined,
                                              color: selected
                                                  ? Colors.white
                                                  : Colors.white.withValues(
                                                      alpha: 0.74,
                                                    ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${widget.dateFormatter(row.date)} · Ticket ${row.ticket}',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    row.materialNameSnapshot,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: selected
                                                          ? Colors.white
                                                                .withValues(
                                                                  alpha: 0.94,
                                                                )
                                                          : kFinanzasMutedInk,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            SizedBox(
                                              width: 130,
                                              child: Text(
                                                '${row.payableWeight.toStringAsFixed(0)} kg',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            SizedBox(
                                              width: 120,
                                              child: Text(
                                                widget.moneyFormatter(
                                                  row.amount,
                                                ),
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
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
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DialogActionsRow(
                      onCancel: () => Navigator.of(context).pop(),
                      confirmLabel: 'Generar Excel',
                      confirmIcon: Icons.table_view_rounded,
                      onConfirm:
                          _selectedIds.isEmpty ||
                              (widget.kind ==
                                      FinanzasProviderExcelTemplateKind.avon &&
                                  _selectedIds.length > 50)
                          ? null
                          : () {
                              Navigator.of(context).pop(
                                _tickets
                                    .where(
                                      (row) => _selectedIds.contains(row.id),
                                    )
                                    .toList(growable: false),
                              );
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

String _providerExcelSelectionRangeLabel(List<ComprasTicketRecord> tickets) {
  final ordered = tickets.toList(growable: false)
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return a.ticket.compareTo(b.ticket);
    });
  final first = ordered.first.date;
  final last = ordered.last.date;
  return '${_dateLabelStatic(first)} - ${_dateLabelStatic(last)}';
}

class _ProviderAccountInvoicesView extends StatelessWidget {
  final _ProviderAccountView account;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final Future<void> Function() onRegisterInvoice;
  final Future<void> Function() onRegisterManualInvoice;
  final Future<void> Function() onPrintInvoices;
  final Future<void> Function(_ProviderInvoiceView invoice) onEditInvoice;
  final Future<void> Function(_ProviderInvoiceView invoice)
  onEditInvoicePriority;
  final Future<void> Function(_ProviderInvoiceView invoice)
  onOpenInvoiceEvidence;
  final Future<void> Function(_ProviderInvoiceView invoice) onDeleteInvoice;

  const _ProviderAccountInvoicesView({
    required this.account,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onRegisterInvoice,
    required this.onRegisterManualInvoice,
    required this.onPrintInvoices,
    required this.onEditInvoice,
    required this.onEditInvoicePriority,
    required this.onOpenInvoiceEvidence,
    required this.onDeleteInvoice,
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
                'Registra facturas desde tickets o manuales sin salir del expediente del proveedor.',
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
            const SizedBox(width: 10),
            _ActionPillButton(
              label: 'Factura manual',
              icon: Icons.post_add_rounded,
              onTap: onRegisterManualInvoice,
            ),
            const SizedBox(width: 10),
            _ActionPillButton(
              label: 'Imprimir facturas',
              icon: Icons.picture_as_pdf_outlined,
              onTap: onPrintInvoices,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (account.invoices.isEmpty)
          Expanded(
            child: _ProviderAccountsPendingPane(
              label: 'Sin facturas registradas',
              subtitle: eligibleCount > 0
                  ? 'Este proveedor tiene tickets pendientes de facturar. También puedes registrar una factura manual si no proviene de compras.'
                  : 'Todavía no hay facturas relacionadas para este proveedor. Puedes registrar una factura manual desde aquí.',
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: account.invoices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final row = account.invoices[index];
                return FinanzasGlassPanel(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  borderRadius: BorderRadius.circular(22),
                  fillColor: kFinanzasPanelSurfaceStrong.withValues(
                    alpha: 0.92,
                  ),
                  borderColor: kFinanzasBorder.withValues(alpha: 0.30),
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
                          if (row.invoice.manualPriority != 'NORMAL') ...[
                            _MiniToneChip(
                              label: finManualPriorityLabel(
                                row.invoice.manualPriority,
                              ),
                              tone: _manualPriorityTone(
                                row.invoice.manualPriority,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (_canEditSupplierInvoice(row) ||
                              _canEditSupplierInvoiceFolioOnly(row)) ...[
                            _MovementIconAction(
                              icon: Icons.edit_outlined,
                              color: tokens.primaryStrong,
                              onTap: () => onEditInvoice(row),
                            ),
                            const SizedBox(width: 8),
                          ],
                          _MovementIconAction(
                            icon: Icons.flag_outlined,
                            color: _manualPriorityTone(
                              row.invoice.manualPriority,
                            ),
                            onTap: () => onEditInvoicePriority(row),
                          ),
                          const SizedBox(width: 8),
                          _MovementIconAction(
                            icon: Icons.delete_outline_rounded,
                            color: const Color(0xFFEA6B5F),
                            onTap: () => onDeleteInvoice(row),
                          ),
                          const SizedBox(width: 8),
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
                          _CompactSummaryPill(
                            label: 'Empresa objetivo',
                            value: row.invoice.targetCompany,
                          ),
                          _CompactSummaryPill(
                            label: 'Cuenta objetivo',
                            value: row.invoice.targetBranch == 'MAZATLAN'
                                ? 'Mazatlan'
                                : 'Celaya',
                          ),
                          _CompactSummaryPill(
                            label: 'Total',
                            value: moneyFormatter(row.invoice.totalAmount),
                          ),
                          _CompactSummaryPill(
                            label: 'Saldo',
                            value: moneyFormatter(row.invoice.balanceAmount),
                          ),
                          _CompactSummaryPill(
                            label: 'Origen',
                            value: finSupplierInvoiceOriginLabel(
                              row.invoice.originType,
                            ),
                          ),
                          _CompactSummaryPill(
                            label: 'Tickets',
                            value: row.invoice.originType == 'MANUAL'
                                ? 'Manual'
                                : row.tickets.isEmpty
                                ? 'Sin relación'
                                : '${row.tickets.length}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _ActionPillButton(
                            label: 'Evidencias ${row.evidences.length}',
                            icon: Icons.attach_file_rounded,
                            onTap: () => onOpenInvoiceEvidence(row),
                          ),
                        ],
                      ),
                      if (row.bankMovement != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: tokens.primaryStrong.withValues(
                                alpha: 0.16,
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
                        if (row.bankMovement!.company !=
                                row.invoice.targetCompany ||
                            row.bankMovement!.branch !=
                                row.invoice.targetBranch) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF8B5E00,
                              ).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(
                                  0xFF8B5E00,
                                ).withValues(alpha: 0.22),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.compare_arrows_rounded,
                                  size: 18,
                                  color: Color(0xFF8B5E00),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Objetivo: ${row.invoice.targetCompany} ${row.invoice.targetBranch == 'MAZATLAN' ? 'Mazatlan' : 'Celaya'} · Ejecución real: ${row.bankMovement!.company} ${row.bankMovement!.branch == 'MAZATLAN' ? 'Mazatlan' : 'Celaya'}',
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
                      if (row.invoice.priorityNote.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: _manualPriorityTone(
                              row.invoice.manualPriority,
                            ).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _manualPriorityTone(
                                row.invoice.manualPriority,
                              ).withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.flag_outlined,
                                size: 16,
                                color: _manualPriorityTone(
                                  row.invoice.manualPriority,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  row.invoice.priorityNote.trim(),
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
          spacing: 8,
          runSpacing: 8,
          children: [
            _CompactSummaryPill(label: 'Movimientos', value: '$totalItems'),
            _CompactSummaryPill(
              label: 'Abonos',
              value: moneyFormatter(totalCredit),
            ),
            _CompactSummaryPill(
              label: 'Cargos',
              value: moneyFormatter(totalDebit),
            ),
            _CompactSummaryPill(label: 'Neto', value: moneyFormatter(net)),
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
  final Future<void> Function(_ProviderAgreementView agreement) onEditAgreement;
  final Future<void> Function(_ProviderAgreementView agreement)
  onCancelAgreement;
  final Future<void> Function(
    _ProviderAgreementView agreement,
    FinanzasSupplierAgreementInstallmentRecord installment,
  )
  onToggleInstallmentPaid;

  const _ProviderAccountAgreementsView({
    required this.account,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onRegisterAgreement,
    required this.onEditAgreement,
    required this.onCancelAgreement,
    required this.onToggleInstallmentPaid,
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
          spacing: 8,
          runSpacing: 8,
          children: [
            _CompactSummaryPill(label: 'Convenios', value: '$totalItems'),
            _CompactSummaryPill(
              label: 'Comprometido',
              value: moneyFormatter(totalCommitted),
            ),
            _CompactSummaryPill(
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
                return FinanzasGlassPanel(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  borderRadius: BorderRadius.circular(22),
                  fillColor: kFinanzasPanelSurfaceStrong.withValues(
                    alpha: 0.92,
                  ),
                  borderColor: kFinanzasBorder.withValues(alpha: 0.30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${finSupplierAgreementTypeLabel(row.agreement.agreementType)} · ${finSupplierAgreementFrequencyLabel(row.agreement.frequency)} · ${dateFormatter(row.agreement.startDate)}',
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
                          const SizedBox(width: 8),
                          _MovementIconAction(
                            icon: Icons.edit_outlined,
                            color: AreaThemeScope.of(context).primaryStrong,
                            onTap: () => onEditAgreement(row),
                          ),
                          const SizedBox(width: 8),
                          _MovementIconAction(
                            icon: Icons.cancel_outlined,
                            color: kFinanzasBurnt,
                            onTap: () => onCancelAgreement(row),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _CompactSummaryPill(
                            label: 'Empresa objetivo',
                            value: row.agreement.targetCompany,
                          ),
                          _CompactSummaryPill(
                            label: 'Cuenta objetivo',
                            value: row.agreement.targetBranch == 'MAZATLAN'
                                ? 'Mazatlan'
                                : 'Celaya',
                          ),
                          if (row.agreement.agreementType == 'POR_MONTO')
                            _CompactSummaryPill(
                              label: 'Pago pactado',
                              value: moneyFormatter(
                                row.agreement.installmentAmount,
                              ),
                            )
                          else
                            _CompactSummaryPill(
                              label: 'Facturas por periodo',
                              value: '${row.agreement.invoicesPerPeriod}',
                            ),
                          _CompactSummaryPill(
                            label: row.agreement.agreementType == 'POR_MONTO'
                                ? 'Pagos'
                                : 'Compromisos',
                            value: '${row.agreement.installmentCount}',
                          ),
                          if (row.agreement.agreementType == 'POR_FACTURAS')
                            _CompactSummaryPill(
                              label: 'Facturas ligadas',
                              value: '${row.agreement.scheduledInvoiceCount}',
                            ),
                          _CompactSummaryPill(
                            label: 'Total',
                            value: moneyFormatter(row.agreement.totalAmount),
                          ),
                          _CompactSummaryPill(
                            label: 'Restante',
                            value: moneyFormatter(
                              row.agreement.remainingAmount,
                            ),
                          ),
                          _CompactSummaryPill(
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
                              Builder(
                                builder: (context) {
                                  final installmentInvoices = row.invoiceLinks
                                      .where(
                                        (link) =>
                                            link.link.installmentId ==
                                            installment.id,
                                      )
                                      .toList(growable: false);
                                  return Container(
                                    width: 210,
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.04,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _installmentTone(
                                          installment.status,
                                        ).withValues(alpha: 0.18),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row.agreement.agreementType ==
                                                  'POR_FACTURAS'
                                              ? 'Compromiso ${installment.sequenceNumber}'
                                              : 'Pago ${installment.sequenceNumber}',
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
                                        if (installmentInvoices.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            installmentInvoices
                                                .map((row) => row.invoice.folio)
                                                .join(' · '),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: kFinanzasMutedInk,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        _MiniToneChip(
                                          label: _installmentStatusLabel(
                                            installment.status,
                                          ),
                                          tone: _installmentTone(
                                            installment.status,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _MovementIconAction(
                                          icon: installment.status == 'PAGADO'
                                              ? Icons.undo_rounded
                                              : Icons
                                                    .check_circle_outline_rounded,
                                          color: installment.status == 'PAGADO'
                                              ? kFinanzasBronze
                                              : kFinanzasSage,
                                          onTap: () => onToggleInstallmentPaid(
                                            row,
                                            installment,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
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
    final tone = row.creditAmount > 0 ? kFinanzasSage : kFinanzasBurnt;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: kFinanzasPanelSurfaceStrong,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
    final tone = positive ? kFinanzasSage : kFinanzasBurnt;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: kFinanzasPanelSurfaceStrong,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
                color: kFinanzasBurnt,
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
  final String agreementType;
  final String frequency;
  final String targetCompany;
  final String targetBranch;
  final double installmentAmount;
  final int installmentCount;
  final int invoicesPerPeriod;
  final List<String> selectedInvoiceIds;
  final String notes;

  const _AgreementDraftResult({
    required this.startDate,
    required this.agreementType,
    required this.frequency,
    required this.targetCompany,
    required this.targetBranch,
    required this.installmentAmount,
    required this.installmentCount,
    required this.invoicesPerPeriod,
    required this.selectedInvoiceIds,
    required this.notes,
  });
}

class _ManualPriorityDraft {
  final String level;
  final String note;

  const _ManualPriorityDraft({required this.level, required this.note});
}

class _ManualPriorityDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final String initialLevel;
  final String initialNote;

  const _ManualPriorityDialog({
    required this.title,
    required this.subtitle,
    required this.initialLevel,
    required this.initialNote,
  });

  @override
  State<_ManualPriorityDialog> createState() => _ManualPriorityDialogState();
}

class _ManualPriorityDialogState extends State<_ManualPriorityDialog> {
  late String _level;
  late final TextEditingController _noteC;

  @override
  void initState() {
    super.initState();
    _level = kFinManualPriorityLevels.contains(widget.initialLevel)
        ? widget.initialLevel
        : 'NORMAL';
    _noteC = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _noteC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: AreaThemeScope(
          tokens: finanzasAreaTokens,
          child: ContractGlassCard(
            borderRadius: BorderRadius.circular(34),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogHeader(title: widget.title, subtitle: widget.subtitle),
                const SizedBox(height: 18),
                Text(
                  'Prioridad manual',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: tokens.badgeText,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final level in kFinManualPriorityLevels)
                      ChoiceChip(
                        label: Text(finManualPriorityLabel(level)),
                        selected: _level == level,
                        onSelected: (_) => setState(() => _level = level),
                        selectedColor: _manualPriorityTone(
                          level,
                        ).withValues(alpha: 0.16),
                        backgroundColor: tokens.fieldSurface.withValues(
                          alpha: 0.78,
                        ),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _level == level
                              ? _manualPriorityTone(level)
                              : tokens.onGlass,
                        ),
                        side: BorderSide(
                          color: _manualPriorityTone(
                            level,
                          ).withValues(alpha: _level == level ? 0.40 : 0.14),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Nota operativa',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: tokens.badgeText,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteC,
                  style: const TextStyle(
                    color: kFinanzasInk,
                    fontWeight: FontWeight.w700,
                  ),
                  cursorColor: finanzasAreaTokens.primaryStrong,
                  maxLines: 3,
                  decoration: contractGlassFieldDecoration(
                    context,
                    hintText:
                        'Ej. proveedor presionando, surtido crítico, acuerdo verbal, etc.',
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                _DialogActionsRow(
                  onCancel: () => Navigator.of(context).pop(),
                  onConfirm: () {
                    Navigator.of(context).pop(
                      _ManualPriorityDraft(
                        level: _level,
                        note: _noteC.text.trim(),
                      ),
                    );
                  },
                  confirmLabel: 'Guardar prioridad',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgreementSaveBundle {
  final FinanzasSupplierAgreementRecord agreement;
  final List<FinanzasSupplierAgreementInstallmentRecord> installments;
  final List<FinanzasSupplierAgreementInvoiceRecord> invoiceLinks;

  const _AgreementSaveBundle({
    required this.agreement,
    required this.installments,
    required this.invoiceLinks,
  });
}

class _RegisterSupplierAgreementDialog extends StatefulWidget {
  final String providerName;
  final double suggestedBalance;
  final List<FinanzasSupplierInvoiceRecord> invoices;
  final _AgreementDraftResult? initialDraft;
  final (String, String) initialTarget;

  const _RegisterSupplierAgreementDialog({
    required this.providerName,
    required this.suggestedBalance,
    required this.invoices,
    required this.initialTarget,
    this.initialDraft,
  });

  @override
  State<_RegisterSupplierAgreementDialog> createState() =>
      _RegisterSupplierAgreementDialogState();
}

class _RegisterSupplierAgreementDialogState
    extends State<_RegisterSupplierAgreementDialog> {
  static const List<String> _targetCompanies = <String>['DICSA', 'VH'];
  static const List<String> _targetBranches = <String>['CELAYA', 'MAZATLAN'];
  late final TextEditingController _amountC;
  late final TextEditingController _countC;
  late final TextEditingController _invoicesPerPeriodC;
  late final TextEditingController _notesC;
  DateTime _startDate = DateUtils.dateOnly(DateTime.now());
  String _agreementType = 'POR_MONTO';
  String _frequency = 'SEMANAL';
  late String _targetCompany;
  late String _targetBranch;
  final Set<String> _selectedInvoiceIds = <String>{};

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    _amountC = TextEditingController(
      text: draft == null || draft.installmentAmount <= 0
          ? ''
          : draft.installmentAmount.toStringAsFixed(2),
    );
    _countC = TextEditingController(
      text: draft == null ? '4' : '${draft.installmentCount}',
    );
    _invoicesPerPeriodC = TextEditingController(
      text: draft == null ? '1' : '${draft.invoicesPerPeriod.clamp(1, 999)}',
    );
    _notesC = TextEditingController(text: draft?.notes ?? '');
    _startDate = draft?.startDate ?? DateUtils.dateOnly(DateTime.now());
    _agreementType = draft?.agreementType ?? 'POR_MONTO';
    _frequency = draft?.frequency ?? 'SEMANAL';
    _targetCompany = draft?.targetCompany ?? widget.initialTarget.$1;
    _targetBranch = draft?.targetBranch ?? widget.initialTarget.$2;
    _selectedInvoiceIds.addAll(draft?.selectedInvoiceIds ?? const <String>[]);
    _amountC.addListener(_refresh);
    _countC.addListener(_refresh);
    _invoicesPerPeriodC.addListener(_refresh);
    _notesC.addListener(_refresh);
  }

  @override
  void dispose() {
    _amountC.dispose();
    _countC.dispose();
    _invoicesPerPeriodC.dispose();
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

  int _parseInvoicesPerPeriod(String raw) {
    return int.tryParse(raw.trim()) ?? 0;
  }

  bool get _canSave {
    if (_agreementType == 'POR_FACTURAS') {
      return _selectedInvoiceIds.isNotEmpty &&
          _parseInvoicesPerPeriod(_invoicesPerPeriodC.text) > 0;
    }
    return _parseAmount(_amountC.text) > 0 && _parseCount(_countC.text) > 0;
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
      builder: (context, child) => AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: Theme(
          data: _buildFinanzasDatePickerTheme(context),
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

  Future<void> _pickAgreementType() async {
    final selected = await _showSimpleOptionsDialog(
      context: context,
      title: 'Tipo de convenio',
      options: const [
        _SimpleOption(
          id: 'POR_MONTO',
          label: 'Por monto',
          subtitle: 'Pagar una cantidad fija por periodo',
        ),
        _SimpleOption(
          id: 'POR_FACTURAS',
          label: 'Por facturas',
          subtitle: 'Pagar una o varias facturas por periodo',
        ),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() {
      _agreementType = selected.id;
      if (_agreementType == 'POR_MONTO') {
        _selectedInvoiceIds.clear();
      }
    });
  }

  Future<void> _pickFrequency() async {
    final selected = await _showSimpleOptionsDialog(
      context: context,
      title: 'Seleccionar frecuencia',
      options: const [
        _SimpleOption(id: 'SEMANAL', label: 'Semanal', subtitle: 'Cada 7 días'),
        _SimpleOption(
          id: 'QUINCENAL',
          label: 'Quincenal',
          subtitle: 'Cada 15 días',
        ),
        _SimpleOption(id: 'MENSUAL', label: 'Mensual', subtitle: 'Cada mes'),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() => _frequency = selected.id);
  }

  Future<void> _pickInvoices() async {
    final selected = await _showInvoiceSelectionDialog(
      context: context,
      invoices: widget.invoices,
      selectedIds: _selectedInvoiceIds,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedInvoiceIds
        ..clear()
        ..addAll(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedInvoices = widget.invoices
        .where((invoice) => _selectedInvoiceIds.contains(invoice.id))
        .toList(growable: false);
    final invoiceTotal = selectedInvoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.balanceAmount,
    );
    final total = _agreementType == 'POR_FACTURAS'
        ? invoiceTotal
        : _parseAmount(_amountC.text) * _parseCount(_countC.text);
    final projectedInstallments = _agreementType == 'POR_FACTURAS'
        ? (() {
            final perPeriod = _parseInvoicesPerPeriod(_invoicesPerPeriodC.text);
            if (perPeriod <= 0 || selectedInvoices.isEmpty) return 0;
            return (selectedInvoices.length / perPeriod).ceil();
          })()
        : _parseCount(_countC.text);
    final dialogMaxHeight = math
        .min(MediaQuery.sizeOf(context).height - 56, 760.0)
        .toDouble();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: Builder(
          builder: (context) => ContractGlassCard(
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 780,
                maxHeight: dialogMaxHeight,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DialogHeader(
                      title: widget.initialDraft == null
                          ? 'Nuevo convenio'
                          : 'Editar convenio',
                      subtitle:
                          '${widget.providerName} · Saldo sugerido ${_moneyStatic(widget.suggestedBalance)}',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _InlineChoiceField(
                            label: 'Tipo',
                            value: finSupplierAgreementTypeLabel(
                              _agreementType,
                            ),
                            onTap: () {
                              unawaited(_pickAgreementType());
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
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
                            value: finSupplierAgreementFrequencyLabel(
                              _frequency,
                            ),
                            onTap: () {
                              unawaited(_pickFrequency());
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
                            label: 'Empresa objetivo',
                            value: _targetCompany,
                            onTap: () async {
                              final selected = await _showSimpleOptionsDialog(
                                context: context,
                                title: 'Seleccionar empresa objetivo',
                                options: _targetCompanies
                                    .map(
                                      (row) => _SimpleOption(
                                        id: row,
                                        label: row,
                                        subtitle: 'Cuenta pagadora esperada',
                                      ),
                                    )
                                    .toList(growable: false),
                              );
                              if (selected == null || !mounted) return;
                              setState(() => _targetCompany = selected.id);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InlineChoiceField(
                            label: 'Cuenta objetivo',
                            value: _targetBranch == 'MAZATLAN'
                                ? 'Mazatlan'
                                : 'Celaya',
                            onTap: () async {
                              final selected = await _showSimpleOptionsDialog(
                                context: context,
                                title: 'Seleccionar cuenta objetivo',
                                options: _targetBranches
                                    .map(
                                      (row) => _SimpleOption(
                                        id: row,
                                        label: row == 'MAZATLAN'
                                            ? 'Mazatlan'
                                            : 'Celaya',
                                        subtitle: 'Sucursal/cuenta objetivo',
                                      ),
                                    )
                                    .toList(growable: false),
                              );
                              if (selected == null || !mounted) return;
                              setState(() => _targetBranch = selected.id);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_agreementType == 'POR_MONTO')
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _amountC,
                              style: const TextStyle(
                                color: kFinanzasInk,
                                fontWeight: FontWeight.w700,
                              ),
                              cursorColor: finanzasAreaTokens.primaryStrong,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                              style: const TextStyle(
                                color: kFinanzasInk,
                                fontWeight: FontWeight.w700,
                              ),
                              cursorColor: finanzasAreaTokens.primaryStrong,
                              keyboardType: TextInputType.number,
                              decoration: contractGlassFieldDecoration(
                                context,
                                hintText: 'Número de pagos',
                                prefixIcon: const Icon(
                                  Icons.format_list_numbered,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _InlineChoiceField(
                                  label: 'Facturas',
                                  value: _selectedInvoiceIds.isEmpty
                                      ? 'Seleccionar facturas'
                                      : '${_selectedInvoiceIds.length} seleccionadas',
                                  onTap: () {
                                    unawaited(_pickInvoices());
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _invoicesPerPeriodC,
                                  style: const TextStyle(
                                    color: kFinanzasInk,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  cursorColor: finanzasAreaTokens.primaryStrong,
                                  keyboardType: TextInputType.number,
                                  decoration: contractGlassFieldDecoration(
                                    context,
                                    hintText: 'Facturas por periodo',
                                    prefixIcon: const Icon(
                                      Icons.stacked_line_chart_outlined,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (selectedInvoices.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final invoice in selectedInvoices)
                                    _CompactInvoiceChip(
                                      label:
                                          '${invoice.folio} · ${_moneyStatic(invoice.balanceAmount)}',
                                    ),
                                ],
                              ),
                            ),
                          ],
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
                          label: _agreementType == 'POR_FACTURAS'
                              ? 'Compromisos'
                              : 'Pagos',
                          value: '$projectedInstallments',
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
                      style: const TextStyle(
                        color: kFinanzasInk,
                        fontWeight: FontWeight.w700,
                      ),
                      cursorColor: finanzasAreaTokens.primaryStrong,
                      minLines: 3,
                      maxLines: 4,
                      decoration: contractGlassFieldDecoration(
                        context,
                        hintText: 'Notas del convenio',
                        prefixIcon: const Icon(Icons.note_alt_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DialogActionsRow(
                      onCancel: () => Navigator.of(context).pop(),
                      onConfirm: !_canSave
                          ? null
                          : () {
                              Navigator.of(context).pop(
                                _AgreementDraftResult(
                                  startDate: _startDate,
                                  agreementType: _agreementType,
                                  frequency: _frequency,
                                  targetCompany: _targetCompany,
                                  targetBranch: _targetBranch,
                                  installmentAmount: _parseAmount(
                                    _amountC.text,
                                  ),
                                  installmentCount: projectedInstallments,
                                  invoicesPerPeriod: _parseInvoicesPerPeriod(
                                    _invoicesPerPeriodC.text,
                                  ),
                                  selectedInvoiceIds: _selectedInvoiceIds
                                      .toList(growable: false),
                                  notes: _notesC.text.trim(),
                                ),
                              );
                            },
                      confirmLabel: 'Guardar convenio',
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final ultraCompact = constraints.maxHeight <= 72;
        final isCompact = constraints.maxHeight <= 156;
        final horizontalCompact = constraints.maxHeight <= 120;
        final maxWidth = math.min(420.0, constraints.maxWidth);
        return Center(
          child: FinanzasGlassPanel(
            width: maxWidth,
            padding: EdgeInsets.fromLTRB(
              horizontalCompact ? 14 : 22,
              ultraCompact
                  ? 8
                  : (horizontalCompact ? 12 : (isCompact ? 16 : 22)),
              horizontalCompact ? 14 : 22,
              ultraCompact
                  ? 8
                  : (horizontalCompact ? 12 : (isCompact ? 16 : 22)),
            ),
            borderRadius: BorderRadius.circular(24),
            fillColor: kFinanzasPanelSurface,
            borderColor: kFinanzasBorder.withValues(alpha: 0.30),
            child: horizontalCompact
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.space_dashboard_outlined,
                        size: ultraCompact ? 18 : 20,
                        color: tokens.primaryStrong,
                      ),
                      SizedBox(width: ultraCompact ? 8 : 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: ultraCompact ? 14 : 15,
                                fontWeight: FontWeight.w900,
                                color: tokens.primaryStrong,
                              ),
                            ),
                            if (!ultraCompact) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: kFinanzasMutedInk,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.space_dashboard_outlined,
                        size: isCompact ? 26 : 34,
                        color: tokens.primaryStrong,
                      ),
                      SizedBox(height: isCompact ? 8 : 12),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isCompact ? 16 : 18,
                          fontWeight: FontWeight.w900,
                          color: tokens.primaryStrong,
                        ),
                      ),
                      SizedBox(height: isCompact ? 4 : 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        maxLines: isCompact ? 2 : null,
                        overflow: isCompact
                            ? TextOverflow.ellipsis
                            : TextOverflow.visible,
                        style: TextStyle(
                          fontSize: isCompact ? 13 : 14,
                          fontWeight: FontWeight.w700,
                          color: kFinanzasMutedInk,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
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
  final IconData icon;

  const _SummaryMetricCard({
    required this.label,
    required this.value,
    this.icon = Icons.insert_chart_outlined_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return FinanzasSummaryMetricCard(
      width: 168,
      label: label,
      value: value,
      icon: icon,
      valueFontSize: 17,
    );
  }
}

class _DialogHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final BuildContext? popContext;

  const _DialogHeader({required this.title, this.subtitle, this.popContext});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final navigatorContext = popContext ?? context;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kFinanzasMutedInk,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        FinanzasGlassPanel(
          width: 52,
          height: 52,
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(999),
          fillColor: kFinanzasPanelSurfaceSubtle,
          borderColor: kFinanzasBorder.withValues(alpha: 0.32),
          child: Center(
            child: IconButton(
              onPressed: () => Navigator.of(navigatorContext).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 52, height: 52),
              iconSize: 28,
              alignment: Alignment.center,
              splashRadius: 22,
              icon: Icon(
                Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogActionsRow extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;
  final String confirmLabel;
  final IconData? confirmIcon;

  const _DialogActionsRow({
    required this.onCancel,
    required this.confirmLabel,
    this.onConfirm,
    this.confirmIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          style: contractSecondaryButtonStyle(context),
          onPressed: onCancel,
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          style: contractPrimaryButtonStyle(context),
          onPressed: onConfirm,
          icon: Icon(confirmIcon ?? Icons.save_outlined),
          label: Text(confirmLabel),
        ),
      ],
    );
  }
}

class _CompactSummaryPill extends StatelessWidget {
  final String label;
  final String value;

  const _CompactSummaryPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return FinanzasGlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      borderRadius: BorderRadius.circular(16),
      fillColor: kFinanzasPanelSurfaceStrong.withValues(alpha: 0.92),
      borderColor: kFinanzasBorder.withValues(alpha: 0.30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: kFinanzasMutedInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
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
  final Color accent;

  const _LongInfoCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return FinanzasGlassPanel(
      width: 260,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      borderRadius: BorderRadius.circular(22),
      fillColor: kFinanzasPanelSurfaceStrong.withValues(alpha: 0.92),
      borderColor: accent.withValues(alpha: 0.30),
      glowColor: accent.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: kFinanzasInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: accent,
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
    final gradient = active
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kFinanzasOrange, kFinanzasOrangeIntense],
          )
        : null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            gradient: gradient,
            color: active
                ? null
                : kFinanzasPanelSurfaceStrong.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? kFinanzasBorderActive
                  : kFinanzasBorder.withValues(alpha: 0.34),
            ),
            boxShadow: [
              if (active)
                BoxShadow(
                  blurRadius: 24,
                  spreadRadius: 1,
                  color: kFinanzasGlowStrong.withValues(alpha: 0.42),
                ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: active ? Colors.white : kFinanzasInk,
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
      return kFinanzasSage;
    case 'PENDIENTE_DE_FACTURAR':
      return kFinanzasBronze;
    default:
      return kFinanzasTaupe;
  }
}

Color _pagoTone(String status) {
  switch (status) {
    case 'PAGADO':
      return kFinanzasSage;
    case 'ABONO':
      return kFinanzasAmber;
    default:
      return kFinanzasBurnt;
  }
}

Color _coverageTone(String status) {
  switch (status) {
    case 'CUBIERTO':
      return kFinanzasSage;
    case 'PARCIAL':
      return kFinanzasAmber;
    default:
      return kFinanzasBronze;
  }
}

Color _invoiceTone(String status) {
  switch (status) {
    case 'PAGADA':
      return kFinanzasSage;
    case 'PARCIAL':
      return kFinanzasAmber;
    case 'VENCIDA':
      return kFinanzasBurnt;
    case 'CONVENIO':
      return kFinanzasTaupe;
    default:
      return kFinanzasBronze;
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
      return kFinanzasSage;
    case 'ATRASADO':
      return kFinanzasBurnt;
    case 'CANCELADO':
      return kFinanzasTaupe;
    default:
      return kFinanzasBronze;
  }
}

Color _installmentTone(String status) {
  switch (status) {
    case 'PAGADO':
      return kFinanzasSage;
    case 'VENCIDO':
      return kFinanzasBurnt;
    default:
      return kFinanzasAmber;
  }
}

Color _manualPriorityTone(String level) {
  switch (level) {
    case 'CRITICA':
      return kFinanzasBurnt;
    case 'ALTA':
      return kFinanzasBronze;
    default:
      return kFinanzasTaupe;
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

String _dateLabelStatic(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

final DateTimeRange _kClearedProviderDateRange = DateTimeRange(
  start: DateTime(1900),
  end: DateTime(1900),
);

Future<DateTimeRange?> _showProviderDateRangeDialog(
  BuildContext context, {
  required String title,
  DateTimeRange? initialRange,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDialog<DateTimeRange?>(
    context: context,
    barrierColor: kFinanzasBgDeep.withValues(alpha: 0.72),
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
                                '${_providerMonthNameEs(monthFirst.month)} ${monthFirst.year}',
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
                            : '${_dateLabelStatic(start!)} - ${_dateLabelStatic(end!)}',
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
                            ).pop(_kClearedProviderDateRange),
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

String _providerMonthNameEs(int month) {
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
  return names[(month - 1).clamp(0, 11)];
}

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

ThemeData _buildFinanzasDatePickerTheme(BuildContext context) {
  return Theme.of(context).copyWith(
    colorScheme: ColorScheme.dark(
      primary: finanzasAreaTokens.primaryStrong,
      onPrimary: Colors.white,
      surface: kFinanzasDialogSurface,
      onSurface: kFinanzasInk,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: kFinanzasDialogSurface),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: kFinanzasDialogSurface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: kFinanzasDialogSurface,
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
  );
}

class _CompactInvoiceChip extends StatelessWidget {
  final String label;

  const _CompactInvoiceChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AreaThemeScope.of(context).fieldSurface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AreaThemeScope.of(context).primaryStrong,
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
                child: ContractGlassCard(
                  borderRadius: BorderRadius.circular(28),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 560,
                      maxHeight: 640,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DialogHeader(title: title, popContext: context),
                        const SizedBox(height: 12),
                        TextField(
                          controller: searchC,
                          autofocus: true,
                          onChanged: (_) => setLocalState(() {
                            highlightedIndex = -1;
                          }),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          cursorColor: finanzasAreaTokens.primaryStrong,
                          decoration:
                              contractGlassFieldDecoration(
                                dialogContext,
                                hintText: 'Buscar opción',
                                prefixIcon: const Icon(Icons.search_rounded),
                              ).copyWith(
                                hintStyle: const TextStyle(
                                  color: Color(0xB3FFFFFF),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
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
                                child: _ProviderPickerOptionTile(
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

Future<List<String>?> _showInvoiceSelectionDialog({
  required BuildContext context,
  required List<FinanzasSupplierInvoiceRecord> invoices,
  required Set<String> selectedIds,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _SelectAgreementInvoicesDialog(
      invoices: invoices,
      initialSelectedIds: selectedIds.toList(growable: false),
    ),
  );
}

class _SelectAgreementInvoicesDialog extends StatefulWidget {
  final List<FinanzasSupplierInvoiceRecord> invoices;
  final List<String> initialSelectedIds;

  const _SelectAgreementInvoicesDialog({
    required this.invoices,
    required this.initialSelectedIds,
  });

  @override
  State<_SelectAgreementInvoicesDialog> createState() =>
      _SelectAgreementInvoicesDialogState();
}

class _SelectAgreementInvoicesDialogState
    extends State<_SelectAgreementInvoicesDialog> {
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initialSelectedIds.toSet();
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
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogHeader(
                  title: 'Seleccionar facturas',
                  subtitle:
                      'Elige las facturas que entran al convenio y luego define cuántas van por periodo.',
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: widget.invoices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final invoice = widget.invoices[index];
                      final selected = _selectedIds.contains(invoice.id);
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedIds.remove(invoice.id);
                            } else {
                              _selectedIds.add(invoice.id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                            color: finanzasAreaTokens.fieldSurface.withValues(
                              alpha: selected ? 0.96 : 0.82,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected
                                  ? finanzasAreaTokens.primaryStrong
                                  : Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                color: selected
                                    ? finanzasAreaTokens.primaryStrong
                                    : kFinanzasMutedInk,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      invoice.folio,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: finanzasAreaTokens.primaryStrong,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_dateLabelStatic(invoice.invoiceDate)} · ${_moneyStatic(invoice.balanceAmount)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: kFinanzasMutedInk,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _DialogActionsRow(
                  onCancel: () => Navigator.of(context).pop(),
                  onConfirm: () => Navigator.of(
                    context,
                  ).pop(_selectedIds.toList(growable: false)),
                  confirmLabel: 'Usar selección',
                  confirmIcon: Icons.check_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
            data: _buildFinanzasDatePickerTheme(context),
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
    final isEditing = widget.initialMovement != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: Builder(
          builder: (context) => ContractGlassCard(
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DialogHeader(
                    title: isEditing ? 'Editar movimiento' : 'Registrar abono',
                    subtitle: isEditing
                        ? '${widget.providerName} · Al guardar se recalculará la aplicación del movimiento en tickets abiertos.'
                        : '${widget.providerName} · Se aplicará por antigüedad al saldo abierto del proveedor.',
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
                          style: const TextStyle(
                            color: kFinanzasInk,
                            fontWeight: FontWeight.w700,
                          ),
                          cursorColor: finanzasAreaTokens.primaryStrong,
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
                          style: const TextStyle(
                            color: kFinanzasInk,
                            fontWeight: FontWeight.w700,
                          ),
                          cursorColor: finanzasAreaTokens.primaryStrong,
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
                    style: const TextStyle(
                      color: kFinanzasInk,
                      fontWeight: FontWeight.w700,
                    ),
                    cursorColor: finanzasAreaTokens.primaryStrong,
                    minLines: 3,
                    maxLines: 4,
                    decoration: contractGlassFieldDecoration(
                      context,
                      hintText: 'Notas del movimiento',
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DialogActionsRow(
                    onCancel: () => Navigator.of(context).pop(),
                    onConfirm: !_canSave
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
                    confirmLabel: isEditing
                        ? 'Guardar cambios'
                        : 'Guardar movimiento',
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
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: tokens.fieldSurface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
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

class _InvoiceDraftResult {
  final String folio;
  final String originType;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final String targetCompany;
  final String targetBranch;
  final double? manualAmount;
  final String notes;
  final Set<String> selectedTicketIds;

  const _InvoiceDraftResult({
    required this.folio,
    required this.originType,
    required this.invoiceDate,
    required this.dueDate,
    required this.targetCompany,
    required this.targetBranch,
    required this.manualAmount,
    required this.notes,
    required this.selectedTicketIds,
  });
}

class _EditSupplierInvoiceFolioDialog extends StatefulWidget {
  final String companyName;
  final String currentFolio;
  final String title;
  final String subtitle;

  const _EditSupplierInvoiceFolioDialog({
    required this.companyName,
    required this.currentFolio,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_EditSupplierInvoiceFolioDialog> createState() =>
      _EditSupplierInvoiceFolioDialogState();
}

class _EditSupplierInvoiceFolioDialogState
    extends State<_EditSupplierInvoiceFolioDialog> {
  late final TextEditingController _folioC;

  @override
  void initState() {
    super.initState();
    _folioC = TextEditingController(text: widget.currentFolio);
  }

  @override
  void dispose() {
    _folioC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _folioC.text.trim().isNotEmpty;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: Builder(
          builder: (context) => ContractGlassCard(
            borderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DialogHeader(
                    title: widget.title,
                    subtitle: '${widget.companyName} · ${widget.subtitle}',
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _folioC,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    cursorColor: finanzasAreaTokens.primaryStrong,
                    decoration: contractGlassFieldDecoration(
                      context,
                      hintText: 'Número de factura',
                      prefixIcon: const Icon(Icons.receipt_long_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Este cambio no modifica saldo, pagos, tickets, cobertura ni vínculos operativos. Solo sincroniza el folio con la referencia del movimiento bancario ligado.',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kFinanzasMutedInk,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _DialogActionsRow(
                    onCancel: () => Navigator.of(context).pop(),
                    onConfirm: !canSave
                        ? null
                        : () => Navigator.of(context).pop(_folioC.text.trim()),
                    confirmLabel: 'Guardar número',
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

class _RegisterSupplierInvoiceDialog extends StatefulWidget {
  final String companyName;
  final List<ComprasTicketRecord> tickets;
  final (String, String) initialTarget;
  final _InvoiceDraftResult? initialDraft;
  final String title;
  final String confirmLabel;

  const _RegisterSupplierInvoiceDialog({
    required this.companyName,
    required this.tickets,
    required this.initialTarget,
    this.initialDraft,
    this.title = 'Registrar factura',
    this.confirmLabel = 'Guardar factura',
  });

  @override
  State<_RegisterSupplierInvoiceDialog> createState() =>
      _RegisterSupplierInvoiceDialogState();
}

class _RegisterSupplierInvoiceDialogState
    extends State<_RegisterSupplierInvoiceDialog> {
  static const List<String> _targetCompanies = <String>['DICSA', 'VH'];
  static const List<String> _targetBranches = <String>['CELAYA', 'MAZATLAN'];
  late final TextEditingController _folioC;
  late final TextEditingController _notesC;
  late final TextEditingController _ticketNumberFilterC;
  final ScrollController _rowsScrollController = ScrollController();
  final GlobalKey _rowsViewportKey = GlobalKey();
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  late DateTime _invoiceDate;
  DateTime? _dueDate;
  late Set<String> _selectedTicketIds;
  late String _targetCompany;
  late String _targetBranch;
  DateTimeRange? _ticketDateRangeFilter;
  bool _dragSelectionActive = false;
  String? _dragSelectionAnchorId;
  Offset? _dragStartGlobal;
  Offset? _dragPointerGlobal;
  double _dragAutoScrollVelocity = 0;
  Timer? _dragAutoScrollTimer;

  @override
  void initState() {
    super.initState();
    _folioC = TextEditingController();
    _notesC = TextEditingController();
    _ticketNumberFilterC = TextEditingController();
    _invoiceDate = DateUtils.dateOnly(
      widget.initialDraft?.invoiceDate ?? DateTime.now(),
    );
    _dueDate = widget.initialDraft?.dueDate == null
        ? null
        : DateUtils.dateOnly(widget.initialDraft!.dueDate!);
    _selectedTicketIds =
        widget.initialDraft?.selectedTicketIds.toSet() ?? <String>{};
    _targetCompany =
        widget.initialDraft?.targetCompany ?? widget.initialTarget.$1;
    _targetBranch =
        widget.initialDraft?.targetBranch ?? widget.initialTarget.$2;
    _folioC.text = widget.initialDraft?.folio ?? '';
    _notesC.text = widget.initialDraft?.notes ?? '';
  }

  @override
  void dispose() {
    _dragAutoScrollTimer?.cancel();
    _rowsScrollController.dispose();
    _folioC.dispose();
    _notesC.dispose();
    _ticketNumberFilterC.dispose();
    super.dispose();
  }

  double get _selectedTotal => widget.tickets
      .where((ticket) => _selectedTicketIds.contains(ticket.id))
      .fold<double>(0, (sum, ticket) => sum + ticket.amount);

  List<ComprasTicketRecord> get _filteredTickets {
    final ticketQuery = _ticketNumberFilterC.text.trim().toLowerCase();
    return widget.tickets
        .where((ticket) {
          if (ticketQuery.isNotEmpty &&
              !ticket.ticket.toLowerCase().contains(ticketQuery)) {
            return false;
          }
          final ticketDay = DateUtils.dateOnly(ticket.date);
          if (_ticketDateRangeFilter != null &&
              (ticketDay.isBefore(
                    DateUtils.dateOnly(_ticketDateRangeFilter!.start),
                  ) ||
                  ticketDay.isAfter(
                    DateUtils.dateOnly(_ticketDateRangeFilter!.end),
                  ))) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
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
    if (value == null) return 'Sin fecha';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  Future<void> _pickInvoiceDate() async {
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
            data: _buildFinanzasDatePickerTheme(context),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _invoiceDate = DateUtils.dateOnly(picked));
  }

  Future<void> _pickDueDate() async {
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
            data: _buildFinanzasDatePickerTheme(context),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _dueDate = DateUtils.dateOnly(picked));
  }

  String _dateRangeLabel(DateTimeRange? value) {
    if (value == null) return 'Todas las fechas';
    return '${_dateLabel(value.start)} - ${_dateLabel(value.end)}';
  }

  Future<void> _pickTicketDateRange() async {
    final picked = await _showProviderDateRangeDialog(
      context,
      title: 'Filtrar fecha',
      initialRange: _ticketDateRangeFilter,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _ticketDateRangeFilter = picked == _kClearedProviderDateRange
          ? null
          : picked;
    });
  }

  GlobalKey _rowItemKey(String rowId) => _rowKeys.putIfAbsent(
    rowId,
    () => GlobalObjectKey('provider-invoice-$rowId'),
  );

  void _beginDragSelection(String ticketId, List<ComprasTicketRecord> rows) {
    setState(() {
      _dragSelectionAnchorId = ticketId;
      _dragStartGlobal = null;
    });
  }

  void _activateDragSelection() {
    if (_dragSelectionActive || _dragSelectionAnchorId == null) return;
    _dragSelectionActive = true;
    _selectedTicketIds
      ..clear()
      ..add(_dragSelectionAnchorId!);
  }

  void _updateDragSelection(String ticketId, List<ComprasTicketRecord> rows) {
    if (!_dragSelectionActive || _dragSelectionAnchorId == null) return;
    final visibleIds = rows.map((row) => row.id).toList(growable: false);
    final start = visibleIds.indexOf(_dragSelectionAnchorId!);
    final end = visibleIds.indexOf(ticketId);
    if (start == -1 || end == -1) return;
    final range = visibleIds.sublist(
      start < end ? start : end,
      start < end ? end + 1 : start + 1,
    );
    setState(() {
      _selectedTicketIds
        ..clear()
        ..addAll(range);
    });
  }

  void _endDragSelection() {
    if (!_dragSelectionActive &&
        _dragSelectionAnchorId == null &&
        _dragStartGlobal == null) {
      return;
    }
    setState(() {
      _dragSelectionActive = false;
      _dragSelectionAnchorId = null;
      _dragStartGlobal = null;
      _dragPointerGlobal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
    });
  }

  int? _visibleRowIndexAtGlobalPosition(
    Offset globalPosition,
    List<ComprasTicketRecord> rows,
  ) {
    for (var i = 0; i < rows.length; i++) {
      final box =
          _rowItemKey(rows[i].id).currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(globalPosition)) return i;
    }
    return null;
  }

  int? _mountedEdgeRowIndex(
    List<ComprasTicketRecord> rows, {
    required bool last,
  }) {
    final indexes = <int>[];
    for (var i = 0; i < rows.length; i++) {
      final box =
          _rowItemKey(rows[i].id).currentContext?.findRenderObject()
              as RenderBox?;
      if (box != null && box.hasSize) indexes.add(i);
    }
    if (indexes.isEmpty) return null;
    return last ? indexes.last : indexes.first;
  }

  void _handleRowsPointerMove(
    PointerMoveEvent event,
    List<ComprasTicketRecord> rows,
  ) {
    if (_dragSelectionAnchorId == null) return;
    _dragStartGlobal ??= event.position;
    if (!_dragSelectionActive) {
      final delta = (event.position - _dragStartGlobal!).distance;
      if (delta < 6) return;
      setState(_activateDragSelection);
    }
    _dragPointerGlobal = event.position;
    _updateDragAutoScroll(rows);
    final visibleIndex = _visibleRowIndexAtGlobalPosition(event.position, rows);
    if (visibleIndex == null) return;
    _updateDragSelection(rows[visibleIndex].id, rows);
  }

  void _updateDragAutoScroll(List<ComprasTicketRecord> rows) {
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
      (_) => _performDragAutoScroll(rows),
    );
  }

  void _performDragAutoScroll(List<ComprasTicketRecord> rows) {
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
    final visibleIndex = _visibleRowIndexAtGlobalPosition(pointer, rows);
    int? targetIndex = visibleIndex;
    if (targetIndex == null) {
      final local = viewportBox.globalToLocal(pointer);
      if (local.dy < 0) {
        targetIndex = _mountedEdgeRowIndex(rows, last: false);
      } else if (local.dy > viewportBox.size.height) {
        targetIndex = _mountedEdgeRowIndex(rows, last: true);
      }
    }
    if (targetIndex == null) return;
    _updateDragSelection(rows[targetIndex].id, rows);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final filteredTickets = _filteredTickets;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: Builder(
          builder: (context) => ContractGlassCard(
            borderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DialogHeader(
                    title: widget.title,
                    subtitle: widget.companyName,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _folioC,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            color: kFinanzasInk,
                            fontWeight: FontWeight.w700,
                          ),
                          cursorColor: finanzasAreaTokens.primaryStrong,
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
                  Row(
                    children: [
                      Expanded(
                        child: _InlineChoiceField(
                          label: 'Empresa objetivo',
                          value: _targetCompany,
                          onTap: () async {
                            final selected = await _showSimpleOptionsDialog(
                              context: context,
                              title: 'Seleccionar empresa objetivo',
                              options: _targetCompanies
                                  .map(
                                    (row) => _SimpleOption(
                                      id: row,
                                      label: row,
                                      subtitle: 'Cuenta pagadora esperada',
                                    ),
                                  )
                                  .toList(growable: false),
                            );
                            if (selected == null || !mounted) return;
                            setState(() => _targetCompany = selected.id);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InlineChoiceField(
                          label: 'Cuenta objetivo',
                          value: _targetBranch == 'MAZATLAN'
                              ? 'Mazatlan'
                              : 'Celaya',
                          onTap: () async {
                            final selected = await _showSimpleOptionsDialog(
                              context: context,
                              title: 'Seleccionar cuenta objetivo',
                              options: _targetBranches
                                  .map(
                                    (row) => _SimpleOption(
                                      id: row,
                                      label: row == 'MAZATLAN'
                                          ? 'Mazatlan'
                                          : 'Celaya',
                                      subtitle: 'Sucursal/cuenta objetivo',
                                    ),
                                  )
                                  .toList(growable: false),
                            );
                            if (selected == null || !mounted) return;
                            setState(() => _targetBranch = selected.id);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesC,
                    style: const TextStyle(
                      color: kFinanzasInk,
                      fontWeight: FontWeight.w700,
                    ),
                    cursorColor: finanzasAreaTokens.primaryStrong,
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
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ticketNumberFilterC,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          cursorColor: finanzasAreaTokens.primaryStrong,
                          decoration: contractGlassFieldDecoration(
                            context,
                            hintText: 'Filtrar por número de ticket',
                            prefixIcon: const Icon(Icons.tag_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateFieldButton(
                          label: 'Rango de fechas',
                          value: _dateRangeLabel(_ticketDateRangeFilter),
                          onTap: _pickTicketDateRange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: contractSecondaryButtonStyle(context),
                        onPressed: () {
                          setState(() {
                            _ticketNumberFilterC.clear();
                            _ticketDateRangeFilter = null;
                          });
                        },
                        child: const Text('Limpiar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Listener(
                      onPointerMove: (event) =>
                          _handleRowsPointerMove(event, filteredTickets),
                      onPointerUp: (_) => _endDragSelection(),
                      onPointerCancel: (_) => _endDragSelection(),
                      child: Container(
                        key: _rowsViewportKey,
                        child: ListView.separated(
                          controller: _rowsScrollController,
                          itemCount: filteredTickets.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final row = filteredTickets[index];
                            final selected = _selectedTicketIds.contains(
                              row.id,
                            );
                            return KeyedSubtree(
                              key: _rowItemKey(row.id),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) => _updateDragSelection(
                                  row.id,
                                  filteredTickets,
                                ),
                                child: Listener(
                                  onPointerDown: (event) {
                                    if (event.kind == PointerDeviceKind.mouse &&
                                        event.buttons == kPrimaryMouseButton) {
                                      _beginDragSelection(
                                        row.id,
                                        filteredTickets,
                                      );
                                    }
                                  },
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (selected) {
                                          _selectedTicketIds.remove(row.id);
                                        } else {
                                          _selectedTicketIds.add(row.id);
                                        }
                                      });
                                    },
                                    child: FinanzasGlassPanel(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        15,
                                        16,
                                        15,
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                      fillColor: selected
                                          ? kFinanzasSelectionFill
                                          : kFinanzasPanelSurface,
                                      borderColor: selected
                                          ? kFinanzasAmber
                                          : Colors.white.withValues(
                                              alpha: 0.12,
                                            ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            selected
                                                ? Icons.check_circle_rounded
                                                : Icons.circle_outlined,
                                            color: selected
                                                ? Colors.white
                                                : Colors.white.withValues(
                                                    alpha: 0.72,
                                                  ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${row.ticket} · ${row.materialNameSnapshot}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${_dateLabel(row.date)} · ${row.providerNameSnapshot}',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: selected
                                                        ? Colors.white
                                                              .withValues(
                                                                alpha: 0.9,
                                                              )
                                                        : kFinanzasMutedInk,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            _money(row.amount),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
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
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DialogActionsRow(
                    onCancel: () => Navigator.of(context).pop(),
                    onConfirm:
                        _folioC.text.trim().isEmpty ||
                            _selectedTicketIds.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).pop(
                              _InvoiceDraftResult(
                                folio: _folioC.text.trim(),
                                originType: 'TICKETS',
                                invoiceDate: _invoiceDate,
                                dueDate: _dueDate,
                                targetCompany: _targetCompany,
                                targetBranch: _targetBranch,
                                manualAmount: null,
                                notes: _notesC.text.trim(),
                                selectedTicketIds: _selectedTicketIds,
                              ),
                            );
                          },
                    confirmLabel: widget.confirmLabel,
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

class _RegisterManualSupplierInvoiceDialog extends StatefulWidget {
  final String companyName;
  final (String, String) initialTarget;
  final _InvoiceDraftResult? initialDraft;
  final String title;
  final String confirmLabel;

  const _RegisterManualSupplierInvoiceDialog({
    required this.companyName,
    required this.initialTarget,
    this.initialDraft,
    this.title = 'Registrar factura manual',
    this.confirmLabel = 'Guardar factura',
  });

  @override
  State<_RegisterManualSupplierInvoiceDialog> createState() =>
      _RegisterManualSupplierInvoiceDialogState();
}

class _RegisterManualSupplierInvoiceDialogState
    extends State<_RegisterManualSupplierInvoiceDialog> {
  static const List<String> _targetCompanies = <String>['DICSA', 'VH'];
  static const List<String> _targetBranches = <String>['CELAYA', 'MAZATLAN'];
  late final TextEditingController _folioC;
  late final TextEditingController _amountC;
  late final TextEditingController _notesC;
  late DateTime _invoiceDate;
  DateTime? _dueDate;
  late String _targetCompany;
  late String _targetBranch;

  @override
  void initState() {
    super.initState();
    _folioC = TextEditingController();
    _amountC = TextEditingController();
    _notesC = TextEditingController();
    _invoiceDate = DateUtils.dateOnly(
      widget.initialDraft?.invoiceDate ?? DateTime.now(),
    );
    _dueDate = widget.initialDraft?.dueDate == null
        ? null
        : DateUtils.dateOnly(widget.initialDraft!.dueDate!);
    _targetCompany =
        widget.initialDraft?.targetCompany ?? widget.initialTarget.$1;
    _targetBranch =
        widget.initialDraft?.targetBranch ?? widget.initialTarget.$2;
    _folioC.text = widget.initialDraft?.folio ?? '';
    if ((widget.initialDraft?.manualAmount ?? 0) > 0) {
      _amountC.text = widget.initialDraft!.manualAmount!.toStringAsFixed(2);
    }
    _notesC.text = widget.initialDraft?.notes ?? '';
  }

  @override
  void dispose() {
    _folioC.dispose();
    _amountC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  double _parseAmount() {
    final sanitized = _amountC.text.replaceAll(',', '').trim();
    return double.tryParse(sanitized) ?? 0;
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
    if (value == null) return 'Sin fecha';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  Future<void> _pickInvoiceDate() async {
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
            data: _buildFinanzasDatePickerTheme(context),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _invoiceDate = DateUtils.dateOnly(picked));
  }

  Future<void> _pickDueDate() async {
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
            data: _buildFinanzasDatePickerTheme(context),
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
    final amount = _parseAmount();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: Builder(
          builder: (context) => ContractGlassCard(
            borderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DialogHeader(
                    title: widget.title,
                    subtitle:
                        '${widget.companyName} · Úsala cuando la factura no proviene de tickets de compra.',
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _folioC,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          cursorColor: finanzasAreaTokens.primaryStrong,
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
                  Row(
                    children: [
                      Expanded(
                        child: _InlineChoiceField(
                          label: 'Empresa objetivo',
                          value: _targetCompany,
                          onTap: () async {
                            final selected = await _showSimpleOptionsDialog(
                              context: context,
                              title: 'Seleccionar empresa objetivo',
                              options: _targetCompanies
                                  .map(
                                    (row) => _SimpleOption(
                                      id: row,
                                      label: row,
                                      subtitle: 'Cuenta pagadora esperada',
                                    ),
                                  )
                                  .toList(growable: false),
                            );
                            if (selected == null || !mounted) return;
                            setState(() => _targetCompany = selected.id);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InlineChoiceField(
                          label: 'Cuenta objetivo',
                          value: _targetBranch == 'MAZATLAN'
                              ? 'Mazatlan'
                              : 'Celaya',
                          onTap: () async {
                            final selected = await _showSimpleOptionsDialog(
                              context: context,
                              title: 'Seleccionar cuenta objetivo',
                              options: _targetBranches
                                  .map(
                                    (row) => _SimpleOption(
                                      id: row,
                                      label: row == 'MAZATLAN'
                                          ? 'Mazatlan'
                                          : 'Celaya',
                                      subtitle: 'Sucursal/cuenta objetivo',
                                    ),
                                  )
                                  .toList(growable: false),
                            );
                            if (selected == null || !mounted) return;
                            setState(() => _targetBranch = selected.id);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _amountC,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: false,
                          ),
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          cursorColor: finanzasAreaTokens.primaryStrong,
                          decoration: contractGlassFieldDecoration(
                            context,
                            hintText: 'Importe total de la factura',
                            prefixIcon: const Icon(Icons.payments_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FinanzasGlassPanel(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          borderRadius: BorderRadius.circular(18),
                          fillColor: kFinanzasPanelSurfaceLight,
                          borderColor: Colors.white.withValues(alpha: 0.10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Saldo inicial',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: kFinanzasMutedInk,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _money(amount),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesC,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    cursorColor: finanzasAreaTokens.primaryStrong,
                    minLines: 2,
                    maxLines: 4,
                    decoration: contractGlassFieldDecoration(
                      context,
                      hintText: 'Notas de factura o convenio',
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _DialogActionsRow(
                    onCancel: () => Navigator.of(context).pop(),
                    onConfirm: _folioC.text.trim().isEmpty || amount <= 0.009
                        ? null
                        : () {
                            Navigator.of(context).pop(
                              _InvoiceDraftResult(
                                folio: _folioC.text.trim(),
                                originType: 'MANUAL',
                                invoiceDate: _invoiceDate,
                                dueDate: _dueDate,
                                targetCompany: _targetCompany,
                                targetBranch: _targetBranch,
                                manualAmount: amount,
                                notes: _notesC.text.trim(),
                                selectedTicketIds: const <String>{},
                              ),
                            );
                          },
                    confirmLabel: widget.confirmLabel,
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
            color: tokens.fieldSurface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
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

class _ProviderPickerOptionTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final bool hovered;
  final ValueChanged<bool>? onHoverChanged;
  final VoidCallback onTap;

  const _ProviderPickerOptionTile({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.hovered = false,
    this.onHoverChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverChanged?.call(true),
      onExit: (_) => onHoverChanged?.call(false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? tokens.primaryStrong.withValues(alpha: 0.16)
                  : hovered
                  ? tokens.primaryStrong.withValues(alpha: 0.12)
                  : kFinanzasPanelSurfaceStrong,
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
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: selected || hovered
                        ? tokens.primaryStrong
                        : kFinanzasInk,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
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

class _FinProviderAccountsBackground extends StatelessWidget {
  const _FinProviderAccountsBackground();

  @override
  Widget build(BuildContext context) => const FinanzasAreaBackground();
}

class _FinProviderAccountsHeaderBrand extends StatelessWidget {
  const _FinProviderAccountsHeaderBrand();

  @override
  Widget build(BuildContext context) {
    return const FinanzasPageHeaderBrand(title: 'Cuentas por Proveedor');
  }
}

class _FinHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final bool iconOnly;

  const _FinHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
    this.iconOnly = false,
  });

  @override
  State<_FinHeaderButton> createState() => _FinHeaderButtonState();
}

class _FinHeaderButtonState extends State<_FinHeaderButton> {
  @override
  Widget build(BuildContext context) {
    return FinanzasPageHeaderButton(
      label: widget.label,
      icon: widget.icon,
      onTap: widget.onTap,
      onTapSync: widget.onTapSync,
      iconOnly: widget.iconOnly,
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
    return FinanzasAreaSidePanel(
      currentLabel: 'Cuentas por Proveedor',
      canReturnToDirection: canReturnToDirection,
      canAccessComprasArea: canAccessComprasArea,
      onNavigate: onNavigate,
    );
  }
}
