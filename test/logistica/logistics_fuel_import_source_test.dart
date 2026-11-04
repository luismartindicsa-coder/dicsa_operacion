import 'package:dicsa_operacion/app/logistica/logistics_diesel_store.dart';
import 'package:dicsa_operacion/app/logistica/logistics_gasoline_store.dart';
import 'package:dicsa_operacion/app/logistica/logistics_performance_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'import estimates remain explicit and corrections do not inherit them',
    () {
      final diesel = LogisticsDieselConsumptionRecord.fromRemoteRow({
        'entry_date': '2026-10-23',
        'operator_name': 'ERNESTO RICO',
        'liters_purchased': 250,
        'liters_requested': 250,
        'source_metadata': {
          'total_amount': '6750.03',
          'estimated_liters': '250.00',
          'reference_price': '27.00',
        },
      });
      expect(diesel.vehicleId, isNull);
      expect(diesel.litersEstimated, isTrue);
      expect(
        diesel.importSource.note(250),
        contains('no es el precio comprobado'),
      );
      expect(diesel.copyWith(litersRequested: 245).litersEstimated, isFalse);
      expect(diesel.copyWith(operatorName: 'OTRO').litersEstimated, isTrue);
      // Operational edits must not write null over the original import evidence.
      expect(diesel.toUpsertJson().containsKey('source_metadata'), isFalse);
      final units = groupPerformanceUnits(
        LogisticsPerformanceData.consolidate(
          mileage: [],
          diesel: [diesel],
          gasoline: [],
          vehicles: [],
          services: [],
          sites: [],
          tanks: {},
          employees: [],
        ),
      );
      expect(units.single.vehicleLabel, 'Sin unidad');
      expect(units.single.warnings, contains('Incluye litros estimados'));
      expect(units.single.days.single.loads.single.litersEstimated, isTrue);
    },
  );

  test('gasoline imports retain exact amount and estimated quantity', () {
    final row = LogisticsGasolineControlRecord.fromRemoteRow({
      'entry_date': '2026-10-27',
      'vehicle_label': 'F2',
      'liters_loaded': '78.57',
      'source_metadata': {
        'total_amount': '1884.94',
        'estimated_liters': '78.57',
        'reference_price': '23.99',
      },
    });
    expect(row.litersEstimated, isTrue);
    expect(row.importSource.totalAmount, 1884.94);
    expect(row.copyWith(litersLoaded: 80).litersEstimated, isFalse);
    expect(row.toUpsertJson().containsKey('source_metadata'), isFalse);
    final old = LogisticsGasolineControlRecord.fromRemoteRow({
      'entry_date': '2026-10-20',
      'liters_loaded': 100,
    });
    expect(old.litersEstimated, isFalse);
    expect(old.importSource.totalAmount, isNull);
  });
}
