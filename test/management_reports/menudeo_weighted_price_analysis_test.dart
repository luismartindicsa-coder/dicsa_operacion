import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:dicsa_operacion/app/management_reports/menudeo_weighted_price_analysis.dart';
import 'package:dicsa_operacion/app/management_reports/management_reports_operations_daily_pdf.dart';

Map<String, dynamic> ticket(
  String direction,
  double kg,
  double amount, {
  String material = 'FIERRO',
  String materialId = 'fierro',
  String supplier = 'p1',
}) => {
  'direction': direction,
  'payable_weight': kg,
  'amount_total': amount,
  'status': 'PAGADO',
  'commercial_material_id': materialId,
  'material_label_snapshot': material,
  'counterparty_id': supplier,
  'counterparty_name_snapshot': 'PROVEEDOR $supplier',
};
Map<String, dynamic> tariff(double value, {String supplier = 'p1'}) => {
  ...ticket('purchase', 0, 0, supplier: supplier),
  'final_price': value,
};

void main() {
  test(
    'weights both sale channels by kilograms and respects one peso spread',
    () {
      final analysis = MenudeoWeightedPriceAnalysis.build(
        tickets: [
          ticket('purchase', 10, 20),
          ticket('purchase', 90, 360),
          ticket('sale', 20, 100),
        ],
        activePrices: [tariff(6)],
        wholesaleSales: [
          {
            'material_name_snapshot': ' FIERRO ',
            'approved_weight': 80,
            'approved_amount': 560,
          },
        ],
      );
      final row = analysis.materials.single;
      expect(row.purchases.price, 3.8);
      expect(row.retailSales.price, 5);
      expect(row.wholesaleSales.price, 7);
      expect(row.sales.price, 6.6);
      expect(row.purchaseCeiling, closeTo(5.6, 1e-9));
      expect(row.saleFloor, 4.8);
      expect(analysis.suppliers.single.requiredReduction, closeTo(.4, 1e-9));
    },
  );
  test('rounds recommendations conservatively to cents', () {
    final analysis = MenudeoWeightedPriceAnalysis.build(
      tickets: [ticket('purchase', 3, 10), ticket('sale', 3, 20)],
      activePrices: [],
    );
    expect(analysis.materials.single.purchaseCeiling, 5.66);
    expect(analysis.materials.single.saleFloor, 4.34);
  });
  test('never mixes materials; excludes invalid or cancelled tickets', () {
    final analysis = MenudeoWeightedPriceAnalysis.build(
      tickets: [
        ticket('purchase', 100, 300),
        ticket('sale', 0, 800),
        ticket('sale', 1, double.nan),
        {...ticket('sale', 20, 900), 'status': 'CANCELADO'},
        ticket('sale', 10, 2000, material: 'COBRE', materialId: 'cobre'),
      ],
      activePrices: [],
    );
    final fierro = analysis.materials.singleWhere((r) => r.label == 'FIERRO');
    expect(fierro.purchaseCeiling, isNull);
    expect(fierro.saleFloor, 4);
    expect(analysis.excludedTickets, 3);
  });
  test(
    'keeps catalog prices separate from historical prices, including absent suppliers',
    () {
      final analysis = MenudeoWeightedPriceAnalysis.build(
        tickets: [ticket('purchase', 100, 300), ticket('sale', 100, 500)],
        activePrices: [
          tariff(3),
          tariff(5),
          tariff(2, supplier: 'p2'),
        ],
      );
      final row = analysis.suppliers.first;
      expect(row.purchases.price, 3);
      expect(row.currentMin, 3);
      expect(row.currentMax, 5);
      expect(row.requiredReduction, 1);
      expect(analysis.suppliers.last.purchases.price, isNull);
      expect(analysis.suppliers.last.requiredReduction, 0);
    },
  );
  test('ambiguous wholesale names and unapproved weights are excluded', () {
    final analysis = MenudeoWeightedPriceAnalysis.build(
      tickets: [
        ticket('purchase', 10, 20),
        ticket('purchase', 10, 30, materialId: 'other-grade'),
      ],
      activePrices: [],
      wholesaleSales: [
        {
          'material_name_snapshot': 'FIERRO',
          'approved_weight': 10,
          'approved_amount': 100,
        },
        {
          'material_name_snapshot': 'COBRE',
          'approved_weight': 10,
          'approved_amount': 100,
        },
      ],
    );
    expect(analysis.excludedWholesaleSales, 2);
    expect(analysis.materials.every((row) => row.sales.price == null), isTrue);
  });
  test(
    'unviable sales stay negative instead of inventing a profitable purchase',
    () {
      final analysis = MenudeoWeightedPriceAnalysis.build(
        tickets: [ticket('sale', 100, 50)],
        activePrices: [tariff(2)],
      );
      expect(analysis.materials.single.purchaseCeiling, -.5);
    },
  );
  test(
    'renders multi-page analysis with long labels and all suppliers',
    () async {
      final tickets = <Map<String, dynamic>>[];
      final prices = <Map<String, dynamic>>[];
      for (var index = 0; index < 35; index++) {
        final label = 'MATERIAL COMERCIAL DE PRUEBA GRADO ESPECIAL $index';
        tickets.add(
          ticket(
            'purchase',
            100,
            300,
            material: label,
            materialId: '$index',
            supplier: '$index',
          ),
        );
        tickets.add(
          ticket('sale', 100, 550, material: label, materialId: '$index'),
        );
        prices.add({...tickets[tickets.length - 2], 'final_price': 5});
      }
      final data = MenudeoWeightedPriceAnalysis.build(
        tickets: tickets,
        activePrices: prices,
      );
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          maxPages: 70,
          build: (_) =>
              buildMenudeoWeightedPriceSections(data, PdfColors.blueGrey800),
        ),
      );
      final bytes = await pdf.save();
      expect(bytes.length, greaterThan(1000));
      final directory = await Directory.systemTemp.createTemp(
        'menudeo-price-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final output = File('${directory.path}/analysis.pdf');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes);
      final qaPath = Platform.environment['DICSA_PRICE_QA_PDF'];
      if (qaPath != null) await output.copy(qaPath);
    },
  );
}
