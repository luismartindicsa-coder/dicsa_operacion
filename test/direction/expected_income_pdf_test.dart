import 'dart:convert';
import 'dart:io';

import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_pdf.dart';
import 'package:dicsa_operacion/app/mayoreo/mayoreo_expected_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';

import 'expected_income_test.dart' as f;

ExpectedIncomePrintData reportFixture({
  int extraRows = 0,
}) => ExpectedIncomePrintData(
  bundle: f.incomeBundle(
    stock: const {
      'PACA_NACIONAL': 10000,
      'PACA_LIMPIA': 10000,
      'PACA_AMERICANA': 10000,
    },
    shipments: [
      f.incomeShipment(),
      f.incomeShipment(
        id: 'americano',
        client: 'PAPELERA DEL NEVADO',
        material: 'PACA_AMERICANA',
        bales: 35,
      ),
      f.incomeShipment(id: 'sanluis', day: 1, client: 'SAN LUIS', bales: 40),
      f.incomeShipment(
        id: 'palomar',
        day: 3,
        client: 'EL PALOMAR',
        material: 'PACA_LIMPIA',
        bales: 60,
      ),
      f.incomeShipment(id: 'real', day: 4, bales: 20, status: 'embarcado'),
      f.incomeShipment(
        id: 'unknown',
        day: 2,
        client: 'CLIENTE SIN CONDICIONES',
        material: 'PACA_LIMPIA',
        bales: 12,
      ),
      f.incomeShipment(
        id: 'cancel',
        day: 4,
        client: 'NEVADO',
        material: 'PACA_AMERICANA',
        bales: 10,
        status: 'cancelado',
      ),
      f.incomeShipment(id: 'tentative', day: 4, bales: 15, status: 'planeado'),
      for (var i = 0; i < extraRows; i++)
        f.incomeShipment(
          id: 'extra-$i',
          day: i % 5,
          client:
              'DESTINO EXTENSO $i - PAPELERA INDUSTRIAL DEL NORTE Y SUS DISTRIBUIDORES REGIONALES',
          bales: 1,
        ),
    ],
  ),
  data: ExpectedIncomeData(
    materials: f.incomeMaterials,
    clients: f.incomeClients,
    productionSource: 'Programa operativo v3 - Aprobado',
    links: const {'real': 'sale-real'},
    sales: [
      IncomeSale(
        id: 'sale-real',
        client: 'RICARDO MENDIETA',
        material: 'PACA_NACIONAL',
        ticket: 'REM-420',
        date: f.incomeWeek.add(const Duration(days: 4)),
        weight: 13000.25,
        price: 2.5,
        approvedCents: 3500000,
        paidCents: 1000000,
        paymentType: 'EFECTIVO',
        dueDate: f.incomeWeek.add(const Duration(days: 4)),
      ),
    ],
    collections: [
      MayoreoExpectedCollection(
        accountId: 'prior',
        client: 'BIO PAPEL',
        material: 'PACA_NACIONAL',
        document: 'FACT-190',
        saleDate: f.incomeWeek.subtract(const Duration(days: 7)),
        dueDate: f.incomeWeek.add(const Duration(days: 2)),
        pendingCents: 900000,
      ),
      MayoreoExpectedCollection(
        accountId: 'next',
        client: 'ECOFIBRAS',
        material: 'PACA_NACIONAL',
        document: 'FACT-191',
        saleDate: f.incomeWeek.subtract(const Duration(days: 3)),
        dueDate: f.incomeWeek.add(const Duration(days: 7)),
        pendingCents: 1500000,
      ),
    ],
    palomarConfig: const PalomarIncomeConfig(
      creditLimit: 400000,
      drawAmount: 400000,
      cashCheck1: 99000,
      cashCheck2: 99000,
    ),
    palomarMovements: [
      PalomarIncomeMovement(
        id: 'opening',
        date: f.incomeWeek.subtract(const Duration(days: 1)),
        signedCents: 11340000,
        concept: 'Saldo por cubrir',
      ),
    ],
  ),
  generatedAt: DateTime(2026, 9, 21, 9, 30),
);

class OldIncomeAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key.startsWith('assets/fonts/')) {
      throw FlutterError('Asset not bundled');
    }
    return rootBundle.load(key);
  }
}

int pages(List<int> bytes) =>
    RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'report reconciles shipment collections, prior sales and Palomar without duplicating cash',
    () {
      final data = reportFixture();
      expect(data.projection.generated, 43393000);
      expect(data.projection.collected, 1000000);
      expect(data.shipmentCollections, [21785000, 7000000, 0, 0, 2268000]);
      expect(data.additionalCollections, [900000, 1500000, 0, 0, 0]);
      expect(data.projection.current.financingTotal, 40000000);
      expect(data.projection.current.total, 62685000);
      expect(data.projection.current.byType['EFECTIVO'], 32275000);
      expect(data.projection.current.byType['FISCAL'], 30410000);
      expect(data.projection.next.total, 8500000);
      expect(data.tentative, 1);
      expect(data.activeRows.length, 7);
      expect(data.cancelled, 1);
      expect(data.bales, 224);
      expect(data.materials.map((m) => m.bales), [117, 72, 35]);
      expect(data.materials.map((m) => m.valueCents), [
        20475000,
        13608000,
        9310000,
      ]);
      expect(data.fileName, 'ingreso_proyectado_embarques_2026-09-21.pdf');
    },
  );

  test(
    'exports the executive summary on exactly one A4 landscape page',
    () async {
      final bytes = await buildExpectedIncomePdf(reportFixture());
      expect(pages(bytes), 1);
      expect(
        latin1.decode(bytes),
        matches(RegExp(r'/MediaBox\s*\[\s*0\s+0\s+841\.\d+\s+595\.\d+\s*\]')),
      );
      if (Platform.environment['DICSA_INCOME_PDF_QA'] == '1') {
        await File('/private/tmp/dicsa-income-week.pdf').writeAsBytes(bytes);
      }
    },
  );

  test(
    'large weeks aggregate every shipment onto the same single page',
    () async {
      final data = reportFixture(extraRows: 100);
      expect(data.activeRows.length, 107);
      expect(data.bales, 324);
      expect(data.materials.map((m) => m.bales), [217, 72, 35]);
      expect(data.projection.generated, 60893000);
      final bytes = await buildExpectedIncomePdf(data);
      expect(pages(bytes), 1);
      if (Platform.environment['DICSA_INCOME_PDF_QA'] == '1') {
        await File('/private/tmp/dicsa-income-long.pdf').writeAsBytes(bytes);
      }
    },
  );

  test(
    'missing values remain explicit and older asset bundles can still export',
    () async {
      final data = ExpectedIncomePrintData(
        bundle: f.incomeBundle(),
        data: const ExpectedIncomeData(),
        generatedAt: f.incomeWeek,
      );
      expect(data.unvalued, 1);
      expect(data.projection.generated, 0);
      expect(data.materials.first.unvalued, 1);
      expect(data.missingProduction, 1);
      final bytes = await buildExpectedIncomePdf(
        data,
        assetBundle: OldIncomeAssets(),
      );
      expect(pages(bytes), 1);
      if (Platform.environment['DICSA_INCOME_PDF_QA'] == '1') {
        await File(
          '/private/tmp/dicsa-income-incomplete.pdf',
        ).writeAsBytes(bytes);
      }
    },
  );

  test(
    'empty week generates a valid report without invented shipments',
    () async {
      final data = ExpectedIncomePrintData(
        bundle: f.incomeBundle(shipments: []),
        data: const ExpectedIncomeData(),
        generatedAt: f.incomeWeek,
      );
      expect(data.activeRows, isEmpty);
      expect(data.bales, 0);
      expect(data.projection.current.total, 0);
      final bytes = await buildExpectedIncomePdf(data);
      expect(pages(bytes), 1);
      if (Platform.environment['DICSA_INCOME_PDF_QA'] == '1') {
        await File('/private/tmp/dicsa-income-empty.pdf').writeAsBytes(bytes);
      }
    },
  );
}
