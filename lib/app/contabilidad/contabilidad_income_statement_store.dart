import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../commercial/commercial_store.dart';
import '../direction/analysis/menudeo/menudeo_analysis_repository.dart';
import '../direction/direction_cash_taxonomy_store.dart';
import '../finanzas/finanzas_bank_accounts_store.dart';
import '../shared/direction_vault/direction_vault_repository.dart';
import 'contabilidad_income_statement_rules.dart';

const String _kMenCashVouchersView = 'vw_men_cash_vouchers_grid';
const String _kMenCashVoucherLinesTable = 'men_cash_voucher_lines';

class ContabilidadIncomeStatementSnapshot {
  final double revenue;
  final double commercialCost;
  final double commercialResult;
  final double operatingExpense;
  final double administrativeExpense;
  final double financialExpense;
  final double payrollExpense;
  final double recognizedExpenses;
  final double periodResult;
  final double internalExcluded;
  final double reviewPending;

  const ContabilidadIncomeStatementSnapshot({
    required this.revenue,
    required this.commercialCost,
    required this.commercialResult,
    required this.operatingExpense,
    required this.administrativeExpense,
    required this.financialExpense,
    required this.payrollExpense,
    required this.recognizedExpenses,
    required this.periodResult,
    required this.internalExcluded,
    required this.reviewPending,
  });
}

class ContabilidadIncomeStatementLine {
  final String label;
  final double amount;
  final bool emphasis;
  final ColorTone tone;

  const ContabilidadIncomeStatementLine({
    required this.label,
    required this.amount,
    required this.emphasis,
    required this.tone,
  });
}

enum ColorTone { neutral, positive, caution, negative }

class ContabilidadIncomeStatementSourceRow {
  final String label;
  final String detail;
  final double recognizedExpenses;
  final double internalExcluded;
  final double reviewPending;

  const ContabilidadIncomeStatementSourceRow({
    required this.label,
    required this.detail,
    required this.recognizedExpenses,
    required this.internalExcluded,
    required this.reviewPending,
  });
}

class ContabilidadIncomeStatementBreakdownRow {
  final String label;
  final double amount;
  final int count;
  final String sourceLabel;

  const ContabilidadIncomeStatementBreakdownRow({
    required this.label,
    required this.amount,
    required this.count,
    required this.sourceLabel,
  });
}

class ContabilidadIncomeStatementReviewRow {
  final String label;
  final String sourceLabel;
  final double amount;
  final int count;
  final String reason;
  final String suggestedTreatment;
  final List<ContabilidadIncomeStatementReviewMovement> movements;

  const ContabilidadIncomeStatementReviewRow({
    required this.label,
    required this.sourceLabel,
    required this.amount,
    required this.count,
    required this.reason,
    required this.suggestedTreatment,
    this.movements = const <ContabilidadIncomeStatementReviewMovement>[],
  });
}

class ContabilidadIncomeStatementReviewMovement {
  final String id;
  final DateTime? date;
  final String title;
  final String subtitle;
  final double amount;
  final String detail;

  const ContabilidadIncomeStatementReviewMovement({
    required this.id,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.detail,
  });
}

class ContabilidadIncomeStatementFamilyRow {
  final String label;
  final double bankAmount;
  final double vaultAmount;
  final double menudeoAmount;
  final double totalAmount;

  const ContabilidadIncomeStatementFamilyRow({
    required this.label,
    required this.bankAmount,
    required this.vaultAmount,
    required this.menudeoAmount,
    required this.totalAmount,
  });
}

class ContabilidadIncomeStatementDataset {
  final DateTimeRange range;
  final ContabilidadIncomeStatementSnapshot snapshot;
  final List<ContabilidadIncomeStatementLine> lines;
  final List<ContabilidadIncomeStatementSourceRow> sourceRows;
  final List<ContabilidadIncomeStatementFamilyRow> familyExpenseRows;
  final List<ContabilidadIncomeStatementBreakdownRow> expenseBreakdown;
  final List<ContabilidadIncomeStatementReviewRow> reviewRows;
  final List<ContabilidadAccountingFamilyDefinition> familyRows;
  final List<String> insights;
  final List<String> warnings;

  const ContabilidadIncomeStatementDataset({
    required this.range,
    required this.snapshot,
    required this.lines,
    required this.sourceRows,
    required this.familyExpenseRows,
    required this.expenseBreakdown,
    required this.reviewRows,
    required this.familyRows,
    required this.insights,
    required this.warnings,
  });
}

class ContabilidadIncomeStatementStore {
  const ContabilidadIncomeStatementStore();

  Future<ContabilidadIncomeStatementDataset> load({
    required int windowDays,
    required DateTimeRange? dateRange,
  }) async {
    await DirectionCashTaxonomyStore.instance.ensureLoaded();
    final range = _resolveRange(windowDays: windowDays, dateRange: dateRange);

    final results = await Future.wait<dynamic>([
      CommercialStore.loadDashboard(),
      FinanzasBankAccountsStore.loadMovementsStrict(),
      DirectionVaultRepository.instance.loadVouchers(),
      MenudeoAnalysisRepository().loadCashDataset(
        windowDays: windowDays,
        dateRange: dateRange,
      ),
      _loadMenudeoExpenseDetails(range),
    ]);

    final commercial = results[0] as CommercialDashboardBundle;
    final bankRows = results[1] as List<FinanzasBankMovementRecord>;
    final vaultRows = results[2] as List<DirectionVaultVoucherRecord>;
    final menudeoDetailed = results[4] as _DetailedExpenseAggregation;

    var revenue = 0.0;
    var commercialCost = 0.0;

    for (final event in commercial.marketEvents) {
      final eventAt = event.eventAt;
      if (eventAt == null || !_withinRange(eventAt, range)) continue;
      if (event.flow == 'purchase') {
        commercialCost += event.amountTotal;
      } else if (event.flow == 'sale') {
        revenue += event.amountTotal;
      }
    }

    var bankOperating = 0.0;
    var bankAdministrative = 0.0;
    var bankFinancial = 0.0;
    var bankPayroll = 0.0;
    var bankInternal = 0.0;
    var bankReview = 0.0;
    final expenseBreakdown = <ContabilidadIncomeStatementBreakdownRow>[];
    final reviewBreakdown = <ContabilidadIncomeStatementReviewRow>[];

    for (final row in bankRows) {
      if (!_withinRange(row.date, range)) continue;
      if (row.debitAmount <= 0.009) continue;
      final rule = classifyBankCategoryForIncomeStatement(row.category);
      final bucket = _effectiveBankExpenseBucket(row, baseRule: rule);
      switch (bucket) {
        case ContabilidadIncomeStatementBucket.operatingExpense:
          bankOperating += row.debitAmount;
          break;
        case ContabilidadIncomeStatementBucket.administrativeExpense:
          bankAdministrative += row.debitAmount;
          break;
        case ContabilidadIncomeStatementBucket.financialExpense:
          bankFinancial += row.debitAmount;
          break;
        case ContabilidadIncomeStatementBucket.payrollExpense:
          bankPayroll += row.debitAmount;
          break;
        case ContabilidadIncomeStatementBucket.internalTransfer:
          bankInternal += row.debitAmount;
          break;
        case ContabilidadIncomeStatementBucket.reviewRequired:
          bankReview += row.debitAmount;
          _accumulateReviewRow(
            reviewBreakdown,
            _buildBankReviewRow(row, baseRule: rule),
          );
          break;
        case ContabilidadIncomeStatementBucket.revenue:
        case ContabilidadIncomeStatementBucket.commercialCost:
          break;
      }
    }

    for (final row in _groupBankExpenseRows(bankRows, range)) {
      expenseBreakdown.add(row);
    }

    var vaultOperating = 0.0;
    var vaultAdministrative = 0.0;
    var vaultFinancial = 0.0;
    var vaultPayroll = 0.0;
    var vaultInternal = 0.0;
    var vaultReview = 0.0;

    for (final row in vaultRows) {
      if (!_withinRange(row.date, range)) continue;
      if (row.type == 'deposit') continue;
      final rule = classifyCashRubricForIncomeStatement(
        movementType: DirectionCashMovementType.exit,
        rubricLabel: row.rubric,
      );
      final bucket = _effectiveVaultExpenseBucket(row, baseRule: rule);
      switch (bucket) {
        case ContabilidadIncomeStatementBucket.operatingExpense:
          vaultOperating += row.total;
          break;
        case ContabilidadIncomeStatementBucket.administrativeExpense:
          vaultAdministrative += row.total;
          break;
        case ContabilidadIncomeStatementBucket.financialExpense:
          vaultFinancial += row.total;
          break;
        case ContabilidadIncomeStatementBucket.payrollExpense:
          vaultPayroll += row.total;
          break;
        case ContabilidadIncomeStatementBucket.internalTransfer:
          vaultInternal += row.total;
          break;
        case ContabilidadIncomeStatementBucket.reviewRequired:
          vaultReview += row.total;
          _accumulateReviewRow(
            reviewBreakdown,
            _buildVaultReviewRow(row, baseRule: rule),
          );
          break;
        case ContabilidadIncomeStatementBucket.revenue:
        case ContabilidadIncomeStatementBucket.commercialCost:
          break;
      }
    }

    for (final row in _groupVaultExpenseRows(vaultRows, range)) {
      expenseBreakdown.add(row);
    }

    var menudeoOperating = 0.0;
    var menudeoAdministrative = 0.0;
    var menudeoFinancial = 0.0;
    var menudeoPayroll = 0.0;
    var menudeoInternal = 0.0;
    var menudeoReview = 0.0;
    menudeoOperating = menudeoDetailed.operating;
    menudeoAdministrative = menudeoDetailed.administrative;
    menudeoFinancial = menudeoDetailed.financial;
    menudeoPayroll = menudeoDetailed.payroll;
    menudeoInternal = menudeoDetailed.internal;
    menudeoReview = menudeoDetailed.review;
    expenseBreakdown.addAll(menudeoDetailed.breakdown);
    reviewBreakdown.addAll(menudeoDetailed.reviewRows);

    expenseBreakdown.sort((a, b) => b.amount.compareTo(a.amount));
    reviewBreakdown.sort((a, b) => b.amount.compareTo(a.amount));

    final operatingExpense = bankOperating + vaultOperating + menudeoOperating;
    final administrativeExpense =
        bankAdministrative + vaultAdministrative + menudeoAdministrative;
    final financialExpense = bankFinancial + vaultFinancial + menudeoFinancial;
    final payrollExpense = bankPayroll + vaultPayroll + menudeoPayroll;
    final recognizedExpenses =
        operatingExpense +
        administrativeExpense +
        financialExpense +
        payrollExpense;
    final internalExcluded = bankInternal + vaultInternal + menudeoInternal;
    final reviewPending = bankReview + vaultReview + menudeoReview;
    final commercialResult = revenue - commercialCost;
    final periodResult = commercialResult - recognizedExpenses;

    final snapshot = ContabilidadIncomeStatementSnapshot(
      revenue: revenue,
      commercialCost: commercialCost,
      commercialResult: commercialResult,
      operatingExpense: operatingExpense,
      administrativeExpense: administrativeExpense,
      financialExpense: financialExpense,
      payrollExpense: payrollExpense,
      recognizedExpenses: recognizedExpenses,
      periodResult: periodResult,
      internalExcluded: internalExcluded,
      reviewPending: reviewPending,
    );

    final lines = <ContabilidadIncomeStatementLine>[
      ContabilidadIncomeStatementLine(
        label: 'Ingresos',
        amount: revenue,
        emphasis: false,
        tone: ColorTone.positive,
      ),
      ContabilidadIncomeStatementLine(
        label: 'Costo comercial',
        amount: -commercialCost,
        emphasis: false,
        tone: ColorTone.caution,
      ),
      ContabilidadIncomeStatementLine(
        label: 'Resultado comercial',
        amount: commercialResult,
        emphasis: true,
        tone: commercialResult >= 0 ? ColorTone.positive : ColorTone.negative,
      ),
      ContabilidadIncomeStatementLine(
        label: 'Gasto operativo',
        amount: -operatingExpense,
        emphasis: false,
        tone: ColorTone.neutral,
      ),
      ContabilidadIncomeStatementLine(
        label: 'Gasto administrativo',
        amount: -administrativeExpense,
        emphasis: false,
        tone: ColorTone.neutral,
      ),
      ContabilidadIncomeStatementLine(
        label: 'Gasto financiero',
        amount: -financialExpense,
        emphasis: false,
        tone: ColorTone.neutral,
      ),
      ContabilidadIncomeStatementLine(
        label: 'Nomina',
        amount: -payrollExpense,
        emphasis: false,
        tone: ColorTone.neutral,
      ),
      ContabilidadIncomeStatementLine(
        label: 'Resultado del periodo',
        amount: periodResult,
        emphasis: true,
        tone: periodResult >= 0 ? ColorTone.positive : ColorTone.negative,
      ),
    ];

    final sourceRows = <ContabilidadIncomeStatementSourceRow>[
      ContabilidadIncomeStatementSourceRow(
        label: 'Bancos',
        detail: 'Gastos reconocidos por categoria bancaria',
        recognizedExpenses:
            bankOperating + bankAdministrative + bankFinancial + bankPayroll,
        internalExcluded: bankInternal,
        reviewPending: bankReview,
      ),
      ContabilidadIncomeStatementSourceRow(
        label: 'Bóveda',
        detail: 'Gastos reconocidos por rubro de salida',
        recognizedExpenses:
            vaultOperating +
            vaultAdministrative +
            vaultFinancial +
            vaultPayroll,
        internalExcluded: vaultInternal,
        reviewPending: vaultReview,
      ),
      ContabilidadIncomeStatementSourceRow(
        label: 'Menudeo',
        detail: 'Gastos reconocidos por rubro de caja',
        recognizedExpenses:
            menudeoOperating +
            menudeoAdministrative +
            menudeoFinancial +
            menudeoPayroll,
        internalExcluded: menudeoInternal,
        reviewPending: menudeoReview,
      ),
    ];

    final familyExpenseRows = <ContabilidadIncomeStatementFamilyRow>[
      ContabilidadIncomeStatementFamilyRow(
        label: 'Nómina',
        bankAmount: bankPayroll,
        vaultAmount: vaultPayroll,
        menudeoAmount: menudeoPayroll,
        totalAmount: bankPayroll + vaultPayroll + menudeoPayroll,
      ),
      ContabilidadIncomeStatementFamilyRow(
        label: 'Administrativo',
        bankAmount: bankAdministrative,
        vaultAmount: vaultAdministrative,
        menudeoAmount: menudeoAdministrative,
        totalAmount:
            bankAdministrative + vaultAdministrative + menudeoAdministrative,
      ),
      ContabilidadIncomeStatementFamilyRow(
        label: 'Operativo',
        bankAmount: bankOperating,
        vaultAmount: vaultOperating,
        menudeoAmount: menudeoOperating,
        totalAmount: bankOperating + vaultOperating + menudeoOperating,
      ),
      if (financialExpense > 0.009)
        ContabilidadIncomeStatementFamilyRow(
          label: 'Financiero',
          bankAmount: bankFinancial,
          vaultAmount: vaultFinancial,
          menudeoAmount: menudeoFinancial,
          totalAmount: bankFinancial + vaultFinancial + menudeoFinancial,
        ),
    ]..removeWhere((row) => row.totalAmount <= 0.009);

    final insights = _buildInsights(snapshot: snapshot, sourceRows: sourceRows);
    final warnings = _buildWarnings(snapshot);

    return ContabilidadIncomeStatementDataset(
      range: range,
      snapshot: snapshot,
      lines: lines,
      sourceRows: sourceRows,
      familyExpenseRows: familyExpenseRows,
      expenseBreakdown: expenseBreakdown.take(12).toList(growable: false),
      reviewRows: reviewBreakdown.take(16).toList(growable: false),
      familyRows: contabilidadAccountingFamilies,
      insights: insights,
      warnings: warnings,
    );
  }

  List<ContabilidadIncomeStatementBreakdownRow> _groupBankExpenseRows(
    List<FinanzasBankMovementRecord> rows,
    DateTimeRange range,
  ) {
    final totals = <String, ({double amount, int count})>{};
    for (final row in rows) {
      if (!_withinRange(row.date, range) || row.debitAmount <= 0.009) continue;
      final rule = classifyBankCategoryForIncomeStatement(row.category);
      final bucket = _effectiveBankExpenseBucket(row, baseRule: rule);
      if (!_isRecognizedExpenseBucket(bucket)) continue;
      if (bucket == ContabilidadIncomeStatementBucket.revenue ||
          bucket == ContabilidadIncomeStatementBucket.commercialCost) {
        continue;
      }
      final key = row.category.trim().isEmpty
          ? 'Sin categoria'
          : row.category.trim();
      final current = totals[key] ?? (amount: 0.0, count: 0);
      totals[key] = (
        amount: current.amount + row.debitAmount,
        count: current.count + 1,
      );
    }
    return totals.entries
        .map(
          (entry) => ContabilidadIncomeStatementBreakdownRow(
            label: entry.key,
            amount: entry.value.amount,
            count: entry.value.count,
            sourceLabel: 'Bancos',
          ),
        )
        .toList(growable: false);
  }

  List<ContabilidadIncomeStatementBreakdownRow> _groupVaultExpenseRows(
    List<DirectionVaultVoucherRecord> rows,
    DateTimeRange range,
  ) {
    final totals = <String, ({double amount, int count})>{};
    for (final row in rows) {
      if (!_withinRange(row.date, range) || row.type == 'deposit') continue;
      final rule = classifyCashRubricForIncomeStatement(
        movementType: DirectionCashMovementType.exit,
        rubricLabel: row.rubric,
      );
      final bucket = _effectiveVaultExpenseBucket(row, baseRule: rule);
      if (!_isRecognizedExpenseBucket(bucket)) continue;
      if (bucket == ContabilidadIncomeStatementBucket.revenue ||
          bucket == ContabilidadIncomeStatementBucket.commercialCost) {
        continue;
      }
      final key = row.rubric.trim().isEmpty ? 'Sin rubro' : row.rubric.trim();
      final current = totals[key] ?? (amount: 0.0, count: 0);
      totals[key] = (
        amount: current.amount + row.total,
        count: current.count + 1,
      );
    }
    return totals.entries
        .map(
          (entry) => ContabilidadIncomeStatementBreakdownRow(
            label: entry.key,
            amount: entry.value.amount,
            count: entry.value.count,
            sourceLabel: 'Bóveda',
          ),
        )
        .toList(growable: false);
  }

  List<String> _buildInsights({
    required ContabilidadIncomeStatementSnapshot snapshot,
    required List<ContabilidadIncomeStatementSourceRow> sourceRows,
  }) {
    final insights = <String>[];
    if (snapshot.periodResult > 0.009) {
      insights.add(
        'El periodo cierra positivo después de costo y gastos reconocidos.',
      );
    } else if (snapshot.periodResult < -0.009) {
      insights.add(
        'El periodo cierra negativo con los gastos hoy reconocidos.',
      );
    } else {
      insights.add(
        'El periodo cierra prácticamente parejo con la lectura actual.',
      );
    }
    if (snapshot.financialExpense > snapshot.operatingExpense &&
        snapshot.financialExpense > 0.009) {
      insights.add(
        'El gasto financiero ya pesa más que el gasto operativo en este corte.',
      );
    }
    final dominantSource = sourceRows
        .fold<ContabilidadIncomeStatementSourceRow?>(
          null,
          (best, row) =>
              best == null || row.recognizedExpenses > best.recognizedExpenses
              ? row
              : best,
        );
    if (dominantSource != null && dominantSource.recognizedExpenses > 0.009) {
      insights.add(
        '${dominantSource.label} concentra la mayor parte del gasto reconocido.',
      );
    }
    if (snapshot.reviewPending > snapshot.recognizedExpenses * 0.20 &&
        snapshot.reviewPending > 0.009) {
      insights.add(
        'Hay una parte relevante del periodo todavía fuera del resultado por revisión.',
      );
    }
    return insights;
  }

  List<String> _buildWarnings(ContabilidadIncomeStatementSnapshot snapshot) {
    final warnings = <String>[
      'Este estado ya calcula importes del periodo, pero sigue excluyendo internos y rubros en revisión.',
      'Préstamos no se cuentan como ingreso y pagos de capital no se cuentan como gasto.',
      'Pago de tarjeta, préstamo o amortización solo entra si puede defenderse como interés o comisión real.',
    ];
    if (snapshot.reviewPending > 0.009) {
      warnings.add(
        'Hay ${snapshot.reviewPending.toStringAsFixed(2)} fuera del resultado porque aún requiere clasificación contable.',
      );
    }
    if (snapshot.internalExcluded > 0.009) {
      warnings.add(
        'Se excluyeron ${snapshot.internalExcluded.toStringAsFixed(2)} de movimientos internos para no inflar utilidad.',
      );
    }
    warnings.add(
      'La futura fuente de Logística todavía no está incorporada en este resultado.',
    );
    return warnings;
  }

  DateTimeRange _resolveRange({
    required int windowDays,
    required DateTimeRange? dateRange,
  }) {
    if (dateRange != null) return dateRange;
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: windowDays - 1)),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  bool _withinRange(DateTime value, DateTimeRange range) {
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
      999,
    );
    return !value.isBefore(start) && !value.isAfter(end);
  }

  bool _isRecognizedExpenseBucket(ContabilidadIncomeStatementBucket bucket) {
    return bucket == ContabilidadIncomeStatementBucket.operatingExpense ||
        bucket == ContabilidadIncomeStatementBucket.administrativeExpense ||
        bucket == ContabilidadIncomeStatementBucket.financialExpense ||
        bucket == ContabilidadIncomeStatementBucket.payrollExpense;
  }

  ContabilidadIncomeStatementBucket _effectiveBankExpenseBucket(
    FinanzasBankMovementRecord row, {
    required ContabilidadIncomeStatementRuleRow baseRule,
  }) {
    if (baseRule.bucket != ContabilidadIncomeStatementBucket.financialExpense) {
      return baseRule.bucket;
    }
    final context = _normalizeFinanceText(
      '${row.comment} ${row.reference} ${row.counterpartyNameSnapshot}',
    );
    if (_looksLikeRealFinancialExpense(context)) {
      return ContabilidadIncomeStatementBucket.financialExpense;
    }
    if (_looksLikeDebtOrPrincipal(context)) {
      return ContabilidadIncomeStatementBucket.reviewRequired;
    }
    return ContabilidadIncomeStatementBucket.reviewRequired;
  }

  ContabilidadIncomeStatementBucket _effectiveVaultExpenseBucket(
    DirectionVaultVoucherRecord row, {
    required ContabilidadIncomeStatementRuleRow baseRule,
  }) {
    if (baseRule.bucket != ContabilidadIncomeStatementBucket.financialExpense) {
      return baseRule.bucket;
    }
    var financial = 0.0;
    var review = 0.0;
    for (final line in row.lines) {
      final bucket = _effectiveCashFinancialLineBucket(
        concept: line.concept,
        subconcept: line.subconcept,
        comment: line.comment,
      );
      if (bucket == ContabilidadIncomeStatementBucket.financialExpense) {
        financial += line.amountValue;
      } else {
        review += line.amountValue;
      }
    }
    if (financial > 0.009 && review <= 0.009) {
      return ContabilidadIncomeStatementBucket.financialExpense;
    }
    if (financial <= 0.009) {
      return ContabilidadIncomeStatementBucket.reviewRequired;
    }
    return ContabilidadIncomeStatementBucket.reviewRequired;
  }

  Future<_DetailedExpenseAggregation> _loadMenudeoExpenseDetails(
    DateTimeRange range,
  ) async {
    final supa = Supabase.instance.client;
    final voucherRows = await supa
        .from(_kMenCashVouchersView)
        .select('id,voucher_date,voucher_type,rubric,total_amount')
        .order('voucher_date', ascending: false);
    final vouchers = (voucherRows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where((row) {
          final rawDate = DateTime.tryParse(
            (row['voucher_date'] ?? '').toString(),
          );
          return rawDate != null &&
              _withinRange(rawDate, range) &&
              (row['voucher_type'] ?? '').toString() == 'expense';
        })
        .toList(growable: false);
    if (vouchers.isEmpty) {
      return const _DetailedExpenseAggregation.empty();
    }

    final voucherIds = vouchers
        .map((row) => (row['id'] ?? '').toString())
        .where((id) => id.trim().isNotEmpty)
        .toList(growable: false);
    final lineRows = <Map<String, dynamic>>[];
    for (final batch in _chunk(voucherIds, 80)) {
      final rows = await supa
          .from(_kMenCashVoucherLinesTable)
          .select('voucher_id,concept,subconcept,amount,comment')
          .inFilter('voucher_id', batch)
          .order('voucher_id');
      lineRows.addAll(
        (rows as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false),
      );
    }
    final voucherById = <String, Map<String, dynamic>>{
      for (final row in vouchers) (row['id'] ?? '').toString(): row,
    };
    var operating = 0.0;
    var administrative = 0.0;
    var financial = 0.0;
    var payroll = 0.0;
    var internal = 0.0;
    var review = 0.0;
    final breakdownTotals = <String, ({double amount, int count})>{};
    final reviewRows = <ContabilidadIncomeStatementReviewRow>[];

    for (final line in lineRows) {
      final voucherId = (line['voucher_id'] ?? '').toString();
      final parent = voucherById[voucherId];
      if (parent == null) continue;
      final rubric = (parent['rubric'] ?? '').toString();
      final amount = ((line['amount'] as num?) ?? 0).toDouble();
      final baseRule = classifyCashRubricForIncomeStatement(
        movementType: DirectionCashMovementType.exit,
        rubricLabel: rubric,
      );
      var bucket = baseRule.bucket;
      if (baseRule.bucket ==
          ContabilidadIncomeStatementBucket.financialExpense) {
        bucket = _effectiveCashFinancialLineBucket(
          concept: (line['concept'] ?? '').toString(),
          subconcept: (line['subconcept'] ?? '').toString(),
          comment: (line['comment'] ?? '').toString(),
        );
      }
      switch (bucket) {
        case ContabilidadIncomeStatementBucket.operatingExpense:
          operating += amount;
          _accumulateBreakdown(breakdownTotals, rubric, amount);
          break;
        case ContabilidadIncomeStatementBucket.administrativeExpense:
          administrative += amount;
          _accumulateBreakdown(breakdownTotals, rubric, amount);
          break;
        case ContabilidadIncomeStatementBucket.financialExpense:
          financial += amount;
          _accumulateBreakdown(breakdownTotals, rubric, amount);
          break;
        case ContabilidadIncomeStatementBucket.payrollExpense:
          payroll += amount;
          _accumulateBreakdown(breakdownTotals, rubric, amount);
          break;
        case ContabilidadIncomeStatementBucket.internalTransfer:
          internal += amount;
          break;
        case ContabilidadIncomeStatementBucket.reviewRequired:
          review += amount;
          _accumulateReviewRow(
            reviewRows,
            _buildMenudeoReviewRow(
              rubric: rubric,
              concept: (line['concept'] ?? '').toString(),
              subconcept: (line['subconcept'] ?? '').toString(),
              amount: amount,
            ),
          );
          break;
        case ContabilidadIncomeStatementBucket.revenue:
        case ContabilidadIncomeStatementBucket.commercialCost:
          break;
      }
    }

    final breakdown = breakdownTotals.entries
        .map(
          (entry) => ContabilidadIncomeStatementBreakdownRow(
            label: entry.key,
            amount: entry.value.amount,
            count: entry.value.count,
            sourceLabel: 'Menudeo',
          ),
        )
        .toList(growable: false);

    return _DetailedExpenseAggregation(
      operating: operating,
      administrative: administrative,
      financial: financial,
      payroll: payroll,
      internal: internal,
      review: review,
      breakdown: breakdown,
      reviewRows: reviewRows,
    );
  }

  ContabilidadIncomeStatementBucket _effectiveCashFinancialLineBucket({
    required String concept,
    required String subconcept,
    required String comment,
  }) {
    final context = _normalizeFinanceText('$concept $subconcept $comment');
    if (_looksLikeRealFinancialExpense(context)) {
      return ContabilidadIncomeStatementBucket.financialExpense;
    }
    if (_looksLikeDebtOrPrincipal(context)) {
      return ContabilidadIncomeStatementBucket.reviewRequired;
    }
    return ContabilidadIncomeStatementBucket.reviewRequired;
  }

  bool _looksLikeRealFinancialExpense(String value) {
    return value.contains('INTERES') ||
        value.contains('INTERESES') ||
        value.contains('COMISION') ||
        value.contains('COMISIONES') ||
        value.contains('ANUALIDAD') ||
        value.contains('RECARGO');
  }

  bool _looksLikeDebtOrPrincipal(String value) {
    return value.contains('PRESTAMO') ||
        value.contains('KONFIO') ||
        value.contains('CREDITO') ||
        value.contains('TARJETA') ||
        value.contains('CAPITAL') ||
        value.contains('AMORTIZACION') ||
        value.contains('LIQUIDACION');
  }

  String _normalizeFinanceText(String value) {
    return value
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U');
  }

  void _accumulateBreakdown(
    Map<String, ({double amount, int count})> totals,
    String rubric,
    double amount,
  ) {
    final key = rubric.trim().isEmpty ? 'Sin rubro' : rubric.trim();
    final current = totals[key] ?? (amount: 0.0, count: 0);
    totals[key] = (amount: current.amount + amount, count: current.count + 1);
  }

  void _accumulateReviewRow(
    List<ContabilidadIncomeStatementReviewRow> rows,
    ContabilidadIncomeStatementReviewRow incoming,
  ) {
    final index = rows.indexWhere(
      (row) =>
          row.label == incoming.label &&
          row.sourceLabel == incoming.sourceLabel &&
          row.reason == incoming.reason &&
          row.suggestedTreatment == incoming.suggestedTreatment,
    );
    if (index == -1) {
      rows.add(incoming);
      return;
    }
    final current = rows[index];
    rows[index] = ContabilidadIncomeStatementReviewRow(
      label: current.label,
      sourceLabel: current.sourceLabel,
      amount: current.amount + incoming.amount,
      count: current.count + incoming.count,
      reason: current.reason,
      suggestedTreatment: current.suggestedTreatment,
      movements: <ContabilidadIncomeStatementReviewMovement>[
        ...current.movements,
        ...incoming.movements,
      ],
    );
  }

  ContabilidadIncomeStatementReviewRow _buildBankReviewRow(
    FinanzasBankMovementRecord row, {
    required ContabilidadIncomeStatementRuleRow baseRule,
  }) {
    final context = _normalizeFinanceText(
      '${row.category} ${row.comment} ${row.reference} ${row.counterpartyNameSnapshot}',
    );
    if (baseRule.bucket == ContabilidadIncomeStatementBucket.financialExpense &&
        _looksLikeDebtOrPrincipal(context)) {
      return ContabilidadIncomeStatementReviewRow(
        label: row.category.trim().isEmpty
            ? 'Sin categoria'
            : row.category.trim(),
        sourceLabel: 'Bancos',
        amount: row.debitAmount,
        count: 1,
        reason:
            'Parece pago de deuda, capital o tarjeta; no gasto del periodo.',
        suggestedTreatment:
            'Excluir del resultado y tratar como pasivo/capital.',
        movements: <ContabilidadIncomeStatementReviewMovement>[
          _buildBankReviewMovement(row),
        ],
      );
    }
    if (baseRule.bucket == ContabilidadIncomeStatementBucket.financialExpense) {
      return ContabilidadIncomeStatementReviewRow(
        label: row.category.trim().isEmpty
            ? 'Sin categoria'
            : row.category.trim(),
        sourceLabel: 'Bancos',
        amount: row.debitAmount,
        count: 1,
        reason:
            'Movimiento financiero ambiguo sin evidencia suficiente de interés o comisión.',
        suggestedTreatment:
            'Revisar comentario, referencia y soporte bancario.',
        movements: <ContabilidadIncomeStatementReviewMovement>[
          _buildBankReviewMovement(row),
        ],
      );
    }
    return ContabilidadIncomeStatementReviewRow(
      label: row.category.trim().isEmpty
          ? 'Sin categoria'
          : row.category.trim(),
      sourceLabel: 'Bancos',
      amount: row.debitAmount,
      count: 1,
      reason: 'La categoria todavía no tiene tratamiento contable automático.',
      suggestedTreatment:
          'Reclasificar a gasto, interno o pasivo según soporte.',
      movements: <ContabilidadIncomeStatementReviewMovement>[
        _buildBankReviewMovement(row),
      ],
    );
  }

  ContabilidadIncomeStatementReviewRow _buildVaultReviewRow(
    DirectionVaultVoucherRecord row, {
    required ContabilidadIncomeStatementRuleRow baseRule,
  }) {
    final context = _normalizeFinanceText(
      '${row.rubric} ${row.comment} ${row.lines.map((line) => '${line.concept} ${line.subconcept} ${line.comment}').join(' ')}',
    );
    if (baseRule.bucket == ContabilidadIncomeStatementBucket.financialExpense &&
        _looksLikeDebtOrPrincipal(context)) {
      return ContabilidadIncomeStatementReviewRow(
        label: row.rubric.trim().isEmpty ? 'Sin rubro' : row.rubric.trim(),
        sourceLabel: 'Bóveda',
        amount: row.total,
        count: 1,
        reason:
            'Parece salida para préstamo, capital o tarjeta, no gasto del periodo.',
        suggestedTreatment:
            'Excluir del resultado y clasificar como pasivo/capital.',
        movements: <ContabilidadIncomeStatementReviewMovement>[
          _buildVaultReviewMovement(row),
        ],
      );
    }
    if (baseRule.bucket == ContabilidadIncomeStatementBucket.financialExpense) {
      return ContabilidadIncomeStatementReviewRow(
        label: row.rubric.trim().isEmpty ? 'Sin rubro' : row.rubric.trim(),
        sourceLabel: 'Bóveda',
        amount: row.total,
        count: 1,
        reason:
            'Rubro financiero sin evidencia suficiente de interés o comisión real.',
        suggestedTreatment: 'Revisar renglones y soporte del movimiento.',
        movements: <ContabilidadIncomeStatementReviewMovement>[
          _buildVaultReviewMovement(row),
        ],
      );
    }
    return ContabilidadIncomeStatementReviewRow(
      label: row.rubric.trim().isEmpty ? 'Sin rubro' : row.rubric.trim(),
      sourceLabel: 'Bóveda',
      amount: row.total,
      count: 1,
      reason:
          'El rubro sigue fuera hasta definir si es gasto, personal, interno o ajuste.',
      suggestedTreatment: 'Dictaminar contablemente antes de incorporarlo.',
      movements: <ContabilidadIncomeStatementReviewMovement>[
        _buildVaultReviewMovement(row),
      ],
    );
  }

  ContabilidadIncomeStatementReviewRow _buildMenudeoReviewRow({
    required String rubric,
    required String concept,
    required String subconcept,
    required double amount,
  }) {
    final context = _normalizeFinanceText('$rubric $concept $subconcept');
    if (_looksLikeDebtOrPrincipal(context)) {
      return ContabilidadIncomeStatementReviewRow(
        label: rubric.trim().isEmpty ? 'Sin rubro' : rubric.trim(),
        sourceLabel: 'Menudeo',
        amount: amount,
        count: 1,
        reason:
            'Parece pago de deuda, capital o tarjeta, no gasto del periodo.',
        suggestedTreatment:
            'Excluir del resultado y clasificar como pasivo/capital.',
        movements: <ContabilidadIncomeStatementReviewMovement>[
          _buildMenudeoReviewMovement(
            rubric: rubric,
            concept: concept,
            subconcept: subconcept,
            amount: amount,
          ),
        ],
      );
    }
    if (_looksLikeRealFinancialExpense(context)) {
      return ContabilidadIncomeStatementReviewRow(
        label: rubric.trim().isEmpty ? 'Sin rubro' : rubric.trim(),
        sourceLabel: 'Menudeo',
        amount: amount,
        count: 1,
        reason:
            'Parece financiero, pero falta evidencia suficiente para reconocerlo.',
        suggestedTreatment:
            'Revisar soporte y reclasificar si fue interés o comisión real.',
        movements: <ContabilidadIncomeStatementReviewMovement>[
          _buildMenudeoReviewMovement(
            rubric: rubric,
            concept: concept,
            subconcept: subconcept,
            amount: amount,
          ),
        ],
      );
    }
    return ContabilidadIncomeStatementReviewRow(
      label: rubric.trim().isEmpty ? 'Sin rubro' : rubric.trim(),
      sourceLabel: 'Menudeo',
      amount: amount,
      count: 1,
      reason:
          'El rubro/concepto todavía no tiene tratamiento contable automático.',
      suggestedTreatment: 'Definir si fue gasto, personal, interno o ajuste.',
      movements: <ContabilidadIncomeStatementReviewMovement>[
        _buildMenudeoReviewMovement(
          rubric: rubric,
          concept: concept,
          subconcept: subconcept,
          amount: amount,
        ),
      ],
    );
  }

  ContabilidadIncomeStatementReviewMovement _buildBankReviewMovement(
    FinanzasBankMovementRecord row,
  ) {
    final subtitleParts = <String>[
      if (row.reference.trim().isNotEmpty) row.reference.trim(),
      if (row.counterpartyNameSnapshot.trim().isNotEmpty)
        row.counterpartyNameSnapshot.trim(),
    ];
    return ContabilidadIncomeStatementReviewMovement(
      id: row.id,
      date: row.date,
      title: row.category.trim().isEmpty
          ? 'Sin categoría'
          : row.category.trim(),
      subtitle: subtitleParts.isEmpty
          ? 'Movimiento bancario'
          : subtitleParts.join(' · '),
      amount: row.debitAmount,
      detail: row.comment.trim().isEmpty
          ? 'Sin comentario adicional.'
          : row.comment.trim(),
    );
  }

  ContabilidadIncomeStatementReviewMovement _buildVaultReviewMovement(
    DirectionVaultVoucherRecord row,
  ) {
    final firstLine = row.lines.isEmpty ? null : row.lines.first;
    final subtitleParts = <String>[
      if (row.folio.trim().isNotEmpty) 'Folio ${row.folio.trim()}',
      if (row.person.trim().isNotEmpty) row.person.trim(),
    ];
    final detailParts = <String>[
      if (row.comment.trim().isNotEmpty) row.comment.trim(),
      if (firstLine != null)
        [
          firstLine.concept.trim(),
          firstLine.subconcept.trim(),
          firstLine.comment.trim(),
        ].where((part) => part.isNotEmpty).join(' · '),
    ].where((part) => part.isNotEmpty).toList(growable: false);
    return ContabilidadIncomeStatementReviewMovement(
      id: row.id,
      date: row.date,
      title: row.rubric.trim().isEmpty ? 'Sin rubro' : row.rubric.trim(),
      subtitle: subtitleParts.isEmpty
          ? 'Salida de bóveda'
          : subtitleParts.join(' · '),
      amount: row.total,
      detail: detailParts.isEmpty
          ? 'Sin detalle adicional.'
          : detailParts.join(' | '),
    );
  }

  ContabilidadIncomeStatementReviewMovement _buildMenudeoReviewMovement({
    required String rubric,
    required String concept,
    required String subconcept,
    required double amount,
  }) {
    final title = rubric.trim().isEmpty ? 'Sin rubro' : rubric.trim();
    final subtitle = <String>[
      concept.trim(),
      subconcept.trim(),
    ].where((part) => part.isNotEmpty).join(' · ');
    return ContabilidadIncomeStatementReviewMovement(
      id: 'men-review-$title-${concept.trim()}-${subconcept.trim()}-${amount.toStringAsFixed(2)}',
      date: null,
      title: title,
      subtitle: subtitle.isEmpty ? 'Movimiento de menudeo' : subtitle,
      amount: amount,
      detail: 'Línea de egreso de menudeo pendiente de clasificación.',
    );
  }

  Iterable<List<String>> _chunk(List<String> items, int size) sync* {
    for (var i = 0; i < items.length; i += size) {
      final end = (i + size < items.length) ? i + size : items.length;
      yield items.sublist(i, end);
    }
  }
}

class _DetailedExpenseAggregation {
  final double operating;
  final double administrative;
  final double financial;
  final double payroll;
  final double internal;
  final double review;
  final List<ContabilidadIncomeStatementBreakdownRow> breakdown;
  final List<ContabilidadIncomeStatementReviewRow> reviewRows;

  const _DetailedExpenseAggregation({
    required this.operating,
    required this.administrative,
    required this.financial,
    required this.payroll,
    required this.internal,
    required this.review,
    required this.breakdown,
    required this.reviewRows,
  });

  const _DetailedExpenseAggregation.empty()
    : operating = 0,
      administrative = 0,
      financial = 0,
      payroll = 0,
      internal = 0,
      review = 0,
      breakdown = const <ContabilidadIncomeStatementBreakdownRow>[],
      reviewRows = const <ContabilidadIncomeStatementReviewRow>[];
}
