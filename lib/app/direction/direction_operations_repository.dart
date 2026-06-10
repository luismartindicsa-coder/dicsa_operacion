import 'package:supabase_flutter/supabase_flutter.dart';

enum DirectionFollowupSeverity { info, warning, critical }

class DirectionFollowupAlert {
  final String title;
  final String detail;
  final DirectionFollowupSeverity severity;

  const DirectionFollowupAlert({
    required this.title,
    required this.detail,
    required this.severity,
  });
}

class DirectionPurchasePendingItem {
  final String id;
  final String folio;
  final String status;
  final DateTime? orderDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String targetLabel;
  final String vendorName;
  final String requestedByName;
  final String quoteContact;
  final String directionComment;
  final double total;
  final double ageHours;
  final List<String> missingReasons;
  final List<String> lineSummaries;

  const DirectionPurchasePendingItem({
    required this.id,
    required this.folio,
    required this.status,
    required this.orderDate,
    required this.createdAt,
    required this.updatedAt,
    required this.targetLabel,
    required this.vendorName,
    required this.requestedByName,
    required this.quoteContact,
    required this.directionComment,
    required this.total,
    required this.ageHours,
    required this.missingReasons,
    required this.lineSummaries,
  });
}

class DirectionPurchaseOrdersSummary {
  final int pendingCount;
  final int criticalCount;
  final int warningCount;
  final int rejectedCount;
  final double pendingAmount;
  final double oldestHours;
  final List<DirectionFollowupAlert> alerts;
  final List<DirectionPurchasePendingItem> pendingItems;

  const DirectionPurchaseOrdersSummary({
    required this.pendingCount,
    required this.criticalCount,
    required this.warningCount,
    required this.rejectedCount,
    required this.pendingAmount,
    required this.oldestHours,
    required this.alerts,
    required this.pendingItems,
  });
}

class DirectionMaintenancePendingItem {
  final String id;
  final String folio;
  final String status;
  final String priority;
  final String impact;
  final String areaLabel;
  final String equipmentLabel;
  final DateTime? requestedAt;
  final DateTime? updatedAt;
  final double estimatedTotal;
  final double actualTotal;
  final bool waitingDirection;
  final double ageHours;
  final List<String> missingReasons;

  const DirectionMaintenancePendingItem({
    required this.id,
    required this.folio,
    required this.status,
    required this.priority,
    required this.impact,
    required this.areaLabel,
    required this.equipmentLabel,
    required this.requestedAt,
    required this.updatedAt,
    required this.estimatedTotal,
    required this.actualTotal,
    required this.waitingDirection,
    required this.ageHours,
    required this.missingReasons,
  });
}

class DirectionMaintenanceSummary {
  final int openCount;
  final int criticalCount;
  final int staleCount;
  final int waitingDirectionCount;
  final double oldestHours;
  final List<DirectionFollowupAlert> alerts;
  final List<DirectionMaintenancePendingItem> pendingItems;

  const DirectionMaintenanceSummary({
    required this.openCount,
    required this.criticalCount,
    required this.staleCount,
    required this.waitingDirectionCount,
    required this.oldestHours,
    required this.alerts,
    required this.pendingItems,
  });
}

class DirectionOperationsRepository {
  DirectionOperationsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<DirectionPurchaseOrdersSummary> loadPurchaseOrdersSummary() async {
    final rawOrders = await _client
        .from('maintenance_purchase_orders')
        .select(
          'id,folio,status,order_date,created_at,updated_at,target_label,quote_vendor_name,quote_contact,requested_by_name,direction_comment',
        )
        .order('created_at', ascending: true);

    final orders = (rawOrders as List)
        .map((row) => Map<String, dynamic>.from(row as Map<String, dynamic>))
        .toList(growable: false);

    final orderIds = orders
        .map((row) => (row['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    final totalByOrderId = <String, double>{};
    final lineCountByOrderId = <String, int>{};
    final invalidDescriptionByOrderId = <String, int>{};
    final invalidQtyByOrderId = <String, int>{};
    final invalidAmountByOrderId = <String, int>{};
    final lineSummariesByOrderId = <String, List<String>>{};
    if (orderIds.isNotEmpty) {
      final rawLines = await _client
          .from('maintenance_purchase_order_lines')
          .select('purchase_order_id,line_total,qty,amount,description')
          .inFilter('purchase_order_id', orderIds);
      for (final raw in rawLines as List) {
        final row = Map<String, dynamic>.from(raw as Map<String, dynamic>);
        final orderId = (row['purchase_order_id'] ?? '').toString();
        if (orderId.isEmpty) continue;
        lineCountByOrderId[orderId] = (lineCountByOrderId[orderId] ?? 0) + 1;
        final explicit = _toDouble(row['line_total']);
        final qty = _toDouble(row['qty']);
        final amount = _toDouble(row['amount']);
        final description = (row['description'] ?? '').toString().trim();
        if (description.isEmpty) {
          invalidDescriptionByOrderId[orderId] =
              (invalidDescriptionByOrderId[orderId] ?? 0) + 1;
        } else {
          final summaries = lineSummariesByOrderId.putIfAbsent(
            orderId,
            () => <String>[],
          );
          if (!summaries.contains(description)) {
            summaries.add(description);
          }
        }
        if (qty <= 0) {
          invalidQtyByOrderId[orderId] =
              (invalidQtyByOrderId[orderId] ?? 0) + 1;
        }
        if (amount <= 0) {
          invalidAmountByOrderId[orderId] =
              (invalidAmountByOrderId[orderId] ?? 0) + 1;
        }
        final total = explicit > 0 ? explicit : (qty * amount);
        totalByOrderId[orderId] = (totalByOrderId[orderId] ?? 0) + total;
      }
    }

    final pendingItems =
        orders
            .where(
              (row) => (row['status'] ?? '').toString() == 'pending_direction',
            )
            .map((row) {
              final createdAt =
                  DateTime.tryParse((row['created_at'] ?? '').toString()) ??
                  DateTime.tryParse((row['order_date'] ?? '').toString());
              final ageHours = _hoursSince(createdAt);
              return DirectionPurchasePendingItem(
                id: (row['id'] ?? '').toString(),
                folio: (row['folio'] ?? '').toString(),
                status: (row['status'] ?? '').toString(),
                orderDate: DateTime.tryParse(
                  (row['order_date'] ?? '').toString(),
                ),
                createdAt: DateTime.tryParse(
                  (row['created_at'] ?? '').toString(),
                ),
                updatedAt: DateTime.tryParse(
                  (row['updated_at'] ?? '').toString(),
                ),
                targetLabel: (row['target_label'] ?? '').toString(),
                vendorName: (row['quote_vendor_name'] ?? '').toString(),
                requestedByName: (row['requested_by_name'] ?? '').toString(),
                quoteContact: (row['quote_contact'] ?? '').toString(),
                directionComment: (row['direction_comment'] ?? '').toString(),
                total: totalByOrderId[(row['id'] ?? '').toString()] ?? 0,
                ageHours: ageHours,
                missingReasons: _purchaseMissingReasons(
                  status: (row['status'] ?? '').toString(),
                  targetLabel: (row['target_label'] ?? '').toString(),
                  vendorName: (row['quote_vendor_name'] ?? '').toString(),
                  quoteContact: (row['quote_contact'] ?? '').toString(),
                  requestedByName: (row['requested_by_name'] ?? '').toString(),
                  lineCount:
                      lineCountByOrderId[(row['id'] ?? '').toString()] ?? 0,
                  invalidDescriptions:
                      invalidDescriptionByOrderId[(row['id'] ?? '')
                          .toString()] ??
                      0,
                  invalidQty:
                      invalidQtyByOrderId[(row['id'] ?? '').toString()] ?? 0,
                  invalidAmount:
                      invalidAmountByOrderId[(row['id'] ?? '').toString()] ?? 0,
                ),
                lineSummaries:
                    lineSummariesByOrderId[(row['id'] ?? '').toString()] ??
                    const <String>[],
              );
            })
            .toList(growable: false)
          ..sort((a, b) {
            final ageCompare = b.ageHours.compareTo(a.ageHours);
            if (ageCompare != 0) return ageCompare;
            return b.total.compareTo(a.total);
          });

    final pendingCount = pendingItems.length;
    final criticalCount = pendingItems
        .where((row) => row.ageHours >= 48)
        .length;
    final warningCount = pendingItems
        .where((row) => row.ageHours >= 24 && row.ageHours < 48)
        .length;
    final rejectedCount = orders
        .where((row) => (row['status'] ?? '').toString() == 'rejected')
        .length;
    final pendingAmount = pendingItems.fold<double>(
      0,
      (sum, row) => sum + row.total,
    );
    final oldestHours = pendingItems.isEmpty
        ? 0.0
        : pendingItems.first.ageHours;

    final alerts = <DirectionFollowupAlert>[];
    if (criticalCount > 0) {
      alerts.add(
        DirectionFollowupAlert(
          title: 'Compras pendientes críticas',
          detail:
              'Hay $criticalCount órdenes de compra con más de 48 horas esperando decisión de Dirección.',
          severity: DirectionFollowupSeverity.critical,
        ),
      );
    }
    if (warningCount > 0) {
      alerts.add(
        DirectionFollowupAlert(
          title: 'Compras pendientes por revisar hoy',
          detail:
              'Hay $warningCount órdenes con más de 24 horas sin resolución ejecutiva.',
          severity: DirectionFollowupSeverity.warning,
        ),
      );
    }
    if (pendingAmount > 0) {
      alerts.add(
        DirectionFollowupAlert(
          title: 'Monto pendiente por aprobar',
          detail:
              'El monto acumulado pendiente en Compras OT es ${_moneyCompact(pendingAmount)}.',
          severity: pendingAmount >= 25000
              ? DirectionFollowupSeverity.warning
              : DirectionFollowupSeverity.info,
        ),
      );
    }
    if (rejectedCount > 0) {
      alerts.add(
        DirectionFollowupAlert(
          title: 'Órdenes rechazadas por corregir',
          detail:
              'Hay $rejectedCount órdenes rechazadas que siguen esperando corrección y reenvío.',
          severity: DirectionFollowupSeverity.info,
        ),
      );
    }
    for (final entry in _topMissingReasonEntries(pendingItems, limit: 4)) {
      final severity = switch (entry.key) {
        'Aprobación de Dirección' => DirectionFollowupSeverity.critical,
        'Proveedor' ||
        'Contacto' ||
        'Renglones' ||
        'Monto en renglones' => DirectionFollowupSeverity.warning,
        _ => DirectionFollowupSeverity.info,
      };
      alerts.add(
        DirectionFollowupAlert(
          title: 'Compras con faltante recurrente',
          detail:
              'Hay ${entry.value} órdenes de compra a las que les falta ${entry.key.toLowerCase()}.',
          severity: severity,
        ),
      );
    }
    if (alerts.isEmpty) {
      alerts.add(
        const DirectionFollowupAlert(
          title: 'Compras OT al día',
          detail: 'No hay órdenes pendientes de Dirección en este momento.',
          severity: DirectionFollowupSeverity.info,
        ),
      );
    }

    return DirectionPurchaseOrdersSummary(
      pendingCount: pendingCount,
      criticalCount: criticalCount,
      warningCount: warningCount,
      rejectedCount: rejectedCount,
      pendingAmount: pendingAmount,
      oldestHours: oldestHours,
      alerts: alerts,
      pendingItems: pendingItems.take(12).toList(growable: false),
    );
  }

  Future<void> authorizePurchaseOrder({
    required String orderId,
    required String actorName,
    required String? actorUserId,
  }) async {
    await _client
        .from('maintenance_purchase_orders')
        .update({
          'status': 'authorized',
          'direction_authorized_by': actorUserId,
          'direction_authorized_by_name': actorName,
          'direction_authorized_at': DateTime.now().toIso8601String(),
          'direction_rejected_at': null,
          'direction_comment': null,
        })
        .eq('id', orderId);
  }

  Future<void> rejectPurchaseOrder({
    required String orderId,
    required String comment,
  }) async {
    await _client
        .from('maintenance_purchase_orders')
        .update({
          'status': 'rejected',
          'direction_rejected_at': DateTime.now().toIso8601String(),
          'direction_comment': comment.trim().isEmpty ? null : comment.trim(),
        })
        .eq('id', orderId);
  }

  Future<DirectionMaintenanceSummary> loadMaintenanceSummary() async {
    final rawOrders = await _client
        .from('maintenance_orders')
        .select(
          'id,ot_folio,status,priority,impact,area_label,equipment_label,requested_at,updated_at,cost_estimated_total,cost_actual_total,mechanic_name,mechanic_contact,problem_description,diagnosis,work_summary,assigned_to_name',
        )
        .order('updated_at', ascending: true);

    final orders = (rawOrders as List)
        .map((row) => Map<String, dynamic>.from(row as Map<String, dynamic>))
        .toList(growable: false);

    final orderIds = orders
        .map((row) => (row['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final materialCountByOtId = <String, int>{};
    if (orderIds.isNotEmpty) {
      final rawMaterials = await _client
          .from('maintenance_materials')
          .select('ot_id,name')
          .inFilter('ot_id', orderIds);
      for (final raw in rawMaterials as List) {
        final row = Map<String, dynamic>.from(raw as Map<String, dynamic>);
        final orderId = (row['ot_id'] ?? '').toString();
        if (orderId.isEmpty) continue;
        final materialName = (row['name'] ?? '').toString().trim();
        if (materialName.isEmpty) continue;
        materialCountByOtId[orderId] = (materialCountByOtId[orderId] ?? 0) + 1;
      }
    }

    final openItems =
        orders
            .where((row) {
              final status = (row['status'] ?? '').toString();
              return status != 'cerrado' && status != 'rechazado';
            })
            .map((row) {
              final updatedAt =
                  DateTime.tryParse((row['updated_at'] ?? '').toString()) ??
                  DateTime.tryParse((row['requested_at'] ?? '').toString());
              final status = (row['status'] ?? '').toString();
              return DirectionMaintenancePendingItem(
                id: (row['id'] ?? '').toString(),
                folio: (row['ot_folio'] ?? '').toString(),
                status: status,
                priority: (row['priority'] ?? '').toString(),
                impact: (row['impact'] ?? '').toString(),
                areaLabel: (row['area_label'] ?? '').toString(),
                equipmentLabel: (row['equipment_label'] ?? '').toString(),
                requestedAt: DateTime.tryParse(
                  (row['requested_at'] ?? '').toString(),
                ),
                updatedAt: DateTime.tryParse(
                  (row['updated_at'] ?? '').toString(),
                ),
                estimatedTotal: _toDouble(row['cost_estimated_total']),
                actualTotal: _toDouble(row['cost_actual_total']),
                waitingDirection:
                    status == 'cotizacion' || status == 'autorizacion_finanzas',
                ageHours: _hoursSince(updatedAt),
                missingReasons: _maintenanceMissingReasons(
                  status: status,
                  areaLabel: (row['area_label'] ?? '').toString(),
                  equipmentLabel: (row['equipment_label'] ?? '').toString(),
                  mechanicName: (row['mechanic_name'] ?? '').toString(),
                  mechanicContact: (row['mechanic_contact'] ?? '').toString(),
                  problemDescription: (row['problem_description'] ?? '')
                      .toString(),
                  diagnosis: (row['diagnosis'] ?? '').toString(),
                  workSummary: (row['work_summary'] ?? '').toString(),
                  assignedToName: (row['assigned_to_name'] ?? '').toString(),
                  materialCount:
                      materialCountByOtId[(row['id'] ?? '').toString()] ?? 0,
                ),
              );
            })
            .toList(growable: false)
          ..sort((a, b) {
            final scoreA = _maintenanceRiskScore(a);
            final scoreB = _maintenanceRiskScore(b);
            final riskCompare = scoreB.compareTo(scoreA);
            if (riskCompare != 0) return riskCompare;
            return b.ageHours.compareTo(a.ageHours);
          });

    final openCount = openItems.length;
    final criticalCount = openItems
        .where(
          (row) =>
              row.impact == 'paro_total' ||
              (row.priority == 'alta' && row.ageHours >= 24),
        )
        .length;
    final staleCount = openItems.where((row) => row.ageHours >= 48).length;
    final waitingDirectionCount = openItems
        .where((row) => row.waitingDirection)
        .length;
    final oldestHours = openItems.isEmpty ? 0.0 : openItems.first.ageHours;

    final alerts = <DirectionFollowupAlert>[];
    if (criticalCount > 0) {
      alerts.add(
        DirectionFollowupAlert(
          title: 'OT críticas sin resolución',
          detail:
              'Hay $criticalCount órdenes con paro total o prioridad alta que requieren seguimiento ejecutivo.',
          severity: DirectionFollowupSeverity.critical,
        ),
      );
    }
    if (waitingDirectionCount > 0) {
      alerts.add(
        DirectionFollowupAlert(
          title: 'OT esperando decisión o impulso',
          detail:
              'Hay $waitingDirectionCount órdenes en cotización o autorización financiera que siguen abiertas.',
          severity: waitingDirectionCount >= 4
              ? DirectionFollowupSeverity.warning
              : DirectionFollowupSeverity.info,
        ),
      );
    }
    if (staleCount > 0) {
      alerts.add(
        DirectionFollowupAlert(
          title: 'OT sin movimiento reciente',
          detail:
              'Hay $staleCount órdenes abiertas con más de 48 horas sin actualización.',
          severity: DirectionFollowupSeverity.warning,
        ),
      );
    }
    for (final entry in _topMissingReasonEntries(openItems, limit: 4)) {
      final severity = switch (entry.key) {
        'Aprobación financiera / Dirección' =>
          DirectionFollowupSeverity.critical,
        'Diagnóstico' ||
        'Responsable o mecánico' ||
        'Contacto del responsable' => DirectionFollowupSeverity.warning,
        _ => DirectionFollowupSeverity.info,
      };
      alerts.add(
        DirectionFollowupAlert(
          title: 'OT con faltante recurrente',
          detail:
              'Hay ${entry.value} órdenes de trabajo a las que les falta ${entry.key.toLowerCase()}.',
          severity: severity,
        ),
      );
    }
    if (alerts.isEmpty) {
      alerts.add(
        const DirectionFollowupAlert(
          title: 'Mantenimiento OT en seguimiento sano',
          detail: 'No hay alertas críticas de mantenimiento para Dirección.',
          severity: DirectionFollowupSeverity.info,
        ),
      );
    }

    return DirectionMaintenanceSummary(
      openCount: openCount,
      criticalCount: criticalCount,
      staleCount: staleCount,
      waitingDirectionCount: waitingDirectionCount,
      oldestHours: oldestHours,
      alerts: alerts,
      pendingItems: openItems.take(12).toList(growable: false),
    );
  }

  int _maintenanceRiskScore(DirectionMaintenancePendingItem row) {
    var score = 0;
    if (row.impact == 'paro_total') score += 100;
    if (row.impact == 'paro_parcial') score += 45;
    if (row.priority == 'alta') score += 50;
    if (row.waitingDirection) score += 35;
    if (row.ageHours >= 72) score += 40;
    if (row.ageHours >= 48) score += 24;
    if (row.ageHours >= 24) score += 12;
    return score;
  }

  List<String> _purchaseMissingReasons({
    required String status,
    required String targetLabel,
    required String vendorName,
    required String quoteContact,
    required String requestedByName,
    required int lineCount,
    required int invalidDescriptions,
    required int invalidQty,
    required int invalidAmount,
  }) {
    final reasons = <String>[];
    if (targetLabel.trim().isEmpty) reasons.add('Unidad o área');
    if (vendorName.trim().isEmpty) reasons.add('Proveedor');
    if (quoteContact.trim().isEmpty) reasons.add('Contacto');
    if (requestedByName.trim().isEmpty) reasons.add('Solicitante');
    if (lineCount <= 0) {
      reasons.add('Renglones');
    } else {
      if (invalidDescriptions > 0) reasons.add('Descripción en renglones');
      if (invalidQty > 0) reasons.add('Cantidad en renglones');
      if (invalidAmount > 0) reasons.add('Monto en renglones');
    }
    if (status == 'pending_direction') reasons.add('Aprobación de Dirección');
    if (status == 'rejected') reasons.add('Corrección y reenvío');
    return _dedupeReasons(reasons);
  }

  List<String> _maintenanceMissingReasons({
    required String status,
    required String areaLabel,
    required String equipmentLabel,
    required String mechanicName,
    required String mechanicContact,
    required String problemDescription,
    required String diagnosis,
    required String workSummary,
    required String assignedToName,
    required int materialCount,
  }) {
    final reasons = <String>[];
    if (areaLabel.trim().isEmpty) reasons.add('Área');
    if (equipmentLabel.trim().isEmpty) reasons.add('Equipo o unidad');
    if (problemDescription.trim().isEmpty) reasons.add('Descripción de falla');
    if (mechanicName.trim().isEmpty) reasons.add('Responsable o mecánico');
    if (mechanicContact.trim().isEmpty) reasons.add('Contacto del responsable');
    if ((status == 'cotizacion' || status == 'autorizacion_finanzas') &&
        diagnosis.trim().isEmpty) {
      reasons.add('Diagnóstico');
    }
    if ((status == 'programado' ||
            status == 'mantenimiento_realizado' ||
            status == 'supervision') &&
        workSummary.trim().isEmpty) {
      reasons.add('Resumen de trabajo');
    }
    if (assignedToName.trim().isEmpty &&
        status != 'aviso_falla' &&
        status != 'revision_area') {
      reasons.add('Asignación');
    }
    if (status == 'autorizacion_finanzas') {
      reasons.add('Aprobación financiera / Dirección');
    } else if (status == 'cotizacion') {
      reasons.add('Impulso para cotización');
    }
    if (materialCount <= 0 &&
        (status == 'material_recolectado' ||
            status == 'programado' ||
            status == 'mantenimiento_realizado' ||
            status == 'supervision')) {
      reasons.add('Materiales / refacciones / mano de obra');
    }
    return _dedupeReasons(reasons);
  }

  List<String> _dedupeReasons(List<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final normalized = value.trim();
      if (normalized.isEmpty) continue;
      if (!seen.add(normalized.toLowerCase())) continue;
      result.add(normalized);
    }
    return result;
  }

  List<MapEntry<String, int>> _topMissingReasonEntries(
    Iterable<dynamic> items, {
    int limit = 4,
  }) {
    final counts = <String, int>{};
    for (final item in items) {
      final reasons = switch (item) {
        DirectionPurchasePendingItem value => value.missingReasons,
        DirectionMaintenancePendingItem value => value.missingReasons,
        _ => const <String>[],
      };
      for (final reason in reasons) {
        counts[reason] = (counts[reason] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return a.key.compareTo(b.key);
      });
    return entries.take(limit).toList(growable: false);
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0;
  }

  double _hoursSince(DateTime? value) {
    if (value == null) return 0;
    return DateTime.now().difference(value).inMinutes / 60;
  }

  static String _moneyCompact(double value) {
    if (value >= 1000000) return '\$${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '\$${(value / 1000).toStringAsFixed(1)}k';
    return '\$${value.toStringAsFixed(0)}';
  }
}
