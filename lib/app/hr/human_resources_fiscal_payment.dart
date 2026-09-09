/// Fiscal delivery only: allocating a cheque never adds another perception.
class HrFiscalPayment {
  final double total;
  final double cheque;
  double get deposit => total - cheque;

  HrFiscalPayment({required double total, required double cheque})
    : total = total.clamp(0, double.infinity).toDouble(),
      cheque = cheque.clamp(0, total.clamp(0, double.infinity)).toDouble();

  /// Older automatic drafts used both null and zero for an unset cheque.
  /// Only a positive legacy allocation or the explicit flag is an override.
  static bool isManual(Map<String, dynamic> snapshot, double? storedCheque) =>
      snapshot['fiscal_payment_is_manual'] == true ||
      (!snapshot.containsKey('fiscal_payment_is_manual') &&
          (storedCheque ?? 0) > 0);

  factory HrFiscalPayment.resolve({
    required double total,
    required double? storedCheque,
    required Map<String, dynamic> snapshot,
    String? personalMode,
    bool frozen = false,
  }) {
    final mode = personalMode ?? snapshot['personal_fiscal_payment_mode'];
    final cheque = frozen || isManual(snapshot, storedCheque)
        ? (storedCheque ?? 0)
        : switch (mode) {
            'cheque' => total,
            'deposito' => 0.0,
            _ => storedCheque ?? 0,
          };
    return HrFiscalPayment(total: total, cheque: cheque);
  }
}
