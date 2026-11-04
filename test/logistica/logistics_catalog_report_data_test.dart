import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/logistica/logistics_catalog_pdf.dart';
import 'package:dicsa_operacion/app/logistica/logistics_catalog_report_data.dart';
import 'package:dicsa_operacion/app/logistica/logistics_company_profile_store.dart';
import 'package:dicsa_operacion/app/logistica/logistics_container_store.dart';
import 'package:dicsa_operacion/app/logistica/logistics_resource_profile_store.dart';

void main() {
  final companies = [
    LogisticsCompanyProfileRecord.fromRemoteRow({
      'site_id': 's1',
      'site_name': 'ALFA',
      'container_count': 99,
      'has_containers': true,
    }),
    LogisticsCompanyProfileRecord.fromRemoteRow({
      'site_id': 's2',
      'site_name': 'BETA',
    }),
  ];
  final drivers = [
    LogisticsDriverProfileRecord.fromRemoteRow({
      'employee_id': 'e1',
      'driver_name': 'ANA',
      'coverage_note': 'ALFA, PUNTO SIN CATALOGO',
      'coverage_import_pending': ['PUNTO SIN CATALOGO'],
      'logistics_driver_companies': [
        {
          'site_id': 's1',
          'sites': {'name': 'ALFA', 'is_active': true},
        },
      ],
    }),
  ];
  final vehicles = [
    LogisticsVehicleProfileRecord.fromRemoteRow({
      'vehicle_id': 'v1',
      'vehicle_code': 'C1',
      'assigned_driver_employee_id': 'e1',
      'model_year': 2020,
      'model_name': 'Modelo real',
    }),
  ];
  final containers = [
    LogisticsContainerRecord.fromRemoteRow({
      'id': 'c1',
      'container_label': 'A1',
      'site_id': 's1',
      'site_name': 'ALFA',
      'location_label': 'ALFA',
      'operator_employee_id': 'e1',
      'operator_name': 'ANA',
      'width_m': 2,
      'height_m': 0,
      'length_m': 4,
      'is_active': true,
    }),
    LogisticsContainerRecord.fromRemoteRow({
      'id': 'c2',
      'container_label': 'A2',
      'site_id': 's1',
      'is_active': false,
    }),
    LogisticsContainerRecord.fromRemoteRow({
      'id': 'c3',
      'container_label': 'A3',
      'site_name': 'ALFA',
      'location_label': 'ALFA',
      'is_active': true,
    }),
  ];
  LogisticsCatalogPdfSection section(
    LogisticsCatalogKind kind, {
    Set<String>? ids,
  }) => buildLogisticsCatalogPdfSection(
    kind: kind,
    companies: companies,
    zones: [],
    drivers: drivers,
    vehicles: vehicles,
    containers: containers,
    includedIds: ids,
    search: ids == null ? '' : 'ALFA',
  );
  Map<String, String> fields(LogisticsCatalogPdfRecord r) => {
    for (final f in r.fields) f.label: f.value,
  };

  test(
    'printed relationships use IDs, active containers, and filtered metrics',
    () {
      final s = section(LogisticsCatalogKind.companies, ids: {'s1'});
      expect(s.totalCount, 2);
      expect(s.records.length, 1);
      expect(fields(s.records.single)['Contenedores'], '1 asignados: A1');
      expect(fields(s.records.single)['Choferes'], 'ANA');
      expect(
        s.metrics.firstWhere((m) => m.label == 'Con contenedores').value,
        '1',
      );
      expect(s.search, 'ALFA');
    },
  );
  test('original coverage stays available without becoming an assignment', () {
    final driver = section(LogisticsCatalogKind.drivers).records.single;
    expect(fields(driver)['Unidades asignadas'], 'C1');
    expect(fields(driver)['Empresas asignadas'], 'ALFA');
    expect(fields(driver)['Otras referencias'], contains('sin vínculo'));
    expect(driver.references.single.value, 'ALFA, PUNTO SIN CATALOGO');
    final unit = section(LogisticsCatalogKind.vehicles).records.single;
    expect(fields(unit)['Cobertura del chofer'], 'ALFA');
    expect(fields(unit)['Año / modelo'], '2020 · Modelo real');
  });
  test('missing measurements remain pending and suggestions are not facts', () {
    final records = section(LogisticsCatalogKind.containers).records;
    expect(
      fields(records.first)['Dimensiones'],
      contains('Alto: No registrado'),
    );
    expect(fields(records.first).containsKey('Unidades compatibles'), isFalse);
    expect(fields(records.first).containsKey('Ubicación'), isFalse);
    expect(fields(records.last)['Empresa'], 'Sin asignación');
    expect(fields(records.last)['Ubicación'], 'ALFA');
  });
  test('only import metadata moves to references and no line is lost', () {
    const notes =
        'REPARAR COMPUERTA\nDATOS PENDIENTES DEL EXCEL: material.\nIMPORTADO DE Control contenedores.xlsx. FUENTES: hoja fila 2.\nOJO: observar soldadura';
    final split = splitLogisticsContainerReportNotes(notes);
    expect(split.$1, 'REPARAR COMPUERTA\nOJO: observar soldadura');
    expect(split.$2, contains('FUENTES: hoja fila 2.'));
    expect(
      '${split.$1}\n${split.$2}'.split('\n').toSet(),
      notes.split('\n').toSet(),
    );
  });
  test('printed order is natural and accented names are discoverable', () {
    final labels = ['I12', 'I7', 'A10', 'ÁNGEL', 'A2', 'I8'];
    labels.sort(compareLogisticsCatalogLabels);
    expect(labels, ['A2', 'A10', 'ÁNGEL', 'I7', 'I8', 'I12']);
  });
}
