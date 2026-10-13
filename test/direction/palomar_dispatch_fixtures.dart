import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/expected_income/palomar_weekly_dispatch.dart';
import 'expected_income_test.dart' as f;

final dispatchQuotes = [
  for (var i = 0; i < palomarDispatchGrades.length; i++)
    PalomarMaterialQuote(
      'MAYOREO:$i',
      palomarDispatchGrades.keys.elementAt(i),
      'kg',
      (i + 2).toDouble(),
    ),
];
IncomeSale dispatchSale(
  int material,
  int date,
  int amount, {
  String? id,
  String client = 'EL PALOMAR',
  String? status,
}) => IncomeSale(
  id: id ?? '$material-$date',
  client: client,
  material: 'MAYOREO:$material',
  ticket: 'R-$material-$date',
  date: f.incomeWeek.add(Duration(days: date)),
  approvedCents: amount,
  accountStatus: status,
);
