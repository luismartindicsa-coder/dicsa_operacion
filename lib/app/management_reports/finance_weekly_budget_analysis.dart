import 'dart:math' as math;

import '../finanzas/finanzas_bank_accounts_store.dart';
import '../finanzas/finanzas_fixed_payments_store.dart';
import '../finanzas/finanzas_provider_accounts_store.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _add(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
int _cents(num value) {
  if (!value.isFinite) throw StateError('Importe financiero no válido.');
  return (value * 100).round();
}

String _normalized(String s) => s
    .trim()
    .toUpperCase()
    .replaceAll('Ó', 'O')
    .replaceAll('É', 'E')
    .replaceAll(RegExp(r'\s+'), ' ');
String financeBudgetAccount(String company, String branch) =>
    '${_normalized(company)}|${_normalized(branch)}';
bool _validAccount(String key) =>
    key.split('|').length == 2 && key.split('|').every((s) => s.isNotEmpty);

class FinanceBudgetPeriod {
  FinanceBudgetPeriod(DateTime at) {
    asOf = _day(at);
    currentMonday = _add(asOf, 1 - asOf.weekday);
    start = _add(currentMonday, 7);
    end = _add(start, 6);
    historyStart = _add(currentMonday, -56);
    historyEnd = _add(currentMonday, -1);
  }
  late final DateTime asOf, currentMonday, start, end, historyStart, historyEnd;
}

class FinanceWeeklyBudgetSource {
  const FinanceWeeklyBudgetSource({
    required this.movements,
    required this.invoices,
    required this.fixedPayments,
    required this.agreements,
    required this.installments,
    required this.agreementLinks,
  });
  final List<FinanzasBankMovementRecord> movements;
  final List<FinanzasSupplierInvoiceRecord> invoices;
  final List<FinanzasFixedPaymentRecord> fixedPayments;
  final List<FinanzasSupplierAgreementRecord> agreements;
  final List<FinanzasSupplierAgreementInstallmentRecord> installments;
  final List<FinanzasSupplierAgreementInvoiceRecord> agreementLinks;
}

class FinanceBudgetWeekFlow {
  FinanceBudgetWeekFlow(this.start);
  final DateTime start;
  int credits = 0, supplierDebits = 0, otherDebits = 0;
  int get debits => supplierDebits + otherDebits;
  int get net => credits - debits;
}

class FinanceBudgetCommitment {
  FinanceBudgetCommitment({
    required this.id,
    required this.account,
    required this.label,
    required this.reference,
    required this.amount,
    required this.dueDate,
    this.fixed = true,
  });
  final String id, account, label, reference;
  int proposed = 0;
  final int amount;
  final DateTime? dueDate;
  final bool fixed;
}

class FinanceBudgetInvoice {
  FinanceBudgetInvoice({
    required this.invoice,
    required this.account,
    required this.balance,
    required this.overdueDays,
    required this.reviewReason,
  });
  final FinanzasSupplierInvoiceRecord invoice;
  final String account;
  final int balance, overdueDays;
  final String? reviewReason;
  int proposed = 0;
  bool additional = false;
  String selectionReason = 'Pendiente para otra semana';
  int get remaining => balance - proposed;
  String get supplier => invoice.providerNameSnapshot.trim().isEmpty
      ? 'Sin proveedor'
      : invoice.providerNameSnapshot.trim();
  String get supplierKey => invoice.providerId.trim().isEmpty
      ? _normalized(supplier)
      : invoice.providerId;
  String get decision => reviewReason ?? selectionReason;
}

class FinanceBudgetAccountPlan {
  FinanceBudgetAccountPlan(this.key);
  final String key;
  final List<FinanceBudgetWeekFlow> history = [];
  int proposed = 0, fixedRequired = 0, fixedProposed = 0;
  int get requiredTotal => proposed + fixedRequired;
  int get proposedTotal => proposed + fixedProposed;
  int get medianCredits => _median(history.map((w) => w.credits));
  int get medianSupplierDebits => _median(history.map((w) => w.supplierDebits));
  String get label => key.replaceAll('|', ' / ');
}

/// A requirements-based weekly proposal. Bank balances and historical flows
/// never determine selection or the ceiling. Money is allocated in cents.
class FinanceWeeklyBudgetAnalysis {
  FinanceWeeklyBudgetAnalysis(this.source, DateTime generatedAt)
    : period = FinanceBudgetPeriod(generatedAt) {
    _build();
  }
  static const int weeklyLimit = 50000000; // MXN 500,000 in cents.
  static const int highDebtThreshold = 10000000; // MXN 100,000 due.
  final FinanceWeeklyBudgetSource source;
  final FinanceBudgetPeriod period;
  final List<FinanceBudgetAccountPlan> accounts = [];
  final List<FinanceBudgetInvoice> invoices = [];
  final List<FinanceBudgetCommitment> commitments = [];
  final List<String> warnings = [];
  int unassignedCommitments = 0;
  final List<FinanceBudgetInvoice> baseInvoices = [];
  int excludedForecastMovements = 0, ignoredFutureMovements = 0;
  int get proposedInvoices => invoices.fold(0, (s, r) => s + r.proposed);
  int get invoiceBalance => invoices.fold(0, (s, r) => s + r.balance);
  int get unprogrammed => invoices.fold(0, (s, r) => s + r.remaining);
  int get fixedPayments =>
      commitments.where((r) => r.fixed).fold(0, (s, r) => s + r.amount);
  int get proposedFixedPayments =>
      commitments.where((r) => r.fixed).fold(0, (s, r) => s + r.proposed);
  int get pendingFixedPayments => fixedPayments - proposedFixedPayments;
  int get agreementHold =>
      commitments.where((r) => !r.fixed).fold(0, (s, r) => s + r.amount);
  int get proposedTotal => proposedInvoices + proposedFixedPayments;
  int get remainingBudget => weeklyLimit - proposedTotal;
  int get baseRequirement =>
      fixedPayments + baseInvoices.fold<int>(0, (s, r) => s + r.balance);
  int get baseOverLimit => math.max(0, baseRequirement - weeklyLimit);
  int get uncoveredProviders =>
      baseInvoices.where((r) => r.proposed == 0).length;
  int get additionalCount => invoices.where((r) => r.additional).length;
  List<FinanceBudgetInvoice> get proposedRows =>
      invoices.where((r) => r.proposed > 0).toList();
  List<FinanceBudgetInvoice> get pendingRows =>
      invoices.where((r) => r.remaining > 0).toList();
  List<FinanceBudgetWeekFlow> get combinedHistory {
    final byDate = <DateTime, FinanceBudgetWeekFlow>{};
    for (final account in accounts) {
      for (final w in account.history) {
        final row = byDate.putIfAbsent(
          w.start,
          () => FinanceBudgetWeekFlow(w.start),
        );
        row.credits += w.credits;
        row.supplierDebits += w.supplierDebits;
        row.otherDebits += w.otherDebits;
      }
    }
    return byDate.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  void _build() {
    void unique(Iterable<String> ids, String source) {
      final seen = <String>{};
      if (ids.any((id) => id.trim().isEmpty || !seen.add(id))) {
        throw StateError('$source sin ID único.');
      }
    }

    unique(source.fixedPayments.map((r) => r.id), 'Pagos fijos');
    unique(source.agreements.map((r) => r.id), 'Convenios');
    unique(source.installments.map((r) => r.id), 'Cuotas');
    final plans = <String, FinanceBudgetAccountPlan>{};
    FinanceBudgetAccountPlan plan(String key) =>
        plans.putIfAbsent(key, () => FinanceBudgetAccountPlan(key));
    final movements = <FinanzasBankMovementRecord>[];
    final seenMovements = <String>{};
    for (final row in source.movements) {
      if (row.id.isEmpty || !seenMovements.add(row.id)) {
        throw StateError('Movimientos bancarios sin ID único.');
      }
      if (_day(row.date).isAfter(period.asOf)) {
        ignoredFutureMovements++;
        continue;
      }
      if (row.creditAmount < 0 || row.debitAmount < 0) {
        throw StateError('Movimiento bancario con importe negativo.');
      }
      final key = financeBudgetAccount(row.company, row.branch);
      if (!_validAccount(key)) {
        throw StateError('Movimiento bancario sin empresa o sucursal.');
      }
      _cents(row.creditAmount);
      _cents(row.debitAmount);
      plan(key);
      movements.add(row);
    }
    final applied = <String, int>{};
    for (final row in movements) {
      final id = row.linkedSupplierInvoiceId;
      if (id != null && id.isNotEmpty) {
        applied.update(
          id,
          (v) => v + _cents(row.effectiveSupplierAppliedAmount),
          ifAbsent: () => _cents(row.effectiveSupplierAppliedAmount),
        );
      }
    }
    final activeAgreements = {
      for (final a in source.agreements)
        if (!['CANCELADO', 'CUMPLIDO'].contains(_normalized(a.status)) &&
            a.remainingAmount > .009)
          a.id: a,
    };
    final linkedInvoices = {
      for (final l in source.agreementLinks)
        if (activeAgreements.containsKey(l.agreementId)) l.invoiceId,
    };
    final seenInvoices = <String>{};
    for (final invoice in source.invoices) {
      if (invoice.id.isEmpty || !seenInvoices.add(invoice.id)) {
        throw StateError('Facturas sin ID único.');
      }
      if ([
        'PAGADA',
        'CANCELADA',
        'CANCELADO',
      ].contains(_normalized(invoice.status))) {
        continue;
      }
      if (_day(invoice.invoiceDate).isAfter(period.asOf)) continue;
      final original = math.max(0, _cents(invoice.totalAmount));
      final stored = _cents(invoice.balanceAmount).clamp(0, original);
      // A partial bank history cannot resurrect an already reduced balance.
      final balance = math.min(
        stored,
        math.max(0, original - (applied[invoice.id] ?? 0)),
      );
      if (balance == 0) continue;
      final key = financeBudgetAccount(
        invoice.targetCompany,
        invoice.targetBranch,
      );
      if (_validAccount(key)) plan(key);
      final due = invoice.dueDate == null ? null : _day(invoice.dueDate!);
      final agreement =
          linkedInvoices.contains(invoice.id) ||
          _normalized(invoice.status) == 'CONVENIO';
      final reason = !_validAccount(key)
          ? 'Revisar cuenta de pago'
          : invoice.providerId.trim().isEmpty &&
                invoice.providerNameSnapshot.trim().isEmpty
          ? 'Confirmar proveedor'
          : agreement
          ? 'Respetar convenio; ver compromisos'
          : due == null
          ? 'Confirmar vencimiento'
          : due.isAfter(period.end)
          ? 'Vence después de la semana'
          : null;
      invoices.add(
        FinanceBudgetInvoice(
          invoice: invoice,
          account: key,
          balance: balance,
          overdueDays: due == null
              ? 0
              : math.max(0, period.asOf.difference(due).inDays),
          reviewReason: reason,
        ),
      );
    }
    invoices.sort((a, b) {
      final date = (a.invoice.dueDate ?? DateTime(9999)).compareTo(
        b.invoice.dueDate ?? DateTime(9999),
      );
      if (date != 0) return date;
      final issued = a.invoice.invoiceDate.compareTo(b.invoice.invoiceDate);
      if (issued != 0) return issued;
      final provider = a.supplier.toLowerCase().compareTo(
        b.supplier.toLowerCase(),
      );
      return provider != 0 ? provider : a.invoice.id.compareTo(b.invoice.id);
    });
    final paidFixed = <String, int>{};
    for (final row in movements) {
      if (row.linkedFixedPaymentId?.isNotEmpty == true) {
        paidFixed.update(
          row.linkedFixedPaymentId!,
          (value) => value + _cents(row.debitAmount),
          ifAbsent: () => _cents(row.debitAmount),
        );
      }
    }
    for (final row in source.fixedPayments) {
      if (_normalized(row.status) == 'PAGADO' ||
          _day(row.paymentDate).isAfter(period.end)) {
        continue;
      }
      final key = financeBudgetAccount(row.targetCompany, row.branch);
      final amount = math.max(0, _cents(row.amount) - (paidFixed[row.id] ?? 0));
      if (amount == 0) continue;
      commitments.add(
        FinanceBudgetCommitment(
          id: row.id,
          account: key,
          label: row.companyNameSnapshot,
          reference: row.notes.trim().isEmpty ? 'Pago fijo' : row.notes.trim(),
          amount: amount,
          dueDate: _day(row.paymentDate),
        ),
      );
      if (_validAccount(key)) {
        plan(key).fixedRequired += amount;
      } else {
        unassignedCommitments += amount;
      }
    }
    final agreementRemaining = {
      for (final a in activeAgreements.values) a.id: _cents(a.remainingAmount),
    };
    final installments = [...source.installments]
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    for (final row in installments) {
      final agreement = activeAgreements[row.agreementId];
      if (agreement == null ||
          ['PAGADO', 'CANCELADO'].contains(_normalized(row.status)) ||
          _day(row.dueDate).isAfter(period.end)) {
        continue;
      }
      final amount = math.min(
        math.max(0, _cents(row.amount) - _cents(row.paidAmount)),
        agreementRemaining[agreement.id] ?? 0,
      );
      if (amount <= 0) continue;
      agreementRemaining[agreement.id] =
          agreementRemaining[agreement.id]! - amount;
      final key = financeBudgetAccount(
        agreement.targetCompany,
        agreement.targetBranch,
      );
      commitments.add(
        FinanceBudgetCommitment(
          id: row.id,
          account: key,
          label: agreement.providerNameSnapshot,
          reference: 'Convenio / cuota ${row.sequenceNumber}',
          amount: amount,
          dueDate: _day(row.dueDate),
          fixed: false,
        ),
      );
      if (_validAccount(key)) {
        plan(key);
      } else {
        unassignedCommitments += amount;
      }
    }
    for (final a in activeAgreements.values) {
      if (!source.installments.any(
        (i) =>
            i.agreementId == a.id &&
            !['PAGADO', 'CANCELADO'].contains(_normalized(i.status)) &&
            i.amount > i.paidAmount,
      )) {
        // Disclose an unscheduled agreement without inventing a payment date.
        final key = financeBudgetAccount(a.targetCompany, a.targetBranch);
        final amount = _cents(a.remainingAmount);
        commitments.add(
          FinanceBudgetCommitment(
            id: a.id,
            account: key,
            label: a.providerNameSnapshot,
            reference: 'Saldo por revisar; confirmar calendario de cuotas',
            amount: amount,
            dueDate: null,
            fixed: false,
          ),
        );
        if (_validAccount(key)) {
          plan(key);
        } else {
          unassignedCommitments += amount;
        }
        warnings.add(
          'Convenio de ${a.providerNameSnapshot} sin cuotas abiertas; confirmar programación de su saldo pendiente.',
        );
      }
    }
    accounts.addAll(
      plans.values.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    for (final p in accounts) {
      final bankRows = movements
          .where((r) => financeBudgetAccount(r.company, r.branch) == p.key)
          .toList();
      final first = bankRows.isEmpty
          ? null
          : bankRows
                .map((r) => _day(r.date))
                .reduce((a, b) => a.isBefore(b) ? a : b);
      for (
        var start = period.historyStart;
        start.isBefore(period.currentMonday);
        start = _add(start, 7)
      ) {
        if (first == null || start.isBefore(first)) {
          continue; // Never invent pre-history zero weeks.
        }
        final week = FinanceBudgetWeekFlow(start);
        for (final row in bankRows) {
          final date = _day(row.date);
          if (date.isBefore(start) || !date.isBefore(_add(start, 7))) continue;
          if (!_recurringExternal(row)) {
            excludedForecastMovements++;
            continue;
          }
          week.credits += _cents(row.creditAmount);
          if (row.linkedSupplierInvoiceId?.isNotEmpty == true ||
              row.sourceType == 'COMPRA_FACTURA') {
            week.supplierDebits += _cents(row.debitAmount);
          } else {
            week.otherDebits += _cents(row.debitAmount);
          }
        }
        p.history.add(week);
      }
      if (p.history.length < 3) {
        warnings.add(
          '${p.label}: historial de ${p.history.length} semanas completas; solo como referencia.',
        );
      }
    }
    _selectInvoices(plans);
    if (ignoredFutureMovements > 0) {
      warnings.add(
        '$ignoredFutureMovements movimientos bancarios futuros excluidos de abonos e historial.',
      );
    }
    if (pendingFixedPayments > 0) {
      warnings.add(
        'Los pagos fijos requeridos superan el tope semanal; quedan compromisos sin programar y no se agregan facturas.',
      );
    }
    if (uncoveredProviders > 0 && pendingFixedPayments == 0) {
      warnings.add(
        '$uncoveredProviders proveedores sin primera factura propuesta: su factura más antigua no cabe en el remanente del tope. No se añaden facturas adicionales.',
      );
    }
    if (unassignedCommitments > 0) {
      warnings.add(
        'Hay pagos fijos o convenios sin empresa/sucursal; confirmar su asignación.',
      );
    }
  }

  void _selectInvoices(Map<String, FinanceBudgetAccountPlan> plans) {
    var available = weeklyLimit;
    final fixed = commitments.where((r) => r.fixed).toList()
      ..sort((a, b) {
        final date = a.dueDate!.compareTo(b.dueDate!);
        return date != 0 ? date : a.id.compareTo(b.id);
      });
    for (final row in fixed) {
      if (row.amount <= available) {
        row.proposed = row.amount;
        available -= row.proposed;
        plans[row.account]?.fixedProposed += row.proposed;
      }
    }
    // Group by supplier globally, not by paying account: one company gets one
    // base invoice even when it operates through multiple branches/accounts.
    final bySupplier = <String, List<FinanceBudgetInvoice>>{};
    for (final row in invoices.where((r) => r.reviewReason == null)) {
      bySupplier.putIfAbsent(row.supplierKey, () => []).add(row);
    }
    final heads = {for (final rows in bySupplier.values) rows.first};
    baseInvoices.addAll(invoices.where(heads.contains));
    void select(FinanceBudgetInvoice row, {bool additional = false}) {
      row.proposed = row.balance;
      row.additional = additional;
      row.selectionReason = additional
          ? 'Adicional por carga alta'
          : 'Primera factura del proveedor';
      available -= row.proposed;
      plans[row.account]!.proposed += row.proposed;
    }

    for (final row in baseInvoices) {
      if (pendingFixedPayments == 0 && row.balance <= available) {
        select(row);
      } else {
        row.selectionReason = pendingFixedPayments > 0
            ? 'Prioridad a pagos fijos; fuera del tope'
            : 'Factura completa fuera del remanente';
      }
    }
    if (pendingFixedPayments > 0 || uncoveredProviders > 0) return;
    final highLoad = bySupplier.values
        .where(
          (rows) =>
              rows.length > 1 &&
              rows.fold<int>(0, (s, r) => s + r.balance) >= highDebtThreshold,
        )
        .toList();
    final blocked = <String>{};
    while (available > 0) {
      final candidates = highLoad
          .where(
            (rows) =>
                !blocked.contains(rows.first.supplierKey) &&
                rows.any((r) => r.proposed == 0),
          )
          .toList();
      if (candidates.isEmpty) break;
      int debt(List<FinanceBudgetInvoice> rows) =>
          rows.fold(0, (s, r) => s + r.remaining);
      candidates.sort((a, b) {
        final balance = debt(b).compareTo(debt(a));
        return balance != 0
            ? balance
            : a.first.supplierKey.compareTo(b.first.supplierKey);
      });
      final rows = candidates.first;
      final next = rows.firstWhere((r) => r.proposed == 0);
      if (next.balance <= available) {
        select(next, additional: true);
      } else {
        next.selectionReason = 'Factura completa fuera del remanente';
        blocked.add(next.supplierKey); // Never jump over an older invoice.
      }
    }
  }
}

bool _recurringExternal(FinanzasBankMovementRecord row) {
  final category = _normalized(row.category);
  final party = _normalized(row.counterpartyNameSnapshot);
  return !['MOVIMIENTOS INTERNOS', 'AJUSTES'].contains(category) &&
      !party.contains('BOVEDA') &&
      !party.contains('REPOSICION DE FONDO') &&
      !party.contains('EFECTIVO');
}

int _median(Iterable<int> values) {
  final rows = values.toList()..sort();
  if (rows.isEmpty) return 0;
  final middle = rows.length ~/ 2;
  return rows.length.isOdd
      ? rows[middle]
      : ((rows[middle - 1] + rows[middle]) / 2).round();
}
