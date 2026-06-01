import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String kFinanzasEvidenceOwnerTypeSupplierInvoice = 'SUPPLIER_INVOICE';
const String kFinanzasEvidenceOwnerTypeBankMovement = 'BANK_MOVEMENT';

const String _kFinanzasEvidenceTable = 'finanzas_evidence';
const String _kFinanzasEvidenceBucket = 'finanzas_evidence';

class FinanzasEvidenceRecord {
  final String id;
  final String ownerType;
  final String ownerId;
  final String fileUrl;
  final String? storagePath;
  final String fileName;
  final String mimeType;
  final String comment;
  final String? uploadedBy;
  final String uploadedByName;
  final DateTime uploadedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FinanzasEvidenceRecord({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.fileUrl,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.comment,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.uploadedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toInsertJson() => <String, dynamic>{
    'id': id,
    'owner_type': ownerType,
    'owner_id': ownerId,
    'file_url': fileUrl,
    'storage_path': storagePath,
    'file_name': fileName,
    'mime_type': mimeType,
    'comment': comment.trim().isEmpty ? null : comment.trim(),
    'uploaded_by': uploadedBy,
    'uploaded_by_name': uploadedByName.trim().isEmpty
        ? null
        : uploadedByName.trim(),
    'uploaded_at': uploadedAt.toIso8601String(),
  };

  factory FinanzasEvidenceRecord.fromRemoteRow(Map<String, dynamic> row) {
    return FinanzasEvidenceRecord(
      id: (row['id'] ?? '').toString(),
      ownerType: (row['owner_type'] ?? '').toString(),
      ownerId: (row['owner_id'] ?? '').toString(),
      fileUrl: (row['file_url'] ?? '').toString(),
      storagePath: row['storage_path']?.toString(),
      fileName: (row['file_name'] ?? '').toString(),
      mimeType: (row['mime_type'] ?? '').toString(),
      comment: (row['comment'] ?? '').toString(),
      uploadedBy: row['uploaded_by']?.toString(),
      uploadedByName: (row['uploaded_by_name'] ?? '').toString(),
      uploadedAt:
          _tryParseDateTime(row['uploaded_at'] as String?) ?? DateTime.now(),
      createdAt: _tryParseDateTime(row['created_at'] as String?),
      updatedAt: _tryParseDateTime(row['updated_at'] as String?),
    );
  }
}

class FinanzasEvidenceStore {
  static Future<List<FinanzasEvidenceRecord>> loadByOwnerType(
    String ownerType,
  ) async {
    try {
      final rows = await Supabase.instance.client
          .from(_kFinanzasEvidenceTable)
          .select()
          .eq('owner_type', ownerType)
          .order('uploaded_at', ascending: false)
          .order('created_at', ascending: false);
      return (rows as List)
          .map(
            (row) => FinanzasEvidenceRecord.fromRemoteRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <FinanzasEvidenceRecord>[];
    }
  }

  static Future<FinanzasEvidenceRecord> createUploadedEvidence({
    required String ownerType,
    required String ownerId,
    required PlatformFile file,
    String comment = '',
    String uploadedByName = '',
  }) async {
    final uploaded = await _uploadEvidenceFile(
      ownerType: ownerType,
      ownerId: ownerId,
      file: file,
    );
    final user = Supabase.instance.client.auth.currentUser;
    final now = DateTime.now();
    final record = FinanzasEvidenceRecord(
      id: 'fin-evidence-${now.microsecondsSinceEpoch}',
      ownerType: ownerType,
      ownerId: ownerId,
      fileUrl: uploaded.$1,
      storagePath: uploaded.$2,
      fileName: file.name,
      mimeType: _mimeTypeFor(file),
      comment: comment.trim(),
      uploadedBy: user?.id,
      uploadedByName: uploadedByName.trim().isNotEmpty
          ? uploadedByName.trim()
          : (user?.email ?? 'Usuario'),
      uploadedAt: now,
      createdAt: null,
      updatedAt: null,
    );
    await Supabase.instance.client
        .from(_kFinanzasEvidenceTable)
        .insert(record.toInsertJson());
    return record;
  }

  static Future<(String, String)> _uploadEvidenceFile({
    required String ownerType,
    required String ownerId,
    required PlatformFile file,
  }) async {
    final sanitized = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath =
        '$ownerType/$ownerId/${DateTime.now().millisecondsSinceEpoch}_$sanitized';

    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('No se pudieron leer los bytes del archivo.');
      }
      await Supabase.instance.client.storage
          .from(_kFinanzasEvidenceBucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _mimeTypeFor(file),
            ),
          );
    } else {
      final path = file.path;
      if (path != null && path.isNotEmpty) {
        await Supabase.instance.client.storage
            .from(_kFinanzasEvidenceBucket)
            .upload(
              storagePath,
              File(path),
              fileOptions: FileOptions(
                upsert: true,
                contentType: _mimeTypeFor(file),
              ),
            );
      } else if (file.bytes != null) {
        await Supabase.instance.client.storage
            .from(_kFinanzasEvidenceBucket)
            .uploadBinary(
              storagePath,
              file.bytes!,
              fileOptions: FileOptions(
                upsert: true,
                contentType: _mimeTypeFor(file),
              ),
            );
      } else {
        throw Exception('No se pudo leer el archivo (sin ruta ni bytes).');
      }
    }

    final url = Supabase.instance.client.storage
        .from(_kFinanzasEvidenceBucket)
        .getPublicUrl(storagePath);
    return (url, storagePath);
  }
}

String _mimeTypeFor(PlatformFile file) {
  final ext = (file.extension ?? '').trim().toLowerCase();
  switch (ext) {
    case 'pdf':
      return 'application/pdf';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    default:
      return 'application/octet-stream';
  }
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
