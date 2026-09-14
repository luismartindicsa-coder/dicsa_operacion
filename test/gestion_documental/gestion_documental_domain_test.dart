import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_records.dart';

void main() {
  test('urgency uses civil dates and exact boundaries', () {
    final today = DateTime(2026, 9, 14, 23, 59);
    for (final value in {
      -1: DocumentalUrgency.expired,
      0: DocumentalUrgency.critical,
      5: DocumentalUrgency.critical,
      6: DocumentalUrgency.attention,
      15: DocumentalUrgency.attention,
      16: DocumentalUrgency.onTime,
    }.entries) {
      final expires = DateTime(2026, 9, 14 + value.key);
      expect(documentalDaysRemaining(expires, today), value.key);
      expect(documentalUrgency('En proceso', expires, today), value.value);
      expect(
        documentalUrgency('Completado', expires, today),
        DocumentalUrgency.completed,
      );
    }
    expect(
      documentalUrgency('Pendiente', null, today),
      DocumentalUrgency.noExpiration,
    );
    expect(documentalDateJson(DateTime(2026, 1, 2, 20)), '2026-01-02');
  });
}
