import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'logistics_fuel_cost.dart';

class LogisticsFuelPrices {
  final DateTime effectiveDate;
  final double? diesel, gasoline;
  const LogisticsFuelPrices({
    required this.effectiveDate,
    this.diesel,
    this.gasoline,
  });

  factory LogisticsFuelPrices.fromRow(Map<String, dynamic> row) =>
      LogisticsFuelPrices(
        effectiveDate: DateTime.parse(row['effective_date'].toString()),
        diesel: double.tryParse(
          row['diesel_price_per_liter']?.toString() ?? '',
        ),
        gasoline: double.tryParse(
          row['gasoline_price_per_liter']?.toString() ?? '',
        ),
      );

  static LogisticsFuelPrices forDate(
    Iterable<LogisticsFuelPrices> history,
    DateTime date,
  ) {
    final day = DateTime(date.year, date.month, date.day);
    final entries = history.where((p) => !p.effectiveDate.isAfter(day)).toList()
      ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    double? diesel, gasoline;
    for (final entry in entries) {
      diesel ??= entry.diesel;
      gasoline ??= entry.gasoline;
      if (diesel != null && gasoline != null) break;
    }
    return LogisticsFuelPrices(
      effectiveDate: day,
      diesel: diesel,
      gasoline: gasoline,
    );
  }
}

class LogisticsFuelPriceStore {
  static Future<List<LogisticsFuelPrices>> loadEntries() async {
    final rows = await fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('logistics_fuel_prices')
          .select(
            'effective_date,diesel_price_per_liter,gasoline_price_per_liter',
          )
          .order('effective_date', ascending: false)
          .range(from, to),
    );
    return rows.map(LogisticsFuelPrices.fromRow).toList();
  }

  static Future<void> save(LogisticsFuelPrices prices) async {
    // Validate here as well as in the form and database; never round a bad input.
    for (final value in [prices.diesel, prices.gasoline]) {
      if (value != null) parseLogisticsFuelPrice(value.toString());
    }
    if (prices.diesel == null && prices.gasoline == null) {
      throw const FormatException('Captura al menos un precio de combustible.');
    }
    await Supabase.instance.client.rpc(
      'set_logistics_fuel_prices',
      params: {
        'p_effective_date': prices.effectiveDate.toIso8601String().substring(
          0,
          10,
        ),
        'p_diesel': prices.diesel,
        'p_gasoline': prices.gasoline,
      },
    );
  }
}
