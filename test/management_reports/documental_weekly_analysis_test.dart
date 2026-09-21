import 'dart:io';

import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_overview.dart';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_records.dart';
import 'package:dicsa_operacion/app/management_reports/documental_weekly_analysis.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_documental_pdf.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_registry.dart';
import 'package:flutter_test/flutter_test.dart';

DocumentalRecord record(
  String id, {
  DocumentalRecordKind kind = DocumentalRecordKind.legal,
  String status = 'Pendiente',
  String? expires,
  Map<String, dynamic> extra = const {},
}) => DocumentalRecord({
  'id': id,
  'category': kind.key,
  'title': 'Documento $id',
  'document_type': 'Documento',
  'status': status,
  'priority': 'Alta',
  'responsible_user_id': 'owner',
  'reference': 'DOC-$id',
  'revision': 1,
  'expiration_date': expires,
  ...extra,
});

DocumentalWeeklySource source(
  List<DocumentalRecord> records, {
  DateTime? day,
}) => DocumentalWeeklySource(
  context: DocumentalContext(
    today: day ?? DateTime(2026, 9, 18),
    untilMidnight: const Duration(hours: 12),
    responsibles: const [
      DocumentalResponsible('owner', 'Responsable de prueba'),
    ],
  ),
  records: records,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'risk windows include today, 5 and 15 days and exclude inactive states',
    () {
      final report = DocumentalWeeklyAnalysis(
        source([
          record('past', expires: '2026-09-17'),
          record('today', expires: '2026-09-18'),
          record('five', expires: '2026-09-23'),
          record('six', status: 'En proceso', expires: '2026-09-24'),
          record('fifteen', expires: '2026-10-03'),
          record('sixteen', expires: '2026-10-04'),
          record('undated'),
          for (final state in ['Completado', 'Cancelado', 'No aplica'])
            record(state, status: state, expires: '2026-01-01'),
        ]),
      );
      expect(report.records, hasLength(10));
      expect(report.active, hasLength(7));
      expect(report.expired.map((r) => r.id), ['past']);
      expect(report.critical.map((r) => r.id), ['today', 'five']);
      expect(report.upcoming, hasLength(4));
      expect(report.risks, hasLength(5));
      expect(report.withoutExpiration.single.id, 'undated');
    },
  );

  test(
    'calendar keeps distinct obligations and has an inclusive 30 day horizon',
    () {
      final report = DocumentalWeeklyAnalysis(
        source([
          record(
            'contract',
            kind: DocumentalRecordKind.contracts,
            expires: '2026-09-18',
            extra: {
              'renewal_type': 'Manual',
              'renewal_date': '2026-09-18',
              'start_date': '2026-09-18',
            },
          ),
          record(
            'no-renewal',
            kind: DocumentalRecordKind.insurance,
            extra: {'renewal_type': 'No aplica', 'renewal_date': '2026-09-18'},
          ),
          record('last', expires: '2026-10-17'),
          record('outside', expires: '2026-10-18'),
          record('periodic', extra: {'periodicity': 'Mensual'}),
          record('done', status: 'Completado', expires: '2026-09-19'),
        ]),
      );
      expect(report.agenda, hasLength(4));
      expect(
        report.agenda
            .where((e) => e.record.id == 'contract')
            .map((e) => e.kind)
            .toSet(),
        {
          DocumentalEventKind.start,
          DocumentalEventKind.renewal,
          DocumentalEventKind.expiration,
        },
      );
      expect(report.risks, hasLength(2));
      expect(report.agenda.last.record.id, 'last');
      expect(
        report.events.map((e) => e.id).toSet().length,
        report.events.length,
      );
    },
  );

  test(
    'completed scheduled activities do not create overdue schedule alerts',
    () {
      final report = DocumentalWeeklyAnalysis(
        source([
          record(
            'audit',
            kind: DocumentalRecordKind.audits,
            extra: {'scheduled_date': '2026-09-15'},
          ),
          record(
            'performed',
            kind: DocumentalRecordKind.maintenance,
            expires: '2026-09-17',
            extra: {
              'scheduled_date': '2026-09-15',
              'performed_date': '2026-09-16',
            },
          ),
          record(
            'upcoming',
            kind: DocumentalRecordKind.maintenance,
            extra: {'scheduled_date': '2026-09-20'},
          ),
        ]),
      );
      expect(report.risks.map((e) => e.id), [
        'audit-programacion',
        'performed-vencimiento',
      ]);
      expect(report.agenda.single.id, 'upcoming-programacion');
    },
  );

  test('server business date and civil day arithmetic define alerts', () {
    final report = DocumentalWeeklyAnalysis(
      source([
        record('spring', expires: '2026-04-06'),
      ], day: DateTime(2026, 4, 1, 23, 50)),
    );
    expect(report.critical.single.id, 'spring');
    expect(report.days(DateTime(2026, 4, 6)), 5);
  });

  test(
    'all categories, manifest scope and unassigned actions are explicit',
    () {
      final report = DocumentalWeeklyAnalysis(
        source([
          for (final kind in DocumentalRecordKind.values)
            record(kind.key, kind: kind),
          record(
            'manifest',
            kind: DocumentalRecordKind.environment,
            extra: {'document_type': 'Manifiestos'},
          ),
          record(
            'unassigned',
            kind: DocumentalRecordKind.procedures,
            extra: {'responsible_user_id': null},
          ),
          record(
            'unknown',
            extra: {
              'responsible_user_id': 'missing',
              'next_action': ' Renovar licencia ',
            },
          ),
        ]),
      );
      expect(report.procedures, hasLength(2));
      expect(report.manifests.single.id, 'manifest');
      expect(report.responsible(report.records[12]), 'Sin responsable');
      expect(report.responsible(report.records.last), 'Usuario no disponible');
      expect(report.action(report.records.last), 'Renovar licencia');
      expect(report.action(report.records.first), isEmpty);
    },
  );

  test(
    'builds dense and empty PDFs, with long text and all document categories',
    () async {
      final rows = <DocumentalRecord>[
        for (var i = 0; i < 44; i++)
          record(
            '$i',
            kind: DocumentalRecordKind.values[i % 11],
            status: i % 4 == 0 ? 'Completado' : 'En proceso',
            expires: i % 3 == 0 ? '2026-09-17' : '2026-09-23',
            extra: {
              'title':
                  'EXPEDIENTE DE PRUEBA $i · ${List.filled(8, "AUTORIZACIÓN Y SEGUIMIENTO").join(" ")}',
              'document_type': i % 11 == 3 ? 'Manifiestos' : 'Capacitaciones',
              'authority': 'DEPENDENCIA DE PRUEBA',
              'progress_percentage': 50,
              'next_action': List.filled(
                12,
                'GESTIONAR RENOVACIÓN CON RESPONSABLE.',
              ).join(' '),
              'counterparty_name': 'CONTRAPARTE DE PRUEBA',
              'signature_date': '2026-01-01',
              'renewal_type': 'Manual',
              'renewal_date': '2026-09-20',
              'provider_name': 'PROVEEDOR DE PRUEBA',
              'related_employee_name': 'PERSONA DE PRUEBA',
              'insured_subject': 'UNIDAD DE PRUEBA',
              'installation_name': 'PLANTA DE PRUEBA',
              'authorization_number': 'AUT-$i',
              'scheduled_date': '2026-09-22',
            },
          ),
      ];
      for (final entry in {
        'gestion_documental_viernes': rows,
        'gestion_documental_vacio': <DocumentalRecord>[],
      }.entries) {
        final bytes = await buildDocumentalWeeklySupervisionPdfBytes(
          area: managementAreaDefinition(ManagementAreaKey.gestion),
          generatedAt: DateTime.utc(2026, 9, 19, 1),
          generatedBy: 'supervision@prueba.invalid',
          source: source(entry.value),
        );
        expect(bytes.take(4), [37, 80, 68, 70]);
        final directory = Platform.environment['DICSA_DOCUMENTAL_QA_DIR'];
        if (directory != null) {
          await Directory(directory).create(recursive: true);
          await File('$directory/${entry.key}.pdf').writeAsBytes(bytes);
        }
      }
    },
  );
}
