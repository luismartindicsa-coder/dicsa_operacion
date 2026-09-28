import 'dart:math';

import 'package:dicsa_operacion/app/mayoreo/mayoreo_invoice_reconciliation.dart';
import 'package:flutter_test/flutter_test.dart';

MayoreoInvoiceTicket ticket(int amount, String id, {String client = 'a'}) =>
    MayoreoInvoiceTicket(
      clientKey: client,
      clientName: client,
      ticketKey: id,
      ticket: id,
      saleDate: DateTime(2026, 9, 28),
      amountCents: amount,
      sourceIds: [id],
    );

void main() {
  test(
    'parses Mexican money exactly and rejects ambiguous or invalid input',
    () {
      expect(parseReconciliationCents(r'$165,643.01'), 16564301);
      expect(parseReconciliationCents('0.01'), 1);
      expect(parseReconciliationCents('165643'), 16564300);
      for (final invalid in [
        '0',
        '-1',
        '1.001',
        '1,20',
        '1e4',
        'NaN',
        '',
        'Infinity',
        '999999999999999999999',
        '1.000,00',
      ]) {
        expect(parseReconciliationCents(invalid), isNull, reason: invalid);
      }
    },
  );

  test('finds a non-greedy exact combination with integer cents', () {
    final result = findMayoreoInvoiceMatch(
      MayoreoInvoiceSearch(
        [
          ticket(10000000, '1'),
          ticket(9564301, '2'),
          ticket(7000000, '3'),
          ticket(123, 'other', client: 'b'),
        ],
        'a',
        16564301,
      ),
    );
    expect(result.missingCents, 0);
    expect(result.tickets.map((row) => row.ticketKey).toSet(), {'2', '3'});
  });

  test('never duplicates a ticket or exceeds the target', () {
    final result = findMayoreoInvoiceMatch(
      MayoreoInvoiceSearch(
        [
          ticket(600, '1'),
          ticket(600, '1'),
          ticket(350, '2'),
          ticket(1001, '3'),
        ],
        'a',
        1000,
      ),
    );
    expect(result.totalCents, 950);
    expect(result.missingCents, 50);
    expect(result.tickets.length, 2);
  });

  test('empty, insufficient total, exact single ticket and equal amounts', () {
    for (final amounts in [
      <int>[],
      [100, 200],
      [300],
      [150, 150, 150],
    ]) {
      final result = findMayoreoInvoiceMatch(
        MayoreoInvoiceSearch(
          [for (var i = 0; i < amounts.length; i++) ticket(amounts[i], '$i')],
          'a',
          300,
        ),
      );
      expect(result.totalCents, amounts.isEmpty ? 0 : 300);
      expect(result.exhaustive, isTrue);
    }
  });

  test('matches brute-force optimum across random and word-boundary cases', () {
    final random = Random(928);
    for (var run = 0; run < 250; run++) {
      final amounts = List.generate(12, (_) => random.nextInt(200) + 1);
      final target = random.nextInt(900) + 1;
      var optimum = 0;
      for (var mask = 0; mask < 1 << amounts.length; mask++) {
        var sum = 0;
        for (var i = 0; i < amounts.length; i++) {
          if (mask & (1 << i) != 0) sum += amounts[i];
        }
        if (sum <= target && sum > optimum) optimum = sum;
      }
      final result = findMayoreoInvoiceMatch(
        MayoreoInvoiceSearch(
          [for (var i = 0; i < amounts.length; i++) ticket(amounts[i], '$i')],
          'a',
          target,
        ),
      );
      expect(
        result.totalCents,
        optimum,
        reason: 'run $run: $amounts / $target',
      );
      expect(
        result.tickets.map((row) => row.ticketKey).toSet().length,
        result.tickets.length,
      );
    }
  });

  test('large searches are conservative and honestly marked approximate', () {
    final result = findMayoreoInvoiceMatch(
      MayoreoInvoiceSearch(
        [ticket(100000000, '1'), ticket(99999999, '2'), ticket(50000000, '3')],
        'a',
        150000001,
      ),
    );
    expect(result.totalCents, lessThanOrEqualTo(150000001));
    expect(result.totalCents, greaterThanOrEqualTo(149999999));
    expect(result.exhaustive, isFalse);
  });
}
