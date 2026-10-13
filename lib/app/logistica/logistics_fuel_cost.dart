import '../shared/utils/number_formatters.dart';

double? parseLogisticsFuelPrice(String input) {
  final text = input.trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  final value = double.tryParse(text);
  if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(text) ||
      value == null ||
      !value.isFinite ||
      value <= 0 ||
      value > 999999.99) {
    throw const FormatException(
      'Captura un precio mayor a 0 con hasta 2 decimales.',
    );
  }
  return value;
}

String logisticsFuelMoney(int cents) => formatMoney(cents / 100);

/// Amounts are rounded to cents per fuel, before adding them together.
class LogisticsFuelCost {
  final int knownCents;
  final int missingPrices;
  const LogisticsFuelCost({this.knownCents = 0, this.missingPrices = 0});

  factory LogisticsFuelCost.calculate({
    required double dieselLiters,
    required double gasolineLiters,
    required double? dieselPrice,
    required double? gasolinePrice,
  }) {
    var cents = 0;
    var missing = 0;
    for (final (liters, price) in [
      (dieselLiters, dieselPrice),
      (gasolineLiters, gasolinePrice),
    ]) {
      if (liters <= 0) continue;
      if (price == null || !price.isFinite || price <= 0) {
        missing++;
      } else {
        cents += (((liters * 100).round() * (price * 100).round() + 50) ~/ 100);
      }
    }
    return LogisticsFuelCost(knownCents: cents, missingPrices: missing);
  }

  bool get isComplete => missingPrices == 0;
  String get label => isComplete
      ? logisticsFuelMoney(knownCents)
      : knownCents == 0
      ? 'Pendiente de precio'
      : '${logisticsFuelMoney(knownCents)} (parcial)';

  LogisticsFuelCost operator +(LogisticsFuelCost other) => LogisticsFuelCost(
    knownCents: knownCents + other.knownCents,
    missingPrices: missingPrices + other.missingPrices,
  );
}
