import 'package:flutter/material.dart';

import '../shared/archetypes/auxiliary_surfaces/date_picker_surface.dart';
import '../shared/archetypes/auxiliary_surfaces/searchable_picker.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'gestion_documental_area_chrome.dart';
import 'gestion_documental_catalog.dart';
import 'gestion_documental_widgets.dart';

class GestionDocumentalCalendarPage extends StatelessWidget {
  final Route<dynamic> dashboardRoute;
  const GestionDocumentalCalendarPage({
    super.key,
    required this.dashboardRoute,
  });

  @override
  Widget build(BuildContext context) => GestionDocumentalAreaShell(
    current: 'calendario',
    dashboardRoute: dashboardRoute,
    workspaceBuilder: (context, navigate) =>
        _CalendarWorkspace(onBack: () => navigate('resumen')),
  );
}

class _CalendarWorkspace extends StatefulWidget {
  final VoidCallback onBack;
  const _CalendarWorkspace({required this.onBack});

  @override
  State<_CalendarWorkspace> createState() => _CalendarWorkspaceState();
}

class _CalendarWorkspaceState extends State<_CalendarWorkspace> {
  late DateTime _selected;
  late DateTime _month;
  String _category = 'todas';

  @override
  void initState() {
    super.initState();
    _select(DateTime.now());
  }

  void _select(DateTime day) {
    _selected = DateUtils.dateOnly(day);
    _month = DateTime(day.year, day.month);
  }

  Future<void> _pickCategory() async {
    final options = [
      const SearchablePickerOption(
        value: 'todas',
        label: 'Todas las categorías',
      ),
      for (final c in documentalCategories)
        SearchablePickerOption(value: c.key, label: c.title),
    ]..sort((a, b) => a.label.compareTo(b.label));
    final value = await showSearchablePickerDialog<String>(
      context,
      title: 'Categoría documental',
      initialValue: _category,
      options: options,
    );
    if (mounted && value != null) setState(() => _category = value);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final value = await showContractDatePickerSurface(
      context,
      initialDate: _selected,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 50, 12, 31),
      title: 'Ir a una fecha',
    );
    if (mounted && value != null) setState(() => _select(value));
  }

  void _changeMonth(int step) {
    setState(() {
      final month = DateTime(_month.year, _month.month + step);
      final lastDay = DateUtils.getDaysInMonth(month.year, month.month);
      _select(
        DateTime(month.year, month.month, _selected.day.clamp(1, lastDay)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    final dates = MaterialLocalizations.of(context);
    final categoryLabel = _category == 'todas'
        ? 'Todas las categorías'
        : documentalCategories.firstWhere((c) => c.key == _category).title;
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
        const DocumentalPageHeading(
          title: 'Calendario',
          description:
              'Vencimientos, renovaciones y obligaciones de todas las categorías.',
          action: DocumentalBadge('Vista inicial'),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _pickCategory,
              style: contractSecondaryButtonStyle(context),
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: Text(categoryLabel),
            ),
            OutlinedButton.icon(
              onPressed: _pickDate,
              style: contractSecondaryButtonStyle(context),
              icon: const Icon(Icons.event_rounded, size: 18),
              label: const Text('Ir a fecha'),
            ),
            OutlinedButton(
              onPressed: () => setState(() => _select(DateTime.now())),
              style: contractSecondaryButtonStyle(context),
              child: const Text('Hoy'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final calendar = ContractGlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Mes anterior',
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          dates.formatMonthYear(_month),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: t.onGlass,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Mes siguiente',
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DocumentalMonthGrid(
                    month: _month,
                    selected: _selected,
                    onSelected: (date) => setState(() => _select(date)),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Selecciona un día para consultar sus obligaciones.',
                      style: TextStyle(
                        color: t.onGlass.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
            final agenda = ContractGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Agenda del día',
                    style: TextStyle(
                      color: t.onGlass,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dates.formatFullDate(_selected),
                    style: TextStyle(
                      color: t.primarySoft,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DocumentalBadge(categoryLabel),
                  const DocumentalEmptyState(
                    title: 'Obligaciones por incorporar',
                    description:
                        'Las fechas aparecerán aquí al integrar los registros documentales.',
                    icon: Icons.event_note_rounded,
                  ),
                ],
              ),
            );
            if (constraints.maxWidth < 950) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [calendar, const SizedBox(height: 16), agenda],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: calendar),
                const SizedBox(width: 16),
                Expanded(child: agenda),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DocumentalMonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  const _DocumentalMonthGrid({
    required this.month,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final firstOffset = month.weekday - 1;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final cells = ((firstOffset + days) / 7).ceil() * 7;
    return Column(
      children: [
        Row(
          children: [
            for (final label in const [
              'Lun',
              'Mar',
              'Mié',
              'Jue',
              'Vie',
              'Sáb',
              'Dom',
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: t.primarySoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: constraints.maxWidth < 400 ? 42 : 68,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              final day = index - firstOffset + 1;
              if (day < 1 || day > days) return const SizedBox.shrink();
              final date = DateTime(month.year, month.month, day);
              final isSelected = DateUtils.isSameDay(date, selected);
              final isToday = DateUtils.isSameDay(date, today);
              return Semantics(
                selected: isSelected,
                label: MaterialLocalizations.of(context).formatFullDate(date),
                child: OutlinedButton(
                  onPressed: () => onSelected(date),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: isSelected ? t.fieldSurface : t.onGlass,
                    backgroundColor: isSelected
                        ? t.primary
                        : t.fieldSurface.withValues(alpha: 0.6),
                    side: BorderSide(
                      color: isToday || isSelected
                          ? t.primary
                          : t.border.withValues(alpha: 0.16),
                      width: isToday ? 1.5 : 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isToday || isSelected
                          ? FontWeight.w900
                          : FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
