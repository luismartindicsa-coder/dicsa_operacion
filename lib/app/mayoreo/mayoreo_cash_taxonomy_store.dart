import 'dart:async';

import 'package:flutter/foundation.dart';

import '../shared/cash_taxonomy/cash_taxonomy_repository.dart';

enum MayoreoCashMovementType { entry, exit }

class MayoreoCashConceptDefinition {
  final String id;
  final String label;
  final bool requiresUnit;
  final bool requiresQuantity;
  final bool requiresPrice;
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
  final String priceLabel;
  final String amountLabel;
  final String companyLabel;
  final String subconceptLabel;
  final String commentLabel;

  const MayoreoCashConceptDefinition({
    required this.id,
    required this.label,
    this.requiresUnit = false,
    this.requiresQuantity = false,
    this.requiresPrice = false,
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
    this.priceLabel = 'Precio',
    this.amountLabel = 'Importe',
    this.companyLabel = 'Empresa',
    this.subconceptLabel = 'Subconcepto',
    this.commentLabel = 'Comentario corto',
  });

  MayoreoCashConceptDefinition copyWith({
    String? id,
    String? label,
    bool? requiresUnit,
    bool? requiresQuantity,
    bool? requiresPrice,
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
    String? priceLabel,
    String? amountLabel,
    String? companyLabel,
    String? subconceptLabel,
    String? commentLabel,
  }) {
    return MayoreoCashConceptDefinition(
      id: id ?? this.id,
      label: label ?? this.label,
      requiresUnit: requiresUnit ?? this.requiresUnit,
      requiresQuantity: requiresQuantity ?? this.requiresQuantity,
      requiresPrice: requiresPrice ?? this.requiresPrice,
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
      priceLabel: priceLabel ?? this.priceLabel,
      amountLabel: amountLabel ?? this.amountLabel,
      companyLabel: companyLabel ?? this.companyLabel,
      subconceptLabel: subconceptLabel ?? this.subconceptLabel,
      commentLabel: commentLabel ?? this.commentLabel,
    );
  }
}

class MayoreoCashRubricDefinition {
  final MayoreoCashMovementType movementType;
  final String label;
  final List<MayoreoCashConceptDefinition> concepts;

  const MayoreoCashRubricDefinition({
    required this.movementType,
    required this.label,
    required this.concepts,
  });

  MayoreoCashRubricDefinition copyWith({
    MayoreoCashMovementType? movementType,
    String? label,
    List<MayoreoCashConceptDefinition>? concepts,
  }) {
    return MayoreoCashRubricDefinition(
      movementType: movementType ?? this.movementType,
      label: label ?? this.label,
      concepts: concepts ?? this.concepts,
    );
  }
}

class MayoreoCashTaxonomyStore
    extends ValueNotifier<List<MayoreoCashRubricDefinition>> {
  MayoreoCashTaxonomyStore._() : super(_seedRubrics()) {
    unawaited(ensureLoaded());
  }

  static final MayoreoCashTaxonomyStore instance = MayoreoCashTaxonomyStore._();

  Future<void>? _loadFuture;
  Future<void> _saveQueue = Future<void>.value();

  final ValueNotifier<List<String>> entryPeople =
      ValueNotifier<List<String>>(const <String>[
        'APASEO',
        'NORMA',
        'JUAN SOLIS',
        'ASUNCION',
        'BOVEDA',
        'EL PALOMAR',
        'SERVIN',
        'DESPERDICIOS QUERETANA SAN PABLO',
        'DESPERDICIOS QUERETANA CRISTO',
        'NOMINA',
        'OTRO',
      ]);

  final ValueNotifier<List<String>> exitPeople =
      ValueNotifier<List<String>>(const <String>[
        'COMPRA DIRECTA',
        'GASTOS ADMINISTRATIVOS',
        'GASTOS FINANCIEROS',
        'GASTOS OPERATIVOS',
        'GASTOS PERSONALES',
        'CAJA',
        'NOMINA',
        'OTRO',
      ]);

  List<MayoreoCashRubricDefinition> rubricsFor(MayoreoCashMovementType type) {
    return value
        .where((rubric) => rubric.movementType == type)
        .toList(growable: false);
  }

  Future<void> ensureLoaded() {
    return _loadFuture ??= _loadFromRemote();
  }

  Future<void> _loadFromRemote() async {
    final payload = await CashTaxonomyRepository.instance.loadArea('mayoreo');
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

    final loadedEntryPeople = _stringListFromJson(payload['entry_people']);
    if (loadedEntryPeople.isNotEmpty) {
      entryPeople.value = loadedEntryPeople;
    }

    final loadedExitPeople = _stringListFromJson(payload['exit_people']);
    if (loadedExitPeople.isNotEmpty) {
      exitPeople.value = loadedExitPeople;
    }

    notifyListeners();
  }

  void _schedulePersist() {
    final snapshot = _toJson();
    _saveQueue = _saveQueue.then(
      (_) => CashTaxonomyRepository.instance.saveArea('mayoreo', snapshot),
    );
  }

  void upsertConcept({
    required MayoreoCashMovementType movementType,
    required String rubricLabel,
    required MayoreoCashConceptDefinition concept,
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
    required MayoreoCashMovementType movementType,
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

  String nextConceptId() {
    return 'cash-concept-${DateTime.now().microsecondsSinceEpoch}';
  }

  List<String> peopleFor(MayoreoCashMovementType type) {
    return List<String>.from(
      type == MayoreoCashMovementType.entry
          ? entryPeople.value
          : exitPeople.value,
    )..sort();
  }

  void addPersonOption({
    required MayoreoCashMovementType movementType,
    required String label,
  }) {
    final normalized = label.trim().toUpperCase();
    if (normalized.isEmpty) return;
    final target = movementType == MayoreoCashMovementType.entry
        ? entryPeople
        : exitPeople;
    if (target.value.contains(normalized)) return;
    target.value = [...target.value, normalized]..sort();
    notifyListeners();
    _schedulePersist();
  }

  void deletePersonOption({
    required MayoreoCashMovementType movementType,
    required String label,
  }) {
    final target = movementType == MayoreoCashMovementType.entry
        ? entryPeople
        : exitPeople;
    target.value = target.value
        .where((item) => item != label)
        .toList(growable: false);
    notifyListeners();
    _schedulePersist();
  }

  Map<String, dynamic> _toJson() {
    return <String, dynamic>{
      'rubrics': value.map(_rubricToJson).toList(growable: false),
      'entry_people': entryPeople.value,
      'exit_people': exitPeople.value,
    };
  }

  Map<String, dynamic> _rubricToJson(MayoreoCashRubricDefinition rubric) {
    return <String, dynamic>{
      'movement_type': _movementTypeToJson(rubric.movementType),
      'label': rubric.label,
      'concepts': rubric.concepts.map(_conceptToJson).toList(growable: false),
    };
  }

  Map<String, dynamic> _conceptToJson(MayoreoCashConceptDefinition concept) {
    return <String, dynamic>{
      'id': concept.id,
      'label': concept.label,
      'requires_unit': concept.requiresUnit,
      'requires_quantity': concept.requiresQuantity,
      'requires_price': concept.requiresPrice,
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
      'price_label': concept.priceLabel,
      'amount_label': concept.amountLabel,
      'company_label': concept.companyLabel,
      'subconcept_label': concept.subconceptLabel,
      'comment_label': concept.commentLabel,
    };
  }
}

MayoreoCashRubricDefinition _rubricFromJson(Map<String, dynamic> json) {
  return MayoreoCashRubricDefinition(
    movementType: _movementTypeFromJson(
      json['movement_type']?.toString() ?? 'entry',
    ),
    label: json['label']?.toString() ?? '',
    concepts: (json['concepts'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => _conceptFromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
  );
}

MayoreoCashConceptDefinition _conceptFromJson(Map<String, dynamic> json) {
  return MayoreoCashConceptDefinition(
    id: json['id']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    requiresUnit: json['requires_unit'] == true,
    requiresQuantity: json['requires_quantity'] == true,
    requiresPrice: json['requires_price'] == true,
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
    priceLabel: json['price_label']?.toString() ?? 'Precio',
    amountLabel: json['amount_label']?.toString() ?? 'Importe',
    companyLabel: json['company_label']?.toString() ?? 'Empresa',
    subconceptLabel: json['subconcept_label']?.toString() ?? 'Subconcepto',
    commentLabel: json['comment_label']?.toString() ?? 'Comentario corto',
  );
}

String _movementTypeToJson(MayoreoCashMovementType type) {
  switch (type) {
    case MayoreoCashMovementType.entry:
      return 'entry';
    case MayoreoCashMovementType.exit:
      return 'exit';
  }
}

MayoreoCashMovementType _movementTypeFromJson(String raw) {
  switch (raw) {
    case 'exit':
      return MayoreoCashMovementType.exit;
    case 'entry':
    default:
      return MayoreoCashMovementType.entry;
  }
}

List<String> _stringListFromJson(Object? raw) {
  return (raw as List? ?? const <dynamic>[])
      .map((item) => item.toString())
      .where((item) => item.trim().isNotEmpty)
      .toList(growable: false);
}

List<MayoreoCashRubricDefinition> _seedRubrics() {
  const drivers = <String>['Luis', 'Sra Mary', 'Diana'];
  const destinations = <String>[
    'El Palomar',
    'Servin',
    'San Pablo',
    'Cristo',
    'Caja',
  ];
  const clients = <String>['Apaseo', 'Norma', 'Juan Solis', 'Asuncion'];

  return <MayoreoCashRubricDefinition>[
    const MayoreoCashRubricDefinition(
      movementType: MayoreoCashMovementType.entry,
      label: 'Venta de material',
      concepts: <MayoreoCashConceptDefinition>[
        MayoreoCashConceptDefinition(
          id: 'entry-sale-apaseo',
          label: 'Apaseo',
          requiresSubconcept: true,
          requiresQuantity: true,
          requiresPrice: true,
          subconcepts: <String>[
            'Bolsa',
            'Tarima',
            'Leña',
            'Pedacería',
            'Plástico',
            'Garrafa',
            'Charola',
            'Unicel',
          ],
          subconceptLabel: 'Material',
          quantityLabel: 'Peso',
          priceLabel: 'Precio',
          amountLabel: 'Importe',
          commentLabel: 'Detalle',
        ),
        MayoreoCashConceptDefinition(
          id: 'entry-sale-norma',
          label: 'Norma',
          requiresSubconcept: true,
          requiresQuantity: true,
          requiresPrice: true,
          subconcepts: <String>['Tarima', 'Leña'],
          subconceptLabel: 'Material',
          quantityLabel: 'Peso',
          priceLabel: 'Precio',
          amountLabel: 'Importe',
          commentLabel: 'Detalle',
        ),
        MayoreoCashConceptDefinition(
          id: 'entry-sale-juan-solis',
          label: 'Juan Solis',
          requiresSubconcept: true,
          requiresQuantity: true,
          requiresPrice: true,
          subconcepts: <String>['Leña', 'Tarima'],
          subconceptLabel: 'Material',
          quantityLabel: 'Peso',
          priceLabel: 'Precio',
          amountLabel: 'Importe',
          commentLabel: 'Detalle',
        ),
        MayoreoCashConceptDefinition(
          id: 'entry-sale-asuncion',
          label: 'Asuncion',
          requiresSubconcept: true,
          requiresQuantity: true,
          requiresPrice: true,
          subconcepts: <String>['Vidrio', 'Textil'],
          subconceptLabel: 'Material',
          quantityLabel: 'Peso',
          priceLabel: 'Precio',
          amountLabel: 'Importe',
          commentLabel: 'Detalle',
        ),
        MayoreoCashConceptDefinition(
          id: 'entry-sale-other',
          label: 'Otro',
          requiresCompany: true,
          companyIsText: true,
          companyLabel: 'Cliente',
          requiresSubconcept: true,
          subconceptIsText: true,
          subconceptLabel: 'Material',
          requiresQuantity: true,
          requiresPrice: true,
          quantityLabel: 'Peso',
          priceLabel: 'Precio',
          amountLabel: 'Importe',
          commentLabel: 'Detalle',
        ),
      ],
    ),
    const MayoreoCashRubricDefinition(
      movementType: MayoreoCashMovementType.entry,
      label: 'Reposición de fondo',
      concepts: <MayoreoCashConceptDefinition>[
        MayoreoCashConceptDefinition(
          id: 'entry-reposition-vault',
          label: 'Bóveda',
          requiresSubconcept: true,
          subconcepts: <String>['Luis', 'Sra Mary'],
          subconceptLabel: 'Cuenta',
          amountLabel: 'Importe',
          commentLabel: 'Detalle',
        ),
      ],
    ),
    const MayoreoCashRubricDefinition(
      movementType: MayoreoCashMovementType.entry,
      label: 'Cheque',
      concepts: <MayoreoCashConceptDefinition>[
        MayoreoCashConceptDefinition(
          id: 'entry-check-palomar',
          label: 'El Palomar',
          amountLabel: 'Importe',
          commentLabel: 'No. de cheque',
        ),
        MayoreoCashConceptDefinition(
          id: 'entry-check-servin',
          label: 'Servin',
          amountLabel: 'Importe',
          commentLabel: 'No. de cheque',
        ),
        MayoreoCashConceptDefinition(
          id: 'entry-check-san-pablo',
          label: 'Desperdicios Queretana San Pablo',
          amountLabel: 'Importe',
          commentLabel: 'No. de cheque',
        ),
        MayoreoCashConceptDefinition(
          id: 'entry-check-cristo',
          label: 'Desperdicios Queretana Cristo',
          amountLabel: 'Importe',
          commentLabel: 'No. de cheque',
        ),
        MayoreoCashConceptDefinition(
          id: 'entry-check-nomina',
          label: 'Nómina',
          amountLabel: 'Importe',
          commentLabel: 'No. de cheque',
        ),
      ],
    ),
    const MayoreoCashRubricDefinition(
      movementType: MayoreoCashMovementType.entry,
      label: 'Otro',
      concepts: <MayoreoCashConceptDefinition>[
        MayoreoCashConceptDefinition(
          id: 'entry-other',
          label: 'Otro',
          requiresSubconcept: true,
          subconceptIsText: true,
          subconceptLabel: 'Concepto',
          amountLabel: 'Importe',
          commentLabel: 'Detalle',
        ),
      ],
    ),
    const MayoreoCashRubricDefinition(
      movementType: MayoreoCashMovementType.exit,
      label: 'Compra de material',
      concepts: <MayoreoCashConceptDefinition>[
        MayoreoCashConceptDefinition(
          id: 'exit-buy-direct',
          label: 'Compra directa',
          requiresCompany: true,
          companyIsText: true,
          companyLabel: 'Cliente',
          requiresSubconcept: true,
          subconceptIsText: true,
          subconceptLabel: 'Material',
          requiresQuantity: true,
          requiresPrice: true,
          quantityLabel: 'Peso',
          priceLabel: 'Precio',
          amountLabel: 'Importe',
          commentLabel: 'Detalle',
        ),
      ],
    ),
    const MayoreoCashRubricDefinition(
      movementType: MayoreoCashMovementType.exit,
      label: 'Gastos administrativos',
      concepts: <MayoreoCashConceptDefinition>[
        MayoreoCashConceptDefinition(
          id: 'exit-admin-stationery',
          label: 'Papelería',
          commentLabel: 'Detalle',
        ),
        MayoreoCashConceptDefinition(
          id: 'exit-admin-maintenance',
          label: 'Mantenimiento',
          commentLabel: 'Detalle',
        ),
        MayoreoCashConceptDefinition(
          id: 'exit-admin-remodel',
          label: 'Remodelación',
          commentLabel: 'Detalle',
        ),
      ],
    ),
    const MayoreoCashRubricDefinition(
      movementType: MayoreoCashMovementType.exit,
      label: 'Gastos financieros',
      concepts: <MayoreoCashConceptDefinition>[
        MayoreoCashConceptDefinition(
          id: 'exit-fin-loan',
          label: 'Préstamo',
          commentLabel: 'Detalle',
        ),
        MayoreoCashConceptDefinition(
          id: 'exit-fin-interest',
          label: 'Intereses',
          commentLabel: 'Detalle',
        ),
      ],
    ),
    MayoreoCashRubricDefinition(
      movementType: MayoreoCashMovementType.exit,
      label: 'Gastos operativos',
      concepts: <MayoreoCashConceptDefinition>[
        const MayoreoCashConceptDefinition(
          id: 'exit-op-fuel',
          label: 'Combustible',
          requiresUnit: true,
          requiresQuantity: true,
          quantityLabel: 'Cantidad',
        ),
        const MayoreoCashConceptDefinition(
          id: 'exit-op-maintenance',
          label: 'Mantenimiento',
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
          commentLabel: 'Detalle',
        ),
        const MayoreoCashConceptDefinition(
          id: 'exit-op-commissions',
          label: 'Comisiones',
        ),
        MayoreoCashConceptDefinition(
          id: 'exit-op-scale',
          label: 'Báscula',
          requiresCompany: true,
          companyOptions: clients,
          requiresDriver: true,
          driverOptions: drivers,
        ),
        MayoreoCashConceptDefinition(
          id: 'exit-op-gratification',
          label: 'Gratificación',
          requiresDriver: true,
          driverOptions: drivers,
          requiresDestination: true,
          destinationOptions: destinations,
        ),
        MayoreoCashConceptDefinition(
          id: 'exit-op-dinner',
          label: 'Cena',
          requiresDriver: true,
          driverOptions: drivers,
          requiresDestination: true,
          destinationOptions: destinations,
        ),
        const MayoreoCashConceptDefinition(
          id: 'exit-op-equipment',
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
        MayoreoCashConceptDefinition(
          id: 'exit-op-freight',
          label: 'Flete',
          requiresDestination: true,
          destinationOptions: destinations,
          requiresMode: true,
          modes: const <String>['Full', 'Sencillo'],
        ),
        const MayoreoCashConceptDefinition(
          id: 'exit-op-trips',
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
        const MayoreoCashConceptDefinition(
          id: 'exit-op-oxygen',
          label: 'Oxígeno',
          requiresQuantity: true,
        ),
      ],
    ),
    const MayoreoCashRubricDefinition(
      movementType: MayoreoCashMovementType.exit,
      label: 'Gastos personales',
      concepts: <MayoreoCashConceptDefinition>[
        MayoreoCashConceptDefinition(
          id: 'exit-personal-luis',
          label: 'Luis',
          commentLabel: 'Concepto',
        ),
        MayoreoCashConceptDefinition(
          id: 'exit-personal-mary',
          label: 'Sra Mary',
          commentLabel: 'Concepto',
        ),
        MayoreoCashConceptDefinition(
          id: 'exit-personal-diana',
          label: 'Diana',
          commentLabel: 'Concepto',
        ),
      ],
    ),
    const MayoreoCashRubricDefinition(
      movementType: MayoreoCashMovementType.exit,
      label: 'Movimientos internos',
      concepts: <MayoreoCashConceptDefinition>[
        MayoreoCashConceptDefinition(
          id: 'exit-internal-cash',
          label: 'Caja',
          commentLabel: 'Detalle',
        ),
      ],
    ),
    const MayoreoCashRubricDefinition(
      movementType: MayoreoCashMovementType.exit,
      label: 'Nómina',
      concepts: <MayoreoCashConceptDefinition>[
        MayoreoCashConceptDefinition(
          id: 'exit-payroll',
          label: 'Nómina',
          commentLabel: 'Detalle',
        ),
      ],
    ),
  ];
}
