import 'package:flutter/material.dart';

/// Single registry for navigation, category cards and the initial workspaces.
@immutable
class DocumentalCategory {
  final String key;
  final String title;
  final IconData icon;
  final String description;
  final List<String> documentTypes;
  final List<String> columns;

  const DocumentalCategory({
    required this.key,
    required this.title,
    required this.icon,
    required this.description,
    required this.documentTypes,
    this.columns = const [
      'Documento',
      'Responsable',
      'Vencimiento',
      'Estatus',
      'Vigencia',
    ],
  });
}

const documentalCategories = <DocumentalCategory>[
  DocumentalCategory(
    key: 'documentacion-legal',
    title: 'Documentación Legal',
    icon: Icons.account_balance_rounded,
    description:
        'Documentos corporativos, poderes y expediente legal de DICSA.',
    documentTypes: [
      'Actas',
      'Poderes notariales',
      'Constancias fiscales',
      'Escrituras',
    ],
  ),
  DocumentalCategory(
    key: 'permisos-y-tramites',
    title: 'Permisos y Trámites',
    icon: Icons.assignment_rounded,
    description: 'Dependencias, responsables y seguimiento de cada gestión.',
    documentTypes: ['Permisos', 'Licencias', 'Trámites', 'Renovaciones'],
    columns: [
      'Trámite',
      'Dependencia',
      'Responsable',
      'Vencimiento',
      'Días',
      'Prioridad',
      'Estatus',
      'Semáforo',
      'Avance',
    ],
  ),
  DocumentalCategory(
    key: 'seguridad-e-higiene',
    title: 'Seguridad e Higiene',
    icon: Icons.health_and_safety_rounded,
    description:
        'Capacitaciones, estudios y obligaciones de seguridad laboral.',
    documentTypes: ['Capacitaciones', 'DC3', 'Estudios', 'Documentación STPS'],
  ),
  DocumentalCategory(
    key: 'medio-ambiente',
    title: 'Medio Ambiente',
    icon: Icons.eco_rounded,
    description: 'Autorizaciones, estudios y documentación ambiental.',
    documentTypes: [
      'Autorizaciones',
      'Manifiestos',
      'Residuos',
      'Agua y emisiones',
    ],
  ),
  DocumentalCategory(
    key: 'vehiculos',
    title: 'Vehículos',
    icon: Icons.local_shipping_rounded,
    description: 'Vigencias y documentos relacionados con las unidades.',
    documentTypes: ['Circulación', 'Verificaciones', 'Permisos', 'Licencias'],
    columns: ['Documento', 'Unidad', 'Responsable', 'Vencimiento', 'Vigencia'],
  ),
  DocumentalCategory(
    key: 'personal',
    title: 'Personal',
    icon: Icons.badge_rounded,
    description: 'Expedientes y constancias vinculados con el personal de RH.',
    documentTypes: [
      'Identificaciones',
      'Contratos laborales',
      'Certificaciones',
      'Constancias',
    ],
    columns: [
      'Documento',
      'Trabajador',
      'Responsable',
      'Vencimiento',
      'Vigencia',
    ],
  ),
  DocumentalCategory(
    key: 'proteccion-civil',
    title: 'Protección Civil',
    icon: Icons.shield_rounded,
    description:
        'Programas, dictámenes, brigadas y preparación ante emergencias.',
    documentTypes: [
      'Programa interno',
      'Vistos buenos',
      'Simulacros',
      'Dictámenes',
    ],
  ),
  DocumentalCategory(
    key: 'contratos',
    title: 'Contratos',
    icon: Icons.handshake_rounded,
    description: 'Acuerdos firmados, contrapartes y fechas de renovación.',
    documentTypes: [
      'Contratos firmados',
      'Convenios',
      'Anexos',
      'Renovaciones',
    ],
    columns: [
      'Contrato',
      'Contraparte',
      'Responsable',
      'Vencimiento',
      'Vigencia',
    ],
  ),
  DocumentalCategory(
    key: 'seguros',
    title: 'Seguros',
    icon: Icons.verified_user_rounded,
    description: 'Pólizas, coberturas y renovaciones de bienes y personas.',
    documentTypes: ['Pólizas', 'Coberturas', 'Endosos', 'Renovaciones'],
    columns: [
      'Póliza',
      'Aseguradora',
      'Responsable',
      'Vencimiento',
      'Vigencia',
    ],
  ),
  DocumentalCategory(
    key: 'mantenimiento',
    title: 'Mantenimiento',
    icon: Icons.build_circle_rounded,
    description:
        'Certificados, programas y evidencias de obligaciones periódicas.',
    documentTypes: ['Certificados', 'Programas', 'Inspecciones', 'Evidencias'],
  ),
  DocumentalCategory(
    key: 'auditorias',
    title: 'Auditorías',
    icon: Icons.fact_check_rounded,
    description:
        'Revisiones, hallazgos, acciones pendientes y evidencia final.',
    documentTypes: ['Auditorías', 'Hallazgos', 'Acciones', 'Informes finales'],
    columns: [
      'Auditoría',
      'Organismo',
      'Responsable',
      'Fecha programada',
      'Estatus',
    ],
  ),
];
