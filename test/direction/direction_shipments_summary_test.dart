import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/direction/direction_shipments_dashboard_card.dart';
import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/direction_shipments_summary.dart';
import 'package:dicsa_operacion/app/direction/direction_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final week = DateTime(2026, 9, 14);

DirectionShipmentPlanRecord shipment({
  int day = 14,
  String material = 'PACA_NACIONAL',
  String destination = 'San Pablo',
  String status = 'planeado',
  int quantity = 50,
  DirectionShipmentQuantityUnit unit = DirectionShipmentQuantityUnit.bales,
}) => DirectionShipmentPlanRecord.fromRow({
  'id': '$day-$material-$destination-$status',
  'ship_date': DateTime(2026, 9, day),
  'planning_material_code': material,
  'client_name': destination,
  'status': status,
  'planned_units': quantity,
  'quantity_unit': unit == DirectionShipmentQuantityUnit.bales ? 'bales' : 'kg',
});

DirectionShipmentsWeeklySummary summary(DateTime date) =>
    DirectionShipmentsWeeklySummary.fromShipments(date, [
      shipment(
        day: 16,
        material: 'PACA_LIMPIA',
        status: 'confirmado',
        quantity: 120,
      ),
      shipment(
        day: 16,
        material: 'PACA_LIMPIA',
        status: 'embarcado',
        quantity: 80,
      ),
      shipment(day: 15, destination: 'El Palomar', quantity: 60),
      shipment(
        day: 14,
        material: 'PACA_AMERICANA',
        destination: 'Bio Papel',
        status: 'embarcado',
        quantity: 90,
      ),
    ]);

Widget harness({
  required Future<DirectionShipmentsWeeklySummary> Function(DateTime) loader,
  Future<void> Function(DateTime)? onOpen,
  double width = 420,
  double textScale = 1,
  DateTime? initialWeek,
  GlobalKey? captureKey,
}) => MaterialApp(
  home: Scaffold(
    backgroundColor: kDirectionBg,
    body: Center(
      child: RepaintBoundary(
        key: captureKey,
        child: ColoredBox(
          color: kDirectionBg,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: SizedBox(
              width: width,
              height: 428,
              child: DirectionShipmentsDashboardCard(
                initialWeekStart: initialWeek ?? week,
                loadSummary: loader,
                onOpenShipments: onOpen ?? (_) async {},
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fontsPath = Platform.environment['DICSA_SHIPMENTS_QA_FONTS'];
    if (fontsPath == null) return;
    for (final (family, file) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(family);
      final bytes = await File('$fontsPath/$file').readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
  });

  test(
    'groups by date, bale type, destination and status without double counting',
    () {
      final result = DirectionShipmentsWeeklySummary.fromShipments(week, [
        shipment(quantity: 30),
        shipment(destination: ' SAN   PABLO ', quantity: 20),
        shipment(status: 'confirmado', quantity: 15),
        shipment(status: 'embarcado', quantity: 40),
        shipment(material: 'PACA_LIMPIA', quantity: 10),
        shipment(destination: 'El Palomar', quantity: 25),
        shipment(day: 15, quantity: 5),
      ]);
      expect(result.rows, hasLength(6));
      expect(result.pendingBales, 105);
      expect(result.shippedBales, 40);
      expect(result.totalBales, 145);
      expect(result.rows.first.date, DateTime(2026, 9, 15));
      expect(
        result.rows.where((r) => r.bales == 50).single.destination,
        'SAN PABLO',
      );
      expect(
        result.rows.where((r) => r.status == 'confirmado').single.statusLabel,
        'Confirmado',
      );
    },
  );

  test(
    'uses the planning week and excludes cancelled, bulk and invalid quantities',
    () {
      final result = DirectionShipmentsWeeklySummary.fromShipments(
        DateTime(2026, 9, 17, 23),
        [
          shipment(day: 13),
          shipment(day: 14, quantity: 12),
          shipment(day: 19, quantity: 18, status: 'embarcado'),
          shipment(day: 20),
          shipment(day: 21),
          shipment(status: 'cancelado'),
          shipment(
            material: 'CHATARRA',
            quantity: 9000,
            unit: DirectionShipmentQuantityUnit.kilograms,
          ),
          shipment(quantity: 0),
          shipment(quantity: -10),
        ],
      );
      expect(result.weekStart, week);
      expect(result.weekEnd, DateTime(2026, 9, 19));
      expect(result.totalBales, 30);
      expect(result.pendingBales, 12);
      expect(result.shippedBales, 18);
    },
  );

  test('keeps missing destinations visible and handles year boundaries', () {
    final result = DirectionShipmentsWeeklySummary.fromShipments(week, [
      shipment(destination: '  ', status: 'movido'),
    ]);
    expect(result.rows.single.destination, 'Sin destino');
    expect(result.rows.single.statusLabel, 'Movido');
    final empty = DirectionShipmentsWeeklySummary.fromShipments(
      DateTime(2027, 1, 1),
      [],
    );
    expect(empty.weekStart, DateTime(2026, 12, 28));
    expect(empty.weekEnd, DateTime(2027, 1, 2));
    expect(empty.totalBales, 0);
  });

  testWidgets('shows totals and all dimensions, and opens the selected week', (
    tester,
  ) async {
    DateTime? openedWeek;
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      harness(
        loader: (date) async => summary(date),
        onOpen: (date) async {
          openedWeek = date;
        },
        captureKey: captureKey,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('350'), findsOneWidget);
    expect(find.text('180'), findsOneWidget);
    expect(find.text('170'), findsOneWidget);
    expect(find.text('Paca limpia'), findsWidgets);
    expect(find.text('SAN PABLO'), findsWidgets);
    expect(find.text('Mié'), findsWidgets);
    expect(find.text('Confirmado'), findsOneWidget);
    expect(find.text('Embarcado'), findsWidgets);
    expect(tester.takeException(), isNull);

    final output = Platform.environment['DICSA_SHIPMENTS_QA_PNG'];
    if (output != null) {
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(output).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.byTooltip('Abrir Embarques'));
    await tester.pumpAndSettle();
    expect(openedWeek, week);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('week changes cannot display a late response from another week', (
    tester,
  ) async {
    final first = Completer<DirectionShipmentsWeeklySummary>();
    final previous = week.subtract(const Duration(days: 7));
    final requests = <DateTime>[];
    DateTime? openedWeek;
    await tester.pumpWidget(
      harness(
        loader: (date) {
          requests.add(date);
          if (date == week) return first.future;
          return Future.value(
            DirectionShipmentsWeeklySummary.fromShipments(date, []),
          );
        },
        onOpen: (date) async {
          openedWeek = date;
        },
      ),
    );
    await tester.tap(find.byTooltip('Semana anterior'));
    await tester.pump();
    first.complete(summary(week));
    await tester.pumpAndSettle();
    expect(requests, [week, previous]);
    expect(find.text('7 – 12 sep 2026'), findsOneWidget);
    expect(find.text('350'), findsNothing);
    expect(find.textContaining('Sin embarques'), findsOneWidget);
    await tester.tap(find.byTooltip('Abrir Embarques'));
    await tester.pumpAndSettle();
    expect(openedWeek, previous);
    await tester.tap(find.byTooltip('Semana actual'));
    await tester.pumpAndSettle();
    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
    );
    expect(next.onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'distinguishes load failure from an empty week and recovers automatically',
    (tester) async {
      var fail = true;
      await tester.pumpWidget(
        harness(
          loader: (date) async {
            if (fail) throw StateError('offline');
            return summary(date);
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudieron cargar'), findsOneWidget);
      expect(find.textContaining('Sin embarques'), findsNothing);
      expect(find.text('0'), findsNothing);
      fail = false;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('350'), findsOneWidget);
      fail = true;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('350'), findsOneWidget);
      expect(find.textContaining('último resumen'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'long destinations and many groups remain scrollable at compact widths',
    (tester) async {
      final data = DirectionShipmentsWeeklySummary.fromShipments(week, [
        for (var i = 0; i < 18; i++)
          shipment(
            destination:
                'CLIENTE CON NOMBRE LARGO Y DESTINO INDUSTRIAL ${i.toString().padLeft(2, '0')}',
          ),
      ]);
      for (final width in [420.0, 320.0]) {
        await tester.pumpWidget(
          harness(width: width, textScale: 1.2, loader: (_) async => data),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text(data.rows.last.destination),
          160,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text(data.rows.last.destination), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
