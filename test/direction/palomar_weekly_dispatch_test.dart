import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/expected_income/palomar_weekly_dispatch.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expected_income_test.dart' as f;
import 'palomar_coverage_test.dart' as c;
import 'palomar_dispatch_fixtures.dart';

PalomarWeeklyDispatch dispatch(ExpectedIncomeData source, {int now = 0}) =>
    projectPalomarWeeklyDispatch(
      data: source,
      bundle: f.incomeBundle(shipments: []),
      now: c.day(now),
    );

void main() {
  test(
    'posted remittances reduce the reference once and only on their ledger date',
    () {
      final source = c.data(
        quotes: dispatchQuotes,
        movements: [
          c.movement(-10, 10000000),
          c.movement(0, -2000000, report: 'applied'),
          c.movement(1, -1000000, report: 'future'),
          c.movement(4, -20000000, projected: true),
        ],
        shipments: [c.shipment('linked', 0)],
        links: {'linked': 'applied'},
        sales: [
          f.incomeSale(id: 'applied', client: 'EL PALOMAR', amount: 2000000),
        ],
      );
      expect(dispatch(source).coverage.remaining, 8000000);
      expect(dispatch(source, now: 1).coverage.remaining, 7000000);
      expect(source.palomarMovements, hasLength(4));
    },
  );
  test(
    'income keeps its projected disposition while the material reference covers the real account',
    () {
      final bundle = f.incomeBundle(
        shipments: [
          f.incomeShipment(
            client: 'EL PALOMAR',
            material: 'PACA_LIMPIA',
            day: 4,
            bales: 100,
          ),
        ],
      );
      final source = ExpectedIncomeData(
        clients: f.incomeClients,
        materials: const [IncomeMaterialRule('PACA_LIMPIA', 700, 3.1)],
        palomarCoverageMaterials: dispatchQuotes,
        palomarCoverageShipments: [
          c.bulkShipment('unvalued', 'METAL', 1000, 4),
        ],
        palomarMovements: [
          c.movement(-1, -1656914),
          c.movement(0, 51656940),
          c.movement(4, -31100026, projected: true),
        ],
        palomarSchedule: PalomarReceiptSchedule(
          week: c.day(0),
          cashDate: c.day(4),
          fiscalDate: c.day(4),
        ),
        palomarConfig: const PalomarIncomeConfig(
          creditLimit: 400000,
          drawAmount: 400000,
          cashCheck1: 99000,
          cashCheck2: 99000,
        ),
      );
      final before = f.forecast(bundle: bundle, data: source).palomar;
      final p = projectPalomarWeeklyDispatch(
        data: source,
        bundle: bundle,
        now: c.day(0),
      );
      final after = f.forecast(bundle: bundle, data: source).palomar;
      expect(before.closing, -2800000);
      expect(before.availableDraw, 40000000);
      expect(p.coverage.complete, true);
      expect(p.coverage.remaining, 50000026);
      expect(p.proposedCents, greaterThanOrEqualTo(50000026));
      expect(p.closing, lessThanOrEqualTo(0));
      expect(after.closing, before.closing);
      expect(after.availableDraw, before.availableDraw);
      expect(after.cash, 19800000);
      expect(after.fiscal, 20200000);
    },
  );
  test(
    'automatically mixes five materials by observed amounts and weekdays at current prices',
    () {
      final p = dispatch(
        c.data(
          movements: [c.movement(-20, 15000000)],
          quotes: dispatchQuotes,
          sales: [
            for (var i = 0; i < 5; i++)
              dispatchSale(i, -7 + i, (i + 1) * 100000),
          ],
        ),
      );
      expect(p.historicalRecords, 5);
      expect(p.materials.map((m) => m.targetCents), [
        1000000,
        2000000,
        3000000,
        4000000,
        5000000,
      ]);
      expect(p.days, hasLength(5));
      for (var i = 0; i < 5; i++) {
        final cell = p.days[i].materials.values.single;
        expect(cell.material, 'MAYOREO:$i');
        expect(cell.unit, 'kg');
        expect(cell.amount, dispatchQuotes[i].amount(cell.quantity!));
        expect(cell.amount, greaterThanOrEqualTo(p.materials[i].targetCents));
      }
      expect(p.closing, lessThanOrEqualTo(0));
      expect(p.days.last.closing, p.closing);
      expect(p.coverage.balance, 15000000);
    },
  );
  test(
    'empty history explicitly uses 20 percent per material, with all cents assigned',
    () {
      final p = dispatch(
        c.data(movements: [c.movement(-10, 10000001)], quotes: dispatchQuotes),
      );
      expect(p.historicalRecords, 0);
      expect(p.materials.every((m) => m.share == .2), true);
      expect(
        p.materials.map((m) => m.targetCents).reduce((a, b) => a + b),
        10000001,
      );
      expect(p.days.every((d) => d.materials.length == 5), true);
      expect(p.warnings.join(' '), contains('reparto inicial de 20%'));
      expect(p.closing, lessThanOrEqualTo(0));
    },
  );
  test(
    'only complete prior six weeks and this customer train; paired remittance counted once',
    () {
      final p = dispatch(
        c.data(
          quotes: dispatchQuotes,
          movements: [
            c.movement(-40, 10000000),
            c.movement(
              -7,
              -10000,
              report: 'linked',
              concept: 'remisionAplicada · ORDINARIO DE PRIMERA',
            ),
            c.movement(-6, -30000, concept: 'remisionAplicada · REBABA'),
            c.movement(
              -5,
              -100000,
              projected: true,
              concept: 'remisionAplicada · MIXTO',
            ),
            c.movement(-4, -100000, concept: 'ajusteAbono · PESADO'),
          ],
          sales: [
            dispatchSale(0, -7, 10000, id: 'linked'),
            dispatchSale(0, -7, 10000, id: 'linked'),
            dispatchSale(2, -43, 9000000),
            dispatchSale(2, 0, 9000000),
            dispatchSale(2, 4, 9000000),
            dispatchSale(2, -3, 9000000, client: 'EL PALOMAR GUADALAJARA'),
            dispatchSale(2, -2, 9000000, status: 'cancelada'),
          ],
        ),
      );
      expect(p.historyFrom, c.day(-42));
      expect(p.historyUntil, c.day(0));
      expect(p.historicalRecords, 2);
      expect(p.materials.map((m) => m.share), [.25, .75, 0, 0, 0]);
      expect(p.materials.map((m) => m.historicalCents), [
        10000,
        30000,
        0,
        0,
        0,
      ]);
    },
  );
  test(
    'future week does not backdate dispatches or use current incomplete week to train',
    () {
      final p = dispatch(
        c.data(
          quotes: dispatchQuotes,
          movements: [c.movement(-30, 10000000)],
          sales: [dispatchSale(0, -14, 999999), dispatchSale(1, -15, 10000)],
        ),
        now: -14,
      );
      expect(p.days.first.date, c.day(0));
      expect(p.days.last.date, c.day(4));
      expect(p.historyUntil, c.day(-14));
      expect(p.historicalRecords, 1);
      expect(p.materials[1].share, 1);
    },
  );
  test(
    'midweek receipt keeps proposals from today through earliest receipt, never later',
    () {
      final p = dispatch(
        c.data(
          quotes: dispatchQuotes,
          receipt: 4,
          fiscal: 3,
          movements: [c.movement(-10, 10000000)],
          sales: [for (var i = 0; i < 5; i++) dispatchSale(i, -7, 10000)],
        ),
        now: 2,
      );
      expect(p.days.map((d) => d.date), [c.day(2), c.day(3)]);
      expect(p.days.every((d) => d.materials.length == 5), true);
      expect(p.closing, lessThanOrEqualTo(0));
    },
  );
  test(
    'real balance excludes agenda, expected credits and future dated ledger entries',
    () {
      final p = dispatch(
        c.data(
          quotes: dispatchQuotes,
          movements: [
            c.movement(-10, 10000000),
            c.movement(2, 1000000),
            c.movement(4, -500000, projected: true),
          ],
          shipments: [c.shipment('planned', 1, bales: 10)],
        ),
      );
      expect(p.coverage.projectedBalance, 10000000);
      expect(p.coverage.events, isEmpty);
      expect(
        p.materials.map((m) => m.targetCents).reduce((a, b) => a + b),
        10000000,
      );
      var balance = p.coverage.balance;
      for (final day in p.days) {
        balance += p.coverage.events
            .where((e) => e.date == day.date)
            .fold<int>(0, (s, e) => s + e.signedCents!);
        balance -= day.total;
        expect(day.closing, balance);
      }
      expect(p.closing, balance);
    },
  );
  test(
    'missing grade price retains its uncovered share without borrowing another variety price',
    () {
      final p = dispatch(
        c.data(
          movements: [c.movement(-10, 10000000)],
          quotes: [
            ...dispatchQuotes.skip(1),
            const PalomarMaterialQuote(
              'PACA_LIMPIA',
              'Cartón limpio',
              'pacas',
              2100,
            ),
            const PalomarMaterialQuote(
              'other',
              'ORDINARIO DE PRIMERA RECOGIDO',
              'kg',
              10,
            ),
          ],
        ),
      );
      expect(p.materials.first.quote, isNull);
      expect(
        p.days.every((d) => !d.materials.containsKey('ORDINARIO DE PRIMERA')),
        true,
      );
      expect(p.closing, greaterThan(1900000));
      expect(p.warnings.join(' '), contains('Limpio (ORDINARIO DE PRIMERA)'));
    },
  );
  test(
    'duplicate active exact grade is ambiguous, no arbitrary current price selected',
    () {
      final p = dispatch(
        c.data(
          quotes: [
            ...dispatchQuotes,
            const PalomarMaterialQuote('duplicate', 'REBABA', 'kg', 99),
          ],
          movements: [c.movement(-10, 10000000)],
        ),
      );
      expect(p.materials[1].quote, isNull);
      expect(p.closing, greaterThan(1900000));
    },
  );
  test(
    'unit conversion is never guessed and per-day subcent rounding still covers',
    () {
      final p = dispatch(
        c.data(
          quotes: [
            for (var i = 0; i < 5; i++)
              PalomarMaterialQuote(
                'MAYOREO:$i',
                palomarDispatchGrades.keys.elementAt(i),
                i == 0 ? 't' : 'kg',
                .004,
              ),
          ],
          movements: [c.movement(-10, 501)],
        ),
      );
      expect(p.closing, lessThanOrEqualTo(0));
      for (final m in p.materials) {
        final cells = p.days
            .map((d) => d.materials[m.catalogName])
            .where((cell) => cell != null)
            .toList();
        expect(
          cells.fold<int>(0, (s, cell) => s + cell!.amount!),
          greaterThanOrEqualTo(m.targetCents),
        );
        expect(cells.every((cell) => cell!.unit == m.quote!.unit), true);
      }
    },
  );
  test(
    'no deadline, expired deadline, Sunday-only and covered account do not invent sends',
    () {
      for (final pair in [(null, 0), (2, 7), (6, 6)]) {
        final p = dispatch(
          c.data(
            receipt: pair.$1,
            quotes: dispatchQuotes,
            movements: [c.movement(-10, 10000000)],
          ),
          now: pair.$2,
        );
        expect(p.days, isEmpty);
        expect(p.proposedCents, 0);
      }
      final covered = dispatch(
        c.data(quotes: dispatchQuotes, movements: [c.movement(-10, -1000)]),
      );
      expect(covered.proposedCents, 0);
      expect(covered.closing, -1000);
    },
  );
  test(
    'unknown agenda valuation does not block the real balance reference',
    () {
      final p = dispatch(
        c.data(
          quotes: dispatchQuotes,
          materials: [],
          movements: [c.movement(-10, 10000000)],
          shipments: [c.shipment('missing', 0)],
        ),
      );
      expect(p.coverage.complete, true);
      expect(p.coverage.remaining, 10000000);
      expect(p.proposedCents, greaterThanOrEqualTo(10000000));
      expect(p.closing, lessThanOrEqualTo(0));
    },
  );
}
