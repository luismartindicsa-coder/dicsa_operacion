const List<String> kMaintenanceVisibleStatusFlow = <String>[
  'aviso_falla',
  'cotizacion',
  'autorizacion_finanzas',
  'supervision',
  'cerrado',
];

const List<String> kMaintenanceSelectableStatuses = <String>[
  'aviso_falla',
  'cotizacion',
  'autorizacion_finanzas',
  'supervision',
  'cerrado',
  'rechazado',
];

const Map<String, String> kMaintenanceStatusLabel = <String, String>{
  'aviso_falla': 'Aviso de falla',
  'cotizacion': 'Cotizacion',
  'autorizacion_finanzas': 'Autorizacion',
  'supervision': 'Supervision',
  'cerrado': 'Cerrado',
  'rechazado': 'Rechazado',
};

String normalizeMaintenanceStatus(dynamic value) {
  final normalized = (value ?? '').toString().trim().toLowerCase();
  switch (normalized) {
    case 'revision_area':
    case 'reporte_mantenimiento':
      return 'aviso_falla';
    case 'autorizacion':
      return 'autorizacion_finanzas';
    case 'material_recolectado':
    case 'programado':
      return 'autorizacion_finanzas';
    case 'mantenimiento_realizado':
      return 'supervision';
    default:
      return normalized;
  }
}

String maintenanceStatusLabel(dynamic value) {
  final normalized = normalizeMaintenanceStatus(value);
  final label = kMaintenanceStatusLabel[normalized];
  if (label != null) return label;
  if (normalized.isEmpty) return '';
  return normalized
      .split('_')
      .where((part) => part.trim().isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String maintenanceStatusShortLabel(dynamic value) {
  switch (normalizeMaintenanceStatus(value)) {
    case 'aviso_falla':
      return 'Aviso';
    case 'cotizacion':
      return 'Cotizacion';
    case 'autorizacion_finanzas':
      return 'Autorizacion';
    case 'supervision':
      return 'Supervision';
    case 'cerrado':
      return 'Cerrado';
    case 'rechazado':
      return 'Rechazado';
    default:
      final label = maintenanceStatusLabel(value);
      return label.isEmpty ? 'Sin estatus' : label;
  }
}

bool isMaintenanceClosedStatus(dynamic value) {
  final normalized = normalizeMaintenanceStatus(value);
  return normalized == 'cerrado' || normalized == 'rechazado';
}

bool isMaintenanceExecutionStatus(dynamic value) {
  final normalized = normalizeMaintenanceStatus(value);
  return normalized == 'autorizacion_finanzas' || normalized == 'supervision';
}

bool isMaintenanceWaitingActionStatus(dynamic value) {
  final normalized = normalizeMaintenanceStatus(value);
  return normalized == 'cotizacion' || normalized == 'autorizacion_finanzas';
}

int maintenanceStatusSortIndex(dynamic value) {
  final normalized = normalizeMaintenanceStatus(value);
  final index = kMaintenanceVisibleStatusFlow.indexOf(normalized);
  if (index >= 0) return index;
  if (normalized == 'rechazado') return kMaintenanceVisibleStatusFlow.length;
  return 999;
}
