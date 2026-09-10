import 'package:dicsa_operacion/app/hr/human_resources_termination_calculation.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> fixture() => {
  'mode': 'finiquito',
  'start_date': '2020-07-30',
  'end_date': '2026-09-04',
  'aguinaldo_start': '2026-01-01',
  'vacation_start': '2026-07-30',
  'weekly_base': 2205.2,
  'weekly_flow': 0,
  'aguinaldo_days': 15,
  'vacation_days': 22,
  'premium_percent': 25,
  'official_isr': 125.48,
  'isr_reference': 'CONTPAQ finiquito RH',
  'reason': 'Renuncia',
  'history_reviewed': true,
  'separation_reviewed': true,
  'minimum_daily': 315.04,
};

HrTerminationResult calculate(Map<String, dynamic> values) =>
    HrTerminationResult.calculate(HrTerminationInput(values));

void main() {
  test(
    'reproduces the actual workbook without rounding daily salary first',
    () {
      final result = calculate(fixture());
      expect(result.gross.total, 4039.27);
      expect(result.net!.total, 3913.79);
      expect(
        result.lines.firstWhere((l) => l.key == 'aguinaldo').amount.total,
        3184.81,
      );
      expect(
        result.lines.firstWhere((l) => l.key == 'vacations').amount.total,
        683.57,
      );
      expect(
        result.lines.firstWhere((l) => l.key == 'premium').amount.total,
        170.89,
      );
      expect(result.canReview, isTrue);
    },
  );

  test(
    'flow derives from contractual compensation and does not absorb ISR',
    () {
      final values = {
        ...fixture(),
        'weekly_base': 2205.28,
        'weekly_flow': 2694.72,
      };
      final before = calculate(values);
      final after = calculate({...values, 'official_isr': 700});
      expect(after.net!.flow, before.net!.flow);
      expect(before.net!.base - after.net!.base, closeTo(574.52, .001));
      expect(
        before.net!.total,
        hrTerminationMoney(before.net!.base + before.net!.flow),
      );
      expect(calculate(fixture()).net!.flow, 0);
    },
  );

  test('modalities accumulate each concept exactly once', () {
    final finiquito = calculate(fixture());
    final liquidation = calculate({...fixture(), 'mode': 'liquidacion'});
    final indemnity = calculate({
      ...fixture(),
      'mode': 'indemnizacion',
      'integrated_daily_base': 350,
      'integrated_daily_total': 500,
    });
    expect(liquidation.lines.where((l) => l.key == 'seniority'), hasLength(1));
    expect(liquidation.lines.where((l) => l.key == 'indemnity'), isEmpty);
    expect(indemnity.lines.where((l) => l.key == 'seniority'), hasLength(1));
    expect(indemnity.lines.where((l) => l.key == 'aguinaldo'), hasLength(1));
    expect(
      indemnity.gross.total - liquidation.gross.total,
      closeTo(45000, .001),
    );
    expect(liquidation.gross.total, greaterThan(finiquito.gross.total));
  });

  test('twelve-day seniority applies its cap to each salary basis', () {
    final result = calculate({
      ...fixture(),
      'mode': 'liquidacion',
      'weekly_base': 7000,
      'weekly_flow': 7000,
    });
    final seniority = result.lines.firstWhere((l) => l.key == 'seniority');
    final years = HrTerminationInput(fixture()).serviceYears;
    expect(seniority.amount.base, hrTerminationMoney(630.08 * 12 * years));
    expect(seniority.amount.flow, 0);
  });

  test('pending salary and saving/bonus balances are included in gross', () {
    final before = calculate(fixture());
    final after = calculate({
      ...fixture(),
      'unpaid_days': 2,
      'savings_base': 500,
      'savings_flow': 300,
      'commissions_flow': 100,
      'night_bonus_flow': 80,
      'attendance_bonus_flow': 90,
    });
    expect(after.gross.total - before.gross.total, closeTo(1700.06, .001));
  });

  test('premium uses the captured percentage, not the template constant', () {
    final result = calculate({...fixture(), 'premium_percent': 30});
    expect(
      result.lines.firstWhere((l) => l.key == 'premium').amount.total,
      205.07,
    );
  });

  test('previous vacation payments are offset only once and expose excess', () {
    final result = calculate({
      ...fixture(),
      'paid_vacation_base': 683.57,
      'paid_premium_base': 170.89,
    });
    expect(result.gross.base, 3184.81);
    final excess = calculate({...fixture(), 'paid_vacation_base': 1000});
    expect(excess.canReview, isFalse);
    expect(excess.lines.firstWhere((l) => l.key == 'vacations').amount.base, 0);
  });

  test('unknown ISR does not appear as a payable net; explicit zero does', () {
    final unknown = calculate({...fixture(), 'official_isr': ''});
    expect(unknown.net, isNull);
    expect(unknown.canReview, isFalse);
    final zero = calculate({...fixture(), 'official_isr': 0});
    expect(zero.net!.total, zero.gross.total);
  });

  test('excess deductions never borrow from flow or silently clamp fiscal', () {
    final result = calculate({
      ...fixture(),
      'official_isr': 5000,
      'weekly_flow': 1000,
    });
    expect(result.net!.base, lessThan(0));
    expect(result.net!.flow, result.gross.flow);
    expect(result.canReview, isFalse);
  });

  test('rejects invalid dates, nonfinite salaries and missing integration', () {
    expect(
      () => calculate({...fixture(), 'end_date': '2019-01-01'}),
      throwsFormatException,
    );
    expect(
      () => calculate({...fixture(), 'weekly_base': double.nan}),
      throwsFormatException,
    );
    expect(
      () => calculate({...fixture(), 'mode': 'indemnizacion'}),
      throwsFormatException,
    );
  });

  test(
    'calendar dates ignore DST and February 29 anniversaries are clamped',
    () {
      final input = HrTerminationInput(fixture());
      expect(input.elapsed('aguinaldo_start'), 246);
      expect(input.elapsed('vacation_start'), 36);
      expect(
        HrTerminationInput({
          ...fixture(),
          'inclusive_dates': true,
        }).elapsed('aguinaldo_start'),
        247,
      );
      expect(
        hrTerminationServiceYears(DateTime(2020, 2, 29), DateTime(2021, 2, 28)),
        1,
      );
    },
  );
}
