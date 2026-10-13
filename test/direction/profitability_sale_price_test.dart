import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_engine.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_models.dart';
import 'profitability_account_test.dart' show account;
import 'profitability_fixtures.dart';

ProfitRow retailSale(
  String id,
  double kg,
  double amount, {
  String material = 'CARTON NACIONAL',
  String materialId = 'retail',
  String date = '2026-09-13',
  String direction = 'sale',
  String status = 'PAGADO',
  String buyer = '',
}) => {
  'id': id,
  'ticket_number': id,
  'ticket_date': date,
  'commercial_material_id': materialId,
  'material_label_snapshot': material,
  'net_weight': kg,
  'payable_weight': kg,
  'price_at_entry': kg > 0 ? amount / kg : 0,
  'amount_total': amount,
  'status': status,
  'direction': direction,
  'counterparty_name_snapshot': buyer,
};

ProfitAnalysis priceAnalysis({
  List<ProfitRow> wholesale = const [],
  List<ProfitRow> retail = const [],
  List<ProfitRow> historicWholesale = const [],
  List<ProfitRow> historicRetail = const [],
  String purchaseMaterial = 'CARTON NACIONAL',
  String saleMaterial = 'CARTON NACIONAL',
  String? recipeKey,
  String supplier = 'PLANTA A',
  String wholesaleUnit = 'KG',
}) => analyzeProfitability(
  profitFixture(
    overrides: {
      'compras_tickets': [
        {
          ...purchase('p', 100, 100, 150),
          'material_name_snapshot': purchaseMaterial,
          'provider_name_snapshot': supplier,
        },
      ],
      'mayoreo_material_catalog': [
        {'id': 'paca', 'name': saleMaterial, 'unit': wholesaleUnit},
      ],
      'material_commercial_catalog_v2': [
        {'id': 'retail', 'name': saleMaterial},
      ],
      'mayoreo_sales_reports': [
        for (final r in wholesale)
          {...r, 'material_name_snapshot': saleMaterial},
      ],
      'men_tickets': retail,
      'profit_history_mayoreo': [
        for (final r in historicWholesale)
          {...r, 'material_name_snapshot': saleMaterial},
      ],
      'profit_history_men': historicRetail,
    },
  ),
  ProfitReview(
    recipes: {
      if (recipeKey != null)
        'site:s1|compras:carton': ProfitRecipe(
          outputs: [ProfitOutputRule(recipeKey, .9)],
          note: 'Recuperación del 90% verificada',
        ),
    },
  ),
  inferOperations: true,
);

void main() {
  test(
    'generic scrap includes both areas even when only retail uses the generic name',
    () {
      final a = priceAnalysis(
        purchaseMaterial: 'CHATARRA',
        saleMaterial: 'CHATARRA MIXTA',
        wholesale: [sale('w', 900, 4500)],
        retail: [retailSale('r', 100, 300, material: 'CHATARRA')],
      );
      expect(account(a).block('value'), 480);
    },
  );
  test(
    'confirmed pallet pieces combine buyers but never include kg sales or kg allocation weight',
    () {
      final a = priceAnalysis(
        supplier: 'MONROE',
        purchaseMaterial: 'TARIMAS',
        saleMaterial: 'TARIMA',
        retail: [
          retailSale(
            'emilio',
            288,
            9504,
            material: 'TARIMA',
            buyer: 'EMILIO SANDOVAL',
          ),
          retailSale(
            'victor',
            515,
            10300,
            material: 'TARIMA',
            buyer: 'VICTOR GARCIA',
          ),
          retailSale(
            'braulio',
            25310,
            60744,
            material: 'TARIMA',
            buyer: 'BRAULIO',
          ),
        ],
      );
      expect(account(a).block('value'), closeTo(100 * 19804 / 803, .001));
      expect(account(a).pieces, 100);
      expect(account(a).kg, 0);
      expect(a.purchases.single.physicalKg, 0);
      expect(a.benchmarks['men:retail@PZA']!.price, closeTo(19804 / 803, .001));
      expect(a.benchmarks['men:retail']!.price, closeTo(2.4, .001));
    },
  );
  test('explicit recovery combines wholesale and retail pieces', () {
    final a = priceAnalysis(
      supplier: 'MONROE',
      purchaseMaterial: 'TARIMAS',
      saleMaterial: 'TARIMA',
      wholesaleUnit: 'PZA',
      recipeKey: 'ventas:paca',
      wholesale: [sale('w', 100, 3000)],
      retail: [
        retailSale('r', 300, 6000, material: 'TARIMA', buyer: 'VICTOR GARCIA'),
      ],
    );
    expect(account(a).block('value'), closeTo(100 * .9 * 9000 / 400, .001));
  });
  test(
    'wood crate equivalence requires equal quantities and later sales; remains explicitly inferred',
    () {
      ProfitAnalysis run(double sold) => priceAnalysis(
        purchaseMaterial: 'CAJON MADERA',
        retail: [retailSale('wood', sold, sold * .8, material: 'MADERA PIEZA')],
      );
      final matched = account(run(100));
      expect(matched.block('value'), 80);
      expect(
        matched.assumptions.join(' '),
        contains('Equivalencia provisional'),
      );
      expect(account(run(99)).block('value'), 150);
    },
  );
  test(
    'pallet prices remain pending when retail mixes possible pieces and kilos',
    () {
      final a = priceAnalysis(
        purchaseMaterial: 'TARIMAS',
        saleMaterial: 'TARIMA',
        retail: [
          retailSale('pieces', 66, 2178, material: 'TARIMA'),
          retailSale('kilos', 6605, 15852, material: 'TARIMA'),
        ],
      );
      expect(
        account(a).block('value'),
        150,
      ); // Existing provisional purchase value.
      expect(
        account(a).assumptions.join(' '),
        contains('kilos, piezas o cargas'),
      );
    },
  );
  test('current family sales precede an isolated historic exact name', () {
    final a = priceAnalysis(
      purchaseMaterial: 'CHATARRA',
      saleMaterial: 'CHATARRA MIXTA',
      wholesale: [sale('w', 10000, 45000)],
      historicRetail: [
        retailSale('old', 20, 560, material: 'CHATARRA', date: '2026-08-21'),
      ],
    );
    expect(account(a).block('value'), 450);
  });
  test(
    'combines amounts and kilos from both areas, not their average prices',
    () {
      final a = priceAnalysis(
        wholesale: [sale('w', 100, 200)],
        retail: [retailSale('r1', 50, 150), retailSale('r2', 250, 1050)],
      );
      // (200 + 150 + 1050) / (100 + 50 + 250) = 3.50.
      expect(account(a).block('value'), closeTo(350, .001));
      final value = account(
        a,
      ).components.singleWhere((c) => c.block == 'value');
      expect(value.rule, contains('Mayoreo + Menudeo'));
      expect(value.rule, contains('1400.00 / 400.00 kg'));
      expect(value.reference, contains('Menudeo'));
    },
  );
  test('wholesale alone supplies its quantity weighted price', () {
    final a = priceAnalysis(
      wholesale: [sale('w1', 100, 200), sale('w2', 300, 1200)],
    );
    expect(account(a).block('value'), 350);
  });
  test(
    'retail alone supplies its quantity weighted price and excludes non-sales',
    () {
      final a = priceAnalysis(
        retail: [
          retailSale('r1', 100, 200),
          retailSale('r2', 300, 1200),
          retailSale('cancelled', 100, 99999, status: 'CANCELADO'),
          retailSale('zero', 0, 99999),
          retailSale(
            'other',
            100,
            99999,
            material: 'COBRE',
            materialId: 'copper',
          ),
        ],
        historicRetail: [
          retailSale(
            'purchase',
            100,
            99999,
            date: '2026-08-10',
            direction: 'purchase',
          ),
        ],
      );
      expect(account(a).block('value'), 350);
      expect(a.benchmarks['men:retail']!.count, 2);
    },
  );
  test(
    'current retail excludes historic wholesale even when only wholesale has a recipe key',
    () {
      final a = priceAnalysis(
        historicWholesale: [
          {...sale('old', 100, 10000), 'sale_date': '2026-08-10'},
        ],
        retail: [retailSale('current', 100, 400)],
        recipeKey: 'ventas:paca',
      );
      expect(account(a).block('value'), closeTo(360, .001));
      final c = a.companies.singleWhere((c) => c.entity.key == 'site:s1');
      expect(c.operating!.known('value'), closeTo(360, .001));
      expect(c.materials.single.value, closeTo(360, .001));
    },
  );
  test('current wholesale excludes historic retail', () {
    final a = priceAnalysis(
      wholesale: [sale('w', 100, 200)],
      historicRetail: [retailSale('old', 100, 10000, date: '2026-08-10')],
    );
    expect(account(a).block('value'), 200);
  });
  test(
    'history combines both areas only if neither has current comparable sales',
    () {
      final a = priceAnalysis(
        historicWholesale: [
          {...sale('old', 100, 200), 'sale_date': '2026-08-10'},
        ],
        historicRetail: [retailSale('old', 300, 1200, date: '2026-08-10')],
      );
      expect(account(a).block('value'), 350);
      expect(
        account(a).components.singleWhere((c) => c.block == 'value').rule,
        contains('referencia histórica'),
      );
    },
  );
  test(
    'explicit recovery uses the combined price even if its selected area has no sales',
    () {
      final a = priceAnalysis(
        retail: [retailSale('r', 100, 400)],
        recipeKey: 'ventas:paca',
      );
      expect(account(a).block('value'), closeTo(360, .001));
    },
  );
  test(
    'American cardboard uses Celanese from either area without including national cardboard',
    () {
      final a = priceAnalysis(
        purchaseMaterial: 'CARTON AMERICANO',
        saleMaterial: 'CARTON CELANESE',
        wholesale: [sale('w', 100, 200)],
        retail: [
          retailSale('r', 300, 1200, material: 'CARTON CELANESE EN PACAS'),
          retailSale('national', 100, 99999, materialId: 'national'),
        ],
      );
      expect(account(a).block('value'), 350);
    },
  );
}
