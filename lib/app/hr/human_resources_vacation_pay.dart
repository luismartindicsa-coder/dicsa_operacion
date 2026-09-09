/// Vacation entitlement uses perceived pay. Fiscal salary only allocates the
/// existing payment between fiscal and flow; it never replaces perceived pay.
class HrVacationPay {
  final double perceivedDaily;
  final double vacation;
  final double premium;
  final double fiscalShare;

  HrVacationPay({
    required double perceivedWeekly,
    required double fiscalWeekly,
    required double vacationDays,
    double additionalPaidDays = 0,
  }) : perceivedDaily = perceivedWeekly > 0 ? perceivedWeekly / 7 : 0,
       vacation = perceivedWeekly > 0
           ? perceivedWeekly / 7 * (vacationDays + additionalPaidDays)
           : 0,
       premium = perceivedWeekly > 0
           ? perceivedWeekly / 7 * vacationDays * 0.25
           : 0,
       fiscalShare = perceivedWeekly > 0 && fiscalWeekly > 0
           ? (fiscalWeekly / perceivedWeekly).clamp(0, 1).toDouble()
           : 1;

  double get total => vacation + premium;
  double get fiscalVacation => vacation * fiscalShare;
  double get fiscalPremium => premium * fiscalShare;
  double get fiscal => total * fiscalShare;
  double get flowVacation => vacation - fiscalVacation;
  double get flowPremium => premium - fiscalPremium;
  double get flow => total - fiscal;
}
