import 'package:supabase_flutter/supabase_flutter.dart';

import 'maintenance_statuses.dart';

class MaintenanceOtPurchaseSyncResult {
  final int purchasableCount;
  final int createdCount;
  final int alreadyLinkedCount;

  const MaintenanceOtPurchaseSyncResult({
    required this.purchasableCount,
    required this.createdCount,
    required this.alreadyLinkedCount,
  });

  bool get hasLinkedRows => createdCount > 0 || alreadyLinkedCount > 0;
}

class MaintenanceOtPurchaseLinkService {
  final SupabaseClient _supa;

  const MaintenanceOtPurchaseLinkService(this._supa);

  Future<MaintenanceOtPurchaseSyncResult> ensurePurchaseOrdersForOtCotizacion({
    required String otId,
    String? actorUserId,
    String? actorName,
  }) async {
    final ot = await _supa
        .from('maintenance_orders')
        .select('id,ot_folio,requested_at,equipment_label,area_label,status')
        .eq('id', otId)
        .single();
    final materials = await _supa
        .from('maintenance_materials')
        .select('*')
        .eq('ot_id', otId)
        .order('line_no');

    final otRow = Map<String, dynamic>.from(ot);
    final requestedAt = _dateFromAny(otRow['requested_at']) ?? DateTime.now();
    final orderDate = _fmtDbDate(requestedAt);
    final targetLabel = _deriveTargetLabel(otRow);
    final otFolio = (otRow['ot_folio'] ?? '').toString().trim();

    var purchasableCount = 0;
    var createdCount = 0;
    var alreadyLinkedCount = 0;

    for (final raw in materials as List) {
      final material = Map<String, dynamic>.from(raw as Map<String, dynamic>);
      final name = (material['name'] ?? '').toString().trim();
      final source = (material['source'] ?? 'almacen').toString().trim();
      if (name.isEmpty || !_isPurchasableMaterialSource(source)) continue;
      purchasableCount++;

      final existingPurchaseOrderId = (material['purchase_order_id'] ?? '')
          .toString()
          .trim();
      final existingPurchaseOrderLineId =
          (material['purchase_order_line_id'] ?? '').toString().trim();
      if (existingPurchaseOrderId.isNotEmpty ||
          existingPurchaseOrderLineId.isNotEmpty) {
        alreadyLinkedCount++;
        continue;
      }

      final qty = _toDouble(material['qty']) ?? 1;
      final safeQty = qty <= 0 ? 1.0 : qty;
      final estimatedTotal = _toDouble(material['cost_estimated']) ?? 0;
      final unitAmount = safeQty == 0
          ? estimatedTotal
          : estimatedTotal / safeQty;
      final providerType = _defaultProviderTypeForSource(source);
      final notes = _mergeNotes(
        'Generada automaticamente desde ${otFolio.isEmpty ? 'OT' : otFolio}.',
        (material['notes'] ?? '').toString(),
      );

      final insertedOrder = await _supa
          .from('maintenance_purchase_orders')
          .insert({
            'order_date': orderDate,
            'target_label': targetLabel,
            'quote_vendor_type': providerType,
            'notes': notes,
            'estimated_total': estimatedTotal,
            'requested_by': _emptyAsNull(actorUserId),
            'requested_by_name': _emptyAsNull(actorName),
            'linked_ot_id': otId,
            'linked_ot_folio': _emptyAsNull(otFolio),
            'linked_material_label': name,
            'generated_from_ot': true,
          })
          .select('id,folio')
          .single();

      final purchaseOrderId = (insertedOrder['id'] ?? '').toString().trim();
      final purchaseOrderFolio = (insertedOrder['folio'] ?? '')
          .toString()
          .trim();
      if (purchaseOrderId.isEmpty) continue;

      final insertedLine = await _supa
          .from('maintenance_purchase_order_lines')
          .insert({
            'purchase_order_id': purchaseOrderId,
            'line_no': 1,
            'line_type': _purchaseOrderLineTypeForMaterialSource(source),
            'qty': qty <= 0 ? 1 : qty,
            'description': name,
            'amount': unitAmount,
            'line_total': estimatedTotal,
            'notes': _emptyAsNull((material['notes'] ?? '').toString()),
          })
          .select('id')
          .single();

      final purchaseOrderLineId = (insertedLine['id'] ?? '').toString().trim();
      final materialId = (material['id'] ?? '').toString().trim();
      if (materialId.isNotEmpty) {
        await _supa
            .from('maintenance_materials')
            .update({
              'purchase_order_id': purchaseOrderId,
              'purchase_order_line_id': _emptyAsNull(purchaseOrderLineId),
              'purchase_order_folio': _emptyAsNull(purchaseOrderFolio),
              'purchase_order_line_description': name,
            })
            .eq('id', materialId);
      }

      createdCount++;
    }

    return MaintenanceOtPurchaseSyncResult(
      purchasableCount: purchasableCount,
      createdCount: createdCount,
      alreadyLinkedCount: alreadyLinkedCount,
    );
  }

  Future<void> syncLinkedPurchaseOrderIntoOtMaterials({
    required String purchaseOrderId,
  }) async {
    final orderRows = await _supa
        .from('maintenance_purchase_orders')
        .select(
          'id,folio,linked_ot_id,linked_ot_folio,actual_total,estimated_total',
        )
        .eq('id', purchaseOrderId)
        .limit(1);
    final orderList = (orderRows as List)
        .map((row) => Map<String, dynamic>.from(row as Map<String, dynamic>))
        .toList(growable: false);
    if (orderList.isEmpty) return;
    final order = orderList.first;
    final linkedOtId = (order['linked_ot_id'] ?? '').toString().trim();
    if (linkedOtId.isEmpty) return;

    final lineRows = await _supa
        .from('maintenance_purchase_order_lines')
        .select('*')
        .eq('purchase_order_id', purchaseOrderId)
        .order('line_no');
    final lines = (lineRows as List)
        .map((row) => Map<String, dynamic>.from(row as Map<String, dynamic>))
        .toList(growable: false);
    if (lines.isEmpty) {
      await _recalculateMaintenanceOrderTotals(linkedOtId);
      return;
    }

    final materialRows = await _supa
        .from('maintenance_materials')
        .select('*')
        .eq('ot_id', linkedOtId)
        .order('line_no');
    final existingMaterials = (materialRows as List)
        .map((row) => Map<String, dynamic>.from(row as Map<String, dynamic>))
        .toList();

    final existingByPurchaseOrderLineId = <String, Map<String, dynamic>>{};
    var maxLineNo = 0;
    for (final row in existingMaterials) {
      final lineNo = (row['line_no'] as num?)?.toInt() ?? 0;
      if (lineNo > maxLineNo) maxLineNo = lineNo;
      final lineId = (row['purchase_order_line_id'] ?? '').toString().trim();
      if (lineId.isNotEmpty) {
        existingByPurchaseOrderLineId[lineId] = row;
      }
    }

    final estimatedTotals = lines
        .map(_purchaseOrderLineTotal)
        .fold<double>(0, (sum, value) => sum + value);
    final actualTotal = _toDouble(order['actual_total']);

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final purchaseOrderLineId = (line['id'] ?? '').toString().trim();
      if (purchaseOrderLineId.isEmpty) continue;

      final existing = existingByPurchaseOrderLineId[purchaseOrderLineId];
      final estimatedLineTotal = _purchaseOrderLineTotal(line);
      final actualLineTotal = _distributedActualLineTotal(
        estimatedLineTotal: estimatedLineTotal,
        estimatedOrderTotal: estimatedTotals,
        actualOrderTotal: actualTotal,
        lineCount: lines.length,
      );
      final payload = <String, dynamic>{
        'ot_id': linkedOtId,
        'name': (line['description'] ?? '').toString().trim(),
        'qty': _toDouble(line['qty']),
        'source': _materialSourceForPurchaseOrderLineType(
          (line['line_type'] ?? 'material').toString(),
        ),
        'cost_estimated': estimatedLineTotal,
        'cost_actual': actualLineTotal,
        'notes': _emptyAsNull((line['notes'] ?? '').toString()),
        'purchase_order_id': purchaseOrderId,
        'purchase_order_line_id': purchaseOrderLineId,
        'purchase_order_folio': _emptyAsNull(
          (order['folio'] ?? '').toString().trim(),
        ),
        'purchase_order_line_description': _emptyAsNull(
          (line['description'] ?? '').toString(),
        ),
      };

      if (existing != null) {
        await _supa
            .from('maintenance_materials')
            .update(payload)
            .eq('id', existing['id']);
        continue;
      }

      maxLineNo += 1;
      await _supa.from('maintenance_materials').insert({
        ...payload,
        'line_no': maxLineNo,
      });
    }

    await _recalculateMaintenanceOrderTotals(linkedOtId);
  }

  Future<void> syncOtStatusFromLinkedPurchaseOrder({
    required String purchaseOrderId,
    String? actorUserId,
    String? actorName,
  }) async {
    final orderRows = await _supa
        .from('maintenance_purchase_orders')
        .select('id,folio,linked_ot_id,status')
        .eq('id', purchaseOrderId)
        .limit(1);
    final orderList = (orderRows as List)
        .map((row) => Map<String, dynamic>.from(row as Map<String, dynamic>))
        .toList(growable: false);
    if (orderList.isEmpty) return;
    final order = orderList.first;
    final linkedOtId = (order['linked_ot_id'] ?? '').toString().trim();
    if (linkedOtId.isEmpty) return;

    final linkedOrders = await _supa
        .from('maintenance_purchase_orders')
        .select('id,status')
        .eq('linked_ot_id', linkedOtId);
    final orders = (linkedOrders as List)
        .map((row) => Map<String, dynamic>.from(row as Map<String, dynamic>))
        .toList(growable: false);
    if (orders.isEmpty) return;

    final allAuthorized = orders.every((row) {
      final status = (row['status'] ?? '').toString().trim();
      return status == 'authorized' || status == 'purchased';
    });
    if (!allAuthorized) return;

    final ot = await _supa
        .from('maintenance_orders')
        .select('id,status')
        .eq('id', linkedOtId)
        .single();
    final currentStatusRaw = (ot['status'] ?? '').toString().trim();
    final currentStatus = normalizeMaintenanceStatus(currentStatusRaw);
    if (currentStatus != 'cotizacion') return;

    await _supa
        .from('maintenance_orders')
        .update({'status': 'autorizacion_finanzas'})
        .eq('id', linkedOtId);
    await _supa.from('maintenance_status_log').insert({
      'ot_id': linkedOtId,
      'from_status': currentStatusRaw.isEmpty ? null : currentStatusRaw,
      'to_status': 'autorizacion_finanzas',
      'changed_by': _emptyAsNull(actorUserId),
      'changed_by_name': _emptyAsNull(actorName),
      'comment': 'Cambio automatico al autorizar todas las OC ligadas.',
    });
  }

  Future<void> _recalculateMaintenanceOrderTotals(String otId) async {
    final materialRows = await _supa
        .from('maintenance_materials')
        .select('cost_estimated,cost_actual')
        .eq('ot_id', otId);
    var estimatedTotal = 0.0;
    var actualTotal = 0.0;
    for (final raw in materialRows as List) {
      final row = Map<String, dynamic>.from(raw as Map<String, dynamic>);
      estimatedTotal += _toDouble(row['cost_estimated']) ?? 0;
      actualTotal += _toDouble(row['cost_actual']) ?? 0;
    }
    await _supa
        .from('maintenance_orders')
        .update({
          'cost_estimated_total': estimatedTotal,
          'cost_actual_total': actualTotal,
        })
        .eq('id', otId);
  }
}

bool _isPurchasableMaterialSource(String source) {
  switch (source.trim().toLowerCase()) {
    case 'compra':
    case 'proveedor':
    case 'mano_obra':
    case 'servicio_tecnico':
      return true;
    default:
      return false;
  }
}

String _purchaseOrderLineTypeForMaterialSource(String source) {
  switch (source.trim().toLowerCase()) {
    case 'mano_obra':
    case 'servicio_tecnico':
      return 'mano_obra';
    default:
      return 'material';
  }
}

String _materialSourceForPurchaseOrderLineType(String lineType) {
  switch (lineType.trim().toLowerCase()) {
    case 'mano_obra':
      return 'mano_obra';
    default:
      return 'compra';
  }
}

String _defaultProviderTypeForSource(String source) {
  switch (source.trim().toLowerCase()) {
    case 'mano_obra':
    case 'servicio_tecnico':
      return 'Mecanico';
    case 'proveedor':
      return 'Proveedor';
    case 'compra':
    default:
      return 'Proveedor';
  }
}

String _deriveTargetLabel(Map<String, dynamic> order) {
  final equipment = (order['equipment_label'] ?? '').toString().trim();
  if (equipment.isNotEmpty) return equipment;
  final area = (order['area_label'] ?? '').toString().trim();
  if (area.isNotEmpty) return area;
  return 'SIN UNIDAD';
}

String? _emptyAsNull(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String? _mergeNotes(String base, String extra) {
  final normalizedBase = base.trim();
  final normalizedExtra = extra.trim();
  if (normalizedBase.isEmpty && normalizedExtra.isEmpty) return null;
  if (normalizedBase.isEmpty) return normalizedExtra;
  if (normalizedExtra.isEmpty) return normalizedBase;
  return '$normalizedBase\n$normalizedExtra';
}

String _fmtDbDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

DateTime? _dateFromAny(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  final value = raw.toString().trim();
  if (value.isEmpty) return null;
  return DateTime.tryParse(value);
}

double? _toDouble(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  final normalized = raw.toString().trim().replaceAll(',', '');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

double _purchaseOrderLineTotal(Map<String, dynamic> line) {
  final explicit = _toDouble(line['line_total']);
  if (explicit != null && explicit > 0) return explicit;
  final qty = _toDouble(line['qty']) ?? 0;
  final amount = _toDouble(line['amount']) ?? 0;
  return qty * amount;
}

double? _distributedActualLineTotal({
  required double estimatedLineTotal,
  required double estimatedOrderTotal,
  required double? actualOrderTotal,
  required int lineCount,
}) {
  if (actualOrderTotal == null || actualOrderTotal <= 0) return null;
  if (lineCount <= 1 || estimatedOrderTotal <= 0) return actualOrderTotal;
  return (actualOrderTotal * (estimatedLineTotal / estimatedOrderTotal));
}
