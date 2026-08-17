import 'package:flutter/material.dart';

enum ManagementAreaKey {
  operaciones,
  bascula,
  logistica,
  menudeo,
  rh,
  ventas,
  gastos,
  gestion,
  finanzas,
  gerencia,
  desarrolloComercial,
  direccionGeneral,
  contabilidad,
}

enum ManagementReportFrequency { daily, weeklyFriday }

enum ManagementReportDataStatus { ready, partial, pending }

class ManagementReportDefinition {
  final String key;
  final String title;
  final ManagementReportFrequency frequency;
  final ManagementReportDataStatus dataStatus;
  final String sourceLabel;
  final String followUpPrompt;

  const ManagementReportDefinition({
    required this.key,
    required this.title,
    required this.frequency,
    required this.dataStatus,
    required this.sourceLabel,
    required this.followUpPrompt,
  });
}

class ManagementAreaDefinition {
  final ManagementAreaKey key;
  final String title;
  final String ownerLabel;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final List<ManagementReportDefinition> reports;

  const ManagementAreaDefinition({
    required this.key,
    required this.title,
    required this.ownerLabel,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.reports,
  });

  bool get hasDailyReports =>
      reports.any((row) => row.frequency == ManagementReportFrequency.daily);

  List<ManagementReportDefinition> reportsFor(
    ManagementReportFrequency frequency,
  ) {
    return reports
        .where((row) => row.frequency == frequency)
        .toList(growable: false);
  }

  int countByStatus(
    ManagementReportFrequency frequency,
    ManagementReportDataStatus status,
  ) {
    return reportsFor(
      frequency,
    ).where((row) => row.dataStatus == status).length;
  }
}

const List<ManagementAreaDefinition>
managementAreaCatalog = <ManagementAreaDefinition>[
  ManagementAreaDefinition(
    key: ManagementAreaKey.operaciones,
    title: 'Operaciones',
    ownerLabel: 'Encargado de Operaciones',
    subtitle:
        'OTs, producción, patio e incidencias para seguimiento diario y de cierre semanal.',
    accent: Color(0xFF0B72FF),
    icon: Icons.precision_manufacturing_rounded,
    reports: <ManagementReportDefinition>[
      ManagementReportDefinition(
        key: 'operations_ot_weekly',
        title: 'Seguimiento de OTs',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'maintenance_orders + flujo de estatus',
        followUpPrompt:
            'Qué OTs siguen abiertas, qué está bloqueando el cierre y quién responde por ellas.',
      ),
      ManagementReportDefinition(
        key: 'operations_new_ot_daily',
        title: 'OTs diarias nuevas',
        frequency: ManagementReportFrequency.daily,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'maintenance_orders',
        followUpPrompt:
            'Qué OTs nacieron hoy, cuáles son urgentes y cuáles debieron prevenirse.',
      ),
      ManagementReportDefinition(
        key: 'operations_ot_costs',
        title: 'Gastos en OTs',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'maintenance_orders + compras OT',
        followUpPrompt:
            'Dónde se fue el dinero, qué OT se desvió y qué acción de control toca.',
      ),
      ManagementReportDefinition(
        key: 'operations_yard_incidents',
        title: 'Incidencias en patio',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'fuente pendiente',
        followUpPrompt:
            'Qué se repitió en patio, cuál fue la causa raíz y quién queda asignado.',
      ),
      ManagementReportDefinition(
        key: 'operations_cleanliness_daily',
        title: 'KPIs de limpieza',
        frequency: ManagementReportFrequency.daily,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Captura pendiente',
        followUpPrompt:
            'Qué estándar no se cumplió hoy y qué corrección inmediata toca.',
      ),
      ManagementReportDefinition(
        key: 'operations_production_weekly',
        title: 'Análisis de producción',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'production_runs',
        followUpPrompt:
            'Qué material avanzó, cuál quedó abajo y qué cuello de botella apareció.',
      ),
    ],
  ),
  ManagementAreaDefinition(
    key: ManagementAreaKey.bascula,
    title: 'Báscula',
    ownerLabel: 'Encargado de Báscula',
    subtitle:
        'Entradas, salidas, tickets y errores operativos para lectura de corte semanal.',
    accent: Color(0xFF21C9A6),
    icon: Icons.scale_rounded,
    reports: <ManagementReportDefinition>[
      ManagementReportDefinition(
        key: 'bascula_incoming_material',
        title: 'Qué material entró',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Pesadas',
        followUpPrompt:
            'Qué materiales entraron más, cómo cambió el mix y qué diferencia llama la atención.',
      ),
      ManagementReportDefinition(
        key: 'bascula_outgoing_material',
        title: 'Qué material salió',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Inventario salidas',
        followUpPrompt:
            'Qué salió realmente y si hay desfase contra embarques o patio.',
      ),
      ManagementReportDefinition(
        key: 'bascula_public_vs_provider',
        title: 'Entradas de público vs proveedor',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Pesadas + clasificación',
        followUpPrompt:
            'Cómo se repartió la entrada y qué dependencia operativa se está formando.',
      ),
      ManagementReportDefinition(
        key: 'bascula_week_comparison',
        title: 'Comparación entre semana actual y pasada',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Pesadas histórico',
        followUpPrompt:
            'Qué subió, qué bajó y qué cambio necesita explicación del área.',
      ),
      ManagementReportDefinition(
        key: 'bascula_ticket_errors',
        title: 'KPIs de errores en tickets',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Pesadas + captura tickets',
        followUpPrompt:
            'Qué error se repite, dónde se origina y cómo se corrige el sistema.',
      ),
    ],
  ),
  ManagementAreaDefinition(
    key: ManagementAreaKey.logistica,
    title: 'Logística',
    ownerLabel: 'Encargado de Logística',
    subtitle:
        'Combustible, viajes, unidades y complicaciones para la junta semanal del viernes.',
    accent: Color(0xFF9FAAB4),
    icon: Icons.local_shipping_rounded,
    reports: <ManagementReportDefinition>[
      ManagementReportDefinition(
        key: 'logistics_diesel',
        title: 'Cuánto diesel se consumió',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Diesel logística',
        followUpPrompt:
            'Qué consumo fue razonable, cuál se desvió y qué ruta o unidad lo explica.',
      ),
      ManagementReportDefinition(
        key: 'logistics_gasoline',
        title: 'Cuánta gasolina se consumió',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Gasolina logística',
        followUpPrompt:
            'Qué consumos no estaban planeados y qué se debe corregir la próxima semana.',
      ),
      ManagementReportDefinition(
        key: 'logistics_top_unit_fuel',
        title: 'Qué unidad consumió más combustible',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Diesel + gasolina',
        followUpPrompt:
            'Qué unidad se disparó y si es por carga, ruta, falla o disciplina.',
      ),
      ManagementReportDefinition(
        key: 'logistics_trips_operator',
        title: 'Número de viajes por operador',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Control diario logística',
        followUpPrompt:
            'Cómo estuvo distribuida la carga de trabajo y dónde hubo saturación.',
      ),
      ManagementReportDefinition(
        key: 'logistics_trips_unit',
        title: 'Número de viajes por unidad',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Control diario + unidades',
        followUpPrompt:
            'Qué unidad cargó más presión y qué balanceo necesita la flotilla.',
      ),
      ManagementReportDefinition(
        key: 'logistics_km',
        title: 'Kilómetros recorridos',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Bitácora logística',
        followUpPrompt:
            'Qué trayecto consumió más capacidad y qué ajuste de ruta toca.',
      ),
      ManagementReportDefinition(
        key: 'logistics_driver_complications',
        title: 'Complicaciones con choferes',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Incidencias logística',
        followUpPrompt:
            'Qué complicación humana se repite y cómo se previene con claridad de rol.',
      ),
      ManagementReportDefinition(
        key: 'logistics_unit_complications',
        title: 'Complicaciones con unidades',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Logística + flotilla',
        followUpPrompt:
            'Qué unidad volvió a fallar y qué decisión operativa requiere.',
      ),
      ManagementReportDefinition(
        key: 'logistics_canceled_trips',
        title: 'Viajes cancelados',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Control diario',
        followUpPrompt:
            'Qué cancelación sí era inevitable y cuál vino de mala planeación.',
      ),
      ManagementReportDefinition(
        key: 'logistics_top_destinations',
        title: 'Destinos con más viajes',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Servicios logística',
        followUpPrompt:
            'Qué destinos concentran demanda y qué ahorro se puede diseñar por ruta.',
      ),
      ManagementReportDefinition(
        key: 'logistics_people_complications',
        title:
            'KPIs de complicaciones personales con choferes, empresas y equipo DICSA',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Incidencias formalizadas',
        followUpPrompt:
            'Qué complicación de coordinación está dañando servicio y cómo se sistematiza.',
      ),
    ],
  ),
  ManagementAreaDefinition(
    key: ManagementAreaKey.menudeo,
    title: 'Menudeo',
    ownerLabel: 'Encargado de Menudeo',
    subtitle:
        'Caja, compras, ajustes de precio y salud comercial resumidos para el viernes.',
    accent: Color(0xFF35506A),
    icon: Icons.storefront_rounded,
    reports: <ManagementReportDefinition>[
      ManagementReportDefinition(
        key: 'retail_main_expenses',
        title: 'Gastos principales',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Caja menudeo',
        followUpPrompt:
            'En qué salió más dinero y qué parte era prevenible o recurrente.',
      ),
      ManagementReportDefinition(
        key: 'retail_purchase_summary',
        title: 'Compras resumidas',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Tickets menudeo',
        followUpPrompt:
            'Qué se compró realmente, cómo cambió la mezcla y dónde hubo oportunidad.',
      ),
      ManagementReportDefinition(
        key: 'retail_price_adjustments',
        title: 'Precios ajustados',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Historial de precios',
        followUpPrompt:
            'Qué ajuste se movió, por qué se autorizó y qué impacto comercial tuvo.',
      ),
      ManagementReportDefinition(
        key: 'retail_missing_providers',
        title: 'Proveedores ausentes',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Tickets + catálogo',
        followUpPrompt:
            'Qué proveedor faltó, qué impacto causó y qué cobertura alterna toca.',
      ),
      ManagementReportDefinition(
        key: 'retail_weekly_comparison',
        title: 'Comparativa semanal en kg, importe y precio',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Análisis menudeo',
        followUpPrompt:
            'Qué mejoró, qué empeoró y si el precio acompañó el costo real.',
      ),
      ManagementReportDefinition(
        key: 'retail_cash_closure_kpi',
        title: 'KPIs de caja no cuadrante en cierre',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Cortes de caja',
        followUpPrompt: 'Qué cierre no cuadró, cuánto fue y qué control faltó.',
      ),
    ],
  ),
  ManagementAreaDefinition(
    key: ManagementAreaKey.rh,
    title: 'RH',
    ownerLabel: 'Responsable de Recursos Humanos',
    subtitle:
        'Nómina, ausencias, permisos, vacaciones y plantilla por cubrir aún en homologación.',
    accent: Color(0xFFB78B5A),
    icon: Icons.badge_rounded,
    reports: <ManagementReportDefinition>[
      ManagementReportDefinition(
        key: 'hr_payroll',
        title: 'Reporte de nómina fiscal y efectivo',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Prenómina RH',
        followUpPrompt:
            'Qué diferencia aparece entre fiscal y efectivo y qué decisión requiere.',
      ),
      ManagementReportDefinition(
        key: 'hr_absences',
        title: 'Reporte de ausencias, permisos y vacaciones',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Asistencia + permisos + vacaciones',
        followUpPrompt:
            'Quién faltó más, qué patrón se repite y qué área está absorbiendo el costo.',
      ),
      ManagementReportDefinition(
        key: 'hr_frequent_incidents',
        title: 'Incidencias frecuentes',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Incidencias RH',
        followUpPrompt:
            'Qué incidencia se repitió y cómo se corrige el sistema y no solo el caso.',
      ),
      ManagementReportDefinition(
        key: 'hr_accidents',
        title: 'Reporte de accidentes',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Captura pendiente',
        followUpPrompt:
            'Qué accidente ocurrió, cuál fue la causa y qué prevención sigue.',
      ),
      ManagementReportDefinition(
        key: 'hr_recruitment',
        title: 'Avances en reclutamiento',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Flujo pendiente',
        followUpPrompt:
            'Qué vacantes avanzaron, cuáles se atoraron y qué apoyo necesita RH.',
      ),
      ManagementReportDefinition(
        key: 'hr_departures',
        title: 'Informe de bajas',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Flujo pendiente',
        followUpPrompt:
            'Qué bajas ocurrieron y qué revela eso del sistema del área.',
      ),
      ManagementReportDefinition(
        key: 'hr_headcount_gap',
        title: 'Plantilla por cubrir',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Flujo pendiente',
        followUpPrompt:
            'Qué puestos siguen abiertos y cuál es su impacto operativo.',
      ),
    ],
  ),
  ManagementAreaDefinition(
    key: ManagementAreaKey.ventas,
    title: 'Ventas',
    ownerLabel: 'Responsable Comercial de Ventas',
    subtitle:
        'Cobranza, facturación pendiente, precios y seguimiento comercial por institucionalizar.',
    accent: Color(0xFF5A4ED3),
    icon: Icons.sell_rounded,
    reports: <ManagementReportDefinition>[
      ManagementReportDefinition(
        key: 'sales_pending_collection',
        title: 'Facturas y cheques pendientes de cobrar',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Mayoreo + finanzas',
        followUpPrompt:
            'Qué cobranza urge y quién se hará responsable de moverla.',
      ),
      ManagementReportDefinition(
        key: 'sales_pending_invoice',
        title: 'Ventas pendientes de facturar o relacionar',
        frequency: ManagementReportFrequency.daily,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Ventas mayoreo',
        followUpPrompt: 'Qué venta quedó colgada hoy y qué impide cerrarla.',
      ),
      ManagementReportDefinition(
        key: 'sales_yard_delays',
        title: 'Atrasos en patio / motivo KPIs',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Cruce pendiente',
        followUpPrompt:
            'Qué atraso pegó a ventas y cómo se coordina con patio.',
      ),
      ManagementReportDefinition(
        key: 'sales_price_adjustments',
        title: 'Ajustes en precios',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Historial comercial',
        followUpPrompt:
            'Qué ajuste se aprobó y si defendió margen o solo resolvió urgencia.',
      ),
      ManagementReportDefinition(
        key: 'sales_whatsapp_contacts',
        title: 'Resumen de clientes y proveedores contactados por WhatsApp',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Fuente pendiente',
        followUpPrompt:
            'Qué seguimiento sí se movió y qué conversación sigue dependiendo de memoria.',
      ),
      ManagementReportDefinition(
        key: 'sales_payment_times',
        title: 'Análisis de tiempos de pago',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Mayoreo + finanzas',
        followUpPrompt:
            'Qué clientes pagan más lento y qué política comercial se ajusta.',
      ),
    ],
  ),
  ManagementAreaDefinition(
    key: ManagementAreaKey.gastos,
    title: 'Gastos',
    ownerLabel: 'Responsable de Compras y Gastos',
    subtitle:
        'Urgencias, flujo de compras y mezcla de gasto operativo con foco diario y semanal.',
    accent: Color(0xFFE67E22),
    icon: Icons.receipt_long_rounded,
    reports: <ManagementReportDefinition>[
      ManagementReportDefinition(
        key: 'expenses_urgent_purchases',
        title: 'Compras urgentes',
        frequency: ManagementReportFrequency.daily,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Compras + OT',
        followUpPrompt:
            'Qué compra de hoy fue realmente urgente y cuál vino de mala previsión.',
      ),
      ManagementReportDefinition(
        key: 'expenses_real_vs_estimate',
        title: 'Real vs estimado',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Compras + finanzas',
        followUpPrompt:
            'Qué gasto se salió del estimado y qué ajuste de planeación toca.',
      ),
      ManagementReportDefinition(
        key: 'expenses_ot_linked',
        title: 'Compras ligadas a OTs',
        frequency: ManagementReportFrequency.daily,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Compras OT',
        followUpPrompt:
            'Qué compra quedó ligada a una OT y si sí era la solución correcta.',
      ),
      ManagementReportDefinition(
        key: 'expenses_flow_feedback',
        title: 'Retroalimentación del flujo de compras',
        frequency: ManagementReportFrequency.daily,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Flujo pendiente',
        followUpPrompt:
            'Qué parte del flujo sigue atorando a operación y qué regla lo corrige.',
      ),
      ManagementReportDefinition(
        key: 'expenses_payment_mix',
        title: 'Compras en efectivo, tarjeta y factura',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Compras + caja + bancos',
        followUpPrompt:
            'Cómo se está pagando y si la mezcla actual es sana para control financiero.',
      ),
    ],
  ),
  ManagementAreaDefinition(
    key: ManagementAreaKey.gestion,
    title: 'Gestión',
    ownerLabel: 'Responsable de Gestión',
    subtitle:
        'Permisos, manifiestos, documentos y subsidios aún pendientes de aterrizar en flujo formal.',
    accent: Color(0xFF7B8A8B),
    icon: Icons.assignment_turned_in_rounded,
    reports: <ManagementReportDefinition>[
      ManagementReportDefinition(
        key: 'management_permissions',
        title: 'Seguimiento de permisos',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Fuente pendiente',
        followUpPrompt:
            'Qué permiso sigue pendiente, quién lo mueve y qué riesgo genera.',
      ),
      ManagementReportDefinition(
        key: 'management_manifests',
        title: 'Análisis de cantidad, material y destino de manifiestos',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Fuente pendiente',
        followUpPrompt:
            'Qué manifiesto concentra riesgo y qué patrón debemos supervisar.',
      ),
      ManagementReportDefinition(
        key: 'management_waybills',
        title: 'Reporte de remisiones y carta porte',
        frequency: ManagementReportFrequency.daily,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Fuente pendiente',
        followUpPrompt:
            'Qué documento diario falta y qué salida queda en riesgo.',
      ),
      ManagementReportDefinition(
        key: 'management_supports',
        title: 'Seguimiento a apoyos y subsidios del gobierno',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Fuente pendiente',
        followUpPrompt:
            'Qué apoyo sí avanza y qué trámite está detenido sin responsable claro.',
      ),
      ManagementReportDefinition(
        key: 'management_expirations',
        title: 'Seguimiento a cursos, vencimientos y caducidades de documentos',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Fuente pendiente',
        followUpPrompt:
            'Qué documento está por vencer y cómo evitamos depender de urgencia.',
      ),
      ManagementReportDefinition(
        key: 'management_contracts',
        title: 'Resúmenes de contratos',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Fuente pendiente',
        followUpPrompt:
            'Qué contrato requiere atención y qué compromiso operativo activa.',
      ),
    ],
  ),
  ManagementAreaDefinition(
    key: ManagementAreaKey.finanzas,
    title: 'Finanzas',
    ownerLabel: 'Responsable de Finanzas',
    subtitle:
        'Presupuesto, pagos urgentes, vencimientos y flujo bancario con lectura diaria y semanal.',
    accent: Color(0xFFB85F22),
    icon: Icons.account_balance_wallet_rounded,
    reports: <ManagementReportDefinition>[
      ManagementReportDefinition(
        key: 'finance_budget_daily',
        title: 'Presupuesto',
        frequency: ManagementReportFrequency.daily,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Centro de pagos',
        followUpPrompt:
            'Qué presión de caja hay hoy y qué pagos sí deben salir contra los que pueden esperar.',
      ),
      ManagementReportDefinition(
        key: 'finance_budget_weekly',
        title: 'Presupuesto',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Centro de pagos',
        followUpPrompt:
            'Qué presión semanal quedó, qué reserva falta y dónde está el hueco real.',
      ),
      ManagementReportDefinition(
        key: 'finance_agreements',
        title: 'Avance de convenios',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Convenios proveedor',
        followUpPrompt:
            'Qué convenio avanzó, cuál se atoró y qué negociación necesita escalarse.',
      ),
      ManagementReportDefinition(
        key: 'finance_forecast',
        title: 'Forecast de pagos',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Pagos + vencimientos',
        followUpPrompt:
            'Qué pagos se vienen y qué tensión se forma en la semana siguiente.',
      ),
      ManagementReportDefinition(
        key: 'finance_overdue',
        title: 'Facturas vencidas',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Cuentas por proveedor',
        followUpPrompt:
            'Qué venció, desde cuándo y cuál es el plan concreto de salida.',
      ),
      ManagementReportDefinition(
        key: 'finance_urgent_payments',
        title: 'Pagos urgentes',
        frequency: ManagementReportFrequency.daily,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Due alerts',
        followUpPrompt:
            'Qué pago urge hoy y si la urgencia viene de mala anticipación o condición real.',
      ),
      ManagementReportDefinition(
        key: 'finance_bank_flow',
        title: 'Flujo bancario',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Movimientos bancarios',
        followUpPrompt:
            'Cómo entró y salió el dinero esta semana y qué decisión toca tomar.',
      ),
    ],
  ),
  ManagementAreaDefinition(
    key: ManagementAreaKey.gerencia,
    title: 'Gerencia',
    ownerLabel: 'Gerente del área',
    subtitle:
        'Metas, problemas, cobros, pagos y seguimiento a nuevos negocios desde lectura ejecutiva.',
    accent: Color(0xFFD84B5B),
    icon: Icons.monitor_heart_outlined,
    reports: <ManagementReportDefinition>[
      ManagementReportDefinition(
        key: 'management_goals',
        title: 'Cumplimiento de metas',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Gerencia semanal',
        followUpPrompt:
            'Qué meta sí se movió, cuál no y qué apoyo interárea requiere.',
      ),
      ManagementReportDefinition(
        key: 'management_problem_kpis',
        title: 'Análisis KPI de problemas en DICSA y otras empresas',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Fuente pendiente',
        followUpPrompt:
            'Qué problema se repite, cómo se clasifica y quién debe tomarlo.',
      ),
      ManagementReportDefinition(
        key: 'management_new_business',
        title: 'Seguimiento a nuevos negocios',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Comercial + gerencia',
        followUpPrompt:
            'Qué negocio avanza, qué se enfrió y cuál merece priorización.',
      ),
      ManagementReportDefinition(
        key: 'management_pending_collections',
        title: 'Cobros y pagos pendientes',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Finanzas + comercial',
        followUpPrompt:
            'Qué pendiente amenaza más la operación y quién lo toma al cierre.',
      ),
      ManagementReportDefinition(
        key: 'management_bonuses',
        title: 'Manejo de bonos y comisiones',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'Fuente pendiente',
        followUpPrompt:
            'Qué bono aplica, qué comisión se ganó y qué criterio debe quedar claro.',
      ),
    ],
  ),
  ManagementAreaDefinition(
    key: ManagementAreaKey.desarrolloComercial,
    title: 'Desarrollo Comercial',
    ownerLabel: 'Responsable de Desarrollo Comercial',
    subtitle:
        'Prospectos, visitas y seguimiento comercial aún sin CRM homologado dentro de la app.',
    accent: Color(0xFF7C4DFF),
    icon: Icons.radar_rounded,
    reports: <ManagementReportDefinition>[
      ManagementReportDefinition(
        key: 'commercial_visits',
        title: 'Reporte de visitas',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'CRM pendiente',
        followUpPrompt:
            'A quién se visitó, qué resultado dejó y qué seguimiento quedó pactado.',
      ),
      ManagementReportDefinition(
        key: 'commercial_10_prospects',
        title: 'Meta 10 prospectos nuevos a la semana',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'CRM pendiente',
        followUpPrompt:
            'Cuántos prospectos se abrieron y qué calidad real tienen.',
      ),
      ManagementReportDefinition(
        key: 'commercial_conventions',
        title: 'Agenda de convenciones',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'CRM pendiente',
        followUpPrompt:
            'Qué evento conviene atender y cuál aporta más contactos útiles.',
      ),
      ManagementReportDefinition(
        key: 'commercial_contacts',
        title: 'Agenda de nuevos contactos',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'CRM pendiente',
        followUpPrompt:
            'Qué contactos nuevos aparecieron y qué siguiente paso tiene cada uno.',
      ),
      ManagementReportDefinition(
        key: 'commercial_followup',
        title: 'Seguimiento a prospectos',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'CRM pendiente',
        followUpPrompt:
            'Qué prospectos se movieron y cuáles siguen sin empuje.',
      ),
      ManagementReportDefinition(
        key: 'commercial_parts_sales',
        title: 'Seguimiento de ventas de piezas',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.pending,
        sourceLabel: 'CRM pendiente',
        followUpPrompt:
            'Qué venta de piezas cerró y qué canal está funcionando mejor.',
      ),
    ],
  ),
  ManagementAreaDefinition(
    key: ManagementAreaKey.direccionGeneral,
    title: 'Dirección General',
    ownerLabel: 'Dirección General',
    subtitle:
        'Producción, embarques, metas, supervisión y avance de app para la junta ejecutiva semanal.',
    accent: Color(0xFFD8E38A),
    icon: Icons.home_work_rounded,
    reports: <ManagementReportDefinition>[
      ManagementReportDefinition(
        key: 'direction_production_shipments',
        title: 'Análisis de producción y embarques',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Producción + embarques',
        followUpPrompt:
            'Qué salió contra lo producido y dónde está el desbalance real.',
      ),
      ManagementReportDefinition(
        key: 'direction_shipment_times',
        title: 'Horarios de embarques',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Embarques',
        followUpPrompt:
            'Qué horario se volvió cuello de botella y qué ajuste operativo toca.',
      ),
      ManagementReportDefinition(
        key: 'direction_goals',
        title: 'Cumplimiento de metas',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Gerencia + dirección',
        followUpPrompt:
            'Qué meta de la semana sí cerró y qué meta sigue vulnerable.',
      ),
      ManagementReportDefinition(
        key: 'direction_supervision',
        title: 'Reportes de supervisión',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Supervisión por áreas',
        followUpPrompt:
            'Qué áreas llegaron preparadas y dónde sigue faltando sistema.',
      ),
      ManagementReportDefinition(
        key: 'direction_app_progress',
        title: 'Avance en desarrollo de app',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Hitos de desarrollo',
        followUpPrompt:
            'Qué se entregó, qué sigue y qué bloqueo requiere decisión de dirección.',
      ),
    ],
  ),
  ManagementAreaDefinition(
    key: ManagementAreaKey.contabilidad,
    title: 'Contabilidad',
    ownerLabel: 'Responsable de Contabilidad',
    subtitle:
        'Resultado comercial, flujo, gastos, estado de resultados y balance desde capa de lectura.',
    accent: Color(0xFF67D2D8),
    icon: Icons.account_balance_rounded,
    reports: <ManagementReportDefinition>[
      ManagementReportDefinition(
        key: 'accounting_trade_result',
        title: 'Resultado comercial',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Contabilidad comercial',
        followUpPrompt:
            'Qué se compró, qué se vendió y cómo se abrió o cerró el margen.',
      ),
      ManagementReportDefinition(
        key: 'accounting_flow',
        title: 'Flujo general',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Flujo general',
        followUpPrompt:
            'Qué dinero entró, salió y cuánto del gasto fue realmente operativo.',
      ),
      ManagementReportDefinition(
        key: 'accounting_expense_analysis',
        title: 'Análisis de gastos',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Gastos homologados',
        followUpPrompt:
            'Qué categoría creció y cuál necesita control o explicación.',
      ),
      ManagementReportDefinition(
        key: 'accounting_income_statement',
        title: 'Estado de resultados',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.ready,
        sourceLabel: 'Estado de resultados',
        followUpPrompt: 'Si el negocio ganó o perdió en el corte y por qué.',
      ),
      ManagementReportDefinition(
        key: 'accounting_balance',
        title: 'Balance',
        frequency: ManagementReportFrequency.weeklyFriday,
        dataStatus: ManagementReportDataStatus.partial,
        sourceLabel: 'Balance contable',
        followUpPrompt:
            'Cómo quedan pasivos vs activos y qué tensión patrimonial destaca.',
      ),
    ],
  ),
];

ManagementAreaDefinition managementAreaDefinition(ManagementAreaKey key) {
  return managementAreaCatalog.firstWhere((row) => row.key == key);
}

String managementAreaKeyLabel(ManagementAreaKey key) {
  return managementAreaDefinition(key).title;
}

String managementAreaKeySlug(ManagementAreaKey key) {
  return switch (key) {
    ManagementAreaKey.operaciones => 'operaciones',
    ManagementAreaKey.bascula => 'bascula',
    ManagementAreaKey.logistica => 'logistica',
    ManagementAreaKey.menudeo => 'menudeo',
    ManagementAreaKey.rh => 'rh',
    ManagementAreaKey.ventas => 'ventas',
    ManagementAreaKey.gastos => 'gastos',
    ManagementAreaKey.gestion => 'gestion',
    ManagementAreaKey.finanzas => 'finanzas',
    ManagementAreaKey.gerencia => 'gerencia',
    ManagementAreaKey.desarrolloComercial => 'desarrollo_comercial',
    ManagementAreaKey.direccionGeneral => 'direccion_general',
    ManagementAreaKey.contabilidad => 'contabilidad',
  };
}

ManagementAreaKey managementAreaKeyFromSlug(String slug) {
  return managementAreaCatalog
      .firstWhere((row) => managementAreaKeySlug(row.key) == slug)
      .key;
}

String managementFrequencyLabel(ManagementReportFrequency frequency) {
  return switch (frequency) {
    ManagementReportFrequency.daily => 'Diario',
    ManagementReportFrequency.weeklyFriday => 'Viernes',
  };
}

String managementFrequencySlug(ManagementReportFrequency frequency) {
  return switch (frequency) {
    ManagementReportFrequency.daily => 'daily',
    ManagementReportFrequency.weeklyFriday => 'weekly_friday',
  };
}

ManagementReportFrequency managementFrequencyFromSlug(String slug) {
  return switch (slug) {
    'daily' => ManagementReportFrequency.daily,
    'weekly_friday' => ManagementReportFrequency.weeklyFriday,
    _ => ManagementReportFrequency.weeklyFriday,
  };
}

String managementStatusLabel(ManagementReportDataStatus status) {
  return switch (status) {
    ManagementReportDataStatus.ready => 'Lista',
    ManagementReportDataStatus.partial => 'Parcial',
    ManagementReportDataStatus.pending => 'Pendiente',
  };
}

Color managementStatusColor(ManagementReportDataStatus status) {
  return switch (status) {
    ManagementReportDataStatus.ready => const Color(0xFF2E9E5B),
    ManagementReportDataStatus.partial => const Color(0xFFD78A1D),
    ManagementReportDataStatus.pending => const Color(0xFFB63E3E),
  };
}
