import 'profitability_models.dart';

// Only user-controlled text is neutralized; negative numeric cells stay numeric.
String profitCsvText(String value) {
  final safe = RegExp(r'^[\s]*[=+@\-]').hasMatch(value) ? "'$value" : value;
  return '"${safe.replaceAll('"', '""')}"';
}

String profitCsv(ProfitAnalysis analysis) {
  String number(double? v) => v?.toStringAsFixed(2) ?? '';
  final rows = <List<String>>[
    [
      'Empresa',
      'Origen',
      'Inicio',
      'Fin',
      'Kg físicos',
      'Kg pagables',
      'Compra MXN',
      'Valor estimado MXN',
      'Nómina asignada',
      'Combustible asignado',
      'Transporte asignado',
      'Proceso asignado',
      'Mantenimiento asignado',
      'Otros asignados',
      'Estructura asignada',
      'Contribución revisada',
      'Resultado revisado',
      'Estado',
      'Pendientes',
      'Base',
    ],
    for (final c in analysis.reportCompanies)
      [
        profitCsvText(c.displayName),
        profitCsvText(c.entity.source),
        profitDateText(analysis.sources.period.start),
        profitDateText(analysis.sources.period.end),
        number(c.kg),
        number(c.payableKg),
        number(c.purchases),
        number(c.value),
        for (final kind in [
          ProfitCostKind.payroll,
          ProfitCostKind.fuel,
          ProfitCostKind.transport,
          ProfitCostKind.process,
          ProfitCostKind.maintenance,
          ProfitCostKind.other,
          ProfitCostKind.overhead,
        ])
          number(c.costs[kind]),
        number(c.contribution),
        number(c.result),
        profitCsvText(c.decision),
        profitCsvText(c.issues.join(' | ')),
        profitCsvText(
          'Estimación por material originado; no utilidad realizada. Costos vacíos: no asignados.',
        ),
      ],
  ];
  return '\uFEFF${rows.map((r) => r.join(',')).join('\r\n')}\r\n';
}

String profitExecutiveCsv(ProfitAnalysis a) {
  String n(double? v) => v?.toStringAsFixed(2) ?? '';
  final rows = <List<String>>[
    [
      'Empresa / planta',
      'Grupo',
      'Inicio',
      'Fin',
      'Kg',
      'Compra conocida',
      'Valor recuperable conocido',
      'Ingresos conocidos',
      'Costos conocidos',
      'Aporte operativo parcial',
      'Aporte/kg',
      'Margen',
      'Después de estructura parcial',
      'Cobertura bloques',
      'Fracción comprobada/asignada de importe conocido',
      'Índice confianza',
      'Faltantes',
      'Base',
    ],
    for (final c in a.reportCompanies)
      [
        profitCsvText(c.displayName),
        profitCsvText(c.operating?.group ?? ''),
        profitDateText(a.sources.period.start),
        profitDateText(a.sources.period.end),
        n(c.kg),
        n(c.operating?.total('purchase')),
        n(c.operating?.total('value')),
        n(c.operating?.total('income')),
        n(c.operating?.costs),
        n(c.operating?.contribution),
        n(
          c.kg > 0 && c.operating?.contribution != null
              ? c.operating!.contribution! / c.kg
              : null,
        ),
        n(c.operating?.margin),
        n(c.operating?.afterOverhead),
        n(c.operating?.blockCoverage),
        n(c.operating?.verifiedShare),
        n(c.operating?.confidence),
        profitCsvText(
          c.operating?.components
                  .where((v) => v.amount == null)
                  .map((v) => v.block)
                  .toSet()
                  .join(' | ') ??
              '',
        ),
        profitCsvText(
          'Estimación gerencial; importes conocidos no incluyen faltantes; no utilidad realizada.',
        ),
      ],
  ];
  return '\uFEFF${rows.map((r) => r.join(',')).join('\r\n')}\r\n';
}

String profitAccountCsv(ProfitAnalysis a) {
  String n(double v) => v.toStringAsFixed(2);
  final rows = <List<String>>[
    [
      'Empresa',
      'Inicio',
      'Fin',
      'Línea',
      'Kg',
      'Servicios',
      'Valor material',
      'Ingreso servicios',
      'Costos de atención',
      'Aporte operativo',
      'Compensación adicional/kg',
      'Compensación adicional/servicio',
      'Base',
    ],
    for (final c in a.reportCompanies.where((c) => c.account != null))
      for (final l in c.account!.lines)
        [
          profitCsvText(c.displayName),
          profitDateText(a.sources.period.start),
          profitDateText(a.sources.period.end),
          profitCsvText(l.label),
          n(l.kg),
          n(l.services),
          n(l.materialValue),
          n(l.income),
          n(l.costs),
          n(l.contribution),
          n(l.additionalPerKg),
          n(l.additionalPerService),
          profitCsvText(
            l.components
                .map((v) => '${v.sourceType.name}: ${v.rule}')
                .join(' | '),
          ),
        ],
  ];
  return '\uFEFF${rows.map((r) => r.join(',')).join('\r\n')}\r\n';
}
