import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../auth/auth_access.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/dialogs/contract_popup_surface.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/number_formatters.dart';
import 'mayoreo_accounts_page.dart';
import 'mayoreo_catalog_page.dart';
import 'mayoreo_dashboard_preview_page.dart';
import 'mayoreo_price_adjustments_page.dart';
import 'mayoreo_sales_report_page.dart';
import 'mayoreo_theme.dart';

const String _kMayoreoSalesReportsTable = 'mayoreo_sales_reports';
const String _kMayoreoPalomarMovementsTable = 'mayoreo_palomar_movements';
const double _kPalomarReferenceLineAmount = 1000000;

enum _PalomarMovementType {
  chequeLiberado,
  remisionAplicada,
  ajusteCargo,
  ajusteAbono,
  corteInterno,
}

enum _PalomarRemissionState { disponible, aplicada, revision }

enum _PalomarLedgerMenuAction { edit, delete }

class MayoreoElPalomarPage extends StatefulWidget {
  final bool instantOpen;

  const MayoreoElPalomarPage({super.key, this.instantOpen = false});

  @override
  State<MayoreoElPalomarPage> createState() => _MayoreoElPalomarPageState();
}

class _MayoreoElPalomarPageState extends State<MayoreoElPalomarPage> {
  final SupabaseClient _supa = Supabase.instance.client;
  bool _menuOpen = false;
  bool _canReturnToDirection = false;
  final ScrollController _bodyScrollController = ScrollController();
  final GlobalKey _rowsViewportKey = GlobalKey(
    debugLabel: 'mayoreo_palomar_rows_viewport',
  );
  final Map<String, GlobalKey> _rowItemKeys = <String, GlobalKey>{};
  String? _selectedMovementId;
  final Set<String> _selectedMovementIds = <String>{};
  String? _selectionAnchorMovementId;
  bool _dragSelectingRows = false;
  bool _pointerDownAdditiveSelection = false;
  bool _suppressNextRowTap = false;
  Offset? _dragPointerGlobal;
  double _dragAutoScrollVelocity = 0;
  Timer? _dragAutoScrollTimer;
  DateTime? _dateFilterFrom;
  DateTime? _dateFilterTo;
  final Set<String> _typeFilters = <String>{};
  final Set<String> _checkFilters = <String>{};
  final Set<String> _remisionFilters = <String>{};
  final Set<String> _materialFilters = <String>{};
  final Set<String> _referenceFilters = <String>{};
  int _currentPage = 0;
  int _pageSize = 40;
  List<_PalomarMovement> _movements = const <_PalomarMovement>[];
  List<_PalomarSourceRemission> _sourceRemissions =
      const <_PalomarSourceRemission>[];

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadState());
  }

  @override
  void dispose() {
    _dragAutoScrollTimer?.cancel();
    _bodyScrollController.dispose();
    super.dispose();
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
    });
  }

  Future<void> _loadState() async {
    List<_PalomarMovement> restoredMovements = const <_PalomarMovement>[];
    try {
      final response = await _supa
          .from(_kMayoreoPalomarMovementsTable)
          .select()
          .order('date', ascending: true)
          .order('created_at', ascending: true);
      restoredMovements = (response as List)
          .map(
            (item) => _PalomarMovement.fromSupabase(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      restoredMovements = const <_PalomarMovement>[];
    }
    final remissions = await _loadSourceRemissions();
    if (!mounted) return;
    setState(() {
      _movements = restoredMovements;
      _sourceRemissions = remissions;
    });
  }

  Future<void> _persistState() async {
    if (_movements.isNotEmpty) {
      await _supa
          .from(_kMayoreoPalomarMovementsTable)
          .upsert(
            _movements
                .map((movement) => movement.toSupabase())
                .toList(growable: false),
            onConflict: 'id',
          );
    }
    final existing = await _supa
        .from(_kMayoreoPalomarMovementsTable)
        .select('id');
    final existingIds = (existing as List)
        .map((row) => (row as Map)['id'].toString())
        .toSet();
    final nextIds = _movements.map((movement) => movement.id).toSet();
    final deletedIds = existingIds.difference(nextIds).toList(growable: false);
    if (deletedIds.isNotEmpty) {
      await _supa
          .from(_kMayoreoPalomarMovementsTable)
          .delete()
          .inFilter('id', deletedIds);
    }
  }

  Future<List<_PalomarSourceRemission>> _loadSourceRemissions() async {
    try {
      final response = await _supa
          .from(_kMayoreoSalesReportsTable)
          .select()
          .order('sale_date', ascending: false);
      final rows = (response as List)
          .map(
            (item) => _PalomarSourceRemission.fromSupabase(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where((row) => _isPalomarClientName(row.clientName))
          .toList(growable: false);
      return rows;
    } catch (_) {
      return const <_PalomarSourceRemission>[];
    }
  }

  bool _isPalomarClientName(String value) {
    final normalized = value
        .toUpperCase()
        .trim()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U');
    return normalized.contains('PALOMAR');
  }

  Future<void> _openDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const MayoreoDashboardPreviewPage(instantOpen: true)),
    );
  }

  Future<void> _openCatalog() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const MayoreoCatalogPage(instantOpen: true)));
  }

  Future<void> _openPriceAdjustments() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(page: const MayoreoPriceAdjustmentsPage(instantOpen: true)),
    );
  }

  Future<void> _openSalesReports() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const MayoreoSalesReportPage(instantOpen: true)));
  }

  Future<void> _openAccounts() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const MayoreoAccountsPage(instantOpen: true)));
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openMailHostinger() async {
    const url = 'https://mail.hostinger.com/';
    final opened = await launchUrlString(
      url,
      mode: LaunchMode.externalApplication,
    );
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo abrir mail.hostinger.com'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Dirección':
        unawaited(_openDirectionDashboard());
        return;
      case 'Dashboard Mayoreo':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openDashboard());
        return;
      case 'Ventas Mayoreo':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openSalesReports());
        return;
      case 'Cuentas':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openAccounts());
        return;
      case 'Catálogo':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openCatalog());
        return;
      case 'Ajuste de precios':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openPriceAdjustments());
        return;
      case 'Cuenta El Palomar':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      default:
        if (_menuOpen) setState(() => _menuOpen = false);
        _toast('$label quedará conectado en la siguiente fase de Mayoreo.');
    }
  }

  Set<String> get _appliedRemissionIds => _movements
      .where(
        (movement) =>
            movement.type == _PalomarMovementType.remisionAplicada &&
            movement.sourceReportId != null &&
            movement.sourceReportId!.isNotEmpty,
      )
      .map((movement) => movement.sourceReportId!)
      .toSet();

  _PalomarRemissionState _remissionStateFor(_PalomarSourceRemission row) {
    if (!row.isRelated || row.approvedAmount <= 0) {
      return _PalomarRemissionState.revision;
    }
    if (_appliedRemissionIds.contains(row.id)) {
      return _PalomarRemissionState.aplicada;
    }
    return _PalomarRemissionState.disponible;
  }

  List<_PalomarLedgerEntry> get _ledgerEntries {
    final sorted = _movements.toList(growable: false)
      ..sort((a, b) {
        final compare = a.date.compareTo(b.date);
        if (compare != 0) return compare;
        return a.createdAt.compareTo(b.createdAt);
      });
    double running = 0;
    return sorted
        .map((movement) {
          running += movement.signedAmount;
          return _PalomarLedgerEntry(movement: movement, balanceAfter: running);
        })
        .toList(growable: false);
  }

  List<_PalomarLedgerEntry> get _filteredEntries {
    final filtered =
        _ledgerEntries
            .where((entry) {
              final dateOnly = DateUtils.dateOnly(entry.movement.date);
              if (_dateFilterFrom != null &&
                  dateOnly.isBefore(DateUtils.dateOnly(_dateFilterFrom!))) {
                return false;
              }
              if (_dateFilterTo != null &&
                  dateOnly.isAfter(DateUtils.dateOnly(_dateFilterTo!))) {
                return false;
              }
              if (_typeFilters.isNotEmpty &&
                  !_typeFilters.contains(
                    _movementTypeLabel(entry.movement.type),
                  )) {
                return false;
              }
              if (_checkFilters.isNotEmpty &&
                  !_checkFilters.any(
                    (filter) => _matchesAnyValue(<String>[
                      entry.movement.checkNumber,
                      entry.movement.bankReference,
                      entry.movement.reference,
                    ], filter),
                  )) {
                return false;
              }
              if (_remisionFilters.isNotEmpty &&
                  !_remisionFilters.any(
                    (filter) => _matchesAnyValue(<String>[
                      entry.movement.remision,
                      entry.movement.ticket,
                    ], filter),
                  )) {
                return false;
              }
              if (_materialFilters.isNotEmpty &&
                  !_materialFilters.any(
                    (filter) => _matchesAnyValue(<String>[
                      entry.movement.material,
                    ], filter),
                  )) {
                return false;
              }
              if (_referenceFilters.isNotEmpty &&
                  !_referenceFilters.any(
                    (filter) => _matchesAnyValue(<String>[
                      entry.movement.reference,
                      entry.movement.notes,
                      entry.movement.client,
                    ], filter),
                  )) {
                return false;
              }
              return true;
            })
            .toList(growable: false)
          ..sort((a, b) => b.movement.date.compareTo(a.movement.date));
    return filtered;
  }

  double get _currentBalance =>
      _ledgerEntries.isEmpty ? 0 : _ledgerEntries.last.balanceAfter;

  bool _isShortcutModifierPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.control) ||
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.meta) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  bool _isShiftPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.shift) ||
        pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
  }

  int _selectedFilteredIndex(List<_PalomarLedgerEntry> rows) {
    if (_selectedMovementId == null) return rows.isEmpty ? -1 : 0;
    return rows.indexWhere((row) => row.movement.id == _selectedMovementId);
  }

  void _selectFilteredIndex(List<_PalomarLedgerEntry> rows, int nextIndex) {
    if (rows.isEmpty) return;
    final safeIndex = nextIndex.clamp(0, rows.length - 1);
    final nextId = rows[safeIndex].movement.id;
    setState(() {
      _selectedMovementId = nextId;
      _selectedMovementIds
        ..clear()
        ..add(nextId);
      _selectionAnchorMovementId = nextId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureRowVisible(nextId);
    });
  }

  void _moveSelectionBy(
    List<_PalomarLedgerEntry> rows,
    int delta, {
    required bool extend,
  }) {
    if (rows.isEmpty) return;
    final currentIndex = _selectedFilteredIndex(rows);
    final baseIndex = currentIndex < 0 ? 0 : currentIndex;
    final nextIndex = (baseIndex + delta).clamp(0, rows.length - 1);
    if (!extend) {
      _selectFilteredIndex(rows, nextIndex);
      return;
    }
    final nextEntry = rows[nextIndex];
    setState(() {
      _selectionAnchorMovementId ??= currentIndex < 0
          ? rows.first.movement.id
          : rows[baseIndex].movement.id;
      _extendSelectionToEntry(nextEntry, rows);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureRowVisible(nextEntry.movement.id);
    });
  }

  void _selectSingleEntry(_PalomarLedgerEntry entry) {
    _selectedMovementId = entry.movement.id;
    _selectedMovementIds
      ..clear()
      ..add(entry.movement.id);
    _selectionAnchorMovementId = entry.movement.id;
    _dragSelectingRows = false;
  }

  void _extendSelectionToEntry(
    _PalomarLedgerEntry entry,
    List<_PalomarLedgerEntry> rows,
  ) {
    final currentIndex = rows.indexWhere(
      (item) => item.movement.id == entry.movement.id,
    );
    final anchorIndex = _selectionAnchorMovementId == null
        ? -1
        : rows.indexWhere(
            (item) => item.movement.id == _selectionAnchorMovementId,
          );
    if (currentIndex < 0 || anchorIndex < 0) {
      _selectSingleEntry(entry);
      return;
    }
    final from = anchorIndex < currentIndex ? anchorIndex : currentIndex;
    final to = anchorIndex < currentIndex ? currentIndex : anchorIndex;
    _selectedMovementId = entry.movement.id;
    _selectedMovementIds
      ..clear()
      ..addAll(
        rows
            .sublist(from, to + 1)
            .map((item) => item.movement.id)
            .toList(growable: false),
      );
    _dragSelectingRows = true;
  }

  void _handleLedgerRowTap(
    _PalomarLedgerEntry entry,
    List<_PalomarLedgerEntry> rows,
  ) {
    if (_suppressNextRowTap || _pointerDownAdditiveSelection) {
      setState(() {
        _suppressNextRowTap = false;
        _pointerDownAdditiveSelection = false;
      });
      return;
    }
    final currentIndex = rows.indexWhere(
      (item) => item.movement.id == entry.movement.id,
    );
    final anchorIndex = _selectionAnchorMovementId == null
        ? -1
        : rows.indexWhere(
            (item) => item.movement.id == _selectionAnchorMovementId,
          );
    setState(() {
      _selectedMovementId = entry.movement.id;
      if (_isShiftPressed() && anchorIndex >= 0 && currentIndex >= 0) {
        final from = anchorIndex < currentIndex ? anchorIndex : currentIndex;
        final to = anchorIndex < currentIndex ? currentIndex : anchorIndex;
        _selectedMovementIds
          ..clear()
          ..addAll(
            rows
                .sublist(from, to + 1)
                .map((item) => item.movement.id)
                .toList(growable: false),
          );
      } else if (_isShortcutModifierPressed()) {
        if (_selectedMovementIds.contains(entry.movement.id)) {
          _selectedMovementIds.remove(entry.movement.id);
          if (_selectedMovementIds.isEmpty) {
            _selectedMovementIds.add(entry.movement.id);
          }
        } else {
          _selectedMovementIds.add(entry.movement.id);
        }
        _selectionAnchorMovementId = entry.movement.id;
      } else if (_selectedMovementIds.length > 1 &&
          _selectedMovementIds.contains(entry.movement.id)) {
        _selectedMovementId = entry.movement.id;
      } else {
        _selectedMovementIds
          ..clear()
          ..add(entry.movement.id);
        _selectionAnchorMovementId = entry.movement.id;
      }
    });
  }

  void _handleLedgerRowPrimaryPointerDown(
    _PalomarLedgerEntry entry,
    List<_PalomarLedgerEntry> rows,
  ) {
    setState(() {
      _pointerDownAdditiveSelection =
          _isShortcutModifierPressed() || _isShiftPressed();
      if (_isShiftPressed()) {
        _extendSelectionToEntry(entry, rows);
        _suppressNextRowTap = true;
      } else if (_isShortcutModifierPressed()) {
        _selectedMovementId = entry.movement.id;
        if (_selectedMovementIds.contains(entry.movement.id)) {
          _selectedMovementIds.remove(entry.movement.id);
          if (_selectedMovementIds.isEmpty) {
            _selectedMovementIds.add(entry.movement.id);
          }
        } else {
          _selectedMovementIds.add(entry.movement.id);
        }
        _selectionAnchorMovementId = entry.movement.id;
        _suppressNextRowTap = true;
      } else {
        _selectSingleEntry(entry);
        _dragSelectingRows = true;
        _suppressNextRowTap = false;
      }
    });
    _updateDragAutoScroll(rows);
  }

  int? _visibleLedgerRowPositionAtGlobalPosition(
    Offset globalPosition,
    List<_PalomarLedgerEntry> rows,
  ) {
    for (var index = 0; index < rows.length; index++) {
      final box =
          _rowItemKeys[rows[index].movement.id]?.currentContext
                  ?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final topLeft = box.localToGlobal(Offset.zero);
      final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
      if (globalPosition.dx >= topLeft.dx &&
          globalPosition.dx <= bottomRight.dx &&
          globalPosition.dy >= topLeft.dy &&
          globalPosition.dy <= bottomRight.dy) {
        return index;
      }
    }
    return null;
  }

  void _handleLedgerRowsPointerDown(
    PointerDownEvent event,
    List<_PalomarLedgerEntry> rows,
  ) {
    _pointerDownAdditiveSelection =
        _isShortcutModifierPressed() || _isShiftPressed();
    if (event.kind != PointerDeviceKind.mouse ||
        (event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }
    final visibleIndex = _visibleLedgerRowPositionAtGlobalPosition(
      event.position,
      rows,
    );
    if (visibleIndex == null) return;
    _dragPointerGlobal = event.position;
    _handleLedgerRowPrimaryPointerDown(rows[visibleIndex], rows);
    _updateDragAutoScroll(rows);
  }

  void _handleLedgerRowDragEnter(
    _PalomarLedgerEntry entry,
    List<_PalomarLedgerEntry> rows,
  ) {
    if (!_dragSelectingRows) return;
    setState(() => _extendSelectionToEntry(entry, rows));
    _updateDragAutoScroll(rows);
  }

  void _handleLedgerRowsPointerMove(
    PointerMoveEvent event,
    List<_PalomarLedgerEntry> rows,
  ) {
    if (!_dragSelectingRows) return;
    _dragPointerGlobal = event.position;
    _updateDragAutoScroll(rows);
    final visibleIndex = _visibleLedgerRowPositionAtGlobalPosition(
      event.position,
      rows,
    );
    if (visibleIndex == null) return;
    setState(() => _extendSelectionToEntry(rows[visibleIndex], rows));
  }

  void _handleLedgerRowPointerEnd() {
    if (!_dragSelectingRows &&
        !_pointerDownAdditiveSelection &&
        !_suppressNextRowTap) {
      return;
    }
    setState(() {
      _dragSelectingRows = false;
      _dragPointerGlobal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      if (!_pointerDownAdditiveSelection && !_suppressNextRowTap) {
        _pointerDownAdditiveSelection = false;
        _suppressNextRowTap = false;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMovementId = null;
      _selectedMovementIds.clear();
      _selectionAnchorMovementId = null;
      _dragSelectingRows = false;
      _pointerDownAdditiveSelection = false;
      _suppressNextRowTap = false;
      _dragPointerGlobal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
    });
  }

  int _effectiveCurrentPageFor(int totalRows) {
    if (totalRows <= 0) return 0;
    final totalPages = ((totalRows - 1) / _pageSize).floor() + 1;
    return _currentPage.clamp(0, totalPages - 1);
  }

  int _totalPagesFor(int totalRows) {
    if (totalRows <= 0) return 1;
    return ((totalRows - 1) / _pageSize).floor() + 1;
  }

  List<_PalomarLedgerEntry> _pageEntries(List<_PalomarLedgerEntry> entries) {
    if (entries.isEmpty) return const <_PalomarLedgerEntry>[];
    final currentPage = _effectiveCurrentPageFor(entries.length);
    final start = currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, entries.length);
    return entries.sublist(start, end);
  }

  GlobalKey _rowItemKey(String rowId) {
    return _rowItemKeys.putIfAbsent(
      rowId,
      () => GlobalKey(debugLabel: 'palomar_row_$rowId'),
    );
  }

  void _ensureRowVisible(String rowId) {
    final rowContext = _rowItemKey(rowId).currentContext;
    if (rowContext == null) return;
    Scrollable.ensureVisible(
      rowContext,
      alignment: 0.4,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _updateDragAutoScroll(List<_PalomarLedgerEntry> pageRows) {
    final pointer = _dragPointerGlobal;
    if (pointer == null || !_dragSelectingRows) {
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final viewportBox =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) {
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final local = viewportBox.globalToLocal(pointer);
    const edge = 48.0;
    const maxStep = 22.0;
    final y = local.dy;
    if (y < edge) {
      _dragAutoScrollVelocity = -((edge - y) / edge).clamp(0.0, 1.0) * maxStep;
    } else if (y > viewportBox.size.height - edge) {
      _dragAutoScrollVelocity =
          ((y - (viewportBox.size.height - edge)) / edge).clamp(0.0, 1.0) *
          maxStep;
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
      (_) => _performDragAutoScroll(pageRows),
    );
  }

  void _performDragAutoScroll(List<_PalomarLedgerEntry> pageRows) {
    if (_dragAutoScrollVelocity == 0 || !_bodyScrollController.hasClients) {
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final position = _bodyScrollController.position;
    final next = (position.pixels + _dragAutoScrollVelocity).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) return;
    _bodyScrollController.jumpTo(next);
    final pointer = _dragPointerGlobal;
    final viewportBox =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (pointer == null || viewportBox == null || !viewportBox.hasSize) return;
    final local = viewportBox.globalToLocal(pointer);
    if (local.dy < 0 || local.dy >= viewportBox.size.height) {
      return;
    }
    final visibleIndex = _visibleLedgerRowPositionAtGlobalPosition(
      pointer,
      pageRows,
    );
    if (visibleIndex == null) return;
    final row = pageRows[visibleIndex];
    setState(() => _extendSelectionToEntry(row, pageRows));
  }

  Future<void> _deleteSelectedMovements() async {
    if (_selectedMovementIds.isEmpty) return;
    final deleteCount = _selectedMovementIds.length;
    final ok = await _showPalomarDeleteConfirmDialog(
      context,
      count: deleteCount,
    );
    if (ok != true || !mounted) return;
    setState(() {
      _movements = _movements
          .where((item) => !_selectedMovementIds.contains(item.id))
          .toList(growable: false);
      _selectedMovementId = null;
      _selectedMovementIds.clear();
      _selectionAnchorMovementId = null;
      _currentPage = 0;
    });
    await _persistState();
  }

  Future<void> _showContextMenuForEntry(
    _PalomarLedgerEntry entry,
    List<_PalomarLedgerEntry> visibleRows,
    Offset globalPosition,
  ) async {
    final rowWasAlreadySelected = _selectedMovementIds.contains(
      entry.movement.id,
    );
    setState(() {
      _selectedMovementId = entry.movement.id;
      if (!rowWasAlreadySelected) {
        _selectedMovementIds
          ..clear()
          ..add(entry.movement.id);
        _selectionAnchorMovementId = entry.movement.id;
      }
      if (_selectedMovementIds.isEmpty && visibleRows.isNotEmpty) {
        _selectedMovementIds.add(entry.movement.id);
      }
    });
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final selectedCount = _selectedMovementIds.length;
    final action = await showMenu<_PalomarLedgerMenuAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      color: mayoreoAreaTokens.surfaceTint.withValues(alpha: 0.98),
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: mayoreoAreaTokens.primarySoft.withValues(alpha: 0.72),
        ),
      ),
      items: [
        const PopupMenuItem(
          value: _PalomarLedgerMenuAction.edit,
          child: Text(
            'Editar',
            style: TextStyle(fontWeight: FontWeight.w800, color: kMayoreoInk),
          ),
        ),
        PopupMenuItem(
          value: _PalomarLedgerMenuAction.delete,
          child: Text(
            selectedCount > 1 ? 'Eliminar selección' : 'Eliminar movimiento',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: kMayoreoInk,
            ),
          ),
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _PalomarLedgerMenuAction.edit:
        await _openEditSelectedMovement();
        break;
      case _PalomarLedgerMenuAction.delete:
        await _deleteSelectedMovements();
        break;
    }
  }

  int get _activeFiltersCount {
    var total = 0;
    if (_dateFilterFrom != null) total += 1;
    if (_dateFilterTo != null) total += 1;
    if (_typeFilters.isNotEmpty) total += 1;
    if (_checkFilters.isNotEmpty) total += 1;
    if (_remisionFilters.isNotEmpty) total += 1;
    if (_materialFilters.isNotEmpty) total += 1;
    if (_referenceFilters.isNotEmpty) total += 1;
    return total;
  }

  double get _totalChecksReleased => _movements
      .where((movement) => movement.type == _PalomarMovementType.chequeLiberado)
      .fold<double>(0, (sum, movement) => sum + movement.amount);

  double get _totalAppliedWithRemissions => _movements
      .where(
        (movement) => movement.type == _PalomarMovementType.remisionAplicada,
      )
      .fold<double>(0, (sum, movement) => sum + movement.amount);

  double get _totalAdjustments => _movements
      .where(
        (movement) =>
            movement.type == _PalomarMovementType.ajusteCargo ||
            movement.type == _PalomarMovementType.ajusteAbono,
      )
      .fold<double>(0, (sum, movement) => sum + movement.signedAmount);

  int get _checksCount => _movements
      .where((movement) => movement.type == _PalomarMovementType.chequeLiberado)
      .length;

  int get _appliedRemissionsCount => _movements
      .where(
        (movement) => movement.type == _PalomarMovementType.remisionAplicada,
      )
      .length;

  int get _availableRemissionsCount => _sourceRemissions
      .where(
        (row) => _remissionStateFor(row) == _PalomarRemissionState.disponible,
      )
      .length;

  double get _availableRemissionsAmount => _sourceRemissions
      .where(
        (row) => _remissionStateFor(row) == _PalomarRemissionState.disponible,
      )
      .fold<double>(0, (sum, row) => sum + row.approvedAmount);

  double get _availableToRequestAmount =>
      _kPalomarReferenceLineAmount - _currentBalance;

  int get _reviewRemissionsCount => _sourceRemissions
      .where(
        (row) => _remissionStateFor(row) == _PalomarRemissionState.revision,
      )
      .length;

  DateTime? get _lastMovementDate => _movements.isEmpty
      ? null
      : (_movements.toList(
          growable: false,
        )..sort((a, b) => b.date.compareTo(a.date))).first.date;

  String get _accountStatusLabel {
    if (_reviewRemissionsCount > 0) return 'Revisión requerida';
    if (_currentBalance <= 0) return 'Cubierta';
    final availableAmount = _sourceRemissions
        .where(
          (row) => _remissionStateFor(row) == _PalomarRemissionState.disponible,
        )
        .fold<double>(0, (sum, row) => sum + row.approvedAmount);
    if (_currentBalance > 0 && availableAmount < (_currentBalance * 0.25)) {
      return 'Conviene pedir más cheques';
    }
    if (_currentBalance >= 500000) return 'Saldo alto pendiente';
    return 'Operativa';
  }

  Color get _accountStatusColor {
    switch (_accountStatusLabel) {
      case 'Revisión requerida':
        return const Color(0xFFC05A0B);
      case 'Cubierta':
        return const Color(0xFF4F8E8C);
      case 'Conviene pedir más cheques':
        return const Color(0xFF9A4300);
      case 'Saldo alto pendiente':
        return const Color(0xFFB35F00);
      default:
        return mayoreoAreaTokens.primaryStrong;
    }
  }

  Future<DateTime?> _pickDate(DateTime? initialDate) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: mayoreoAreaTokens.primaryStrong,
            onPrimary: Colors.white,
            surface: mayoreoAreaTokens.surfaceTint,
            onSurface: kMayoreoInk,
          ),
        ),
        child: child!,
      ),
    );
  }

  Future<void> _openRegisterCheckDialog() async {
    final movement = await showDialog<_PalomarMovement>(
      context: context,
      builder: (_) => AreaThemeScope(
        tokens: mayoreoAreaTokens,
        child: _PalomarCheckDialog(onPickDate: _pickDate),
      ),
    );
    if (!mounted || movement == null) return;
    setState(() => _movements = <_PalomarMovement>[..._movements, movement]);
    await _persistState();
  }

  Future<void> _openManualAdjustmentDialog() async {
    final movement = await showDialog<_PalomarMovement>(
      context: context,
      builder: (_) => AreaThemeScope(
        tokens: mayoreoAreaTokens,
        child: _PalomarAdjustmentDialog(onPickDate: _pickDate),
      ),
    );
    if (!mounted || movement == null) return;
    setState(() => _movements = <_PalomarMovement>[..._movements, movement]);
    await _persistState();
  }

  Future<void> _openApplyRemissionsDialog() async {
    final selected = await showDialog<List<_PalomarSourceRemission>>(
      context: context,
      builder: (_) => AreaThemeScope(
        tokens: mayoreoAreaTokens,
        child: _PalomarApplyRemissionsDialog(
          remissions: _sourceRemissions,
          appliedIds: _appliedRemissionIds,
          onStateFor: _remissionStateFor,
        ),
      ),
    );
    if (!mounted || selected == null || selected.isEmpty) return;
    final newMovements = selected
        .map(
          (row) => _PalomarMovement(
            id: '${row.id}-${DateTime.now().microsecondsSinceEpoch}',
            createdAt: DateTime.now(),
            date: row.saleDate,
            type: _PalomarMovementType.remisionAplicada,
            reference: 'Aplicación manual de remisión',
            checkNumber: '',
            remision: row.remision,
            ticket: row.ticket,
            client: row.clientName,
            material: row.materialName,
            exitWeight: row.exitWeight,
            approvedWeight: row.approvedWeight,
            approvedPrice: row.approvedPrice,
            amount: row.approvedAmount,
            notes: 'Aplicada a Cuenta El Palomar',
            bankReference: '',
            sourceReportId: row.id,
          ),
        )
        .toList(growable: false);
    setState(
      () => _movements = <_PalomarMovement>[..._movements, ...newMovements],
    );
    await _persistState();
  }

  Future<void> _openCreateCutDialog() async {
    final movement = await showDialog<_PalomarMovement>(
      context: context,
      builder: (_) => AreaThemeScope(
        tokens: mayoreoAreaTokens,
        child: _PalomarCutDialog(
          ledgerEntries: _ledgerEntries,
          onPickDate: _pickDate,
        ),
      ),
    );
    if (!mounted || movement == null) return;
    setState(() => _movements = <_PalomarMovement>[..._movements, movement]);
    await _persistState();
  }

  Future<void> _openHistoryDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AreaThemeScope(
        tokens: mayoreoAreaTokens,
        child: _PalomarHistoryDialog(entries: _ledgerEntries),
      ),
    );
  }

  _PalomarMovement? get _selectedMovement {
    if (_selectedMovementId == null) return null;
    for (final movement in _movements) {
      if (movement.id == _selectedMovementId) return movement;
    }
    return null;
  }

  Future<void> _openEditMovement(_PalomarMovement movement) async {
    final edited = await showDialog<_PalomarMovement>(
      context: context,
      builder: (_) => AreaThemeScope(
        tokens: mayoreoAreaTokens,
        child: _PalomarEditMovementDialog(
          movement: movement,
          onPickDate: _pickDate,
        ),
      ),
    );
    if (!mounted || edited == null) return;
    setState(() {
      _movements = _movements
          .map((item) => item.id == edited.id ? edited : item)
          .toList(growable: false);
      _selectedMovementId = edited.id;
      _selectedMovementIds
        ..clear()
        ..add(edited.id);
      _selectionAnchorMovementId = edited.id;
    });
    await _persistState();
  }

  Future<void> _openEditSelectedMovement() async {
    final movement = _selectedMovement;
    if (movement == null) return;
    if (movement.type == _PalomarMovementType.corteInterno) {
      return;
    }
    await _openEditMovement(movement);
  }

  Future<void> _openDateRangeFilterDialog() async {
    final bounds =
        _movements.map((movement) => movement.date).toList(growable: false)
          ..sort();
    final now = DateTime.now();
    final result = await _showPalomarDateRangeFilterDialog(
      context,
      label: 'FECHA',
      bounds: DateTimeRange(
        start: bounds.isEmpty ? DateTime(now.year - 1, 1, 1) : bounds.first,
        end: bounds.isEmpty ? DateTime(now.year + 1, 12, 31) : bounds.last,
      ),
      initialRange: _dateFilterFrom == null && _dateFilterTo == null
          ? null
          : DateTimeRange(
              start: _dateFilterFrom ?? _dateFilterTo!,
              end: _dateFilterTo ?? _dateFilterFrom!,
            ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (result.clear) {
        _dateFilterFrom = null;
        _dateFilterTo = null;
      } else {
        _dateFilterFrom = result.from;
        _dateFilterTo = result.to;
      }
    });
  }

  Future<void> _openTypeFilterDialog() async {
    final selected = await _showPalomarValueFilterDialog(
      context,
      title: 'Filtrar tipo de movimiento',
      options: _PalomarMovementType.values
          .map(_movementTypeLabel)
          .toList(growable: false),
      initialValues: _typeFilters,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _typeFilters
        ..clear()
        ..addAll(selected);
      _currentPage = 0;
    });
  }

  Future<void> _openTextFilterDialog({
    required String title,
    required Set<String> currentValues,
    required ValueChanged<Set<String>> onSelected,
    required List<String> suggestions,
  }) async {
    final result = await _showPalomarValueFilterDialog(
      context,
      title: title,
      options: suggestions,
      initialValues: currentValues,
    );
    if (!mounted || result == null) return;
    setState(() {
      onSelected(result);
      _currentPage = 0;
    });
  }

  void _clearFilters() {
    setState(() {
      _dateFilterFrom = null;
      _dateFilterTo = null;
      _typeFilters.clear();
      _checkFilters.clear();
      _remisionFilters.clear();
      _materialFilters.clear();
      _referenceFilters.clear();
      _currentPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _filteredEntries;
    final currentPage = _effectiveCurrentPageFor(filteredEntries.length);
    final totalPages = _totalPagesFor(filteredEntries.length);
    final pageEntries = _pageEntries(filteredEntries);
    final checksLast30Days = _movements
        .where(
          (movement) =>
              movement.type == _PalomarMovementType.chequeLiberado &&
              movement.date.isAfter(
                DateTime.now().subtract(const Duration(days: 30)),
              ),
        )
        .length;
    final remissionsLast30Days = _movements
        .where(
          (movement) =>
              movement.type == _PalomarMovementType.remisionAplicada &&
              movement.date.isAfter(
                DateTime.now().subtract(const Duration(days: 30)),
              ),
        )
        .length;

    return AreaThemeScope(
      tokens: mayoreoAreaTokens,
      child: Theme(
        data: _palomarMaterialTheme(context),
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final filteredEntries = _filteredEntries;
            final pageEntries = _pageEntries(filteredEntries);
            if (event.logicalKey == LogicalKeyboardKey.escape && _menuOpen) {
              setState(() => _menuOpen = false);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.escape &&
                _selectedMovementIds.isNotEmpty) {
              _clearSelection();
              return KeyEventResult.handled;
            }
            if (_isShortcutModifierPressed() &&
                event.logicalKey == LogicalKeyboardKey.keyA &&
                pageEntries.isNotEmpty) {
              setState(() {
                _selectedMovementId = pageEntries.first.movement.id;
                _selectedMovementIds
                  ..clear()
                  ..addAll(pageEntries.map((row) => row.movement.id));
                _selectionAnchorMovementId = pageEntries.first.movement.id;
              });
              return KeyEventResult.handled;
            }
            if (pageEntries.isNotEmpty &&
                event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _moveSelectionBy(
                pageEntries,
                1,
                extend: _isShiftPressed() && _selectedMovementId != null,
              );
              return KeyEventResult.handled;
            }
            if (pageEntries.isNotEmpty &&
                event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _moveSelectionBy(
                pageEntries,
                -1,
                extend: _isShiftPressed() && _selectedMovementId != null,
              );
              return KeyEventResult.handled;
            }
            if (pageEntries.isNotEmpty &&
                (event.logicalKey == LogicalKeyboardKey.delete ||
                    event.logicalKey == LogicalKeyboardKey.backspace)) {
              unawaited(_deleteSelectedMovements());
              return KeyEventResult.handled;
            }
            if (pageEntries.isNotEmpty &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
              unawaited(_openEditSelectedMovement());
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: AppShell(
            background: const _PalomarBackground(),
            wrapBodyInGlass: false,
            animateHeaderSlots: false,
            animateBody: !widget.instantOpen,
            headerBodySpacing: 8,
            padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
            leadingBuilder: (_, _) => _PalomarHeaderButton(
              label: _menuOpen ? 'Cerrar panel' : 'Navegación',
              icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
              onTapSync: () => setState(() => _menuOpen = !_menuOpen),
            ),
            centerBuilder: (_, _) => const _PalomarHeaderBrand(),
            trailingBuilder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PalomarHeaderButton(
                  label: 'Correo',
                  icon: Icons.mail_outline_rounded,
                  compact: true,
                  onTap: _openMailHostinger,
                ),
                const SizedBox(width: 10),
                _PalomarHeaderButton(
                  label: 'Cerrar sesión',
                  icon: Icons.logout_rounded,
                  onTap: () async {},
                ),
              ],
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: TapRegion(
                    onTapOutside: (_) {
                      if (_selectedMovementIds.isNotEmpty) {
                        _clearSelection();
                      }
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: SingleChildScrollView(
                        controller: _bodyScrollController,
                        padding: const EdgeInsets.only(
                          left: 56,
                          right: 12,
                          bottom: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PalomarTopBar(
                              currentBalance: _currentBalance,
                              totalChecksReleased: _totalChecksReleased,
                              totalApplied: _totalAppliedWithRemissions,
                              totalAdjustments: _totalAdjustments,
                              checksCount: _checksCount,
                              appliedRemissionsCount: _appliedRemissionsCount,
                              lastMovementDate: _lastMovementDate,
                              accountStatusLabel: _accountStatusLabel,
                              accountStatusColor: _accountStatusColor,
                              availableRemissionsCount:
                                  _availableRemissionsCount,
                              reviewRemissionsCount: _reviewRemissionsCount,
                              availableRemissionsAmount:
                                  _availableRemissionsAmount,
                              availableToRequestAmount:
                                  _availableToRequestAmount,
                              checksLast30Days: checksLast30Days,
                              remissionsLast30Days: remissionsLast30Days,
                              totalMovementsCount: _movements.length,
                              visibleMovementsCount: filteredEntries.length,
                              onRegisterCheck: _openRegisterCheckDialog,
                              onApplyRemissions: _openApplyRemissionsDialog,
                              onAdjustment: _openManualAdjustmentDialog,
                              onCreateCut: _openCreateCutDialog,
                              onOpenHistory: _openHistoryDialog,
                            ),
                            const SizedBox(height: 14),
                            _PalomarLedgerCard(
                              entries: filteredEntries,
                              pageEntries: pageEntries,
                              selectedMovementId: _selectedMovementId,
                              selectedMovementIds: _selectedMovementIds,
                              rowKeyForId: _rowItemKey,
                              viewportKey: _rowsViewportKey,
                              hasDateFilter:
                                  _dateFilterFrom != null ||
                                  _dateFilterTo != null,
                              hasTypeFilter: _typeFilters.isNotEmpty,
                              hasCheckFilter: _checkFilters.isNotEmpty,
                              hasRemisionFilter: _remisionFilters.isNotEmpty,
                              hasMaterialFilter: _materialFilters.isNotEmpty,
                              hasReferenceFilter: _referenceFilters.isNotEmpty,
                              onOpenDateFilter: _openDateRangeFilterDialog,
                              onOpenTypeFilter: _openTypeFilterDialog,
                              onOpenCheckFilter: () => _openTextFilterDialog(
                                title: 'Filtrar cheque',
                                currentValues: _checkFilters,
                                onSelected: (values) {
                                  _checkFilters
                                    ..clear()
                                    ..addAll(values);
                                },
                                suggestions:
                                    _movements
                                        .expand(
                                          (movement) => <String>[
                                            movement.checkNumber,
                                            movement.bankReference,
                                          ],
                                        )
                                        .map((item) => item.trim())
                                        .where((item) => item.isNotEmpty)
                                        .toSet()
                                        .toList(growable: false)
                                      ..sort(),
                              ),
                              onOpenRemisionFilter: () => _openTextFilterDialog(
                                title: 'Filtrar remisión',
                                currentValues: _remisionFilters,
                                onSelected: (values) {
                                  _remisionFilters
                                    ..clear()
                                    ..addAll(values);
                                },
                                suggestions:
                                    _movements
                                        .expand(
                                          (movement) => <String>[
                                            movement.remision,
                                            movement.ticket,
                                          ],
                                        )
                                        .map((item) => item.trim())
                                        .where((item) => item.isNotEmpty)
                                        .toSet()
                                        .toList(growable: false)
                                      ..sort(),
                              ),
                              onOpenMaterialFilter: () => _openTextFilterDialog(
                                title: 'Filtrar material',
                                currentValues: _materialFilters,
                                onSelected: (values) {
                                  _materialFilters
                                    ..clear()
                                    ..addAll(values);
                                },
                                suggestions:
                                    _movements
                                        .map(
                                          (movement) =>
                                              movement.material.trim(),
                                        )
                                        .where((item) => item.isNotEmpty)
                                        .toSet()
                                        .toList(growable: false)
                                      ..sort(),
                              ),
                              onOpenReferenceFilter: () =>
                                  _openTextFilterDialog(
                                    title: 'Filtrar referencia',
                                    currentValues: _referenceFilters,
                                    onSelected: (values) {
                                      _referenceFilters
                                        ..clear()
                                        ..addAll(values);
                                    },
                                    suggestions:
                                        _movements
                                            .expand(
                                              (movement) => <String>[
                                                movement.reference,
                                                movement.client,
                                                movement.notes,
                                              ],
                                            )
                                            .map((item) => item.trim())
                                            .where((item) => item.isNotEmpty)
                                            .toSet()
                                            .toList(growable: false)
                                          ..sort(),
                                  ),
                              onClearFilters: _activeFiltersCount > 0
                                  ? _clearFilters
                                  : null,
                              onTapRow: (entry) =>
                                  _handleLedgerRowTap(entry, pageEntries),
                              onRowPrimaryPointerDown: (entry) =>
                                  _handleLedgerRowPrimaryPointerDown(
                                    entry,
                                    pageEntries,
                                  ),
                              onRowDragEnter: (entry) =>
                                  _handleLedgerRowDragEnter(entry, pageEntries),
                              onDoubleTapRow: (entry) async {
                                setState(() {
                                  _selectedMovementId = entry.movement.id;
                                  _selectedMovementIds
                                    ..clear()
                                    ..add(entry.movement.id);
                                  _selectionAnchorMovementId =
                                      entry.movement.id;
                                });
                                if (entry.movement.type !=
                                    _PalomarMovementType.corteInterno) {
                                  await _openEditMovement(entry.movement);
                                }
                              },
                              onRowsPointerDown: (event) =>
                                  _handleLedgerRowsPointerDown(
                                    event,
                                    pageEntries,
                                  ),
                              onRowsPointerMove: (event) =>
                                  _handleLedgerRowsPointerMove(
                                    event,
                                    pageEntries,
                                  ),
                              onRowPointerEnd: _handleLedgerRowPointerEnd,
                              onSecondaryTapDown: (entry, globalPosition) =>
                                  _showContextMenuForEntry(
                                    entry,
                                    pageEntries,
                                    globalPosition,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: _PalomarGridPager(
                                currentPage: currentPage,
                                totalPages: totalPages,
                                pageSize: _pageSize,
                                totalRows: filteredEntries.length,
                                onPrevious: currentPage > 0
                                    ? () {
                                        setState(() {
                                          _currentPage = currentPage - 1;
                                          _selectedMovementId = null;
                                          _selectedMovementIds.clear();
                                          _selectionAnchorMovementId = null;
                                        });
                                        _persistState();
                                      }
                                    : null,
                                onNext: currentPage < totalPages - 1
                                    ? () {
                                        setState(() {
                                          _currentPage = currentPage + 1;
                                          _selectedMovementId = null;
                                          _selectedMovementIds.clear();
                                          _selectionAnchorMovementId = null;
                                        });
                                        _persistState();
                                      }
                                    : null,
                                onPageSizeChanged: (value) {
                                  setState(() {
                                    _pageSize = value;
                                    _currentPage = 0;
                                    _selectedMovementId = null;
                                    _selectedMovementIds.clear();
                                    _selectionAnchorMovementId = null;
                                  });
                                  _persistState();
                                },
                              ),
                            ),
                          ],
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
                    child: _PalomarSidePanel(
                      canReturnToDirection: _canReturnToDirection,
                      onNavigate: _handleNavigationAction,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PalomarTopBar extends StatelessWidget {
  final double currentBalance;
  final double totalChecksReleased;
  final double totalApplied;
  final double totalAdjustments;
  final int checksCount;
  final int appliedRemissionsCount;
  final DateTime? lastMovementDate;
  final String accountStatusLabel;
  final Color accountStatusColor;
  final int availableRemissionsCount;
  final int reviewRemissionsCount;
  final double availableRemissionsAmount;
  final double availableToRequestAmount;
  final int checksLast30Days;
  final int remissionsLast30Days;
  final int totalMovementsCount;
  final int visibleMovementsCount;
  final Future<void> Function() onRegisterCheck;
  final Future<void> Function() onApplyRemissions;
  final Future<void> Function() onAdjustment;
  final Future<void> Function() onCreateCut;
  final Future<void> Function() onOpenHistory;

  const _PalomarTopBar({
    required this.currentBalance,
    required this.totalChecksReleased,
    required this.totalApplied,
    required this.totalAdjustments,
    required this.checksCount,
    required this.appliedRemissionsCount,
    required this.lastMovementDate,
    required this.accountStatusLabel,
    required this.accountStatusColor,
    required this.availableRemissionsCount,
    required this.reviewRemissionsCount,
    required this.availableRemissionsAmount,
    required this.availableToRequestAmount,
    required this.checksLast30Days,
    required this.remissionsLast30Days,
    required this.totalMovementsCount,
    required this.visibleMovementsCount,
    required this.onRegisterCheck,
    required this.onApplyRemissions,
    required this.onAdjustment,
    required this.onCreateCut,
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Ventas / Cuenta El Palomar',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        ContractGlassCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    FilledButton.icon(
                      style: _palomarPrimaryButtonStyle(),
                      onPressed: () => unawaited(onRegisterCheck()),
                      icon: const Icon(Icons.add_card_rounded),
                      label: const Text('Registrar cheque'),
                    ),
                    OutlinedButton.icon(
                      style: _palomarSecondaryButtonStyle(),
                      onPressed: () => unawaited(onApplyRemissions()),
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Aplicar remisiones'),
                    ),
                    OutlinedButton.icon(
                      style: _palomarSecondaryButtonStyle(),
                      onPressed: () => unawaited(onAdjustment()),
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Ajuste'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _PalomarStatementBalanceCard(
                balance: currentBalance,
                releasedTotal: totalChecksReleased,
                appliedTotal: totalApplied,
                availableToRequestAmount: availableToRequestAmount,
                statusLabel: accountStatusLabel,
                statusColor: accountStatusColor,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _PalomarMiniInfoChip(
                    icon: Icons.inventory_2_outlined,
                    label:
                        'Remisiones disponibles: ${formatMoney(availableRemissionsAmount, decimals: 0)}',
                  ),
                  _PalomarMiniInfoChip(
                    icon: Icons.checklist_rounded,
                    label:
                        '$availableRemissionsCount disponibles · $reviewRemissionsCount en revisión',
                  ),
                  _PalomarMiniInfoChip(
                    icon: Icons.visibility_outlined,
                    label:
                        '$visibleMovementsCount visibles de $totalMovementsCount movimientos',
                  ),
                  if (lastMovementDate != null)
                    _PalomarMiniInfoChip(
                      icon: Icons.schedule_rounded,
                      label:
                          'Último mov.: ${_formatPalomarDate(lastMovementDate!)}',
                    ),
                  TextButton.icon(
                    onPressed: () => unawaited(onCreateCut()),
                    icon: const Icon(Icons.view_timeline_rounded, size: 16),
                    label: const Text('Corte interno'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _PalomarGridHeaderFilterCell extends StatelessWidget {
  final String label;
  final TextStyle style;
  final bool active;
  final Future<void> Function() onTap;

  const _PalomarGridHeaderFilterCell({
    required this.label,
    required this.style,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => unawaited(onTap()),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: active ? tokens.primaryStrong : tokens.badgeBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active ? tokens.primaryStrong : tokens.border,
              ),
            ),
            child: Icon(
              active ? Icons.filter_alt : Icons.filter_alt_outlined,
              size: 15,
              color: active ? Colors.white : tokens.badgeText,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label, style: style, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _PalomarLedgerCard extends StatelessWidget {
  final List<_PalomarLedgerEntry> entries;
  final List<_PalomarLedgerEntry> pageEntries;
  final String? selectedMovementId;
  final Set<String> selectedMovementIds;
  final GlobalKey Function(String rowId) rowKeyForId;
  final Key viewportKey;
  final bool hasDateFilter;
  final bool hasTypeFilter;
  final bool hasCheckFilter;
  final bool hasRemisionFilter;
  final bool hasMaterialFilter;
  final bool hasReferenceFilter;
  final Future<void> Function() onOpenDateFilter;
  final Future<void> Function() onOpenTypeFilter;
  final Future<void> Function() onOpenCheckFilter;
  final Future<void> Function() onOpenRemisionFilter;
  final Future<void> Function() onOpenMaterialFilter;
  final Future<void> Function() onOpenReferenceFilter;
  final VoidCallback? onClearFilters;
  final ValueChanged<_PalomarLedgerEntry> onTapRow;
  final ValueChanged<_PalomarLedgerEntry> onRowPrimaryPointerDown;
  final ValueChanged<_PalomarLedgerEntry> onRowDragEnter;
  final ValueChanged<_PalomarLedgerEntry> onDoubleTapRow;
  final ValueChanged<PointerDownEvent> onRowsPointerDown;
  final ValueChanged<PointerMoveEvent> onRowsPointerMove;
  final VoidCallback onRowPointerEnd;
  final Future<void> Function(_PalomarLedgerEntry row, Offset globalPosition)
  onSecondaryTapDown;

  const _PalomarLedgerCard({
    required this.entries,
    required this.pageEntries,
    required this.selectedMovementId,
    required this.selectedMovementIds,
    required this.rowKeyForId,
    required this.viewportKey,
    required this.hasDateFilter,
    required this.hasTypeFilter,
    required this.hasCheckFilter,
    required this.hasRemisionFilter,
    required this.hasMaterialFilter,
    required this.hasReferenceFilter,
    required this.onOpenDateFilter,
    required this.onOpenTypeFilter,
    required this.onOpenCheckFilter,
    required this.onOpenRemisionFilter,
    required this.onOpenMaterialFilter,
    required this.onOpenReferenceFilter,
    this.onClearFilters,
    required this.onTapRow,
    required this.onRowPrimaryPointerDown,
    required this.onRowDragEnter,
    required this.onDoubleTapRow,
    required this.onRowsPointerDown,
    required this.onRowsPointerMove,
    required this.onRowPointerEnd,
    required this.onSecondaryTapDown,
  });

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onClearFilters != null) ...[
            Row(
              children: [
                const Spacer(),
                OutlinedButton(
                  style: _palomarSecondaryButtonStyle(),
                  onPressed: onClearFilters,
                  child: const Text('Limpiar filtros'),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          _PalomarLedgerHeader(
            hasDateFilter: hasDateFilter,
            hasTypeFilter: hasTypeFilter,
            hasCheckFilter: hasCheckFilter,
            hasRemisionFilter: hasRemisionFilter,
            hasMaterialFilter: hasMaterialFilter,
            hasReferenceFilter: hasReferenceFilter,
            onOpenDateFilter: onOpenDateFilter,
            onOpenTypeFilter: onOpenTypeFilter,
            onOpenCheckFilter: onOpenCheckFilter,
            onOpenRemisionFilter: onOpenRemisionFilter,
            onOpenMaterialFilter: onOpenMaterialFilter,
            onOpenReferenceFilter: onOpenReferenceFilter,
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 420),
            child: entries.isEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      gradient: kMayoreoPanelGradient,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: mayoreoAreaTokens.border.withValues(alpha: 0.52),
                      ),
                    ),
                    child: const Text(
                      'No hay movimientos visibles. Registra cheques, remisiones o ajustes para empezar a trazar la cuenta.',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: kMayoreoInk,
                      ),
                    ),
                  )
                : Listener(
                    onPointerDown: onRowsPointerDown,
                    onPointerMove: onRowsPointerMove,
                    onPointerUp: (_) => onRowPointerEnd(),
                    onPointerCancel: (_) => onRowPointerEnd(),
                    child: Container(
                      key: viewportKey,
                      child: Column(
                        children: [
                          for (final entry in pageEntries) ...[
                            _PalomarLedgerRow(
                              key: rowKeyForId(entry.movement.id),
                              entry: entry,
                              selected: selectedMovementIds.contains(
                                entry.movement.id,
                              ),
                              active: entry.movement.id == selectedMovementId,
                              onTap: () => onTapRow(entry),
                              onPrimaryPointerDown: () =>
                                  onRowPrimaryPointerDown(entry),
                              onDragEnter: () => onRowDragEnter(entry),
                              onDoubleTap: () => onDoubleTapRow(entry),
                              onSecondaryTapDown: (globalPosition) =>
                                  onSecondaryTapDown(entry, globalPosition),
                            ),
                            if (entry != pageEntries.last)
                              const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PalomarLedgerHeader extends StatelessWidget {
  final bool hasDateFilter;
  final bool hasTypeFilter;
  final bool hasCheckFilter;
  final bool hasRemisionFilter;
  final bool hasMaterialFilter;
  final bool hasReferenceFilter;
  final Future<void> Function() onOpenDateFilter;
  final Future<void> Function() onOpenTypeFilter;
  final Future<void> Function() onOpenCheckFilter;
  final Future<void> Function() onOpenRemisionFilter;
  final Future<void> Function() onOpenMaterialFilter;
  final Future<void> Function() onOpenReferenceFilter;

  const _PalomarLedgerHeader({
    required this.hasDateFilter,
    required this.hasTypeFilter,
    required this.hasCheckFilter,
    required this.hasRemisionFilter,
    required this.hasMaterialFilter,
    required this.hasReferenceFilter,
    required this.onOpenDateFilter,
    required this.onOpenTypeFilter,
    required this.onOpenCheckFilter,
    required this.onOpenRemisionFilter,
    required this.onOpenMaterialFilter,
    required this.onOpenReferenceFilter,
  });

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w900,
      color: kMayoreoInk,
    );

    Widget cell(String label, double width) {
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: headerStyle,
          ),
        ),
      );
    }

    Widget filterCell({
      required String label,
      required double width,
      required bool active,
      required Future<void> Function() onTap,
    }) {
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: _PalomarGridHeaderFilterCell(
            label: label,
            style: headerStyle,
            active: active,
            onTap: onTap,
          ),
        ),
      );
    }

    return ContractGridScaledRow(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          filterCell(
            label: 'FECHA',
            width: 96,
            active: hasDateFilter,
            onTap: onOpenDateFilter,
          ),
          filterCell(
            label: 'MOVIMIENTO',
            width: 142,
            active: hasTypeFilter,
            onTap: onOpenTypeFilter,
          ),
          filterCell(
            label: 'FOLIO',
            width: 176,
            active: hasReferenceFilter,
            onTap: onOpenReferenceFilter,
          ),
          filterCell(
            label: 'MATERIAL',
            width: 196,
            active: hasMaterialFilter,
            onTap: onOpenMaterialFilter,
          ),
          cell('SALIDA KG', 106),
          cell('APROB. KG', 106),
          cell('PRECIO APROB.', 118),
          cell('MONTO', 128),
          cell('SALDO', 128),
        ],
      ),
    );
  }
}

class _PalomarLedgerRow extends StatefulWidget {
  final _PalomarLedgerEntry entry;
  final bool selected;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onPrimaryPointerDown;
  final VoidCallback? onDragEnter;
  final VoidCallback? onDoubleTap;
  final ValueChanged<Offset>? onSecondaryTapDown;

  const _PalomarLedgerRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.active,
    required this.onTap,
    required this.onPrimaryPointerDown,
    this.onDragEnter,
    this.onDoubleTap,
    this.onSecondaryTapDown,
  });

  @override
  State<_PalomarLedgerRow> createState() => _PalomarLedgerRowState();
}

class _PalomarLedgerRowState extends State<_PalomarLedgerRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final highlighted = widget.selected || _hovered || widget.active;
    final activeOnly = widget.active && !widget.selected;
    final typeScheme = _movementTypeScheme(entry.movement.type);
    final signedAmount = entry.movement.signedAmount;
    final signedAmountLabel = _palomarSignedMoney(signedAmount);
    final signedAmountColor = _palomarSignedAmountColor(entry.movement.type);
    final detail = _buildLedgerDetail(entry.movement);

    Widget cell(Widget child, double width) {
      return SizedBox(
        width: width,
        child: Padding(padding: const EdgeInsets.only(right: 10), child: child),
      );
    }

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        widget.onDragEnter?.call();
      },
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: highlighted
                ? [
                    mayoreoAreaTokens.badgeBackground.withValues(alpha: 0.98),
                    mayoreoAreaTokens.primarySoft.withValues(alpha: 0.94),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.78),
                    mayoreoAreaTokens.surfaceTint.withValues(alpha: 0.74),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: activeOnly
                ? mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.42)
                : highlighted
                ? mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.22)
                : mayoreoAreaTokens.border.withValues(alpha: 0.54),
            width: activeOnly ? 1.6 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: ContractGridScaledRow(
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (_) => widget.onPrimaryPointerDown(),
                onSecondaryTapDown: widget.onSecondaryTapDown == null
                    ? null
                    : (details) =>
                          widget.onSecondaryTapDown!(details.globalPosition),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: widget.onTap,
                  onDoubleTap: widget.onDoubleTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      cell(
                        Text(
                          _formatPalomarDate(entry.movement.date),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: kMayoreoInk,
                          ),
                        ),
                        96,
                      ),
                      cell(
                        _PalomarLedgerTypeChip(
                          label: _movementTypeShortLabel(entry.movement.type),
                          accent: typeScheme.$1,
                          background: typeScheme.$2,
                          border: typeScheme.$3,
                        ),
                        142,
                      ),
                      cell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _ledgerPrimaryReference(entry.movement),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.8,
                                fontWeight: FontWeight.w800,
                                color: kMayoreoInk,
                              ),
                            ),
                            if (detail != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                detail,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w600,
                                  color: kMayoreoMutedInk,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                        176,
                      ),
                      cell(
                        Text(
                          entry.movement.material.isEmpty
                              ? '—'
                              : entry.movement.material,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.4,
                            fontWeight: FontWeight.w700,
                            color: entry.movement.material.isEmpty
                                ? kMayoreoMutedInk
                                : kMayoreoInk,
                          ),
                        ),
                        196,
                      ),
                      cell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _palomarWeightCell(entry.movement.exitWeight),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12.4,
                              fontWeight: FontWeight.w800,
                              color: entry.movement.exitWeight == null
                                  ? kMayoreoMutedInk
                                  : kMayoreoInk,
                            ),
                          ),
                        ),
                        106,
                      ),
                      cell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _palomarWeightCell(entry.movement.approvedWeight),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12.4,
                              fontWeight: FontWeight.w800,
                              color: entry.movement.approvedWeight == null
                                  ? kMayoreoMutedInk
                                  : kMayoreoInk,
                            ),
                          ),
                        ),
                        106,
                      ),
                      cell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _palomarPriceCell(entry.movement.approvedPrice),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12.4,
                              fontWeight: FontWeight.w800,
                              color: entry.movement.approvedPrice == null
                                  ? kMayoreoMutedInk
                                  : kMayoreoInk,
                            ),
                          ),
                        ),
                        118,
                      ),
                      cell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            signedAmountLabel,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: signedAmountColor,
                            ),
                          ),
                        ),
                        128,
                      ),
                      cell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            formatMoney(entry.balanceAfter, decimals: 0),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: kMayoreoInk,
                            ),
                          ),
                        ),
                        128,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PalomarStatementBalanceCard extends StatelessWidget {
  final double balance;
  final double releasedTotal;
  final double appliedTotal;
  final double availableToRequestAmount;
  final String statusLabel;
  final Color statusColor;

  const _PalomarStatementBalanceCard({
    required this.balance,
    required this.releasedTotal,
    required this.appliedTotal,
    required this.availableToRequestAmount,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 360, maxWidth: 560),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: kMayoreoPanelGradient,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: mayoreoAreaTokens.border.withValues(alpha: 0.76),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'SALDO ACTUAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.55,
                    color: mayoreoAreaTokens.primaryStrong,
                  ),
                ),
              ),
              _PalomarStatusPill(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatMoney(balance, decimals: 0),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: kMayoreoInk,
              height: 0.96,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Liberado: ${formatMoney(releasedTotal, decimals: 0)}  |  Aplicado: ${formatMoney(appliedTotal, decimals: 0)}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: kMayoreoMutedInk,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.56),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: mayoreoAreaTokens.border.withValues(alpha: 0.68),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.trending_up_rounded,
                  size: 18,
                  color: Color(0xFFB97700),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Disponible para pedir sobre ${formatMoney(_kPalomarReferenceLineAmount, decimals: 0)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: kMayoreoMutedInk,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _palomarSignedMoney(availableToRequestAmount),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: availableToRequestAmount >= 0
                        ? const Color(0xFFB97700)
                        : const Color(0xFF9A4300),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PalomarStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _PalomarStatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _PalomarMiniInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PalomarMiniInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.badgeBackground.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: tokens.primaryStrong),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: kMayoreoInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _PalomarLedgerTypeChip extends StatelessWidget {
  final String label;
  final Color accent;
  final Color background;
  final Color border;

  const _PalomarLedgerTypeChip({
    required this.label,
    required this.accent,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: accent,
          ),
        ),
      ),
    );
  }
}

class _PalomarGridPager extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final int totalRows;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onPageSizeChanged;

  const _PalomarGridPager({
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.totalRows,
    required this.onPrevious,
    required this.onNext,
    required this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border.withValues(alpha: 0.66)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              style: _palomarSecondaryButtonStyle(),
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Anterior'),
            ),
            Text(
              'Página ${currentPage + 1} de $totalPages',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: tokens.primaryStrong,
              ),
            ),
            OutlinedButton.icon(
              style: _palomarSecondaryButtonStyle(),
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Siguiente'),
            ),
            const Text('Filas/pág:'),
            SizedBox(
              width: 90,
              child: DropdownButtonFormField<int>(
                initialValue: pageSize,
                isDense: true,
                dropdownColor: mayoreoAreaTokens.surfaceTint,
                iconEnabledColor: tokens.primaryStrong,
                style: TextStyle(
                  color: tokens.primaryStrong,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.82),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: tokens.primarySoft.withValues(alpha: 0.9),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: tokens.primaryStrong.withValues(alpha: 0.4),
                      width: 1.4,
                    ),
                  ),
                ),
                items: const [40, 80, 120]
                    .map(
                      (size) => DropdownMenuItem<int>(
                        value: size,
                        child: Text('$size'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) onPageSizeChanged(value);
                },
              ),
            ),
            Text(
              'Total: $totalRows',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _PalomarContextBadge extends StatelessWidget {
  final String label;
  final String value;

  const _PalomarContextBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mayoreoAreaTokens.border.withValues(alpha: 0.66),
        ),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kMayoreoMutedInk,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: kMayoreoInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PalomarDateFilterResult {
  final DateTime? from;
  final DateTime? to;
  final bool clear;

  const _PalomarDateFilterResult({this.from, this.to, this.clear = false});
}

class _PalomarDateRangeFilterDialog extends StatefulWidget {
  final String label;
  final DateTime boundsStart;
  final DateTime boundsEnd;
  final DateTime? initialFrom;
  final DateTime? initialTo;
  final Future<DateTime?> Function(DateTime? initialDate) onPickDate;

  const _PalomarDateRangeFilterDialog({
    required this.label,
    required this.boundsStart,
    required this.boundsEnd,
    required this.initialFrom,
    required this.initialTo,
    required this.onPickDate,
  });

  @override
  State<_PalomarDateRangeFilterDialog> createState() =>
      _PalomarDateRangeFilterDialogState();
}

class _PalomarDateRangeFilterDialogState
    extends State<_PalomarDateRangeFilterDialog> {
  late DateTime? _from;
  late DateTime? _to;

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
  }

  @override
  Widget build(BuildContext context) {
    return ContractDialogShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _PalomarDialogTitle(
                      icon: Icons.calendar_month_rounded,
                      title: 'Filtrar ${widget.label}',
                      subtitle:
                          'Acota movimientos por rango de fechas dentro del ledger continuo.',
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PalomarDialogFieldRow(
                left: _PalomarDialogDateField(
                  label: 'Fecha inicial',
                  value: _from,
                  onTap: () async {
                    final picked = await widget.onPickDate(
                      _from ?? widget.boundsStart,
                    );
                    if (picked == null || !mounted) return;
                    setState(() => _from = picked);
                  },
                ),
                right: _PalomarDialogDateField(
                  label: 'Fecha final',
                  value: _to,
                  onTap: () async {
                    final picked = await widget.onPickDate(
                      _to ?? widget.boundsEnd,
                    );
                    if (picked == null || !mounted) return;
                    setState(() => _to = picked);
                  },
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: _palomarSecondaryButtonStyle(),
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const _PalomarDateFilterResult(clear: true)),
                    child: const Text('Limpiar'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: _palomarSecondaryButtonStyle(),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: _palomarPrimaryButtonStyle(),
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(_PalomarDateFilterResult(from: _from, to: _to)),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Aplicar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PalomarTypeFilterDialog extends StatefulWidget {
  final _PalomarMovementType? initialValue;

  const _PalomarTypeFilterDialog({required this.initialValue});

  @override
  State<_PalomarTypeFilterDialog> createState() =>
      _PalomarTypeFilterDialogState();
}

class _PalomarTypeFilterDialogState extends State<_PalomarTypeFilterDialog> {
  late _PalomarMovementType? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return ContractDialogShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _PalomarDialogTitle(
                      icon: Icons.filter_alt_rounded,
                      title: 'Filtrar tipo de movimiento',
                      subtitle:
                          'Elige si quieres ver todo el ledger o un solo tipo.',
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        Navigator.of(context).pop(widget.initialValue),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ContractGlassCard(
                  padding: const EdgeInsets.all(10),
                  child: ListView(
                    children: [
                      _PalomarTypeChoiceRow(
                        label: 'Todos',
                        selected: _value == null,
                        onTap: () => setState(() => _value = null),
                      ),
                      for (final type in _PalomarMovementType.values)
                        _PalomarTypeChoiceRow(
                          label: _movementTypeLabel(type),
                          selected: _value == type,
                          onTap: () => setState(() => _value = type),
                        ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: _palomarSecondaryButtonStyle(),
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Limpiar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: _palomarPrimaryButtonStyle(),
                    onPressed: () => Navigator.of(context).pop(_value),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Aplicar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PalomarTextFilterDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initialValue;
  final List<String> suggestions;

  const _PalomarTextFilterDialog({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.suggestions,
  });

  @override
  State<_PalomarTextFilterDialog> createState() =>
      _PalomarTextFilterDialogState();
}

class _PalomarTextFilterDialogState extends State<_PalomarTextFilterDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toUpperCase();
    final filtered = widget.suggestions
        .where((item) => query.isEmpty || item.toUpperCase().contains(query))
        .take(12)
        .toList(growable: false);
    return ContractDialogShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _PalomarDialogTitle(
                      icon: Icons.search_rounded,
                      title: widget.title,
                      subtitle:
                          'Captura o elige una coincidencia para filtrar el ledger.',
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        Navigator.of(context).pop(widget.initialValue),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                onChanged: (_) => setState(() {}),
                decoration: contractGlassFieldDecoration(
                  context,
                  hintText: widget.label,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isNotEmpty)
                Expanded(
                  child: ContractGlassCard(
                    padding: const EdgeInsets.all(10),
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            item,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: kMayoreoInk,
                            ),
                          ),
                          onTap: () => setState(() => _controller.text = item),
                        );
                      },
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: _palomarSecondaryButtonStyle(),
                    onPressed: () => Navigator.of(context).pop(''),
                    child: const Text('Limpiar'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: _palomarSecondaryButtonStyle(),
                    onPressed: () =>
                        Navigator.of(context).pop(widget.initialValue),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: _palomarPrimaryButtonStyle(),
                    onPressed: () =>
                        Navigator.of(context).pop(_controller.text.trim()),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Aplicar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PalomarTypeChoiceRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PalomarTypeChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              gradient: selected ? kMayoreoPanelGradient : null,
              color: selected ? null : Colors.white.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? tokens.primaryStrong.withValues(alpha: 0.22)
                    : tokens.border.withValues(alpha: 0.68),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected ? tokens.primaryStrong : kMayoreoInk,
                    ),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 18,
                  color: selected ? tokens.primaryStrong : kMayoreoMutedInk,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PalomarCheckDialog extends StatefulWidget {
  final Future<DateTime?> Function(DateTime? initialDate) onPickDate;

  const _PalomarCheckDialog({required this.onPickDate});

  @override
  State<_PalomarCheckDialog> createState() => _PalomarCheckDialogState();
}

class _PalomarCheckDialogState extends State<_PalomarCheckDialog> {
  late final TextEditingController _checkC;
  late final TextEditingController _amountC;
  late final TextEditingController _bankC;
  late final TextEditingController _notesC;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _checkC = TextEditingController();
    _amountC = TextEditingController();
    _bankC = TextEditingController();
    _notesC = TextEditingController();
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _checkC.dispose();
    _amountC.dispose();
    _bankC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: ContractPopupSurface(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 520),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _PalomarDialogTitle(
                    icon: Icons.add_card_rounded,
                    title: 'Registrar cheque liberado',
                    subtitle:
                        'Cada cheque suma saldo pendiente en la cuenta corriente de El Palomar.',
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _PalomarSummaryCard(
                            icon: Icons.request_page_rounded,
                            title: 'TIPO',
                            value: 'Cheque liberado',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PalomarSummaryCard(
                            icon: Icons.payments_outlined,
                            title: 'MONTO CAPTURADO',
                            value: _amountC.text.trim().isEmpty
                                ? 'Sin monto'
                                : formatMoney(
                                    _parseAmount(_amountC.text),
                                    decimals: 0,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _PalomarDialogSection(
                      icon: Icons.account_balance_wallet_outlined,
                      title: '1. Datos del cheque',
                      child: Column(
                        children: [
                          _PalomarDialogFieldRow(
                            left: _PalomarDialogTextField(
                              controller: _checkC,
                              label: 'Número de cheque',
                              hintText: 'Cheque',
                              onChanged: (_) => setState(() {}),
                            ),
                            right: _PalomarDialogDateField(
                              label: 'Fecha',
                              value: _date,
                              onTap: () async {
                                final picked = await widget.onPickDate(_date);
                                if (picked == null || !mounted) return;
                                setState(() => _date = picked);
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          _PalomarDialogFieldRow(
                            left: _PalomarDialogTextField(
                              controller: _amountC,
                              label: 'Monto',
                              hintText: '0.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => setState(() {}),
                            ),
                            right: _PalomarDialogTextField(
                              controller: _bankC,
                              label: 'Banco o referencia',
                              hintText: 'Banco / referencia',
                            ),
                          ),
                          const SizedBox(height: 10),
                          _PalomarDialogTextField(
                            controller: _notesC,
                            label: 'Observaciones',
                            hintText: 'Observaciones',
                            minLines: 3,
                            maxLines: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: _palomarSecondaryButtonStyle(),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancelar'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: _palomarPrimaryButtonStyle(),
                  onPressed: _canSave
                      ? () => Navigator.of(context).pop(
                          _PalomarMovement(
                            id: DateTime.now().microsecondsSinceEpoch
                                .toString(),
                            createdAt: DateTime.now(),
                            date: _date!,
                            type: _PalomarMovementType.chequeLiberado,
                            reference: 'Cheque liberado',
                            checkNumber: _checkC.text.trim(),
                            remision: '',
                            ticket: '',
                            client: 'EL PALOMAR',
                            material: '',
                            exitWeight: null,
                            approvedWeight: null,
                            approvedPrice: null,
                            amount: _parseAmount(_amountC.text),
                            notes: _notesC.text.trim(),
                            bankReference: _bankC.text.trim(),
                            sourceReportId: null,
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar cheque'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSave =>
      _date != null &&
      _checkC.text.trim().isNotEmpty &&
      _parseAmount(_amountC.text) > 0;
}

class _PalomarAdjustmentDialog extends StatefulWidget {
  final Future<DateTime?> Function(DateTime? initialDate) onPickDate;

  const _PalomarAdjustmentDialog({required this.onPickDate});

  @override
  State<_PalomarAdjustmentDialog> createState() =>
      _PalomarAdjustmentDialogState();
}

class _PalomarAdjustmentDialogState extends State<_PalomarAdjustmentDialog> {
  late final TextEditingController _amountC;
  late final TextEditingController _motiveC;
  late final TextEditingController _notesC;
  DateTime? _date;
  bool _isCharge = true;

  @override
  void initState() {
    super.initState();
    _amountC = TextEditingController();
    _motiveC = TextEditingController();
    _notesC = TextEditingController();
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _amountC.dispose();
    _motiveC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: ContractPopupSurface(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 540),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _PalomarDialogTitle(
                    icon: Icons.tune_rounded,
                    title: 'Registrar ajuste manual',
                    subtitle:
                        'Un cargo aumenta saldo y un abono lo reduce, siempre con trazabilidad.',
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _PalomarSummaryCard(
                            icon: _isCharge
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            title: 'TIPO AJUSTE',
                            value: _isCharge ? 'Cargo' : 'Abono',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PalomarSummaryCard(
                            icon: Icons.payments_outlined,
                            title: 'MONTO CAPTURADO',
                            value: _amountC.text.trim().isEmpty
                                ? 'Sin monto'
                                : formatMoney(
                                    _parseAmount(_amountC.text),
                                    decimals: 0,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _PalomarDialogSection(
                      icon: Icons.tune_rounded,
                      title: '1. Datos del ajuste',
                      child: Column(
                        children: [
                          _PalomarDialogFieldRow(
                            left: _PalomarDialogDateField(
                              label: 'Fecha',
                              value: _date,
                              onTap: () async {
                                final picked = await widget.onPickDate(_date);
                                if (picked == null || !mounted) return;
                                setState(() => _date = picked);
                              },
                            ),
                            right: _PalomarDialogTextField(
                              controller: _amountC,
                              label: 'Monto',
                              hintText: '0.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment<bool>(
                                value: true,
                                label: Text('Cargo'),
                              ),
                              ButtonSegment<bool>(
                                value: false,
                                label: Text('Abono'),
                              ),
                            ],
                            selected: <bool>{_isCharge},
                            onSelectionChanged: (next) =>
                                setState(() => _isCharge = next.first),
                          ),
                          const SizedBox(height: 10),
                          _PalomarDialogTextField(
                            controller: _motiveC,
                            label: 'Motivo',
                            hintText: 'Motivo del ajuste',
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 10),
                          _PalomarDialogTextField(
                            controller: _notesC,
                            label: 'Observaciones',
                            hintText: 'Observaciones',
                            minLines: 3,
                            maxLines: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: _palomarSecondaryButtonStyle(),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancelar'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: _palomarPrimaryButtonStyle(),
                  onPressed: _canSave
                      ? () => Navigator.of(context).pop(
                          _PalomarMovement(
                            id: DateTime.now().microsecondsSinceEpoch
                                .toString(),
                            createdAt: DateTime.now(),
                            date: _date!,
                            type: _isCharge
                                ? _PalomarMovementType.ajusteCargo
                                : _PalomarMovementType.ajusteAbono,
                            reference: _motiveC.text.trim(),
                            checkNumber: '',
                            remision: '',
                            ticket: '',
                            client: '',
                            material: '',
                            exitWeight: null,
                            approvedWeight: null,
                            approvedPrice: null,
                            amount: _parseAmount(_amountC.text),
                            notes: _notesC.text.trim(),
                            bankReference: '',
                            sourceReportId: null,
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar ajuste'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSave =>
      _date != null &&
      _motiveC.text.trim().isNotEmpty &&
      _parseAmount(_amountC.text) > 0;
}

class _PalomarApplyRemissionsDialog extends StatefulWidget {
  final List<_PalomarSourceRemission> remissions;
  final Set<String> appliedIds;
  final _PalomarRemissionState Function(_PalomarSourceRemission row) onStateFor;

  const _PalomarApplyRemissionsDialog({
    required this.remissions,
    required this.appliedIds,
    required this.onStateFor,
  });

  @override
  State<_PalomarApplyRemissionsDialog> createState() =>
      _PalomarApplyRemissionsDialogState();
}

class _PalomarApplyRemissionsDialogState
    extends State<_PalomarApplyRemissionsDialog> {
  final Set<String> _selectedIds = <String>{};
  final TextEditingController _searchC = TextEditingController();
  _PalomarRemissionState? _stateFilter;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchC.text.trim().toUpperCase();
    final rows =
        widget.remissions
            .where((row) {
              final state = widget.onStateFor(row);
              if (_stateFilter != null && state != _stateFilter) return false;
              if (query.isEmpty) return true;
              return _containsAny(<String>[
                row.ticket,
                row.remision,
                row.clientName,
                row.materialName,
              ], query);
            })
            .toList(growable: false)
          ..sort((a, b) => b.saleDate.compareTo(a.saleDate));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: ContractPopupSurface(
        constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 720),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _PalomarDialogTitle(
                    icon: Icons.link_rounded,
                    title: 'Aplicar remisiones',
                    subtitle:
                        'Selecciona manualmente remisiones disponibles para reducir saldo sin duplicarlas.',
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PalomarSummaryCard(
                    icon: Icons.checklist_rounded,
                    title: 'SELECCIONADAS',
                    value: '${_selectedIds.length}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PalomarSummaryCard(
                    icon: Icons.inventory_2_outlined,
                    title: 'VISIBLES',
                    value: '${rows.length}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 10,
                    child: _PalomarDialogSection(
                      icon: Icons.filter_alt_rounded,
                      title: '1. Búsqueda y filtro',
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchC,
                            onChanged: (_) => setState(() {}),
                            decoration: contractGlassFieldDecoration(
                              context,
                              hintText:
                                  'Buscar ticket, remisión, cliente o material',
                              prefixIcon: const Icon(Icons.search_rounded),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Theme(
                            data: Theme.of(context).copyWith(
                              canvasColor: mayoreoAreaTokens.surfaceTint,
                            ),
                            child:
                                DropdownButtonFormField<
                                  _PalomarRemissionState?
                                >(
                                  initialValue: _stateFilter,
                                  decoration: contractGlassFieldDecoration(
                                    context,
                                    hintText: 'Estado',
                                  ),
                                  items:
                                      <
                                        DropdownMenuItem<
                                          _PalomarRemissionState?
                                        >
                                      >[
                                        const DropdownMenuItem<
                                          _PalomarRemissionState?
                                        >(value: null, child: Text('Todos')),
                                        ..._PalomarRemissionState.values.map(
                                          (state) =>
                                              DropdownMenuItem<
                                                _PalomarRemissionState?
                                              >(
                                                value: state,
                                                child: Text(
                                                  _remissionStateLabel(state),
                                                ),
                                              ),
                                        ),
                                      ],
                                  onChanged: (value) =>
                                      setState(() => _stateFilter = value),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 18,
                    child: _PalomarDialogSection(
                      icon: Icons.link_rounded,
                      title: '2. Remisiones disponibles',
                      expandChild: true,
                      child: rows.isEmpty
                          ? const Center(
                              child: Text(
                                'No hay remisiones que coincidan con el filtro.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: kMayoreoMutedInk,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.separated(
                              itemCount: rows.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final row = rows[index];
                                final state = widget.onStateFor(row);
                                final selectable =
                                    state == _PalomarRemissionState.disponible;
                                final checked = _selectedIds.contains(row.id);
                                return _PalomarRemissionPickCard(
                                  row: row,
                                  state: state,
                                  checked: checked,
                                  selectable: selectable,
                                  onToggle: selectable
                                      ? () {
                                          setState(() {
                                            if (checked) {
                                              _selectedIds.remove(row.id);
                                            } else {
                                              _selectedIds.add(row.id);
                                            }
                                          });
                                        }
                                      : null,
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${_selectedIds.length} remisiones seleccionadas',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: kMayoreoMutedInk,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  style: _palomarSecondaryButtonStyle(),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancelar'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: _palomarPrimaryButtonStyle(),
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(
                          rows
                              .where((row) => _selectedIds.contains(row.id))
                              .toList(growable: false),
                        ),
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Aplicar selección'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PalomarCutDialog extends StatefulWidget {
  final List<_PalomarLedgerEntry> ledgerEntries;
  final Future<DateTime?> Function(DateTime? initialDate) onPickDate;

  const _PalomarCutDialog({
    required this.ledgerEntries,
    required this.onPickDate,
  });

  @override
  State<_PalomarCutDialog> createState() => _PalomarCutDialogState();
}

class _PalomarCutDialogState extends State<_PalomarCutDialog> {
  DateTime? _from;
  DateTime? _to;
  late final TextEditingController _notesC;

  @override
  void initState() {
    super.initState();
    _notesC = TextEditingController();
    final lastDate = widget.ledgerEntries.isEmpty
        ? DateTime.now()
        : widget.ledgerEntries.last.movement.date;
    _to = lastDate;
    _from = lastDate.subtract(const Duration(days: 30));
  }

  @override
  void dispose() {
    _notesC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _buildCutSummary(widget.ledgerEntries, _from, _to);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: ContractPopupSurface(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 560),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _PalomarDialogTitle(
                    icon: Icons.view_timeline_rounded,
                    title: 'Crear corte interno',
                    subtitle:
                        'Agrupa visualmente movimientos por periodo, sin bloquear la operación corriente.',
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _PalomarSummaryCard(
                            icon: Icons.playlist_add_check_circle_outlined,
                            title: 'SALDO INICIAL',
                            value: formatMoney(
                              summary.openingBalance,
                              decimals: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PalomarSummaryCard(
                            icon: Icons.flag_outlined,
                            title: 'SALDO FINAL',
                            value: formatMoney(
                              summary.closingBalance,
                              decimals: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _PalomarDialogSection(
                      icon: Icons.view_timeline_rounded,
                      title: '1. Periodo del corte',
                      child: Column(
                        children: [
                          _PalomarDialogFieldRow(
                            left: _PalomarDialogDateField(
                              label: 'Fecha inicial',
                              value: _from,
                              onTap: () async {
                                final picked = await widget.onPickDate(_from);
                                if (picked == null || !mounted) return;
                                setState(() => _from = picked);
                              },
                            ),
                            right: _PalomarDialogDateField(
                              label: 'Fecha final',
                              value: _to,
                              onTap: () async {
                                final picked = await widget.onPickDate(_to);
                                if (picked == null || !mounted) return;
                                setState(() => _to = picked);
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          _PalomarCutSummaryCard(summary: summary),
                          const SizedBox(height: 12),
                          _PalomarDialogTextField(
                            controller: _notesC,
                            label: 'Observaciones',
                            hintText: 'Observaciones del corte',
                            minLines: 3,
                            maxLines: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: _palomarSecondaryButtonStyle(),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancelar'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: _palomarPrimaryButtonStyle(),
                  onPressed: _from == null || _to == null
                      ? null
                      : () => Navigator.of(context).pop(
                          _PalomarMovement(
                            id: DateTime.now().microsecondsSinceEpoch
                                .toString(),
                            createdAt: DateTime.now(),
                            date: _to!,
                            type: _PalomarMovementType.corteInterno,
                            reference: 'Corte interno',
                            checkNumber: '',
                            remision: '',
                            ticket: '',
                            client: '',
                            material: '',
                            exitWeight: null,
                            approvedWeight: null,
                            approvedPrice: null,
                            amount: 0,
                            notes:
                                'Periodo ${_formatPalomarDate(_from!)} a ${_formatPalomarDate(_to!)} · ${_notesC.text.trim()}',
                            bankReference: '',
                            sourceReportId: null,
                            periodStart: _from,
                            periodEnd: _to,
                            periodOpeningBalance: summary.openingBalance,
                            periodClosingBalance: summary.closingBalance,
                            periodChecksTotal: summary.checksReleased,
                            periodAppliedTotal: summary.remissionsApplied,
                            periodAdjustmentsTotal: summary.adjustments,
                          ),
                        ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar corte'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PalomarHistoryDialog extends StatelessWidget {
  final List<_PalomarLedgerEntry> entries;

  const _PalomarHistoryDialog({required this.entries});

  @override
  Widget build(BuildContext context) {
    final sorted = entries
        .toList(growable: false)
        .reversed
        .toList(growable: false);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: ContractPopupSurface(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 760),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _PalomarDialogTitle(
                    icon: Icons.history_rounded,
                    title: 'Historial de movimientos',
                    subtitle:
                        'Ledger completo de cheques, remisiones, ajustes y cortes internos.',
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _PalomarLedgerCard(
                entries: sorted,
                pageEntries: sorted,
                selectedMovementId: null,
                selectedMovementIds: const <String>{},
                rowKeyForId: (rowId) => GlobalKey(debugLabel: 'history_$rowId'),
                viewportKey: GlobalKey(debugLabel: 'history_viewport'),
                hasDateFilter: false,
                hasTypeFilter: false,
                hasCheckFilter: false,
                hasRemisionFilter: false,
                hasMaterialFilter: false,
                hasReferenceFilter: false,
                onOpenDateFilter: () async {},
                onOpenTypeFilter: () async {},
                onOpenCheckFilter: () async {},
                onOpenRemisionFilter: () async {},
                onOpenMaterialFilter: () async {},
                onOpenReferenceFilter: () async {},
                onTapRow: (_) {},
                onRowPrimaryPointerDown: (_) {},
                onRowDragEnter: (_) {},
                onDoubleTapRow: (_) async {},
                onRowsPointerDown: (_) {},
                onRowsPointerMove: (_) {},
                onRowPointerEnd: () {},
                onSecondaryTapDown: (_, _) async {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PalomarEditMovementDialog extends StatefulWidget {
  final _PalomarMovement movement;
  final Future<DateTime?> Function(DateTime? initialDate) onPickDate;

  const _PalomarEditMovementDialog({
    required this.movement,
    required this.onPickDate,
  });

  @override
  State<_PalomarEditMovementDialog> createState() =>
      _PalomarEditMovementDialogState();
}

class _PalomarEditMovementDialogState
    extends State<_PalomarEditMovementDialog> {
  late final TextEditingController _referenceC;
  late final TextEditingController _checkC;
  late final TextEditingController _remisionC;
  late final TextEditingController _ticketC;
  late final TextEditingController _materialC;
  late final TextEditingController _exitWeightC;
  late final TextEditingController _approvedWeightC;
  late final TextEditingController _approvedPriceC;
  late final TextEditingController _amountC;
  late final TextEditingController _bankC;
  late final TextEditingController _notesC;
  late DateTime _date;
  late _PalomarMovementType _type;

  @override
  void initState() {
    super.initState();
    final movement = widget.movement;
    _referenceC = TextEditingController(text: movement.reference);
    _checkC = TextEditingController(text: movement.checkNumber);
    _remisionC = TextEditingController(text: movement.remision);
    _ticketC = TextEditingController(text: movement.ticket);
    _materialC = TextEditingController(text: movement.material);
    _exitWeightC = TextEditingController(
      text: movement.exitWeight == null
          ? ''
          : formatDecimal(movement.exitWeight!),
    );
    _approvedWeightC = TextEditingController(
      text: movement.approvedWeight == null
          ? ''
          : formatDecimal(movement.approvedWeight!),
    );
    _approvedPriceC = TextEditingController(
      text: movement.approvedPrice == null
          ? ''
          : movement.approvedPrice!.toStringAsFixed(2),
    );
    _amountC = TextEditingController(text: movement.amount.toStringAsFixed(2));
    _bankC = TextEditingController(text: movement.bankReference);
    _notesC = TextEditingController(text: movement.notes);
    _date = movement.date;
    _type = movement.type;
    _approvedWeightC.addListener(_syncRemissionAmount);
    _approvedPriceC.addListener(_syncRemissionAmount);
  }

  @override
  void dispose() {
    _referenceC.dispose();
    _checkC.dispose();
    _remisionC.dispose();
    _ticketC.dispose();
    _materialC.dispose();
    _exitWeightC.dispose();
    _approvedWeightC.dispose();
    _approvedPriceC.dispose();
    _amountC.dispose();
    _bankC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  bool get _isRemission => _type == _PalomarMovementType.remisionAplicada;
  bool get _isCheck => _type == _PalomarMovementType.chequeLiberado;
  bool get _isAdjustment =>
      _type == _PalomarMovementType.ajusteCargo ||
      _type == _PalomarMovementType.ajusteAbono;
  bool get _isCut => _type == _PalomarMovementType.corteInterno;

  void _syncRemissionAmount() {
    if (!_isRemission) return;
    final weight = _parseAmount(_approvedWeightC.text);
    final price = _parseAmount(_approvedPriceC.text);
    if (weight <= 0 || price <= 0) return;
    final next = (weight * price).toStringAsFixed(2);
    if (_amountC.text != next) {
      _amountC.text = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: ContractPopupSurface(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 620),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _PalomarDialogTitle(
                    icon: Icons.edit_note_rounded,
                    title: 'Editar movimiento',
                    subtitle:
                        'Ajusta datos del ledger sin romper la trazabilidad de la cuenta.',
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _PalomarSummaryCard(
                            icon: Icons.tune_rounded,
                            title: 'MOVIMIENTO',
                            value: _movementTypeLabel(_type),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PalomarSummaryCard(
                            icon: Icons.payments_outlined,
                            title: 'MONTO',
                            value: formatMoney(
                              _parseAmount(_amountC.text),
                              decimals: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _PalomarDialogSection(
                      icon: Icons.edit_rounded,
                      title: '1. Datos del movimiento',
                      child: Column(
                        children: [
                          _PalomarDialogFieldRow(
                            left: _PalomarDialogDateField(
                              label: 'Fecha',
                              value: _date,
                              onTap: () async {
                                final picked = await widget.onPickDate(_date);
                                if (picked == null || !mounted) return;
                                setState(() => _date = picked);
                              },
                            ),
                            right: _PalomarDialogTextField(
                              controller: _referenceC,
                              label: _isCut ? 'Referencia' : 'Concepto',
                              hintText: 'Referencia',
                            ),
                          ),
                          if (_isCheck) ...[
                            const SizedBox(height: 10),
                            _PalomarDialogFieldRow(
                              left: _PalomarDialogTextField(
                                controller: _checkC,
                                label: 'Cheque',
                                hintText: 'Cheque',
                              ),
                              right: _PalomarDialogTextField(
                                controller: _bankC,
                                label: 'Banco o referencia',
                                hintText: 'Banco / referencia',
                              ),
                            ),
                          ],
                          if (_isRemission) ...[
                            const SizedBox(height: 10),
                            _PalomarDialogFieldRow(
                              left: _PalomarDialogTextField(
                                controller: _remisionC,
                                label: 'Remisión',
                                hintText: 'Remisión',
                              ),
                              right: _PalomarDialogTextField(
                                controller: _ticketC,
                                label: 'Ticket',
                                hintText: 'Ticket',
                              ),
                            ),
                            const SizedBox(height: 10),
                            _PalomarDialogTextField(
                              controller: _materialC,
                              label: 'Material',
                              hintText: 'Material',
                            ),
                            const SizedBox(height: 10),
                            _PalomarDialogFieldRow(
                              left: _PalomarDialogTextField(
                                controller: _exitWeightC,
                                label: 'Peso salida KG',
                                hintText: '0.00',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                              right: _PalomarDialogTextField(
                                controller: _approvedWeightC,
                                label: 'Peso aprobado KG',
                                hintText: '0.00',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _PalomarDialogFieldRow(
                              left: _PalomarDialogTextField(
                                controller: _approvedPriceC,
                                label: 'Precio aprobado',
                                hintText: '0.00',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (_) => setState(() {}),
                              ),
                              right: _PalomarDialogTextField(
                                controller: _amountC,
                                label: 'Monto',
                                hintText: '0.00',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ] else if (!_isCut) ...[
                            const SizedBox(height: 10),
                            _PalomarDialogTextField(
                              controller: _amountC,
                              label: 'Monto',
                              hintText: '0.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                          const SizedBox(height: 10),
                          _PalomarDialogTextField(
                            controller: _notesC,
                            label: 'Observaciones',
                            hintText: 'Observaciones',
                            minLines: 3,
                            maxLines: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: _palomarSecondaryButtonStyle(),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancelar'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: _palomarPrimaryButtonStyle(),
                  onPressed: _canSave
                      ? () => Navigator.of(context).pop(_buildMovement())
                      : null,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar cambios'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSave {
    if (_isCut) return true;
    if (_isCheck) {
      return _checkC.text.trim().isNotEmpty && _parseAmount(_amountC.text) > 0;
    }
    if (_isAdjustment) {
      return _referenceC.text.trim().isNotEmpty &&
          _parseAmount(_amountC.text) > 0;
    }
    if (_isRemission) {
      return (_remisionC.text.trim().isNotEmpty ||
              _ticketC.text.trim().isNotEmpty) &&
          _parseAmount(_amountC.text) > 0;
    }
    return true;
  }

  _PalomarMovement _buildMovement() {
    return widget.movement.copyWith(
      date: _date,
      reference: _referenceC.text.trim(),
      checkNumber: _checkC.text.trim(),
      remision: _remisionC.text.trim(),
      ticket: _ticketC.text.trim(),
      material: _materialC.text.trim(),
      exitWeight: _parseOptionalAmount(_exitWeightC.text),
      approvedWeight: _parseOptionalAmount(_approvedWeightC.text),
      approvedPrice: _parseOptionalAmount(_approvedPriceC.text),
      amount: _isCut ? widget.movement.amount : _parseAmount(_amountC.text),
      notes: _notesC.text.trim(),
      bankReference: _bankC.text.trim(),
    );
  }
}

class _PalomarDialogTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PalomarDialogTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: kMayoreoHeroGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.18),
            ),
          ),
          child: Icon(icon, color: mayoreoAreaTokens.primaryStrong),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: kMayoreoInk,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kMayoreoMutedInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PalomarDialogSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final bool expandChild;

  const _PalomarDialogSection({
    required this.icon,
    required this.title,
    required this.child,
    this.expandChild = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: mayoreoAreaTokens.border.withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: mayoreoAreaTokens.primaryStrong),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: kMayoreoInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class _PalomarSummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _PalomarSummaryCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: kMayoreoPanelGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: mayoreoAreaTokens.border.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: mayoreoAreaTokens.primaryStrong),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: kMayoreoMutedInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: kMayoreoInk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PalomarDialogFieldRow extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _PalomarDialogFieldRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }
}

class _PalomarDialogDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final Future<void> Function() onTap;

  const _PalomarDialogDateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PalomarDialogShellField(
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => unawaited(onTap()),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null
                    ? 'Seleccionar fecha'
                    : _formatPalomarDate(value!),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: value == null ? kMayoreoMutedInk : kMayoreoInk,
                ),
              ),
            ),
            const Icon(Icons.calendar_month_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _PalomarDialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;

  const _PalomarDialogTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.keyboardType,
    this.minLines,
    this.maxLines,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _PalomarDialogShellField(
      label: label,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: maxLines ?? 1,
        onChanged: onChanged,
        decoration: InputDecoration.collapsed(hintText: hintText),
      ),
    );
  }
}

class _PalomarDialogShellField extends StatelessWidget {
  final String label;
  final Widget child;

  const _PalomarDialogShellField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: mayoreoAreaTokens.border.withValues(alpha: 0.66),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: kMayoreoMutedInk,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _PalomarRemissionPickCard extends StatelessWidget {
  final _PalomarSourceRemission row;
  final _PalomarRemissionState state;
  final bool checked;
  final bool selectable;
  final VoidCallback? onToggle;

  const _PalomarRemissionPickCard({
    required this.row,
    required this.state,
    required this.checked,
    required this.selectable,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final stateScheme = _remissionStateScheme(state);

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: checked
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    mayoreoAreaTokens.badgeBackground.withValues(alpha: 0.98),
                    mayoreoAreaTokens.primarySoft.withValues(alpha: 0.92),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.78),
                    mayoreoAreaTokens.surfaceTint.withValues(alpha: 0.74),
                  ],
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: checked
                ? mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.30)
                : mayoreoAreaTokens.border.withValues(alpha: 0.60),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: checked,
                  onChanged: selectable ? (_) => onToggle?.call() : null,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row.ticket} · ${row.remision}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: kMayoreoInk,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        row.clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kMayoreoMutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  constraints: const BoxConstraints(minHeight: 34),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: stateScheme.$2,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: stateScheme.$3),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _remissionStateLabel(state),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: stateScheme.$1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _PalomarContextBadge(
                  label: 'Fecha',
                  value: _formatPalomarDate(row.saleDate),
                ),
                _PalomarContextBadge(
                  label: 'Material',
                  value: row.materialName,
                ),
                _PalomarContextBadge(
                  label: 'Peso aprobado',
                  value: '${formatDecimal(row.approvedWeight ?? 0)} KG',
                ),
                _PalomarContextBadge(
                  label: 'Importe aprobado',
                  value: formatMoney(row.approvedAmount, decimals: 0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PalomarCutSummaryCard extends StatelessWidget {
  final _PalomarCutSummary summary;

  const _PalomarCutSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _PalomarContextBadge(
            label: 'Saldo inicial',
            value: formatMoney(summary.openingBalance, decimals: 0),
          ),
          _PalomarContextBadge(
            label: 'Cheques periodo',
            value: formatMoney(summary.checksReleased, decimals: 0),
          ),
          _PalomarContextBadge(
            label: 'Remisiones periodo',
            value: formatMoney(summary.remissionsApplied, decimals: 0),
          ),
          _PalomarContextBadge(
            label: 'Ajustes periodo',
            value: formatMoney(summary.adjustments, decimals: 0),
          ),
          _PalomarContextBadge(
            label: 'Saldo final',
            value: formatMoney(summary.closingBalance, decimals: 0),
          ),
        ],
      ),
    );
  }
}

class _PalomarHeaderBrand extends StatelessWidget {
  const _PalomarHeaderBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.46)),
            boxShadow: [
              BoxShadow(
                color: mayoreoAreaTokens.glow.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Center(child: DicsaLogoD(size: 36, progress: 1)),
        ),
        const SizedBox(width: 14),
        const Text(
          'Cuenta El Palomar',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: kMayoreoInk,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _PalomarHeaderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final bool compact;

  const _PalomarHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap:
            onTapSync ??
            (onTap == null ? null : () => unawaited(onTap!.call())),
        child: Ink(
          width: compact ? 56 : 176,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.40)),
            boxShadow: [
              BoxShadow(
                color: tokens.primaryStrong.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              if (compact)
                Expanded(
                  child: Center(
                    child: Icon(icon, size: 20, color: tokens.primaryStrong),
                  ),
                )
              else ...[
                const SizedBox(width: 12),
                Icon(icon, size: 22, color: tokens.primaryStrong),
                const SizedBox(width: 10),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: tokens.primaryStrong,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PalomarBackground extends StatelessWidget {
  const _PalomarBackground();

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
                const Color(0xFFFFF1B8),
                tokens.accent.withValues(alpha: 0.34),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: -260,
          top: -130,
          child: _backgroundCircle(
            760,
            LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.88),
                const Color(0xFFFFED9C),
              ],
            ),
          ),
        ),
        Positioned(
          right: -180,
          top: -70,
          child: _backgroundCircle(
            580,
            LinearGradient(
              colors: [
                const Color(0xFFFFE94A).withValues(alpha: 0.78),
                const Color(0xFFF9A411).withValues(alpha: 0.18),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          bottom: -260,
          child: _backgroundCircle(
            640,
            LinearGradient(
              colors: [
                const Color(0xFFF88C12).withValues(alpha: 0.22),
                tokens.primarySoft.withValues(alpha: 0.88),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _backgroundCircle(double diameter, Gradient gradient) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              blurRadius: diameter * 0.10,
              spreadRadius: diameter * 0.015,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: SizedBox(width: diameter, height: diameter),
      ),
    );
  }
}

class _PalomarSidePanel extends StatelessWidget {
  final bool canReturnToDirection;
  final ValueChanged<String> onNavigate;

  const _PalomarSidePanel({
    required this.canReturnToDirection,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ContractGlassCard(
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mayoreo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              if (canReturnToDirection) ...[
                _PalomarNavItem(
                  icon: Icons.arrow_back_rounded,
                  title: 'Volver a Dirección',
                  onTapSync: () => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 10),
              ],
              const _PalomarSectionHeader(label: 'MENU'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.primarySoft.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: tokens.primaryStrong.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  children: [
                    _PalomarNavItem(
                      icon: Icons.point_of_sale_rounded,
                      title: 'Ventas',
                      subtitle: 'Reporte comercial base',
                      onTapSync: () => onNavigate('Ventas Mayoreo'),
                    ),
                    const SizedBox(height: 8),
                    _PalomarNavItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Cuentas',
                      subtitle: 'Seguimiento financiero',
                      onTapSync: () => onNavigate('Cuentas'),
                    ),
                    const SizedBox(height: 8),
                    const _PalomarNavItem(
                      icon: Icons.currency_exchange_rounded,
                      title: 'Cuenta El Palomar',
                      subtitle: 'Cuenta corriente especial',
                      accented: true,
                    ),
                    const SizedBox(height: 8),
                    _PalomarNavItem(
                      icon: Icons.price_check_rounded,
                      title: 'Catálogo',
                      subtitle: 'Clientes, materiales y precios',
                      onTapSync: () => onNavigate('Catálogo'),
                    ),
                    const SizedBox(height: 8),
                    _PalomarNavItem(
                      icon: Icons.request_quote_rounded,
                      title: 'Ajuste de precios',
                      subtitle: 'Vigentes e historial',
                      onTapSync: () => onNavigate('Ajuste de precios'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _PalomarSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              if (canReturnToDirection) ...[
                _PalomarNavItem(
                  icon: Icons.assessment_outlined,
                  title: 'Dashboard Dirección',
                  subtitle: 'Vista ejecutiva multiarea',
                  onTapSync: () => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 8),
              ],
              _PalomarNavItem(
                icon: Icons.space_dashboard_rounded,
                title: 'Dashboard Mayoreo',
                subtitle: 'Vista general del área',
                onTapSync: () => onNavigate('Dashboard Mayoreo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PalomarSectionHeader extends StatelessWidget {
  final String label;

  const _PalomarSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.4,
        color: tokens.badgeText,
      ),
    );
  }
}

class _PalomarNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool accented;
  final VoidCallback? onTapSync;

  const _PalomarNavItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.accented = false,
    this.onTapSync,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTapSync,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: accented ? kMayoreoPanelGradient : null,
            color: accented ? null : Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accented
                  ? tokens.primaryStrong.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.26),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accented
                      ? tokens.primaryStrong.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accented
                        ? tokens.primaryStrong.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.42),
                  ),
                ),
                child: Icon(icon, size: 18, color: tokens.primaryStrong),
              ),
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
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.badgeText,
                        ),
                      ),
                    ],
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

class _PalomarMovement {
  final String id;
  final DateTime createdAt;
  final DateTime date;
  final _PalomarMovementType type;
  final String reference;
  final String checkNumber;
  final String remision;
  final String ticket;
  final String client;
  final String material;
  final double? exitWeight;
  final double? approvedWeight;
  final double? approvedPrice;
  final double amount;
  final String notes;
  final String bankReference;
  final String? sourceReportId;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double? periodOpeningBalance;
  final double? periodClosingBalance;
  final double? periodChecksTotal;
  final double? periodAppliedTotal;
  final double? periodAdjustmentsTotal;

  const _PalomarMovement({
    required this.id,
    required this.createdAt,
    required this.date,
    required this.type,
    required this.reference,
    required this.checkNumber,
    required this.remision,
    required this.ticket,
    required this.client,
    required this.material,
    required this.exitWeight,
    required this.approvedWeight,
    required this.approvedPrice,
    required this.amount,
    required this.notes,
    required this.bankReference,
    required this.sourceReportId,
    this.periodStart,
    this.periodEnd,
    this.periodOpeningBalance,
    this.periodClosingBalance,
    this.periodChecksTotal,
    this.periodAppliedTotal,
    this.periodAdjustmentsTotal,
  });

  double get signedAmount {
    switch (type) {
      case _PalomarMovementType.chequeLiberado:
      case _PalomarMovementType.ajusteCargo:
        return amount;
      case _PalomarMovementType.remisionAplicada:
      case _PalomarMovementType.ajusteAbono:
        return -amount;
      case _PalomarMovementType.corteInterno:
        return 0;
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'date': date.toIso8601String(),
    'type': type.name,
    'reference': reference,
    'checkNumber': checkNumber,
    'remision': remision,
    'ticket': ticket,
    'client': client,
    'material': material,
    'exitWeight': exitWeight,
    'approvedWeight': approvedWeight,
    'approvedPrice': approvedPrice,
    'amount': amount,
    'notes': notes,
    'bankReference': bankReference,
    'sourceReportId': sourceReportId,
    'periodStart': periodStart?.toIso8601String(),
    'periodEnd': periodEnd?.toIso8601String(),
    'periodOpeningBalance': periodOpeningBalance,
    'periodClosingBalance': periodClosingBalance,
    'periodChecksTotal': periodChecksTotal,
    'periodAppliedTotal': periodAppliedTotal,
    'periodAdjustmentsTotal': periodAdjustmentsTotal,
  };

  Map<String, dynamic> toSupabase() => <String, dynamic>{
    'id': id,
    'created_at': createdAt.toIso8601String(),
    'date': date.toIso8601String(),
    'type': type.name,
    'reference': reference,
    'check_number': checkNumber,
    'remision': remision,
    'ticket': ticket,
    'client_name_snapshot': client,
    'material_name_snapshot': material,
    'exit_weight': exitWeight,
    'approved_weight': approvedWeight,
    'approved_price': approvedPrice,
    'amount': amount,
    'notes': notes.isEmpty ? null : notes,
    'bank_reference': bankReference.isEmpty ? null : bankReference,
    'source_report_id': sourceReportId,
    'period_start': periodStart?.toIso8601String(),
    'period_end': periodEnd?.toIso8601String(),
    'period_opening_balance': periodOpeningBalance,
    'period_closing_balance': periodClosingBalance,
    'period_checks_total': periodChecksTotal,
    'period_applied_total': periodAppliedTotal,
    'period_adjustments_total': periodAdjustmentsTotal,
  };

  factory _PalomarMovement.fromSupabase(Map<String, dynamic> json) {
    return _PalomarMovement(
      id: (json['id'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.now(),
      date:
          DateTime.tryParse((json['date'] as String?) ?? '') ?? DateTime.now(),
      type: _PalomarMovementType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => _PalomarMovementType.chequeLiberado,
      ),
      reference: (json['reference'] as String?) ?? '',
      checkNumber: (json['check_number'] as String?) ?? '',
      remision: (json['remision'] as String?) ?? '',
      ticket: (json['ticket'] as String?) ?? '',
      client: (json['client_name_snapshot'] as String?) ?? '',
      material: (json['material_name_snapshot'] as String?) ?? '',
      exitWeight: (json['exit_weight'] as num?)?.toDouble(),
      approvedWeight: (json['approved_weight'] as num?)?.toDouble(),
      approvedPrice: (json['approved_price'] as num?)?.toDouble(),
      amount: ((json['amount'] as num?) ?? 0).toDouble(),
      notes: (json['notes'] as String?) ?? '',
      bankReference: (json['bank_reference'] as String?) ?? '',
      sourceReportId: json['source_report_id'] as String?,
      periodStart: DateTime.tryParse((json['period_start'] as String?) ?? ''),
      periodEnd: DateTime.tryParse((json['period_end'] as String?) ?? ''),
      periodOpeningBalance: (json['period_opening_balance'] as num?)
          ?.toDouble(),
      periodClosingBalance: (json['period_closing_balance'] as num?)
          ?.toDouble(),
      periodChecksTotal: (json['period_checks_total'] as num?)?.toDouble(),
      periodAppliedTotal: (json['period_applied_total'] as num?)?.toDouble(),
      periodAdjustmentsTotal: (json['period_adjustments_total'] as num?)
          ?.toDouble(),
    );
  }

  _PalomarMovement copyWith({
    DateTime? date,
    _PalomarMovementType? type,
    String? reference,
    String? checkNumber,
    String? remision,
    String? ticket,
    String? client,
    String? material,
    double? exitWeight,
    double? approvedWeight,
    double? approvedPrice,
    double? amount,
    String? notes,
    String? bankReference,
    String? sourceReportId,
    DateTime? periodStart,
    DateTime? periodEnd,
    double? periodOpeningBalance,
    double? periodClosingBalance,
    double? periodChecksTotal,
    double? periodAppliedTotal,
    double? periodAdjustmentsTotal,
  }) {
    return _PalomarMovement(
      id: id,
      createdAt: createdAt,
      date: date ?? this.date,
      type: type ?? this.type,
      reference: reference ?? this.reference,
      checkNumber: checkNumber ?? this.checkNumber,
      remision: remision ?? this.remision,
      ticket: ticket ?? this.ticket,
      client: client ?? this.client,
      material: material ?? this.material,
      exitWeight: exitWeight ?? this.exitWeight,
      approvedWeight: approvedWeight ?? this.approvedWeight,
      approvedPrice: approvedPrice ?? this.approvedPrice,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      bankReference: bankReference ?? this.bankReference,
      sourceReportId: sourceReportId ?? this.sourceReportId,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      periodOpeningBalance: periodOpeningBalance ?? this.periodOpeningBalance,
      periodClosingBalance: periodClosingBalance ?? this.periodClosingBalance,
      periodChecksTotal: periodChecksTotal ?? this.periodChecksTotal,
      periodAppliedTotal: periodAppliedTotal ?? this.periodAppliedTotal,
      periodAdjustmentsTotal:
          periodAdjustmentsTotal ?? this.periodAdjustmentsTotal,
    );
  }
}

(Color, Color, Color) _movementTypeScheme(_PalomarMovementType type) {
  switch (type) {
    case _PalomarMovementType.chequeLiberado:
      return (
        const Color(0xFF9A5A00),
        const Color(0xFFFFE7A6),
        const Color(0xFFE0BC55),
      );
    case _PalomarMovementType.remisionAplicada:
      return (
        const Color(0xFF2D7774),
        const Color(0xFFD8F1EF),
        const Color(0xFF8CCFC9),
      );
    case _PalomarMovementType.ajusteCargo:
      return (
        const Color(0xFF7D4A1C),
        const Color(0xFFF6DFC3),
        const Color(0xFFD3A672),
      );
    case _PalomarMovementType.ajusteAbono:
      return (
        const Color(0xFF3E6E4D),
        const Color(0xFFE1F1DF),
        const Color(0xFFA7CC9B),
      );
    case _PalomarMovementType.corteInterno:
      return (
        const Color(0xFF6F674C),
        const Color(0xFFF3EAC6),
        const Color(0xFFD8CA92),
      );
  }
}

class _PalomarSourceRemission {
  final String id;
  final DateTime saleDate;
  final String ticket;
  final String remision;
  final String clientName;
  final String materialName;
  final double exitWeight;
  final double? approvedWeight;
  final double? approvedPrice;
  final double approvedAmount;

  const _PalomarSourceRemission({
    required this.id,
    required this.saleDate,
    required this.ticket,
    required this.remision,
    required this.clientName,
    required this.materialName,
    required this.exitWeight,
    required this.approvedWeight,
    required this.approvedPrice,
    required this.approvedAmount,
  });

  bool get isRelated =>
      approvedWeight != null && approvedPrice != null && approvedWeight! > 0;

  factory _PalomarSourceRemission.fromSupabase(Map<String, dynamic> json) {
    return _PalomarSourceRemission(
      id: (json['id'] as String?) ?? '',
      saleDate:
          DateTime.tryParse((json['sale_date'] as String?) ?? '') ??
          DateTime.now(),
      ticket: (json['ticket'] as String?) ?? '',
      remision: (json['remision'] as String?) ?? '',
      clientName: (json['client_name_snapshot'] as String?) ?? '',
      materialName: (json['material_name_snapshot'] as String?) ?? '',
      exitWeight: ((json['exit_weight'] as num?) ?? 0).toDouble(),
      approvedWeight: (json['approved_weight'] as num?)?.toDouble(),
      approvedPrice: (json['approved_price'] as num?)?.toDouble(),
      approvedAmount: ((json['approved_amount'] as num?) ?? 0).toDouble(),
    );
  }
}

class _PalomarLedgerEntry {
  final _PalomarMovement movement;
  final double balanceAfter;

  const _PalomarLedgerEntry({
    required this.movement,
    required this.balanceAfter,
  });
}

class _PalomarCutSummary {
  final double openingBalance;
  final double checksReleased;
  final double remissionsApplied;
  final double adjustments;
  final double closingBalance;

  const _PalomarCutSummary({
    required this.openingBalance,
    required this.checksReleased,
    required this.remissionsApplied,
    required this.adjustments,
    required this.closingBalance,
  });
}

_PalomarCutSummary _buildCutSummary(
  List<_PalomarLedgerEntry> entries,
  DateTime? from,
  DateTime? to,
) {
  if (from == null || to == null) {
    return const _PalomarCutSummary(
      openingBalance: 0,
      checksReleased: 0,
      remissionsApplied: 0,
      adjustments: 0,
      closingBalance: 0,
    );
  }
  final normalizedFrom = DateUtils.dateOnly(from);
  final normalizedTo = DateUtils.dateOnly(to);
  double opening = 0;
  double checks = 0;
  double remissions = 0;
  double adjustments = 0;
  double closing = 0;
  for (final entry in entries) {
    final date = DateUtils.dateOnly(entry.movement.date);
    if (date.isBefore(normalizedFrom)) {
      opening = entry.balanceAfter;
      continue;
    }
    if (date.isAfter(normalizedTo)) break;
    switch (entry.movement.type) {
      case _PalomarMovementType.chequeLiberado:
        checks += entry.movement.amount;
        break;
      case _PalomarMovementType.remisionAplicada:
        remissions += entry.movement.amount;
        break;
      case _PalomarMovementType.ajusteCargo:
      case _PalomarMovementType.ajusteAbono:
        adjustments += entry.movement.signedAmount;
        break;
      case _PalomarMovementType.corteInterno:
        break;
    }
    closing = entry.balanceAfter;
  }
  if (entries.isEmpty || closing == 0) {
    closing = opening + checks + adjustments - remissions;
  }
  return _PalomarCutSummary(
    openingBalance: opening,
    checksReleased: checks,
    remissionsApplied: remissions,
    adjustments: adjustments,
    closingBalance: closing,
  );
}

ThemeData _palomarMaterialTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    colorScheme: base.colorScheme.copyWith(
      primary: mayoreoAreaTokens.primaryStrong,
      onPrimary: Colors.white,
      secondary: mayoreoAreaTokens.primarySoft,
      surface: mayoreoAreaTokens.surfaceTint,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: mayoreoAreaTokens.primaryStrong,
      selectionColor: mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.18),
      selectionHandleColor: mayoreoAreaTokens.primaryStrong,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return mayoreoAreaTokens.primaryStrong;
        }
        return Colors.white.withValues(alpha: 0.66);
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
    ),
  );
}

Future<bool?> _showPalomarDeleteConfirmDialog(
  BuildContext context, {
  required int count,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: ContractPopupSurface(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _PalomarDialogTitle(
                      icon: Icons.delete_outline_rounded,
                      title: 'Eliminar movimientos',
                      subtitle:
                          'La selección se borrará del estado de cuenta de El Palomar.',
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                count == 1
                    ? 'Se eliminará 1 movimiento del ledger.'
                    : 'Se eliminarán $count movimientos del ledger.',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kMayoreoInk,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: _palomarSecondaryButtonStyle(),
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF9A4300),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    icon: const Icon(Icons.delete_rounded),
                    label: const Text('Eliminar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<Set<String>?> _showPalomarValueFilterDialog(
  BuildContext context, {
  required String title,
  required List<String> options,
  required Set<String> initialValues,
}) {
  final normalizedOptions =
      options
          .map((option) => option.trim())
          .where((option) => option.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return showDialog<Set<String>>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      final searchC = TextEditingController();
      final searchFocus = FocusNode();
      final itemFocusNodes = <FocusNode>[];
      var query = '';
      final selectedValues = <String>{...initialValues};
      int? focusedIndex;

      void syncNodes(int target) {
        while (itemFocusNodes.length < target) {
          itemFocusNodes.add(FocusNode());
        }
        while (itemFocusNodes.length > target) {
          itemFocusNodes.removeLast().dispose();
        }
      }

      return AreaThemeScope(
        tokens: mayoreoAreaTokens,
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            final tokens = AreaThemeScope.of(context);
            final filtered = normalizedOptions
                .where(
                  (option) =>
                      option.toLowerCase().contains(query.trim().toLowerCase()),
                )
                .toList(growable: false);
            syncNodes(filtered.length);
            return Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.of(dialogContext).pop();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                  Navigator.of(dialogContext).pop(<String>{...selectedValues});
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Dialog(
                backgroundColor: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 440,
                    maxHeight: 560,
                  ),
                  child: ContractPopupSurface(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: tokens.primaryStrong,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Focus(
                          onKeyEvent: (_, event) {
                            if (event is! KeyDownEvent) {
                              return KeyEventResult.ignored;
                            }
                            if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowDown &&
                                itemFocusNodes.isNotEmpty) {
                              itemFocusNodes.first.requestFocus();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: searchC,
                            focusNode: searchFocus,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Buscar',
                              prefixIcon: const Icon(Icons.search_rounded),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.82),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: tokens.primarySoft.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: tokens.primaryStrong.withValues(
                                    alpha: 0.42,
                                  ),
                                  width: 1.4,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: tokens.primarySoft.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                            ),
                            onChanged: (value) =>
                                setLocalState(() => query = value),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                setLocalState(selectedValues.clear),
                            child: Text(
                              'Limpiar selección',
                              style: TextStyle(color: tokens.primaryStrong),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(child: Text('Sin resultados'))
                              : ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) {
                                    final option = filtered[i];
                                    final selected = selectedValues.contains(
                                      option,
                                    );
                                    final highlighted = focusedIndex == i;
                                    return Focus(
                                      focusNode: itemFocusNodes[i],
                                      onFocusChange: (hasFocus) {
                                        setLocalState(
                                          () => focusedIndex = hasFocus
                                              ? i
                                              : focusedIndex == i
                                              ? null
                                              : focusedIndex,
                                        );
                                      },
                                      onKeyEvent: (_, event) {
                                        if (event is! KeyDownEvent) {
                                          return KeyEventResult.ignored;
                                        }
                                        if (event.logicalKey ==
                                            LogicalKeyboardKey.arrowUp) {
                                          if (i == 0) {
                                            searchFocus.requestFocus();
                                          } else {
                                            itemFocusNodes[i - 1]
                                                .requestFocus();
                                          }
                                          return KeyEventResult.handled;
                                        }
                                        if (event.logicalKey ==
                                                LogicalKeyboardKey.arrowDown &&
                                            i < itemFocusNodes.length - 1) {
                                          itemFocusNodes[i + 1].requestFocus();
                                          return KeyEventResult.handled;
                                        }
                                        if (event.logicalKey ==
                                                LogicalKeyboardKey.enter ||
                                            event.logicalKey ==
                                                LogicalKeyboardKey
                                                    .numpadEnter ||
                                            event.logicalKey ==
                                                LogicalKeyboardKey.space) {
                                          setLocalState(() {
                                            if (!selectedValues.add(option)) {
                                              selectedValues.remove(option);
                                            }
                                          });
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.ignored;
                                      },
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () => setLocalState(() {
                                          if (!selectedValues.add(option)) {
                                            selectedValues.remove(option);
                                          }
                                        }),
                                        onHover: (value) {
                                          if (value) {
                                            setLocalState(
                                              () => focusedIndex = i,
                                            );
                                          }
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 140,
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? tokens.badgeBackground
                                                      .withValues(alpha: 0.76)
                                                : highlighted
                                                ? Colors.white.withValues(
                                                    alpha: 0.72,
                                                  )
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: selected
                                                  ? tokens.primaryStrong
                                                        .withValues(alpha: 0.26)
                                                  : Colors.transparent,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  option,
                                                  style: TextStyle(
                                                    fontWeight: selected
                                                        ? FontWeight.w900
                                                        : FontWeight.w700,
                                                    color: tokens.primaryStrong,
                                                  ),
                                                ),
                                              ),
                                              if (selected)
                                                Icon(
                                                  Icons.check_rounded,
                                                  size: 18,
                                                  color: tokens.primaryStrong,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              style: _palomarSecondaryButtonStyle(),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: _palomarSecondaryButtonStyle(),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(<String>{}),
                              child: const Text('Limpiar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: _palomarPrimaryButtonStyle(),
                              onPressed: () => Navigator.of(
                                dialogContext,
                              ).pop(<String>{...selectedValues}),
                              child: const Text('Aplicar'),
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
        ),
      );
    },
  );
}

Future<_PalomarDateFilterResult?> _showPalomarDateRangeFilterDialog(
  BuildContext context, {
  required String label,
  required DateTimeRange bounds,
  DateTimeRange? initialRange,
}) {
  return showDialog<_PalomarDateFilterResult>(
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

      return AreaThemeScope(
        tokens: mayoreoAreaTokens,
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            final tokens = AreaThemeScope.of(context);
            final monthFirst = DateTime(
              displayMonth.year,
              displayMonth.month,
              1,
            );
            final leading = (monthFirst.weekday + 6) % 7;
            final gridStart = monthFirst.subtract(Duration(days: leading));
            final previewEnd = end ?? hover;

            bool withinBounds(DateTime day) {
              final d = dateOnly(day);
              return !d.isBefore(dateOnly(bounds.start)) &&
                  !d.isAfter(dateOnly(bounds.end));
            }

            bool inPreviewRange(DateTime day) {
              if (start == null || previewEnd == null) return false;
              final a = dateOnly(start!);
              final b = dateOnly(previewEnd);
              final from = a.isBefore(b) ? a : b;
              final to = a.isBefore(b) ? b : a;
              final d = dateOnly(day);
              return !d.isBefore(from) && !d.isAfter(to);
            }

            _PalomarDateFilterResult? buildResult() {
              if (start == null) return null;
              final s = dateOnly(start!);
              final e = dateOnly(end ?? start!);
              final from = s.isBefore(e) ? s : e;
              final to = s.isBefore(e) ? e : s;
              return _PalomarDateFilterResult(from: from, to: to);
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              child: ContractPopupSurface(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                  maxHeight: 516,
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtro: $label',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: tokens.primaryStrong,
                      ),
                    ),
                    const SizedBox(height: 10),
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
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${_palomarMonthNameEs(monthFirst.month)} ${monthFirst.year}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
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
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (final dayLabel in const [
                          'L',
                          'M',
                          'M',
                          'J',
                          'V',
                          'S',
                          'D',
                        ])
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  dayLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 42,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                            childAspectRatio: 1.08,
                          ),
                      itemBuilder: (_, index) {
                        final day = gridStart.add(Duration(days: index));
                        final inMonth = day.month == monthFirst.month;
                        final allowed = withinBounds(day);
                        final active =
                            (start != null && isSameDay(day, start!)) ||
                            (end != null && isSameDay(day, end!));
                        final inRange = inPreviewRange(day) && allowed;
                        return MouseRegion(
                          onEnter: (_) {
                            if (start != null && end == null && allowed) {
                              setLocalState(() => hover = dateOnly(day));
                            }
                          },
                          child: GestureDetector(
                            onTap: !allowed
                                ? null
                                : () {
                                    final picked = dateOnly(day);
                                    setLocalState(() {
                                      if (start == null || end != null) {
                                        start = picked;
                                        end = null;
                                        hover = null;
                                      } else {
                                        end = picked;
                                        hover = null;
                                      }
                                    });
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              decoration: BoxDecoration(
                                color: active
                                    ? tokens.primaryStrong.withValues(
                                        alpha: 0.18,
                                      )
                                    : inRange
                                    ? tokens.primarySoft.withValues(alpha: 0.24)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: active
                                      ? tokens.primaryStrong.withValues(
                                          alpha: 0.46,
                                        )
                                      : Colors.transparent,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: active
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                    color: !allowed
                                        ? tokens.badgeText.withValues(
                                            alpha: 0.28,
                                          )
                                        : inMonth
                                        ? tokens.primaryStrong
                                        : tokens.badgeText.withValues(
                                            alpha: 0.55,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      start == null
                          ? 'Selecciona fecha inicial'
                          : end == null
                          ? 'Selecciona fecha final'
                          : '${_palomarFmtDate(start!)} - ${_palomarFmtDate(end!)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: tokens.badgeText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: _palomarSecondaryButtonStyle(),
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: _palomarSecondaryButtonStyle(),
                          onPressed: () => Navigator.pop(
                            dialogContext,
                            const _PalomarDateFilterResult(clear: true),
                          ),
                          child: const Text('Limpiar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: _palomarPrimaryButtonStyle(),
                          onPressed: start == null
                              ? null
                              : () =>
                                    Navigator.pop(dialogContext, buildResult()),
                          child: const Text('Aplicar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

String _palomarFmtDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}

String _palomarMonthNameEs(int month) {
  const names = <String>[
    '',
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
  return names[month];
}

ButtonStyle _palomarPrimaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: mayoreoAreaTokens.primaryStrong,
    foregroundColor: Colors.white,
    minimumSize: const Size(0, 46),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

ButtonStyle _palomarSecondaryButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: mayoreoAreaTokens.primaryStrong,
    side: BorderSide(
      color: mayoreoAreaTokens.primarySoft.withValues(alpha: 0.84),
    ),
    minimumSize: const Size(0, 46),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

String _movementTypeLabel(_PalomarMovementType type) {
  switch (type) {
    case _PalomarMovementType.chequeLiberado:
      return 'CHEQUE LIBERADO';
    case _PalomarMovementType.remisionAplicada:
      return 'REMISIÓN APLICADA';
    case _PalomarMovementType.ajusteCargo:
      return 'AJUSTE CARGO';
    case _PalomarMovementType.ajusteAbono:
      return 'AJUSTE ABONO';
    case _PalomarMovementType.corteInterno:
      return 'CORTE INTERNO';
  }
}

String _movementTypeShortLabel(_PalomarMovementType type) {
  switch (type) {
    case _PalomarMovementType.chequeLiberado:
      return 'CHEQUE';
    case _PalomarMovementType.remisionAplicada:
      return 'REMISIÓN';
    case _PalomarMovementType.ajusteCargo:
    case _PalomarMovementType.ajusteAbono:
      return 'AJUSTE';
    case _PalomarMovementType.corteInterno:
      return 'CORTE';
  }
}

String _ledgerPrimaryReference(_PalomarMovement movement) {
  switch (movement.type) {
    case _PalomarMovementType.chequeLiberado:
      if (movement.checkNumber.isNotEmpty) return movement.checkNumber;
      return movement.reference;
    case _PalomarMovementType.remisionAplicada:
      if (movement.remision.isNotEmpty) return 'Remisión ${movement.remision}';
      if (movement.ticket.isNotEmpty) return 'Ticket ${movement.ticket}';
      return movement.reference;
    case _PalomarMovementType.ajusteCargo:
    case _PalomarMovementType.ajusteAbono:
      return movement.reference;
    case _PalomarMovementType.corteInterno:
      return 'Corte interno';
  }
}

String? _buildLedgerDetail(_PalomarMovement movement) {
  final parts = <String>[];
  if (movement.type == _PalomarMovementType.remisionAplicada) {
    if (movement.ticket.isNotEmpty && movement.remision.isNotEmpty) {
      parts.add('Ticket ${movement.ticket}');
    }
    if (movement.notes.isNotEmpty) {
      parts.add(movement.notes);
    }
  } else if (movement.type == _PalomarMovementType.chequeLiberado) {
    if (movement.bankReference.isNotEmpty) {
      parts.add(movement.bankReference);
    }
    if (movement.notes.isNotEmpty) {
      parts.add(movement.notes);
    }
  } else {
    if (movement.notes.isNotEmpty) {
      parts.add(movement.notes);
    }
  }
  if (parts.isEmpty) return null;
  return parts.join('  ·  ');
}

String _palomarWeightCell(double? value) {
  if (value == null || value <= 0) return '—';
  return formatDecimal(value);
}

String _palomarPriceCell(double? value) {
  if (value == null || value <= 0) return '—';
  return formatMoney(value, decimals: 2);
}

String _palomarSignedMoney(double amount) {
  if (amount > 0) return '+${formatMoney(amount, decimals: 0)}';
  if (amount < 0) return '-${formatMoney(amount.abs(), decimals: 0)}';
  return formatMoney(0, decimals: 0);
}

Color _palomarSignedAmountColor(_PalomarMovementType type) {
  switch (type) {
    case _PalomarMovementType.chequeLiberado:
    case _PalomarMovementType.ajusteCargo:
      return const Color(0xFFB97700);
    case _PalomarMovementType.remisionAplicada:
    case _PalomarMovementType.ajusteAbono:
      return const Color(0xFF2D7774);
    case _PalomarMovementType.corteInterno:
      return const Color(0xFF6F674C);
  }
}

String _remissionStateLabel(_PalomarRemissionState state) {
  switch (state) {
    case _PalomarRemissionState.disponible:
      return 'DISPONIBLE';
    case _PalomarRemissionState.aplicada:
      return 'APLICADA';
    case _PalomarRemissionState.revision:
      return 'EN REVISIÓN';
  }
}

(Color, Color, Color) _remissionStateScheme(_PalomarRemissionState state) {
  switch (state) {
    case _PalomarRemissionState.disponible:
      return (
        const Color(0xFF2D7774),
        const Color(0xFFD8F1EF),
        const Color(0xFF8CCFC9),
      );
    case _PalomarRemissionState.aplicada:
      return (
        const Color(0xFF6F674C),
        const Color(0xFFF3EAC6),
        const Color(0xFFD8CA92),
      );
    case _PalomarRemissionState.revision:
      return (
        const Color(0xFF9A4300),
        const Color(0xFFFFE1C1),
        const Color(0xFFE3B07D),
      );
  }
}

String _formatPalomarDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}

double _parseAmount(String value) {
  final normalized = value.replaceAll(',', '').trim();
  return double.tryParse(normalized) ?? 0;
}

double? _parseOptionalAmount(String value) {
  final normalized = value.replaceAll(',', '').trim();
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

bool _containsAny(List<String> values, String query) {
  return values.any((value) => value.toUpperCase().contains(query));
}

bool _matchesAnyValue(Iterable<String> values, String candidate) {
  final normalized = candidate.trim().toUpperCase();
  if (normalized.isEmpty) return false;
  return values.any((value) => value.trim().toUpperCase() == normalized);
}
