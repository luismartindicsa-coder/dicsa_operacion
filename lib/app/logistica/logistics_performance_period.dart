import 'package:flutter/material.dart';

/// Every source shares a closed-day cutoff, including fuel and services.
DateTimeRange logisticsClosedPeriod(String period, DateTime now) {
  final end = DateUtils.dateOnly(now).subtract(const Duration(days: 1));
  return DateTimeRange(
    start: end.subtract(Duration(days: period == 'month' ? 29 : 6)),
    end: end,
  );
}
