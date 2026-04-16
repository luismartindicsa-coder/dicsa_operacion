String formatDecimal(
  num value, {
  int decimals = 2,
  String thousandsSeparator = ',',
  String decimalSeparator = '.',
}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final integer = parts.first;
  final fraction = parts.length > 1 ? parts[1] : '';

  final groupedInteger = integer.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => thousandsSeparator,
  );

  final buffer = StringBuffer();
  if (negative) buffer.write('-');
  buffer.write(groupedInteger);
  if (decimals > 0) {
    buffer.write(decimalSeparator);
    buffer.write(fraction);
  }
  return buffer.toString();
}

String formatMoney(num value, {String symbol = '\$', int decimals = 2}) {
  return '$symbol${formatDecimal(value, decimals: decimals)}';
}
