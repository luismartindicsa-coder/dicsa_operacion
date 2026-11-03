import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_cash_flow_income.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_payment_schedule.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_report.dart';
import 'package:dicsa_operacion/app/mayoreo/mayoreo_expected_collections.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expected_income_collections_test.dart' as c;
import 'expected_income_test.dart' as f;

DateTime day(int offset) => f.incomeWeek.add(Duration(days: offset));
WeeklyExpensePlan plan() => WeeklyExpensePlan(
  week: f.incomeWeek,
  generated: true,
  openingCash: 0,
  openingFiscal: 0,
);
ExpectedIncomeProjection projection({
  int? cashDay = 6,
  int? fiscalDay = 1,
  List<MayoreoExpectedCollection> collections = const [],
}) => f.forecast(
  bundle: f.incomeBundle(shipments: []),
  data: ExpectedIncomeData(
    collections: collections,
    palomarConfig: const PalomarIncomeConfig(
      creditLimit: 400000,
      drawAmount: 400000,
      cashCheck1: 99000,
      cashCheck2: 99000,
    ),
    palomarSchedule: PalomarReceiptSchedule(
      week: f.incomeWeek,
      cashDate: cashDay == null ? null : day(cashDay),
      fiscalDate: fiscalDay == null ? null : day(fiscalDay),
    ),
  ),
);

void main() {
  test(
    'Sunday Palomar is excluded per channel from total, balance, detail and daily funds',
    () {
      final source = projection();
      final report = WeeklyCashFlowReport(source, plan());
      expect(report.flow.income.total, 20200000);
      expect(report.flow.income.financingByType['EFECTIVO'], 0);
      expect(report.flow.closing, 20200000);
      expect(report.incomes.single.type, 'FISCAL');
      expect(report.income.excludedPalomar.total, 19800000);
      final pressure = weeklyPaymentPressure(
        plan: plan(),
        income: source,
        now: day(0),
      );
      expect(pressure.days[1].receipts, 20200000);
      expect(pressure.days[6].receipts, 0);
      expect(pressure.days[6].closing['EFECTIVO'], 0);
      expect(pressure.warnings, contains(contains('domingo')));
      // Deriving a flow repeatedly never mutates/deducts the source a second time.
      expect(source.current.total, 40000000);
      expect(source.timeline[day(6)]!.financingTotal, 19800000);
      expect(WeeklyCashFlowIncome(source, day(0)).totals.total, 20200000);
      expect(
        WeeklyCashFlowReport(
          projection(cashDay: 6, fiscalDay: 6),
          plan(),
        ).flow.income.total,
        0,
      );
    },
  );

  test(
    'Saturday and undated Palomar retain weekly treatment; other Sunday sales remain included',
    () {
      final source = projection(
        cashDay: 5,
        fiscalDay: null,
        collections: mayoreoExpectedCollections([
          c.account(id: 'sunday-sale', due: '2026-09-27', paid: 0),
        ], {}),
      );
      final report = WeeklyCashFlowReport(source, plan());
      expect(report.flow.income.total, 41000000);
      expect(report.income.excludedPalomar.total, 0);
      final calendar = WeeklyCashFlowCalendar(report, day(0));
      expect(calendar.undated.total, 20200000);
      expect(calendar.pressure.days[5].receipts, 19800000);
      expect(calendar.pressure.days[6].receipts, 1000000);
    },
  );

  test(
    'unpaid Bio Papel carries only its net balance and retains original due date without funding Monday',
    () {
      final accounts = mayoreoExpectedCollections(
        [
          c.account(
            id: 'bio',
            client: 'BIO PAPEL',
            due: '2026-09-18',
            paid: 2000,
          ),
          c.account(id: 'current', due: '2026-09-23', paid: 0),
          c.account(id: 'next', due: '2026-09-28', paid: 0),
          c.account(id: 'paid', status: 'pagada', due: '2026-09-18'),
          c.account(id: 'cancel', status: 'cancelada', due: '2026-09-18'),
          c.account(id: 'undated', due: null),
        ],
        {'bio': 4000},
      );
      final source = f.forecast(
        bundle: f.incomeBundle(shipments: []),
        data: ExpectedIncomeData(collections: accounts),
      );
      final report = WeeklyCashFlowReport(source, plan());
      expect(report.flow.income.total, 1600000);
      expect(report.income.carryover.total, 600000);
      expect(report.incomes, hasLength(2));
      final bio = report.incomes.singleWhere((r) => r.client == 'BIO PAPEL');
      expect(bio.amount, 600000);
      expect(bio.date, isNull);
      expect(bio.reference, contains('2026-09-18'));
      expect(bio.reference, contains('F-18'));
      expect(bio.carriedOver, isTrue);
      final calendar = WeeklyCashFlowCalendar(report, day(0));
      expect(calendar.undated.total, 600000);
      expect(calendar.pressure.days.first.receipts, 0);
      expect(calendar.pressure.days[2].receipts, 1000000);
      expect(calendar.pressure.warnings, contains(contains('vencidos')));
      expect(source.overdue.total, 600000);
      expect(source.collections.first.dueDate, day(-3));
      expect(source.current.total, 1000000);
    },
  );

  test(
    'linked overdue receivable counts once and mixed allocations retain their channels',
    () {
      final bundle = f.incomeBundle(
        shipments: [f.incomeShipment(status: 'embarcado')],
      );
      ExpectedIncomeData data({
        List<IncomeSale>? sales,
        Map<String, IncomeAllocation> allocations = const {},
      }) => ExpectedIncomeData(
        materials: f.incomeMaterials,
        clients: const [
          IncomeClientRule(
            key: 'RICARDO MENDIETA',
            name: 'RICARDO MENDIETA',
            paymentType: 'MIXTO',
          ),
        ],
        allocations: allocations,
        sales:
            sales ??
            [
              f.incomeSale(
                amount: 1000000,
                paid: 400000,
                status: 'pagoParcial',
                due: day(-3),
              ),
            ],
        collections: mayoreoExpectedCollections(
          [
            c.account(
              id: 'r1',
              client: 'RICARDO MENDIETA',
              saleDate: '2026-09-21',
              due: '2026-09-18',
            ),
          ],
          {'r1': 4000},
        ),
      );
      final original = f.forecast(bundle: bundle, data: data());
      final allocation = original.rows.single.distribute(
        cashCents: 200000,
        fiscalCents: 400000,
      );
      final source = f.forecast(
        bundle: bundle,
        data: data(allocations: {'s1': allocation}),
      );
      final report = WeeklyCashFlowReport(source, plan());
      expect(source.collections, isEmpty);
      expect(report.flow.income.total, 600000);
      expect(report.income.carryover.byType['EFECTIVO'], 200000);
      expect(report.income.carryover.byType['FISCAL'], 400000);
      expect(report.incomes, hasLength(2)); // One split, no extra collection.
      expect(report.incomes.every((r) => r.carriedOver), isTrue);
      final settled = f.forecast(
        bundle: bundle,
        data: data(
          sales: [
            f.incomeSale(amount: 1000000, status: 'pagada', due: day(-3)),
          ],
        ),
      );
      expect(WeeklyCashFlowIncome(settled, day(0)).totals.total, 0);
    },
  );

  test(
    'refreshing a bank payment or rescheduled date updates carryover without accumulation',
    () {
      WeeklyCashFlowIncome reload({
        double paid = 0,
        String due = '2026-09-18',
      }) {
        final collections = mayoreoExpectedCollections(
          [c.account(id: 'bio', client: 'BIO PAPEL', due: due)],
          {'bio': paid},
        );
        return WeeklyCashFlowIncome(
          f.forecast(
            bundle: f.incomeBundle(shipments: []),
            data: ExpectedIncomeData(collections: collections),
          ),
          day(0),
        );
      }

      expect(reload().totals.total, 1000000);
      expect(reload(paid: 3000).totals.total, 700000);
      expect(reload(paid: 10000).totals.total, 0);
      expect(reload(due: '2026-09-28').totals.total, 0);
      final rescheduled = reload(paid: 3000, due: '2026-09-24');
      expect(rescheduled.totals.total, 700000);
      expect(rescheduled.carryover.total, 0);
      expect(rescheduled.incomes.single.date, day(3));
    },
  );
}
