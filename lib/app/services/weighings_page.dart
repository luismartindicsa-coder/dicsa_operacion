import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/dashboard_page.dart';
import '../dashboard/general_dashboard_page.dart';
import '../maintenance/maintenance_page.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/page_routes.dart';
import 'inventory_page.dart';
import 'services_page.dart';
import 'services_shell.dart';
import 'warehouse_page.dart';

const double _kActionsW = 76;
const double _kColGap = 6;
const int _kDateFlex = 14;
const int _kTicketFlex = 20;
const int _kProviderFlex = 30;
const int _kPriceFlex = 16;

const Color _kFilterAccent = Color(0xFF4F8E8C);
const Color _kFilterAccentSoft = Color(0xFFE2EEEC);
const Color _kGlassMenuBg = Color(0xE6EAF2F9);

class WeighingsPage extends StatefulWidget {
  const WeighingsPage({super.key});

  @override
  State<WeighingsPage> createState() => _WeighingsPageState();
}

class _WeighingsPageState extends State<WeighingsPage>
    with WidgetsBindingObserver {
  final SupabaseClient _supa = Supabase.instance.client;

  bool _loading = true;
  bool _refreshingRows = false;
  bool _bulkDeleting = false;

  final TextEditingController _draftTicketC = TextEditingController();
  final TextEditingController _draftProviderC = TextEditingController();
  final TextEditingController _draftPriceC = TextEditingController();
  final FocusNode _draftTicketFocusNode = FocusNode(
    debugLabel: 'pesadas_draft_ticket',
  );
  final FocusNode _draftProviderFocusNode = FocusNode(
    debugLabel: 'pesadas_draft_provider',
  );
  final FocusNode _draftPriceFocusNode = FocusNode(
    debugLabel: 'pesadas_draft_price',
  );
  DateTime? _draftDate;

  final FocusNode _insertFocusNode = FocusNode(debugLabel: 'pesadas_insert');
  final FocusNode _rowsFocusNode = FocusNode(debugLabel: 'pesadas_rows_focus');
  final ScrollController _rowsScrollController = ScrollController();
  final GlobalKey _rowsViewportKey = GlobalKey(debugLabel: 'pesadas_rows_view');

  final Map<String, GlobalKey<_WeighingDataRowState>> _rowKeys =
      <String, GlobalKey<_WeighingDataRowState>>{};

  List<Map<String, dynamic>> _rows = [];
  String _rowsSignature = '';

  String? _selectedRowId;
  final Set<String> _bulkSelectedRowIds = <String>{};

  int _activeInsertColumn = 0;
  static const int _insertColumnCount = 4;
  int _activeGridColumn = 0;

  DateTimeRange? _fechaFilter;
  Set<String> _ticketFilter = <String>{};
  Set<String> _proveedorFilter = <String>{};
  Set<String> _precioFilter = <String>{};

  int _currentPage = 0;
  int _pageSize = 40;

  Timer? _autoRefreshTimer;
  RealtimeChannel? _realtime;
  DateTime? _lastBackgroundRefreshAt;
  static const Duration _backgroundRefreshMinGap = Duration(seconds: 10);

  bool _marqueeActive = false;
  bool _marqueeAdditive = false;
  Set<String> _marqueeBaseSelection = <String>{};
  Offset? _marqueeStartLocal;
  Offset? _marqueePointerLocal;
  Offset? _marqueeStartContent;
  Offset? _marqueeCurrentContent;
  Timer? _marqueeAutoScrollTimer;
  double _marqueeAutoScrollVelocity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draftDate = null;
    unawaited(_loadRows());
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _realtime?.unsubscribe();
    _marqueeAutoScrollTimer?.cancel();
    _draftTicketC.dispose();
    _draftProviderC.dispose();
    _draftPriceC.dispose();
    _draftTicketFocusNode.dispose();
    _draftProviderFocusNode.dispose();
    _draftPriceFocusNode.dispose();
    _insertFocusNode.dispose();
    _rowsFocusNode.dispose();
    _rowsScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestBackgroundRefresh(force: true);
    }
  }

  List<Map<String, dynamic>> get _filteredRows {
    return _rows.where((row) {
      final fecha = _dateFromAny(row['fecha']);
      if (_fechaFilter != null && fecha != null) {
        final d = DateUtils.dateOnly(fecha);
        if (d.isBefore(_fechaFilter!.start) || d.isAfter(_fechaFilter!.end)) {
          return false;
        }
      }

      if (_ticketFilter.isNotEmpty) {
        final text = (row['ticket'] ?? '').toString().trim();
        if (!_ticketFilter.contains(text)) return false;
      }

      if (_proveedorFilter.isNotEmpty) {
        final text = (row['proveedor'] ?? '').toString().trim();
        if (!_proveedorFilter.contains(text)) return false;
      }

      if (_precioFilter.isNotEmpty) {
        final text = _fmtMoney(_num(row['precio']) ?? 0);
        if (!_precioFilter.contains(text)) return false;
      }

      return true;
    }).toList();
  }

  int get _totalPages {
    final total = _filteredRows.length;
    if (total <= 0) return 1;
    return (total / _pageSize).ceil();
  }

  List<Map<String, dynamic>> get _visibleRows {
    final rows = _filteredRows;
    if (rows.isEmpty) return const [];
    final maxStart = ((rows.length - 1) ~/ _pageSize) * _pageSize;
    final safeStart = (_currentPage * _pageSize).clamp(0, maxStart);
    final end = (safeStart + _pageSize).clamp(0, rows.length);
    return rows.sublist(safeStart, end);
  }

  int get _selectedCount {
    final ids = _currentSelectionIds();
    return ids.length;
  }

  Set<String> _currentSelectionIds() {
    final ids = <String>{..._bulkSelectedRowIds};
    if (_selectedRowId != null) ids.add(_selectedRowId!);
    return ids;
  }

  bool get _hasExplicitMultiSelection {
    return _currentSelectionIds().length > 1;
  }

  bool get _hasDraftChanges {
    return _draftDate != null ||
        _draftTicketC.text.trim().isNotEmpty ||
        _draftProviderC.text.trim().isNotEmpty ||
        _draftPriceC.text.trim().isNotEmpty;
  }

  bool get _hasRowsInEditingState {
    for (final key in _rowKeys.values) {
      if (key.currentState?.isEditing ?? false) return true;
    }
    return false;
  }

  bool get _shouldDeferBackgroundRefresh =>
      _hasDraftChanges ||
      _hasRowsInEditingState ||
      _bulkDeleting ||
      _isEditableTextFocused();

  void _setupAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 120), (_) {
      _requestBackgroundRefresh();
    });

    _realtime?.unsubscribe();
    _realtime = _supa
        .channel('pesadas-auto-refresh')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pesadas',
          callback: (_) => _requestBackgroundRefresh(),
        )
        .subscribe();
  }

  void _requestBackgroundRefresh({bool force = false}) {
    if (!mounted || _refreshingRows) return;
    if (!force && _shouldDeferBackgroundRefresh) return;
    if (!force && _lastBackgroundRefreshAt != null) {
      final elapsed = DateTime.now().difference(_lastBackgroundRefreshAt!);
      if (elapsed < _backgroundRefreshMinGap) return;
    }

    _refreshingRows = true;
    unawaited(
      _loadRows(showLoader: false, onlyApplyIfChanged: true).whenComplete(() {
        _refreshingRows = false;
        _lastBackgroundRefreshAt = DateTime.now();
      }),
    );
  }

  Future<void> _loadRows({
    bool showLoader = true,
    bool onlyApplyIfChanged = false,
  }) async {
    if (showLoader && mounted) setState(() => _loading = true);
    try {
      final result = await _supa
          .from('pesadas')
          .select('id, fecha, ticket, proveedor, precio, created_at')
          .order('fecha', ascending: false)
          .order('created_at', ascending: false);

      final nextRows = (result as List).cast<Map<String, dynamic>>();
      final nextSig = _rowsSignatureOf(nextRows);
      if (onlyApplyIfChanged && nextSig == _rowsSignature) return;

      if (!mounted) return;
      setState(() {
        _rows = nextRows;
        _rowsSignature = nextSig;
        _bulkSelectedRowIds.removeWhere(
          (id) => !_rows.any((r) => (r['id'] as String?) == id),
        );
        if (_selectedRowId != null &&
            !_rows.any((r) => r['id'] == _selectedRowId)) {
          _selectedRowId = null;
        }
        _clampCurrentPage();
      });
    } catch (e) {
      _toast('No se pudo cargar pesadas: $e');
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  String _rowsSignatureOf(List<Map<String, dynamic>> rows) => '$rows';

  void _clampCurrentPage() {
    final maxPage = (_totalPages - 1).clamp(0, 999999);
    if (_currentPage > maxPage) _currentPage = maxPage;
  }

  Future<void> _insertDraft() async {
    if (_draftDate == null) {
      _toast('Fecha es obligatoria');
      return;
    }

    final ticket = _draftTicketC.text.trim();
    final proveedor = _normalizeProvider(_draftProviderC.text);
    final precio = _parseMoney(_draftPriceC.text);

    if (ticket.isEmpty) {
      _toast('Ticket es obligatorio');
      return;
    }
    if (proveedor.isEmpty || !_providerPattern.hasMatch(proveedor)) {
      _toast('Proveedor debe ir en MAYUSCULAS y sin caracteres especiales');
      return;
    }
    if (precio == null || precio < 0) {
      _toast('Precio invalido');
      return;
    }

    await _supa.from('pesadas').insert({
      'fecha': _fmtDbDate(_draftDate!),
      'ticket': ticket,
      'proveedor': proveedor,
      'precio': precio,
    });

    _toast('Pesada agregada');
    setState(() {
      _draftDate = null;
      _draftTicketC.clear();
      _draftProviderC.clear();
      _draftPriceC.clear();
      _activeInsertColumn = 0;
    });
    await _loadRows(showLoader: false);
    if (!mounted) return;
    _insertFocusNode.requestFocus();
  }

  Future<void> _updateRow(String id, Map<String, dynamic> patch) async {
    await _supa.from('pesadas').update(patch).eq('id', id);
    await _loadRows(showLoader: false);
  }

  Future<void> _deleteRow(String id) async {
    await _supa.from('pesadas').delete().eq('id', id);
    if (!mounted) return;
    setState(() {
      if (_selectedRowId == id) _selectedRowId = null;
      _bulkSelectedRowIds.remove(id);
    });
    _toast('Pesada eliminada');
    await _loadRows(showLoader: false);
  }

  Future<void> _deleteSelectedRows() async {
    final ids = _currentSelectionIds();
    if (ids.isEmpty || _bulkDeleting) return;
    final ok = await _showGlassConfirmDialog(
      context,
      title: 'Eliminar pesadas',
      content: ids.length == 1
          ? '¿Seguro que quieres eliminar el registro seleccionado?'
          : '¿Seguro que quieres eliminar ${_fmtCountInt(ids.length)} registros?',
      confirmText: 'Eliminar',
    );
    if (ok != true) return;

    setState(() => _bulkDeleting = true);
    try {
      await _supa.from('pesadas').delete().inFilter('id', ids.toList());
      if (!mounted) return;
      setState(() {
        _selectedRowId = null;
        _bulkSelectedRowIds.clear();
      });
      _toast(ids.length == 1 ? 'Pesada eliminada' : 'Pesadas eliminadas');
      await _loadRows(showLoader: false);
    } finally {
      if (mounted) setState(() => _bulkDeleting = false);
    }
  }

  void _setActiveInsertColumn(int value, {bool requestFocus = true}) {
    setState(() {
      _activeInsertColumn =
          ((value % _insertColumnCount) + _insertColumnCount) %
          _insertColumnCount;
      _selectedRowId = null;
      _bulkSelectedRowIds.clear();
    });
    if (!requestFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (_activeInsertColumn) {
        case 1:
          FocusScope.of(context).requestFocus(_draftTicketFocusNode);
          break;
        case 2:
          FocusScope.of(context).requestFocus(_draftProviderFocusNode);
          break;
        case 3:
          FocusScope.of(context).requestFocus(_draftPriceFocusNode);
          break;
        default:
          FocusManager.instance.primaryFocus?.unfocus();
          _insertFocusNode.requestFocus();
      }
    });
  }

  void _moveInsertColumn(int delta) =>
      _setActiveInsertColumn(_activeInsertColumn + delta);

  void _activateInsertTextField(int column, FocusNode focusNode) {
    _setActiveInsertColumn(column, requestFocus: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!focusNode.hasFocus) {
        FocusScope.of(context).requestFocus(focusNode);
      }
    });
  }

  void _clearActiveInsertCell() {
    setState(() {
      switch (_activeInsertColumn) {
        case 0:
          _draftDate = null;
          return;
        case 1:
          _draftTicketC.clear();
          return;
        case 2:
          _draftProviderC.clear();
          return;
        case 3:
          _draftPriceC.clear();
          return;
      }
    });
  }

  Future<void> _activateInsertCellFromKeyboard() async {
    switch (_activeInsertColumn) {
      case 0:
        final picked = await _pickInlineDate(context, _draftDate);
        if (!mounted || picked == null) return;
        setState(() => _draftDate = picked);
        return;
      case 1:
        _setActiveInsertColumn(1);
        return;
      case 2:
        _setActiveInsertColumn(2);
        return;
      case 3:
        _setActiveInsertColumn(3);
        return;
    }
  }

  void _focusGridFromInsert() {
    final firstVisibleId = _visibleRows.isEmpty
        ? null
        : _visibleRows.first['id'] as String;
    setState(() {
      _activeGridColumn = _activeInsertColumn.clamp(
        0,
        _gridColumnLabels.length - 1,
      );
      if (firstVisibleId != null) {
        _selectedRowId = firstVisibleId;
        _bulkSelectedRowIds.clear();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rowsFocusNode.requestFocus();
      if (firstVisibleId != null) {
        _ensureRowVisible(firstVisibleId);
      }
    });
  }

  void _focusInsertRowFromGrid() {
    setState(() {
      _activeInsertColumn = _activeGridColumn.clamp(0, _insertColumnCount - 1);
      _selectedRowId = null;
      _bulkSelectedRowIds.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (_activeInsertColumn) {
        case 1:
          FocusScope.of(context).requestFocus(_draftTicketFocusNode);
          break;
        case 2:
          FocusScope.of(context).requestFocus(_draftProviderFocusNode);
          break;
        case 3:
          FocusScope.of(context).requestFocus(_draftPriceFocusNode);
          break;
        default:
          FocusManager.instance.primaryFocus?.unfocus();
          _insertFocusNode.requestFocus();
      }
    });
  }

  GlobalKey<_WeighingDataRowState> _rowKeyFor(String id) =>
      _rowKeys.putIfAbsent(id, () => GlobalKey<_WeighingDataRowState>());

  bool _isCtrlOrCmdPressed() {
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

  bool _isSelectionExtendPressed() =>
      _isCtrlOrCmdPressed() || _isShiftPressed();

  bool _isEditableTextFocused() {
    final focused = FocusManager.instance.primaryFocus;
    final ctx = focused?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _caretAtStart(TextEditingController controller, FocusNode focusNode) {
    if (!focusNode.hasFocus) return false;
    final selection = controller.selection;
    return selection.isValid &&
        selection.isCollapsed &&
        selection.baseOffset <= 0;
  }

  bool _caretAtEnd(TextEditingController controller, FocusNode focusNode) {
    if (!focusNode.hasFocus) return false;
    final selection = controller.selection;
    return selection.isValid &&
        selection.isCollapsed &&
        selection.baseOffset >= controller.text.length;
  }

  double get _rowsScrollOffset =>
      _rowsScrollController.hasClients ? _rowsScrollController.offset : 0;

  Offset _localToContent(Offset local) =>
      Offset(local.dx, local.dy + _rowsScrollOffset);

  Rect _marqueeRectContent() {
    final start = _marqueeStartContent ?? Offset.zero;
    final current = _marqueeCurrentContent ?? start;
    return Rect.fromPoints(start, current);
  }

  Rect _marqueeRectForPaint() =>
      _marqueeRectContent().shift(Offset(0, -_rowsScrollOffset));

  Rect _clampRectToViewport(Rect rectViewport) {
    final viewportContext = _rowsViewportKey.currentContext;
    final viewportBox = viewportContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null) return rectViewport;
    final width = viewportBox.size.width;
    final height = viewportBox.size.height;
    final left = rectViewport.left.clamp(0.0, width).toDouble();
    final top = rectViewport.top.clamp(0.0, height).toDouble();
    final right = rectViewport.right.clamp(0.0, width).toDouble();
    final bottom = rectViewport.bottom.clamp(0.0, height).toDouble();
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Set<String> _marqueeIntersectedIds(Rect rectContent) {
    final viewportContext = _rowsViewportKey.currentContext;
    final viewportBox = viewportContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null) return const <String>{};

    final scrollOffset = _rowsScrollOffset;
    final hits = <String>{};
    for (final row in _visibleRows) {
      final id = row['id'] as String;
      final rowContext = _rowKeyFor(id).currentContext;
      final rowBox = rowContext?.findRenderObject() as RenderBox?;
      if (rowBox == null || !rowBox.hasSize) continue;
      final rowTopLeftGlobal = rowBox.localToGlobal(Offset.zero);
      final rowTopLeftViewport = viewportBox.globalToLocal(rowTopLeftGlobal);
      final viewportRect = Rect.fromLTWH(
        rowTopLeftViewport.dx,
        rowTopLeftViewport.dy,
        rowBox.size.width,
        rowBox.size.height,
      );
      final rowRectContent = viewportRect.shift(Offset(0, scrollOffset));
      if (rowRectContent.overlaps(rectContent)) hits.add(id);
    }
    return hits;
  }

  void _applyMarqueeSelection() {
    if (!_marqueeActive) return;
    final rect = _marqueeRectContent();
    final hit = _marqueeIntersectedIds(rect);
    final next = _marqueeAdditive ? ({..._marqueeBaseSelection, ...hit}) : hit;
    if (!mounted) return;
    setState(() {
      _bulkSelectedRowIds
        ..clear()
        ..addAll(next);
      if (next.isEmpty) {
        _selectedRowId = null;
      } else if (_selectedRowId == null || !next.contains(_selectedRowId)) {
        _selectedRowId = next.first;
      }
    });
  }

  void _syncMarqueeAutoScroll() {
    final viewportContext = _rowsViewportKey.currentContext;
    final viewportBox = viewportContext?.findRenderObject() as RenderBox?;
    if (!_marqueeActive ||
        _marqueePointerLocal == null ||
        viewportBox == null ||
        !_rowsScrollController.hasClients) {
      _marqueeAutoScrollVelocity = 0;
      _marqueeAutoScrollTimer?.cancel();
      _marqueeAutoScrollTimer = null;
      return;
    }

    const edge = 64.0;
    const maxVelocity = 18.0;
    final h = viewportBox.size.height;
    final y = _marqueePointerLocal!.dy;
    if (y < edge) {
      _marqueeAutoScrollVelocity = -((edge - y) / edge) * maxVelocity;
    } else if (y > h - edge) {
      _marqueeAutoScrollVelocity = ((y - (h - edge)) / edge) * maxVelocity;
    } else {
      _marqueeAutoScrollVelocity = 0;
    }

    if (_marqueeAutoScrollVelocity == 0) {
      _marqueeAutoScrollTimer?.cancel();
      _marqueeAutoScrollTimer = null;
      return;
    }
    _marqueeAutoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _tickMarqueeAutoScroll(),
    );
  }

  void _tickMarqueeAutoScroll() {
    if (!_marqueeActive ||
        _marqueeAutoScrollVelocity == 0 ||
        !_rowsScrollController.hasClients) {
      _marqueeAutoScrollTimer?.cancel();
      _marqueeAutoScrollTimer = null;
      return;
    }
    final pos = _rowsScrollController.position;
    final next = (pos.pixels + _marqueeAutoScrollVelocity).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if (next == pos.pixels) return;
    _rowsScrollController.jumpTo(next.toDouble());
    if (_marqueePointerLocal != null) {
      _marqueeCurrentContent = _localToContent(_marqueePointerLocal!);
      _applyMarqueeSelection();
      if (mounted) setState(() {});
    }
  }

  void _startMarqueeSelection(Offset local) {
    _marqueeStartLocal = local;
    _marqueePointerLocal = local;
    _marqueeStartContent = _localToContent(local);
    _marqueeCurrentContent = _marqueeStartContent;
    _marqueeAdditive = _isSelectionExtendPressed();
    _marqueeBaseSelection = _currentSelectionIds();
    _marqueeActive = false;
  }

  void _updateMarqueeSelection(Offset local) {
    if (_marqueeStartLocal == null) return;
    _marqueePointerLocal = local;
    _marqueeCurrentContent = _localToContent(local);
    final shouldActivate = (local - _marqueeStartLocal!).distance > 6;
    if (!shouldActivate && !_marqueeActive) return;
    if (!_marqueeActive && mounted) {
      setState(() => _marqueeActive = true);
    }
    _applyMarqueeSelection();
    _syncMarqueeAutoScroll();
  }

  void _endMarqueeSelection() {
    _marqueeAutoScrollVelocity = 0;
    _marqueeAutoScrollTimer?.cancel();
    _marqueeAutoScrollTimer = null;
    _marqueeStartLocal = null;
    _marqueePointerLocal = null;
    _marqueeStartContent = null;
    _marqueeCurrentContent = null;
    _marqueeAdditive = false;
    _marqueeBaseSelection = <String>{};
    if (_marqueeActive && mounted) {
      setState(() => _marqueeActive = false);
    } else {
      _marqueeActive = false;
    }
  }

  void _selectRow(
    String id, {
    bool focusTable = true,
    bool allowToggle = false,
    bool ensureVisible = true,
    bool additive = false,
    bool additiveToggle = true,
  }) {
    if (additive) {
      setState(() {
        final previouslySelectedId = _selectedRowId;
        if (_bulkSelectedRowIds.isEmpty &&
            previouslySelectedId != null &&
            previouslySelectedId != id) {
          _bulkSelectedRowIds.add(previouslySelectedId);
        }
        if (_bulkSelectedRowIds.contains(id) && additiveToggle) {
          _bulkSelectedRowIds.remove(id);
          if (_selectedRowId == id) {
            _selectedRowId = _bulkSelectedRowIds.isEmpty
                ? null
                : _bulkSelectedRowIds.last;
          }
        } else {
          _bulkSelectedRowIds.add(id);
          _selectedRowId = id;
        }
      });
      if (focusTable) _rowsFocusNode.requestFocus();
      if (ensureVisible) _ensureRowVisible(id);
      return;
    }

    if (allowToggle && _selectedRowId == id) {
      setState(() {
        _selectedRowId = null;
        _bulkSelectedRowIds.clear();
      });
      if (focusTable) _rowsFocusNode.requestFocus();
      return;
    }

    setState(() {
      _selectedRowId = id;
      _bulkSelectedRowIds.clear();
    });
    if (focusTable) _rowsFocusNode.requestFocus();
    if (ensureVisible) _ensureRowVisible(id);
  }

  void _ensureRowVisible(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rowContext = _rowKeyFor(id).currentContext;
      if (rowContext == null) return;
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _moveSelectedRow(int delta) {
    final rows = _visibleRows;
    if (rows.isEmpty) return;

    final currentIndex = _selectedRowId == null
        ? -1
        : rows.indexWhere((r) => r['id'] == _selectedRowId);
    int nextIndex;
    if (currentIndex == -1) {
      nextIndex = delta >= 0 ? 0 : rows.length - 1;
    } else {
      final rawIndex = currentIndex + delta;
      nextIndex = ((rawIndex % rows.length) + rows.length) % rows.length;
    }

    _selectRow(rows[nextIndex]['id'] as String, focusTable: false);
  }

  void _extendSelectionWithArrow(int delta) {
    final rows = _visibleRows;
    if (rows.isEmpty) return;
    final currentIndex = _selectedRowId == null
        ? -1
        : rows.indexWhere((r) => r['id'] == _selectedRowId);
    if (currentIndex != -1) {
      _bulkSelectedRowIds.add(rows[currentIndex]['id'] as String);
    }

    int nextIndex;
    if (currentIndex == -1) {
      nextIndex = delta >= 0 ? 0 : rows.length - 1;
    } else {
      final rawIndex = currentIndex + delta;
      nextIndex = ((rawIndex % rows.length) + rows.length) % rows.length;
    }
    _selectRow(
      rows[nextIndex]['id'] as String,
      focusTable: false,
      additive: true,
      additiveToggle: false,
    );
  }

  List<_WeighingDataRowState> _selectedRowStates() {
    if (!_hasExplicitMultiSelection) {
      final id = _selectedRowId;
      if (id == null) return const [];
      final state = _rowKeys[id]?.currentState;
      if (state == null) return const [];
      return [state];
    }

    final ids = <String>[];
    if (_selectedRowId != null) ids.add(_selectedRowId!);
    for (final row in _visibleRows) {
      final id = row['id'] as String;
      if (_currentSelectionIds().contains(id) && !ids.contains(id)) ids.add(id);
    }
    return ids
        .map((id) => _rowKeys[id]?.currentState)
        .whereType<_WeighingDataRowState>()
        .toList();
  }

  _WeighingDataRowState? _selectedRowState() {
    final id = _selectedRowId;
    if (id == null) return null;
    return _rowKeys[id]?.currentState;
  }

  void _handleEnterOnSelectedRow() {
    final states = _selectedRowStates();
    if (states.isEmpty) return;
    final anyNotEditing = states.any((s) => !s.isEditing);
    if (anyNotEditing) {
      setState(() => _activeGridColumn = 0);
      for (final s in states) {
        s.startEditingFromKeyboard();
      }
      return;
    }
    unawaited(Future.wait(states.map((s) => s.saveFromKeyboard())));
  }

  void _handleEscapeOnSelectedRow() {
    final states = _selectedRowStates();
    if (states.isNotEmpty && states.any((s) => s.isEditing)) {
      for (final s in states) {
        s.cancelEditingFromKeyboard();
      }
      return;
    }

    if (_selectedRowId != null || _bulkSelectedRowIds.isNotEmpty) {
      setState(() {
        _selectedRowId = null;
        _bulkSelectedRowIds.clear();
      });
    }
  }

  void _handleDeleteOnSelectedRow() {
    if (_hasExplicitMultiSelection) {
      unawaited(_deleteSelectedRows());
      return;
    }
    final states = _selectedRowStates();
    if (states.isEmpty) return;
    unawaited(states.first.deleteWithConfirmation());
  }

  List<MapEntry<String, String>> _rowContextActions() {
    final states = _selectedRowStates();
    final multi = _hasExplicitMultiSelection;
    final anyEditing = states.any((s) => s.isEditing);
    if (multi) {
      return [
        if (!anyEditing) const MapEntry('edit', 'EDITAR SELECCION'),
        if (anyEditing) ...const [
          MapEntry('save', 'GUARDAR SELECCION'),
          MapEntry('cancel', 'CANCELAR SELECCION'),
        ],
        const MapEntry('delete', 'ELIMINAR SELECCION'),
      ];
    }
    return [
      if (!anyEditing) const MapEntry('edit', 'EDITAR'),
      if (anyEditing) ...const [
        MapEntry('save', 'ACTUALIZAR'),
        MapEntry('cancel', 'CANCELAR'),
      ],
      const MapEntry('delete', 'ELIMINAR'),
    ];
  }

  Future<String?> _showRowsContextMenu(Offset globalPosition) {
    final actions = _rowContextActions();
    const menuTextStyle = TextStyle(
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
      color: Color(0xFF223D5A),
    );
    final media = MediaQuery.of(context).size;

    return showMenu<String>(
      context: context,
      color: _kGlassMenuBg,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        media.width - globalPosition.dx,
        media.height - globalPosition.dy,
      ),
      items: [
        for (var i = 0; i < actions.length; i++) ...[
          PopupMenuItem<String>(
            value: actions[i].key,
            child: Text(
              actions[i].value,
              style: actions[i].key == 'delete'
                  ? menuTextStyle.copyWith(color: const Color(0xFF8A1F1F))
                  : menuTextStyle,
            ),
          ),
          if (i != actions.length - 1) const PopupMenuDivider(height: 1),
        ],
      ],
    );
  }

  Future<void> _openRowsContextMenuAt(
    Offset globalPosition, {
    String? rowId,
  }) async {
    if (rowId != null && !_currentSelectionIds().contains(rowId)) {
      _selectRow(
        rowId,
        allowToggle: false,
        additive: false,
        ensureVisible: false,
      );
    }

    final choice = await _showRowsContextMenu(globalPosition);
    if (choice == null || !mounted) return;

    final states = _selectedRowStates();
    switch (choice) {
      case 'edit':
        if (states.isEmpty) return;
        setState(() => _activeGridColumn = 0);
        for (final s in states) {
          s.startEditingFromKeyboard();
        }
        return;
      case 'save':
        if (states.isEmpty) return;
        await Future.wait(states.map((s) => s.saveFromKeyboard()));
        return;
      case 'cancel':
        if (states.isEmpty) return;
        for (final s in states) {
          s.cancelEditingFromKeyboard();
        }
        return;
      case 'delete':
        _handleDeleteOnSelectedRow();
        return;
      default:
        return;
    }
  }

  Future<void> _openColumnFilter(String columnId, String label) async {
    if (columnId == 'fecha') {
      final result = await _showDateRangeFilterDialog(
        context,
        label: label,
        bounds: DateTimeRange(
          start: DateTime(2020, 1, 1),
          end: DateTime(2100, 12, 31),
        ),
        initialRange: _fechaFilter,
      );
      if (!mounted || result == null) return;
      setState(() {
        if (result.clear) {
          _fechaFilter = null;
        } else {
          _fechaFilter = result.range;
        }
        _currentPage = 0;
      });
      return;
    }

    final initial = switch (columnId) {
      'ticket' => _ticketFilter,
      'proveedor' => _proveedorFilter,
      'precio' => _precioFilter,
      _ => <String>{},
    };

    final result = await showDialog<_WeighingsFilterDialogResult>(
      context: context,
      builder: (dialogContext) {
        final localSelected = <String>{...initial};
        String localSearch = '';

        return StatefulBuilder(
          builder: (_, setLocalState) {
            final options = _columnDistinctValues(
              columnId,
              search: localSearch,
            );
            final allVisibleSelected =
                options.isNotEmpty && options.every(localSelected.contains);

            void applyAndClose() {
              Navigator.pop(
                dialogContext,
                _WeighingsFilterDialogResult(selectedValues: localSelected),
              );
            }

            return Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                final key = event.logicalKey;
                if (key == LogicalKeyboardKey.escape) {
                  Navigator.pop(dialogContext);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.enter ||
                    key == LogicalKeyboardKey.numpadEnter) {
                  applyAndClose();
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      width: 420,
                      constraints: const BoxConstraints(maxHeight: 560),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      decoration: _filterDialogDecoration(),
                      child: FocusScope(
                        autofocus: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filtro: $label',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0B2B2B),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              onChanged: (v) =>
                                  setLocalState(() => localSearch = v),
                              onSubmitted: (_) => applyAndClose(),
                              decoration: _glassFieldDecoration(
                                hintText: 'Buscar',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF2A4B49),
                                  ),
                                  onPressed: () {
                                    setLocalState(() {
                                      if (allVisibleSelected) {
                                        localSelected.removeAll(options);
                                      } else {
                                        localSelected.addAll(options);
                                      }
                                    });
                                  },
                                  child: Text(
                                    allVisibleSelected
                                        ? 'Deseleccionar visibles'
                                        : 'Seleccionar visibles',
                                  ),
                                ),
                                const Spacer(),
                                Text('${localSelected.length} seleccionados'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: options.isEmpty
                                  ? const Center(
                                      child: Text('Sin valores para mostrar'),
                                    )
                                  : ListView.builder(
                                      itemCount: options.length,
                                      itemBuilder: (_, i) {
                                        final value = options[i];
                                        final checked = localSelected.contains(
                                          value,
                                        );
                                        return CheckboxListTile(
                                          dense: true,
                                          value: checked,
                                          activeColor: const Color(0xFF2D7A73),
                                          checkColor: Colors.white,
                                          hoverColor: const Color(
                                            0xFFE9F7EE,
                                          ).withValues(alpha: 0.95),
                                          title: Text(
                                            value,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          onChanged: (v) {
                                            setLocalState(() {
                                              if (v ?? false) {
                                                localSelected.add(value);
                                              } else {
                                                localSelected.remove(value);
                                              }
                                            });
                                          },
                                        );
                                      },
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  style: _filterOutlinedButtonStyle(),
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Cancelar'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  style: _filterOutlinedButtonStyle(),
                                  onPressed: () => Navigator.pop(
                                    dialogContext,
                                    const _WeighingsFilterDialogResult(
                                      selectedValues: <String>{},
                                    ),
                                  ),
                                  child: const Text('Limpiar'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  style: _filterFilledButtonStyle(),
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
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() {
      switch (columnId) {
        case 'ticket':
          _ticketFilter = result.selectedValues;
          break;
        case 'proveedor':
          _proveedorFilter = result.selectedValues;
          break;
        case 'precio':
          _precioFilter = result.selectedValues;
          break;
        default:
          break;
      }
      _currentPage = 0;
      final visibleIds = _filteredRows.map((r) => r['id'] as String).toSet();
      _bulkSelectedRowIds.removeWhere((id) => !visibleIds.contains(id));
      if (!visibleIds.contains(_selectedRowId)) {
        _selectedRowId = null;
      }
    });
  }

  List<String> _columnDistinctValues(String columnId, {String search = ''}) {
    final normalizedSearch = search.trim().toLowerCase();
    final values = <String>{};
    for (final row in _rows) {
      final raw = switch (columnId) {
        'ticket' => (row['ticket'] ?? '').toString().trim(),
        'proveedor' => (row['proveedor'] ?? '').toString().trim(),
        'precio' => _fmtMoney(_num(row['precio']) ?? 0),
        _ => '',
      };
      if (raw.isEmpty) continue;
      if (normalizedSearch.isNotEmpty &&
          !raw.toLowerCase().contains(normalizedSearch)) {
        continue;
      }
      values.add(raw);
    }
    final sorted = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  bool _hasActiveFilter(String columnId) {
    return switch (columnId) {
      'fecha' => _fechaFilter != null,
      'ticket' => _ticketFilter.isNotEmpty,
      'proveedor' => _proveedorFilter.isNotEmpty,
      'precio' => _precioFilter.isNotEmpty,
      _ => false,
    };
  }

  Future<void> _exportCsvToClipboard() async {
    final rows = _filteredRows;
    final sb = StringBuffer('FECHA,TICKET,PROVEEDOR,PRECIO\n');
    for (final row in rows) {
      sb.writeln(
        '${_fmtDbDate(_dateFromAny(row['fecha']) ?? DateTime.now())},'
        '${_csvEscape((row['ticket'] ?? '').toString())},'
        '${_csvEscape((row['proveedor'] ?? '').toString())},'
        '${(_num(row['precio']) ?? 0).toStringAsFixed(2)}',
      );
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (!mounted) return;
    _toast('CSV copiado (${_fmtCountInt(rows.length)} filas)');
  }

  Future<void> _logout() async {
    final ok = await _showGlassConfirmDialog(
      context,
      title: 'Cerrar sesión',
      content: '¿Seguro que deseas cerrar tu sesión?',
      confirmText: 'Cerrar sesión',
    );
    if (ok != true) return;
    if (!mounted) return;
    await signOutAndRouteToLogin(context);
  }

  Future<void> _goToDashboard() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!AuthAccess.canAccessDashboard(profile)) {
      _toast('Acceso no autorizado');
      return;
    }

    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pushReplacement(
        appPageRoute(
          page: const DashboardPage(instantOpen: true),
          duration: const Duration(milliseconds: 420),
          reverseDuration: const Duration(milliseconds: 360),
        ),
      );
      return;
    }
    nav.push(
      appPageRoute(
        page: const DashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToGeneralDashboard() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!AuthAccess.canAccessGeneralDashboard(profile)) {
      _toast('Acceso no autorizado');
      return;
    }

    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pushReplacement(
        appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
      );
      return;
    }
    nav.push(appPageRoute(page: const GeneralDashboardPage(instantOpen: true)));
  }

  Future<void> _goToEntriesAndOutputs() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const InventoryPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToProduction() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const InventoryProductionPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToInventory() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const InventoryStockPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToServices() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const ServicesPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToMaintenance() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const MaintenancePage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToWarehouse() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const WarehousePage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedRows = _rows
        .where(
          (row) =>
              _currentSelectionIds().contains((row['id'] ?? '').toString()),
        )
        .toList();
    final selectedTotal = selectedRows.fold<double>(
      0,
      (sum, row) => sum + (_num(row['precio']) ?? 0),
    );
    final selectedAvg = selectedRows.isEmpty
        ? 0.0
        : selectedTotal / selectedRows.length;

    return ServicesShell(
      headerTitle: 'Pesadas',
      activeOverlayModule: ServicesOverlayNavModule.pesadas,
      onLogout: _logout,
      onGoToGeneralDashboard: _goToGeneralDashboard,
      onGoToOperacion: _goToDashboard,
      onGoToEntriesAndOutputs: _goToEntriesAndOutputs,
      onGoToProduction: _goToProduction,
      onGoToInventory: _goToInventory,
      onGoToServices: _goToServices,
      onGoToWeighings: () async {},
      onGoToMaintenance: _goToMaintenance,
      onGoToWarehouse: _goToWarehouse,
      topContent: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
        child: OperationalGlassToolbarPanel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final actions = FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      style: _actionOutlinedButtonStyle(),
                      onPressed: _exportCsvToClipboard,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Descargar CSV'),
                    ),
                    if (_selectedCount > 0) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: _actionFilledButtonStyle(),
                        onPressed: _bulkDeleting ? null : _deleteSelectedRows,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(
                          'Eliminar (${_fmtCountInt(_selectedCount)})',
                        ),
                      ),
                    ],
                  ],
                ),
              );

              final info = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_fmtCountInt(_selectedCount)} seleccionadas',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_selectedCount > 0)
                    Text(
                      'Suma: ${_fmtMoney(selectedTotal)} · Promedio: ${_fmtMoney(selectedAvg)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2A4B49),
                      ),
                    ),
                  if (_selectedRowState()?.isEditing ?? false)
                    Text(
                      'Celda: ${_gridColumnLabels[_activeGridColumn]} · Space',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2A4B49),
                      ),
                    ),
                ],
              );

              if (constraints.maxWidth < 980) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: actions),
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.centerRight, child: info),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: actions,
                    ),
                  ),
                  const SizedBox(width: 8),
                  info,
                ],
              );
            },
          ),
        ),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _HeaderRow(
                    hasActiveFilter: _hasActiveFilter,
                    onOpenFilter: _openColumnFilter,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildInlineInsertRow(),
                ),
                Expanded(
                  child: Focus(
                    focusNode: _rowsFocusNode,
                    onKeyEvent: (_, event) {
                      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                        return KeyEventResult.ignored;
                      }
                      final key = event.logicalKey;
                      final editingText = _isEditableTextFocused();
                      final extendSelection = _isSelectionExtendPressed();
                      final editingAnyRow =
                          _selectedRowState()?.isEditing ?? false;
                      final keyboardCellMode = editingAnyRow;

                      if (editingText) {
                        if (key == LogicalKeyboardKey.enter ||
                            key == LogicalKeyboardKey.numpadEnter) {
                          _handleEnterOnSelectedRow();
                          return KeyEventResult.handled;
                        }
                        if (key == LogicalKeyboardKey.escape) {
                          _handleEscapeOnSelectedRow();
                          return KeyEventResult.handled;
                        }
                        if (key == LogicalKeyboardKey.delete ||
                            key == LogicalKeyboardKey.backspace ||
                            key == LogicalKeyboardKey.arrowLeft ||
                            key == LogicalKeyboardKey.arrowRight ||
                            key == LogicalKeyboardKey.arrowUp ||
                            key == LogicalKeyboardKey.arrowDown ||
                            key == LogicalKeyboardKey.space) {
                          return KeyEventResult.ignored;
                        }
                      }

                      if (key == LogicalKeyboardKey.arrowUp) {
                        if (extendSelection) {
                          _extendSelectionWithArrow(-1);
                        } else if (!_hasExplicitMultiSelection &&
                            _selectedRowId != null &&
                            _visibleRows.isNotEmpty &&
                            _selectedRowId == _visibleRows.first['id']) {
                          _focusInsertRowFromGrid();
                        } else if (keyboardCellMode) {
                          _moveSelectedRow(-1);
                        } else {
                          _moveSelectedRow(-1);
                        }
                        return KeyEventResult.handled;
                      }
                      if (key == LogicalKeyboardKey.arrowDown) {
                        if (extendSelection) {
                          _extendSelectionWithArrow(1);
                        } else if (keyboardCellMode) {
                          _moveSelectedRow(1);
                        } else {
                          _moveSelectedRow(1);
                        }
                        return KeyEventResult.handled;
                      }
                      if (key == LogicalKeyboardKey.arrowLeft &&
                          keyboardCellMode) {
                        setState(() {
                          final raw = _activeGridColumn - 1;
                          _activeGridColumn = ((raw % 4) + 4) % 4;
                        });
                        return KeyEventResult.handled;
                      }
                      if (key == LogicalKeyboardKey.arrowRight &&
                          keyboardCellMode) {
                        setState(() {
                          final raw = _activeGridColumn + 1;
                          _activeGridColumn = ((raw % 4) + 4) % 4;
                        });
                        return KeyEventResult.handled;
                      }
                      if (key == LogicalKeyboardKey.space && keyboardCellMode) {
                        final s = _selectedRowState();
                        if (s != null) {
                          unawaited(s.activateGridCell(_activeGridColumn));
                          return KeyEventResult.handled;
                        }
                      }
                      if (key == LogicalKeyboardKey.enter ||
                          key == LogicalKeyboardKey.numpadEnter) {
                        _handleEnterOnSelectedRow();
                        return KeyEventResult.handled;
                      }
                      if (key == LogicalKeyboardKey.escape) {
                        _handleEscapeOnSelectedRow();
                        return KeyEventResult.handled;
                      }
                      if (key == LogicalKeyboardKey.delete ||
                          key == LogicalKeyboardKey.backspace) {
                        _handleDeleteOnSelectedRow();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: _visibleRows.isEmpty
                        ? const Center(
                            child: Text(
                              'NO HAY PESADAS TODAVIA',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          )
                        : Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (event) {
                              if (!_rowsFocusNode.hasFocus) {
                                _rowsFocusNode.requestFocus();
                              }
                              _startMarqueeSelection(event.localPosition);
                            },
                            onPointerMove: (event) =>
                                _updateMarqueeSelection(event.localPosition),
                            onPointerUp: (_) => _endMarqueeSelection(),
                            onPointerCancel: (_) => _endMarqueeSelection(),
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onSecondaryTapDown: (details) {
                                if (_selectedCount <= 0) return;
                                unawaited(
                                  _openRowsContextMenuAt(
                                    details.globalPosition,
                                  ),
                                );
                              },
                              child: Stack(
                                key: _rowsViewportKey,
                                children: [
                                  Positioned.fill(
                                    child: AbsorbPointer(
                                      absorbing: _marqueeActive,
                                      child: ListView.builder(
                                        controller: _rowsScrollController,
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          0,
                                          12,
                                          20,
                                        ),
                                        itemCount: _visibleRows.length,
                                        itemBuilder: (_, i) {
                                          final row = _visibleRows[i];
                                          final rowId = row['id'] as String;
                                          return _WeighingDataRow(
                                            key: _rowKeyFor(rowId),
                                            row: row,
                                            parseDate: _dateFromAny,
                                            fmtDateDb: _fmtDbDate,
                                            fmtDateUi: _fmtUiDate,
                                            onDelete: _deleteRow,
                                            onUpdate: _updateRow,
                                            isSelected: _selectedRowId == rowId,
                                            isChecked: _bulkSelectedRowIds
                                                .contains(rowId),
                                            activeGridColumn: _activeGridColumn,
                                            showRowActions: true,
                                            onOpenContextMenu: (position) =>
                                                _openRowsContextMenuAt(
                                                  position,
                                                  rowId: rowId,
                                                ),
                                            onSelect: (additive) => _selectRow(
                                              rowId,
                                              allowToggle: false,
                                              additive: additive,
                                              ensureVisible: false,
                                            ),
                                            onActivateColumn: (columnIndex) {
                                              _selectRow(
                                                rowId,
                                                allowToggle: false,
                                                additive: false,
                                                ensureVisible: false,
                                              );
                                              setState(
                                                () => _activeGridColumn =
                                                    columnIndex,
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  if (_marqueeActive)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: CustomPaint(
                                          painter: _MarqueeSelectionPainter(
                                            rect: _clampRectToViewport(
                                              _marqueeRectForPaint(),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: _buildPager(),
                ),
              ],
            ),
    );
  }

  Widget _buildInlineInsertRow() {
    return Card(
      elevation: 0.4,
      color: const Color(0xFFE7F1F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFF3C8DCC).withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            Widget insertCellFrame(int columnIndex, Widget child) {
              final active = _activeInsertColumn == columnIndex;
              return DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF0B72FF).withValues(alpha: 0.80)
                        : Colors.transparent,
                    width: active ? 1.15 : 1.0,
                  ),
                ),
                child: child,
              );
            }

            return Focus(
              focusNode: _insertFocusNode,
              autofocus: false,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                final key = event.logicalKey;
                final editingText = _isEditableTextFocused();
                if (key == LogicalKeyboardKey.arrowLeft) {
                  if (editingText) {
                    if (_draftTicketFocusNode.hasFocus &&
                        !_caretAtStart(_draftTicketC, _draftTicketFocusNode)) {
                      return KeyEventResult.ignored;
                    }
                    if (_draftProviderFocusNode.hasFocus &&
                        !_caretAtStart(
                          _draftProviderC,
                          _draftProviderFocusNode,
                        )) {
                      return KeyEventResult.ignored;
                    }
                    if (_draftPriceFocusNode.hasFocus &&
                        !_caretAtStart(_draftPriceC, _draftPriceFocusNode)) {
                      return KeyEventResult.ignored;
                    }
                  }
                  _moveInsertColumn(-1);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowRight) {
                  if (editingText) {
                    if (_draftTicketFocusNode.hasFocus &&
                        !_caretAtEnd(_draftTicketC, _draftTicketFocusNode)) {
                      return KeyEventResult.ignored;
                    }
                    if (_draftProviderFocusNode.hasFocus &&
                        !_caretAtEnd(
                          _draftProviderC,
                          _draftProviderFocusNode,
                        )) {
                      return KeyEventResult.ignored;
                    }
                    if (_draftPriceFocusNode.hasFocus &&
                        !_caretAtEnd(_draftPriceC, _draftPriceFocusNode)) {
                      return KeyEventResult.ignored;
                    }
                  }
                  _moveInsertColumn(1);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowUp) {
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowDown) {
                  _focusGridFromInsert();
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.space) {
                  if (editingText) return KeyEventResult.ignored;
                  unawaited(_activateInsertCellFromKeyboard());
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.delete ||
                    key == LogicalKeyboardKey.backspace) {
                  if (editingText) return KeyEventResult.ignored;
                  _clearActiveInsertCell();
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.escape) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  _insertFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.enter ||
                    key == LogicalKeyboardKey.numpadEnter) {
                  if (editingText) return KeyEventResult.ignored;
                  unawaited(_insertDraft());
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: SizedBox(
                width: constraints.maxWidth,
                child: Row(
                  children: [
                    Expanded(
                      flex: _kDateFlex,
                      child: insertCellFrame(
                        0,
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            _setActiveInsertColumn(0, requestFocus: false);
                            final d = await _pickInlineDate(
                              context,
                              _draftDate,
                            );
                            if (!mounted || d == null) return;
                            setState(() => _draftDate = d);
                          },
                          child: InputDecorator(
                            decoration: _glassFieldDecoration(),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _FitText(
                                    _draftDate == null
                                        ? '—'
                                        : _fmtUiDate(_draftDate!),
                                  ),
                                ),
                                const Icon(Icons.calendar_month, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: _kColGap),
                    Expanded(
                      flex: _kTicketFlex,
                      child: insertCellFrame(
                        1,
                        TextField(
                          controller: _draftTicketC,
                          focusNode: _draftTicketFocusNode,
                          decoration: _glassFieldDecoration(
                            hintText: 'Ticket / folio',
                          ),
                          onTap: () => _activateInsertTextField(
                            1,
                            _draftTicketFocusNode,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: _kColGap),
                    Expanded(
                      flex: _kProviderFlex,
                      child: insertCellFrame(
                        2,
                        TextField(
                          controller: _draftProviderC,
                          focusNode: _draftProviderFocusNode,
                          inputFormatters: const [_ProviderInputFormatter()],
                          decoration: _glassFieldDecoration(
                            hintText: 'Proveedor',
                          ),
                          onTap: () => _activateInsertTextField(
                            2,
                            _draftProviderFocusNode,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: _kColGap),
                    Expanded(
                      flex: _kPriceFlex,
                      child: insertCellFrame(
                        3,
                        TextField(
                          controller: _draftPriceC,
                          focusNode: _draftPriceFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: const [_MoneyInputFormatter()],
                          decoration: _glassFieldDecoration(hintText: 'Precio'),
                          onTap: () =>
                              _activateInsertTextField(3, _draftPriceFocusNode),
                        ),
                      ),
                    ),
                    const SizedBox(width: _kColGap),
                    SizedBox(
                      width: _kActionsW,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Tooltip(
                          message: 'AGREGAR',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _insertDraft,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF19C37D,
                                ).withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.52),
                                ),
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPager() {
    return Card(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              style: _actionOutlinedButtonStyle(),
              onPressed: _currentPage > 0
                  ? () => setState(() => _currentPage--)
                  : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Anterior'),
            ),
            Text(
              'Página ${_fmtCountInt(_currentPage + 1)} de ${_fmtCountInt(_totalPages)}',
            ),
            OutlinedButton.icon(
              style: _actionOutlinedButtonStyle(),
              onPressed: _currentPage < _totalPages - 1
                  ? () => setState(() => _currentPage++)
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Siguiente'),
            ),
            const Text('Filas/pág:'),
            SizedBox(
              width: 90,
              child: DropdownButtonFormField<int>(
                initialValue: _pageSize,
                isDense: true,
                decoration: _glassFieldDecoration(),
                items: const [40, 80, 120]
                    .map(
                      (s) => DropdownMenuItem<int>(value: s, child: Text('$s')),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _pageSize = v;
                    _currentPage = 0;
                    _clampCurrentPage();
                  });
                },
              ),
            ),
            Text('Total: ${_fmtCountInt(_filteredRows.length)}'),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final bool Function(String columnId) hasActiveFilter;
  final void Function(String columnId, String label) onOpenFilter;

  const _HeaderRow({required this.hasActiveFilter, required this.onOpenFilter});

  @override
  Widget build(BuildContext context) {
    const TextStyle s = TextStyle(fontSize: 12, fontWeight: FontWeight.w800);
    return Card(
      elevation: 0,
      color: Colors.black.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              child: Row(
                children: [
                  Expanded(
                    flex: _kDateFlex,
                    child: _HCell(
                      'FECHA',
                      s,
                      active: hasActiveFilter('fecha'),
                      onFilter: () => onOpenFilter('fecha', 'FECHA'),
                    ),
                  ),
                  const SizedBox(width: _kColGap),
                  Expanded(
                    flex: _kTicketFlex,
                    child: _HCell(
                      'TICKET',
                      s,
                      active: hasActiveFilter('ticket'),
                      onFilter: () => onOpenFilter('ticket', 'TICKET'),
                    ),
                  ),
                  const SizedBox(width: _kColGap),
                  Expanded(
                    flex: _kProviderFlex,
                    child: _HCell(
                      'PROVEEDOR',
                      s,
                      active: hasActiveFilter('proveedor'),
                      onFilter: () => onOpenFilter('proveedor', 'PROVEEDOR'),
                    ),
                  ),
                  const SizedBox(width: _kColGap),
                  Expanded(
                    flex: _kPriceFlex,
                    child: _HCell(
                      'PRECIO',
                      s,
                      active: hasActiveFilter('precio'),
                      onFilter: () => onOpenFilter('precio', 'PRECIO'),
                    ),
                  ),
                  const SizedBox(width: _kColGap),
                  const SizedBox(width: _kActionsW),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HCell extends StatelessWidget {
  final String t;
  final TextStyle s;
  final bool active;
  final VoidCallback onFilter;

  const _HCell(this.t, this.s, {required this.active, required this.onFilter});

  @override
  Widget build(BuildContext context) {
    return _HCellExpand(t, s, active: active, onFilter: onFilter);
  }
}

class _HCellExpand extends StatelessWidget {
  final String t;
  final TextStyle s;
  final bool active;
  final VoidCallback onFilter;

  const _HCellExpand(
    this.t,
    this.s, {
    required this.active,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onFilter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: active
                  ? _kFilterAccent
                  : _kFilterAccentSoft.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active
                    ? _kFilterAccent.withValues(alpha: 0.55)
                    : const Color(0xFF0B2B2B).withValues(alpha: 0.15),
              ),
            ),
            child: Icon(
              active ? Icons.filter_alt : Icons.filter_alt_outlined,
              size: 15,
              color: active ? Colors.white : const Color(0xFF2A4B49),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(t, style: s, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _WeighingDataRow extends StatefulWidget {
  final Map<String, dynamic> row;
  final DateTime? Function(dynamic) parseDate;
  final String Function(DateTime) fmtDateDb;
  final String Function(DateTime) fmtDateUi;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(String id, Map<String, dynamic> patch) onUpdate;
  final bool isSelected;
  final bool isChecked;
  final int activeGridColumn;
  final bool showRowActions;
  final ValueChanged<Offset>? onOpenContextMenu;
  final ValueChanged<bool> onSelect;
  final ValueChanged<int> onActivateColumn;

  const _WeighingDataRow({
    super.key,
    required this.row,
    required this.parseDate,
    required this.fmtDateDb,
    required this.fmtDateUi,
    required this.onDelete,
    required this.onUpdate,
    required this.isSelected,
    required this.isChecked,
    required this.activeGridColumn,
    required this.showRowActions,
    this.onOpenContextMenu,
    required this.onSelect,
    required this.onActivateColumn,
  });

  @override
  State<_WeighingDataRow> createState() => _WeighingDataRowState();
}

class _WeighingDataRowState extends State<_WeighingDataRow> {
  bool _editing = false;
  bool _hovering = false;
  int? _hoveredEditableColumn;
  bool _hoverActionsButton = false;

  late DateTime _fecha;
  late TextEditingController _ticket;
  late TextEditingController _proveedor;
  late TextEditingController _precio;

  final FocusNode _ticketFocus = FocusNode();
  final FocusNode _proveedorFocus = FocusNode();
  final FocusNode _precioFocus = FocusNode();

  String get id => widget.row['id'] as String;
  bool get isEditing => _editing;

  @override
  void initState() {
    super.initState();
    _syncFromRow();
  }

  @override
  void dispose() {
    _ticket.dispose();
    _proveedor.dispose();
    _precio.dispose();
    _ticketFocus.dispose();
    _proveedorFocus.dispose();
    _precioFocus.dispose();
    super.dispose();
  }

  void _syncFromRow() {
    _fecha =
        widget.parseDate(widget.row['fecha']) ??
        DateUtils.dateOnly(DateTime.now());
    _ticket = TextEditingController(
      text: (widget.row['ticket'] ?? '').toString(),
    );
    _proveedor = TextEditingController(
      text: (widget.row['proveedor'] ?? '').toString(),
    );
    _precio = TextEditingController(
      text: (_num(widget.row['precio']) ?? 0).toStringAsFixed(2),
    );
  }

  void _setEditing(bool v) => setState(() => _editing = v);

  void startEditingFromKeyboard() {
    if (_editing) return;
    _setEditing(true);
  }

  void cancelEditingFromKeyboard() {
    if (!_editing) return;
    setState(() {
      _ticket.dispose();
      _proveedor.dispose();
      _precio.dispose();
      _syncFromRow();
      _editing = false;
    });
  }

  Future<void> saveFromKeyboard() async {
    if (!_editing) return;
    await _save();
  }

  Future<void> deleteWithConfirmation() async {
    final ok = await _showGlassConfirmDialog(
      context,
      title: 'Eliminar pesada',
      content: '¿Seguro que quieres eliminarla?',
      confirmText: 'Eliminar',
    );
    if (!mounted) return;
    if (ok == true) {
      await widget.onDelete(id);
    }
  }

  Future<void> activateGridCell(int columnIndex) async {
    if (!_editing) return;
    switch (columnIndex) {
      case 0:
        await _pickFecha();
        return;
      case 1:
        _ticketFocus.requestFocus();
        return;
      case 2:
        _proveedorFocus.requestFocus();
        return;
      case 3:
        _precioFocus.requestFocus();
        return;
      default:
        return;
    }
  }

  Future<void> _pickFecha() async {
    final picked = await _showGlassDatePickerDialog(
      context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _fecha = DateUtils.dateOnly(picked));
    }
  }

  Future<void> _save({bool keepEditing = false}) async {
    final ticket = _ticket.text.trim();
    final proveedor = _normalizeProvider(_proveedor.text);
    final precio = _parseMoney(_precio.text);

    if (ticket.isEmpty) {
      _toastInline('Ticket es obligatorio');
      return;
    }
    if (proveedor.isEmpty || !_providerPattern.hasMatch(proveedor)) {
      _toastInline('Proveedor invalido');
      return;
    }
    if (precio == null || precio < 0) {
      _toastInline('Precio invalido');
      return;
    }

    await widget.onUpdate(id, {
      'fecha': widget.fmtDateDb(_fecha),
      'ticket': ticket,
      'proveedor': proveedor,
      'precio': precio,
    });
    _setEditing(keepEditing);
  }

  void _toastInline(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _isAdditiveSelectionPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  @override
  Widget build(BuildContext context) {
    final isPrimarySelected = widget.isSelected;
    final isMultiSelected = widget.isChecked;
    final hasSelection = isPrimarySelected || isMultiSelected;
    final hoverOnly = _hovering && !hasSelection;
    final highlighted = hasSelection || _hovering;
    final rowBg = _editing
        ? const Color(0xFFDCEAF7).withValues(alpha: 0.82)
        : hasSelection
        ? const Color(
            0xFF00A3FF,
          ).withValues(alpha: isPrimarySelected ? 0.16 : 0.13)
        : hoverOnly
        ? const Color(0xFFE9F7EE)
        : Colors.white;

    Widget gridCellFrame(int columnIndex, Widget child) {
      final active =
          _editing &&
          widget.isSelected &&
          widget.activeGridColumn == columnIndex;
      if (!active) return child;
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF0B72FF).withValues(alpha: 0.85),
            width: 1.2,
          ),
        ),
        child: child,
      );
    }

    void previewEditableCellTap(int col) {
      if (_isAdditiveSelectionPressed()) {
        widget.onSelect(true);
        return;
      }
      widget.onSelect(false);
      widget.onActivateColumn(col);
    }

    void enterEditingFromPointer(int col) {
      if (_isAdditiveSelectionPressed()) {
        widget.onSelect(true);
        return;
      }
      widget.onSelect(false);
      widget.onActivateColumn(col);
      if (!_editing) {
        setState(() => _editing = true);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(activateGridCell(col));
      });
    }

    Widget previewEditableCell({required int col, required Widget child}) {
      final hovered = !_editing && _hoveredEditableColumn == col;
      final top = hasSelection
          ? const Color(0xFFD9E8F6).withValues(alpha: 0.78)
          : const Color(0xFFE5F2EC).withValues(alpha: 0.78);
      final bottom = hasSelection
          ? const Color(0xFFCCE0F2).withValues(alpha: 0.64)
          : const Color(0xFFD4E7DE).withValues(alpha: 0.64);
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (_editing) return;
          if (_hoveredEditableColumn != col) {
            setState(() => _hoveredEditableColumn = col);
          }
        },
        onExit: (_) {
          if (_hoveredEditableColumn == col) {
            setState(() => _hoveredEditableColumn = null);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: hovered
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [top, bottom],
                  )
                : null,
            boxShadow: hovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF8FB4D6).withValues(alpha: 0.20),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : const [],
          ),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              if (event.buttons != kPrimaryMouseButton) return;
              previewEditableCellTap(col);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () => enterEditingFromPointer(col),
              child: child,
            ),
          ),
        ),
      );
    }

    Widget readonlyCell({
      required Widget child,
      bool showDivider = true,
      EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 4),
    }) {
      return Stack(
        children: [
          Padding(padding: padding, child: child),
          if (showDivider)
            Positioned(
              right: 0,
              top: 2,
              bottom: 2,
              child: Container(
                width: 1,
                decoration: BoxDecoration(
                  color: const Color(0xFFC9D5E2).withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
        ],
      );
    }

    return TapRegion(
      onTapOutside: (_) {
        if (_editing) {
          cancelEditingFromKeyboard();
        }
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTapDown: (details) {
            widget.onOpenContextMenu?.call(details.globalPosition);
          },
          onTapDown: (_) {
            if (_editing) return;
            widget.onSelect(_isAdditiveSelectionPressed());
          },
          child: AnimatedContainer(
            duration: Duration.zero,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              0.0,
              highlighted ? -2.0 : 0.0,
              0,
            ),
            child: Card(
              elevation: highlighted ? 4 : 0.5,
              color: rowBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: widget.isSelected
                      ? const Color(0xFF00A3FF).withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: _hovering ? 0.44 : 0.0),
                  width: 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SizedBox(
                      width: constraints.maxWidth,
                      child: Row(
                        children: [
                          Expanded(
                            flex: _kDateFlex,
                            child: gridCellFrame(
                              0,
                              _editing
                                  ? InkWell(
                                      onTap: () {
                                        widget.onActivateColumn(0);
                                        _pickFecha();
                                      },
                                      child: _CellBox(
                                        text: widget.fmtDateUi(_fecha),
                                        icon: Icons.calendar_month,
                                      ),
                                    )
                                  : previewEditableCell(
                                      col: 0,
                                      child: readonlyCell(
                                        child: _FitText(
                                          widget.fmtDateUi(_fecha),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: _kColGap),
                          Expanded(
                            flex: _kTicketFlex,
                            child: gridCellFrame(
                              1,
                              _editing
                                  ? TextField(
                                      controller: _ticket,
                                      focusNode: _ticketFocus,
                                      decoration: _glassFieldDecoration(),
                                      onSubmitted: (_) =>
                                          unawaited(saveFromKeyboard()),
                                      onTap: () {
                                        widget.onActivateColumn(1);
                                        if (!_ticketFocus.hasFocus) {
                                          _ticketFocus.requestFocus();
                                        }
                                      },
                                    )
                                  : previewEditableCell(
                                      col: 1,
                                      child: readonlyCell(
                                        child: _FitText(_ticket.text),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: _kColGap),
                          Expanded(
                            flex: _kProviderFlex,
                            child: gridCellFrame(
                              2,
                              _editing
                                  ? TextField(
                                      controller: _proveedor,
                                      focusNode: _proveedorFocus,
                                      inputFormatters: const [
                                        _ProviderInputFormatter(),
                                      ],
                                      decoration: _glassFieldDecoration(),
                                      onSubmitted: (_) =>
                                          unawaited(saveFromKeyboard()),
                                      onTap: () {
                                        widget.onActivateColumn(2);
                                        if (!_proveedorFocus.hasFocus) {
                                          _proveedorFocus.requestFocus();
                                        }
                                      },
                                    )
                                  : previewEditableCell(
                                      col: 2,
                                      child: readonlyCell(
                                        child: _FitText(_proveedor.text),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: _kColGap),
                          Expanded(
                            flex: _kPriceFlex,
                            child: gridCellFrame(
                              3,
                              _editing
                                  ? TextField(
                                      controller: _precio,
                                      focusNode: _precioFocus,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: const [
                                        _MoneyInputFormatter(),
                                      ],
                                      decoration: _glassFieldDecoration(),
                                      onSubmitted: (_) =>
                                          unawaited(saveFromKeyboard()),
                                      onTap: () {
                                        widget.onActivateColumn(3);
                                        if (!_precioFocus.hasFocus) {
                                          _precioFocus.requestFocus();
                                        }
                                      },
                                    )
                                  : previewEditableCell(
                                      col: 3,
                                      child: readonlyCell(
                                        showDivider: false,
                                        child: _FitText(
                                          _fmtMoney(
                                            _parseMoney(_precio.text) ?? 0,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: _kColGap),
                          SizedBox(
                            width: _kActionsW,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (widget.showRowActions)
                                  MouseRegion(
                                    onEnter: (_) => setState(
                                      () => _hoverActionsButton = true,
                                    ),
                                    onExit: (_) => setState(
                                      () => _hoverActionsButton = false,
                                    ),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapDown: (details) => widget
                                          .onOpenContextMenu
                                          ?.call(details.globalPosition),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: _hoverActionsButton
                                              ? Colors.white.withValues(
                                                  alpha: 0.62,
                                                )
                                              : Colors.white.withValues(
                                                  alpha: 0.42,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.72,
                                            ),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: _hoverActionsButton
                                                    ? 0.15
                                                    : 0.08,
                                              ),
                                              blurRadius: _hoverActionsButton
                                                  ? 14
                                                  : 8,
                                              offset: Offset(
                                                0,
                                                _hoverActionsButton ? 7 : 4,
                                              ),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.more_horiz,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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

class _CellBox extends StatelessWidget {
  final String text;
  final IconData icon;
  const _CellBox({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, overflow: TextOverflow.ellipsis)),
          Icon(icon, size: 16),
        ],
      ),
    );
  }
}

class _MarqueeSelectionPainter extends CustomPainter {
  final Rect rect;

  const _MarqueeSelectionPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    if (rect.isEmpty) return;
    final fill = Paint()
      ..color = const Color(0xFF4B8DBD).withValues(alpha: 0.18);
    final stroke = Paint()
      ..color = const Color(0xFF3C7FB0).withValues(alpha: 0.80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
  }

  @override
  bool shouldRepaint(covariant _MarqueeSelectionPainter oldDelegate) =>
      oldDelegate.rect != rect;
}

class _FitText extends StatelessWidget {
  final String text;
  const _FitText(this.text);

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 1, softWrap: false),
    );
  }
}

class _DateFilterDialogResult {
  final DateTimeRange? range;
  final bool clear;
  const _DateFilterDialogResult({this.range, this.clear = false});
}

class _WeighingsFilterDialogResult {
  final Set<String> selectedValues;
  const _WeighingsFilterDialogResult({required this.selectedValues});
}

String _monthNameEs(int month) {
  const months = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return months[(month - 1).clamp(0, 11)];
}

String _fmtDateLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

Future<_DateFilterDialogResult?> _showDateRangeFilterDialog(
  BuildContext context, {
  required String label,
  required DateTimeRange bounds,
  DateTimeRange? initialRange,
}) {
  return showDialog<_DateFilterDialogResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      DateTime displayMonth = DateTime(
        (initialRange?.start ?? DateTime.now()).year,
        (initialRange?.start ?? DateTime.now()).month,
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

          _DateFilterDialogResult? buildApplyResult() {
            if (start == null) return null;
            final s = dateOnly(start!);
            final e = dateOnly(end ?? start!);
            final from = s.isBefore(e) ? s : e;
            final to = s.isBefore(e) ? e : s;
            return _DateFilterDialogResult(
              range: DateTimeRange(start: from, end: to),
            );
          }

          bool inPreviewRange(DateTime day) {
            if (start == null || rangePreviewEnd == null) return false;
            final a = dateOnly(start!);
            final b = dateOnly(rangePreviewEnd);
            final from = a.isBefore(b) ? a : b;
            final to = a.isBefore(b) ? b : a;
            final d = dateOnly(day);
            return !d.isBefore(from) && !d.isAfter(to);
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
                      decoration: _filterDialogDecoration(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtro: $label',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0B2B2B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setLocalState(() {
                                    displayMonth = DateTime(
                                      displayMonth.year,
                                      displayMonth.month - 1,
                                    );
                                  });
                                },
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '${_monthNameEs(monthFirst.month)[0].toUpperCase()}${_monthNameEs(monthFirst.month).substring(1)} ${monthFirst.year}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setLocalState(() {
                                    displayMonth = DateTime(
                                      displayMonth.year,
                                      displayMonth.month + 1,
                                    );
                                  });
                                },
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: const [
                              Expanded(child: Center(child: Text('L'))),
                              Expanded(child: Center(child: Text('M'))),
                              Expanded(child: Center(child: Text('M'))),
                              Expanded(child: Center(child: Text('J'))),
                              Expanded(child: Center(child: Text('V'))),
                              Expanded(child: Center(child: Text('S'))),
                              Expanded(child: Center(child: Text('D'))),
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
                                          ? _kFilterAccent
                                          : inRange
                                          ? _kFilterAccentSoft.withValues(
                                              alpha: 0.8,
                                            )
                                          : Colors.transparent;

                                      final txtColor = active
                                          ? Colors.white
                                          : !allowed
                                          ? Colors.black38
                                          : inMonth
                                          ? const Color(0xFF0B2B2B)
                                          : Colors.black54;

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
                                                        color: _kFilterAccent
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
                          const SizedBox(height: 6),
                          Text(
                            start == null
                                ? 'Selecciona fecha inicial'
                                : end == null
                                ? 'Mueve el mouse y selecciona fecha final'
                                : '${_fmtDateLabel(start!)} - ${_fmtDateLabel(end!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2A4B49),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                style: _filterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: _filterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(
                                  dialogContext,
                                  const _DateFilterDialogResult(clear: true),
                                ),
                                child: const Text('Limpiar'),
                              ),
                              const SizedBox(width: 6),
                              FilledButton(
                                style: _filterFilledButtonStyle(),
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

Future<DateTime?> _showGlassDatePickerDialog(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  DateTime tempDate = DateUtils.dateOnly(initialDate);

  DateTime clampDate(DateTime value) {
    if (value.isBefore(firstDate)) return firstDate;
    if (value.isAfter(lastDate)) return lastDate;
    return value;
  }

  void moveDateByDays(void Function(void Function()) setInnerState, int days) {
    setInnerState(() {
      tempDate = DateUtils.dateOnly(
        clampDate(tempDate.add(Duration(days: days))),
      );
    });
  }

  void deferredPop(BuildContext ctx, [DateTime? value]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ctx.mounted) return;
      Navigator.of(ctx).pop(value);
    });
  }

  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (innerContext, setInnerState) {
          return FocusScope(
            autofocus: true,
            child: Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) {
                  return KeyEventResult.ignored;
                }
                final key = event.logicalKey;
                if (key == LogicalKeyboardKey.escape) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  deferredPop(dialogContext);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowLeft) {
                  moveDateByDays(setInnerState, -1);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowRight) {
                  moveDateByDays(setInnerState, 1);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowUp) {
                  moveDateByDays(setInnerState, -7);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowDown) {
                  moveDateByDays(setInnerState, 7);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.enter ||
                    key == LogicalKeyboardKey.numpadEnter) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  deferredPop(dialogContext, DateUtils.dateOnly(tempDate));
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Theme(
                data: Theme.of(innerContext).copyWith(
                  colorScheme: Theme.of(innerContext).colorScheme.copyWith(
                    primary: const Color(0xFF6A99C7),
                    onPrimary: Colors.white,
                    surface: const Color(0xFFEAF2F9),
                  ),
                ),
                child: AlertDialog(
                  backgroundColor: const Color(
                    0xFFEAF2F9,
                  ).withValues(alpha: 0.98),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: const Color(0xFF8AA9C2).withValues(alpha: 0.42),
                    ),
                  ),
                  title: const Text('Selecciona fecha'),
                  content: SizedBox(
                    width: 320,
                    child: CalendarDatePicker(
                      key: ValueKey<DateTime>(tempDate),
                      initialDate: tempDate,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      onDateChanged: (d) {
                        setInnerState(() {
                          tempDate = DateUtils.dateOnly(d);
                        });
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2D5478),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6A99C7),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(
                        dialogContext,
                      ).pop(DateUtils.dateOnly(tempDate)),
                      child: const Text('Aceptar'),
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

InputDecoration _glassFieldDecoration({String? hintText}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: Colors.white.withValues(alpha: 0.58),
      width: 1,
    ),
  );

  return InputDecoration(
    hintText: hintText,
    isDense: true,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.45),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(
        color: const Color(0xFF00A3FF).withValues(alpha: 0.8),
        width: 1.2,
      ),
    ),
  );
}

BoxDecoration _filterDialogDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.62),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
  );
}

ButtonStyle _filterOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF2A4B49),
    side: BorderSide(color: const Color(0xFF2A4B49).withValues(alpha: 0.25)),
    backgroundColor: Colors.white.withValues(alpha: 0.40),
  );
}

ButtonStyle _filterFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: _kFilterAccent,
    foregroundColor: Colors.white,
  );
}

ButtonStyle _actionOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF0B2B2B),
    backgroundColor: Colors.white.withValues(alpha: 0.34),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.black.withValues(alpha: 0.28),
  ).copyWith(
    overlayColor: WidgetStateProperty.all(Colors.transparent),
    elevation: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return 0;
      if (states.contains(WidgetState.pressed)) return 1.5;
      if (states.contains(WidgetState.hovered)) return 6;
      return 0;
    }),
  );
}

ButtonStyle _actionFilledButtonStyle() {
  return FilledButton.styleFrom(
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.black.withValues(alpha: 0.30),
  ).copyWith(
    overlayColor: WidgetStateProperty.all(Colors.transparent),
    elevation: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return 0;
      if (states.contains(WidgetState.pressed)) return 2;
      if (states.contains(WidgetState.hovered)) return 7;
      return 0;
    }),
  );
}

Future<bool?> _showGlassConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmText,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) => Focus(
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
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B2B2B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      content,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.35,
                        color: Color(0xFF1D3D3B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2A4B49),
                            side: BorderSide(
                              color: const Color(
                                0xFF2A4B49,
                              ).withValues(alpha: 0.25),
                            ),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.36,
                            ),
                          ),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2D6A6A),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: Text(confirmText),
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
}

class _ProviderInputFormatter extends TextInputFormatter {
  const _ProviderInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = _stripAccents(newValue.text).toUpperCase();
    text = text.replaceAll(RegExp(r'[^A-Z0-9 ]+'), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = text.replaceAll(RegExp(r'^\s+'), '');
    final safeOffset = newValue.selection.baseOffset.clamp(0, text.length);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: safeOffset),
    );
  }
}

class _MoneyInputFormatter extends TextInputFormatter {
  const _MoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (RegExp(r'^\d{0,9}([\.,]\d{0,2})?$').hasMatch(text)) return newValue;
    return oldValue;
  }
}

final RegExp _providerPattern = RegExp(r'^[A-Z0-9]+(?: [A-Z0-9]+)*$');

const List<String> _gridColumnLabels = [
  'FECHA',
  'TICKET',
  'PROVEEDOR',
  'PRECIO',
];

String _stripAccents(String input) {
  const map = <String, String>{
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
    'Á': 'A',
    'À': 'A',
    'Ä': 'A',
    'Â': 'A',
    'Ã': 'A',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'É': 'E',
    'È': 'E',
    'Ë': 'E',
    'Ê': 'E',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'Í': 'I',
    'Ì': 'I',
    'Ï': 'I',
    'Î': 'I',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'Ó': 'O',
    'Ò': 'O',
    'Ö': 'O',
    'Ô': 'O',
    'Õ': 'O',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'Ú': 'U',
    'Ù': 'U',
    'Ü': 'U',
    'Û': 'U',
    'ç': 'c',
    'Ç': 'C',
    'ñ': 'n',
    'Ñ': 'N',
  };

  final sb = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    sb.write(map[ch] ?? ch);
  }
  return sb.toString();
}

String _normalizeProvider(String raw) {
  final upper = _stripAccents(raw).toUpperCase();
  final safe = upper.replaceAll(RegExp(r'[^A-Z0-9 ]+'), '');
  return safe.replaceAll(RegExp(r'\s+'), ' ').trim();
}

DateTime? _dateFromAny(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return DateUtils.dateOnly(value);
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return null;
  return DateUtils.dateOnly(parsed);
}

String _fmtDbDate(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.toIso8601String().split('T').first;
}

String _fmtUiDate(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

String _fmtMoney(double v) {
  final fixed = v.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final decimal = parts[1];
  final re = RegExp(r'(\d+)(\d{3})');
  var out = intPart;
  while (re.hasMatch(out)) {
    out = out.replaceAllMapped(re, (m) => '${m[1]},${m[2]}');
  }
  return '\$$out.$decimal';
}

double? _parseMoney(String raw) {
  final clean = raw.trim().replaceAll(',', '.');
  if (clean.isEmpty) return null;
  return double.tryParse(clean);
}

double? _num(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String _csvEscape(String value) {
  final needsQuotes =
      value.contains(',') || value.contains('"') || value.contains('\n');
  final escaped = value.replaceAll('"', '""');
  return needsQuotes ? '"$escaped"' : escaped;
}

String _fmtCountInt(int value) {
  final s = value.toString();
  final re = RegExp(r'(\d+)(\d{3})');
  var out = s;
  while (re.hasMatch(out)) {
    out = out.replaceAllMapped(re, (m) => '${m[1]},${m[2]}');
  }
  return out;
}

Future<DateTime?> _pickInlineDate(
  BuildContext context,
  DateTime? current,
) async {
  return _showGlassDatePickerDialog(
    context,
    initialDate: DateUtils.dateOnly(current ?? DateTime.now()),
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
}
