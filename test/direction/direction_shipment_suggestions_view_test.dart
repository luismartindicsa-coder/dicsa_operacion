import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/direction/direction_shipments_page.dart';
import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/direction_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'direction_shipment_suggestions_test.dart' as data;

DirectionShipmentPlanningBundle fixture({bool empty = false}) {
  final report = data.propose(floor: empty ? 0 : 100, production: []);
  return DirectionShipmentPlanningBundle(
    weekStartDate: data.week,
    weekEndDate: data.week.add(const Duration(days: 5)),
    shipments: const [],
    projections: const [],
    suggestedShipments: report.suggestions,
    floorCountByMaterial: const {},
    floorCountUpdatedAt: data.now,
    expectedDays: const [],
    activeCapacityImpacts: const [],
    impactSummaries: const [],
    maintenanceAlerts: const [],
    suggestionReport: report,
  );
}

void main() {
  setUpAll(() async {
    for (final family in ['Roboto', 'Ahem']) {
      final font = FontLoader(family);
      font.addFont(
        Future.value(
          ByteData.sublistView(
            await File('assets/fonts/Roboto-Regular.ttf').readAsBytes(),
          ),
        ),
      );
      await font.load();
    }
    final iconsPath = Platform.environment['DICSA_SUGGESTIONS_ICONS'];
    if (iconsPath != null) {
      final icons = FontLoader('MaterialIcons');
      icons.addFont(
        Future.value(ByteData.sublistView(await File(iconsPath).readAsBytes())),
      );
      await icons.load();
    }
  });

  Future<void> open(
    WidgetTester tester, {
    required ValueChanged<DirectionShipmentSuggestionSelection?> done,
    bool empty = false,
    GlobalKey? capture,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto'),
        ),
        builder: (_, child) => RepaintBoundary(key: capture, child: child!),
        home: Scaffold(
          backgroundColor: kDirectionBg,
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  done(
                    await showDialog<DirectionShipmentSuggestionSelection>(
                      context: context,
                      builder: (_) => DirectionSuggestedShipmentsDialog(
                        bundle: fixture(empty: empty),
                      ),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(1440, 1050), const Size(390, 844)]) {
    testWidgets(
      'review dialog fits ${size.width}, selects and confirms program input',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        DirectionShipmentSuggestionSelection? result;
        final capture = GlobalKey();
        await open(tester, done: (v) => result = v, capture: capture);
        expect(tester.takeException(), isNull);
        expect(find.text('30 pacas seleccionadas'), findsOneWidget);
        if (size.width > 1000) {
          final path = Platform.environment['DICSA_SUGGESTIONS_QA_PNG'];
          if (path != null) {
            await tester.runAsync(() async {
              final boundary =
                  capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final img = await boundary.toImage(pixelRatio: 1.5);
              final bytes = await img.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(path).writeAsBytes(bytes!.buffer.asUint8List());
              img.dispose();
            });
          }
        }
        final select = find.byKey(const ValueKey('select-suggestion-0'));
        await tester.ensureVisible(select);
        await tester.tap(select);
        await tester.pumpAndSettle();
        final confirm = find.byKey(
          const ValueKey('confirm-suggested-shipments'),
        );
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
        await tester.tap(select);
        await tester.pumpAndSettle();
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(result!.confirmForProgram, isTrue);
        expect(result!.shipments.single.suggestedQuantity, 30);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('saving retains planned status and Escape cancels review', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    DirectionShipmentSuggestionSelection? result;
    await open(tester, done: (v) => result = v);
    await tester.tap(find.text('Guardar selección'));
    await tester.pumpAndSettle();
    expect(result!.confirmForProgram, isFalse);
    result = null;
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(DirectionSuggestedShipmentsDialog), findsNothing);
    expect(result, isNull);
  });

  testWidgets('empty report explains unmet goal and cannot be accepted', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await open(tester, done: (_) {}, empty: true);
    expect(find.text('Sin embarques factibles para sugerir'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('confirm-suggested-shipments')),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
