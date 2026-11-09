import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gps_reconciliation.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gps_reconciliation_panel.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gps_visit_store.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gps_curation_store.dart';

void main() {
  setUpAll(() async {
    final config = File('.dart_tool/package_config.json');
    final packages =
        jsonDecode(await config.readAsString())['packages'] as List;
    final root = config.absolute.uri.resolve(
      '${packages.singleWhere((p) => p['name'] == 'flutter')['rootUri']}/',
    );
    for (final font in ['Roboto', 'MaterialIcons']) {
      final file = File.fromUri(
        root.resolve(
          '../../bin/cache/artifacts/material_fonts/${font == 'Roboto' ? 'Roboto-Regular.ttf' : 'MaterialIcons-Regular.otf'}',
        ),
      );
      await (FontLoader(
        font,
      )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  final day = DateTime.utc(2026, 11, 5);
  final now = DateTime.utc(2026, 11, 5, 19);
  GpsDailyService service({
    String id = 's1',
    String? vehicle = 'u1',
    String? site = 'c1',
    String status = 'programado',
    String date = '2026-11-05',
    String? due,
    String company = 'AVON',
  }) => GpsDailyService.fromRow(
    {
      'id': id,
      'vehicle_id': vehicle,
      'client_id': site,
      'status': status,
      'service_date': date,
      'due_date': due,
      'client_name': company,
    },
    {?site: company},
    {?vehicle: 'C1'},
  );
  LogisticsGpsVisit visit({
    String id = 'v1',
    String vehicle = 'u1',
    String site = 'c1',
    String company = 'AVON',
    int seconds = 300,
    bool gap = false,
    String status = 'closed',
    String start = '2026-11-05T18:00:00Z',
  }) {
    final started = DateTime.parse(start);
    final end = started.add(Duration(seconds: seconds)).toIso8601String();
    return LogisticsGpsVisit.fromRow({
      'id': id,
      'provider_unit_id': 'provider1',
      'vehicle_id': vehicle,
      'site_id': site,
      'unit_label': 'C1',
      'place_label': company,
      'geofence_name': company,
      'classification': 'company',
      'arrival_kind': 'arrival',
      'status': status,
      'started_at': start,
      'last_inside_at': end,
      'ended_at': status == 'closed' ? end : null,
      'has_gap': gap,
    });
  }

  List<GpsDailyMatch> cross(
    List<GpsDailyService> services,
    List<LogisticsGpsVisit> visits,
  ) => reconcileGpsDay(day: day, services: services, visits: visits);

  test('five minute boundary, Celaya exclusion and ID-based matching', () {
    expect(
      cross([service()], [visit(seconds: 299)]).single.kind,
      GpsMatchKind.noVisit,
    );
    expect(cross([service()], [visit()]).single.kind, GpsMatchKind.matched);
    expect(
      cross([service()], [visit(status: 'open')]).single.kind,
      GpsMatchKind.matched,
    );
    expect(cross([], [visit(company: 'Dicsa · Celaya')]), isEmpty);
    expect(cross([service(company: 'DICSA CELAYA')], []), isEmpty);
    final renamed = cross([service(company: 'Nombre nuevo')], [visit()]);
    expect(renamed.single.kind, GpsMatchKind.matched);
    final differentIds = cross([service()], [visit(site: 'c2')]);
    expect(
      differentIds.map((r) => r.kind),
      containsAll([GpsMatchKind.noVisit, GpsMatchKind.noService]),
    );
  });
  test(
    'duplicates on either side require review without consuming a visit twice',
    () {
      final repeated = cross([service(), service(id: 's2')], [visit()]);
      expect(repeated.length, 2);
      expect(repeated.every((r) => r.kind == GpsMatchKind.review), isTrue);
      expect(
        cross([service()], [visit(), visit(id: 'v2')]).single.kind,
        GpsMatchKind.review,
      );
    },
  );
  test('missing links and interrupted observations are not confirmations', () {
    expect(
      cross([service(vehicle: null)], []).single.kind,
      GpsMatchKind.review,
    );
    expect(
      cross([service()], [visit(gap: true)]).single.kind,
      GpsMatchKind.review,
    );
    expect(
      cross([], [visit(status: 'interrupted')]).single.kind,
      GpsMatchKind.review,
    );
  });
  test(
    'operational date uses Celaya midnight, due date and frozen observations',
    () {
      expect(gpsOperationalDay(DateTime.parse('2026-11-06T05:59:59Z')), day);
      expect(
        gpsOperationalDay(DateTime.parse('2026-11-06T06:00:00Z')),
        DateTime.utc(2026, 11, 6),
      );
      expect(
        cross(
          [service(date: '2026-11-04', due: '2026-11-05')],
          [visit()],
        ).single.kind,
        GpsMatchKind.matched,
      );
      expect(
        cross([service()], [visit(start: '2026-11-06T04:00:00Z')]).single.kind,
        GpsMatchKind.matched,
      );
      expect(
        cross([service()], [visit(start: '2026-11-05T05:58:00Z')]).single.kind,
        GpsMatchKind.review,
      );
      expect(
        cross(
          [service()],
          [visit(status: 'open', start: '2026-11-04T18:00:00Z')],
        ).single.kind,
        GpsMatchKind.noVisit,
      );
    },
  );
  test('cancelled services do not confirm a visit', () {
    expect(
      cross([service(status: 'cancelado')], [visit()]).single.kind,
      GpsMatchKind.noService,
    );
  });

  test('simultaneous geofences cannot confirm two different destinations', () {
    final rows = cross([service()], [visit(), visit(id: 'v2', site: 'c2')]);
    expect(rows.length, 2);
    expect(rows.every((r) => r.kind == GpsMatchKind.review), isTrue);
  });

  for (final width in [800.0, 1440.0]) {
    testWidgets('comparison search, refresh and failure fit at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var fail = false, reads = 0;
      Future<List<GpsDailyService>> load(DateTime _) async {
        reads++;
        if (fail) throw StateError('offline');
        return [
          service(),
          service(id: 's2', vehicle: 'u2', site: 'c2', company: 'SETEX'),
        ];
      }

      Widget screen(DateTime time, {bool active = true}) => MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('capture'),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: LogisticsGpsReconciliationPanel(
                bundle: LogisticsGpsVisitBundle(
                  visits: [visit()],
                  status: 'ok',
                  lastRunAt: now,
                ),
                curation: const GpsCuration(available: true),
                now: time,
                active: active,
                sourceFresh: true,
                loadServices: load,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen(now, active: false));
      await tester.pump();
      expect(reads, 0);
      await tester.pumpWidget(screen(now));
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(find.text('Todos (2)'), findsOneWidget);
      expect(find.text('Sin asignar (2)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width == 1440) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture')),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/dicsa-gps-reconciliation.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.enterText(
        find.byKey(const ValueKey('reconciliation-search')),
        'SETEX',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('reconciliation-service-s1')),
        findsNothing,
      );
      await tester.pumpWidget(screen(now.add(const Duration(seconds: 30))));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('reconciliation-search')),
            )
            .controller!
            .text,
        'SETEX',
      );
      fail = true;
      await tester.pumpWidget(screen(now.add(const Duration(seconds: 60))));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No se pudo consultar Control Diario'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reconciliation-service-s2')),
        findsNothing,
      );
      fail = false;
      await tester.pumpWidget(screen(now.add(const Duration(seconds: 90))));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('reconciliation-service-s2')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
