import 'dart:convert';

import '../direction_shipments_store.dart';
import '../operating_program/operating_program_models.dart';
import '../../mayoreo/mayoreo_expected_collections.dart';

DateTime incomeDay(DateTime date) => DateTime(date.year, date.month, date.day);
DateTime? incomeDate(Object? value) =>
    value == null ? null : incomeDay(DateTime.parse('$value'));
double? incomeNumber(Object? value) =>
    value == null ? null : (value as num).toDouble();
int incomeCents(double value) => (value * 100).round();

String incomeKey(String name) {
  var result = name.trim().toUpperCase();
  const accents = {'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U'};
  for (final entry in accents.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result.replaceAll(RegExp(r'\s+'), ' ');
}

String? incomeMaterial(String value) =>
    switch (incomeKey(value).replaceAll('_', ' ')) {
      'PACA NACIONAL' ||
      'CARTON NACIONAL' ||
      'CARTON NACIONAL EN PACAS' => 'PACA_NACIONAL',
      'PACA LIMPIA' || 'CARTON LIMPIO' => 'PACA_LIMPIA',
      'PACA AMERICANA' || 'CARTON AMERICANO' => 'PACA_AMERICANA',
      _ => null,
    };

enum IncomeState {
  projected('Proyectado'),
  ready('Listo para embarcar'),
  shipped('Embarcado'),
  receivable('Por cobrar'),
  collected('Cobrado'),
  cancelled('Cancelado');

  final String label;
  const IncomeState(this.label);
}

class IncomeMaterialRule {
  final String material;
  final double kgPerBale;
  final double? price;
  const IncomeMaterialRule(this.material, this.kgPerBale, this.price);
  factory IncomeMaterialRule.fromJson(Map<String, dynamic> row) =>
      IncomeMaterialRule(
        row['material_code'] as String,
        incomeNumber(row['kg_per_bale'])!,
        incomeNumber(row['price_per_kg']),
      );
  Map<String, dynamic> toJson() => {
    'material_code': material,
    'kg_per_bale': kgPerBale,
    'price_per_kg': price,
  };
}

class IncomeClientRule {
  final String key, name, paymentType, termUnit, specialRules;
  final String? clientId, usualMaterial;
  final List<String> aliases;
  final int term;
  final double? price;
  final bool active, revolving;
  const IncomeClientRule({
    required this.key,
    required this.name,
    required this.paymentType,
    this.clientId,
    this.termUnit = 'DIAS',
    this.term = 0,
    this.price,
    this.usualMaterial,
    this.specialRules = '',
    this.active = true,
    this.revolving = false,
    this.aliases = const [],
  });
  int get days =>
      termUnit == 'INMEDIATO' ? 0 : term * (termUnit == 'SEMANAS' ? 7 : 1);
  bool matches(String name) =>
      incomeKey(name) == key ||
      aliases.map(incomeKey).contains(incomeKey(name));
  factory IncomeClientRule.fromJson(Map<String, dynamic> row) =>
      IncomeClientRule(
        key: row['client_key'] as String,
        name: row['client_name'] as String,
        clientId: row['client_id'] as String?,
        paymentType: row['payment_type'] as String,
        termUnit: row['term_unit'] as String,
        term: (row['term_value'] as num).toInt(),
        price: incomeNumber(row['default_price_per_kg']),
        usualMaterial: row['usual_material'] as String?,
        specialRules: row['special_rules'] as String? ?? '',
        active: row['is_active'] as bool,
        revolving: row['is_revolving'] as bool,
        aliases: List<String>.from(row['aliases'] as List? ?? []),
      );
  Map<String, dynamic> toJson() => {
    'client_key': key,
    'client_name': name,
    'client_id': clientId,
    'payment_type': paymentType,
    'term_unit': termUnit,
    'term_value': term,
    'default_price_per_kg': price,
    'usual_material': usualMaterial,
    'special_rules': specialRules,
    'is_active': active,
    'is_revolving': revolving,
    'aliases': aliases,
  };
}

class IncomeSale {
  final String id, client, material, ticket;
  final DateTime date;
  final double? weight, price;
  final int? approvedCents;
  final int paidCents;
  final DateTime? dueDate, settledDate;
  final String? accountStatus;
  final String? paymentType;
  const IncomeSale({
    required this.id,
    required this.client,
    required this.material,
    required this.ticket,
    required this.date,
    this.weight,
    this.price,
    this.approvedCents,
    this.paidCents = 0,
    this.dueDate,
    this.settledDate,
    this.accountStatus,
    this.paymentType,
  });
  bool get cancelled => accountStatus == 'cancelada';
  bool get settled =>
      accountStatus == 'pagada' || accountStatus == 'chequeCanjeado';
}

class IncomeSupply {
  final DateTime availableDate;
  final String material;
  final int bales;
  const IncomeSupply(this.availableDate, this.material, this.bales);
}

class PalomarIncomeConfig {
  final double? creditLimit, drawAmount;
  final double cashCheck1, cashCheck2;
  final int shipmentEffect;
  final bool requireCovered;
  const PalomarIncomeConfig({
    this.creditLimit,
    this.drawAmount,
    this.cashCheck1 = 0,
    this.cashCheck2 = 0,
    this.shipmentEffect = -1,
    this.requireCovered = true,
  });
  factory PalomarIncomeConfig.fromJson(Map<String, dynamic> row) =>
      PalomarIncomeConfig(
        creditLimit: incomeNumber(row['credit_limit']),
        drawAmount: incomeNumber(row['draw_amount']),
        cashCheck1: incomeNumber(row['cash_check_1'])!,
        cashCheck2: incomeNumber(row['cash_check_2'])!,
        shipmentEffect: (row['shipment_effect'] as num).toInt(),
        requireCovered: row['require_covered'] as bool,
      );
  Map<String, dynamic> toJson() => {
    'id': true,
    'credit_limit': creditLimit,
    'draw_amount': drawAmount,
    'cash_check_1': cashCheck1,
    'cash_check_2': cashCheck2,
    'shipment_effect': shipmentEffect,
    'require_covered': requireCovered,
  };
}

class PalomarReceiptSchedule {
  final DateTime week;
  final DateTime? cashDate, fiscalDate;
  final int revision;
  const PalomarReceiptSchedule({
    required this.week,
    this.cashDate,
    this.fiscalDate,
    this.revision = 0,
  });
  bool get valid =>
      week.weekday == DateTime.monday &&
      revision >= 0 &&
      [cashDate, fiscalDate].every(
        (date) =>
            date == null ||
            (!incomeDay(date).isBefore(incomeDay(week)) &&
                incomeDay(
                  date,
                ).isBefore(incomeDay(week).add(const Duration(days: 7)))),
      );
  factory PalomarReceiptSchedule.fromJson(Map<String, dynamic> row) =>
      PalomarReceiptSchedule(
        week: DateTime.parse(row['week_start'] as String),
        cashDate: row['cash_date'] == null
            ? null
            : DateTime.parse(row['cash_date'] as String),
        fiscalDate: row['fiscal_date'] == null
            ? null
            : DateTime.parse(row['fiscal_date'] as String),
        revision: (row['revision'] as num).toInt(),
      );
}

class PalomarIncomeMovement {
  final String id, concept;
  final String? reportId;
  final DateTime date;
  final int signedCents;
  final bool projected;
  const PalomarIncomeMovement({
    required this.id,
    required this.date,
    required this.signedCents,
    required this.concept,
    this.reportId,
    this.projected = false,
  });
  factory PalomarIncomeMovement.fromLedger(Map<String, dynamic> row) {
    final sign = switch (row['type']) {
      'chequeLiberado' || 'ajusteCargo' => 1,
      'remisionAplicada' || 'ajusteAbono' => -1,
      'corteInterno' => 0,
      _ => throw FormatException(
        'Movimiento de El Palomar desconocido: ${row['type']}',
      ),
    };
    return PalomarIncomeMovement(
      id: row['id'] as String,
      date: incomeDate(row['date'])!,
      signedCents: sign * incomeCents(incomeNumber(row['amount'])!),
      concept: '${row['type']} · ${row['material_name_snapshot'] ?? ''}',
      reportId: row['source_report_id'] as String?,
    );
  }
}

/// A commercial material quoted in its catalog unit. Bale conversions are
/// supplied separately by the existing weight rules, never guessed from names.
class PalomarMaterialQuote {
  final String code, label, unit;
  final double? price;
  const PalomarMaterialQuote(this.code, this.label, this.unit, this.price);
  bool get usable =>
      unit.isNotEmpty && price != null && price!.isFinite && price! > 0;
  int? amount(int quantity) =>
      unit.isEmpty || price == null || !price!.isFinite || price! < 0
      ? null
      : incomeCents(quantity * price!);
  int? quantityFor(int cents) {
    if (!usable) return null;
    var quantity = (cents / (price! * 100)).ceil();
    while (quantity > 0 && amount(quantity - 1)! >= cents) {
      quantity--;
    }
    while (amount(quantity)! < cents) {
      quantity++;
    }
    return quantity;
  }
}

/// A distribution of the outstanding forecast, never a posted collection.
class IncomeAllocation {
  final String shipmentId, sourceKey;
  final int totalCents, cashCents, fiscalCents, revision;
  const IncomeAllocation({
    required this.shipmentId,
    required this.sourceKey,
    required this.totalCents,
    required this.cashCents,
    required this.fiscalCents,
    this.revision = 0,
  });
  factory IncomeAllocation.fromJson(Map<String, dynamic> row) =>
      IncomeAllocation(
        shipmentId: row['shipment_id'] as String,
        sourceKey: row['source_key'] as String,
        totalCents: (row['total_cents'] as num).toInt(),
        cashCents: (row['cash_cents'] as num).toInt(),
        fiscalCents: (row['fiscal_cents'] as num).toInt(),
        revision: (row['revision'] as num).toInt(),
      );
  bool get valid =>
      totalCents > 0 &&
      totalCents <= 100000000000000 &&
      cashCents >= 0 &&
      fiscalCents >= 0 &&
      cashCents + fiscalCents == totalCents &&
      revision >= 0 &&
      shipmentId.isNotEmpty &&
      sourceKey.isNotEmpty &&
      sourceKey.length <= 4000;
}

class ExpectedIncomeData {
  final Map<String, IncomeAllocation> allocations;
  final List<MayoreoExpectedCollection> collections;
  final List<IncomeMaterialRule> materials;
  final List<IncomeClientRule> clients;
  final List<Map<String, dynamic>> catalogClients;
  final Map<String, double> clientMaterialPrices;
  final Map<String, double> priceOverrides;
  final List<IncomeSale> sales;
  final Map<String, String> links;
  final Set<String> externallyLinkedSales;
  final List<IncomeSupply> supplies;
  final String productionSource;
  final List<String> warnings;
  final PalomarIncomeConfig palomarConfig;
  final PalomarReceiptSchedule? palomarSchedule;
  final List<PalomarIncomeMovement> palomarMovements;
  final List<DirectionShipmentPlanRecord> palomarCoverageShipments;
  final Map<String, String> palomarCoverageLinks;
  final List<PalomarMaterialQuote> palomarCoverageMaterials;
  const ExpectedIncomeData({
    this.allocations = const {},
    this.collections = const [],
    this.materials = const [],
    this.clients = const [],
    this.catalogClients = const [],
    this.clientMaterialPrices = const {},
    this.priceOverrides = const {},
    this.sales = const [],
    this.links = const {},
    this.externallyLinkedSales = const {},
    this.supplies = const [],
    this.productionSource = '',
    this.warnings = const [],
    this.palomarConfig = const PalomarIncomeConfig(),
    this.palomarSchedule,
    this.palomarMovements = const [],
    this.palomarCoverageShipments = const [],
    this.palomarCoverageLinks = const {},
    this.palomarCoverageMaterials = const [],
  });
  IncomeClientRule? ruleFor(String name) {
    final matches = clients.where((c) => c.matches(name)).toList();
    return matches.length == 1 ? matches.single : null;
  }

  String clientIdentity(String name) => ruleFor(name)?.key ?? incomeKey(name);
  bool saleMatches(DirectionShipmentPlanRecord shipment, IncomeSale sale) =>
      clientIdentity(shipment.clientName) == clientIdentity(sale.client) &&
      shipment.materialCode == sale.material;
}

class ExpectedIncomeRow {
  final IncomeAllocation? allocation;
  final bool cashExcluded;
  final DirectionShipmentPlanRecord shipment;
  final IncomeState state;
  final String? paymentType;
  final double? kilograms, price;
  final int? valueCents;
  final int paidCents;
  final DateTime? collectionDate;
  final IncomeSale? sale;
  final bool revolving;
  final int missingBales, stockBales;
  final List<String> risks;
  const ExpectedIncomeRow({
    this.allocation,
    this.cashExcluded = false,
    required this.shipment,
    required this.state,
    required this.paymentType,
    required this.kilograms,
    required this.price,
    required this.valueCents,
    required this.paidCents,
    required this.collectionDate,
    required this.sale,
    required this.revolving,
    required this.missingBales,
    required this.stockBales,
    required this.risks,
  });
  int get pendingCents =>
      state == IncomeState.cancelled || state == IncomeState.collected
      ? 0
      : ((valueCents ?? 0) - paidCents).clamp(0, 1 << 62);
  bool get ordinary =>
      !revolving && !cashExcluded && state != IncomeState.cancelled;
  bool get canAllocate =>
      ordinary && paymentType == 'MIXTO' && pendingCents > 0;
  // Amount or sale changes require a new decision. Date/status changes alone
  // keep the split while the same outstanding income moves to its new bucket.
  String get allocationSourceKey => jsonEncode([
    shipment.id,
    incomeKey(shipment.clientName),
    shipment.materialCode,
    sale?.id,
    valueCents,
    paidCents,
    paymentType,
  ]);
  bool get allocationApplied =>
      canAllocate &&
      allocation != null &&
      allocation!.valid &&
      allocation!.shipmentId == shipment.id &&
      allocation!.sourceKey == allocationSourceKey &&
      allocation!.totalCents == pendingCents;
  bool get allocationStale =>
      canAllocate && allocation != null && !allocationApplied;
  Map<String, int> get pendingByType => allocationApplied
      ? {'EFECTIVO': allocation!.cashCents, 'FISCAL': allocation!.fiscalCents}
      : {paymentType ?? 'SIN CLASIFICAR': pendingCents};

  IncomeAllocation distribute({
    required int cashCents,
    required int fiscalCents,
  }) {
    final result = IncomeAllocation(
      shipmentId: shipment.id,
      sourceKey: allocationSourceKey,
      totalCents: pendingCents,
      cashCents: cashCents,
      fiscalCents: fiscalCents,
      revision: allocation?.revision ?? 0,
    );
    if (!canAllocate || !result.valid) {
      throw ArgumentError(
        'Efectivo y Fiscal deben sumar exactamente el importe por distribuir.',
      );
    }
    return result;
  }
}

class IncomeTotals {
  final Map<String, int> byType = {'EFECTIVO': 0, 'FISCAL': 0, 'MIXTO': 0};
  final Map<String, int> financingByType = {};
  int get total => byType.values.fold(0, (a, b) => a + b);
  int get financingTotal => financingByType.values.fold(0, (a, b) => a + b);
  int get salesTotal => total - financingTotal;
  void add(String type, int cents) =>
      byType[type] = (byType[type] ?? 0) + cents;
  void addFinancing(String type, int cents) {
    add(type, cents);
    financingByType[type] = (financingByType[type] ?? 0) + cents;
  }
}

class PalomarIncomeProjection {
  final DateTime? cashDate, fiscalDate;
  final int opening,
      charges,
      credits,
      plannedShipments,
      closing,
      availableDraw,
      cash,
      fiscal;
  final bool configured, complete;
  const PalomarIncomeProjection({
    this.cashDate,
    this.fiscalDate,
    required this.opening,
    required this.charges,
    required this.credits,
    required this.plannedShipments,
    required this.closing,
    required this.availableDraw,
    required this.cash,
    required this.fiscal,
    required this.configured,
    required this.complete,
  });
  int get toCover => closing.clamp(0, 1 << 62);
  DateTime? dateFor(String type) => type == 'EFECTIVO' ? cashDate : fiscalDate;
  int get undatedDraw =>
      (cashDate == null ? cash : 0) + (fiscalDate == null ? fiscal : 0);
}

class ExpectedIncomeProjection {
  final List<MayoreoExpectedCollection> collections;
  final List<ExpectedIncomeRow> rows;
  final IncomeTotals current, next, later, overdue, undated;
  final Map<DateTime, IncomeTotals> timeline;
  final PalomarIncomeProjection palomar;
  final List<String> warnings;
  const ExpectedIncomeProjection({
    this.collections = const [],
    required this.rows,
    required this.current,
    required this.next,
    required this.later,
    required this.overdue,
    required this.undated,
    required this.timeline,
    required this.palomar,
    required this.warnings,
  });
  int get generated => rows
      .where((r) => r.state != IncomeState.cancelled)
      .fold(0, (s, r) => s + (r.valueCents ?? 0));
  int get projected => rows
      .where(
        (r) =>
            r.ordinary &&
            (r.state == IncomeState.projected || r.state == IncomeState.ready),
      )
      .fold(0, (s, r) => s + r.pendingCents);
  int get committed =>
      collections.fold(0, (s, c) => s + c.pendingCents) +
      rows
          .where(
            (r) =>
                r.ordinary &&
                (r.state == IncomeState.shipped ||
                    r.state == IncomeState.receivable),
          )
          .fold(0, (s, r) => s + r.pendingCents);
  int get collected =>
      rows.where((r) => r.ordinary).fold(0, (s, r) => s + r.paidCents);
  Map<String, int> groupBy(String Function(ExpectedIncomeRow) key) {
    final result = <String, int>{};
    for (final row in rows.where((r) => r.ordinary)) {
      result.update(
        key(row),
        (v) => v + row.pendingCents,
        ifAbsent: () => row.pendingCents,
      );
    }
    return result;
  }

  Map<String, int> get byClient {
    final result = groupBy((r) => r.shipment.clientName);
    for (final c in collections) {
      result.update(
        c.client,
        (v) => v + c.pendingCents,
        ifAbsent: () => c.pendingCents,
      );
    }
    if (palomar.availableDraw > 0) {
      result['El Palomar · disposición'] = palomar.availableDraw;
    }
    return result;
  }

  Map<String, int> get byMaterial {
    final result = groupBy((r) => incomeMaterialName(r.shipment.materialCode));
    for (final c in collections) {
      final material = incomeMaterial(c.material);
      final label = material == null
          ? c.material
          : incomeMaterialName(material);
      result.update(
        label,
        (v) => v + c.pendingCents,
        ifAbsent: () => c.pendingCents,
      );
    }
    return result;
  }
}

String incomeMaterialName(String code) {
  final index = programMaterials.indexOf(code);
  return index < 0 ? code : programMaterialNames[index];
}
