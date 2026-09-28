import 'dart:math' as math;

import '../../management_reports/finance_weekly_budget_analysis.dart';
import '../expected_income/expected_income_models.dart';
import '../operating_program/operating_program_models.dart';

const projectionPaymentTypes = {
  'EFECTIVO': 'Efectivo',
  'FISCAL': 'Fiscal',
  'SIN_CLASIFICAR': 'Sin clasificar',
};

/// Amounts are cents. These are estimates, never ledger movements.
class ProjectedPayment {
  final String id, source, payee, reference, account, paymentType, notes;
  final DateTime date;
  final int amount, available;
  final bool included;
  // Retain Finance IDs so incorporating new obligations cannot restore a
  // payment deliberately removed from this week. Source records are untouched.
  final bool removed;
  final bool paymentTypeAutomatic;

  /// Only an explicit edit, exclusion or deletion overrides Friday selection.
  final bool selectionAutomatic;
  final String? warning;
  const ProjectedPayment({
    required this.id,
    required this.source,
    required this.payee,
    required this.reference,
    required this.account,
    required this.date,
    required this.amount,
    required this.available,
    this.included = true,
    this.removed = false,
    this.paymentType = 'SIN_CLASIFICAR',
    this.paymentTypeAutomatic = false,
    this.selectionAutomatic = false,
    this.notes = '',
    this.warning,
  });
  int get total => included && !removed ? amount : 0;
  ProjectedPayment copyWith({
    DateTime? date,
    int? amount,
    int? available,
    bool? included,
    bool? removed,
    String? paymentType,
    bool? paymentTypeAutomatic,
    bool? selectionAutomatic,
    String? notes,
    String? warning,
  }) => ProjectedPayment(
    id: id,
    source: source,
    payee: payee,
    reference: reference,
    account: account,
    date: date ?? this.date,
    amount: amount ?? this.amount,
    available: available ?? this.available,
    included: included ?? this.included,
    removed: removed ?? this.removed,
    paymentType: paymentType ?? this.paymentType,
    paymentTypeAutomatic: paymentTypeAutomatic ?? this.paymentTypeAutomatic,
    selectionAutomatic: selectionAutomatic ?? this.selectionAutomatic,
    notes: notes ?? this.notes,
    warning: warning ?? this.warning,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'payee': payee,
    'reference': reference,
    'account': account,
    'date': programDate(date),
    'amount': amount,
    'available': available,
    'included': included,
    'removed': removed,
    'payment_type': paymentType,
    'payment_type_automatic': paymentTypeAutomatic,
    'selection_automatic': selectionAutomatic,
    'notes': notes,
  };
  factory ProjectedPayment.fromJson(Map<String, dynamic> j) => ProjectedPayment(
    id: j['id'] as String,
    source: j['source'] as String,
    payee: j['payee'] as String,
    reference: j['reference'] as String,
    account: j['account'] as String,
    date: DateTime.parse(j['date'] as String),
    amount: (j['amount'] as num).toInt(),
    available: (j['available'] as num).toInt(),
    included: j['included'] as bool,
    removed: j['removed'] as bool? ?? false,
    paymentType: j['payment_type'] as String,
    // Legacy, unclassified rows had no manual choice to preserve.
    paymentTypeAutomatic:
        j['payment_type_automatic'] as bool? ??
        (j['source'] != 'manual' && j['payment_type'] == 'SIN_CLASIFICAR'),
    // Previously imported zero candidates could never be selected/excluded
    // through the checkbox. Preserve other legacy rows conservatively.
    selectionAutomatic:
        j['selection_automatic'] as bool? ??
        (j['source'] != 'manual' &&
            j['removed'] != true &&
            j['included'] == false &&
            (j['amount'] as num) == 0 &&
            (j['notes'] as String).trim().isEmpty),
    notes: j['notes'] as String,
  );
}

class MenudeoExpenseSettings {
  final bool included;
  final int? purchases, expenses;
  const MenudeoExpenseSettings({
    this.included = true,
    this.purchases,
    this.expenses,
  });
  factory MenudeoExpenseSettings.fromJson(Map<String, dynamic> j) =>
      MenudeoExpenseSettings(
        included: j['included'] as bool? ?? true,
        purchases: (j['purchases'] as num?)?.toInt(),
        expenses: (j['expenses'] as num?)?.toInt(),
      );
  Map<String, dynamic> toJson() => {
    'included': included,
    'purchases': purchases,
    'expenses': expenses,
  };
}

class WeeklyExpensePlan {
  final MenudeoExpenseSettings menudeo;

  /// Derived from the current history snapshot; never persisted as Finance rows.
  final List<ProjectedPayment> menudeoPayments;
  final List<String> menudeoWarnings;
  final DateTime week;
  final int revision;
  final List<ProjectedPayment> payments;
  final int? openingCash, openingFiscal;
  final bool generated;
  const WeeklyExpensePlan({
    this.menudeo = const MenudeoExpenseSettings(),
    this.menudeoPayments = const [],
    this.menudeoWarnings = const [],
    required this.week,
    this.revision = 0,
    this.payments = const [],
    this.openingCash,
    this.openingFiscal,
    this.generated = false,
  });
  Iterable<ProjectedPayment> get activePayments =>
      payments.where((r) => !r.removed);
  Iterable<ProjectedPayment> get scheduledPayments => [
    ...activePayments,
    ...menudeoPayments,
  ].where((r) => r.included && !r.removed);
  int get total => scheduledPayments.fold(0, (sum, r) => sum + r.amount);
  int totalForType(String type) => scheduledPayments
      .where((r) => r.paymentType == type)
      .fold(0, (sum, r) => sum + r.amount);
  WeeklyExpensePlan copyWith({
    MenudeoExpenseSettings? menudeo,
    List<ProjectedPayment>? menudeoPayments,
    List<String>? menudeoWarnings,
    List<ProjectedPayment>? payments,
    int? openingCash,
    int? openingFiscal,
    bool? generated,
  }) => WeeklyExpensePlan(
    menudeo: menudeo ?? this.menudeo,
    menudeoPayments: menudeoPayments ?? this.menudeoPayments,
    menudeoWarnings: menudeoWarnings ?? this.menudeoWarnings,
    week: week,
    revision: revision,
    payments: payments ?? this.payments,
    openingCash: openingCash ?? this.openingCash,
    openingFiscal: openingFiscal ?? this.openingFiscal,
    generated: generated ?? this.generated,
  );
  factory WeeklyExpensePlan.fromJson(Map<String, dynamic> j) =>
      WeeklyExpensePlan(
        menudeo: MenudeoExpenseSettings.fromJson(
          Map<String, dynamic>.from(j['menudeo_settings'] as Map? ?? {}),
        ),
        week: DateTime.parse(j['week_start'] as String),
        revision: j['revision'] as int,
        payments: (j['payments'] as List)
            .map((v) => ProjectedPayment.fromJson(Map<String, dynamic>.from(v)))
            .toList(),
        openingCash: (j['opening_cash'] as num?)?.toInt(),
        openingFiscal: (j['opening_fiscal'] as num?)?.toInt(),
        generated: j['generated'] as bool,
      );
}

/// Reuses exactly the Friday selection rules, anchored to the displayed week.
List<ProjectedPayment> paymentProposal(FinanceWeeklyBudgetAnalysis analysis) {
  final week = analysis.period.start;
  DateTime date(DateTime? due) => due == null || due.isBefore(week)
      ? week
      : due.isAfter(analysis.period.end)
      ? analysis.period.end
      : due;
  final agreementById = {for (final r in analysis.source.agreements) r.id: r};
  final agreementInvoiceIds = {
    for (final link in analysis.source.agreementLinks)
      if (agreementById[link.agreementId] case final agreement?)
        if (agreement.remainingAmount > 0.009 &&
            ![
              'CANCELADO',
              'CUMPLIDO',
            ].contains(agreement.status.trim().toUpperCase()))
          link.invoiceId,
  };
  final agreementByInstallment = {
    for (final r in analysis.source.installments) r.id: r.agreementId,
  };
  String agreementType(String id) {
    final agreementId = agreementByInstallment[id] ?? id;
    return agreementById[agreementId]?.agreementType == 'POR_FACTURAS'
        ? 'FISCAL'
        : 'SIN_CLASIFICAR';
  }

  final invoicedTickets = analysis.source.invoiceTickets
      .map((r) => r.ticketId)
      .toSet();
  final applied = <String, int>{};
  for (final r in analysis.source.ticketApplications) {
    final day = DateTime(r.appliedAt.year, r.appliedAt.month, r.appliedAt.day);
    if (day.isAfter(analysis.period.asOf)) continue;
    applied.update(
      r.ticketId,
      (v) => v + (r.appliedAmount * 100).round(),
      ifAbsent: () => (r.appliedAmount * 100).round(),
    );
  }
  final agreementProviders = analysis.source.agreements
      .where(
        (r) =>
            r.agreementType == 'POR_MONTO' &&
            r.remainingAmount > 0.009 &&
            !['CANCELADO', 'CUMPLIDO'].contains(r.status),
      )
      .map((r) => r.providerId)
      .toSet();
  return [
    for (final r in analysis.commitments)
      ProjectedPayment(
        id: '${r.fixed ? 'fixed' : 'agreement'}:${r.id}',
        source: r.fixed ? 'fixed' : 'agreement',
        payee: r.label,
        reference: r.reference,
        account: r.account,
        date: date(r.dueDate),
        amount: r.proposed,
        available: r.amount,
        included: r.proposed > 0,
        paymentType: r.fixed
            ? switch (analysis.source.fixedPayments
                  .firstWhere((p) => p.id == r.id)
                  .executionMethod) {
                'EFECTIVO' => 'EFECTIVO',
                'BANCO' => 'FISCAL',
                _ => 'SIN_CLASIFICAR',
              }
            : agreementType(r.id),
        paymentTypeAutomatic: true,
        selectionAutomatic: true,
        warning: r.fixed
            ? null
            : 'Convenio: confirmar importe y fecha antes de incluir.',
      ),
    for (final r in analysis.invoices)
      ProjectedPayment(
        id: 'invoice:${r.invoice.id}',
        source: 'invoice',
        payee: r.supplier,
        reference: 'Factura ${r.invoice.folio}',
        account: r.account,
        date: date(r.invoice.dueDate),
        amount: r.proposed,
        included: r.proposed > 0,
        available:
            r.invoice.status.trim().toUpperCase() == 'CONVENIO' ||
                agreementInvoiceIds.contains(r.invoice.id)
            ? 0
            : r.balance,
        warning: r.reviewReason,
        paymentType: 'FISCAL',
        paymentTypeAutomatic: true,
        selectionAutomatic: true,
      ),
    // Tickets are separate review candidates; the Friday invoice selection is
    // unchanged. Linked/invoiced tickets must never duplicate invoice debt.
    for (final r in analysis.source.tickets)
      if (r.facturaStatus != 'FACTURADO' &&
          !invoicedTickets.contains(r.id) &&
          !['PAGADO', 'CANCELADO'].contains(r.pagoStatus) &&
          !r.date.isAfter(analysis.period.asOf) &&
          !r.date.isAfter(analysis.period.end) &&
          (r.amount * 100).round() - (applied[r.id] ?? 0) > 0)
        ProjectedPayment(
          id: 'ticket:${r.id}',
          source: 'ticket',
          payee: r.providerNameSnapshot.trim().isEmpty
              ? 'Sin proveedor'
              : r.providerNameSnapshot,
          reference:
              'Ticket ${r.ticket} · ${r.facturaStatus == 'SIN_FACTURA' ? 'Sin factura' : 'Pendiente de facturar'}',
          account: '',
          date: week,
          amount: 0,
          included: false,
          available: agreementProviders.contains(r.providerId)
              ? 0
              : ((r.amount * 100).round() - (applied[r.id] ?? 0)).clamp(
                  0,
                  (r.amount * 100).round(),
                ),
          paymentType: r.facturaStatus == 'SIN_FACTURA'
              ? 'EFECTIVO'
              : 'SIN_CLASIFICAR',
          paymentTypeAutomatic: true,
          selectionAutomatic: true,
          warning: agreementProviders.contains(r.providerId)
              ? 'Proveedor con convenio por monto; revisar el convenio para evitar duplicar el pago.'
              : r.facturaStatus == 'SIN_FACTURA'
              ? 'Definir importe y fecha para programar el ticket.'
              : 'Pendiente de facturar: confirmar documento antes de programar.',
        ),
  ];
}

/// A paid/cancelled obligation cannot be resurrected by a saved projection.
/// New obligations are left for review; a refresh never resets manual choices.
List<ProjectedPayment> reconcilePayments(
  List<ProjectedPayment> saved,
  List<ProjectedPayment> current,
) {
  final byId = {for (final r in current) r.id: r};
  return [
    for (final r in saved)
      if (r.source == 'manual' || r.removed)
        r
      else if (byId[r.id] case final live?)
        ProjectedPayment(
          id: r.id,
          source: r.source,
          payee: live.payee,
          reference: live.reference,
          account: live.account,
          date: r.date,
          amount: math.min(r.amount, live.available),
          available: live.available,
          included: r.included && live.available > 0,
          paymentType: r.paymentTypeAutomatic
              ? live.paymentType
              : r.paymentType,
          paymentTypeAutomatic: r.paymentTypeAutomatic,
          selectionAutomatic: r.selectionAutomatic,
          notes: r.notes,
          warning: live.available == 0 && live.warning != null
              ? live.warning
              : r.amount > live.available
              ? 'Importe ajustado al saldo pendiente actual.'
              : live.warning,
        )
      else
        r.copyWith(
          amount: 0,
          available: 0,
          included: false,
          warning: 'Ya no está pendiente en Finanzas; excluido del flujo.',
        ),
  ];
}

/// Re-run Friday selection for automatic candidates, including existing zero
/// rows. Explicit decisions always stay intact.
List<ProjectedPayment> incorporateFinanceProposal(
  List<ProjectedPayment> saved,
  List<ProjectedPayment> current,
) {
  final byId = {for (final r in current) r.id: r};
  final ids = saved.map((r) => r.id).toSet();
  return [
    for (final r in reconcilePayments(saved, current))
      if (r.source != 'manual' &&
          !r.removed &&
          r.selectionAutomatic &&
          byId.containsKey(r.id))
        byId[r.id]!
      else
        r,
    for (final r in current)
      if (!ids.contains(r.id)) r,
  ];
}

/// Explicitly restore Finance's current recommendation, including payments
/// previously excluded or removed. Manual expenses belong to the user and stay.
List<ProjectedPayment> resetFinanceProposal(
  List<ProjectedPayment> saved,
  List<ProjectedPayment> current,
) => [
  ...current,
  for (final r in saved)
    if (r.source == 'manual') r,
];

class WeeklyCashFlow {
  final IncomeTotals income;
  final WeeklyExpensePlan plan;
  WeeklyCashFlow(this.income, this.plan);
  int expense(String type) => plan.totalForType(type);
  int get expenses => plan.total;
  int get net => income.total - expenses;
  int? get opening => plan.openingCash == null || plan.openingFiscal == null
      ? null
      : plan.openingCash! + plan.openingFiscal!;
  int? get closing => opening == null ? null : opening! + net;
  bool get classified =>
      (income.byType['MIXTO'] ?? 0) == 0 && expense('SIN_CLASIFICAR') == 0;
  int? closingFor(String type) {
    final start = type == 'EFECTIVO' ? plan.openingCash : plan.openingFiscal;
    return start == null || !classified
        ? null
        : start + (income.byType[type] ?? 0) - expense(type);
  }
}
