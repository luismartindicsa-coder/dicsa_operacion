import 'logistics_catalog_pdf.dart';
import 'logistics_company_profile_store.dart';
import 'logistics_container_store.dart';
import 'logistics_resource_profile_store.dart';
import 'logistics_zone_store.dart';

/// Read-only presentation of catalog data. Relationships always use IDs;
/// compatibility suggestions and old free text never become assignments.
LogisticsCatalogPdfSection buildLogisticsCatalogPdfSection({
  required LogisticsCatalogKind kind,
  required List<LogisticsCompanyProfileRecord> companies,
  required List<LogisticsZoneRecord> zones,
  required List<LogisticsDriverProfileRecord> drivers,
  required List<LogisticsVehicleProfileRecord> vehicles,
  required List<LogisticsContainerRecord> containers,
  Set<String>? includedIds,
  String search = '',
}) {
  bool includes(String id) => includedIds == null || includedIds.contains(id);
  String joined(Iterable<String> values, {String empty = 'Sin asignación'}) {
    final labels = values.where((v) => v.trim().isNotEmpty).toSet().toList()
      ..sort(compareLogisticsCatalogLabels);
    return labels.isEmpty ? empty : labels.join(', ');
  }

  String value(String text) =>
      text.trim().isEmpty ? 'No registrado' : text.trim();
  String units(String employeeId) => joined(
    vehicles
        .where((v) => v.assignedDriverEmployeeId == employeeId)
        .map((v) => v.vehicleCode),
  );
  String companyDrivers(String siteId) => joined(
    drivers
        .where((d) => d.assignedCompanies.any((c) => c.siteId == siteId))
        .map((d) => d.driverName),
  );
  List<LogisticsContainerRecord> companyContainers(String siteId) =>
      containers.where((c) => c.active && c.siteId == siteId).toList();
  String number(double v, String suffix, {int decimals = 2}) =>
      v > 0 ? '${v.toStringAsFixed(decimals)} $suffix' : 'No registrado';
  LogisticsCatalogPdfField field(String label, String text) =>
      LogisticsCatalogPdfField(label, value(text));
  LogisticsCatalogPdfField metric(String label, int count) =>
      LogisticsCatalogPdfField(label, '$count');
  final zoneById = {for (final z in zones) z.id: z};
  final driverById = {for (final d in drivers) d.employeeId: d};
  final companyById = {for (final c in companies) c.siteId: c};
  late List<LogisticsCatalogPdfRecord> records;
  late int total;
  late List<LogisticsCatalogPdfField> metrics;
  switch (kind) {
    case LogisticsCatalogKind.companies:
      total = companies.length;
      final rows = companies.where((r) => includes(r.siteId)).toList();
      metrics = [
        metric(
          'Con chofer asignado',
          rows
              .where(
                (r) => drivers.any(
                  (d) => d.assignedCompanies.any((c) => c.siteId == r.siteId),
                ),
              )
              .length,
        ),
        metric(
          'Con contenedores',
          rows.where((r) => companyContainers(r.siteId).isNotEmpty).length,
        ),
        metric(
          'Con contacto',
          rows
              .where(
                (r) =>
                    r.operationalContact.isNotEmpty ||
                    r.contactPhone.isNotEmpty,
              )
              .length,
        ),
      ];
      records = rows.map((r) {
        final zone = zoneById[r.zoneId];
        final assigned = companyContainers(r.siteId);
        return LogisticsCatalogPdfRecord(
          id: r.siteId,
          title: r.siteName,
          status: r.active ? 'Activa' : 'Inactiva',
          fields: [
            field('Dirección', r.addressLine),
            if (r.addressReference.trim().isNotEmpty)
              field('Referencia', r.addressReference),
            field(
              'Contacto',
              [
                r.operationalContact,
                r.contactPhone,
              ].where((v) => v.isNotEmpty).join(' · '),
            ),
            field(
              'Zona',
              zone == null ? 'Sin asignación' : '${zone.code} · ${zone.name}',
            ),
            field('Horario', r.pickupWindow),
            if (r.scheduleFlexibility != 'POR_DEFINIR' || r.earlyPickupRequired)
              field(
                'Condiciones',
                [
                  if (r.scheduleFlexibility != 'POR_DEFINIR')
                    logisticsScheduleFlexibilityLabel(r.scheduleFlexibility),
                  if (r.earlyPickupRequired) 'Recolección temprana',
                ].join(' · '),
              ),
            field('Choferes', companyDrivers(r.siteId)),
            field(
              'Contenedores',
              assigned.isEmpty
                  ? 'Sin asignación'
                  : '${assigned.length} asignados: ${joined(assigned.map((c) => c.containerLabel))}',
            ),
            if (r.containerCapacityNote.trim().isNotEmpty)
              field('Capacidad', r.containerCapacityNote),
            if (r.notes.trim().isNotEmpty) field('Observaciones', r.notes),
          ],
          references: [
            if (r.latitude != null && r.longitude != null)
              field(
                'Coordenadas',
                '${r.latitude!.toStringAsFixed(5)}, ${r.longitude!.toStringAsFixed(5)}',
              ),
            if (r.zoneNotes.trim().isNotEmpty)
              field('Notas de zona', r.zoneNotes),
            if (r.collectionUrgency != 'MEDIA')
              field(
                'Prioridad registrada',
                logisticsCollectionUrgencyLabel(r.collectionUrgency),
              ),
            if (r.volumePressure != 'POR_DEFINIR')
              field(
                'Volumen registrado',
                logisticsVolumePressureLabel(r.volumePressure),
              ),
          ],
        );
      }).toList();
    case LogisticsCatalogKind.zones:
      final active = zones.where((r) => r.active).toList();
      total = active.length;
      final rows = active.where((r) => includes(r.id)).toList();
      final ids = rows.map((r) => r.id).toSet();
      metrics = [
        metric(
          'Empresas asignadas',
          companies.where((r) => ids.contains(r.zoneId)).length,
        ),
      ];
      records = rows
          .map(
            (r) => LogisticsCatalogPdfRecord(
              id: r.id,
              title: '${r.code} · ${r.name}',
              status: 'Activa',
              fields: [
                field(
                  'Localidad',
                  [r.city, r.state].where((s) => s.isNotEmpty).join(', '),
                ),
                field('Cobertura', r.coverageHint),
                field(
                  'Empresas',
                  joined(
                    companies
                        .where((c) => c.zoneId == r.id)
                        .map((c) => c.siteName),
                  ),
                ),
                if (r.notes.trim().isNotEmpty) field('Observaciones', r.notes),
              ],
            ),
          )
          .toList();
    case LogisticsCatalogKind.drivers:
      total = drivers.length;
      final rows = drivers.where((r) => includes(r.employeeId)).toList();
      metrics = [
        metric(
          'Con unidad asignada',
          rows
              .where(
                (r) => vehicles.any(
                  (v) => v.assignedDriverEmployeeId == r.employeeId,
                ),
              )
              .length,
        ),
        metric(
          'Con empresas',
          rows.where((r) => r.assignedCompanies.isNotEmpty).length,
        ),
        metric(
          'Fuera de programación',
          rows.where((r) => r.planningStatus == 'NO_PROGRAMAR').length,
        ),
      ];
      records = rows
          .map(
            (r) => LogisticsCatalogPdfRecord(
              id: r.employeeId,
              title: r.driverName,
              status: _planningLabel(r.planningStatus),
              fields: [
                field('Unidades asignadas', units(r.employeeId)),
                field(
                  'Tipos de unidad',
                  joined(
                    r.compatibleUnitTypes.map(_unitLabel),
                    empty: 'No registrado',
                  ),
                ),
                field(
                  'Empresas asignadas',
                  joined(
                    r.assignedCompanies.map(
                      (c) => '${c.siteName}${c.active ? '' : ' (inactiva)'}',
                    ),
                  ),
                ),
                if (r.coverageImportPending.isNotEmpty)
                  field(
                    'Otras referencias',
                    '${r.coverageImportPending.join(', ')} (sin vínculo a empresa)',
                  ),
                if (r.coverageNote.trim().isNotEmpty &&
                    r.assignedCompanies.isEmpty)
                  field('Cobertura registrada', r.coverageNote),
                if (r.notes.trim().isNotEmpty)
                  field('Documentación y notas', r.notes),
              ],
              references: [
                if (r.coverageNote.trim().isNotEmpty &&
                    r.assignedCompanies.isNotEmpty)
                  field('Cobertura original', r.coverageNote),
              ],
            ),
          )
          .toList();
    case LogisticsCatalogKind.vehicles:
      total = vehicles.length;
      final rows = vehicles.where((r) => includes(r.vehicleId)).toList();
      metrics = [
        metric(
          'Con chofer asignado',
          rows.where((r) => r.assignedDriverEmployeeId != null).length,
        ),
        metric(
          'Sin chofer asignado',
          rows.where((r) => r.assignedDriverEmployeeId == null).length,
        ),
        metric(
          'Fuera de programación',
          rows.where((r) => r.planningStatus == 'NO_PROGRAMAR').length,
        ),
      ];
      records = rows.map((r) {
        final driver = driverById[r.assignedDriverEmployeeId];
        return LogisticsCatalogPdfRecord(
          id: r.vehicleId,
          title: r.vehicleCode,
          status: _planningLabel(r.planningStatus),
          fields: [
            field('Tipo', _unitLabel(r.logisticsUnitType)),
            field(
              'Chofer asignado',
              driver?.driverName ??
                  (r.assignedDriverEmployeeId == null
                      ? 'Sin asignación'
                      : 'Nombre no disponible'),
            ),
            field(
              'Año / modelo',
              [
                r.modelYear == null ? 'Año no registrado' : '${r.modelYear}',
                r.modelName.isEmpty ? 'Modelo no registrado' : r.modelName,
              ].join(' · '),
            ),
            if (r.serialNumber.trim().isNotEmpty)
              field('Número de serie', r.serialNumber),
            field(
              'Tipo de carga',
              joined(
                r.compatibleLoadTypes.map(logisticsLoadTypeLabel),
                empty: 'No registrado',
              ),
            ),
            field(
              'Tanque',
              r.tankCapacityLiters == null
                  ? 'No registrado'
                  : number(r.tankCapacityLiters!, 'L', decimals: 1),
            ),
            if (r.capacityNote.trim().isNotEmpty)
              field('Descripción registrada', r.capacityNote),
            if (driver != null && driver.assignedCompanies.isNotEmpty)
              field(
                'Cobertura del chofer',
                joined(driver.assignedCompanies.map((c) => c.siteName)),
              ),
            if (r.notes.trim().isNotEmpty) field('Observaciones', r.notes),
          ],
        );
      }).toList();
    case LogisticsCatalogKind.containers:
      total = containers.length;
      final rows = containers
          .where((r) => includes(r.id ?? r.containerLabel))
          .toList();
      metrics = [
        metric(
          'Con empresa asignada',
          rows.where((r) => r.siteId != null).length,
        ),
        metric(
          'Con chofer asignado',
          rows.where((r) => r.operatorEmployeeId != null).length,
        ),
        metric(
          'Con medidas completas',
          rows
              .where((r) => r.widthM > 0 && r.heightM > 0 && r.lengthM > 0)
              .length,
        ),
      ];
      records = rows.map((r) {
        final notes = splitLogisticsContainerReportNotes(r.notes);
        final location = r.locationLabel.trim();
        final company = companyById[r.siteId]?.siteName ?? r.siteName;
        final date =
            '${r.entryDate.day.toString().padLeft(2, '0')}/${r.entryDate.month.toString().padLeft(2, '0')}/${r.entryDate.year}';
        final importedDate = r.notes.contains('FECHA ORIGINAL NO CAPTURADA.');
        return LogisticsCatalogPdfRecord(
          id: r.id ?? r.containerLabel,
          title: r.containerLabel,
          status: r.active ? 'Activo' : 'Inactivo',
          fields: [
            field(
              'Empresa',
              r.siteId == null ? 'Sin asignación' : value(company),
            ),
            if (location.isNotEmpty &&
                (r.siteId == null ||
                    location.toUpperCase() != company.trim().toUpperCase()))
              field(
                'Ubicación',
                location.toUpperCase() == 'POR ESPECIFICAR'
                    ? 'No registrada'
                    : location,
              ),
            if (r.siteId == null &&
                company.trim().isNotEmpty &&
                location.toUpperCase() != company.trim().toUpperCase())
              field('Empresa mencionada', '$company (sin vínculo registrado)'),
            field(
              'Chofer asignado',
              driverById[r.operatorEmployeeId]?.driverName ??
                  (r.operatorName.isEmpty
                      ? 'Sin asignación'
                      : '${r.operatorName}${r.operatorEmployeeId == null ? ' (nombre registrado)' : ''}'),
            ),
            field('Material', r.materialName),
            field(
              'Tara / volumen',
              '${number(r.tareWeightKg, 'kg')} / ${number(r.capacityM3, 'm³')}',
            ),
            field(
              'Dimensiones',
              'Ancho: ${number(r.widthM, 'm')} · Alto: ${number(r.heightM, 'm')} · Largo: ${number(r.lengthM, 'm')}',
            ),
            if (r.compatibleUnitTypes.isNotEmpty)
              field(
                'Unidades compatibles',
                joined(r.compatibleUnitTypes.map(_unitLabel)),
              ),
            field(importedDate ? 'Alta en catálogo' : 'Fecha registrada', date),
            if (r.legacyCode.isNotEmpty && r.legacyCode != r.containerLabel)
              field('Número anterior', r.legacyCode),
            if (notes.$1.isNotEmpty) field('Observaciones', notes.$1),
          ],
          references: [
            if (notes.$2.isNotEmpty) field('Antecedentes', notes.$2),
          ],
        );
      }).toList();
  }
  return LogisticsCatalogPdfSection(
    kind: kind,
    records: records,
    metrics: metrics,
    totalCount: total,
    search: search,
  );
}

/// Only known import lines move to the appendix; human notes stay on the card.
/// Neither branch is discarded or written back to the source record.
(String, String) splitLogisticsContainerReportNotes(String notes) {
  final observations = <String>[];
  final references = <String>[];
  const prefixes = [
    'FECHA ORIGINAL NO CAPTURADA.',
    'DATOS PENDIENTES DEL EXCEL:',
    'EXISTENCIA CONFIRMADA POR EL USUARIO;',
    'DIFERENCIA ENTRE HOJAS (',
    'DATO COMPLEMENTADO (',
    'IMPORTADO DE Control contenedores.xlsx.',
  ];
  for (final line
      in notes.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
    (prefixes.any(line.startsWith) ? references : observations).add(line);
  }
  return (observations.join('\n'), references.join('\n'));
}

String _planningLabel(String value) => value == 'NO_PROGRAMAR'
    ? 'Fuera de programación'
    : logisticsPlanningStatusLabel(value);
String _unitLabel(String value) => switch (value) {
  'CAMION' => 'Camión',
  'GRUA' => 'Grúa',
  'TRAILER' => 'Tráiler',
  _ => logisticsUnitTypeLabel(value),
};
