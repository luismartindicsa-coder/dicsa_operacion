part of '../human_resources_documentation_page.dart';

/// Compact catalog using the RH dashboard's dark glass and navigation lift.
class _HrDocumentLibrary extends StatelessWidget {
  final List<HrDocument> records;
  final TextEditingController search;
  final ScrollController scrollController;
  final String? group;
  final VoidCallback onSearchChanged;
  final ValueChanged<String?> onGroupChanged;
  final ValueChanged<HrDocumentCategory> onOpen;

  const _HrDocumentLibrary({
    required this.records,
    required this.search,
    required this.scrollController,
    required this.group,
    required this.onSearchChanged,
    required this.onGroupChanged,
    required this.onOpen,
  });

  void _clearFilters() {
    search.clear();
    onGroupChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final query = _hrDocSearchText(search.text.trim());
    final groups =
        HrDocumentCategory.values.map((c) => c.group).toSet().toList()..sort();
    final categories = HrDocumentCategory.values.where((category) {
      return (group == null || category.group == group) &&
          _hrDocSearchText(
            '${category.label} ${category.group}',
          ).contains(query);
    }).toList()..sort((a, b) => a.label.compareTo(b.label));
    final active = records.where((r) => !r.archived).toList();
    final documents = active.where((r) => r.kind != 'template').length;
    final templates = active.length - documents;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 4
            : constraints.maxWidth >= 880
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Documentación RH', style: _hrDocText(28, strong: true)),
            const SizedBox(height: 6),
            Text(
              'Archivos, plantillas y formatos en un solo lugar.',
              style: _hrDocText(
                14,
              ).copyWith(color: tokens.onGlass.withValues(alpha: .72)),
            ),
          ],
        );
        final summary = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _summary(Icons.description_outlined, documents, 'documento'),
            _summary(Icons.copy_all_outlined, templates, 'plantilla'),
          ],
        );
        // Allow text scaling without clipping card titles or their counts.
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final cardHeight = 152.0 + (textScale > 1 ? (textScale - 1) * 110 : 0);

        return Scrollbar(
          controller: scrollController,
          child: CustomScrollView(
            key: const PageStorageKey('hr-document-library'),
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 22),
                  child: constraints.maxWidth >= 850 && textScale <= 1.2
                      ? Row(
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: 20),
                            summary,
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            title,
                            const SizedBox(height: 16),
                            summary,
                          ],
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: ContractGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const ValueKey('document-library-search'),
                        controller: search,
                        style: _hrDocText(14),
                        onChanged: (_) => onSearchChanged(),
                        decoration:
                            contractGlassFieldDecoration(
                              context,
                              hintText: 'Buscar tipo de documento…',
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: tokens.accent,
                              ),
                            ).copyWith(
                              suffixIcon: search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Limpiar búsqueda',
                                      color: tokens.accent,
                                      onPressed: () {
                                        search.clear();
                                        onSearchChanged();
                                      },
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 20,
                                      ),
                                    ),
                            ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final value in <String?>[null, ...groups])
                            ChoiceChip(
                              key: ValueKey('document-group-${value ?? 'all'}'),
                              label: Text(value ?? 'Todos'),
                              selected: group == value,
                              onSelected: (_) => onGroupChanged(value),
                              showCheckmark: false,
                              selectedColor: tokens.accent,
                              backgroundColor: tokens.fieldSurface,
                              side: BorderSide(
                                color: group == value
                                    ? tokens.accent
                                    : tokens.border.withValues(alpha: .24),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              labelStyle: _hrDocText(13, strong: true).copyWith(
                                color: group == value
                                    ? tokens.primaryStrong
                                    : tokens.onGlass.withValues(alpha: .8),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 20, 2, 12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        group ?? 'Todos los documentos',
                        style: _hrDocText(16, strong: true),
                      ),
                      Text(
                        '${categories.length} ${categories.length == 1 ? 'tipo disponible' : 'tipos disponibles'}',
                        style: _hrDocText(12, muted: true),
                      ),
                    ],
                  ),
                ),
              ),
              if (categories.isEmpty)
                SliverToBoxAdapter(
                  child: ContractGlassCard(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          color: tokens.accent,
                          size: 36,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No encontramos ese tipo de documento',
                          textAlign: TextAlign.center,
                          style: _hrDocText(18, strong: true),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Prueba con otro nombre o selecciona otro grupo.',
                          textAlign: TextAlign.center,
                          style: _hrDocText(14, muted: true),
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          style: contractSecondaryButtonStyle(context),
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: const Text('Limpiar filtros'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  sliver: SliverGrid.builder(
                    itemCount: categories.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      mainAxisExtent: cardHeight,
                    ),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final contents = active.where(
                        (r) => r.category == category,
                      );
                      return _HrDocumentCategoryCard(
                        key: ValueKey('document-card-${category.name}'),
                        category: category,
                        documents: contents
                            .where((r) => r.kind != 'template')
                            .length,
                        templates: contents
                            .where((r) => r.kind == 'template')
                            .length,
                        onTap: () => onOpen(category),
                      );
                    },
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 18, 2, 18),
                  child: Text(
                    'Selecciona un tipo para llenar un documento, cargar un archivo o administrar plantillas.',
                    style: _hrDocText(
                      12,
                    ).copyWith(color: tokens.onGlass.withValues(alpha: .65)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summary(IconData icon, int count, String noun) => ContractGlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    borderRadius: BorderRadius.circular(18),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: humanResourcesAreaTokens.accent),
        const SizedBox(width: 10),
        Text('$count', style: _hrDocText(20, strong: true)),
        const SizedBox(width: 6),
        Text(
          '$noun${count == 1 ? '' : 's'}',
          style: _hrDocText(12, muted: true),
        ),
      ],
    ),
  );
}

class _HrDocumentCategoryCard extends StatefulWidget {
  final HrDocumentCategory category;
  final int documents, templates;
  final VoidCallback onTap;

  const _HrDocumentCategoryCard({
    super.key,
    required this.category,
    required this.documents,
    required this.templates,
    required this.onTap,
  });

  @override
  State<_HrDocumentCategoryCard> createState() =>
      _HrDocumentCategoryCardState();
}

class _HrDocumentCategoryCardState extends State<_HrDocumentCategoryCard> {
  bool _hovered = false, _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final highlighted = _hovered || _focused;
    final documentLabel = widget.documents == 0
        ? 'Sin documentos'
        : '${widget.documents} ${widget.documents == 1 ? 'documento' : 'documentos'}';
    final templateLabel = widget.templates == 0
        ? ''
        : '${widget.templates} ${widget.templates == 1 ? 'plantilla' : 'plantillas'}';
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      scale: highlighted ? 1.015 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, highlighted ? -2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: tokens.primaryStrong.withValues(
                alpha: highlighted ? .3 : .14,
              ),
              blurRadius: highlighted ? 26 : 18,
              offset: Offset(0, highlighted ? 14 : 10),
            ),
          ],
        ),
        child: ContractGlassCard(
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('category-${widget.category.name}'),
              borderRadius: BorderRadius.circular(24),
              onHover: (value) => setState(() => _hovered = value),
              onFocusChange: (value) => setState(() => _focused = value),
              onTap: widget.onTap,
              hoverColor: tokens.surfaceTint.withValues(alpha: .2),
              focusColor: tokens.surfaceTint.withValues(alpha: .3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: highlighted ? tokens.accent : Colors.transparent,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: tokens.surfaceTint.withValues(alpha: .28),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _hrDocCategoryIcon(widget.category),
                            color: tokens.accent,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.category.group,
                            style: _hrDocText(12, muted: true),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: highlighted ? tokens.onGlass : tokens.accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.category.label,
                          style: _hrDocText(16, strong: true),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      [
                        documentLabel,
                        if (templateLabel.isNotEmpty) templateLabel,
                      ].join(' · '),
                      style: _hrDocText(12).copyWith(
                        color: widget.documents == 0 && widget.templates == 0
                            ? tokens.onGlass.withValues(alpha: .6)
                            : tokens.badgeText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _hrDocSearchText(String value) {
  var result = value.toLowerCase();
  const replacements = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
  };
  for (final entry in replacements.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result;
}
