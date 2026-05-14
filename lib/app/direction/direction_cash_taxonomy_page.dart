import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dashboard/general_dashboard_page.dart';
import 'direction_cash_entries_exits_page.dart';
import 'direction_menudeo_analysis_page.dart';
import 'direction_theme.dart';
import '../shared/app_shell.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'direction_cash_taxonomy_store.dart';

class DirectionCashTaxonomyPage extends StatefulWidget {
  final bool instantOpen;

  const DirectionCashTaxonomyPage({super.key, this.instantOpen = false});

  @override
  State<DirectionCashTaxonomyPage> createState() =>
      _DirectionCashTaxonomyPageState();
}

class _DirectionCashTaxonomyPageState extends State<DirectionCashTaxonomyPage> {
  bool _menuOpen = false;
  DirectionCashMovementType _movementType = DirectionCashMovementType.entry;
  String? _selectedRubric;
  String? _selectedConceptId;
  late final TextEditingController _entryPersonC;
  late final TextEditingController _exitPersonC;

  @override
  void initState() {
    super.initState();
    _entryPersonC = TextEditingController();
    _exitPersonC = TextEditingController();
    DirectionCashTaxonomyStore.instance.addListener(_handleStoreChange);
    _syncInitialSelection();
  }

  @override
  void dispose() {
    _entryPersonC.dispose();
    _exitPersonC.dispose();
    DirectionCashTaxonomyStore.instance.removeListener(_handleStoreChange);
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

  List<DirectionCashRubricDefinition> get _rubricsForCurrentType =>
      DirectionCashTaxonomyStore.instance.rubricsFor(_movementType);

  List<DirectionCashConceptDefinition> get _conceptsForCurrentRubric {
    final rubric = _rubricsForCurrentType.where(
      (item) => item.label == _selectedRubric,
    );
    if (rubric.isEmpty) return const <DirectionCashConceptDefinition>[];
    return rubric.first.concepts;
  }

  DirectionCashConceptDefinition? get _selectedConcept {
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
        page: const GeneralDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Dirección':
        unawaited(_openDashboard());
        return;
      case 'Análisis Menudeo':
        unawaited(_openMenudeoAnalysisPage());
        return;
      case 'Catálogo Bóveda':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      case 'Bóveda':
        unawaited(_openEntriesExitsPage());
        return;
      default:
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
    }
  }

  Future<void> _openEntriesExitsPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const DirectionCashEntriesExitsPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openMenudeoAnalysisPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const DirectionMenudeoAnalysisPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _addConcept() async {
    final created = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const _NewConceptDialog(),
    );
    final label = (created ?? '').trim();
    if (label.isEmpty || _selectedRubric == null) return;
    final concept = DirectionCashConceptDefinition(
      id: DirectionCashTaxonomyStore.instance.nextConceptId(),
      label: label,
    );
    DirectionCashTaxonomyStore.instance.upsertConcept(
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
    DirectionCashTaxonomyStore.instance.deleteConcept(
      movementType: _movementType,
      rubricLabel: rubric,
      conceptId: concept.id,
    );
  }

  void _saveConcept(DirectionCashConceptDefinition concept) {
    final rubric = _selectedRubric;
    if (rubric == null) return;
    DirectionCashTaxonomyStore.instance.upsertConcept(
      movementType: _movementType,
      rubricLabel: rubric,
      concept: concept,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = directionAreaTokens;
    return AreaThemeScope(
      tokens: directionAreaTokens,
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
          background: const DirectionExecutiveBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => DirectionHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, contentAnim) => DirectionHeaderBrand(
            contentAnim: contentAnim,
            title: 'Catálogo Bóveda',
          ),
          trailingBuilder: (_, _) => DirectionHeaderButton(
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
                          DirectionMetricCard(
                            icon: Icons.schema_rounded,
                            title: 'RUBROS',
                            value: '${_rubricsForCurrentType.length}',
                            detail:
                                _movementType == DirectionCashMovementType.entry
                                ? 'Configuración de entradas'
                                : 'Configuración de salidas',
                            accent: tokens.primary,
                          ),
                          DirectionMetricCard(
                            icon: Icons.account_tree_rounded,
                            title: 'CONCEPTOS',
                            value: '${_conceptsForCurrentRubric.length}',
                            detail: _selectedRubric ?? 'Sin rubro activo',
                            accent: tokens.accent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DirectionGlassPanel(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        borderRadius: BorderRadius.circular(24),
                        blurSigma: 28,
                        fillColor: const Color(
                          0xFF173A78,
                        ).withValues(alpha: 0.24),
                        borderColor: Colors.white.withValues(alpha: 0.24),
                        shadowColor: Colors.black.withValues(alpha: 0.10),
                        edgeHighlightColor: Colors.white.withValues(
                          alpha: 0.62,
                        ),
                        bevelShadowColor: Colors.black.withValues(alpha: 0.18),
                        glowColor: const Color(
                          0xFF66D5FF,
                        ).withValues(alpha: 0.08),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SegmentedButton<DirectionCashMovementType>(
                              segments: const [
                                ButtonSegment(
                                  value: DirectionCashMovementType.entry,
                                  label: Text('Entradas'),
                                ),
                                ButtonSegment(
                                  value: DirectionCashMovementType.exit,
                                  label: Text('Salidas'),
                                ),
                              ],
                              selected: <DirectionCashMovementType>{
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
                                    selectedColor: const Color(
                                      0xFF22477F,
                                    ).withValues(alpha: 0.92),
                                    backgroundColor: const Color(
                                      0xFF14305E,
                                    ).withValues(alpha: 0.52),
                                    checkmarkColor: kDirectionSurfaceText,
                                    labelStyle: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: _selectedRubric == rubric.label
                                          ? kDirectionSurfaceText
                                          : kDirectionMutedText,
                                    ),
                                    side: BorderSide(
                                      color: _selectedRubric == rubric.label
                                          ? const Color(
                                              0xFF7ED7FF,
                                            ).withValues(alpha: 0.40)
                                          : Colors.white.withValues(
                                              alpha: 0.16,
                                            ),
                                    ),
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
                      DirectionGlassPanel(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        borderRadius: BorderRadius.circular(24),
                        blurSigma: 28,
                        fillColor: const Color(
                          0xFF173A78,
                        ).withValues(alpha: 0.24),
                        borderColor: Colors.white.withValues(alpha: 0.24),
                        shadowColor: Colors.black.withValues(alpha: 0.10),
                        edgeHighlightColor: Colors.white.withValues(
                          alpha: 0.62,
                        ),
                        bevelShadowColor: Colors.black.withValues(alpha: 0.18),
                        glowColor: const Color(
                          0xFF66D5FF,
                        ).withValues(alpha: 0.08),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _PeopleCatalogCard(
                                title: 'Recibido de',
                                people: DirectionCashTaxonomyStore.instance
                                    .peopleFor(DirectionCashMovementType.entry),
                                controller: _entryPersonC,
                                onAdd: (value) => DirectionCashTaxonomyStore
                                    .instance
                                    .addPersonOption(
                                      movementType:
                                          DirectionCashMovementType.entry,
                                      label: value,
                                    ),
                                onDelete: (value) => DirectionCashTaxonomyStore
                                    .instance
                                    .deletePersonOption(
                                      movementType:
                                          DirectionCashMovementType.entry,
                                      label: value,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _PeopleCatalogCard(
                                title: 'Entregado a',
                                people: DirectionCashTaxonomyStore.instance
                                    .peopleFor(DirectionCashMovementType.exit),
                                controller: _exitPersonC,
                                onAdd: (value) => DirectionCashTaxonomyStore
                                    .instance
                                    .addPersonOption(
                                      movementType:
                                          DirectionCashMovementType.exit,
                                      label: value,
                                    ),
                                onDelete: (value) => DirectionCashTaxonomyStore
                                    .instance
                                    .deletePersonOption(
                                      movementType:
                                          DirectionCashMovementType.exit,
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
                              child: DirectionGlassPanel(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  14,
                                  14,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                blurSigma: 28,
                                fillColor: const Color(
                                  0xFF173A78,
                                ).withValues(alpha: 0.24),
                                borderColor: Colors.white.withValues(
                                  alpha: 0.22,
                                ),
                                shadowColor: Colors.black.withValues(
                                  alpha: 0.10,
                                ),
                                edgeHighlightColor: Colors.white.withValues(
                                  alpha: 0.60,
                                ),
                                bevelShadowColor: Colors.black.withValues(
                                  alpha: 0.18,
                                ),
                                glowColor: const Color(
                                  0xFF66D5FF,
                                ).withValues(alpha: 0.08),
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
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF1E4C8F,
                                            ).withValues(alpha: 0.94),
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor:
                                                const Color(
                                                  0xFF26456F,
                                                ).withValues(alpha: 0.54),
                                            disabledForegroundColor: Colors
                                                .white
                                                .withValues(alpha: 0.45),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            side: BorderSide(
                                              color: Colors.white.withValues(
                                                alpha: 0.16,
                                              ),
                                            ),
                                            elevation: 0,
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
                                                    ? kDirectionSelectionGradient
                                                    : null,
                                                color: selected
                                                    ? null
                                                    : const Color(
                                                        0xFF16376C,
                                                      ).withValues(alpha: 0.30),
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                border: Border.all(
                                                  color: selected
                                                      ? Colors.white.withValues(
                                                          alpha: 0.34,
                                                        )
                                                      : tokens.border
                                                            .withValues(
                                                              alpha: 0.34,
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
                                                      if (concept.requiresPrice)
                                                        concept.priceLabel,
                                                      concept.amountLabel,
                                                    ].join(' · '),
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          kDirectionMutedText,
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
                      child: Container(color: Colors.transparent),
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: DirectionGlassPanel(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        borderRadius: BorderRadius.circular(28),
        blurSigma: 30,
        fillColor: const Color(0xFF10254B).withValues(alpha: 0.72),
        borderColor: Colors.white.withValues(alpha: 0.24),
        shadowColor: Colors.black.withValues(alpha: 0.24),
        edgeHighlightColor: Colors.white.withValues(alpha: 0.68),
        bevelShadowColor: Colors.black.withValues(alpha: 0.18),
        glowColor: const Color(0xFF66D5FF).withValues(alpha: 0.08),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nuevo concepto',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: kDirectionSurfaceText,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              autofocus: true,
              initialValue: _value,
              onChanged: (value) => _value = value,
              onFieldSubmitted: (_) => _submit(),
              style: const TextStyle(
                color: kDirectionSurfaceText,
                fontWeight: FontWeight.w700,
              ),
              decoration: _directionInputDecoration('Nombre del concepto'),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: _directionSecondaryButtonStyle(),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: _directionPrimaryButtonStyle(),
                  onPressed: _submit,
                  child: const Text('Crear'),
                ),
              ],
            ),
          ],
        ),
      ),
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
              _DirectionValueChip(label: item, onDeleted: () => onDelete(item)),
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
              style: _directionPrimaryButtonStyle(),
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
  final DirectionCashConceptDefinition concept;
  final ValueChanged<DirectionCashConceptDefinition> onSave;
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
  late TextEditingController _priceLabelC;
  late TextEditingController _amountLabelC;
  late TextEditingController _companyLabelC;
  late TextEditingController _subconceptLabelC;
  late TextEditingController _commentLabelC;
  late TextEditingController _newSubconceptC;
  late DirectionCashConceptDefinition _draft;

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

  void _bootstrap(DirectionCashConceptDefinition concept) {
    _draft = concept;
    _labelC = TextEditingController(text: concept.label);
    _quantityLabelC = TextEditingController(text: concept.quantityLabel);
    _priceLabelC = TextEditingController(text: concept.priceLabel);
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
    _priceLabelC.dispose();
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
        priceLabel: _priceLabelC.text.trim().isEmpty
            ? 'Precio'
            : _priceLabelC.text.trim(),
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
    return DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      borderRadius: BorderRadius.circular(24),
      blurSigma: 28,
      fillColor: const Color(0xFF173A78).withValues(alpha: 0.24),
      borderColor: Colors.white.withValues(alpha: 0.22),
      shadowColor: Colors.black.withValues(alpha: 0.10),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.60),
      bevelShadowColor: Colors.black.withValues(alpha: 0.18),
      glowColor: const Color(0xFF66D5FF).withValues(alpha: 0.08),
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
                  style: _directionSecondaryButtonStyle(),
                  onPressed: widget.onDelete,
                  child: const Text('Eliminar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: _directionPrimaryButtonStyle(),
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
                  label: 'Peso / cantidad',
                  value: _draft.requiresQuantity,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(requiresQuantity: value),
                  ),
                ),
                _EditorToggleChip(
                  label: 'Precio',
                  value: _draft.requiresPrice,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(requiresPrice: value),
                  ),
                ),
                _EditorToggleChip(
                  label: 'Cliente / empresa',
                  value: _draft.requiresCompany,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(requiresCompany: value),
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
                    label: 'Label precio',
                    controller: _priceLabelC,
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
                  _DirectionValueChip(
                    label: item,
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
                  style: _directionPrimaryButtonStyle(),
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
  final DirectionCashConceptDefinition concept;

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
      if (concept.requiresPrice) concept.priceLabel,
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
            Colors.white.withValues(alpha: 0.08),
            const Color(0xFF183766).withValues(alpha: 0.86),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
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
          Text(
            'Asi se armara el renglon al capturar este concepto.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: kDirectionMutedText,
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
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0x1FFFFFFF),
                        Color(0x332A4F89),
                        Color(0x55112952),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Text(
                    field,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: kDirectionSurfaceText,
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
                  _DirectionValueChip(label: item),
                if (concept.subconcepts.length > 6)
                  _DirectionValueChip(
                    label: '+${concept.subconcepts.length - 6} mas',
                  ),
              ],
            ),
          ],
          if (concept.requiresSubconcept && concept.subconceptIsText) ...[
            const SizedBox(height: 12),
            Text(
              '${concept.subconceptLabel} se capturara como texto libre.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: tokens.badgeText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

ButtonStyle _directionPrimaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF1F4D8F).withValues(alpha: 0.96),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
    elevation: 0,
  );
}

ButtonStyle _directionSecondaryButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: kDirectionSurfaceText,
    backgroundColor: const Color(0xFF15305D).withValues(alpha: 0.48),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

InputDecoration _directionInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: kDirectionSubtleText,
      fontWeight: FontWeight.w700,
    ),
    filled: true,
    fillColor: const Color(0xFF153262).withValues(alpha: 0.42),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: directionAreaTokens.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: directionAreaTokens.border.withValues(alpha: 0.48),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: directionAreaTokens.primary.withValues(alpha: 0.72),
      ),
    ),
  );
}

class _DirectionValueChip extends StatelessWidget {
  final String label;
  final VoidCallback? onDeleted;

  const _DirectionValueChip({required this.label, this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          color: kDirectionSurfaceText,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: const Color(0xFF16376C).withValues(alpha: 0.56),
      deleteIconColor: kDirectionMutedText,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      onDeleted: onDeleted,
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
      style: const TextStyle(
        color: kDirectionSurfaceText,
        fontWeight: FontWeight.w700,
      ),
      decoration: _directionInputDecoration(label),
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
      label: Text(
        label,
        style: TextStyle(
          color: value ? kDirectionSurfaceText : kDirectionMutedText,
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: value,
      selectedColor: const Color(0xFF22477F).withValues(alpha: 0.92),
      backgroundColor: const Color(0xFF14305E).withValues(alpha: 0.52),
      checkmarkColor: kDirectionSurfaceText,
      side: BorderSide(
        color: value
            ? const Color(0xFF7ED7FF).withValues(alpha: 0.40)
            : Colors.white.withValues(alpha: 0.16),
      ),
      onSelected: onChanged,
    );
  }
}

class _EmptyEditorState extends StatelessWidget {
  const _EmptyEditorState();

  @override
  Widget build(BuildContext context) {
    return DirectionGlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(24),
      blurSigma: 28,
      fillColor: const Color(0xFF173A78).withValues(alpha: 0.24),
      borderColor: Colors.white.withValues(alpha: 0.22),
      shadowColor: Colors.black.withValues(alpha: 0.10),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.60),
      bevelShadowColor: Colors.black.withValues(alpha: 0.18),
      glowColor: const Color(0xFF66D5FF).withValues(alpha: 0.08),
      child: const Center(
        child: Text(
          'Selecciona un concepto para editar sus parámetros.',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: kDirectionMutedText,
          ),
        ),
      ),
    );
  }
}

class _TaxonomySidePanel extends StatelessWidget {
  final ValueChanged<String> onNavigate;

  const _TaxonomySidePanel({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return DirectionModuleMenuPanel(
      subtitle: 'Páginas activas del módulo ejecutivo',
      entries: [
        DirectionModuleMenuEntry(
          icon: Icons.space_dashboard_rounded,
          title: 'Dashboard Dirección',
          subtitle: 'Vista general del área',
          onTap: () => onNavigate('Dashboard Dirección'),
        ),
        DirectionModuleMenuEntry(
          icon: Icons.analytics_rounded,
          title: 'Análisis Menudeo',
          subtitle: 'Mercado, efectivo y operación',
          onTap: () => onNavigate('Análisis Menudeo'),
        ),
        DirectionModuleMenuEntry(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Bóveda',
          subtitle: 'Captura operativa de efectivo',
          onTap: () => onNavigate('Bóveda'),
        ),
        const DirectionModuleMenuEntry(
          icon: Icons.tune_rounded,
          title: 'Catálogo Bóveda',
          subtitle: 'Conceptos, personas y parámetros',
          current: true,
        ),
      ],
    );
  }
}
