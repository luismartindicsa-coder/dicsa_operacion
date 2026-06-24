import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/archetypes/grid_editable/grid_editable_shell.dart';
import '../shared/archetypes/grid_editable/grid_keyboard_shell.dart';
import '../shared/archetypes/grid_editable/grid_navigation_controller.dart';
import '../shared/archetypes/grid_editable/grid_selection_controller.dart';
import '../shared/archetypes/grid_editable/row/editable_row_actions_button.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/contract_menu_surface.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import 'human_resources_area_chrome.dart';
import 'human_resources_dashboard_page.dart';
import 'human_resources_mock_page.dart';
import 'human_resources_theme.dart';

const double _kHrActionsW = 82;
const double _kHrPersonnelIdW = 88;
const double _kHrPersonnelNameW = 270;
const double _kHrPersonnelCompanyW = 180;
const double _kHrPersonnelScheduleW = 150;
const double _kHrPersonnelNssW = 160;
const double _kHrPersonnelRfcW = 160;
const double _kHrPersonnelCurpW = 220;
const double _kHrPersonnelIngresoW = 150;
const double _kHrPersonnelPhoneW = 150;
const double _kHrPersonnelAccountW = 190;
const double _kHrPersonnelShoeW = 110;

const double _kHrPersonnelContentW =
    _kHrActionsW +
    _kHrPersonnelIdW +
    _kHrPersonnelNameW +
    _kHrPersonnelCompanyW +
    _kHrPersonnelScheduleW +
    _kHrPersonnelNssW +
    _kHrPersonnelRfcW +
    _kHrPersonnelCurpW +
    _kHrPersonnelIngresoW +
    _kHrPersonnelPhoneW +
    _kHrPersonnelAccountW +
    _kHrPersonnelShoeW;

class HumanResourcesPersonnelPage extends StatefulWidget {
  final bool instantOpen;

  const HumanResourcesPersonnelPage({super.key, this.instantOpen = false});

  @override
  State<HumanResourcesPersonnelPage> createState() =>
      _HumanResourcesPersonnelPageState();
}

enum _PersonnelRowAction { open, export }

class _HumanResourcesPersonnelPageState
    extends State<HumanResourcesPersonnelPage> {
  bool _menuOpen = false;
  bool _canReturnToDirection = false;
  bool _exportingCsv = false;
  String? _hoveredRowId;
  final TextEditingController _searchController = TextEditingController();
  final GridNavigationController _navigationController =
      GridNavigationController();
  final GridSelectionController _selectionController =
      GridSelectionController();
  List<_HumanResourcesEmployeeRow> _visibleRows =
      _HumanResourcesEmployeeRow.seed;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _navigationController.addListener(_handleGridStateChanged);
    _selectionController.addListener(_handleGridStateChanged);
    _configureGrid();
    unawaited(_resolveNavigationAccess());
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_applyFilters)
      ..dispose();
    _navigationController
      ..removeListener(_handleGridStateChanged)
      ..dispose();
    _selectionController
      ..removeListener(_handleGridStateChanged)
      ..dispose();
    super.dispose();
  }

  void _handleGridStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.canAccessGeneralDashboard(profile);
    });
  }

  void _configureGrid() {
    _navigationController.configure(
      insertColumnCount: 0,
      gridColumnCount: 12,
      rowCount: _visibleRows.length,
    );
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toUpperCase();
    final nextRows = _HumanResourcesEmployeeRow.seed
        .where((row) {
          if (query.isEmpty) return true;
          return row.id.contains(query) ||
              row.nombre.contains(query) ||
              row.empresa.contains(query) ||
              row.horario.contains(query) ||
              row.nss.contains(query) ||
              row.rfc.contains(query) ||
              row.curp.contains(query);
        })
        .toList(growable: false);

    final visibleIds = nextRows.map((row) => row.id).toSet();
    if (_selectionController.selectedIds.isNotEmpty &&
        !_selectionController.selectedIds.every(visibleIds.contains)) {
      _selectionController.clear();
    }

    setState(() {
      _visibleRows = nextRows;
      _hoveredRowId = visibleIds.contains(_hoveredRowId) ? _hoveredRowId : null;
    });
    _configureGrid();
  }

  Future<void> _logout() => signOutAndRouteToLogin(context);

  Future<void> _openDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openMockVisual() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const HumanResourcesMockPage()));
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _exportCsv() async {
    if (_exportingCsv) return;
    setState(() => _exportingCsv = true);
    final buffer = StringBuffer()
      ..writeln(
        [
          'ID',
          'Nombre',
          'Empresa',
          'Horario',
          'NSS',
          'RFC',
          'CURP',
          'Fecha de ingreso',
          'Telefono',
          'No. de Cuenta',
          'Calzado',
        ].map(_csvCell).join(','),
      );
    for (final row in _visibleRows) {
      buffer.writeln(
        [
          row.id,
          row.nombre,
          row.empresa,
          row.horario,
          row.nss,
          row.rfc,
          row.curp,
          row.fechaIngreso,
          row.telefono,
          row.numeroCuenta,
          row.calzado,
        ].map(_csvCell).join(','),
      );
    }

    try {
      final output = await saveCsvFile(
        fileName: 'rh_personal.csv',
        content: buffer.toString(),
        dialogTitle: 'Guardar personal RH',
      );
      if (!mounted || output == null) return;
      _showSnack('CSV exportado: $output');
    } finally {
      if (mounted) {
        setState(() => _exportingCsv = false);
      }
    }
  }

  void _handleEscape() {
    if (_menuOpen) {
      setState(() => _menuOpen = false);
      return;
    }
    if (_selectionController.selectedIds.isNotEmpty) {
      _selectionController.clear();
      return;
    }
    if (_visibleRows.isNotEmpty) {
      _navigationController.focusGridCell(rowIndex: 0, columnIndex: 1);
    }
  }

  void _handleDeleteSelection() {
    if (_selectionController.selectedIds.isEmpty) return;
    _showSnack(
      'La selección se limpió. La eliminación real se conectará aquí.',
    );
    _selectionController.clear();
  }

  void _openActiveRecord() {
    if (_visibleRows.isEmpty) return;
    final index = _navigationController.active.rowIndex;
    if (index < 0 || index >= _visibleRows.length) return;
    _handleRowAction(_PersonnelRowAction.open, _visibleRows[index]);
  }

  Future<void> _handleRowAction(
    _PersonnelRowAction action,
    _HumanResourcesEmployeeRow row,
  ) async {
    switch (action) {
      case _PersonnelRowAction.open:
        _showSnack('Expediente listo para abrir: ${row.nombre}');
        return;
      case _PersonnelRowAction.export:
        _showSnack('La exportación individual se conectará para ${row.id}.');
        return;
    }
  }

  Future<void> _openRowMenu(
    TapDownDetails details,
    _HumanResourcesEmployeeRow row,
    int rowIndex,
  ) async {
    _selectionController.selectSingle(row.id, rowIndex: rowIndex);
    _navigationController.focusGridCell(rowIndex: rowIndex, columnIndex: 1);
    final selected = await showContractContextMenu<_PersonnelRowAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      entries: const [
        ContractMenuEntry(
          value: _PersonnelRowAction.open,
          label: 'Abrir expediente',
          icon: Icons.open_in_new_rounded,
        ),
        ContractMenuEntry(
          value: _PersonnelRowAction.export,
          label: 'Exportar fila',
          icon: Icons.download_rounded,
        ),
      ],
    );
    if (selected != null && mounted) {
      await _handleRowAction(selected, row);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: humanResourcesAreaTokens,
      child: AppShell(
        background: const HumanResourcesAreaBackground(),
        wrapBodyInGlass: false,
        animateHeaderSlots: false,
        animateBody: !widget.instantOpen,
        headerBodySpacing: 8,
        padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
        leadingBuilder: (_, _) => HumanResourcesAreaHeaderButton(
          label: _menuOpen ? 'Cerrar panel' : 'Navegación',
          icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
          onTapSync: () => setState(() => _menuOpen = !_menuOpen),
        ),
        centerBuilder: (_, _) => const _HumanResourcesPersonnelBrand(),
        trailingBuilder: (_, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HumanResourcesAreaHeaderButton(
              label: 'Recargar',
              icon: Icons.refresh_rounded,
              compact: true,
              onTapSync: _applyFilters,
            ),
            const SizedBox(width: 10),
            HumanResourcesAreaHeaderButton(
              label: 'Cerrar sesión',
              icon: Icons.logout_rounded,
              onTap: _logout,
            ),
          ],
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1540),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(56, 4, 8, 0),
                  child: GridKeyboardShell(
                    navigationController: _navigationController,
                    onEscape: _handleEscape,
                    onDelete: _handleDeleteSelection,
                    onConfirm: _openActiveRecord,
                    onOpenActiveCell: _openActiveRecord,
                    child: _HumanResourcesPersonnelWorkspace(
                      searchController: _searchController,
                      rows: _visibleRows,
                      selectedCount: _selectionController.selectedIds.length,
                      activeColumnIndex:
                          _navigationController.active.columnIndex,
                      exportingCsv: _exportingCsv,
                      hoveredRowId: _hoveredRowId,
                      navigationController: _navigationController,
                      selectionController: _selectionController,
                      onExportCsv: _exportCsv,
                      onHoverRowChanged: (value) {
                        if (_hoveredRowId == value) return;
                        setState(() => _hoveredRowId = value);
                      },
                      onRowAction: _handleRowAction,
                      onRowContextMenu: _openRowMenu,
                    ),
                  ),
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
                    behavior: HitTestBehavior.opaque,
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
                child: HumanResourcesAreaSidePanel(
                  label: 'Recursos Humanos',
                  canReturnToDirection: _canReturnToDirection,
                  areaItems: [
                    HumanResourcesAreaNavEntry(
                      icon: Icons.space_dashboard_rounded,
                      title: 'Dashboard RH',
                      subtitle: 'Resumen y contexto del área',
                      onTap: _openDashboard,
                    ),
                    const HumanResourcesAreaNavEntry(
                      icon: Icons.badge_outlined,
                      title: 'Personal',
                      subtitle: 'Grid homologado de expediente base',
                      accented: true,
                    ),
                    HumanResourcesAreaNavEntry(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Mock visual RH',
                      subtitle: 'Referencia cromática actual',
                      onTap: _openMockVisual,
                    ),
                  ],
                  accessItems: [
                    if (_canReturnToDirection)
                      HumanResourcesAreaNavEntry(
                        icon: Icons.assessment_outlined,
                        title: 'Dashboard Dirección',
                        subtitle: 'Vista ejecutiva multiarea',
                        onTap: _openDirectionDashboard,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HumanResourcesPersonnelWorkspace extends StatelessWidget {
  final TextEditingController searchController;
  final List<_HumanResourcesEmployeeRow> rows;
  final int selectedCount;
  final int activeColumnIndex;
  final bool exportingCsv;
  final String? hoveredRowId;
  final GridNavigationController navigationController;
  final GridSelectionController selectionController;
  final Future<void> Function() onExportCsv;
  final ValueChanged<String?> onHoverRowChanged;
  final Future<void> Function(
    _PersonnelRowAction action,
    _HumanResourcesEmployeeRow row,
  )
  onRowAction;
  final Future<void> Function(
    TapDownDetails details,
    _HumanResourcesEmployeeRow row,
    int rowIndex,
  )
  onRowContextMenu;

  const _HumanResourcesPersonnelWorkspace({
    required this.searchController,
    required this.rows,
    required this.selectedCount,
    required this.activeColumnIndex,
    required this.exportingCsv,
    required this.hoveredRowId,
    required this.navigationController,
    required this.selectionController,
    required this.onExportCsv,
    required this.onHoverRowChanged,
    required this.onRowAction,
    required this.onRowContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    final safeColumnIndex = activeColumnIndex.clamp(
      0,
      _kGridColumns.length - 1,
    );
    final activeColumnLabel = _kGridColumns[safeColumnIndex].label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContractGlassCard(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final actions = Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    style: contractPrimaryButtonStyle(context),
                    onPressed: exporttingDisabled(exportingCsv)
                        ? null
                        : onExportCsv,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      exportingCsv ? 'Exportando...' : 'Descargar CSV',
                    ),
                  ),
                  OutlinedButton.icon(
                    style: contractSecondaryButtonStyle(context),
                    onPressed: () => searchController.clear(),
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    label: const Text('Limpiar filtros'),
                  ),
                ],
              );
              final search = SizedBox(
                width: constraints.maxWidth < 1180 ? double.infinity : 340,
                child: TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: contractGlassFieldDecoration(
                    context,
                    hintText: 'Buscar por ID, nombre, empresa, RFC o CURP',
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              );
              final summary = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: constraints.maxWidth < 1180
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  Text(
                    '${rows.length} registros visibles',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$selectedCount seleccionados · Celda activa: $activeColumnLabel',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.64),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );

              if (constraints.maxWidth < 1180) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    actions,
                    const SizedBox(height: 12),
                    search,
                    const SizedBox(height: 12),
                    summary,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: actions),
                  const SizedBox(width: 12),
                  search,
                  const SizedBox(width: 12),
                  summary,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ContractGlassCard(
            padding: EdgeInsets.zero,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xED201132),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: GridEditableShell(
                topBar: const _HumanResourcesGridModuleHeader(),
                body: _HumanResourcesPersonnelGrid(
                  rows: rows,
                  hoveredRowId: hoveredRowId,
                  navigationController: navigationController,
                  selectionController: selectionController,
                  onHoverRowChanged: onHoverRowChanged,
                  onRowAction: onRowAction,
                  onRowContextMenu: onRowContextMenu,
                ),
                footer: _HumanResourcesGridFooter(
                  rows: rows.length,
                  selectedCount: selectedCount,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool exporttingDisabled(bool exportingCsv) => exportingCsv;
}

class _HumanResourcesGridModuleHeader extends StatelessWidget {
  const _HumanResourcesGridModuleHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final badges = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _HumanResourcesContextBadge(
              icon: Icons.grid_view_rounded,
              label: 'Grid Editable RH',
            ),
            _HumanResourcesContextBadge(
              icon: Icons.keyboard_command_key_rounded,
              label: 'Flechas · Enter · Esc · Delete',
            ),
            _HumanResourcesContextBadge(
              icon: Icons.approval_outlined,
              label: 'Base expediente',
            ),
          ],
        );
        final copy = const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Superficie homologada para expediente operativo, adscripción y validación de identidad laboral.',
              style: TextStyle(
                color: Color(0xC7FFFFFF),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        );

        if (constraints.maxWidth < 1020) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [copy, const SizedBox(height: 12), badges],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: copy),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: badges,
            ),
          ],
        );
      },
    );
  }
}

class _HumanResourcesContextBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HumanResourcesContextBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x99432A65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFC79CFF)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HumanResourcesPersonnelGrid extends StatelessWidget {
  final List<_HumanResourcesEmployeeRow> rows;
  final String? hoveredRowId;
  final GridNavigationController navigationController;
  final GridSelectionController selectionController;
  final ValueChanged<String?> onHoverRowChanged;
  final Future<void> Function(
    _PersonnelRowAction action,
    _HumanResourcesEmployeeRow row,
  )
  onRowAction;
  final Future<void> Function(
    TapDownDetails details,
    _HumanResourcesEmployeeRow row,
    int rowIndex,
  )
  onRowContextMenu;

  const _HumanResourcesPersonnelGrid({
    required this.rows,
    required this.hoveredRowId,
    required this.navigationController,
    required this.selectionController,
    required this.onHoverRowChanged,
    required this.onRowAction,
    required this.onRowContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = math.max(
          _kHrPersonnelContentW,
          constraints.maxWidth,
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xCC1B102C),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  children: [
                    const _HumanResourcesGridHeaderRow(),
                    if (rows.isEmpty)
                      const _HumanResourcesGridEmptyState()
                    else
                      for (var index = 0; index < rows.length; index++)
                        _HumanResourcesGridDataRow(
                          row: rows[index],
                          rowIndex: index,
                          hovered: hoveredRowId == rows[index].id,
                          selected: selectionController.isSelected(
                            rows[index].id,
                          ),
                          activePosition: navigationController.active,
                          onHoverChanged: onHoverRowChanged,
                          onTap: () {
                            selectionController.handlePointerSelection(
                              id: rows[index].id,
                              rowIndex: index,
                              resolveRangeIds: (start, end) => rows
                                  .getRange(start, end + 1)
                                  .map((row) => row.id),
                            );
                            navigationController.focusGridCell(
                              rowIndex: index,
                              columnIndex: 1,
                            );
                          },
                          onSecondaryTapDown: (details) =>
                              onRowContextMenu(details, rows[index], index),
                          onActionSelected: (action) =>
                              onRowAction(action, rows[index]),
                        ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HumanResourcesGridHeaderRow extends StatelessWidget {
  const _HumanResourcesGridHeaderRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF24103D),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          for (final column in _kGridColumns)
            _HumanResourcesHeaderCell(
              width: column.width,
              label: column.label,
              centered: column.centered,
            ),
        ],
      ),
    );
  }
}

class _HumanResourcesGridDataRow extends StatelessWidget {
  final _HumanResourcesEmployeeRow row;
  final int rowIndex;
  final bool hovered;
  final bool selected;
  final GridCellPosition activePosition;
  final ValueChanged<String?> onHoverChanged;
  final VoidCallback onTap;
  final GestureTapDownCallback onSecondaryTapDown;
  final ValueChanged<_PersonnelRowAction> onActionSelected;

  const _HumanResourcesGridDataRow({
    required this.row,
    required this.rowIndex,
    required this.hovered,
    required this.selected,
    required this.activePosition,
    required this.onHoverChanged,
    required this.onTap,
    required this.onSecondaryTapDown,
    required this.onActionSelected,
  });

  bool _isActiveCell(int columnIndex) {
    return activePosition.zone == GridNavigationZone.grid &&
        activePosition.rowIndex == rowIndex &&
        activePosition.columnIndex == columnIndex;
  }

  @override
  Widget build(BuildContext context) {
    final rowColor = selected
        ? const Color(0xFF3A215A)
        : hovered
        ? const Color(0xFF2A183F)
        : const Color(0xFF201231);
    final rowBorder = selected
        ? const Color(0x66B68CFF)
        : Colors.white.withValues(alpha: 0.04);
    return MouseRegion(
      onEnter: (_) => onHoverChanged(row.id),
      onExit: (_) => onHoverChanged(null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onSecondaryTapDown: onSecondaryTapDown,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: rowColor,
            border: Border(bottom: BorderSide(color: rowBorder)),
          ),
          child: Row(
            children: [
              _HumanResourcesActionCell(
                width: _kHrActionsW,
                selected: selected,
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: EditableRowActionsButton<_PersonnelRowAction>(
                    tooltip: 'Acciones de expediente',
                    iconColor: const Color(0xFFC79CFF),
                    entries: const [
                      ContractMenuEntry(
                        value: _PersonnelRowAction.open,
                        label: 'Abrir expediente',
                        icon: Icons.open_in_new_rounded,
                      ),
                      ContractMenuEntry(
                        value: _PersonnelRowAction.export,
                        label: 'Exportar fila',
                        icon: Icons.download_rounded,
                      ),
                    ],
                    onSelected: onActionSelected,
                  ),
                ),
              ),
              _HumanResourcesDataCell(
                width: _kHrPersonnelIdW,
                value: row.id,
                active: _isActiveCell(1),
                centered: true,
              ),
              _HumanResourcesDataCell(
                width: _kHrPersonnelNameW,
                value: row.nombre,
                active: _isActiveCell(2),
              ),
              _HumanResourcesDataCell(
                width: _kHrPersonnelCompanyW,
                value: row.empresa,
                active: _isActiveCell(3),
              ),
              _HumanResourcesDataCell(
                width: _kHrPersonnelScheduleW,
                value: row.horario,
                active: _isActiveCell(4),
                centered: true,
              ),
              _HumanResourcesDataCell(
                width: _kHrPersonnelNssW,
                value: row.nss,
                active: _isActiveCell(5),
              ),
              _HumanResourcesDataCell(
                width: _kHrPersonnelRfcW,
                value: row.rfc,
                active: _isActiveCell(6),
              ),
              _HumanResourcesDataCell(
                width: _kHrPersonnelCurpW,
                value: row.curp,
                active: _isActiveCell(7),
              ),
              _HumanResourcesDataCell(
                width: _kHrPersonnelIngresoW,
                value: row.fechaIngreso,
                active: _isActiveCell(8),
                centered: true,
              ),
              _HumanResourcesDataCell(
                width: _kHrPersonnelPhoneW,
                value: row.telefono,
                active: _isActiveCell(9),
              ),
              _HumanResourcesDataCell(
                width: _kHrPersonnelAccountW,
                value: row.numeroCuenta,
                active: _isActiveCell(10),
              ),
              _HumanResourcesDataCell(
                width: _kHrPersonnelShoeW,
                value: row.calzado,
                active: _isActiveCell(11),
                centered: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HumanResourcesHeaderCell extends StatelessWidget {
  final double width;
  final String label;
  final bool centered;

  const _HumanResourcesHeaderCell({
    required this.width,
    required this.label,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: centered ? 0 : 10),
        child: ContractGridScaledRow(
          alignment: centered ? Alignment.center : Alignment.centerLeft,
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFFF1E7FF),
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.45,
            ),
          ),
        ),
      ),
    );
  }
}

class _HumanResourcesActionCell extends StatelessWidget {
  final double width;
  final bool selected;
  final Widget child;

  const _HumanResourcesActionCell({
    required this.width,
    required this.selected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Center(
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xA5432A65)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _HumanResourcesDataCell extends StatelessWidget {
  final double width;
  final String value;
  final bool active;
  final bool centered;

  const _HumanResourcesDataCell({
    required this.width,
    required this.value,
    required this.active,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF432A65) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? const Color(0xFFB68CFF) : Colors.transparent,
            ),
          ),
          child: Align(
            alignment: centered ? Alignment.center : Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.82),
                fontSize: 13.2,
                fontWeight: active ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HumanResourcesGridEmptyState extends StatelessWidget {
  const _HumanResourcesGridEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: const BoxDecoration(color: Color(0xCC1B102C)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(
          color: const Color(0xCC1D112F),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0x40B68CFF),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.badge_outlined,
              size: 34,
              color: Color(0xFFB68CFF),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sin coincidencias',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajusta el filtro para volver a mostrar el grid base del personal.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HumanResourcesGridFooter extends StatelessWidget {
  final int rows;
  final int selectedCount;

  const _HumanResourcesGridFooter({
    required this.rows,
    required this.selectedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          Text(
            'Mostrando $rows registros',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            '$selectedCount seleccionados',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HumanResourcesPersonnelBrand extends StatelessWidget {
  const _HumanResourcesPersonnelBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: humanResourcesAreaTokens.glow.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Center(child: DicsaLogoD(size: 36, progress: 1)),
        ),
        const SizedBox(width: 14),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Recursos Humanos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Personal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFFCFAEFF),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HumanResourcesGridColumn {
  final String label;
  final double width;
  final bool centered;

  const _HumanResourcesGridColumn({
    required this.label,
    required this.width,
    this.centered = false,
  });
}

const List<_HumanResourcesGridColumn> _kGridColumns =
    <_HumanResourcesGridColumn>[
      _HumanResourcesGridColumn(
        label: 'Acciones',
        width: _kHrActionsW,
        centered: true,
      ),
      _HumanResourcesGridColumn(
        label: 'ID',
        width: _kHrPersonnelIdW,
        centered: true,
      ),
      _HumanResourcesGridColumn(label: 'Nombre', width: _kHrPersonnelNameW),
      _HumanResourcesGridColumn(label: 'Empresa', width: _kHrPersonnelCompanyW),
      _HumanResourcesGridColumn(
        label: 'Horario',
        width: _kHrPersonnelScheduleW,
        centered: true,
      ),
      _HumanResourcesGridColumn(label: 'NSS', width: _kHrPersonnelNssW),
      _HumanResourcesGridColumn(label: 'RFC', width: _kHrPersonnelRfcW),
      _HumanResourcesGridColumn(label: 'CURP', width: _kHrPersonnelCurpW),
      _HumanResourcesGridColumn(
        label: 'Fecha de ingreso',
        width: _kHrPersonnelIngresoW,
        centered: true,
      ),
      _HumanResourcesGridColumn(label: 'Telefono', width: _kHrPersonnelPhoneW),
      _HumanResourcesGridColumn(
        label: 'No. de Cuenta',
        width: _kHrPersonnelAccountW,
      ),
      _HumanResourcesGridColumn(
        label: 'Calzado',
        width: _kHrPersonnelShoeW,
        centered: true,
      ),
    ];

class _HumanResourcesEmployeeRow {
  final String id;
  final String nombre;
  final String empresa;
  final String horario;
  final String nss;
  final String rfc;
  final String curp;
  final String fechaIngreso;
  final String telefono;
  final String numeroCuenta;
  final String calzado;

  const _HumanResourcesEmployeeRow({
    required this.id,
    required this.nombre,
    required this.empresa,
    required this.horario,
    required this.nss,
    required this.rfc,
    required this.curp,
    required this.fechaIngreso,
    required this.telefono,
    required this.numeroCuenta,
    required this.calzado,
  });

  static const List<_HumanResourcesEmployeeRow> seed =
      <_HumanResourcesEmployeeRow>[
        _HumanResourcesEmployeeRow(
          id: '2',
          nombre: 'JOSE LUIS CRUZ CRUZ',
          empresa: 'MONROE',
          horario: 'MATUTINO',
          nss: '12119002637',
          rfc: 'CUCL900819TK7',
          curp: 'CUCL900819HQTRRS01',
          fechaIngreso: '2022-04-10',
          telefono: '4610001201',
          numeroCuenta: '2771768107',
          calzado: '8',
        ),
        _HumanResourcesEmployeeRow(
          id: '8',
          nombre: 'REBECA SOLORZANO GRANADOS',
          empresa: 'DICSA CELAYA',
          horario: 'ADMIN',
          nss: '12836333778',
          rfc: 'SOGR630614B59',
          curp: 'SOGR630614MGTLRB04',
          fechaIngreso: '2015-05-01',
          telefono: '4610003308',
          numeroCuenta: '2703700186',
          calzado: '5',
        ),
        _HumanResourcesEmployeeRow(
          id: '12',
          nombre: 'JUAN RODRIGUEZ ABOYTES',
          empresa: 'DICSA APASEO',
          horario: 'NOCTURNO',
          nss: '12118725071',
          rfc: 'ROAJ870624AY0',
          curp: 'ROAJ870624HGTDBN05',
          fechaIngreso: '2014-02-17',
          telefono: '4610004412',
          numeroCuenta: '2996606083',
          calzado: '9',
        ),
        _HumanResourcesEmployeeRow(
          id: '84',
          nombre: 'JOSE DE JESUS MORALES PEREZ',
          empresa: 'KS',
          horario: 'MIXTO',
          nss: '12078644577',
          rfc: 'MOPJ8612143L3',
          curp: 'MOPJ861214HGTRRS01',
          fechaIngreso: '2018-09-20',
          telefono: '4610005584',
          numeroCuenta: '1565101174',
          calzado: '5',
        ),
        _HumanResourcesEmployeeRow(
          id: '92',
          nombre: 'EMILIO JOSE SANDOVAL MORA',
          empresa: 'MONROE',
          horario: 'MATUTINO',
          nss: '12128205825',
          rfc: 'SAME820512P36',
          curp: 'SAME820512HDFNRM05',
          fechaIngreso: '2013-05-17',
          telefono: '4610007792',
          numeroCuenta: '2960852503',
          calzado: '10',
        ),
        _HumanResourcesEmployeeRow(
          id: '195',
          nombre: 'ANDRES GARCIA DE LA ROSA',
          empresa: 'WHIRLPOOL',
          horario: 'MATUTINO',
          nss: '12159320881',
          rfc: 'GARA9306211P5',
          curp: 'GARA930621HGTLRN02',
          fechaIngreso: '2024-03-11',
          telefono: '4610010195',
          numeroCuenta: '1552467786',
          calzado: '7',
        ),
        _HumanResourcesEmployeeRow(
          id: '223',
          nombre: 'CRUZ ANGEL RAMIREZ CAMPOS',
          empresa: 'DICSA CELAYA',
          horario: 'VESPERTINO',
          nss: '12119450771',
          rfc: 'RACC9408282H8',
          curp: 'RACC940828HGTMMP08',
          fechaIngreso: '2025-01-06',
          telefono: '4610011223',
          numeroCuenta: '1527321812',
          calzado: '8',
        ),
      ];
}

String _csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
