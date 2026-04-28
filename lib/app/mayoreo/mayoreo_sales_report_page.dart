import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../auth/auth_access.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/confirm_dialog_key_handler.dart';
import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/dialogs/contract_popup_surface.dart';
import '../shared/ui_contract_core/keyboard/grid_keyboard_contract.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_tokens.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/editable_hover_capsule.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import '../shared/utils/number_formatters.dart';
import 'mayoreo_accounts_page.dart';
import 'mayoreo_catalog_page.dart';
import 'mayoreo_data_store.dart';
import 'mayoreo_dashboard_preview_page.dart';
import 'mayoreo_el_palomar_page.dart';
import 'mayoreo_price_adjustments_page.dart';
import 'mayoreo_theme.dart';

const double _kReportDateW = 118;
const double _kReportTicketW = 112;
const double _kReportClientW = 228;
const double _kReportRemisionW = 120;
const double _kReportMaterialW = 212;
const double _kReportExitWeightW = 118;
const double _kReportPriceW = 118;
const double _kReportApprovedWeightW = 128;
const double _kReportApprovedPriceW = 128;
const double _kReportTypeW = 108;
const double _kReportNotesW = 230;
const double _kReportActionsW = 154;
const double _kSalesGridBodyMinHeight = 430;
const double _kVoucherFieldMinHeight = 84;
const double _kVoucherInteractiveMinHeight = 24;
const String _kMayoreoSalesReportsTable = 'mayoreo_sales_reports';

enum _MayoreoReportOperationType { factura, cheque }

enum _SalesReportMenuAction { edit, relate, delete }

class MayoreoSalesReportPage extends StatefulWidget {
  final bool instantOpen;

  const MayoreoSalesReportPage({super.key, this.instantOpen = false});

  @override
  State<MayoreoSalesReportPage> createState() => _MayoreoSalesReportPageState();
}

class _MayoreoSalesReportPageState extends State<MayoreoSalesReportPage> {
  final SupabaseClient _supa = Supabase.instance.client;
  Future<void> _persistRowsQueue = Future<void>.value();
  bool _menuOpen = false;
  bool _canReturnToDirection = false;
  bool _dragSelectingRows = false;
  bool _pointerDownAdditiveSelection = false;
  bool _suppressNextRowTap = false;
  String? _selectedRowId;
  final Set<String> _selectedRowIds = <String>{};
  final Set<String> _ticketFilters = <String>{};
  final Set<String> _remisionFilters = <String>{};
  DateTime? _dateFilterFrom;
  DateTime? _dateFilterTo;
  final Set<String> _clientFilterIds = <String>{};
  final Set<String> _materialFilterIds = <String>{};
  final Set<String> _operationFilters = <String>{};
  final Set<String> _statusFilters = <String>{};
  int _currentPage = 0;
  int _pageSize = 40;
  String? _selectionAnchorRowId;
  bool _exportingCsv = false;
  final ScrollController _bodyScrollController = ScrollController();
  final GlobalKey _rowsViewportKey = GlobalKey(
    debugLabel: 'mayoreo_sales_rows_viewport',
  );
  final Map<String, GlobalKey> _rowItemKeys = <String, GlobalKey>{};
  Offset? _dragPointerGlobal;
  double _dragAutoScrollVelocity = 0;
  Timer? _dragAutoScrollTimer;

  List<_MayoreoSalesClient> _clients = const <_MayoreoSalesClient>[];
  List<_MayoreoSalesMaterial> _materials = const <_MayoreoSalesMaterial>[];
  List<_MayoreoSalesCatalogPrice> _prices = const <_MayoreoSalesCatalogPrice>[];
  late List<_MayoreoSalesReportRow> _rows;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    final savedState = _MayoreoSalesReportPageMemory.current;
    if (savedState != null) {
      _rows = savedState.rows
          .map((row) => row.copyWith())
          .where((row) => !_isSeedReportRow(row))
          .toList(growable: false);
      _selectedRowId = savedState.selectedRowId;
      _clientFilterIds.addAll(savedState.clientFilterIds);
      _materialFilterIds.addAll(savedState.materialFilterIds);
      _operationFilters.addAll(savedState.operationFilters);
      _statusFilters.addAll(savedState.statusFilters);
      _ticketFilters.addAll(savedState.ticketFilters);
      _remisionFilters.addAll(savedState.remisionFilters);
      _dateFilterFrom = savedState.dateFilterFrom;
      _dateFilterTo = savedState.dateFilterTo;
      _selectedRowIds
        ..clear()
        ..addAll(savedState.selectedRowIds);
      _currentPage = savedState.currentPage;
      _pageSize = savedState.pageSize;
      _selectionAnchorRowId = savedState.selectionAnchorRowId;
    } else {
      _rows = const <_MayoreoSalesReportRow>[];
      if (_rows.isNotEmpty) {
        _selectedRowId = _rows.first.id;
        _selectedRowIds.add(_rows.first.id);
        _selectionAnchorRowId = _rows.first.id;
      }
      _persistState();
    }
    unawaited(_loadCatalogData());
    unawaited(_loadRemoteRows());
  }

  @override
  void dispose() {
    _dragAutoScrollTimer?.cancel();
    _bodyScrollController.dispose();
    _persistState();
    super.dispose();
  }

  Future<void> _loadCatalogData() async {
    final snapshot = await MayoreoDataStore.loadCatalogSnapshot();
    final clients = snapshot.companies
        .where((row) => row.active && row.name.trim().isNotEmpty)
        .map((row) => _MayoreoSalesClient(id: row.id, name: row.name))
        .toList(growable: false);
    final materials = snapshot.materials
        .where(
          (row) =>
              row.active &&
              row.level == 'COMERCIAL' &&
              row.name.trim().isNotEmpty,
        )
        .map((row) => _MayoreoSalesMaterial(id: row.id, name: row.name))
        .toList(growable: false);
    final prices = snapshot.prices
        .where((row) => row.active)
        .map(
          (row) => _MayoreoSalesCatalogPrice(
            clientId: row.companyId,
            materialId: row.materialId,
            finalPrice: row.amount,
          ),
        )
        .toList(growable: false);
    if (!mounted) return;
    setState(() {
      _clients = clients;
      _materials = materials;
      _prices = prices;
    });
  }

  void _persistState() {
    _MayoreoSalesReportPageMemory.current = _MayoreoSalesReportPageMemory(
      rows: _rows.map((row) => row.copyWith()).toList(growable: false),
      selectedRowId: _selectedRowId,
      clientFilterIds: _clientFilterIds.toList(growable: false),
      materialFilterIds: _materialFilterIds.toList(growable: false),
      operationFilters: _operationFilters.toList(growable: false),
      statusFilters: _statusFilters.toList(growable: false),
      ticketFilters: _ticketFilters.toList(growable: false),
      remisionFilters: _remisionFilters.toList(growable: false),
      dateFilterFrom: _dateFilterFrom,
      dateFilterTo: _dateFilterTo,
      selectedRowIds: _selectedRowIds.toList(growable: false),
      currentPage: _currentPage,
      pageSize: _pageSize,
      selectionAnchorRowId: _selectionAnchorRowId,
    );
  }

  Future<void> _loadRemoteRows() async {
    try {
      final response = await _supa
          .from(_kMayoreoSalesReportsTable)
          .select()
          .order('sale_date', ascending: false)
          .order('created_at', ascending: false);
      final remoteRows = (response as List)
          .map(
            (row) => _MayoreoSalesReportRow.fromSupabase(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _rows = remoteRows;
        if (_rows.isNotEmpty &&
            (_selectedRowId == null ||
                !_rows.any((row) => row.id == _selectedRowId))) {
          _selectedRowId = _rows.first.id;
        }
        if (_selectedRowId != null && _selectedRowIds.isEmpty) {
          _selectedRowIds.add(_selectedRowId!);
        }
        if (_rows.isEmpty) {
          _selectedRowId = null;
          _selectedRowIds.clear();
          _selectionAnchorRowId = null;
        }
      });
      _persistState();
    } on PostgrestException catch (e) {
      _toast('No se pudo cargar ventas Mayoreo desde Supabase: ${e.message}');
    } catch (_) {}
  }

  Future<void> _persistRowsToSupabase(List<_MayoreoSalesReportRow> rows) async {
    try {
      if (rows.isNotEmpty) {
        await _supa
            .from(_kMayoreoSalesReportsTable)
            .upsert(
              rows.map((row) => row.toSupabase()).toList(growable: false),
              onConflict: 'id',
            );
      }
      final existingIdsResponse = await _supa
          .from(_kMayoreoSalesReportsTable)
          .select('id');
      final existingIds = (existingIdsResponse as List)
          .map((row) => (row as Map)['id'].toString())
          .toSet();
      final nextIds = rows.map((row) => row.id).toSet();
      final deletedIds = existingIds
          .difference(nextIds)
          .toList(growable: false);
      if (deletedIds.isNotEmpty) {
        await _supa
            .from(_kMayoreoSalesReportsTable)
            .delete()
            .inFilter('id', deletedIds);
      }
    } on PostgrestException catch (e) {
      _toast('No se pudo guardar Ventas Mayoreo: ${e.message}');
      await _loadRemoteRows();
    } catch (_) {
      _toast(
        'No se pudo guardar Ventas Mayoreo. Se restauró el estado remoto.',
      );
      await _loadRemoteRows();
    }
  }

  void _persistRows() {
    final snapshot = _rows.map((row) => row.copyWith()).toList(growable: false);
    _persistRowsQueue = _persistRowsQueue
        .catchError((_) {})
        .then((_) => _persistRowsToSupabase(snapshot));
    unawaited(_persistRowsQueue);
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

  Future<void> _openAccounts() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const MayoreoAccountsPage(instantOpen: true)));
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
        unawaited(_openDashboard());
        return;
      case 'Ventas Mayoreo':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      case 'Cuentas':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openAccounts());
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

  _MayoreoSalesReportRow? get _selectedRow {
    for (final row in _rows) {
      if (row.id == _selectedRowId) return row;
    }
    return null;
  }

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

  int _selectedFilteredIndex(List<_MayoreoSalesReportRow> filteredRows) {
    if (_selectedRowId == null) return filteredRows.isEmpty ? -1 : 0;
    return filteredRows.indexWhere((row) => row.id == _selectedRowId);
  }

  void _selectFilteredIndex(
    List<_MayoreoSalesReportRow> filteredRows,
    int nextIndex,
  ) {
    if (filteredRows.isEmpty) return;
    final safeIndex = nextIndex.clamp(0, filteredRows.length - 1);
    final nextRowId = filteredRows[safeIndex].id;
    setState(() {
      _selectedRowId = nextRowId;
      _selectedRowIds
        ..clear()
        ..add(_selectedRowId!);
      _selectionAnchorRowId = _selectedRowId;
    });
    _persistState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureRowVisible(nextRowId);
    });
  }

  void _handleRowTap(
    _MayoreoSalesReportRow row,
    List<_MayoreoSalesReportRow> filteredRows,
  ) {
    if (_suppressNextRowTap || _pointerDownAdditiveSelection) {
      setState(() {
        _suppressNextRowTap = false;
        _pointerDownAdditiveSelection = false;
      });
      return;
    }
    final currentIndex = filteredRows.indexWhere((item) => item.id == row.id);
    final anchorIndex = _selectionAnchorRowId == null
        ? -1
        : filteredRows.indexWhere((item) => item.id == _selectionAnchorRowId);
    setState(() {
      _selectedRowId = row.id;
      if (_isShiftPressed() && anchorIndex >= 0 && currentIndex >= 0) {
        final from = anchorIndex < currentIndex ? anchorIndex : currentIndex;
        final to = anchorIndex < currentIndex ? currentIndex : anchorIndex;
        _selectedRowIds
          ..clear()
          ..addAll(
            filteredRows
                .sublist(from, to + 1)
                .map((item) => item.id)
                .toList(growable: false),
          );
      } else if (_isShortcutModifierPressed()) {
        if (_selectedRowIds.contains(row.id)) {
          _selectedRowIds.remove(row.id);
          if (_selectedRowIds.isEmpty) {
            _selectedRowIds.add(row.id);
          }
        } else {
          _selectedRowIds.add(row.id);
        }
        _selectionAnchorRowId = row.id;
      } else if (_selectedRowIds.length > 1 &&
          _selectedRowIds.contains(row.id)) {
        _selectedRowId = row.id;
      } else {
        _selectedRowIds
          ..clear()
          ..add(row.id);
        _selectionAnchorRowId = row.id;
      }
    });
    _persistState();
    _persistRows();
  }

  void _selectSingleRow(_MayoreoSalesReportRow row) {
    _selectedRowId = row.id;
    _selectedRowIds
      ..clear()
      ..add(row.id);
    _selectionAnchorRowId = row.id;
    _dragSelectingRows = false;
  }

  void _extendSelectionToRow(
    _MayoreoSalesReportRow row,
    List<_MayoreoSalesReportRow> filteredRows,
  ) {
    final currentIndex = filteredRows.indexWhere((item) => item.id == row.id);
    final anchorIndex = _selectionAnchorRowId == null
        ? -1
        : filteredRows.indexWhere((item) => item.id == _selectionAnchorRowId);
    if (currentIndex < 0 || anchorIndex < 0) {
      _selectSingleRow(row);
      return;
    }
    final from = anchorIndex < currentIndex ? anchorIndex : currentIndex;
    final to = anchorIndex < currentIndex ? currentIndex : anchorIndex;
    _selectedRowId = row.id;
    _selectedRowIds
      ..clear()
      ..addAll(
        filteredRows
            .sublist(from, to + 1)
            .map((item) => item.id)
            .toList(growable: false),
      );
    _dragSelectingRows = true;
  }

  void _handleRowPrimaryPointerDown(
    _MayoreoSalesReportRow row,
    List<_MayoreoSalesReportRow> filteredRows,
  ) {
    setState(() {
      _pointerDownAdditiveSelection =
          _isShortcutModifierPressed() || _isShiftPressed();
      if (_isShiftPressed()) {
        _extendSelectionToRow(row, filteredRows);
        _suppressNextRowTap = true;
      } else if (_isShortcutModifierPressed()) {
        _selectedRowId = row.id;
        if (_selectedRowIds.contains(row.id)) {
          _selectedRowIds.remove(row.id);
          if (_selectedRowIds.isEmpty) {
            _selectedRowIds.add(row.id);
          }
        } else {
          _selectedRowIds.add(row.id);
        }
        _selectionAnchorRowId = row.id;
        _suppressNextRowTap = true;
      } else {
        _selectSingleRow(row);
        _dragSelectingRows = true;
        _suppressNextRowTap = false;
      }
    });
    _updateDragAutoScroll(filteredRows);
    _persistState();
  }

  int? _visibleRowPositionAtGlobalPosition(
    Offset globalPosition,
    List<_MayoreoSalesReportRow> rows,
  ) {
    for (var index = 0; index < rows.length; index++) {
      final box =
          _rowItemKeys[rows[index].id]?.currentContext?.findRenderObject()
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

  void _handleRowsPointerDown(
    PointerDownEvent event,
    List<_MayoreoSalesReportRow> filteredRows,
  ) {
    _pointerDownAdditiveSelection =
        _isShortcutModifierPressed() || _isShiftPressed();
    if (event.kind != PointerDeviceKind.mouse ||
        (event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }
    final visibleIndex = _visibleRowPositionAtGlobalPosition(
      event.position,
      filteredRows,
    );
    if (visibleIndex == null) return;
    _dragPointerGlobal = event.position;
    _handleRowPrimaryPointerDown(filteredRows[visibleIndex], filteredRows);
    _updateDragAutoScroll(filteredRows);
  }

  void _handleRowDragEnter(
    _MayoreoSalesReportRow row,
    List<_MayoreoSalesReportRow> filteredRows,
  ) {
    if (!_dragSelectingRows) return;
    setState(() => _extendSelectionToRow(row, filteredRows));
    _updateDragAutoScroll(filteredRows);
    _persistState();
  }

  void _handleRowsPointerMove(
    PointerMoveEvent event,
    List<_MayoreoSalesReportRow> filteredRows,
  ) {
    if (!_dragSelectingRows) return;
    _dragPointerGlobal = event.position;
    _updateDragAutoScroll(filteredRows);
    final visibleIndex = _visibleRowPositionAtGlobalPosition(
      event.position,
      filteredRows,
    );
    if (visibleIndex == null) return;
    setState(
      () => _extendSelectionToRow(filteredRows[visibleIndex], filteredRows),
    );
  }

  void _handleRowPointerEnd() {
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
      _selectedRowId = null;
      _selectedRowIds.clear();
      _selectionAnchorRowId = null;
      _dragSelectingRows = false;
      _pointerDownAdditiveSelection = false;
      _suppressNextRowTap = false;
      _dragPointerGlobal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
    });
    _persistState();
    _persistRows();
  }

  Future<void> _showContextMenuForRow(
    _MayoreoSalesReportRow row,
    Offset globalPosition,
  ) async {
    final rowWasAlreadySelected = _selectedRowIds.contains(row.id);
    setState(() {
      _selectedRowId = row.id;
      if (!rowWasAlreadySelected) {
        _selectedRowIds
          ..clear()
          ..add(row.id);
        _selectionAnchorRowId = row.id;
      }
    });
    _persistState();
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final selectedCount = _selectedRowIds.length;
    final action = await showMenu<_SalesReportMenuAction>(
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
        PopupMenuItem(
          value: _SalesReportMenuAction.edit,
          child: Text(
            selectedCount > 1 ? 'Editar actual' : 'Editar',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: kMayoreoInk,
            ),
          ),
        ),
        PopupMenuItem(
          value: _SalesReportMenuAction.relate,
          child: Text(
            selectedCount > 1
                ? (row.isRelated
                      ? 'Ajustar relación actual'
                      : 'Relacionar actual')
                : (row.isRelated ? 'Ajustar relación' : 'Relacionar'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: kMayoreoInk,
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: _SalesReportMenuAction.delete,
          child: Text(
            selectedCount > 1
                ? 'Eliminar selección ($selectedCount)'
                : 'Eliminar',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: kMayoreoInk,
            ),
          ),
        ),
      ],
    );
    if (action != null) {
      await _handleRowMenuAction(row, action);
    }
  }

  List<_MayoreoSalesReportRow> get _filteredRows {
    return _rows
        .where((row) {
          final rowDate = DateUtils.dateOnly(row.date);
          if (_dateFilterFrom != null &&
              rowDate.isBefore(DateUtils.dateOnly(_dateFilterFrom!))) {
            return false;
          }
          if (_dateFilterTo != null &&
              rowDate.isAfter(DateUtils.dateOnly(_dateFilterTo!))) {
            return false;
          }
          if (_ticketFilters.isNotEmpty &&
              !_ticketFilters.contains(row.ticket)) {
            return false;
          }
          if (_remisionFilters.isNotEmpty &&
              !_remisionFilters.contains(row.remision)) {
            return false;
          }
          if (_clientFilterIds.isNotEmpty &&
              !_clientFilterIds.contains(row.clientId)) {
            return false;
          }
          if (_materialFilterIds.isNotEmpty &&
              !_materialFilterIds.contains(row.materialId)) {
            return false;
          }
          if (_operationFilters.isNotEmpty &&
              !_operationFilters.contains(row.operationType.name)) {
            return false;
          }
          final rowStatus = row.isRelated ? 'related' : 'pending';
          if (_statusFilters.isNotEmpty &&
              !_statusFilters.contains(rowStatus)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  int _effectiveCurrentPageFor(int totalRows) =>
      _effectiveCurrentPageForCount(_currentPage, _pageSize, totalRows);

  int _totalPagesFor(int totalRows) =>
      _totalPagesForCount(_pageSize, totalRows);

  List<_MayoreoSalesReportRow> _pageRows(List<_MayoreoSalesReportRow> rows) {
    if (rows.isEmpty) return const <_MayoreoSalesReportRow>[];
    final currentPage = _effectiveCurrentPageFor(rows.length);
    final start = currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  GlobalKey _rowItemKey(String rowId) {
    return _rowItemKeys.putIfAbsent(
      rowId,
      () => GlobalKey(debugLabel: 'sales_row_$rowId'),
    );
  }

  void _ensureRowVisible(String rowId) {
    final context = _rowItemKey(rowId).currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _updateDragAutoScroll(List<_MayoreoSalesReportRow> pageRows) {
    if (!_dragSelectingRows || _dragPointerGlobal == null) {
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
      (_) => _tickDragAutoScroll(pageRows),
    );
  }

  void _tickDragAutoScroll(List<_MayoreoSalesReportRow> pageRows) {
    if (!_dragSelectingRows ||
        _dragAutoScrollVelocity == 0 ||
        !_bodyScrollController.hasClients) {
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
    if (pointer == null) return;
    final viewportBox =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox != null && viewportBox.hasSize && pageRows.isNotEmpty) {
      final local = viewportBox.globalToLocal(pointer);
      if (local.dy <= 0) {
        setState(() => _extendSelectionToRow(pageRows.first, pageRows));
        _persistState();
        return;
      }
      if (local.dy >= viewportBox.size.height) {
        setState(() => _extendSelectionToRow(pageRows.last, pageRows));
        _persistState();
        return;
      }
    }
    for (final row in pageRows) {
      final context = _rowItemKey(row.id).currentContext;
      if (context == null) continue;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(pointer)) {
        setState(() => _extendSelectionToRow(row, pageRows));
        _persistState();
        return;
      }
    }
  }

  double? _currentCatalogPrice(String clientId, String materialId) {
    for (final row in _prices) {
      if (row.clientId == clientId && row.materialId == materialId) {
        return row.finalPrice;
      }
    }
    return null;
  }

  Future<void> _printSelectedReports() async {
    final selectedRows = _rows
        .where((row) => _selectedRowIds.contains(row.id))
        .toList(growable: false);
    if (selectedRows.isEmpty) {
      _toast('Selecciona al menos un reporte para imprimir.');
      return;
    }
    final pendingRows = selectedRows.where((row) => !row.isRelated).toList();
    if (pendingRows.isNotEmpty) {
      _toast(
        pendingRows.length == 1
            ? 'El reporte seleccionado todavía no está relacionado.'
            : 'Todos los reportes seleccionados deben estar relacionados para imprimir.',
      );
      return;
    }
    try {
      final pdfBytes = await _buildSelectedReportsPdfBytes(selectedRows);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(
        '${Directory.systemTemp.path}/mayoreo_relacion_lote_$stamp.pdf',
      );
      await file.writeAsBytes(pdfBytes, flush: true);
      await _openPdfFile(file.path);
    } catch (e) {
      _toast('No se pudo abrir la relación en PDF: $e');
    }
  }

  Future<Uint8List> _buildSelectedReportsPdfBytes(
    List<_MayoreoSalesReportRow> rows,
  ) async {
    final doc = pw.Document();
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo_dicsa.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final now = DateTime.now();
    final printedAt =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final totalExitWeight = rows.fold<double>(
      0,
      (sum, row) => sum + row.exitWeight,
    );
    final totalApprovedWeight = rows.fold<double>(
      0,
      (sum, row) => sum + (row.approvedWeight ?? 0),
    );
    final totalApprovedAmount = rows.fold<double>(
      0,
      (sum, row) => sum + row.approvedAmount,
    );
    final totalApproximateAmount = rows.fold<double>(
      0,
      (sum, row) => sum + (row.exitWeight * row.priceSnapshot),
    );
    final allSameClient = rows.every(
      (row) => row.clientId == rows.first.clientId,
    );
    final clientLabel = allSameClient
        ? rows.first.clientName
        : 'CLIENTES MIXTOS';

    pw.Widget summaryCard(String label, String value) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FFF0AE'),
            borderRadius: pw.BorderRadius.circular(14),
            border: pw.Border.all(color: PdfColor.fromHex('#E1C863')),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 9.2,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#7B6515'),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 15.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#3E3311'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        build: (_) => [
          pw.Row(
            children: [
              if (logoImage != null)
                pw.SizedBox(
                  width: 42,
                  height: 28,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
              if (logoImage != null) pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'REPORTE DE RELACION',
                      style: pw.TextStyle(
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      clientLabel,
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Text(printedAt, style: const pw.TextStyle(fontSize: 9.5)),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            children: [
              summaryCard(
                'PESO APROBADO TOTAL',
                '${formatDecimal(totalApprovedWeight)} KG',
              ),
              pw.SizedBox(width: 10),
              summaryCard(
                'IMPORTE APROBADO TOTAL',
                formatMoney(totalApprovedAmount),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              summaryCard(
                'PESO SALIDA TOTAL',
                '${formatDecimal(totalExitWeight)} KG',
              ),
              pw.SizedBox(width: 10),
              summaryCard(
                'IMPORTE APROXIMADO',
                formatMoney(totalApproximateAmount),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#D9C98A')),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.0),
              1: const pw.FlexColumnWidth(1.0),
              2: const pw.FlexColumnWidth(1.65),
              3: const pw.FlexColumnWidth(1.55),
              4: const pw.FlexColumnWidth(1.0),
              5: const pw.FlexColumnWidth(1.0),
              6: const pw.FlexColumnWidth(1.15),
              7: const pw.FlexColumnWidth(1.0),
              8: const pw.FlexColumnWidth(1.05),
              9: const pw.FlexColumnWidth(1.15),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FFF0AE'),
                ),
                children:
                    [
                          'TICKET',
                          'REMISION',
                          'CLIENTE',
                          'MATERIAL',
                          'PESO SALIDA',
                          'PRECIO BASE',
                          'IMP. APROX.',
                          'PESO APROB.',
                          'PRECIO APROB.',
                          'IMPORTE',
                        ]
                        .map(
                          (label) => pw.Padding(
                            padding: const pw.EdgeInsets.all(7),
                            child: pw.Text(
                              label,
                              style: pw.TextStyle(
                                fontSize: 9.4,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
              ),
              for (final row in rows)
                pw.TableRow(
                  children:
                      [
                            row.ticket,
                            row.remision,
                            row.clientName,
                            row.materialName,
                            '${formatDecimal(row.exitWeight)} KG',
                            formatMoney(row.priceSnapshot),
                            formatMoney(row.exitWeight * row.priceSnapshot),
                            '${formatDecimal(row.approvedWeight ?? 0)} KG',
                            formatMoney(row.approvedPrice ?? 0),
                            formatMoney(row.approvedAmount),
                          ]
                          .map(
                            (value) => pw.Padding(
                              padding: const pw.EdgeInsets.all(7),
                              child: pw.Text(
                                value,
                                style: const pw.TextStyle(fontSize: 9.2),
                              ),
                            ),
                          )
                          .toList(growable: false),
                ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _openPdfFile(String path) async {
    ProcessResult result;
    if (Platform.isMacOS) {
      result = await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      result = await Process.run('cmd', ['/c', 'start', '', path]);
    } else if (Platform.isLinux) {
      result = await Process.run('xdg-open', [path]);
    } else {
      throw UnsupportedError('Plataforma no soportada para abrir PDF');
    }
    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString().trim());
    }
  }

  Future<void> _openNewReportDialog() async {
    final draft = await showDialog<_MayoreoSalesReportDraft>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _SalesReportDialog(
        clients: _clients,
        materials: _materials,
        prices: _prices,
        priceLookup: _currentCatalogPrice,
      ),
    );
    if (draft == null) return;
    final row = _MayoreoSalesReportRow(
      id: 'sale-report-${DateTime.now().microsecondsSinceEpoch}',
      ticket: draft.ticket,
      date: draft.date,
      clientId: draft.clientId,
      clientName: _clientName(draft.clientId),
      remision: draft.remision,
      materialId: draft.materialId,
      materialName: _materialName(draft.materialId),
      exitWeight: draft.exitWeight,
      priceSnapshot: draft.priceSnapshot,
      approvedWeight: draft.approvedWeight,
      approvedPrice: draft.approvedPrice,
      approvedAmount: draft.approvedAmount,
      operationType: draft.operationType,
      observations: draft.observations,
    );
    setState(() {
      _rows = [row, ..._rows];
      _selectedRowId = row.id;
      _selectedRowIds
        ..clear()
        ..add(row.id);
      _selectionAnchorRowId = row.id;
      _currentPage = 0;
    });
    _persistState();
    _persistRows();
  }

  Future<void> _openEditDialog(_MayoreoSalesReportRow row) async {
    final draft = await showDialog<_MayoreoSalesReportDraft>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _SalesReportDialog(
        initial: row,
        clients: _clients,
        materials: _materials,
        prices: _prices,
        priceLookup: _currentCatalogPrice,
      ),
    );
    if (draft == null) return;
    setState(() {
      _rows = _rows
          .map(
            (item) => item.id == row.id
                ? item.copyWith(
                    ticket: draft.ticket,
                    date: draft.date,
                    clientId: draft.clientId,
                    clientName: _clientName(draft.clientId),
                    remision: draft.remision,
                    materialId: draft.materialId,
                    materialName: _materialName(draft.materialId),
                    exitWeight: draft.exitWeight,
                    priceSnapshot: draft.priceSnapshot,
                    operationType: draft.operationType,
                    observations: draft.observations,
                  )
                : item,
          )
          .toList(growable: false);
      _selectedRowId = row.id;
      _selectedRowIds
        ..clear()
        ..add(row.id);
      _selectionAnchorRowId = row.id;
    });
    _persistState();
    _persistRows();
  }

  Future<void> _openRelateDialog(_MayoreoSalesReportRow row) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _RelationVoucherDialog(
        row: row,
        onPersist: (result) async {
          setState(() {
            _rows = _rows
                .map(
                  (item) => item.id == row.id
                      ? item.copyWith(
                          approvedWeight: result.approvedWeight,
                          approvedPrice: result.approvedPrice,
                          approvedAmount: result.approvedAmount,
                        )
                      : item,
                )
                .toList(growable: false);
            _selectedRowId = row.id;
            _selectedRowIds
              ..clear()
              ..add(row.id);
            _selectionAnchorRowId = row.id;
          });
          _persistState();
          _persistRows();
        },
      ),
    );
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
            'FECHA',
            'TICKET',
            'CLIENTE',
            'REMISION',
            'MATERIAL',
            'PESO_SALIDA',
            'PRECIO',
            'PESO_APROBADO',
            'PRECIO_APROBADO',
            'IMPORTE_APROBADO',
            'OPERACION',
            'OBSERVACIONES',
            'ESTATUS',
          ].join(','),
        );
      for (final row in rows) {
        csv.writeln(
          [
            _formatDate(row.date),
            row.ticket,
            row.clientName,
            row.remision,
            row.materialName,
            formatDecimal(row.exitWeight),
            row.priceSnapshot.toStringAsFixed(2),
            row.approvedWeight?.toStringAsFixed(2) ?? '',
            row.approvedPrice?.toStringAsFixed(2) ?? '',
            row.approvedAmount.toStringAsFixed(2),
            _operationTypeLabel(row.operationType),
            row.observations,
            row.isRelated ? 'RELACIONADO' : 'PENDIENTE',
          ].map(_csvCell).join(','),
        );
      }
      final path = await saveCsvFile(
        fileName: 'mayoreo_reporte_ventas_$stamp.csv',
        content: csv.toString(),
        dialogTitle: 'Guardar CSV de reporte de ventas',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path == null ? 'Exportación cancelada' : 'CSV exportado en: $path',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo exportar CSV: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingCsv = false);
      }
    }
  }

  void _deleteSelected() {
    if (_selectedRowIds.isEmpty) return;
    unawaited(_confirmDeleteSelection());
  }

  Future<void> _confirmDeleteSelection() async {
    final deleteCount = _selectedRowIds.length;
    final ok = await _showMayoreoDeleteConfirmDialog(
      context,
      title: deleteCount == 1 ? 'Eliminar reporte' : 'Eliminar selección',
      subtitle: 'Confirma la baja del reporte visible.',
      message: deleteCount == 1
          ? 'Se eliminará el reporte seleccionado. Esta acción no se puede deshacer.'
          : 'Se eliminarán $deleteCount reportes seleccionados. Esta acción no se puede deshacer.',
      impactLabel: deleteCount == 1
          ? 'El reporte saldrá del grid y del estado persistido.'
          : 'Toda la selección saldrá del grid y del estado persistido.',
      confirmLabel: deleteCount == 1
          ? 'Eliminar reporte'
          : 'Eliminar selección',
    );
    if (ok != true || !mounted) return;
    setState(() {
      _rows = _rows
          .where((item) => !_selectedRowIds.contains(item.id))
          .toList(growable: false);
      _selectedRowId = _rows.isEmpty ? null : _rows.first.id;
      _selectedRowIds
        ..clear()
        ..addAll(
          _selectedRowId == null ? const <String>{} : <String>{_selectedRowId!},
        );
      _selectionAnchorRowId = _selectedRowId;
    });
    _persistState();
    _persistRows();
  }

  Future<void> _handleRowMenuAction(
    _MayoreoSalesReportRow row,
    _SalesReportMenuAction action,
  ) async {
    setState(() {
      _selectedRowId = row.id;
      if (!_selectedRowIds.contains(row.id)) {
        _selectedRowIds
          ..clear()
          ..add(row.id);
      }
      _selectionAnchorRowId = row.id;
    });
    switch (action) {
      case _SalesReportMenuAction.edit:
        await _openEditDialog(row);
        return;
      case _SalesReportMenuAction.relate:
        await _openRelateDialog(row);
        return;
      case _SalesReportMenuAction.delete:
        _deleteSelected();
        return;
    }
  }

  String _clientName(String id) {
    for (final row in _clients) {
      if (row.id == id) return row.name;
    }
    return id;
  }

  String _materialName(String id) {
    for (final row in _materials) {
      if (row.id == id) return row.name;
    }
    return id;
  }

  Widget _buildBody() {
    final filteredRows = _filteredRows;
    final selectedFilteredRows = filteredRows
        .where((row) => _selectedRowIds.contains(row.id))
        .toList(growable: false);
    final selectedCount = _selectedRowIds.length;
    final currentPage = _effectiveCurrentPageFor(filteredRows.length);
    final totalPages = _totalPagesFor(filteredRows.length);
    final pageRows = _pageRows(filteredRows);
    final pendingCount = filteredRows.where((row) => !row.isRelated).length;
    final relatedCount = filteredRows.where((row) => row.isRelated).length;
    final visibleExitWeight = filteredRows.fold<double>(
      0,
      (sum, row) => sum + row.exitWeight,
    );
    final approvedTotal = filteredRows.fold<double>(
      0,
      (sum, row) => sum + row.approvedAmount,
    );
    final selectedExitWeight = selectedFilteredRows.fold<double>(
      0,
      (sum, row) => sum + row.exitWeight,
    );
    final selectedApprovedTotal = selectedFilteredRows.fold<double>(
      0,
      (sum, row) => sum + row.approvedAmount,
    );
    final selectedPriceAverage = selectedFilteredRows.isEmpty
        ? 0.0
        : selectedFilteredRows.fold<double>(
                0,
                (sum, row) => sum + row.priceSnapshot,
              ) /
              selectedFilteredRows.length;
    return TapRegion(
      onTapOutside: (_) {
        if (_selectedRowIds.isNotEmpty) {
          _clearSelection();
        }
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: SingleChildScrollView(
            controller: _bodyScrollController,
            padding: const EdgeInsets.only(left: 56, right: 56, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SalesModuleTopBar(
                  moduleTitle: 'Ventas / Reporte de ventas',
                  visibleCount: filteredRows.length,
                  selectedCount: selectedCount,
                  pendingCount: pendingCount,
                  relatedCount: relatedCount,
                  visibleExitWeight: visibleExitWeight,
                  approvedTotal: approvedTotal,
                  selectedExitWeight: selectedExitWeight,
                  selectedApprovedTotal: selectedApprovedTotal,
                  selectedPriceAverage: selectedPriceAverage,
                  exportingCsv: _exportingCsv,
                  canPrintSelection: selectedCount > 0,
                  onExportCsv: _exportCsv,
                  onPrintSelection: _printSelectedReports,
                  onShowNewReport: _openNewReportDialog,
                ),
                const SizedBox(height: 12),
                _SalesGridCard(
                  rows: filteredRows,
                  pageRows: pageRows,
                  selectedRowId: _selectedRowId,
                  selectedRowIds: _selectedRowIds,
                  onTapRow: (row) => _handleRowTap(row, filteredRows),
                  onRowsPointerDown: (event) =>
                      _handleRowsPointerDown(event, pageRows),
                  onRowDragEnter: (row) => _handleRowDragEnter(row, pageRows),
                  onRowsPointerMove: (event) =>
                      _handleRowsPointerMove(event, pageRows),
                  onRowPointerEnd: _handleRowPointerEnd,
                  onDoubleTapRow: _openEditDialog,
                  onRelateRow: _openRelateDialog,
                  onMenuAction: _handleRowMenuAction,
                  onSecondaryTapDown: _showContextMenuForRow,
                  rowKeyForId: _rowItemKey,
                  viewportKey: _rowsViewportKey,
                  hasDateFilter:
                      _dateFilterFrom != null || _dateFilterTo != null,
                  hasTicketFilter: _ticketFilters.isNotEmpty,
                  hasRemisionFilter: _remisionFilters.isNotEmpty,
                  hasClientFilter: _clientFilterIds.isNotEmpty,
                  hasMaterialFilter: _materialFilterIds.isNotEmpty,
                  hasOperationFilter: _operationFilters.isNotEmpty,
                  hasStatusFilter: _statusFilters.isNotEmpty,
                  onOpenDateFilter: () async {
                    final availableDates =
                        _rows
                            .map((row) => DateUtils.dateOnly(row.date))
                            .toSet()
                            .toList(growable: false)
                          ..sort();
                    final range = await _showMayoreoSalesDateRangeDialog(
                      context,
                      title: 'Filtrar fecha',
                      initialFrom: _dateFilterFrom,
                      initialTo: _dateFilterTo,
                      firstDate: availableDates.isNotEmpty
                          ? availableDates.first
                          : DateTime(2024),
                      lastDate: availableDates.isNotEmpty
                          ? availableDates.last
                          : DateTime(2035),
                    );
                    if (!mounted) return;
                    if (range == null) return;
                    setState(() {
                      _dateFilterFrom = range.from;
                      _dateFilterTo = range.to;
                    });
                    _persistState();
                  },
                  onOpenTicketFilter: () async {
                    final next =
                        await _showMayoreoSalesMultiSelectDialog<String>(
                          context,
                          title: 'Filtrar ticket',
                          initialSelected: _ticketFilters,
                          options:
                              (_rows.map((row) => row.ticket).toSet().toList()
                                    ..sort())
                                  .map(
                                    (value) =>
                                        _MayoreoSalesPickerOption<String>(
                                          value: value,
                                          label: value,
                                        ),
                                  )
                                  .toList(growable: false),
                        );
                    if (!mounted) return;
                    if (next == null) return;
                    setState(() {
                      _ticketFilters
                        ..clear()
                        ..addAll(next);
                    });
                    _persistState();
                  },
                  onOpenRemisionFilter: () async {
                    final next =
                        await _showMayoreoSalesMultiSelectDialog<String>(
                          context,
                          title: 'Filtrar remisión',
                          initialSelected: _remisionFilters,
                          options:
                              (_rows.map((row) => row.remision).toSet().toList()
                                    ..sort())
                                  .map(
                                    (value) =>
                                        _MayoreoSalesPickerOption<String>(
                                          value: value,
                                          label: value,
                                        ),
                                  )
                                  .toList(growable: false),
                        );
                    if (!mounted) return;
                    if (next == null) return;
                    setState(() {
                      _remisionFilters
                        ..clear()
                        ..addAll(next);
                    });
                    _persistState();
                  },
                  onOpenClientFilter: () async {
                    final next =
                        await _showMayoreoSalesMultiSelectDialog<String>(
                          context,
                          title: 'Filtrar cliente',
                          initialSelected: _clientFilterIds,
                          options: _clients
                              .map(
                                (item) => _MayoreoSalesPickerOption<String>(
                                  value: item.id,
                                  label: item.name,
                                ),
                              )
                              .toList(growable: false),
                        );
                    if (!mounted) return;
                    if (next == null) return;
                    setState(() {
                      _clientFilterIds
                        ..clear()
                        ..addAll(next);
                    });
                    _persistState();
                  },
                  onOpenMaterialFilter: () async {
                    final next =
                        await _showMayoreoSalesMultiSelectDialog<String>(
                          context,
                          title: 'Filtrar material',
                          initialSelected: _materialFilterIds,
                          options: _materials
                              .map(
                                (item) => _MayoreoSalesPickerOption<String>(
                                  value: item.id,
                                  label: item.name,
                                ),
                              )
                              .toList(growable: false),
                        );
                    if (!mounted) return;
                    if (next == null) return;
                    setState(() {
                      _materialFilterIds
                        ..clear()
                        ..addAll(next);
                    });
                    _persistState();
                  },
                  onOpenOperationFilter: () async {
                    final next =
                        await _showMayoreoSalesMultiSelectDialog<String>(
                          context,
                          title: 'Filtrar operación',
                          initialSelected: _operationFilters,
                          options: _MayoreoReportOperationType.values
                              .map(
                                (item) => _MayoreoSalesPickerOption<String>(
                                  value: item.name,
                                  label: _operationTypeLabel(item),
                                ),
                              )
                              .toList(growable: false),
                        );
                    if (!mounted) return;
                    if (next == null) return;
                    setState(() {
                      _operationFilters
                        ..clear()
                        ..addAll(next);
                    });
                    _persistState();
                  },
                  onOpenStatusFilter: () async {
                    final next =
                        await _showMayoreoSalesMultiSelectDialog<String>(
                          context,
                          title: 'Filtrar estatus',
                          initialSelected: _statusFilters,
                          options: const [
                            _MayoreoSalesPickerOption<String>(
                              value: 'pending',
                              label: 'PENDIENTE',
                            ),
                            _MayoreoSalesPickerOption<String>(
                              value: 'related',
                              label: 'RELACIONADO',
                            ),
                          ],
                        );
                    if (!mounted) return;
                    if (next == null) return;
                    setState(() {
                      _statusFilters
                        ..clear()
                        ..addAll(next);
                    });
                    _persistState();
                  },
                  onClearFilters:
                      _dateFilterFrom != null ||
                          _dateFilterTo != null ||
                          _ticketFilters.isNotEmpty ||
                          _remisionFilters.isNotEmpty ||
                          _clientFilterIds.isNotEmpty ||
                          _materialFilterIds.isNotEmpty ||
                          _operationFilters.isNotEmpty ||
                          _statusFilters.isNotEmpty
                      ? () {
                          setState(() {
                            _dateFilterFrom = null;
                            _dateFilterTo = null;
                            _ticketFilters.clear();
                            _remisionFilters.clear();
                            _clientFilterIds.clear();
                            _materialFilterIds.clear();
                            _operationFilters.clear();
                            _statusFilters.clear();
                          });
                          _persistState();
                        }
                      : null,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _SalesGridPager(
                    currentPage: currentPage,
                    totalPages: totalPages,
                    pageSize: _pageSize,
                    totalRows: filteredRows.length,
                    onPrevious: currentPage > 0
                        ? () {
                            setState(() => _currentPage = currentPage - 1);
                            _persistState();
                          }
                        : null,
                    onNext: currentPage < totalPages - 1
                        ? () {
                            setState(() => _currentPage = currentPage + 1);
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: mayoreoAreaTokens,
      child: Theme(
        data: _mayoreoMaterialTheme(context),
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final filteredRows = _filteredRows;
            final pageRows = _pageRows(filteredRows);
            final selectedIndex = _selectedFilteredIndex(pageRows);
            if (event.logicalKey == LogicalKeyboardKey.escape && _menuOpen) {
              setState(() => _menuOpen = false);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.escape &&
                _selectedRowIds.isNotEmpty) {
              _clearSelection();
              _persistState();
              return KeyEventResult.handled;
            }
            if (_isShortcutModifierPressed() &&
                event.logicalKey == LogicalKeyboardKey.keyA &&
                pageRows.isNotEmpty) {
              setState(() {
                _selectedRowId = pageRows.first.id;
                _selectedRowIds
                  ..clear()
                  ..addAll(pageRows.map((row) => row.id));
                _selectionAnchorRowId = pageRows.first.id;
              });
              _persistState();
              return KeyEventResult.handled;
            }
            if (pageRows.isNotEmpty &&
                event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _selectFilteredIndex(
                pageRows,
                selectedIndex < 0 ? 0 : selectedIndex + 1,
              );
              if (_isShiftPressed() && _selectedRowId != null) {
                final row = pageRows[_selectedFilteredIndex(pageRows)];
                setState(() => _extendSelectionToRow(row, pageRows));
                _persistState();
              }
              return KeyEventResult.handled;
            }
            if (pageRows.isNotEmpty &&
                event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _selectFilteredIndex(
                pageRows,
                selectedIndex <= 0 ? 0 : selectedIndex - 1,
              );
              if (_isShiftPressed() && _selectedRowId != null) {
                final row = pageRows[_selectedFilteredIndex(pageRows)];
                setState(() => _extendSelectionToRow(row, pageRows));
                _persistState();
              }
              return KeyEventResult.handled;
            }
            if (pageRows.isNotEmpty && isEnterKey(event.logicalKey)) {
              unawaited(_openEditDialog(_selectedRow!));
              return KeyEventResult.handled;
            }
            if (pageRows.isNotEmpty && isDeleteKey(event.logicalKey)) {
              _deleteSelected();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: AppShell(
            background: const _SalesReportBackground(),
            wrapBodyInGlass: false,
            animateHeaderSlots: false,
            animateBody: !widget.instantOpen,
            headerBodySpacing: 8,
            padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
            leadingBuilder: (_, _) => _SalesHeaderButton(
              label: _menuOpen ? 'Cerrar panel' : 'Navegación',
              icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
              onTapSync: () => setState(() => _menuOpen = !_menuOpen),
            ),
            centerBuilder: (_, _) => const _SalesHeaderBrand(),
            trailingBuilder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SalesHeaderButton(
                  label: 'Correo',
                  icon: Icons.mail_outline_rounded,
                  compact: true,
                  onTap: _openMailHostinger,
                ),
                const SizedBox(width: 10),
                _SalesHeaderButton(
                  label: 'Cerrar sesión',
                  icon: Icons.logout_rounded,
                  onTap: () async {},
                ),
              ],
            ),
            child: Stack(
              children: [
                _buildBody(),
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
                    child: _SalesSidePanel(
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

class _SalesHeaderBrand extends StatelessWidget {
  const _SalesHeaderBrand();

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
          'Reporte de Ventas',
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

class _SalesGridHeader extends StatelessWidget {
  final bool hasDateFilter;
  final bool hasTicketFilter;
  final bool hasRemisionFilter;
  final bool hasClientFilter;
  final bool hasMaterialFilter;
  final bool hasOperationFilter;
  final bool hasStatusFilter;
  final Future<void> Function()? onOpenDateFilter;
  final Future<void> Function()? onOpenTicketFilter;
  final Future<void> Function()? onOpenRemisionFilter;
  final Future<void> Function()? onOpenClientFilter;
  final Future<void> Function()? onOpenMaterialFilter;
  final Future<void> Function()? onOpenOperationFilter;
  final Future<void> Function()? onOpenStatusFilter;

  const _SalesGridHeader({
    required this.hasDateFilter,
    required this.hasTicketFilter,
    required this.hasRemisionFilter,
    required this.hasClientFilter,
    required this.hasMaterialFilter,
    required this.hasOperationFilter,
    required this.hasStatusFilter,
    this.onOpenDateFilter,
    this.onOpenTicketFilter,
    this.onOpenRemisionFilter,
    this.onOpenClientFilter,
    this.onOpenMaterialFilter,
    this.onOpenOperationFilter,
    this.onOpenStatusFilter,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    Widget cell(String label, double width) {
      return SizedBox(
        width: width,
        child: _SalesGridHeaderFilterCell(
          label: label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: tokens.primaryStrong,
            letterSpacing: 0.22,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: mayoreoAreaTokens.border.withValues(alpha: 0.52),
        ),
      ),
      child: ContractGridScaledRow(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _kReportDateW,
              child: _SalesGridHeaderFilterCell(
                label: 'FECHA',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: kMayoreoInk,
                  letterSpacing: 0.22,
                ),
                active: hasDateFilter,
                onTap: onOpenDateFilter,
              ),
            ),
            SizedBox(
              width: _kReportTicketW,
              child: _SalesGridHeaderFilterCell(
                label: 'TICKET',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: kMayoreoInk,
                  letterSpacing: 0.22,
                ),
                active: hasTicketFilter,
                onTap: onOpenTicketFilter,
              ),
            ),
            SizedBox(
              width: _kReportClientW,
              child: _SalesGridHeaderFilterCell(
                label: 'CLIENTE',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: kMayoreoInk,
                  letterSpacing: 0.22,
                ),
                active: hasClientFilter,
                onTap: onOpenClientFilter,
              ),
            ),
            SizedBox(
              width: _kReportRemisionW,
              child: _SalesGridHeaderFilterCell(
                label: 'REMISIÓN',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: kMayoreoInk,
                  letterSpacing: 0.22,
                ),
                active: hasRemisionFilter,
                onTap: onOpenRemisionFilter,
              ),
            ),
            SizedBox(
              width: _kReportMaterialW,
              child: _SalesGridHeaderFilterCell(
                label: 'MATERIAL',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: kMayoreoInk,
                  letterSpacing: 0.22,
                ),
                active: hasMaterialFilter,
                onTap: onOpenMaterialFilter,
              ),
            ),
            cell('PESO SALIDA', _kReportExitWeightW),
            cell('PRECIO', _kReportPriceW),
            cell('PESO APROB.', _kReportApprovedWeightW),
            cell('PRECIO APROB.', _kReportApprovedPriceW),
            SizedBox(
              width: _kReportTypeW,
              child: _SalesGridHeaderFilterCell(
                label: 'OPERACIÓN',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: kMayoreoInk,
                  letterSpacing: 0.22,
                ),
                active: hasOperationFilter,
                onTap: onOpenOperationFilter,
              ),
            ),
            cell('OBSERVACIONES', _kReportNotesW),
            SizedBox(
              width: _kReportActionsW,
              child: _SalesGridHeaderFilterCell(
                label: 'ESTADO',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: kMayoreoInk,
                  letterSpacing: 0.22,
                ),
                active: hasStatusFilter,
                onTap: onOpenStatusFilter,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesGridRow extends StatefulWidget {
  final _MayoreoSalesReportRow row;
  final bool selected;
  final VoidCallback onTapRow;
  final VoidCallback onDoubleTap;
  final VoidCallback onRelate;
  final VoidCallback? onDragEnter;
  final Future<void> Function(_SalesReportMenuAction action) onMenuAction;
  final Future<void> Function(Offset globalPosition)? onSecondaryTapDown;

  const _SalesGridRow({
    required this.row,
    required this.selected,
    required this.onTapRow,
    required this.onDoubleTap,
    required this.onRelate,
    this.onDragEnter,
    required this.onMenuAction,
    this.onSecondaryTapDown,
  });

  @override
  State<_SalesGridRow> createState() => _SalesGridRowState();
}

class _SalesGridRowState extends State<_SalesGridRow> {
  bool _hovered = false;
  int? _hoveredEditableColumn;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final row = widget.row;
    final softenDividers = _hoveredEditableColumn != null;

    Widget divider() {
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 110),
        opacity: softenDividers ? 0.0 : 1.0,
        child: Container(
          width: 1,
          height: 28,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: tokens.border.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    }

    Widget cell({
      required int index,
      required double width,
      required Widget child,
      bool editable = false,
      bool includeDivider = true,
    }) {
      final hoveredEditable = editable && _hoveredEditableColumn == index;
      final content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ContractEditableHoverCapsule(
                hovered: hoveredEditable,
                selectedContext: widget.selected,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: child,
              ),
            ),
          ),
          if (includeDivider) divider(),
        ],
      );
      final cellChild = SizedBox(width: width, child: content);
      if (!editable) return cellChild;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredEditableColumn = index),
        onExit: (_) {
          if (_hoveredEditableColumn == index) {
            setState(() => _hoveredEditableColumn = null);
          }
        },
        child: cellChild,
      );
    }

    final highlighted = widget.selected || _hovered;
    final rowContentWidth =
        _kReportDateW +
        _kReportTicketW +
        _kReportClientW +
        _kReportRemisionW +
        _kReportMaterialW +
        _kReportExitWeightW +
        _kReportPriceW +
        _kReportApprovedWeightW +
        _kReportApprovedPriceW +
        _kReportTypeW +
        _kReportNotesW +
        _kReportActionsW;

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
            color: highlighted
                ? mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.22)
                : mayoreoAreaTokens.border.withValues(alpha: 0.54),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: highlighted ? 0.10 : 0.05),
              blurRadius: highlighted ? 18 : 12,
              offset: Offset(0, highlighted ? 10 : 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: ContractGridScaledRow(
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onSecondaryTapDown: widget.onSecondaryTapDown == null
                    ? null
                    : (details) => unawaited(
                        widget.onSecondaryTapDown!(details.globalPosition),
                      ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: widget.onTapRow,
                  onDoubleTap: widget.onDoubleTap,
                  child: SizedBox(
                    width: rowContentWidth,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        cell(
                          index: 0,
                          width: _kReportDateW,
                          editable: true,
                          child: Text(_formatDate(row.date)),
                        ),
                        cell(
                          index: 1,
                          width: _kReportTicketW,
                          editable: true,
                          child: Text(
                            row.ticket,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: tokens.primaryStrong,
                            ),
                          ),
                        ),
                        cell(
                          index: 2,
                          width: _kReportClientW,
                          editable: true,
                          child: Text(row.clientName),
                        ),
                        cell(
                          index: 3,
                          width: _kReportRemisionW,
                          editable: true,
                          child: Text(row.remision),
                        ),
                        cell(
                          index: 4,
                          width: _kReportMaterialW,
                          editable: true,
                          child: Text(row.materialName),
                        ),
                        cell(
                          index: 5,
                          width: _kReportExitWeightW,
                          editable: true,
                          child: Text('${formatDecimal(row.exitWeight)} KG'),
                        ),
                        cell(
                          index: 6,
                          width: _kReportPriceW,
                          editable: true,
                          child: Text(formatMoney(row.priceSnapshot)),
                        ),
                        cell(
                          index: 7,
                          width: _kReportApprovedWeightW,
                          editable: true,
                          child: Text(
                            row.approvedWeight == null
                                ? '—'
                                : '${formatDecimal(row.approvedWeight!)} KG',
                          ),
                        ),
                        cell(
                          index: 8,
                          width: _kReportApprovedPriceW,
                          editable: true,
                          child: Text(
                            row.approvedPrice == null
                                ? '—'
                                : formatMoney(row.approvedPrice!),
                          ),
                        ),
                        cell(
                          index: 9,
                          width: _kReportTypeW,
                          editable: true,
                          child: Text(_operationTypeLabel(row.operationType)),
                        ),
                        cell(
                          index: 10,
                          width: _kReportNotesW,
                          editable: true,
                          child: Text(
                            row.observations.isEmpty ? '—' : row.observations,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        AnchoredActionSlot(
                          width: _kReportActionsW,
                          trailingWidth: 36,
                          gap: 6,
                          leading: Align(
                            alignment: Alignment.centerLeft,
                            child: _SalesStatusChip(
                              related: row.isRelated,
                              activeContext: highlighted,
                            ),
                          ),
                          trailing: PopupMenuButton<_SalesReportMenuAction>(
                            tooltip: 'Acciones',
                            padding: EdgeInsets.zero,
                            color: tokens.surfaceTint.withValues(alpha: 0.98),
                            elevation: 8,
                            shadowColor: Colors.black.withValues(alpha: 0.12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(
                                color: tokens.primarySoft.withValues(
                                  alpha: 0.72,
                                ),
                              ),
                            ),
                            onSelected: (action) =>
                                unawaited(widget.onMenuAction(action)),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: _SalesReportMenuAction.edit,
                                child: Text(
                                  'Editar',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: kMayoreoInk,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: _SalesReportMenuAction.relate,
                                child: Text(
                                  row.isRelated
                                      ? 'Ajustar relación'
                                      : 'Relacionar',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: kMayoreoInk,
                                  ),
                                ),
                              ),
                              const PopupMenuDivider(height: 1),
                              const PopupMenuItem(
                                value: _SalesReportMenuAction.delete,
                                child: Text(
                                  'Eliminar',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: kMayoreoInk,
                                  ),
                                ),
                              ),
                            ],
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.82),
                                    tokens.surfaceTint.withValues(alpha: 0.78),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                              ),
                              child: const Icon(Icons.more_horiz_rounded),
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
      ),
    );
  }
}

class _SalesModuleTopBar extends StatelessWidget {
  final String moduleTitle;
  final int visibleCount;
  final int selectedCount;
  final int pendingCount;
  final int relatedCount;
  final double visibleExitWeight;
  final double approvedTotal;
  final double selectedExitWeight;
  final double selectedApprovedTotal;
  final double selectedPriceAverage;
  final bool exportingCsv;
  final bool canPrintSelection;
  final Future<void> Function() onExportCsv;
  final Future<void> Function() onPrintSelection;
  final Future<void> Function() onShowNewReport;

  const _SalesModuleTopBar({
    required this.moduleTitle,
    required this.visibleCount,
    required this.selectedCount,
    required this.pendingCount,
    required this.relatedCount,
    required this.visibleExitWeight,
    required this.approvedTotal,
    required this.selectedExitWeight,
    required this.selectedApprovedTotal,
    required this.selectedPriceAverage,
    required this.exportingCsv,
    required this.canPrintSelection,
    required this.onExportCsv,
    required this.onPrintSelection,
    required this.onShowNewReport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Ventas / Reporte de ventas',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        AppGlassToolbarPanel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                  FilledButton.icon(
                    style: _mayoreoToolbarSecondaryActionStyle(),
                    onPressed: canPrintSelection
                        ? () => unawaited(onPrintSelection())
                        : null,
                    icon: const Icon(Icons.print_rounded),
                    label: Text(
                      selectedCount > 1 ? 'Imprimir selección' : 'Imprimir',
                    ),
                  ),
                  FilledButton.icon(
                    style: _mayoreoPrimaryButtonStyle(),
                    onPressed: onShowNewReport,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Nuevo reporte'),
                  ),
                ],
              );
              final selectionInfo = _SalesSelectionInfo(
                selectedCount: selectedCount,
                pendingCount: pendingCount,
                relatedCount: relatedCount,
                selectedExitWeight: selectedExitWeight,
                selectedApprovedTotal: selectedApprovedTotal,
                selectedPriceAverage: selectedPriceAverage,
              );
              if (constraints.maxWidth < 860) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    actions,
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: selectionInfo,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: actions),
                  const SizedBox(width: 10),
                  selectionInfo,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              _SalesMetricCard(
                icon: Icons.scale_rounded,
                title: 'PESO SALIDA',
                value: '${formatDecimal(visibleExitWeight)} KG',
                detail: '$visibleCount registros filtrados',
              ),
              _SalesMetricCard(
                icon: Icons.payments_rounded,
                title: 'IMPORTE APROB.',
                value: formatMoney(approvedTotal, decimals: 0),
                detail: '$relatedCount relacionados',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SalesMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String detail;

  const _SalesMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        width: 310,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: tokens.badgeBackground.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
          boxShadow: [
            BoxShadow(
              color: tokens.glow.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tokens.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: kMayoreoMutedInk,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kMayoreoInk,
                      height: 1.0,
                    ),
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesSelectionInfo extends StatelessWidget {
  final int selectedCount;
  final int pendingCount;
  final int relatedCount;
  final double selectedExitWeight;
  final double selectedApprovedTotal;
  final double selectedPriceAverage;

  const _SalesSelectionInfo({
    required this.selectedCount,
    required this.pendingCount,
    required this.relatedCount,
    required this.selectedExitWeight,
    required this.selectedApprovedTotal,
    required this.selectedPriceAverage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          selectedCount == 1
              ? '1 seleccionado'
              : '$selectedCount seleccionados',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: kMayoreoMutedInk,
          ),
          textAlign: TextAlign.right,
        ),
        Text(
          'Pendientes: $pendingCount · Relacionados: $relatedCount',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: kMayoreoMutedInk,
          ),
          textAlign: TextAlign.right,
        ),
        if (selectedCount > 0)
          Text(
            'KG: ${formatDecimal(selectedExitWeight)} · Importe: ${formatMoney(selectedApprovedTotal, decimals: 0)} · Prom.: ${formatMoney(selectedPriceAverage, decimals: 2)}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kMayoreoMutedInk,
            ),
            textAlign: TextAlign.right,
          ),
      ],
    );
  }
}

class _SalesGridCard extends StatelessWidget {
  final List<_MayoreoSalesReportRow> rows;
  final List<_MayoreoSalesReportRow> pageRows;
  final String? selectedRowId;
  final Set<String> selectedRowIds;
  final ValueChanged<_MayoreoSalesReportRow> onTapRow;
  final ValueChanged<PointerDownEvent> onRowsPointerDown;
  final ValueChanged<_MayoreoSalesReportRow> onRowDragEnter;
  final ValueChanged<PointerMoveEvent> onRowsPointerMove;
  final VoidCallback onRowPointerEnd;
  final ValueChanged<_MayoreoSalesReportRow> onDoubleTapRow;
  final ValueChanged<_MayoreoSalesReportRow> onRelateRow;
  final Future<void> Function(
    _MayoreoSalesReportRow row,
    _SalesReportMenuAction action,
  )
  onMenuAction;
  final Future<void> Function(_MayoreoSalesReportRow row, Offset globalPosition)
  onSecondaryTapDown;
  final GlobalKey Function(String rowId) rowKeyForId;
  final Key viewportKey;
  final bool hasDateFilter;
  final bool hasTicketFilter;
  final bool hasRemisionFilter;
  final bool hasClientFilter;
  final bool hasMaterialFilter;
  final bool hasOperationFilter;
  final bool hasStatusFilter;
  final Future<void> Function() onOpenDateFilter;
  final Future<void> Function() onOpenTicketFilter;
  final Future<void> Function() onOpenRemisionFilter;
  final Future<void> Function() onOpenClientFilter;
  final Future<void> Function() onOpenMaterialFilter;
  final Future<void> Function() onOpenOperationFilter;
  final Future<void> Function() onOpenStatusFilter;
  final VoidCallback? onClearFilters;

  const _SalesGridCard({
    required this.rows,
    required this.pageRows,
    required this.selectedRowId,
    required this.selectedRowIds,
    required this.onTapRow,
    required this.onRowsPointerDown,
    required this.onRowDragEnter,
    required this.onRowsPointerMove,
    required this.onRowPointerEnd,
    required this.onDoubleTapRow,
    required this.onRelateRow,
    required this.onMenuAction,
    required this.onSecondaryTapDown,
    required this.rowKeyForId,
    required this.viewportKey,
    required this.hasDateFilter,
    required this.hasTicketFilter,
    required this.hasRemisionFilter,
    required this.hasClientFilter,
    required this.hasMaterialFilter,
    required this.hasOperationFilter,
    required this.hasStatusFilter,
    required this.onOpenDateFilter,
    required this.onOpenTicketFilter,
    required this.onOpenRemisionFilter,
    required this.onOpenClientFilter,
    required this.onOpenMaterialFilter,
    required this.onOpenOperationFilter,
    required this.onOpenStatusFilter,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: viewportKey,
      child: ContractGlassCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SalesGridHeader(
              hasDateFilter: hasDateFilter,
              hasTicketFilter: hasTicketFilter,
              hasRemisionFilter: hasRemisionFilter,
              hasClientFilter: hasClientFilter,
              hasMaterialFilter: hasMaterialFilter,
              hasOperationFilter: hasOperationFilter,
              hasStatusFilter: hasStatusFilter,
              onOpenDateFilter: onOpenDateFilter,
              onOpenTicketFilter: onOpenTicketFilter,
              onOpenRemisionFilter: onOpenRemisionFilter,
              onOpenClientFilter: onOpenClientFilter,
              onOpenMaterialFilter: onOpenMaterialFilter,
              onOpenOperationFilter: onOpenOperationFilter,
              onOpenStatusFilter: onOpenStatusFilter,
            ),
            if (onClearFilters != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: const Text('Limpiar filtros'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: _kSalesGridBodyMinHeight,
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
                        'No hay reportes de ventas con los filtros actuales.',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: kMayoreoInk,
                        ),
                      ),
                    )
                  : Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: onRowsPointerDown,
                      onPointerMove: onRowsPointerMove,
                      onPointerUp: (_) => onRowPointerEnd(),
                      onPointerCancel: (_) => onRowPointerEnd(),
                      child: Column(
                        children: [
                          for (final row in pageRows) ...[
                            KeyedSubtree(
                              key: rowKeyForId(row.id),
                              child: _SalesGridRow(
                                row: row,
                                selected: selectedRowIds.contains(row.id),
                                onTapRow: () => onTapRow(row),
                                onDragEnter: () => onRowDragEnter(row),
                                onDoubleTap: () => onDoubleTapRow(row),
                                onRelate: () => onRelateRow(row),
                                onMenuAction: (action) =>
                                    onMenuAction(row, action),
                                onSecondaryTapDown: (globalPosition) =>
                                    onSecondaryTapDown(row, globalPosition),
                              ),
                            ),
                            if (row != pageRows.last)
                              const SizedBox(height: 10),
                          ],
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

class _SalesGridHeaderFilterCell extends StatelessWidget {
  final String label;
  final TextStyle style;
  final bool active;
  final Future<void> Function()? onTap;

  const _SalesGridHeaderFilterCell({
    required this.label,
    required this.style,
    this.active = false,
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

class _SalesStatusChip extends StatelessWidget {
  final bool related;
  final bool activeContext;

  const _SalesStatusChip({required this.related, required this.activeContext});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final background = related
        ? const LinearGradient(
            colors: [Color(0xFFEAF4E4), Color(0xFFD5E8CD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              activeContext
                  ? tokens.badgeBackground.withValues(alpha: 0.98)
                  : Colors.white.withValues(alpha: 0.92),
              activeContext
                  ? tokens.badgeBackground.withValues(alpha: 0.82)
                  : Colors.white.withValues(alpha: 0.76),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final border = related ? const Color(0xFFBAD2B1) : tokens.border;
    final textColor = related ? const Color(0xFF4B865C) : tokens.primaryStrong;
    final iconBackground = related
        ? const Color(0xFFB8D4AE)
        : tokens.primary.withValues(alpha: 0.14);
    final iconColor = related ? const Color(0xFF447653) : tokens.primaryStrong;
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        gradient: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border.withValues(alpha: 0.95)),
        boxShadow: [
          BoxShadow(
            color: (related ? const Color(0xFF7DA76D) : tokens.glow).withValues(
              alpha: 0.16,
            ),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.35),
                    blurRadius: 2,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Icon(
                related ? Icons.check_rounded : Icons.schedule_rounded,
                size: 12.5,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              related ? 'RELACIONADO' : 'PENDIENTE',
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                fontSize: 11.6,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.15,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesGridPager extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final int totalRows;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onPageSizeChanged;

  const _SalesGridPager({
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
              style: _mayoreoPagerButtonStyle(),
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
              style: _mayoreoPagerButtonStyle(),
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

class _SalesHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final bool compact;

  const _SalesHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
    this.compact = false,
  });

  @override
  State<_SalesHeaderButton> createState() => _SalesHeaderButtonState();
}

class _SalesHeaderButtonState extends State<_SalesHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final enabled = widget.onTap != null || widget.onTapSync != null;
    final highlighted = enabled && _hovered;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: highlighted ? 1.026 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            onTap: !enabled
                ? null
                : () async {
                    if (widget.onTap != null) {
                      await widget.onTap!();
                    } else {
                      widget.onTapSync?.call();
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              transform: Matrix4.translationValues(
                0,
                highlighted ? -2.5 : 0,
                0,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 0 : 18,
                vertical: widget.compact ? 0 : 14,
              ),
              width: widget.compact ? 56 : 176,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: highlighted ? 0.30 : 0.22),
                    tokens.surfaceTint.withValues(
                      alpha: highlighted ? 0.34 : 0.24,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: highlighted
                      ? Colors.white.withValues(alpha: 0.70)
                      : Colors.white.withValues(alpha: 0.46),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: highlighted ? 28 : 16,
                    color: Colors.black.withValues(
                      alpha: highlighted ? 0.16 : 0.08,
                    ),
                    offset: Offset(0, highlighted ? 14 : 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.compact)
                    Expanded(
                      child: Center(
                        child: Icon(
                          widget.icon,
                          size: 20,
                          color: tokens.primaryStrong,
                        ),
                      ),
                    )
                  else ...[
                    const SizedBox(width: 12),
                    Icon(widget.icon, size: 24, color: tokens.primaryStrong),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: tokens.primaryStrong,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SalesSidePanel extends StatelessWidget {
  final bool canReturnToDirection;
  final ValueChanged<String> onNavigate;

  const _SalesSidePanel({
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
                _SalesNavItem(
                  icon: Icons.arrow_back_rounded,
                  title: 'Volver a Dirección',
                  onTapSync: () => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 10),
              ],
              const _SalesSectionHeader(label: 'MENU'),
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
                    const _SalesNavItem(
                      icon: Icons.point_of_sale_rounded,
                      title: 'Ventas',
                      subtitle: 'Reporte inicial de salidas',
                      accented: true,
                    ),
                    const SizedBox(height: 8),
                    _SalesNavItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Cuentas',
                      subtitle: 'Factura, cheque y cobranza',
                      onTapSync: () => onNavigate('Cuentas'),
                    ),
                    const SizedBox(height: 8),
                    _SalesNavItem(
                      icon: Icons.currency_exchange_rounded,
                      title: 'Cuenta El Palomar',
                      subtitle: 'Cuenta corriente especial',
                      onTapSync: () => onNavigate('Cuenta El Palomar'),
                    ),
                    const SizedBox(height: 8),
                    _SalesNavItem(
                      icon: Icons.price_check_rounded,
                      title: 'Catálogo',
                      subtitle: 'Clientes, materiales y precios',
                      onTapSync: () => onNavigate('Catálogo'),
                    ),
                    const SizedBox(height: 8),
                    _SalesNavItem(
                      icon: Icons.request_quote_rounded,
                      title: 'Ajuste de precios',
                      subtitle: 'Vigentes e historial',
                      onTapSync: () => onNavigate('Ajuste de precios'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _SalesSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              if (canReturnToDirection) ...[
                _SalesNavItem(
                  icon: Icons.assessment_outlined,
                  title: 'Dashboard Dirección',
                  subtitle: 'Vista ejecutiva multiarea',
                  onTapSync: () => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 8),
              ],
              _SalesNavItem(
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

class _SalesSectionHeader extends StatelessWidget {
  final String label;

  const _SalesSectionHeader({required this.label});

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

class _SalesNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool accented;
  final VoidCallback? onTapSync;

  const _SalesNavItem({
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
              Icon(icon, color: tokens.primaryStrong),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: tokens.primaryStrong,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
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

class _SalesReportBackground extends StatelessWidget {
  const _SalesReportBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                mayoreoAreaTokens.surfaceTint,
                const Color(0xFFFFF1B8),
                mayoreoAreaTokens.accent.withValues(alpha: 0.34),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: -160,
          top: -140,
          child: Container(
            width: 580,
            height: 580,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: kMayoreoPanelGradient,
            ),
          ),
        ),
        Positioned(
          right: -220,
          top: -120,
          child: Container(
            width: 560,
            height: 560,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mayoreoAreaTokens.glow.withValues(alpha: 0.18),
            ),
          ),
        ),
      ],
    );
  }
}

class _SalesReportDialog extends StatefulWidget {
  final _MayoreoSalesReportRow? initial;
  final List<_MayoreoSalesClient> clients;
  final List<_MayoreoSalesMaterial> materials;
  final List<_MayoreoSalesCatalogPrice> prices;
  final double? Function(String clientId, String materialId) priceLookup;

  const _SalesReportDialog({
    this.initial,
    required this.clients,
    required this.materials,
    required this.prices,
    required this.priceLookup,
  });

  @override
  State<_SalesReportDialog> createState() => _SalesReportDialogState();
}

class _SalesReportDialogState extends State<_SalesReportDialog> {
  late final TextEditingController _ticketC;
  late final TextEditingController _remisionC;
  late final TextEditingController _exitWeightC;
  late final TextEditingController _priceC;
  late final TextEditingController _observationsC;
  late DateTime _date;
  String? _clientId;
  String? _materialId;
  late _MayoreoReportOperationType _operationType;

  bool get _isEditing => widget.initial != null;

  List<_MayoreoSalesMaterial> get _availableMaterials {
    final clientId = _clientId;
    if (clientId == null) return const <_MayoreoSalesMaterial>[];
    final allowedIds = widget.prices
        .where((row) => row.clientId == clientId)
        .map((row) => row.materialId)
        .toSet();
    return widget.materials
        .where((row) => allowedIds.contains(row.id))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _ticketC = TextEditingController(text: initial?.ticket ?? '');
    _remisionC = TextEditingController(text: initial?.remision ?? '');
    _exitWeightC = TextEditingController(
      text: initial == null ? '' : formatDecimal(initial.exitWeight),
    );
    _priceC = TextEditingController(
      text: initial == null ? '' : formatDecimal(initial.priceSnapshot),
    );
    _observationsC = TextEditingController(text: initial?.observations ?? '');
    _date = initial?.date ?? DateTime.now();
    _clientId = initial?.clientId ?? widget.clients.firstOrNull?.id;
    _materialId = initial?.materialId;
    _operationType =
        initial?.operationType ?? _MayoreoReportOperationType.factura;
    _syncMaterialAvailability();
    if (initial == null) {
      _syncPriceFromCatalog();
    }
  }

  @override
  void dispose() {
    _ticketC.dispose();
    _remisionC.dispose();
    _exitWeightC.dispose();
    _priceC.dispose();
    _observationsC.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await _showMayoreoSalesSingleDateDialog(
      context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      title: 'Selecciona fecha del reporte',
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  void _syncPriceFromCatalog() {
    final clientId = _clientId;
    final materialId = _materialId;
    if (clientId == null || materialId == null) return;
    final price = widget.priceLookup(clientId, materialId);
    _priceC.text = price == null ? '' : formatDecimal(price);
  }

  void _syncMaterialAvailability() {
    final available = _availableMaterials;
    if (available.isEmpty) {
      _materialId = null;
      _priceC.text = '';
      return;
    }
    final stillValid =
        _materialId != null && available.any((item) => item.id == _materialId);
    if (!stillValid) {
      _materialId = available.first.id;
    }
  }

  Future<void> _pickClient() async {
    final picked = await _showMayoreoSalesSingleSelectDialog<String>(
      context,
      title: 'Seleccionar cliente',
      initialValue: _clientId,
      options: widget.clients
          .map(
            (item) => _MayoreoSalesPickerOption<String>(
              value: item.id,
              label: item.name,
            ),
          )
          .toList(growable: false),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _clientId = picked;
      _syncMaterialAvailability();
      _syncPriceFromCatalog();
    });
  }

  Future<void> _pickMaterial() async {
    final available = _availableMaterials;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esa empresa no tiene materiales con precio vigente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final picked = await _showMayoreoSalesSingleSelectDialog<String>(
      context,
      title: 'Seleccionar material',
      initialValue: _materialId,
      options: available
          .map(
            (item) => _MayoreoSalesPickerOption<String>(
              value: item.id,
              label: item.name,
            ),
          )
          .toList(growable: false),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _materialId = picked;
      _syncPriceFromCatalog();
    });
  }

  void _save() {
    final clientId = _clientId;
    final materialId = _materialId;
    final exitWeight = _parseDouble(_exitWeightC.text);
    final price = _parseDouble(_priceC.text);
    if (_ticketC.text.trim().isEmpty ||
        clientId == null ||
        materialId == null ||
        exitWeight == null ||
        price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completa ticket, cliente, material, peso de salida y precio.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      _MayoreoSalesReportDraft(
        ticket: _ticketC.text.trim(),
        date: _date,
        clientId: clientId,
        remision: _remisionC.text.trim(),
        materialId: materialId,
        exitWeight: exitWeight,
        priceSnapshot: price,
        approvedWeight: widget.initial?.approvedWeight,
        approvedPrice: widget.initial?.approvedPrice,
        approvedAmount: widget.initial?.approvedAmount ?? 0,
        operationType: _operationType,
        observations: _observationsC.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final approximateAmount =
        (_parseDouble(_exitWeightC.text) ?? 0) *
        (_parseDouble(_priceC.text) ?? 0);

    return AreaThemeScope(
      tokens: mayoreoAreaTokens,
      child: Theme(
        data: _mayoreoMaterialTheme(context),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 18,
          ),
          child: ContractPopupSurface(
            constraints: const BoxConstraints(
              minWidth: 720,
              maxWidth: 900,
              maxHeight: 620,
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _DialogTitleBlock(
                      icon: _isEditing
                          ? Icons.edit_note_rounded
                          : Icons.note_add_rounded,
                      title: _isEditing ? 'Editar reporte' : 'Nuevo reporte',
                      subtitle: _isEditing
                          ? 'Corrige solo la captura operativa base.'
                          : 'Captura inicial para alimentar cobranza después.',
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: _TopSummaryChip(
                    icon: Icons.calculate_rounded,
                    label: 'Importe aproximado',
                    value: formatMoney(approximateAmount),
                  ),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ContractGlassCard(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _VoucherSectionTitle(
                              '1. Salida operativa',
                              icon: Icons.local_shipping_outlined,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _VoucherFieldShell(
                                    label: 'Fecha',
                                    child: InkWell(
                                      onTap: _pickDate,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _formatDate(_date),
                                              style: _voucherInputTextStyle(
                                                tokens,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.calendar_month_rounded,
                                            size: 18,
                                            color: tokens.primaryStrong,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _VoucherFieldShell(
                                    label: 'Ticket',
                                    child: _DialogTextField(
                                      controller: _ticketC,
                                      hintText: 'Ticket',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _VoucherFieldShell(
                                    label: 'Remisión',
                                    child: _DialogTextField(
                                      controller: _remisionC,
                                      hintText: 'Remisión',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _VoucherFieldShell(
                                    label: 'Cliente',
                                    child: _PickerValueField(
                                      label: widget.clients
                                          .firstWhere(
                                            (item) => item.id == _clientId,
                                            orElse: () =>
                                                const _MayoreoSalesClient(
                                                  id: '',
                                                  name: 'Seleccionar cliente',
                                                ),
                                          )
                                          .name,
                                      onTap: _pickClient,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _VoucherFieldShell(
                                    label: 'Material',
                                    child: _PickerValueField(
                                      label: widget.materials
                                          .firstWhere(
                                            (item) => item.id == _materialId,
                                            orElse: () =>
                                                const _MayoreoSalesMaterial(
                                                  id: '',
                                                  name: 'Seleccionar material',
                                                ),
                                          )
                                          .name,
                                      onTap: _pickMaterial,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _VoucherFieldShell(
                                    label: 'Tipo operación',
                                    child: _OperationTypeToggle(
                                      value: _operationType,
                                      onChanged: (value) => setState(
                                        () => _operationType = value,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _VoucherFieldShell(
                                    label: 'Peso de salida',
                                    child: _DialogTextField(
                                      controller: _exitWeightC,
                                      hintText: 'KG',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _VoucherFieldShell(
                                    label: 'Precio',
                                    child: Text(
                                      _priceC.text.trim().isEmpty
                                          ? 'Sin precio'
                                          : formatMoney(
                                              _parseDouble(_priceC.text) ?? 0,
                                            ),
                                      style: _voucherInputTextStyle(tokens),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _VoucherFieldShell(
                                    label: 'Observaciones',
                                    child: _DialogTextField(
                                      controller: _observationsC,
                                      hintText: 'Observaciones',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: _mayoreoSecondaryButtonStyle(),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      style: _mayoreoPrimaryButtonStyle(),
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(
                        _isEditing ? 'Guardar cambios' : 'Crear reporte',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RelationVoucherDialog extends StatefulWidget {
  final _MayoreoSalesReportRow row;
  final Future<void> Function(_MayoreoRelationResult result) onPersist;

  const _RelationVoucherDialog({required this.row, required this.onPersist});

  @override
  State<_RelationVoucherDialog> createState() => _RelationVoucherDialogState();
}

class _RelationVoucherDialogState extends State<_RelationVoucherDialog> {
  late final TextEditingController _approvedWeightC;
  late final TextEditingController _overpriceC;
  late bool _savedRelation;
  bool _saving = false;

  void _handleLivePreviewChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _savedRelation = widget.row.isRelated;
    _approvedWeightC = TextEditingController(
      text: widget.row.approvedWeight == null
          ? ''
          : formatDecimal(widget.row.approvedWeight!),
    );
    final initialOverprice = widget.row.approvedPrice == null
        ? 0.0
        : widget.row.approvedPrice! - widget.row.priceSnapshot;
    _overpriceC = TextEditingController(text: formatDecimal(initialOverprice));
    _approvedWeightC.addListener(_handleLivePreviewChanged);
    _overpriceC.addListener(_handleLivePreviewChanged);
  }

  @override
  void dispose() {
    _approvedWeightC.removeListener(_handleLivePreviewChanged);
    _overpriceC.removeListener(_handleLivePreviewChanged);
    _approvedWeightC.dispose();
    _overpriceC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final approvedWeight = _parseDouble(_approvedWeightC.text);
    if (approvedWeight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Captura el peso aprobado para relacionar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final overprice = _parseDouble(_overpriceC.text) ?? 0;
    final approvedPrice = widget.row.priceSnapshot + overprice;
    final approvedAmount = approvedWeight * approvedPrice;
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onPersist(
        _MayoreoRelationResult(
          approvedWeight: approvedWeight,
          approvedPrice: approvedPrice,
          approvedAmount: approvedAmount,
        ),
      );
      if (!mounted) return;
      setState(() => _savedRelation = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.row.isRelated
                ? 'Ajuste de relación guardado.'
                : 'Relación guardada. Ya puedes imprimir.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _print() {
    unawaited(_printPdf());
  }

  Future<void> _printPdf() async {
    try {
      final pdfBytes = await _buildRelationPrintPdfBytes();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final ticket = widget.row.ticket.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '_',
      );
      final file = File(
        '${Directory.systemTemp.path}/mayoreo_relacion_${ticket}_$stamp.pdf',
      );
      await file.writeAsBytes(pdfBytes, flush: true);
      await _openPdfFile(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir el reporte en PDF: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<Uint8List> _buildRelationPrintPdfBytes() async {
    final doc = pw.Document();
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo_dicsa.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final approvedWeight = _parseDouble(_approvedWeightC.text) ?? 0;
    final overprice = _parseDouble(_overpriceC.text) ?? 0;
    final approvedPrice = widget.row.priceSnapshot + overprice;
    final approximateAmount = widget.row.exitWeight * widget.row.priceSnapshot;
    final approvedAmount = approvedWeight * approvedPrice;
    final now = DateTime.now();
    final printedAt =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    pw.Widget infoRow(String label, String value, {bool emphasize = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 96,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Text(
                value.isEmpty ? '—' : value,
                style: pw.TextStyle(
                  fontSize: emphasize ? 12.8 : 10.5,
                  fontWeight: emphasize
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget summaryCard(String label, String value) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FFF0AE'),
            borderRadius: pw.BorderRadius.circular(14),
            border: pw.Border.all(color: PdfColor.fromHex('#E1C863')),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 9.2,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#7B6515'),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#3E3311'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  if (logoImage != null)
                    pw.SizedBox(
                      width: 42,
                      height: 28,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                  if (logoImage != null) pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'REPORTE DE RELACION',
                          style: pw.TextStyle(
                            fontSize: 17,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Text(printedAt, style: const pw.TextStyle(fontSize: 9.5)),
                ],
              ),
              pw.SizedBox(height: 18),
              pw.Row(
                children: [
                  summaryCard(
                    'IMPORTE APROXIMADO',
                    formatMoney(approximateAmount),
                  ),
                  pw.SizedBox(width: 10),
                  summaryCard('IMPORTE APROBADO', formatMoney(approvedAmount)),
                ],
              ),
              pw.SizedBox(height: 18),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(16),
                  border: pw.Border.all(color: PdfColor.fromHex('#D9C98A')),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '1. REPORTE',
                      style: pw.TextStyle(
                        fontSize: 12.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    infoRow('Ticket', widget.row.ticket),
                    infoRow('Remisión', widget.row.remision),
                    infoRow('Cliente', widget.row.clientName),
                    infoRow('Material', widget.row.materialName),
                    infoRow(
                      'Peso salida',
                      '${formatDecimal(widget.row.exitWeight)} KG',
                    ),
                    infoRow(
                      'Precio base',
                      formatMoney(widget.row.priceSnapshot),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(16),
                  border: pw.Border.all(color: PdfColor.fromHex('#D9C98A')),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '2. APROBACION',
                      style: pw.TextStyle(
                        fontSize: 12.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    infoRow(
                      'Peso aprobado',
                      '${formatDecimal(approvedWeight)} KG',
                    ),
                    infoRow('Sobreprecio', formatMoney(overprice)),
                    infoRow(
                      'Precio aprobado',
                      formatMoney(approvedPrice),
                      emphasize: true,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  Future<void> _openPdfFile(String path) async {
    ProcessResult result;
    if (Platform.isMacOS) {
      result = await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      result = await Process.run('cmd', ['/c', 'start', '', path]);
    } else if (Platform.isLinux) {
      result = await Process.run('xdg-open', [path]);
    } else {
      throw UnsupportedError('Plataforma no soportada para abrir PDF');
    }
    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString().trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final approvedWeight = _parseDouble(_approvedWeightC.text) ?? 0;
    final overprice = _parseDouble(_overpriceC.text) ?? 0;
    final approvedPrice = widget.row.priceSnapshot + overprice;
    final approximateAmount = widget.row.exitWeight * widget.row.priceSnapshot;
    final approvedAmount = approvedWeight * approvedPrice;
    final isAdjusting = widget.row.isRelated;
    final canPrint = isAdjusting || _savedRelation;

    return AreaThemeScope(
      tokens: mayoreoAreaTokens,
      child: Theme(
        data: _mayoreoMaterialTheme(context),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 18,
          ),
          child: ContractConfirmDialogKeyHandler(
            onConfirm: _saving ? () {} : () => unawaited(_save()),
            onCancel: () => Navigator.of(context).pop(),
            child: ContractPopupSurface(
              constraints: const BoxConstraints(
                minWidth: 700,
                maxWidth: 900,
                maxHeight: 720,
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _DialogTitleBlock(
                        icon: Icons.link_rounded,
                        title: isAdjusting
                            ? 'Ajustar relación'
                            : 'Relacionar reporte',
                        subtitle: isAdjusting
                            ? 'Modifica solo la aprobación ya registrada.'
                            : 'Confirma la validación comercial del reporte.',
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!isAdjusting) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _TopSummaryChip(
                            icon: Icons.calculate_rounded,
                            label: 'Importe aproximado',
                            value: formatMoney(approximateAmount),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TopSummaryChip(
                            icon: Icons.payments_outlined,
                            label: 'Importe aprobado',
                            value: formatMoney(approvedAmount),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 11,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (isAdjusting) ...[
                                  _TopSummaryChip(
                                    icon: Icons.calculate_rounded,
                                    label: 'Importe aproximado',
                                    value: formatMoney(approximateAmount),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                ContractGlassCard(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _VoucherSectionTitle(
                                        '1. Reporte a relacionar',
                                        icon: Icons.receipt_long_outlined,
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          _DialogInfoChip(
                                            icon: Icons
                                                .confirmation_number_outlined,
                                            label: 'Ticket',
                                            value: widget.row.ticket,
                                          ),
                                          _DialogInfoChip(
                                            icon: Icons.assignment_outlined,
                                            label: 'Remisión',
                                            value: widget.row.remision,
                                          ),
                                          _DialogInfoChip(
                                            icon: Icons.business_outlined,
                                            label: 'Cliente',
                                            value: widget.row.clientName,
                                          ),
                                          _DialogInfoChip(
                                            icon: Icons.inventory_2_outlined,
                                            label: 'Material',
                                            value: widget.row.materialName,
                                          ),
                                          _DialogInfoChip(
                                            icon: Icons.scale_outlined,
                                            label: 'Peso salida',
                                            value:
                                                '${formatDecimal(widget.row.exitWeight)} KG',
                                          ),
                                          _DialogInfoChip(
                                            icon: Icons.sell_outlined,
                                            label: 'Precio base',
                                            value: formatMoney(
                                              widget.row.priceSnapshot,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (isAdjusting) ...[
                                  _TopSummaryChip(
                                    icon: Icons.payments_outlined,
                                    label: 'Importe aprobado',
                                    value: formatMoney(approvedAmount),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                ContractGlassCard(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _VoucherSectionTitle(
                                        '2. Aprobación',
                                        icon: Icons.task_alt_rounded,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        isAdjusting
                                            ? 'Ajusta la aprobación ya relacionada sin tocar la captura operativa base.'
                                            : 'Confirma aquí el peso y precio aprobados para cerrar la relación.',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: kMayoreoMutedInk,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _VoucherFieldShell(
                                        label: 'Peso aprobado',
                                        child: _DialogTextField(
                                          controller: _approvedWeightC,
                                          hintText: 'KG aprobados',
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _VoucherFieldShell(
                                        label: 'Sobreprecio',
                                        child: _DialogTextField(
                                          controller: _overpriceC,
                                          hintText: 'Ajuste por KG',
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _VoucherFieldShell(
                                        label: 'Precio aprobado',
                                        child: Text(
                                          formatMoney(approvedPrice),
                                          style: _voucherInputTextStyle(tokens),
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
                  if (canPrint) const SizedBox(height: 10),
                  if (canPrint)
                    Row(
                      children: [
                        const Spacer(flex: 11),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 12,
                          child: Align(
                            alignment: Alignment.center,
                            child: FilledButton.icon(
                              style: _mayoreoPrimaryButtonStyle().copyWith(
                                minimumSize: const WidgetStatePropertyAll(
                                  Size(210, 48),
                                ),
                              ),
                              onPressed: _print,
                              icon: const Icon(Icons.print_rounded),
                              label: const Text('Imprimir'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Spacer(),
                      OutlinedButton(
                        style: _mayoreoSecondaryButtonStyle(),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        style: _mayoreoPrimaryButtonStyle(),
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.link_rounded),
                        label: Text(
                          isAdjusting ? 'Guardar ajuste' : 'Guardar relación',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopSummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TopSummaryChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: kMayoreoPanelGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: mayoreoAreaTokens.border.withValues(alpha: 0.58),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: mayoreoAreaTokens.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(icon, size: 19, color: mayoreoAreaTokens.primaryStrong),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: kMayoreoMutedInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: kMayoreoInk,
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

class _DialogInfoChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;

  const _DialogInfoChip({this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: mayoreoAreaTokens.border.withValues(alpha: 0.48),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: mayoreoAreaTokens.primaryStrong),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: kMayoreoMutedInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: kMayoreoInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherSectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;

  const _VoucherSectionTitle(this.title, {this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: mayoreoAreaTokens.primaryStrong),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: kMayoreoInk,
          ),
        ),
      ],
    );
  }
}

class _OperationTypeToggle extends StatelessWidget {
  final _MayoreoReportOperationType value;
  final ValueChanged<_MayoreoReportOperationType> onChanged;

  const _OperationTypeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget buildOption(_MayoreoReportOperationType option, IconData icon) {
      final selected = value == option;
      return Expanded(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 140),
            scale: selected ? 1.03 : 1.0,
            child: GestureDetector(
              onTap: () => onChanged(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                constraints: const BoxConstraints(
                  minHeight: _kVoucherInteractiveMinHeight,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? mayoreoAreaTokens.badgeBackground
                      : Colors.white.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? mayoreoAreaTokens.primaryStrong
                        : mayoreoAreaTokens.border.withValues(alpha: 0.82),
                    width: selected ? 1.5 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: mayoreoAreaTokens.glow.withValues(
                              alpha: 0.16,
                            ),
                            blurRadius: 14,
                            offset: const Offset(0, 7),
                          ),
                        ]
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Icon(
                    icon,
                    size: selected ? 18 : 16,
                    color: selected
                        ? kMayoreoInk
                        : mayoreoAreaTokens.primaryStrong,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        buildOption(
          _MayoreoReportOperationType.factura,
          Icons.receipt_long_rounded,
        ),
        const SizedBox(width: 8),
        buildOption(_MayoreoReportOperationType.cheque, Icons.payments_rounded),
      ],
    );
  }
}

class _DialogTitleBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _DialogTitleBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: mayoreoAreaTokens.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.24),
            ),
          ),
          child: Icon(icon, color: mayoreoAreaTokens.primaryStrong),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: kMayoreoInk,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: kMayoreoMutedInk,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VoucherFieldShell extends StatefulWidget {
  final String label;
  final Widget child;

  const _VoucherFieldShell({required this.label, required this.child});

  @override
  State<_VoucherFieldShell> createState() => _VoucherFieldShellState();
}

class _VoucherFieldShellState extends State<_VoucherFieldShell> {
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(minHeight: _kVoucherFieldMinHeight),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: mayoreoAreaTokens.border.withValues(alpha: 0.52),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: kMayoreoMutedInk,
            ),
          ),
          const SizedBox(height: 6),
          widget.child,
        ],
      ),
    );
  }
}

class _DialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const _DialogTextField({required this.controller, required this.hintText});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: _kVoucherInteractiveMinHeight,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextField(
          controller: controller,
          cursorColor: tokens.primaryStrong,
          style: _voucherInputTextStyle(tokens),
          decoration: InputDecoration.collapsed(
            hintText: hintText,
            hintStyle: TextStyle(
              color: tokens.badgeText.withValues(alpha: 0.65),
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerValueField extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _PickerValueField({required this.label, required this.onTap});

  @override
  State<_PickerValueField> createState() => _PickerValueFieldState();
}

class _PickerValueFieldState extends State<_PickerValueField> {
  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: widget.onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: _kVoucherInteractiveMinHeight,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: _voucherInputTextStyle(tokens),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.expand_more_rounded, color: tokens.primaryStrong),
          ],
        ),
      ),
    );
  }
}

class _MayoreoSalesPickerOption<T> {
  final T value;
  final String label;

  const _MayoreoSalesPickerOption({required this.value, required this.label});
}

Future<T?> _showMayoreoSalesSingleSelectDialog<T>(
  BuildContext context, {
  required String title,
  required List<_MayoreoSalesPickerOption<T>> options,
  T? initialValue,
  bool allowClear = false,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      final searchC = TextEditingController();
      final searchFocus = FocusNode();
      final itemFocusNodes = <FocusNode>[];
      String query = '';
      int? focusedIndex;

      void syncNodes(int count) {
        while (itemFocusNodes.length < count) {
          itemFocusNodes.add(FocusNode());
        }
        while (itemFocusNodes.length > count) {
          itemFocusNodes.removeLast().dispose();
        }
      }

      return StatefulBuilder(
        builder: (context, setLocalState) {
          final filtered = options
              .where(
                (option) =>
                    option.label.toLowerCase().contains(query.toLowerCase()),
              )
              .toList(growable: false);
          syncNodes(filtered.length);
          return AreaThemeScope(
            tokens: mayoreoAreaTokens,
            child: Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.of(dialogContext).pop();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                  if (filtered.isEmpty) return KeyEventResult.handled;
                  final index = (focusedIndex ?? 0).clamp(
                    0,
                    filtered.length - 1,
                  );
                  Navigator.of(dialogContext).pop(filtered[index].value);
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
                  child: ContractGlassCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: mayoreoAreaTokens.primaryStrong,
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
                            decoration: contractGlassFieldDecoration(
                              context,
                              hintText: 'Buscar',
                              prefixIcon: const Icon(Icons.search_rounded),
                            ),
                            onChanged: (value) =>
                                setLocalState(() => query = value),
                          ),
                        ),
                        if (allowClear) ...[
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(null),
                              child: Text(
                                'Limpiar selección',
                                style: TextStyle(
                                  color: mayoreoAreaTokens.primaryStrong,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(child: Text('Sin resultados'))
                              : ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) {
                                    final option = filtered[i];
                                    final selected =
                                        option.value == initialValue;
                                    final highlighted = focusedIndex == i;
                                    return Focus(
                                      focusNode: itemFocusNodes[i],
                                      onFocusChange: (hasFocus) {
                                        if (hasFocus) {
                                          setLocalState(() => focusedIndex = i);
                                        } else if (focusedIndex == i) {
                                          setLocalState(
                                            () => focusedIndex = null,
                                          );
                                        }
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
                                          Navigator.of(
                                            dialogContext,
                                          ).pop(option.value);
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.ignored;
                                      },
                                      child: _MayoreoSalesPickerOptionTile(
                                        label: option.label,
                                        selected: selected,
                                        highlighted: highlighted,
                                        onTap: () => Navigator.of(
                                          dialogContext,
                                        ).pop(option.value),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
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

Future<Set<T>?> _showMayoreoSalesMultiSelectDialog<T>(
  BuildContext context, {
  required String title,
  required List<_MayoreoSalesPickerOption<T>> options,
  required Set<T> initialSelected,
}) {
  return showDialog<Set<T>?>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      final searchC = TextEditingController();
      final searchFocus = FocusNode();
      final selected = <T>{...initialSelected};
      String query = '';

      return StatefulBuilder(
        builder: (context, setLocalState) {
          final filtered = options
              .where(
                (option) =>
                    option.label.toLowerCase().contains(query.toLowerCase()),
              )
              .toList(growable: false);
          final allVisibleSelected =
              filtered.isNotEmpty &&
              filtered.every((option) => selected.contains(option.value));

          void applyAndClose() {
            Navigator.of(dialogContext).pop(<T>{...selected});
          }

          return AreaThemeScope(
            tokens: mayoreoAreaTokens,
            child: Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.of(dialogContext).pop();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                  applyAndClose();
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
                  child: ContractGlassCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: mayoreoAreaTokens.primaryStrong,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: searchC,
                          focusNode: searchFocus,
                          autofocus: true,
                          decoration: contractGlassFieldDecoration(
                            context,
                            hintText: 'Buscar',
                            prefixIcon: const Icon(Icons.search_rounded),
                          ),
                          onChanged: (value) =>
                              setLocalState(() => query = value),
                          onSubmitted: (_) => applyAndClose(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setLocalState(() {
                                  if (allVisibleSelected) {
                                    for (final option in filtered) {
                                      selected.remove(option.value);
                                    }
                                  } else {
                                    for (final option in filtered) {
                                      selected.add(option.value);
                                    }
                                  }
                                });
                              },
                              child: Text(
                                allVisibleSelected
                                    ? 'Deseleccionar visibles'
                                    : 'Seleccionar visibles',
                                style: TextStyle(
                                  color: mayoreoAreaTokens.primaryStrong,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${selected.length} seleccionados',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: kMayoreoMutedInk,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(child: Text('Sin resultados'))
                              : ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) {
                                    final option = filtered[i];
                                    final checked = selected.contains(
                                      option.value,
                                    );
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Material(
                                        color: checked
                                            ? mayoreoAreaTokens.badgeBackground
                                                  .withValues(alpha: 0.90)
                                            : Colors.white.withValues(
                                                alpha: 0.44,
                                              ),
                                        borderRadius: BorderRadius.circular(14),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          onTap: () {
                                            setLocalState(() {
                                              if (checked) {
                                                selected.remove(option.value);
                                              } else {
                                                selected.add(option.value);
                                              }
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            child: Row(
                                              children: [
                                                Checkbox(
                                                  value: checked,
                                                  activeColor: mayoreoAreaTokens
                                                      .primaryStrong,
                                                  onChanged: (value) {
                                                    setLocalState(() {
                                                      if (value ?? false) {
                                                        selected.add(
                                                          option.value,
                                                        );
                                                      } else {
                                                        selected.remove(
                                                          option.value,
                                                        );
                                                      }
                                                    });
                                                  },
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    option.label,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: kMayoreoInk,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
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
                            OutlinedButton(
                              style: _mayoreoSecondaryButtonStyle(),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(<T>{}),
                              child: const Text('Limpiar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: _mayoreoPrimaryButtonStyle(),
                              onPressed: applyAndClose,
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
          );
        },
      );
    },
  );
}

class _MayoreoSalesPickerOptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  const _MayoreoSalesPickerOptionTile({
    required this.label,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? mayoreoAreaTokens.badgeBackground.withValues(alpha: 0.90)
        : highlighted
        ? mayoreoAreaTokens.surfaceTint.withValues(alpha: 0.66)
        : Colors.white.withValues(alpha: 0.44);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: kMayoreoInk,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: mayoreoAreaTokens.primaryStrong,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MayoreoSalesDateRangeResult {
  final DateTime? from;
  final DateTime? to;

  const _MayoreoSalesDateRangeResult({required this.from, required this.to});
}

Future<DateTime?> _showMayoreoSalesSingleDateDialog(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required String title,
}) async {
  final range = await _showMayoreoSalesDateRangeDialog(
    context,
    title: title,
    initialFrom: initialDate,
    initialTo: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    singleDateMode: true,
  );
  return range?.from;
}

Future<_MayoreoSalesDateRangeResult?> _showMayoreoSalesDateRangeDialog(
  BuildContext context, {
  required String title,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? initialFrom,
  DateTime? initialTo,
  bool singleDateMode = false,
}) {
  return showDialog<_MayoreoSalesDateRangeResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      DateTime displayMonth = DateTime(
        (initialFrom ?? initialTo ?? firstDate).year,
        (initialFrom ?? initialTo ?? firstDate).month,
      );
      DateTime? start = initialFrom == null
          ? null
          : DateUtils.dateOnly(initialFrom);
      DateTime? end = initialTo == null ? null : DateUtils.dateOnly(initialTo);
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
            final previewEnd = singleDateMode ? start : (end ?? hover);

            bool withinBounds(DateTime day) {
              final d = dateOnly(day);
              return !d.isBefore(dateOnly(firstDate)) &&
                  !d.isAfter(dateOnly(lastDate));
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

            _MayoreoSalesDateRangeResult? buildResult() {
              if (start == null) return null;
              final s = dateOnly(start!);
              final e = dateOnly(singleDateMode ? start! : (end ?? start!));
              final from = s.isBefore(e) ? s : e;
              final to = s.isBefore(e) ? e : s;
              return _MayoreoSalesDateRangeResult(
                from: from,
                to: singleDateMode ? from : to,
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
                      title,
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
                              '${_mayoreoSalesMonthNameEs(monthFirst.month)} ${monthFirst.year}',
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
                            (!singleDateMode &&
                                end != null &&
                                isSameDay(day, end!));
                        final inRange = inPreviewRange(day) && allowed;
                        return MouseRegion(
                          onEnter: (_) {
                            if (!singleDateMode &&
                                start != null &&
                                end == null &&
                                allowed) {
                              setLocalState(() => hover = dateOnly(day));
                            }
                          },
                          child: GestureDetector(
                            onTap: !allowed
                                ? null
                                : () {
                                    final picked = dateOnly(day);
                                    setLocalState(() {
                                      if (singleDateMode) {
                                        start = picked;
                                        end = picked;
                                        hover = null;
                                      } else if (start == null || end != null) {
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
                      singleDateMode
                          ? (start == null
                                ? 'Selecciona fecha'
                                : _formatDate(start!))
                          : start == null
                          ? 'Selecciona fecha inicial'
                          : end == null
                          ? 'Selecciona fecha final'
                          : '${_formatDate(start!)} - ${_formatDate(end!)}',
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
                        if (!singleDateMode) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: _mayoreoSecondaryButtonStyle(),
                            onPressed: () => Navigator.pop(
                              dialogContext,
                              const _MayoreoSalesDateRangeResult(
                                from: null,
                                to: null,
                              ),
                            ),
                            child: const Text('Limpiar'),
                          ),
                        ],
                        const SizedBox(width: 8),
                        FilledButton(
                          style: _mayoreoPrimaryButtonStyle(),
                          onPressed: start == null
                              ? null
                              : () =>
                                    Navigator.pop(dialogContext, buildResult()),
                          child: Text(singleDateMode ? 'Aceptar' : 'Aplicar'),
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

TextStyle _voucherInputTextStyle(ContractAreaTokens tokens) =>
    TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: kMayoreoInk);

class _MayoreoSalesClient {
  final String id;
  final String name;

  const _MayoreoSalesClient({required this.id, required this.name});
}

class _MayoreoSalesMaterial {
  final String id;
  final String name;

  const _MayoreoSalesMaterial({required this.id, required this.name});
}

class _MayoreoSalesCatalogPrice {
  final String clientId;
  final String materialId;
  final double finalPrice;

  const _MayoreoSalesCatalogPrice({
    required this.clientId,
    required this.materialId,
    required this.finalPrice,
  });
}

Future<bool?> _showMayoreoDeleteConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String impactLabel,
  String confirmLabel = 'Eliminar',
  String subtitle = 'Confirma la baja del registro visible.',
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      return AreaThemeScope(
        tokens: mayoreoAreaTokens,
        child: Theme(
          data: _mayoreoMaterialTheme(dialogContext),
          child: ContractConfirmDialogKeyHandler(
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
            child: Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.of(dialogContext).pop(false);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                  Navigator.of(dialogContext).pop(true);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: ContractDialogShell(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 446),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: mayoreoAreaTokens.badgeBackground,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: mayoreoAreaTokens.primaryStrong
                                      .withValues(alpha: 0.18),
                                ),
                              ),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: mayoreoAreaTokens.primaryStrong,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                      color: kMayoreoInk,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: kMayoreoMutedInk,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          message,
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.35,
                            color: kMayoreoMutedInk,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: mayoreoAreaTokens.badgeBackground.withValues(
                              alpha: 0.94,
                            ),
                            border: Border.all(
                              color: mayoreoAreaTokens.primaryStrong.withValues(
                                alpha: 0.14,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: mayoreoAreaTokens.primaryStrong,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  impactLabel,
                                  style: const TextStyle(
                                    fontSize: 12.8,
                                    fontWeight: FontWeight.w800,
                                    color: kMayoreoInk,
                                  ),
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
                              style: _mayoreoSecondaryButtonStyle(),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: _mayoreoPrimaryButtonStyle(),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: Text(confirmLabel),
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
        ),
      );
    },
  );
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
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return mayoreoAreaTokens.badgeBackground;
          }
          return Colors.white.withValues(alpha: 0.72);
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? kMayoreoInk
              : mayoreoAreaTokens.primaryStrong;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          return BorderSide(
            color: states.contains(WidgetState.selected)
                ? mayoreoAreaTokens.primary
                : mayoreoAreaTokens.border.withValues(alpha: 0.82),
          );
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(
          mayoreoAreaTokens.primaryStrong,
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return mayoreoAreaTokens.badgeBackground.withValues(alpha: 0.72);
          }
          return Colors.transparent;
        }),
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
    disabledForegroundColor: mayoreoAreaTokens.badgeText.withValues(
      alpha: 0.48,
    ),
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
    disabledForegroundColor: mayoreoAreaTokens.badgeText.withValues(
      alpha: 0.48,
    ),
    side: BorderSide(color: mayoreoAreaTokens.border.withValues(alpha: 0.8)),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

ButtonStyle _mayoreoPagerButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: mayoreoAreaTokens.primaryStrong,
    backgroundColor: Colors.white.withValues(alpha: 0.72),
    side: BorderSide(color: mayoreoAreaTokens.border.withValues(alpha: 0.86)),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

class _MayoreoSalesReportDraft {
  final String ticket;
  final DateTime date;
  final String clientId;
  final String remision;
  final String materialId;
  final double exitWeight;
  final double priceSnapshot;
  final double? approvedWeight;
  final double? approvedPrice;
  final double approvedAmount;
  final _MayoreoReportOperationType operationType;
  final String observations;

  const _MayoreoSalesReportDraft({
    required this.ticket,
    required this.date,
    required this.clientId,
    required this.remision,
    required this.materialId,
    required this.exitWeight,
    required this.priceSnapshot,
    required this.approvedWeight,
    required this.approvedPrice,
    required this.approvedAmount,
    required this.operationType,
    required this.observations,
  });
}

class _MayoreoRelationResult {
  final double approvedWeight;
  final double approvedPrice;
  final double approvedAmount;

  const _MayoreoRelationResult({
    required this.approvedWeight,
    required this.approvedPrice,
    required this.approvedAmount,
  });
}

class _MayoreoSalesReportRow {
  final String id;
  final String ticket;
  final DateTime date;
  final String clientId;
  final String clientName;
  final String remision;
  final String materialId;
  final String materialName;
  final double exitWeight;
  final double priceSnapshot;
  final double? approvedWeight;
  final double? approvedPrice;
  final double approvedAmount;
  final _MayoreoReportOperationType operationType;
  final String observations;

  const _MayoreoSalesReportRow({
    required this.id,
    required this.ticket,
    required this.date,
    required this.clientId,
    required this.clientName,
    required this.remision,
    required this.materialId,
    required this.materialName,
    required this.exitWeight,
    required this.priceSnapshot,
    required this.approvedWeight,
    required this.approvedPrice,
    required this.approvedAmount,
    required this.operationType,
    required this.observations,
  });

  bool get isRelated =>
      approvedWeight != null && approvedPrice != null && approvedWeight! > 0;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'ticket': ticket,
      'date': date.toIso8601String(),
      'clientId': clientId,
      'clientName': clientName,
      'remision': remision,
      'materialId': materialId,
      'materialName': materialName,
      'exitWeight': exitWeight,
      'priceSnapshot': priceSnapshot,
      'approvedWeight': approvedWeight,
      'approvedPrice': approvedPrice,
      'approvedAmount': approvedAmount,
      'operationType': operationType.name,
      'observations': observations,
    };
  }

  Map<String, dynamic> toSupabase() {
    return <String, dynamic>{
      'id': id,
      'ticket': ticket,
      'sale_date': date.toIso8601String(),
      'client_id': clientId,
      'client_name_snapshot': clientName,
      'remision': remision,
      'material_id': materialId,
      'material_name_snapshot': materialName,
      'exit_weight': exitWeight,
      'price_snapshot': priceSnapshot,
      'approved_weight': approvedWeight,
      'approved_price': approvedPrice,
      'approved_amount': approvedAmount,
      'operation_type': operationType.name,
      'observations': observations.isEmpty ? null : observations,
    };
  }

  factory _MayoreoSalesReportRow.fromSupabase(Map<String, dynamic> json) {
    final operationName = (json['operation_type'] as String?) ?? 'factura';
    return _MayoreoSalesReportRow(
      id: (json['id'] as String?) ?? '',
      ticket: (json['ticket'] as String?) ?? '',
      date:
          DateTime.tryParse((json['sale_date'] as String?) ?? '') ??
          DateTime.now(),
      clientId: (json['client_id'] as String?) ?? '',
      clientName: (json['client_name_snapshot'] as String?) ?? '',
      remision: (json['remision'] as String?) ?? '',
      materialId: (json['material_id'] as String?) ?? '',
      materialName: (json['material_name_snapshot'] as String?) ?? '',
      exitWeight: ((json['exit_weight'] as num?) ?? 0).toDouble(),
      priceSnapshot: ((json['price_snapshot'] as num?) ?? 0).toDouble(),
      approvedWeight: (json['approved_weight'] as num?)?.toDouble(),
      approvedPrice: (json['approved_price'] as num?)?.toDouble(),
      approvedAmount: ((json['approved_amount'] as num?) ?? 0).toDouble(),
      operationType: _MayoreoReportOperationType.values.firstWhere(
        (item) => item.name == operationName,
        orElse: () => _MayoreoReportOperationType.factura,
      ),
      observations: (json['observations'] as String?) ?? '',
    );
  }

  _MayoreoSalesReportRow copyWith({
    String? ticket,
    DateTime? date,
    String? clientId,
    String? clientName,
    String? remision,
    String? materialId,
    String? materialName,
    double? exitWeight,
    double? priceSnapshot,
    Object? approvedWeight = _mayoreoSalesReportNoChange,
    Object? approvedPrice = _mayoreoSalesReportNoChange,
    Object? approvedAmount = _mayoreoSalesReportNoChange,
    _MayoreoReportOperationType? operationType,
    String? observations,
  }) {
    return _MayoreoSalesReportRow(
      id: id,
      ticket: ticket ?? this.ticket,
      date: date ?? this.date,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      remision: remision ?? this.remision,
      materialId: materialId ?? this.materialId,
      materialName: materialName ?? this.materialName,
      exitWeight: exitWeight ?? this.exitWeight,
      priceSnapshot: priceSnapshot ?? this.priceSnapshot,
      approvedWeight: identical(approvedWeight, _mayoreoSalesReportNoChange)
          ? this.approvedWeight
          : approvedWeight as double?,
      approvedPrice: identical(approvedPrice, _mayoreoSalesReportNoChange)
          ? this.approvedPrice
          : approvedPrice as double?,
      approvedAmount: identical(approvedAmount, _mayoreoSalesReportNoChange)
          ? this.approvedAmount
          : approvedAmount as double,
      operationType: operationType ?? this.operationType,
      observations: observations ?? this.observations,
    );
  }
}

const Object _mayoreoSalesReportNoChange = Object();

String _operationTypeLabel(_MayoreoReportOperationType type) {
  switch (type) {
    case _MayoreoReportOperationType.factura:
      return 'FACTURA';
    case _MayoreoReportOperationType.cheque:
      return 'CHEQUE';
  }
}

double? _parseDouble(String raw) {
  final normalized = raw.trim().replaceAll(',', '');
  return double.tryParse(normalized);
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}

String _mayoreoSalesMonthNameEs(int month) {
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

bool _isSeedReportRow(_MayoreoSalesReportRow row) {
  return row.id.startsWith('rep_');
}

class _MayoreoSalesReportPageMemory {
  final List<_MayoreoSalesReportRow> rows;
  final String? selectedRowId;
  final List<String> clientFilterIds;
  final List<String> materialFilterIds;
  final List<String> ticketFilters;
  final List<String> remisionFilters;
  final DateTime? dateFilterFrom;
  final DateTime? dateFilterTo;
  final List<String> operationFilters;
  final List<String> statusFilters;
  final List<String> selectedRowIds;
  final int currentPage;
  final int pageSize;
  final String? selectionAnchorRowId;

  const _MayoreoSalesReportPageMemory({
    required this.rows,
    required this.selectedRowId,
    required this.clientFilterIds,
    required this.materialFilterIds,
    required this.ticketFilters,
    required this.remisionFilters,
    required this.dateFilterFrom,
    required this.dateFilterTo,
    required this.operationFilters,
    required this.statusFilters,
    required this.selectedRowIds,
    required this.currentPage,
    required this.pageSize,
    required this.selectionAnchorRowId,
  });

  static _MayoreoSalesReportPageMemory? current;
}
