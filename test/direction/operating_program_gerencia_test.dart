import 'dart:convert';

import 'package:dicsa_operacion/app/direction/operating_program/operating_program_engine.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_models.dart';
import 'package:dicsa_operacion/app/direction/operating_program/operating_program_repository.dart';
import 'package:dicsa_operacion/app/gerencia/gerencia_bale_weekly_tracking_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final week = DateTime(2026, 9, 21);
  var version = 0;
  var failApproval = false;
  final writes = <http.Request>[];
  const goals = ['revuelto', 'limpio', 'americano'];
  final conditions = ProgramConditions.fromJson({
    'daily_capacity': 100,
    'day_share': 50,
    'yard': {for (final m in programMaterials) m: 0},
    'days': [
      for (var d = 0; d < 5; d++)
        {
          'working': true,
          'day_available': true,
          'night_available': true,
          'loss_percent': 0,
        },
    ],
  });
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://gerencia-program-test.invalid',
      anonKey: 'test-only-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        dynamic result = [];
        final table = request.url.pathSegments.last;
        if (request.method != 'GET') writes.add(request);
        if (table == 'direction_approve_operating_program') {
          if (failApproval) {
            return http.Response(
              jsonEncode({'code': 'PT409', 'message': 'La semana cambió'}),
              409,
              request: request,
            );
          }
          final execute =
              (jsonDecode(request.body) as Map)['p_execute'] == true;
          if (!execute) version++;
          result = {
            'id': 'program-$version',
            'week_start': programDate(week),
            'version': version,
            'status': execute ? 'executing' : 'approved',
            'is_operational': true,
            'conditions': conditions.toJson(),
            'shipments': [],
            'lines': emptyProgramLines().map((l) => l.toJson()).toList(),
          };
        } else if (table == 'gerencia_bale_type_catalog') {
          result = [
            for (final key in goals)
              {'key': key, 'label': key, 'sort_order': 1},
          ];
        } else if (table == 'gerencia_bale_weekly_plans' &&
            request.method == 'GET') {
          result = [
            {
              'id': 'plan',
              'week_start_date': programDate(week),
              'week_end_date': '2026-09-26',
              'source_operating_program_id': version == 0
                  ? null
                  : 'program-$version',
              'source_operating_program_version': version == 0 ? null : version,
              'operating_program_synced_at': version == 0
                  ? null
                  : '2026-09-21T12:00:00Z',
              'snapshot_production_actual_bales': 0,
              'snapshot_shipment_actual_bales': 0,
              'snapshot_production_target_bales': 3 * version * 30,
              'snapshot_shipment_target_bales': 3 * version * 40,
              'snapshot_refreshed_at': '2026-09-21T12:00:00Z',
            },
          ];
        } else if (table == 'gerencia_bale_weekly_plan_lines' &&
            request.method == 'GET') {
          result = [
            for (final key in goals)
              {
                'id': key,
                'bale_type_key': key,
                'sort_order': 1,
                'production_target_bales': version * 30,
                'shipment_target_bales': version * 40,
              },
          ];
        }
        return http.Response(
          jsonEncode(result),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  test(
    'approval refreshes cached Gerencia targets immediately; reapproval replaces them',
    () async {
      final notifications = <DateTime>[];
      final subscription = GerenciaBaleWeeklyTrackingStore.approvedPrograms
          .listen(notifications.add);
      addTearDown(subscription.cancel);
      final before = await GerenciaBaleWeeklyTrackingStore.loadWeek(week);
      expect(before.currentPlan!.totalProductionTarget, 0);
      expect(before.currentPlan!.hasOperatingProgram, isFalse);
      final repository = OperatingProgramRepository();
      await repository.approve('program-1');
      final first = await GerenciaBaleWeeklyTrackingStore.loadWeek(week);
      expect(first.currentPlan!.totalProductionTarget, 90);
      expect(first.currentPlan!.totalShipmentTarget, 120);
      expect(first.currentPlan!.sourceOperatingProgramVersion, 1);
      expect(first.currentPlan!.isLinkedMaterial('revuelto'), isTrue);
      expect(first.currentPlan!.isLinkedMaterial('otro'), isFalse);
      await repository.approve('program-2');
      final second = await GerenciaBaleWeeklyTrackingStore.loadWeek(week);
      expect(second.currentPlan!.totalProductionTarget, 180);
      expect(second.currentPlan!.totalShipmentTarget, 240);
      expect(second.currentPlan!.sourceOperatingProgramVersion, 2);
      await Future<void>.delayed(Duration.zero);
      expect(notifications, [week, week]);
      await repository.approve('program-2', execute: true);
      failApproval = true;
      await expectLater(
        repository.approve('program-3'),
        throwsA(isA<PostgrestException>()),
      );
      failApproval = false;
      await Future<void>.delayed(Duration.zero);
      expect(
        notifications,
        [week, week],
        reason: 'Execution and failed approval must not signal new goals',
      );
      expect(
        (await GerenciaBaleWeeklyTrackingStore.loadWeek(
          week,
        )).currentPlan!.sourceOperatingProgramVersion,
        2,
      );
      expect(
        writes.where(
          (r) =>
              r.url.pathSegments.last != 'direction_approve_operating_program',
        ),
        isEmpty,
        reason: 'The client must not perform a second non-atomic goal write',
      );
      final line = second.currentPlan!.lines.first;
      await GerenciaBaleWeeklyTrackingStore.updatePlanLine(
        line,
        productionTargetBales: 999,
        shipmentTargetBales: 999,
        notes: 'Nota',
        notesOnly: true,
      );
      expect(
        jsonDecode(writes.last.body),
        {'notes': 'Nota'},
        reason: 'Editing notes cannot resubmit stale linked targets',
      );
    },
  );
}
