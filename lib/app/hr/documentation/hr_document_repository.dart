import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../shared/utils/fetch_all_supabase_rows.dart';
import 'hr_document.dart';

const hrDocumentFileLimit = 25 * 1024 * 1024;
const hrDocumentMimeTypes = {
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
};

class HrDocumentUpload {
  final String name;
  final Uint8List bytes;
  HrDocumentUpload(this.name, this.bytes);
  String get extension => name.split('.').last.toLowerCase();
  void validate() {
    if (!hrDocumentMimeTypes.containsKey(extension)) {
      throw const FormatException('Selecciona PDF, Word, JPG o PNG.');
    }
    if (bytes.isEmpty || bytes.length > hrDocumentFileLimit) {
      throw const FormatException(
        'El archivo debe pesar entre 1 byte y 25 MB.',
      );
    }
  }
}

class HrDocumentSaveOperation {
  final String requestId = const Uuid().v4();
  final HrDocument document;
  final HrDocumentUpload? upload;
  Map<String, dynamic>? uploadedFile;
  bool confirmationPending = false;
  HrDocumentSaveOperation(this.document, {this.upload});
}

class HrDocumentRepository {
  final SupabaseClient client;
  HrDocumentRepository(this.client);

  Future<List<HrDocument>> load() async => (await fetchAllSupabaseRows(
    (from, to) => client
        .from('hr_documentation')
        .select()
        .order('document_date', ascending: false)
        .order('id')
        .range(from, to),
  )).map(HrDocument.new).toList();

  Future<List<Map<String, dynamic>>> employees() => fetchAllSupabaseRows(
    (from, to) => client
        .from('hr_employee_profiles')
        .select('id,nombre,empresa,puesto')
        .order('nombre')
        .order('id')
        .range(from, to),
  );

  Future<HrDocument> save(HrDocumentSaveOperation operation) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('La sesión expiró. Vuelve a iniciar sesión.');
    }
    final upload = operation.upload;
    if (upload != null && operation.uploadedFile == null) {
      upload.validate();
      final path =
          '$uid/${operation.document.id}/${const Uuid().v4()}.${upload.extension}';
      await client.storage
          .from('hr_documentation')
          .uploadBinary(
            path,
            upload.bytes,
            fileOptions: FileOptions(
              upsert: false,
              contentType: hrDocumentMimeTypes[upload.extension],
            ),
          );
      operation.uploadedFile = {
        'path': path,
        'name': upload.name,
        'size': upload.bytes.length,
        'mime': hrDocumentMimeTypes[upload.extension],
      };
    }
    final record = {...operation.document.row};
    if (operation.uploadedFile != null) record['file'] = operation.uploadedFile;
    operation.confirmationPending = true;
    final result = await client
        .rpc(
          'hr_documentation_save',
          params: {
            'p_id': operation.document.id,
            'p_expected_revision': operation.document.revision,
            'p_request_id': operation.requestId,
            'p_record': record,
          },
        )
        .timeout(const Duration(seconds: 45));
    return HrDocument(Map<String, dynamic>.from(result as Map));
  }

  Future<Uint8List> download(HrDocument record) => client.storage
      .from('hr_documentation')
      .download(record.file!['path'] as String);

  Future<Uri> fileUrl(HrDocument record) async => Uri.parse(
    await client.storage
        .from('hr_documentation')
        .createSignedUrl(record.file!['path'] as String, 180),
  );
}
