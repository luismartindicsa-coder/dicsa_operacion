import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

Future<String?> saveRemoteFileAs({
  required String url,
  required String suggestedFileName,
  String dialogTitle = 'Descargar como...',
}) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'No se pudo descargar el archivo (${response.statusCode}).',
    );
  }

  String? outputPath;
  try {
    outputPath = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: suggestedFileName,
      type: FileType.custom,
      allowedExtensions: _allowedExtensionsFor(suggestedFileName),
    );
  } catch (_) {
    return null;
  }

  if (outputPath == null || outputPath.trim().isEmpty) return null;
  final normalized = _normalizeExtension(outputPath, suggestedFileName);
  await File(normalized).writeAsBytes(response.bodyBytes, flush: true);
  return normalized;
}

List<String> _allowedExtensionsFor(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0 || dot == fileName.length - 1) {
    return const <String>[];
  }
  return <String>[fileName.substring(dot + 1).toLowerCase()];
}

String _normalizeExtension(String outputPath, String suggestedFileName) {
  final dot = suggestedFileName.lastIndexOf('.');
  if (dot <= 0 || dot == suggestedFileName.length - 1) return outputPath;
  final extension = suggestedFileName.substring(dot).toLowerCase();
  return outputPath.toLowerCase().endsWith(extension)
      ? outputPath
      : '$outputPath$extension';
}
