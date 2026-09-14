import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'gestion_documental_record_draft.dart';
import 'gestion_documental_records.dart';

class DocumentalSaveOperation {
  final String id;
  final String requestId = const Uuid().v4();
  final int revision;
  final Map<String, dynamic> record;
  final List<({PlatformFile file, String role})> files;
  final List<String> retiredIds;
  final List<Map<String, dynamic>> uploaded = [];
  bool confirmationPending = false;
  DocumentalSaveOperation(DocumentalRecordDraft draft)
    : id = draft.id ?? const Uuid().v4(),
      revision = draft.revision,
      record = Map.unmodifiable(draft.toRecordJson()),
      files = [
        if (draft.principal != null)
          (file: draft.principal!, role: 'principal'),
        for (final f in draft.attachments) (file: f, role: 'complementario'),
      ],
      retiredIds = List.unmodifiable(draft.retiredFileIds);
}

abstract class DocumentalRepository {
  Future<DocumentalContext> loadContext();
  Future<DocumentalResultPage> loadPage(DocumentalQuery query);
  Future<DocumentalDetail> loadDetail(String id);
  Future<DocumentalDetail> save(DocumentalSaveOperation operation);
  Future<Uri> fileUrl(DocumentalFile file);
  Stream<void> get changes;
}

class DocumentalRepositoryScope extends InheritedWidget {
  final DocumentalRepository repository;
  const DocumentalRepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });
  static DocumentalRepository of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DocumentalRepositoryScope>()
          ?.repository ??
      SupabaseDocumentalStore.instance;
  @override
  bool updateShouldNotify(DocumentalRepositoryScope oldWidget) =>
      repository != oldWidget.repository;
}

class SupabaseDocumentalStore implements DocumentalRepository {
  final SupabaseClient client;
  SupabaseDocumentalStore(this.client);
  static final instance = SupabaseDocumentalStore(Supabase.instance.client);

  @override
  Future<DocumentalContext> loadContext() async {
    final json = Map<String, dynamic>.from(
      await client.rpc('documental_context') as Map,
    );
    final people = [
      for (final r in json['responsibles'] as List)
        DocumentalResponsible(r['id'] as String, r['label'] as String),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return DocumentalContext(
      today: DateTime.parse(json['today'] as String),
      untilMidnight: Duration(
        seconds: (json['seconds_to_midnight'] as num).ceil() + 1,
      ),
      responsibles: people,
    );
  }

  @override
  Future<DocumentalResultPage> loadPage(DocumentalQuery query) async {
    final json = Map<String, dynamic>.from(
      await client.rpc('documental_query_records', params: query.toParams())
          as Map,
    );
    return DocumentalResultPage([
      for (final r in json['records'] as List)
        DocumentalRecord(Map<String, dynamic>.from(r as Map)),
    ], json['total'] as int);
  }

  @override
  Future<DocumentalDetail> loadDetail(String id) async =>
      DocumentalDetail.fromJson(
        Map<String, dynamic>.from(
          await client.rpc('documental_get_record', params: {'p_id': id})
              as Map,
        ),
      );

  @override
  Stream<void> get changes {
    late StreamController<void> controller;
    RealtimeChannel? channel;
    controller = StreamController<void>(
      onListen: () {
        channel = client
            .channel('documental-${const Uuid().v4()}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'documental_records',
              callback: (_) => controller.add(null),
            )
            .subscribe();
      },
      onCancel: () async {
        if (channel != null) await client.removeChannel(channel!);
      },
    );
    return controller.stream;
  }

  @override
  Future<Uri> fileUrl(DocumentalFile file) async => Uri.parse(
    await client.storage.from('documental').createSignedUrl(file.path, 120),
  );

  @override
  Future<DocumentalDetail> save(DocumentalSaveOperation operation) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('La sesión expiró. Vuelve a iniciar sesión.');
    }
    if (!operation.confirmationPending) {
      try {
        for (
          var i = operation.uploaded.length;
          i < operation.files.length;
          i++
        ) {
          final selected = operation.files[i];
          final file = selected.file;
          if (file.size > 52428800) {
            throw StateError('Cada archivo debe pesar como máximo 50 MB.');
          }
          final path = '$uid/${operation.id}/${const Uuid().v4()}';
          final mime = _mime(file);
          final options = FileOptions(upsert: false, contentType: mime);
          if (!kIsWeb && file.path != null) {
            await client.storage
                .from('documental')
                .upload(path, File(file.path!), fileOptions: options);
          } else if (file.bytes != null) {
            await client.storage
                .from('documental')
                .uploadBinary(path, file.bytes!, fileOptions: options);
          } else {
            throw StateError(
              'No se pudo leer ${file.name}. Selecciona el archivo otra vez.',
            );
          }
          operation.uploaded.add({
            'storage_path': path,
            'role': selected.role,
            'file_name': file.name,
            'mime_type': mime,
            'size_bytes': file.size,
          });
        }
      } catch (_) {
        // No SQL request has started, so these objects cannot be referenced.
        await _cleanup(operation);
        rethrow;
      }
    }
    operation.confirmationPending = true;
    try {
      final result = await client
          .rpc(
            'documental_save_record',
            params: {
              'p_id': operation.id,
              'p_expected_revision': operation.revision,
              'p_request_id': operation.requestId,
              'p_record': operation.record,
              'p_files': operation.uploaded,
              'p_retire_file_ids': operation.retiredIds,
            },
          )
          .timeout(const Duration(seconds: 45));
      final detail = DocumentalDetail.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
      operation.confirmationPending = false;
      return detail;
    } on PostgrestException catch (error) {
      // Only server SQL errors prove rollback. Transport/response failures may
      // have committed; retain the same request and uploaded paths for retry.
      if (RegExp(r'^[0-9A-Z]{5}$').hasMatch(error.code ?? '') &&
          !((error.code ?? '').startsWith('PGRST'))) {
        operation.confirmationPending = false;
        await _cleanup(operation);
      }
      rethrow;
    }
  }

  Future<void> _cleanup(DocumentalSaveOperation operation) async {
    if (operation.uploaded.isEmpty) return;
    try {
      await client.storage.from('documental').remove([
        for (final f in operation.uploaded) f['storage_path'] as String,
      ]);
    } catch (_) {
      // Unreferenced objects remain private. Never remove committed history.
    }
    operation.uploaded.clear();
  }

  String _mime(PlatformFile file) => switch (file.extension?.toLowerCase()) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    _ => 'application/octet-stream',
  };
}

String documentalErrorMessage(Object error) {
  if (error is PostgrestException) {
    if (error.code == '42501') {
      return 'Tu sesión no tiene acceso a Gestión Documental.';
    }
    if (error.code == 'PT409' || error.code == '40001') {
      return 'El expediente cambió en otra sesión. Cierra y vuelve a abrirlo antes de guardar.';
    }
    if (error.code == 'PGRST202' || error.code == '42P01') {
      return 'Gestión Documental aún no está habilitada en la base de datos.';
    }
    if (error.code == '23514' || error.code == 'P0001') return error.message;
  }
  if (error is StateError) return error.message.toString();
  return 'No se pudo completar la operación. Revisa la conexión e intenta de nuevo.';
}
