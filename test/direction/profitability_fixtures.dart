import 'package:dicsa_operacion/app/direction/profitability/profitability_models.dart';

const payrollLabel = 'SEM 38 (11/09/2026 - 17/09/2026)';
ProfitSources profitFixture({
  Map<String, List<ProfitRow>> overrides = const {},
}) => ProfitSources(
  period: ProfitPeriod.pilot(),
  readAt: DateTime(2026, 9, 21),
  tables: {
    'sites': [
      {'id': 's1', 'name': 'PLANTA A'},
      {'id': 's2', 'name': 'PLANTA B'},
    ],
    'compras_counterparties': [
      {'id': 'c1', 'name': 'PLANTA A'},
    ],
    'men_counterparties': [
      {'id': 'm1', 'name': 'PLANTA A', 'site_id': 's1'},
    ],
    'mayoreo_counterparties': [
      {'id': 'v1', 'name': 'CLIENTE FINAL'},
    ],
    'compras_material_catalog': [
      {'id': 'carton', 'name': 'CARTON', 'unit': 'KG'},
    ],
    'mayoreo_material_catalog': [
      {'id': 'paca', 'name': 'PACA', 'unit': 'KG'},
      {'id': 'servicio', 'name': 'FLETE', 'unit': 'SERVICIO'},
    ],
    'compras_tickets': [
      purchase('p1', 100, 80, 160),
      purchase('p2', 300, 270, 540),
    ],
    'mayoreo_sales_reports': [
      sale('v1', 100, 500),
      sale('v2', 300, 2100),
      {...sale('service', 1, 10000), 'material_id': 'servicio'},
    ],
    'men_tickets': [],
    'hr_payroll_period_closures': [
      {'id': 'close', 'period_label': payrollLabel, 'status': 'cerrado'},
    ],
    'hr_prenomina_draft_rows': [
      {
        'id': 'rh1',
        'period_label': payrollLabel,
        'employee_id': 'e1',
        'empresa': 'PLANTA A',
        'draft_status': 'publicado',
        'fiscal_net_amount': 100,
        'check_amount': 50,
        'cash_salary_amount': 40,
        'loan_deduction_amount': 10,
      },
    ],
    'finanzas_bank_movements': [
      {
        'id': 'fuel',
        'movement_date': '2026-09-12',
        'debit_amount': 100,
        'category': 'DIESEL',
        'reference': 'F-1',
      },
    ],
    'services': [
      {
        'id': 'trip',
        'due_date': '2026-09-12',
        'area': 'LOGISTICA',
        'status': 'completado',
        'client_id': 's1',
        'vehicle_id': 'truck',
      },
    ],
    'logistics_vehicle_mileage': [
      {
        'id': 'km',
        'entry_date': '2026-09-12',
        'vehicle_id': 'truck',
        'kilometers': 80,
      },
    ],
    'logistics_diesel_consumption': [
      {
        'id': 'diesel',
        'entry_date': '2026-09-12',
        'vehicle_id': 'truck',
        'liters_requested': 400,
      },
    ],
    ...overrides,
  },
);
ProfitRow purchase(String id, double kg, double payable, double amount) => {
  'id': id,
  'ticket_date': '2026-09-12',
  'ticket_number': id,
  'provider_id': 'c1',
  'provider_name_snapshot': 'PLANTA A',
  'material_id': 'carton',
  'material_name_snapshot': 'CARTON',
  'net_weight': kg,
  'payable_weight': payable,
  'amount': amount,
};
ProfitRow sale(String id, double kg, double amount) => {
  'id': id,
  'sale_date': '2026-09-13',
  'material_id': 'paca',
  'material_name_snapshot': 'PACA',
  'approved_weight': kg,
  'approved_amount': amount,
  'approved_price': kg > 0 ? amount / kg : 0,
};
ProfitCompanyReview completeReview(String signature) => ProfitCompanyReview(
  identity: true,
  labor: true,
  fuel: true,
  process: true,
  expenses: true,
  taxBasis: true,
  note: 'Documentación conciliada',
  evidenceSignature: signature,
);
