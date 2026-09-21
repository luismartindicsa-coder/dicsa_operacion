import '../shared/utils/number_formatters.dart';

/// Includes the app navigation and operational modules, not only areas with
/// an individual Friday report. Catalogs belong to their consuming area.
enum DirectionSummaryArea {
  operaciones(
    'Operación y Producción',
    'Operación',
    'Producción y mantenimiento',
  ),
  bascula('Báscula', 'Báscula', 'Entradas, salidas y pesadas'),
  inventario('Inventario', 'Operación', 'Existencias generales y comerciales'),
  almacen('Almacén', 'Operación', 'Artículos y mínimos de almacén'),
  logistica('Logística', 'Logística', 'Viajes, servicios y combustible'),
  embarques('Embarques', 'Dirección / Logística', 'Planeación de embarques'),
  menudeo('Menudeo', 'Menudeo', 'Tickets, caja, cortes y precios'),
  compras('Compras Mayoreo', 'Compras', 'Compras registradas de material'),
  ventas('Ventas Mayoreo', 'Ventas', 'Ventas y cobranza'),
  desarrolloComercial(
    'Desarrollo Comercial',
    'Desarrollo Comercial',
    'CRM, prospectos y agenda',
  ),
  finanzas('Finanzas', 'Finanzas', 'Bancos y facturas por pagar'),
  boveda('Bóveda', 'Dirección', 'Vales de efectivo'),
  gastos('Gastos', 'Gastos', 'Órdenes de compra de mantenimiento'),
  contabilidad(
    'Contabilidad',
    'Contabilidad',
    'Resultado comercial y estado de resultados',
  ),
  rh('Recursos Humanos', 'Recursos Humanos', 'Plantilla, asistencia y nómina'),
  gestion(
    'Gestión Documental',
    'Gestión Documental',
    'Expedientes, vencimientos y agenda',
  ),
  gerencia('Gerencia', 'Gerencia', 'Metas de producción y embarques'),
  supervision(
    'Supervisión',
    'Dirección',
    'Historial local de generación de reportes',
  );

  const DirectionSummaryArea(this.title, this.owner, this.source);
  final String title, owner, source;
}

class DirectionSummaryMetric {
  const DirectionSummaryMetric(this.label, this.current, [this.previous = '—']);
  final String label, current, previous;
}

class DirectionAreaSummary {
  const DirectionAreaSummary({
    required this.area,
    required this.basis,
    required this.metrics,
    this.alerts = const [],
    this.notes = const [],
    this.available = true,
  });
  final DirectionSummaryArea area;
  final String basis;
  final List<DirectionSummaryMetric> metrics;
  final List<String> alerts, notes;
  final bool available;

  factory DirectionAreaSummary.unavailable(
    DirectionSummaryArea area,
  ) => DirectionAreaSummary(
    area: area,
    basis: 'Consulta no disponible',
    metrics: const [],
    available: false,
    alerts: [
      'No se pudo consultar la base. Revisar conexión y permisos y volver a generar el reporte.',
    ],
    notes: ['No se muestran ceros ni se infiere ausencia de actividad.'],
  );
}

typedef DirectionAreaLoader = Future<DirectionAreaSummary> Function();

/// Every area keeps its place even when one source is unavailable. A failed
/// request cannot turn into a zero or silently remove an area from the PDF.
Future<List<DirectionAreaSummary>> collectDirectionAreaSummaries(
  Map<DirectionSummaryArea, DirectionAreaLoader> loaders,
) async => Future.wait([
  for (final area in DirectionSummaryArea.values)
    () async {
      try {
        final loader = loaders[area];
        if (loader == null) return DirectionAreaSummary.unavailable(area);
        final summary = await loader();
        if (summary.area != area) {
          throw StateError('Área de resumen incorrecta');
        }
        return summary;
      } catch (_) {
        return DirectionAreaSummary.unavailable(area);
      }
    }(),
]);

String directionSummaryNumber(num? n, [String unit = '']) => n == null
    ? 'Sin dato'
    : '${formatDecimal(n.toDouble(), decimals: 2)}${unit.isEmpty ? '' : ' $unit'}';
String directionSummaryMoney(num? n) =>
    n == null ? 'Sin dato' : '\$${formatDecimal(n.toDouble(), decimals: 2)}';
