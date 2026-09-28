import 'dart:math' as math;

import '../expected_income/expected_income_models.dart';
import '../operating_program/operating_program_models.dart';
import 'weekly_projection_models.dart';

DateTime menudeoHistoryEnd(DateTime week, DateTime now) {
  final day = incomeDay(now);
  final monday = day.subtract(Duration(days: day.weekday - 1));
  return week.isBefore(monday) ? week : monday;
}

class MenudeoExpenseMovement {
  final String id;
  final DateTime date;
  final int amount;
  final bool purchase;
  const MenudeoExpenseMovement(
    this.id,
    this.date,
    this.amount, {
    required this.purchase,
  });
}

class MenudeoExpenseHistory {
  final List<MenudeoExpenseMovement> movements;
  final int excludedInternal;
  const MenudeoExpenseHistory({
    this.movements = const [],
    this.excludedInternal = 0,
  });

  factory MenudeoExpenseHistory.fromRows({
    required List<Map<String, dynamic>> tickets,
    required List<Map<String, dynamic>> vouchers,
    required List<Map<String, dynamic>> lines,
  }) {
    int cents(Object? value) {
      final number = num.tryParse('$value');
      if (number == null || !number.isFinite || number < 0) {
        throw const FormatException('Importe de Menudeo inválido.');
      }
      return (number * 100).round();
    }

    DateTime date(Object? value) {
      final parsed = DateTime.tryParse('$value');
      if (parsed == null) {
        throw const FormatException('Fecha de Menudeo inválida.');
      }
      return incomeDay(parsed);
    }

    bool internal(String value) {
      final key = incomeKey(value);
      return key == 'REPOSICION DE FONDO' ||
          key == 'MOVIMIENTOS INTERNOS' ||
          key == 'BOVEDA' ||
          key == 'CAJA GRANDE' ||
          key.contains('TRANSFERENCIA') ||
          key.contains('INTERNO');
    }

    final byVoucher = <String, List<Map<String, dynamic>>>{};
    final seenLines = <String>{};
    for (final line in lines) {
      if (!seenLines.add('${line['id']}')) continue;
      byVoucher.putIfAbsent('${line['voucher_id']}', () => []).add(line);
    }
    var excluded = 0;
    final result = <MenudeoExpenseMovement>[];
    final seen = <String>{};
    for (final row in tickets) {
      if (row['direction'] != 'purchase' || row['status'] != 'PAGADO') continue;
      final id = 'ticket:${row['id']}';
      if (!seen.add(id)) continue;
      final amount = cents(row['amount_total']);
      if (amount > 0) {
        result.add(
          MenudeoExpenseMovement(
            id,
            date(row['ticket_date']),
            amount,
            purchase: true,
          ),
        );
      }
    }
    for (final row in vouchers) {
      if (row['voucher_type'] != 'expense') continue;
      final id = 'voucher:${row['id']}';
      if (!seen.add(id)) continue;
      if (internal('${row['rubric'] ?? ''}')) {
        excluded++;
        continue;
      }
      final detail = byVoucher['${row['id']}'] ?? [];
      if ((row['line_count'] as num? ?? 0).toInt() != detail.length) {
        throw const FormatException(
          'El detalle de gastos de Menudeo cambió; vuelve a consultar.',
        );
      }
      var amount = 0;
      if (detail.isEmpty) {
        // The view's amount is used only when the voucher has no detail.
        if ((row['line_count'] as num? ?? 0) > 0) {
          throw const FormatException(
            'Falta el detalle de un gasto de Menudeo.',
          );
        }
        amount = cents(row['total_amount']);
      } else {
        for (final line in detail) {
          final concept = '${line['concept_label_snapshot'] ?? ''}'.trim();
          if (internal(
            concept.isEmpty ? '${line['concept'] ?? ''}' : concept,
          )) {
            excluded++;
          } else {
            amount += cents(line['amount']);
          }
        }
      }
      if (amount > 0) {
        result.add(
          MenudeoExpenseMovement(
            id,
            date(row['voucher_date']),
            amount,
            purchase: false,
          ),
        );
      }
    }
    return MenudeoExpenseHistory(movements: result, excludedInternal: excluded);
  }
}

class MenudeoExpenseEstimate {
  final DateTime week, asOf, historyStart, historyEnd;
  final int weeks, records, purchaseRecords, expenseRecords, excludedInternal;
  final List<int> averagePurchases,
      averageExpenses,
      actualPurchases,
      actualExpenses;
  final MenudeoExpenseSettings settings;
  const MenudeoExpenseEstimate._({
    required this.week,
    required this.asOf,
    required this.historyStart,
    required this.historyEnd,
    required this.weeks,
    required this.records,
    required this.purchaseRecords,
    required this.expenseRecords,
    required this.excludedInternal,
    required this.averagePurchases,
    required this.averageExpenses,
    required this.actualPurchases,
    required this.actualExpenses,
    required this.settings,
  });

  factory MenudeoExpenseEstimate({
    required DateTime week,
    required DateTime now,
    required MenudeoExpenseHistory history,
    MenudeoExpenseSettings settings = const MenudeoExpenseSettings(),
  }) {
    final end = menudeoHistoryEnd(week, now);
    var start = end.subtract(const Duration(days: 42));
    final past = history.movements
        .where((r) => !r.date.isBefore(start) && r.date.isBefore(end))
        .toList();
    if (past.isNotEmpty) {
      final first = past
          .map((r) => r.date)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      start = first.subtract(Duration(days: first.weekday - 1));
    }
    final weeks = past.isEmpty ? 0 : end.difference(start).inDays ~/ 7;
    List<int> totals(Iterable<MenudeoExpenseMovement> rows, bool purchase) {
      final days = List.filled(7, 0);
      for (final row in rows.where((r) => r.purchase == purchase)) {
        days[row.date.weekday - 1] += row.amount;
      }
      return days;
    }

    final actual = history.movements.where(
      (r) =>
          !r.date.isBefore(week) &&
          r.date.isBefore(week.add(const Duration(days: 7))) &&
          !r.date.isAfter(incomeDay(now)),
    );
    return MenudeoExpenseEstimate._(
      week: week,
      asOf: incomeDay(now),
      historyStart: start,
      historyEnd: end,
      weeks: weeks,
      records: past.length,
      purchaseRecords: past.where((r) => r.purchase).length,
      expenseRecords: past.where((r) => !r.purchase).length,
      excludedInternal: history.excludedInternal,
      averagePurchases: totals(
        past,
        true,
      ).map((v) => weeks == 0 ? 0 : (v / weeks).round()).toList(),
      averageExpenses: totals(
        past,
        false,
      ).map((v) => weeks == 0 ? 0 : (v / weeks).round()).toList(),
      actualPurchases: totals(actual, true),
      actualExpenses: totals(actual, false),
      settings: settings,
    );
  }
  int sum(List<int> values) => values.fold(0, (a, b) => a + b);
  List<int> budget(bool purchase) {
    final pattern = purchase ? averagePurchases : averageExpenses;
    final override = purchase ? settings.purchases : settings.expenses;
    if (override == null) return pattern;
    final weight = sum(pattern);
    // Round cumulative shares, retaining every cent of an explicit weekly total.
    var cumulative = 0, allocated = 0;
    return List.generate(7, (d) {
      cumulative += weight == 0 ? 1 : pattern[d];
      final target = (override * cumulative / (weight == 0 ? 7 : weight))
          .round();
      final amount = target - allocated;
      allocated = target;
      return amount;
    });
  }

  List<int> remaining(bool purchase) {
    final target = budget(purchase);
    final actual = purchase ? actualPurchases : actualExpenses;
    return List.generate(7, (d) {
      final date = week.add(Duration(days: d));
      if (date.isBefore(asOf)) return 0;
      return math.max(0, target[d] - actual[d]);
    });
  }

  int get pending => sum(remaining(true)) + sum(remaining(false));
  int get actual => sum(actualPurchases) + sum(actualExpenses);
  List<ProjectedPayment> get payments => [
    for (final purchase in [true, false])
      for (var d = 0; d < 7; d++)
        if (remaining(purchase)[d] > 0)
          ProjectedPayment(
            id: 'menudeo:${purchase ? 'purchase' : 'expense'}:$d',
            source: 'menudeo_estimate',
            payee: purchase
                ? 'Menudeo · compras estimadas'
                : 'Menudeo · gastos estimados',
            reference:
                'Estimación de efectivo · ${weeks == 0 ? 'captura manual' : '$weeks semanas de historial'}',
            account: 'Menudeo',
            date: week.add(Duration(days: d)),
            amount: remaining(purchase)[d],
            available: remaining(purchase)[d],
            paymentType: 'EFECTIVO',
            paymentTypeAutomatic: true,
            included: settings.included,
          ),
  ];
  List<String> get warnings => [
    if (!settings.included)
      'Estimación de Menudeo excluida del flujo por configuración de esta semana.',
    if (weeks == 0)
      settings.purchases != null && settings.expenses != null
          ? 'Menudeo sin historial previo: estimación manual distribuida entre lunes y domingo.'
          : 'Sin historial previo de Menudeo; captura una estimación para contemplarlo en el flujo.',
    if (weeks > 0 && weeks < 6)
      'Referencia limitada: $weeks de 6 semanas con cobertura desde el primer registro.',
    if (weeks > 0 && purchaseRecords == 0)
      'Sin compras pagadas en el historial consultado.',
    if (weeks > 0 && expenseRecords == 0)
      'Sin gastos externos en el historial consultado.',
  ];
  String get period => weeks == 0
      ? 'Sin referencia histórica'
      : '${programDate(historyStart)} al ${programDate(historyEnd.subtract(const Duration(days: 1)))} · $weeks semanas · $records registros';
}
