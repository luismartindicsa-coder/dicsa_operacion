import 'dart:math' as math;

import '../direction_shipments_store.dart';
import '../operating_program/operating_program_models.dart';
import 'expected_income_models.dart';

/// A forecast of the selected week's saved shipments, never a second ledger.
ExpectedIncomeProjection projectExpectedIncome({
  required DirectionShipmentPlanningBundle bundle,
  required ExpectedIncomeData data,
  required DateTime now,
}) {
  final today = incomeDay(now);
  final week = bundle.weekStartDate;
  final end = week.add(const Duration(days: 7));
  final nextEnd = week.add(const Duration(days: 14));
  final shipments =
      bundle.shipments
          .where(
            (s) =>
                s.quantityUnit == DirectionShipmentQuantityUnit.bales &&
                programMaterials.contains(s.materialCode) &&
                !s.shipDate.isBefore(week) &&
                s.shipDate.isBefore(end),
          )
          .toList()
        ..sort((a, b) {
          final date = a.shipDate.compareTo(b.shipDate);
          if (date != 0) return date;
          // Confirmed commitments reserve material before tentative shipments.
          final status = (a.status == 'confirmado' ? 0 : 1).compareTo(
            b.status == 'confirmado' ? 0 : 1,
          );
          return status != 0 ? status : a.id.compareTo(b.id);
        });
  final sales = {for (final s in data.sales) s.id: s};
  final matched = <String, IncomeSale>{};
  final claimed = {...data.externallyLinkedSales, ...data.links.values};
  final linkRisks = <String, String>{};
  for (final shipment in shipments) {
    final linked = data.links[shipment.id];
    if (linked == null) continue;
    final sale = sales[linked];
    if (sale != null && data.saleMatches(shipment, sale)) {
      matched[shipment.id] = sale;
    } else {
      linkRisks[shipment.id] =
          'Revisar vínculo con venta: cliente o material cambió.';
    }
  }
  // Automatic matching requires a unique candidate on BOTH sides. A sale can
  // never settle two shipments even when clients/dates/materials are identical.
  final candidates = <String, List<IncomeSale>>{};
  for (final shipment in shipments.where(
    (s) => s.status != 'cancelado' && !data.links.containsKey(s.id),
  )) {
    candidates[shipment.id] = data.sales
        .where(
          (sale) =>
              !claimed.contains(sale.id) &&
              !sale.cancelled &&
              data.saleMatches(shipment, sale) &&
              sale.date == shipment.shipDate,
        )
        .toList();
  }
  for (final entry in candidates.entries) {
    if (entry.value.length != 1) continue;
    final sale = entry.value.single;
    if (candidates.values
            .where((list) => list.any((s) => s.id == sale.id))
            .length ==
        1) {
      matched[entry.key] = sale;
    }
  }

  final report = bundle.suggestionReport;
  final stock = <String, int>{
    for (final m in programMaterials)
      m: math.max(
        0,
        report?.currentFloorByMaterial[m] ??
            bundle.floorCountByMaterial[m] ??
            0,
      ),
  };
  final remaining = Map<String, int>.from(stock);
  final supplies = [...data.supplies]
    ..sort((a, b) => a.availableDate.compareTo(b.availableDate));
  var supplyIndex = 0;
  final rows = <ExpectedIncomeRow>[];
  for (final shipment in shipments) {
    final risks = <String>[];
    final rule = data.ruleFor(shipment.clientName);
    final material = data.materials
        .where((r) => r.material == shipment.materialCode)
        .firstOrNull;
    final sale = matched[shipment.id];
    final overlapsCollection =
        sale == null &&
        data.collections.any(
          (c) =>
              c.saleDate == shipment.shipDate &&
              data.clientIdentity(c.client) ==
                  data.clientIdentity(shipment.clientName) &&
              incomeMaterial(c.material) == shipment.materialCode,
        );
    if (overlapsCollection) {
      risks.add(
        'Existe cobranza de Mayoreo para esta fecha, cliente y material. Vincular venta; la estimación no se suma mientras se concilia.',
      );
    }
    final cancelled = shipment.status == 'cancelado' || sale?.cancelled == true;
    final delivered = shipment.isShipped || sale != null;
    if (linkRisks[shipment.id] case final risk?) risks.add(risk);
    if (rule == null || !rule.active) {
      risks.add('Condiciones comerciales sin definir o inactivas.');
    }
    final kg =
        sale?.weight ??
        (material == null
            ? null
            : shipment.plannedQuantity * material.kgPerBale);
    final price =
        sale?.price ??
        data.clientMaterialPrices['${rule?.key ?? incomeKey(shipment.clientName)}|${shipment.materialCode}'] ??
        rule?.price ??
        material?.price;
    final value =
        sale?.approvedCents ??
        (kg == null || price == null ? null : incomeCents(kg * price));
    if (kg == null) risks.add('Peso promedio sin definir.');
    if (price == null && sale?.approvedCents == null) {
      risks.add('Precio sin definir.');
    }
    final revolving = rule?.revolving == true;
    final due = revolving
        ? null
        : sale?.dueDate ??
              (rule == null || !rule.active
                  ? null
                  : (sale?.date ?? shipment.shipDate).add(
                      Duration(days: rule.days),
                    ));
    var paid = sale?.paidCents ?? 0;
    if (sale?.settled == true && value != null) paid = value;
    paid = math.min(math.max(0, paid), value ?? paid);
    var state = cancelled
        ? IncomeState.cancelled
        : delivered
        ? (sale?.settled == true || value != null && value > 0 && paid >= value
              ? IncomeState.collected
              : sale?.accountStatus != null
              ? IncomeState.receivable
              : IncomeState.shipped)
        : IncomeState.projected;
    var missing = 0, stockUsed = 0;
    if (!cancelled && !delivered) {
      final deadline = shipment.shipDate.isBefore(today)
          ? today
          : shipment.shipDate;
      while (supplyIndex < supplies.length &&
          !supplies[supplyIndex].availableDate.isAfter(deadline)) {
        final supply = supplies[supplyIndex++];
        remaining.update(
          supply.material,
          (v) => v + supply.bales,
          ifAbsent: () => supply.bales,
        );
      }
      stockUsed = math.min(
        stock[shipment.materialCode] ?? 0,
        shipment.plannedQuantity,
      );
      stock[shipment.materialCode] =
          (stock[shipment.materialCode] ?? 0) - stockUsed;
      final available = remaining[shipment.materialCode] ?? 0;
      missing = math.max(0, shipment.plannedQuantity - available);
      // Keep deficits, so future shipments cannot reuse unfulfilled commitments.
      remaining[shipment.materialCode] = available - shipment.plannedQuantity;
      final floorEstimated =
          report?.estimatedFloorMaterials.contains(shipment.materialCode) ??
          bundle.floorCountFreshness != DirectionFloorCountFreshness.fresh;
      if (stockUsed == shipment.plannedQuantity &&
          !floorEstimated &&
          !week.isAfter(today)) {
        state = IncomeState.ready;
      }
      if (floorEstimated) {
        risks.add('Inventario estimado; validar conteo de piso.');
      }
      if (missing > 0) {
        risks.add(
          'Producción insuficiente: faltan $missing pacas al embarcar.',
        );
      }
      risks.add(
        shipment.shipDate.isBefore(today)
            ? 'Embarque pendiente con fecha vencida.'
            : 'Embarque pendiente.',
      );
      if (shipment.status == 'planeado') {
        risks.add('Embarque pendiente de aceptar.');
      }
    }
    if (!cancelled && delivered && sale == null) {
      risks.add('Vincular venta real para actualizar peso, precio y cobro.');
    }
    if (!cancelled &&
        due != null &&
        due.isBefore(today) &&
        state != IncomeState.collected) {
      risks.add(
        delivered
            ? 'Pago vencido.'
            : 'Fecha de cobro condicionada a embarque pendiente.',
      );
    }
    if (revolving && !cancelled) {
      risks.add(
        'Aplicación a cuenta revolvente; sin fecha de cobro ordinario.',
      );
    }
    rows.add(
      ExpectedIncomeRow(
        allocation: data.allocations[shipment.id],
        shipment: shipment,
        state: state,
        paymentType:
            sale?.paymentType ??
            (rule?.active == true ? rule?.paymentType : null),
        cashExcluded: overlapsCollection,
        kilograms: kg,
        price: price,
        valueCents: value,
        paidCents: cancelled ? 0 : paid,
        collectionDate: due,
        sale: sale,
        revolving: revolving,
        missingBales: missing,
        stockBales: stockUsed,
        risks: cancelled ? [] : risks,
      ),
    );
    if (rows.last.canAllocate && !rows.last.allocationApplied) {
      risks.add(
        rows.last.allocationStale
            ? 'El importe o la venta cambió; revisa la distribución Efectivo / Fiscal.'
            : 'Ingreso mixto por distribuir entre Efectivo y Fiscal.',
      );
    }
  }
  final current = IncomeTotals(),
      next = IncomeTotals(),
      later = IncomeTotals(),
      overdue = IncomeTotals(),
      undated = IncomeTotals();
  final timeline = <DateTime, IncomeTotals>{};
  for (final row in rows.where((r) => r.ordinary && r.pendingCents > 0)) {
    final date = row.collectionDate, type = row.paymentType;
    if (date == null || type == null) {
      for (final part in row.pendingByType.entries) {
        undated.add(part.key, part.value);
      }
      continue;
    }
    final bucket = date.isBefore(week)
        ? overdue
        : date.isBefore(end)
        ? current
        : date.isBefore(nextEnd)
        ? next
        : later;
    for (final part in row.pendingByType.entries) {
      bucket.add(part.key, part.value);
      timeline.putIfAbsent(date, IncomeTotals.new).add(part.key, part.value);
    }
  }
  final represented = rows
      .where((r) => r.state != IncomeState.cancelled && r.sale != null)
      .map((r) => r.sale!.id)
      .toSet();
  final collections = data.collections
      .where(
        (c) =>
            !represented.contains(c.accountId) &&
            data.ruleFor(c.client)?.revolving != true,
      )
      .toList();
  for (final collection in collections) {
    final date = collection.dueDate;
    final bucket = date.isBefore(week)
        ? overdue
        : date.isBefore(end)
        ? current
        : date.isBefore(nextEnd)
        ? next
        : later;
    bucket.add('FISCAL', collection.pendingCents);
    timeline
        .putIfAbsent(date, IncomeTotals.new)
        .add('FISCAL', collection.pendingCents);
  }
  final palomar = _projectPalomar(week, rows, data);
  // Availability is evaluated at the close of the selected week. Include one
  // possible draw in that week's cash forecast, keeping it separate from sales.
  // It has no agreed payment date, so do not invent a day in the timeline or
  // repeat the revolving credit limit in the next/later buckets.
  if (palomar.availableDraw > 0) {
    current.addFinancing('EFECTIVO', palomar.cash);
    current.addFinancing('FISCAL', palomar.fiscal);
  }
  return ExpectedIncomeProjection(
    collections: collections,
    rows: rows,
    current: current,
    next: next,
    later: later,
    overdue: overdue,
    undated: undated,
    timeline: timeline,
    palomar: palomar,
    warnings: data.warnings,
  );
}

PalomarIncomeProjection _projectPalomar(
  DateTime week,
  List<ExpectedIncomeRow> rows,
  ExpectedIncomeData data,
) {
  final end = week.add(const Duration(days: 7));
  var opening = 0, charges = 0, credits = 0, planned = 0;
  final applied = <String>{};
  for (final movement in data.palomarMovements.where(
    (m) => m.date.isBefore(end),
  )) {
    if (movement.reportId != null) applied.add(movement.reportId!);
    if (movement.date.isBefore(week)) {
      if (!movement.projected) opening += movement.signedCents;
    } else if (movement.signedCents > 0) {
      charges += movement.signedCents;
    } else {
      credits -= movement.signedCents;
    }
  }
  var complete = true;
  for (final row in rows.where(
    (r) => r.revolving && r.state != IncomeState.cancelled,
  )) {
    if (row.sale != null && applied.contains(row.sale!.id)) continue;
    if (row.valueCents == null) {
      complete = false;
      continue;
    }
    final amount = row.valueCents! * data.palomarConfig.shipmentEffect;
    planned += amount;
    if (amount > 0) {
      charges += amount;
    } else {
      credits -= amount;
    }
  }
  final config = data.palomarConfig;
  final closing = opening + charges - credits;
  final configured = config.creditLimit != null && config.drawAmount != null;
  final allowed =
      complete && configured && (!config.requireCovered || closing <= 0);
  final available = allowed
      ? math.min<int>(
          incomeCents(config.drawAmount!),
          math.max<int>(
            0,
            incomeCents(config.creditLimit!) - math.max<int>(0, closing),
          ),
        )
      : 0;
  final cash = math.min<int>(
    available,
    incomeCents(config.cashCheck1 + config.cashCheck2),
  );
  return PalomarIncomeProjection(
    opening: opening,
    charges: charges,
    credits: credits,
    plannedShipments: planned,
    closing: closing,
    availableDraw: available,
    cash: cash,
    fiscal: available - cash,
    configured: configured,
    complete: complete,
  );
}
