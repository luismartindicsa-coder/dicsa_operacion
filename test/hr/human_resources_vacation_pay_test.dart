import 'package:dicsa_operacion/app/hr/human_resources_vacation_pay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'vacation and premium use perceived salary; fiscal plus flow equals total',
    () {
      final pay = HrVacationPay(
        perceivedWeekly: 3500,
        fiscalWeekly: 2100,
        vacationDays: 6,
      );
      expect(pay.perceivedDaily, 500);
      expect(pay.vacation, 3000);
      expect(pay.premium, 750);
      expect(pay.total, 3750);
      expect(pay.fiscalVacation, 1800);
      expect(pay.fiscalPremium, 450);
      expect(pay.flowVacation, 1200);
      expect(pay.flowPremium, 300);
      expect(pay.fiscal + pay.flow, pay.total);
    },
  );
  test(
    'changing base salary only redistributes payment, never changes entitlement',
    () {
      for (final fiscal in [1400.0, 2100.0, 3500.0, 4900.0]) {
        final pay = HrVacationPay(
          perceivedWeekly: 3500,
          fiscalWeekly: fiscal,
          vacationDays: 6,
        );
        expect(pay.total, 3750);
        expect(pay.premium, 750);
        expect(pay.flow, greaterThanOrEqualTo(0));
        expect(pay.fiscal + pay.flow, pay.total);
      }
    },
  );
  test('additional salary days keep existing premium day semantics', () {
    final pay = HrVacationPay(
      perceivedWeekly: 3500,
      fiscalWeekly: 2100,
      vacationDays: 6,
      additionalPaidDays: 1,
    );
    expect(pay.vacation, 3500);
    expect(pay.premium, 750);
    expect(pay.total, 4250);
    expect(pay.fiscal + pay.flow, pay.total);
  });
  test('missing perceived salary never silently substitutes base salary', () {
    final pay = HrVacationPay(
      perceivedWeekly: 0,
      fiscalWeekly: 2100,
      vacationDays: 6,
    );
    expect(pay.total, 0);
    expect(pay.premium, 0);
  });
}
