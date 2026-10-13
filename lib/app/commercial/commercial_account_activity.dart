import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../direction/profitability/profitability_material_units.dart'
    show profitQuantityUnit, profitRetailSaleUnit, profitPurchaseUnit;
import '../shared/utils/fetch_all_supabase_rows.dart';
import '../shared/utils/number_formatters.dart';
import 'commercial_store.dart';

enum CommercialTradeFlow { purchase, sale }

/// Only the inputs needed for material averages; no folios or monetary totals.
class CommercialTradeSample {
  final String material, materialId, unit;
  final DateTime date;
  final double quantity, price;
  const CommercialTradeSample({
    required this.material,
    required this.materialId,
    required this.unit,
    required this.date,
    required this.quantity,
    required this.price,
  });
}

class CommercialMaterialAverage {
  final String material, unit;
  final double averageQuantity, averagePrice;
  const CommercialMaterialAverage({
    required this.material,
    required this.unit,
    required this.averageQuantity,
    required this.averagePrice,
  });
}

List<CommercialMaterialAverage> commercialMaterialAverages(
  List<CommercialTradeSample> samples, {
  required int days,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final start = DateTime(current.year, current.month, current.day - (days - 1));
  final end = DateTime(current.year, current.month, current.day + 1);
  final groups = <String, List<CommercialTradeSample>>{};
  for (final row in samples) {
    if (!row.quantity.isFinite ||
        row.quantity <= 0 ||
        !row.price.isFinite ||
        row.price < 0 ||
        !row.date.isBefore(end) ||
        (days > 0 && row.date.isBefore(start))) {
      continue;
    }
    groups
        .putIfAbsent(
          '${row.materialId.isEmpty ? row.material.trim().toUpperCase() : row.materialId}|${row.unit}',
          () => [],
        )
        .add(row);
  }
  final result = <CommercialMaterialAverage>[];
  for (final group in groups.values) {
    final quantity = group.fold<double>(0, (sum, row) => sum + row.quantity);
    result.add(
      CommercialMaterialAverage(
        material: group.first.material,
        unit: group.first.unit,
        averageQuantity: quantity / group.length,
        averagePrice:
            group.fold<double>(
              0,
              (sum, row) => sum + row.quantity * row.price,
            ) /
            quantity,
      ),
    );
  }
  result.sort((a, b) {
    final material = a.material.toUpperCase().compareTo(
      b.material.toUpperCase(),
    );
    return material != 0 ? material : a.unit.compareTo(b.unit);
  });
  return result;
}

class CommercialActivityStore {
  static Future<List<CommercialTradeSample>> load(
    CommercialDirectoryAccountRecord account, {
    required CommercialTradeFlow flow,
  }) async {
    final retail = account.sourceArea == 'menudeo';
    final purchase = flow == CommercialTradeFlow.purchase;
    if (account.sourceRecordId.isEmpty ||
        (!retail &&
            account.sourceArea !=
                (purchase ? 'mayoreo_compras' : 'mayoreo_ventas'))) {
      return [];
    }
    final client = Supabase.instance.client;
    final table = retail
        ? 'men_tickets'
        : purchase
        ? 'compras_tickets'
        : 'mayoreo_sales_reports';
    final dateColumn = retail || purchase ? 'ticket_date' : 'sale_date';
    final rows = await fetchAllSupabaseRows((from, to) {
      final query = client
          .from(table)
          .select(
            retail
                ? 'id,ticket_date,status,commercial_material_id,material_label_snapshot,counterparty_name_snapshot,payable_weight,price_at_entry,premium_per_kg'
                : purchase
                ? 'id,ticket_date,material_id,material_name_snapshot,provider_name_snapshot,payable_weight,price,premium'
                : 'id,sale_date,material_id,material_name_snapshot,approved_weight,approved_price',
          )
          .eq(
            retail
                ? 'counterparty_id'
                : purchase
                ? 'provider_id'
                : 'client_id',
            account.sourceRecordId,
          );
      return (retail
              ? query.eq('direction', purchase ? 'purchase' : 'sale')
              : query)
          .order(dateColumn, ascending: false)
          .order('id')
          .range(from, to);
    });
    final catalog = <String, Map<String, dynamic>>{};
    final cancelled = <String>{};
    if (!retail && rows.isNotEmpty) {
      final materials = await fetchAllSupabaseRows(
        (from, to) => client
            .from(
              purchase
                  ? 'compras_material_catalog'
                  : 'mayoreo_material_catalog',
            )
            .select('id,unit')
            .order('id')
            .range(from, to),
      );
      for (final material in materials) {
        catalog[material['id'].toString()] = material;
      }
      if (!purchase) {
        final cancellations = await fetchAllSupabaseRows(
          (from, to) => client
              .from('mayoreo_accounts')
              .select('id')
              .eq('client_id', account.sourceRecordId)
              .eq('status', 'cancelada')
              .order('id')
              .range(from, to),
        );
        cancelled.addAll(cancellations.map((row) => row['id'].toString()));
      }
    }
    final result = <CommercialTradeSample>[];
    for (final row in rows) {
      if (cancelled.contains(row['id'].toString()) ||
          [
            'cancelada',
            'cancelado',
          ].contains((row['status'] ?? '').toString().toLowerCase())) {
        continue;
      }
      final quantity =
          row[retail || purchase ? 'payable_weight' : 'approved_weight']
              as num?;
      final price =
          row[retail
                  ? 'price_at_entry'
                  : purchase
                  ? 'price'
                  : 'approved_price']
              as num?;
      // Pending approvals must not influence the commercial averages.
      if (quantity == null || price == null) continue;
      final materialId =
          (row[retail ? 'commercial_material_id' : 'material_id'] ?? '')
              .toString();
      result.add(
        CommercialTradeSample(
          material:
              (row[retail
                          ? 'material_label_snapshot'
                          : 'material_name_snapshot'] ??
                      '')
                  .toString(),
          materialId: materialId,
          unit: purchase
              ? profitPurchaseUnit(
                  row,
                  retail: retail,
                  catalog: catalog[materialId],
                )
              : retail
              ? profitRetailSaleUnit(row)
              : profitQuantityUnit(catalog[materialId]?['unit']),
          date: DateTime.parse(row[dateColumn].toString()).toLocal(),
          quantity: quantity.toDouble(),
          price:
              price.toDouble() +
              ((row[retail ? 'premium_per_kg' : 'premium'] as num?)
                      ?.toDouble() ??
                  0),
        ),
      );
    }
    return result;
  }
}

/// Summary tab inside the existing commercial master-detail workspace.
class CommercialAccountActivity extends StatefulWidget {
  final CommercialDirectoryAccountRecord account;
  const CommercialAccountActivity({super.key, required this.account});
  @override
  State<CommercialAccountActivity> createState() =>
      _CommercialAccountActivityState();
}

class _CommercialAccountActivityState extends State<CommercialAccountActivity> {
  late Future<List<CommercialTradeSample>> _future;
  late CommercialTradeFlow _flow;
  int _days = 90;
  @override
  void initState() {
    super.initState();
    _flow = widget.account.flow == 'purchase'
        ? CommercialTradeFlow.purchase
        : CommercialTradeFlow.sale;
    _future = CommercialActivityStore.load(widget.account, flow: _flow);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        widget.account.displayName,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 20,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<CommercialTradeFlow>(
            segments: const [
              ButtonSegment(
                value: CommercialTradeFlow.purchase,
                label: Text('Compras'),
              ),
              ButtonSegment(
                value: CommercialTradeFlow.sale,
                label: Text('Ventas'),
              ),
            ],
            selected: {_flow},
            onSelectionChanged: (selection) {
              final flow = selection.single;
              if (flow == _flow) return;
              setState(() {
                _flow = flow;
                _future = CommercialActivityStore.load(
                  widget.account,
                  flow: flow,
                );
              });
            },
          ),
          DropdownButton<int>(
            value: _days,
            items: const [
              DropdownMenuItem(value: 30, child: Text('Últimos 30 días')),
              DropdownMenuItem(value: 90, child: Text('Últimos 90 días')),
              DropdownMenuItem(value: 0, child: Text('Todo el historial')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _days = value);
            },
          ),
        ],
      ),
      const SizedBox(height: 12),
      Expanded(
        child: FutureBuilder<List<CommercialTradeSample>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No se pudo cargar el resumen.'),
                    TextButton(
                      onPressed: () => setState(() {
                        _future = CommercialActivityStore.load(
                          widget.account,
                          flow: _flow,
                        );
                      }),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }
            final rows = commercialMaterialAverages(
              snapshot.data ?? [],
              days: _days,
            );
            if (rows.isEmpty) {
              return Center(
                child: Text(
                  'Sin ${_flow == CommercialTradeFlow.purchase ? 'compras' : 'ventas'} confirmadas en el periodo.',
                ),
              );
            }
            return ListView(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 28,
                    columns: [
                      const DataColumn(label: Text('Material')),
                      DataColumn(
                        label: Tooltip(
                          message: 'Promedio por operación',
                          child: Text(
                            rows.every((row) => row.unit == 'KG')
                                ? 'Peso promedio'
                                : 'Peso / cantidad promedio',
                          ),
                        ),
                        numeric: true,
                      ),
                      const DataColumn(
                        label: Tooltip(
                          message: 'Promedio ponderado por peso o cantidad',
                          child: Text('Precio promedio'),
                        ),
                        numeric: true,
                      ),
                    ],
                    rows: rows
                        .map(
                          (row) => DataRow(
                            cells: [
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 220,
                                  ),
                                  child: Text(row.material),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${row.averageQuantity.toStringAsFixed(2)} ${row.unit == 'PENDIENTE' ? '(unidad por confirmar)' : row.unit}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${formatMoney(row.averagePrice)}${row.unit == 'PENDIENTE' ? '' : ' / ${row.unit}'}',
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}
