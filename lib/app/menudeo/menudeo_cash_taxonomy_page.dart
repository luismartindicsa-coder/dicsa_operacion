import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../menudeo/menudeo_header_brand.dart';
import '../menudeo/menudeo_metric_card.dart';
import '../shared/app_shell.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'menudeo_cash_taxonomy_store.dart';
import 'menudeo_dashboard_page.dart';
import 'menudeo_theme.dart';

class MenudeoCashTaxonomyPage extends StatefulWidget {
  final bool instantOpen;

  const MenudeoCashTaxonomyPage({super.key, this.instantOpen = false});

  @override
  State<MenudeoCashTaxonomyPage> createState() =>
      _MenudeoCashTaxonomyPageState();
}

class _MenudeoCashTaxonomyPageState extends State<MenudeoCashTaxonomyPage> {
  bool _menuOpen = false;
  MenudeoCashMovementType _movementType = MenudeoCashMovementType.deposit;
  String? _selectedRubric;
  String? _selectedConceptId;
  late final TextEditingController _depositPersonC;
  late final TextEditingController _expensePersonC;

  @override
  void initState() {
    super.initState();
    _depositPersonC = TextEditingController();
    _expensePersonC = TextEditingController();
    MenudeoCashTaxonomyStore.instance.addListener(_handleStoreChange);
    _syncInitialSelection();
  }

  @override
  void dispose() {
    _depositPersonC.dispose();
    _expensePersonC.dispose();
    MenudeoCashTaxonomyStore.instance.removeListener(_handleStoreChange);
    super.dispose();
  }

  void _handleStoreChange() {
    if (!mounted) return;
    setState(_ensureSelectionIsValid);
  }

  void _syncInitialSelection() {
    final rubrics = _rubricsForCurrentType;
    _selectedRubric = rubrics.isEmpty ? null : rubrics.first.label;
    final concepts = _conceptsForCurrentRubric;
    _selectedConceptId = concepts.isEmpty ? null : concepts.first.id;
  }

  void _ensureSelectionIsValid() {
    final rubrics = _rubricsForCurrentType;
    if (_selectedRubric == null ||
        !rubrics.any((rubric) => rubric.label == _selectedRubric)) {
      _selectedRubric = rubrics.isEmpty ? null : rubrics.first.label;
    }
    final concepts = _conceptsForCurrentRubric;
    if (_selectedConceptId == null ||
        !concepts.any((concept) => concept.id == _selectedConceptId)) {
      _selectedConceptId = concepts.isEmpty ? null : concepts.first.id;
    }
  }

  List<MenudeoCashRubricDefinition> get _rubricsForCurrentType =>
      MenudeoCashTaxonomyStore.instance.rubricsFor(_movementType);

  List<MenudeoCashConceptDefinition> get _conceptsForCurrentRubric {
    final rubric = _rubricsForCurrentType.where(
      (item) => item.label == _selectedRubric,
    );
    if (rubric.isEmpty) return const <MenudeoCashConceptDefinition>[];
    return rubric.first.concepts;
  }

  MenudeoCashConceptDefinition? get _selectedConcept {
    final concepts = _conceptsForCurrentRubric;
    for (final concept in concepts) {
      if (concept.id == _selectedConceptId) return concept;
    }
    return concepts.isEmpty ? null : concepts.first;
  }

  Future<void> _openDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const MenudeoDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Menudeo':
        unawaited(_openDashboard());
        return;
      case 'Catálogo efectivo':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      default:
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
    }
  }

  Future<void> _addConcept() async {
    final created = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const _NewConceptDialog(),
    );
    final label = (created ?? '').trim();
    if (label.isEmpty || _selectedRubric == null) return;
    final concept = MenudeoCashConceptDefinition(
      id: MenudeoCashTaxonomyStore.instance.nextConceptId(),
      label: label,
    );
    MenudeoCashTaxonomyStore.instance.upsertConcept(
      movementType: _movementType,
      rubricLabel: _selectedRubric!,
      concept: concept,
    );
    setState(() => _selectedConceptId = concept.id);
  }

  void _deleteSelectedConcept() {
    final concept = _selectedConcept;
    final rubric = _selectedRubric;
    if (concept == null || rubric == null) return;
    MenudeoCashTaxonomyStore.instance.deleteConcept(
      movementType: _movementType,
      rubricLabel: rubric,
      conceptId: concept.id,
    );
  }

  void _saveConcept(MenudeoCashConceptDefinition concept) {
    final rubric = _selectedRubric;
    if (rubric == null) return;
    MenudeoCashTaxonomyStore.instance.upsertConcept(
      movementType: _movementType,
      rubricLabel: rubric,
      concept: concept,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = menudeoAreaTokens;
    return AreaThemeScope(
      tokens: menudeoAreaTokens,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape && _menuOpen) {
            setState(() => _menuOpen = false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AppShell(
          background: const _TaxonomyBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => _TaxonomyHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, contentAnim) => MenudeoHeaderBrand(
            contentAnim: contentAnim,
            title: 'Catálogo Efectivo',
          ),
          trailingBuilder: (_, _) => _TaxonomyHeaderButton(
            label: 'Dashboard',
            icon: Icons.space_dashboard_rounded,
            onTap: _openDashboard,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          MenudeoMetricCard(
                            icon: Icons.schema_rounded,
                            title: 'RUBROS',
                            value: '${_rubricsForCurrentType.length}',
                            detail:
                                _movementType == MenudeoCashMovementType.deposit
                                ? 'Configuración de depósitos'
                                : 'Configuración de gastos',
                            accent: tokens.primaryStrong,
                          ),
                          MenudeoMetricCard(
                            icon: Icons.account_tree_rounded,
                            title: 'CONCEPTOS',
                            value: '${_conceptsForCurrentRubric.length}',
                            detail: _selectedRubric ?? 'Sin rubro activo',
                            accent: tokens.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ContractGlassCard(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SegmentedButton<MenudeoCashMovementType>(
                              segments: const [
                                ButtonSegment(
                                  value: MenudeoCashMovementType.deposit,
                                  label: Text('Depósitos'),
                                ),
                                ButtonSegment(
                                  value: MenudeoCashMovementType.expense,
                                  label: Text('Gastos'),
                                ),
                              ],
                              selected: <MenudeoCashMovementType>{
                                _movementType,
                              },
                              onSelectionChanged: (selection) {
                                setState(() {
                                  _movementType = selection.first;
                                  _ensureSelectionIsValid();
                                });
                              },
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final rubric in _rubricsForCurrentType)
                                  ChoiceChip(
                                    label: Text(rubric.label),
                                    selected: _selectedRubric == rubric.label,
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedRubric = rubric.label;
                                        _ensureSelectionIsValid();
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ContractGlassCard(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _PeopleCatalogCard(
                                title: 'Recibido de',
                                people: MenudeoCashTaxonomyStore.instance
                                    .peopleFor(MenudeoCashMovementType.deposit),
                                controller: _depositPersonC,
                                onAdd: (value) => MenudeoCashTaxonomyStore
                                    .instance
                                    .addPersonOption(
                                      movementType:
                                          MenudeoCashMovementType.deposit,
                                      label: value,
                                    ),
                                onDelete: (value) => MenudeoCashTaxonomyStore
                                    .instance
                                    .deletePersonOption(
                                      movementType:
                                          MenudeoCashMovementType.deposit,
                                      label: value,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _PeopleCatalogCard(
                                title: 'Entregado a',
                                people: MenudeoCashTaxonomyStore.instance
                                    .peopleFor(MenudeoCashMovementType.expense),
                                controller: _expensePersonC,
                                onAdd: (value) => MenudeoCashTaxonomyStore
                                    .instance
                                    .addPersonOption(
                                      movementType:
                                          MenudeoCashMovementType.expense,
                                      label: value,
                                    ),
                                onDelete: (value) => MenudeoCashTaxonomyStore
                                    .instance
                                    .deletePersonOption(
                                      movementType:
                                          MenudeoCashMovementType.expense,
                                      label: value,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 320,
                              child: ContractGlassCard(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  14,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Conceptos',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        FilledButton(
                                          style: contractPrimaryButtonStyle(
                                            context,
                                          ),
                                          onPressed: _selectedRubric == null
                                              ? null
                                              : _addConcept,
                                          child: const Text('+'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: ListView.separated(
                                        itemCount:
                                            _conceptsForCurrentRubric.length,
                                        separatorBuilder: (_, _) =>
                                            const SizedBox(height: 8),
                                        itemBuilder: (context, index) {
                                          final concept =
                                              _conceptsForCurrentRubric[index];
                                          final selected =
                                              concept.id == _selectedConceptId;
                                          return InkWell(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            onTap: () => setState(
                                              () => _selectedConceptId =
                                                  concept.id,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                gradient: selected
                                                    ? kMenudeoPanelGradient
                                                    : null,
                                                color: selected
                                                    ? null
                                                    : Colors.white.withValues(
                                                        alpha: 0.72,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                border: Border.all(
                                                  color: selected
                                                      ? tokens.primaryStrong
                                                            .withValues(
                                                              alpha: 0.24,
                                                            )
                                                      : tokens.border
                                                            .withValues(
                                                              alpha: 0.48,
                                                            ),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    concept.label,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color:
                                                          tokens.primaryStrong,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    [
                                                      if (concept
                                                          .requiresQuantity)
                                                        concept.quantityLabel,
                                                      if (concept
                                                          .requiresCompany)
                                                        concept.companyLabel,
                                                      if (concept
                                                          .requiresSubconcept)
                                                        concept.subconceptLabel,
                                                      concept.amountLabel,
                                                    ].join(' · '),
                                                    style: const TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: kMenudeoMutedText,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _selectedConcept == null
                                  ? const _EmptyEditorState()
                                  : _ConceptEditorCard(
                                      concept: _selectedConcept!,
                                      onSave: _saveConcept,
                                      onDelete: _deleteSelectedConcept,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_menuOpen,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _menuOpen ? 1 : 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _menuOpen = false),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: _menuOpen ? 0 : -332,
                top: 0,
                bottom: 0,
                width: 320,
                child: IgnorePointer(
                  ignoring: !_menuOpen,
                  child: _TaxonomySidePanel(
                    onNavigate: _handleNavigationAction,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewConceptDialog extends StatefulWidget {
  const _NewConceptDialog();

  @override
  State<_NewConceptDialog> createState() => _NewConceptDialogState();
}

class _NewConceptDialogState extends State<_NewConceptDialog> {
  String _value = '';

  void _submit() {
    Navigator.of(context).pop(_value.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo concepto'),
      content: TextFormField(
        autofocus: true,
        initialValue: _value,
        onChanged: (value) => _value = value,
        onFieldSubmitted: (_) => _submit(),
        decoration: const InputDecoration(labelText: 'Nombre del concepto'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Crear')),
      ],
    );
  }
}

class _PeopleCatalogCard extends StatelessWidget {
  final String title;
  final List<String> people;
  final TextEditingController controller;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onDelete;

  const _PeopleCatalogCard({
    required this.title,
    required this.people,
    required this.controller,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in people)
              Chip(label: Text(item), onDeleted: () => onDelete(item)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _EditorTextField(
                label: 'Agregar opción',
                controller: controller,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: contractPrimaryButtonStyle(context),
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                onAdd(value);
                controller.clear();
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConceptEditorCard extends StatefulWidget {
  final MenudeoCashConceptDefinition concept;
  final ValueChanged<MenudeoCashConceptDefinition> onSave;
  final VoidCallback onDelete;

  const _ConceptEditorCard({
    required this.concept,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_ConceptEditorCard> createState() => _ConceptEditorCardState();
}

class _ConceptEditorCardState extends State<_ConceptEditorCard> {
  late TextEditingController _labelC;
  late TextEditingController _quantityLabelC;
  late TextEditingController _amountLabelC;
  late TextEditingController _companyLabelC;
  late TextEditingController _subconceptLabelC;
  late TextEditingController _commentLabelC;
  late TextEditingController _newSubconceptC;
  late MenudeoCashConceptDefinition _draft;

  @override
  void initState() {
    super.initState();
    _bootstrap(widget.concept);
  }

  @override
  void didUpdateWidget(covariant _ConceptEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.concept.id != widget.concept.id) {
      _disposeControllers();
      _bootstrap(widget.concept);
    }
  }

  void _bootstrap(MenudeoCashConceptDefinition concept) {
    _draft = concept;
    _labelC = TextEditingController(text: concept.label);
    _quantityLabelC = TextEditingController(text: concept.quantityLabel);
    _amountLabelC = TextEditingController(text: concept.amountLabel);
    _companyLabelC = TextEditingController(text: concept.companyLabel);
    _subconceptLabelC = TextEditingController(text: concept.subconceptLabel);
    _commentLabelC = TextEditingController(text: concept.commentLabel);
    _newSubconceptC = TextEditingController();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _labelC.dispose();
    _quantityLabelC.dispose();
    _amountLabelC.dispose();
    _companyLabelC.dispose();
    _subconceptLabelC.dispose();
    _commentLabelC.dispose();
    _newSubconceptC.dispose();
  }

  void _applySave() {
    widget.onSave(
      _draft.copyWith(
        label: _labelC.text.trim(),
        quantityLabel: _quantityLabelC.text.trim().isEmpty
            ? 'Cantidad'
            : _quantityLabelC.text.trim(),
        amountLabel: _amountLabelC.text.trim().isEmpty
            ? 'Importe'
            : _amountLabelC.text.trim(),
        companyLabel: _companyLabelC.text.trim().isEmpty
            ? 'Empresa'
            : _companyLabelC.text.trim(),
        subconceptLabel: _subconceptLabelC.text.trim().isEmpty
            ? 'Subconcepto'
            : _subconceptLabelC.text.trim(),
        commentLabel: _commentLabelC.text.trim().isEmpty
            ? 'Comentario corto'
            : _commentLabelC.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Editor de concepto',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                OutlinedButton(
                  style: contractSecondaryButtonStyle(context),
                  onPressed: widget.onDelete,
                  child: const Text('Eliminar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: contractPrimaryButtonStyle(context),
                  onPressed: _applySave,
                  child: const Text('Guardar'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _EditorTextField(label: 'Nombre del concepto', controller: _labelC),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _EditorToggleChip(
                  label: 'Unidad',
                  value: _draft.requiresUnit,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(requiresUnit: value),
                  ),
                ),
                _EditorToggleChip(
                  label: 'Cantidad',
                  value: _draft.requiresQuantity,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(requiresQuantity: value),
                  ),
                ),
                _EditorToggleChip(
                  label: 'Empresa',
                  value: _draft.requiresCompany,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(requiresCompany: value),
                  ),
                ),
                _EditorToggleChip(
                  label: 'Chofer',
                  value: _draft.requiresDriver,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(requiresDriver: value),
                  ),
                ),
                _EditorToggleChip(
                  label: 'Destino',
                  value: _draft.requiresDestination,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(requiresDestination: value),
                  ),
                ),
                _EditorToggleChip(
                  label: 'Subconcepto',
                  value: _draft.requiresSubconcept,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(requiresSubconcept: value),
                  ),
                ),
                _EditorToggleChip(
                  label: 'Modalidad',
                  value: _draft.requiresMode,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(requiresMode: value),
                  ),
                ),
                _EditorToggleChip(
                  label: 'Texto libre en subconcepto',
                  value: _draft.subconceptIsText,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(subconceptIsText: value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _EditorTextField(
                    label: 'Label cantidad',
                    controller: _quantityLabelC,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _EditorTextField(
                    label: 'Label importe',
                    controller: _amountLabelC,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _EditorTextField(
                    label: 'Label empresa',
                    controller: _companyLabelC,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _EditorTextField(
                    label: 'Label subconcepto',
                    controller: _subconceptLabelC,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _EditorTextField(
                    label: 'Label comentario',
                    controller: _commentLabelC,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Subconceptos',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in _draft.subconcepts)
                  Chip(
                    label: Text(item),
                    onDeleted: () => setState(
                      () => _draft = _draft.copyWith(
                        subconcepts: _draft.subconcepts
                            .where((existing) => existing != item)
                            .toList(growable: false),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _EditorTextField(
                    label: 'Agregar subconcepto',
                    controller: _newSubconceptC,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: contractPrimaryButtonStyle(context),
                  onPressed: () {
                    final value = _newSubconceptC.text.trim();
                    if (value.isEmpty) return;
                    setState(() {
                      _draft = _draft.copyWith(
                        subconcepts: <String>[..._draft.subconcepts, value],
                      );
                      _newSubconceptC.clear();
                    });
                  },
                  child: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ConceptCapturePreview(concept: _draft),
          ],
        ),
      ),
    );
  }
}

class _ConceptCapturePreview extends StatelessWidget {
  final MenudeoCashConceptDefinition concept;

  const _ConceptCapturePreview({required this.concept});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final fields = <String>[
      'Concepto',
      if (concept.requiresSubconcept) concept.subconceptLabel,
      if (concept.requiresCompany) concept.companyLabel,
      if (concept.requiresUnit) 'Unidad',
      if (concept.requiresQuantity) concept.quantityLabel,
      if (concept.requiresDriver) 'Chofer',
      if (concept.requiresDestination) 'Destino',
      if (concept.requiresMode) 'Modalidad',
      concept.amountLabel,
      concept.commentLabel,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.82),
            menudeoAreaTokens.surfaceTint.withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: menudeoAreaTokens.border.withValues(alpha: 0.62),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mini vista previa',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Asi se armara el renglon al capturar este concepto.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: kMenudeoMutedText,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final field in fields)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: kMenudeoPanelGradient,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: menudeoAreaTokens.border.withValues(alpha: 0.72),
                    ),
                  ),
                  child: Text(
                    field,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: tokens.primaryStrong,
                    ),
                  ),
                ),
            ],
          ),
          if (concept.requiresSubconcept &&
              !concept.subconceptIsText &&
              concept.subconcepts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Opciones de ${concept.subconceptLabel.toLowerCase()}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: tokens.badgeText,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in concept.subconcepts.take(6))
                  Chip(label: Text(item)),
                if (concept.subconcepts.length > 6)
                  Chip(label: Text('+${concept.subconcepts.length - 6} mas')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EditorTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _EditorTextField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.74),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: menudeoAreaTokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: menudeoAreaTokens.border.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }
}

class _EditorToggleChip extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _EditorToggleChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
    );
  }
}

class _EmptyEditorState extends StatelessWidget {
  const _EmptyEditorState();

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.all(24),
      child: const Center(
        child: Text(
          'Selecciona un concepto para editar sus parámetros.',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TaxonomyHeaderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _TaxonomyHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          if (onTap != null) {
            await onTap!();
          } else {
            onTapSync?.call();
          }
        },
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: kMenudeoPanelGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: tokens.primaryStrong),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: tokens.primaryStrong,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaxonomyBackground extends StatelessWidget {
  const _TaxonomyBackground();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.surfaceTint,
                const Color(0xFFE5F0FF),
                tokens.accent.withValues(alpha: 0.26),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}

class _TaxonomySidePanel extends StatelessWidget {
  final ValueChanged<String> onNavigate;

  const _TaxonomySidePanel({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ContractGlassCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Menudeo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ACCESOS',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              _TaxonomyNavItem(
                icon: Icons.tune_rounded,
                title: 'Catálogo efectivo',
                subtitle: 'Conceptos y parámetros',
                highlighted: true,
              ),
              const SizedBox(height: 8),
              _TaxonomyNavItem(
                icon: Icons.space_dashboard_rounded,
                title: 'Dashboard Menudeo',
                subtitle: 'Vista general del área',
                onTapSync: () => onNavigate('Dashboard Menudeo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaxonomyNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlighted;
  final VoidCallback? onTapSync;

  const _TaxonomyNavItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.highlighted = false,
    this.onTapSync,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTapSync,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: highlighted ? kMenudeoPanelGradient : null,
            color: highlighted ? null : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: tokens.border.withValues(alpha: 0.48)),
          ),
          child: Row(
            children: [
              Icon(icon, color: tokens.primaryStrong),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: tokens.primaryStrong,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
