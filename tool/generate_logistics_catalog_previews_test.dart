// Read-only preview generator. Input is an explicit local catalog snapshot.
// DICSA_CATALOG_SNAPSHOT=/path/snapshot.json DICSA_CATALOG_OUTPUT=/path/output \
// flutter test tool/generate_logistics_catalog_previews_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/logistica/logistics_catalog_pdf.dart';
import 'package:dicsa_operacion/app/logistica/logistics_catalog_report_data.dart';
import 'package:dicsa_operacion/app/logistica/logistics_company_profile_store.dart';
import 'package:dicsa_operacion/app/logistica/logistics_container_store.dart';
import 'package:dicsa_operacion/app/logistica/logistics_resource_profile_store.dart';
import 'package:dicsa_operacion/app/logistica/logistics_zone_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final input = Platform.environment['DICSA_CATALOG_SNAPSHOT'];
  final output = Platform.environment['DICSA_CATALOG_OUTPUT'];
  test(
    'generate printable reports from a read-only snapshot',
    () async {
      final snapshot = jsonDecode(await File(input!).readAsString()) as Map;
      List<Map<String, dynamic>> rows(String table) => (snapshot[table] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      final sites = {for (final r in rows('sites')) r['id']: r};
      final employees = {for (final r in rows('employees')) r['id']: r};
      final sourceVehicles = {for (final r in rows('vehicles')) r['id']: r};
      final companies = rows('logistics_company_profiles')
          .where((r) => sites[r['site_id']]?['is_active'] == true)
          .map(
            (r) => LogisticsCompanyProfileRecord.fromRemoteRow({
              ...r,
              'site_name': sites[r['site_id']]!['name'],
            }),
          )
          .toList();
      final zones = rows(
        'logistics_zones',
      ).map(LogisticsZoneRecord.fromRemoteRow).toList();
      final drivers = rows('logistics_driver_profiles')
          .where((r) => employees[r['employee_id']]?['is_active'] == true)
          .map(
            (r) => LogisticsDriverProfileRecord.fromRemoteRow({
              ...r,
              'driver_name': employees[r['employee_id']]!['full_name'],
            }),
          )
          .toList();
      final vehicles = rows('logistics_vehicle_profiles')
          .where((r) => sourceVehicles[r['vehicle_id']]?['status'] == 'activo')
          .map(
            (r) => LogisticsVehicleProfileRecord.fromRemoteRow({
              ...r,
              'vehicle_code': sourceVehicles[r['vehicle_id']]!['code'],
              'serial_number':
                  sourceVehicles[r['vehicle_id']]!['serial_number'],
            }),
          )
          .toList();
      final containers = rows(
        'logistics_containers',
      ).map(LogisticsContainerRecord.fromRemoteRow).toList();
      final sections = [
        for (final kind in LogisticsCatalogKind.values)
          buildLogisticsCatalogPdfSection(
            kind: kind,
            companies: companies,
            zones: zones,
            drivers: drivers,
            vehicles: vehicles,
            containers: containers,
          ),
      ];
      final directory = await Directory(output!).create(recursive: true);
      // Supplied local edition time, or current system time for manual invocations.
      final date =
          DateTime.tryParse(
            Platform.environment['DICSA_CATALOG_EDITION'] ?? '',
          ) ??
          DateTime.now();
      for (final selected in [
        for (final section in sections) [section],
        sections,
      ]) {
        final bytes = await buildLogisticsCatalogPdf(
          sections: selected,
          generatedAt: date,
        );
        await File(
          '${directory.path}/${logisticsCatalogPdfFileName(selected, date)}',
        ).writeAsBytes(bytes);
      }
      await File('${directory.path}/verification_manifest.json').writeAsString(
        jsonEncode([
          for (final s in sections)
            {
              'kind': s.kind.fileKey,
              'total': s.totalCount,
              'records': [
                for (final r in s.records)
                  {
                    'id': r.id,
                    'title': r.title,
                    'fields': [
                      for (final f in r.fields)
                        {'label': f.label, 'value': f.value},
                    ],
                    'references': [
                      for (final f in r.references)
                        {'label': f.label, 'value': f.value},
                    ],
                  },
              ],
            },
        ]),
      );
    },
    skip: input == null || output == null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
