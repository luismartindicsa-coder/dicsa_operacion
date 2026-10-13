import 'package:uuid/uuid.dart';

enum HrDocumentCategory {
  reglamento('Reglamento interno de trabajo', 'Reglamentos'),
  manual('Manual de actividades por puesto', 'Manuales'),
  comisiones('Política de comisiones', 'Políticas'),
  telefono('Política de uso de teléfono', 'Políticas'),
  laptop('Política de uso de laptop', 'Políticas'),
  unidad('Política de uso de unidad', 'Políticas'),
  vacaciones('Convenio de vacaciones', 'Convenios'),
  finiquito('Convenio de finiquito', 'Convenios'),
  renuncia('Carta de renuncia', 'Cartas'),
  recomendacion('Carta de recomendación', 'Cartas'),
  acta('Acta administrativa', 'Actas'),
  otros('Otros documentos', 'Otros');

  final String label, group;
  const HrDocumentCategory(this.label, this.group);
}

class HrDocumentField {
  final String key, label, type;
  final bool required;
  const HrDocumentField(
    this.key,
    this.label, {
    this.type = 'text',
    this.required = false,
  });
  factory HrDocumentField.fromJson(Map value) => HrDocumentField(
    '${value['key']}',
    '${value['label']}',
    type: value['type']?.toString() ?? 'text',
    required: value['required'] == true,
  );
  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'type': type,
    'required': required,
  };
}

/// A saved snapshot. PDFs never consult live personnel or a newer template.
class HrDocument {
  final Map<String, dynamic> row;
  HrDocument(Map<String, dynamic> row) : row = Map.unmodifiable(row);
  String get id => row['id'] as String;
  int get revision => (row['revision'] as num?)?.toInt() ?? 0;
  HrDocumentCategory get category =>
      HrDocumentCategory.values.byName(row['category'] as String);
  String get kind => row['kind'] as String;
  String get title => row['title'] as String;
  String get date => row['document_date'] as String;
  String get body => row['body']?.toString() ?? '';
  bool get archived => row['archived'] == true;
  Map<String, String> get values =>
      Map<String, String>.from(row['data'] as Map? ?? {});
  List<HrDocumentField> get fields => (row['fields'] as List? ?? [])
      .map((f) => HrDocumentField.fromJson(f as Map))
      .toList();
  List<Map<String, String>> get signatures => (row['signatures'] as List? ?? [])
      .map((s) => Map<String, String>.from(s as Map))
      .toList();
  Map<String, dynamic>? get file => row['file'] == null
      ? null
      : Map<String, dynamic>.from(row['file'] as Map);
  String get kindLabel => switch (kind) {
    'template' => 'Plantilla',
    'uploaded' => 'Archivo cargado',
    _ => 'Documento',
  };
  String get folio => 'RH-${id.substring(0, 8).toUpperCase()}';

  HrDocument copy(Map<String, dynamic> changes) =>
      HrDocument({...row, ...changes});

  /// Reusable formats carry field definitions and text, never a person's data.
  HrDocument asTemplate() => copy({
    'id': const Uuid().v4(),
    'revision': 0,
    'kind': 'template',
    'data': <String, String>{},
    'employee_id': null,
    'file': null,
    'archived': false,
    'signatures': [
      for (final s in signatures) {'label': s['label'] ?? '', 'name': ''},
    ],
  });

  HrDocument instantiate(DateTime today) => copy({
    'id': const Uuid().v4(),
    'revision': 0,
    'kind': 'generated',
    'document_date': hrDocumentIsoDate(today),
    'data': <String, String>{},
    'employee_id': null,
    'file': null,
    'archived': false,
    'signatures': [
      for (final s in signatures) {'label': s['label'] ?? '', 'name': ''},
    ],
  });

  List<String> validation({bool forPdf = false}) {
    final errors = <String>[];
    if (title.trim().isEmpty) errors.add('Escribe el nombre del documento.');
    if (title.length > 240) {
      errors.add('El nombre admite hasta 240 caracteres.');
    }
    if (!hrDocumentValidDate(date)) {
      errors.add('Revisa la fecha del documento.');
    }
    if (kind == 'uploaded') return errors;
    if (body.trim().isEmpty) errors.add('Escribe el contenido del documento.');
    if (body.length > 100000) {
      errors.add('El contenido admite hasta 100,000 caracteres.');
    }
    final known = {'fecha', ...fields.map((f) => f.key)};
    final missing = RegExp(r'\{\{\s*([^{}]+?)\s*\}\}')
        .allMatches(body)
        .map((m) => m[1]!.trim())
        .where((key) => !known.contains(key))
        .toSet();
    if (missing.isNotEmpty) {
      errors.add('Datos desconocidos en el texto: ${missing.join(', ')}.');
    }
    for (final field in fields) {
      final value = values[field.key]?.trim() ?? '';
      if (kind != 'template' && forPdf && field.required && value.isEmpty) {
        errors.add('Completa ${field.label.toLowerCase()}.');
      }
      if (value.isEmpty) continue;
      if (field.type == 'date' && !hrDocumentValidDate(value)) {
        errors.add('Revisa ${field.label.toLowerCase()}.');
      }
      if (field.type == 'money' && hrDocumentAmount(value) == null) {
        errors.add(
          'Revisa ${field.label.toLowerCase()}: usa un monto válido con hasta dos decimales.',
        );
      }
      if (field.type == 'number' &&
          (num.tryParse(value) == null ||
              !num.parse(value).isFinite ||
              num.parse(value) < 0)) {
        errors.add('Revisa ${field.label.toLowerCase()}.');
      }
    }
    return errors;
  }

  String renderedBody() {
    final byKey = {for (final f in fields) f.key: f};
    return body.replaceAllMapped(RegExp(r'\{\{\s*([^{}]+?)\s*\}\}'), (match) {
      final key = match[1]!.trim();
      if (key == 'fecha') return hrDocumentDisplayDate(date);
      final field = byKey[key];
      final value = values[key]?.trim() ?? '';
      if (value.isEmpty) return '________________';
      return switch (field?.type) {
        'date' => hrDocumentDisplayDate(value),
        'money' => hrDocumentMoney(value),
        _ => value,
      };
    });
  }
}

String hrDocumentIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
bool hrDocumentValidDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final date = DateTime.tryParse(value);
  return date != null && hrDocumentIsoDate(date) == value;
}

String hrDocumentDisplayDate(String value) =>
    hrDocumentValidDate(value) ? value.split('-').reversed.join('/') : value;
num? hrDocumentAmount(String text) {
  final value = text.trim().replaceAll(r'$', '').replaceAll(',', '');
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) return null;
  final amount = num.tryParse(value);
  return amount != null && amount.isFinite && amount < 1000000000000
      ? amount
      : null;
}

String hrDocumentMoney(String value) {
  final amount = hrDocumentAmount(value);
  if (amount == null) return value;
  final parts = amount.toStringAsFixed(2).split('.');
  return '\$${parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}.${parts[1]}';
}
