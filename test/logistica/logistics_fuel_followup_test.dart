import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/logistica/logistics_fuel_followup_store.dart';
import 'package:dicsa_operacion/app/logistica/logistics_performance_data.dart';
import 'package:dicsa_operacion/app/logistica/logistics_performance_period.dart';
import 'package:dicsa_operacion/app/logistica/logistics_performance_store.dart';

void main() {
  final now = DateTime(2026, 11, 5, 13), yesterday = DateTime(2026, 11, 4);
  PerformanceLoad load({
    String id = 'load',
    double liters = 150,
    DateTime? at,
  }) => PerformanceLoad(
    id: id,
    vehicleId: 'v1',
    vehicleLabel: 'C1',
    diesel: true,
    liters: liters,
    driver: 'CHOFER',
    origin: 'patio',
    loadedAt: at,
  );
  PerformanceDay day(List<PerformanceLoad> loads, {DateTime? date}) {
    final d = PerformanceDay(
      date: date ?? yesterday,
      vehicleKey: 'id:v1',
      vehicleLabel: 'C1',
      vehicleId: 'v1',
      tankCapacityLiters: null,
    );
    d.loads.addAll(loads);
    return d;
  }

  LogisticsLoadMileage cache(
    PerformanceDay d, {
    String kind = 'after_load_day',
    DateTime? from,
    String status = 'ok',
  }) => LogisticsLoadMileage.fromRow({
    'vehicle_id': 'v1',
    'load_date': d.date.toIso8601String().substring(0, 10),
    'from_at': (from ?? d.date.add(const Duration(days: 1)))
        .toUtc()
        .toIso8601String(),
    'through_at': now
        .subtract(const Duration(minutes: 1))
        .toUtc()
        .toIso8601String(),
    'fetched_at': now.toUtc().toIso8601String(),
    'window_kind': kind,
    'status': status,
    'kilometers': 42.125,
    'load_snapshot': d.loads
        .map(
          (l) => {
            'id': l.id,
            'fuel': 'diesel',
            'liters': l.liters,
            'loaded_at': l.loadedAt?.toUtc().toIso8601String(),
          },
        )
        .toList(),
  });
  test(
    'rolling closed periods include 7/30 complete days across month and year boundaries',
    () {
      final seven = logisticsClosedPeriod('week', DateTime(2027, 1, 1, 10));
      expect(seven.start, DateTime(2026, 12, 25));
      expect(seven.end, DateTime(2026, 12, 31));
      final thirty = logisticsClosedPeriod('month', DateTime(2026, 3, 1));
      expect(thirty.start, DateTime(2026, 1, 30));
      expect(thirty.end, DateTime(2026, 2, 28));
    },
  );
  test(
    'date-only delivery excludes that day instead of inventing a delivery hour',
    () {
      final d = day([load()]);
      final follow = LogisticsFuelFollowup(PerformanceUnit([d]), now, cache(d));
      expect(follow.hasTime, false);
      expect(follow.from, DateTime(2026, 11, 5));
      expect(follow.fresh, true);
      expect(follow.distanceLabel, '42.1 km');
      expect(follow.performanceNote, 'Sin kilómetros del periodo');
      expect(follow.intervalLabel, 'Desde el día siguiente a la carga');
    },
  );
  test(
    'today total is explicitly distinct from distance after delivery, and resets at midnight',
    () {
      final d = day([load()], date: DateTime(2026, 11, 5));
      final c = cache(d, kind: 'load_day', from: d.date);
      final follow = LogisticsFuelFollowup(PerformanceUnit([d]), now, c);
      expect(follow.mileage, isNotNull);
      expect(follow.intervalLabel, contains('incluye antes'));
      expect(
        LogisticsFuelFollowup(
          PerformanceUnit([d]),
          DateTime(2026, 11, 6, 1),
          c,
        ).mileage,
        isNull,
      );
    },
  );
  test(
    'edited/new/deleted deliveries invalidate the cached provider window immediately',
    () {
      final d = day([load()]);
      final c = cache(d);
      expect(
        LogisticsFuelFollowup(
          PerformanceUnit([
            day([load(liters: 140)]),
          ]),
          now,
          c,
        ).mileage,
        isNull,
      );
      expect(
        LogisticsFuelFollowup(
          PerformanceUnit([
            day([load(at: yesterday.add(const Duration(hours: 10)))]),
          ]),
          now,
          c,
        ).mileage,
        isNull,
      );
      expect(
        LogisticsFuelFollowup(
          PerformanceUnit([
            day([load(id: 'new')]),
          ]),
          now,
          c,
        ).mileage,
        isNull,
      );
      expect(
        LogisticsFuelFollowup(PerformanceUnit([day([])]), now, c).day,
        isNull,
      );
    },
  );
  test(
    'same-day loads use actual last time only when every delivery has a known time',
    () {
      final one = load(at: yesterday.add(const Duration(hours: 10)));
      final two = load(id: 'second', liters: 50);
      var d = day([one, two]);
      var follow = LogisticsFuelFollowup(PerformanceUnit([d]), now, cache(d));
      expect(follow.hasTime, false);
      expect(follow.liters, 200);
      expect(follow.lastLoads, hasLength(2));
      final last = load(
        id: 'second',
        liters: 50,
        at: yesterday.add(const Duration(hours: 12)),
      );
      d = day([one, last]);
      follow = LogisticsFuelFollowup(
        PerformanceUnit([d]),
        now,
        cache(d, kind: 'since_load', from: last.loadedAt),
      );
      expect(follow.liters, 50);
      expect(follow.loadedAt, last.loadedAt);
      expect(follow.fresh, true);
      expect(follow.performanceNote, 'Sin kilómetros del periodo');
    },
  );
  LogisticsVehicleMileageRecord reading(PerformanceDay d, double km) =>
      LogisticsVehicleMileageRecord(
        id: null,
        entryDate: d.date,
        vehicleId: d.vehicleId,
        vehicleLabel: d.vehicleLabel,
        vehicleKey: d.vehicleKey,
        kilometers: km,
        sourceFileName: 'test',
      );

  test(
    '30-day reference includes earlier partial loads and excludes today, live km and older history',
    () {
      final closed = day([load(liters: 55.44)]);
      closed.mileage = reading(closed, 518.137);
      final earlier = day([
        load(id: 'earlier', liters: 655.75),
      ], date: DateTime(2026, 10, 27));
      earlier.mileage = reading(earlier, 2071.255);
      final first = day([
        load(id: 'first', liters: 95.19),
      ], date: DateTime(2026, 10, 6));
      first.mileage = reading(first, 100);
      final current = day([
        load(id: 'today', liters: 150),
      ], date: DateTime(2026, 11, 5));
      current.mileage = reading(current, 900);
      final old = day([
        load(id: 'old', liters: 1000),
      ], date: DateTime(2026, 10, 5));
      old.mileage = reading(old, 50);
      final follow = LogisticsFuelFollowup(
        PerformanceUnit([closed, earlier, first, current, old]),
        now,
        cache(current, kind: 'load_day', from: current.date),
      );
      expect(follow.unit.tankCapacityLiters, isNull);
      expect(follow.performanceStart, DateTime(2026, 10, 6));
      expect(follow.performanceEnd, yesterday);
      expect(follow.periodSummary.kilometers, closeTo(2689.392, .000001));
      expect(follow.periodSummary.fuel.total, closeTo(806.38, .000001));
      expect(follow.performanceLabel, '3.34 km/L');
      expect(follow.performanceNote, 'Referencia por litros cargados');
      // The short cut can be high because earlier fuel is outside it.
      expect(PerformanceUnit([closed]).performanceLabel, '9.35 km/L');
      expect(follow.liters, 150);
      expect(follow.mileage!.kilometers, 42.125);
    },
  );

  test(
    'partial km/L retains all fuel and becomes complete only when the missing reading arrives',
    () {
      final measured = day([load(liters: 100)]);
      measured.mileage = reading(measured, 500);
      final missing = day([
        load(id: 'missing', liters: 50),
      ], date: DateTime(2026, 10, 20));
      final follow = LogisticsFuelFollowup(
        PerformanceUnit([measured, missing]),
        now,
        null,
      );
      expect(follow.performanceLabel, '3.33 km/L (parcial)');
      expect(follow.performanceNote, '1 día con km · 1 sin km');
      expect(follow.periodSummary.performance, isNull);
      expect(follow.periodSummary.fuel.total, 150);
      expect(missing.mileage, isNull);
      missing.mileage = reading(missing, 0);
      expect(follow.performanceLabel, '3.33 km/L');
      expect(follow.periodSummary.performance, closeTo(500 / 150, .000001));
      expect(follow.performanceNote, 'Referencia por litros cargados');
      missing.loads.add(
        const PerformanceLoad(
          id: 'gas',
          vehicleId: 'v1',
          vehicleLabel: 'C1',
          diesel: false,
          liters: 10,
          driver: 'CHOFER',
          origin: 'gasolinera',
        ),
      );
      expect(follow.performanceLabel, 'Sin estimación');
      expect(follow.performanceNote, 'Combustibles mezclados');
    },
  );

  test(
    'a GPS gap without a load or service stays missing but does not hide the available reference',
    () {
      final measured = day([load(liters: 100)]);
      measured.mileage = reading(measured, 500);
      final gap = day([], date: DateTime(2026, 11, 1));
      gap.gpsMileage = LogisticsGpsDailyMileage.fromRow({
        'provider_unit_id': '1',
        'entry_date': '2026-11-01',
        'vehicle_id': 'v1',
        'vehicle_label': 'C1',
        'status': 'no_data',
        'message_count': 0,
      });
      final follow = LogisticsFuelFollowup(
        PerformanceUnit([measured, gap]),
        now,
        null,
      );
      expect(follow.performanceLabel, '5.00 km/L (parcial)');
      expect(follow.periodSummary.missingMileageDays, 1);
      expect(gap.mileage, isNull);
      expect(gap.gpsMileage!.status, 'no_data');
      measured.mileage = null;
      expect(follow.performanceLabel, 'Sin estimación');
      expect(follow.performanceNote, 'Sin kilómetros del periodo');
    },
  );
  test('errors and stale snapshots keep the GPS freshness warning', () {
    final d = day([load(at: yesterday.add(const Duration(hours: 12)))]);
    final c = cache(
      d,
      kind: 'since_load',
      from: d.loads.single.loadedAt,
      status: 'error',
    );
    expect(LogisticsFuelFollowup(PerformanceUnit([d]), now, c).fresh, false);
    expect(
      LogisticsFuelFollowup(PerformanceUnit([d]), now, c).distanceLabel,
      contains('revisar actualización'),
    );
    expect(
      LogisticsFuelFollowup(PerformanceUnit([d]), now, null).distanceLabel,
      'Pendiente de GPS',
    );
  });
}
