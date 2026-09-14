import 'dart:async';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_records.dart';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DocumentalTestRepository implements DocumentalRepository {
  final records = <String, DocumentalDetail>{};
  final requests = <String, DocumentalDetail>{};
  final events = StreamController<void>.broadcast();
  bool unavailable = false;
  bool failSave = false;
  int saves = 0;
  @override
  Stream<void> get changes => events.stream;
  @override
  Future<DocumentalContext> loadContext() async {
    if (unavailable) {
      throw const PostgrestException(message: 'missing', code: 'PGRST202');
    }
    return DocumentalContext(
      today: DateTime.now(),
      untilMidnight: const Duration(days: 1),
      responsibles: const [
        DocumentalResponsible(
          '00000000-0000-4000-8000-000000000001',
          'Responsable de prueba',
        ),
      ],
    );
  }

  @override
  Future<DocumentalResultPage> loadPage(DocumentalQuery query) async {
    final all = records.values
        .map((r) => r.record)
        .where(
          (r) =>
              r.kind == query.kind &&
              r.title.toLowerCase().contains(query.search.toLowerCase()) &&
              (query.priority == null || r.priority == query.priority) &&
              (query.status == null || r.status == query.status) &&
              (query.type == null || r.type == query.type) &&
              (query.responsibleId == null ||
                  r.responsibleId == query.responsibleId) &&
              (query.urgency == null ||
                  documentalUrgency(
                        r.status,
                        r.expiration,
                        DateTime.now(),
                      ).label ==
                      query.urgency),
        )
        .toList();
    return DocumentalResultPage(
      all.skip(query.page * 50).take(50).toList(),
      all.length,
    );
  }

  @override
  Future<DocumentalDetail> loadDetail(String id) async => records[id]!;
  @override
  Future<Uri> fileUrl(DocumentalFile file) async =>
      Uri.parse('https://test.invalid/authorized-file');
  @override
  Future<DocumentalDetail> save(DocumentalSaveOperation op) async {
    saves++;
    if (failSave) throw StateError('Fallo de guardado de prueba');
    if (requests.containsKey(op.requestId)) return requests[op.requestId]!;
    final previous = records[op.id];
    if ((previous?.record.revision ?? 0) != op.revision) {
      throw const PostgrestException(message: 'conflict', code: 'PT409');
    }
    final row = DocumentalRecord({
      ...op.record,
      'id': op.id,
      'revision': op.revision + 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    final files = [
      for (final f in previous?.files ?? <DocumentalFile>[])
        DocumentalFile({
          ...f.data,
          'is_current':
              f.current &&
              !op.retiredIds.contains(f.id) &&
              !(f.role == 'principal' &&
                  op.files.any((s) => s.role == 'principal')),
        }),
      for (var i = 0; i < op.files.length; i++)
        DocumentalFile({
          'id': '${op.requestId}-$i',
          'role': op.files[i].role,
          'file_name': op.files[i].file.name,
          'storage_path': 'test/${op.id}/$i',
          'is_current': true,
          'revision': op.revision + 1,
          'uploaded_by': op.record['responsible_user_id'],
        }),
    ];
    final history = DocumentalHistory({
      'revision': row.revision,
      'event': previous == null
          ? (row.kind == DocumentalRecordKind.procedures
                ? 'Trámite registrado'
                : 'Documento registrado')
          : 'Expediente actualizado',
      'actor_name': 'Responsable de prueba',
      'created_at': DateTime.now().toIso8601String(),
      'snapshot': {
        'record': row.data,
        'files': [for (final f in files.where((f) => f.current)) f.data],
      },
    });
    final result = DocumentalDetail(
      record: row,
      files: files,
      history: [history, ...?previous?.history],
    );
    records[op.id] = result;
    requests[op.requestId] = result;
    events.add(null);
    return result;
  }
}
