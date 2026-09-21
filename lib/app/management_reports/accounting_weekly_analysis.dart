import 'package:flutter/material.dart';

import '../commercial/commercial_store.dart';
import '../contabilidad/contabilidad_income_statement_store.dart';

/// Calendar-day cuts, like the accounting screens. Before Friday both weeks
/// cover the same weekdays; weekends retain the Friday just completed.
class AccountingWeeklyCut {
  AccountingWeeklyCut(DateTime generatedAt) {
    final day = DateTime(generatedAt.year, generatedAt.month, generatedAt.day);
    final monday = DateTime(day.year, day.month, day.day - day.weekday + 1);
    friday = DateTime(monday.year, monday.month, monday.day + 4);
    final end = day.isBefore(friday) ? day : friday;
    current = DateTimeRange(start: monday, end: end);
    previous = DateTimeRange(
      start: DateTime(monday.year, monday.month, monday.day - 7),
      end: DateTime(end.year, end.month, end.day - 7),
    );
  }
  late final DateTime friday;
  late final DateTimeRange current, previous;
  bool get partial => current.end.isBefore(friday);
  bool contains(DateTime? date, {bool prior = false}) {
    if (date == null) return false;
    final range = prior ? previous : current;
    final endExclusive = DateTime(
      range.end.year,
      range.end.month,
      range.end.day + 1,
    );
    return !date.isBefore(range.start) && date.isBefore(endExclusive);
  }
}

class AccountingWeeklySource {
  final AccountingWeeklyCut cut;
  final List<CommercialMarketEventRecord> events;
  final ContabilidadIncomeStatementDataset currentStatement, previousStatement;
  const AccountingWeeklySource({
    required this.cut,
    required this.events,
    required this.currentStatement,
    required this.previousStatement,
  });
}

class AccountingTradeTotals {
  final List<CommercialMarketEventRecord> events;
  AccountingTradeTotals(Iterable<CommercialMarketEventRecord> events)
    : events = List.unmodifiable(events);
  double _sum(
    String flow,
    double Function(CommercialMarketEventRecord) value,
  ) => events.where((e) => e.flow == flow).fold(0, (sum, e) => sum + value(e));
  double get purchases => _sum('purchase', (e) => e.amountTotal);
  double get sales => _sum('sale', (e) => e.amountTotal);
  double get purchasedKg => _sum('purchase', (e) => e.volumeKg);
  double get soldKg => _sum('sale', (e) => e.volumeKg);
  double get result => sales - purchases;
  double? get purchasePrice => purchasedKg > 0 ? purchases / purchasedKg : null;
  double? get salePrice => soldKg > 0 ? sales / soldKg : null;
}

class AccountingTradeComparison {
  final String label;
  final AccountingTradeTotals current, previous;
  const AccountingTradeComparison(this.label, this.current, this.previous);
}

class AccountingAmountComparison {
  final String label, source;
  final double current, previous;
  const AccountingAmountComparison(
    this.label,
    this.source,
    this.current,
    this.previous,
  );
  double get change => current - previous;
}

/// A zero baseline has no percentage comparison. With losses the denominator
/// is the absolute previous value so an improvement keeps a positive sign.
double? accountingChangePercent(double current, double previous) =>
    previous.abs() < 0.005 ? null : (current - previous) / previous.abs() * 100;

class AccountingWeeklyAnalysis {
  final AccountingWeeklySource source;
  AccountingWeeklyAnalysis(this.source) {
    if (source.currentStatement.range != source.cut.current ||
        source.previousStatement.range != source.cut.previous) {
      throw ArgumentError(
        'Los estados de resultados no corresponden a los cortes comparados.',
      );
    }
    current = AccountingTradeTotals(
      source.events.where(
        (e) => _knownFlow(e) && source.cut.contains(e.eventAt),
      ),
    );
    previous = AccountingTradeTotals(
      source.events.where(
        (e) => _knownFlow(e) && source.cut.contains(e.eventAt, prior: true),
      ),
    );
  }
  late final AccountingTradeTotals current, previous;
  bool _knownFlow(CommercialMarketEventRecord e) =>
      e.flow == 'purchase' || e.flow == 'sale';
  int get ignoredEvents => source.events
      .where(
        (e) =>
            e.eventAt == null ||
            (!_knownFlow(e) &&
                (source.cut.contains(e.eventAt) ||
                    source.cut.contains(e.eventAt, prior: true))),
      )
      .length;

  List<AccountingTradeComparison> _groups(
    String Function(CommercialMarketEventRecord) key,
    String Function(CommercialMarketEventRecord) label,
  ) {
    final a = <String, List<CommercialMarketEventRecord>>{};
    final b = <String, List<CommercialMarketEventRecord>>{};
    final labels = <String, String>{};
    void collect(
      List<CommercialMarketEventRecord> events,
      Map<String, List<CommercialMarketEventRecord>> target,
    ) {
      for (final e in events) {
        target.putIfAbsent(key(e), () => []).add(e);
        labels[key(e)] = label(e);
      }
    }

    collect(previous.events, b);
    collect(current.events, a);
    return labels.entries
        .map(
          (entry) => AccountingTradeComparison(
            entry.value,
            AccountingTradeTotals(a[entry.key] ?? []),
            AccountingTradeTotals(b[entry.key] ?? []),
          ),
        )
        .toList()
      ..sort((a, b) {
        final amount = (b.current.sales + b.current.purchases).compareTo(
          a.current.sales + a.current.purchases,
        );
        return amount != 0 ? amount : a.label.compareTo(b.label);
      });
  }

  List<AccountingTradeComparison> get materials => _groups(
    (e) =>
        (e.generalMaterialKey.trim().isEmpty
                ? e.generalMaterialLabel
                : e.generalMaterialKey)
            .trim()
            .toUpperCase()
            .replaceAll(RegExp(r'\s+'), ' '),
    (e) => e.generalMaterialLabel.trim().isEmpty
        ? 'Sin material'
        : e.generalMaterialLabel,
  );
  List<AccountingTradeComparison> get channels => _groups(
    (e) => e.channel.trim().isEmpty ? e.sourceArea : e.channel,
    (e) => switch (e.channel) {
      'menudeo' => 'Menudeo',
      'mayoreo' => 'Mayoreo',
      _ => e.sourceArea.isEmpty ? 'Sin canal' : e.sourceArea,
    },
  );

  List<AccountingAmountComparison> get expenses => _amountGroups(
    source.currentStatement.expenseBreakdown,
    source.previousStatement.expenseBreakdown,
  );
  List<AccountingAmountComparison> get otherIncome => _amountGroups(
    source.currentStatement.otherIncomeBreakdown,
    source.previousStatement.otherIncomeBreakdown,
  );
  List<AccountingAmountComparison> _amountGroups(
    List<ContabilidadIncomeStatementBreakdownRow> current,
    List<ContabilidadIncomeStatementBreakdownRow> previous,
  ) {
    final a = <(String, String), double>{};
    final b = <(String, String), double>{};
    for (final row in current) {
      final key = (row.label, row.sourceLabel);
      a[key] = (a[key] ?? 0) + row.amount;
    }
    for (final row in previous) {
      final key = (row.label, row.sourceLabel);
      b[key] = (b[key] ?? 0) + row.amount;
    }
    return {...a.keys, ...b.keys}
        .map(
          (key) => AccountingAmountComparison(
            key.$1,
            key.$2,
            a[key] ?? 0,
            b[key] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) {
        final change = b.change.abs().compareTo(a.change.abs());
        if (change != 0) return change;
        final label = a.label.compareTo(b.label);
        return label != 0 ? label : a.source.compareTo(b.source);
      });
  }
}
