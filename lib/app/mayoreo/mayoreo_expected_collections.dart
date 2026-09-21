/// Shared rule for Mayoreo's "Cobranza esta semana". Linked bank credits
/// replace the captured paid amount; the two sources must never be added.
double mayoreoEffectivePaid({
  required String accountId,
  required double amount,
  required double paid,
  required Map<String, double> bankCredits,
}) => (bankCredits[accountId] ?? paid).clamp(0, amount).toDouble();

bool mayoreoCollectionIsOpen({
  required String operationType,
  required String status,
  required double pending,
  required DateTime? due,
}) =>
    operationType.toLowerCase() != 'cheque' &&
    due != null &&
    pending > 0.009 &&
    !{'pagada', 'chequecanjeado', 'cancelada'}.contains(status.toLowerCase());

class MayoreoExpectedCollection {
  final String accountId, client, material, document;
  final DateTime saleDate, dueDate;
  final int pendingCents;
  const MayoreoExpectedCollection({
    required this.accountId,
    required this.client,
    required this.material,
    required this.document,
    required this.saleDate,
    required this.dueDate,
    required this.pendingCents,
  });
}

List<MayoreoExpectedCollection> mayoreoExpectedCollections(
  List<Map<String, dynamic>> accounts,
  Map<String, double> bankCredits,
) {
  DateTime day(String value) {
    final d = DateTime.parse(value);
    return DateTime(d.year, d.month, d.day);
  }

  final result = <MayoreoExpectedCollection>[];
  for (final row in accounts) {
    final id = '${row['id']}';
    final amount = (row['approved_amount'] as num? ?? 0).toDouble();
    final paid = mayoreoEffectivePaid(
      accountId: id,
      amount: amount,
      paid: (row['paid_amount'] as num? ?? 0).toDouble(),
      bankCredits: bankCredits,
    );
    final pending = (amount - paid).clamp(0, double.infinity).toDouble();
    final due = row['estimated_payment_date'] == null
        ? null
        : day('${row['estimated_payment_date']}');
    if (!mayoreoCollectionIsOpen(
      operationType: '${row['operation_type'] ?? 'factura'}',
      status: '${row['status']}',
      pending: pending,
      due: due,
    )) {
      continue;
    }
    result.add(
      MayoreoExpectedCollection(
        accountId: id,
        client: '${row['client_name_snapshot'] ?? ''}',
        material: '${row['material_name_snapshot'] ?? ''}',
        document: '${row['document_number'] ?? ''}',
        saleDate: day('${row['sale_date']}'),
        dueDate: due!,
        pendingCents: (pending * 100).round(),
      ),
    );
  }
  return result;
}
