import 'package:flutter/material.dart';

DateTime clampDatePickerDate(
  DateTime value, {
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final normalized = DateUtils.dateOnly(value);
  final normalizedFirst = DateUtils.dateOnly(firstDate);
  final normalizedLast = DateUtils.dateOnly(lastDate);
  if (normalized.isBefore(normalizedFirst)) return normalizedFirst;
  if (normalized.isAfter(normalizedLast)) return normalizedLast;
  return normalized;
}

DateTime defaultDatePickerOpenDate({
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return clampDatePickerDate(
    DateTime.now(),
    firstDate: firstDate,
    lastDate: lastDate,
  );
}

DateTime defaultDatePickerOpenMonth({
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final date = defaultDatePickerOpenDate(
    firstDate: firstDate,
    lastDate: lastDate,
  );
  return DateTime(date.year, date.month);
}
