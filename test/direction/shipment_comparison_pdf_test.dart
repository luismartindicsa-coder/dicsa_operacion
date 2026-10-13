import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/execution/direction_execution_view.dart';
import 'package:dicsa_operacion/app/direction/execution/shipment_comparison_pdf.dart';
import 'package:dicsa_operacion/app/direction/execution/shipment_comparison_report.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'direction_execution_test.dart' as a;
import 'direction_execution_view_test.dart' as v;
import 'direction_shipment_suggestions_test.dart' as f;
import 'expected_income_export_test.dart' as e;
import 'expected_income_pdf_test.dart' as p;
import 'expected_income_view_test.dart' as app;

List<DirectionExecutionRow> sample({bool long = false}) => [
  DirectionExecutionRow(
    kind: 'shipment',
    date: f.week,
    material: f.national,
    client: 'MENDIETA',
    planned: 30,
    observed: 35,
    confirmation: a.actual(
      quantity: 30,
      planned: 40,
      observed: 35,
      loads: [30],
      agendaChanges: [
        DirectionExecutionAgendaChange(
          before: f.shipment('a', f.week, 40, status: 'confirmado'),
          after: f.shipment('a', f.week, 30),
        ),
      ],
    ),
  ),
  DirectionExecutionRow(
    kind: 'shipment',
    date: f.week,
    material: f.national,
    client: 'EL PALOMAR',
    confirmation: a.actual(quantity: 0, loads: [], observed: null, planned: 42),
  ),
  DirectionExecutionRow(
    kind: 'shipment',
    date: f.week.add(const Duration(days: 1)),
    material: f.national,
    client: 'BIO PAPEL',
    planned: 25,
    confirmation: a.actual(quantity: 25, planned: null),
  ),
  DirectionExecutionRow(
    kind: 'shipment',
    date: f.week.add(const Duration(days: 1)),
    material: 'PACA_AMERICANA',
    client: 'NEVADO',
    planned: 35,
    observed: 32,
  ),
  DirectionExecutionRow(
    kind: 'shipment',
    date: f.week.add(const Duration(days: 2)),
    material: f.national,
    client: 'SAN LUIS',
    planned: 20,
  ),
  DirectionExecutionRow(
    kind: 'shipment',
    date: f.week.add(const Duration(days: 3)),
    material: 'METAL',
    client: 'CLIENTE GRANEL',
    planned: 1500,
    observed: 1400,
  ),
  DirectionExecutionRow(
    kind: 'shipment',
    date: f.week.add(const Duration(days: 5)),
    material: f.national,
    client: 'QUERETANA',
    planned: 10,
  ),
  if (long)
    DirectionExecutionRow(
      kind: 'shipment',
      date: f.week,
      material: f.national,
      client:
          'INICIO DESTINO ${List.filled(150, 'PAPELERA INDUSTRIAL REGIONAL').join(' ')} FIN DESTINO',
      planned: 40,
      observed: 30,
      confirmation: DirectionExecutionActual(
        kind: 'shipment',
        date: f.week,
        material: f.national,
        client: 'EXTENSO',
        quantity: 30,
        plannedQuantity: 40,
        observedQuantity: 30,
        revision: 1,
        notes:
            'INICIO NOTA ${List.filled(150, 'OBSERVACION CONSERVADA COMPLETA').join(' ')} FIN NOTA',
      ),
    ),
];

ShipmentComparisonReport report({bool long = false}) =>
    ShipmentComparisonReport(
      week: f.week,
      generatedAt: f.week.add(const Duration(days: 3)),
      rows: sample(long: long),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Roboto', 'Ahem']) {
      await (FontLoader(family)..addFont(
            Future.value(
              ByteData.sublistView(
                await File('assets/fonts/Roboto-Regular.ttf').readAsBytes(),
              ),
            ),
          ))
          .load();
    }
  });
  test(
    'comparison uses original baseline, explicit zero and separate units',
    () {
      final r = report();
      final corrected = r.rows.singleWhere(
        (r) => r.source.client == 'MENDIETA',
      );
      expect(corrected.planned, 40);
      expect(corrected.actual, 30);
      expect(corrected.difference, -10);
      final zero = r.rows.singleWhere((r) => r.source.client == 'EL PALOMAR');
      expect(zero.actual, 0);
      expect(zero.difference, -42);
      expect(zero.status, 'Cancelado · real 0');
      final extra = r.rows.singleWhere((r) => r.source.client == 'BIO PAPEL');
      expect(extra.planned, isNull);
      expect(extra.difference, isNull);
      expect(extra.status, 'Adicional confirmado');
      expect(r.plannedFor('pacas'), 147);
      expect(r.confirmedFor('pacas'), 55);
      expect(r.plannedFor('kg'), 1500);
      expect(r.confirmedFor('kg'), 0);
      expect(r.pending, 2);
      expect(r.missing, 1);
      expect(r.future, 1);
      expect(r.rows.first.source.client, 'EL PALOMAR');
    },
  );
  test('unconfirmed and future readings never count as confirmed or zero', () {
    final r = report();
    final pending = r.rows.singleWhere((r) => r.source.client == 'NEVADO');
    expect(pending.actual, 32);
    expect(pending.confirmed, false);
    expect(pending.status, 'Por confirmar');
    final missing = r.rows.singleWhere((r) => r.source.client == 'SAN LUIS');
    expect(missing.actual, isNull);
    expect(missing.difference, isNull);
    final future = ShipmentComparisonReport(
      week: f.week,
      generatedAt: f.week,
      rows: [
        DirectionExecutionRow(
          kind: 'shipment',
          date: f.week.add(const Duration(days: 2)),
          material: f.national,
          client: 'FUTURO',
          planned: 40,
          observed: 30,
        ),
        DirectionExecutionRow(
          kind: 'shipment',
          date: f.week.add(const Duration(days: 7)),
          material: f.national,
          client: 'OTRA SEMANA',
          planned: 50,
        ),
      ],
    );
    expect(future.rows, hasLength(1));
    expect(future.rows.single.actual, isNull);
    expect(future.confirmedFor('pacas'), 0);
    expect(future.future, 1);
  });
  for (final scenario in ['normal', 'long', 'empty', 'legacy']) {
    test(
      'printable comparison PDF renders $scenario without changing source',
      () async {
        final r = scenario == 'empty'
            ? ShipmentComparisonReport(
                week: f.week,
                generatedAt: f.week,
                rows: [],
              )
            : report(long: scenario == 'long');
        final before = r.plannedFor('pacas');
        final bytes = await buildShipmentComparisonPdf(
          r,
          assetBundle: scenario == 'legacy' ? p.OldIncomeAssets() : null,
        );
        expect(p.pages(bytes), scenario == 'long' ? greaterThan(1) : 1);
        expect(r.plannedFor('pacas'), before);
        if (Platform.environment['DICSA_SHIPMENT_COMPARISON_QA'] == '1') {
          await File(
            '/private/tmp/dicsa-shipment-comparison-$scenario.pdf',
          ).writeAsBytes(bytes);
        }
      },
    );
  }
  testWidgets(
    'exports current week after refresh; cancel and save errors are recoverable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dir = Directory.systemTemp.createTempSync('shipment-comparison-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final picker = e.IncomeSavePicker()..path = '${dir.path}/comparativo';
      FilePicker.platform = picker;
      final repo = v.ActualRepo();
      var refreshes = 0, failRefresh = false;
      final busy = <bool>[];
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: app.app(
            DirectionExecutionView(
              kind: 'shipment',
              bundle: v.bundle(),
              repository: repo,
              asOf: f.week.add(const Duration(days: 3)),
              onWeekChanged: (_) async {},
              onChanged: () async {},
              onBusyChanged: busy.add,
              refreshReference: () async {
                refreshes++;
                if (failRefresh) throw StateError('Fuente no disponible');
                return v.bundle(observed: 37);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('export-shipment-comparison'));
      Future<void> export() async {
        final action = tester.widget<OutlinedButton>(button).onPressed;
        expect(action, isNotNull);
        await tester.runAsync(action! as Future<void> Function());
        await tester.pumpAndSettle();
      }

      if (Platform.environment['DICSA_SHIPMENT_COMPARISON_QA'] == '1') {
        await tester.runAsync(() async {
          final picture =
              await (capture.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final data = await picture.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/private/tmp/dicsa-shipment-comparison-button.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          picture.dispose();
        });
      }
      await export();
      expect(refreshes, 1);
      expect(picker.calls, 1);
      expect(repo.saved, isEmpty);
      expect(picker.name, 'embarques_planeado_vs_real_2026-09-21.pdf');
      final file = File('${dir.path}/comparativo.pdf');
      expect(p.pages(file.readAsBytesSync()), 1);
      expect(find.text('PDF guardado en ${file.path}'), findsOneWidget);
      if (Platform.environment['DICSA_SHIPMENT_COMPARISON_QA'] == '1') {
        file.copySync('/private/tmp/dicsa-shipment-comparison-refreshed.pdf');
      }
      picker.path = null;
      await export();
      expect(find.textContaining('no se eligió un archivo'), findsOneWidget);
      picker.error = const FileSystemException('No hay permiso');
      await export();
      expect(find.textContaining('No hay permiso'), findsOneWidget);
      picker.error = null;
      failRefresh = true;
      final calls = picker.calls;
      await export();
      expect(picker.calls, calls);
      expect(find.textContaining('Fuente no disponible'), findsOneWidget);
      expect(busy, [true, false, true, false, true, false, true, false]);
      await tester.binding.setSurfaceSize(const Size(650, 900));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
