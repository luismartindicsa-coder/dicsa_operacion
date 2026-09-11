/// Weekly price references. The minimum spread is pesos per payable kilogram,
/// before freight, processing, shrinkage and other operating costs.
const menudeoMinimumSpreadPerKg = 1.0;

class MenudeoWeightedVolume {
  double kg = 0;
  double amount = 0;
  double? get price => kg > 0 ? amount / kg : null;

  void add(double weight, double total) {
    kg += weight;
    amount += total;
  }
}

class MenudeoMaterialPriceAnalysis {
  MenudeoMaterialPriceAnalysis(this.key, this.label);
  final String key;
  final String label;
  final purchases = MenudeoWeightedVolume();
  final sales = MenudeoWeightedVolume();
  final retailSales = MenudeoWeightedVolume();
  final wholesaleSales = MenudeoWeightedVolume();
  double? get purchaseCeiling => sales.price == null
      ? null
      : ((sales.price! - menudeoMinimumSpreadPerKg) * 100 + 1e-9).floor() / 100;
  double? get saleFloor => purchases.price == null
      ? null
      : ((purchases.price! + menudeoMinimumSpreadPerKg) * 100 - 1e-9).ceil() /
            100;
  double? get spread => purchases.price == null || sales.price == null
      ? null
      : sales.price! - purchases.price!;
}

class MenudeoSupplierPriceAnalysis {
  MenudeoSupplierPriceAnalysis(this.supplier, this.material);
  final String supplier;
  final MenudeoMaterialPriceAnalysis material;
  final purchases = MenudeoWeightedVolume();
  final List<double> currentPrices = [];
  double? get currentMin => currentPrices.isEmpty
      ? null
      : currentPrices.reduce((a, b) => a < b ? a : b);
  double? get currentMax => currentPrices.isEmpty
      ? null
      : currentPrices.reduce((a, b) => a > b ? a : b);
  double? get requiredReduction =>
      currentMax == null || material.purchaseCeiling == null
      ? null
      : (currentMax! - material.purchaseCeiling!).clamp(0, double.infinity);
}

class MenudeoWeightedPriceAnalysis {
  MenudeoWeightedPriceAnalysis({
    required this.materials,
    required this.suppliers,
    required this.excludedTickets,
    required this.excludedWholesaleSales,
  });
  final List<MenudeoMaterialPriceAnalysis> materials;
  final List<MenudeoSupplierPriceAnalysis> suppliers;
  final int excludedTickets;
  final int excludedWholesaleSales;

  factory MenudeoWeightedPriceAnalysis.build({
    required List<Map<String, dynamic>> tickets,
    required List<Map<String, dynamic>> activePrices,
    List<Map<String, dynamic>> wholesaleSales = const [],
  }) {
    final materials = <String, MenudeoMaterialPriceAnalysis>{};
    final suppliers = <(String, String), MenudeoSupplierPriceAnalysis>{};
    var excluded = 0;
    String text(dynamic value) => (value ?? '').toString().trim();
    double? number(dynamic value) => double.tryParse(text(value));
    String materialKey(Map<String, dynamic> row) {
      // Compare the same commercial grade, never a blend of unrelated grades.
      for (final field in [
        'commercial_material_id',
        'material_alias_id',
        'general_material_id',
      ]) {
        if (text(row[field]).isNotEmpty) return '$field:${text(row[field])}';
      }
      return 'label:${text(row['material_label_snapshot']).toUpperCase()}';
    }

    MenudeoMaterialPriceAnalysis material(Map<String, dynamic> row) {
      final key = materialKey(row);
      return materials.putIfAbsent(
        key,
        () => MenudeoMaterialPriceAnalysis(
          key,
          text(row['material_label_snapshot']).isEmpty
              ? 'Material sin nombre'
              : text(row['material_label_snapshot']),
        ),
      );
    }

    MenudeoSupplierPriceAnalysis supplier(
      Map<String, dynamic> row,
      MenudeoMaterialPriceAnalysis mat,
    ) {
      final name = text(
        row['counterparty_name_snapshot'] ?? row['counterparty_name'],
      );
      final id = text(row['counterparty_id']);
      final key = (
        mat.key,
        id.isEmpty ? 'name:${name.toUpperCase()}' : 'id:$id',
      );
      return suppliers.putIfAbsent(
        key,
        () => MenudeoSupplierPriceAnalysis(
          name.isEmpty ? 'Sin proveedor' : name,
          mat,
        ),
      );
    }

    for (final row in tickets) {
      final direction = text(row['direction']).toLowerCase();
      final status = text(row['status']).toUpperCase();
      final kg = number(row['payable_weight']);
      final amount = number(row['amount_total']);
      if (!['purchase', 'sale'].contains(direction) ||
          !['PAGADO', 'PENDIENTE'].contains(status) ||
          kg == null ||
          !kg.isFinite ||
          kg <= 0 ||
          amount == null ||
          !amount.isFinite ||
          amount <= 0 ||
          materialKey(row) == 'label:') {
        excluded++;
        continue;
      }
      final mat = material(row);
      if (direction == 'sale') {
        mat.sales.add(kg, amount);
        mat.retailSales.add(kg, amount);
      } else {
        mat.purchases.add(kg, amount);
        supplier(row, mat).purchases.add(kg, amount);
      }
    }
    for (final row in activePrices) {
      if (text(row['direction']).toLowerCase() != 'purchase' ||
          materialKey(row) == 'label:') {
        continue;
      }
      final price = number(row['final_price']);
      if (price == null || !price.isFinite || price < 0) continue;
      supplier(row, material(row)).currentPrices.add(price);
    }
    // The two catalogs have unrelated IDs. Only unambiguous exact normalized
    // names are comparable; different grades must never be matched fuzzily.
    String normalized(String value) =>
        value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    final byName = <String, List<MenudeoMaterialPriceAnalysis>>{};
    for (final mat in materials.values) {
      byName.putIfAbsent(normalized(mat.label), () => []).add(mat);
    }
    var excludedWholesale = 0;
    for (final row in wholesaleSales) {
      final matches = byName[normalized(text(row['material_name_snapshot']))];
      final kg = number(row['approved_weight']);
      final amount = number(row['approved_amount']);
      if (matches == null ||
          matches.length != 1 ||
          kg == null ||
          !kg.isFinite ||
          kg <= 0 ||
          amount == null ||
          !amount.isFinite ||
          amount <= 0) {
        excludedWholesale++;
        continue;
      }
      final mat = matches.single;
      mat.wholesaleSales.add(kg, amount);
      mat.sales.add(kg, amount);
    }
    final materialRows = materials.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    final supplierRows = suppliers.values.toList()
      ..sort((a, b) {
        final bySupplier = a.supplier.compareTo(b.supplier);
        return bySupplier != 0
            ? bySupplier
            : a.material.label.compareTo(b.material.label);
      });
    return MenudeoWeightedPriceAnalysis(
      materials: materialRows,
      suppliers: supplierRows,
      excludedTickets: excluded,
      excludedWholesaleSales: excludedWholesale,
    );
  }
}
