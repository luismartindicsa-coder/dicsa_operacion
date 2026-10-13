import 'profitability_models.dart';

String profitQuantityUnit(Object? value) => switch (profitKey(value)) {
  'KG' || 'KGS' || 'KILOGRAMO' || 'KILOGRAMOS' => 'KG',
  'PZA' || 'PZAS' || 'PIEZA' || 'PIEZAS' => 'PZA',
  _ => 'PENDIENTE',
};

String profitUnitLabel(String unit) => switch (unit) {
  'KG' => 'kg',
  'PZA' => 'pzas',
  _ => 'unidades sin confirmar',
};

bool _pallet(Object? name) => RegExp(r'\bTARIMAS?\b').hasMatch(profitKey(name));

/// Confirmed by Dirección on 29/09/2026: Monroe's 66/222 pallets and
/// Emilio's corresponding sales are pieces; Braulio's bulk loads are kilos.
/// Scope these exceptions to material + counterparty, never a price threshold.
String profitRetailSaleUnit(ProfitRow row) {
  final explicit = profitQuantityUnit(row['quantity_unit']);
  if (explicit != 'PENDIENTE') return explicit;
  final material = profitKey(row['material_label_snapshot']);
  if (_pallet(material)) {
    final buyer = profitKey(row['counterparty_name_snapshot']);
    if (material == 'TARIMA' || material == 'TARIMAS') {
      if (['EMILIO SANDOVAL', 'VICTOR GARCIA'].contains(buyer)) return 'PZA';
      if (buyer == 'BRAULIO') return 'KG';
    }
    return 'PENDIENTE';
  }
  if (RegExp(r'LENA|LEÑA|CAJON.*MADERA').hasMatch(material)) {
    return 'PENDIENTE';
  }
  return 'KG';
}

String profitPurchaseUnit(
  ProfitRow row, {
  required bool retail,
  ProfitRow? catalog,
}) {
  final explicit = profitQuantityUnit(row['quantity_unit']);
  if (explicit != 'PENDIENTE') return explicit;
  final material = profitKey(
    row[retail ? 'material_label_snapshot' : 'material_name_snapshot'],
  );
  final supplier = profitKey(
    row[retail ? 'counterparty_name_snapshot' : 'provider_name_snapshot'],
  );
  if (['MONROE', 'MONROE NORTE', 'MONROE MEXICO'].contains(supplier) &&
      ['TARIMA', 'TARIMAS'].contains(material)) {
    return 'PZA';
  }
  return retail ? 'KG' : profitQuantityUnit(catalog?['unit']);
}
