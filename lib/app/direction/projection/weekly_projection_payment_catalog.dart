import '../../management_reports/finance_weekly_budget_analysis.dart';
import '../operating_program/operating_program_models.dart';
import 'weekly_projection_models.dart';

/// Discovery is broader than Friday's automatic selection. An invoice covered
/// by an agreement opens the existing commitment, never a second obligation.
class ProjectionPaymentCatalog {
  final Map<String, ProjectedPayment> byId = {};
  final Map<String, List<String>> _commitmentsByInvoice = {};

  ProjectionPaymentCatalog(FinanceWeeklyBudgetAnalysis analysis) {
    for (final payment in paymentProposal(analysis)) {
      byId[payment.id] = payment;
    }
    final invoices = {for (final r in analysis.source.invoices) r.id: r};
    final agreements = {
      for (final r in analysis.source.agreements)
        if (r.remainingAmount > .009 &&
            !['CANCELADO', 'CUMPLIDO'].contains(r.status.trim().toUpperCase()))
          r.id: r,
    };
    final installments = {
      for (final r in analysis.source.installments) r.id: r,
    };
    final foliosByCommitment = <String, Set<String>>{};
    final scheduleByInvoice = <String, Set<String>>{};
    for (final link in analysis.source.agreementLinks) {
      if (!agreements.containsKey(link.agreementId)) continue;
      final invoice = invoices[link.invoiceId];
      final installment = installments[link.installmentId];
      // A valid installment link must belong to the same agreement. A balance
      // without a schedule is represented by the agreement's own ID.
      final target = installment?.agreementId == link.agreementId
          ? byId['agreement:${link.installmentId}']
          : null;
      final payment = target ?? byId['agreement:${link.agreementId}'];
      if (payment != null && payment.available > 0) {
        final ids = _commitmentsByInvoice.putIfAbsent(
          'invoice:${link.invoiceId}',
          () => [],
        );
        if (!ids.contains(payment.id)) ids.add(payment.id);
        if (invoice != null) {
          foliosByCommitment
              .putIfAbsent(payment.id, () => {})
              .add(invoice.folio);
        }
      } else if (installment?.agreementId == link.agreementId) {
        scheduleByInvoice
            .putIfAbsent('invoice:${link.invoiceId}', () => {})
            .add(
              'Cuota ${installment!.sequenceNumber} · '
              '${programDate(installment.dueDate)} · ${installment.status}',
            );
      }
    }
    for (final entry in foliosByCommitment.entries) {
      final payment = byId[entry.key]!;
      final folios = entry.value.toList()..sort();
      byId[entry.key] = ProjectedPayment(
        id: payment.id,
        source: payment.source,
        payee: payment.payee,
        reference: '${payment.reference} · Facturas ${folios.join(', ')}',
        account: payment.account,
        date: payment.date,
        amount: payment.amount,
        available: payment.available,
        included: payment.included,
        paymentType: payment.paymentType,
        paymentTypeAutomatic: payment.paymentTypeAutomatic,
        selectionAutomatic: payment.selectionAutomatic,
        warning: payment.warning,
      );
    }
    for (final entry in byId.entries.toList()) {
      if (entry.value.source != 'agreement') continue;
      final installment =
          installments[entry.key.substring('agreement:'.length)];
      if (installment == null) continue;
      byId[entry.key] = entry.value.copyWith(
        warning:
            'Vencimiento original: ${programDate(installment.dueDate)}. '
            '${installment.dueDate.isBefore(analysis.period.start) ? 'Cuota atrasada; puede programarse en esta semana. ' : ''}'
            'Confirma importe y fecha antes de incluir.',
      );
    }
    for (final invoice in invoices.values) {
      final id = 'invoice:${invoice.id}';
      final current = byId[id];
      if (current != null && current.available > 0) continue;
      String reason;
      if (current != null) {
        final targets = commitmentsFor(id);
        if (targets.isNotEmpty) {
          reason =
              'Factura incluida en convenio. Programa o edita su cuota '
              'para contar el pago una sola vez en el flujo.';
        } else {
          final schedule = scheduleByInvoice[id];
          reason =
              'Factura marcada como convenio en Finanzas. '
              'No hay una cuota pendiente disponible para esta semana.'
              '${schedule == null ? '' : '\n${schedule.join('\n')}'} '
              'Revisa el calendario y el vínculo de la factura en Finanzas.';
        }
        byId[id] = current.copyWith(warning: reason);
      } else {
        final status = invoice.status.trim().toUpperCase();
        final issued = DateTime(
          invoice.invoiceDate.year,
          invoice.invoiceDate.month,
          invoice.invoiceDate.day,
        );
        reason = switch (status) {
          'PAGADA' => 'Factura pagada en Finanzas; no tiene un pago pendiente.',
          'CANCELADA' || 'CANCELADO' => 'Factura cancelada en Finanzas.',
          _ when issued.isAfter(analysis.period.asOf) =>
            'La fecha de la factura es posterior a la fecha de consulta.',
          _ when invoice.balanceAmount <= .009 || invoice.totalAmount <= .009 =>
            'Factura sin saldo pendiente en Finanzas.',
          _ =>
            'Saldo cubierto por los abonos registrados en Finanzas. '
                'Revisa la conciliación de la factura si el saldo no coincide.',
        };
        _commitmentsByInvoice.remove(id);
        byId[id] = ProjectedPayment(
          id: id,
          source: 'invoice',
          payee: invoice.providerNameSnapshot,
          reference: 'Factura ${invoice.folio}',
          account: financeBudgetAccount(
            invoice.targetCompany,
            invoice.targetBranch,
          ),
          date: analysis.period.start,
          amount: 0,
          available: 0,
          included: false,
          paymentType: 'FISCAL',
          paymentTypeAutomatic: true,
          selectionAutomatic: true,
          warning: reason,
        );
      }
    }
  }

  List<ProjectedPayment> commitmentsFor(String invoiceId) => [
    for (final id in _commitmentsByInvoice[invoiceId] ?? const <String>[])
      byId[id]!,
  ];
}
