import 'dart:io';

import 'package:file_picker/file_picker.dart';

Future<String?> saveCsvFile({
  required String fileName,
  required String content,
  String dialogTitle = 'Guardar CSV',
}) async {
  String? outputPath;
  try {
    outputPath = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      allowedExtensions: const ['csv'],
      type: FileType.custom,
    );
  } catch (_) {
    return null;
  }
  if (outputPath == null || outputPath.trim().isEmpty) return null;
  final normalized = outputPath.toLowerCase().endsWith('.csv')
      ? outputPath
      : '$outputPath.csv';
  await File(normalized).writeAsString(content, flush: true);
  return normalized;
}
