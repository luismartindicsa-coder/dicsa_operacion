import 'package:flutter/material.dart';

import '../../direction_theme.dart';

enum MenudeoAnalysisFlow { all, purchase, sale }

enum MenudeoOpportunitySeverity { all, healthy, watch, outOfRange, critical }

enum MenudeoOpportunityAction { hold, raisePrice, lowerPrice }

enum MenudeoCashMovementFilter { all, deposits, expenses }

class MenudeoAnalysisFilters {
  final int windowDays;
  final DateTimeRange? dateRange;
  final MenudeoAnalysisFlow flow;
  final String? material;
  final String? counterparty;
  final String? groupCode;
  final MenudeoOpportunitySeverity severity;
  final bool actionableOnly;
  final bool highImpactOnly;
  final bool recentChangesOnly;

  const MenudeoAnalysisFilters({
    this.windowDays = 30,
    this.dateRange,
    this.flow = MenudeoAnalysisFlow.all,
    this.material,
    this.counterparty,
    this.groupCode,
    this.severity = MenudeoOpportunitySeverity.all,
    this.actionableOnly = false,
    this.highImpactOnly = false,
    this.recentChangesOnly = false,
  });

  MenudeoAnalysisFilters copyWith({
    int? windowDays,
    Object? dateRange = _sentinel,
    MenudeoAnalysisFlow? flow,
    Object? material = _sentinel,
    Object? counterparty = _sentinel,
    Object? groupCode = _sentinel,
    MenudeoOpportunitySeverity? severity,
    bool? actionableOnly,
    bool? highImpactOnly,
    bool? recentChangesOnly,
  }) {
    return MenudeoAnalysisFilters(
      windowDays: windowDays ?? this.windowDays,
      dateRange: identical(dateRange, _sentinel)
          ? this.dateRange
          : dateRange as DateTimeRange?,
      flow: flow ?? this.flow,
      material: identical(material, _sentinel)
          ? this.material
          : material as String?,
      counterparty: identical(counterparty, _sentinel)
          ? this.counterparty
          : counterparty as String?,
      groupCode: identical(groupCode, _sentinel)
          ? this.groupCode
          : groupCode as String?,
      severity: severity ?? this.severity,
      actionableOnly: actionableOnly ?? this.actionableOnly,
      highImpactOnly: highImpactOnly ?? this.highImpactOnly,
      recentChangesOnly: recentChangesOnly ?? this.recentChangesOnly,
    );
  }

  static const Object _sentinel = Object();
}

class MenudeoMarketSnapshot {
  final int activePrices;
  final int actionablePrices;
  final double potentialImpact;
  final int pressuredMaterials;

  const MenudeoMarketSnapshot({
    required this.activePrices,
    required this.actionablePrices,
    required this.potentialImpact,
    required this.pressuredMaterials,
  });
}

class MenudeoPriceOpportunity {
  final String id;
  final String counterparty;
  final String groupCode;
  final String material;
  final MenudeoAnalysisFlow flow;
  final double currentPrice;
  final double referencePrice;
  final double suggestedDelta;
  final double impactEstimate;
  final double deviationPercent;
  final double recentWeight;
  final double recentAmount;
  final int recentTickets;
  final MenudeoOpportunitySeverity severity;
  final MenudeoOpportunityAction action;
  final DateTime? lastChangedAt;

  const MenudeoPriceOpportunity({
    required this.id,
    required this.counterparty,
    required this.groupCode,
    required this.material,
    required this.flow,
    required this.currentPrice,
    required this.referencePrice,
    required this.suggestedDelta,
    required this.impactEstimate,
    required this.deviationPercent,
    required this.recentWeight,
    required this.recentAmount,
    required this.recentTickets,
    required this.severity,
    required this.action,
    required this.lastChangedAt,
  });

  bool get isActionable => action != MenudeoOpportunityAction.hold;
}

class MenudeoSpreadRow {
  final String material;
  final double? purchasePrice;
  final double? salePrice;
  final double spread;
  final double purchaseWeight;
  final double saleWeight;

  const MenudeoSpreadRow({
    required this.material,
    required this.purchasePrice,
    required this.salePrice,
    required this.spread,
    required this.purchaseWeight,
    required this.saleWeight,
  });

  bool get isPressured =>
      purchasePrice != null && salePrice != null && spread <= 0;
}

class MenudeoMarketAlert {
  final String id;
  final MenudeoOpportunitySeverity severity;
  final String title;
  final String detail;
  final String material;
  final String counterparty;

  const MenudeoMarketAlert({
    required this.id,
    required this.severity,
    required this.title,
    required this.detail,
    required this.material,
    required this.counterparty,
  });
}

class MenudeoMarketHistoryEvent {
  final String id;
  final String priceId;
  final DateTime? createdAt;
  final String counterparty;
  final String groupCode;
  final String material;
  final MenudeoAnalysisFlow flow;
  final double previousPrice;
  final double newPrice;
  final String reason;
  final String eventKind;
  final String adjustmentMode;
  final String appliedBy;

  const MenudeoMarketHistoryEvent({
    required this.id,
    required this.priceId,
    required this.createdAt,
    required this.counterparty,
    required this.groupCode,
    required this.material,
    required this.flow,
    required this.previousPrice,
    required this.newPrice,
    required this.reason,
    required this.eventKind,
    required this.adjustmentMode,
    required this.appliedBy,
  });

  double get delta => newPrice - previousPrice;
}

class MenudeoMarketDataset {
  final List<MenudeoPriceOpportunity> opportunities;
  final List<MenudeoSpreadRow> spreads;
  final List<MenudeoMarketAlert> alerts;
  final List<MenudeoMarketHistoryEvent> history;
  final List<String> materials;
  final List<String> counterparties;
  final List<String> groupCodes;

  const MenudeoMarketDataset({
    required this.opportunities,
    required this.spreads,
    required this.alerts,
    required this.history,
    required this.materials,
    required this.counterparties,
    required this.groupCodes,
  });
}

class MenudeoMarketViewData {
  final MenudeoMarketSnapshot snapshot;
  final List<MenudeoPriceOpportunity> opportunities;
  final List<MenudeoSpreadRow> spreads;
  final List<MenudeoMarketAlert> alerts;
  final List<MenudeoMarketHistoryEvent> history;
  final MenudeoPriceOpportunity? selectedOpportunity;

  const MenudeoMarketViewData({
    required this.snapshot,
    required this.opportunities,
    required this.spreads,
    required this.alerts,
    required this.history,
    required this.selectedOpportunity,
  });
}

class MenudeoCashSnapshot {
  final double deposits;
  final double expenses;
  final double netFlow;
  final int cutsWithDifference;
  final int pendingChecks;

  const MenudeoCashSnapshot({
    required this.deposits,
    required this.expenses,
    required this.netFlow,
    required this.cutsWithDifference,
    required this.pendingChecks,
  });
}

class MenudeoCashBreakdownRow {
  final String label;
  final double total;
  final int count;
  final double share;

  const MenudeoCashBreakdownRow({
    required this.label,
    required this.total,
    required this.count,
    required this.share,
  });
}

class MenudeoCashAlert {
  final String id;
  final MenudeoOpportunitySeverity severity;
  final String title;
  final String detail;

  const MenudeoCashAlert({
    required this.id,
    required this.severity,
    required this.title,
    required this.detail,
  });
}

class MenudeoCashFocusedBreakdown {
  final String title;
  final double total;
  final List<MenudeoCashBreakdownRow> rows;

  const MenudeoCashFocusedBreakdown({
    required this.title,
    required this.total,
    required this.rows,
  });
}

class MenudeoCashLogisticsRow {
  final String label;
  final double total;
  final double fuelTotal;
  final double maintenanceTotal;
  final double travelTotal;
  final int count;
  final double share;

  const MenudeoCashLogisticsRow({
    required this.label,
    required this.total,
    required this.fuelTotal,
    required this.maintenanceTotal,
    required this.travelTotal,
    required this.count,
    required this.share,
  });
}

class MenudeoCashTimelinePoint {
  final DateTime date;
  final double deposits;
  final double expenses;
  final double net;

  const MenudeoCashTimelinePoint({
    required this.date,
    required this.deposits,
    required this.expenses,
    required this.net,
  });
}

class MenudeoCashDataset {
  final MenudeoCashSnapshot snapshot;
  final List<MenudeoCashTimelinePoint> timeline;
  final List<MenudeoCashBreakdownRow> rubricRows;
  final List<MenudeoCashBreakdownRow> conceptRows;
  final List<MenudeoCashBreakdownRow> subconceptRows;
  final List<MenudeoCashBreakdownRow> personRows;
  final MenudeoCashFocusedBreakdown fuelBreakdown;
  final MenudeoCashFocusedBreakdown maintenanceBreakdown;
  final MenudeoCashFocusedBreakdown travelBreakdown;
  final MenudeoCashFocusedBreakdown logisticsUnitBreakdown;
  final MenudeoCashFocusedBreakdown logisticsDriverBreakdown;
  final List<MenudeoCashLogisticsRow> logisticsUnitRows;
  final List<MenudeoCashLogisticsRow> logisticsDriverRows;
  final List<MenudeoCashAlert> alerts;
  final List<String> rubrics;
  final List<String> people;

  const MenudeoCashDataset({
    required this.snapshot,
    required this.timeline,
    required this.rubricRows,
    required this.conceptRows,
    required this.subconceptRows,
    required this.personRows,
    required this.fuelBreakdown,
    required this.maintenanceBreakdown,
    required this.travelBreakdown,
    required this.logisticsUnitBreakdown,
    required this.logisticsDriverBreakdown,
    required this.logisticsUnitRows,
    required this.logisticsDriverRows,
    required this.alerts,
    required this.rubrics,
    required this.people,
  });
}

class MenudeoOperationSnapshot {
  final double purchaseAmount;
  final double saleAmount;
  final double netCommercialFlow;
  final int paidTickets;
  final int pendingTickets;
  final int pendingChecks;

  const MenudeoOperationSnapshot({
    required this.purchaseAmount,
    required this.saleAmount,
    required this.netCommercialFlow,
    required this.paidTickets,
    required this.pendingTickets,
    required this.pendingChecks,
  });
}

class MenudeoOperationBreakdownRow {
  final String label;
  final double amount;
  final double weight;
  final int count;
  final double share;

  const MenudeoOperationBreakdownRow({
    required this.label,
    required this.amount,
    required this.weight,
    required this.count,
    required this.share,
  });
}

class MenudeoOperationTimelinePoint {
  final DateTime date;
  final double purchaseAmount;
  final double saleAmount;
  final double netAmount;
  final int paidTickets;

  const MenudeoOperationTimelinePoint({
    required this.date,
    required this.purchaseAmount,
    required this.saleAmount,
    required this.netAmount,
    required this.paidTickets,
  });
}

class MenudeoPendingTicketRow {
  final String id;
  final DateTime? ticketDate;
  final String ticketNumber;
  final String counterparty;
  final String material;
  final MenudeoAnalysisFlow flow;
  final String status;
  final double amount;
  final double weight;

  const MenudeoPendingTicketRow({
    required this.id,
    required this.ticketDate,
    required this.ticketNumber,
    required this.counterparty,
    required this.material,
    required this.flow,
    required this.status,
    required this.amount,
    required this.weight,
  });
}

class MenudeoOperationAlert {
  final String id;
  final MenudeoOpportunitySeverity severity;
  final String title;
  final String detail;

  const MenudeoOperationAlert({
    required this.id,
    required this.severity,
    required this.title,
    required this.detail,
  });
}

class MenudeoOperationDataset {
  final MenudeoOperationSnapshot snapshot;
  final List<MenudeoOperationTimelinePoint> timeline;
  final List<MenudeoOperationBreakdownRow> materialRows;
  final List<MenudeoOperationBreakdownRow> counterpartyRows;
  final List<MenudeoPendingTicketRow> pendingRows;
  final List<MenudeoOperationAlert> alerts;
  final List<String> materials;
  final List<String> counterparties;

  const MenudeoOperationDataset({
    required this.snapshot,
    required this.timeline,
    required this.materialRows,
    required this.counterpartyRows,
    required this.pendingRows,
    required this.alerts,
    required this.materials,
    required this.counterparties,
  });
}

String menudeoFlowLabel(MenudeoAnalysisFlow flow) {
  switch (flow) {
    case MenudeoAnalysisFlow.all:
      return 'Ambos';
    case MenudeoAnalysisFlow.purchase:
      return 'Compra';
    case MenudeoAnalysisFlow.sale:
      return 'Venta';
  }
}

String menudeoSeverityLabel(MenudeoOpportunitySeverity severity) {
  switch (severity) {
    case MenudeoOpportunitySeverity.all:
      return 'Todos';
    case MenudeoOpportunitySeverity.healthy:
      return 'Sano';
    case MenudeoOpportunitySeverity.watch:
      return 'Vigilar';
    case MenudeoOpportunitySeverity.outOfRange:
      return 'Fuera de rango';
    case MenudeoOpportunitySeverity.critical:
      return 'Crítico';
  }
}

String menudeoActionLabel(MenudeoOpportunityAction action) {
  switch (action) {
    case MenudeoOpportunityAction.hold:
      return 'Mantener';
    case MenudeoOpportunityAction.raisePrice:
      return 'Subir';
    case MenudeoOpportunityAction.lowerPrice:
      return 'Bajar';
  }
}

String menudeoCashMovementLabel(MenudeoCashMovementFilter filter) {
  switch (filter) {
    case MenudeoCashMovementFilter.all:
      return 'Ambos';
    case MenudeoCashMovementFilter.deposits:
      return 'Depósitos';
    case MenudeoCashMovementFilter.expenses:
      return 'Gastos';
  }
}

Color menudeoSeverityColor(MenudeoOpportunitySeverity severity) {
  switch (severity) {
    case MenudeoOpportunitySeverity.healthy:
      return kDirectionSuccess;
    case MenudeoOpportunitySeverity.watch:
      return kDirectionOliveMist;
    case MenudeoOpportunitySeverity.outOfRange:
      return kDirectionWarning;
    case MenudeoOpportunitySeverity.critical:
      return kDirectionDanger;
    case MenudeoOpportunitySeverity.all:
      return kDirectionMutedText;
  }
}
