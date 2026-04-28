import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../auth/auth_access.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/dialogs/contract_popup_surface.dart';
import '../shared/ui_contract_core/keyboard/grid_keyboard_contract.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import '../shared/utils/number_formatters.dart';
import 'mayoreo_catalog_page.dart';
import 'mayoreo_dashboard_preview_page.dart';
import 'mayoreo_el_palomar_page.dart';
import 'mayoreo_price_adjustments_page.dart';
import 'mayoreo_sales_report_page.dart';
import 'mayoreo_theme.dart';

const String _kMayoreoSalesReportsTable = 'mayoreo_sales_reports';
const String _kMayoreoAccountsTable = 'mayoreo_accounts';

const double _kAccountsDateW = 112;
const double _kAccountsTicketW = 108;
const double _kAccountsClientW = 210;
const double _kAccountsRemisionW = 114;
const double _kAccountsMaterialW = 178;
const double _kAccountsApprovedWeightW = 110;
const double _kAccountsApprovedPriceW = 114;
const double _kAccountsAmountW = 124;
const double _kAccountsOperationW = 100;
const double _kAccountsDocumentW = 128;
const double _kAccountsInvoiceDateW = 120;
const double _kAccountsPaymentDateW = 120;
const double _kAccountsStatusW = 162;
const double _kAccountsActionsW = 102;
const double _kAccountsGridMinHeight = 430;

enum _MayoreoAccountsOperationType { factura, cheque }

enum _MayoreoAccountsStatus {
  pendienteFactura,
  facturadaPendientePago,
  pagada,
  pagoParcial,
  cancelada,
  porRevisar,
  pendienteCheque,
  chequeRecibido,
  chequePendienteCanje,
  chequeCanjeado,
}

enum _AccountsMenuAction { detail, markReview }

class MayoreoAccountsPage extends StatefulWidget {
  final bool instantOpen;

  const MayoreoAccountsPage({super.key, this.instantOpen = false});

  @override
  State<MayoreoAccountsPage> createState() => _MayoreoAccountsPageState();
}

class _MayoreoAccountsPageState extends State<MayoreoAccountsPage> {
  final SupabaseClient _supa = Supabase.instance.client;
  Future<void> _persistRowsQueue = Future<void>.value();
  bool _menuOpen = false;
  bool _canReturnToDirection = false;
  bool _exportingCsv = false;
  String? _selectedRowId;
  final Set<String> _selectedRowIds = <String>{};
  String? _selectionAnchorId;
  int _currentPage = 0;
  int _pageSize = 40;
  DateTime? _dateFilterFrom;
  DateTime? _dateFilterTo;
  DateTime? _invoiceDateFilterFrom;
  DateTime? _invoiceDateFilterTo;
  DateTime? _paymentDateFilterFrom;
  DateTime? _paymentDateFilterTo;
  final Set<String> _ticketFilters = <String>{};
  final Set<String> _clientFilters = <String>{};
  final Set<String> _remisionFilters = <String>{};
  final Set<String> _materialFilters = <String>{};
  final Set<String> _operationFilters = <String>{};
  final Set<String> _documentFilters = <String>{};
  final Set<String> _statusFilters = <String>{};
  bool _overdueEstimatedPaymentOnly = false;
  final ScrollController _rowsScrollController = ScrollController();
  final GlobalKey _rowsViewportKey = GlobalKey();
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  bool _dragSelectingRows = false;
  bool _pointerDownAdditiveSelection = false;
  bool _suppressNextRowTap = false;
  Offset? _dragPointerLocal;
  Offset? _dragPointerGlobal;
  double _dragAutoScrollVelocity = 0;
  Timer? _dragAutoScrollTimer;

  late List<_MayoreoAccountRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = const <_MayoreoAccountRow>[];
    unawaited(_resolveNavigationAccess());
    unawaited(_loadAccounts());
  }

  @override
  void dispose() {
    _dragAutoScrollTimer?.cancel();
    _rowsScrollController.dispose();
    super.dispose();
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
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

  Future<void> _openElPalomar() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const MayoreoElPalomarPage(instantOpen: true)));
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
        return;
      case 'Cuenta El Palomar':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openElPalomar());
        return;
      case 'Catálogo':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openCatalog());
        return;
      case 'Ajuste de precios':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openPriceAdjustments());
        return;
      default:
        if (_menuOpen) setState(() => _menuOpen = false);
        _toast('$label quedará conectado en la siguiente fase de Mayoreo.');
    }
  }

  Future<void> _loadAccounts() async {
    final sourceRows = await _loadSourceReports();
    final persistedRows = <String, _MayoreoAccountRow>{};

    try {
      persistedRows.addAll(await _loadRemotePersistedAccounts());
    } catch (_) {}

    final rows = sourceRows
        .map((source) {
          final saved = persistedRows[source.id];
          return saved == null
              ? _MayoreoAccountRow.fromSource(source)
              : saved.syncOperational(source);
        })
        .toList(growable: false);

    if (!mounted) return;
    setState(() {
      _rows = rows;
      if (_selectedRowId == null && rows.isNotEmpty) {
        _selectedRowId = rows.first.id;
      }
      if (_selectedRowId != null &&
          rows.every((row) => row.id != _selectedRowId)) {
        _selectedRowId = rows.isEmpty ? null : rows.first.id;
      }
      _selectedRowIds.removeWhere((id) => rows.every((row) => row.id != id));
      if (_selectedRowId != null) {
        _selectedRowIds.add(_selectedRowId!);
      } else if (rows.isNotEmpty) {
        _selectedRowIds
          ..clear()
          ..add(rows.first.id);
        _selectedRowId = rows.first.id;
      }
      if (_selectionAnchorId != null &&
          rows.every((row) => row.id != _selectionAnchorId)) {
        _selectionAnchorId = _selectedRowId;
      }
      _currentPage = _effectiveCurrentPageFor(rows.length);
    });
    _persistState();
  }

  Future<List<_MayoreoSourceReportRow>> _loadSourceReports() async {
    try {
      final response = await _supa
          .from(_kMayoreoSalesReportsTable)
          .select()
          .order('sale_date', ascending: false)
          .order('created_at', ascending: false);
      final rows = (response as List)
          .map(
            (item) => _MayoreoSourceReportRow.fromSupabase(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where((row) => row.isRelated)
          .where((row) => !_isSeedAccountSourceId(row.id))
          .toList(growable: false);
      return rows;
    } catch (_) {
      return const <_MayoreoSourceReportRow>[];
    }
  }

  Future<Map<String, _MayoreoAccountRow>> _loadRemotePersistedAccounts() async {
    final response = await _supa
        .from(_kMayoreoAccountsTable)
        .select()
        .order('sale_date', ascending: false)
        .order('updated_at', ascending: false);
    final rows = (response as List)
        .map(
          (item) => _MayoreoAccountRow.fromSupabase(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .where((row) => !_isSeedAccountSourceId(row.id))
        .toList(growable: false);
    return <String, _MayoreoAccountRow>{for (final row in rows) row.id: row};
  }

  Future<void> _persistRowsToSupabase() async {
    try {
      if (_rows.isNotEmpty) {
        await _supa
            .from(_kMayoreoAccountsTable)
            .upsert(
              _rows.map((row) => row.toSupabase()).toList(growable: false),
              onConflict: 'id',
            );
      }
      final existing = await _supa.from(_kMayoreoAccountsTable).select('id');
      final existingIds = (existing as List)
          .map((row) => (row as Map)['id'].toString())
          .toSet();
      final nextIds = _rows.map((row) => row.id).toSet();
      final deletedIds = existingIds
          .difference(nextIds)
          .toList(growable: false);
      if (deletedIds.isNotEmpty) {
        await _supa
            .from(_kMayoreoAccountsTable)
            .delete()
            .inFilter('id', deletedIds);
      }
    } on PostgrestException catch (e) {
      _toast('No se pudo guardar Cuentas Mayoreo: ${e.message}');
      await _loadAccounts();
    } catch (_) {
      _toast(
        'No se pudo guardar Cuentas Mayoreo. Se restauró el estado remoto.',
      );
      await _loadAccounts();
    }
  }

  void _persistState() {
    _persistRowsQueue = _persistRowsQueue
        .catchError((_) {})
        .then((_) => _persistRowsToSupabase());
    unawaited(_persistRowsQueue);
  }

  List<_MayoreoAccountRow> get _filteredRows {
    return _rows
        .where((row) {
          final rowDate = DateUtils.dateOnly(row.saleDate);
          if (_dateFilterFrom != null &&
              rowDate.isBefore(DateUtils.dateOnly(_dateFilterFrom!))) {
            return false;
          }
          if (_dateFilterTo != null &&
              rowDate.isAfter(DateUtils.dateOnly(_dateFilterTo!))) {
            return false;
          }
          if (_invoiceDateFilterFrom != null) {
            final documentDate = row.documentDate == null
                ? null
                : DateUtils.dateOnly(row.documentDate!);
            if (documentDate == null ||
                documentDate.isBefore(
                  DateUtils.dateOnly(_invoiceDateFilterFrom!),
                )) {
              return false;
            }
          }
          if (_invoiceDateFilterTo != null) {
            final documentDate = row.documentDate == null
                ? null
                : DateUtils.dateOnly(row.documentDate!);
            if (documentDate == null ||
                documentDate.isAfter(
                  DateUtils.dateOnly(_invoiceDateFilterTo!),
                )) {
              return false;
            }
          }
          if (_paymentDateFilterFrom != null) {
            final paymentDate = row.settlementDate == null
                ? null
                : DateUtils.dateOnly(row.settlementDate!);
            if (paymentDate == null ||
                paymentDate.isBefore(
                  DateUtils.dateOnly(_paymentDateFilterFrom!),
                )) {
              return false;
            }
          }
          if (_paymentDateFilterTo != null) {
            final paymentDate = row.settlementDate == null
                ? null
                : DateUtils.dateOnly(row.settlementDate!);
            if (paymentDate == null ||
                paymentDate.isAfter(
                  DateUtils.dateOnly(_paymentDateFilterTo!),
                )) {
              return false;
            }
          }
          if (_ticketFilters.isNotEmpty &&
              !_ticketFilters.contains(row.ticket)) {
            return false;
          }
          if (_clientFilters.isNotEmpty &&
              !_clientFilters.contains(row.clientId)) {
            return false;
          }
          if (_remisionFilters.isNotEmpty &&
              !_remisionFilters.contains(row.remision)) {
            return false;
          }
          if (_materialFilters.isNotEmpty &&
              !_materialFilters.contains(row.materialName)) {
            return false;
          }
          if (_operationFilters.isNotEmpty &&
              !_operationFilters.contains(row.operationType.name)) {
            return false;
          }
          if (_documentFilters.isNotEmpty &&
              !_documentFilters.contains(row.documentNumber.trim())) {
            return false;
          }
          if (_statusFilters.isNotEmpty &&
              !_statusFilters.contains(row.status.name)) {
            return false;
          }
          if (_overdueEstimatedPaymentOnly &&
              !row.hasEstimatedPaymentReminder) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  int _effectiveCurrentPageFor(int totalRows) =>
      _effectiveCurrentPageForCount(_currentPage, _pageSize, totalRows);

  List<_MayoreoAccountRow> _pageRows(List<_MayoreoAccountRow> rows) {
    if (rows.isEmpty) return const <_MayoreoAccountRow>[];
    final currentPage = _effectiveCurrentPageFor(rows.length);
    final start = currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  int _selectedFilteredIndex(List<_MayoreoAccountRow> rows) {
    if (_selectedRowId == null) return rows.isEmpty ? -1 : 0;
    return rows.indexWhere((row) => row.id == _selectedRowId);
  }

  void _selectFilteredIndex(List<_MayoreoAccountRow> rows, int nextIndex) {
    if (rows.isEmpty) return;
    final safeIndex = nextIndex.clamp(0, rows.length - 1);
    setState(() => _selectSingleRow(rows[safeIndex].id));
    final key = _rowKeys[rows[safeIndex].id];
    final rowContext = key?.currentContext;
    if (rowContext != null) {
      Scrollable.ensureVisible(
        rowContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    }
    _persistState();
  }

  bool _isShortcutModifierPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  bool _isShiftPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
  }

  int _visiblePositionForId(String? rowId, List<_MayoreoAccountRow> rows) {
    if (rowId == null) return -1;
    return rows.indexWhere((row) => row.id == rowId);
  }

  void _selectVisibleRange(
    List<_MayoreoAccountRow> rows,
    int startVisible,
    int endVisible,
  ) {
    final from = startVisible < endVisible ? startVisible : endVisible;
    final to = startVisible < endVisible ? endVisible : startVisible;
    _selectedRowIds
      ..clear()
      ..addAll(rows.sublist(from, to + 1).map((row) => row.id));
  }

  void _selectSingleRow(String rowId) {
    _selectedRowId = rowId;
    _selectionAnchorId = rowId;
    _selectedRowIds
      ..clear()
      ..add(rowId);
    _dragSelectingRows = false;
    _dragPointerLocal = null;
    _dragPointerGlobal = null;
    _dragAutoScrollVelocity = 0;
    _dragAutoScrollTimer?.cancel();
    _dragAutoScrollTimer = null;
  }

  void _toggleRowSelection(String rowId) {
    _selectedRowId = rowId;
    _selectionAnchorId = rowId;
    if (_selectedRowIds.contains(rowId)) {
      _selectedRowIds.remove(rowId);
      if (_selectedRowIds.isEmpty) {
        _selectedRowIds.add(rowId);
      }
    } else {
      _selectedRowIds.add(rowId);
    }
    _dragSelectingRows = false;
  }

  void _extendSelectionTo(String rowId, List<_MayoreoAccountRow> rows) {
    final anchor = _selectionAnchorId ?? _selectedRowId;
    final anchorVisible = _visiblePositionForId(anchor, rows);
    final targetVisible = _visiblePositionForId(rowId, rows);
    if (anchorVisible < 0 || targetVisible < 0) {
      _selectSingleRow(rowId);
      return;
    }
    _selectedRowId = rowId;
    _selectVisibleRange(rows, anchorVisible, targetVisible);
    _dragSelectingRows = true;
  }

  void _clearSelection() {
    _selectedRowIds.clear();
    _selectedRowId = null;
    _selectionAnchorId = null;
    _dragSelectingRows = false;
    _dragPointerLocal = null;
    _dragPointerGlobal = null;
    _dragAutoScrollVelocity = 0;
    _dragAutoScrollTimer?.cancel();
    _dragAutoScrollTimer = null;
    _pointerDownAdditiveSelection = false;
    _suppressNextRowTap = false;
  }

  void _selectAllVisibleRows(List<_MayoreoAccountRow> rows) {
    if (rows.isEmpty) return;
    _selectedRowIds
      ..clear()
      ..addAll(rows.map((row) => row.id));
    _selectedRowId = rows.first.id;
    _selectionAnchorId = rows.first.id;
  }

  int? _visibleRowPositionAtGlobalPosition(
    Offset globalPosition,
    List<_MayoreoAccountRow> rows,
  ) {
    for (var index = 0; index < rows.length; index++) {
      final box =
          _rowKeys[rows[index].id]?.currentContext?.findRenderObject()
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

  Offset? _globalToRowsLocal(Offset globalPosition) {
    final box =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.globalToLocal(globalPosition);
  }

  void _handleRowPrimaryPointerDown(
    String rowId,
    List<_MayoreoAccountRow> rows,
  ) {
    setState(() {
      _pointerDownAdditiveSelection =
          _isShortcutModifierPressed() || _isShiftPressed();
      if (_isShiftPressed()) {
        _extendSelectionTo(rowId, rows);
        _suppressNextRowTap = true;
      } else if (_isShortcutModifierPressed()) {
        _toggleRowSelection(rowId);
        _suppressNextRowTap = true;
      } else {
        _selectSingleRow(rowId);
        _dragSelectingRows = true;
        _suppressNextRowTap = false;
      }
    });
  }

  void _handleRowsPointerDown(
    PointerDownEvent event,
    List<_MayoreoAccountRow> rows,
  ) {
    _pointerDownAdditiveSelection =
        _isShortcutModifierPressed() || _isShiftPressed();
    if (event.kind != PointerDeviceKind.mouse ||
        (event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }
    final visibleIndex = _visibleRowPositionAtGlobalPosition(
      event.position,
      rows,
    );
    if (visibleIndex == null) return;
    _dragPointerLocal = _globalToRowsLocal(event.position);
    _dragPointerGlobal = event.position;
    _handleRowPrimaryPointerDown(rows[visibleIndex].id, rows);
    _updateRowsDragAutoScroll(rows);
  }

  void _handleRowTap(String rowId) {
    if (_suppressNextRowTap || _pointerDownAdditiveSelection) {
      setState(() {
        _suppressNextRowTap = false;
        _pointerDownAdditiveSelection = false;
      });
      return;
    }
    setState(() => _selectSingleRow(rowId));
    _persistState();
  }

  void _handleRowDragEnter(String rowId, List<_MayoreoAccountRow> rows) {
    if (!_dragSelectingRows) return;
    setState(() => _extendSelectionTo(rowId, rows));
  }

  void _handleRowsPointerMove(
    PointerMoveEvent event,
    List<_MayoreoAccountRow> rows,
  ) {
    if (!_dragSelectingRows) return;
    _dragPointerLocal = _globalToRowsLocal(event.position);
    _dragPointerGlobal = event.position;
    _updateRowsDragAutoScroll(rows);
    final visibleIndex = _visibleRowPositionAtGlobalPosition(
      event.position,
      rows,
    );
    if (visibleIndex == null) return;
    setState(() => _extendSelectionTo(rows[visibleIndex].id, rows));
  }

  void _handleRowsPointerEnd() {
    if (!_dragSelectingRows &&
        !_pointerDownAdditiveSelection &&
        !_suppressNextRowTap) {
      _dragPointerLocal = null;
      _dragPointerGlobal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    setState(() {
      _dragSelectingRows = false;
      _dragPointerLocal = null;
      _dragPointerGlobal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      _pointerDownAdditiveSelection = false;
      _suppressNextRowTap = false;
    });
    _persistState();
  }

  void _updateRowsDragAutoScroll(List<_MayoreoAccountRow> rows) {
    if (!_dragSelectingRows || _dragPointerLocal == null) {
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final box =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _dragAutoScrollVelocity = 0;
      return;
    }
    const edge = 36.0;
    const maxStep = 18.0;
    final y = _dragPointerLocal!.dy;
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
      (_) => _performRowsDragAutoScroll(rows),
    );
  }

  void _performRowsDragAutoScroll(List<_MayoreoAccountRow> rows) {
    if (!_dragSelectingRows ||
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
    final pointerGlobal = _dragPointerGlobal;
    if (pointerGlobal == null || rows.isEmpty) return;
    final visibleIndex = _visibleRowPositionAtGlobalPosition(
      pointerGlobal,
      rows,
    );
    int? targetIndex = visibleIndex;
    if (targetIndex == null) {
      final box =
          _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final topLeft = box.localToGlobal(Offset.zero);
        final bottom = topLeft.dy + box.size.height;
        targetIndex = pointerGlobal.dy >= bottom ? rows.length - 1 : 0;
      }
    }
    if (targetIndex == null || !mounted) return;
    setState(() => _extendSelectionTo(rows[targetIndex!].id, rows));
  }

  void _markRowIdsForReview(
    Set<String> rowIds,
    List<_MayoreoAccountRow> visibleRows,
  ) {
    if (rowIds.isEmpty) return;
    setState(() {
      _rows = _rows
          .map(
            (row) => rowIds.contains(row.id)
                ? row.copyWith(status: _MayoreoAccountsStatus.porRevisar)
                : row,
          )
          .toList(growable: false);
      if (_selectedRowId == null && visibleRows.isNotEmpty) {
        _selectedRowId = visibleRows.first.id;
      }
    });
    _persistState();
  }

  Future<void> _openDetailDialog(_MayoreoAccountRow row) async {
    final result = await showDialog<_MayoreoAccountRow>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Theme(
        data: _mayoreoMaterialTheme(dialogContext),
        child: _AccountDetailDialog(row: row),
      ),
    );
    if (result == null) return;
    setState(() {
      _rows = _rows
          .map((item) => item.id == result.id ? result : item)
          .toList(growable: false);
      _selectedRowId = result.id;
    });
    _persistState();
  }

  Future<void> _handleMenuAction(
    _MayoreoAccountRow row,
    _AccountsMenuAction action,
  ) async {
    switch (action) {
      case _AccountsMenuAction.detail:
        await _openDetailDialog(row);
        return;
      case _AccountsMenuAction.markReview:
        setState(() {
          _rows = _rows
              .map(
                (item) => item.id == row.id
                    ? item.copyWith(status: _MayoreoAccountsStatus.porRevisar)
                    : item,
              )
              .toList(growable: false);
        });
        _persistState();
        return;
    }
  }

  Future<void> _showContextMenuForRow(
    _MayoreoAccountRow row,
    List<_MayoreoAccountRow> visibleRows,
    Offset globalPosition,
  ) async {
    setState(() {
      if (!_selectedRowIds.contains(row.id)) {
        _selectSingleRow(row.id);
      } else {
        _selectedRowId = row.id;
        _selectionAnchorId ??= row.id;
      }
      if (_selectedRowIds.isEmpty && visibleRows.isNotEmpty) {
        _selectSingleRow(visibleRows.first.id);
      }
    });
    _persistState();
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final appliesToSelection =
        _selectedRowIds.length > 1 && _selectedRowIds.contains(row.id);
    final action = await showMenu<_AccountsMenuAction>(
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
        if (!appliesToSelection)
          const PopupMenuItem(
            value: _AccountsMenuAction.detail,
            child: Text(
              'Abrir detalle',
              style: TextStyle(fontWeight: FontWeight.w800, color: kMayoreoInk),
            ),
          ),
        PopupMenuItem(
          value: _AccountsMenuAction.markReview,
          child: Text(
            appliesToSelection
                ? 'Marcar selección por revisar'
                : 'Marcar por revisar',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: kMayoreoInk,
            ),
          ),
        ),
      ],
    );
    if (action != null) {
      if (action == _AccountsMenuAction.markReview && appliesToSelection) {
        _markRowIdsForReview(_selectedRowIds, visibleRows);
      } else {
        await _handleMenuAction(row, action);
      }
    }
  }

  Future<void> _exportCsv() async {
    if (_exportingCsv) return;
    setState(() => _exportingCsv = true);
    try {
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final rows = _filteredRows;
      final csv = StringBuffer()
        ..writeln(
          [
            'FECHA_VENTA',
            'TICKET',
            'CLIENTE',
            'REMISION',
            'MATERIAL',
            'PESO_APROBADO',
            'PRECIO_APROBADO',
            'IMPORTE_APROBADO',
            'TIPO_OPERACION',
            'DOCUMENTO',
            'FECHA_DOCUMENTO',
            'FECHA_PAGO_CANJE',
            'ESTATUS',
            'MONTO_PAGADO',
            'SALDO',
            'OBSERVACIONES',
          ].join(','),
        );
      for (final row in rows) {
        csv.writeln(
          [
            _formatDate(row.saleDate),
            row.ticket,
            row.clientName,
            row.remision,
            row.materialName,
            formatDecimal(row.approvedWeight),
            row.approvedPrice.toStringAsFixed(2),
            row.approvedAmount.toStringAsFixed(2),
            _operationTypeLabel(row.operationType),
            row.documentNumber,
            row.documentDate == null ? '' : _formatDate(row.documentDate!),
            row.settlementDate == null ? '' : _formatDate(row.settlementDate!),
            _financialStatusLabel(row.status),
            row.paidAmount.toStringAsFixed(2),
            row.pendingBalance.toStringAsFixed(2),
            row.financialNotes,
          ].map(_csvCell).join(','),
        );
      }
      final path = await saveCsvFile(
        fileName: 'mayoreo_cuentas_$stamp.csv',
        content: csv.toString(),
        dialogTitle: 'Guardar CSV de cuentas de mayoreo',
      );
      _toast(
        path == null ? 'Exportación cancelada' : 'CSV exportado en: $path',
      );
    } catch (e) {
      _toast('No se pudo exportar CSV: $e');
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Future<void> _openClientFilterDialog() async {
    final options =
        _rows
            .map(
              (row) => _FilterOption(id: row.clientId, label: row.clientName),
            )
            .toSet()
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));
    final selected = await _showMayoreoValueFilterDialog(
      context,
      title: 'Filtrar cliente',
      options: options.map((item) => item.label).toList(growable: false),
      initialValues: options
          .where((item) => _clientFilters.contains(item.id))
          .map((item) => item.label)
          .toSet(),
    );
    if (selected == null) return;
    setState(() {
      _clientFilters
        ..clear()
        ..addAll(
          options
              .where((item) => selected.contains(item.label))
              .map((item) => item.id),
        );
      _currentPage = 0;
    });
    _persistState();
  }

  Future<void> _openTicketFilterDialog() async {
    final options =
        _rows
            .map((row) => row.ticket.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final selected = await _showMayoreoValueFilterDialog(
      context,
      title: 'Filtrar ticket',
      options: options,
      initialValues: _ticketFilters,
    );
    if (selected == null) return;
    setState(() {
      _ticketFilters
        ..clear()
        ..addAll(selected);
      _currentPage = 0;
    });
    _persistState();
  }

  Future<void> _openRemisionFilterDialog() async {
    final options =
        _rows
            .map((row) => row.remision.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final selected = await _showMayoreoValueFilterDialog(
      context,
      title: 'Filtrar remisión',
      options: options,
      initialValues: _remisionFilters,
    );
    if (selected == null) return;
    setState(() {
      _remisionFilters
        ..clear()
        ..addAll(selected);
      _currentPage = 0;
    });
    _persistState();
  }

  Future<void> _openMaterialFilterDialog() async {
    final options =
        _rows
            .map((row) => row.materialName.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final selected = await _showMayoreoValueFilterDialog(
      context,
      title: 'Filtrar material',
      options: options,
      initialValues: _materialFilters,
    );
    if (selected == null) return;
    setState(() {
      _materialFilters
        ..clear()
        ..addAll(selected);
      _currentPage = 0;
    });
    _persistState();
  }

  Future<void> _openOperationFilterDialog() async {
    final selected = await _showMayoreoValueFilterDialog(
      context,
      title: 'Filtrar operación',
      options: _MayoreoAccountsOperationType.values
          .map((item) => _operationTypeLabel(item))
          .toList(growable: false),
      initialValues: _operationFilters
          .map(
            (value) => _operationTypeLabel(
              _MayoreoAccountsOperationType.values.firstWhere(
                (item) => item.name == value,
              ),
            ),
          )
          .toSet(),
    );
    if (selected == null) return;
    setState(() {
      _operationFilters
        ..clear()
        ..addAll(
          _MayoreoAccountsOperationType.values
              .where((item) => selected.contains(_operationTypeLabel(item)))
              .map((item) => item.name),
        );
      _currentPage = 0;
    });
    _persistState();
  }

  Future<void> _openStatusFilterDialog() async {
    const overdueLabel = 'COBRO VENCIDO';
    final selected = await _showMayoreoValueFilterDialog(
      context,
      title: 'Filtrar estatus',
      options: <String>[
        ..._MayoreoAccountsStatus.values.map(_financialStatusLabel),
        overdueLabel,
      ],
      initialValues: {
        ..._statusFilters.map(
          (value) => _financialStatusLabel(
            _MayoreoAccountsStatus.values.firstWhere(
              (item) => item.name == value,
            ),
          ),
        ),
        if (_overdueEstimatedPaymentOnly) overdueLabel,
      },
    );
    if (selected == null) return;
    setState(() {
      _statusFilters
        ..clear()
        ..addAll(
          _MayoreoAccountsStatus.values
              .where((item) => selected.contains(_financialStatusLabel(item)))
              .map((item) => item.name),
        );
      _overdueEstimatedPaymentOnly = selected.contains(overdueLabel);
      _currentPage = 0;
    });
    _persistState();
  }

  Future<void> _openDocumentFilterDialog() async {
    final options =
        _rows
            .map((row) => row.documentNumber.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final selected = await _showMayoreoValueFilterDialog(
      context,
      title: 'Filtrar factura/cheque',
      options: options,
      initialValues: _documentFilters,
    );
    if (selected == null) return;
    setState(() {
      _documentFilters
        ..clear()
        ..addAll(selected);
      _currentPage = 0;
    });
    _persistState();
  }

  Future<void> _openDateRangeDialog() async {
    final bounds = _rows.map((row) => row.saleDate).toList(growable: false)
      ..sort();
    if (bounds.isEmpty) return;
    final initialRange = _dateFilterFrom == null || _dateFilterTo == null
        ? null
        : DateTimeRange(start: _dateFilterFrom!, end: _dateFilterTo!);
    final result = await _showMayoreoDateRangeFilterDialog(
      context,
      label: 'FECHA',
      bounds: DateTimeRange(start: bounds.first, end: bounds.last),
      initialRange: initialRange,
    );
    if (result == null) return;
    setState(() {
      if (result.clear) {
        _dateFilterFrom = null;
        _dateFilterTo = null;
      } else {
        _dateFilterFrom = result.range?.start;
        _dateFilterTo = result.range?.end;
      }
      _currentPage = 0;
    });
    _persistState();
  }

  Future<void> _openInvoiceDateFilterDialog() async {
    final bounds =
        _rows
            .map((row) => row.documentDate)
            .whereType<DateTime>()
            .toList(growable: false)
          ..sort();
    final now = DateTime.now();
    final initialRange =
        _invoiceDateFilterFrom == null || _invoiceDateFilterTo == null
        ? null
        : DateTimeRange(
            start: _invoiceDateFilterFrom!,
            end: _invoiceDateFilterTo!,
          );
    final result = await _showMayoreoDateRangeFilterDialog(
      context,
      label: 'FECHA FACTURA',
      bounds: DateTimeRange(
        start: bounds.isEmpty ? DateTime(now.year - 1, 1, 1) : bounds.first,
        end: bounds.isEmpty ? DateTime(now.year + 1, 12, 31) : bounds.last,
      ),
      initialRange: initialRange,
    );
    if (result == null) return;
    setState(() {
      if (result.clear) {
        _invoiceDateFilterFrom = null;
        _invoiceDateFilterTo = null;
      } else {
        _invoiceDateFilterFrom = result.range?.start;
        _invoiceDateFilterTo = result.range?.end;
      }
      _currentPage = 0;
    });
    _persistState();
  }

  Future<void> _openPaymentDateFilterDialog() async {
    final bounds =
        _rows
            .map((row) => row.settlementDate)
            .whereType<DateTime>()
            .toList(growable: false)
          ..sort();
    final now = DateTime.now();
    final initialRange =
        _paymentDateFilterFrom == null || _paymentDateFilterTo == null
        ? null
        : DateTimeRange(
            start: _paymentDateFilterFrom!,
            end: _paymentDateFilterTo!,
          );
    final result = await _showMayoreoDateRangeFilterDialog(
      context,
      label: 'FECHA PAGO',
      bounds: DateTimeRange(
        start: bounds.isEmpty ? DateTime(now.year - 1, 1, 1) : bounds.first,
        end: bounds.isEmpty ? DateTime(now.year + 1, 12, 31) : bounds.last,
      ),
      initialRange: initialRange,
    );
    if (result == null) return;
    setState(() {
      if (result.clear) {
        _paymentDateFilterFrom = null;
        _paymentDateFilterTo = null;
      } else {
        _paymentDateFilterFrom = result.range?.start;
        _paymentDateFilterTo = result.range?.end;
      }
      _currentPage = 0;
    });
    _persistState();
  }

  void _clearFilters() {
    setState(() {
      _dateFilterFrom = null;
      _dateFilterTo = null;
      _invoiceDateFilterFrom = null;
      _invoiceDateFilterTo = null;
      _paymentDateFilterFrom = null;
      _paymentDateFilterTo = null;
      _ticketFilters.clear();
      _clientFilters.clear();
      _remisionFilters.clear();
      _materialFilters.clear();
      _operationFilters.clear();
      _documentFilters.clear();
      _statusFilters.clear();
      _overdueEstimatedPaymentOnly = false;
      _currentPage = 0;
    });
    _persistState();
  }

  bool get _hasActiveFilters =>
      _dateFilterFrom != null ||
      _dateFilterTo != null ||
      _invoiceDateFilterFrom != null ||
      _invoiceDateFilterTo != null ||
      _paymentDateFilterFrom != null ||
      _paymentDateFilterTo != null ||
      _ticketFilters.isNotEmpty ||
      _clientFilters.isNotEmpty ||
      _remisionFilters.isNotEmpty ||
      _materialFilters.isNotEmpty ||
      _operationFilters.isNotEmpty ||
      _documentFilters.isNotEmpty ||
      _statusFilters.isNotEmpty ||
      _overdueEstimatedPaymentOnly;

  @override
  Widget build(BuildContext context) {
    final filteredRows = _filteredRows;
    final pageRows = _pageRows(filteredRows);
    final currentPage = _effectiveCurrentPageFor(filteredRows.length);
    final totalPages = _totalPagesForCount(_pageSize, filteredRows.length);
    final selectedRow = _rows
        .where((row) => row.id == _selectedRowId)
        .firstOrNull;
    final pendingTotal = filteredRows.fold<double>(
      0,
      (sum, row) => sum + (row.isFinanciallyOpen ? row.pendingBalance : 0),
    );
    final paidTotal = filteredRows.fold<double>(
      0,
      (sum, row) => sum + row.paidAmount,
    );
    final toInvoiceTotal = filteredRows
        .where(
          (row) =>
              row.operationType == _MayoreoAccountsOperationType.factura &&
              row.documentNumber.trim().isEmpty,
        )
        .fold<double>(0, (sum, row) => sum + row.approvedAmount);
    final pendingCheckTotal = filteredRows
        .where(
          (row) =>
              row.operationType == _MayoreoAccountsOperationType.cheque &&
              row.status != _MayoreoAccountsStatus.chequeCanjeado,
        )
        .fold<double>(0, (sum, row) => sum + row.approvedAmount);

    return AreaThemeScope(
      tokens: mayoreoAreaTokens,
      child: Theme(
        data: _mayoreoMaterialTheme(context),
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final selectedIndex = _selectedFilteredIndex(pageRows);
            if (event.logicalKey == LogicalKeyboardKey.escape && _menuOpen) {
              setState(() => _menuOpen = false);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.escape &&
                _selectedRowIds.isNotEmpty) {
              setState(_clearSelection);
              _persistState();
              return KeyEventResult.handled;
            }
            if (_isShortcutModifierPressed() &&
                event.logicalKey == LogicalKeyboardKey.keyA &&
                pageRows.isNotEmpty) {
              setState(() => _selectAllVisibleRows(pageRows));
              _persistState();
              return KeyEventResult.handled;
            }
            if (pageRows.isNotEmpty &&
                event.logicalKey == LogicalKeyboardKey.arrowDown) {
              if (_isShiftPressed() && selectedIndex >= 0) {
                final targetIndex = (selectedIndex + 1).clamp(
                  0,
                  pageRows.length - 1,
                );
                setState(
                  () => _extendSelectionTo(pageRows[targetIndex].id, pageRows),
                );
                _persistState();
              } else {
                _selectFilteredIndex(
                  pageRows,
                  selectedIndex < 0 ? 0 : selectedIndex + 1,
                );
              }
              return KeyEventResult.handled;
            }
            if (pageRows.isNotEmpty &&
                event.logicalKey == LogicalKeyboardKey.arrowUp) {
              if (_isShiftPressed() && selectedIndex >= 0) {
                final targetIndex = (selectedIndex - 1).clamp(
                  0,
                  pageRows.length - 1,
                );
                setState(
                  () => _extendSelectionTo(pageRows[targetIndex].id, pageRows),
                );
                _persistState();
              } else {
                _selectFilteredIndex(
                  pageRows,
                  selectedIndex <= 0 ? 0 : selectedIndex - 1,
                );
              }
              return KeyEventResult.handled;
            }
            if (selectedRow != null && isEnterKey(event.logicalKey)) {
              unawaited(_openDetailDialog(selectedRow));
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: AppShell(
            background: const _AccountsBackground(),
            wrapBodyInGlass: false,
            animateHeaderSlots: false,
            animateBody: !widget.instantOpen,
            headerBodySpacing: 8,
            padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
            leadingBuilder: (_, _) => _AccountsHeaderButton(
              label: _menuOpen ? 'Cerrar panel' : 'Navegación',
              icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
              onTapSync: () => setState(() => _menuOpen = !_menuOpen),
            ),
            centerBuilder: (_, _) => const _AccountsHeaderBrand(),
            trailingBuilder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AccountsHeaderButton(
                  label: 'Correo',
                  icon: Icons.mail_outline_rounded,
                  compact: true,
                  onTap: _openMailHostinger,
                ),
                const SizedBox(width: 10),
                _AccountsHeaderButton(
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
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: SingleChildScrollView(
                      controller: _rowsScrollController,
                      padding: const EdgeInsets.only(
                        left: 56,
                        right: 12,
                        bottom: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AccountsTopBar(
                            selectedRow: selectedRow,
                            visibleCount: filteredRows.length,
                            selectedCount: _selectedRowIds.length,
                            pendingTotal: pendingTotal,
                            paidTotal: paidTotal,
                            toInvoiceTotal: toInvoiceTotal,
                            pendingCheckTotal: pendingCheckTotal,
                            exportingCsv: _exportingCsv,
                            onExportCsv: _exportCsv,
                          ),
                          const SizedBox(height: 12),
                          _AccountsGridCard(
                            rows: filteredRows,
                            pageRows: pageRows,
                            selectedRowId: _selectedRowId,
                            selectedRowIds: _selectedRowIds,
                            rowKeys: _rowKeys,
                            viewportKey: _rowsViewportKey,
                            hasDateFilter:
                                _dateFilterFrom != null ||
                                _dateFilterTo != null,
                            hasTicketFilter: _ticketFilters.isNotEmpty,
                            hasClientFilter: _clientFilters.isNotEmpty,
                            hasRemisionFilter: _remisionFilters.isNotEmpty,
                            hasMaterialFilter: _materialFilters.isNotEmpty,
                            hasOperationFilter: _operationFilters.isNotEmpty,
                            hasDocumentFilter: _documentFilters.isNotEmpty,
                            hasInvoiceDateFilter:
                                _invoiceDateFilterFrom != null ||
                                _invoiceDateFilterTo != null,
                            hasPaymentDateFilter:
                                _paymentDateFilterFrom != null ||
                                _paymentDateFilterTo != null,
                            hasStatusFilter: _statusFilters.isNotEmpty,
                            onOpenDateFilter: _openDateRangeDialog,
                            onOpenTicketFilter: _openTicketFilterDialog,
                            onOpenClientFilter: _openClientFilterDialog,
                            onOpenRemisionFilter: _openRemisionFilterDialog,
                            onOpenMaterialFilter: _openMaterialFilterDialog,
                            onOpenOperationFilter: _openOperationFilterDialog,
                            onOpenDocumentFilter: _openDocumentFilterDialog,
                            onOpenInvoiceDateFilter:
                                _openInvoiceDateFilterDialog,
                            onOpenPaymentDateFilter:
                                _openPaymentDateFilterDialog,
                            onOpenStatusFilter: _openStatusFilterDialog,
                            onClearFilters: _hasActiveFilters
                                ? _clearFilters
                                : null,
                            onRowPrimaryPointerDown: (rowId) =>
                                _handleRowPrimaryPointerDown(rowId, pageRows),
                            onTapRow: _handleRowTap,
                            onRowDragEnter: (rowId) =>
                                _handleRowDragEnter(rowId, pageRows),
                            onRowPointerEnd: _handleRowsPointerEnd,
                            onRowsPointerDown: (event) =>
                                _handleRowsPointerDown(event, pageRows),
                            onRowsPointerMove: (event) =>
                                _handleRowsPointerMove(event, pageRows),
                            onDoubleTapRow: _openDetailDialog,
                            onMenuAction: _handleMenuAction,
                            onSecondaryTapDown: (row, globalPosition) =>
                                _showContextMenuForRow(
                                  row,
                                  pageRows,
                                  globalPosition,
                                ),
                            onTapOutside: _selectedRowIds.isNotEmpty
                                ? () {
                                    setState(_clearSelection);
                                    _persistState();
                                  }
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _MayoreoGridPager(
                              currentPage: currentPage,
                              totalPages: totalPages,
                              pageSize: _pageSize,
                              totalRows: filteredRows.length,
                              onPrevious: currentPage > 0
                                  ? () {
                                      setState(
                                        () => _currentPage = currentPage - 1,
                                      );
                                      _persistState();
                                    }
                                  : null,
                              onNext: currentPage < totalPages - 1
                                  ? () {
                                      setState(
                                        () => _currentPage = currentPage + 1,
                                      );
                                      _persistState();
                                    }
                                  : null,
                              onPageSizeChanged: (value) {
                                setState(() {
                                  _pageSize = value;
                                  _currentPage = 0;
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
                    child: _AccountsSidePanel(
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

class _AccountsTopBar extends StatelessWidget {
  final _MayoreoAccountRow? selectedRow;
  final int visibleCount;
  final int selectedCount;
  final double pendingTotal;
  final double paidTotal;
  final double toInvoiceTotal;
  final double pendingCheckTotal;
  final bool exportingCsv;
  final Future<void> Function() onExportCsv;

  const _AccountsTopBar({
    required this.selectedRow,
    required this.visibleCount,
    required this.selectedCount,
    required this.pendingTotal,
    required this.paidTotal,
    required this.toInvoiceTotal,
    required this.pendingCheckTotal,
    required this.exportingCsv,
    required this.onExportCsv,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Ventas / Cuentas',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        AppGlassToolbarPanel(
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: _mayoreoToolbarSecondaryActionStyle(),
                      onPressed: exportingCsv
                          ? null
                          : () => unawaited(onExportCsv()),
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
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _AccountsSelectionInfo(
                selectedRow: selectedRow,
                visibleCount: visibleCount,
                selectedCount: selectedCount,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _AccountsMetricCard(
              icon: Icons.pending_actions_rounded,
              title: 'TOTAL PENDIENTE',
              value: formatMoney(pendingTotal, decimals: 0),
              detail: 'Saldo abierto visible',
            ),
            _AccountsMetricCard(
              icon: Icons.verified_rounded,
              title: 'TOTAL PAGADO',
              value: formatMoney(paidTotal, decimals: 0),
              detail: 'Pagos/canjes registrados',
            ),
            _AccountsMetricCard(
              icon: Icons.receipt_long_rounded,
              title: 'POR FACTURAR',
              value: formatMoney(toInvoiceTotal, decimals: 0),
              detail: 'Factura aún no asignada',
            ),
            _AccountsMetricCard(
              icon: Icons.payments_outlined,
              title: 'CHEQUE PEND./CANJE',
              value: formatMoney(pendingCheckTotal, decimals: 0),
              detail: 'Cheque recibido o pendiente',
            ),
          ],
        ),
      ],
    );
  }
}

class _AccountsSelectionInfo extends StatelessWidget {
  final _MayoreoAccountRow? selectedRow;
  final int visibleCount;
  final int selectedCount;

  const _AccountsSelectionInfo({
    required this.selectedRow,
    required this.visibleCount,
    required this.selectedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          selectedCount > 0
              ? '$selectedCount seleccionadas · $visibleCount visibles'
              : '$visibleCount cuentas visibles',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: kMayoreoMutedInk,
          ),
        ),
        if (selectedRow != null)
          Text(
            '${selectedRow!.ticket} · ${formatMoney(selectedRow!.pendingBalance, decimals: 0)} saldo',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kMayoreoMutedInk,
            ),
          ),
      ],
    );
  }
}

class _AccountsMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String detail;

  const _AccountsMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      width: 308,
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.badgeBackground.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tokens.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: tokens.primaryStrong.withValues(alpha: 0.24),
              ),
            ),
            child: Icon(icon, size: 18, color: tokens.primaryStrong),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: kMayoreoMutedInk,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: kMayoreoInk,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: kMayoreoMutedInk,
                    height: 1.0,
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

class _MayoreoGridHeaderFilterCell extends StatelessWidget {
  final String label;
  final TextStyle style;
  final bool active;
  final Future<void> Function()? onTap;

  const _MayoreoGridHeaderFilterCell({
    required this.label,
    required this.style,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      children: [
        if (onTap != null) ...[
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => unawaited(onTap!.call()),
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
        ],
        Expanded(
          child: Text(label, style: style, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _MayoreoGridPager extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final int totalRows;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onPageSizeChanged;

  const _MayoreoGridPager({
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
              style: _mayoreoSecondaryButtonStyle(),
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
              style: _mayoreoSecondaryButtonStyle(),
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
                      color: tokens.primaryStrong.withValues(alpha: 0.42),
                      width: 1.4,
                    ),
                  ),
                ),
                items: const [40, 80, 120]
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
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
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: tokens.primaryStrong,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountsGridCard extends StatelessWidget {
  final List<_MayoreoAccountRow> rows;
  final List<_MayoreoAccountRow> pageRows;
  final String? selectedRowId;
  final Set<String> selectedRowIds;
  final Map<String, GlobalKey> rowKeys;
  final Key viewportKey;
  final bool hasDateFilter;
  final bool hasTicketFilter;
  final bool hasClientFilter;
  final bool hasRemisionFilter;
  final bool hasMaterialFilter;
  final bool hasOperationFilter;
  final bool hasDocumentFilter;
  final bool hasInvoiceDateFilter;
  final bool hasPaymentDateFilter;
  final bool hasStatusFilter;
  final Future<void> Function() onOpenDateFilter;
  final Future<void> Function() onOpenTicketFilter;
  final Future<void> Function() onOpenClientFilter;
  final Future<void> Function() onOpenRemisionFilter;
  final Future<void> Function() onOpenMaterialFilter;
  final Future<void> Function() onOpenOperationFilter;
  final Future<void> Function() onOpenDocumentFilter;
  final Future<void> Function() onOpenInvoiceDateFilter;
  final Future<void> Function() onOpenPaymentDateFilter;
  final Future<void> Function() onOpenStatusFilter;
  final VoidCallback? onClearFilters;
  final ValueChanged<String> onRowPrimaryPointerDown;
  final ValueChanged<String> onTapRow;
  final ValueChanged<String> onRowDragEnter;
  final VoidCallback onRowPointerEnd;
  final ValueChanged<PointerDownEvent> onRowsPointerDown;
  final ValueChanged<PointerMoveEvent> onRowsPointerMove;
  final ValueChanged<_MayoreoAccountRow> onDoubleTapRow;
  final Future<void> Function(
    _MayoreoAccountRow row,
    _AccountsMenuAction action,
  )
  onMenuAction;
  final Future<void> Function(_MayoreoAccountRow row, Offset globalPosition)
  onSecondaryTapDown;
  final VoidCallback? onTapOutside;

  const _AccountsGridCard({
    required this.rows,
    required this.pageRows,
    required this.selectedRowId,
    required this.selectedRowIds,
    required this.rowKeys,
    required this.viewportKey,
    required this.hasDateFilter,
    required this.hasTicketFilter,
    required this.hasClientFilter,
    required this.hasRemisionFilter,
    required this.hasMaterialFilter,
    required this.hasOperationFilter,
    required this.hasDocumentFilter,
    required this.hasInvoiceDateFilter,
    required this.hasPaymentDateFilter,
    required this.hasStatusFilter,
    required this.onOpenDateFilter,
    required this.onOpenTicketFilter,
    required this.onOpenClientFilter,
    required this.onOpenRemisionFilter,
    required this.onOpenMaterialFilter,
    required this.onOpenOperationFilter,
    required this.onOpenDocumentFilter,
    required this.onOpenInvoiceDateFilter,
    required this.onOpenPaymentDateFilter,
    required this.onOpenStatusFilter,
    this.onClearFilters,
    required this.onRowPrimaryPointerDown,
    required this.onTapRow,
    required this.onRowDragEnter,
    required this.onRowPointerEnd,
    required this.onRowsPointerDown,
    required this.onRowsPointerMove,
    required this.onDoubleTapRow,
    required this.onMenuAction,
    required this.onSecondaryTapDown,
    this.onTapOutside,
  });

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: onTapOutside == null ? null : (_) => onTapOutside!.call(),
      child: ContractGlassCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (onClearFilters != null) ...[
              Row(
                children: [
                  const Spacer(),
                  OutlinedButton(
                    style: _mayoreoSecondaryButtonStyle(),
                    onPressed: onClearFilters,
                    child: const Text('Limpiar filtros'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            _AccountsGridHeader(
              hasDateFilter: hasDateFilter,
              hasTicketFilter: hasTicketFilter,
              hasClientFilter: hasClientFilter,
              hasRemisionFilter: hasRemisionFilter,
              hasMaterialFilter: hasMaterialFilter,
              hasOperationFilter: hasOperationFilter,
              hasDocumentFilter: hasDocumentFilter,
              hasInvoiceDateFilter: hasInvoiceDateFilter,
              hasPaymentDateFilter: hasPaymentDateFilter,
              hasStatusFilter: hasStatusFilter,
              onOpenDateFilter: onOpenDateFilter,
              onOpenTicketFilter: onOpenTicketFilter,
              onOpenClientFilter: onOpenClientFilter,
              onOpenRemisionFilter: onOpenRemisionFilter,
              onOpenMaterialFilter: onOpenMaterialFilter,
              onOpenOperationFilter: onOpenOperationFilter,
              onOpenDocumentFilter: onOpenDocumentFilter,
              onOpenInvoiceDateFilter: onOpenInvoiceDateFilter,
              onOpenPaymentDateFilter: onOpenPaymentDateFilter,
              onOpenStatusFilter: onOpenStatusFilter,
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: _kAccountsGridMinHeight,
              ),
              child: rows.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        gradient: kMayoreoPanelGradient,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: mayoreoAreaTokens.border.withValues(
                            alpha: 0.52,
                          ),
                        ),
                      ),
                      child: const Text(
                        'No hay cuentas visibles. Primero relaciona ventas en Reporte de Ventas o ajusta filtros.',
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
                            for (final row in pageRows) ...[
                              _AccountsGridRow(
                                key: rowKeys.putIfAbsent(
                                  row.id,
                                  () => GlobalKey(),
                                ),
                                row: row,
                                selected: selectedRowIds.contains(row.id),
                                active: row.id == selectedRowId,
                                onPrimaryPointerDown: () =>
                                    onRowPrimaryPointerDown(row.id),
                                onTap: () => onTapRow(row.id),
                                onDragEnter: () => onRowDragEnter(row.id),
                                onDoubleTap: () => onDoubleTapRow(row),
                                onMenuAction: (action) =>
                                    onMenuAction(row, action),
                                onSecondaryTapDown: (globalPosition) =>
                                    onSecondaryTapDown(row, globalPosition),
                              ),
                              if (row != pageRows.last)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountsGridHeader extends StatelessWidget {
  final bool hasDateFilter;
  final bool hasTicketFilter;
  final bool hasClientFilter;
  final bool hasRemisionFilter;
  final bool hasMaterialFilter;
  final bool hasOperationFilter;
  final bool hasDocumentFilter;
  final bool hasInvoiceDateFilter;
  final bool hasPaymentDateFilter;
  final bool hasStatusFilter;
  final Future<void> Function() onOpenDateFilter;
  final Future<void> Function() onOpenTicketFilter;
  final Future<void> Function() onOpenClientFilter;
  final Future<void> Function() onOpenRemisionFilter;
  final Future<void> Function() onOpenMaterialFilter;
  final Future<void> Function() onOpenOperationFilter;
  final Future<void> Function() onOpenDocumentFilter;
  final Future<void> Function() onOpenInvoiceDateFilter;
  final Future<void> Function() onOpenPaymentDateFilter;
  final Future<void> Function() onOpenStatusFilter;

  const _AccountsGridHeader({
    required this.hasDateFilter,
    required this.hasTicketFilter,
    required this.hasClientFilter,
    required this.hasRemisionFilter,
    required this.hasMaterialFilter,
    required this.hasOperationFilter,
    required this.hasDocumentFilter,
    required this.hasInvoiceDateFilter,
    required this.hasPaymentDateFilter,
    required this.hasStatusFilter,
    required this.onOpenDateFilter,
    required this.onOpenTicketFilter,
    required this.onOpenClientFilter,
    required this.onOpenRemisionFilter,
    required this.onOpenMaterialFilter,
    required this.onOpenOperationFilter,
    required this.onOpenDocumentFilter,
    required this.onOpenInvoiceDateFilter,
    required this.onOpenPaymentDateFilter,
    required this.onOpenStatusFilter,
  });

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w900,
      color: kMayoreoInk,
    );

    Widget plainCell(String label, double width) {
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
          child: _MayoreoGridHeaderFilterCell(
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
            width: _kAccountsDateW,
            active: hasDateFilter,
            onTap: onOpenDateFilter,
          ),
          filterCell(
            label: 'TICKET',
            width: _kAccountsTicketW,
            active: hasTicketFilter,
            onTap: onOpenTicketFilter,
          ),
          filterCell(
            label: 'CLIENTE',
            width: _kAccountsClientW,
            active: hasClientFilter,
            onTap: onOpenClientFilter,
          ),
          filterCell(
            label: 'REMISIÓN',
            width: _kAccountsRemisionW,
            active: hasRemisionFilter,
            onTap: onOpenRemisionFilter,
          ),
          filterCell(
            label: 'MATERIAL',
            width: _kAccountsMaterialW,
            active: hasMaterialFilter,
            onTap: onOpenMaterialFilter,
          ),
          plainCell('PESO APROB.', _kAccountsApprovedWeightW),
          plainCell('PRECIO APROB.', _kAccountsApprovedPriceW),
          plainCell('IMPORTE', _kAccountsAmountW),
          filterCell(
            label: 'OPERACIÓN',
            width: _kAccountsOperationW,
            active: hasOperationFilter,
            onTap: onOpenOperationFilter,
          ),
          filterCell(
            label: 'FACT./CHEQUE',
            width: _kAccountsDocumentW,
            active: hasDocumentFilter,
            onTap: onOpenDocumentFilter,
          ),
          filterCell(
            label: 'FECHA FACT.',
            width: _kAccountsInvoiceDateW,
            active: hasInvoiceDateFilter,
            onTap: onOpenInvoiceDateFilter,
          ),
          filterCell(
            label: 'FECHA PAGO',
            width: _kAccountsPaymentDateW,
            active: hasPaymentDateFilter,
            onTap: onOpenPaymentDateFilter,
          ),
          filterCell(
            label: 'ESTATUS',
            width: _kAccountsStatusW,
            active: hasStatusFilter,
            onTap: onOpenStatusFilter,
          ),
          plainCell('ACCIONES', _kAccountsActionsW),
        ],
      ),
    );
  }
}

class _AccountsGridRow extends StatefulWidget {
  final _MayoreoAccountRow row;
  final bool selected;
  final bool active;
  final VoidCallback onPrimaryPointerDown;
  final VoidCallback onTap;
  final VoidCallback onDragEnter;
  final VoidCallback onDoubleTap;
  final Future<void> Function(_AccountsMenuAction action) onMenuAction;
  final Future<void> Function(Offset globalPosition)? onSecondaryTapDown;

  const _AccountsGridRow({
    super.key,
    required this.row,
    required this.selected,
    required this.active,
    required this.onPrimaryPointerDown,
    required this.onTap,
    required this.onDragEnter,
    required this.onDoubleTap,
    required this.onMenuAction,
    this.onSecondaryTapDown,
  });

  @override
  State<_AccountsGridRow> createState() => _AccountsGridRowState();
}

class _AccountsGridRowState extends State<_AccountsGridRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final highlighted = widget.selected || widget.active || _hovered;
    final overdueReminder = row.hasEstimatedPaymentReminder;

    Widget cell(double width, Widget child) {
      return SizedBox(
        width: width,
        child: Padding(padding: const EdgeInsets.only(right: 10), child: child),
      );
    }

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        widget.onDragEnter();
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
                : overdueReminder
                ? [
                    const Color(0xFFFFEFE8).withValues(alpha: 0.92),
                    const Color(0xFFFFD9C7).withValues(alpha: 0.84),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.78),
                    mayoreoAreaTokens.surfaceTint.withValues(alpha: 0.74),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: highlighted
                ? mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.22)
                : overdueReminder
                ? const Color(0xFFD86A3A).withValues(alpha: 0.44)
                : mayoreoAreaTokens.border.withValues(alpha: 0.54),
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
                    : (details) => unawaited(
                        widget.onSecondaryTapDown!(details.globalPosition),
                      ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: widget.onTap,
                  onDoubleTap: widget.onDoubleTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      cell(_kAccountsDateW, Text(_formatDate(row.saleDate))),
                      cell(
                        _kAccountsTicketW,
                        Text(
                          row.ticket,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      cell(_kAccountsClientW, Text(row.clientName)),
                      cell(_kAccountsRemisionW, Text(row.remision)),
                      cell(_kAccountsMaterialW, Text(row.materialName)),
                      cell(
                        _kAccountsApprovedWeightW,
                        Text('${formatDecimal(row.approvedWeight)} KG'),
                      ),
                      cell(
                        _kAccountsApprovedPriceW,
                        Text(formatMoney(row.approvedPrice)),
                      ),
                      cell(
                        _kAccountsAmountW,
                        Text(
                          formatMoney(row.approvedAmount, decimals: 0),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      cell(
                        _kAccountsOperationW,
                        Text(_operationTypeLabel(row.operationType)),
                      ),
                      cell(
                        _kAccountsDocumentW,
                        Text(
                          row.documentNumber.trim().isEmpty
                              ? '—'
                              : row.documentNumber,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: row.documentNumber.trim().isEmpty
                                ? kMayoreoMutedInk
                                : kMayoreoInk,
                          ),
                        ),
                      ),
                      cell(
                        _kAccountsInvoiceDateW,
                        Text(
                          row.documentDate == null
                              ? '—'
                              : _formatDate(row.documentDate!),
                        ),
                      ),
                      cell(
                        _kAccountsPaymentDateW,
                        Text(
                          row.settlementDate == null
                              ? '—'
                              : _formatDate(row.settlementDate!),
                          style: TextStyle(
                            fontWeight: overdueReminder
                                ? FontWeight.w900
                                : FontWeight.w700,
                            color: overdueReminder
                                ? const Color(0xFFB14E20)
                                : kMayoreoInk,
                          ),
                        ),
                      ),
                      cell(
                        _kAccountsStatusW,
                        _AccountsStatusChip(
                          status: row.status,
                          active: highlighted,
                        ),
                      ),
                      SizedBox(
                        width: _kAccountsActionsW,
                        child: AnchoredActionSlot(
                          width: _kAccountsActionsW,
                          trailingWidth: 38,
                          gap: 0,
                          leading: const SizedBox.shrink(),
                          trailing: PopupMenuButton<_AccountsMenuAction>(
                            tooltip: 'Acciones de cuenta',
                            onSelected: (action) =>
                                unawaited(widget.onMenuAction(action)),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: _AccountsMenuAction.detail,
                                child: Text('Abrir detalle'),
                              ),
                              PopupMenuItem(
                                value: _AccountsMenuAction.markReview,
                                child: Text('Marcar por revisar'),
                              ),
                            ],
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.82),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: mayoreoAreaTokens.primarySoft
                                      .withValues(alpha: 0.86),
                                ),
                              ),
                              child: const Icon(
                                Icons.more_horiz_rounded,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
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

class _AccountsStatusChip extends StatelessWidget {
  final _MayoreoAccountsStatus status;
  final bool active;

  const _AccountsStatusChip({required this.status, required this.active});

  @override
  Widget build(BuildContext context) {
    final scheme = _statusColors(status);
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.$1, scheme.$2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.$3.withValues(alpha: 0.95)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_statusIcon(status), size: 14, color: scheme.$4),
            const SizedBox(width: 6),
            Text(
              _financialStatusLabel(status),
              style: TextStyle(
                fontSize: 11.2,
                fontWeight: FontWeight.w900,
                color: scheme.$4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDetailDialog extends StatefulWidget {
  final _MayoreoAccountRow row;

  const _AccountDetailDialog({required this.row});

  @override
  State<_AccountDetailDialog> createState() => _AccountDetailDialogState();
}

class _AccountDetailDialogState extends State<_AccountDetailDialog> {
  late final TextEditingController _documentNumberC;
  late final TextEditingController _paidAmountC;
  late final TextEditingController _notesC;
  late _MayoreoAccountsStatus _status;
  late DateTime? _documentDate;
  late DateTime? _estimatedPaymentDate;
  late DateTime? _settlementDate;

  @override
  void initState() {
    super.initState();
    _documentNumberC = TextEditingController(text: widget.row.documentNumber);
    _paidAmountC = TextEditingController(
      text: widget.row.paidAmount == 0
          ? ''
          : formatDecimal(widget.row.paidAmount),
    );
    _notesC = TextEditingController(text: widget.row.financialNotes);
    _status = widget.row.status;
    _documentDate = widget.row.documentDate;
    _estimatedPaymentDate = widget.row.estimatedPaymentDate;
    _settlementDate = widget.row.settlementDate;
  }

  @override
  void dispose() {
    _documentNumberC.dispose();
    _paidAmountC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final paidAmount = _parseDouble(_paidAmountC.text) ?? 0;
    final documentNumber = _documentNumberC.text.trim();
    final normalizedStatus = _normalizeFinancialStatus(
      baseStatus: _status,
      operationType: widget.row.operationType,
      documentNumber: documentNumber,
      documentDate: _documentDate,
      settlementDate: _settlementDate,
      paidAmount: paidAmount,
      approvedAmount: widget.row.approvedAmount,
    );
    final requiresException =
        _isFinalFinancialStatus(normalizedStatus) &&
        (documentNumber.isEmpty || _documentDate == null);
    if (requiresException) {
      final confirm = await _showFinancialExceptionConfirmDialog(context);
      if (!confirm) return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      widget.row.copyWith(
        documentNumber: documentNumber,
        documentDate: _documentDate,
        estimatedPaymentDate: _estimatedPaymentDate,
        settlementDate: _settlementDate,
        status: normalizedStatus,
        paidAmount: paidAmount,
        financialNotes: _notesC.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final paidAmount = _parseDouble(_paidAmountC.text) ?? 0;
    final nextStatus = _normalizeFinancialStatus(
      baseStatus: _status,
      operationType: row.operationType,
      documentNumber: _documentNumberC.text.trim(),
      documentDate: _documentDate,
      settlementDate: _settlementDate,
      paidAmount: paidAmount,
      approvedAmount: row.approvedAmount,
    );
    final pendingBalance = (row.approvedAmount - paidAmount)
        .clamp(-999999999, 999999999)
        .toDouble();
    final documentLabel =
        row.operationType == _MayoreoAccountsOperationType.factura
        ? 'NÚMERO DE FACTURA'
        : 'NÚMERO DE CHEQUE';
    final documentDateLabel =
        row.operationType == _MayoreoAccountsOperationType.factura
        ? 'FECHA DE FACTURA'
        : 'FECHA DE CHEQUE';
    const estimatedPaymentLabel = 'FECHA DE PAGO ESTIMADA';
    final settlementLabel =
        row.operationType == _MayoreoAccountsOperationType.factura
        ? 'FECHA DE PAGO'
        : 'FECHA DE CANJE';

    return ContractDialogShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _DetailTitleBlock(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Detalle de cuenta',
                      subtitle:
                          'Completa aquí la capa financiera sin recapturar la venta.',
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _DetailSummaryCard(
                      icon: Icons.payments_outlined,
                      title: 'IMPORTE APROBADO',
                      value: formatMoney(row.approvedAmount, decimals: 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DetailSummaryCard(
                      icon: Icons.pending_actions_rounded,
                      title: 'SALDO PENDIENTE',
                      value: formatMoney(pendingBalance, decimals: 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 11,
                        child: _DetailSection(
                          icon: Icons.local_shipping_outlined,
                          title: '1. Venta origen',
                          child: Column(
                            children: [
                              _DetailFieldsRow(
                                left: _ReadOnlyField(
                                  label: 'TICKET',
                                  value: row.ticket,
                                ),
                                right: _ReadOnlyField(
                                  label: 'FECHA',
                                  value: _formatDate(row.saleDate),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _DetailFieldsRow(
                                left: _ReadOnlyField(
                                  label: 'CLIENTE',
                                  value: row.clientName,
                                ),
                                right: _ReadOnlyField(
                                  label: 'REMISIÓN',
                                  value: row.remision,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _DetailFieldsRow(
                                left: _ReadOnlyField(
                                  label: 'MATERIAL',
                                  value: row.materialName,
                                ),
                                right: _ReadOnlyField(
                                  label: 'PESO APROBADO',
                                  value:
                                      '${formatDecimal(row.approvedWeight)} KG',
                                ),
                              ),
                              const SizedBox(height: 10),
                              _DetailFieldsRow(
                                left: _ReadOnlyField(
                                  label: 'PRECIO APROBADO',
                                  value: formatMoney(row.approvedPrice),
                                ),
                                right: _ReadOnlyField(
                                  label: 'OPERACIÓN',
                                  value: _operationTypeLabel(row.operationType),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DetailSection(
                              icon: Icons.account_balance_wallet_outlined,
                              title: '2. Seguimiento financiero',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Completa documento, fechas y conciliación sin tocar la información operativa de la venta.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: mayoreoAreaTokens.badgeText,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Column(
                                    children: [
                                      _DetailFieldsRow(
                                        left: _EditableFieldShell(
                                          label: documentLabel,
                                          child: TextField(
                                            controller: _documentNumberC,
                                            textCapitalization:
                                                TextCapitalization.characters,
                                            decoration: const InputDecoration(
                                              hintText: 'Captura documento',
                                            ),
                                          ),
                                        ),
                                        right: _DatePickerField(
                                          label: documentDateLabel,
                                          value: _documentDate,
                                          onTap: () async {
                                            final picked =
                                                await _pickMayoreoDate(
                                                  context,
                                                  _documentDate,
                                                );
                                            if (picked == null) return;
                                            setState(
                                              () => _documentDate = picked,
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _DetailFieldsRow(
                                        left: _DatePickerField(
                                          label: estimatedPaymentLabel,
                                          value: _estimatedPaymentDate,
                                          onTap: () async {
                                            final picked =
                                                await _pickMayoreoDate(
                                                  context,
                                                  _estimatedPaymentDate,
                                                );
                                            if (picked == null) return;
                                            setState(
                                              () => _estimatedPaymentDate =
                                                  picked,
                                            );
                                          },
                                        ),
                                        right: _DatePickerField(
                                          label: settlementLabel,
                                          value: _settlementDate,
                                          onTap: () async {
                                            final picked =
                                                await _pickMayoreoDate(
                                                  context,
                                                  _settlementDate,
                                                );
                                            if (picked == null) return;
                                            setState(
                                              () => _settlementDate = picked,
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _DetailFieldsRow(
                                        left: _EditableFieldShell(
                                          label: 'MONTO PAGADO',
                                          child: TextField(
                                            controller: _paidAmountC,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration: const InputDecoration(
                                              hintText: 'Monto pagado',
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                        right: _StatusPickerField(
                                          label: 'ESTATUS',
                                          value: _status,
                                          operationType: row.operationType,
                                          onChanged: (value) =>
                                              setState(() => _status = value),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _DetailFieldsRow(
                                        left: const SizedBox.shrink(),
                                        right: _ReadOnlyField(
                                          label: 'SALDO PENDIENTE',
                                          value: formatMoney(
                                            pendingBalance,
                                            decimals: 0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _EditableFieldShell(
                                    label: 'OBSERVACIONES FINANCIERAS',
                                    wide: true,
                                    child: TextField(
                                      controller: _notesC,
                                      minLines: 3,
                                      maxLines: 4,
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Notas financieras o aclaraciones',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _AccountsStatusChip(
                                      status: nextStatus,
                                      active: false,
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
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: _mayoreoSecondaryButtonStyle(),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: _mayoreoPrimaryButtonStyle(),
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar cuenta'),
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

class _DetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailTitleBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _DetailTitleBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: kMayoreoPanelGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tokens.primaryStrong.withValues(alpha: 0.18),
            ),
          ),
          child: Icon(icon, color: tokens.primaryStrong),
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tokens.badgeText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailSummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailSummaryCard({
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
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailFieldsRow extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _DetailFieldsRow({required this.left, required this.right});

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

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

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
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _EditableFieldShell extends StatelessWidget {
  final String label;
  final Widget child;
  final bool wide;

  const _EditableFieldShell({
    required this.label,
    required this.child,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      constraints: BoxConstraints(minHeight: wide ? 120 : 82),
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

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final Future<void> Function() onTap;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _EditableFieldShell(
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => unawaited(onTap()),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null ? 'Seleccionar fecha' : _formatDate(value!),
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

class _StatusPickerField extends StatelessWidget {
  final String label;
  final _MayoreoAccountsStatus value;
  final _MayoreoAccountsOperationType operationType;
  final ValueChanged<_MayoreoAccountsStatus> onChanged;

  const _StatusPickerField({
    required this.label,
    required this.value,
    required this.operationType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final allowed = _statusesForOperation(operationType);
    final tokens = AreaThemeScope.of(context);
    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: mayoreoAreaTokens.surfaceTint,
        highlightColor: tokens.primarySoft.withValues(alpha: 0.14),
        splashColor: tokens.primarySoft.withValues(alpha: 0.12),
        hoverColor: tokens.primarySoft.withValues(alpha: 0.12),
        iconTheme: const IconThemeData(color: kMayoreoInk),
        textTheme: Theme.of(
          context,
        ).textTheme.apply(bodyColor: kMayoreoInk, displayColor: kMayoreoInk),
        listTileTheme: const ListTileThemeData(
          textColor: kMayoreoInk,
          iconColor: kMayoreoInk,
        ),
      ),
      child: _EditableFieldShell(
        label: label,
        child: DropdownButtonFormField<_MayoreoAccountsStatus>(
          initialValue: value,
          isExpanded: true,
          menuMaxHeight: 320,
          borderRadius: BorderRadius.circular(18),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: kMayoreoInk,
          ),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: kMayoreoInk,
          ),
          decoration: const InputDecoration(isDense: true),
          dropdownColor: mayoreoAreaTokens.surfaceTint,
          selectedItemBuilder: (context) {
            return allowed
                .map(
                  (item) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _financialStatusLabel(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: kMayoreoInk,
                      ),
                    ),
                  ),
                )
                .toList(growable: false);
          },
          items: allowed
              .map(
                (item) => DropdownMenuItem<_MayoreoAccountsStatus>(
                  value: item,
                  child: Text(
                    _financialStatusLabel(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: kMayoreoInk,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _AccountsHeaderBrand extends StatelessWidget {
  const _AccountsHeaderBrand();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
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
                color: tokens.glow.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Center(child: DicsaLogoD(size: 36, progress: 1)),
        ),
        const SizedBox(width: 14),
        const Text(
          'Cuentas',
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

class _AccountsHeaderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final bool compact;

  const _AccountsHeaderButton({
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
            mainAxisSize: MainAxisSize.min,
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

class _AccountsSidePanel extends StatelessWidget {
  final bool canReturnToDirection;
  final ValueChanged<String> onNavigate;

  const _AccountsSidePanel({
    required this.canReturnToDirection,
    required this.onNavigate,
  });

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
                'Mayoreo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              if (canReturnToDirection) ...[
                _AccountsNavItem(
                  icon: Icons.arrow_back_rounded,
                  title: 'Volver a Dirección',
                  onTapSync: () => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 10),
              ],
              const _AccountsSectionHeader(label: 'MENU'),
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
                    _AccountsNavItem(
                      icon: Icons.point_of_sale_rounded,
                      title: 'Ventas',
                      subtitle: 'Reporte comercial base',
                      onTapSync: () => onNavigate('Ventas Mayoreo'),
                    ),
                    const SizedBox(height: 8),
                    const _AccountsNavItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Cuentas',
                      subtitle: 'Seguimiento financiero',
                      accented: true,
                    ),
                    const SizedBox(height: 8),
                    _AccountsNavItem(
                      icon: Icons.currency_exchange_rounded,
                      title: 'Cuenta El Palomar',
                      subtitle: 'Cuenta corriente especial',
                      onTapSync: () => onNavigate('Cuenta El Palomar'),
                    ),
                    const SizedBox(height: 8),
                    _AccountsNavItem(
                      icon: Icons.price_check_rounded,
                      title: 'Catálogo',
                      subtitle: 'Clientes, materiales y precios',
                      onTapSync: () => onNavigate('Catálogo'),
                    ),
                    const SizedBox(height: 8),
                    _AccountsNavItem(
                      icon: Icons.request_quote_rounded,
                      title: 'Ajuste de precios',
                      subtitle: 'Vigentes e historial',
                      onTapSync: () => onNavigate('Ajuste de precios'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _AccountsSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              if (canReturnToDirection) ...[
                _AccountsNavItem(
                  icon: Icons.assessment_outlined,
                  title: 'Dashboard Dirección',
                  subtitle: 'Vista ejecutiva multiarea',
                  onTapSync: () => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 8),
              ],
              _AccountsNavItem(
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

class _AccountsSectionHeader extends StatelessWidget {
  final String label;

  const _AccountsSectionHeader({required this.label});

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

class _AccountsNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool accented;
  final VoidCallback? onTapSync;

  const _AccountsNavItem({
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

class _AccountsBackground extends StatelessWidget {
  const _AccountsBackground();

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

class _FilterOption {
  final String id;
  final String label;

  const _FilterOption({required this.id, required this.label});

  @override
  bool operator ==(Object other) =>
      other is _FilterOption && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

class _MayoreoSourceReportRow {
  final String id;
  final String ticket;
  final DateTime saleDate;
  final String clientId;
  final String clientName;
  final String remision;
  final String materialName;
  final double approvedWeight;
  final double approvedPrice;
  final double approvedAmount;
  final _MayoreoAccountsOperationType operationType;
  final String observations;

  const _MayoreoSourceReportRow({
    required this.id,
    required this.ticket,
    required this.saleDate,
    required this.clientId,
    required this.clientName,
    required this.remision,
    required this.materialName,
    required this.approvedWeight,
    required this.approvedPrice,
    required this.approvedAmount,
    required this.operationType,
    required this.observations,
  });

  bool get isRelated => approvedWeight > 0 && approvedPrice > 0;

  factory _MayoreoSourceReportRow.fromSupabase(Map<String, dynamic> json) {
    return _MayoreoSourceReportRow(
      id: (json['id'] as String?) ?? '',
      ticket: (json['ticket'] as String?) ?? '',
      saleDate:
          DateTime.tryParse((json['sale_date'] as String?) ?? '') ??
          DateTime.now(),
      clientId: (json['client_id'] as String?) ?? '',
      clientName: (json['client_name_snapshot'] as String?) ?? '',
      remision: (json['remision'] as String?) ?? '',
      materialName: (json['material_name_snapshot'] as String?) ?? '',
      approvedWeight: ((json['approved_weight'] as num?) ?? 0).toDouble(),
      approvedPrice: ((json['approved_price'] as num?) ?? 0).toDouble(),
      approvedAmount: ((json['approved_amount'] as num?) ?? 0).toDouble(),
      operationType:
          ((json['operation_type'] as String?) ?? 'factura') == 'cheque'
          ? _MayoreoAccountsOperationType.cheque
          : _MayoreoAccountsOperationType.factura,
      observations: (json['observations'] as String?) ?? '',
    );
  }
}

class _MayoreoAccountRow {
  final String id;
  final String ticket;
  final DateTime saleDate;
  final String clientId;
  final String clientName;
  final String remision;
  final String materialName;
  final double approvedWeight;
  final double approvedPrice;
  final double approvedAmount;
  final _MayoreoAccountsOperationType operationType;
  final String saleNotes;
  final String documentNumber;
  final DateTime? documentDate;
  final DateTime? estimatedPaymentDate;
  final DateTime? settlementDate;
  final _MayoreoAccountsStatus status;
  final String financialNotes;
  final double paidAmount;

  const _MayoreoAccountRow({
    required this.id,
    required this.ticket,
    required this.saleDate,
    required this.clientId,
    required this.clientName,
    required this.remision,
    required this.materialName,
    required this.approvedWeight,
    required this.approvedPrice,
    required this.approvedAmount,
    required this.operationType,
    required this.saleNotes,
    required this.documentNumber,
    required this.documentDate,
    required this.estimatedPaymentDate,
    required this.settlementDate,
    required this.status,
    required this.financialNotes,
    required this.paidAmount,
  });

  factory _MayoreoAccountRow.fromSource(_MayoreoSourceReportRow source) {
    return _MayoreoAccountRow(
      id: source.id,
      ticket: source.ticket,
      saleDate: source.saleDate,
      clientId: source.clientId,
      clientName: source.clientName,
      remision: source.remision,
      materialName: source.materialName,
      approvedWeight: source.approvedWeight,
      approvedPrice: source.approvedPrice,
      approvedAmount: source.approvedAmount,
      operationType: source.operationType,
      saleNotes: source.observations,
      documentNumber: '',
      documentDate: null,
      estimatedPaymentDate: null,
      settlementDate: null,
      status: source.operationType == _MayoreoAccountsOperationType.factura
          ? _MayoreoAccountsStatus.pendienteFactura
          : _MayoreoAccountsStatus.pendienteCheque,
      financialNotes: '',
      paidAmount: 0,
    );
  }

  factory _MayoreoAccountRow.fromSupabase(Map<String, dynamic> json) {
    return _MayoreoAccountRow(
      id: (json['id'] as String?) ?? '',
      ticket: (json['ticket'] as String?) ?? '',
      saleDate:
          DateTime.tryParse((json['sale_date'] as String?) ?? '') ??
          DateTime.now(),
      clientId: (json['client_id'] as String?) ?? '',
      clientName: (json['client_name_snapshot'] as String?) ?? '',
      remision: (json['remision'] as String?) ?? '',
      materialName: (json['material_name_snapshot'] as String?) ?? '',
      approvedWeight: ((json['approved_weight'] as num?) ?? 0).toDouble(),
      approvedPrice: ((json['approved_price'] as num?) ?? 0).toDouble(),
      approvedAmount: ((json['approved_amount'] as num?) ?? 0).toDouble(),
      operationType:
          ((json['operation_type'] as String?) ?? 'factura') == 'cheque'
          ? _MayoreoAccountsOperationType.cheque
          : _MayoreoAccountsOperationType.factura,
      saleNotes: (json['sale_notes'] as String?) ?? '',
      documentNumber: (json['document_number'] as String?) ?? '',
      documentDate: _tryParseDate(json['document_date'] as String?),
      estimatedPaymentDate: _tryParseDate(
        json['estimated_payment_date'] as String?,
      ),
      settlementDate: _tryParseDate(json['settlement_date'] as String?),
      status: _MayoreoAccountsStatus.values.firstWhere(
        (item) => item.name == ((json['status'] as String?) ?? ''),
        orElse: () => _MayoreoAccountsStatus.porRevisar,
      ),
      financialNotes: (json['financial_notes'] as String?) ?? '',
      paidAmount: ((json['paid_amount'] as num?) ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'ticket': ticket,
      'saleDate': saleDate.toIso8601String(),
      'clientId': clientId,
      'clientName': clientName,
      'remision': remision,
      'materialName': materialName,
      'approvedWeight': approvedWeight,
      'approvedPrice': approvedPrice,
      'approvedAmount': approvedAmount,
      'operationType': operationType.name,
      'saleNotes': saleNotes,
      'documentNumber': documentNumber,
      'documentDate': documentDate?.toIso8601String(),
      'estimatedPaymentDate': estimatedPaymentDate?.toIso8601String(),
      'settlementDate': settlementDate?.toIso8601String(),
      'status': status.name,
      'financialNotes': financialNotes,
      'paidAmount': paidAmount,
    };
  }

  Map<String, dynamic> toSupabase() {
    return <String, dynamic>{
      'id': id,
      'ticket': ticket,
      'sale_date': saleDate.toIso8601String(),
      'client_id': clientId,
      'client_name_snapshot': clientName,
      'remision': remision,
      'material_name_snapshot': materialName,
      'approved_weight': approvedWeight,
      'approved_price': approvedPrice,
      'approved_amount': approvedAmount,
      'operation_type': operationType.name,
      'sale_notes': saleNotes.isEmpty ? null : saleNotes,
      'document_number': documentNumber,
      'document_date': documentDate?.toIso8601String(),
      'estimated_payment_date': estimatedPaymentDate?.toIso8601String(),
      'settlement_date': settlementDate?.toIso8601String(),
      'status': status.name,
      'financial_notes': financialNotes.isEmpty ? null : financialNotes,
      'paid_amount': paidAmount,
    };
  }

  double get pendingBalance => approvedAmount - paidAmount;

  bool get isFinanciallyOpen =>
      status != _MayoreoAccountsStatus.pagada &&
      status != _MayoreoAccountsStatus.chequeCanjeado &&
      status != _MayoreoAccountsStatus.cancelada;

  bool get hasEstimatedPaymentReminder {
    if (!isFinanciallyOpen || estimatedPaymentDate == null) return false;
    final today = DateUtils.dateOnly(DateTime.now());
    return !DateUtils.dateOnly(estimatedPaymentDate!).isAfter(today);
  }

  _MayoreoAccountRow syncOperational(_MayoreoSourceReportRow source) {
    return copyWith(
      ticket: source.ticket,
      saleDate: source.saleDate,
      clientId: source.clientId,
      clientName: source.clientName,
      remision: source.remision,
      materialName: source.materialName,
      approvedWeight: source.approvedWeight,
      approvedPrice: source.approvedPrice,
      approvedAmount: source.approvedAmount,
      operationType: source.operationType,
      saleNotes: source.observations,
    );
  }

  _MayoreoAccountRow copyWith({
    String? ticket,
    DateTime? saleDate,
    String? clientId,
    String? clientName,
    String? remision,
    String? materialName,
    double? approvedWeight,
    double? approvedPrice,
    double? approvedAmount,
    _MayoreoAccountsOperationType? operationType,
    String? saleNotes,
    String? documentNumber,
    DateTime? documentDate,
    DateTime? estimatedPaymentDate,
    DateTime? settlementDate,
    _MayoreoAccountsStatus? status,
    String? financialNotes,
    double? paidAmount,
  }) {
    return _MayoreoAccountRow(
      id: id,
      ticket: ticket ?? this.ticket,
      saleDate: saleDate ?? this.saleDate,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      remision: remision ?? this.remision,
      materialName: materialName ?? this.materialName,
      approvedWeight: approvedWeight ?? this.approvedWeight,
      approvedPrice: approvedPrice ?? this.approvedPrice,
      approvedAmount: approvedAmount ?? this.approvedAmount,
      operationType: operationType ?? this.operationType,
      saleNotes: saleNotes ?? this.saleNotes,
      documentNumber: documentNumber ?? this.documentNumber,
      documentDate: documentDate ?? this.documentDate,
      estimatedPaymentDate: estimatedPaymentDate ?? this.estimatedPaymentDate,
      settlementDate: settlementDate ?? this.settlementDate,
      status: status ?? this.status,
      financialNotes: financialNotes ?? this.financialNotes,
      paidAmount: paidAmount ?? this.paidAmount,
    );
  }
}

ThemeData _mayoreoMaterialTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: mayoreoAreaTokens.primaryStrong,
      onPrimary: Colors.white,
      secondary: mayoreoAreaTokens.primary,
      onSecondary: kMayoreoInk,
      surface: mayoreoAreaTokens.surfaceTint,
      onSurface: kMayoreoInk,
      outline: mayoreoAreaTokens.border,
    ),
    scaffoldBackgroundColor: Colors.transparent,
    iconTheme: IconThemeData(color: mayoreoAreaTokens.primaryStrong),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: mayoreoAreaTokens.primaryStrong,
      selectionColor: mayoreoAreaTokens.primary.withValues(alpha: 0.24),
      selectionHandleColor: mayoreoAreaTokens.primaryStrong,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      hintStyle: TextStyle(
        color: mayoreoAreaTokens.badgeText.withValues(alpha: 0.65),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: mayoreoAreaTokens.surfaceTint.withValues(alpha: 0.98),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: mayoreoAreaTokens.primarySoft.withValues(alpha: 0.72),
        ),
      ),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        color: kMayoreoInk,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: mayoreoAreaTokens.primaryStrong,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );
}

ButtonStyle _mayoreoPrimaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: mayoreoAreaTokens.primaryStrong,
    foregroundColor: Colors.white,
    disabledBackgroundColor: mayoreoAreaTokens.primaryStrong.withValues(
      alpha: 0.34,
    ),
    disabledForegroundColor: Colors.white.withValues(alpha: 0.78),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

ButtonStyle _mayoreoSecondaryButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: mayoreoAreaTokens.primaryStrong,
    backgroundColor: Colors.white.withValues(alpha: 0.74),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    side: BorderSide(color: mayoreoAreaTokens.border.withValues(alpha: 0.92)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

ButtonStyle _mayoreoToolbarSecondaryActionStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: mayoreoAreaTokens.primaryStrong,
    backgroundColor: Colors.white.withValues(alpha: 0.42),
    side: BorderSide(color: mayoreoAreaTokens.border.withValues(alpha: 0.8)),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

class _MayoreoDateFilterResult {
  final DateTimeRange? range;
  final bool clear;

  const _MayoreoDateFilterResult({this.range, this.clear = false});
}

Future<Set<String>?> _showMayoreoValueFilterDialog(
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
                              style: _mayoreoSecondaryButtonStyle(),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: _mayoreoPrimaryButtonStyle(),
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

Future<_MayoreoDateFilterResult?> _showMayoreoDateRangeFilterDialog(
  BuildContext context, {
  required String label,
  required DateTimeRange bounds,
  DateTimeRange? initialRange,
}) {
  return showDialog<_MayoreoDateFilterResult>(
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

            _MayoreoDateFilterResult? buildResult() {
              if (start == null) return null;
              final s = dateOnly(start!);
              final e = dateOnly(end ?? start!);
              final from = s.isBefore(e) ? s : e;
              final to = s.isBefore(e) ? e : s;
              return _MayoreoDateFilterResult(
                range: DateTimeRange(start: from, end: to),
              );
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
                              '${_monthNameEs(monthFirst.month)} ${monthFirst.year}',
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
                          : '${_fmtDate(start!)} - ${_fmtDate(end!)}',
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
                          style: _mayoreoSecondaryButtonStyle(),
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: _mayoreoSecondaryButtonStyle(),
                          onPressed: () => Navigator.pop(
                            dialogContext,
                            const _MayoreoDateFilterResult(clear: true),
                          ),
                          child: const Text('Limpiar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: _mayoreoPrimaryButtonStyle(),
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

Future<DateTime?> _pickMayoreoDate(BuildContext context, DateTime? current) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: current ?? now,
    firstDate: DateTime(2024),
    lastDate: DateTime(2030),
    builder: (dialogContext, child) {
      return Theme(
        data: _mayoreoMaterialTheme(dialogContext),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}

String _fmtDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}

String _monthNameEs(int month) {
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

Future<bool> _showFinancialExceptionConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Theme(
      data: _mayoreoMaterialTheme(dialogContext),
      child: AlertDialog(
        title: const Text('Confirmar excepción'),
        content: const Text(
          'Se intentó cerrar financieramente la cuenta sin documento asignado. ¿Deseas guardar así de todos modos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: _mayoreoPrimaryButtonStyle(),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Guardar excepción'),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

_MayoreoAccountsStatus _normalizeFinancialStatus({
  required _MayoreoAccountsStatus baseStatus,
  required _MayoreoAccountsOperationType operationType,
  required String documentNumber,
  required DateTime? documentDate,
  required DateTime? settlementDate,
  required double paidAmount,
  required double approvedAmount,
}) {
  if (baseStatus == _MayoreoAccountsStatus.cancelada ||
      baseStatus == _MayoreoAccountsStatus.porRevisar) {
    return baseStatus;
  }
  if (operationType == _MayoreoAccountsOperationType.factura) {
    if (documentNumber.isEmpty || documentDate == null) {
      return _MayoreoAccountsStatus.pendienteFactura;
    }
    if (paidAmount <= 0) return _MayoreoAccountsStatus.facturadaPendientePago;
    if (paidAmount < approvedAmount) return _MayoreoAccountsStatus.pagoParcial;
    return _MayoreoAccountsStatus.pagada;
  }
  if (documentNumber.isEmpty || documentDate == null) {
    return _MayoreoAccountsStatus.pendienteCheque;
  }
  if (settlementDate == null && paidAmount <= 0) {
    return _MayoreoAccountsStatus.chequeRecibido;
  }
  if (settlementDate == null) {
    return _MayoreoAccountsStatus.chequePendienteCanje;
  }
  return _MayoreoAccountsStatus.chequeCanjeado;
}

bool _isFinalFinancialStatus(_MayoreoAccountsStatus status) {
  return status == _MayoreoAccountsStatus.pagada ||
      status == _MayoreoAccountsStatus.chequeCanjeado;
}

List<_MayoreoAccountsStatus> _statusesForOperation(
  _MayoreoAccountsOperationType operationType,
) {
  switch (operationType) {
    case _MayoreoAccountsOperationType.factura:
      return const [
        _MayoreoAccountsStatus.pendienteFactura,
        _MayoreoAccountsStatus.facturadaPendientePago,
        _MayoreoAccountsStatus.pagoParcial,
        _MayoreoAccountsStatus.pagada,
        _MayoreoAccountsStatus.cancelada,
        _MayoreoAccountsStatus.porRevisar,
      ];
    case _MayoreoAccountsOperationType.cheque:
      return const [
        _MayoreoAccountsStatus.pendienteCheque,
        _MayoreoAccountsStatus.chequeRecibido,
        _MayoreoAccountsStatus.chequePendienteCanje,
        _MayoreoAccountsStatus.chequeCanjeado,
        _MayoreoAccountsStatus.cancelada,
        _MayoreoAccountsStatus.porRevisar,
      ];
  }
}

String _operationTypeLabel(_MayoreoAccountsOperationType type) {
  switch (type) {
    case _MayoreoAccountsOperationType.factura:
      return 'FACTURA';
    case _MayoreoAccountsOperationType.cheque:
      return 'CHEQUE';
  }
}

String _financialStatusLabel(_MayoreoAccountsStatus status) {
  switch (status) {
    case _MayoreoAccountsStatus.pendienteFactura:
      return 'PEND. FACTURA';
    case _MayoreoAccountsStatus.facturadaPendientePago:
      return 'FACT. PEND. PAGO';
    case _MayoreoAccountsStatus.pagada:
      return 'PAGADA';
    case _MayoreoAccountsStatus.pagoParcial:
      return 'PAGO PARCIAL';
    case _MayoreoAccountsStatus.cancelada:
      return 'CANCELADA';
    case _MayoreoAccountsStatus.porRevisar:
      return 'POR REVISAR';
    case _MayoreoAccountsStatus.pendienteCheque:
      return 'PEND. CHEQUE';
    case _MayoreoAccountsStatus.chequeRecibido:
      return 'CHEQUE RECIBIDO';
    case _MayoreoAccountsStatus.chequePendienteCanje:
      return 'PEND. CANJE';
    case _MayoreoAccountsStatus.chequeCanjeado:
      return 'CHEQUE CANJEADO';
  }
}

IconData _statusIcon(_MayoreoAccountsStatus status) {
  switch (status) {
    case _MayoreoAccountsStatus.pagada:
    case _MayoreoAccountsStatus.chequeCanjeado:
      return Icons.verified_rounded;
    case _MayoreoAccountsStatus.pagoParcial:
      return Icons.timelapse_rounded;
    case _MayoreoAccountsStatus.cancelada:
    case _MayoreoAccountsStatus.porRevisar:
      return Icons.error_outline_rounded;
    default:
      return Icons.schedule_rounded;
  }
}

(Color, Color, Color, Color) _statusColors(_MayoreoAccountsStatus status) {
  switch (status) {
    case _MayoreoAccountsStatus.pagada:
    case _MayoreoAccountsStatus.chequeCanjeado:
      return (
        const Color(0xFFEAF4E4),
        const Color(0xFFD5E8CD),
        const Color(0xFFBAD2B1),
        const Color(0xFF4B865C),
      );
    case _MayoreoAccountsStatus.pagoParcial:
      return (
        const Color(0xFFFFF2D6),
        const Color(0xFFFFE4A8),
        const Color(0xFFE9C66B),
        const Color(0xFF8A5E12),
      );
    case _MayoreoAccountsStatus.cancelada:
    case _MayoreoAccountsStatus.porRevisar:
      return (
        const Color(0xFFFFE8E2),
        const Color(0xFFFFD6C8),
        const Color(0xFFE9B6A8),
        const Color(0xFF924E3B),
      );
    default:
      return (
        const Color(0xFFFFF8DF),
        const Color(0xFFFFE97C),
        const Color(0xFFF0D15F),
        const Color(0xFF6A5200),
      );
  }
}

bool _isSeedAccountSourceId(String id) {
  return id.startsWith('rep_');
}

double? _parseDouble(String raw) {
  final normalized = raw.trim().replaceAll(',', '');
  return double.tryParse(normalized);
}

DateTime? _tryParseDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}

String _csvCell(Object? value) {
  final text = (value ?? '').toString().replaceAll('"', '""');
  return '"$text"';
}

int _effectiveCurrentPageForCount(
  int currentPage,
  int pageSize,
  int totalRows,
) {
  if (totalRows <= 0) return 0;
  final maxPage = (totalRows - 1) ~/ pageSize;
  return currentPage.clamp(0, maxPage);
}

int _totalPagesForCount(int pageSize, int totalRows) {
  if (totalRows <= 0) return 1;
  return ((totalRows - 1) ~/ pageSize) + 1;
}
