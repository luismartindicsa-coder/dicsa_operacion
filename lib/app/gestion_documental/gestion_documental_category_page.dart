import 'package:flutter/material.dart';

import '../shared/archetypes/auxiliary_surfaces/date_picker_surface.dart';
import '../shared/archetypes/auxiliary_surfaces/searchable_picker.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'gestion_documental_area_chrome.dart';
import 'gestion_documental_catalog.dart';
import 'gestion_documental_widgets.dart';

/// Initial, empty category surface. Editable records will adopt Entradas/Salidas.
class GestionDocumentalCategoryPage extends StatelessWidget {
  final DocumentalCategory category;
  final Route<dynamic> dashboardRoute;
  const GestionDocumentalCategoryPage({
    super.key,
    required this.category,
    required this.dashboardRoute,
  });

  @override
  Widget build(BuildContext context) => GestionDocumentalAreaShell(
    current: category.key,
    dashboardRoute: dashboardRoute,
    workspaceBuilder: (context, navigate) => _CategoryWorkspace(
      category: category,
      onBack: () => navigate('resumen'),
    ),
  );
}

class _CategoryWorkspace extends StatefulWidget {
  final DocumentalCategory category;
  final VoidCallback onBack;
  const _CategoryWorkspace({required this.category, required this.onBack});

  @override
  State<_CategoryWorkspace> createState() => _CategoryWorkspaceState();
}

class _CategoryWorkspaceState extends State<_CategoryWorkspace> {
  final _search = TextEditingController();
  String _status = 'Todos los estatus';
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickStatus() async {
    final values = [
      'Todos los estatus',
      'Pendiente',
      'En proceso',
      'Completado',
      'Cancelado',
      'No aplica',
    ]..sort();
    final value = await showSearchablePickerDialog<String>(
      context,
      title: 'Estatus del registro',
      initialValue: _status,
      options: [
        for (final item in values)
          SearchablePickerOption(value: item, label: item),
      ],
    );
    if (value != null && mounted) setState(() => _status = value);
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final value = await showContractDateRangePickerSurface(
      context,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 50, 12, 31),
      initialDateRange: _dateRange,
      title: 'Fecha de vencimiento',
    );
    if (value != null && mounted) setState(() => _dateRange = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    final category = widget.category;
    final filtered =
        _search.text.isNotEmpty ||
        _status != 'Todos los estatus' ||
        _dateRange != null;
    final dates = MaterialLocalizations.of(context);
    final rangeLabel = _dateRange == null
        ? 'Vencimiento'
        : '${dates.formatShortDate(_dateRange!.start)} – ${dates.formatShortDate(_dateRange!.end)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            style: TextButton.styleFrom(foregroundColor: t.primary),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Gestión Documental · Resumen'),
          ),
        ),
        const SizedBox(height: 8),
        DocumentalPageHeading(
          title: category.title,
          description: category.description,
          action: const DocumentalBadge('Vista inicial'),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in category.documentTypes) DocumentalBadge(type),
          ],
        ),
        const SizedBox(height: 20),
        ContractGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth < 600
                          ? constraints.maxWidth
                          : 260,
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText:
                              'Buscar en ${category.title.toLowerCase()}…',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickStatus,
                      style: contractSecondaryButtonStyle(context),
                      icon: const Icon(Icons.filter_list_rounded, size: 18),
                      label: Text(_status),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickDates,
                      style: contractSecondaryButtonStyle(context),
                      icon: const Icon(Icons.date_range_rounded, size: 18),
                      label: Text(rangeLabel),
                    ),
                    if (filtered)
                      TextButton(
                        onPressed: () => setState(() {
                          _search.clear();
                          _status = 'Todos los estatus';
                          _dateRange = null;
                        }),
                        style: TextButton.styleFrom(foregroundColor: t.primary),
                        child: const Text('Limpiar'),
                      ),
                    Tooltip(
                      message:
                          'La captura se habilitará en la siguiente etapa de esta categoría.',
                      child: ElevatedButton.icon(
                        onPressed: null,
                        style: contractPrimaryButtonStyle(context),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Nuevo'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Header only: no alternate editable-grid interaction is introduced.
              LayoutBuilder(
                builder: (context, constraints) {
                  final minWidth = 248.0 + (category.columns.length - 1) * 112;
                  final width = constraints.maxWidth < minWidth
                      ? minWidth
                      : constraints.maxWidth;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: t.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            for (var i = 0; i < category.columns.length; i++)
                              Expanded(
                                flex: i == 0 ? 2 : 1,
                                child: Text(
                                  category.columns[i],
                                  style: TextStyle(
                                    color: t.primarySoft,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              DocumentalEmptyState(
                icon: category.icon,
                title: 'Expediente por integrar',
                description:
                    'Esta categoría está en su vista inicial. La captura, los archivos y el seguimiento se habilitarán en la próxima etapa.',
              ),
              if (category.key == 'documentacion-legal')
                const Align(
                  alignment: Alignment.centerLeft,
                  child: DocumentalBadge(
                    'Admite documentos sin vencimiento',
                    icon: Icons.all_inclusive_rounded,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
