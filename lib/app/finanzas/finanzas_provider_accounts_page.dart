import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
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
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/utils/file_download_save.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'finanzas_bank_accounts_store.dart';
import 'finanzas_bank_accounts_page.dart';
import 'finanzas_catalog_page.dart';
import 'finanzas_company_directory_page.dart';
import 'finanzas_company_directory_store.dart';
import 'finanzas_dashboard_page.dart';
import 'finanzas_evidence_store.dart';
import 'finanzas_fixed_payments_page.dart';
import 'finanzas_payment_center_page.dart';
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
                      .toList(growable: false) ??
                  <_ProviderAgreementView>[];
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

  Future<void> _printAccountReportFor(_ProviderAccountView account) async {
    if (account.tickets.isEmpty &&
        account.movements.isEmpty &&
        account.cashMovements.isEmpty) {
      _toast('Esta cuenta todavía no tiene información para imprimir.');
      return;
    }
    final preset = await _showAccountReportPresetDialog(
      context,
      providerName: account.company.companyName,
    );
    if (preset == _kDismissedAccountReportPreset) return;
    try {
      final pdfBytes = await _buildAccountReportPdfBytes(
        account,
        preset: preset,
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

  Future<Uint8List> _buildAccountReportPdfBytes(
    _ProviderAccountView account, {
    _AccountReportPreset? preset,
  }) async {
    final doc = pw.Document();
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo_dicsa.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final reportTickets =
        (preset == null
                ? account.tickets
                : account.tickets.where(
                    (row) => _matchesAccountReportPreset(row.date, preset),
                  ))
            .toList(growable: false);
    if (reportTickets.isEmpty) {
      throw Exception('No hay tickets en ese rango.');
    }
    final reportTicketIds = reportTickets.map((row) => row.id).toSet();
    final now = DateTime.now();
    final printedAt =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final ticketTotal = reportTickets.fold<double>(
      0,
      (sum, row) => sum + row.amount,
    );
    final directApplicationsByTicketId =
        <String, List<_ProviderTicketSettlementView>>{};
    for (final ticket in reportTickets) {
      final applications =
          account.ticketApplicationsByTicketId[ticket.id]?.toList(
            growable: false,
          ) ??
          const <_ProviderTicketApplicationView>[];
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
      account.invoices,
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
      final bankCoverage = bankApplications.fold<double>(
        0,
        (sum, item) => sum + item.amount,
      );
      final appliedTotal = (appliedFromCash + bankCoverage).clamp(
        0,
        ticket.amount,
      );
      paymentTotal += appliedTotal;
      openTotal += (ticket.amount - appliedTotal).clamp(0, double.infinity);
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
    final paymentRows = providerPaymentRowsById.values.toList(growable: false)
      ..sort((a, b) => a.date.compareTo(b.date));

    pw.Widget summaryCard(String label, String value) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F3D9D4'),
            borderRadius: pw.BorderRadius.circular(14),
            border: pw.Border.all(color: PdfColor.fromHex('#D8A39A')),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 9.2,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#8B2A1B'),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 15.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#3F130C'),
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
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      account.company.companyName,
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (preset != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        preset.label.toUpperCase(),
                        style: const pw.TextStyle(fontSize: 9.4),
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
              summaryCard('ABONOS TOTAL', _money(paymentTotal)),
              pw.SizedBox(width: 10),
              summaryCard('SALDO PENDIENTE', _money(openTotal)),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'TICKETS',
            style: pw.TextStyle(
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#7A1914'),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#D8A39A')),
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
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F3D9D4'),
                ),
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
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
              ),
              for (final row in prioritizedTickets)
                pw.TableRow(
                  children: () {
                    final ticketApplications = <_ProviderTicketSettlementView>[
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
                                final reference = item.reference.trim().isEmpty
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
            'ABONOS',
            style: pw.TextStyle(
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#7A1914'),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#D8A39A')),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.0),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.1),
              3: const pw.FlexColumnWidth(1.4),
              4: const pw.FlexColumnWidth(1.0),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F3D9D4'),
                ),
                children: ['FECHA', 'ORIGEN', 'TIPO', 'REFERENCIA', 'IMPORTE']
                    .map(
                      (label) => pw.Padding(
                        padding: const pw.EdgeInsets.all(7),
                        child: pw.Text(
                          label,
                          style: pw.TextStyle(
                            fontSize: 9.4,
                            fontWeight: pw.FontWeight.bold,
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
    final eligibleInvoices = account.invoices
        .map((row) => row.invoice)
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
      final selectedInvoices = eligibleInvoices
          .where((invoice) => draft.selectedInvoiceIds.contains(invoice.id))
          .toList(growable: false);
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar convenio'),
        content: const Text(
          'Se cancelarán los compromisos pendientes, pero el historial permanecerá visible. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar convenio'),
          ),
        ],
      ),
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
                child: ContractGlassCard(
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
                                        context,
                                      ).primaryStrong,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    row.invoice.folio,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: kFinanzasMutedInk,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.icon(
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
                            IconButton(
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
                                    color: Colors.white.withValues(alpha: 0.74),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: AreaThemeScope.of(
                                        context,
                                      ).border.withValues(alpha: 0.84),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        evidence.fileName
                                                .toLowerCase()
                                                .endsWith('.pdf')
                                            ? Icons.picture_as_pdf_outlined
                                            : Icons.photo_library_outlined,
                                        color: AreaThemeScope.of(
                                          context,
                                        ).primaryStrong,
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
                                                color: AreaThemeScope.of(
                                                  context,
                                                ).primaryStrong,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${_dateLabelStatic(evidence.uploadedAt)} · ${evidence.uploadedByName.isEmpty ? 'Usuario' : evidence.uploadedByName}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: kFinanzasMutedInk,
                                              ),
                                            ),
                                            if (evidence.comment
                                                .trim()
                                                .isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Text(
                                                  evidence.comment.trim(),
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
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
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
              return AlertDialog(
                title: Text(title),
                content: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final result = await FilePicker.platform.pickFiles(
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
                            if (result == null || result.files.isEmpty) return;
                            setLocalState(() => picked = result.files.first);
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
                      const SizedBox(height: 12),
                      TextField(
                        controller: commentC,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Comentario',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Guardar'),
                  ),
                ],
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

  String _providerMovementSourceLabel(String source) {
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
      final appliedAmount = (directApplied + bankApplied)
          .clamp(0, ticket.amount)
          .toDouble();
      final fullyCovered = appliedAmount >= ticket.amount - 0.009;
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

  bool _matchesAccountReportPreset(DateTime date, _AccountReportPreset preset) {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = DateTime(
      today.year,
      today.month,
      today.day - (preset.days - 1),
    );
    final ticketDay = DateUtils.dateOnly(date);
    return !ticketDay.isBefore(start) && !ticketDay.isAfter(today);
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
                                        onEditInvoicePriority:
                                            _editInvoicePriority,
                                        onOpenInvoiceEvidence:
                                            _openInvoiceEvidenceDialog,
                                        onPrintAccount: _printAccountReportFor,
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
  final appliedAmount = (directApplied + bankApplied)
      .clamp(0, ticket.amount)
      .toDouble();
  final fullyCovered = appliedAmount >= ticket.amount - 0.009;
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

class _AccountReportPreset {
  final String id;
  final String label;
  final int days;

  const _AccountReportPreset({
    required this.id,
    required this.label,
    required this.days,
  });
}

const List<_AccountReportPreset> _kAccountReportPresets = [
  _AccountReportPreset(id: 'last_30', label: 'Ultimos 30', days: 30),
  _AccountReportPreset(id: 'last_90', label: 'Ultimos 90', days: 90),
  _AccountReportPreset(id: 'last_180', label: 'Ultimos 180', days: 180),
];

const _AccountReportPreset _kDismissedAccountReportPreset =
    _AccountReportPreset(id: 'dismissed', label: 'Cancelar', days: 0);

Future<_AccountReportPreset?> _showAccountReportPresetDialog(
  BuildContext context, {
  required String providerName,
}) async {
  return showDialog<_AccountReportPreset?>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Alcance del reporte'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                providerName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kFinanzasMutedInk,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'El reporte toma tickets del periodo elegido. Los abonos se jalán por relación real a esos tickets, aunque hayan ocurrido después.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: kFinanzasMutedInk,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              for (final preset in _kAccountReportPresets) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(preset),
                    child: Text(preset.label),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_kDismissedAccountReportPreset),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Todos'),
          ),
        ],
      );
    },
  );
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
    final metrics = _computeProviderAccountMetrics(row);
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
                  const SizedBox(width: 8),
                  _MovementIconAction(
                    icon: Icons.picture_as_pdf_outlined,
                    color: tokens.primaryStrong,
                    onTap: onPrint,
                  ),
                  const SizedBox(width: 10),
                  _MiniToneChip(label: row.urgencyLabel, tone: row.urgencyTone),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Saldo abierto ${moneyFormatter(metrics.openAmount)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: tokens.badgeText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Abiertos ${metrics.openTicketsCount} · Próximo ${dateFormatter(metrics.nextCommitmentDate)}',
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
  final Future<void> Function(_ProviderInvoiceView invoice)
  onEditInvoicePriority;
  final Future<void> Function(_ProviderInvoiceView invoice)
  onOpenInvoiceEvidence;
  final Future<void> Function(_ProviderAccountView account) onPrintAccount;

  const _ProviderAccountsDetailPane({
    required this.account,
    required this.activeTab,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onTabSelected,
    required this.onRegisterInvoice,
    required this.onEditProviderPriority,
    required this.onOpenBankAccounts,
    required this.onRegisterCashMovement,
    required this.onRegisterAgreement,
    required this.onEditAgreement,
    required this.onCancelAgreement,
    required this.onToggleInstallmentPaid,
    required this.onEditCashMovement,
    required this.onDeleteCashMovement,
    required this.onEditInvoicePriority,
    required this.onOpenInvoiceEvidence,
    required this.onPrintAccount,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final metrics = _computeProviderAccountMetrics(account);
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
              ),
              _SummaryMetricCard(
                label: 'Vencido',
                value: moneyFormatter(metrics.overdueAmount),
              ),
              _SummaryMetricCard(
                label: 'Facturado',
                value: moneyFormatter(metrics.facturadoAmount),
              ),
              _SummaryMetricCard(
                label: 'Sin factura',
                value: moneyFormatter(metrics.sinFacturaAmount),
              ),
              _SummaryMetricCard(
                label: 'Pend. facturar',
                value: moneyFormatter(metrics.pendienteFacturarAmount),
              ),
              _SummaryMetricCard(
                label: 'Pagado',
                value: moneyFormatter(metrics.paidAmount),
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
                onEditInvoicePriority: onEditInvoicePriority,
                onOpenInvoiceEvidence: onOpenInvoiceEvidence,
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
              final resolved = _resolveProviderTicketStatus(account, row);
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
  final Future<void> Function(_ProviderInvoiceView invoice)
  onEditInvoicePriority;
  final Future<void> Function(_ProviderInvoiceView invoice)
  onOpenInvoiceEvidence;

  const _ProviderAccountInvoicesView({
    required this.account,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onRegisterInvoice,
    required this.onEditInvoicePriority,
    required this.onOpenInvoiceEvidence,
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
                          _MovementIconAction(
                            icon: Icons.flag_outlined,
                            color: _manualPriorityTone(
                              row.invoice.manualPriority,
                            ),
                            onTap: () => onEditInvoicePriority(row),
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
                          _SummaryMetricCard(
                            label: 'Empresa objetivo',
                            value: row.invoice.targetCompany,
                          ),
                          _SummaryMetricCard(
                            label: 'Cuenta objetivo',
                            value: row.invoice.targetBranch == 'MAZATLAN'
                                ? 'Mazatlan'
                                : 'Celaya',
                          ),
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
                            color: const Color(0xFFB42318),
                            onTap: () => onCancelAgreement(row),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _SummaryMetricCard(
                            label: 'Empresa objetivo',
                            value: row.agreement.targetCompany,
                          ),
                          _SummaryMetricCard(
                            label: 'Cuenta objetivo',
                            value: row.agreement.targetBranch == 'MAZATLAN'
                                ? 'Mazatlan'
                                : 'Celaya',
                          ),
                          if (row.agreement.agreementType == 'POR_MONTO')
                            _SummaryMetricCard(
                              label: 'Pago pactado',
                              value: moneyFormatter(
                                row.agreement.installmentAmount,
                              ),
                            )
                          else
                            _SummaryMetricCard(
                              label: 'Facturas por periodo',
                              value: '${row.agreement.invoicesPerPeriod}',
                            ),
                          _SummaryMetricCard(
                            label: row.agreement.agreementType == 'POR_MONTO'
                                ? 'Pagos'
                                : 'Compromisos',
                            value: '${row.agreement.installmentCount}',
                          ),
                          if (row.agreement.agreementType == 'POR_FACTURAS')
                            _SummaryMetricCard(
                              label: 'Facturas ligadas',
                              value: '${row.agreement.scheduledInvoiceCount}',
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
                                        alpha: 0.74,
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
                                              ? const Color(0xFF8B5E00)
                                              : const Color(0xFF0F766E),
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(
                  color: tokens.primaryStrong.withValues(alpha: 0.16),
                ),
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
                              widget.title,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: tokens.primaryStrong,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.subtitle,
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
                        icon: Icon(
                          Icons.close_rounded,
                          color: tokens.primaryStrong,
                        ),
                      ),
                    ],
                  ),
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
                          backgroundColor: Colors.white.withValues(alpha: 0.72),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _level == level
                                ? _manualPriorityTone(level)
                                : tokens.primaryStrong,
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
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'Ej. proveedor presionando, surtido crítico, acuerdo verbal, etc.',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.88),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: tokens.primaryStrong.withValues(alpha: 0.16),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: tokens.primaryStrong.withValues(alpha: 0.16),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: tokens.primaryStrong.withValues(alpha: 0.34),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop(
                            _ManualPriorityDraft(
                              level: _level,
                              note: _noteC.text.trim(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Guardar prioridad'),
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
                  widget.initialDraft == null
                      ? 'Nuevo convenio'
                      : 'Editar convenio',
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
                        label: 'Tipo',
                        value: finSupplierAgreementTypeLabel(_agreementType),
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
                        value: finSupplierAgreementFrequencyLabel(_frequency),
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

Color _manualPriorityTone(String level) {
  switch (level) {
    case 'CRITICA':
      return const Color(0xFFB42318);
    case 'ALTA':
      return const Color(0xFF8B5E00);
    default:
      return const Color(0xFF6B7280);
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

class _CompactInvoiceChip extends StatelessWidget {
  final String label;

  const _CompactInvoiceChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AreaThemeScope.of(context).border.withValues(alpha: 0.86),
        ),
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
                const Text(
                  'Seleccionar facturas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: kFinanzasInk,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Elige las facturas que entran al convenio y luego define cuántas van por periodo.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kFinanzasMutedInk,
                  ),
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
                            color: Colors.white.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected
                                  ? finanzasAreaTokens.primaryStrong
                                  : finanzasAreaTokens.border.withValues(
                                      alpha: 0.9,
                                    ),
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: kFinanzasInk,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_selectedIds.toList(growable: false)),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Usar selección'),
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
  final String targetCompany;
  final String targetBranch;
  final String notes;
  final Set<String> selectedTicketIds;

  const _InvoiceDraftResult({
    required this.folio,
    required this.invoiceDate,
    required this.dueDate,
    required this.targetCompany,
    required this.targetBranch,
    required this.notes,
    required this.selectedTicketIds,
  });
}

class _RegisterSupplierInvoiceDialog extends StatefulWidget {
  final String companyName;
  final List<ComprasTicketRecord> tickets;
  final (String, String) initialTarget;

  const _RegisterSupplierInvoiceDialog({
    required this.companyName,
    required this.tickets,
    required this.initialTarget,
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
  late DateTime _invoiceDate;
  DateTime? _dueDate;
  late Set<String> _selectedTicketIds;
  late String _targetCompany;
  late String _targetBranch;

  @override
  void initState() {
    super.initState();
    _folioC = TextEditingController();
    _notesC = TextEditingController();
    _invoiceDate = DateUtils.dateOnly(DateTime.now());
    _selectedTicketIds = widget.tickets.map((ticket) => ticket.id).toSet();
    _targetCompany = widget.initialTarget.$1;
    _targetBranch = widget.initialTarget.$2;
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
                                  targetCompany: _targetCompany,
                                  targetBranch: _targetBranch,
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
  Widget build(BuildContext context) => const FinanzasAreaBackground();
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
        const SizedBox(width: 20),
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
    return FinanzasAreaSidePanel(
      currentLabel: 'Cuentas por Proveedor',
      canReturnToDirection: canReturnToDirection,
      canAccessComprasArea: canAccessComprasArea,
      onNavigate: onNavigate,
    );
  }
}
