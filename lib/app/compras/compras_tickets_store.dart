import 'package:supabase_flutter/supabase_flutter.dart';

import '../mayoreo/mayoreo_sorting.dart';
import 'compras_data_store.dart';

const String _kComprasTicketsTable = 'compras_tickets';
const String _kComprasProviderMovementsTable = 'compras_provider_movements';
const String _kComprasTicketPaymentApplicationsTable =
    'compras_ticket_payment_applications';

const List<String> kComprasFacturaStatuses = <String>[
  'SIN_FACTURA',
  'PENDIENTE_DE_FACTURAR',
  'FACTURADO',
];

const List<String> kComprasPagoStatuses = <String>[
  'PENDIENTE_DE_PAGO',
  'ABONO',
  'PAGADO',
];

const List<String> kComprasCoverageStatuses = <String>[
  'SIN_CUBRIR',
  'PARCIAL',
  'CUBIERTO',
];

String comprasFacturaStatusLabel(String value) {
  switch (value) {
    case 'PENDIENTE_DE_FACTURAR':
      return 'Pendiente de facturar';
    case 'FACTURADO':
      return 'Facturado';
    default:
      return 'Sin factura';
  }
}

String comprasPagoStatusLabel(String value) {
  switch (value) {
    case 'ABONO':
      return 'Abono';
    case 'PAGADO':
      return 'Pagado';
    default:
      return 'Pendiente de pago';
  }
}

String comprasCoverageStatusLabel(String value) {
  switch (value) {
    case 'PARCIAL':
      return 'Parcial';
    case 'CUBIERTO':
      return 'Cubierto';
    default:
      return 'Sin cubrir';
  }
}

class ComprasTicketRecord {
  final String id;
  final DateTime date;
  final String ticket;
  final String providerId;
  final String providerNameSnapshot;
  final String materialId;
  final String materialNameSnapshot;
  final double grossWeight;
  final double tareWeight;
  final double netWeight;
  final double humidityPercent;
  final double trashPercent;
  final double payableWeight;
  final double price;
  final double premium;
  final double amount;
  final String facturaStatus;
  final String pagoStatus;
  final String coverageStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ComprasTicketRecord({
    required this.id,
    required this.date,
    required this.ticket,
    required this.providerId,
    required this.providerNameSnapshot,
    required this.materialId,
    required this.materialNameSnapshot,
    required this.grossWeight,
    required this.tareWeight,
    required this.netWeight,
    required this.humidityPercent,
    required this.trashPercent,
    required this.payableWeight,
    required this.price,
    required this.premium,
    required this.amount,
    required this.facturaStatus,
    required this.pagoStatus,
    required this.coverageStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  ComprasTicketRecord copyWith({
    String? id,
    DateTime? date,
    String? ticket,
    String? providerId,
    String? providerNameSnapshot,
    String? materialId,
    String? materialNameSnapshot,
    double? grossWeight,
    double? tareWeight,
    double? netWeight,
    double? humidityPercent,
    double? trashPercent,
    double? payableWeight,
    double? price,
    double? premium,
    double? amount,
    String? facturaStatus,
    String? pagoStatus,
    String? coverageStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ComprasTicketRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      ticket: ticket ?? this.ticket,
      providerId: providerId ?? this.providerId,
      providerNameSnapshot: providerNameSnapshot ?? this.providerNameSnapshot,
      materialId: materialId ?? this.materialId,
      materialNameSnapshot: materialNameSnapshot ?? this.materialNameSnapshot,
      grossWeight: grossWeight ?? this.grossWeight,
      tareWeight: tareWeight ?? this.tareWeight,
      netWeight: netWeight ?? this.netWeight,
      humidityPercent: humidityPercent ?? this.humidityPercent,
      trashPercent: trashPercent ?? this.trashPercent,
      payableWeight: payableWeight ?? this.payableWeight,
      price: price ?? this.price,
      premium: premium ?? this.premium,
      amount: amount ?? this.amount,
      facturaStatus: facturaStatus ?? this.facturaStatus,
      pagoStatus: pagoStatus ?? this.pagoStatus,
      coverageStatus: coverageStatus ?? this.coverageStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'ticket_date': date.toIso8601String(),
    'ticket_number': ticket,
    'provider_id': providerId,
    'provider_name_snapshot': providerNameSnapshot,
    'material_id': materialId,
    'material_name_snapshot': materialNameSnapshot,
    'gross_weight': grossWeight,
    'tare_weight': tareWeight,
    'net_weight': netWeight,
    'humidity_percent': humidityPercent,
    'trash_percent': trashPercent,
    'payable_weight': payableWeight,
    'price': price,
    'premium': premium,
    'amount': amount,
    'factura_status': facturaStatus,
    'pago_status': pagoStatus,
    'coverage_status': coverageStatus,
  };

  factory ComprasTicketRecord.fromRemoteRow(Map<String, dynamic> row) {
    return ComprasTicketRecord(
      id: (row['id'] ?? '').toString(),
      date: _tryParseDateTime(row['ticket_date'] as String?) ?? DateTime.now(),
      ticket: (row['ticket_number'] ?? '').toString(),
      providerId: (row['provider_id'] ?? '').toString(),
      providerNameSnapshot: (row['provider_name_snapshot'] ?? '').toString(),
      materialId: (row['material_id'] ?? '').toString(),
      materialNameSnapshot: (row['material_name_snapshot'] ?? '').toString(),
      grossWeight: ((row['gross_weight'] as num?) ?? 0).toDouble(),
      tareWeight: ((row['tare_weight'] as num?) ?? 0).toDouble(),
      netWeight: ((row['net_weight'] as num?) ?? 0).toDouble(),
      humidityPercent: ((row['humidity_percent'] as num?) ?? 0).toDouble(),
      trashPercent: ((row['trash_percent'] as num?) ?? 0).toDouble(),
      payableWeight: ((row['payable_weight'] as num?) ?? 0).toDouble(),
      price: ((row['price'] as num?) ?? 0).toDouble(),
      premium: ((row['premium'] as num?) ?? 0).toDouble(),
      amount: ((row['amount'] as num?) ?? 0).toDouble(),
      facturaStatus: (row['factura_status'] as String?) ?? 'SIN_FACTURA',
      pagoStatus: (row['pago_status'] as String?) ?? 'PENDIENTE_DE_PAGO',
      coverageStatus: (row['coverage_status'] as String?) ?? 'SIN_CUBRIR',
      createdAt: _tryParseDateTime(row['created_at'] as String?),
      updatedAt: _tryParseDateTime(row['updated_at'] as String?),
    );
  }
}

class ComprasProviderMovementRecord {
  final String id;
  final String providerId;
  final DateTime date;
  final String type;
  final String source;
  final double amount;
  final String reference;
  final String notes;
  final DateTime? createdAt;

  const ComprasProviderMovementRecord({
    required this.id,
    required this.providerId,
    required this.date,
    required this.type,
    required this.source,
    required this.amount,
    required this.reference,
    required this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'provider_id': providerId,
    'movement_date': date.toIso8601String(),
    'movement_type': type,
    'source_type': source,
    'amount': amount,
    'reference': reference.isEmpty ? null : reference,
    'notes': notes.isEmpty ? null : notes,
  };

  factory ComprasProviderMovementRecord.fromRemoteRow(
    Map<String, dynamic> row,
  ) {
    return ComprasProviderMovementRecord(
      id: (row['id'] ?? '').toString(),
      providerId: (row['provider_id'] ?? '').toString(),
      date:
          _tryParseDateTime(row['movement_date'] as String?) ?? DateTime.now(),
      type: (row['movement_type'] ?? 'ABONO').toString(),
      source: (row['source_type'] ?? 'EFECTIVO').toString(),
      amount: ((row['amount'] as num?) ?? 0).toDouble(),
      reference: (row['reference'] ?? '').toString(),
      notes: (row['notes'] ?? '').toString(),
      createdAt: _tryParseDateTime(row['created_at'] as String?),
    );
  }
}

class ComprasTicketPaymentApplicationRecord {
  final String id;
  final String ticketId;
  final String providerMovementId;
  final double appliedAmount;
  final DateTime appliedAt;

  const ComprasTicketPaymentApplicationRecord({
    required this.id,
    required this.ticketId,
    required this.providerMovementId,
    required this.appliedAmount,
    required this.appliedAt,
  });

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'ticket_id': ticketId,
    'provider_movement_id': providerMovementId,
    'applied_amount': appliedAmount,
    'applied_at': appliedAt.toIso8601String(),
  };

  factory ComprasTicketPaymentApplicationRecord.fromRemoteRow(
    Map<String, dynamic> row,
  ) {
    return ComprasTicketPaymentApplicationRecord(
      id: (row['id'] ?? '').toString(),
      ticketId: (row['ticket_id'] ?? '').toString(),
      providerMovementId: (row['provider_movement_id'] ?? '').toString(),
      appliedAmount: ((row['applied_amount'] as num?) ?? 0).toDouble(),
      appliedAt:
          _tryParseDateTime(row['applied_at'] as String?) ?? DateTime.now(),
    );
  }
}

class ComprasTicketsReferenceData {
  final List<ComprasCatalogProviderRecord> providers;
  final List<ComprasCatalogMaterialRecord> materials;
  final List<ComprasCatalogPriceRecord> prices;

  const ComprasTicketsReferenceData({
    required this.providers,
    required this.materials,
    required this.prices,
  });
}

class ComprasTicketsStore {
  static Future<List<ComprasTicketRecord>> loadTickets() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kComprasTicketsTable)
          .select()
          .order('ticket_date', ascending: false)
          .order('ticket_number', ascending: false);
      return (rows as List)
          .map(
            (row) => ComprasTicketRecord.fromRemoteRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false)
        ..sort((a, b) {
          final dateCompare = b.date.compareTo(a.date);
          if (dateCompare != 0) return dateCompare;
          return compareMayoreoAlpha(a.ticket, b.ticket);
        });
    } catch (_) {
      return const <ComprasTicketRecord>[];
    }
  }

  static Future<void> saveTickets(List<ComprasTicketRecord> rows) async {
    if (rows.isEmpty) return;
    await Supabase.instance.client
        .from(_kComprasTicketsTable)
        .upsert(
          rows.map((row) => row.toUpsertJson()).toList(growable: false),
          onConflict: 'id',
        );
  }

  static Future<void> saveTicket(ComprasTicketRecord row) async {
    await saveTickets(<ComprasTicketRecord>[row]);
  }

  static Future<void> deleteTickets(Set<String> ids) async {
    if (ids.isEmpty) return;
    await Supabase.instance.client
        .from(_kComprasTicketPaymentApplicationsTable)
        .delete()
        .inFilter('ticket_id', ids.toList(growable: false));
    await Supabase.instance.client
        .from(_kComprasTicketsTable)
        .delete()
        .inFilter('id', ids.toList(growable: false));
  }

  static Future<ComprasTicketsReferenceData> loadReferenceData() async {
    final snapshot = await ComprasDataStore.loadCatalogSnapshot();
    final providers =
        snapshot.companies.where((row) => row.active).toList(growable: false)
          ..sort((a, b) => compareMayoreoAlpha(a.name, b.name));
    final materials =
        snapshot.materials
            .where(
              (row) =>
                  row.active && row.level.trim().toUpperCase() != 'GENERAL',
            )
            .toList(growable: false)
          ..sort((a, b) => compareMayoreoAlpha(a.name, b.name));
    return ComprasTicketsReferenceData(
      providers: providers,
      materials: materials,
      prices: snapshot.prices
          .where((row) => row.active)
          .toList(growable: false),
    );
  }

  static Future<void> saveProviderMovement(
    ComprasProviderMovementRecord row,
  ) async {
    await Supabase.instance.client.from(_kComprasProviderMovementsTable).upsert(
      <Map<String, dynamic>>[row.toUpsertJson()],
      onConflict: 'id',
    );
  }

  static Future<void> saveTicketPaymentApplications(
    List<ComprasTicketPaymentApplicationRecord> rows,
  ) async {
    if (rows.isEmpty) return;
    await Supabase.instance.client
        .from(_kComprasTicketPaymentApplicationsTable)
        .upsert(
          rows.map((row) => row.toUpsertJson()).toList(growable: false),
          onConflict: 'id',
        );
  }

  static Future<List<ComprasProviderMovementRecord>>
  loadProviderMovements() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kComprasProviderMovementsTable)
          .select()
          .order('movement_date', ascending: false)
          .order('created_at', ascending: false);
      return (rows as List)
          .map(
            (row) => ComprasProviderMovementRecord.fromRemoteRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <ComprasProviderMovementRecord>[];
    }
  }

  static Future<List<ComprasTicketPaymentApplicationRecord>>
  loadTicketPaymentApplications() async {
    try {
      final rows = await Supabase.instance.client
          .from(_kComprasTicketPaymentApplicationsTable)
          .select()
          .order('applied_at', ascending: false)
          .order('created_at', ascending: false);
      return (rows as List)
          .map(
            (row) => ComprasTicketPaymentApplicationRecord.fromRemoteRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <ComprasTicketPaymentApplicationRecord>[];
    }
  }

  static Future<void> createProviderMovementAndAutoApply({
    required ComprasProviderMovementRecord movement,
  }) async {
    await _saveProviderMovementAndRebuildApplications(movement);
  }

  static Future<void> updateProviderMovementAndAutoApply({
    required ComprasProviderMovementRecord movement,
  }) async {
    await _saveProviderMovementAndRebuildApplications(movement);
  }

  static Future<void> deleteProviderMovementAndRebuildApplications({
    required ComprasProviderMovementRecord movement,
  }) async {
    await Supabase.instance.client
        .from(_kComprasProviderMovementsTable)
        .delete()
        .eq('id', movement.id);
    await _rebuildProviderMovementApplications(movement.providerId);
  }
}

Future<void> _saveProviderMovementAndRebuildApplications(
  ComprasProviderMovementRecord movement,
) async {
  await ComprasTicketsStore.saveProviderMovement(movement);
  await _rebuildProviderMovementApplications(movement.providerId);
}

Future<void> _rebuildProviderMovementApplications(String providerId) async {
  final tickets = await ComprasTicketsStore.loadTickets();
  final providerTickets =
      tickets
          .where((ticket) => ticket.providerId == providerId)
          .toList(growable: false)
        ..sort((a, b) => a.date.compareTo(b.date));
  if (providerTickets.isEmpty) return;

  final providerTicketIds = providerTickets
      .map((ticket) => ticket.id)
      .toList(growable: false);
  final providerMovements =
      (await ComprasTicketsStore.loadProviderMovements())
          .where((row) => row.providerId == providerId)
          .toList(growable: false)
        ..sort((a, b) {
          final dateCompare = a.date.compareTo(b.date);
          if (dateCompare != 0) return dateCompare;
          return a.id.compareTo(b.id);
        });
  final existingApplications =
      await ComprasTicketsStore.loadTicketPaymentApplications();
  final providerApplications = existingApplications
      .where((row) => providerTicketIds.contains(row.ticketId))
      .toList(growable: false);

  final externallySettledTicketIds = <String>{};
  final existingAppliedByTicketId = <String, double>{};
  for (final application in providerApplications) {
    existingAppliedByTicketId.update(
      application.ticketId,
      (value) => value + application.appliedAmount,
      ifAbsent: () => application.appliedAmount,
    );
  }
  for (final ticket in providerTickets) {
    final existingApplied = existingAppliedByTicketId[ticket.id] ?? 0;
    if (existingApplied <= 0.009 &&
        ticket.pagoStatus == 'PAGADO' &&
        ticket.coverageStatus == 'CUBIERTO') {
      externallySettledTicketIds.add(ticket.id);
    }
  }

  await Supabase.instance.client
      .from(_kComprasTicketPaymentApplicationsTable)
      .delete()
      .inFilter('ticket_id', providerTicketIds);

  final appliedByTicketId = <String, double>{};
  final newApplications = <ComprasTicketPaymentApplicationRecord>[];
  final eligibleMovements = providerMovements.where(
    (row) => row.type == 'ABONO' || row.type == 'PAGO',
  );
  for (final providerMovement in eligibleMovements) {
    var remaining = providerMovement.amount;
    for (final ticket in providerTickets) {
      if (remaining <= 0) break;
      if (externallySettledTicketIds.contains(ticket.id)) continue;
      final alreadyApplied = appliedByTicketId[ticket.id] ?? 0;
      final pending = (ticket.amount - alreadyApplied)
          .clamp(0, double.infinity)
          .toDouble();
      if (pending <= 0) continue;
      final applied = remaining > pending ? pending : remaining;
      if (applied <= 0) continue;
      newApplications.add(
        ComprasTicketPaymentApplicationRecord(
          id: 'compras-ticket-app-${providerMovement.id}-${ticket.id}-${newApplications.length}',
          ticketId: ticket.id,
          providerMovementId: providerMovement.id,
          appliedAmount: applied,
          appliedAt: providerMovement.date,
        ),
      );
      appliedByTicketId[ticket.id] = alreadyApplied + applied;
      remaining -= applied;
    }
  }
  if (newApplications.isNotEmpty) {
    await ComprasTicketsStore.saveTicketPaymentApplications(newApplications);
  }

  final updatedTickets = providerTickets
      .map((ticket) {
        if (externallySettledTicketIds.contains(ticket.id)) {
          return ticket;
        }
        final applied = (appliedByTicketId[ticket.id] ?? 0).clamp(
          0,
          double.infinity,
        );
        final coverageStatus = applied >= ticket.amount - 0.009
            ? 'CUBIERTO'
            : applied > 0
            ? 'PARCIAL'
            : 'SIN_CUBRIR';
        final pagoStatus = applied >= ticket.amount - 0.009
            ? 'PAGADO'
            : applied > 0
            ? 'ABONO'
            : 'PENDIENTE_DE_PAGO';
        return ticket.copyWith(
          coverageStatus: coverageStatus,
          pagoStatus: pagoStatus,
        );
      })
      .toList(growable: false);
  if (updatedTickets.isNotEmpty) {
    await ComprasTicketsStore.saveTickets(updatedTickets);
  }
}

double? resolveComprasCurrentPrice({
  required List<ComprasCatalogPriceRecord> prices,
  required String providerId,
  required String materialId,
}) {
  if (providerId.trim().isEmpty || materialId.trim().isEmpty) return null;
  ComprasCatalogPriceRecord? match;
  for (final row in prices) {
    if (row.companyId == providerId && row.materialId == materialId) {
      if (match == null) {
        match = row;
        continue;
      }
      final currentUpdatedAt =
          row.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bestUpdatedAt =
          match.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (currentUpdatedAt.isAfter(bestUpdatedAt)) {
        match = row;
      }
    }
  }
  return match?.amount;
}

ComprasTicketRecord buildComprasTicketDraft({
  required String id,
  required DateTime date,
  required String ticket,
  required String providerId,
  required String providerNameSnapshot,
  required String materialId,
  required String materialNameSnapshot,
  required double grossWeight,
  required double tareWeight,
  required double humidityPercent,
  required double trashPercent,
  required double price,
  required double premium,
  required String facturaStatus,
  String pagoStatus = 'PENDIENTE_DE_PAGO',
  String coverageStatus = 'SIN_CUBRIR',
}) {
  final netWeight = (grossWeight - tareWeight).clamp(0, double.infinity);
  final discountFactor = 1 - ((humidityPercent + trashPercent) / 100);
  final payableWeight = (netWeight * discountFactor).clamp(0, double.infinity);
  final amount = payableWeight * (price + premium);
  return ComprasTicketRecord(
    id: id,
    date: date,
    ticket: ticket.trim(),
    providerId: providerId,
    providerNameSnapshot: providerNameSnapshot.trim(),
    materialId: materialId,
    materialNameSnapshot: materialNameSnapshot.trim(),
    grossWeight: grossWeight,
    tareWeight: tareWeight,
    netWeight: netWeight.toDouble(),
    humidityPercent: humidityPercent,
    trashPercent: trashPercent,
    payableWeight: payableWeight.toDouble(),
    price: price,
    premium: premium,
    amount: amount.toDouble(),
    facturaStatus: facturaStatus,
    pagoStatus: pagoStatus,
    coverageStatus: coverageStatus,
    createdAt: null,
    updatedAt: DateTime.now(),
  );
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
