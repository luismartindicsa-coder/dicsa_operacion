import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gps_reconciliation.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gps_reconciliation_panel.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gps_curation_store.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gps_visit_store.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gps_stop_store.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gps_visits_panel.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gps_stops_panel.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gps_trash_widgets.dart';

void main() {
  final now = DateTime.utc(2026, 11, 5, 19);
  Map<String, dynamic> visitRow(String id) => {
    'id': id,
    'provider_unit_id': 'provider',
    'vehicle_id': 'u1',
    'site_id': 'c1',
    'unit_label': 'C1',
    'place_label': 'AVON',
    'geofence_name': 'Avon',
    'classification': 'company',
    'status': 'closed',
    'arrival_kind': 'arrival',
    'started_at': '2026-11-05T18:00:00Z',
    'last_inside_at': '2026-11-05T18:10:00Z',
    'ended_at': '2026-11-05T18:11:00Z',
    'has_gap': false,
  };
  final visit = LogisticsGpsVisit.fromRow(visitRow('v1'));
  GpsDailyService service(String id, {String status = 'programado'}) =>
      GpsDailyService.fromRow(
        {
          'id': id,
          'vehicle_id': 'u1',
          'client_id': 'c1',
          'service_date': '2026-11-05',
          'status': status,
          'direction': 'RECOLECCION',
          'scheduled_time': '12:00:00',
        },
        {'c1': 'AVON'},
        {'u1': 'C1'},
      );
  GpsTrashEntry entry(String kind) => GpsTrashEntry.fromRow({
    'id': 'trash-$kind',
    'visit_id': kind == 'visit' ? 'v1' : null,
    'stop_id': kind == 'stop' ? 'stop1' : null,
    'reason': 'No ocurrió',
    'discarded_at': now.toIso8601String(),
    'event_snapshot': visitRow('v1'),
  });

  testWidgets('completed services disappear with or without a GPS assignment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var completed = false;
    final curation = GpsCuration(
      available: true,
      assignments: [
        GpsAssignment.fromRow({
          'id': 'previous',
          'service_id': 'already-linked',
          'visit_id': 'v2',
          'note': '',
          'assigned_at': now.toIso8601String(),
          'visit_snapshot': visitRow('v2'),
        }),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LogisticsGpsReconciliationPanel(
            bundle: LogisticsGpsVisitBundle(
              visits: [visit],
              status: 'ok',
              lastRunAt: now,
            ),
            now: now,
            active: true,
            sourceFresh: true,
            curation: curation,
            loadServices: (_) async => [
              service('s1', status: completed ? 'completado' : 'programado'),
              service('already-linked', status: 'completado'),
              service('without-visit', status: 'completado'),
            ],
            saveAssignment: (_, _, _, _) async {
              completed = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('reconciliation-service-already-linked')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('reconciliation-service-without-visit')),
      findsNothing,
    );
    expect(find.text('Todos (1)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reconciliation-service-s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-v1')));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(
      find.byKey(const ValueKey('reconciliation-service-s1')),
      findsNothing,
    );
    expect(find.text('Todos (0)'), findsOneWidget);
  });

  for (final drag in [false, true]) {
    testWidgets(
      '${drag ? 'drag' : 'button'} assigns, persists after rebuild and releases visit',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var curation = const GpsCuration(available: true);
        late StateSetter redraw;
        var writes = 0;
        Future<void> save(
          String s,
          String? v,
          String? expected,
          String note,
        ) async {
          writes++;
          expect(s, 's1');
          expect(expected, v == null ? 'a1' : null);
          curation = GpsCuration(
            available: true,
            assignments: v == null
                ? []
                : [
                    GpsAssignment.fromRow({
                      'id': 'a1',
                      'service_id': s,
                      'visit_id': v,
                      'note': note,
                      'assigned_at': now.toIso8601String(),
                      'visit_snapshot': visitRow(v),
                    }),
                  ],
          );
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  redraw = setState;
                  return LogisticsGpsReconciliationPanel(
                    bundle: LogisticsGpsVisitBundle(
                      visits: [visit],
                      status: 'ok',
                      lastRunAt: now,
                    ),
                    now: now,
                    active: true,
                    sourceFresh: true,
                    curation: curation,
                    loadServices: (_) async => [service('s1'), service('s2')],
                    saveAssignment: save,
                    onChanged: () async {
                      redraw(() {});
                    },
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (drag) {
          final from =
              tester.getTopLeft(find.byKey(const ValueKey('drag-v1'))) +
              const Offset(25, 25);
          final to = tester.getCenter(find.byKey(const ValueKey('drop-s1')));
          await tester.timedDragFrom(
            from,
            to - from,
            const Duration(milliseconds: 800),
          );
        } else {
          await tester.tap(
            find.byKey(const ValueKey('reconciliation-service-s1')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('assign-v1')));
        }
        await tester.pumpAndSettle();
        expect(writes, 1);
        expect(find.byKey(const ValueKey('unassign-s1')), findsOneWidget);
        expect(find.byKey(const ValueKey('drag-v1')), findsNothing);
        redraw(() {});
        await tester.pumpAndSettle();
        expect(find.text('Asignados (1)'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('unassign-s1')));
        await tester.pumpAndSettle();
        expect(writes, 2);
        expect(find.byKey(const ValueKey('drag-v1')), findsOneWidget);
        expect(find.text('Asignados (0)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failed assignment leaves visit available and service unassigned',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogisticsGpsReconciliationPanel(
              bundle: LogisticsGpsVisitBundle(
                visits: [visit],
                status: 'ok',
                lastRunAt: now,
              ),
              now: now,
              active: true,
              sourceFresh: true,
              curation: const GpsCuration(available: true),
              loadServices: (_) async => [service('s1')],
              saveAssignment: (_, _, _, _) async => throw StateError('offline'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reconciliation-service-s1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assign-v1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('drag-v1')), findsOneWidget);
      expect(find.byKey(const ValueKey('unassign-s1')), findsNothing);
      expect(find.textContaining('No se pudo guardar'), findsOneWidget);
    },
  );

  for (final kind in ['visit', 'stop']) {
    testWidgets(
      '$kind trash requires reason and restores without deleting source',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var curation = const GpsCuration(available: true);
        late StateSetter redraw;
        var discarded = 0, restored = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  redraw = setState;
                  return Column(
                    children: [
                      GpsTrashButton(
                        kind: kind,
                        eventId: kind == 'visit' ? 'v1' : 'stop1',
                        label: 'C1',
                        enabled: curation.trash.isEmpty,
                        onChanged: () async => redraw(() {}),
                        discard: (k, id, reason) async {
                          expect(k, kind);
                          expect(reason, 'No ocurrió');
                          discarded++;
                          curation = GpsCuration(
                            available: true,
                            trash: [entry(kind)],
                          );
                        },
                      ),
                      Expanded(
                        child: LogisticsGpsTrashPanel(
                          curation: curation,
                          onChanged: () async => redraw(() {}),
                          restore: (id) async {
                            expect(id, 'trash-$kind');
                            restored++;
                            curation = const GpsCuration(available: true);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('A papelera'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Guardar'),
              )
              .onPressed,
          isNull,
        );
        await tester.enterText(
          find.byKey(const ValueKey('gps-review-reason')),
          'No ocurrió',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        expect(discarded, 1);
        expect(find.text('Motivo: No ocurrió'), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('restore-trash-$kind')));
        await tester.pumpAndSettle();
        expect(restored, 1);
        expect(curation.trash, isEmpty);
        expect(visit.id, 'v1');
      },
    );
  }
  testWidgets(
    'working lists hide trash and assigned visits cannot be discarded',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final curation = GpsCuration(
        available: true,
        trash: [entry('visit'), entry('stop')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogisticsGpsVisitsPanel(
              bundle: LogisticsGpsVisitBundle(visits: [visit]),
              now: now,
              curation: curation,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('visit-v1')), findsNothing);
      final stop = LogisticsGpsStop.fromRow({
        'id': 'stop1',
        'provider_unit_id': '1',
        'unit_label': 'C1',
        'status': 'open',
        'latitude': 20.0,
        'longitude': -100.0,
        'started_at': '2026-11-05T18:00:00Z',
        'last_stationary_at': '2026-11-05T18:10:00Z',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogisticsGpsStopsPanel(
              bundle: LogisticsGpsStopBundle(stops: [stop]),
              now: now,
              curation: curation,
              geofences: const [],
              onChanged: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stop-stop1')), findsNothing);
      final assigned = GpsCuration(
        available: true,
        assignments: [
          GpsAssignment.fromRow({
            'id': 'a1',
            'service_id': 's1',
            'visit_id': 'v1',
            'note': '',
            'assigned_at': now.toIso8601String(),
            'visit_snapshot': visitRow('v1'),
          }),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogisticsGpsVisitsPanel(
              bundle: LogisticsGpsVisitBundle(visits: [visit]),
              now: now,
              curation: assigned,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('trash-visit-v1')))
            .onPressed,
        isNull,
      );
    },
  );
}
