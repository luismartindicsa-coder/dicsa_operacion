import 'dart:math' as math;

int hrLoanCents(Object? value) => ((num.tryParse('$value') ?? 0) * 100).round();
String hrLoanDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

class HrLoan {
  final String id, employeeId, employeeName, company, method, frequency, notes;
  final String payrollChannel;
  final int folio, principalCents, installments;
  final int? fixedInstallmentCents;
  final int openingPaidCents, openingPaidInstallments;
  final Map<String, dynamic> openingSnapshot;
  final DateTime issuedOn, firstDueOn;

  HrLoan.fromRow(Map<String, dynamic> row)
    : id = '${row['id']}',
      employeeId = '${row['employee_id']}',
      employeeName = '${row['employee_name']}',
      company = '${row['empresa'] ?? ''}',
      method = '${row['repayment_method']}',
      payrollChannel = '${row['payroll_channel'] ?? 'flujo'}',
      frequency = '${row['frequency']}',
      notes = '${row['notes'] ?? ''}',
      folio = (row['folio'] as num).toInt(),
      principalCents = hrLoanCents(row['principal']),
      installments = (row['installment_count'] as num).toInt(),
      fixedInstallmentCents = row['installment_amount'] == null
          ? null
          : hrLoanCents(row['installment_amount']),
      openingPaidCents = hrLoanCents(row['opening_paid_amount']),
      openingPaidInstallments = (row['opening_paid_installments'] as num? ?? 0)
          .toInt(),
      openingSnapshot = Map<String, dynamic>.from(
        row['opening_snapshot'] as Map? ?? const {},
      ),
      issuedOn = DateTime.parse('${row['issued_on']}'),
      firstDueOn = DateTime.parse('${row['first_due_on']}');

  int get regularInstallmentCents =>
      fixedInstallmentCents ?? principalCents ~/ installments;
  int installmentCents(int index) => index == installments - 1
      ? principalCents - regularInstallmentCents * (installments - 1)
      : regularInstallmentCents;
  int paidBeforeInstallment(int index) => regularInstallmentCents * index;
  bool get isHistorical => openingSnapshot.isNotEmpty;
  DateTime get displayDate =>
      DateTime.tryParse('${openingSnapshot['requested_on']}') ?? issuedOn;

  DateTime? dueOn(int index) {
    if (index < openingPaidInstallments) return null;
    final pendingIndex = index - openingPaidInstallments;
    if (frequency != 'mensual') {
      return DateTime(
        firstDueOn.year,
        firstDueOn.month,
        firstDueOn.day + pendingIndex * (frequency == 'quincenal' ? 14 : 7),
      );
    }
    final month = DateTime(firstDueOn.year, firstDueOn.month + pendingIndex);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, math.min(firstDueOn.day, lastDay));
  }

  String get methodLabel => method == 'nomina'
      ? 'Nómina · ${payrollChannel == 'fiscal' ? 'Fiscal (CONTPAQ)' : 'Flujo'}'
      : 'Efectivo';
  String get frequencyLabel => switch (frequency) {
    'mensual' => 'Mensual',
    'quincenal' => 'Cada 14 días',
    _ => 'Semanal',
  };
}

class HrLoanPayment {
  final String id, loanId, method, notes, periodLabel;
  final String? payrollChannel;
  final int cents;
  final DateTime paidOn;

  HrLoanPayment.fromRow(Map<String, dynamic> row)
    : id = '${row['id']}',
      loanId = '${row['loan_id']}',
      method = '${row['method']}',
      payrollChannel = row['method'] == 'nomina'
          ? '${row['payroll_channel'] ?? 'flujo'}'
          : null,
      notes = '${row['notes'] ?? ''}',
      periodLabel = '${row['period_label'] ?? ''}',
      cents = hrLoanCents(row['amount']),
      paidOn = DateTime.parse('${row['paid_on']}');

  String get methodLabel => method == 'efectivo'
      ? 'Efectivo'
      : payrollChannel == 'fiscal'
      ? 'Fiscal · incluido en CONTPAQ'
      : 'Nómina · Flujo';
}

class HrLoanFundState {
  final int capitalCents;
  final List<HrLoan> loans;
  final List<HrLoanPayment> payments;
  const HrLoanFundState({
    required this.capitalCents,
    required this.loans,
    required this.payments,
  });

  int get lentCents => loans.fold(0, (sum, loan) => sum + loan.principalCents);
  int get recoveredCents =>
      loans.fold<int>(0, (sum, loan) => sum + loan.openingPaidCents) +
      payments.fold(0, (sum, payment) => sum + payment.cents);
  int get outstandingCents => lentCents - recoveredCents;
  int get availableCents => capitalCents - outstandingCents;
  int paidCents(HrLoan loan) =>
      loan.openingPaidCents +
      payments
          .where((p) => p.loanId == loan.id)
          .fold(0, (sum, p) => sum + p.cents);
  int balanceCents(HrLoan loan) =>
      math.max(0, loan.principalCents - paidCents(loan));
  int dueCents(HrLoan loan, DateTime through) {
    if (loan.issuedOn.isAfter(through)) return 0;
    var scheduled = 0;
    for (var i = 0; i < loan.installments; i++) {
      final due = loan.dueOn(i);
      if (due != null && !due.isAfter(through)) {
        scheduled += loan.installmentCents(i);
      }
    }
    return math.max(0, scheduled - (paidCents(loan) - loan.openingPaidCents));
  }

  HrLoanPayrollPlan payrollPlan(
    String employeeId,
    DateTime end, {
    required int flowAvailableCents,
    bool fiscalReady = false,
  }) {
    final candidates =
        loans
            .where(
              (l) =>
                  l.employeeId == employeeId &&
                  l.method == 'nomina' &&
                  dueCents(l, end) > 0,
            )
            .toList()
          ..sort((a, b) {
            final byDate = a.firstDueOn.compareTo(b.firstDueOn);
            return byDate == 0 ? a.folio.compareTo(b.folio) : byDate;
          });
    final dues = [
      for (final loan in candidates)
        HrLoanAllocation(
          loan.id,
          loan.folio,
          dueCents(loan, end),
          channel: loan.payrollChannel,
        ),
    ];
    return HrLoanPayrollPlan(
      end: end,
      dues: dues,
      fiscalReady: fiscalReady,
    ).limitedTo(flowAvailableCents);
  }
}

class HrLoanAllocation {
  final String loanId;
  final String channel;
  final int folio, cents;
  const HrLoanAllocation(
    this.loanId,
    this.folio,
    this.cents, {
    this.channel = 'flujo',
  });
  Map<String, dynamic> toJson() => {
    'loan_id': loanId,
    'folio': folio,
    'amount': cents / 100,
    'channel': channel,
  };
  factory HrLoanAllocation.fromJson(Map<String, dynamic> value) =>
      HrLoanAllocation(
        '${value['loan_id']}',
        (value['folio'] as num? ?? 0).toInt(),
        hrLoanCents(value['amount']),
        channel: '${value['channel'] ?? 'flujo'}',
      );
}

class HrLoanPayrollPlan {
  final DateTime? end;
  final List<HrLoanAllocation> dues, allocations;
  final bool fiscalReady;
  const HrLoanPayrollPlan({
    this.end,
    this.dues = const [],
    this.allocations = const [],
    this.fiscalReady = false,
  });

  int get requestedCents => dues.fold(0, (sum, a) => sum + a.cents);

  /// Only flow belongs in loan_deduction_amount; fiscal is already in CONTPAQ.
  int get cents => allocations
      .where((a) => a.channel == 'flujo')
      .fold(0, (sum, a) => sum + a.cents);
  int get fiscalCents => allocations
      .where((a) => a.channel == 'fiscal')
      .fold(0, (sum, a) => sum + a.cents);
  int get recoveredCents => cents + fiscalCents;
  int get pendingCents => requestedCents - recoveredCents;

  HrLoanPayrollPlan limitedTo(int available) {
    var remaining = math.max(0, available);
    final result = <HrLoanAllocation>[];
    for (final due in dues) {
      if (due.channel == 'fiscal') {
        if (fiscalReady) result.add(due);
        continue;
      }
      final amount = math.min(due.cents, remaining);
      if (amount > 0) {
        result.add(
          HrLoanAllocation(due.loanId, due.folio, amount, channel: due.channel),
        );
      }
      remaining -= amount;
    }
    return HrLoanPayrollPlan(
      end: end,
      dues: dues,
      allocations: result,
      fiscalReady: fiscalReady,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 2,
    if (end != null) 'end_date': hrLoanDate(end!),
    'requested_amount': requestedCents / 100,
    'amount': cents / 100,
    'fiscal_amount': fiscalCents / 100,
    'fiscal_ready': fiscalReady,
    'pending_amount': pendingCents / 100,
    'dues': dues.map((a) => a.toJson()).toList(),
    'allocations': allocations.map((a) => a.toJson()).toList(),
  };

  factory HrLoanPayrollPlan.fromSnapshot(Map<String, dynamic> snapshot) {
    final raw = snapshot['loan_fund'];
    if (raw is! Map) return const HrLoanPayrollPlan();
    List<HrLoanAllocation> read(String key) => (raw[key] as List? ?? [])
        .whereType<Map>()
        .map((r) => HrLoanAllocation.fromJson(Map<String, dynamic>.from(r)))
        .toList();
    return HrLoanPayrollPlan(
      end: DateTime.tryParse('${raw['end_date']}'),
      dues: read('dues'),
      allocations: read('allocations'),
      fiscalReady: raw['fiscal_ready'] == true,
    );
  }
}
