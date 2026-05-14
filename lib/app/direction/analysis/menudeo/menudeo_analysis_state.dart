import 'dart:async';

import 'package:flutter/material.dart';

import 'menudeo_analysis_models.dart';
import 'menudeo_analysis_repository.dart';

class MenudeoAnalysisState extends ChangeNotifier {
  MenudeoAnalysisState({MenudeoAnalysisRepository? repository})
    : _repository = repository ?? MenudeoAnalysisRepository();

  final MenudeoAnalysisRepository _repository;

  bool _loading = true;
  String? _error;
  MenudeoAnalysisFilters _filters = const MenudeoAnalysisFilters();
  MenudeoMarketDataset? _dataset;
  MenudeoCashDataset? _cashDataset;
  MenudeoOperationDataset? _operationDataset;
  String? _selectedOpportunityId;

  bool get loading => _loading;
  String? get error => _error;
  MenudeoAnalysisFilters get filters => _filters;
  MenudeoMarketDataset? get dataset => _dataset;
  MenudeoCashDataset? get cashDataset => _cashDataset;
  MenudeoOperationDataset? get operationDataset => _operationDataset;
  String? get selectedOpportunityId => _selectedOpportunityId;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait<dynamic>([
        _repository.loadMarketDataset(
          windowDays: _filters.windowDays,
          dateRange: _filters.dateRange,
        ),
        _repository.loadCashDataset(
          windowDays: _filters.windowDays,
          dateRange: _filters.dateRange,
        ),
        _repository.loadOperationDataset(
          windowDays: _filters.windowDays,
          dateRange: _filters.dateRange,
        ),
      ]);
      _dataset = results[0] as MenudeoMarketDataset;
      _cashDataset = results[1] as MenudeoCashDataset;
      _operationDataset = results[2] as MenudeoOperationDataset;
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setWindowDays(int value) {
    _filters = _filters.copyWith(windowDays: value, dateRange: null);
    unawaited(load());
  }

  void setDateRange(DateTimeRange? value) {
    _filters = _filters.copyWith(dateRange: value);
    unawaited(load());
  }

  void setFlow(MenudeoAnalysisFlow value) {
    _filters = _filters.copyWith(flow: value);
    notifyListeners();
  }

  void setMaterial(String? value) {
    _filters = _filters.copyWith(material: value);
    notifyListeners();
  }

  void setCounterparty(String? value) {
    _filters = _filters.copyWith(counterparty: value);
    notifyListeners();
  }

  void setGroupCode(String? value) {
    _filters = _filters.copyWith(groupCode: value);
    notifyListeners();
  }

  void setSeverity(MenudeoOpportunitySeverity value) {
    _filters = _filters.copyWith(severity: value);
    notifyListeners();
  }

  void setActionableOnly(bool value) {
    _filters = _filters.copyWith(actionableOnly: value);
    notifyListeners();
  }

  void setHighImpactOnly(bool value) {
    _filters = _filters.copyWith(highImpactOnly: value);
    notifyListeners();
  }

  void setRecentChangesOnly(bool value) {
    _filters = _filters.copyWith(recentChangesOnly: value);
    notifyListeners();
  }

  void selectOpportunity(String? id) {
    _selectedOpportunityId = id;
    notifyListeners();
  }

  MenudeoMarketViewData? get marketView {
    final dataset = _dataset;
    if (dataset == null) return null;

    var opportunities = dataset.opportunities
        .where((row) {
          if (_filters.flow != MenudeoAnalysisFlow.all &&
              row.flow != _filters.flow) {
            return false;
          }
          if (_filters.material != null && row.material != _filters.material) {
            return false;
          }
          if (_filters.counterparty != null &&
              row.counterparty != _filters.counterparty) {
            return false;
          }
          if (_filters.groupCode != null &&
              row.groupCode != _filters.groupCode) {
            return false;
          }
          if (_filters.severity != MenudeoOpportunitySeverity.all &&
              row.severity != _filters.severity) {
            return false;
          }
          if (_filters.actionableOnly && !row.isActionable) {
            return false;
          }
          if (_filters.highImpactOnly && row.impactEstimate < 5000) {
            return false;
          }
          if (_filters.recentChangesOnly) {
            final lastChanged = row.lastChangedAt;
            if (lastChanged == null ||
                lastChanged.isBefore(
                  DateTime.now().subtract(const Duration(days: 14)),
                )) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);

    final spreadMaterialFilter = _filters.material;
    final spreads = dataset.spreads
        .where((row) {
          if (spreadMaterialFilter != null &&
              row.material != spreadMaterialFilter) {
            return false;
          }
          if (_filters.flow == MenudeoAnalysisFlow.purchase) {
            return row.purchasePrice != null;
          }
          if (_filters.flow == MenudeoAnalysisFlow.sale) {
            return row.salePrice != null;
          }
          return true;
        })
        .toList(growable: false);

    final alerts = dataset.alerts
        .where((row) {
          if (_filters.material != null && row.material != _filters.material) {
            return false;
          }
          if (_filters.counterparty != null &&
              row.counterparty.isNotEmpty &&
              row.counterparty != _filters.counterparty) {
            return false;
          }
          if (_filters.severity != MenudeoOpportunitySeverity.all &&
              row.severity != _filters.severity) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    MenudeoPriceOpportunity? selectedOpportunity;
    if (_selectedOpportunityId != null) {
      for (final row in opportunities) {
        if (row.id == _selectedOpportunityId) {
          selectedOpportunity = row;
          break;
        }
      }
    }

    final history = dataset.history
        .where((row) {
          if (_filters.flow != MenudeoAnalysisFlow.all &&
              row.flow != _filters.flow) {
            return false;
          }
          if (_filters.material != null && row.material != _filters.material) {
            return false;
          }
          if (_filters.counterparty != null &&
              row.counterparty != _filters.counterparty) {
            return false;
          }
          if (_filters.groupCode != null &&
              row.groupCode != _filters.groupCode) {
            return false;
          }
          if (_filters.recentChangesOnly &&
              (row.createdAt == null ||
                  row.createdAt!.isBefore(
                    DateTime.now().subtract(const Duration(days: 14)),
                  ))) {
            return false;
          }
          if (selectedOpportunity != null &&
              (row.material != selectedOpportunity.material ||
                  row.counterparty != selectedOpportunity.counterparty ||
                  row.flow != selectedOpportunity.flow)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    final snapshot = MenudeoMarketSnapshot(
      activePrices: opportunities.length,
      actionablePrices: opportunities.where((row) => row.isActionable).length,
      potentialImpact: opportunities.fold<double>(
        0,
        (sum, row) => sum + row.impactEstimate,
      ),
      pressuredMaterials: spreads.where((row) => row.isPressured).length,
    );

    return MenudeoMarketViewData(
      snapshot: snapshot,
      opportunities: opportunities,
      spreads: spreads,
      alerts: alerts,
      history: history,
      selectedOpportunity: selectedOpportunity,
    );
  }
}
