import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../mayoreo/mayoreo_expected_collections.dart';

import '../../shared/utils/fetch_all_supabase_rows.dart';
import '../direction_shipments_store.dart';
import '../operating_program/operating_program_models.dart';
import 'expected_income_models.dart';
import 'palomar_materials.dart';

class ExpectedIncomeRepository {
  final SupabaseClient? _client;
  ExpectedIncomeRepository({SupabaseClient? client}) : _client = client;
  SupabaseClient get client => _client ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _all(String table, {String key = 'id'}) =>
      fetchAllSupabaseRows(
        (from, to) => client.from(table).select().order(key).range(from, to),
      );

  Future<ExpectedIncomeData> load(
    DirectionShipmentPlanningBundle bundle, {
    DateTime? now,
  }) async {
    final today = incomeDay(now ?? DateTime.now());
    final week = bundle.weekStartDate;
    final results = await Future.wait([
      _all('direction_income_material_rules', key: 'material_code'),
      _all('direction_income_client_rules', key: 'client_key'),
      _all('mayoreo_counterparties'),
      _all('mayoreo_counterparty_material_prices'),
      _all('mayoreo_material_catalog'),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('direction_income_client_prices')
            .select()
            .order('client_key')
            .order('material_code')
            .range(from, to),
      ),
      _all('direction_income_shipment_links', key: 'shipment_id'),
      _all('mayoreo_sales_reports'),
      _all('mayoreo_accounts'),
      _all('direction_income_palomar_config'),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('mayoreo_palomar_movements')
            .select()
            .lt('date', programDate(week.add(const Duration(days: 7))))
            .order('date')
            .order('id')
            .range(from, to),
      ),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('direction_income_palomar_adjustments')
            .select()
            .gte(
              'expected_date',
              programDate(today.isBefore(week) ? today : week),
            )
            .lt('expected_date', programDate(week.add(const Duration(days: 7))))
            .order('expected_date')
            .order('id')
            .range(from, to),
      ),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('direction_operating_programs')
            .select('*,lines:direction_operating_program_lines(*)')
            .eq('week_start', programDate(week))
            .order('version', ascending: false)
            .range(from, to),
      ),
      DirectionShipmentsStore.loadProgramProductionActuals(week),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('finanzas_bank_movements')
            .select('id,source_type,linked_external_ref,credit_amount')
            .eq('source_type', 'VENTA_FACTURA')
            .order('id')
            .range(from, to),
      ),
      bundle.shipments.isEmpty
          ? Future.value(<Map<String, dynamic>>[])
          : fetchAllSupabaseRows(
              (from, to) => client
                  .from('direction_income_allocations')
                  .select()
                  .inFilter(
                    'shipment_id',
                    bundle.shipments.map((s) => s.id).toList(),
                  )
                  .order('shipment_id')
                  .range(from, to),
            ),
      client
          .from('direction_income_palomar_schedule')
          .select()
          .eq('week_start', programDate(week)),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('direction_shipment_plans')
            .select()
            .lt('ship_date', programDate(week.add(const Duration(days: 7))))
            .order('ship_date')
            .order('id')
            .range(from, to),
      ),
    ]);
    return assembleExpectedIncomeData(
      bundle: bundle,
      today: today,
      tables: results,
    );
  }

  Future<void> saveMaterial(IncomeMaterialRule rule) async {
    if (!rule.kgPerBale.isFinite ||
        rule.kgPerBale <= 0 ||
        rule.kgPerBale > 10000 ||
        rule.price != null &&
            (!rule.price!.isFinite ||
                rule.price! < 0 ||
                rule.price! > 100000)) {
      throw ArgumentError('Peso o precio fuera de rango.');
    }
    await client.from('direction_income_material_rules').upsert(rule.toJson());
  }

  Future<void> saveAllocation(IncomeAllocation allocation) async {
    if (!allocation.valid) {
      throw ArgumentError('Distribución de ingreso inválida.');
    }
    await client.rpc(
      'direction_income_save_allocation',
      params: {
        'p_shipment_id': allocation.shipmentId,
        'p_source_key': allocation.sourceKey,
        'p_total_cents': allocation.totalCents,
        'p_cash_cents': allocation.cashCents,
        'p_fiscal_cents': allocation.fiscalCents,
        'p_expected_revision': allocation.revision,
      },
    );
  }

  Future<void> saveClient(
    IncomeClientRule rule,
    Map<String, double> prices,
  ) async {
    if (rule.key.isEmpty ||
        rule.term < 0 ||
        rule.term > 365 ||
        [
          if (rule.price != null) rule.price!,
          ...prices.values,
        ].any((v) => !v.isFinite || v < 0 || v > 100000)) {
      throw ArgumentError('Condiciones comerciales inválidas.');
    }
    await client.rpc(
      'direction_income_save_client',
      params: {'p_rule': rule.toJson(), 'p_prices': prices},
    );
  }

  Future<void> linkSale(String shipmentId, String? reportId) async {
    if (reportId == null) {
      await client
          .from('direction_income_shipment_links')
          .delete()
          .eq('shipment_id', shipmentId);
    } else {
      await client.from('direction_income_shipment_links').upsert({
        'shipment_id': shipmentId,
        'sale_report_id': reportId,
      });
    }
  }

  Future<void> savePalomarConfig(PalomarIncomeConfig config) async {
    if ([
      if (config.creditLimit != null) config.creditLimit!,
      if (config.drawAmount != null) config.drawAmount!,
      config.cashCheck1,
      config.cashCheck2,
    ].any((v) => !v.isFinite || v < 0)) {
      throw ArgumentError('Importes inválidos.');
    }
    await client
        .from('direction_income_palomar_config')
        .upsert(config.toJson());
  }

  Future<void> saveAdjustment(Map<String, dynamic> row) async =>
      await client.from('direction_income_palomar_adjustments').upsert(row);
  Future<void> deleteAdjustment(String id) async => await client
      .from('direction_income_palomar_adjustments')
      .delete()
      .eq('id', id);

  Future<void> savePalomarSchedule(PalomarReceiptSchedule schedule) async {
    if (!schedule.valid) {
      throw ArgumentError(
        'Las fechas deben pertenecer a la semana seleccionada.',
      );
    }
    await client.rpc(
      'direction_income_save_palomar_schedule',
      params: {
        'p_week': programDate(schedule.week),
        'p_cash_date': schedule.cashDate == null
            ? null
            : programDate(schedule.cashDate!),
        'p_fiscal_date': schedule.fiscalDate == null
            ? null
            : programDate(schedule.fiscalDate!),
        'p_expected_revision': schedule.revision,
      },
    );
  }
}

/// Pure adapter for source validation and deterministic integration tests.
ExpectedIncomeData assembleExpectedIncomeData({
  required DirectionShipmentPlanningBundle bundle,
  required DateTime today,
  required List<List<Map<String, dynamic>>> tables,
}) {
  final rules = tables[1].map(IncomeClientRule.fromJson).toList();
  final clients = tables[2];
  final warnings = <String>[];
  final bankCredits = <String, double>{};
  for (final row
      in tables.length > 14 ? tables[14] : <Map<String, dynamic>>[]) {
    final id = '${row['linked_external_ref'] ?? ''}'.trim();
    final credit = incomeNumber(row['credit_amount']) ?? 0;
    if (row['source_type'] != 'VENTA_FACTURA' ||
        id.isEmpty ||
        credit <= 0.009) {
      continue;
    }
    bankCredits.update(id, (v) => v + credit, ifAbsent: () => credit);
  }
  IncomeClientRule? ruleFor(String name) {
    final matches = rules.where((r) => r.matches(name)).toList();
    return matches.length == 1 ? matches.single : null;
  }

  final materialCodes = {
    for (final row in tables[4])
      row['id']:
          incomeMaterial('${row['code']}') ?? incomeMaterial('${row['name']}'),
  };
  final coverageCodes = {
    for (final row in tables[4]) row['id']: palomarCatalogCode(row),
  };
  final clientsById = {for (final row in clients) row['id']: row};
  final catalogPrices = <String, List<double>>{};
  for (final row in tables[3].where((r) => r['is_active'] == true)) {
    final company = clientsById[row['company_id']];
    final material = materialCodes[row['material_id']];
    if (company == null || material == null || company['is_active'] != true) {
      continue;
    }
    final rule =
        rules.where((r) => r.clientId == company['id']).firstOrNull ??
        ruleFor('${company['name']}');
    final key = '${rule?.key ?? incomeKey('${company['name']}')}|$material';
    catalogPrices
        .putIfAbsent(key, () => [])
        .add(incomeNumber(row['final_price'])!);
  }
  final prices = <String, double>{};
  for (final entry in catalogPrices.entries) {
    if (entry.value.toSet().length == 1) {
      prices[entry.key] = entry.value.first;
    } else {
      warnings.add(
        'Precios comerciales distintos para ${entry.key.replaceAll('|', ' · ')}; definir precio en Condiciones comerciales.',
      );
    }
  }
  for (final row in tables[5]) {
    prices['${row['client_key']}|${row['material_code']}'] = incomeNumber(
      row['price_per_kg'],
    )!;
  }
  final accounts = {for (final row in tables[8]) row['id']: row};
  final sales = <IncomeSale>[];
  for (final row in tables[7]) {
    final account = accounts[row['id']];
    final material =
        materialCodes[row['material_id']] ??
        coverageCodes[row['material_id']] ??
        palomarKnownMaterial('${row['material_name_snapshot']}');
    if (material == null) continue;
    // Null means not approved; zero is a valid explicit price. A report's
    // default zero approved_amount is not evidence of a free/collected sale.
    final weight = incomeNumber(row['approved_weight']);
    final price = incomeNumber(row['approved_price']);
    final amount = account?['approved_amount'] ?? row['approved_amount'];
    final approved = weight != null && price != null;
    final accountWeight = incomeNumber(account?['approved_weight']);
    final accountPrice = incomeNumber(account?['approved_price']);
    final realWeight = accountWeight != null && accountWeight > 0
        ? accountWeight
        : weight ?? incomeNumber(row['exit_weight']);
    final snapshotPrice = incomeNumber(row['price_snapshot']);
    final realPrice = accountWeight != null && accountWeight > 0
        ? accountPrice
        : price ??
              (snapshotPrice != null && snapshotPrice > 0
                  ? snapshotPrice
                  : null);
    sales.add(
      IncomeSale(
        id: row['id'] as String,
        client: '${row['client_name_snapshot']}',
        material: material,
        ticket: '${row['ticket']}',
        date: incomeDate(row['sale_date'])!,
        weight: realWeight != null && realWeight > 0 ? realWeight : null,
        price: realPrice,
        approvedCents:
            (approved || accountWeight != null && accountWeight > 0) &&
                amount != null &&
                ((incomeNumber(amount) ?? 0) > 0 || realPrice == 0)
            ? incomeCents(incomeNumber(amount)!)
            : null,
        paidCents: incomeCents(
          mayoreoEffectivePaid(
            accountId: row['id'] as String,
            amount: incomeNumber(amount) ?? 0,
            paid: incomeNumber(account?['paid_amount']) ?? 0,
            bankCredits: bankCredits,
          ),
        ),
        dueDate: incomeDate(account?['estimated_payment_date']),
        settledDate: incomeDate(account?['settlement_date']),
        accountStatus: account?['status'] as String?,
        paymentType: account?['operation_type'] == 'factura' ? 'FISCAL' : null,
      ),
    );
  }
  final ids = bundle.shipments.map((s) => s.id).toSet();
  final links = {
    for (final r in tables[6].where((r) => ids.contains(r['shipment_id'])))
      r['shipment_id'] as String: r['sale_report_id'] as String,
  };
  final external = {
    for (final r in tables[6].where((r) => !ids.contains(r['shipment_id'])))
      r['sale_report_id'] as String,
  };
  final versions = tables[12].map(OperatingProgram.fromJson).toList();
  final program =
      versions.where((p) => p.operational).firstOrNull ?? versions.firstOrNull;
  final supplies = <IncomeSupply>[];
  var source = 'Estimación histórica de producción';
  final demands = ProgramDemand.fromShipments(
    bundle.weekStartDate,
    bundle.shipments,
  );
  // Do not use a saved schedule when shipment edits invalidated its source.
  final programValid =
      program != null &&
      programDemandFingerprint(
            program.demands
                .where(
                  (d) =>
                      !bundle.shipments.any((s) => s.id == d.id && s.isShipped),
                )
                .toList(),
          ) ==
          programDemandFingerprint(demands);
  if (programValid) {
    source = 'Programa operativo v${program.version} · ${program.statusLabel}';
    final actual = <String, int>{};
    for (final row in tables[13]) {
      final key = '${row['date']}|${row['shift']}|${row['material']}';
      actual.update(
        key,
        (v) => v + (row['quantity'] as num).toInt(),
        ifAbsent: () => (row['quantity'] as num).toInt(),
      );
    }
    for (final line in program.lines) {
      final date = program.week.add(Duration(days: line.day));
      if (date.isBefore(today)) continue;
      final observed =
          actual['${programDate(date)}|${programShifts[line.shift]}|${line.material}'] ??
          0;
      supplies.add(
        IncomeSupply(
          date.add(Duration(days: line.shift == 1 ? 1 : 0)),
          line.material,
          math.max(0, line.quantity - observed),
        ),
      );
    }
  } else {
    if (program != null) {
      warnings.add(
        'Los embarques cambiaron: regenerar el Programa operativo. Se usa la estimación histórica.',
      );
    }
    final report = bundle.suggestionReport;
    for (final entry
        in report?.productionForecast.entries ??
            <MapEntry<DateTime, Map<String, int>>>[]) {
      if (entry.key.isBefore(today)) continue;
      for (final material in programMaterials) {
        final total = entry.value[material] ?? 0;
        final day = report?.dayProductionForecast[entry.key]?[material] ?? 0;
        supplies.add(IncomeSupply(entry.key, material, day));
        supplies.add(
          IncomeSupply(
            entry.key.add(const Duration(days: 1)),
            material,
            math.max(0, total - day),
          ),
        );
      }
    }
    if (report == null) {
      warnings.add(
        'Sin programa ni referencia de producción; disponibilidad calculada solo con inventario.',
      );
    }
  }
  return ExpectedIncomeData(
    allocations: {
      if (tables.length > 15)
        for (final row in tables[15])
          row['shipment_id'] as String: IncomeAllocation.fromJson(row),
    },
    collections: mayoreoExpectedCollections(tables[8], bankCredits),
    materials: tables[0].map(IncomeMaterialRule.fromJson).toList(),
    clients: rules,
    catalogClients: clients,
    clientMaterialPrices: prices,
    priceOverrides: {
      for (final row in tables[5])
        '${row['client_key']}|${row['material_code']}': incomeNumber(
          row['price_per_kg'],
        )!,
    },
    sales: sales,
    links: links,
    externallyLinkedSales: external,
    supplies: supplies,
    productionSource: source,
    warnings: warnings,
    palomarConfig: tables[9].isEmpty
        ? const PalomarIncomeConfig()
        : PalomarIncomeConfig.fromJson(tables[9].single),
    palomarSchedule: tables.length > 16 && tables[16].isNotEmpty
        ? PalomarReceiptSchedule.fromJson(tables[16].single)
        : null,
    palomarCoverageShipments: tables.length > 17
        ? tables[17].map(DirectionShipmentPlanRecord.fromRow).toList()
        : bundle.shipments,
    palomarCoverageLinks: {
      for (final row in tables[6])
        row['shipment_id'] as String: row['sale_report_id'] as String,
    },
    palomarCoverageMaterials: palomarCatalogQuotes(
      materials: tables[4],
      prices: tables[3],
      clients: clients,
      rule: ruleFor('EL PALOMAR'),
    ),
    palomarMovements: [
      ...tables[10].map(PalomarIncomeMovement.fromLedger),
      for (final row in tables[11])
        PalomarIncomeMovement(
          id: row['id'] as String,
          date: incomeDate(row['expected_date'])!,
          signedCents:
              (row['effect'] as num).toInt() *
              incomeCents(incomeNumber(row['amount'])!),
          concept: '${row['concept']} · ${row['notes'] ?? ''}',
          projected: true,
        ),
    ],
  );
}
