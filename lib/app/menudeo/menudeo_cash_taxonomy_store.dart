import 'dart:async';

import 'package:flutter/foundation.dart';

import '../shared/cash_taxonomy/cash_taxonomy_repository.dart';

enum MenudeoCashMovementType { deposit, expense }

class MenudeoCashConceptDefinition {
  final String id;
  final String label;
  final bool requiresUnit;
  final bool requiresQuantity;
  final bool requiresCompany;
  final bool requiresDriver;
  final bool requiresDestination;
  final bool requiresSubconcept;
  final bool requiresMode;
  final List<String> subconcepts;
  final List<String> modes;
  final List<String> companyOptions;
  final List<String> driverOptions;
  final List<String> destinationOptions;
  final bool companyIsText;
  final bool subconceptIsText;
  final String quantityLabel;
  final String amountLabel;
  final String companyLabel;
  final String subconceptLabel;
  final String commentLabel;

  const MenudeoCashConceptDefinition({
    required this.id,
    required this.label,
    this.requiresUnit = false,
    this.requiresQuantity = false,
    this.requiresCompany = false,
    this.requiresDriver = false,
    this.requiresDestination = false,
    this.requiresSubconcept = false,
    this.requiresMode = false,
    this.subconcepts = const <String>[],
    this.modes = const <String>[],
    this.companyOptions = const <String>[],
    this.driverOptions = const <String>[],
    this.destinationOptions = const <String>[],
    this.companyIsText = false,
    this.subconceptIsText = false,
    this.quantityLabel = 'Cantidad',
    this.amountLabel = 'Importe',
    this.companyLabel = 'Empresa',
    this.subconceptLabel = 'Subconcepto',
    this.commentLabel = 'Comentario corto',
  });

  MenudeoCashConceptDefinition copyWith({
    String? id,
    String? label,
    bool? requiresUnit,
    bool? requiresQuantity,
    bool? requiresCompany,
    bool? requiresDriver,
    bool? requiresDestination,
    bool? requiresSubconcept,
    bool? requiresMode,
    List<String>? subconcepts,
    List<String>? modes,
    List<String>? companyOptions,
    List<String>? driverOptions,
    List<String>? destinationOptions,
    bool? companyIsText,
    bool? subconceptIsText,
    String? quantityLabel,
    String? amountLabel,
    String? companyLabel,
    String? subconceptLabel,
    String? commentLabel,
  }) {
    return MenudeoCashConceptDefinition(
      id: id ?? this.id,
      label: label ?? this.label,
      requiresUnit: requiresUnit ?? this.requiresUnit,
      requiresQuantity: requiresQuantity ?? this.requiresQuantity,
      requiresCompany: requiresCompany ?? this.requiresCompany,
      requiresDriver: requiresDriver ?? this.requiresDriver,
      requiresDestination: requiresDestination ?? this.requiresDestination,
      requiresSubconcept: requiresSubconcept ?? this.requiresSubconcept,
      requiresMode: requiresMode ?? this.requiresMode,
      subconcepts: subconcepts ?? this.subconcepts,
      modes: modes ?? this.modes,
      companyOptions: companyOptions ?? this.companyOptions,
      driverOptions: driverOptions ?? this.driverOptions,
      destinationOptions: destinationOptions ?? this.destinationOptions,
      companyIsText: companyIsText ?? this.companyIsText,
      subconceptIsText: subconceptIsText ?? this.subconceptIsText,
      quantityLabel: quantityLabel ?? this.quantityLabel,
      amountLabel: amountLabel ?? this.amountLabel,
      companyLabel: companyLabel ?? this.companyLabel,
      subconceptLabel: subconceptLabel ?? this.subconceptLabel,
      commentLabel: commentLabel ?? this.commentLabel,
    );
  }
}

class MenudeoCashRubricDefinition {
  final MenudeoCashMovementType movementType;
  final String label;
  final List<MenudeoCashConceptDefinition> concepts;

  const MenudeoCashRubricDefinition({
    required this.movementType,
    required this.label,
    required this.concepts,
  });

  MenudeoCashRubricDefinition copyWith({
    MenudeoCashMovementType? movementType,
    String? label,
    List<MenudeoCashConceptDefinition>? concepts,
  }) {
    return MenudeoCashRubricDefinition(
      movementType: movementType ?? this.movementType,
      label: label ?? this.label,
      concepts: concepts ?? this.concepts,
    );
  }
}

class MenudeoCashTaxonomyStore
    extends ValueNotifier<List<MenudeoCashRubricDefinition>> {
  MenudeoCashTaxonomyStore._() : super(_seedRubrics()) {
    unawaited(ensureLoaded());
  }

  static final MenudeoCashTaxonomyStore instance = MenudeoCashTaxonomyStore._();

  Future<void>? _loadFuture;
  Future<void> _saveQueue = Future<void>.value();

  final ValueNotifier<List<String>> depositPeople = ValueNotifier<List<String>>(
    const <String>[
      'PUBLICO GENERAL',
      'BOVEDA',
      'CAJA GRANDE',
      'SERVICIO DE TRANSPORTE',
      'OTRO',
    ],
  );

  final ValueNotifier<List<String>> expensePeople = ValueNotifier<List<String>>(
    const <String>[
      'OPERATIVO',
      'ADMINISTRATIVO',
      'NOMINA',
      'PERSONALES',
      'OTRO',
    ],
  );

  List<MenudeoCashRubricDefinition> rubricsFor(MenudeoCashMovementType type) {
    return value
        .where((rubric) => rubric.movementType == type)
        .toList(growable: false);
  }

  Future<void> ensureLoaded() {
    return _loadFuture ??= _loadFromRemote();
  }

  Future<void> _loadFromRemote() async {
    final payload = await CashTaxonomyRepository.instance.loadArea('menudeo');
    if (payload == null) return;
    _hydrateFromPayload(payload);
  }

  void _hydrateFromPayload(Map<String, dynamic> payload) {
    final rubricList = payload['rubrics'];
    if (rubricList is List) {
      value = rubricList
          .whereType<Map>()
          .map((item) => _rubricFromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }

    final loadedDepositPeople = _stringListFromJson(payload['deposit_people']);
    if (loadedDepositPeople.isNotEmpty) {
      depositPeople.value = loadedDepositPeople;
    }

    final loadedExpensePeople = _stringListFromJson(payload['expense_people']);
    if (loadedExpensePeople.isNotEmpty) {
      expensePeople.value = loadedExpensePeople;
    }

    notifyListeners();
  }

  void _schedulePersist() {
    final snapshot = _toJson();
    _saveQueue = _saveQueue.then(
      (_) => CashTaxonomyRepository.instance.saveArea('menudeo', snapshot),
    );
  }

  void upsertConcept({
    required MenudeoCashMovementType movementType,
    required String rubricLabel,
    required MenudeoCashConceptDefinition concept,
  }) {
    value = [
      for (final rubric in value)
        if (rubric.movementType == movementType && rubric.label == rubricLabel)
          rubric.copyWith(
            concepts: [
              for (final existing in rubric.concepts)
                if (existing.id == concept.id) concept else existing,
              if (!rubric.concepts.any((existing) => existing.id == concept.id))
                concept,
            ],
          )
        else
          rubric,
    ];
    _schedulePersist();
  }

  void deleteConcept({
    required MenudeoCashMovementType movementType,
    required String rubricLabel,
    required String conceptId,
  }) {
    value = [
      for (final rubric in value)
        if (rubric.movementType == movementType && rubric.label == rubricLabel)
          rubric.copyWith(
            concepts: rubric.concepts
                .where((concept) => concept.id != conceptId)
                .toList(growable: false),
          )
        else
          rubric,
    ];
    _schedulePersist();
  }

  List<String> peopleFor(MenudeoCashMovementType type) {
    return List<String>.from(
      type == MenudeoCashMovementType.deposit
          ? depositPeople.value
          : expensePeople.value,
    )..sort();
  }

  void addPersonOption({
    required MenudeoCashMovementType movementType,
    required String label,
  }) {
    final normalized = label.trim().toUpperCase();
    if (normalized.isEmpty) return;
    final target = movementType == MenudeoCashMovementType.deposit
        ? depositPeople
        : expensePeople;
    if (target.value.contains(normalized)) return;
    target.value = [...target.value, normalized]..sort();
    notifyListeners();
    _schedulePersist();
  }

  void deletePersonOption({
    required MenudeoCashMovementType movementType,
    required String label,
  }) {
    final target = movementType == MenudeoCashMovementType.deposit
        ? depositPeople
        : expensePeople;
    target.value = target.value
        .where((item) => item != label)
        .toList(growable: false);
    notifyListeners();
    _schedulePersist();
  }

  String nextConceptId() {
    return 'men-cash-concept-${DateTime.now().microsecondsSinceEpoch}';
  }

  Map<String, dynamic> _toJson() {
    return <String, dynamic>{
      'rubrics': value.map(_rubricToJson).toList(growable: false),
      'deposit_people': depositPeople.value,
      'expense_people': expensePeople.value,
    };
  }

  Map<String, dynamic> _rubricToJson(MenudeoCashRubricDefinition rubric) {
    return <String, dynamic>{
      'movement_type': _movementTypeToJson(rubric.movementType),
      'label': rubric.label,
      'concepts': rubric.concepts.map(_conceptToJson).toList(growable: false),
    };
  }

  Map<String, dynamic> _conceptToJson(MenudeoCashConceptDefinition concept) {
    return <String, dynamic>{
      'id': concept.id,
      'label': concept.label,
      'requires_unit': concept.requiresUnit,
      'requires_quantity': concept.requiresQuantity,
      'requires_company': concept.requiresCompany,
      'requires_driver': concept.requiresDriver,
      'requires_destination': concept.requiresDestination,
      'requires_subconcept': concept.requiresSubconcept,
      'requires_mode': concept.requiresMode,
      'subconcepts': concept.subconcepts,
      'modes': concept.modes,
      'company_options': concept.companyOptions,
      'driver_options': concept.driverOptions,
      'destination_options': concept.destinationOptions,
      'company_is_text': concept.companyIsText,
      'subconcept_is_text': concept.subconceptIsText,
      'quantity_label': concept.quantityLabel,
      'amount_label': concept.amountLabel,
      'company_label': concept.companyLabel,
      'subconcept_label': concept.subconceptLabel,
      'comment_label': concept.commentLabel,
    };
  }
}

MenudeoCashRubricDefinition _rubricFromJson(Map<String, dynamic> json) {
  return MenudeoCashRubricDefinition(
    movementType: _movementTypeFromJson(
      json['movement_type']?.toString() ?? 'deposit',
    ),
    label: json['label']?.toString() ?? '',
    concepts: (json['concepts'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => _conceptFromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
  );
}

MenudeoCashConceptDefinition _conceptFromJson(Map<String, dynamic> json) {
  return MenudeoCashConceptDefinition(
    id: json['id']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    requiresUnit: json['requires_unit'] == true,
    requiresQuantity: json['requires_quantity'] == true,
    requiresCompany: json['requires_company'] == true,
    requiresDriver: json['requires_driver'] == true,
    requiresDestination: json['requires_destination'] == true,
    requiresSubconcept: json['requires_subconcept'] == true,
    requiresMode: json['requires_mode'] == true,
    subconcepts: _stringListFromJson(json['subconcepts']),
    modes: _stringListFromJson(json['modes']),
    companyOptions: _stringListFromJson(json['company_options']),
    driverOptions: _stringListFromJson(json['driver_options']),
    destinationOptions: _stringListFromJson(json['destination_options']),
    companyIsText: json['company_is_text'] == true,
    subconceptIsText: json['subconcept_is_text'] == true,
    quantityLabel: json['quantity_label']?.toString() ?? 'Cantidad',
    amountLabel: json['amount_label']?.toString() ?? 'Importe',
    companyLabel: json['company_label']?.toString() ?? 'Empresa',
    subconceptLabel: json['subconcept_label']?.toString() ?? 'Subconcepto',
    commentLabel: json['comment_label']?.toString() ?? 'Comentario corto',
  );
}

String _movementTypeToJson(MenudeoCashMovementType type) {
  switch (type) {
    case MenudeoCashMovementType.deposit:
      return 'deposit';
    case MenudeoCashMovementType.expense:
      return 'expense';
  }
}

MenudeoCashMovementType _movementTypeFromJson(String raw) {
  switch (raw) {
    case 'expense':
      return MenudeoCashMovementType.expense;
    case 'deposit':
    default:
      return MenudeoCashMovementType.deposit;
  }
}

List<String> _stringListFromJson(Object? raw) {
  return (raw as List? ?? const <dynamic>[])
      .map((item) => item.toString())
      .where((item) => item.trim().isNotEmpty)
      .toList(growable: false);
}

List<MenudeoCashRubricDefinition> _seedRubrics() {
  const destinations = <String>[
    'De Acero',
    'Grupak',
    'San Pablo',
    'San Luis',
    'Jaime Velázquez',
    'TDF',
    'Morelia',
    'Querétaro',
    'Queretania',
  ];

  return <MenudeoCashRubricDefinition>[
    const MenudeoCashRubricDefinition(
      movementType: MenudeoCashMovementType.deposit,
      label: 'Venta de material',
      concepts: <MenudeoCashConceptDefinition>[
        MenudeoCashConceptDefinition(id: 'dep-sale-income', label: 'Ingreso'),
      ],
    ),
    const MenudeoCashRubricDefinition(
      movementType: MenudeoCashMovementType.deposit,
      label: 'Reposición de fondo',
      concepts: <MenudeoCashConceptDefinition>[
        MenudeoCashConceptDefinition(id: 'dep-repo-vault', label: 'Bóveda'),
        MenudeoCashConceptDefinition(
          id: 'dep-repo-big-cash',
          label: 'Caja grande',
        ),
      ],
    ),
    const MenudeoCashRubricDefinition(
      movementType: MenudeoCashMovementType.deposit,
      label: 'Servicio de transporte',
      concepts: <MenudeoCashConceptDefinition>[
        MenudeoCashConceptDefinition(
          id: 'dep-transport-buy',
          label: 'Compra de material',
        ),
        MenudeoCashConceptDefinition(
          id: 'dep-transport-sell',
          label: 'Venta de material',
        ),
      ],
    ),
    MenudeoCashRubricDefinition(
      movementType: MenudeoCashMovementType.expense,
      label: 'Operativo',
      concepts: <MenudeoCashConceptDefinition>[
        const MenudeoCashConceptDefinition(
          id: 'exp-op-fuel',
          label: 'Combustible',
          requiresUnit: true,
          requiresQuantity: true,
        ),
        const MenudeoCashConceptDefinition(
          id: 'exp-op-maintenance',
          label: 'Mantenimiento',
          requiresUnit: true,
          requiresSubconcept: true,
          subconcepts: <String>[
            'Talacha',
            'Luz',
            'Espejos',
            'Llantas',
            'Mangueras',
            'Electricidad',
            'Mecánica',
          ],
        ),
        const MenudeoCashConceptDefinition(
          id: 'exp-op-commissions',
          label: 'Comisiones',
        ),
        const MenudeoCashConceptDefinition(
          id: 'exp-op-scale',
          label: 'Báscula',
          requiresCompany: true,
          requiresDriver: true,
        ),
        MenudeoCashConceptDefinition(
          id: 'exp-op-gratification',
          label: 'Gratificación',
          requiresDriver: true,
          requiresDestination: true,
          destinationOptions: destinations,
        ),
        MenudeoCashConceptDefinition(
          id: 'exp-op-dinner',
          label: 'Cena',
          requiresDriver: true,
          requiresDestination: true,
          destinationOptions: destinations,
        ),
        const MenudeoCashConceptDefinition(
          id: 'exp-op-equipment',
          label: 'Equipo',
          requiresSubconcept: true,
          requiresQuantity: true,
          subconcepts: <String>[
            'Guantes',
            'Lentes',
            'Chalecos',
            'Tapones',
            'Uniformes',
            'Zapatos',
            'Extintores',
            'Cables',
            'Almacén',
            'Tanques',
            'Agujas',
          ],
        ),
        MenudeoCashConceptDefinition(
          id: 'exp-op-freight',
          label: 'Flete',
          requiresDestination: true,
          destinationOptions: destinations,
          requiresMode: true,
          modes: const <String>['Full', 'Sencillo'],
        ),
        const MenudeoCashConceptDefinition(
          id: 'exp-op-trips',
          label: 'Viajes',
          requiresSubconcept: true,
          subconcepts: <String>[
            'Comida',
            'Caseta',
            'Combustible',
            'Estacionamiento',
            'Tránsito',
          ],
        ),
        const MenudeoCashConceptDefinition(
          id: 'exp-op-oxygen',
          label: 'Oxígeno',
          requiresQuantity: true,
        ),
      ],
    ),
    const MenudeoCashRubricDefinition(
      movementType: MenudeoCashMovementType.expense,
      label: 'Administrativo',
      concepts: <MenudeoCashConceptDefinition>[
        MenudeoCashConceptDefinition(
          id: 'exp-admin-stationery',
          label: 'Papelería',
          requiresSubconcept: true,
          requiresQuantity: true,
          subconcepts: <String>[
            'Plumas',
            'Lápices',
            'Plumones',
            'Borradores',
            'Post-its',
            'Hojas',
            'Pegamento',
            'Tijeras',
            'Calculadora',
            'USB',
            'Engrapadora',
            'Grapas',
            'Sobres',
          ],
        ),
        MenudeoCashConceptDefinition(
          id: 'exp-admin-maintenance',
          label: 'Mantenimiento',
          requiresSubconcept: true,
          subconcepts: <String>[
            'Impresoras',
            'Computadoras',
            'Teléfonos',
            'Oficina',
          ],
        ),
        MenudeoCashConceptDefinition(
          id: 'exp-admin-remodel',
          label: 'Remodelación',
        ),
      ],
    ),
    const MenudeoCashRubricDefinition(
      movementType: MenudeoCashMovementType.expense,
      label: 'Nómina',
      concepts: <MenudeoCashConceptDefinition>[
        MenudeoCashConceptDefinition(
          id: 'exp-payroll-company',
          label: 'Empresa',
          requiresSubconcept: true,
          subconcepts: <String>['Whirlpool', 'KS', 'Monroe'],
        ),
        MenudeoCashConceptDefinition(id: 'exp-payroll-loan', label: 'Préstamo'),
      ],
    ),
    const MenudeoCashRubricDefinition(
      movementType: MenudeoCashMovementType.expense,
      label: 'Personales',
      concepts: <MenudeoCashConceptDefinition>[
        MenudeoCashConceptDefinition(id: 'exp-personal-food', label: 'Comida'),
        MenudeoCashConceptDefinition(id: 'exp-personal-gas', label: 'Gasolina'),
        MenudeoCashConceptDefinition(
          id: 'exp-personal-tolls',
          label: 'Casetas',
        ),
      ],
    ),
  ];
}
