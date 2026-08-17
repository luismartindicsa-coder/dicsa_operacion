import '../compras/compras_tickets_store.dart';
import 'finanzas_bank_accounts_store.dart';
import 'finanzas_company_directory_store.dart';
import 'finanzas_fixed_payments_store.dart';
import 'finanzas_payment_learning_store.dart';
import 'finanzas_payment_center_reserves_store.dart';
import 'finanzas_provider_accounts_store.dart';

enum FinanzasPaymentCenterPriorityBucket {
  obligatorio('Obligatorio'),
  urgente('Urgente'),
  recomendado('Recomendado'),
  postergable('Postergable');

  final String label;
  const FinanzasPaymentCenterPriorityBucket(this.label);
}

enum FinanzasPaymentCenterExecutionDecision {
  pagarCompleto('Pagar completo'),
  abonar('Abonar'),
  esperar('Esperar');

  final String label;
  const FinanzasPaymentCenterExecutionDecision(this.label);
}

enum FinanzasPaymentCenterBudgetBand {
  minimoHoy('Minimo hoy'),
  recomendadoHoy('Recomendado hoy'),
  postergable('Postergable'),
  riesgoRevisar('Riesgo a revisar');

  final String label;
  const FinanzasPaymentCenterBudgetBand(this.label);
}

class FinanzasPaymentCenterPriorityMeta {
  final FinanzasPaymentCenterPriorityBucket bucket;
  final List<String> reasons;
  final int score;

  const FinanzasPaymentCenterPriorityMeta({
    required this.bucket,
    required this.reasons,
    required this.score,
  });
}

class FinanzasPaymentCenterOperationalItem {
  final String providerId;
  final String providerName;
  final FinanzasPaymentCenterPriorityBucket bucket;
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
  bool isPreviewMock;
  double availableBalance;
  bool canPayNow;
  FinanzasPaymentCenterExecutionDecision executionDecision;
  double executionAmount;
  String executionSummary;

  FinanzasPaymentCenterOperationalItem({
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
    this.isPreviewMock = false,
    this.availableBalance = 0,
    this.canPayNow = false,
    this.executionDecision = FinanzasPaymentCenterExecutionDecision.esperar,
    this.executionAmount = 0,
    this.executionSummary = '',
  });

  String get stableKey =>
      '$providerId|$itemType|$sourceLabel|${linkedInvoiceId ?? linkedAgreementId ?? linkedFixedPaymentId ?? ''}';
}

class FinanzasPaymentCenterSourceSnapshot {
  final List<FinanzasCompanyDirectoryRecord> directory;
  final List<ComprasTicketRecord> tickets;
  final List<ComprasTicketPaymentApplicationRecord> ticketApplications;
  final List<FinanzasSupplierInvoiceRecord> invoices;
  final List<FinanzasSupplierAgreementRecord> agreements;
  final List<FinanzasSupplierAgreementInstallmentRecord> installments;
  final List<FinanzasSupplierAgreementInvoiceRecord> agreementInvoiceLinks;
  final List<FinanzasBankMovementRecord> bankMovements;
  final List<FinanzasFixedPaymentRecord> fixedPayments;
  final List<FinanzasPaymentLearningRecord> learningLogs;
  final List<FinanzasPaymentCenterReserveRecord> reserves;

  const FinanzasPaymentCenterSourceSnapshot({
    required this.directory,
    required this.tickets,
    required this.ticketApplications,
    required this.invoices,
    required this.agreements,
    required this.installments,
    required this.agreementInvoiceLinks,
    required this.bankMovements,
    required this.fixedPayments,
    required this.learningLogs,
    required this.reserves,
  });
}

class FinanzasPaymentCenterReserveImpactSummary {
  final double realTotalBalance;
  final double visibleReserveTotal;
  final double blockingReserveTotal;
  final double provisionalVisibleTotal;
  final double accountScopedBlockingTotal;
  final double globalBlockingTotal;
  final double availableAfterBlocking;
  final Map<String, double> accountReserveAmounts;
  final Map<String, double> accountAvailableBalances;
  final List<FinanzasPaymentCenterReserveRecord> activeReserves;

  const FinanzasPaymentCenterReserveImpactSummary({
    required this.realTotalBalance,
    required this.visibleReserveTotal,
    required this.blockingReserveTotal,
    required this.provisionalVisibleTotal,
    required this.accountScopedBlockingTotal,
    required this.globalBlockingTotal,
    required this.availableAfterBlocking,
    required this.accountReserveAmounts,
    required this.accountAvailableBalances,
    required this.activeReserves,
  });

  const FinanzasPaymentCenterReserveImpactSummary.empty()
    : realTotalBalance = 0,
      visibleReserveTotal = 0,
      blockingReserveTotal = 0,
      provisionalVisibleTotal = 0,
      accountScopedBlockingTotal = 0,
      globalBlockingTotal = 0,
      availableAfterBlocking = 0,
      accountReserveAmounts = const <String, double>{},
      accountAvailableBalances = const <String, double>{},
      activeReserves = const <FinanzasPaymentCenterReserveRecord>[];

  int get activeCount => activeReserves.length;

  int get accountPressureCount =>
      accountReserveAmounts.values.where((value) => value > 0.009).length;

  int get globalReserveCount =>
      activeReserves.where((row) => row.isGlobal).length;

  int get blockingReserveCount =>
      activeReserves.where((row) => row.blocksCash).length;
}

class FinanzasPaymentCenterBudgetProviderSummary {
  final String providerId;
  final String providerName;
  final String accountKey;
  final String targetCompany;
  final String targetBranch;
  final double minimumTodayAmount;
  final double recommendedAdditionalAmount;
  final double postergableAmount;
  final double riskReviewAmount;
  final double totalOpenAmount;
  final double plannedTodayAmount;
  final int itemCount;
  final int priorityScore;
  final List<String> sourcePreviews;
  final List<FinanzasPaymentCenterOperationalItem> items;
  final FinanzasPaymentCenterOperationalItem? primaryActionItem;

  const FinanzasPaymentCenterBudgetProviderSummary({
    required this.providerId,
    required this.providerName,
    required this.accountKey,
    required this.targetCompany,
    required this.targetBranch,
    required this.minimumTodayAmount,
    required this.recommendedAdditionalAmount,
    required this.postergableAmount,
    required this.riskReviewAmount,
    required this.totalOpenAmount,
    required this.plannedTodayAmount,
    required this.itemCount,
    required this.priorityScore,
    required this.sourcePreviews,
    required this.items,
    required this.primaryActionItem,
  });

  double get recommendedTodayAmount =>
      minimumTodayAmount + recommendedAdditionalAmount;

  double get pendingVisibleTodayAmount =>
      (recommendedTodayAmount - plannedTodayAmount)
          .clamp(0, double.infinity)
          .toDouble();

  double get uncoveredMinimumTodayAmount =>
      (minimumTodayAmount - plannedTodayAmount)
          .clamp(0, double.infinity)
          .toDouble();
}

class FinanzasPaymentCenterBudgetAccountSummary {
  final String accountKey;
  final String targetCompany;
  final String targetBranch;
  final double realBalance;
  final double reserveAmount;
  final double availableBalance;
  final double minimumTodayAmount;
  final double recommendedAdditionalAmount;
  final double postergableAmount;
  final double riskReviewAmount;
  final double plannedTodayAmount;
  final List<FinanzasPaymentCenterBudgetProviderSummary> providers;

  const FinanzasPaymentCenterBudgetAccountSummary({
    required this.accountKey,
    required this.targetCompany,
    required this.targetBranch,
    required this.realBalance,
    required this.reserveAmount,
    required this.availableBalance,
    required this.minimumTodayAmount,
    required this.recommendedAdditionalAmount,
    required this.postergableAmount,
    required this.riskReviewAmount,
    required this.plannedTodayAmount,
    required this.providers,
  });

  double get recommendedTodayAmount =>
      minimumTodayAmount + recommendedAdditionalAmount;

  double get pendingVisibleTodayAmount =>
      (recommendedTodayAmount - plannedTodayAmount)
          .clamp(0, double.infinity)
          .toDouble();

  double get marginAfterMinimum => availableBalance - minimumTodayAmount;

  double get marginAfterRecommended =>
      availableBalance - recommendedTodayAmount;

  double get marginAfterPlanned => availableBalance - plannedTodayAmount;

  double get uncoveredMinimumTodayAmount =>
      (minimumTodayAmount - plannedTodayAmount)
          .clamp(0, double.infinity)
          .toDouble();
}

class FinanzasPaymentCenterBudgetTodaySummary {
  final DateTime today;
  final double realTotalBalance;
  final double protectedReserveTotal;
  final double availableBudgetAmount;
  final double minimumTodayAmount;
  final double recommendedAdditionalAmount;
  final double postergableAmount;
  final double riskReviewAmount;
  final double plannedTodayAmount;
  final List<FinanzasPaymentCenterBudgetAccountSummary> accounts;
  final List<FinanzasPaymentCenterOperationalItem> riskItems;

  const FinanzasPaymentCenterBudgetTodaySummary({
    required this.today,
    required this.realTotalBalance,
    required this.protectedReserveTotal,
    required this.availableBudgetAmount,
    required this.minimumTodayAmount,
    required this.recommendedAdditionalAmount,
    required this.postergableAmount,
    required this.riskReviewAmount,
    required this.plannedTodayAmount,
    required this.accounts,
    required this.riskItems,
  });

  double get recommendedTodayAmount =>
      minimumTodayAmount + recommendedAdditionalAmount;

  double get pendingVisibleTodayAmount =>
      (recommendedTodayAmount - plannedTodayAmount)
          .clamp(0, double.infinity)
          .toDouble();

  double get freeMarginAfterMinimum =>
      availableBudgetAmount - minimumTodayAmount;

  double get freeMarginAfterRecommended =>
      availableBudgetAmount - recommendedTodayAmount;

  double get freeMarginAfterPlanned =>
      availableBudgetAmount - plannedTodayAmount;

  double get uncoveredMinimumTodayAmount =>
      (minimumTodayAmount - plannedTodayAmount)
          .clamp(0, double.infinity)
          .toDouble();
}

class FinanzasPaymentCenterBudgetWeekDaySummary {
  final DateTime date;
  final double committedAmount;
  final double suggestedAdditionalAmount;
  final int providerCount;
  final int itemCount;
  final double remainingAfterCommitted;
  final double remainingAfterSuggested;
  final List<String> providerNames;

  const FinanzasPaymentCenterBudgetWeekDaySummary({
    required this.date,
    required this.committedAmount,
    required this.suggestedAdditionalAmount,
    required this.providerCount,
    required this.itemCount,
    required this.remainingAfterCommitted,
    required this.remainingAfterSuggested,
    required this.providerNames,
  });

  double get pressureAmount => committedAmount + suggestedAdditionalAmount;
}

class FinanzasPaymentCenterBudgetWeekProviderSummary {
  final String providerId;
  final String providerName;
  final String accountKey;
  final String targetCompany;
  final String targetBranch;
  final double committedWeekAmount;
  final double suggestedAdditionalAmount;
  final double outsideWindowAmount;
  final double riskReviewAmount;
  final double totalOpenAmount;
  final double plannedWeekAmount;
  final int itemCount;
  final int priorityScore;
  final DateTime? nextDueDate;
  final List<String> sourcePreviews;
  final List<FinanzasPaymentCenterOperationalItem> items;
  final FinanzasPaymentCenterOperationalItem? primaryActionItem;

  const FinanzasPaymentCenterBudgetWeekProviderSummary({
    required this.providerId,
    required this.providerName,
    required this.accountKey,
    required this.targetCompany,
    required this.targetBranch,
    required this.committedWeekAmount,
    required this.suggestedAdditionalAmount,
    required this.outsideWindowAmount,
    required this.riskReviewAmount,
    required this.totalOpenAmount,
    required this.plannedWeekAmount,
    required this.itemCount,
    required this.priorityScore,
    required this.nextDueDate,
    required this.sourcePreviews,
    required this.items,
    required this.primaryActionItem,
  });

  double get weekPressureAmount =>
      committedWeekAmount + suggestedAdditionalAmount;
}

class FinanzasPaymentCenterBudgetWeekAccountSummary {
  final String accountKey;
  final String targetCompany;
  final String targetBranch;
  final double realBalance;
  final double reserveAmount;
  final double availableBalance;
  final double committedWeekAmount;
  final double suggestedAdditionalAmount;
  final double outsideWindowAmount;
  final double riskReviewAmount;
  final double plannedWeekAmount;
  final List<FinanzasPaymentCenterBudgetWeekProviderSummary> providers;

  const FinanzasPaymentCenterBudgetWeekAccountSummary({
    required this.accountKey,
    required this.targetCompany,
    required this.targetBranch,
    required this.realBalance,
    required this.reserveAmount,
    required this.availableBalance,
    required this.committedWeekAmount,
    required this.suggestedAdditionalAmount,
    required this.outsideWindowAmount,
    required this.riskReviewAmount,
    required this.plannedWeekAmount,
    required this.providers,
  });

  double get weekPressureAmount =>
      committedWeekAmount + suggestedAdditionalAmount;

  double get marginAfterCommitted => availableBalance - committedWeekAmount;

  double get marginAfterWeekPressure => availableBalance - weekPressureAmount;
}

class FinanzasPaymentCenterBudgetWeekSummary {
  final DateTime startDate;
  final DateTime endDate;
  final double realTotalBalance;
  final double protectedReserveTotal;
  final double availableBudgetAmount;
  final double committedWeekAmount;
  final double suggestedAdditionalAmount;
  final double outsideWindowAmount;
  final double riskReviewAmount;
  final double plannedWeekAmount;
  final List<FinanzasPaymentCenterBudgetWeekDaySummary> days;
  final List<FinanzasPaymentCenterBudgetWeekAccountSummary> accounts;
  final List<FinanzasPaymentCenterOperationalItem> riskItems;

  const FinanzasPaymentCenterBudgetWeekSummary({
    required this.startDate,
    required this.endDate,
    required this.realTotalBalance,
    required this.protectedReserveTotal,
    required this.availableBudgetAmount,
    required this.committedWeekAmount,
    required this.suggestedAdditionalAmount,
    required this.outsideWindowAmount,
    required this.riskReviewAmount,
    required this.plannedWeekAmount,
    required this.days,
    required this.accounts,
    required this.riskItems,
  });

  double get weekPressureAmount =>
      committedWeekAmount + suggestedAdditionalAmount;

  double get freeMarginAfterCommitted =>
      availableBudgetAmount - committedWeekAmount;

  double get freeMarginAfterWeekPressure =>
      availableBudgetAmount - weekPressureAmount;
}

class FinanzasPaymentCenterOperationalSnapshot {
  final Map<String, double> realAccountBalances;
  final Map<String, double> accountBalances;
  final List<FinanzasPaymentCenterOperationalItem> items;
  final List<FinanzasPaymentLearningRecord> learningLogs;
  final List<FinanzasPaymentCenterReserveRecord> reserves;
  final FinanzasPaymentCenterReserveImpactSummary reserveSummary;
  final FinanzasPaymentCenterBudgetTodaySummary budgetToday;
  final FinanzasPaymentCenterBudgetWeekSummary budgetWeek;

  const FinanzasPaymentCenterOperationalSnapshot({
    required this.realAccountBalances,
    required this.accountBalances,
    required this.items,
    required this.learningLogs,
    required this.reserves,
    required this.reserveSummary,
    required this.budgetToday,
    required this.budgetWeek,
  });
}
