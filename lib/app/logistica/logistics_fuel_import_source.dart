/// Import evidence is kept separately from editable operational fields.
class LogisticsFuelImportSource {
  final double? totalAmount;
  final double? estimatedLiters;
  final double? referencePrice;
  final String referenceUrl;

  const LogisticsFuelImportSource({
    this.totalAmount,
    this.estimatedLiters,
    this.referencePrice,
    this.referenceUrl = '',
  });

  factory LogisticsFuelImportSource.fromJson(dynamic value) {
    if (value is! Map) return const LogisticsFuelImportSource();
    double? number(String key) => double.tryParse('${value[key]}');
    return LogisticsFuelImportSource(
      totalAmount: number('total_amount'),
      estimatedLiters: number('estimated_liters'),
      referencePrice: number('reference_price'),
      referenceUrl: '${value['reference_url'] ?? ''}',
    );
  }

  // A later correction to the quantity must not inherit the import estimate.
  bool isEstimatedAt(double liters) =>
      estimatedLiters != null && (estimatedLiters! - liters).abs() < 0.00001;

  String note(double liters) {
    final amount = totalAmount;
    final price = referencePrice;
    if (isEstimatedAt(liters) && amount != null && price != null) {
      return 'Litros estimados: \$${amount.toStringAsFixed(2)} ÷ '
          '\$${price.toStringAsFixed(2)}/L. Precio de referencia de Celaya; '
          'no es el precio comprobado del ticket.';
    }
    return amount == null
        ? ''
        : 'Importe original del Excel: \$${amount.toStringAsFixed(2)}';
  }
}
