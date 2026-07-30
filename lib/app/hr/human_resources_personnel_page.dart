import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/app_shell.dart';
import '../shared/archetypes/auxiliary_surfaces/confirmation_dialog.dart';
import '../shared/archetypes/auxiliary_surfaces/searchable_picker.dart';
import '../shared/archetypes/grid_editable/grid_editable_shell.dart';
import '../shared/archetypes/grid_editable/filters/grid_filter_dialog.dart';
import '../shared/archetypes/grid_editable/filters/grid_filter_state.dart';
import '../shared/archetypes/grid_editable/grid_keyboard_shell.dart';
import '../shared/archetypes/grid_editable/grid_navigation_controller.dart';
import '../shared/archetypes/grid_editable/grid_scroll_visibility_coordinator.dart';
import '../shared/archetypes/grid_editable/grid_selection_controller.dart';
import '../shared/archetypes/grid_editable/row/editable_row_actions_button.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/dialogs/contract_menu_surface.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'human_resources_attendance_page.dart';
import 'human_resources_attendance_incidents_page.dart';
import 'human_resources_area_chrome.dart';
import 'human_resources_dashboard_page.dart';
import 'human_resources_permissions_page.dart';
import 'human_resources_prenomina_page.dart';
import 'human_resources_theme.dart';
import 'human_resources_vacations_page.dart';

const double _kHrActionsW = 118;
const double _kHrPersonnelIdW = 84;
const double _kHrPersonnelNameW = 420;
const double _kHrPersonnelCompanyW = 260;
const double _kHrPersonnelScheduleW = 190;
const double _kHrPersonnelIngresoW = 210;
const List<String> _kHrEmpresaOptions = <String>[
  'DICSA CELAYA',
  'DICSA APASEO',
  'MONROE',
  'WHIRLPOOL',
  'KS',
];
const List<String> _kHrWeekdayOptions = <String>[
  'Lun',
  'Mar',
  'Mie',
  'Jue',
  'Vie',
  'Sab',
  'Dom',
];
const List<String> _kHrFileExtensions = <String>[
  'pdf',
  'jpg',
  'jpeg',
  'png',
  'webp',
  'heic',
];
const String _kHrEmployeeProfilesTable = 'hr_employee_profiles';
const String _kHrEmployeeDocumentsTable = 'hr_employee_documents';
const String _kHrEmployeeFilesBucket = 'hr_employee_files';
const List<_HrExpedienteRequirementSpec> _kHrExpedienteRequirements =
    <_HrExpedienteRequirementSpec>[
      _HrExpedienteRequirementSpec(
        key: 'solicitud',
        title: 'Solicitud elaborada',
        detail: 'Formato base de ingreso firmado por el colaborador.',
      ),
      _HrExpedienteRequirementSpec(
        key: 'nss_imss',
        title: 'No. de seguridad social (IMSS)',
        detail: 'Comprobante o documento de afiliacion IMSS/NSS.',
      ),
      _HrExpedienteRequirementSpec(
        key: 'antecedentes_penales',
        title: 'Antecedentes penales actualizados',
        detail: 'Constancia vigente del colaborador.',
      ),
      _HrExpedienteRequirementSpec(
        key: 'acta_nacimiento',
        title: 'Acta de nacimiento',
        detail: 'Copia legible del acta.',
      ),
      _HrExpedienteRequirementSpec(
        key: 'curp_doc',
        title: 'CURP',
        detail: 'Copia del CURP para expediente.',
      ),
      _HrExpedienteRequirementSpec(
        key: 'ine',
        title: 'INE',
        detail: 'Copia de identificacion oficial.',
      ),
      _HrExpedienteRequirementSpec(
        key: 'comprobante_domicilio',
        title: 'Comprobante de domicilio',
        detail: 'Documento reciente y legible.',
      ),
      _HrExpedienteRequirementSpec(
        key: 'cartas_recomendacion',
        title: 'Cartas de recomendacion',
        detail: 'Se requieren dos cartas.',
        minimumFiles: 2,
      ),
      _HrExpedienteRequirementSpec(
        key: 'telefono_contacto',
        title: 'Telefono de contacto',
        detail: 'Se toma del dato base del expediente.',
        kind: _HrExpedienteRequirementKind.baseTelefono,
      ),
      _HrExpedienteRequirementSpec(
        key: 'cuenta_nomina',
        title: 'Cuenta de nomina BBVA',
        detail: 'Se toma del dato base cuando exista.',
        kind: _HrExpedienteRequirementKind.baseCuenta,
      ),
      _HrExpedienteRequirementSpec(
        key: 'credito_aviso',
        title: 'Aviso de credito',
        detail: 'Declarar Infonavit, Fonacot u otro credito.',
        kind: _HrExpedienteRequirementKind.creditNotice,
      ),
      _HrExpedienteRequirementSpec(
        key: 'antidoping',
        title: 'Antidoping 5 parametros',
        detail: 'Resultado/documento de control.',
      ),
      _HrExpedienteRequirementSpec(
        key: 'constancia_fiscal',
        title: 'Constancia de situacion fiscal',
        detail: 'Documento actualizado.',
      ),
      _HrExpedienteRequirementSpec(
        key: 'contrato',
        title: 'Contrato',
        detail: 'Contrato firmado y vigente.',
      ),
    ];

enum _HrExpedienteRequirementKind {
  upload,
  baseTelefono,
  baseCuenta,
  creditNotice,
}

class _HrExpedienteRequirementSpec {
  final String key;
  final String title;
  final String detail;
  final int minimumFiles;
  final _HrExpedienteRequirementKind kind;

  const _HrExpedienteRequirementSpec({
    required this.key,
    required this.title,
    required this.detail,
    this.minimumFiles = 1,
    this.kind = _HrExpedienteRequirementKind.upload,
  });
}

class HumanResourcesPersonnelPage extends StatefulWidget {
  final bool instantOpen;

  const HumanResourcesPersonnelPage({super.key, this.instantOpen = false});

  @override
  State<HumanResourcesPersonnelPage> createState() =>
      _HumanResourcesPersonnelPageState();
}

enum _PersonnelRowAction { open, export, delete }

class _HumanResourcesPersonnelPageState
    extends State<HumanResourcesPersonnelPage> {
  bool _menuOpen = false;
  bool _canReturnToDirection = false;
  bool _exportingCsv = false;
  String? _hoveredRowId;
  String? _selectedRowId;
  Set<String> _selectedRowIds = <String>{};
  final FocusNode _rowsFocusNode = FocusNode(debugLabel: 'hrPersonnelRows');
  final Map<String, Set<String>> _columnFilters = <String, Set<String>>{};
  final Map<String, DateTimeRange> _columnDateRangeFilters =
      <String, DateTimeRange>{};
  final GridNavigationController _navigationController =
      GridNavigationController();
  final GridSelectionController _selectionController =
      GridSelectionController();
  final ScrollController _rowsScrollController = ScrollController();
  final GridScrollVisibilityCoordinator _gridVisibilityCoordinator =
      GridScrollVisibilityCoordinator();
  final GlobalKey _rowsViewportKey = GlobalKey();
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  final List<_HumanResourcesEmployeeRow> _allRows =
      List<_HumanResourcesEmployeeRow>.of(_HumanResourcesEmployeeRow.seed);
  List<_HumanResourcesEmployeeRow> _visibleRows =
      _HumanResourcesEmployeeRow.seed;
  int _currentPage = 0;
  int _pageSize = 40;
  bool _dragSelectionActive = false;
  bool _dragSelectionAdditive = false;
  bool _dragSelectionMoved = false;
  bool _pointerDownAdditiveSelection = false;
  bool _suppressNextRowTap = false;
  Set<String> _dragSelectionBaseIds = <String>{};
  List<String> _dragSelectionIds = const <String>[];
  String? _dragSelectionAnchorId;
  Offset? _dragPointerGlobal;
  double _dragAutoScrollVelocity = 0;
  Timer? _dragAutoScrollTimer;

  @override
  void initState() {
    super.initState();
    _navigationController.addListener(_handleNavigationChanged);
    _selectionController.addListener(_handleGridStateChanged);
    _configureGrid();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncViewportState(requestFocus: true);
    });
    unawaited(_resolveNavigationAccess());
    unawaited(_loadRemoteEmployees());
  }

  @override
  void dispose() {
    _rowsFocusNode.dispose();
    _navigationController
      ..removeListener(_handleNavigationChanged)
      ..dispose();
    _selectionController
      ..removeListener(_handleGridStateChanged)
      ..dispose();
    _rowsScrollController.dispose();
    _dragAutoScrollTimer?.cancel();
    super.dispose();
  }

  void _handleGridStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleNavigationChanged() {
    final position = _navigationController.active;
    if (position.zone == GridNavigationZone.grid &&
        position.rowIndex >= 0 &&
        position.rowIndex < _pagedRows.length) {
      final row = _pagedRows[position.rowIndex];
      if (!_selectionController.isSelected(row.id) ||
          _selectionController.selectedIds.length != 1) {
        _selectionController.selectSingle(row.id, rowIndex: position.rowIndex);
      }
      _syncSelectionFromController(preferredRowId: row.id);
      unawaited(
        _gridVisibilityCoordinator.ensureGridRowVisible(position.rowIndex),
      );
      return;
    }
    _handleGridStateChanged();
  }

  void _syncSelectionFromController({String? preferredRowId}) {
    final rows = _pagedRows;
    final visibleIds = rows.map((row) => row.id).toSet();
    final nextSelectedIds = _selectionController.selectedIds.intersection(
      visibleIds,
    );
    String? nextSelectedRowId;
    if (preferredRowId != null && nextSelectedIds.contains(preferredRowId)) {
      nextSelectedRowId = preferredRowId;
    } else if (_selectedRowId != null &&
        nextSelectedIds.contains(_selectedRowId)) {
      nextSelectedRowId = _selectedRowId;
    } else if (nextSelectedIds.isNotEmpty) {
      nextSelectedRowId = rows
          .firstWhere((row) => nextSelectedIds.contains(row.id))
          .id;
    }
    if (!mounted) return;
    setState(() {
      _selectedRowId = nextSelectedRowId;
      _selectedRowIds = nextSelectedIds;
    });
  }

  void _requestGridFocus({bool preserveSelectedRow = true}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pagedRows.isNotEmpty) {
        final targetRowId = preserveSelectedRow ? _selectedRowId : null;
        final targetIndex = targetRowId == null
            ? 0
            : _pagedRows.indexWhere((row) => row.id == targetRowId);
        _navigationController.focusGridCell(
          rowIndex: targetIndex >= 0 ? targetIndex : 0,
          columnIndex: 0,
        );
      }
      _rowsFocusNode.requestFocus();
    });
  }

  void _handleRowTap(String rowId, int rowIndex) {
    if (_suppressNextRowTap) {
      setState(() {
        _suppressNextRowTap = false;
        _dragSelectionMoved = false;
        _pointerDownAdditiveSelection = false;
      });
      return;
    }
    if (_pointerDownAdditiveSelection) {
      _selectionController.toggle(rowId, rowIndex: rowIndex);
      _navigationController.focusGridCell(rowIndex: rowIndex, columnIndex: 0);
      _syncSelectionFromController(preferredRowId: rowId);
      setState(() {
        _pointerDownAdditiveSelection = false;
        _dragSelectionMoved = false;
      });
      _rowsFocusNode.requestFocus();
      return;
    }
    _selectionController.handlePointerSelection(
      id: rowId,
      rowIndex: rowIndex,
      resolveRangeIds: (start, end) =>
          _pagedRows.getRange(start, end + 1).map((row) => row.id),
      visibilityCoordinator: _gridVisibilityCoordinator,
    );
    _navigationController.focusGridCell(rowIndex: rowIndex, columnIndex: 0);
    _syncSelectionFromController(preferredRowId: rowId);
    setState(() => _dragSelectionMoved = false);
    _rowsFocusNode.requestFocus();
  }

  void _beginDragSelection(
    String rowId,
    List<String> visibleIds, {
    required bool additive,
  }) {
    _rowsFocusNode.requestFocus();
    final rowIndex = visibleIds.indexOf(rowId);
    if (rowIndex < 0) return;
    final baseIds = additive ? {..._selectedRowIds} : <String>{};
    final nextIds = additive ? baseIds : <String>{rowId};
    setState(() {
      _dragSelectionActive = true;
      _dragSelectionAdditive = additive;
      _dragSelectionMoved = false;
      _suppressNextRowTap = false;
      _pointerDownAdditiveSelection = additive;
      _dragSelectionBaseIds = baseIds;
      _dragSelectionIds = visibleIds;
      _dragSelectionAnchorId = rowId;
      _dragPointerGlobal = null;
    });
    _selectionController.selectRange(nextIds, anchorRowIndex: rowIndex);
    _navigationController.focusGridCell(rowIndex: rowIndex, columnIndex: 0);
    _syncSelectionFromController(preferredRowId: rowId);
    _rowsFocusNode.requestFocus();
  }

  void _updateDragSelection(String rowId) {
    if (!_dragSelectionActive || _dragSelectionAnchorId == null) return;
    final visibleIds = _dragSelectionIds;
    final start = visibleIds.indexOf(_dragSelectionAnchorId!);
    final end = visibleIds.indexOf(rowId);
    if (start == -1 || end == -1) return;
    final range = visibleIds.sublist(
      start < end ? start : end,
      start < end ? end + 1 : start + 1,
    );
    final nextIds = _dragSelectionAdditive
        ? {..._dragSelectionBaseIds, ...range}
        : range.toSet();
    _selectionController.selectRange(nextIds, anchorRowIndex: start);
    _navigationController.focusGridCell(rowIndex: end, columnIndex: 0);
    _syncSelectionFromController(preferredRowId: rowId);
    setState(() {
      _dragSelectionMoved = end != start || nextIds.length > 1;
    });
  }

  void _endDragSelection() {
    if (!_dragSelectionActive) return;
    setState(() {
      _dragSelectionActive = false;
      _dragSelectionAdditive = false;
      _suppressNextRowTap = _dragSelectionMoved;
      if (_dragSelectionMoved) {
        _pointerDownAdditiveSelection = false;
      }
      _dragSelectionIds = const <String>[];
      _dragSelectionAnchorId = null;
      _dragPointerGlobal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      _dragSelectionBaseIds = <String>{};
    });
  }

  int? _visibleRowIndexAtGlobalPosition(
    Offset globalPosition,
    List<String> visibleIds,
  ) {
    for (var i = 0; i < visibleIds.length; i++) {
      final box =
          _rowKeys[visibleIds[i]]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(globalPosition)) return i;
    }
    return null;
  }

  int? _mountedEdgeRowIndex(List<String> visibleIds, {required bool last}) {
    final indexes = <int>[];
    for (var i = 0; i < visibleIds.length; i++) {
      final box =
          _rowKeys[visibleIds[i]]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (box != null && box.hasSize) indexes.add(i);
    }
    if (indexes.isEmpty) return null;
    return last ? indexes.last : indexes.first;
  }

  void _handleRowsPointerMove(PointerMoveEvent event, List<String> visibleIds) {
    if (!_dragSelectionActive) return;
    _dragPointerGlobal = event.position;
    _updateDragAutoScroll(visibleIds);
    final visibleIndex = _visibleRowIndexAtGlobalPosition(
      event.position,
      visibleIds,
    );
    if (visibleIndex == null) return;
    _updateDragSelection(visibleIds[visibleIndex]);
  }

  void _updateDragAutoScroll(List<String> visibleIds) {
    if (!_dragSelectionActive || _dragPointerGlobal == null) {
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final box =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    const edge = 36.0;
    const maxStep = 18.0;
    final local = box.globalToLocal(_dragPointerGlobal!);
    final y = local.dy;
    if (y < edge) {
      _dragAutoScrollVelocity = -((edge - y) / edge).clamp(0.0, 1.0) * maxStep;
    } else if (y > box.size.height - edge) {
      _dragAutoScrollVelocity =
          ((y - (box.size.height - edge)) / edge).clamp(0.0, 1.0) * maxStep;
    } else {
      _dragAutoScrollVelocity = 0;
    }
    if (_dragAutoScrollVelocity == 0) {
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    _dragAutoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _performDragAutoScroll(visibleIds),
    );
  }

  void _performDragAutoScroll(List<String> visibleIds) {
    if (!_dragSelectionActive ||
        _dragAutoScrollVelocity == 0 ||
        !_rowsScrollController.hasClients) {
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final position = _rowsScrollController.position;
    final next = (position.pixels + _dragAutoScrollVelocity).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((next - position.pixels).abs() < 0.5) return;
    _rowsScrollController.jumpTo(next);
    final pointer = _dragPointerGlobal;
    final viewportBox =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (pointer == null || viewportBox == null || !viewportBox.hasSize) return;
    final visibleIndex = _visibleRowIndexAtGlobalPosition(pointer, visibleIds);
    int? targetIndex = visibleIndex;
    if (targetIndex == null) {
      final local = viewportBox.globalToLocal(pointer);
      if (local.dy < 0) {
        targetIndex = _mountedEdgeRowIndex(visibleIds, last: false);
      } else if (local.dy > viewportBox.size.height) {
        targetIndex = _mountedEdgeRowIndex(visibleIds, last: true);
      }
    }
    if (targetIndex == null) return;
    _updateDragSelection(visibleIds[targetIndex]);
  }

  void _syncViewportState({bool requestFocus = false}) {
    _clampCurrentPage();
    _configureGrid();
    final rows = _pagedRows;
    if (rows.isEmpty) {
      _selectionController.clear();
      if (mounted) {
        setState(() {
          _selectedRowId = null;
          _selectedRowIds = <String>{};
        });
      }
      return;
    }
    final preferredRowId =
        _selectedRowId != null && rows.any((row) => row.id == _selectedRowId)
        ? _selectedRowId!
        : rows.first.id;
    final rowIndex = rows.indexWhere((row) => row.id == preferredRowId);
    if (!_selectionController.isSelected(preferredRowId) ||
        _selectionController.selectedIds.length != 1) {
      _selectionController.selectSingle(preferredRowId, rowIndex: rowIndex);
    } else {
      _selectionController.anchorIndex = rowIndex;
    }
    _syncSelectionFromController(preferredRowId: preferredRowId);
    final active = _navigationController.active;
    if (active.zone != GridNavigationZone.grid ||
        active.rowIndex != rowIndex ||
        active.columnIndex >= _kGridColumns.length) {
      _navigationController.focusGridCell(rowIndex: rowIndex, columnIndex: 0);
    }
    unawaited(_gridVisibilityCoordinator.ensureGridRowVisible(rowIndex));
    if (requestFocus) {
      _requestGridFocus();
    }
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
      gridColumnCount: _kGridColumns.length,
      rowCount: _pagedRows.length,
    );
  }

  List<_HumanResourcesEmployeeRow> get _pagedRows {
    final start = _currentPage * _pageSize;
    if (start >= _visibleRows.length) {
      return const <_HumanResourcesEmployeeRow>[];
    }
    final end = math.min(start + _pageSize, _visibleRows.length);
    return _visibleRows.sublist(start, end);
  }

  int get _totalPages {
    final total = (_visibleRows.length / _pageSize).ceil();
    return math.max(1, total);
  }

  void _clampCurrentPage() {
    final maxPage = _totalPages - 1;
    if (_currentPage > maxPage) _currentPage = maxPage;
    if (_currentPage < 0) _currentPage = 0;
  }

  void _applyFilters() {
    final nextRows =
        _allRows.where(_matchesColumnFilters).toList(growable: false)
          ..sort(_compareHrEmployeeRowsById);

    final visibleIds = nextRows.map((row) => row.id).toSet();
    if (_selectedRowIds.isNotEmpty &&
        !_selectedRowIds.every(visibleIds.contains)) {
      _selectionController.clear();
    }

    setState(() {
      _visibleRows = nextRows;
      _currentPage = 0;
      _hoveredRowId = visibleIds.contains(_hoveredRowId) ? _hoveredRowId : null;
    });
    _syncViewportState();
  }

  Future<void> _loadRemoteEmployees() async {
    try {
      final rows = await _HrPersonnelStore.loadEmployees();
      if (!mounted) return;
      if (rows.isNotEmpty) {
        setState(() {
          _allRows
            ..clear()
            ..addAll(rows)
            ..sort(_compareHrEmployeeRowsById);
        });
        _applyFilters();
      }
    } catch (_) {}
  }

  bool _matchesColumnFilters(_HumanResourcesEmployeeRow row) {
    for (final entry in _columnDateRangeFilters.entries) {
      final value = _dateValueForColumn(row, entry.key);
      if (value == null) return false;
      final d = DateUtils.dateOnly(value);
      final start = DateUtils.dateOnly(entry.value.start);
      final end = DateUtils.dateOnly(entry.value.end);
      if (d.isBefore(start) || d.isAfter(end)) {
        return false;
      }
    }
    for (final entry in _columnFilters.entries) {
      if (entry.value.isEmpty) continue;
      final cell = _cellValueForColumn(row, entry.key);
      if (!entry.value.contains(cell)) {
        return false;
      }
    }
    return true;
  }

  DateTime? _dateValueForColumn(
    _HumanResourcesEmployeeRow row,
    String columnId,
  ) {
    if (columnId != 'fecha_ingreso') return null;
    final parts = row.fechaIngreso.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  String _cellValueForColumn(_HumanResourcesEmployeeRow row, String columnId) {
    switch (columnId) {
      case 'id':
        return row.id;
      case 'nombre':
        return row.nombre;
      case 'empresa':
        return row.empresa;
      case 'horario':
        return row.horario;
      case 'nss':
        return row.nss;
      case 'rfc':
        return row.rfc;
      case 'curp':
        return row.curp;
      case 'fecha_ingreso':
        return row.fechaIngreso;
      case 'telefono':
        return row.telefono;
      case 'numero_cuenta':
        return row.numeroCuenta;
      case 'calzado':
        return row.calzado;
      default:
        return '';
    }
  }

  bool _hasActiveFilter(String columnId) =>
      (_columnFilters[columnId] ?? const <String>{}).isNotEmpty ||
      _columnDateRangeFilters.containsKey(columnId);

  bool _isDateFilterColumn(String columnId) => columnId == 'fecha_ingreso';

  void _replaceRow(
    _HumanResourcesEmployeeRow updatedRow, {
    String? originalId,
  }) {
    final lookupId = (originalId == null || originalId == updatedRow.id)
        ? updatedRow.id
        : originalId;
    final rowIndex = _allRows.indexWhere((row) => row.id == lookupId);
    if (rowIndex < 0) return;
    setState(() {
      _allRows[rowIndex] = updatedRow;
      _allRows.sort(_compareHrEmployeeRowsById);
      _selectedRowId = updatedRow.id;
      _selectedRowIds = <String>{updatedRow.id};
    });
    _applyFilters();
  }

  Future<void> _startNewRecord() async {
    final next = await showDialog<_HumanResourcesEmployeeRow>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (dialogContext) => AreaThemeScope(
        tokens: humanResourcesAreaTokens,
        child: _HumanResourcesEmployeeDialog.create(
          nextId: _suggestNextEmployeeId(),
          reservedIds: _allRows.map((row) => row.id).toSet(),
        ),
      ),
    );
    if (!mounted || next == null) return;
    final persisted = await _persistRow(next, creating: true);
    if (!mounted || persisted == null) return;
    setState(() {
      _allRows.add(persisted);
      _allRows.sort(_compareHrEmployeeRowsById);
      _selectedRowId = persisted.id;
      _selectedRowIds = <String>{persisted.id};
    });
    _applyFilters();
    _showSnack('Registro agregado: ${persisted.nombre}');
  }

  Future<void> _editRecord(_HumanResourcesEmployeeRow row) async {
    final updated = await showDialog<_HumanResourcesEmployeeRow>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (dialogContext) => AreaThemeScope(
        tokens: humanResourcesAreaTokens,
        child: _HumanResourcesEmployeeDialog.edit(
          employee: row,
          reservedIds: _allRows
              .where((item) => item.id != row.id)
              .map((item) => item.id)
              .toSet(),
        ),
      ),
    );
    if (!mounted || updated == null) return;
    final persisted = await _persistRow(updated, originalId: row.id);
    if (!mounted || persisted == null) return;
    _replaceRow(persisted, originalId: row.id);
    _showSnack('Registro actualizado: ${persisted.nombre}');
  }

  Future<_HumanResourcesEmployeeRow?> _persistRow(
    _HumanResourcesEmployeeRow row, {
    bool creating = false,
    String? originalId,
  }) async {
    try {
      final persisted = await _HrPersonnelStore.upsertEmployee(
        row,
        originalId: originalId,
      );
      return persisted;
    } catch (error) {
      if (!mounted) return null;
      _showSnack(
        creating
            ? 'No se pudo crear en Supabase. Se conserva localmente. $error'
            : 'No se pudo guardar en Supabase. Se conserva localmente. $error',
      );
      return row;
    }
  }

  String _suggestNextEmployeeId() {
    var maxId = 0;
    for (final row in _allRows) {
      final parsed = int.tryParse(row.id);
      if (parsed != null && parsed > maxId) maxId = parsed;
    }
    return '${maxId + 1}';
  }

  DateTimeRange _dateBoundsForColumn(String columnId) {
    DateTime? minDate;
    DateTime? maxDate;
    for (final row in _allRows) {
      final date = _dateValueForColumn(row, columnId);
      if (date == null) continue;
      final dateOnly = DateUtils.dateOnly(date);
      if (minDate == null || dateOnly.isBefore(minDate)) minDate = dateOnly;
      if (maxDate == null || dateOnly.isAfter(maxDate)) maxDate = dateOnly;
    }
    final now = DateUtils.dateOnly(DateTime.now());
    return DateTimeRange(
      start: minDate ?? DateTime(now.year - 3, 1, 1),
      end: maxDate ?? DateTime(now.year + 3, 12, 31),
    );
  }

  Future<void> _openColumnFilter(String columnId, String label) async {
    if (_isDateFilterColumn(columnId)) {
      final result = await _showHrDateRangeFilterDialog(
        context,
        label: label,
        bounds: _dateBoundsForColumn(columnId),
        initialRange: _columnDateRangeFilters[columnId],
      );
      if (!mounted || result == null) return;
      setState(() {
        if (result.clear) {
          _columnDateRangeFilters.remove(columnId);
        } else if (result.range != null) {
          _columnDateRangeFilters[columnId] = DateTimeRange(
            start: DateUtils.dateOnly(result.range!.start),
            end: DateUtils.dateOnly(result.range!.end),
          );
        }
        _columnFilters.remove(columnId);
      });
      _applyFilters();
      return;
    }

    final options =
        _allRows
            .map((row) => _cellValueForColumn(row, columnId))
            .where((value) => value.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final current = _columnFilters[columnId] ?? const <String>{};
    final result = await showDialog<GridFilterState>(
      context: context,
      builder: (dialogContext) => AreaThemeScope(
        tokens: humanResourcesAreaTokens,
        child: GridFilterDialog(
          title: label,
          initialState: GridFilterState(
            options: options
                .map(
                  (value) => GridFilterOption(
                    value: value,
                    label: value,
                    selected: current.contains(value),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      final selected = result.selectedValues;
      if (selected.isEmpty) {
        _columnFilters.remove(columnId);
      } else {
        _columnFilters[columnId] = selected;
      }
    });
    _applyFilters();
  }

  Future<void> _logout() => signOutAndRouteToLogin(context);

  Future<void> _openDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openAttendanceIncidents() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const HumanResourcesAttendanceIncidentsPage(instantOpen: true),
      ),
    );
  }

  Future<void> _openAttendance() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesAttendancePage(instantOpen: true)),
    );
  }

  Future<void> _openVacations() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesVacationsPage(instantOpen: true)),
    );
  }

  Future<void> _openPermissions() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const HumanResourcesPermissionsPage(instantOpen: true),
      ),
    );
  }

  Future<void> _openPrenomina() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesPrenominaPage(instantOpen: true)),
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
          'Dias que labora',
          'NSS',
          'RFC',
          'CURP',
          'Fecha de ingreso',
          'Fecha de alta',
          'Telefono',
          'No. de Cuenta',
          'Salario',
          'Salario percibido',
          'Calzado',
          'Talla de uniforme',
        ].map(_csvCell).join(','),
      );
    for (final row in _visibleRows) {
      buffer.writeln(
        [
          row.id,
          row.nombre,
          row.empresa,
          row.horario,
          row.diasLabora.join(', '),
          row.nss,
          row.rfc,
          row.curp,
          row.fechaIngreso,
          row.fechaAlta,
          row.telefono,
          row.numeroCuenta,
          row.salario,
          row.salarioRealPercibido,
          row.calzado,
          row.tallaUniforme,
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
    if (_selectedRowIds.isNotEmpty) {
      _selectionController.clear();
      setState(() {
        _selectedRowId = null;
        _selectedRowIds = <String>{};
      });
      return;
    }
    if (_visibleRows.isNotEmpty) {
      _navigationController.focusGridCell(rowIndex: 0, columnIndex: 0);
      _requestGridFocus(preserveSelectedRow: false);
    }
  }

  void _handleDeleteSelection() {
    if (_selectedRowIds.isEmpty) return;
    unawaited(_requestDeleteRowsByIds(_selectedRowIds));
  }

  void _openActiveRecord() {
    if (_visibleRows.isEmpty) return;
    final index = _navigationController.active.rowIndex;
    if (index < 0 || index >= _visibleRows.length) return;
    unawaited(_editRecord(_visibleRows[index]));
  }

  Future<void> _handleRowAction(
    _PersonnelRowAction action,
    _HumanResourcesEmployeeRow row,
  ) async {
    switch (action) {
      case _PersonnelRowAction.open:
        await _editRecord(row);
        return;
      case _PersonnelRowAction.export:
        await _exportSingleRowCsv(row);
        return;
      case _PersonnelRowAction.delete:
        await _requestDeleteRowsByIds(
          _selectedRowIds.contains(row.id) ? _selectedRowIds : <String>{row.id},
        );
        return;
    }
  }

  Future<void> _requestDeleteRowsByIds(Iterable<String> ids) async {
    final selectedIds = Set<String>.of(ids);
    if (selectedIds.isEmpty) return;
    final rowsToDelete = _allRows
        .where((row) => selectedIds.contains(row.id))
        .toList(growable: false);
    if (rowsToDelete.isEmpty) return;
    final confirmed = await showContractConfirmationDialog(
      context,
      title: rowsToDelete.length == 1
          ? 'Eliminar registro'
          : 'Eliminar registros',
      content: rowsToDelete.length == 1
          ? 'Se eliminará el expediente de ${rowsToDelete.first.nombre}.'
          : 'Se eliminarán ${rowsToDelete.length} expedientes seleccionados de Personal RH.',
      confirmText: rowsToDelete.length == 1
          ? 'Eliminar registro'
          : 'Eliminar ${rowsToDelete.length}',
      destructive: true,
      tokens: humanResourcesAreaTokens,
    );
    if (confirmed != true || !mounted) return;
    _deleteRowsByIdsNow(selectedIds);
  }

  void _deleteRowsByIdsNow(Set<String> selectedIds) {
    final rowsToDelete = _allRows
        .where((row) => selectedIds.contains(row.id))
        .toList(growable: false);
    final deletedCount = rowsToDelete.length;
    if (deletedCount == 0) return;
    unawaited(_deleteRowsRemotely(rowsToDelete, selectedIds));
  }

  Future<void> _deleteRowsRemotely(
    List<_HumanResourcesEmployeeRow> rowsToDelete,
    Set<String> selectedIds,
  ) async {
    try {
      await _HrPersonnelStore.deleteEmployees(rowsToDelete);
    } catch (error) {
      if (mounted) {
        _showSnack('No se pudieron borrar en Supabase. $error');
        return;
      }
    }
    final deletedCount = rowsToDelete.length;
    if (!mounted) return;
    setState(() {
      _allRows.removeWhere((row) => selectedIds.contains(row.id));
      _selectionController.clear();
      _selectedRowId = null;
      _selectedRowIds = <String>{};
      _hoveredRowId = selectedIds.contains(_hoveredRowId)
          ? null
          : _hoveredRowId;
    });
    _applyFilters();
    _showSnack(
      deletedCount == 1
          ? '1 registro eliminado.'
          : '$deletedCount registros eliminados.',
    );
  }

  void _prepareRowSelectionForActions({
    required String rowId,
    required int rowIndex,
  }) {
    final preserveMultiSelection =
        _selectionController.selectedIds.length > 1 &&
        _selectionController.selectedIds.contains(rowId);
    if (!preserveMultiSelection) {
      _selectionController.selectSingle(rowId, rowIndex: rowIndex);
      _syncSelectionFromController(preferredRowId: rowId);
    } else {
      _selectionController.anchorIndex = rowIndex;
      setState(() => _selectedRowId = rowId);
    }
    _navigationController.focusGridCell(rowIndex: rowIndex, columnIndex: 0);
    _rowsFocusNode.requestFocus();
  }

  Future<void> _exportSingleRowCsv(_HumanResourcesEmployeeRow row) async {
    final buffer = StringBuffer()
      ..writeln(
        [
          'ID',
          'Nombre',
          'Empresa',
          'Horario',
          'Dias que labora',
          'NSS',
          'RFC',
          'CURP',
          'Fecha de ingreso',
          'Fecha de alta',
          'Telefono',
          'No. de Cuenta',
          'Salario',
          'Salario percibido',
          'Calzado',
          'Talla de uniforme',
        ].map(_csvCell).join(','),
      )
      ..writeln(
        [
          row.id,
          row.nombre,
          row.empresa,
          row.horario,
          row.diasLabora.join(', '),
          row.nss,
          row.rfc,
          row.curp,
          row.fechaIngreso,
          row.fechaAlta,
          row.telefono,
          row.numeroCuenta,
          row.salario,
          row.salarioRealPercibido,
          row.calzado,
          row.tallaUniforme,
        ].map(_csvCell).join(','),
      );
    final safeName = row.nombre
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final output = await saveCsvFile(
      fileName:
          'rh_personal_${row.id}_${safeName.isEmpty ? 'registro' : safeName}.csv',
      content: buffer.toString(),
      dialogTitle: 'Guardar registro de personal',
    );
    if (!mounted || output == null) return;
    _showSnack('Registro exportado: $output');
  }

  Future<void> _openRowMenu(
    TapDownDetails details,
    _HumanResourcesEmployeeRow row,
    int rowIndex,
  ) async {
    _prepareRowSelectionForActions(rowId: row.id, rowIndex: rowIndex);
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
        ContractMenuEntry(
          value: _PersonnelRowAction.delete,
          label: 'Eliminar registro',
          icon: Icons.delete_outline_rounded,
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
        trailingBuilder: (_, _) => HumanResourcesAreaHeaderButton(
          label: 'Cerrar sesión',
          icon: Icons.logout_rounded,
          onTap: _logout,
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
                    focusNode: _rowsFocusNode,
                    onEscape: _handleEscape,
                    onDelete: _handleDeleteSelection,
                    onConfirm: _openActiveRecord,
                    onOpenActiveCell: _openActiveRecord,
                    child: _HumanResourcesPersonnelWorkspace(
                      rows: _pagedRows,
                      totalRows: _visibleRows.length,
                      selectedCount: _selectionController.selectedIds.length,
                      activeColumnIndex:
                          _navigationController.active.columnIndex,
                      exportingCsv: _exportingCsv,
                      hoveredRowId: _hoveredRowId,
                      navigationController: _navigationController,
                      selectionController: _selectionController,
                      rowsScrollController: _rowsScrollController,
                      visibilityCoordinator: _gridVisibilityCoordinator,
                      rowsViewportKey: _rowsViewportKey,
                      onExportCsv: _exportCsv,
                      onRowsPointerMove: _handleRowsPointerMove,
                      onTapRow: _handleRowTap,
                      onHoverRowChanged: (value) {
                        if (_hoveredRowId == value) return;
                        setState(() => _hoveredRowId = value);
                      },
                      onRowAction: _handleRowAction,
                      onRowContextMenu: _openRowMenu,
                      hasActiveFilter: _hasActiveFilter,
                      onOpenFilter: _openColumnFilter,
                      onShowNewRecord: _startNewRecord,
                      onBeginDragSelection: _beginDragSelection,
                      onUpdateDragSelection: _updateDragSelection,
                      onEndDragSelection: _endDragSelection,
                      onPrepareRowActions: (row, rowIndex) {
                        _prepareRowSelectionForActions(
                          rowId: row.id,
                          rowIndex: rowIndex,
                        );
                        if (_hoveredRowId != row.id) {
                          setState(() => _hoveredRowId = row.id);
                        }
                      },
                      rowKeyForId: (rowId) =>
                          _rowKeys.putIfAbsent(rowId, GlobalKey.new),
                      currentPage: _currentPage,
                      totalPages: _totalPages,
                      pageSize: _pageSize,
                      onPreviousPage: _currentPage > 0
                          ? () {
                              setState(() => _currentPage--);
                              _syncViewportState(requestFocus: true);
                            }
                          : null,
                      onNextPage: _currentPage < _totalPages - 1
                          ? () {
                              setState(() => _currentPage++);
                              _syncViewportState(requestFocus: true);
                            }
                          : null,
                      onPageSizeChanged: (value) {
                        setState(() {
                          _pageSize = value;
                          _currentPage = 0;
                        });
                        _syncViewportState(requestFocus: true);
                      },
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
                      icon: Icons.fact_check_outlined,
                      title: 'Asistencia',
                      subtitle: 'Cierre editable semanal por colaborador',
                      onTap: _openAttendance,
                    ),
                    HumanResourcesAreaNavEntry(
                      icon: Icons.schedule_rounded,
                      title: 'Importación y conciliación',
                      subtitle: 'Lectura y cruce de NGTeco y CONTPAQ',
                      onTap: _openAttendanceIncidents,
                    ),
                    HumanResourcesAreaNavEntry(
                      icon: Icons.beach_access_rounded,
                      title: 'Vacaciones',
                      subtitle: 'Derecho, aplicación y saldo por ejercicio',
                      onTap: _openVacations,
                    ),
                    HumanResourcesAreaNavEntry(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'Permisos',
                      subtitle: 'Ledger operativo por periodo y colaborador',
                      onTap: _openPermissions,
                    ),
                    HumanResourcesAreaNavEntry(
                      icon: Icons.payments_outlined,
                      title: 'Prenómina',
                      subtitle: 'Corrida borrador semanal por colaborador',
                      onTap: _openPrenomina,
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
  final List<_HumanResourcesEmployeeRow> rows;
  final int totalRows;
  final int selectedCount;
  final int activeColumnIndex;
  final bool exportingCsv;
  final String? hoveredRowId;
  final GridNavigationController navigationController;
  final GridSelectionController selectionController;
  final ScrollController rowsScrollController;
  final GridScrollVisibilityCoordinator visibilityCoordinator;
  final Future<void> Function() onExportCsv;
  final GlobalKey rowsViewportKey;
  final void Function(PointerMoveEvent event, List<String> visibleIds)
  onRowsPointerMove;
  final void Function(String rowId, int rowIndex) onTapRow;
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
  final void Function(_HumanResourcesEmployeeRow row, int rowIndex)
  onPrepareRowActions;
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;
  final VoidCallback onShowNewRecord;
  final void Function(
    String rowId,
    List<String> visibleIds, {
    required bool additive,
  })
  onBeginDragSelection;
  final void Function(String rowId) onUpdateDragSelection;
  final VoidCallback onEndDragSelection;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final GlobalKey Function(String rowId) rowKeyForId;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<int> onPageSizeChanged;

  const _HumanResourcesPersonnelWorkspace({
    required this.rows,
    required this.totalRows,
    required this.selectedCount,
    required this.activeColumnIndex,
    required this.exportingCsv,
    required this.hoveredRowId,
    required this.navigationController,
    required this.selectionController,
    required this.rowsScrollController,
    required this.visibilityCoordinator,
    required this.rowsViewportKey,
    required this.onExportCsv,
    required this.onRowsPointerMove,
    required this.onTapRow,
    required this.onHoverRowChanged,
    required this.onRowAction,
    required this.onRowContextMenu,
    required this.hasActiveFilter,
    required this.onOpenFilter,
    required this.onShowNewRecord,
    required this.onBeginDragSelection,
    required this.onUpdateDragSelection,
    required this.onEndDragSelection,
    required this.onPrepareRowActions,
    required this.rowKeyForId,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPageSizeChanged,
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
        Expanded(
          child: ContractGlassCard(
            padding: EdgeInsets.zero,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: GridEditableShell(
                topBar: _HumanResourcesModuleTopBar(
                  totalRows: totalRows,
                  selectedCount: selectedCount,
                  activeCellLabel: 'Celda: $activeColumnLabel',
                  exportingCsv: exportingCsv,
                  onExportCsv: () => unawaited(onExportCsv()),
                  onShowNewRecord: onShowNewRecord,
                ),
                body: _HumanResourcesPersonnelGrid(
                  rows: rows,
                  hoveredRowId: hoveredRowId,
                  navigationController: navigationController,
                  selectionController: selectionController,
                  rowsScrollController: rowsScrollController,
                  visibilityCoordinator: visibilityCoordinator,
                  rowsViewportKey: rowsViewportKey,
                  onRowsPointerMove: onRowsPointerMove,
                  onTapRow: onTapRow,
                  hasActiveFilter: hasActiveFilter,
                  onOpenFilter: onOpenFilter,
                  onHoverRowChanged: onHoverRowChanged,
                  onRowAction: onRowAction,
                  onRowContextMenu: onRowContextMenu,
                  onBeginDragSelection: onBeginDragSelection,
                  onUpdateDragSelection: onUpdateDragSelection,
                  onEndDragSelection: onEndDragSelection,
                  onPrepareRowActions: onPrepareRowActions,
                  rowKeyForId: rowKeyForId,
                ),
                footer: _HumanResourcesGridFooter(
                  rows: rows.length,
                  totalRows: totalRows,
                  selectedCount: selectedCount,
                  currentPage: currentPage,
                  totalPages: totalPages,
                  pageSize: pageSize,
                  onPreviousPage: onPreviousPage,
                  onNextPage: onNextPage,
                  onPageSizeChanged: onPageSizeChanged,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HumanResourcesPersonnelGrid extends StatelessWidget {
  final List<_HumanResourcesEmployeeRow> rows;
  final String? hoveredRowId;
  final GridNavigationController navigationController;
  final GridSelectionController selectionController;
  final ScrollController rowsScrollController;
  final GridScrollVisibilityCoordinator visibilityCoordinator;
  final GlobalKey rowsViewportKey;
  final void Function(PointerMoveEvent event, List<String> visibleIds)
  onRowsPointerMove;
  final void Function(String rowId, int rowIndex) onTapRow;
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;
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
  final void Function(
    String rowId,
    List<String> visibleIds, {
    required bool additive,
  })
  onBeginDragSelection;
  final void Function(String rowId) onUpdateDragSelection;
  final VoidCallback onEndDragSelection;
  final void Function(_HumanResourcesEmployeeRow row, int rowIndex)
  onPrepareRowActions;
  final GlobalKey Function(String rowId) rowKeyForId;

  const _HumanResourcesPersonnelGrid({
    required this.rows,
    required this.hoveredRowId,
    required this.navigationController,
    required this.selectionController,
    required this.rowsScrollController,
    required this.visibilityCoordinator,
    required this.rowsViewportKey,
    required this.onRowsPointerMove,
    required this.onTapRow,
    required this.hasActiveFilter,
    required this.onOpenFilter,
    required this.onHoverRowChanged,
    required this.onRowAction,
    required this.onRowContextMenu,
    required this.onBeginDragSelection,
    required this.onUpdateDragSelection,
    required this.onEndDragSelection,
    required this.onPrepareRowActions,
    required this.rowKeyForId,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xDDF0E7FF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x66B084FF)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              width: constraints.maxWidth,
              child: Column(
                children: [
                  _HumanResourcesGridHeaderRow(
                    hasActiveFilter: hasActiveFilter,
                    onOpenFilter: onOpenFilter,
                  ),
                  Expanded(
                    child: Listener(
                      onPointerMove: (event) => onRowsPointerMove(
                        event,
                        rows.map((row) => row.id).toList(growable: false),
                      ),
                      onPointerUp: (_) => onEndDragSelection(),
                      onPointerCancel: (_) => onEndDragSelection(),
                      child: Container(
                        key: rowsViewportKey,
                        child: SingleChildScrollView(
                          controller: rowsScrollController,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: math.max(
                                0,
                                constraints.maxHeight - 68,
                              ),
                            ),
                            child: Column(
                              children: [
                                if (rows.isEmpty)
                                  const _HumanResourcesGridEmptyState()
                                else
                                  for (
                                    var index = 0;
                                    index < rows.length;
                                    index++
                                  )
                                    KeyedSubtree(
                                      key: rowKeyForId(rows[index].id),
                                      child: _HumanResourcesGridDataRow(
                                        row: rows[index],
                                        rowIndex: index,
                                        hovered: hoveredRowId == rows[index].id,
                                        selected: selectionController
                                            .isSelected(rows[index].id),
                                        activePosition:
                                            navigationController.active,
                                        visibilityCoordinator:
                                            visibilityCoordinator,
                                        onHoverChanged: onHoverRowChanged,
                                        onTap: () =>
                                            onTapRow(rows[index].id, index),
                                        onPrimaryPointerDown: (additive) =>
                                            onBeginDragSelection(
                                              rows[index].id,
                                              rows
                                                  .map((row) => row.id)
                                                  .toList(growable: false),
                                              additive: additive,
                                            ),
                                        onDragEnter: () =>
                                            onUpdateDragSelection(
                                              rows[index].id,
                                            ),
                                        onPointerEnd: onEndDragSelection,
                                        onDoubleTap: () => onRowAction(
                                          _PersonnelRowAction.open,
                                          rows[index],
                                        ),
                                        onSecondaryTapDown: (details) =>
                                            onRowContextMenu(
                                              details,
                                              rows[index],
                                              index,
                                            ),
                                        onPrepareActionsMenu: () =>
                                            onPrepareRowActions(
                                              rows[index],
                                              index,
                                            ),
                                        onActionSelected: (action) =>
                                            onRowAction(action, rows[index]),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HumanResourcesGridHeaderRow extends StatelessWidget {
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;

  const _HumanResourcesGridHeaderRow({
    required this.hasActiveFilter,
    required this.onOpenFilter,
  });

  @override
  Widget build(BuildContext context) {
    const s = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w900,
      color: Color(0xFF24103D),
      letterSpacing: 0.3,
    );
    return Card(
      elevation: 0,
      color: const Color(0xFFF4EEFF).withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widths = _resolveHrGridWidths(constraints.maxWidth);
            return SizedBox(
              width: constraints.maxWidth,
              child: Row(
                children: [
                  for (var index = 0; index < _kGridColumns.length; index++)
                    SizedBox(
                      width: widths[index],
                      child: _HrHCellExpand(
                        _kGridColumns[index].label.toUpperCase(),
                        s,
                        active: _kGridColumns[index].filterable
                            ? hasActiveFilter(_kGridColumns[index].id)
                            : false,
                        centered: _kGridColumns[index].centered,
                        onFilter: _kGridColumns[index].filterable
                            ? () => onOpenFilter(
                                _kGridColumns[index].id,
                                _kGridColumns[index].label,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
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
  final GridScrollVisibilityCoordinator visibilityCoordinator;
  final ValueChanged<String?> onHoverChanged;
  final VoidCallback onTap;
  final ValueChanged<bool>? onPrimaryPointerDown;
  final VoidCallback? onDragEnter;
  final VoidCallback? onPointerEnd;
  final VoidCallback onDoubleTap;
  final GestureTapDownCallback onSecondaryTapDown;
  final VoidCallback onPrepareActionsMenu;
  final ValueChanged<_PersonnelRowAction> onActionSelected;

  const _HumanResourcesGridDataRow({
    required this.row,
    required this.rowIndex,
    required this.hovered,
    required this.selected,
    required this.activePosition,
    required this.visibilityCoordinator,
    required this.onHoverChanged,
    required this.onTap,
    this.onPrimaryPointerDown,
    this.onDragEnter,
    this.onPointerEnd,
    required this.onDoubleTap,
    required this.onSecondaryTapDown,
    required this.onPrepareActionsMenu,
    required this.onActionSelected,
  });

  bool get _isActiveRow =>
      activePosition.zone == GridNavigationZone.grid &&
      activePosition.rowIndex == rowIndex;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selected || _isActiveRow;
    final hoverOnly = hovered && !hasSelection;
    final rowBg = hasSelection
        ? const Color(0xFF9F6BFF).withValues(alpha: 0.18)
        : hoverOnly
        ? const Color(0xFFF6F0FF)
        : Colors.white;
    final hoverLift = hasSelection
        ? -1.4
        : hovered
        ? -1.15
        : 0.0;
    final hoverElevation = hasSelection
        ? 3.2
        : hovered
        ? 2.7
        : 0.5;

    Widget gridFrame({
      required int col,
      required double width,
      required Widget child,
      bool centered = false,
    }) {
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Align(
            alignment: centered ? Alignment.center : Alignment.centerLeft,
            child: child,
          ),
        ),
      );
    }

    Widget actionButton() {
      return Align(
        alignment: Alignment.center,
        child: Container(
          width: 44,
          height: 36,
          decoration: BoxDecoration(
            color: hasSelection
                ? const Color(0xFF6E47A8)
                : const Color(0xFFF3EBFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasSelection
                  ? const Color(0xFF9F6BFF).withValues(alpha: 0.86)
                  : const Color(0xFFB68CFF).withValues(alpha: 0.38),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: hasSelection ? 0.12 : 0.06,
                ),
                blurRadius: hasSelection ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: EditableRowActionsButton<_PersonnelRowAction>(
            tooltip: 'Acciones de expediente',
            iconColor: hasSelection ? Colors.white : const Color(0xFF6E47A8),
            onBeforeOpen: onPrepareActionsMenu,
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
              ContractMenuEntry(
                value: _PersonnelRowAction.delete,
                label: 'Eliminar registro',
                icon: Icons.delete_outline_rounded,
              ),
            ],
            onSelected: onActionSelected,
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) {
        onHoverChanged(row.id);
        onDragEnter?.call();
      },
      onExit: (_) => onHoverChanged(null),
      child: Listener(
        onPointerDown: (event) {
          if ((event.buttons & kPrimaryMouseButton) != 0) {
            final pressed = HardwareKeyboard.instance.logicalKeysPressed;
            final additive =
                pressed.contains(LogicalKeyboardKey.controlLeft) ||
                pressed.contains(LogicalKeyboardKey.controlRight) ||
                pressed.contains(LogicalKeyboardKey.metaLeft) ||
                pressed.contains(LogicalKeyboardKey.metaRight);
            onPrimaryPointerDown?.call(additive);
          }
        },
        onPointerUp: (_) => onPointerEnd?.call(),
        onPointerCancel: (_) => onPointerEnd?.call(),
        child: GestureDetector(
          key: visibilityCoordinator.keyForCell(
            zone: GridNavigationZone.grid,
            rowIndex: rowIndex,
            columnIndex: 0,
          ),
          behavior: HitTestBehavior.translucent,
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onSecondaryTapDown: onSecondaryTapDown,
          child: AnimatedContainer(
            duration: Duration.zero,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, hoverLift, 0),
            child: Card(
              elevation: hoverElevation,
              color: rowBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: hasSelection
                      ? const Color(0xFF9F6BFF).withValues(alpha: 0.72)
                      : Colors.white.withValues(alpha: 0.0),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final widths = _resolveHrGridWidths(constraints.maxWidth);
                    return SizedBox(
                      width: constraints.maxWidth,
                      child: Row(
                        children: [
                          gridFrame(
                            col: 0,
                            width: widths[0],
                            centered: true,
                            child: _HrFitText(row.id, centered: true),
                          ),
                          gridFrame(
                            col: 1,
                            width: widths[1],
                            child: _HrFitText(row.nombre),
                          ),
                          gridFrame(
                            col: 2,
                            width: widths[2],
                            child: _HrFitText(row.empresa),
                          ),
                          gridFrame(
                            col: 3,
                            width: widths[3],
                            centered: true,
                            child: _HrFitText(row.horario, centered: true),
                          ),
                          gridFrame(
                            col: 4,
                            width: widths[4],
                            centered: true,
                            child: _HrFitText(row.fechaIngreso, centered: true),
                          ),
                          gridFrame(
                            col: 5,
                            width: widths[5],
                            centered: true,
                            child: actionButton(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
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
      decoration: const BoxDecoration(color: Color(0xDDF0E7FF)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F3FF).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0x66B68CFF),
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
                color: Color(0xFF24103D),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajusta el filtro para volver a mostrar el grid base del personal.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF6E47A8).withValues(alpha: 0.92),
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

List<double> _resolveHrGridWidths(double maxWidth) {
  final base = _kGridColumns.map((column) => column.width).toList();
  final baseTotal = base.fold<double>(0, (sum, width) => sum + width);
  if (maxWidth <= baseTotal) return base;

  final extra = maxWidth - baseTotal;
  const flexIndexes = <int>[1, 2, 3, 4, 5];
  final flexBaseTotal = flexIndexes.fold<double>(
    0,
    (sum, index) => sum + base[index],
  );
  final resolved = List<double>.of(base);
  for (final index in flexIndexes) {
    resolved[index] += extra * (base[index] / flexBaseTotal);
  }
  return resolved;
}

class _HumanResourcesGridFooter extends StatelessWidget {
  final int rows;
  final int totalRows;
  final int selectedCount;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<int> onPageSizeChanged;

  const _HumanResourcesGridFooter({
    required this.rows,
    required this.totalRows,
    required this.selectedCount,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        elevation: 0,
        color: const Color(0xFFF0E6FF).withValues(alpha: 0.56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                style: _hrInvActionOutlinedButtonStyle(),
                onPressed: onPreviousPage,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Anterior'),
              ),
              Text(
                'Página ${_fmtHrInt(currentPage + 1)} de ${_fmtHrInt(totalPages)}',
              ),
              OutlinedButton.icon(
                style: _hrInvActionOutlinedButtonStyle(),
                onPressed: onNextPage,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Siguiente'),
              ),
              const Text('Filas/pág:'),
              SizedBox(
                width: 90,
                child: DropdownButtonFormField<int>(
                  initialValue: pageSize,
                  isDense: true,
                  decoration: _hrInvGlassFieldDecoration(),
                  items: const [40, 80, 120]
                      .map(
                        (e) =>
                            DropdownMenuItem<int>(value: e, child: Text('$e')),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onPageSizeChanged(value);
                  },
                ),
              ),
              Text('Mostrando: ${_fmtHrInt(rows)}'),
              Text('Total: ${_fmtHrInt(totalRows)}'),
              Text('Selección: ${_fmtHrInt(selectedCount)}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _HumanResourcesModuleTopBar extends StatelessWidget {
  final int totalRows;
  final int selectedCount;
  final String? activeCellLabel;
  final bool exportingCsv;
  final VoidCallback onExportCsv;
  final VoidCallback onShowNewRecord;

  const _HumanResourcesModuleTopBar({
    required this.totalRows,
    required this.selectedCount,
    required this.activeCellLabel,
    required this.exportingCsv,
    required this.onExportCsv,
    required this.onShowNewRecord,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Personal',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        AppGlassToolbarPanel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final info = _HumanResourcesSelectionInfo(
                selectedCount: selectedCount,
                activeCellLabel: activeCellLabel,
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: _hrInvActionOutlinedButtonStyle(),
                    onPressed: exportingCsv ? null : onExportCsv,
                    icon: exportingCsv
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(
                      exportingCsv ? 'Exportando...' : 'Descargar CSV',
                    ),
                  ),
                  FilledButton.icon(
                    style: contractPrimaryButtonStyle(context),
                    onPressed: onShowNewRecord,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Nuevo registro'),
                  ),
                ],
              );
              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    actions,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: info),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: actions),
                  const SizedBox(width: 10),
                  info,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: _HumanResourcesMetricCard(totalRows: totalRows),
        ),
      ],
    );
  }
}

class _HumanResourcesSelectionInfo extends StatelessWidget {
  final int selectedCount;
  final String? activeCellLabel;

  const _HumanResourcesSelectionInfo({
    required this.selectedCount,
    required this.activeCellLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          selectedCount == 1
              ? '1 registro seleccionado'
              : '${_fmtHrInt(selectedCount)} registros seleccionados',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF24103D),
          ),
          textAlign: TextAlign.right,
        ),
        if (selectedCount > 1)
          const Text(
            'Shift/Ctrl amplian la selección activa',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6E47A8),
            ),
            textAlign: TextAlign.right,
          ),
        if (activeCellLabel != null)
          Text(
            activeCellLabel!,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6E47A8),
            ),
            textAlign: TextAlign.right,
          ),
      ],
    );
  }
}

class _HumanResourcesMetricCard extends StatelessWidget {
  final int totalRows;

  const _HumanResourcesMetricCard({required this.totalRows});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 278),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2EAFF).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x66B084FF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF130B22).withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE6D5FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: Color(0xFF6E47A8),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PERSONAL RH',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6E47A8),
                  letterSpacing: 0.7,
                ),
              ),
              Text(
                _fmtHrInt(totalRows),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF24103D),
                  height: 1,
                ),
              ),
              Text(
                'Filtrado (${_fmtHrInt(totalRows)} registros)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6E47A8).withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HumanResourcesEmployeeDialog extends StatefulWidget {
  final String initialId;
  final _HumanResourcesEmployeeRow? existing;
  final Set<String> reservedIds;

  const _HumanResourcesEmployeeDialog.create({
    required String nextId,
    required this.reservedIds,
  }) : initialId = nextId,
       existing = null;

  _HumanResourcesEmployeeDialog.edit({
    required _HumanResourcesEmployeeRow employee,
    required this.reservedIds,
  }) : initialId = employee.id,
       existing = employee;

  @override
  State<_HumanResourcesEmployeeDialog> createState() =>
      _HumanResourcesEmployeeDialogState();
}

class _HumanResourcesEmployeeDialogState
    extends State<_HumanResourcesEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController = TextEditingController(
    text: widget.initialId,
  );
  late final TextEditingController _nombreController = TextEditingController(
    text: widget.existing?.nombre ?? '',
  );
  late final TextEditingController _nssController = TextEditingController(
    text: widget.existing?.nss ?? '',
  );
  late final TextEditingController _rfcController = TextEditingController(
    text: widget.existing?.rfc ?? '',
  );
  late final TextEditingController _curpController = TextEditingController(
    text: widget.existing?.curp ?? '',
  );
  late final TextEditingController _telefonoController = TextEditingController(
    text: widget.existing?.telefono ?? '',
  );
  late final TextEditingController _cuentaController = TextEditingController(
    text: widget.existing?.numeroCuenta ?? '',
  );
  late final TextEditingController _salarioController = TextEditingController(
    text: widget.existing?.salario ?? '',
  );
  late final TextEditingController _salarioRealPercibidoController =
      TextEditingController(text: widget.existing?.salarioRealPercibido ?? '');
  late final TextEditingController _calzadoController = TextEditingController(
    text: widget.existing?.calzado ?? '',
  );
  late final TextEditingController _tallaUniformeController =
      TextEditingController(text: widget.existing?.tallaUniforme ?? '');
  late final TextEditingController _creditoDetalleController =
      TextEditingController(text: widget.existing?.creditoDetalle ?? '');
  String? _empresa;
  String? _horario;
  List<String> _diasLabora = <String>[];
  List<_HrLaborSchedule> _additionalLaborSchedules = <_HrLaborSchedule>[];
  DateTime? _fechaIngreso;
  DateTime? _fechaAlta;
  _HrEmployeeAttachment? _photo;
  bool? _creditoDeclarado;
  late List<_HrEmployeeAttachment> _requiredAttachments;
  late List<_HrEmployeeAttachment> _additionalAttachments;
  bool _showRequiredDocuments = false;
  bool _showAdditionalAttachments = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _empresa = widget.existing?.empresa;
    final schedules =
        widget.existing?.laborSchedules
            .where((schedule) => schedule.isMeaningful)
            .toList(growable: false) ??
        const <_HrLaborSchedule>[];
    if (schedules.isNotEmpty) {
      _horario = schedules.first.horario;
      _diasLabora = List<String>.of(schedules.first.diasLabora);
      _additionalLaborSchedules = List<_HrLaborSchedule>.of(schedules.skip(1));
    } else {
      _horario = widget.existing?.horario;
      _diasLabora = List<String>.of(widget.existing?.diasLabora ?? const []);
    }
    _fechaIngreso = widget.existing == null
        ? null
        : _tryParseHrDbDate(widget.existing!.fechaIngreso);
    _fechaAlta = widget.existing == null
        ? null
        : _tryParseHrDbDate(widget.existing!.fechaAlta);
    _photo = widget.existing?.photo;
    _creditoDeclarado = widget.existing?.creditoDeclarado;
    _requiredAttachments = List<_HrEmployeeAttachment>.of(
      widget.existing?.requiredAttachments ?? const <_HrEmployeeAttachment>[],
    );
    _additionalAttachments = List<_HrEmployeeAttachment>.of(
      widget.existing?.additionalAttachments ?? const <_HrEmployeeAttachment>[],
    );
    _telefonoController.addListener(_handleDerivedExpedienteChanged);
    _cuentaController.addListener(_handleDerivedExpedienteChanged);
  }

  @override
  void dispose() {
    _idController.dispose();
    _nombreController.dispose();
    _nssController.dispose();
    _rfcController.dispose();
    _curpController.dispose();
    _telefonoController.dispose();
    _cuentaController.dispose();
    _salarioController.dispose();
    _salarioRealPercibidoController.dispose();
    _calzadoController.dispose();
    _tallaUniformeController.dispose();
    _creditoDetalleController.dispose();
    super.dispose();
  }

  void _handleDerivedExpedienteChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _pickEmpresa() async {
    final value = await showSearchablePickerDialog<String>(
      context,
      title: 'Empresa',
      initialValue: _empresa,
      options: _kHrEmpresaOptions
          .map((option) => SearchablePickerOption(value: option, label: option))
          .toList(growable: false),
    );
    if (!mounted || value == null) return;
    setState(() => _empresa = value);
  }

  Future<void> _pickHorario() async {
    final value = await _showHrScheduleDialog(context, initialValue: _horario);
    if (!mounted || value == null) return;
    setState(() => _horario = value);
  }

  Future<void> _pickDiasLabora() async {
    final value = await _showHrWeekdaySelectionDialog(
      context,
      initialValues: _diasLabora,
    );
    if (!mounted || value == null) return;
    setState(() => _diasLabora = value);
  }

  Future<void> _addLaborSchedule() async {
    final value = await _showHrLaborScheduleComposerDialog(context);
    if (!mounted || value == null) return;
    setState(() {
      _additionalLaborSchedules = [..._additionalLaborSchedules, value];
    });
  }

  Future<void> _editLaborSchedule(int index) async {
    if (index < 0 || index >= _additionalLaborSchedules.length) return;
    final value = await _showHrLaborScheduleComposerDialog(
      context,
      initialValue: _additionalLaborSchedules[index],
    );
    if (!mounted || value == null) return;
    setState(() {
      _additionalLaborSchedules = List<_HrLaborSchedule>.of(
        _additionalLaborSchedules,
      )..[index] = value;
    });
  }

  void _removeLaborSchedule(int index) {
    if (index < 0 || index >= _additionalLaborSchedules.length) return;
    setState(() {
      _additionalLaborSchedules = List<_HrLaborSchedule>.of(
        _additionalLaborSchedules,
      )..removeAt(index);
    });
  }

  List<_HrLaborSchedule> _composeLaborSchedules() {
    final schedules = <_HrLaborSchedule>[];
    final primary = _HrLaborSchedule(
      horario: (_horario ?? '').trim(),
      diasLabora: List<String>.of(_diasLabora),
    );
    if (primary.isMeaningful) schedules.add(primary);
    for (final schedule in _additionalLaborSchedules) {
      if (schedule.isMeaningful) schedules.add(schedule);
    }
    return schedules;
  }

  Future<void> _pickFechaIngreso() async {
    final picked = await _showHrSingleDateDialog(
      context,
      initialDate: _fechaIngreso ?? DateTime.now(),
      firstDate: DateTime(1990, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      title: 'Fecha de ingreso',
    );
    if (!mounted || picked == null) return;
    setState(() => _fechaIngreso = DateUtils.dateOnly(picked));
  }

  Future<void> _pickFechaAlta() async {
    final picked = await _showHrSingleDateDialog(
      context,
      initialDate: _fechaAlta ?? _fechaIngreso ?? DateTime.now(),
      firstDate: DateTime(1990, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      title: 'Fecha de alta',
    );
    if (!mounted || picked == null) return;
    setState(() => _fechaAlta = DateUtils.dateOnly(picked));
  }

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        lockParentWindow: true,
        type: FileType.custom,
        allowedExtensions: _kHrFileExtensions
            .where((ext) => ext != 'pdf')
            .toList(growable: false),
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final attachment = _attachmentFromPlatformFile(
        result.files.first,
        categoryKey: 'photo',
        categoryLabel: 'Fotografia',
      );
      if (attachment == null) return;
      setState(() => _photo = attachment);
    } catch (_) {}
  }

  Future<void> _pickRequiredFiles(_HrExpedienteRequirementSpec spec) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: spec.minimumFiles > 1,
        withData: true,
        lockParentWindow: true,
        type: FileType.custom,
        allowedExtensions: _kHrFileExtensions,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final next = List<_HrEmployeeAttachment>.of(_requiredAttachments);
      for (final file in result.files) {
        final attachment = _attachmentFromPlatformFile(
          file,
          categoryKey: spec.key,
          categoryLabel: spec.title,
        );
        if (attachment != null) next.insert(0, attachment);
      }
      setState(() => _requiredAttachments = next);
    } catch (_) {}
  }

  Future<void> _pickAdditionalFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        lockParentWindow: true,
        type: FileType.custom,
        allowedExtensions: _kHrFileExtensions,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final next = List<_HrEmployeeAttachment>.of(_additionalAttachments);
      for (final file in result.files) {
        final attachment = _attachmentFromPlatformFile(
          file,
          categoryKey: 'adicional',
          categoryLabel: 'Adjunto adicional',
        );
        if (attachment != null) next.insert(0, attachment);
      }
      setState(() => _additionalAttachments = next);
    } catch (_) {}
  }

  void _removeRequiredAttachment(_HrEmployeeAttachment attachment) {
    setState(() {
      _requiredAttachments = _requiredAttachments
          .where((item) => item.id != attachment.id)
          .toList(growable: false);
    });
  }

  void _removeAdditionalAttachment(_HrEmployeeAttachment attachment) {
    setState(() {
      _additionalAttachments = _additionalAttachments
          .where((item) => item.id != attachment.id)
          .toList(growable: false);
    });
  }

  _HrEmployeeAttachment? _attachmentFromPlatformFile(
    PlatformFile file, {
    required String categoryKey,
    required String categoryLabel,
  }) {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    return _HrEmployeeAttachment(
      id: '${categoryKey}_${DateTime.now().microsecondsSinceEpoch}_${file.name}',
      title: file.name,
      fileName: file.name,
      bytes: bytes,
      fileUrl: '',
      storagePath: null,
      mimeType: _hrMimeTypeFor(file),
      sizeBytes: file.size,
      uploadedBy: null,
      uploadedByName: '',
      uploadedAt: DateTime.now(),
      createdAt: null,
      updatedAt: null,
      categoryKey: categoryKey,
      categoryLabel: categoryLabel,
    );
  }

  _HumanResourcesEmployeeRow _draftEmployeeRow() {
    return _HumanResourcesEmployeeRow(
      id: _idController.text.trim(),
      nombre: _nombreController.text.trim().toUpperCase(),
      empresa: (_empresa ?? '').trim(),
      horario: (_horario ?? '').trim(),
      diasLabora: List<String>.of(_diasLabora),
      laborSchedules: _composeLaborSchedules(),
      nss: _nssController.text.trim(),
      rfc: _rfcController.text.trim().toUpperCase(),
      curp: _curpController.text.trim().toUpperCase(),
      fechaIngreso: _fechaIngreso == null ? '' : _fmtHrDbDate(_fechaIngreso!),
      fechaAlta: _fechaAlta == null ? '' : _fmtHrDbDate(_fechaAlta!),
      telefono: _telefonoController.text.trim(),
      numeroCuenta: _cuentaController.text.trim(),
      salario: _normalizeHrMoneyInput(_salarioController.text),
      salarioRealPercibido: _normalizeHrMoneyInput(
        _salarioRealPercibidoController.text,
      ),
      calzado: _calzadoController.text.trim(),
      tallaUniforme: _tallaUniformeController.text.trim(),
      photo: _photo,
      creditoDeclarado: _creditoDeclarado,
      creditoDetalle: _creditoDetalleController.text.trim(),
      requiredAttachments: List<_HrEmployeeAttachment>.of(_requiredAttachments),
      additionalAttachments: List<_HrEmployeeAttachment>.of(
        _additionalAttachments,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaIngreso == null) {
      _showDialogValidationSnack('Fecha de ingreso es obligatoria.');
      return;
    }
    if (_normalizeHrMoneyInput(_salarioController.text).isEmpty) {
      _showDialogValidationSnack('Salario es obligatorio.');
      return;
    }
    if (_normalizeHrMoneyInput(_salarioRealPercibidoController.text).isEmpty) {
      _showDialogValidationSnack('Salario percibido es obligatorio.');
      return;
    }
    final nextRow = _draftEmployeeRow().copyWith(
      empresa: (_empresa ?? '').trim(),
      horario: (_horario ?? '').trim(),
      fechaIngreso: _fmtHrDbDate(_fechaIngreso!),
      fechaAlta: _fechaAlta == null ? '' : _fmtHrDbDate(_fechaAlta!),
    );
    final originalId = widget.existing?.id;
    if (originalId != null && originalId != nextRow.id) {
      final confirmed = await showContractConfirmationDialog(
        context,
        title: 'Confirmar cambio de ID',
        content:
            'Vas a cambiar el ID del trabajador de "$originalId" a "${nextRow.id}". '
            'Esto moverá la llave principal del expediente digital. ¿Deseas continuar?',
        confirmText: 'Sí, cambiar ID',
        tokens: humanResourcesAreaTokens,
      );
      if (confirmed != true || !mounted) return;
    }
    Navigator.of(context).pop(nextRow);
  }

  void _showDialogValidationSnack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draftEmployeeRow();
    final completedRequirements = _completedHrRequirementCount(draft);
    final totalRequirements = _kHrExpedienteRequirements.length;
    final progress = _hrExpedienteProgress(draft);
    final expedienteStatus = _hrExpedienteStatusLabel(progress);
    final ingresoChip = _fechaIngreso == null
        ? 'Ingreso pendiente'
        : 'Ingreso: ${_fmtHrDateLabel(_fechaIngreso!)}';
    return ContractDialogShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Container(
          width: 1028,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F0FF).withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x66B084FF)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9DAFF),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0x66B084FF),
                              ),
                            ),
                            child: Text(
                              _isEditing
                                  ? 'EDICION DE EXPEDIENTE'
                                  : 'NUEVO EXPEDIENTE',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF6E47A8),
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Expediente del colaborador',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF24103D),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Informacion administrativa y laboral del empleado.',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6E47A8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _HrStatusChip(
                                label:
                                    '#${_idController.text.trim().isEmpty ? '---' : _idController.text.trim()}',
                                complete: true,
                              ),
                              _HrStatusChip(
                                label: (_empresa ?? 'Empresa pendiente'),
                                complete:
                                    _empresa != null &&
                                    _empresa!.trim().isNotEmpty,
                              ),
                              _HrStatusChip(
                                label: ingresoChip,
                                complete: _fechaIngreso != null,
                              ),
                              _HrStatusChip(
                                label: expedienteStatus,
                                complete: progress >= 1,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(
                              0xFFF1E6FF,
                            ).withValues(alpha: 0.92),
                            foregroundColor: const Color(0xFF6E47A8),
                            side: const BorderSide(color: Color(0x66B084FF)),
                          ),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Cerrar',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 250,
                              child: _HrPassportPhotoCard(
                                photo: _photo,
                                onUpload: _pickPhoto,
                                onRemove: _photo == null
                                    ? null
                                    : () => setState(() => _photo = null),
                                nombre: _nombreController.text.trim(),
                                id: _idController.text.trim(),
                                empresa: (_empresa ?? '').trim(),
                                nss: _nssController.text.trim(),
                                rfc: _rfcController.text.trim().toUpperCase(),
                                curp: _curpController.text.trim().toUpperCase(),
                                statusLabel: expedienteStatus,
                                progress: progress,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                children: [
                                  _HrDialogSectionCard(
                                    title: 'Datos personales',
                                    subtitle:
                                        'Identificacion oficial y datos base del colaborador.',
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        _HrDialogField(
                                          width: 132,
                                          label: 'ID',
                                          child: TextFormField(
                                            controller: _idController,
                                            style: const TextStyle(
                                              color: Color(0xFF24103D),
                                            ),
                                            decoration:
                                                _hrDialogFieldDecoration(
                                                  context,
                                                  hintText: 'ID interno',
                                                ),
                                            validator: (value) {
                                              final required =
                                                  _requiredValidator(value);
                                              if (required != null) {
                                                return required;
                                              }
                                              final normalized = value!.trim();
                                              if (widget.reservedIds.contains(
                                                normalized,
                                              )) {
                                                return 'Este ID ya existe.';
                                              }
                                              return null;
                                            },
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                        _HrDialogField(
                                          width: 514,
                                          label: 'Nombre',
                                          child: TextFormField(
                                            controller: _nombreController,
                                            style: const TextStyle(
                                              color: Color(0xFF24103D),
                                            ),
                                            decoration:
                                                _hrDialogFieldDecoration(
                                                  context,
                                                  hintText: 'Nombre completo',
                                                ),
                                            validator: _requiredValidator,
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                        _HrDialogField(
                                          width: 320,
                                          label: 'CURP',
                                          child: TextFormField(
                                            controller: _curpController,
                                            style: const TextStyle(
                                              color: Color(0xFF24103D),
                                            ),
                                            decoration:
                                                _hrDialogFieldDecoration(
                                                  context,
                                                  hintText: 'CURP',
                                                ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                        _HrDialogField(
                                          width: 200,
                                          label: 'RFC',
                                          child: TextFormField(
                                            controller: _rfcController,
                                            style: const TextStyle(
                                              color: Color(0xFF24103D),
                                            ),
                                            decoration:
                                                _hrDialogFieldDecoration(
                                                  context,
                                                  hintText: 'RFC',
                                                ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                        _HrDialogField(
                                          width: 180,
                                          label: 'NSS',
                                          child: TextFormField(
                                            controller: _nssController,
                                            style: const TextStyle(
                                              color: Color(0xFF24103D),
                                            ),
                                            decoration:
                                                _hrDialogFieldDecoration(
                                                  context,
                                                  hintText: 'NSS',
                                                ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                        _HrDialogField(
                                          width: 200,
                                          label: 'Telefono',
                                          child: TextFormField(
                                            controller: _telefonoController,
                                            style: const TextStyle(
                                              color: Color(0xFF24103D),
                                            ),
                                            decoration:
                                                _hrDialogFieldDecoration(
                                                  context,
                                                  hintText: 'Telefono',
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _HrDialogSectionCard(
                                    title: 'Datos laborales',
                                    subtitle:
                                        'Adscripcion, horario y vigencia del colaborador.',
                                    trailing: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF8B5CF6,
                                        ),
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      onPressed: _addLaborSchedule,
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Jornada'),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 12,
                                          children: [
                                            _HrDialogField(
                                              width: 220,
                                              label: 'Empresa',
                                              child: _HrDialogPickerField(
                                                label:
                                                    _empresa ??
                                                    'Selecciona empresa',
                                                onTap: _pickEmpresa,
                                              ),
                                            ),
                                            _HrDialogField(
                                              width: 230,
                                              label: 'Horario',
                                              child: _HrDialogPickerField(
                                                label:
                                                    _horario ??
                                                    'Selecciona horario',
                                                onTap: _pickHorario,
                                                icon: Icons.schedule_rounded,
                                              ),
                                            ),
                                            _HrDialogField(
                                              width: 246,
                                              label: 'Dias que labora',
                                              child: _HrDialogPickerField(
                                                label: _diasLabora.isEmpty
                                                    ? 'Selecciona dias'
                                                    : _diasLabora.join(', '),
                                                onTap: _pickDiasLabora,
                                                icon: Icons
                                                    .calendar_view_week_rounded,
                                              ),
                                            ),
                                            _HrDialogField(
                                              width: 220,
                                              label: 'Fecha de ingreso',
                                              child: _HrDialogPickerField(
                                                label: _fechaIngreso == null
                                                    ? 'Selecciona fecha'
                                                    : _fmtHrDateLabel(
                                                        _fechaIngreso!,
                                                      ),
                                                onTap: _pickFechaIngreso,
                                                icon: Icons
                                                    .calendar_month_rounded,
                                              ),
                                            ),
                                            _HrDialogField(
                                              width: 220,
                                              label: 'Fecha de alta',
                                              child: _HrDialogPickerField(
                                                label: _fechaAlta == null
                                                    ? 'Selecciona fecha'
                                                    : _fmtHrDateLabel(
                                                        _fechaAlta!,
                                                      ),
                                                onTap: _pickFechaAlta,
                                                icon: Icons
                                                    .event_available_rounded,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (_additionalLaborSchedules
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Column(
                                            children: [
                                              for (
                                                var index = 0;
                                                index <
                                                    _additionalLaborSchedules
                                                        .length;
                                                index += 1
                                              ) ...[
                                                _HrLaborScheduleCard(
                                                  title: 'Jornada ${index + 2}',
                                                  schedule:
                                                      _additionalLaborSchedules[index],
                                                  onEdit: () =>
                                                      _editLaborSchedule(index),
                                                  onRemove: () =>
                                                      _removeLaborSchedule(
                                                        index,
                                                      ),
                                                ),
                                                if (index !=
                                                    _additionalLaborSchedules
                                                            .length -
                                                        1)
                                                  const SizedBox(height: 8),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _HrDialogSectionCard(
                                    title: 'Nomina',
                                    subtitle:
                                        'Datos operativos para calculo y dispersion.',
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        _HrDialogField(
                                          width: 240,
                                          label: 'No. de Cuenta',
                                          child: TextFormField(
                                            controller: _cuentaController,
                                            style: const TextStyle(
                                              color: Color(0xFF24103D),
                                            ),
                                            decoration:
                                                _hrDialogFieldDecoration(
                                                  context,
                                                  hintText: 'No. de Cuenta',
                                                ),
                                          ),
                                        ),
                                        _HrDialogField(
                                          width: 200,
                                          label: 'Salario',
                                          child: TextFormField(
                                            controller: _salarioController,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            style: const TextStyle(
                                              color: Color(0xFF24103D),
                                            ),
                                            decoration:
                                                _hrDialogFieldDecoration(
                                                  context,
                                                  hintText: 'Salario',
                                                ),
                                            validator: _requiredMoneyValidator,
                                          ),
                                        ),
                                        _HrDialogField(
                                          width: 220,
                                          label: 'Salario percibido',
                                          child: TextFormField(
                                            controller:
                                                _salarioRealPercibidoController,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            style: const TextStyle(
                                              color: Color(0xFF24103D),
                                            ),
                                            decoration:
                                                _hrDialogFieldDecoration(
                                                  context,
                                                  hintText: 'Salario percibido',
                                                ),
                                            validator: _requiredMoneyValidator,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _HrDialogSectionCard(
                                    title: 'Contacto y uniforme',
                                    subtitle:
                                        'Datos operativos complementarios del expediente.',
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        _HrDialogField(
                                          width: 180,
                                          label: 'Calzado',
                                          child: TextFormField(
                                            controller: _calzadoController,
                                            style: const TextStyle(
                                              color: Color(0xFF24103D),
                                            ),
                                            decoration:
                                                _hrDialogFieldDecoration(
                                                  context,
                                                  hintText: 'Calzado',
                                                ),
                                          ),
                                        ),
                                        _HrDialogField(
                                          width: 220,
                                          label: 'Talla de uniforme',
                                          child: TextFormField(
                                            controller:
                                                _tallaUniformeController,
                                            style: const TextStyle(
                                              color: Color(0xFF24103D),
                                            ),
                                            decoration:
                                                _hrDialogFieldDecoration(
                                                  context,
                                                  hintText: 'Talla de uniforme',
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _HrDialogSectionCard(
                          title: 'Expediente digital',
                          subtitle:
                              'Controla avance documental, foto y adjuntos del colaborador.',
                          trailing: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                style: _hrInvActionOutlinedButtonStyle(),
                                onPressed: () => setState(
                                  () => _showRequiredDocuments =
                                      !_showRequiredDocuments,
                                ),
                                icon: Icon(
                                  _showRequiredDocuments
                                      ? Icons.expand_less_rounded
                                      : Icons.description_outlined,
                                ),
                                label: Text(
                                  _showRequiredDocuments
                                      ? 'Ocultar requeridos'
                                      : 'Ver documentos requeridos',
                                ),
                              ),
                              OutlinedButton.icon(
                                style: _hrInvActionOutlinedButtonStyle(),
                                onPressed: () => setState(
                                  () => _showAdditionalAttachments =
                                      !_showAdditionalAttachments,
                                ),
                                icon: Icon(
                                  _showAdditionalAttachments
                                      ? Icons.expand_less_rounded
                                      : Icons.folder_open_rounded,
                                ),
                                label: Text(
                                  _showAdditionalAttachments
                                      ? 'Ocultar adjuntos'
                                      : 'Ver adjuntos adicionales',
                                ),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: progress.clamp(0.0, 1.0),
                                        minHeight: 12,
                                        backgroundColor: const Color(
                                          0xFFE8D8FF,
                                        ),
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Color(0xFF9F6BFF),
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    '$completedRequirements / $totalRequirements',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF24103D),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${(progress * 100).round()}% del expediente estructurado completo.',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6E47A8),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBFF),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0x44B084FF),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      color: Color(0xFF6E47A8),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _creditoDeclarado == null
                                            ? 'Falta declarar si el colaborador tiene credito Infonavit, Fonacot u otro.'
                                            : _creditoDeclarado == true
                                            ? 'Credito declarado. Puedes documentarlo desde los requeridos.'
                                            : 'Colaborador marcado sin credito declarado.',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF6E47A8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_showRequiredDocuments) ...[
                          const SizedBox(height: 12),
                          _HrDialogSectionCard(
                            title: 'Documentos requeridos',
                            subtitle:
                                'Checklist estructurado para medir integridad del expediente.',
                            child: Column(
                              children: [
                                _HrDialogInlineNote(
                                  icon: Icons.credit_score_rounded,
                                  message:
                                      'Declaracion de credito: ${_creditoDeclarado == null
                                          ? 'pendiente'
                                          : _creditoDeclarado == true
                                          ? 'con credito'
                                          : 'sin credito'}.',
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _HrChoiceChip(
                                      label: 'Pendiente',
                                      selected: _creditoDeclarado == null,
                                      onTap: () => setState(
                                        () => _creditoDeclarado = null,
                                      ),
                                    ),
                                    _HrChoiceChip(
                                      label: 'Sin credito',
                                      selected: _creditoDeclarado == false,
                                      onTap: () => setState(
                                        () => _creditoDeclarado = false,
                                      ),
                                    ),
                                    _HrChoiceChip(
                                      label: 'Con credito',
                                      selected: _creditoDeclarado == true,
                                      onTap: () => setState(
                                        () => _creditoDeclarado = true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _creditoDetalleController,
                                  minLines: 2,
                                  maxLines: 3,
                                  style: const TextStyle(
                                    color: Color(0xFF24103D),
                                  ),
                                  decoration: _hrDialogFieldDecoration(
                                    context,
                                    hintText:
                                        'Detalle del credito o nota interna de declaracion',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                for (final spec
                                    in _kHrExpedienteRequirements) ...[
                                  _buildRequirementTile(draft, spec),
                                  if (spec != _kHrExpedienteRequirements.last)
                                    const SizedBox(height: 10),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (_showAdditionalAttachments) ...[
                          const SizedBox(height: 12),
                          _HrDialogSectionCard(
                            title: 'Adjuntos adicionales',
                            subtitle:
                                'Responsivas, actas administrativas, prestaciones firmadas y otros soportes.',
                            trailing: FilledButton.icon(
                              style: contractSecondaryButtonStyle(context),
                              onPressed: _pickAdditionalFiles,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Subir archivos'),
                            ),
                            child: _additionalAttachments.isEmpty
                                ? Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      16,
                                      14,
                                      16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFF8F2FF,
                                      ).withValues(alpha: 0.92),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0x44B084FF),
                                      ),
                                    ),
                                    child: const Text(
                                      'Aun no hay adjuntos libres en este expediente.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF7D62A8),
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < _additionalAttachments.length;
                                        i++
                                      ) ...[
                                        _HrAttachmentTile(
                                          attachment: _additionalAttachments[i],
                                          onRemove: () =>
                                              _removeAdditionalAttachment(
                                                _additionalAttachments[i],
                                              ),
                                        ),
                                        if (i !=
                                            _additionalAttachments.length - 1)
                                          const SizedBox(height: 10),
                                      ],
                                    ],
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFE4FF).withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x55B084FF)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: _HrDialogInlineNote(
                          icon: Icons.info_outline_rounded,
                          message:
                              'Verifica la informacion antes de guardar. Podras seguir completando el expediente despues.',
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: _hrInvActionOutlinedButtonStyle(),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: contractPrimaryButtonStyle(context),
                        onPressed: _submit,
                        child: const Text('Guardar expediente'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Obligatorio';
    return null;
  }

  String? _requiredMoneyValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Obligatorio';
    return _optionalMoneyValidator(text);
  }

  Widget _buildRequirementTile(
    _HumanResourcesEmployeeRow draft,
    _HrExpedienteRequirementSpec spec,
  ) {
    final attachments = _attachmentsForRequirement(draft, spec.key);
    final isComplete = _isHrRequirementComplete(draft, spec);
    final statusLabel = isComplete
        ? 'Completo'
        : spec.kind == _HrExpedienteRequirementKind.upload
        ? 'Pendiente ${attachments.length}/${spec.minimumFiles}'
        : 'Pendiente';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete ? const Color(0x88B084FF) : const Color(0x44B084FF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF24103D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spec.detail,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7D62A8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _HrStatusChip(label: statusLabel, complete: isComplete),
            ],
          ),
          const SizedBox(height: 10),
          if (spec.kind == _HrExpedienteRequirementKind.upload) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: _hrInvActionOutlinedButtonStyle(),
                onPressed: () => _pickRequiredFiles(spec),
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(
                  spec.minimumFiles > 1
                      ? 'Subir archivos'
                      : attachments.isEmpty
                      ? 'Subir archivo'
                      : 'Agregar archivo',
                ),
              ),
            ),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              Column(
                children: [
                  for (var i = 0; i < attachments.length; i++) ...[
                    _HrAttachmentTile(
                      attachment: attachments[i],
                      onRemove: () => _removeRequiredAttachment(attachments[i]),
                    ),
                    if (i != attachments.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
            ],
          ] else ...[
            Text(
              switch (spec.kind) {
                _HrExpedienteRequirementKind.baseTelefono =>
                  draft.telefono.trim().isEmpty
                      ? 'Captura el telefono en datos base para completar este punto.'
                      : 'Dato base actual: ${draft.telefono}',
                _HrExpedienteRequirementKind.baseCuenta =>
                  draft.numeroCuenta.trim().isEmpty
                      ? 'Captura la cuenta de nomina en datos base si existe.'
                      : 'Dato base actual: ${draft.numeroCuenta}',
                _HrExpedienteRequirementKind.creditNotice =>
                  draft.creditoDeclarado == null
                      ? 'Declara si el colaborador reporto o no credito.'
                      : draft.creditoDeclarado == true
                      ? 'Colaborador con credito declarado.'
                      : 'Colaborador declarado sin credito.',
                _HrExpedienteRequirementKind.upload => '',
              },
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6E47A8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HrDialogField extends StatelessWidget {
  final double width;
  final String? label;
  final Widget child;

  const _HrDialogField({required this.width, required this.child, this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6E47A8),
              ),
            ),
            const SizedBox(height: 5),
          ],
          child,
        ],
      ),
    );
  }
}

class _HrDialogPickerField extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData icon;

  const _HrDialogPickerField({
    required this.label,
    required this.onTap,
    this.icon = Icons.arrow_drop_down_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: InputDecorator(
        decoration: _hrDialogFieldDecoration(context),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF24103D)),
              ),
            ),
            Icon(icon, size: 18, color: const Color(0xFF6E47A8)),
          ],
        ),
      ),
    );
  }
}

class _HrLaborScheduleCard extends StatelessWidget {
  final String title;
  final _HrLaborSchedule schedule;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _HrLaborScheduleCard({
    required this.title,
    required this.schedule,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x44B084FF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF24103D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  schedule.horario.trim().isEmpty
                      ? 'Horario pendiente'
                      : schedule.horario,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF24103D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  schedule.diasLabora.isEmpty
                      ? 'Dias pendientes'
                      : schedule.diasLabora.join(', '),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6E47A8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: onEdit,
            tooltip: 'Editar jornada',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF1E6FF),
              foregroundColor: const Color(0xFF6E47A8),
              side: const BorderSide(color: Color(0x55B084FF)),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.edit_rounded, size: 18),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Eliminar jornada',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFFFF1F6),
              foregroundColor: const Color(0xFFB24A75),
              side: const BorderSide(color: Color(0x55E5A8BF)),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _HrPassportPhotoCard extends StatelessWidget {
  final _HrEmployeeAttachment? photo;
  final VoidCallback onUpload;
  final VoidCallback? onRemove;
  final String nombre;
  final String id;
  final String empresa;
  final String nss;
  final String rfc;
  final String curp;
  final String statusLabel;
  final double progress;

  const _HrPassportPhotoCard({
    required this.photo,
    required this.onUpload,
    this.onRemove,
    required this.nombre,
    required this.id,
    required this.empresa,
    required this.nss,
    required this.rfc,
    required this.curp,
    required this.statusLabel,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return _HrDialogSectionCard(
      title: 'Ficha del colaborador',
      subtitle: 'Resumen identificador del expediente.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFFF0E4FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x55B084FF)),
            ),
            clipBehavior: Clip.antiAlias,
            child: photo?.bytes != null
                ? Image.memory(photo!.bytes!, fit: BoxFit.cover)
                : (photo != null && photo!.fileUrl.trim().isNotEmpty)
                ? Image.network(photo!.fileUrl, fit: BoxFit.cover)
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        size: 44,
                        color: Color(0xFF6E47A8),
                      ),
                      SizedBox(height: 12),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: Text(
                          'Selecciona una foto para el expediente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6E47A8),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            nombre.isEmpty ? 'Nombre pendiente' : nombre,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF24103D),
            ),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HrStatusChip(
                label: id.isEmpty ? 'ID pendiente' : 'ID #$id',
                complete: id.isNotEmpty,
              ),
              _HrStatusChip(
                label: empresa.isEmpty ? 'Empresa pendiente' : empresa,
                complete: empresa.isNotEmpty,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _HrSidebarDivider(),
          _HrSidebarDatum(label: 'Estado', value: statusLabel),
          _HrSidebarDatum(
            label: 'Avance',
            value: '${(progress * 100).round()}% completo',
          ),
          const _HrSidebarDivider(),
          _HrSidebarDatum(label: 'NSS', value: nss),
          _HrSidebarDatum(label: 'RFC', value: rfc),
          _HrSidebarDatum(label: 'CURP', value: curp),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: contractSecondaryButtonStyle(context),
            onPressed: onUpload,
            icon: const Icon(Icons.upload_rounded),
            label: Text(photo == null ? 'Subir foto' : 'Cambiar foto'),
          ),
          if (onRemove != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              style: _hrInvActionOutlinedButtonStyle(),
              onPressed: onRemove,
              child: const Text('Quitar'),
            ),
          ],
        ],
      ),
    );
  }
}

class _HrSidebarDivider extends StatelessWidget {
  const _HrSidebarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xFFE7DCFF),
    );
  }
}

class _HrSidebarDatum extends StatelessWidget {
  final String label;
  final String value;

  const _HrSidebarDatum({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final safeValue = value.trim().isEmpty ? 'Pendiente' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF6E47A8),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            safeValue,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF24103D),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrDialogSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _HrDialogSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E9FF).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x55B084FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF24103D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6E47A8),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _HrChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HrChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE7D4FF) : const Color(0xFFFFFBFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF7C4DFF) : const Color(0x66B084FF),
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: selected ? const Color(0xFF3B1F5C) : const Color(0xFF6E47A8),
          ),
        ),
      ),
    );
  }
}

class _HrStatusChip extends StatelessWidget {
  final String label;
  final bool complete;

  const _HrStatusChip({required this.label, required this.complete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: complete ? const Color(0xFFDCC5FF) : const Color(0xFFF7F0FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: complete ? const Color(0xFF9F6BFF) : const Color(0x44B084FF),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: complete ? const Color(0xFF24103D) : const Color(0xFF6E47A8),
        ),
      ),
    );
  }
}

class _HrAttachmentTile extends StatelessWidget {
  final _HrEmployeeAttachment attachment;
  final VoidCallback onRemove;

  const _HrAttachmentTile({required this.attachment, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x44B084FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE9DAFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              attachment.isImage
                  ? Icons.image_outlined
                  : Icons.picture_as_pdf_outlined,
              size: 20,
              color: const Color(0xFF6E47A8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF24103D),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_fmtHrDateLabel(attachment.uploadedAt)} · ${_hrAttachmentSizeLabel(attachment.sizeBytes)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7D62A8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Quitar archivo',
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFF6E47A8),
              backgroundColor: const Color(0xFFF1E6FF),
              side: const BorderSide(color: Color(0x44B084FF)),
            ),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _HrDialogInlineNote extends StatelessWidget {
  final IconData icon;
  final String message;

  const _HrDialogInlineNote({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6E47A8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6E47A8),
            ),
          ),
        ),
      ],
    );
  }
}

class _HrScheduleDraft {
  final TimeOfDay start;
  final TimeOfDay end;
  final TimeOfDay? lunchStart;
  final TimeOfDay? lunchEnd;

  const _HrScheduleDraft({
    required this.start,
    required this.end,
    this.lunchStart,
    this.lunchEnd,
  });

  String format() {
    final base = '${_fmtTimeOfDay(start)} - ${_fmtTimeOfDay(end)}';
    if (lunchStart == null || lunchEnd == null) return base;
    return '$base | comida ${_fmtTimeOfDay(lunchStart!)} - ${_fmtTimeOfDay(lunchEnd!)}';
  }
}

Future<List<String>?> _showHrWeekdaySelectionDialog(
  BuildContext context, {
  required List<String> initialValues,
}) {
  return showDialog<List<String>>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      final selected = <String>{...initialValues};
      return StatefulBuilder(
        builder: (context, setLocalState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: _hrFilterDialogDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dias que labora',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Selecciona los dias de la semana en los que se presenta.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final day in _kHrWeekdayOptions)
                          _HrChoiceChip(
                            label: day,
                            selected: selected.contains(day),
                            onTap: () => setLocalState(() {
                              if (!selected.add(day)) selected.remove(day);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        OutlinedButton(
                          style: _hrInvFilterOutlinedButtonStyle(),
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancelar'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () =>
                              setLocalState(() => selected.clear()),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withValues(
                              alpha: 0.78,
                            ),
                          ),
                          child: const Text('Limpiar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: _hrInvFilterFilledButtonStyle(),
                          onPressed: () => Navigator.pop(
                            dialogContext,
                            _kHrWeekdayOptions
                                .where(selected.contains)
                                .toList(growable: false),
                          ),
                          child: const Text('Aplicar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<_HrLaborSchedule?> _showHrLaborScheduleComposerDialog(
  BuildContext context, {
  _HrLaborSchedule? initialValue,
}) {
  return showDialog<_HrLaborSchedule>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      var horario = initialValue?.horario ?? '';
      var diasLabora = List<String>.of(initialValue?.diasLabora ?? const []);
      return StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> pickHorario() async {
            final value = await _showHrScheduleDialog(
              context,
              initialValue: horario,
            );
            if (value == null) return;
            setLocal(() => horario = value);
          }

          Future<void> pickDiasLabora() async {
            final value = await _showHrWeekdaySelectionDialog(
              context,
              initialValues: diasLabora,
            );
            if (value == null) return;
            setLocal(() => diasLabora = value);
          }

          return ContractDialogShell(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Container(
                width: 468,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F0FF).withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x66B084FF)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                initialValue == null
                                    ? 'Nueva jornada'
                                    : 'Editar jornada',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF24103D),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Define horario y dias laborables de una jornada adicional.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6E47A8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF1E6FF),
                            foregroundColor: const Color(0xFF6E47A8),
                            side: const BorderSide(color: Color(0x66B084FF)),
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _HrDialogField(
                      width: double.infinity,
                      label: 'Horario',
                      child: _HrDialogPickerField(
                        label: horario.trim().isEmpty
                            ? 'Selecciona horario'
                            : horario,
                        onTap: pickHorario,
                        icon: Icons.schedule_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _HrDialogField(
                      width: double.infinity,
                      label: 'Dias que labora',
                      child: _HrDialogPickerField(
                        label: diasLabora.isEmpty
                            ? 'Selecciona dias'
                            : diasLabora.join(', '),
                        onTap: pickDiasLabora,
                        icon: Icons.calendar_view_week_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: _hrInvActionOutlinedButtonStyle(),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: _hrInvFilterFilledButtonStyle(),
                          onPressed: horario.trim().isEmpty
                              ? null
                              : () => Navigator.of(dialogContext).pop(
                                  _HrLaborSchedule(
                                    horario: horario.trim(),
                                    diasLabora: List<String>.of(diasLabora),
                                  ),
                                ),
                          child: const Text('Guardar jornada'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

InputDecoration _hrDialogFieldDecoration(
  BuildContext context, {
  String? hintText,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: const Color(0x66B084FF)),
  );
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFF7D62A8),
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: const Color(0xFFFFFBFF),
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(
        color: humanResourcesAreaTokens.primary,
        width: 1.2,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  );
}

Future<TimeOfDay?> _showHrTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: humanResourcesAreaTokens.primary,
            onPrimary: Colors.white,
            surface: const Color(0xFFF6F0FF),
            onSurface: const Color(0xFF24103D),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: humanResourcesAreaTokens.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: const Color(0xFFF6F0FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0x66B084FF)),
            ),
            hourMinuteColor: const Color(0xFFEFE4FF),
            hourMinuteTextColor: const Color(0xFF24103D),
            dayPeriodTextColor: const Color(0xFF24103D),
            dayPeriodColor: const Color(0xFFEFE4FF),
            dialHandColor: humanResourcesAreaTokens.primary,
            dialBackgroundColor: const Color(0xFFF0E4FF),
            dialTextColor: const Color(0xFF24103D),
            entryModeIconColor: humanResourcesAreaTokens.primary,
            helpTextStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF24103D),
            ),
            hourMinuteTextStyle: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: const Color(0xFFF6F0FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Color(0x66B084FF)),
            ),
          ),
        ),
        child: child!,
      );
    },
  );
}

Future<String?> _showHrScheduleDialog(
  BuildContext context, {
  String? initialValue,
}) {
  final initialDraft = _parseHrSchedule(initialValue);
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      var draft = initialDraft;
      var includeLunch = draft.lunchStart != null && draft.lunchEnd != null;
      return StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> pickStart() async {
            final picked = await _showHrTimePicker(
              context,
              initialTime: draft.start,
            );
            if (picked == null) return;
            setLocal(
              () => draft = _HrScheduleDraft(
                start: picked,
                end: draft.end,
                lunchStart: draft.lunchStart,
                lunchEnd: draft.lunchEnd,
              ),
            );
          }

          Future<void> pickEnd() async {
            final picked = await _showHrTimePicker(
              context,
              initialTime: draft.end,
            );
            if (picked == null) return;
            setLocal(
              () => draft = _HrScheduleDraft(
                start: draft.start,
                end: picked,
                lunchStart: draft.lunchStart,
                lunchEnd: draft.lunchEnd,
              ),
            );
          }

          Future<void> pickLunchStart() async {
            final picked = await _showHrTimePicker(
              context,
              initialTime:
                  draft.lunchStart ?? const TimeOfDay(hour: 13, minute: 0),
            );
            if (picked == null) return;
            setLocal(
              () => draft = _HrScheduleDraft(
                start: draft.start,
                end: draft.end,
                lunchStart: picked,
                lunchEnd: draft.lunchEnd,
              ),
            );
          }

          Future<void> pickLunchEnd() async {
            final picked = await _showHrTimePicker(
              context,
              initialTime:
                  draft.lunchEnd ?? const TimeOfDay(hour: 14, minute: 0),
            );
            if (picked == null) return;
            setLocal(
              () => draft = _HrScheduleDraft(
                start: draft.start,
                end: draft.end,
                lunchStart: draft.lunchStart,
                lunchEnd: picked,
              ),
            );
          }

          return ContractDialogShell(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: AreaThemeScope(
                tokens: humanResourcesAreaTokens,
                child: Container(
                  width: 540,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F0FF).withValues(alpha: 0.98),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x66B084FF)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Horario laboral',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF24103D),
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Captura entrada, salida y tramo de comida opcional.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6E47A8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF1E6FF),
                              foregroundColor: const Color(0xFF6E47A8),
                              side: const BorderSide(color: Color(0x66B084FF)),
                            ),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _HrScheduleTimeButton(
                              label: 'Entrada',
                              value: _fmtTimeOfDay(draft.start),
                              onTap: pickStart,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _HrScheduleTimeButton(
                              label: 'Salida',
                              value: _fmtTimeOfDay(draft.end),
                              onTap: pickEnd,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: includeLunch,
                        activeThumbColor: humanResourcesAreaTokens.primary,
                        title: const Text(
                          'Incluir horario de comida',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF24103D),
                          ),
                        ),
                        subtitle: const Text(
                          'Permite guardar de tal a tal y de tal a tal.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6E47A8),
                          ),
                        ),
                        onChanged: (value) {
                          setLocal(() {
                            includeLunch = value;
                            draft = _HrScheduleDraft(
                              start: draft.start,
                              end: draft.end,
                              lunchStart: value
                                  ? (draft.lunchStart ??
                                        const TimeOfDay(hour: 13, minute: 0))
                                  : null,
                              lunchEnd: value
                                  ? (draft.lunchEnd ??
                                        const TimeOfDay(hour: 14, minute: 0))
                                  : null,
                            );
                          });
                        },
                      ),
                      if (includeLunch) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _HrScheduleTimeButton(
                                label: 'Comida inicio',
                                value: _fmtTimeOfDay(
                                  draft.lunchStart ??
                                      const TimeOfDay(hour: 13, minute: 0),
                                ),
                                onTap: pickLunchStart,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _HrScheduleTimeButton(
                                label: 'Comida fin',
                                value: _fmtTimeOfDay(
                                  draft.lunchEnd ??
                                      const TimeOfDay(hour: 14, minute: 0),
                                ),
                                onTap: pickLunchEnd,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x44B084FF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Vista previa',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF6E47A8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              draft.format(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF24103D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: _hrInvActionOutlinedButtonStyle(),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: _hrInvFilterFilledButtonStyle(),
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(draft.format()),
                            child: const Text('Aplicar horario'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

_HrScheduleDraft _parseHrSchedule(String? raw) {
  final normalized = (raw ?? '').trim();
  final pattern = RegExp(
    r'^(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2})(?:\s*\|\s*comida\s*(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2}))?$',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(normalized);
  if (match == null) {
    return const _HrScheduleDraft(
      start: TimeOfDay(hour: 8, minute: 0),
      end: TimeOfDay(hour: 17, minute: 0),
    );
  }
  return _HrScheduleDraft(
    start:
        _parseTimeOfDay(match.group(1)) ?? const TimeOfDay(hour: 8, minute: 0),
    end:
        _parseTimeOfDay(match.group(2)) ?? const TimeOfDay(hour: 17, minute: 0),
    lunchStart: _parseTimeOfDay(match.group(3)),
    lunchEnd: _parseTimeOfDay(match.group(4)),
  );
}

TimeOfDay? _parseTimeOfDay(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _fmtTimeOfDay(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _HrScheduleTimeButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _HrScheduleTimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x44B084FF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6E47A8),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF24103D),
                    ),
                  ),
                ),
                const Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: Color(0xFF6E47A8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HrHCellExpand extends StatelessWidget {
  final String text;
  final TextStyle style;
  final bool centered;
  final bool active;
  final VoidCallback? onFilter;

  const _HrHCellExpand(
    this.text,
    this.style, {
    this.centered = false,
    this.active = false,
    this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final filterIcon = onFilter == null
        ? const SizedBox(width: 21, height: 21)
        : InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onFilter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: active
                    ? humanResourcesAreaTokens.primary
                    : const Color(0xFFE7D8FF).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active
                      ? humanResourcesAreaTokens.primary
                      : const Color(0xFF6E47A8).withValues(alpha: 0.26),
                ),
              ),
              child: Icon(
                active ? Icons.filter_alt : Icons.filter_alt_outlined,
                size: 15,
                color: active ? Colors.white : const Color(0xFF6E47A8),
              ),
            ),
          );
    return Row(
      children: [
        filterIcon,
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: style,
            maxLines: 1,
            textAlign: centered ? TextAlign.center : TextAlign.left,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _HrFitText extends StatelessWidget {
  final String text;
  final bool centered;

  const _HrFitText(this.text, {this.centered = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Align(
        alignment: centered ? Alignment.center : Alignment.centerLeft,
        child: Text(
          text.isEmpty ? '—' : text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

InputDecoration _hrInvGlassFieldDecoration({String? hintText}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: const Color(0x66B084FF), width: 1),
  );
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(
      color: const Color(0xFF6E47A8).withValues(alpha: 0.72),
      fontWeight: FontWeight.w400,
    ),
    isDense: true,
    filled: true,
    fillColor: const Color(0xFFF7F1FF).withValues(alpha: 0.96),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(
        color: humanResourcesAreaTokens.primary.withValues(alpha: 0.86),
        width: 1.2,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  );
}

BoxDecoration _hrFilterDialogDecoration() {
  return BoxDecoration(
    color: const Color(0xEE1D112F),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.26),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

ButtonStyle _hrInvActionOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF24103D),
    side: const BorderSide(color: Color(0x66B084FF)),
    backgroundColor: const Color(0xFFF4ECFF).withValues(alpha: 0.82),
  );
}

ButtonStyle _hrInvFilterOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFFF1E7FF),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
    backgroundColor: const Color(0xFF34204E).withValues(alpha: 0.72),
  );
}

ButtonStyle _hrInvFilterFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: humanResourcesAreaTokens.primary,
    foregroundColor: Colors.white,
  );
}

String _fmtHrInt(int value) {
  final s = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final remaining = s.length - i;
    buffer.write(s[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _normalizeHrMoneyInput(String value) {
  final trimmed = value.trim().replaceAll(',', '');
  if (trimmed.isEmpty) return '';
  final parsed = double.tryParse(trimmed);
  if (parsed == null) return trimmed;
  return parsed.toStringAsFixed(2);
}

bool _sameHrStringList(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<String> _parseHrDiasLaboraValue(Object? value) {
  if (value == null) return const <String>[];
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final text = value.toString().trim();
  if (text.isEmpty) return const <String>[];
  return text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<_HrLaborSchedule> _parseHrLaborSchedulesValue(
  Object? value, {
  String fallbackHorario = '',
  List<String> fallbackDiasLabora = const <String>[],
}) {
  final parsed = <_HrLaborSchedule>[];
  if (value is List) {
    for (final item in value) {
      if (item is Map) {
        final schedule = _HrLaborSchedule.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (schedule.isMeaningful) parsed.add(schedule);
      }
    }
  }
  if (parsed.isNotEmpty) return parsed;
  final fallback = _HrLaborSchedule(
    horario: fallbackHorario,
    diasLabora: fallbackDiasLabora,
  );
  return fallback.isMeaningful ? <_HrLaborSchedule>[fallback] : const [];
}

double? _hrDbMoneyValue(String value) {
  final normalized = _normalizeHrMoneyInput(value);
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

String _hrDbNumericToText(Object? value) {
  if (value == null) return '';
  if (value is num) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }
  final text = value.toString().trim();
  if (text.isEmpty) return '';
  final parsed = double.tryParse(text.replaceAll(',', ''));
  if (parsed == null) return text;
  if (parsed == parsed.roundToDouble()) return parsed.toInt().toString();
  return parsed.toStringAsFixed(2);
}

class _HrDateFilterDialogResult {
  final DateTimeRange? range;
  final bool clear;

  const _HrDateFilterDialogResult({this.range, this.clear = false});
}

Future<_HrDateFilterDialogResult?> _showHrDateRangeFilterDialog(
  BuildContext context, {
  required String label,
  required DateTimeRange bounds,
  DateTimeRange? initialRange,
}) {
  return showDialog<_HrDateFilterDialogResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      DateTime displayMonth = DateTime(
        (initialRange?.start ?? bounds.start).year,
        (initialRange?.start ?? bounds.start).month,
      );
      DateTime? start = initialRange?.start;
      DateTime? end = initialRange?.end;
      DateTime? hover;

      bool isSameDay(DateTime a, DateTime b) =>
          a.year == b.year && a.month == b.month && a.day == b.day;
      DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
      bool withinBounds(DateTime day) {
        final d = dateOnly(day);
        return !d.isBefore(dateOnly(bounds.start)) &&
            !d.isAfter(dateOnly(bounds.end));
      }

      return StatefulBuilder(
        builder: (context, setLocalState) {
          final monthFirst = DateTime(displayMonth.year, displayMonth.month, 1);
          final leading = (monthFirst.weekday + 6) % 7;
          final gridStart = monthFirst.subtract(Duration(days: leading));
          final rangePreviewEnd = end ?? hover;

          bool inPreviewRange(DateTime day) {
            if (start == null || rangePreviewEnd == null) return false;
            final a = dateOnly(start!);
            final b = dateOnly(rangePreviewEnd);
            final from = a.isBefore(b) ? a : b;
            final to = a.isBefore(b) ? b : a;
            final d = dateOnly(day);
            return !d.isBefore(from) && !d.isAfter(to);
          }

          _HrDateFilterDialogResult? buildApplyResult() {
            if (start == null) return null;
            final s = dateOnly(start!);
            final e = dateOnly(end ?? start!);
            final from = s.isBefore(e) ? s : e;
            final to = s.isBefore(e) ? e : s;
            return _HrDateFilterDialogResult(
              range: DateTimeRange(start: from, end: to),
            );
          }

          return Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.pop(dialogContext);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                final applyResult = buildApplyResult();
                if (applyResult != null) {
                  Navigator.pop(dialogContext, applyResult);
                }
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      decoration: _hrFilterDialogDecoration(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtro: $label',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setLocalState(
                                  () => displayMonth = DateTime(
                                    displayMonth.year,
                                    displayMonth.month - 1,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.chevron_left,
                                  color: Colors.white,
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '${_hrMonthNameEs(monthFirst.month)[0].toUpperCase()}${_hrMonthNameEs(monthFirst.month).substring(1)} ${monthFirst.year}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setLocalState(
                                  () => displayMonth = DateTime(
                                    displayMonth.year,
                                    displayMonth.month + 1,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: const [
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'L',
                                    style: TextStyle(color: Color(0xFFF1E7FF)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'M',
                                    style: TextStyle(color: Color(0xFFF1E7FF)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'M',
                                    style: TextStyle(color: Color(0xFFF1E7FF)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'J',
                                    style: TextStyle(color: Color(0xFFF1E7FF)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'V',
                                    style: TextStyle(color: Color(0xFFF1E7FF)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'S',
                                    style: TextStyle(color: Color(0xFFF1E7FF)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'D',
                                    style: TextStyle(color: Color(0xFFF1E7FF)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 250,
                            child: Column(
                              children: List.generate(6, (row) {
                                return Expanded(
                                  child: Row(
                                    children: List.generate(7, (col) {
                                      final day = gridStart.add(
                                        Duration(days: row * 7 + col),
                                      );
                                      final inMonth =
                                          day.month == displayMonth.month;
                                      final allowed = withinBounds(day);
                                      final selectedStart =
                                          start != null &&
                                          isSameDay(day, start!);
                                      final selectedEnd =
                                          end != null && isSameDay(day, end!);
                                      final inRange = inPreviewRange(day);
                                      final active =
                                          selectedStart || selectedEnd;
                                      final bgColor = active
                                          ? humanResourcesAreaTokens.primary
                                          : inRange
                                          ? humanResourcesAreaTokens.primarySoft
                                                .withValues(alpha: 0.8)
                                          : Colors.transparent;

                                      final txtColor = active
                                          ? Colors.white
                                          : !allowed
                                          ? Colors.white38
                                          : inMonth
                                          ? const Color(0xFFF1E7FF)
                                          : Colors.white54;

                                      return Expanded(
                                        child: MouseRegion(
                                          onHover: (_) {
                                            if (start != null &&
                                                end == null &&
                                                allowed) {
                                              setLocalState(
                                                () => hover = dateOnly(day),
                                              );
                                            }
                                          },
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: !allowed
                                                ? null
                                                : () {
                                                    final picked = dateOnly(
                                                      day,
                                                    );
                                                    setLocalState(() {
                                                      if (start == null ||
                                                          end != null) {
                                                        start = picked;
                                                        end = null;
                                                        hover = null;
                                                        return;
                                                      }
                                                      if (picked.isBefore(
                                                        start!,
                                                      )) {
                                                        start = picked;
                                                        hover = null;
                                                        return;
                                                      }
                                                      end = picked;
                                                      hover = null;
                                                    });
                                                  },
                                            child: Container(
                                              margin: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: bgColor,
                                                borderRadius:
                                                    BorderRadius.circular(9),
                                                border: inRange && !active
                                                    ? Border.all(
                                                        color:
                                                            humanResourcesAreaTokens
                                                                .primary
                                                                .withValues(
                                                                  alpha: 0.35,
                                                                ),
                                                      )
                                                    : null,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${day.day}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: active
                                                        ? FontWeight.w800
                                                        : FontWeight.w600,
                                                    color: txtColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            start == null
                                ? 'Selecciona fecha inicial'
                                : end == null
                                ? 'Mueve el mouse y selecciona fecha final'
                                : '${_fmtHrDateLabel(start!)} - ${_fmtHrDateLabel(end!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE7D8FF),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                style: _hrInvFilterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: _hrInvFilterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(
                                  dialogContext,
                                  const _HrDateFilterDialogResult(clear: true),
                                ),
                                child: const Text('Limpiar'),
                              ),
                              const SizedBox(width: 6),
                              FilledButton(
                                style: _hrInvFilterFilledButtonStyle(),
                                onPressed: start == null
                                    ? null
                                    : () => Navigator.pop(
                                        dialogContext,
                                        buildApplyResult(),
                                      ),
                                child: const Text('Aplicar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<DateTime?> _showHrSingleDateDialog(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required String title,
}) {
  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      DateTime displayMonth = DateTime(initialDate.year, initialDate.month);
      DateTime selected = DateUtils.dateOnly(initialDate);

      bool isSameDay(DateTime a, DateTime b) =>
          a.year == b.year && a.month == b.month && a.day == b.day;
      DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
      bool withinBounds(DateTime day) {
        final d = dateOnly(day);
        return !d.isBefore(dateOnly(firstDate)) &&
            !d.isAfter(dateOnly(lastDate));
      }

      return StatefulBuilder(
        builder: (context, setLocalState) {
          final monthFirst = DateTime(displayMonth.year, displayMonth.month, 1);
          final leading = (monthFirst.weekday + 6) % 7;
          final gridStart = monthFirst.subtract(Duration(days: leading));

          return Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.pop(dialogContext);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                Navigator.pop(dialogContext, selected);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      decoration: _hrFilterDialogDecoration(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setLocalState(
                                  () => displayMonth = DateTime(
                                    displayMonth.year,
                                    displayMonth.month - 1,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.chevron_left,
                                  color: Colors.white,
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '${_hrMonthNameEs(monthFirst.month)[0].toUpperCase()}${_hrMonthNameEs(monthFirst.month).substring(1)} ${monthFirst.year}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setLocalState(
                                  () => displayMonth = DateTime(
                                    displayMonth.year,
                                    displayMonth.month + 1,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: const [
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'L',
                                    style: TextStyle(color: Color(0xFFF1E7FF)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'M',
                                    style: TextStyle(color: Color(0xFFF1E7FF)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'M',
                                    style: TextStyle(color: Color(0xFFF1E7FF)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'J',
                                    style: TextStyle(color: Color(0xFFF1E7FF)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'V',
                                    style: TextStyle(color: Color(0xFFF1E7FF)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'S',
                                    style: TextStyle(color: Color(0xFFF1E7FF)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'D',
                                    style: TextStyle(color: Color(0xFFF1E7FF)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 250,
                            child: Column(
                              children: List.generate(6, (row) {
                                return Expanded(
                                  child: Row(
                                    children: List.generate(7, (col) {
                                      final day = gridStart.add(
                                        Duration(days: row * 7 + col),
                                      );
                                      final inMonth =
                                          day.month == displayMonth.month;
                                      final allowed = withinBounds(day);
                                      final active = isSameDay(day, selected);
                                      return Expanded(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: !allowed
                                              ? null
                                              : () => setLocalState(
                                                  () =>
                                                      selected = dateOnly(day),
                                                ),
                                          child: Container(
                                            margin: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: active
                                                  ? humanResourcesAreaTokens
                                                        .primary
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                              border: active
                                                  ? Border.all(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.7,
                                                          ),
                                                    )
                                                  : null,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${day.day}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: active
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                  color: active
                                                      ? Colors.white
                                                      : !allowed
                                                      ? Colors.white38
                                                      : inMonth
                                                      ? const Color(0xFFF1E7FF)
                                                      : Colors.white54,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _fmtHrDateLabel(selected),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE7D8FF),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                style: _hrInvFilterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: _hrInvFilterFilledButtonStyle(),
                                onPressed: () =>
                                    Navigator.pop(dialogContext, selected),
                                child: const Text('Aplicar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

String _fmtHrDateLabel(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

DateTime? _tryParseHrDbDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

String _fmtHrDbDate(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

String? _optionalMoneyValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  return double.tryParse(text.replaceAll(',', '')) == null
      ? 'Numero invalido'
      : null;
}

String _hrMonthNameEs(int month) {
  const months = <String>[
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  return months[(month - 1).clamp(0, 11)];
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
  final String id;
  final String label;
  final double width;
  final bool centered;
  final bool filterable;

  const _HumanResourcesGridColumn({
    required this.id,
    required this.label,
    required this.width,
    this.centered = false,
    this.filterable = true,
  });
}

const List<_HumanResourcesGridColumn> _kGridColumns =
    <_HumanResourcesGridColumn>[
      _HumanResourcesGridColumn(
        id: 'id',
        label: 'ID',
        width: _kHrPersonnelIdW,
        centered: true,
      ),
      _HumanResourcesGridColumn(
        id: 'nombre',
        label: 'Nombre',
        width: _kHrPersonnelNameW,
      ),
      _HumanResourcesGridColumn(
        id: 'empresa',
        label: 'Empresa',
        width: _kHrPersonnelCompanyW,
      ),
      _HumanResourcesGridColumn(
        id: 'horario',
        label: 'Horario',
        width: _kHrPersonnelScheduleW,
        centered: true,
      ),
      _HumanResourcesGridColumn(
        id: 'fecha_ingreso',
        label: 'Fecha de ingreso',
        width: _kHrPersonnelIngresoW,
        centered: true,
      ),
      _HumanResourcesGridColumn(
        id: 'acciones',
        label: 'Acciones',
        width: _kHrActionsW,
        centered: true,
        filterable: false,
      ),
    ];

class _HrEmployeeAttachment {
  final String id;
  final String title;
  final String fileName;
  final Uint8List? bytes;
  final String fileUrl;
  final String? storagePath;
  final String mimeType;
  final int sizeBytes;
  final String? uploadedBy;
  final String uploadedByName;
  final DateTime uploadedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String categoryKey;
  final String categoryLabel;

  const _HrEmployeeAttachment({
    required this.id,
    required this.title,
    required this.fileName,
    required this.bytes,
    required this.fileUrl,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.uploadedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.categoryKey,
    required this.categoryLabel,
  });

  _HrEmployeeAttachment copyWith({
    String? id,
    String? title,
    String? fileName,
    Uint8List? bytes,
    String? fileUrl,
    String? storagePath,
    String? mimeType,
    int? sizeBytes,
    String? uploadedBy,
    String? uploadedByName,
    DateTime? uploadedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? categoryKey,
    String? categoryLabel,
  }) {
    return _HrEmployeeAttachment(
      id: id ?? this.id,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      bytes: bytes ?? this.bytes,
      fileUrl: fileUrl ?? this.fileUrl,
      storagePath: storagePath ?? this.storagePath,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedByName: uploadedByName ?? this.uploadedByName,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categoryKey: categoryKey ?? this.categoryKey,
      categoryLabel: categoryLabel ?? this.categoryLabel,
    );
  }

  bool get isImage {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic');
  }
}

class _HrLaborSchedule {
  final String horario;
  final List<String> diasLabora;

  const _HrLaborSchedule({
    required this.horario,
    this.diasLabora = const <String>[],
  });

  Map<String, dynamic> toJson() => {
    'horario': horario,
    'dias_labora': diasLabora,
  };

  static _HrLaborSchedule fromJson(Map<String, dynamic> json) {
    return _HrLaborSchedule(
      horario: (json['horario'] ?? '').toString(),
      diasLabora: _parseHrDiasLaboraValue(json['dias_labora']),
    );
  }

  _HrLaborSchedule copyWith({String? horario, List<String>? diasLabora}) {
    return _HrLaborSchedule(
      horario: horario ?? this.horario,
      diasLabora: diasLabora ?? List<String>.of(this.diasLabora),
    );
  }

  bool get isMeaningful =>
      horario.trim().isNotEmpty ||
      diasLabora.any((day) => day.trim().isNotEmpty);
}

class _HumanResourcesEmployeeRow {
  final String id;
  final String nombre;
  final String empresa;
  final String horario;
  final List<String> diasLabora;
  final String nss;
  final String rfc;
  final String curp;
  final String fechaIngreso;
  final String fechaAlta;
  final String telefono;
  final String numeroCuenta;
  final String salario;
  final String salarioRealPercibido;
  final String calzado;
  final String tallaUniforme;
  final List<_HrLaborSchedule> laborSchedules;
  final _HrEmployeeAttachment? photo;
  final bool? creditoDeclarado;
  final String creditoDetalle;
  final List<_HrEmployeeAttachment> requiredAttachments;
  final List<_HrEmployeeAttachment> additionalAttachments;

  const _HumanResourcesEmployeeRow({
    required this.id,
    required this.nombre,
    required this.empresa,
    required this.horario,
    this.diasLabora = const <String>[],
    required this.nss,
    required this.rfc,
    required this.curp,
    required this.fechaIngreso,
    this.fechaAlta = '',
    required this.telefono,
    required this.numeroCuenta,
    this.salario = '',
    this.salarioRealPercibido = '',
    required this.calzado,
    this.tallaUniforme = '',
    this.laborSchedules = const <_HrLaborSchedule>[],
    this.photo,
    this.creditoDeclarado,
    this.creditoDetalle = '',
    this.requiredAttachments = const <_HrEmployeeAttachment>[],
    this.additionalAttachments = const <_HrEmployeeAttachment>[],
  });

  _HumanResourcesEmployeeRow copyWithColumn(String columnId, String value) {
    switch (columnId) {
      case 'nombre':
        return value == nombre ? this : copyWith(nombre: value);
      case 'empresa':
        return value == empresa ? this : copyWith(empresa: value);
      case 'horario':
        return value == horario ? this : copyWith(horario: value);
      case 'dias_labora':
        final normalized = _parseHrDiasLaboraValue(value);
        return _sameHrStringList(normalized, diasLabora)
            ? this
            : copyWith(diasLabora: normalized);
      case 'nss':
        return value == nss ? this : copyWith(nss: value);
      case 'rfc':
        return value == rfc ? this : copyWith(rfc: value);
      case 'curp':
        return value == curp ? this : copyWith(curp: value);
      case 'fecha_ingreso':
        return value == fechaIngreso ? this : copyWith(fechaIngreso: value);
      case 'fecha_alta':
        return value == fechaAlta ? this : copyWith(fechaAlta: value);
      case 'telefono':
        return value == telefono ? this : copyWith(telefono: value);
      case 'numero_cuenta':
        return value == numeroCuenta ? this : copyWith(numeroCuenta: value);
      case 'salario':
        return value == salario ? this : copyWith(salario: value);
      case 'salario_real_percibido':
        return value == salarioRealPercibido
            ? this
            : copyWith(salarioRealPercibido: value);
      case 'calzado':
        return value == calzado ? this : copyWith(calzado: value);
      case 'talla_uniforme':
        return value == tallaUniforme ? this : copyWith(tallaUniforme: value);
      default:
        return this;
    }
  }

  _HumanResourcesEmployeeRow copyWith({
    String? id,
    String? nombre,
    String? empresa,
    String? horario,
    List<String>? diasLabora,
    String? nss,
    String? rfc,
    String? curp,
    String? fechaIngreso,
    String? fechaAlta,
    String? telefono,
    String? numeroCuenta,
    String? salario,
    String? salarioRealPercibido,
    String? calzado,
    String? tallaUniforme,
    List<_HrLaborSchedule>? laborSchedules,
    _HrEmployeeAttachment? photo,
    bool? creditoDeclarado,
    String? creditoDetalle,
    List<_HrEmployeeAttachment>? requiredAttachments,
    List<_HrEmployeeAttachment>? additionalAttachments,
  }) {
    return _HumanResourcesEmployeeRow(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      empresa: empresa ?? this.empresa,
      horario: horario ?? this.horario,
      diasLabora: diasLabora ?? List<String>.of(this.diasLabora),
      nss: nss ?? this.nss,
      rfc: rfc ?? this.rfc,
      curp: curp ?? this.curp,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
      fechaAlta: fechaAlta ?? this.fechaAlta,
      telefono: telefono ?? this.telefono,
      numeroCuenta: numeroCuenta ?? this.numeroCuenta,
      salario: salario ?? this.salario,
      salarioRealPercibido: salarioRealPercibido ?? this.salarioRealPercibido,
      calzado: calzado ?? this.calzado,
      tallaUniforme: tallaUniforme ?? this.tallaUniforme,
      laborSchedules:
          laborSchedules ?? List<_HrLaborSchedule>.of(this.laborSchedules),
      photo: photo ?? this.photo,
      creditoDeclarado: creditoDeclarado ?? this.creditoDeclarado,
      creditoDetalle: creditoDetalle ?? this.creditoDetalle,
      requiredAttachments:
          requiredAttachments ??
          List<_HrEmployeeAttachment>.of(this.requiredAttachments),
      additionalAttachments:
          additionalAttachments ??
          List<_HrEmployeeAttachment>.of(this.additionalAttachments),
    );
  }

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

List<_HrEmployeeAttachment> _attachmentsForRequirement(
  _HumanResourcesEmployeeRow row,
  String requirementKey,
) {
  return row.requiredAttachments
      .where((attachment) => attachment.categoryKey == requirementKey)
      .toList(growable: false);
}

bool _isHrRequirementComplete(
  _HumanResourcesEmployeeRow row,
  _HrExpedienteRequirementSpec spec,
) {
  switch (spec.kind) {
    case _HrExpedienteRequirementKind.baseTelefono:
      return row.telefono.trim().isNotEmpty;
    case _HrExpedienteRequirementKind.baseCuenta:
      return row.numeroCuenta.trim().isNotEmpty;
    case _HrExpedienteRequirementKind.creditNotice:
      return row.creditoDeclarado != null;
    case _HrExpedienteRequirementKind.upload:
      return _attachmentsForRequirement(row, spec.key).length >=
          spec.minimumFiles;
  }
}

int _completedHrRequirementCount(_HumanResourcesEmployeeRow row) {
  var completed = 0;
  for (final spec in _kHrExpedienteRequirements) {
    if (_isHrRequirementComplete(row, spec)) completed += 1;
  }
  return completed;
}

double _hrExpedienteProgress(_HumanResourcesEmployeeRow row) {
  if (_kHrExpedienteRequirements.isEmpty) return 0;
  return _completedHrRequirementCount(row) / _kHrExpedienteRequirements.length;
}

String _hrExpedienteStatusLabel(double progress) {
  if (progress >= 1) return 'Expediente completo';
  if (progress <= 0) return 'Expediente pendiente';
  return 'Expediente incompleto';
}

int _compareHrEmployeeRowsById(
  _HumanResourcesEmployeeRow a,
  _HumanResourcesEmployeeRow b,
) {
  final aInt = int.tryParse(a.id);
  final bInt = int.tryParse(b.id);
  if (aInt != null && bInt != null) return aInt.compareTo(bInt);
  if (aInt != null) return -1;
  if (bInt != null) return 1;
  return a.id.compareTo(b.id);
}

class _HrPersonnelStore {
  static Future<List<_HumanResourcesEmployeeRow>> loadEmployees() async {
    final profileRows = await fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from(_kHrEmployeeProfilesTable)
          .select()
          .order('id')
          .range(from, to),
    );
    final documentRows = await fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from(_kHrEmployeeDocumentsTable)
          .select()
          .order('uploaded_at', ascending: false)
          .order('created_at', ascending: false)
          .range(from, to),
    );

    final docsByEmployeeId = <String, List<_HrEmployeeAttachment>>{};
    for (final raw in documentRows) {
      final map = Map<String, dynamic>.from(raw);
      final ownerId = (map['employee_id'] ?? '').toString();
      if (ownerId.isEmpty) continue;
      docsByEmployeeId
          .putIfAbsent(ownerId, () => <_HrEmployeeAttachment>[])
          .add(_hrAttachmentFromRemoteRow(map));
    }

    return profileRows
        .map((raw) => Map<String, dynamic>.from(raw))
        .map((row) {
          final employeeId = (row['id'] ?? '').toString();
          final documents =
              docsByEmployeeId[employeeId] ?? const <_HrEmployeeAttachment>[];
          return _HumanResourcesEmployeeRow(
            id: employeeId,
            nombre: (row['nombre'] ?? '').toString(),
            empresa: (row['empresa'] ?? '').toString(),
            horario: (row['horario'] ?? '').toString(),
            diasLabora: _parseHrDiasLaboraValue(row['dias_labora']),
            laborSchedules: _parseHrLaborSchedulesValue(
              row['labor_schedules'],
              fallbackHorario: (row['horario'] ?? '').toString(),
              fallbackDiasLabora: _parseHrDiasLaboraValue(row['dias_labora']),
            ),
            nss: (row['nss'] ?? '').toString(),
            rfc: (row['rfc'] ?? '').toString(),
            curp: (row['curp'] ?? '').toString(),
            fechaIngreso: (row['fecha_ingreso'] ?? '').toString(),
            fechaAlta: (row['fecha_alta'] ?? '').toString(),
            telefono: (row['telefono'] ?? '').toString(),
            numeroCuenta: (row['numero_cuenta'] ?? '').toString(),
            salario: _hrDbNumericToText(row['salario']),
            salarioRealPercibido: _hrDbNumericToText(
              row['salario_real_percibido'],
            ),
            calzado: (row['calzado'] ?? '').toString(),
            tallaUniforme: (row['talla_uniforme'] ?? '').toString(),
            creditoDeclarado: row['credito_declarado'] as bool?,
            creditoDetalle: (row['credito_detalle'] ?? '').toString(),
            photo: _hrPhotoFromProfileRow(row),
            requiredAttachments: documents
                .where((doc) => doc.categoryKey != 'adicional')
                .toList(growable: false),
            additionalAttachments: documents
                .where((doc) => doc.categoryKey == 'adicional')
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  static Future<_HumanResourcesEmployeeRow> upsertEmployee(
    _HumanResourcesEmployeeRow row, {
    String? originalId,
  }) async {
    final client = Supabase.instance.client;
    final sourceEmployeeId = (originalId == null || originalId == row.id)
        ? row.id
        : originalId;
    final existingDocumentsRows = await client
        .from(_kHrEmployeeDocumentsTable)
        .select()
        .eq('employee_id', sourceEmployeeId);
    final existingDocuments = (existingDocumentsRows as List)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .map(_hrAttachmentFromRemoteRow)
        .toList(growable: false);

    _HrEmployeeAttachment? photo = row.photo;
    if (photo != null && photo.fileUrl.trim().isEmpty) {
      photo = await _uploadAttachment(
        employeeId: row.id,
        attachment: photo,
        segment: 'photo',
      );
    }

    final syncedRequired = <_HrEmployeeAttachment>[];
    for (final attachment in row.requiredAttachments) {
      if (attachment.fileUrl.trim().isNotEmpty) {
        syncedRequired.add(attachment);
      } else {
        syncedRequired.add(
          await _uploadAttachment(
            employeeId: row.id,
            attachment: attachment,
            segment: 'required',
          ),
        );
      }
    }

    final syncedAdditional = <_HrEmployeeAttachment>[];
    for (final attachment in row.additionalAttachments) {
      if (attachment.fileUrl.trim().isNotEmpty) {
        syncedAdditional.add(attachment);
      } else {
        syncedAdditional.add(
          await _uploadAttachment(
            employeeId: row.id,
            attachment: attachment,
            segment: 'additional',
          ),
        );
      }
    }

    final syncedRow = row.copyWith(
      photo: photo,
      requiredAttachments: syncedRequired,
      additionalAttachments: syncedAdditional,
    );

    final currentDocIds = {
      ...syncedRequired.map((doc) => doc.id),
      ...syncedAdditional.map((doc) => doc.id),
    };
    final removedDocs = existingDocuments
        .where((doc) => !currentDocIds.contains(doc.id))
        .toList(growable: false);
    for (final doc in removedDocs) {
      if (doc.storagePath != null && doc.storagePath!.isNotEmpty) {
        await client.storage.from(_kHrEmployeeFilesBucket).remove([
          doc.storagePath!,
        ]);
      }
    }
    if (removedDocs.isNotEmpty) {
      await client
          .from(_kHrEmployeeDocumentsTable)
          .delete()
          .eq('employee_id', sourceEmployeeId)
          .inFilter('id', removedDocs.map((doc) => doc.id).toList());
    }

    final oldProfileRows = await client
        .from(_kHrEmployeeProfilesTable)
        .select('photo_storage_path')
        .eq('id', sourceEmployeeId)
        .limit(1);
    final oldPhotoPath = (oldProfileRows as List).isNotEmpty
        ? Map<String, dynamic>.from(
            oldProfileRows.first as Map,
          )['photo_storage_path']?.toString()
        : null;
    if (photo == null && oldPhotoPath != null && oldPhotoPath.isNotEmpty) {
      await client.storage.from(_kHrEmployeeFilesBucket).remove([oldPhotoPath]);
    } else if (photo != null &&
        oldPhotoPath != null &&
        oldPhotoPath.isNotEmpty &&
        oldPhotoPath != photo.storagePath) {
      await client.storage.from(_kHrEmployeeFilesBucket).remove([oldPhotoPath]);
    }

    await client.from(_kHrEmployeeProfilesTable).upsert(<String, dynamic>{
      'id': syncedRow.id,
      'nombre': syncedRow.nombre,
      'empresa': syncedRow.empresa,
      'horario': syncedRow.horario,
      'dias_labora': syncedRow.diasLabora,
      'labor_schedules': syncedRow.laborSchedules
          .where((schedule) => schedule.isMeaningful)
          .map((schedule) => schedule.toJson())
          .toList(growable: false),
      'nss': syncedRow.nss,
      'rfc': syncedRow.rfc,
      'curp': syncedRow.curp,
      'fecha_ingreso': syncedRow.fechaIngreso,
      'fecha_alta': syncedRow.fechaAlta.trim().isEmpty
          ? null
          : syncedRow.fechaAlta,
      'telefono': syncedRow.telefono,
      'numero_cuenta': syncedRow.numeroCuenta,
      'salario': _hrDbMoneyValue(syncedRow.salario),
      'salario_real_percibido': _hrDbMoneyValue(syncedRow.salarioRealPercibido),
      'calzado': syncedRow.calzado,
      'talla_uniforme': syncedRow.tallaUniforme,
      'credito_declarado': syncedRow.creditoDeclarado,
      'credito_detalle': syncedRow.creditoDetalle.trim().isEmpty
          ? null
          : syncedRow.creditoDetalle.trim(),
      'photo_file_url': photo?.fileUrl,
      'photo_storage_path': photo?.storagePath,
      'photo_file_name': photo?.fileName,
      'photo_mime_type': photo?.mimeType,
      'photo_uploaded_at': photo?.uploadedAt.toIso8601String(),
    });

    final docsToUpsert = [
      ...syncedRequired.map(
        (doc) => _hrDocumentToInsertJson(doc, employeeId: row.id),
      ),
      ...syncedAdditional.map(
        (doc) => _hrDocumentToInsertJson(doc, employeeId: row.id),
      ),
    ];
    if (docsToUpsert.isNotEmpty) {
      await client.from(_kHrEmployeeDocumentsTable).upsert(docsToUpsert);
    }
    if (sourceEmployeeId != row.id) {
      await client
          .from(_kHrEmployeeProfilesTable)
          .delete()
          .eq('id', sourceEmployeeId);
    }
    return syncedRow;
  }

  static Future<void> deleteEmployees(
    List<_HumanResourcesEmployeeRow> rows,
  ) async {
    if (rows.isEmpty) return;
    final client = Supabase.instance.client;
    final ids = rows.map((row) => row.id).toList(growable: false);
    final documentRows = await client
        .from(_kHrEmployeeDocumentsTable)
        .select('storage_path')
        .inFilter('employee_id', ids);
    final profileRows = await client
        .from(_kHrEmployeeProfilesTable)
        .select('photo_storage_path')
        .inFilter('id', ids);
    final paths = <String>{
      for (final raw in (documentRows as List))
        if (Map<String, dynamic>.from(raw as Map)['storage_path'] != null)
          Map<String, dynamic>.from(raw)['storage_path'].toString(),
      for (final raw in (profileRows as List))
        if (Map<String, dynamic>.from(raw as Map)['photo_storage_path'] != null)
          Map<String, dynamic>.from(raw)['photo_storage_path'].toString(),
    }.where((path) => path.trim().isNotEmpty).toList(growable: false);
    if (paths.isNotEmpty) {
      await client.storage.from(_kHrEmployeeFilesBucket).remove(paths);
    }
    await client.from(_kHrEmployeeProfilesTable).delete().inFilter('id', ids);
  }

  static Future<_HrEmployeeAttachment> _uploadAttachment({
    required String employeeId,
    required _HrEmployeeAttachment attachment,
    required String segment,
  }) async {
    final sanitized = attachment.fileName.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    final storagePath =
        'employees/$employeeId/$segment/${DateTime.now().millisecondsSinceEpoch}_$sanitized';
    if (kIsWeb) {
      final bytes = attachment.bytes;
      if (bytes == null) {
        throw Exception('No se pudieron leer los bytes del archivo.');
      }
      await Supabase.instance.client.storage
          .from(_kHrEmployeeFilesBucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: attachment.mimeType,
            ),
          );
    } else {
      if (attachment.bytes != null) {
        await Supabase.instance.client.storage
            .from(_kHrEmployeeFilesBucket)
            .uploadBinary(
              storagePath,
              attachment.bytes!,
              fileOptions: FileOptions(
                upsert: true,
                contentType: attachment.mimeType,
              ),
            );
      } else {
        throw Exception('No se pudo leer el archivo local.');
      }
    }
    final url = Supabase.instance.client.storage
        .from(_kHrEmployeeFilesBucket)
        .getPublicUrl(storagePath);
    final user = Supabase.instance.client.auth.currentUser;
    final now = DateTime.now();
    return attachment.copyWith(
      fileUrl: url,
      storagePath: storagePath,
      uploadedAt: now,
      uploadedBy: user?.id,
      uploadedByName: user?.email ?? 'Usuario',
    );
  }
}

Map<String, dynamic> _hrDocumentToInsertJson(
  _HrEmployeeAttachment attachment, {
  required String employeeId,
}) => <String, dynamic>{
  'id': attachment.id,
  'employee_id': employeeId,
  'category_key': attachment.categoryKey,
  'category_label': attachment.categoryLabel,
  'title': attachment.title,
  'file_url': attachment.fileUrl,
  'storage_path': attachment.storagePath,
  'file_name': attachment.fileName,
  'mime_type': attachment.mimeType,
  'size_bytes': attachment.sizeBytes,
  'uploaded_by': attachment.uploadedBy,
  'uploaded_by_name': attachment.uploadedByName.trim().isEmpty
      ? null
      : attachment.uploadedByName.trim(),
  'uploaded_at': attachment.uploadedAt.toIso8601String(),
  'is_required': attachment.categoryKey != 'adicional',
};

_HrEmployeeAttachment _hrAttachmentFromRemoteRow(Map<String, dynamic> row) {
  return _HrEmployeeAttachment(
    id: (row['id'] ?? '').toString(),
    title: (row['title'] ?? row['file_name'] ?? '').toString(),
    fileName: (row['file_name'] ?? '').toString(),
    bytes: null,
    fileUrl: (row['file_url'] ?? '').toString(),
    storagePath: row['storage_path']?.toString(),
    mimeType: (row['mime_type'] ?? 'application/octet-stream').toString(),
    sizeBytes: (row['size_bytes'] as num?)?.toInt() ?? 0,
    uploadedBy: row['uploaded_by']?.toString(),
    uploadedByName: (row['uploaded_by_name'] ?? '').toString(),
    uploadedAt:
        _tryParseDateTime(row['uploaded_at']?.toString()) ?? DateTime.now(),
    createdAt: _tryParseDateTime(row['created_at']?.toString()),
    updatedAt: _tryParseDateTime(row['updated_at']?.toString()),
    categoryKey: (row['category_key'] ?? '').toString(),
    categoryLabel: (row['category_label'] ?? '').toString(),
  );
}

_HrEmployeeAttachment? _hrPhotoFromProfileRow(Map<String, dynamic> row) {
  final fileUrl = (row['photo_file_url'] ?? '').toString();
  final fileName = (row['photo_file_name'] ?? '').toString();
  if (fileUrl.trim().isEmpty && fileName.trim().isEmpty) return null;
  return _HrEmployeeAttachment(
    id: 'photo_${row['id']}',
    title: fileName.isEmpty ? 'Foto' : fileName,
    fileName: fileName,
    bytes: null,
    fileUrl: fileUrl,
    storagePath: row['photo_storage_path']?.toString(),
    mimeType: (row['photo_mime_type'] ?? 'image/jpeg').toString(),
    sizeBytes: 0,
    uploadedBy: null,
    uploadedByName: '',
    uploadedAt:
        _tryParseDateTime(row['photo_uploaded_at']?.toString()) ??
        DateTime.now(),
    createdAt: null,
    updatedAt: null,
    categoryKey: 'photo',
    categoryLabel: 'Fotografia',
  );
}

String _hrMimeTypeFor(PlatformFile file) {
  final ext = (file.extension ?? '').trim().toLowerCase();
  switch (ext) {
    case 'pdf':
      return 'application/pdf';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    default:
      return 'application/octet-stream';
  }
}

DateTime? _tryParseDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}

String _hrAttachmentSizeLabel(int sizeBytes) {
  if (sizeBytes <= 0) return 'sin tamaño';
  if (sizeBytes < 1024) return '$sizeBytes B';
  if (sizeBytes < 1024 * 1024) {
    return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
