import 'dart:io';

import 'package:dicsa_operacion/app/commercial/commercial_store.dart';
import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/management_reports/accounting_weekly_analysis.dart';
import 'package:dicsa_operacion/app/management_reports/direction_weekly_source.dart';
import 'package:dicsa_operacion/app/management_reports/direction_weekly_summary.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_direction_pdf.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_history_store.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_registry.dart';
import 'package:dicsa_operacion/app/management_reports/operations_weekly_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

DirectionSummaryMetric metric(DirectionAreaSummary row, String label) =>
    row.metrics.firstWhere((m) => m.label == label);
CommercialMarketEventRecord trade(
  String source,
  String flow,
  String date,
  double amount,
) => CommercialMarketEventRecord.fromRow({
  'source_area': source,
  'source_event_id': '$source-$date',
  'event_at': date,
  'flow': flow,
  'volume_kg': 100,
  'amount_total': amount,
  'unit_price': 999,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final at = DateTime(2026, 9, 18, 17);
  final cut = AccountingWeeklyCut(at);
  test(
    'coverage retains all app areas including those without individual PDFs',
    () async {
      final rows = await collectDirectionAreaSummaries({
        DirectionSummaryArea.compras: () async => const DirectionAreaSummary(
          area: DirectionSummaryArea.compras,
          basis: 'Semana',
          metrics: [DirectionSummaryMetric('Compras', '\$1,000.00')],
        ),
        DirectionSummaryArea.finanzas: () async =>
            throw StateError('permission denied'),
        // Reject accidentally mismatched area data too.
        DirectionSummaryArea.boveda: () async => const DirectionAreaSummary(
          area: DirectionSummaryArea.compras,
          basis: '',
          metrics: [],
        ),
      });
      expect(rows.map((r) => r.area), DirectionSummaryArea.values);
      expect(
        rows.where((r) => r.available).single.area,
        DirectionSummaryArea.compras,
      );
      expect(
        rows.where((r) => !r.available).every((r) => r.metrics.isEmpty),
        isTrue,
      );
      expect(
        DirectionSummaryArea.values.map((a) => a.name),
        containsAll([
          'compras',
          'inventario',
          'almacen',
          'embarques',
          'boveda',
        ]),
      );
    },
  );
  test(
    'trade separates source areas and same weekdays, never prices or weekend activity',
    () {
      final events = [
        trade('mayoreo_compras', 'purchase', '2026-09-15', 500),
        trade('mayoreo_compras', 'purchase', '2026-09-08', 300),
        trade('mayoreo_compras', 'purchase', '2026-09-12', 99999),
        trade('menudeo', 'purchase', '2026-09-15', 700),
        trade('mayoreo_ventas', 'sale', '2026-09-15', 1000),
        trade('mayoreo_compras', 'unknown', '2026-09-15', 11111),
      ];
      final purchases = summarizeDirectionTrade(events, cut, purchases: true);
      expect(metric(purchases, 'Compras registradas').current, '\$500.00');
      expect(metric(purchases, 'Compras registradas').previous, '\$300.00');
      expect(metric(purchases, 'Precio ponderado por kg').current, '\$5.00');
      final sales = summarizeDirectionTrade(events, cut, purchases: false);
      expect(metric(sales, 'Ventas registradas').current, '\$1,000.00');
    },
  );
  test(
    'shipment quantities keep bales and kg separate, exclude cancelled and weekends',
    () {
      DirectionShipmentPlanRecord row(
        String date,
        String code,
        String unit,
        int quantity,
        String status,
      ) => DirectionShipmentPlanRecord.fromRow({
        'id': '$date-$code-$status',
        'ship_date': date,
        'planning_material_code': code,
        'quantity_unit': unit,
        'planned_units': quantity,
        'status': status,
      });
      final summary = summarizeDirectionShipments([
        row('2026-09-15', 'PACA_LIMPIA', 'bales', 100, 'embarcado'),
        row('2026-09-15', 'CHATARRA', 'kilograms', 2000, 'embarcado'),
        row('2026-09-15', 'PACA_LIMPIA', 'bales', 999, 'cancelado'),
        row('2026-09-15', 'PACA_LIMPIA', 'bales', 50, 'planeado'),
        row('2026-09-19', 'PACA_LIMPIA', 'bales', 800, 'embarcado'),
        row('2026-09-08', 'PACA_LIMPIA', 'bales', 70, 'embarcado'),
      ], cut);
      expect(metric(summary, 'Pacas marcadas embarcadas').current, '100');
      expect(metric(summary, 'Pacas marcadas embarcadas').previous, '70');
      expect(
        metric(summary, 'Kg a granel marcados embarcados').current,
        '2,000.00 kg',
      );
      expect(metric(summary, 'Embarques pendientes').current, '1');
    },
  );
  test(
    'warehouse excludes inactive items and inventory never combines levels',
    () {
      final warehouse = summarizeDirectionWarehouse([
        {'id': 'a', 'current_stock': 0, 'minimum_stock': 5, 'is_active': true},
        {'id': 'b', 'current_stock': 4, 'minimum_stock': 4, 'is_active': true},
        {'id': 'c', 'current_stock': 0, 'minimum_stock': 4, 'is_active': false},
      ]);
      expect(metric(warehouse, 'En mínimo o bajo mínimo').current, '2');
      expect(metric(warehouse, 'Sin existencias').current, '1');
      final inventory = summarizeDirectionInventory(
        [
          {'on_hand_kg': 1000},
        ],
        [
          {'on_hand_kg': -20},
        ],
      );
      expect(
        metric(inventory, 'Existencia en nivel general').current,
        '1,000.00 kg',
      );
      expect(
        metric(inventory, 'Existencia en nivel comercial').current,
        '-20.00 kg',
      );
      expect(inventory.alerts.single, contains('saldo negativo'));
    },
  );
  test(
    'missing maintenance amounts and production weights are never treated as known zero',
    () {
      final summary = summarizeDirectionOperations(
        OperationsWeeklySource(
          orders: [
            {'id': 'ot1', 'status': 'open', 'requested_at': '2026-09-14'},
          ],
          purchases: [
            {
              'id': 'oc1',
              'order_date': '2026-09-14',
              'status': 'purchased',
              'purchased_at': '2026-09-15',
              'linked_ot_id': 'ot1',
            },
          ],
          transformations: [],
          legacyProduction: [
            {
              'op_date': '2026-09-15',
              'bale_material': 'BALE_CLEAN',
              'bale_count': 10,
            },
          ],
        ),
        at,
      );
      expect(
        metric(summary, 'Compras ligadas a OT: real conocido').current,
        'Sin dato',
      );
      expect(
        metric(summary, 'Producción con peso registrado').current,
        'Sin dato',
      );
      expect(metric(summary, 'Unidades producidas').current, '10');
    },
  );
  test('local history counts areas once and cannot claim report delivery', () {
    final records = [
      for (var i = 0; i < 3; i++)
        ManagementReportRunRecord(
          areaKey: ManagementAreaKey.operaciones,
          frequency: ManagementReportFrequency.weeklyFriday,
          generatedAt: DateTime(2026, 9, 15),
          generatedBy: 'Prueba',
          fileName: '$i.pdf',
        ),
      ManagementReportRunRecord(
        areaKey: ManagementAreaKey.direccionGeneral,
        frequency: ManagementReportFrequency.weeklyFriday,
        generatedAt: DateTime(2026, 9, 15),
        generatedBy: 'Prueba',
        fileName: 'dir.pdf',
      ),
    ];
    final summary = summarizeDirectionHistory(records, cut);
    expect(
      metric(summary, 'Áreas con PDF de viernes en historial').current,
      '1 / 12',
    );
    expect(summary.notes.join(), contains('No acredita entrega'));
  });
  test('a total source outage cannot generate a misleading PDF', () async {
    await expectLater(
      buildDirectionWeeklySupervisionPdfBytes(
        area: managementAreaDefinition(ManagementAreaKey.direccionGeneral),
        generatedAt: at,
        generatedBy: 'Prueba',
        summaries: const [],
      ),
      throwsStateError,
    );
  });
  test(
    'complete and incomplete multi-area PDFs withstand long text and many alerts',
    () async {
      final out = Platform.environment['DICSA_DIRECTION_QA_DIR'];
      final long = List.filled(
        12,
        'Responsable de atención y seguimiento extraordinario',
      ).join(' ');
      for (final partial in [false, true]) {
        final summaries = [
          for (final area in DirectionSummaryArea.values)
            if (partial && area.index % 4 == 0)
              DirectionAreaSummary.unavailable(area)
            else
              DirectionAreaSummary(
                area: area,
                basis: 'Situación al corte / $long',
                metrics: [
                  for (var i = 0; i < 6; i++)
                    DirectionSummaryMetric(
                      'Indicador $i $long',
                      '\$1,234,567.89',
                      '\$987,654.32',
                    ),
                ],
                alerts: [for (var i = 0; i < 15; i++) 'Alerta $i $long'],
                notes: [long, long, long],
              ),
        ];
        final bytes = await buildDirectionWeeklySupervisionPdfBytes(
          area: managementAreaDefinition(ManagementAreaKey.direccionGeneral),
          generatedAt: partial ? DateTime(2026, 9, 16, 12) : at,
          generatedBy: 'QA · SIN DATOS PRODUCTIVOS',
          summaries: summaries,
        );
        expect(bytes.take(4), [37, 80, 68, 70]);
        if (out != null) {
          await Directory(out).create(recursive: true);
          await File(
            '$out/direccion_${partial ? 'incompleto' : 'denso'}.pdf',
          ).writeAsBytes(bytes);
        }
      }
    },
  );
}
