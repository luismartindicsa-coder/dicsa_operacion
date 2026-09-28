import 'profitability_models.dart';

/// Coverage belongs to consumption, independently of the selected view.
/// Explicit document dates win; otherwise only an explicit monthly concept
/// accrues over a calendar month. No tax/payment frequency is guessed.
ProfitPeriod profitCostCoverage(DateTime date, String description) {
  final text = profitKey(description)
      .replaceAllMapped(RegExp(r'(\d)([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAllMapped(RegExp(r'([A-Z])(\d)'), (m) => '${m[1]} ${m[2]}');
  final dates = RegExp(
    r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b',
  ).allMatches(text).toList();
  DateTime? valid(int year, int month, int day) {
    final value = DateTime(year, month, day);
    return value.year == year && value.month == month && value.day == day
        ? value
        : null;
  }

  if (dates.length >= 2) {
    DateTime? parse(RegExpMatch m) =>
        valid(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    final from = parse(dates[0]), to = parse(dates[1]);
    if (from != null &&
        to != null &&
        !to.isBefore(from) &&
        to.difference(from).inDays < 366) {
      return ProfitPeriod(from, to);
    }
  }
  const months = [
    'ENERO',
    'FEBRERO',
    'MARZO',
    'ABRIL',
    'MAYO',
    'JUNIO',
    'JULIO',
    'AGOSTO',
    'SEPTIEMBRE',
    'OCTUBRE',
    'NOVIEMBRE',
    'DICIEMBRE',
  ];
  int? month(String raw) {
    final i = months.indexWhere((m) => m.startsWith(raw));
    return i < 0 ? null : i + 1;
  }

  final named = RegExp(
    r'\b(\d{1,2})\s+(ENE(?:RO)?|FEB(?:RERO)?|MAR(?:ZO)?|ABR(?:IL)?|MAY(?:O)?|JUN(?:IO)?|JUL(?:IO)?|AGO(?:STO)?|SEP(?:TIEMBRE)?|OCT(?:UBRE)?|NOV(?:IEMBRE)?|DIC(?:IEMBRE)?)\b',
  ).allMatches(text).toList();
  final explicitYear = RegExp(r'\b(20\d{2})\b').firstMatch(text);
  var year = explicitYear == null ? date.year : int.parse(explicitYear[1]!);
  if (named.length >= 2) {
    final firstMonth = month(named[0][2]!)!, lastMonth = month(named[1][2]!)!;
    if (explicitYear == null && lastMonth > date.month) year--;
    final from = valid(
      year - (firstMonth > lastMonth ? 1 : 0),
      firstMonth,
      int.parse(named[0][1]!),
    );
    final to = valid(year, lastMonth, int.parse(named[1][1]!));
    if (from != null && to != null && !to.isBefore(from)) {
      return ProfitPeriod(from, to);
    }
  }
  // Also accept "01–10 SEPTIEMBRE 2026".
  final shortRange = RegExp(
    r'\b(\d{1,2})\s*[-–]\s*(\d{1,2})\s+([A-Z]+)',
  ).firstMatch(text);
  if (shortRange != null) {
    final m = month(shortRange[3]!);
    if (m != null) {
      final from = valid(year, m, int.parse(shortRange[1]!)),
          to = valid(year, m, int.parse(shortRange[2]!));
      if (from != null && to != null && !to.isBefore(from)) {
        return ProfitPeriod(from, to);
      }
    }
  }
  if (RegExp(
    r'IMSS|IMPUEST|RENTA|ARRENDAMIENTO|MENSUAL|HONORARIOS|CONTABLE',
  ).hasMatch(text)) {
    final m = months.indexWhere((m) => RegExp('\\b$m\\b').hasMatch(text));
    if (m >= 0 || text.contains('MENSUAL')) {
      final calendarMonth = m >= 0 ? m + 1 : date.month;
      if (explicitYear == null && calendarMonth > date.month) year--;
      return ProfitPeriod(
        DateTime(year, calendarMonth),
        DateTime(year, calendarMonth + 1, 0),
      );
    }
  }
  return ProfitPeriod(date, date);
}

/// Source metadata used by all views and by history. Keep legal center,
/// consumption dates and recurrence key separate from customer identity.
class ProfitCostBasis {
  final ProfitSources sources;
  late final banks = {
    for (final r in sources.rows('finanzas_bank_movements'))
      'bank:${r['id']}': r,
  };
  late final invoices = {
    for (final r in sources.rows('finanzas_supplier_invoices'))
      profitText(r['id']): r,
  };
  late final orders = {
    for (final r in sources.rows('maintenance_orders')) 'ot:${r['id']}': r,
  };
  late final purchases = {
    for (final r in sources.rows('maintenance_purchase_orders'))
      'po:${r['id']}': r,
  };
  ProfitCostBasis(this.sources);
  ProfitRow? invoice(String key) => key.startsWith('invoice:')
      ? invoices[key.substring(8)]
      : invoices[profitText(banks[key]?['linked_supplier_invoice_id'])];
  String description(String key, [String label = '']) {
    final i = invoice(key), b = banks[key];
    return profitKey(
      '$label ${profitText(b?['category'])} ${profitText(b?['comment'])} ${profitText(i?['notes'])} ${profitText(i?['provider_name_snapshot'])}',
    );
  }

  String center(String key) {
    final b = banks[key], i = invoice(key);
    return '${profitKey(b?['company'] ?? i?['target_company'])}|${profitKey(b?['branch'] ?? i?['target_branch'])}';
  }

  ProfitPeriod coverage(String key, DateTime date, [String label = '']) {
    final i = invoice(key);
    return profitCostCoverage(
      profitDate(i?['invoice_date']) ?? date,
      description(key, label),
    );
  }

  String recurrence(ProfitCostFact f, String block) {
    final b = banks[f.key], i = invoice(f.key);
    var party = profitKey(
      i?['provider_name_snapshot'] ?? b?['counterparty_name_snapshot'],
    );
    // Voucher folios and document numbers are intentionally not recurrence IDs.
    if (party.startsWith('IMSS')) party = 'IMSS';
    // A repair's supplier/folio is not a separate operating cost pool.
    // Keep vehicle, yard, company and legal center boundaries intact.
    if (block == 'maintenance') {
      final unit = equipment(f.key).isNotEmpty ? equipment(f.key) : f.vehicleId;
      final scope = yardEquipment(f.key, description(f.key, f.label))
          ? 'yard:$unit'
          : 'transport:$unit';
      return '$block|${center(f.key)}|$scope|${f.entityKey}';
    }
    // A provider's accounting category can change from ADMINISTRATIVOS to
    // AJUSTES; that must not create another IMSS recurrence alongside this one.
    final concept = party.isNotEmpty
        ? block
        : b != null
        ? profitKey(b['category'])
        : profitKey(f.label.split('·').skip(1).join(' '));
    return '$block|${center(f.key)}|$party|$concept|${f.entityKey}|${f.vehicleId}';
  }

  String equipment(String key) => profitText(orders[key]?['equipment_id']);
  bool yardEquipment(String key, String label) => RegExp(
    r'COMPACT|MONTACARG|BASCULA|PRENSA|TRITUR',
  ).hasMatch(profitKey(label));
  bool inventoryPurchase(String key) =>
      purchases[key] != null &&
      profitKey(purchases[key]?['target_label']) == 'ALMACEN' &&
      profitText(purchases[key]?['linked_ot_id']).isEmpty;
}
