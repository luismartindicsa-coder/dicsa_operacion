import '../direction_shipments_store.dart';
import 'expected_income_models.dart';

String? palomarKnownMaterial(String value) {
  final carton = incomeMaterial(value);
  if (carton != null) return carton;
  final key = incomeKey(value).replaceAll('_', ' ');
  for (final option in kDirectionShipmentMaterials) {
    if (key == incomeKey(option.code).replaceAll('_', ' ') ||
        key == incomeKey(option.label)) {
      return option.code;
    }
  }
  return null;
}

String palomarCatalogCode(Map<String, dynamic> row) =>
    palomarKnownMaterial('${row['code']}') ??
    palomarKnownMaterial('${row['name']}') ??
    'MAYOREO:${row['id']}';

String palomarCatalogUnit(Object? unit) => switch (incomeKey('$unit')) {
  'KG' || 'KGS' || 'KILOGRAMO' || 'KILOGRAMOS' => 'kg',
  'PZA' || 'PZAS' || 'PIEZA' || 'PIEZAS' => 'pzas',
  'PACA' || 'PACAS' => 'pacas',
  'T' || 'TON' || 'TONELADA' || 'TONELADAS' => 't',
  _ => '',
};

List<PalomarMaterialQuote> palomarCatalogQuotes({
  required List<Map<String, dynamic>> materials,
  required List<Map<String, dynamic>> prices,
  required List<Map<String, dynamic>> clients,
  required IncomeClientRule? rule,
}) {
  final clientIds = {
    for (final c in clients)
      if (c['is_active'] == true &&
          (rule?.clientId == c['id'] || rule?.matches('${c['name']}') == true))
        c['id'],
  };
  final grouped = <String, List<PalomarMaterialQuote>>{};
  for (final m in materials) {
    final candidates = prices
        .where(
          (p) =>
              p['is_active'] == true &&
              p['material_id'] == m['id'] &&
              clientIds.contains(p['company_id']),
        )
        .map((p) => incomeNumber(p['final_price']))
        .whereType<double>()
        .toSet();
    final code = palomarCatalogCode(m);
    grouped
        .putIfAbsent(code, () => [])
        .add(
          PalomarMaterialQuote(
            code,
            '${m['name']}',
            palomarCatalogUnit(m['unit']),
            m['is_active'] == true && candidates.length == 1
                ? candidates.single
                : null,
          ),
        );
  }
  return [
    for (final e in grouped.entries)
      PalomarMaterialQuote(
        e.key,
        e.value.first.label,
        e.value.map((q) => q.unit).toSet().length == 1
            ? e.value.first.unit
            : '',
        e.value.map((q) => q.price).toSet().length == 1
            ? e.value.first.price
            : null,
      ),
  ];
}
