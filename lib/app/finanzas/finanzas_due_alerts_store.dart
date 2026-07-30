import 'package:flutter/material.dart';

import 'finanzas_fixed_payments_store.dart';
import 'finanzas_provider_accounts_store.dart';

enum FinanzasDueAlertSeverity { info, warning, critical }

class FinanzasDueAlertItem {
  final String id;
  final String sourceType;
  final String title;
  final String subtitle;
  final DateTime dueDate;
  final double amount;
  final int daysUntilDue;
  final String reminderLabel;
  final FinanzasDueAlertSeverity severity;

  const FinanzasDueAlertItem({
    required this.id,
    required this.sourceType,
    required this.title,
    required this.subtitle,
    required this.dueDate,
    required this.amount,
    required this.daysUntilDue,
    required this.reminderLabel,
    required this.severity,
  });
}

class FinanzasDueAlertsSummary {
  final int overdueCount;
  final int dueTodayCount;
  final int dueIn2DaysCount;
  final int dueIn7DaysCount;
  final double overdueAmount;
  final double dueTodayAmount;
  final double dueIn2DaysAmount;
  final double dueIn7DaysAmount;
  final List<FinanzasDueAlertItem> items;

  const FinanzasDueAlertsSummary({
    required this.overdueCount,
    required this.dueTodayCount,
    required this.dueIn2DaysCount,
    required this.dueIn7DaysCount,
    required this.overdueAmount,
    required this.dueTodayAmount,
    required this.dueIn2DaysAmount,
    required this.dueIn7DaysAmount,
    required this.items,
  });

  const FinanzasDueAlertsSummary.empty()
    : overdueCount = 0,
      dueTodayCount = 0,
      dueIn2DaysCount = 0,
      dueIn7DaysCount = 0,
      overdueAmount = 0,
      dueTodayAmount = 0,
      dueIn2DaysAmount = 0,
      dueIn7DaysAmount = 0,
      items = const <FinanzasDueAlertItem>[];

  int get totalCount =>
      overdueCount + dueTodayCount + dueIn2DaysCount + dueIn7DaysCount;

  double get totalAmount =>
      overdueAmount + dueTodayAmount + dueIn2DaysAmount + dueIn7DaysAmount;
}

enum FinanzasDueAlertsSessionScope { finanzasDashboard, directionDashboard }

class FinanzasDueAlertsSessionGate {
  static const int maxPresentationsPerSession = 3;
  static final Map<FinanzasDueAlertsSessionScope, int> _presentationCounts =
      <FinanzasDueAlertsSessionScope, int>{};

  static bool canPresent(FinanzasDueAlertsSessionScope scope) =>
      (_presentationCounts[scope] ?? 0) < maxPresentationsPerSession;

  static int remainingPresentations(FinanzasDueAlertsSessionScope scope) =>
      maxPresentationsPerSession - (_presentationCounts[scope] ?? 0);

  static bool registerPresentation(FinanzasDueAlertsSessionScope scope) {
    if (!canPresent(scope)) return false;
    _presentationCounts[scope] = (_presentationCounts[scope] ?? 0) + 1;
    return true;
  }
}

class FinanzasDueAlertsStore {
  static Future<FinanzasDueAlertsSummary> loadSummary() async {
    final results = await Future.wait<dynamic>([
      FinanzasProviderAccountsStore.loadInvoices(),
      FinanzasFixedPaymentsStore.loadPayments(),
      FinanzasProviderAccountsStore.loadAgreements(),
      FinanzasProviderAccountsStore.loadAgreementInstallments(),
    ]);

    final invoices = results[0] as List<FinanzasSupplierInvoiceRecord>;
    final fixedPayments = results[1] as List<FinanzasFixedPaymentRecord>;
    final agreements = results[2] as List<FinanzasSupplierAgreementRecord>;
    final installments =
        results[3] as List<FinanzasSupplierAgreementInstallmentRecord>;

    final today = DateUtils.dateOnly(DateTime.now());
    final agreementById = <String, FinanzasSupplierAgreementRecord>{
      for (final row in agreements) row.id: row,
    };

    final items = <FinanzasDueAlertItem>[];

    for (final invoice in invoices) {
      if (invoice.balanceAmount <= 0.009 || invoice.status == 'PAGADA') {
        continue;
      }
      final dueDate = invoice.dueDate;
      if (dueDate == null) continue;
      final normalizedDue = DateUtils.dateOnly(dueDate);
      final daysUntilDue = normalizedDue.difference(today).inDays;
      final meta = _reminderMeta(daysUntilDue);
      if (meta == null) continue;
      final folio = invoice.folio.trim().isEmpty ? 'sin folio' : invoice.folio;
      items.add(
        FinanzasDueAlertItem(
          id: 'invoice-${invoice.id}-${meta.$1}',
          sourceType: 'FACTURA',
          title: invoice.providerNameSnapshot,
          subtitle: 'Factura $folio · ${meta.$2}',
          dueDate: normalizedDue,
          amount: invoice.balanceAmount,
          daysUntilDue: daysUntilDue,
          reminderLabel: meta.$2,
          severity: meta.$3,
        ),
      );
    }

    for (final payment in fixedPayments) {
      if (payment.status == 'PAGADO') continue;
      final normalizedDue = DateUtils.dateOnly(payment.paymentDate);
      final daysUntilDue = normalizedDue.difference(today).inDays;
      final meta = _reminderMeta(daysUntilDue);
      if (meta == null) continue;
      items.add(
        FinanzasDueAlertItem(
          id: 'fixed-${payment.id}-${meta.$1}',
          sourceType: 'PAGO_FIJO',
          title: payment.companyNameSnapshot,
          subtitle: 'Pago fijo · ${meta.$2}',
          dueDate: normalizedDue,
          amount: payment.amount,
          daysUntilDue: daysUntilDue,
          reminderLabel: meta.$2,
          severity: meta.$3,
        ),
      );
    }

    for (final installment in installments) {
      final pendingAmount = (installment.amount - installment.paidAmount).clamp(
        0.0,
        double.infinity,
      );
      if (pendingAmount <= 0.009) continue;
      final normalizedDue = DateUtils.dateOnly(installment.dueDate);
      final daysUntilDue = normalizedDue.difference(today).inDays;
      final meta = _reminderMeta(daysUntilDue);
      if (meta == null) continue;
      final agreement = agreementById[installment.agreementId];
      final providerName =
          agreement?.providerNameSnapshot.trim().isNotEmpty == true
          ? agreement!.providerNameSnapshot
          : 'Convenio proveedor';
      items.add(
        FinanzasDueAlertItem(
          id: 'installment-${installment.id}-${meta.$1}',
          sourceType: 'CONVENIO',
          title: providerName,
          subtitle:
              'Convenio ${installment.sequenceNumber} · ${meta.$2} · ${installment.commitmentType == 'FACTURAS' ? '${installment.scheduledInvoiceCount} facturas' : 'cuota programada'}',
          dueDate: normalizedDue,
          amount: pendingAmount,
          daysUntilDue: daysUntilDue,
          reminderLabel: meta.$2,
          severity: meta.$3,
        ),
      );
    }

    items.sort((a, b) {
      final severityCompare = b.severity.index.compareTo(a.severity.index);
      if (severityCompare != 0) return severityCompare;
      final dueCompare = a.dueDate.compareTo(b.dueDate);
      if (dueCompare != 0) return dueCompare;
      return b.amount.compareTo(a.amount);
    });

    return FinanzasDueAlertsSummary(
      overdueCount: items.where((row) => row.daysUntilDue < 0).length,
      dueTodayCount: items.where((row) => row.daysUntilDue == 0).length,
      dueIn2DaysCount: items.where((row) => row.daysUntilDue == 2).length,
      dueIn7DaysCount: items.where((row) => row.daysUntilDue == 7).length,
      overdueAmount: items
          .where((row) => row.daysUntilDue < 0)
          .fold<double>(0, (sum, row) => sum + row.amount),
      dueTodayAmount: items
          .where((row) => row.daysUntilDue == 0)
          .fold<double>(0, (sum, row) => sum + row.amount),
      dueIn2DaysAmount: items
          .where((row) => row.daysUntilDue == 2)
          .fold<double>(0, (sum, row) => sum + row.amount),
      dueIn7DaysAmount: items
          .where((row) => row.daysUntilDue == 7)
          .fold<double>(0, (sum, row) => sum + row.amount),
      items: items.take(8).toList(growable: false),
    );
  }
}

(String, String, FinanzasDueAlertSeverity)? _reminderMeta(int daysUntilDue) {
  if (daysUntilDue == 0) {
    return ('today', 'vence hoy', FinanzasDueAlertSeverity.critical);
  }
  if (daysUntilDue == 2) {
    return ('two_days', 'vence en 2 días', FinanzasDueAlertSeverity.warning);
  }
  if (daysUntilDue == 7) {
    return ('seven_days', 'vence en 1 semana', FinanzasDueAlertSeverity.info);
  }
  return null;
}
