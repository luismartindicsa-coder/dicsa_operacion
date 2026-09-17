import 'package:dicsa_operacion/app/direction/direction_documental_summary.dart';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_records.dart';
import 'package:flutter_test/flutter_test.dart';

import '../gestion_documental/documental_test_repository.dart';

class DirectionDocumentalTestRepository extends DocumentalTestRepository {
  final queries = <DocumentalQuery>[];
  final opened = <String>[];
  bool failPages = false;

  @override
  Future<DocumentalResultPage> loadPage(DocumentalQuery query) async {
    if (failPages) {
      throw StateError('No se pudieron consultar los expedientes.');
    }
    queries.add(query);
    final rows =
        records.values
            .map((detail) => detail.record)
            .where(
              (row) =>
                  row.kind == query.kind &&
                  (query.status == null || row.status == query.status) &&
                  (query.urgency == null ||
                      documentalUrgency(
                            row.status,
                            row.expiration,
                            today,
                          ).label ==
                          query.urgency),
            )
            .toList()
          ..sort((a, b) {
            final date = (a.expiration ?? DateTime(9999)).compareTo(
              b.expiration ?? DateTime(9999),
            );
            return date != 0 ? date : a.id.compareTo(b.id);
          });
    return DocumentalResultPage(
      rows.skip(query.page * 50).take(50).toList(),
      rows.length,
    );
  }

  @override
  Future<DocumentalDetail> loadDetail(String id) async {
    opened.add(id);
    return super.loadDetail(id);
  }

  void add(DocumentalRecord row) =>
      records[row.id] = DocumentalDetail(record: row, files: [], history: []);
}

DocumentalRecord record(
  String id, {
  String? expiration = '2026-09-18',
  String status = 'Pendiente',
  DocumentalRecordKind kind = DocumentalRecordKind.legal,
  String? title,
  int progress = 0,
}) => DocumentalRecord({
  'id': id,
  'category': kind.key,
  'title': title ?? 'Documento $id',
  'document_type': kind == DocumentalRecordKind.procedures
      ? 'Trámites'
      : 'Actas',
  'expiration_date': expiration,
  'status': status,
  'progress_percentage': progress,
  'priority': 'Media',
  'responsible_user_id': '00000000-0000-4000-8000-000000000001',
  'reference': id,
  'revision': 1,
  'authority': kind == DocumentalRecordKind.procedures
      ? 'Municipio de Celaya'
      : '',
  'department': '',
  'observations': '',
  'next_action': '',
});

DirectionDocumentalTestRepository fixture() =>
    DirectionDocumentalTestRepository()
      ..todayOverride = DateTime(2026, 9, 15)
      ..add(
        record(
          'd1',
          expiration: '2026-09-15',
          title: 'Licencia de funcionamiento',
          kind: DocumentalRecordKind.environment,
        ),
      )
      ..add(
        record(
          'd2',
          expiration: '2026-09-20',
          title: 'Póliza de responsabilidad civil',
          kind: DocumentalRecordKind.insurance,
        ),
      )
      ..add(
        record(
          'd3',
          expiration: '2026-09-28',
          title: 'Verificación vehicular C1',
          kind: DocumentalRecordKind.vehicles,
        ),
      )
      ..add(
        record(
          'p1',
          title: 'Renovación de uso de suelo',
          expiration: '2026-10-01',
          status: 'En proceso',
          kind: DocumentalRecordKind.procedures,
          progress: 65,
        ),
      )
      ..add(
        record(
          'p2',
          title: 'Actualización de permiso ambiental',
          expiration: null,
          status: 'En proceso',
          kind: DocumentalRecordKind.procedures,
          progress: 30,
        ),
      );

void main() {
  test(
    'expiring uses server today, includes days 0 through 15 and only active records',
    () async {
      final repo = DirectionDocumentalTestRepository()
        ..todayOverride = DateTime(2028, 2, 29);
      addTearDown(repo.events.close);
      final today = repo.today;
      final documents = [
        for (final offset in [-1, 0, 5, 15, 16])
          record(
            'day$offset',
            expiration: documentalDateJson(today.add(Duration(days: offset))),
          ),
        for (final status in ['Completado', 'Cancelado', 'No aplica'])
          record(status, expiration: '2028-02-29', status: status),
        record('undated', expiration: null),
      ];
      final result = DirectionDocumentalSummary.fromRecords(
        context: await repo.loadContext(),
        documents: [...documents, documents[1]],
        procedures: [],
      );
      expect(result.expiring.map((row) => row.id), ['day0', 'day5', 'day15']);
      expect(result.context.today, DateTime(2028, 2, 29));
    },
  );

  test(
    'only permits and procedures in progress are included, with overdue and undated records',
    () async {
      final repo = fixture();
      addTearDown(repo.events.close);
      final rows = [
        record('pending', kind: DocumentalRecordKind.procedures),
        record(
          'done',
          kind: DocumentalRecordKind.procedures,
          status: 'Completado',
        ),
        record(
          'cancelled',
          kind: DocumentalRecordKind.procedures,
          status: 'Cancelado',
        ),
        record('other-area', status: 'En proceso'),
        record(
          'old',
          expiration: '2026-09-14',
          kind: DocumentalRecordKind.procedures,
          status: 'En proceso',
        ),
        ...repo.records.values.map((d) => d.record),
      ];
      final result = DirectionDocumentalSummary.fromRecords(
        context: await repo.loadContext(),
        documents: [],
        procedures: rows,
      );
      expect(result.procedures.map((row) => row.id), ['old', 'p1', 'p2']);
      expect(result.procedures[1].progress, 65);
    },
  );

  test(
    'store loads complete paginated lists instead of the twelve-event preview',
    () async {
      final repo = DirectionDocumentalTestRepository()
        ..todayOverride = DateTime(2026, 9, 15);
      addTearDown(repo.events.close);
      for (var i = 0; i < 55; i++) {
        repo.add(record('doc${i.toString().padLeft(3, '0')}'));
      }
      repo.add(record('cancelled', status: 'Cancelado'));
      repo.add(
        record(
          'insurance',
          expiration: '2026-09-30',
          kind: DocumentalRecordKind.insurance,
        ),
      );
      for (var i = 0; i < 61; i++) {
        repo.add(
          record(
            'p$i',
            expiration: null,
            kind: DocumentalRecordKind.procedures,
            status: 'En proceso',
          ),
        );
      }
      final preview = await repo.loadDashboard();
      expect(preview.upcoming, hasLength(12));
      final data = await DirectionDocumentalSummaryStore(repo).load();
      expect(data.expiring, hasLength(56));
      expect(data.procedures, hasLength(61));
      expect(data.expiring.length, preview.metrics['upcoming']);
      expect(data.procedures.length, preview.metrics['in_progress_procedures']);
      expect(
        repo.queries.any(
          (q) => q.kind == DocumentalRecordKind.legal && q.page == 1,
        ),
        isTrue,
      );
      expect(
        repo.queries.any(
          (q) => q.kind == DocumentalRecordKind.procedures && q.page == 1,
        ),
        isTrue,
      );
      expect(repo.queries.every((q) => q.sort == 'expiration'), isTrue);
      expect(repo.saves, 0);
    },
  );

  test(
    'query failure propagates instead of returning partial or empty counts',
    () async {
      final repo = fixture()..failPages = true;
      addTearDown(repo.events.close);
      await expectLater(
        DirectionDocumentalSummaryStore(repo).load(),
        throwsStateError,
      );
    },
  );
}
