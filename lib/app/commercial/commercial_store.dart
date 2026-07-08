import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/utils/number_formatters.dart';

const String _kCommercialAccountsTable = 'commercial_accounts';
const String _kCommercialContactsTable = 'commercial_account_contacts';
const String _kCommercialFollowUpsTable = 'commercial_follow_ups';
const String _kCommercialUnifiedCounterpartiesView =
    'v_commercial_unified_counterparties';
const String _kCommercialMaterialSnapshotView =
    'v_commercial_material_market_snapshot';
const String _kCommercialMaterialGeneralSnapshotView =
    'v_commercial_material_general_snapshot';
const String _kCommercialCounterpartyActivityView =
    'v_commercial_counterparty_activity_snapshot';
const String _kCommercialCounterpartyGeneralActivityView =
    'v_commercial_counterparty_general_activity_snapshot';
const String _kCommercialAlertsView = 'v_commercial_variation_alerts';
const String _kCommercialMarketEventsView = 'v_commercial_market_events';
const String _kInventoryGeneralBalanceView = 'v_inventory_general_balance_v2';
const String _kMenEffectivePricesView = 'vw_men_effective_prices';
const String _kComprasPriceAuditCatalogView = 'vw_compras_price_audit_catalog';
const String _kMayoreoPriceAuditCatalogView = 'vw_mayoreo_price_audit_catalog';

const List<String> kCommercialAccountStatusOptions = <String>[
  'activo',
  'prospecto',
  'dormido',
  'cerrado',
];

const List<String> kCommercialPriorityOptions = <String>[
  'baja',
  'media',
  'alta',
  'estrategica',
];

const List<String> kCommercialKindOptions = <String>[
  'supplier',
  'customer',
  'both',
  'prospect',
];

const List<String> kCommercialChannelOptions = <String>['menudeo', 'mayoreo'];

const List<String> kCommercialBusinessTypeOptions = <String>[
  'empresa_generadora',
  'proveedor_directo',
  'proveedor_grande',
  'cliente_final',
  'prospect',
];

const List<String> kCommercialBusinessGroupOptions = <String>[
  'menudeo_empresa',
  'menudeo_triciclo',
  'menudeo_preferencial',
  'menudeo_proveedor_directo',
  'menudeo_cliente',
  'mayoreo_proveedor',
  'mayoreo_cliente',
  'manual_prospect',
];

const List<String> kCommercialInteractionTypeOptions = <String>[
  'llamada',
  'whatsapp',
  'visita',
  'correo',
  'cotizacion',
  'seguimiento',
];

const List<String> kCommercialFollowUpStatusOptions = <String>[
  'abierto',
  'hecho',
  'pospuesto',
  'sin_respuesta',
];

class CommercialKpiSummary {
  final double buyVolume30d;
  final double sellVolume30d;
  final double buyAmount30d;
  final double sellAmount30d;
  final int materialsActive30d;
  final int counterpartiesActive30d;

  const CommercialKpiSummary({
    required this.buyVolume30d,
    required this.sellVolume30d,
    required this.buyAmount30d,
    required this.sellAmount30d,
    required this.materialsActive30d,
    required this.counterpartiesActive30d,
  });

  const CommercialKpiSummary.empty()
    : buyVolume30d = 0,
      sellVolume30d = 0,
      buyAmount30d = 0,
      sellAmount30d = 0,
      materialsActive30d = 0,
      counterpartiesActive30d = 0;
}

class CommercialAlertRecord {
  final String alertType;
  final String severity;
  final String entityLabel;
  final String channel;
  final String flow;
  final String businessGroup;
  final String materialLabel;
  final double? deltaPercent;
  final String message;
  final String suggestedAction;

  const CommercialAlertRecord({
    required this.alertType,
    required this.severity,
    required this.entityLabel,
    required this.channel,
    required this.flow,
    required this.businessGroup,
    required this.materialLabel,
    required this.deltaPercent,
    required this.message,
    required this.suggestedAction,
  });

  factory CommercialAlertRecord.fromRow(Map<String, dynamic> row) {
    return CommercialAlertRecord(
      alertType: (row['alert_type'] ?? '').toString(),
      severity: (row['severity'] ?? '').toString(),
      entityLabel: (row['entity_label'] ?? '').toString(),
      channel: (row['channel'] ?? '').toString(),
      flow: (row['flow'] ?? '').toString(),
      businessGroup: (row['counterparty_business_group'] ?? '').toString(),
      materialLabel: (row['material_label'] ?? '').toString(),
      deltaPercent: (row['delta_percent'] as num?)?.toDouble(),
      message: (row['message'] ?? '').toString(),
      suggestedAction: (row['suggested_action'] ?? '').toString(),
    );
  }
}

class CommercialMaterialSnapshotRecord {
  final String channel;
  final String businessGroup;
  final String materialKey;
  final String materialLabel;
  final double buyVolume30d;
  final double sellVolume30d;
  final double buyAmount30d;
  final double sellAmount30d;
  final double? avgBuyPrice30d;
  final double? avgSellPrice30d;

  const CommercialMaterialSnapshotRecord({
    required this.channel,
    required this.businessGroup,
    required this.materialKey,
    required this.materialLabel,
    required this.buyVolume30d,
    required this.sellVolume30d,
    required this.buyAmount30d,
    required this.sellAmount30d,
    required this.avgBuyPrice30d,
    required this.avgSellPrice30d,
  });

  double get totalVolume30d => buyVolume30d + sellVolume30d;

  factory CommercialMaterialSnapshotRecord.fromRow(Map<String, dynamic> row) {
    return CommercialMaterialSnapshotRecord(
      channel: (row['channel'] ?? '').toString(),
      businessGroup: (row['counterparty_business_group'] ?? '').toString(),
      materialKey: (row['material_key'] ?? '').toString(),
      materialLabel: (row['material_label'] ?? '').toString(),
      buyVolume30d: ((row['buy_volume_30d'] as num?) ?? 0).toDouble(),
      sellVolume30d: ((row['sell_volume_30d'] as num?) ?? 0).toDouble(),
      buyAmount30d: ((row['buy_amount_30d'] as num?) ?? 0).toDouble(),
      sellAmount30d: ((row['sell_amount_30d'] as num?) ?? 0).toDouble(),
      avgBuyPrice30d: (row['avg_buy_price_30d'] as num?)?.toDouble(),
      avgSellPrice30d: (row['avg_sell_price_30d'] as num?)?.toDouble(),
    );
  }
}

class CommercialCounterpartyActivityRecord {
  final String sourceArea;
  final String sourceRecordId;
  final String name;
  final String kind;
  final String channel;
  final String flow;
  final String businessType;
  final String businessGroup;
  final String materialLabel;
  final double volume30d;
  final double amount30d;
  final DateTime? lastActivityAt;
  final double? avgDaysBetweenOperations;

  const CommercialCounterpartyActivityRecord({
    required this.sourceArea,
    required this.sourceRecordId,
    required this.name,
    required this.kind,
    required this.channel,
    required this.flow,
    required this.businessType,
    required this.businessGroup,
    required this.materialLabel,
    required this.volume30d,
    required this.amount30d,
    required this.lastActivityAt,
    required this.avgDaysBetweenOperations,
  });

  factory CommercialCounterpartyActivityRecord.fromRow(
    Map<String, dynamic> row,
  ) {
    return CommercialCounterpartyActivityRecord(
      sourceArea: (row['source_area'] ?? '').toString(),
      sourceRecordId: (row['source_record_id'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      kind: (row['kind'] ?? '').toString(),
      channel: (row['channel'] ?? '').toString(),
      flow: (row['flow'] ?? '').toString(),
      businessType: (row['counterparty_business_type'] ?? '').toString(),
      businessGroup: (row['counterparty_business_group'] ?? '').toString(),
      materialLabel: (row['material_label'] ?? '').toString(),
      volume30d: ((row['volume_30d'] as num?) ?? 0).toDouble(),
      amount30d: ((row['amount_30d'] as num?) ?? 0).toDouble(),
      lastActivityAt: _tryParseDateTime(row['last_activity_at'] as String?),
      avgDaysBetweenOperations: (row['avg_days_between_operations'] as num?)
          ?.toDouble(),
    );
  }
}

class CommercialDirectoryAccountRecord {
  final String id;
  final String displayName;
  final String sourceArea;
  final String sourceRecordId;
  final String channel;
  final String flow;
  final String kind;
  final String businessType;
  final String businessGroup;
  final bool active;
  final String status;
  final String priority;
  final String notes;
  final String contact;
  final int contactCount;
  final int followUpCount;
  final DateTime? nextFollowUpAt;
  final int activeAlertCount;
  final String highestAlertSeverity;

  const CommercialDirectoryAccountRecord({
    required this.id,
    required this.displayName,
    required this.sourceArea,
    required this.sourceRecordId,
    required this.channel,
    required this.flow,
    required this.kind,
    required this.businessType,
    required this.businessGroup,
    required this.active,
    required this.status,
    required this.priority,
    required this.notes,
    required this.contact,
    required this.contactCount,
    required this.followUpCount,
    required this.nextFollowUpAt,
    required this.activeAlertCount,
    required this.highestAlertSeverity,
  });
}

class CommercialContactRecord {
  final String id;
  final String accountId;
  final String name;
  final String role;
  final String phone;
  final String email;
  final bool isPrimary;

  const CommercialContactRecord({
    required this.id,
    required this.accountId,
    required this.name,
    required this.role,
    required this.phone,
    required this.email,
    required this.isPrimary,
  });

  factory CommercialContactRecord.fromRow(Map<String, dynamic> row) {
    return CommercialContactRecord(
      id: (row['id'] ?? '').toString(),
      accountId: (row['account_id'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      role: (row['role'] ?? '').toString(),
      phone: (row['phone'] ?? '').toString(),
      email: (row['email'] ?? '').toString(),
      isPrimary: row['is_primary'] as bool? ?? false,
    );
  }
}

class CommercialFollowUpRecord {
  final String id;
  final String accountId;
  final DateTime? interactionAt;
  final String interactionType;
  final String summary;
  final String nextAction;
  final DateTime? nextFollowUpAt;
  final String status;

  const CommercialFollowUpRecord({
    required this.id,
    required this.accountId,
    required this.interactionAt,
    required this.interactionType,
    required this.summary,
    required this.nextAction,
    required this.nextFollowUpAt,
    required this.status,
  });

  factory CommercialFollowUpRecord.fromRow(Map<String, dynamic> row) {
    return CommercialFollowUpRecord(
      id: (row['id'] ?? '').toString(),
      accountId: (row['account_id'] ?? '').toString(),
      interactionAt: _tryParseDateTime(row['interaction_at'] as String?),
      interactionType: (row['interaction_type'] ?? '').toString(),
      summary: (row['summary'] ?? '').toString(),
      nextAction: (row['next_action'] ?? '').toString(),
      nextFollowUpAt: _tryParseDateTime(row['next_follow_up_at'] as String?),
      status: (row['status'] ?? '').toString(),
    );
  }
}

class CommercialDashboardBundle {
  final CommercialKpiSummary kpis;
  final List<CommercialMarketEventRecord> marketEvents;
  final List<CommercialAlertRecord> alerts;
  final List<CommercialMaterialSnapshotRecord> materialRows;
  final List<CommercialCounterpartyActivityRecord> counterpartyRows;
  final List<CommercialGeneralMaterialSnapshotRecord> generalMaterialRows;
  final List<CommercialGeneralCounterpartyActivityRecord>
  generalCounterpartyRows;
  final List<CommercialCatalogPriceReferenceRecord> catalogPriceRows;
  final List<CommercialInventoryGeneralBalanceRecord> inventoryGeneralRows;

  const CommercialDashboardBundle({
    required this.kpis,
    required this.marketEvents,
    required this.alerts,
    required this.materialRows,
    required this.counterpartyRows,
    required this.generalMaterialRows,
    required this.generalCounterpartyRows,
    required this.catalogPriceRows,
    required this.inventoryGeneralRows,
  });
}

class CommercialMarketEventRecord {
  final String sourceArea;
  final String sourceEventId;
  final DateTime? eventAt;
  final String channel;
  final String flow;
  final String generalMaterialKey;
  final String generalMaterialLabel;
  final double volumeKg;
  final double amountTotal;
  final double unitPrice;

  const CommercialMarketEventRecord({
    required this.sourceArea,
    required this.sourceEventId,
    required this.eventAt,
    required this.channel,
    required this.flow,
    required this.generalMaterialKey,
    required this.generalMaterialLabel,
    required this.volumeKg,
    required this.amountTotal,
    required this.unitPrice,
  });

  factory CommercialMarketEventRecord.fromRow(Map<String, dynamic> row) {
    return CommercialMarketEventRecord(
      sourceArea: (row['source_area'] ?? '').toString(),
      sourceEventId: (row['source_event_id'] ?? '').toString(),
      eventAt: _tryParseDateTime(row['event_at'] as String?),
      channel: (row['channel'] ?? '').toString(),
      flow: (row['flow'] ?? '').toString(),
      generalMaterialKey: (row['general_material_key'] ?? '').toString(),
      generalMaterialLabel: (row['general_material_label'] ?? '').toString(),
      volumeKg: ((row['volume_kg'] as num?) ?? 0).toDouble(),
      amountTotal: ((row['amount_total'] as num?) ?? 0).toDouble(),
      unitPrice: ((row['unit_price'] as num?) ?? 0).toDouble(),
    );
  }
}

class CommercialCatalogPriceReferenceRecord {
  final String counterpartyName;
  final String channel;
  final String flow;
  final String generalMaterialKey;
  final String generalMaterialLabel;
  final String materialLabel;
  final String segmentLabel;
  final double finalPrice;
  final DateTime? updatedAt;

  const CommercialCatalogPriceReferenceRecord({
    required this.counterpartyName,
    required this.channel,
    required this.flow,
    required this.generalMaterialKey,
    required this.generalMaterialLabel,
    required this.materialLabel,
    required this.segmentLabel,
    required this.finalPrice,
    required this.updatedAt,
  });
}

class CommercialGeneralMaterialSnapshotRecord {
  final String channel;
  final String businessGroup;
  final String businessType;
  final String generalMaterialKey;
  final String generalMaterialLabel;
  final double buyVolume30d;
  final double sellVolume30d;
  final double buyAmount30d;
  final double sellAmount30d;

  const CommercialGeneralMaterialSnapshotRecord({
    required this.channel,
    required this.businessGroup,
    required this.businessType,
    required this.generalMaterialKey,
    required this.generalMaterialLabel,
    required this.buyVolume30d,
    required this.sellVolume30d,
    required this.buyAmount30d,
    required this.sellAmount30d,
  });

  double get totalVolume30d => buyVolume30d + sellVolume30d;
  double? get avgBuyPrice30d =>
      buyVolume30d > 0 ? buyAmount30d / buyVolume30d : null;
  double? get avgSellPrice30d =>
      sellVolume30d > 0 ? sellAmount30d / sellVolume30d : null;

  factory CommercialGeneralMaterialSnapshotRecord.fromRow(
    Map<String, dynamic> row,
  ) {
    return CommercialGeneralMaterialSnapshotRecord(
      channel: (row['channel'] ?? '').toString(),
      businessGroup: (row['counterparty_business_group'] ?? '').toString(),
      businessType: (row['counterparty_business_type'] ?? '').toString(),
      generalMaterialKey: (row['general_material_key'] ?? '').toString(),
      generalMaterialLabel: (row['general_material_label'] ?? '').toString(),
      buyVolume30d: ((row['buy_volume_30d'] as num?) ?? 0).toDouble(),
      sellVolume30d: ((row['sell_volume_30d'] as num?) ?? 0).toDouble(),
      buyAmount30d: ((row['buy_amount_30d'] as num?) ?? 0).toDouble(),
      sellAmount30d: ((row['sell_amount_30d'] as num?) ?? 0).toDouble(),
    );
  }
}

class CommercialGeneralCounterpartyActivityRecord {
  final String sourceArea;
  final String sourceRecordId;
  final String name;
  final String kind;
  final String channel;
  final String flow;
  final String businessType;
  final String businessGroup;
  final String generalMaterialKey;
  final String generalMaterialLabel;
  final double volume30d;
  final double amount30d;
  final DateTime? lastActivityAt;

  const CommercialGeneralCounterpartyActivityRecord({
    required this.sourceArea,
    required this.sourceRecordId,
    required this.name,
    required this.kind,
    required this.channel,
    required this.flow,
    required this.businessType,
    required this.businessGroup,
    required this.generalMaterialKey,
    required this.generalMaterialLabel,
    required this.volume30d,
    required this.amount30d,
    required this.lastActivityAt,
  });

  factory CommercialGeneralCounterpartyActivityRecord.fromRow(
    Map<String, dynamic> row,
  ) {
    return CommercialGeneralCounterpartyActivityRecord(
      sourceArea: (row['source_area'] ?? '').toString(),
      sourceRecordId: (row['source_record_id'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      kind: (row['kind'] ?? '').toString(),
      channel: (row['channel'] ?? '').toString(),
      flow: (row['flow'] ?? '').toString(),
      businessType: (row['counterparty_business_type'] ?? '').toString(),
      businessGroup: (row['counterparty_business_group'] ?? '').toString(),
      generalMaterialKey: (row['general_material_key'] ?? '').toString(),
      generalMaterialLabel: (row['general_material_label'] ?? '').toString(),
      volume30d: ((row['volume_30d'] as num?) ?? 0).toDouble(),
      amount30d: ((row['amount_30d'] as num?) ?? 0).toDouble(),
      lastActivityAt: _tryParseDateTime(row['last_activity_at'] as String?),
    );
  }

  double? get avgPrice30d => volume30d > 0 ? amount30d / volume30d : null;
}

class CommercialInventoryGeneralBalanceRecord {
  final String id;
  final String code;
  final String name;
  final double openingKg;
  final double movementKg;
  final double onHandKg;
  final int openingUnits;
  final int movementUnits;
  final int onHandUnits;

  const CommercialInventoryGeneralBalanceRecord({
    required this.id,
    required this.code,
    required this.name,
    required this.openingKg,
    required this.movementKg,
    required this.onHandKg,
    required this.openingUnits,
    required this.movementUnits,
    required this.onHandUnits,
  });

  factory CommercialInventoryGeneralBalanceRecord.fromRow(
    Map<String, dynamic> row,
  ) {
    return CommercialInventoryGeneralBalanceRecord(
      id: (row['id'] ?? '').toString(),
      code: (row['code'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      openingKg: ((row['opening_kg'] as num?) ?? 0).toDouble(),
      movementKg: ((row['movement_kg'] as num?) ?? 0).toDouble(),
      onHandKg: ((row['on_hand_kg'] as num?) ?? 0).toDouble(),
      openingUnits: ((row['opening_units'] as num?) ?? 0).toInt(),
      movementUnits: ((row['movement_units'] as num?) ?? 0).toInt(),
      onHandUnits: ((row['on_hand_units'] as num?) ?? 0).toInt(),
    );
  }
}

class CommercialDirectoryBundle {
  final List<CommercialDirectoryAccountRecord> accounts;
  final Map<String, List<CommercialContactRecord>> contactsByAccountId;
  final Map<String, List<CommercialFollowUpRecord>> followUpsByAccountId;
  final Map<String, List<CommercialAlertRecord>> alertsByAccountId;

  const CommercialDirectoryBundle({
    required this.accounts,
    required this.contactsByAccountId,
    required this.followUpsByAccountId,
    required this.alertsByAccountId,
  });
}

class CommercialStore {
  static final SupabaseClient _supa = Supabase.instance.client;

  static Future<CommercialDashboardBundle> loadDashboard() async {
    final results = await Future.wait<dynamic>([
      _selectAllRows(_kCommercialMarketEventsView, orderColumn: 'event_at'),
      _supa.from(_kCommercialAlertsView).select(),
      _supa.from(_kCommercialMaterialSnapshotView).select(),
      _supa.from(_kCommercialCounterpartyActivityView).select(),
      _supa.from(_kCommercialMaterialGeneralSnapshotView).select(),
      _supa.from(_kCommercialCounterpartyGeneralActivityView).select(),
      _supa.from(_kInventoryGeneralBalanceView).select(),
      _supa.from(_kMenEffectivePricesView).select(),
      _supa.from(_kComprasPriceAuditCatalogView).select(),
      _supa.from(_kMayoreoPriceAuditCatalogView).select(),
    ]);

    final events = _rows(results[0]);
    final marketEvents = events
        .map(CommercialMarketEventRecord.fromRow)
        .toList(growable: false);
    final alerts = _rows(
      results[1],
    ).map(CommercialAlertRecord.fromRow).toList(growable: false);
    final materials =
        _rows(results[2])
            .map(CommercialMaterialSnapshotRecord.fromRow)
            .toList(growable: false)
          ..sort((a, b) => b.totalVolume30d.compareTo(a.totalVolume30d));
    final counterparties =
        _rows(results[3])
            .map(CommercialCounterpartyActivityRecord.fromRow)
            .toList(growable: false)
          ..sort((a, b) => b.amount30d.compareTo(a.amount30d));
    final generalMaterials =
        _rows(results[4])
            .map(CommercialGeneralMaterialSnapshotRecord.fromRow)
            .toList(growable: false)
          ..sort((a, b) => b.totalVolume30d.compareTo(a.totalVolume30d));
    final generalCounterparties =
        _rows(results[5])
            .map(CommercialGeneralCounterpartyActivityRecord.fromRow)
            .toList(growable: false)
          ..sort((a, b) => b.amount30d.compareTo(a.amount30d));
    final inventoryGeneralRows =
        _rows(results[6])
            .map(CommercialInventoryGeneralBalanceRecord.fromRow)
            .toList(growable: false)
          ..sort((a, b) => b.onHandKg.compareTo(a.onHandKg));
    final catalogPriceRows =
        <CommercialCatalogPriceReferenceRecord>[
          ..._buildMenCatalogPriceRows(_rows(results[7])),
          ..._buildComprasCatalogPriceRows(_rows(results[8])),
          ..._buildMayoreoCatalogPriceRows(_rows(results[9])),
        ]..sort((a, b) {
          final left = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });

    final materialKeys = <String>{};
    final counterpartiesSet = <String>{};
    double buyVolume = 0;
    double sellVolume = 0;
    double buyAmount = 0;
    double sellAmount = 0;
    final cutoff = DateTime.now().subtract(const Duration(days: 30));

    for (final row in events) {
      final eventAt = _tryParseDateTime(row['event_at'] as String?);
      if (eventAt == null || eventAt.isBefore(cutoff)) continue;
      final flow = (row['flow'] ?? '').toString();
      final volume = ((row['volume_kg'] as num?) ?? 0).toDouble();
      final amount = ((row['amount_total'] as num?) ?? 0).toDouble();
      materialKeys.add((row['material_key'] ?? '').toString());
      counterpartiesSet.add(
        '${(row['source_area'] ?? '').toString()}|${(row['source_record_id'] ?? '').toString()}',
      );
      if (flow == 'purchase') {
        buyVolume += volume;
        buyAmount += amount;
      } else {
        sellVolume += volume;
        sellAmount += amount;
      }
    }

    return CommercialDashboardBundle(
      kpis: CommercialKpiSummary(
        buyVolume30d: buyVolume,
        sellVolume30d: sellVolume,
        buyAmount30d: buyAmount,
        sellAmount30d: sellAmount,
        materialsActive30d: materialKeys
            .where((value) => value.isNotEmpty)
            .length,
        counterpartiesActive30d: counterpartiesSet
            .where((value) => !value.endsWith('|'))
            .length,
      ),
      marketEvents: marketEvents,
      alerts: alerts,
      materialRows: materials,
      counterpartyRows: counterparties,
      generalMaterialRows: generalMaterials,
      generalCounterpartyRows: generalCounterparties,
      catalogPriceRows: catalogPriceRows,
      inventoryGeneralRows: inventoryGeneralRows,
    );
  }

  static Future<List<Map<String, dynamic>>> _selectAllRows(
    String tableOrView, {
    String? orderColumn,
    bool ascending = false,
    int pageSize = 1000,
  }) async {
    final rows = <Map<String, dynamic>>[];
    var from = 0;

    while (true) {
      dynamic query = _supa.from(tableOrView).select();
      if (orderColumn != null && orderColumn.trim().isNotEmpty) {
        query = query.order(orderColumn, ascending: ascending);
      }
      final page = _rows(await query.range(from, from + pageSize - 1));
      rows.addAll(page);
      if (page.length < pageSize) break;
      from += pageSize;
    }

    return rows;
  }

  static Future<CommercialDirectoryBundle> loadDirectory() async {
    final results = await Future.wait<dynamic>([
      _supa.from(_kCommercialUnifiedCounterpartiesView).select(),
      _supa.from(_kCommercialAccountsTable).select(),
      _supa.from(_kCommercialContactsTable).select(),
      _supa
          .from(_kCommercialFollowUpsTable)
          .select()
          .order('interaction_at', ascending: false),
      _supa.from(_kCommercialAlertsView).select(),
    ]);
    final sourceRows = _rows(results[0]);
    final accountRows = _rows(results[1]);
    final contactRows = _rows(results[2]);
    final followUpRows = _rows(results[3]);
    final alertRows = _rows(results[4]);

    final accountsBySource = <String, Map<String, dynamic>>{};
    final manualAccounts = <Map<String, dynamic>>[];
    for (final row in accountRows) {
      final sourceArea = (row['source_area'] ?? '').toString();
      final sourceRecordId = (row['source_record_id'] ?? '').toString();
      if (sourceArea.isNotEmpty && sourceRecordId.isNotEmpty) {
        accountsBySource['$sourceArea|$sourceRecordId'] = row;
      } else {
        manualAccounts.add(row);
      }
    }

    final contacts = contactRows
        .map(CommercialContactRecord.fromRow)
        .toList(growable: false);
    final followUps = followUpRows
        .map(CommercialFollowUpRecord.fromRow)
        .toList(growable: false);
    final contactsByAccountId = <String, List<CommercialContactRecord>>{};
    final followUpsByAccountId = <String, List<CommercialFollowUpRecord>>{};

    for (final row in contacts) {
      contactsByAccountId
          .putIfAbsent(row.accountId, () => <CommercialContactRecord>[])
          .add(row);
    }
    for (final row in followUps) {
      followUpsByAccountId
          .putIfAbsent(row.accountId, () => <CommercialFollowUpRecord>[])
          .add(row);
    }

    final alertCountBySource = <String, int>{};
    final highestAlertSeverityBySource = <String, String>{};
    final alertsBySource = <String, List<CommercialAlertRecord>>{};
    for (final row in alertRows) {
      final sourceKey = _sourceKeyFromAlertRow(row);
      if (sourceKey == null) continue;
      final sourceArea = sourceKey.$1;
      final sourceRecordId = sourceKey.$2;
      if (sourceArea.isEmpty || sourceRecordId.isEmpty) continue;
      final key = '$sourceArea|$sourceRecordId';
      final severity = (row['severity'] ?? '').toString();
      final alert = CommercialAlertRecord.fromRow(row);
      alertCountBySource[key] = (alertCountBySource[key] ?? 0) + 1;
      alertsBySource
          .putIfAbsent(key, () => <CommercialAlertRecord>[])
          .add(alert);
      final current = highestAlertSeverityBySource[key];
      if (current == null ||
          _alertSeverityRank(severity) > _alertSeverityRank(current)) {
        highestAlertSeverityBySource[key] = severity;
      }
    }

    final accounts = <CommercialDirectoryAccountRecord>[];
    final alertsByAccountId = <String, List<CommercialAlertRecord>>{};
    for (final row in sourceRows) {
      final sourceArea = (row['source_area'] ?? '').toString();
      final sourceRecordId = (row['source_record_id'] ?? '').toString();
      final overlay = accountsBySource['$sourceArea|$sourceRecordId'];
      final accountId = (overlay?['id'] ?? '$sourceArea|$sourceRecordId')
          .toString();
      final accountContacts = contactsByAccountId[accountId] ?? const [];
      final accountFollowUps = followUpsByAccountId[accountId] ?? const [];
      final nextFollowUp = accountFollowUps
          .where(
            (entry) => entry.nextFollowUpAt != null && entry.status != 'hecho',
          )
          .map((entry) => entry.nextFollowUpAt!)
          .fold<DateTime?>(null, (current, value) {
            if (current == null) return value;
            return value.isBefore(current) ? value : current;
          });

      accounts.add(
        CommercialDirectoryAccountRecord(
          id: accountId,
          displayName: (overlay?['display_name'] ?? row['name'] ?? '')
              .toString(),
          sourceArea: sourceArea,
          sourceRecordId: sourceRecordId,
          channel: (row['channel'] ?? '').toString(),
          flow: (row['flow'] ?? '').toString(),
          kind: (overlay?['kind'] ?? row['kind'] ?? '').toString(),
          businessType:
              (overlay?['counterparty_business_type'] ??
                      row['counterparty_business_type'] ??
                      '')
                  .toString(),
          businessGroup:
              (overlay?['counterparty_business_group'] ??
                      row['counterparty_business_group'] ??
                      '')
                  .toString(),
          active:
              (overlay?['is_active'] as bool?) ??
              (row['active'] as bool? ?? true),
          status: (overlay?['status'] ?? 'activo').toString(),
          priority: (overlay?['priority'] ?? 'media').toString(),
          notes: (overlay?['notes'] ?? row['notes'] ?? '').toString(),
          contact: accountContacts.isNotEmpty
              ? accountContacts.first.name
              : (row['contact'] ?? '').toString(),
          contactCount: accountContacts.length,
          followUpCount: accountFollowUps.length,
          nextFollowUpAt: nextFollowUp,
          activeAlertCount:
              alertCountBySource['$sourceArea|$sourceRecordId'] ?? 0,
          highestAlertSeverity:
              highestAlertSeverityBySource['$sourceArea|$sourceRecordId'] ?? '',
        ),
      );
      final sourceKey = '$sourceArea|$sourceRecordId';
      final accountAlerts =
          List<CommercialAlertRecord>.from(
            alertsBySource[sourceKey] ?? const <CommercialAlertRecord>[],
          )..sort((a, b) {
            final severityCompare = _alertSeverityRank(
              b.severity,
            ).compareTo(_alertSeverityRank(a.severity));
            if (severityCompare != 0) return severityCompare;
            final deltaA = a.deltaPercent?.abs() ?? 0;
            final deltaB = b.deltaPercent?.abs() ?? 0;
            return deltaB.compareTo(deltaA);
          });
      alertsByAccountId[accountId] = accountAlerts;
    }

    for (final row in manualAccounts) {
      final accountId = (row['id'] ?? '').toString();
      final accountContacts = contactsByAccountId[accountId] ?? const [];
      final accountFollowUps = followUpsByAccountId[accountId] ?? const [];
      final nextFollowUp = accountFollowUps
          .where(
            (entry) => entry.nextFollowUpAt != null && entry.status != 'hecho',
          )
          .map((entry) => entry.nextFollowUpAt!)
          .fold<DateTime?>(null, (current, value) {
            if (current == null) return value;
            return value.isBefore(current) ? value : current;
          });
      accounts.add(
        CommercialDirectoryAccountRecord(
          id: accountId,
          displayName: (row['display_name'] ?? '').toString(),
          sourceArea: (row['source_area'] ?? 'manual').toString(),
          sourceRecordId: (row['source_record_id'] ?? '').toString(),
          channel: (row['primary_channel'] ?? '').toString(),
          flow: (row['kind'] == 'customer') ? 'sale' : 'purchase',
          kind: (row['kind'] ?? '').toString(),
          businessType: (row['counterparty_business_type'] ?? '').toString(),
          businessGroup: (row['counterparty_business_group'] ?? '').toString(),
          active: row['is_active'] as bool? ?? true,
          status: (row['status'] ?? 'prospecto').toString(),
          priority: (row['priority'] ?? 'media').toString(),
          notes: (row['notes'] ?? '').toString(),
          contact: accountContacts.isNotEmpty ? accountContacts.first.name : '',
          contactCount: accountContacts.length,
          followUpCount: accountFollowUps.length,
          nextFollowUpAt: nextFollowUp,
          activeAlertCount: 0,
          highestAlertSeverity: '',
        ),
      );
    }

    accounts.sort((a, b) {
      final alertCompare = b.activeAlertCount.compareTo(a.activeAlertCount);
      if (alertCompare != 0) return alertCompare;
      final priorityCompare = _priorityRank(
        b.priority,
      ).compareTo(_priorityRank(a.priority));
      if (priorityCompare != 0) return priorityCompare;
      return a.displayName.toUpperCase().compareTo(b.displayName.toUpperCase());
    });

    return CommercialDirectoryBundle(
      accounts: accounts,
      contactsByAccountId: contactsByAccountId,
      followUpsByAccountId: followUpsByAccountId,
      alertsByAccountId: alertsByAccountId,
    );
  }

  static Future<String> saveManualAccount({
    String? accountId,
    required String displayName,
    required String kind,
    required String primaryChannel,
    required String businessType,
    required String businessGroup,
    required String status,
    required String priority,
    required String notes,
    bool isActive = true,
  }) async {
    final payload = <String, dynamic>{
      if (accountId != null && accountId.trim().isNotEmpty) 'id': accountId,
      'display_name': displayName.trim(),
      'kind': kind,
      'counterparty_business_type': businessType,
      'counterparty_business_group': businessGroup,
      'source_area': null,
      'source_record_id': null,
      'primary_channel': primaryChannel,
      'status': status,
      'priority': priority,
      'notes': _nullableText(notes),
      'is_active': isActive,
    };
    final response = await _supa
        .from(_kCommercialAccountsTable)
        .upsert(<Map<String, dynamic>>[payload])
        .select('id')
        .single();
    return (response['id'] ?? '').toString();
  }

  static Future<String> saveAccountOverlay({
    required CommercialDirectoryAccountRecord row,
    required String status,
    required String priority,
    required String notes,
  }) async {
    if (row.sourceArea == 'manual') {
      return saveManualAccount(
        accountId: row.id,
        displayName: row.displayName,
        kind: row.kind,
        primaryChannel: row.channel,
        businessType: row.businessType,
        businessGroup: row.businessGroup,
        status: status,
        priority: priority,
        notes: notes,
        isActive: row.active,
      );
    }
    final existingId = await _findAccountIdBySource(
      sourceArea: row.sourceArea,
      sourceRecordId: row.sourceRecordId,
    );
    final payload = <String, dynamic>{
      ...?existingId == null ? null : <String, dynamic>{'id': existingId},
      'display_name': row.displayName.trim(),
      'kind': row.kind,
      'counterparty_business_type': row.businessType,
      'counterparty_business_group': row.businessGroup,
      'source_area': row.sourceArea,
      'source_record_id': row.sourceRecordId,
      'primary_channel': row.channel,
      'status': status,
      'priority': priority,
      'notes': _nullableText(notes),
      'is_active': row.active,
    };
    final response = await _supa
        .from(_kCommercialAccountsTable)
        .upsert(<Map<String, dynamic>>[payload])
        .select('id')
        .single();
    return (response['id'] ?? '').toString();
  }

  static Future<void> saveContact({
    String? contactId,
    required String accountId,
    required String name,
    required String role,
    required String phone,
    required String email,
    required String preferredChannel,
    String notes = '',
    bool isPrimary = false,
    bool isActive = true,
  }) async {
    if (isPrimary) {
      await _supa
          .from(_kCommercialContactsTable)
          .update(<String, dynamic>{'is_primary': false})
          .eq('account_id', accountId);
    }
    final payload = <String, dynamic>{
      if (contactId != null && contactId.trim().isNotEmpty) 'id': contactId,
      'account_id': accountId,
      'name': name.trim(),
      'role': _nullableText(role),
      'phone': _nullableText(phone),
      'email': _nullableText(email),
      'preferred_channel': _nullableText(preferredChannel),
      'notes': _nullableText(notes),
      'is_primary': isPrimary,
      'is_active': isActive,
    };
    await _supa.from(_kCommercialContactsTable).upsert(<Map<String, dynamic>>[
      payload,
    ]);
  }

  static Future<void> saveFollowUp({
    String? followUpId,
    required String accountId,
    String? contactId,
    required DateTime interactionAt,
    required String interactionType,
    required String summary,
    required String nextAction,
    DateTime? nextFollowUpAt,
    required String status,
  }) async {
    final payload = <String, dynamic>{
      if (followUpId != null && followUpId.trim().isNotEmpty) 'id': followUpId,
      'account_id': accountId,
      'contact_id': _nullableText(contactId),
      'interaction_at': interactionAt.toIso8601String(),
      'interaction_type': interactionType,
      'summary': summary.trim(),
      'next_action': _nullableText(nextAction),
      'next_follow_up_at': nextFollowUpAt?.toIso8601String(),
      'status': status,
    };
    await _supa.from(_kCommercialFollowUpsTable).upsert(<Map<String, dynamic>>[
      payload,
    ]);
  }

  static Future<String?> _findAccountIdBySource({
    required String sourceArea,
    required String sourceRecordId,
  }) async {
    if (sourceArea.trim().isEmpty || sourceRecordId.trim().isEmpty) return null;
    final row = await _supa
        .from(_kCommercialAccountsTable)
        .select('id')
        .eq('source_area', sourceArea)
        .eq('source_record_id', sourceRecordId)
        .maybeSingle();
    if (row == null) return null;
    return (row['id'] ?? '').toString();
  }

  static int _priorityRank(String value) {
    switch (value) {
      case 'estrategica':
        return 4;
      case 'alta':
        return 3;
      case 'media':
        return 2;
      default:
        return 1;
    }
  }

  static int _alertSeverityRank(String value) {
    switch (value) {
      case 'critica':
        return 3;
      case 'atencion':
        return 2;
      default:
        return 1;
    }
  }

  static List<Map<String, dynamic>> _rows(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }
}

String? _nullableText(String? value) {
  if (value == null) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String commercialPriorityLabel(String value) {
  switch (value) {
    case 'estrategica':
      return 'Estrategica';
    case 'alta':
      return 'Alta';
    case 'media':
      return 'Media';
    default:
      return 'Baja';
  }
}

String commercialKindLabel(String value) {
  switch (value) {
    case 'customer':
      return 'Cliente';
    case 'both':
      return 'Mixto';
    case 'prospect':
      return 'Prospecto';
    default:
      return 'Proveedor';
  }
}

String commercialFlowLabel(String value) {
  return value == 'sale' ? 'Venta' : 'Compra';
}

String commercialKilos(double value) =>
    '${formatDecimal(value, decimals: 2)} kg';

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}

(String, String)? _sourceKeyFromAlertRow(Map<String, dynamic> row) {
  final directArea = (row['source_area'] ?? '').toString().trim();
  final directId = (row['source_record_id'] ?? '').toString().trim();
  if (directArea.isNotEmpty && directId.isNotEmpty) {
    return (directArea, directId);
  }
  final entityId = (row['entity_id'] ?? '').toString().trim();
  if (entityId.isEmpty || !entityId.contains(':')) return null;
  final separator = entityId.indexOf(':');
  final sourceArea = entityId.substring(0, separator).trim();
  final sourceRecordId = entityId.substring(separator + 1).trim();
  if (sourceArea.isEmpty || sourceRecordId.isEmpty) return null;
  return (sourceArea, sourceRecordId);
}

List<CommercialCatalogPriceReferenceRecord> _buildMenCatalogPriceRows(
  List<Map<String, dynamic>> rows,
) {
  return rows
      .map((row) {
        final generalMaterialLabel =
            (row['general_material_name'] ??
                    row['material_label_snapshot'] ??
                    '')
                .toString()
                .trim();
        final price = ((row['final_price'] as num?) ?? 0).toDouble();
        if (generalMaterialLabel.isEmpty || price <= 0) return null;
        return CommercialCatalogPriceReferenceRecord(
          counterpartyName: (row['counterparty_name'] ?? '').toString(),
          channel: 'menudeo',
          flow: (row['direction'] ?? 'purchase').toString(),
          generalMaterialKey:
              (row['general_material_code'] ?? generalMaterialLabel)
                  .toString()
                  .trim(),
          generalMaterialLabel: generalMaterialLabel,
          materialLabel:
              (row['material_label_snapshot'] ?? generalMaterialLabel)
                  .toString(),
          segmentLabel: (row['group_code'] ?? 'menudeo').toString(),
          finalPrice: price,
          updatedAt: _tryParseDateTime(row['updated_at'] as String?),
        );
      })
      .whereType<CommercialCatalogPriceReferenceRecord>()
      .toList(growable: false);
}

List<CommercialCatalogPriceReferenceRecord> _buildComprasCatalogPriceRows(
  List<Map<String, dynamic>> rows,
) {
  return rows
      .map((row) {
        final generalMaterialLabel =
            (row['general_material_name'] ?? row['material_name'] ?? '')
                .toString()
                .trim();
        final materialLabel = (row['material_name'] ?? generalMaterialLabel)
            .toString()
            .trim();
        final price = ((row['final_price'] as num?) ?? 0).toDouble();
        if (generalMaterialLabel.isEmpty || price <= 0) return null;
        return CommercialCatalogPriceReferenceRecord(
          counterpartyName: (row['company_name'] ?? '').toString(),
          channel: 'mayoreo',
          flow: 'purchase',
          generalMaterialKey: generalMaterialLabel.toUpperCase(),
          generalMaterialLabel: generalMaterialLabel,
          materialLabel: materialLabel,
          segmentLabel: 'mayoreo_proveedor',
          finalPrice: price,
          updatedAt: _tryParseDateTime(row['updated_at'] as String?),
        );
      })
      .whereType<CommercialCatalogPriceReferenceRecord>()
      .toList(growable: false);
}

List<CommercialCatalogPriceReferenceRecord> _buildMayoreoCatalogPriceRows(
  List<Map<String, dynamic>> rows,
) {
  return rows
      .map((row) {
        final generalMaterialLabel =
            (row['general_material_name'] ?? row['material_name'] ?? '')
                .toString()
                .trim();
        final materialLabel = (row['material_name'] ?? generalMaterialLabel)
            .toString()
            .trim();
        final price = ((row['final_price'] as num?) ?? 0).toDouble();
        if (generalMaterialLabel.isEmpty || price <= 0) return null;
        return CommercialCatalogPriceReferenceRecord(
          counterpartyName: (row['company_name'] ?? '').toString(),
          channel: 'mayoreo',
          flow: 'sale',
          generalMaterialKey: generalMaterialLabel.toUpperCase(),
          generalMaterialLabel: generalMaterialLabel,
          materialLabel: materialLabel,
          segmentLabel: 'mayoreo_cliente',
          finalPrice: price,
          updatedAt: _tryParseDateTime(row['updated_at'] as String?),
        );
      })
      .whereType<CommercialCatalogPriceReferenceRecord>()
      .toList(growable: false);
}
