import 'package:uuid/uuid.dart';
import 'hr_document.dart';

/// Editable starting formats; policy rules and agreed terms are supplied by RH.
HrDocument hrDocumentBase(
  HrDocumentCategory category,
  DateTime today, {
  String kind = 'generated',
}) {
  const company = HrDocumentField('empresa', 'Empresa', required: true);
  const name = HrDocumentField(
    'nombre',
    'Nombre del colaborador',
    required: true,
  );
  const position = HrDocumentField('puesto', 'Puesto', required: true);
  const place = HrDocumentField('lugar', 'Lugar', required: true);
  const start = HrDocumentField(
    'inicio',
    'Fecha de inicio',
    type: 'date',
    required: true,
  );
  const end = HrDocumentField(
    'fin',
    'Fecha de término',
    type: 'date',
    required: true,
  );
  const amount = HrDocumentField(
    'monto',
    'Monto',
    type: 'money',
    required: true,
  );
  const terms = HrDocumentField(
    'condiciones',
    'Condiciones y acuerdos',
    type: 'multiline',
    required: true,
  );
  const observations = HrDocumentField(
    'observaciones',
    'Observaciones',
    type: 'multiline',
  );
  final fields = <HrDocumentField>[company, place];
  var body = '{{lugar}}, {{fecha}}\n\nEmpresa: {{empresa}}\n\n';
  var signatures = <Map<String, String>>[
    {'label': 'Elaboró', 'name': ''},
    {'label': 'Revisó', 'name': ''},
  ];
  switch (category) {
    case HrDocumentCategory.reglamento:
      fields.addAll([
        start,
        const HrDocumentField(
          'alcance',
          'Ámbito de aplicación',
          type: 'multiline',
          required: true,
        ),
        const HrDocumentField(
          'horarios',
          'Jornadas y horarios',
          type: 'multiline',
          required: true,
        ),
        const HrDocumentField(
          'reglas',
          'Disposiciones del reglamento',
          type: 'multiline',
          required: true,
        ),
      ]);
      body +=
          'Vigencia a partir de: {{inicio}}\n\nÁMBITO DE APLICACIÓN\n{{alcance}}\n\nJORNADAS Y HORARIOS\n{{horarios}}\n\nDISPOSICIONES\n{{reglas}}';
    case HrDocumentCategory.manual:
      fields.addAll([
        position,
        const HrDocumentField(
          'objetivo',
          'Objetivo del puesto',
          type: 'multiline',
          required: true,
        ),
        const HrDocumentField('responsable', 'Reporta a'),
        const HrDocumentField(
          'actividades',
          'Actividades y frecuencia',
          type: 'multiline',
          required: true,
        ),
        const HrDocumentField(
          'herramientas',
          'Herramientas y equipo',
          type: 'multiline',
        ),
      ]);
      body +=
          'Puesto: {{puesto}}\nReporta a: {{responsable}}\n\nOBJETIVO\n{{objetivo}}\n\nACTIVIDADES Y FRECUENCIA\n{{actividades}}\n\nHERRAMIENTAS Y EQUIPO\n{{herramientas}}';
    case HrDocumentCategory.comisiones:
      fields.addAll([
        position,
        start,
        const HrDocumentField(
          'base',
          'Base de cálculo',
          type: 'multiline',
          required: true,
        ),
        const HrDocumentField('tasa', 'Porcentaje o cuota', required: true),
        const HrDocumentField(
          'pago',
          'Periodicidad y fecha de pago',
          required: true,
        ),
        terms,
      ]);
      body +=
          'Puesto / alcance: {{puesto}}\nVigencia a partir de: {{inicio}}\n\nBASE DE CÁLCULO\n{{base}}\n\nPORCENTAJE O CUOTA\n{{tasa}}\n\nPAGO\n{{pago}}\n\nCONDICIONES\n{{condiciones}}';
    case HrDocumentCategory.telefono:
    case HrDocumentCategory.laptop:
    case HrDocumentCategory.unidad:
      final asset = switch (category) {
        HrDocumentCategory.telefono => 'Teléfono',
        HrDocumentCategory.laptop => 'Laptop',
        _ => 'Unidad',
      };
      fields.addAll([
        name,
        position,
        start,
        HrDocumentField(
          'equipo',
          '$asset: modelo, serie / identificación',
          required: true,
        ),
        const HrDocumentField(
          'estado',
          'Estado y accesorios al entregar',
          type: 'multiline',
          required: true,
        ),
        terms,
      ]);
      body +=
          'Colaborador: {{nombre}}\nPuesto: {{puesto}}\nFecha de entrega: {{inicio}}\n\nEQUIPO / UNIDAD\n{{equipo}}\n\nESTADO Y ACCESORIOS\n{{estado}}\n\nCONDICIONES DE USO, CUIDADO Y DEVOLUCIÓN\n{{condiciones}}';
      signatures = [
        {'label': 'Entrega', 'name': ''},
        {'label': 'Recibe', 'name': ''},
      ];
    case HrDocumentCategory.vacaciones:
      fields.addAll([
        name,
        position,
        start,
        end,
        const HrDocumentField(
          'dias',
          'Días acordados',
          type: 'number',
          required: true,
        ),
        const HrDocumentField(
          'regreso',
          'Fecha de regreso',
          type: 'date',
          required: true,
        ),
        terms,
      ]);
      body +=
          'Colaborador: {{nombre}}\nPuesto: {{puesto}}\n\nPERIODO ACORDADO\nDel {{inicio}} al {{fin}}\nDías: {{dias}}\nRegreso: {{regreso}}\n\nACUERDOS\n{{condiciones}}';
      signatures = [
        {'label': 'Colaborador', 'name': ''},
        {'label': 'Representante de la empresa', 'name': ''},
      ];
    case HrDocumentCategory.finiquito:
      fields.addAll([
        name,
        position,
        start,
        end,
        amount,
        const HrDocumentField(
          'conceptos',
          'Desglose de conceptos e importes',
          type: 'multiline',
          required: true,
        ),
        const HrDocumentField('pago', 'Forma y fecha de pago', required: true),
        terms,
      ]);
      body +=
          'Colaborador: {{nombre}}\nPuesto: {{puesto}}\nFecha de ingreso: {{inicio}}\nFecha de término: {{fin}}\n\nCONCEPTOS\n{{conceptos}}\n\nMonto indicado: {{monto}}\nForma y fecha de pago: {{pago}}\n\nACUERDOS\n{{condiciones}}';
      signatures = [
        {'label': 'Colaborador', 'name': ''},
        {'label': 'Representante de la empresa', 'name': ''},
      ];
    case HrDocumentCategory.renuncia:
      fields.addAll([
        name,
        position,
        end,
        const HrDocumentField('destinatario', 'Dirigida a', required: true),
        const HrDocumentField(
          'declaracion',
          'Declaración del colaborador',
          type: 'multiline',
          required: true,
        ),
      ]);
      body +=
          'A: {{destinatario}}\n\nNombre: {{nombre}}\nPuesto: {{puesto}}\nFecha de separación indicada: {{fin}}\n\nDECLARACIÓN\n{{declaracion}}';
      signatures = [
        {'label': 'Colaborador', 'name': ''},
      ];
    case HrDocumentCategory.recomendacion:
      fields.addAll([
        name,
        position,
        start,
        end,
        const HrDocumentField('destinatario', 'Dirigida a', required: true),
        const HrDocumentField(
          'referencia',
          'Referencia y recomendación',
          type: 'multiline',
          required: true,
        ),
        const HrDocumentField('contacto', 'Datos de contacto'),
      ]);
      body +=
          'A: {{destinatario}}\n\nColaborador: {{nombre}}\nPuesto desempeñado: {{puesto}}\nPeriodo: {{inicio}} al {{fin}}\n\nREFERENCIA\n{{referencia}}\n\nContacto: {{contacto}}';
      signatures = [
        {'label': 'Emite la recomendación', 'name': ''},
      ];
    case HrDocumentCategory.acta:
      fields.addAll([
        name,
        position,
        const HrDocumentField(
          'hechos_fecha',
          'Fecha de los hechos',
          type: 'date',
          required: true,
        ),
        const HrDocumentField('hora', 'Hora'),
        const HrDocumentField(
          'hechos',
          'Descripción de los hechos',
          type: 'multiline',
          required: true,
        ),
        const HrDocumentField(
          'declaracion',
          'Manifestación del colaborador',
          type: 'multiline',
          required: true,
        ),
        const HrDocumentField(
          'acuerdos',
          'Acuerdos y seguimiento',
          type: 'multiline',
          required: true,
        ),
      ]);
      body +=
          'Colaborador: {{nombre}}\nPuesto: {{puesto}}\nFecha de los hechos: {{hechos_fecha}}\nHora: {{hora}}\n\nHECHOS\n{{hechos}}\n\nMANIFESTACIÓN DEL COLABORADOR\n{{declaracion}}\n\nACUERDOS Y SEGUIMIENTO\n{{acuerdos}}';
      signatures = [
        {'label': 'Colaborador', 'name': ''},
        {'label': 'Representante de RH', 'name': ''},
        {'label': 'Testigo 1', 'name': ''},
        {'label': 'Testigo 2', 'name': ''},
      ];
    case HrDocumentCategory.otros:
      fields.addAll([
        name,
        position,
        const HrDocumentField('monto', 'Monto', type: 'money'),
        const HrDocumentField(
          'contenido',
          'Contenido',
          type: 'multiline',
          required: true,
        ),
      ]);
      body +=
          'Colaborador: {{nombre}}\nPuesto: {{puesto}}\nMonto: {{monto}}\n\n{{contenido}}';
  }
  fields.add(observations);
  if (kind == 'uploaded') {
    fields
      ..clear()
      ..addAll([company, name, position, observations]);
  }
  body += '\n\nOBSERVACIONES\n{{observaciones}}';
  return HrDocument({
    'id': const Uuid().v4(),
    'revision': 0,
    'category': category.name,
    'kind': kind,
    'title': category.label,
    'document_date': hrDocumentIsoDate(today),
    'body': kind == 'uploaded' ? '' : body,
    'fields': fields.map((f) => f.toJson()).toList(),
    'data': <String, String>{},
    'signatures': signatures,
    'file': null,
    'employee_id': null,
    'archived': false,
  });
}
