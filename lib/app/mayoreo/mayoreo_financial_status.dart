bool isMayoreoPalomarClientName(String value) {
  final normalized = value
      .toUpperCase()
      .trim()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U');
  return normalized.contains('PALOMAR');
}

String deriveMayoreoFinancialStatus({
  required String baseStatus,
  required String operationType,
  required bool isPalomarAccount,
  required String documentNumber,
  required DateTime? documentDate,
  required DateTime? settlementDate,
  required double paidAmount,
  required double approvedAmount,
}) {
  const tolerance = 0.5;
  final normalizedPaidAmount = paidAmount < 0 ? 0.0 : paidAmount;
  final pendingBalance = approvedAmount - normalizedPaidAmount;
  final isSettled = pendingBalance <= tolerance;
  final hasDocumentEvidence =
      documentNumber.trim().isNotEmpty || documentDate != null;

  if (baseStatus == 'cancelada' || baseStatus == 'porRevisar') {
    return baseStatus;
  }
  if (operationType == 'factura') {
    if (normalizedPaidAmount > tolerance) {
      return isSettled ? 'pagada' : 'pagoParcial';
    }
    return hasDocumentEvidence ? 'facturadaPendientePago' : 'pendienteFactura';
  }
  if (isPalomarAccount && baseStatus == 'chequeCanjeado') {
    return 'chequeCanjeado';
  }
  if (settlementDate != null) {
    return 'chequeCanjeado';
  }
  if (normalizedPaidAmount > tolerance) {
    return 'chequePendienteCanje';
  }
  return hasDocumentEvidence ? 'chequeRecibido' : 'pendienteCheque';
}
