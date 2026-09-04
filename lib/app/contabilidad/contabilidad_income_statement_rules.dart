import '../direction/direction_cash_taxonomy_store.dart';
import '../finanzas/finanzas_bank_accounts_store.dart';

String _normalizeAccountingToken(String value) {
  return value
      .trim()
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U');
}

enum ContabilidadIncomeStatementBucket {
  revenue,
  commercialCost,
  operatingExpense,
  administrativeExpense,
  financialExpense,
  payrollExpense,
  internalTransfer,
  reviewRequired,
}

enum ContabilidadAccountingFamily {
  revenue,
  commercialCost,
  operatingExpense,
  administrativeExpense,
  financialExpense,
  payrollExpense,
  internalTransfer,
  reviewRequired,
}

enum ContabilidadExpenseSubaccount {
  operatingPayroll,
  taxes,
  imss,
  fuel,
  maintenance,
  transport,
  utilities,
  rent,
  insurance,
  operatingMisc,
  professionalFees,
  administrativePayroll,
  software,
  administrativeMisc,
  interestPaid,
  biancaInterest,
}

String contabilidadExpenseSubaccountLabel(ContabilidadExpenseSubaccount value) {
  return switch (value) {
    ContabilidadExpenseSubaccount.operatingPayroll => 'Nominas',
    ContabilidadExpenseSubaccount.taxes => 'Impuestos',
    ContabilidadExpenseSubaccount.imss => 'IMSS',
    ContabilidadExpenseSubaccount.fuel => 'Combustibles y gasolinas',
    ContabilidadExpenseSubaccount.maintenance => 'Reparaciones y mantenimiento',
    ContabilidadExpenseSubaccount.transport => 'Gastos de transporte',
    ContabilidadExpenseSubaccount.utilities => 'Agua, luz, telefono',
    ContabilidadExpenseSubaccount.rent => 'Renta',
    ContabilidadExpenseSubaccount.insurance => 'Seguros',
    ContabilidadExpenseSubaccount.operatingMisc => 'Varios',
    ContabilidadExpenseSubaccount.professionalFees => 'Honorarios',
    ContabilidadExpenseSubaccount.administrativePayroll =>
      'Sueldos administrativos',
    ContabilidadExpenseSubaccount.software => 'Software',
    ContabilidadExpenseSubaccount.administrativeMisc => 'Varios',
    ContabilidadExpenseSubaccount.interestPaid => 'Intereses pagados',
    ContabilidadExpenseSubaccount.biancaInterest => '4% Bianca',
  };
}

ContabilidadExpenseSubaccount? classifyExpenseSubaccount({
  required ContabilidadIncomeStatementBucket bucket,
  required String context,
}) {
  if (bucket != ContabilidadIncomeStatementBucket.operatingExpense &&
      bucket != ContabilidadIncomeStatementBucket.administrativeExpense &&
      bucket != ContabilidadIncomeStatementBucket.financialExpense &&
      bucket != ContabilidadIncomeStatementBucket.payrollExpense) {
    return null;
  }
  final value = _normalizeAccountingToken(context);
  if (value.contains('BIANCA')) {
    return ContabilidadExpenseSubaccount.biancaInterest;
  }
  if (value.contains('IMSS')) return ContabilidadExpenseSubaccount.imss;
  if (value.contains('IMPUEST') || value.contains('SAT')) {
    return ContabilidadExpenseSubaccount.taxes;
  }
  if (value.contains('DIESEL') ||
      value.contains('GASOLINA') ||
      value.contains('ACEITE') ||
      value.contains('COMBUSTIBLE')) {
    return ContabilidadExpenseSubaccount.fuel;
  }
  if (value.contains('REFACCION') ||
      value.contains('MECANIC') ||
      value.contains('TALACHA') ||
      value.contains('MANTENIMIENTO') ||
      value.contains('REPARACION')) {
    return ContabilidadExpenseSubaccount.maintenance;
  }
  if (value.contains('CASETA') ||
      value.contains('VIATIC') ||
      value.contains('PERMISO') ||
      value.contains('VERIFICACION')) {
    return ContabilidadExpenseSubaccount.transport;
  }
  if (value.contains('AGUA') ||
      value.contains('LUZ') ||
      value.contains('CFE') ||
      value.contains('TELEFON') ||
      value.contains('INTERNET')) {
    return ContabilidadExpenseSubaccount.utilities;
  }
  if (value.contains('RENTA') || value.contains('ARREND')) {
    return ContabilidadExpenseSubaccount.rent;
  }
  if (value.contains('SEGURO') || value.contains('POLIZA')) {
    return ContabilidadExpenseSubaccount.insurance;
  }
  if (value.contains('ABOGAD') ||
      value.contains('CONTADOR') ||
      value.contains('ARQUITECT') ||
      value.contains('HONORARIO')) {
    return ContabilidadExpenseSubaccount.professionalFees;
  }
  if (value.contains('LICENCIA') ||
      value.contains('SOFTWARE') ||
      value.contains('GPS') ||
      value.contains('SUSCRIP')) {
    return ContabilidadExpenseSubaccount.software;
  }
  if (bucket == ContabilidadIncomeStatementBucket.financialExpense) {
    return ContabilidadExpenseSubaccount.interestPaid;
  }
  if (bucket == ContabilidadIncomeStatementBucket.payrollExpense) {
    return value.contains('ADMIN') || value.contains('OFICINA')
        ? ContabilidadExpenseSubaccount.administrativePayroll
        : ContabilidadExpenseSubaccount.operatingPayroll;
  }
  return bucket == ContabilidadIncomeStatementBucket.administrativeExpense
      ? ContabilidadExpenseSubaccount.administrativeMisc
      : ContabilidadExpenseSubaccount.operatingMisc;
}

class ContabilidadAccountingFamilyDefinition {
  final ContabilidadAccountingFamily family;
  final String title;
  final String statementLabel;
  final List<String> bankCategories;
  final List<String> cashRubrics;
  final String rationale;

  const ContabilidadAccountingFamilyDefinition({
    required this.family,
    required this.title,
    required this.statementLabel,
    required this.bankCategories,
    required this.cashRubrics,
    required this.rationale,
  });
}

class ContabilidadIncomeStatementRuleRow {
  final String sourceLabel;
  final String movementLabel;
  final ContabilidadIncomeStatementBucket bucket;
  final String statementLabel;
  final bool includedInStatement;
  final String rationale;

  const ContabilidadIncomeStatementRuleRow({
    required this.sourceLabel,
    required this.movementLabel,
    required this.bucket,
    required this.statementLabel,
    required this.includedInStatement,
    required this.rationale,
  });
}

String contabilidadIncomeStatementBucketLabel(
  ContabilidadIncomeStatementBucket bucket,
) {
  switch (bucket) {
    case ContabilidadIncomeStatementBucket.revenue:
      return 'Ingreso';
    case ContabilidadIncomeStatementBucket.commercialCost:
      return 'Costo comercial';
    case ContabilidadIncomeStatementBucket.operatingExpense:
      return 'Gasto operativo';
    case ContabilidadIncomeStatementBucket.administrativeExpense:
      return 'Gasto administrativo';
    case ContabilidadIncomeStatementBucket.financialExpense:
      return 'Gasto financiero';
    case ContabilidadIncomeStatementBucket.payrollExpense:
      return 'Nomina';
    case ContabilidadIncomeStatementBucket.internalTransfer:
      return 'Movimiento interno';
    case ContabilidadIncomeStatementBucket.reviewRequired:
      return 'Revision';
  }
}

const List<ContabilidadAccountingFamilyDefinition>
contabilidadAccountingFamilies = <ContabilidadAccountingFamilyDefinition>[
  ContabilidadAccountingFamilyDefinition(
    family: ContabilidadAccountingFamily.revenue,
    title: 'Ingresos',
    statementLabel: 'Ingresos',
    bankCategories: <String>['VENTAS'],
    cashRubrics: <String>['Venta de material'],
    rationale:
        'Representa dinero ganado por la operacion comercial, ya sea en bancos o en efectivo.',
  ),
  ContabilidadAccountingFamilyDefinition(
    family: ContabilidadAccountingFamily.commercialCost,
    title: 'Costo comercial',
    statementLabel: 'Costo comercial',
    bankCategories: <String>['COMPRA DE MATERIAL'],
    cashRubrics: <String>['Compra de material'],
    rationale:
        'Representa el costo de adquirir el material que despues se comercializa.',
  ),
  ContabilidadAccountingFamilyDefinition(
    family: ContabilidadAccountingFamily.operatingExpense,
    title: 'Gasto operativo',
    statementLabel: 'Gasto operativo',
    bankCategories: <String>['GASTOS OPERATIVOS'],
    cashRubrics: <String>['Gastos operativos'],
    rationale:
        'Representa gasto necesario para operar el negocio en el dia a dia.',
  ),
  ContabilidadAccountingFamilyDefinition(
    family: ContabilidadAccountingFamily.administrativeExpense,
    title: 'Gasto administrativo',
    statementLabel: 'Gasto administrativo',
    bankCategories: <String>['SERVICIOS', 'GASTOS ADMINISTRATIVOS'],
    cashRubrics: <String>['Gastos administrativos'],
    rationale:
        'Representa gasto administrativo; en bancos Servicios entra aqui de forma provisional.',
  ),
  ContabilidadAccountingFamilyDefinition(
    family: ContabilidadAccountingFamily.financialExpense,
    title: 'Gasto financiero',
    statementLabel: 'Gasto financiero',
    bankCategories: <String>['GASTOS FINANCIEROS'],
    cashRubrics: <String>['Gastos financieros'],
    rationale:
        'Representa costo financiero real, aunque todavia debe vigilarse que no mezcle pago de pasivos.',
  ),
  ContabilidadAccountingFamilyDefinition(
    family: ContabilidadAccountingFamily.payrollExpense,
    title: 'Nomina',
    statementLabel: 'Nomina',
    bankCategories: <String>['NOMINA'],
    cashRubrics: <String>['Nómina'],
    rationale: 'Representa nomina pagada por cualquier via.',
  ),
  ContabilidadAccountingFamilyDefinition(
    family: ContabilidadAccountingFamily.internalTransfer,
    title: 'Internos',
    statementLabel: 'Movimiento interno',
    bankCategories: <String>['MOVIMIENTOS INTERNOS'],
    cashRubrics: <String>['Reposición de fondo', 'Movimientos internos'],
    rationale:
        'Representa traspasos dentro de la empresa; no deben tocar utilidad.',
  ),
  ContabilidadAccountingFamilyDefinition(
    family: ContabilidadAccountingFamily.reviewRequired,
    title: 'Revision requerida',
    statementLabel: 'Revision',
    bankCategories: <String>['GASTOS PERSONALES', 'AJUSTES', 'OTROS'],
    cashRubrics: <String>['Cheque', 'Otro', 'Gastos personales'],
    rationale:
        'Representa movimientos que todavia no deben entrar automatico al resultado.',
  ),
];

ContabilidadAccountingFamilyDefinition? contabilidadFamilyByBankCategory(
  String category,
) {
  final normalized = _normalizeAccountingToken(category);
  for (final family in contabilidadAccountingFamilies) {
    if (family.bankCategories.any(
      (item) => _normalizeAccountingToken(item) == normalized,
    )) {
      return family;
    }
  }
  return null;
}

ContabilidadAccountingFamilyDefinition? contabilidadFamilyByCashRubric(
  String rubric,
) {
  final normalized = _normalizeAccountingToken(rubric);
  for (final family in contabilidadAccountingFamilies) {
    if (family.cashRubrics.any(
      (item) => _normalizeAccountingToken(item) == normalized,
    )) {
      return family;
    }
  }
  return null;
}

ContabilidadIncomeStatementRuleRow classifyBankCategoryForIncomeStatement(
  String category,
) {
  final normalized = _normalizeAccountingToken(category);
  switch (normalized) {
    case 'VENTAS':
      return const ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Bancos',
        movementLabel: 'VENTAS',
        bucket: ContabilidadIncomeStatementBucket.revenue,
        statementLabel: 'Ingresos',
        includedInStatement: true,
        rationale: 'Se reconoce como ingreso real del negocio.',
      );
    case 'COMPRA DE MATERIAL':
      return const ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Bancos',
        movementLabel: 'COMPRA DE MATERIAL',
        bucket: ContabilidadIncomeStatementBucket.commercialCost,
        statementLabel: 'Costo comercial',
        includedInStatement: true,
        rationale: 'Se usa como costo comercial del periodo.',
      );
    case 'GASTOS OPERATIVOS':
      return const ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Bancos',
        movementLabel: 'GASTOS OPERATIVOS',
        bucket: ContabilidadIncomeStatementBucket.operatingExpense,
        statementLabel: 'Gasto operativo',
        includedInStatement: true,
        rationale: 'Es gasto de operacion que si pega al resultado.',
      );
    case 'SERVICIOS':
      return const ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Bancos',
        movementLabel: 'SERVICIOS',
        bucket: ContabilidadIncomeStatementBucket.administrativeExpense,
        statementLabel: 'Gasto administrativo',
        includedInStatement: true,
        rationale:
            'Entra provisionalmente como gasto administrativo hasta tener analisis de gastos mas fino.',
      );
    case 'GASTOS ADMINISTRATIVOS':
      return const ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Bancos',
        movementLabel: 'GASTOS ADMINISTRATIVOS',
        bucket: ContabilidadIncomeStatementBucket.administrativeExpense,
        statementLabel: 'Gasto administrativo',
        includedInStatement: true,
        rationale: 'Es gasto administrativo reconocido en el resultado.',
      );
    case 'GASTOS FINANCIEROS':
      return const ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Bancos',
        movementLabel: 'GASTOS FINANCIEROS',
        bucket: ContabilidadIncomeStatementBucket.financialExpense,
        statementLabel: 'Gasto financiero',
        includedInStatement: true,
        rationale:
            'Entra al resultado, pero debe vigilarse porque puede mezclar intereses con pagos de pasivo.',
      );
    case 'NOMINA':
      return const ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Bancos',
        movementLabel: 'NOMINA',
        bucket: ContabilidadIncomeStatementBucket.payrollExpense,
        statementLabel: 'Nomina',
        includedInStatement: true,
        rationale: 'Se reconoce como nomina del periodo.',
      );
    case 'MOVIMIENTOS INTERNOS':
      return const ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Bancos',
        movementLabel: 'MOVIMIENTOS INTERNOS',
        bucket: ContabilidadIncomeStatementBucket.internalTransfer,
        statementLabel: 'Movimiento interno',
        includedInStatement: false,
        rationale:
            'No entra al resultado porque solo mueve dinero dentro de la empresa.',
      );
    case 'GASTOS PERSONALES':
      return const ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Bancos',
        movementLabel: 'GASTOS PERSONALES',
        bucket: ContabilidadIncomeStatementBucket.reviewRequired,
        statementLabel: 'Revision',
        includedInStatement: false,
        rationale:
            'Requiere criterio contable; puede no ser gasto operativo real del negocio.',
      );
    case 'AJUSTES':
      return const ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Bancos',
        movementLabel: 'AJUSTES',
        bucket: ContabilidadIncomeStatementBucket.reviewRequired,
        statementLabel: 'Revision',
        includedInStatement: false,
        rationale:
            'No debe afectar utilidad sin revisar primero su origen real.',
      );
    case 'OTROS':
    default:
      return ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Bancos',
        movementLabel: normalized.isEmpty ? 'SIN CATEGORIA' : normalized,
        bucket: ContabilidadIncomeStatementBucket.reviewRequired,
        statementLabel: 'Revision',
        includedInStatement: false,
        rationale:
            'Queda fuera de momento hasta saber si es gasto, pasivo, ajuste o ingreso no operativo.',
      );
  }
}

ContabilidadIncomeStatementRuleRow classifyCashRubricForIncomeStatement({
  required DirectionCashMovementType movementType,
  required String rubricLabel,
}) {
  final normalized = _normalizeAccountingToken(rubricLabel);
  if (movementType == DirectionCashMovementType.entry) {
    switch (normalized) {
      case 'VENTA DE MATERIAL':
        return const ContabilidadIncomeStatementRuleRow(
          sourceLabel: 'Caja y Boveda',
          movementLabel: 'Venta de material',
          bucket: ContabilidadIncomeStatementBucket.revenue,
          statementLabel: 'Ingresos',
          includedInStatement: true,
          rationale: 'Se reconoce como ingreso comercial cobrado en efectivo.',
        );
      case 'REPOSICION DE FONDO':
        return const ContabilidadIncomeStatementRuleRow(
          sourceLabel: 'Caja y Boveda',
          movementLabel: 'Reposicion de fondo',
          bucket: ContabilidadIncomeStatementBucket.internalTransfer,
          statementLabel: 'Movimiento interno',
          includedInStatement: false,
          rationale:
              'Es traspaso entre Boveda y caja, no ingreso nuevo del negocio.',
        );
      case 'CHEQUE':
        return const ContabilidadIncomeStatementRuleRow(
          sourceLabel: 'Caja y Boveda',
          movementLabel: 'Cheque',
          bucket: ContabilidadIncomeStatementBucket.reviewRequired,
          statementLabel: 'Revision',
          includedInStatement: false,
          rationale:
              'Puede ser cobranza real o fondeo especifico; requiere analisis de origen antes de entrar al resultado.',
        );
      case 'OTRO':
      default:
        return ContabilidadIncomeStatementRuleRow(
          sourceLabel: 'Caja y Boveda',
          movementLabel: rubricLabel.trim().isEmpty ? 'Sin rubro' : rubricLabel,
          bucket: ContabilidadIncomeStatementBucket.reviewRequired,
          statementLabel: 'Revision',
          includedInStatement: false,
          rationale:
              'No entra automatico hasta confirmar si es ingreso real, ajuste o fondeo.',
        );
    }
  }

  switch (normalized) {
    case 'COMPRA DE MATERIAL':
      return const ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Caja y Boveda',
        movementLabel: 'Compra de material',
        bucket: ContabilidadIncomeStatementBucket.commercialCost,
        statementLabel: 'Costo comercial',
        includedInStatement: true,
        rationale: 'Se usa como costo comercial pagado en efectivo.',
      );
    case 'GASTOS OPERATIVOS':
    case 'OPERATIVO':
    case 'OPERATIVOS':
      return const ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Caja y Boveda',
        movementLabel: 'Gastos operativos',
        bucket: ContabilidadIncomeStatementBucket.operatingExpense,
        statementLabel: 'Gasto operativo',
        includedInStatement: true,
        rationale: 'Es gasto operativo que si pega al resultado.',
      );
    case 'GASTOS ADMINISTRATIVOS':
    case 'ADMINISTRATIVO':
    case 'ADMINISTRATIVOS':
      return const ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Caja y Boveda',
        movementLabel: 'Gastos administrativos',
        bucket: ContabilidadIncomeStatementBucket.administrativeExpense,
        statementLabel: 'Gasto administrativo',
        includedInStatement: true,
        rationale: 'Se reconoce como gasto administrativo del periodo.',
      );
    case 'GASTOS FINANCIEROS':
    case 'FINANCIERO':
    case 'FINANCIEROS':
      return const ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Caja y Boveda',
        movementLabel: 'Gastos financieros',
        bucket: ContabilidadIncomeStatementBucket.financialExpense,
        statementLabel: 'Gasto financiero',
        includedInStatement: true,
        rationale:
            'Entra al resultado, pero debe vigilarse si mezcla intereses con pago de deuda.',
      );
    case 'NOMINA':
      return const ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Caja y Boveda',
        movementLabel: 'Nomina',
        bucket: ContabilidadIncomeStatementBucket.payrollExpense,
        statementLabel: 'Nomina',
        includedInStatement: true,
        rationale: 'Se reconoce como nomina pagada en efectivo.',
      );
    case 'MOVIMIENTOS INTERNOS':
    case 'INTERNO':
    case 'INTERNOS':
      return const ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Caja y Boveda',
        movementLabel: 'Movimientos internos',
        bucket: ContabilidadIncomeStatementBucket.internalTransfer,
        statementLabel: 'Movimiento interno',
        includedInStatement: false,
        rationale:
            'No entra al resultado porque solo mueve dinero entre areas internas.',
      );
    case 'GASTOS PERSONALES':
    case 'PERSONAL':
    case 'PERSONALES':
      return const ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Caja y Boveda',
        movementLabel: 'Gastos personales',
        bucket: ContabilidadIncomeStatementBucket.reviewRequired,
        statementLabel: 'Revision',
        includedInStatement: false,
        rationale:
            'Requiere criterio contable antes de tratarse como gasto del negocio.',
      );
    default:
      return ContabilidadIncomeStatementRuleRow(
        sourceLabel: 'Caja y Boveda',
        movementLabel: rubricLabel.trim().isEmpty ? 'Sin rubro' : rubricLabel,
        bucket: ContabilidadIncomeStatementBucket.reviewRequired,
        statementLabel: 'Revision',
        includedInStatement: false,
        rationale:
            'Queda pendiente de clasificacion antes de entrar al resultado.',
      );
  }
}

List<ContabilidadIncomeStatementRuleRow> buildBankIncomeStatementRules() {
  return kFinBankCategories
      .map(classifyBankCategoryForIncomeStatement)
      .toList(growable: false);
}

List<ContabilidadIncomeStatementRuleRow> buildCashIncomeStatementRules(
  List<DirectionCashRubricDefinition> rubrics,
) {
  return rubrics
      .map(
        (rubric) => classifyCashRubricForIncomeStatement(
          movementType: rubric.movementType,
          rubricLabel: rubric.label,
        ),
      )
      .toList(growable: false);
}
