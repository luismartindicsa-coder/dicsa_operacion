import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/compras/compras_data_store.dart';
import 'package:dicsa_operacion/app/compras/compras_tickets_store.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_provider_excel_templates.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds avon workbook bytes', () async {
    final bytes = await FinanzasProviderExcelTemplates.buildWorkbook(
      kind: FinanzasProviderExcelTemplateKind.avon,
      tickets: <ComprasTicketRecord>[
        ComprasTicketRecord(
          id: 't1',
          date: DateTime(2026, 5, 22),
          ticket: 'VIG-001',
          providerId: 'compras_avon',
          providerNameSnapshot: 'AVON',
          materialId: 'm1',
          materialNameSnapshot: 'Chatarra',
          grossWeight: 1000,
          tareWeight: 200,
          netWeight: 800,
          humidityPercent: 5,
          trashPercent: 5,
          trashKg: 40,
          trashCaptureMode: 'PERCENT',
          payableWeight: 720,
          price: 2.8,
          premium: 0,
          amount: 2016,
          facturaStatus: 'SIN_FACTURA',
          pagoStatus: 'PENDIENTE_DE_PAGO',
          coverageStatus: 'SIN_CUBRIR',
          createdAt: null,
          updatedAt: null,
        ),
      ],
      providerName: 'AVON',
    );
    final file = File('/tmp/avon_excel_smoke.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    expect(bytes.isNotEmpty, isTrue);
    expect(file.existsSync(), isTrue);
  });

  test('builds generic materials workbook bytes', () async {
    final bytes = await FinanzasProviderExcelTemplates.buildWorkbook(
      kind: FinanzasProviderExcelTemplateKind.genericMaterials,
      providerName: 'MONROE',
      tickets: <ComprasTicketRecord>[
        ComprasTicketRecord(
          id: 't1',
          date: DateTime(2026, 5, 22),
          ticket: 'M-001',
          providerId: 'compras_monroe',
          providerNameSnapshot: 'MONROE',
          materialId: 'm_carton',
          materialNameSnapshot: 'SCRAP CARTON',
          grossWeight: 1000,
          tareWeight: 200,
          netWeight: 800,
          humidityPercent: 0,
          trashPercent: 0,
          trashKg: 0,
          trashCaptureMode: 'PERCENT',
          payableWeight: 800,
          price: 0,
          premium: 0,
          amount: 0,
          facturaStatus: 'SIN_FACTURA',
          pagoStatus: 'PENDIENTE_DE_PAGO',
          coverageStatus: 'SIN_CUBRIR',
          createdAt: null,
          updatedAt: null,
        ),
        ComprasTicketRecord(
          id: 't2',
          date: DateTime(2026, 5, 23),
          ticket: 'M-002',
          providerId: 'compras_monroe',
          providerNameSnapshot: 'MONROE',
          materialId: 'm_acero',
          materialNameSnapshot: 'REBABA DE ACERO',
          grossWeight: 900,
          tareWeight: 100,
          netWeight: 800,
          humidityPercent: 0,
          trashPercent: 0,
          trashKg: 0,
          trashCaptureMode: 'PERCENT',
          payableWeight: 800,
          price: 0,
          premium: 0,
          amount: 0,
          facturaStatus: 'SIN_FACTURA',
          pagoStatus: 'PENDIENTE_DE_PAGO',
          coverageStatus: 'SIN_CUBRIR',
          createdAt: null,
          updatedAt: null,
        ),
      ],
      comprasCatalogSnapshot: ComprasCatalogSnapshot(
        companies: const <ComprasCatalogProviderRecord>[
          ComprasCatalogProviderRecord(
            id: 'prov_monroe',
            code: 'MONROE',
            name: 'MONROE',
            contact: '',
            active: true,
            notes: '',
          ),
        ],
        materials: const <ComprasCatalogMaterialRecord>[],
        prices: const <ComprasCatalogPriceRecord>[
          ComprasCatalogPriceRecord(
            id: 'p1',
            companyId: 'prov_monroe',
            materialId: 'm_carton',
            amount: 1.4,
            active: true,
            notes: '',
            updatedAt: null,
          ),
          ComprasCatalogPriceRecord(
            id: 'p2',
            companyId: 'prov_monroe',
            materialId: 'm_acero',
            amount: 2.27,
            active: true,
            notes: '',
            updatedAt: null,
          ),
        ],
      ),
    );
    final file = File('/tmp/generic_provider_excel_smoke.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    expect(bytes.isNotEmpty, isTrue);
    expect(file.existsSync(), isTrue);
  });
}
