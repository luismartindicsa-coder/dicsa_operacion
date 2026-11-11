import 'package:flutter/material.dart';
import 'logistics_fuel_followup_store.dart';
import 'logistics_performance_data.dart';
import 'logistics_theme.dart';

// Read-only summary table and auxiliary dialogs, matching Rendimiento's existing
// source-detail flow. Editing amounts stays in the original homologated grids.
class LogisticsFuelFollowupPanel extends StatelessWidget {
  final List<LogisticsFuelFollowup> rows;
  final ValueChanged<LogisticsFuelFollowup> onOpen;
  const LogisticsFuelFollowupPanel({
    super.key,
    required this.rows,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Referencia de los últimos 30 días cerrados, junto a la última carga y el recorrido GPS.',
          style: TextStyle(color: kLogisticsSilverTextSecondary),
        ),
      ),
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            gradient: kLogisticsPanelGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kLogisticsSilverBorder),
          ),
          child: rows.isEmpty
              ? const Center(child: Text('No hay unidades con estos filtros.'))
              : LayoutBuilder(
                  builder: (context, size) => SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(12),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: (size.maxWidth - 24).clamp(
                            0,
                            double.infinity,
                          ),
                        ),
                        child: DataTable(
                          showCheckboxColumn: false,
                          columnSpacing: 24,
                          headingRowColor: const WidgetStatePropertyAll(
                            kLogisticsSilverSurfaceInteractive,
                          ),
                          dataRowMinHeight: 74,
                          dataRowMaxHeight: 94,
                          columns: const [
                            DataColumn(label: Text('UNIDAD')),
                            DataColumn(label: Text('ÚLTIMA CARGA')),
                            DataColumn(label: Text('LITROS ENTREGADOS')),
                            DataColumn(label: Text('RECORRIDO GPS')),
                            DataColumn(label: Text('KM/L CARGADO · 30 DÍAS')),
                          ],
                          rows: rows
                              .map(
                                (r) => DataRow(
                                  key: ValueKey(
                                    'load-followup-${r.unit.vehicleKey}',
                                  ),
                                  onSelectChanged: (_) => onOpen(r),
                                  cells: [
                                    DataCell(
                                      Text(
                                        r.unit.vehicleLabel,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        r.day == null
                                            ? 'Sin registro'
                                            : r.loadedAt == null
                                            ? '${fuelFollowupDate(r.day!.date)}${r.dayLoads.length > 1 ? '\n${r.dayLoads.length} cargas' : ''}'
                                            : fuelFollowupTime(r.loadedAt!),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        r.day == null
                                            ? '—'
                                            : '${r.estimatedLiters ? '≈ ' : ''}${r.liters.toStringAsFixed(1)} L${!r.hasTime && r.dayLoads.length > 1 ? '\nTotal del día' : ''}',
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 285,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(r.distanceLabel),
                                            if (r.day != null)
                                              Text(
                                                r.intervalLabel,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      kLogisticsSilverTextSecondary,
                                                ),
                                              ),
                                            if (r.mileage?.through != null)
                                              Text(
                                                'Hasta ${fuelFollowupTime(r.mileage!.through!)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      kLogisticsSilverTextSecondary,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 230,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r.performanceLabel,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              r.performanceNote,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    kLogisticsSilverTextSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'km/L cargado = kilómetros ÷ litros entregados de los 30 días hasta ayer. Con cargas parciales es una referencia, no consumo medido. Un valor parcial puede aumentar al completar los días sin km.',
          style: TextStyle(fontSize: 12, color: kLogisticsSilverTextSecondary),
        ),
      ),
    ],
  );
}

class LogisticsFuelFollowupDetail extends StatelessWidget {
  final LogisticsFuelFollowup row;
  final Future<void> Function(PerformanceDay, PerformanceLoad)? onSource;
  const LogisticsFuelFollowupDetail({
    super.key,
    required this.row,
    required this.onSource,
  });
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: kLogisticsSilverSurfaceElevated,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780, maxHeight: 680),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${row.unit.vehicleLabel} · Desde última carga',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar detalle',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Referencia · últimos 30 días cerrados'),
                    Text(
                      row.performanceLabel,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${fuelFollowupDate(row.performanceStart)} — ${fuelFollowupDate(row.performanceEnd)}',
                    ),
                    Text(
                      '${row.periodSummary.kilometerLabel} ÷ ${row.periodSummary.fuel.total.toStringAsFixed(1)} L',
                    ),
                    Text(
                      row.performanceNote,
                      style: const TextStyle(
                        color: kLogisticsSilverTextSecondary,
                      ),
                    ),
                    if (row.periodSummary.hasPartialPerformance)
                      const Text(
                        'Cálculo parcial con todos los litros del periodo y los kilómetros registrados. Puede aumentar al completar los días faltantes; no confirma un rendimiento bajo.',
                      ),
                    const Text(
                      'Con cargas parciales, los litros entregados pueden ser distintos de los consumidos.',
                    ),
                    const Divider(height: 28),
                    Text(
                      row.distanceLabel,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (row.day != null) Text(row.intervalLabel),
                    if (row.mileage?.through != null)
                      Text(
                        'Periodo observado: ${fuelFollowupTime(row.mileage!.from)} — ${fuelFollowupTime(row.mileage!.through!)}',
                      ),
                    if (row.mileage?.fetchedAt != null)
                      Text(
                        'Consultado: ${fuelFollowupTime(row.mileage!.fetchedAt!)}',
                      ),
                    if (!row.fresh)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'El recorrido está pendiente o requiere una actualización. No se interpreta como cero.',
                        ),
                      ),
                    if (!row.hasTime && row.day != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          row.kind == 'load_day'
                              ? 'Seguimiento por fecha: el recorrido de hoy incluye kilómetros anteriores y posteriores a la carga.'
                              : 'Seguimiento por fecha: el recorrido comienza al día siguiente de la carga; no incluye el día de carga.',
                        ),
                      ),
                    const Divider(height: 28),
                    Text(
                      row.day == null
                          ? 'Sin carga registrada'
                          : 'Cargas del ${fuelFollowupDate(row.day!.date)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    ...row.dayLoads.map(
                      (load) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${load.diesel ? 'Diésel' : 'Gasolina'} · ${load.litersEstimated ? '≈ ' : ''}${load.liters.toStringAsFixed(1)} L · ${load.driver}',
                            ),
                            if (onSource != null)
                              Wrap(
                                spacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => onSource!(row.day!, load),
                                    icon: const Icon(Icons.open_in_new_rounded),
                                    label: const Text('Abrir carga'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
