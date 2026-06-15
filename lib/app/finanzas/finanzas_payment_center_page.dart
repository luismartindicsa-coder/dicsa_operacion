import 'dart:async';
import 'package:flutter/material.dart';

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
import 'finanzas_bank_accounts_page.dart';
import 'finanzas_bank_accounts_store.dart';
import 'finanzas_catalog_page.dart';
import 'finanzas_company_identity.dart';
import 'finanzas_company_directory_page.dart';
import 'finanzas_company_directory_store.dart';
import 'finanzas_dashboard_page.dart';
import 'finanzas_financial_rules.dart';
import 'finanzas_fixed_payments_page.dart';
import 'finanzas_fixed_payments_store.dart';
import 'finanzas_payment_learning_store.dart';
import 'finanzas_provider_accounts_page.dart';
import 'finanzas_provider_accounts_store.dart';
import 'finanzas_theme.dart';

enum _PaymentCenterTab {
  obligatorio('Obligatorio'),
  urgente('Urgente'),
  recomendado('Recomendado'),
  postergable('Postergable');

  final String label;
  const _PaymentCenterTab(this.label);
}

enum _PaymentExecutionDecision {
  pagarCompleto('Pagar completo'),
  abonar('Abonar'),
  esperar('Esperar');

  final String label;
  const _PaymentExecutionDecision(this.label);
}

enum _PaymentCenterMode {
  operacion('Operación'),
  // Conservado para reactivarlo después sin rearmar la capa de aprendizaje.
  // ignore: unused_field
  aprendizaje('Aprendizaje');

  final String label;
  const _PaymentCenterMode(this.label);
}

class FinanzasPaymentCenterPage extends StatefulWidget {
  final bool instantOpen;

  const FinanzasPaymentCenterPage({super.key, this.instantOpen = false});

  @override
  State<FinanzasPaymentCenterPage> createState() =>
      _FinanzasPaymentCenterPageState();
}

class _FinanzasPaymentCenterPageState extends State<FinanzasPaymentCenterPage> {
  bool _menuOpen = false;
  bool _loading = true;
  bool _canReturnToDirection = false;
  bool _canAccessComprasArea = false;
  final _PaymentCenterMode _activeMode = _PaymentCenterMode.operacion;
  List<_PaymentCenterItem> _items = const <_PaymentCenterItem>[];
  List<FinanzasPaymentLearningRecord> _learningLogs =
      const <FinanzasPaymentLearningRecord>[];
  Map<String, double> _accountBalances = const <String, double>{};

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadPage());
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
      ComprasTicketsStore.loadTicketPaymentApplications(),
      FinanzasProviderAccountsStore.loadInvoices(),
      FinanzasProviderAccountsStore.loadAgreements(),
      FinanzasProviderAccountsStore.loadAgreementInstallments(),
      FinanzasProviderAccountsStore.loadAgreementInvoices(),
      FinanzasBankAccountsStore.loadMovements(),
      FinanzasFixedPaymentsStore.loadPayments(),
      FinanzasPaymentLearningStore.loadLogs(),
    ]);
    if (!mounted) return;
    final directory = results[0] as List<FinanzasCompanyDirectoryRecord>;
    final tickets = results[1] as List<ComprasTicketRecord>;
    final ticketApplications =
        results[2] as List<ComprasTicketPaymentApplicationRecord>;
    final invoices = results[3] as List<FinanzasSupplierInvoiceRecord>;
    final agreements = results[4] as List<FinanzasSupplierAgreementRecord>;
    final installments =
        results[5] as List<FinanzasSupplierAgreementInstallmentRecord>;
    final agreementInvoiceLinks =
        results[6] as List<FinanzasSupplierAgreementInvoiceRecord>;
    final bankMovements = results[7] as List<FinanzasBankMovementRecord>;
    final fixedPayments = results[8] as List<FinanzasFixedPaymentRecord>;
    final learningLogs = results[9] as List<FinanzasPaymentLearningRecord>;

    final balances = _computeBalances(bankMovements);
    final items = _buildItems(
      directory: directory,
      tickets: tickets,
      ticketApplications: ticketApplications,
      invoices: invoices,
      agreements: agreements,
      installments: installments,
      agreementInvoiceLinks: agreementInvoiceLinks,
      fixedPayments: fixedPayments,
      balances: balances,
    );
    setState(() {
      _accountBalances = balances;
      _items = items;
      _learningLogs = learningLogs;
      _loading = false;
    });
  }

  String _learningActionLabel(_PaymentExecutionDecision decision) {
    switch (decision) {
      case _PaymentExecutionDecision.pagarCompleto:
        return 'PAGAR_COMPLETO';
      case _PaymentExecutionDecision.abonar:
        return 'ABONAR';
      case _PaymentExecutionDecision.esperar:
        return 'ESPERAR';
    }
  }

  String _learningActionDisplay(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'PAGAR_COMPLETO':
        return 'Pagar completo';
      case 'ABONAR':
        return 'Abonar';
      case 'ESPERAR':
        return 'Esperar';
      default:
        return raw.trim().isEmpty ? 'Sin registrar' : raw.trim();
    }
  }

  List<FinanzasPaymentLearningRecord> _buildLearningSnapshotRecords() {
    final capturedAt = DateTime.now();
    return _items
        .map((item) {
          final millis = capturedAt.microsecondsSinceEpoch;
          return FinanzasPaymentLearningRecord(
            id: '${item.providerId}_${item.itemType}_${millis}_${item.priorityScore}',
            capturedAt: capturedAt,
            providerId: item.providerId,
            providerName: item.providerName,
            bucket: item.bucket.label.toUpperCase(),
            itemType: item.itemType,
            sourceLabel: item.sourceLabel,
            dueDate: item.dueDate,
            targetCompany: item.targetCompany,
            targetBranch: item.targetBranch,
            suggestedAction: _learningActionLabel(item.executionDecision),
            suggestedAmount: item.executionAmount > 0
                ? item.executionAmount
                : item.amountSuggested,
            recommendation: item.executionSummary.isNotEmpty
                ? item.executionSummary
                : item.recommendation,
            status: 'PENDIENTE',
            executedAction: null,
            executedAmount: null,
            notes: item.decisionReasons.join(' | '),
            createdAt: null,
            updatedAt: null,
          );
        })
        .toList(growable: false);
  }

  Future<void> _captureLearningSnapshot() async {
    if (_items.isEmpty) return;
    final logs = _buildLearningSnapshotRecords();
    await FinanzasPaymentLearningStore.saveLogs(logs);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Se capturó un corte de aprendizaje con ${logs.length} pendientes.',
        ),
      ),
    );
    await _loadPage();
  }

  Future<void> _registerLearningDecision(
    FinanzasPaymentLearningRecord row,
  ) async {
    final amountC = TextEditingController(
      text:
          row.executedAmount?.toStringAsFixed(2) ??
          row.suggestedAmount.toStringAsFixed(2),
    );
    final notesC = TextEditingController(text: row.notes);
    String selectedAction = row.executedAction ?? row.suggestedAction;
    var saving = false;
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setLocalState) {
              final tokens = AreaThemeScope.of(context);
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ContractGlassCard(
                    borderRadius: BorderRadius.circular(30),
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registrar decisión',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: tokens.primaryStrong,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          row.providerName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: kFinanzasMutedInk,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final action in const <String>[
                              'PAGAR_COMPLETO',
                              'ABONAR',
                              'ESPERAR',
                            ])
                              ChoiceChip(
                                label: Text(_learningActionDisplay(action)),
                                selected: selectedAction == action,
                                onSelected: (_) => setLocalState(
                                  () => selectedAction = action,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: amountC,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Monto ejecutado',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: notesC,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(labelText: 'Notas'),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: saving
                                  ? null
                                  : () =>
                                        Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      setLocalState(() => saving = true);
                                      final parsedAmount =
                                          double.tryParse(
                                            amountC.text
                                                .replaceAll(',', '')
                                                .trim(),
                                          ) ??
                                          0;
                                      final updated = row.copyWith(
                                        status: 'REGISTRADO',
                                        executedAction: selectedAction,
                                        executedAmount: parsedAmount,
                                        notes: notesC.text.trim(),
                                      );
                                      await FinanzasPaymentLearningStore.saveLog(
                                        updated,
                                      );
                                      if (dialogContext.mounted) {
                                        Navigator.of(dialogContext).pop(true);
                                      }
                                    },
                              child: const Text('Guardar'),
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
      if (saved == true && mounted) {
        await _loadPage();
      }
    } finally {
      amountC.dispose();
      notesC.dispose();
    }
  }

  Map<String, double> _computeBalances(List<FinanzasBankMovementRecord> rows) {
    final map = <String, double>{};
    for (final row in rows) {
      map.update(
        row.accountKey,
        (value) => value + row.creditAmount - row.debitAmount,
        ifAbsent: () => row.creditAmount - row.debitAmount,
      );
    }
    return map;
  }

  int _bucketBaseScore(_PaymentCenterTab bucket) {
    switch (bucket) {
      case _PaymentCenterTab.obligatorio:
        return 400;
      case _PaymentCenterTab.urgente:
        return 300;
      case _PaymentCenterTab.recomendado:
        return 200;
      case _PaymentCenterTab.postergable:
        return 100;
    }
  }

  _PaymentCenterTab _maxUrgencyBucket(
    _PaymentCenterTab current,
    _PaymentCenterTab minimum,
  ) {
    final order = <_PaymentCenterTab, int>{
      _PaymentCenterTab.obligatorio: 0,
      _PaymentCenterTab.urgente: 1,
      _PaymentCenterTab.recomendado: 2,
      _PaymentCenterTab.postergable: 3,
    };
    return (order[current] ?? 99) <= (order[minimum] ?? 99) ? current : minimum;
  }

  ({_PaymentCenterTab bucket, List<String> reasons, int score})
  _buildPriorityMeta({
    required _PaymentCenterTab bucket,
    required String itemType,
    required DateTime? dueDate,
    required String agreementLabel,
    required double amountSuggested,
    required bool hasAgreement,
    required String paymentStage,
    required String providerManualPriority,
    required String providerPriorityNote,
    required String invoiceManualPriority,
    required String invoicePriorityNote,
    required DateTime today,
  }) {
    final reasons = <String>[];
    var effectiveBucket = bucket;
    var score = _bucketBaseScore(effectiveBucket);
    final dueOnly = dueDate == null ? null : DateUtils.dateOnly(dueDate);
    if (dueOnly != null) {
      if (dueOnly.isBefore(today)) {
        reasons.add('Ya venció');
        score += 60;
      } else if (dueOnly.isAtSameMomentAs(today)) {
        reasons.add('Vence hoy');
        score += 45;
      } else if (dueOnly.isBefore(today.add(const Duration(days: 4)))) {
        reasons.add('Vence esta semana');
        score += 25;
      }
    }
    if (itemType == 'Pago fijo') {
      reasons.add('Compromiso fijo del mes');
      score += 40;
    }
    if (itemType == 'Convenio') {
      reasons.add('Compromiso pactado con proveedor');
      score += 35;
    }
    if (invoiceManualPriority == 'CRITICA') {
      effectiveBucket = _maxUrgencyBucket(
        effectiveBucket,
        _PaymentCenterTab.obligatorio,
      );
      reasons.add('Prioridad manual crítica en factura');
      score += 110;
      if (invoicePriorityNote.trim().isNotEmpty) {
        reasons.add('Nota factura: ${invoicePriorityNote.trim()}');
      }
    } else if (invoiceManualPriority == 'ALTA') {
      effectiveBucket = _maxUrgencyBucket(
        effectiveBucket,
        _PaymentCenterTab.urgente,
      );
      reasons.add('Prioridad manual alta en factura');
      score += 60;
      if (invoicePriorityNote.trim().isNotEmpty) {
        reasons.add('Nota factura: ${invoicePriorityNote.trim()}');
      }
    } else if (providerManualPriority == 'CRITICA') {
      effectiveBucket = _maxUrgencyBucket(
        effectiveBucket,
        _PaymentCenterTab.urgente,
      );
      reasons.add('Proveedor con prioridad crítica');
      score += 80;
      if (providerPriorityNote.trim().isNotEmpty) {
        reasons.add('Nota proveedor: ${providerPriorityNote.trim()}');
      }
    } else if (providerManualPriority == 'ALTA') {
      effectiveBucket = _maxUrgencyBucket(
        effectiveBucket,
        _PaymentCenterTab.recomendado,
      );
      reasons.add('Proveedor con prioridad alta');
      score += 36;
      if (providerPriorityNote.trim().isNotEmpty) {
        reasons.add('Nota proveedor: ${providerPriorityNote.trim()}');
      }
    }
    if (itemType == 'Factura' && hasAgreement) {
      reasons.add('Proveedor con convenio activo');
      score += 10;
    }
    if (paymentStage == 'ATRASADO') {
      reasons.add('Proveedor marcado como atrasado');
      score += 30;
    } else if (paymentStage == 'PAGO_SEMANAL') {
      reasons.add('Proveedor de pago semanal');
      score += 14;
    } else if (paymentStage == 'CONVENIO') {
      reasons.add('Proveedor bajo convenio');
      score += 20;
    }
    if (agreementLabel.contains('Vencid') ||
        agreementLabel.contains('Atrasad')) {
      reasons.add('Estado sensible');
      score += 18;
    }
    if (amountSuggested >= 100000) {
      reasons.add('Monto alto');
      score += 12;
    } else if (amountSuggested >= 25000) {
      reasons.add('Monto relevante');
      score += 6;
    }
    score += (_bucketBaseScore(effectiveBucket) - _bucketBaseScore(bucket));
    return (bucket: effectiveBucket, reasons: reasons, score: score);
  }

  List<_PaymentCenterItem> _buildItems({
    required List<FinanzasCompanyDirectoryRecord> directory,
    required List<ComprasTicketRecord> tickets,
    required List<ComprasTicketPaymentApplicationRecord> ticketApplications,
    required List<FinanzasSupplierInvoiceRecord> invoices,
    required List<FinanzasSupplierAgreementRecord> agreements,
    required List<FinanzasSupplierAgreementInstallmentRecord> installments,
    required List<FinanzasSupplierAgreementInvoiceRecord> agreementInvoiceLinks,
    required List<FinanzasFixedPaymentRecord> fixedPayments,
    required Map<String, double> balances,
  }) {
    final providerById = <String, FinanzasCompanyDirectoryRecord>{
      for (final row in directory.where(
        (company) =>
            company.active && company.source.trim().toUpperCase() != 'VENTAS',
      ))
        row.companyId: row,
    };
    final providerByAlias = <String, FinanzasCompanyDirectoryRecord>{
      for (final row in providerById.values)
        normalizeFinanzasCompanyAliasKey(
          row.linkedName.trim().isNotEmpty ? row.linkedName : row.companyName,
        ): row,
    };

    final installmentsByAgreementId =
        <String, List<FinanzasSupplierAgreementInstallmentRecord>>{};
    for (final row in installments) {
      installmentsByAgreementId
          .putIfAbsent(
            row.agreementId,
            () => <FinanzasSupplierAgreementInstallmentRecord>[],
          )
          .add(row);
    }
    final invoicesById = <String, FinanzasSupplierInvoiceRecord>{
      for (final invoice in invoices) invoice.id: invoice,
    };
    final agreementInvoiceLinksByInstallmentId =
        <String, List<FinanzasSupplierAgreementInvoiceRecord>>{};
    for (final link in agreementInvoiceLinks) {
      agreementInvoiceLinksByInstallmentId
          .putIfAbsent(
            link.installmentId,
            () => <FinanzasSupplierAgreementInvoiceRecord>[],
          )
          .add(link);
    }

    final items = <_PaymentCenterItem>[];
    final agreementProviderIds = <String>{};
    final today = DateUtils.dateOnly(DateTime.now());
    final directAppliedByTicketId = <String, double>{};
    final comprasProviderIdByAlias = <String, String>{};
    for (final application in ticketApplications) {
      directAppliedByTicketId.update(
        application.ticketId,
        (value) => value + application.appliedAmount,
        ifAbsent: () => application.appliedAmount,
      );
    }
    for (final ticket in tickets) {
      final aliasKey = normalizeFinanzasCompanyAliasKey(
        ticket.providerNameSnapshot,
      );
      if (aliasKey.isNotEmpty) {
        comprasProviderIdByAlias.putIfAbsent(aliasKey, () => ticket.providerId);
      }
    }

    for (final payment in fixedPayments.where(
      (row) => row.status != 'PAGADO',
    )) {
      final dueDate = DateUtils.dateOnly(payment.paymentDate);
      final bucket = payment.status == 'VENCIDO' || dueDate.isBefore(today)
          ? _PaymentCenterTab.obligatorio
          : dueDate.isAtSameMomentAs(today) ||
                dueDate.isBefore(today.add(const Duration(days: 4)))
          ? _PaymentCenterTab.urgente
          : dueDate.month == today.month && dueDate.year == today.year
          ? _PaymentCenterTab.recomendado
          : _PaymentCenterTab.postergable;
      final priority = _buildPriorityMeta(
        bucket: bucket,
        itemType: 'Pago fijo',
        dueDate: payment.paymentDate,
        agreementLabel: finFixedPaymentStatusLabel(payment.status),
        amountSuggested: payment.amount,
        hasAgreement: false,
        paymentStage: 'AL_CORRIENTE',
        providerManualPriority: 'NORMAL',
        providerPriorityNote: '',
        invoiceManualPriority: 'NORMAL',
        invoicePriorityNote: '',
        today: today,
      );
      items.add(
        _PaymentCenterItem(
          providerId: payment.companyId,
          providerName: payment.companyNameSnapshot,
          bucket: priority.bucket,
          itemType: 'Pago fijo',
          sourceLabel: payment.notes.trim().isEmpty
              ? 'Compromiso mensual'
              : payment.notes.trim(),
          dueDate: payment.paymentDate,
          agreementLabel: finFixedPaymentStatusLabel(payment.status),
          amountSuggested: payment.amount,
          amountTotal: payment.amount,
          targetCompany: payment.targetCompany,
          targetBranch: payment.branch,
          urgencyLabel: bucket.label,
          recommendation: bucket == _PaymentCenterTab.obligatorio
              ? 'Cubrir pago fijo vencido'
              : bucket == _PaymentCenterTab.urgente
              ? 'Reservar flujo para pago fijo'
              : bucket == _PaymentCenterTab.recomendado
              ? 'Programar pago fijo del mes'
              : 'Pago fijo futuro',
          decisionReasons: priority.reasons,
          priorityScore: priority.score,
          allowPartialPayment: false,
          linkedFixedPaymentId: payment.id,
        ),
      );
    }

    for (final agreement in agreements) {
      final provider =
          providerById[agreement.providerId] ??
          providerByAlias[normalizeFinanzasCompanyAliasKey(
            agreement.providerNameSnapshot,
          )];
      if (provider == null) continue;
      agreementProviderIds.add(provider.companyId);
      final agreementInstallments =
          installmentsByAgreementId[agreement.id] ?? const [];
      for (final installment in agreementInstallments) {
        if (installment.status == 'PAGADO') continue;
        final dueDate = DateUtils.dateOnly(installment.dueDate);
        final amount = (installment.amount - installment.paidAmount)
            .clamp(0, double.infinity)
            .toDouble();
        if (amount <= 0.009) continue;
        final bucket = dueDate.isBefore(today)
            ? _PaymentCenterTab.obligatorio
            : dueDate.isAtSameMomentAs(today) ||
                  dueDate.isBefore(today.add(const Duration(days: 4)))
            ? _PaymentCenterTab.urgente
            : _PaymentCenterTab.recomendado;
        final installmentLinks =
            agreementInvoiceLinksByInstallmentId[installment.id] ??
            const <FinanzasSupplierAgreementInvoiceRecord>[];
        final sourceLabel = agreement.agreementType == 'POR_FACTURAS'
            ? installmentLinks
                      .map((link) => invoicesById[link.invoiceId]?.folio ?? '')
                      .where((folio) => folio.isNotEmpty)
                      .join(' · ')
                      .trim()
                      .isEmpty
                  ? 'Compromiso ${installment.sequenceNumber}'
                  : installmentLinks
                        .map(
                          (link) => invoicesById[link.invoiceId]?.folio ?? '',
                        )
                        .where((folio) => folio.isNotEmpty)
                        .join(' · ')
            : 'Pago ${installment.sequenceNumber}';
        final priority = _buildPriorityMeta(
          bucket: bucket,
          itemType: 'Convenio',
          dueDate: installment.dueDate,
          agreementLabel: finSupplierAgreementStatusLabel(agreement.status),
          amountSuggested: amount,
          hasAgreement: true,
          paymentStage: provider.paymentStage,
          providerManualPriority: provider.manualPriority,
          providerPriorityNote: provider.priorityNote,
          invoiceManualPriority: 'NORMAL',
          invoicePriorityNote: '',
          today: today,
        );
        items.add(
          _PaymentCenterItem(
            providerId: provider.companyId,
            providerName: provider.companyName,
            bucket: priority.bucket,
            itemType: 'Convenio',
            sourceLabel: sourceLabel,
            dueDate: installment.dueDate,
            agreementLabel:
                '${finSupplierAgreementTypeLabel(agreement.agreementType)} · ${finSupplierAgreementFrequencyLabel(agreement.frequency)} · ${finSupplierAgreementStatusLabel(agreement.status)}',
            amountSuggested: amount,
            amountTotal: agreement.remainingAmount,
            targetCompany: agreement.targetCompany,
            targetBranch: agreement.targetBranch,
            urgencyLabel: bucket.label,
            recommendation: dueDate.isBefore(today)
                ? agreement.agreementType == 'POR_FACTURAS'
                      ? 'Cumplir facturas comprometidas'
                      : 'Cumplir convenio vencido'
                : agreement.agreementType == 'POR_FACTURAS'
                ? 'Respetar facturas comprometidas'
                : 'Respetar pago comprometido',
            decisionReasons: priority.reasons,
            priorityScore: priority.score,
            allowPartialPayment: agreement.agreementType == 'POR_MONTO',
            linkedAgreementId: agreement.id,
          ),
        );
      }
    }

    for (final invoice in invoices.where((row) => row.status != 'PAGADA')) {
      final provider =
          providerById[invoice.providerId] ??
          providerByAlias[normalizeFinanzasCompanyAliasKey(
            invoice.providerNameSnapshot,
          )];
      if (provider == null) continue;
      final dueDate = invoice.dueDate;
      final dueOnly = dueDate == null ? null : DateUtils.dateOnly(dueDate);
      final hasAgreement = agreementProviderIds.contains(provider.companyId);
      final bucket = dueOnly != null && dueOnly.isBefore(today)
          ? _PaymentCenterTab.urgente
          : hasAgreement
          ? _PaymentCenterTab.recomendado
          : invoice.status == 'VENCIDA' || provider.paymentStage == 'ATRASADO'
          ? _PaymentCenterTab.urgente
          : provider.paymentStage == 'PAGO_SEMANAL'
          ? _PaymentCenterTab.recomendado
          : _PaymentCenterTab.postergable;
      final priority = _buildPriorityMeta(
        bucket: bucket,
        itemType: 'Factura',
        dueDate: dueDate,
        agreementLabel: hasAgreement ? 'Con convenio' : 'Sin convenio',
        amountSuggested: invoice.balanceAmount,
        hasAgreement: hasAgreement,
        paymentStage: provider.paymentStage,
        providerManualPriority: provider.manualPriority,
        providerPriorityNote: provider.priorityNote,
        invoiceManualPriority: invoice.manualPriority,
        invoicePriorityNote: invoice.priorityNote,
        today: today,
      );
      items.add(
        _PaymentCenterItem(
          providerId: provider.companyId,
          providerName: provider.companyName,
          bucket: priority.bucket,
          itemType: 'Factura',
          sourceLabel: invoice.folio,
          dueDate: dueDate,
          agreementLabel: hasAgreement ? 'Con convenio' : 'Sin convenio',
          amountSuggested: invoice.balanceAmount,
          amountTotal: invoice.totalAmount,
          targetCompany: invoice.targetCompany,
          targetBranch: invoice.targetBranch,
          urgencyLabel: bucket.label,
          recommendation: hasAgreement
              ? 'No adelantar sin revisar convenio'
              : dueOnly != null && dueOnly.isBefore(today)
              ? 'Atender factura vencida'
              : provider.paymentStage == 'ATRASADO'
              ? 'Proveedor con urgencia de pago'
              : 'Pago negociable',
          decisionReasons: priority.reasons,
          priorityScore: priority.score,
          allowPartialPayment: false,
          linkedInvoiceId: invoice.id,
        ),
      );
    }

    final ticketAmountsByProvider = computeOpenGeneralAmountsByProvider(
      tickets: tickets,
      applications: ticketApplications,
    );

    for (final provider in providerById.values) {
      if (agreementProviderIds.contains(provider.companyId)) continue;
      final comprasId = _resolveComprasProviderId(
        provider,
        comprasProviderIdByAlias,
      );
      final openAmount = ticketAmountsByProvider[comprasId] ?? 0;
      if (openAmount <= 0.009) continue;
      if (provider.paymentStage == 'AL_CORRIENTE') continue;
      final target = _inferTarget(provider);
      final bucket = provider.paymentStage == 'ATRASADO'
          ? _PaymentCenterTab.urgente
          : _PaymentCenterTab.recomendado;
      final priority = _buildPriorityMeta(
        bucket: bucket,
        itemType: 'Saldo general',
        dueDate: null,
        agreementLabel: 'Sin convenio',
        amountSuggested: openAmount,
        hasAgreement: false,
        paymentStage: provider.paymentStage,
        providerManualPriority: provider.manualPriority,
        providerPriorityNote: provider.priorityNote,
        invoiceManualPriority: 'NORMAL',
        invoicePriorityNote: '',
        today: today,
      );
      items.add(
        _PaymentCenterItem(
          providerId: provider.companyId,
          providerName: provider.companyName,
          bucket: priority.bucket,
          itemType: 'Saldo general',
          sourceLabel: 'Cuenta abierta',
          dueDate: null,
          agreementLabel: 'Sin convenio',
          amountSuggested: openAmount,
          amountTotal: openAmount,
          targetCompany: target.$1,
          targetBranch: target.$2,
          urgencyLabel: bucket.label,
          recommendation: provider.paymentStage == 'ATRASADO'
              ? 'Proveedor urgente sin convenio'
              : 'Preparar siguiente abono',
          decisionReasons: priority.reasons,
          priorityScore: priority.score,
          allowPartialPayment: true,
        ),
      );
    }

    final bucketOrder = <_PaymentCenterTab, int>{
      _PaymentCenterTab.obligatorio: 0,
      _PaymentCenterTab.urgente: 1,
      _PaymentCenterTab.recomendado: 2,
      _PaymentCenterTab.postergable: 3,
    };
    items.sort((a, b) {
      final bucketCompare = (bucketOrder[a.bucket] ?? 99).compareTo(
        bucketOrder[b.bucket] ?? 99,
      );
      if (bucketCompare != 0) return bucketCompare;
      final aDue = a.dueDate ?? DateTime(2100);
      final bDue = b.dueDate ?? DateTime(2100);
      final dueCompare = aDue.compareTo(bDue);
      if (dueCompare != 0) return dueCompare;
      final scoreCompare = b.priorityScore.compareTo(a.priorityScore);
      if (scoreCompare != 0) return scoreCompare;
      return b.amountSuggested.compareTo(a.amountSuggested);
    });
    final decisions = optimizePaymentExecution(
      items: items
          .map(
            (item) => PaymentOptimizationSnapshot(
              id: '${item.providerId}|${item.itemType}|${item.sourceLabel}|${item.linkedInvoiceId ?? item.linkedAgreementId ?? item.linkedFixedPaymentId ?? ''}',
              accountKey: buildFinBankAccountKey(
                company: item.targetCompany,
                branch: item.targetBranch,
              ),
              bucketKey: switch (item.bucket) {
                _PaymentCenterTab.obligatorio => 'OBLIGATORIO',
                _PaymentCenterTab.urgente => 'URGENTE',
                _PaymentCenterTab.recomendado => 'RECOMENDADO',
                _PaymentCenterTab.postergable => 'POSTERGABLE',
              },
              itemType: item.itemType,
              amountSuggested: item.amountSuggested,
              allowPartialPayment: item.allowPartialPayment,
              priorityScore: item.priorityScore,
              dueDate: item.dueDate,
            ),
          )
          .toList(growable: false),
      balances: balances,
    );
    for (final item in items) {
      final key =
          '${item.providerId}|${item.itemType}|${item.sourceLabel}|${item.linkedInvoiceId ?? item.linkedAgreementId ?? item.linkedFixedPaymentId ?? ''}';
      final decision = decisions[key];
      if (decision == null) continue;
      item.availableBalance = decision.availableBalance;
      item.canPayNow = decision.canPayNow;
      item.executionDecision = switch (decision.decisionKey) {
        'PAGAR_COMPLETO' => _PaymentExecutionDecision.pagarCompleto,
        'ABONAR' => _PaymentExecutionDecision.abonar,
        _ => _PaymentExecutionDecision.esperar,
      };
      item.executionAmount = decision.executionAmount;
      item.executionSummary = decision.summary;
    }
    return items;
  }

  (String, String) _inferTarget(FinanzasCompanyDirectoryRecord provider) {
    final raw =
        '${provider.companyName} ${provider.linkedName} ${provider.location} ${provider.paymentNotes}'
            .toUpperCase();
    final company = raw.contains('VH') ? 'VH' : 'DICSA';
    final branch = raw.contains('MAZATLAN') ? 'MAZATLAN' : 'CELAYA';
    return (company, branch);
  }

  String _resolveComprasProviderId(
    FinanzasCompanyDirectoryRecord company,
    Map<String, String> comprasProviderIdByAlias,
  ) {
    if (company.source.trim().toUpperCase() == 'COMPRAS' &&
        company.companyId.startsWith('compras_')) {
      return company.companyId.substring('compras_'.length);
    }
    final aliasKey = normalizeFinanzasCompanyAliasKey(
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

  Future<void> _openFixedPayments() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasFixedPaymentsPage(instantOpen: true)),
    );
  }

  Future<void> _openFixedPaymentsForRow(_PaymentCenterItem row) async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: FinanzasFixedPaymentsPage(
          instantOpen: true,
          initialSelectedPaymentId: row.linkedFixedPaymentId,
        ),
      ),
    );
  }

  Future<void> _openBankExecutionForRow(_PaymentCenterItem row) async {
    if (!mounted) return;
    final preset = _buildBankLaunchPreset(row);
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: FinanzasBankAccountsPage(instantOpen: true, launchPreset: preset),
      ),
    );
  }

  FinanzasBankMovementLaunchPreset? _buildBankLaunchPreset(
    _PaymentCenterItem row,
  ) {
    if (row.itemType == 'Pago fijo' && row.linkedFixedPaymentId != null) {
      return FinanzasBankMovementLaunchPreset(
        sourceType: 'PAGO_FIJO',
        linkedFixedPaymentId: row.linkedFixedPaymentId,
        company: row.targetCompany,
        branch: row.targetBranch,
        counterpartyName: row.providerName,
        counterpartyCompanyId: row.providerId,
        category: 'GASTOS OPERATIVOS',
        reference: row.sourceLabel,
        comment: row.recommendation,
        creditAmount: 0,
        debitAmount: row.executionAmount > 0
            ? row.executionAmount
            : row.amountSuggested,
      );
    }
    if (row.itemType == 'Factura' && row.linkedInvoiceId != null) {
      return FinanzasBankMovementLaunchPreset(
        sourceType: 'COMPRA_FACTURA',
        linkedSupplierInvoiceId: row.linkedInvoiceId,
        company: row.targetCompany,
        branch: row.targetBranch,
        counterpartyName: row.providerName,
        counterpartyCompanyId: row.providerId,
        category: 'COMPRA DE MATERIAL',
        reference: row.sourceLabel,
        comment: row.recommendation,
        creditAmount: 0,
        debitAmount: row.executionAmount,
      );
    }
    if (row.itemType == 'Convenio' || row.itemType == 'Saldo general') {
      return FinanzasBankMovementLaunchPreset(
        sourceType: 'MANUAL',
        company: row.targetCompany,
        branch: row.targetBranch,
        counterpartyName: row.providerName,
        counterpartyCompanyId: row.providerId,
        category: 'COMPRA DE MATERIAL',
        reference: row.sourceLabel,
        comment: row.recommendation,
        creditAmount: 0,
        debitAmount: row.executionAmount,
      );
    }
    return null;
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
      case 'Pagos fijos':
        unawaited(_openFixedPayments());
        return;
      case 'Centro de pagos':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      case 'Dashboard Compras':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openComprasDashboard());
        return;
    }
  }

  String _money(double value) {
    final sign = value < 0 ? '-' : '';
    final absolute = value.abs().toStringAsFixed(2);
    final parts = absolute.split('.');
    final integer = parts.first;
    final decimal = parts.last;
    final buffer = StringBuffer();
    for (var i = 0; i < integer.length; i++) {
      final reversed = integer.length - i;
      buffer.write(integer[i]);
      if (reversed > 1 && reversed % 3 == 1) {
        buffer.write(',');
      }
    }
    return '$sign\$$buffer.$decimal';
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return '—';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final totalAvailable = _accountBalances.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final displayItems = _items;
    final totalSuggested = displayItems.fold<double>(
      0,
      (sum, row) => sum + row.amountSuggested,
    );
    final visualItemsByBucket = <_PaymentCenterTab, List<_PaymentCenterItem>>{
      for (final bucket in _PaymentCenterTab.values)
        bucket: displayItems
            .where((row) => row.bucket == bucket)
            .toList(growable: false),
    };
    final payableNowAmount = displayItems.fold<double>(
      0,
      (sum, row) => sum + (row.executionAmount > 0 ? row.executionAmount : 0),
    );
    final criticalCount = displayItems
        .where((row) => row.bucket == _PaymentCenterTab.obligatorio)
        .length;
    final urgentCount = displayItems
        .where((row) => row.bucket == _PaymentCenterTab.urgente)
        .length;
    final actionableCount = displayItems
        .where(
          (row) => row.executionDecision != _PaymentExecutionDecision.esperar,
        )
        .length;
    final coverageRatio = totalSuggested <= 0.009
        ? 1.0
        : (totalAvailable / totalSuggested).clamp(0.0, 1.0);
    final learningPending = _learningLogs
        .where((row) => row.status == 'PENDIENTE')
        .length;
    final learningRegistered = _learningLogs
        .where((row) => row.status == 'REGISTRADO')
        .length;
    final learningMatched = _learningLogs
        .where(
          (row) =>
              row.status == 'REGISTRADO' &&
              row.executedAction != null &&
              row.executedAction == row.suggestedAction,
        )
        .length;
    final learningMatchRatio = learningRegistered == 0
        ? 0.0
        : learningMatched / learningRegistered;
    return AreaThemeScope(
      tokens: finanzasAreaTokens,
      child: Material(
        color: Colors.transparent,
        child: AppShell(
          background: const _FinPaymentCenterBackground(),
          animateBody: !widget.instantOpen,
          wrapBodyInGlass: false,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => _FinCenterHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => const _FinPaymentCenterHeaderBrand(),
          trailingBuilder: (_, _) => _FinCenterHeaderButton(
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
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  const spacing = 10.0;
                                  final cardWidth =
                                      ((constraints.maxWidth - (spacing * 3)) /
                                              4)
                                          .clamp(250.0, 380.0);
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: cardWidth,
                                          child: _CenterMetricCard(
                                            label: 'Disponible total',
                                            value: _money(totalAvailable),
                                            subtitle:
                                                'Suma viva por cuentas bancarias',
                                            icon: Icons
                                                .account_balance_wallet_rounded,
                                            tone: finanzasAreaTokens
                                                .primaryStrong,
                                          ),
                                        ),
                                        const SizedBox(width: spacing),
                                        SizedBox(
                                          width: cardWidth,
                                          child: _CenterMetricCard(
                                            label: 'Pendientes',
                                            value: '${displayItems.length}',
                                            subtitle:
                                                '$criticalCount críticos · $urgentCount urgentes',
                                            icon: Icons.layers_rounded,
                                            tone: const Color(0xFFFFB36B),
                                          ),
                                        ),
                                        const SizedBox(width: spacing),
                                        SizedBox(
                                          width: cardWidth,
                                          child: _CenterMetricCard(
                                            label: 'Monto sugerido',
                                            value: _money(totalSuggested),
                                            subtitle:
                                                '$actionableCount salidas listas para revisión',
                                            icon: Icons.rule_folder_outlined,
                                            tone: const Color(0xFFFF7A1F),
                                          ),
                                        ),
                                        const SizedBox(width: spacing),
                                        SizedBox(
                                          width: cardWidth,
                                          child: _CenterMetricCard(
                                            label: 'Cobertura inmediata',
                                            value:
                                                '${(coverageRatio * 100).toStringAsFixed(0)}%',
                                            subtitle:
                                                'Pago ejecutable hoy: ${_money(payableNowAmount)}',
                                            icon: Icons.radar_rounded,
                                            tone: coverageRatio >= 0.85
                                                ? const Color(0xFF22C55E)
                                                : coverageRatio >= 0.55
                                                ? const Color(0xFFFFB36B)
                                                : const Color(0xFFEF4444),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 18),
                              Expanded(
                                child:
                                    _activeMode == _PaymentCenterMode.operacion
                                    ? (displayItems.isEmpty
                                          ? const _CenterEmptyPane(
                                              label:
                                                  'Sin pendientes por priorizar',
                                              subtitle:
                                                  'Cuando entren compromisos, urgencias o facturas priorizadas, aparecerán aquí.',
                                            )
                                          : LayoutBuilder(
                                              builder: (context, constraints) {
                                                const spacing = 12.0;
                                                final columnWidth =
                                                    ((constraints.maxWidth -
                                                                (spacing * 3)) /
                                                            4)
                                                        .clamp(280.0, 380.0);
                                                final totalWidth =
                                                    (columnWidth * 4) +
                                                    (spacing * 3);
                                                return SingleChildScrollView(
                                                  child: SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    child: SizedBox(
                                                      width:
                                                          totalWidth <
                                                              constraints
                                                                  .maxWidth
                                                          ? constraints.maxWidth
                                                          : totalWidth,
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          for (
                                                            var i = 0;
                                                            i <
                                                                _PaymentCenterTab
                                                                    .values
                                                                    .length;
                                                            i++
                                                          ) ...[
                                                            SizedBox(
                                                              width:
                                                                  columnWidth,
                                                              height: constraints
                                                                  .maxHeight,
                                                              child: _PaymentCenterPriorityColumn(
                                                                bucket:
                                                                    _PaymentCenterTab
                                                                        .values[i],
                                                                rows:
                                                                    visualItemsByBucket[_PaymentCenterTab
                                                                        .values[i]] ??
                                                                    const <
                                                                      _PaymentCenterItem
                                                                    >[],
                                                                moneyFormatter:
                                                                    _money,
                                                                dateFormatter:
                                                                    _dateLabel,
                                                                onOpenProviderAccounts:
                                                                    () =>
                                                                        _openProviderAccounts(),
                                                                onOpenBankAccounts:
                                                                    (row) =>
                                                                        _openBankExecutionForRow(
                                                                          row,
                                                                        ),
                                                                onOpenFixedPayments:
                                                                    (row) =>
                                                                        _openFixedPaymentsForRow(
                                                                          row,
                                                                        ),
                                                              ),
                                                            ),
                                                            if (i !=
                                                                _PaymentCenterTab
                                                                        .values
                                                                        .length -
                                                                    1)
                                                              const SizedBox(
                                                                width: spacing,
                                                              ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ))
                                    : _PaymentCenterLearningView(
                                        logs: _learningLogs,
                                        pendingCount: learningPending,
                                        registeredCount: learningRegistered,
                                        matchRatio: learningMatchRatio,
                                        moneyFormatter: _money,
                                        dateFormatter: _dateLabel,
                                        onCaptureSnapshot:
                                            _captureLearningSnapshot,
                                        onRegisterDecision:
                                            _registerLearningDecision,
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
                      child: _FinPaymentCenterSidePanel(
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

class _PaymentCenterItem {
  final String providerId;
  final String providerName;
  final _PaymentCenterTab bucket;
  final String itemType;
  final String sourceLabel;
  final DateTime? dueDate;
  final String agreementLabel;
  final double amountSuggested;
  final double amountTotal;
  final String targetCompany;
  final String targetBranch;
  final String urgencyLabel;
  final String recommendation;
  final List<String> decisionReasons;
  final int priorityScore;
  final bool allowPartialPayment;
  final String? linkedInvoiceId;
  final String? linkedFixedPaymentId;
  final String? linkedAgreementId;
  bool isPreviewMock = false;
  double availableBalance = 0;
  bool canPayNow = false;
  _PaymentExecutionDecision executionDecision =
      _PaymentExecutionDecision.esperar;
  double executionAmount = 0;
  String executionSummary = '';

  _PaymentCenterItem({
    required this.providerId,
    required this.providerName,
    required this.bucket,
    required this.itemType,
    required this.sourceLabel,
    required this.dueDate,
    required this.agreementLabel,
    required this.amountSuggested,
    required this.amountTotal,
    required this.targetCompany,
    required this.targetBranch,
    required this.urgencyLabel,
    required this.recommendation,
    required this.decisionReasons,
    required this.priorityScore,
    required this.allowPartialPayment,
    this.linkedInvoiceId,
    this.linkedFixedPaymentId,
    this.linkedAgreementId,
  });
}

class _CenterMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color tone;

  const _CenterMetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return FinanzasGlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      borderRadius: BorderRadius.circular(24),
      fillColor: const Color(0x10FFFFFF),
      borderColor: Colors.white.withValues(alpha: 0.24),
      glowColor: Colors.white.withValues(alpha: 0.06),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.18),
      child: SizedBox(
        height: 170,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tone.withValues(alpha: 0.10),
                border: Border.all(color: tone.withValues(alpha: 0.26)),
              ),
              child: Icon(icon, color: tone, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: tokens.badgeText,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tone,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.08),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: tone == const Color(0xFF22C55E)
                    ? 1
                    : tone == const Color(0xFFFFB36B)
                    ? 0.58
                    : tone == const Color(0xFFEF4444)
                    ? 0.32
                    : 0.72,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        tone.withValues(alpha: 0.58),
                        tone.withValues(alpha: 0.92),
                      ],
                    ),
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

class _PaymentCenterLearningView extends StatelessWidget {
  final List<FinanzasPaymentLearningRecord> logs;
  final int pendingCount;
  final int registeredCount;
  final double matchRatio;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final Future<void> Function() onCaptureSnapshot;
  final Future<void> Function(FinanzasPaymentLearningRecord row)
  onRegisterDecision;

  const _PaymentCenterLearningView({
    required this.logs,
    required this.pendingCount,
    required this.registeredCount,
    required this.matchRatio,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onCaptureSnapshot,
    required this.onRegisterDecision,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Capa de aprendizaje',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onCaptureSnapshot,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Capturar corte actual'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Aquí se registran las sugerencias del motor y la decisión humana real para entrenar mejor la lógica sin tocar el flujo operativo.',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: kFinanzasMutedInk,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _CenterMetricCard(
              label: 'Pendientes por registrar',
              value: '$pendingCount',
              subtitle: 'Cortes capturados pendientes de decisión humana',
              icon: Icons.pending_actions_rounded,
              tone: const Color(0xFFFFB36B),
            ),
            _CenterMetricCard(
              label: 'Decisiones registradas',
              value: '$registeredCount',
              subtitle: 'Historial ya validado contra la operación',
              icon: Icons.fact_check_outlined,
              tone: const Color(0xFF22C55E),
            ),
            _CenterMetricCard(
              label: 'Coincidencia con sistema',
              value: '${(matchRatio * 100).toStringAsFixed(0)}%',
              subtitle: 'Qué tanto coincide el motor con la decisión real',
              icon: Icons.hub_outlined,
              tone: finanzasAreaTokens.primaryStrong,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: logs.isEmpty
              ? const _CenterEmptyPane(
                  label: 'Aún no hay cortes de aprendizaje',
                  subtitle:
                      'Captura un corte actual para empezar a guardar recomendaciones y decisiones humanas.',
                )
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: tokens.border.withValues(alpha: 0.82),
                    ),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    itemBuilder: (context, index) {
                      final row = logs[index];
                      return _PaymentLearningRow(
                        row: row,
                        moneyFormatter: moneyFormatter,
                        dateFormatter: dateFormatter,
                        onRegisterDecision: () => onRegisterDecision(row),
                      );
                    },
                    separatorBuilder: (_, separatorIndex) => Divider(
                      height: 1,
                      thickness: 1,
                      color: tokens.border.withValues(alpha: 0.8),
                    ),
                    itemCount: logs.length,
                  ),
                ),
        ),
      ],
    );
  }
}

class _PaymentLearningRow extends StatelessWidget {
  final FinanzasPaymentLearningRecord row;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final Future<void> Function() onRegisterDecision;

  const _PaymentLearningRow({
    required this.row,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onRegisterDecision,
  });

  String _displayAction(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'PAGAR_COMPLETO':
        return 'Pagar completo';
      case 'ABONAR':
        return 'Abonar';
      case 'ESPERAR':
        return 'Esperar';
      default:
        return raw.trim().isEmpty ? '—' : raw.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final statusTone = row.status == 'REGISTRADO'
        ? const Color(0xFF0F766E)
        : const Color(0xFF8B5E00);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.providerName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: tokens.primaryStrong,
                  ),
                ),
              ),
              _TinyChip(label: row.bucket, tone: statusTone),
              const SizedBox(width: 8),
              _TinyChip(label: row.status, tone: statusTone),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniInfoPill(label: 'Tipo', value: row.itemType),
              _MiniInfoPill(label: 'Vence', value: dateFormatter(row.dueDate)),
              _MiniInfoPill(
                label: 'Sugerido',
                value:
                    '${_displayAction(row.suggestedAction)} · ${moneyFormatter(row.suggestedAmount)}',
              ),
              _MiniInfoPill(
                label: 'Objetivo',
                value: '${row.targetCompany} ${row.targetBranch}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            row.sourceLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: kFinanzasMutedInk,
            ),
          ),
          if (row.recommendation.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              row.recommendation,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  row.executedAction == null
                      ? 'Sin decisión registrada todavía.'
                      : 'Ejecutado: ${_displayAction(row.executedAction!)}${row.executedAmount == null ? '' : ' · ${moneyFormatter(row.executedAmount!)}'}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: tokens.primaryStrong,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onRegisterDecision,
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: Text(
                  row.status == 'REGISTRADO'
                      ? 'Editar decisión'
                      : 'Registrar decisión',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCenterPriorityColumn extends StatelessWidget {
  final _PaymentCenterTab bucket;
  final List<_PaymentCenterItem> rows;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final Future<void> Function() onOpenProviderAccounts;
  final Future<void> Function(_PaymentCenterItem row) onOpenBankAccounts;
  final Future<void> Function(_PaymentCenterItem row) onOpenFixedPayments;

  const _PaymentCenterPriorityColumn({
    required this.bucket,
    required this.rows,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onOpenProviderAccounts,
    required this.onOpenBankAccounts,
    required this.onOpenFixedPayments,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final tone = _paymentCenterBucketTone(bucket);
    final total = rows.fold<double>(0, (sum, row) => sum + row.amountSuggested);
    final previewCount = rows.where((row) => row.isPreviewMock).length;
    return FinanzasGlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      borderRadius: BorderRadius.circular(30),
      fillColor: const Color(0x08FFFFFF),
      borderColor: Colors.white.withValues(alpha: 0.16),
      glowColor: Colors.white.withValues(alpha: 0.04),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tone.withValues(alpha: 0.12),
                  border: Border.all(color: tone.withValues(alpha: 0.26)),
                ),
                child: Icon(
                  _paymentCenterBucketIcon(bucket),
                  color: tone,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        bucket.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: tokens.onGlass,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _paymentCenterBucketSubtitle(bucket),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: kFinanzasMutedInk,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        moneyFormatter(total),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: tone,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Monto visible del bucket',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.badgeText,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _TinyChip(label: '${rows.length}', tone: tone),
                  if (previewCount > 0) ...[
                    const SizedBox(height: 6),
                    _PreviewLabelChip(label: '$previewCount preview'),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: rows.isEmpty
                ? const _CenterEmptyMiniColumn()
                : ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      scrollbars: false,
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return _PaymentCenterCompactCard(
                          row: row,
                          tone: tone,
                          moneyFormatter: moneyFormatter,
                          dateFormatter: dateFormatter,
                          onOpenProviderAccounts: onOpenProviderAccounts,
                          onOpenBankAccounts: () => onOpenBankAccounts(row),
                          onOpenFixedPayments: () => onOpenFixedPayments(row),
                          featured: index == 0,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCenterCompactCard extends StatelessWidget {
  final _PaymentCenterItem row;
  final Color tone;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final Future<void> Function() onOpenProviderAccounts;
  final Future<void> Function() onOpenBankAccounts;
  final Future<void> Function() onOpenFixedPayments;
  final bool featured;

  const _PaymentCenterCompactCard({
    required this.row,
    required this.tone,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onOpenProviderAccounts,
    required this.onOpenBankAccounts,
    required this.onOpenFixedPayments,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        featured ? 16 : 14,
        featured ? 16 : 14,
        featured ? 16 : 14,
        featured ? 16 : 14,
      ),
      decoration: BoxDecoration(
        color: featured ? const Color(0xD4141920) : const Color(0xB3131820),
        borderRadius: BorderRadius.circular(featured ? 24 : 22),
        border: Border.all(
          color: row.isPreviewMock
              ? tone.withValues(alpha: 0.26)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: featured ? 18 : 12,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: featured ? 0.16 : 0.10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  row.providerName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: featured ? 18 : 16,
                    fontWeight: FontWeight.w900,
                    color: tokens.onGlass,
                    height: 1.12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _TinyChip(label: row.itemType, tone: tone),
                  if (row.isPreviewMock) ...[
                    const SizedBox(height: 6),
                    const _PreviewLabelChip(label: 'Preview'),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniInfoPill(label: 'Vence', value: dateFormatter(row.dueDate)),
              _MiniInfoPill(
                label: 'Cantidad',
                value: row.executionAmount > 0.009
                    ? moneyFormatter(row.executionAmount)
                    : moneyFormatter(row.amountSuggested),
              ),
              _MiniInfoPill(
                label: 'Cuenta',
                value: '${row.targetCompany} ${row.targetBranch}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            row.sourceLabel,
            maxLines: featured ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: kFinanzasMutedInk,
              height: 1.3,
            ),
          ),
          if (row.recommendation.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              row.recommendation,
              maxLines: featured ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: tokens.badgeText,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyChip(label: row.executionDecision.label, tone: tone),
              if (row.decisionReasons.isNotEmpty)
                _TinyChip(label: row.decisionReasons.first, tone: tone),
              if (row.canPayNow)
                const _PreviewLabelChip(label: 'Caja disponible'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: row.itemType == 'Pago fijo'
                    ? onOpenFixedPayments
                    : onOpenProviderAccounts,
                icon: Icon(
                  row.itemType == 'Pago fijo'
                      ? Icons.receipt_long_outlined
                      : Icons.account_tree_outlined,
                  size: 18,
                ),
                label: Text(row.itemType == 'Pago fijo' ? 'Ver' : 'Cuenta'),
              ),
              FilledButton.icon(
                onPressed: onOpenBankAccounts,
                icon: const Icon(Icons.account_balance_outlined, size: 18),
                label: Text(switch (row.executionDecision) {
                  _PaymentExecutionDecision.pagarCompleto => 'Pagar',
                  _PaymentExecutionDecision.abonar => 'Abonar',
                  _PaymentExecutionDecision.esperar => 'Revisar',
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniInfoPill extends StatelessWidget {
  final String label;
  final String value;

  const _MiniInfoPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: tokens.surfaceTint.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border.withValues(alpha: 0.84)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: tokens.badgeText,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterEmptyMiniColumn extends StatelessWidget {
  const _CenterEmptyMiniColumn();

  @override
  Widget build(BuildContext context) {
    return FinanzasGlassPanel(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      borderRadius: BorderRadius.circular(20),
      fillColor: const Color(0xA3121820),
      child: Text(
        'Sin pendientes en esta prioridad.',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: kFinanzasMutedInk,
        ),
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  final String label;
  final Color tone;

  const _TinyChip({required this.label, required this.tone});

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

class _PreviewLabelChip extends StatelessWidget {
  final String label;

  const _PreviewLabelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: kFinanzasMutedInk,
        ),
      ),
    );
  }
}

class _CenterEmptyPane extends StatelessWidget {
  final String label;
  final String subtitle;

  const _CenterEmptyPane({required this.label, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Center(
      child: Container(
        width: 460,
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
            Icon(Icons.balance_outlined, size: 34, color: tokens.primaryStrong),
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

class _FinPaymentCenterBackground extends StatelessWidget {
  const _FinPaymentCenterBackground();

  @override
  Widget build(BuildContext context) => const FinanzasAreaBackground();
}

class _FinPaymentCenterHeaderBrand extends StatelessWidget {
  const _FinPaymentCenterHeaderBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
          ),
          child: const Center(child: DicsaLogoD(size: 48)),
        ),
        const SizedBox(width: 30),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Centro de pagos',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: kFinanzasInk,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Motor preliminar de prioridades y capacidad',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FinCenterHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _FinCenterHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_FinCenterHeaderButton> createState() => _FinCenterHeaderButtonState();
}

class _FinCenterHeaderButtonState extends State<_FinCenterHeaderButton> {
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
                  color: Colors.white.withValues(
                    alpha: highlighted ? 0.56 : 0.42,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: tokens.primaryStrong.withValues(
                      alpha: highlighted ? 0.18 : 0.10,
                    ),
                    blurRadius: highlighted ? 24 : 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, size: 20, color: tokens.primary),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: tokens.primary,
                        letterSpacing: 0.1,
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

class _FinPaymentCenterSidePanel extends StatelessWidget {
  final bool canReturnToDirection;
  final bool canAccessComprasArea;
  final void Function(String label) onNavigate;

  const _FinPaymentCenterSidePanel({
    required this.canReturnToDirection,
    required this.canAccessComprasArea,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      margin: const EdgeInsets.fromLTRB(28, 56, 0, 56),
      child: FinanzasAreaSidePanel(
        currentLabel: 'Centro de pagos',
        canReturnToDirection: canReturnToDirection,
        canAccessComprasArea: canAccessComprasArea,
        onNavigate: onNavigate,
      ),
    );
  }
}

Color _paymentCenterBucketTone(_PaymentCenterTab bucket) {
  switch (bucket) {
    case _PaymentCenterTab.obligatorio:
      return const Color(0xFFEF4444);
    case _PaymentCenterTab.urgente:
      return const Color(0xFFFFB36B);
    case _PaymentCenterTab.recomendado:
      return const Color(0xFF22C55E);
    case _PaymentCenterTab.postergable:
      return const Color(0xFF94A3B8);
  }
}

IconData _paymentCenterBucketIcon(_PaymentCenterTab bucket) {
  switch (bucket) {
    case _PaymentCenterTab.obligatorio:
      return Icons.warning_amber_rounded;
    case _PaymentCenterTab.urgente:
      return Icons.flash_on_rounded;
    case _PaymentCenterTab.recomendado:
      return Icons.check_circle_outline_rounded;
    case _PaymentCenterTab.postergable:
      return Icons.schedule_rounded;
  }
}

String _paymentCenterBucketSubtitle(_PaymentCenterTab bucket) {
  switch (bucket) {
    case _PaymentCenterTab.obligatorio:
      return 'Compromisos que ya no deberían esperar.';
    case _PaymentCenterTab.urgente:
      return 'Salidas sensibles para esta ventana de caja.';
    case _PaymentCenterTab.recomendado:
      return 'Pagos programables con buena lectura operativa.';
    case _PaymentCenterTab.postergable:
      return 'Elementos visibles sin presión inmediata.';
  }
}
