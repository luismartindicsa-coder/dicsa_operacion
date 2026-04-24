import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_navigation.dart';
import '../shared/app_shell.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/contract_popup_surface.dart';
import '../shared/ui_contract_core/keyboard/grid_keyboard_contract.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/contract_tokens.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import '../shared/utils/number_formatters.dart';
import 'menudeo_catalog_page.dart';
import 'menudeo_dashboard_page.dart';
import 'menudeo_delete_confirm_dialog.dart';
import 'menudeo_deposits_expenses_page.dart';
import 'menudeo_filter_widgets.dart';
import 'menudeo_header_brand.dart';
import 'menudeo_metric_card.dart';
import 'menudeo_price_adjustments_page.dart';
import 'menudeo_session_confirm_dialog.dart';
import 'menudeo_theme.dart';

class MenudeoTicketsPage extends StatefulWidget {
  final bool instantOpen;
  final MenudeoTicketFlow flow;

  const MenudeoTicketsPage({
    super.key,
    this.instantOpen = false,
    this.flow = MenudeoTicketFlow.purchase,
  });

  @override
  State<MenudeoTicketsPage> createState() => _MenudeoTicketsPageState();
}

enum MenudeoTicketFlow { purchase, sale }

enum _TicketGridMenuAction { open, openLot, deleteSelection }

const double _kTicketsDateW = 140;
const double _kTicketsTicketW = 140;
const double _kTicketsProviderW = 290;
const double _kTicketsMaterialW = 290;
const double _kTicketsNetoW = 130;
const double _kTicketsImporteW = 150;
const double _kTicketsActionsW = 180;
final Object _kTicketsSelectionTapRegionGroup = Object();
const double _kTicketPrintWidthMm = 78;
const double _kTicketPrintHeightMm = 133;

const TextStyle _kTicketsMenuTextStyle = TextStyle(
  fontSize: 13.5,
  fontWeight: FontWeight.w800,
  color: Color(0xFF2D2A28),
  letterSpacing: 0.2,
);

Widget _ticketsPopupMenuItemChild({
  required IconData icon,
  required String label,
}) {
  return Row(
    children: [
      Icon(icon, size: 18, color: menudeoAreaTokens.primaryStrong),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label.toUpperCase(),
          style: _kTicketsMenuTextStyle,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

List<PopupMenuEntry<_TicketGridMenuAction>> _buildTicketMenuItems({
  required int selectedCount,
}) {
  return <PopupMenuEntry<_TicketGridMenuAction>>[
    PopupMenuItem<_TicketGridMenuAction>(
      value: _TicketGridMenuAction.open,
      child: _ticketsPopupMenuItemChild(
        icon: Icons.open_in_new_rounded,
        label: 'Abrir ticket',
      ),
    ),
    PopupMenuItem<_TicketGridMenuAction>(
      value: _TicketGridMenuAction.openLot,
      child: _ticketsPopupMenuItemChild(
        icon: Icons.dataset_linked_rounded,
        label: selectedCount > 1
            ? 'Entrar al lote ($selectedCount)'
            : 'Entrar al lote actual',
      ),
    ),
    const PopupMenuDivider(height: 1),
    PopupMenuItem<_TicketGridMenuAction>(
      value: _TicketGridMenuAction.deleteSelection,
      child: _ticketsPopupMenuItemChild(
        icon: Icons.delete_outline_rounded,
        label: selectedCount > 1 ? 'Eliminar selección' : 'Eliminar ticket',
      ),
    ),
  ];
}

ButtonStyle _ticketsGlassToolbarActionStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: menudeoAreaTokens.primaryStrong,
    side: BorderSide(color: Colors.white.withValues(alpha: 0.52)),
    backgroundColor: Colors.white.withValues(alpha: 0.18),
    textStyle: const TextStyle(fontWeight: FontWeight.w700),
  );
}

class _MenudeoTicketsPageState extends State<MenudeoTicketsPage> {
  final SupabaseClient _supa = Supabase.instance.client;
  final TextEditingController _ticketC = TextEditingController();
  final TextEditingController _brutoC = TextEditingController();
  final TextEditingController _taraC = TextEditingController();
  final TextEditingController _humedadC = TextEditingController();
  final TextEditingController _basuraC = TextEditingController();
  final TextEditingController _precioC = TextEditingController();
  final TextEditingController _sobreprecioC = TextEditingController();
  final TextEditingController _exitOrderNumberC = TextEditingController();
  final TextEditingController _comentarioC = TextEditingController();

  bool _menuOpen = false;
  bool _creatingTicketDraft = false;
  bool _splitEnabled = false;
  bool _loadingCatalogPrices = false;
  bool _exportingCsv = false;
  bool _dragSelectingRows = false;
  bool _suppressNextRowTap = false;
  bool _pointerDownAdditiveSelection = false;
  double _dragAutoScrollVelocity = 0;
  int _splitCount = 2;
  String _selectedProvider = '';
  String _selectedMaterial = '';
  String _selectedStatus = 'PENDIENTE';
  int _activeRowIndex = 0;
  int _currentPage = 0;
  int _pageSize = 40;
  int? _selectionAnchorIndex;
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _ticketDateFilter;
  List<Map<String, dynamic>> _catalogPriceRows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _ticketRows = <Map<String, dynamic>>[];
  final List<_SplitDraft> _splitDrafts = <_SplitDraft>[];
  final Set<int> _selectedRowIndexes = <int>{};
  final ScrollController _ticketsRowsScrollController = ScrollController();
  final GlobalKey _ticketsRowsViewportKey = GlobalKey(
    debugLabel: 'tickets_rows_viewport',
  );
  final Map<int, GlobalKey> _ticketRowItemKeys = <int, GlobalKey>{};
  Set<String> _providerGridFilter = <String>{};
  Set<String> _materialGridFilter = <String>{};
  Set<String> _statusGridFilter = <String>{};
  Set<String> _ticketNumberGridFilter = <String>{};
  Offset? _dragPointerLocal;
  Timer? _dragAutoScrollTimer;

  bool get _isSales => widget.flow == MenudeoTicketFlow.sale;
  String get _flowDirection => _isSales ? 'sale' : 'purchase';
  String get _headerTitle => _isSales ? 'Ventas' : 'Compra';
  String get _moduleTitle =>
      _isSales ? 'Ventas / Tickets' : 'Compras / Tickets';
  String get _counterpartyLabel => _isSales ? 'Cliente' : 'Proveedor';
  String get _counterpartyLabelUpper => _counterpartyLabel.toUpperCase();
  String get _newTicketButtonLabel => _isSales ? 'Nueva venta' : 'Nuevo ticket';
  String get _emptyGridLabel => _isSales
      ? 'No hay tickets de venta para mostrar.'
      : 'No hay tickets para mostrar.';

  List<_TicketGridEntry> _lotEntriesForInitialIndex(int initialIndex) {
    final filteredEntries = _filteredTicketEntries;
    final selectedVisibleEntries = filteredEntries
        .where((entry) => _selectedRowIndexes.contains(entry.index))
        .toList(growable: false);
    return selectedVisibleEntries.length > 1 &&
            selectedVisibleEntries.any((entry) => entry.index == initialIndex)
        ? selectedVisibleEntries
        : filteredEntries;
  }

  @override
  void initState() {
    super.initState();
    unawaited(HardwareKeyboard.instance.syncKeyboardState());
    unawaited(_loadCatalogPrices());
    unawaited(_loadTickets());
    for (final controller in <TextEditingController>[
      _ticketC,
      _brutoC,
      _taraC,
      _humedadC,
      _basuraC,
      _precioC,
      _sobreprecioC,
      _exitOrderNumberC,
      _comentarioC,
    ]) {
      controller.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _dragAutoScrollTimer?.cancel();
    _ticketsRowsScrollController.dispose();
    _ticketC.dispose();
    _brutoC.dispose();
    _taraC.dispose();
    _humedadC.dispose();
    _basuraC.dispose();
    _precioC.dispose();
    _sobreprecioC.dispose();
    _exitOrderNumberC.dispose();
    _comentarioC.dispose();
    for (final draft in _splitDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  double _numFrom(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  String _formatDateIso(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$year-$month-$day';
  }

  String get _todayLabel => _formatDate(_selectedDate);
  String get _todayIso => _formatDateIso(_selectedDate);

  String _displayDate(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();
    return '$day/$month/$year';
  }

  DateTime? _tryParseDisplayDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final parts = value.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.tryParse(value);
  }

  List<_TicketGridEntry> get _filteredTicketEntries {
    final entries = <_TicketGridEntry>[];
    for (var index = 0; index < _ticketRows.length; index++) {
      final row = _ticketRows[index];
      if (_ticketNumberGridFilter.isNotEmpty &&
          !_ticketNumberGridFilter.contains((row['ticket'] ?? '').toString())) {
        continue;
      }
      if (_providerGridFilter.isNotEmpty &&
          !_providerGridFilter.contains((row['provider'] ?? '').toString())) {
        continue;
      }
      if (_materialGridFilter.isNotEmpty &&
          !_materialGridFilter.contains((row['material'] ?? '').toString())) {
        continue;
      }
      if (_statusGridFilter.isNotEmpty &&
          !_statusGridFilter.contains((row['status'] ?? '').toString())) {
        continue;
      }
      if (_ticketDateFilter != null) {
        final rowDate = _tryParseDisplayDate((row['date'] ?? '').toString());
        if (rowDate == null) continue;
        final onlyDate = DateTime(rowDate.year, rowDate.month, rowDate.day);
        final start = DateTime(
          _ticketDateFilter!.start.year,
          _ticketDateFilter!.start.month,
          _ticketDateFilter!.start.day,
        );
        final end = DateTime(
          _ticketDateFilter!.end.year,
          _ticketDateFilter!.end.month,
          _ticketDateFilter!.end.day,
        );
        if (onlyDate.isBefore(start) || onlyDate.isAfter(end)) {
          continue;
        }
      }
      entries.add(_TicketGridEntry(index: index, row: row));
    }
    return entries;
  }

  int _effectiveCurrentPageFor(int totalRows) {
    if (totalRows <= 0) return 0;
    final maxPage = (totalRows - 1) ~/ _pageSize;
    return _currentPage.clamp(0, maxPage);
  }

  int _totalPagesFor(int totalRows) {
    if (totalRows <= 0) return 1;
    return ((totalRows - 1) ~/ _pageSize) + 1;
  }

  List<_TicketGridEntry> _pageEntries(List<_TicketGridEntry> entries) {
    if (entries.isEmpty) return const <_TicketGridEntry>[];
    final currentPage = _effectiveCurrentPageFor(entries.length);
    final start = currentPage * _pageSize;
    final end = math.min(start + _pageSize, entries.length);
    return entries.sublist(start, end);
  }

  bool _hasGridFilters() {
    return _ticketDateFilter != null ||
        _ticketNumberGridFilter.isNotEmpty ||
        _providerGridFilter.isNotEmpty ||
        _materialGridFilter.isNotEmpty ||
        _statusGridFilter.isNotEmpty;
  }

  void _clearGridFilters() {
    setState(() {
      _ticketDateFilter = null;
      _ticketNumberGridFilter.clear();
      _providerGridFilter.clear();
      _materialGridFilter.clear();
      _statusGridFilter.clear();
    });
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

  int _visiblePositionForIndex(
    int rowIndex,
    List<_TicketGridEntry> visibleEntries,
  ) {
    return visibleEntries.indexWhere((entry) => entry.index == rowIndex);
  }

  GlobalKey _ticketRowItemKey(int rowIndex) {
    return _ticketRowItemKeys.putIfAbsent(
      rowIndex,
      () => GlobalKey(debugLabel: 'ticket_row_$rowIndex'),
    );
  }

  void _ensureRowVisible(int rowIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rowContext = _ticketRowItemKey(rowIndex).currentContext;
      if (rowContext == null) return;
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    });
  }

  Offset? _globalToRowsLocal(Offset globalPosition) {
    final box =
        _ticketsRowsViewportKey.currentContext?.findRenderObject()
            as RenderBox?;
    if (box == null) return null;
    return box.globalToLocal(globalPosition);
  }

  int? _visibleRowPositionAtGlobalPosition(
    Offset globalPosition,
    List<_TicketGridEntry> visibleEntries,
  ) {
    for (var i = 0; i < visibleEntries.length; i++) {
      final context = _ticketRowItemKey(visibleEntries[i].index).currentContext;
      if (context == null) continue;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final origin = box.localToGlobal(Offset.zero);
      final rect = origin & box.size;
      if (rect.contains(globalPosition)) return i;
    }
    return null;
  }

  int? _visibleRowPositionForDragPosition(
    Offset globalPosition,
    List<_TicketGridEntry> visibleEntries,
  ) {
    final exactIndex = _visibleRowPositionAtGlobalPosition(
      globalPosition,
      visibleEntries,
    );
    if (exactIndex != null) return exactIndex;
    final local = _globalToRowsLocal(globalPosition);
    if (local == null || visibleEntries.isEmpty) return null;
    final box =
        _ticketsRowsViewportKey.currentContext?.findRenderObject()
            as RenderBox?;
    if (box == null || !box.hasSize) return null;
    if (local.dy < 0) return 0;
    if (local.dy > box.size.height) return visibleEntries.length - 1;
    return null;
  }

  void _selectVisibleRange(
    List<_TicketGridEntry> visibleEntries,
    int startVisible,
    int endVisible,
  ) {
    final from = startVisible < endVisible ? startVisible : endVisible;
    final to = startVisible < endVisible ? endVisible : startVisible;
    _selectedRowIndexes
      ..clear()
      ..addAll(
        visibleEntries.sublist(from, to + 1).map((entry) => entry.index),
      );
  }

  void _selectSingleRow(int rowIndex, List<_TicketGridEntry> visibleEntries) {
    _activeRowIndex = rowIndex;
    _selectionAnchorIndex = rowIndex;
    _selectedRowIndexes
      ..clear()
      ..add(rowIndex);
    _dragSelectingRows = false;
  }

  void _clearSelection() {
    _selectedRowIndexes.clear();
    _activeRowIndex = -1;
    _selectionAnchorIndex = null;
    _dragSelectingRows = false;
    _pointerDownAdditiveSelection = false;
    _suppressNextRowTap = false;
  }

  void _toggleRowSelection(int rowIndex) {
    _activeRowIndex = rowIndex;
    _selectionAnchorIndex = rowIndex;
    if (_selectedRowIndexes.contains(rowIndex)) {
      _selectedRowIndexes.remove(rowIndex);
      if (_selectedRowIndexes.isEmpty) {
        _selectedRowIndexes.add(rowIndex);
      }
    } else {
      _selectedRowIndexes.add(rowIndex);
    }
    _dragSelectingRows = false;
  }

  void _extendSelectionTo(int rowIndex, List<_TicketGridEntry> visibleEntries) {
    final anchor = _selectionAnchorIndex ?? _activeRowIndex;
    final anchorVisible = _visiblePositionForIndex(anchor, visibleEntries);
    final targetVisible = _visiblePositionForIndex(rowIndex, visibleEntries);
    if (anchorVisible < 0 || targetVisible < 0) {
      _selectSingleRow(rowIndex, visibleEntries);
      return;
    }
    _activeRowIndex = rowIndex;
    _selectVisibleRange(visibleEntries, anchorVisible, targetVisible);
    _dragSelectingRows = true;
  }

  void _extendSelectionToVisiblePosition(
    int visibleIndex,
    List<_TicketGridEntry> visibleEntries,
  ) {
    if (visibleEntries.isEmpty) return;
    final nextIndex = visibleEntries[visibleIndex].index;
    final anchor = _selectionAnchorIndex ?? _activeRowIndex;
    final anchorVisible = _visiblePositionForIndex(anchor, visibleEntries);
    if (anchorVisible < 0) {
      _selectSingleRow(nextIndex, visibleEntries);
      return;
    }
    _activeRowIndex = nextIndex;
    _selectVisibleRange(visibleEntries, anchorVisible, visibleIndex);
    _dragSelectingRows = true;
  }

  void _handleRowPrimaryPointerDown(
    int rowIndex,
    List<_TicketGridEntry> visibleEntries,
  ) {
    setState(() {
      _pointerDownAdditiveSelection =
          _isShortcutModifierPressed() || _isShiftPressed();
      if (_isShiftPressed()) {
        _extendSelectionTo(rowIndex, visibleEntries);
        _suppressNextRowTap = true;
      } else if (_isShortcutModifierPressed()) {
        _toggleRowSelection(rowIndex);
        _suppressNextRowTap = true;
      } else {
        _selectSingleRow(rowIndex, visibleEntries);
        _dragSelectingRows = true;
        _suppressNextRowTap = false;
      }
    });
  }

  void _handleRowsPointerDown(
    PointerDownEvent event,
    List<_TicketGridEntry> visibleEntries,
  ) {
    _pointerDownAdditiveSelection =
        _isShortcutModifierPressed() || _isShiftPressed();
    if (event.kind != PointerDeviceKind.mouse ||
        (event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }
    final visibleIndex = _visibleRowPositionAtGlobalPosition(
      event.position,
      visibleEntries,
    );
    if (visibleIndex == null) return;
    _dragPointerLocal = _globalToRowsLocal(event.position);
    _handleRowPrimaryPointerDown(
      visibleEntries[visibleIndex].index,
      visibleEntries,
    );
    _updateDragAutoScroll(visibleEntries);
  }

  void _handleRowTap(int rowIndex, List<_TicketGridEntry> visibleEntries) {
    if (_suppressNextRowTap || _pointerDownAdditiveSelection) {
      setState(() {
        _suppressNextRowTap = false;
        _pointerDownAdditiveSelection = false;
      });
      return;
    }
    setState(() => _selectSingleRow(rowIndex, visibleEntries));
  }

  void _handleRowsPointerMove(
    PointerMoveEvent event,
    List<_TicketGridEntry> visibleEntries,
  ) {
    if (!_dragSelectingRows) return;
    _dragPointerLocal = _globalToRowsLocal(event.position);
    _updateDragAutoScroll(visibleEntries);
    final visibleIndex = _visibleRowPositionForDragPosition(
      event.position,
      visibleEntries,
    );
    if (visibleIndex == null) return;
    setState(
      () => _extendSelectionToVisiblePosition(visibleIndex, visibleEntries),
    );
  }

  void _handleRowDragEnter(
    int rowIndex,
    List<_TicketGridEntry> visibleEntries,
  ) {
    if (!_dragSelectingRows) return;
    setState(() => _extendSelectionTo(rowIndex, visibleEntries));
  }

  void _handleRowPointerEnd() {
    if (!_dragSelectingRows &&
        !_pointerDownAdditiveSelection &&
        !_suppressNextRowTap) {
      _dragPointerLocal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    setState(() {
      _dragSelectingRows = false;
      _pointerDownAdditiveSelection = false;
      _dragPointerLocal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
    });
  }

  void _updateDragAutoScroll(List<_TicketGridEntry> visibleEntries) {
    if (!_dragSelectingRows || _dragPointerLocal == null) {
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final box =
        _ticketsRowsViewportKey.currentContext?.findRenderObject()
            as RenderBox?;
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
      (_) => _tickDragAutoScroll(visibleEntries),
    );
  }

  void _tickDragAutoScroll(List<_TicketGridEntry> visibleEntries) {
    if (!_dragSelectingRows ||
        _dragAutoScrollVelocity == 0 ||
        !_ticketsRowsScrollController.hasClients) {
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final position = _ticketsRowsScrollController.position;
    final next = (position.pixels + _dragAutoScrollVelocity).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) return;
    _ticketsRowsScrollController.jumpTo(next);
    final pointerLocal = _dragPointerLocal;
    if (pointerLocal == null) return;
    final box =
        _ticketsRowsViewportKey.currentContext?.findRenderObject()
            as RenderBox?;
    if (box == null || !box.hasSize) return;
    final clampedLocal = Offset(
      pointerLocal.dx.clamp(0.0, box.size.width),
      pointerLocal.dy.clamp(0.0, box.size.height),
    );
    final global = box.localToGlobal(clampedLocal);
    final visibleIndex = _visibleRowPositionForDragPosition(
      global,
      visibleEntries,
    );
    if (visibleIndex == null) return;
    setState(() {
      _extendSelectionToVisiblePosition(visibleIndex, visibleEntries);
    });
  }

  Future<void> _openActiveTicketLot() async {
    final filteredEntries = _filteredTicketEntries;
    if (filteredEntries.isEmpty) return;
    final activeEntry = filteredEntries.firstWhere(
      (entry) => entry.index == _activeRowIndex,
      orElse: () => filteredEntries.first,
    );
    await _showTicketDetailDialog(activeEntry.index);
  }

  Future<void> _deleteSelectedRows() async {
    final visibleEntries = _filteredTicketEntries;
    if (visibleEntries.isEmpty) return;
    final selectedVisibleEntries = visibleEntries
        .where((entry) => _selectedRowIndexes.contains(entry.index))
        .toList(growable: false);
    final targetEntries = selectedVisibleEntries.isEmpty
        ? <_TicketGridEntry>[
            visibleEntries.firstWhere(
              (entry) => entry.index == _activeRowIndex,
              orElse: () => visibleEntries.first,
            ),
          ]
        : selectedVisibleEntries;
    final targetIndexes = targetEntries.map((entry) => entry.index).toSet();
    final confirmed = await _showDeleteTicketsConfirmationDialog(
      context,
      ticketLabel: targetEntries.length == 1
          ? targetEntries.first.row['ticket'].toString()
          : null,
      deleteCount: targetEntries.length,
    );
    if (confirmed != true || !mounted) return;
    try {
      for (final entry in targetEntries) {
        final id = entry.row['id'];
        if (id == null) continue;
        await _supa.from('men_tickets').delete().eq('id', id);
      }
      setState(() {
        final nextRows = <Map<String, dynamic>>[];
        for (var index = 0; index < _ticketRows.length; index++) {
          if (targetIndexes.contains(index)) continue;
          nextRows.add(Map<String, dynamic>.from(_ticketRows[index]));
        }
        _ticketRows = nextRows;
        _selectedRowIndexes
          ..clear()
          ..addAll(
            _ticketRows.isEmpty
                ? const <int>{}
                : <int>{_activeRowIndex.clamp(0, _ticketRows.length - 1)},
          );
        _activeRowIndex = _ticketRows.isEmpty
            ? 0
            : _activeRowIndex.clamp(0, _ticketRows.length - 1);
      });
      _toast(
        targetEntries.length == 1
            ? 'Ticket eliminado'
            : 'Se eliminaron ${targetEntries.length} tickets',
      );
    } on PostgrestException catch (e) {
      _toast('No se pudo eliminar: ${e.message}');
    }
  }

  Future<bool?> _showDeleteTicketsConfirmationDialog(
    BuildContext context, {
    required int deleteCount,
    String? ticketLabel,
  }) {
    return showMenudeoDeleteConfirmDialog(
      context,
      title: deleteCount == 1 ? 'Eliminar ticket' : 'Eliminar selección',
      message: deleteCount == 1
          ? 'Se eliminará $ticketLabel del corte actual. Esta acción no se puede deshacer.'
          : 'Se eliminarán $deleteCount tickets seleccionados del corte actual. Esta acción no se puede deshacer.',
      impactLabel: deleteCount == 1
          ? 'El ticket saldrá del grid y del lote actual.'
          : '$deleteCount tickets saldrán del grid actual.',
      subtitle: deleteCount == 1
          ? 'Confirma la baja del ticket visible.'
          : 'Confirma la baja de la selección activa.',
      confirmLabel: deleteCount == 1 ? 'Eliminar ticket' : 'Eliminar selección',
    );
  }

  Future<void> _handleRowSecondaryTap(
    BuildContext context, {
    required int rowIndex,
    required Offset globalPosition,
  }) async {
    _alignSelectionForContextMenu(rowIndex);
    final lotEntries = _lotEntriesForInitialIndex(rowIndex);
    final action = await showMenu<_TicketGridMenuAction>(
      context: context,
      color: menudeoAreaTokens.surfaceTint.withValues(alpha: 0.98),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: menudeoAreaTokens.primarySoft.withValues(alpha: 0.58),
        ),
      ),
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: _buildTicketMenuItems(selectedCount: lotEntries.length),
    );
    if (!mounted || action == null) return;
    await _handleRowMenuAction(rowIndex, action);
  }

  void _alignSelectionForContextMenu(int rowIndex) {
    setState(() {
      _activeRowIndex = rowIndex;
      if (!_selectedRowIndexes.contains(rowIndex)) {
        _selectedRowIndexes
          ..clear()
          ..add(rowIndex);
      }
      _selectionAnchorIndex = rowIndex;
    });
  }

  Future<void> _handleRowMenuAction(
    int rowIndex,
    _TicketGridMenuAction action,
  ) async {
    switch (action) {
      case _TicketGridMenuAction.open:
        await _showTicketDetailDialog(rowIndex);
        break;
      case _TicketGridMenuAction.openLot:
        await _openActiveTicketLot();
        break;
      case _TicketGridMenuAction.deleteSelection:
        await _deleteSelectedRows();
        break;
    }
  }

  Future<void> _exportFilteredTicketsCsv() async {
    if (_exportingCsv) return;
    final entries = _filteredTicketEntries;
    if (entries.isEmpty) {
      _toast('No hay tickets para exportar');
      return;
    }
    setState(() => _exportingCsv = true);
    try {
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final sb = StringBuffer()
        ..write('\uFEFF')
        ..writeln(
          [
            'fecha',
            'ticket',
            'proveedor',
            'material',
            'bruto',
            'tara',
            'neto',
            'humedad',
            'basura',
            'precio',
            'sobreprecio',
            'importe',
            'estado',
            'comentario',
          ].join(','),
        );
      for (final entry in entries) {
        final row = entry.row;
        final neto =
            ((row['gross'] as num).toDouble() -
            (row['tare'] as num).toDouble());
        final peso =
            (neto * (1 - ((row['humidity'] as num).toDouble() / 100))) -
            (row['trash'] as num).toDouble();
        final importe =
            peso *
            ((row['price'] as num).toDouble() +
                (row['premium'] as num).toDouble());
        final values = <String>[
          (row['date'] ?? '').toString(),
          (row['ticket'] ?? '').toString(),
          (row['provider'] ?? '').toString(),
          (row['material'] ?? '').toString(),
          (row['gross'] ?? '').toString(),
          (row['tare'] ?? '').toString(),
          neto.toStringAsFixed(2),
          (row['humidity'] ?? '').toString(),
          (row['trash'] ?? '').toString(),
          (row['price'] ?? '').toString(),
          (row['premium'] ?? '').toString(),
          importe.toStringAsFixed(2),
          (row['status'] ?? '').toString(),
          (row['comment'] ?? '').toString(),
        ];
        sb.writeln(values.map(_csvEscape).join(','));
      }
      final path = await saveCsvFile(
        fileName: 'menudeo_tickets_$stamp.csv',
        content: sb.toString(),
        dialogTitle: 'Guardar CSV de tickets',
      );
      _toast(
        path == null ? 'No se pudo guardar CSV' : 'CSV exportado en: $path',
      );
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    final needsQuotes =
        escaped.contains(',') ||
        escaped.contains('\n') ||
        escaped.contains('"');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  Map<String, dynamic> _normalizeTicketRow(Map<String, dynamic> row) {
    return <String, dynamic>{
      'id': row['id'],
      'date': _displayDate(row['date'] ?? row['ticket_date']),
      'ticket': row['ticket'] ?? row['ticket_number'] ?? '',
      'provider': row['provider'] ?? row['counterparty_name_snapshot'] ?? '',
      'material': row['material'] ?? row['material_label_snapshot'] ?? '',
      'price': row['price'] ?? row['price_at_entry'] ?? 0,
      'gross': row['gross'] ?? row['gross_weight'] ?? 0,
      'tare': row['tare'] ?? row['tare_weight'] ?? 0,
      'humidity': row['humidity'] ?? row['humidity_percent'] ?? 0,
      'trash': row['trash'] ?? row['trash_weight'] ?? 0,
      'premium': row['premium'] ?? row['premium_per_kg'] ?? 0,
      'exit_order_number':
          row['exit_order_number']?.toString().trim().isEmpty ?? true
          ? ''
          : row['exit_order_number'].toString().trim(),
      'status': row['status'] ?? 'PENDIENTE',
      'comment': row['comment'] ?? '',
    };
  }

  Future<void> _loadCatalogPrices() async {
    setState(() => _loadingCatalogPrices = true);
    try {
      final response = await _loadCatalogPricesForDirection(_flowDirection);
      if (!mounted) return;
      _catalogPriceRows = response
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      _syncSelectedPrice();
      setState(() => _loadingCatalogPrices = false);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _loadingCatalogPrices = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cargar el catálogo de precios: ${e.message}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<List<dynamic>> _loadCatalogPricesForDirection(String direction) async {
    try {
      return await _supa
          .from('vw_men_effective_prices')
          .select(
            'price_id,counterparty_id,counterparty_name,general_material_id,commercial_material_id,material_alias_id,material_label_snapshot,final_price,direction',
          )
          .eq('direction', direction)
          .order('counterparty_name')
          .order('material_label_snapshot');
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (!message.contains('direction')) rethrow;
      return await _supa
          .from('vw_men_effective_prices')
          .select(
            'price_id,counterparty_id,counterparty_name,general_material_id,commercial_material_id,material_alias_id,material_label_snapshot,final_price',
          )
          .order('counterparty_name')
          .order('material_label_snapshot');
    }
  }

  double? _catalogPriceForSelection() {
    final row = _selectedCatalogPriceRow();
    if (row == null) return null;
    return ((row['final_price'] ?? 0) as num).toDouble();
  }

  Map<String, dynamic>? _selectedCatalogPriceRow() {
    if (_catalogPriceRows.isEmpty) return null;
    final provider = _selectedProvider.trim().toUpperCase();
    final material = _selectedMaterial.trim().toUpperCase();
    if (provider.isEmpty || material.isEmpty) return null;
    for (final row in _catalogPriceRows) {
      final rowProvider = (row['counterparty_name'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      final rowMaterial = (row['material_label_snapshot'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      if (rowProvider == provider && rowMaterial == material) {
        return row;
      }
    }
    return null;
  }

  Map<String, dynamic>? _selectedCatalogPriceRowFor(String material) {
    if (_catalogPriceRows.isEmpty) return null;
    final provider = _selectedProvider.trim().toUpperCase();
    final targetMaterial = material.trim().toUpperCase();
    if (provider.isEmpty || targetMaterial.isEmpty) return null;
    for (final row in _catalogPriceRows) {
      final rowProvider = (row['counterparty_name'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      final rowMaterial = (row['material_label_snapshot'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      if (rowProvider == provider && rowMaterial == targetMaterial) {
        return row;
      }
    }
    return null;
  }

  double? _catalogPriceForMaterial(String material) {
    final row = _selectedCatalogPriceRowFor(material);
    if (row == null) return null;
    return ((row['final_price'] ?? 0) as num).toDouble();
  }

  void _syncSelectedPrice() {
    final price = _catalogPriceForSelection();
    if (price == null) {
      if (_precioC.text.isNotEmpty) {
        _precioC.clear();
      }
      return;
    }
    final next = price.toStringAsFixed(2);
    if (_precioC.text == next) return;
    _precioC.value = _precioC.value.copyWith(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
      composing: TextRange.empty,
    );
  }

  String _money(num value) => formatMoney(value);

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _loadTickets() async {
    try {
      final response = await _supa
          .from('vw_men_tickets_grid')
          .select()
          .eq('direction', _flowDirection)
          .order('ticket_date', ascending: true)
          .order('ticket_number', ascending: true);
      if (!mounted) return;
      setState(() {
        final loadedRows = response
            .map((row) => _normalizeTicketRow(Map<String, dynamic>.from(row)))
            .toList(growable: true);
        _ticketRows = loadedRows;
        _activeRowIndex = _ticketRows.isEmpty
            ? -1
            : _activeRowIndex.clamp(0, _ticketRows.length - 1);
        _selectedRowIndexes.removeWhere((index) => index >= _ticketRows.length);
        if (_ticketRows.isNotEmpty && _selectedRowIndexes.isEmpty) {
          _selectedRowIndexes.add(_activeRowIndex);
        }
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _ticketRows = <Map<String, dynamic>>[];
        _activeRowIndex = -1;
        _selectedRowIndexes.clear();
      });
      _toast('No se pudieron cargar los tickets: ${e.message}');
    }
  }

  Future<bool> _createTicketsFromDraft() async {
    if (_creatingTicketDraft) return false;
    final baseTicket = _ticketC.text.trim();
    if (baseTicket.isEmpty) {
      _toast('El ticket es obligatorio');
      return false;
    }
    if (_selectedProvider.trim().isEmpty) {
      _toast('Selecciona un ${_counterpartyLabel.toLowerCase()}');
      return false;
    }
    if (_splitEnabled) {
      _syncSplitDrafts();
    }
    final createdRows = <Map<String, dynamic>>[];
    if (_splitEnabled) {
      final selectedPriceRow = _selectedCatalogPriceRow();
      final priceAtEntry = selectedPriceRow == null
          ? null
          : ((selectedPriceRow['final_price'] ?? 0) as num).toDouble();
      if (_selectedMaterial.trim().isEmpty ||
          priceAtEntry == null ||
          selectedPriceRow == null) {
        _toast('Completa el ticket principal para generar $baseTicket-A');
        return false;
      }
      createdRows.add(
        _buildTicketInsertRow(
          baseTicket: baseTicket,
          suffix: 'A',
          selectedPriceRow: selectedPriceRow,
          materialLabel: _selectedMaterial,
          grossWeight: _numFrom(_brutoC),
          tareWeight: _numFrom(_taraC),
          humidityPercent: _numFrom(_humedadC),
          trashWeight: _numFrom(_basuraC),
          premiumPerKg: _numFrom(_sobreprecioC),
          comment: _comentarioC.text.trim(),
        ),
      );
      for (var index = 0; index < _splitDrafts.length; index++) {
        final draft = _splitDrafts[index];
        final material = draft.selectedMaterial.trim();
        if (material.isEmpty) {
          _toast(
            'Selecciona material para $baseTicket-${String.fromCharCode(66 + index)}',
          );
          return false;
        }
        final selectedPriceRow = _selectedCatalogPriceRowFor(material);
        final priceAtEntry = selectedPriceRow == null
            ? null
            : ((selectedPriceRow['final_price'] ?? 0) as num).toDouble();
        if (priceAtEntry == null || selectedPriceRow == null) {
          _toast('No hay precio vigente para $material');
          return false;
        }
        createdRows.add(
          _buildTicketInsertRow(
            baseTicket: baseTicket,
            suffix: String.fromCharCode(66 + index),
            selectedPriceRow: selectedPriceRow,
            materialLabel: material,
            grossWeight: _parseDraftController(draft.brutoC),
            tareWeight: _parseDraftController(draft.taraC),
            humidityPercent: _parseDraftController(draft.humedadC),
            trashWeight: _parseDraftController(draft.basuraC),
            premiumPerKg: _parseDraftController(draft.sobreprecioC),
            comment: draft.comentarioC.text.trim(),
          ),
        );
      }
    } else {
      final selectedPriceRow = _selectedCatalogPriceRow();
      final priceAtEntry = selectedPriceRow == null
          ? null
          : ((selectedPriceRow['final_price'] ?? 0) as num).toDouble();
      if (_selectedMaterial.trim().isEmpty ||
          priceAtEntry == null ||
          selectedPriceRow == null) {
        _toast(
          'Selecciona ${_counterpartyLabel.toLowerCase()} y material con precio vigente',
        );
        return false;
      }
      createdRows.add(
        _buildTicketInsertRow(
          baseTicket: baseTicket,
          suffix: null,
          selectedPriceRow: selectedPriceRow,
          materialLabel: _selectedMaterial,
          grossWeight: _numFrom(_brutoC),
          tareWeight: _numFrom(_taraC),
          humidityPercent: _numFrom(_humedadC),
          trashWeight: _numFrom(_basuraC),
          premiumPerKg: _numFrom(_sobreprecioC),
          comment: _comentarioC.text.trim(),
        ),
      );
    }
    final candidateTicketNumbers =
        createdRows
            .map(
              (row) => _ticketNumberFromParts(
                row['ticket_base']?.toString() ?? '',
                row['ticket_suffix']?.toString(),
              ),
            )
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    try {
      final existingRaw = await _supa
          .from('men_tickets')
          .select('ticket_number')
          .inFilter('ticket_number', candidateTicketNumbers);
      final existing = (existingRaw as List)
          .map((row) => (row as Map<String, dynamic>)['ticket_number'])
          .whereType<String>()
          .toSet();
      if (existing.isNotEmpty) {
        final duplicates = existing.toList()..sort();
        _toast(
          duplicates.length == 1
              ? 'Ya existe el ticket ${duplicates.first}'
              : 'Ya existen los tickets ${duplicates.join(', ')}',
        );
        return false;
      }
    } on PostgrestException catch (e) {
      _toast('No se pudo validar el número de ticket: ${e.message}');
      return false;
    }
    setState(() => _creatingTicketDraft = true);
    try {
      await _supa.from('men_tickets').insert(createdRows);
      await _loadTickets();
      _toast(
        _splitEnabled
            ? 'Se crearon ${createdRows.length} tickets del split'
            : 'Ticket creado',
      );
      return true;
    } on PostgrestException catch (e) {
      if (_isDuplicateTicketError(e)) {
        _toast(
          'Ya existe un ticket con ese número. Usa un subticket distinto.',
        );
      } else {
        _toast('No se pudo crear el ticket: ${e.message}');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _creatingTicketDraft = false);
      }
    }
  }

  Map<String, dynamic> _buildTicketInsertRow({
    required String baseTicket,
    required String? suffix,
    required Map<String, dynamic> selectedPriceRow,
    required String materialLabel,
    required double grossWeight,
    required double tareWeight,
    required double humidityPercent,
    required double trashWeight,
    required double premiumPerKg,
    required String comment,
  }) {
    return <String, dynamic>{
      'ticket_date': _todayIso,
      'direction': _flowDirection,
      'ticket_base': baseTicket,
      'ticket_suffix': suffix,
      'counterparty_id': selectedPriceRow['counterparty_id'],
      'counterparty_name_snapshot': _selectedProvider,
      'price_id': selectedPriceRow['price_id'],
      'general_material_id': selectedPriceRow['general_material_id'],
      'commercial_material_id': selectedPriceRow['commercial_material_id'],
      'material_alias_id': selectedPriceRow['material_alias_id'],
      'material_label_snapshot': materialLabel,
      'price_at_entry': ((selectedPriceRow['final_price'] ?? 0) as num)
          .toDouble(),
      'gross_weight': grossWeight,
      'tare_weight': tareWeight,
      'humidity_percent': humidityPercent,
      'trash_weight': trashWeight,
      'premium_per_kg': premiumPerKg,
      'exit_order_number': _isSales
          ? (_exitOrderNumberC.text.trim().isEmpty
                ? null
                : _exitOrderNumberC.text.trim())
          : null,
      'status': _selectedStatus,
      'comment': comment.isEmpty ? null : comment,
    };
  }

  String _ticketNumberFromParts(String baseTicket, String? suffix) {
    final base = baseTicket.trim();
    final normalizedSuffix = suffix?.trim().toUpperCase() ?? '';
    if (base.isEmpty) return '';
    if (normalizedSuffix.isEmpty) return base;
    return '$base-$normalizedSuffix';
  }

  bool _isDuplicateTicketError(PostgrestException error) {
    final message = error.message.toString().toLowerCase();
    final details = (error.details ?? '').toString().toLowerCase();
    return error.code == '23505' &&
        (message.contains('ticket_number') ||
            details.contains('ticket_number'));
  }

  List<String> get _providerOptions {
    final values =
        _catalogPriceRows
            .map(
              (row) => (row['counterparty_name'] ?? '')
                  .toString()
                  .trim()
                  .toUpperCase(),
            )
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<String> get _materialOptionsForProvider {
    final provider = _selectedProvider.trim().toUpperCase();
    if (provider.isEmpty) return const <String>[];
    final values =
        _catalogPriceRows
            .where(
              (row) =>
                  (row['counterparty_name'] ?? '')
                      .toString()
                      .trim()
                      .toUpperCase() ==
                  provider,
            )
            .map(
              (row) => (row['material_label_snapshot'] ?? '')
                  .toString()
                  .trim()
                  .toUpperCase(),
            )
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  void _resetDraft() {
    _ticketC.clear();
    _brutoC.clear();
    _taraC.clear();
    _humedadC.clear();
    _basuraC.clear();
    _precioC.clear();
    _sobreprecioC.clear();
    _exitOrderNumberC.clear();
    _comentarioC.clear();
    _splitEnabled = false;
    _splitCount = 2;
    _selectedProvider = '';
    _selectedMaterial = '';
    _selectedStatus = 'PENDIENTE';
    _selectedDate = DateTime.now();
    for (final draft in _splitDrafts) {
      draft.dispose();
    }
    _splitDrafts.clear();
  }

  void _selectAllVisibleRows(List<_TicketGridEntry> visibleEntries) {
    if (visibleEntries.isEmpty) return;
    _selectedRowIndexes
      ..clear()
      ..addAll(visibleEntries.map((entry) => entry.index));
    _activeRowIndex = visibleEntries.first.index;
    _selectionAnchorIndex = visibleEntries.first.index;
  }

  void _syncSplitDrafts() {
    final additionalCount = (_splitCount - 1).clamp(0, 99);
    while (_splitDrafts.length < additionalCount) {
      _splitDrafts.add(_SplitDraft());
    }
    while (_splitDrafts.length > additionalCount) {
      _splitDrafts.removeLast().dispose();
    }
  }

  double _parseDraftController(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _pickTicketDate() async {
    final picked = await _showTicketsSingleDateDialog(
      context,
      bounds: DateTimeRange(start: DateTime(2024), end: DateTime(2035)),
      initialDate: _selectedDate,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _openTicketDateFilter() async {
    final bounds = _ticketRows
        .map((row) => _tryParseDisplayDate((row['date'] ?? '').toString()))
        .whereType<DateTime>()
        .toList(growable: false);
    if (bounds.isEmpty) return;
    final sorted = [...bounds]..sort();
    final result = await _showTicketsDateRangeFilterDialog(
      context,
      label: 'FECHA',
      bounds: DateTimeRange(start: sorted.first, end: sorted.last),
      initialRange: _ticketDateFilter,
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.clear) {
        _ticketDateFilter = null;
      } else {
        _ticketDateFilter = result.range;
      }
    });
  }

  Future<void> _openValueFilter({
    required String label,
    required Set<String> current,
    required List<String> options,
    required ValueChanged<Set<String>> onApply,
  }) async {
    final result = await _showTicketsValueFilterDialog(
      context,
      label: label,
      options: options,
      initialSelected: current,
    );
    if (result == null || !mounted) return;
    setState(() => onApply(result.selectedValues));
  }

  Future<void> _goBack() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const MenudeoDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openCatalogPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoCatalogPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openPriceAdjustmentsPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoPriceAdjustmentsPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  void _showStub(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label quedará conectado en la siguiente fase de Tickets.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Menudeo':
        unawaited(_goBack());
        return;
      case 'Catálogo':
        unawaited(_openCatalogPage());
        return;
      case 'Ajuste de precios':
        unawaited(_openPriceAdjustmentsPage());
        return;
      case 'Tickets de menudeo':
        if (_isSales) {
          unawaited(
            Navigator.of(context).pushReplacement(
              appPageRoute(
                page: const MenudeoTicketsPage(instantOpen: true),
                duration: const Duration(milliseconds: 300),
                reverseDuration: const Duration(milliseconds: 220),
              ),
            ),
          );
          return;
        }
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      case 'Ventas menudeo':
        if (_isSales) {
          if (_menuOpen) setState(() => _menuOpen = false);
          return;
        }
        unawaited(
          Navigator.of(context).pushReplacement(
            appPageRoute(
              page: const MenudeoTicketsPage(
                instantOpen: true,
                flow: MenudeoTicketFlow.sale,
              ),
              duration: const Duration(milliseconds: 300),
              reverseDuration: const Duration(milliseconds: 220),
            ),
          ),
        );
        return;
      case 'Depósitos y gastos':
        unawaited(
          Navigator.of(context).push(
            appPageRoute(
              page: const MenudeoDepositsExpensesPage(instantOpen: true),
              duration: const Duration(milliseconds: 300),
              reverseDuration: const Duration(milliseconds: 220),
            ),
          ),
        );
        return;
      default:
        _showStub(label);
    }
  }

  Future<void> _logout() async {
    final ok = await showMenudeoSessionConfirmDialog(context);
    if (ok != true || !mounted) return;
    await signOutAndRouteToLogin(context);
  }

  Future<void> _showNewTicketDialog() async {
    setState(_resetDraft);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              child: AreaThemeScope(
                tokens: menudeoAreaTokens,
                child: ContractPopupSurface(
                  constraints: const BoxConstraints(
                    minWidth: 360,
                    maxWidth: 430,
                    maxHeight: 840,
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TicketDialogHeader(
                          onClose: () => Navigator.of(dialogContext).pop(),
                        ),
                        const SizedBox(height: 8),
                        _NewTicketCard(
                          counterpartyLabel: _counterpartyLabel,
                          showExitOrderField: _isSales,
                          dateLabel: _todayLabel,
                          onPickDate: () async {
                            await _pickTicketDate();
                            setDialogState(() {});
                          },
                          ticketC: _ticketC,
                          brutoC: _brutoC,
                          taraC: _taraC,
                          humedadC: _humedadC,
                          basuraC: _basuraC,
                          precioC: _precioC,
                          sobreprecioC: _sobreprecioC,
                          exitOrderNumberC: _exitOrderNumberC,
                          comentarioC: _comentarioC,
                          providerOptions: _providerOptions,
                          materialOptions: _materialOptionsForProvider,
                          selectedProvider: _selectedProvider,
                          selectedMaterial: _selectedMaterial,
                          selectedStatus: _selectedStatus,
                          splitEnabled: _splitEnabled,
                          splitCount: _splitCount,
                          splitDrafts: _splitDrafts,
                          formatMoney: _money,
                          catalogPriceForMaterial: _catalogPriceForMaterial,
                          onProviderChanged: (value) {
                            setState(() {
                              _selectedProvider = value;
                              final materials = _materialOptionsForProvider;
                              if (materials.isNotEmpty &&
                                  !materials.contains(_selectedMaterial)) {
                                _selectedMaterial = materials.first;
                              } else if (materials.isEmpty) {
                                _selectedMaterial = '';
                              }
                              _syncSelectedPrice();
                            });
                            setDialogState(() {});
                          },
                          onMaterialChanged: (value) {
                            setState(() {
                              _selectedMaterial = value;
                              _syncSelectedPrice();
                            });
                            setDialogState(() {});
                          },
                          onStatusChanged: (value) {
                            setState(() => _selectedStatus = value);
                            setDialogState(() {});
                          },
                          onSplitChanged: (value) {
                            setState(() {
                              _splitEnabled = value;
                              if (value) _syncSplitDrafts();
                            });
                            setDialogState(() {});
                          },
                          onSplitCountChanged: (value) {
                            setState(() {
                              _splitCount = value;
                              _syncSplitDrafts();
                            });
                            setDialogState(() {});
                          },
                          onSplitMaterialChanged: (index, value) {
                            setState(() {
                              _splitDrafts[index].selectedMaterial = value;
                            });
                            setDialogState(() {});
                          },
                          loadingCatalogPrice: _loadingCatalogPrices,
                          creatingTicketDraft: _creatingTicketDraft,
                          hasCatalogPrice: _catalogPriceForSelection() != null,
                          onCreateTicket: () async {
                            final created = await _createTicketsFromDraft();
                            if (created && dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          },
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

  Future<void> _showTicketDetailDialog(int initialIndex) async {
    final lotEntries = _lotEntriesForInitialIndex(initialIndex);
    if (lotEntries.isEmpty) return;
    var currentLotPosition = lotEntries.indexWhere(
      (entry) => entry.index == initialIndex,
    );
    if (currentLotPosition < 0) currentLotPosition = 0;
    int currentIndex = lotEntries[currentLotPosition].index;
    final humedadC = TextEditingController();
    final basuraC = TextEditingController();
    final sobreprecioC = TextEditingController();
    final exitOrderNumberC = TextEditingController();
    final comentarioC = TextEditingController();
    String selectedStatus = '';
    void syncFromCurrentRow() {
      final row = _ticketRows[currentIndex];
      humedadC.text = ((row['humidity'] as num?) ?? 0).toString();
      basuraC.text = ((row['trash'] as num?) ?? 0).toString();
      sobreprecioC.text = ((row['premium'] as num?) ?? 0).toString();
      exitOrderNumberC.text = (row['exit_order_number'] ?? '').toString();
      comentarioC.text = (row['comment'] ?? '').toString();
      selectedStatus = (row['status'] ?? 'PENDIENTE').toString();
    }

    syncFromCurrentRow();
    setState(() => _activeRowIndex = currentIndex);
    VoidCallback? goPrevious;
    VoidCallback? goNext;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final row = _ticketRows[currentIndex];
              goPrevious = currentLotPosition == 0
                  ? null
                  : () {
                      setDialogState(() {
                        currentLotPosition--;
                        currentIndex = lotEntries[currentLotPosition].index;
                        syncFromCurrentRow();
                      });
                      setState(() => _activeRowIndex = currentIndex);
                    };
              goNext = currentLotPosition == lotEntries.length - 1
                  ? null
                  : () {
                      setDialogState(() {
                        currentLotPosition++;
                        currentIndex = lotEntries[currentLotPosition].index;
                        syncFromCurrentRow();
                      });
                      setState(() => _activeRowIndex = currentIndex);
                    };
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: Focus(
                  onKeyEvent: (_, event) {
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      goPrevious?.call();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                      goNext?.call();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: AreaThemeScope(
                    tokens: menudeoAreaTokens,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(34),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.26),
                            blurRadius: 24,
                            offset: const Offset(-4, -4),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 36,
                            offset: const Offset(0, 24),
                          ),
                        ],
                      ),
                      child: ContractPopupSurface(
                        constraints: const BoxConstraints(
                          minWidth: 620,
                          maxWidth: 760,
                          maxHeight: 760,
                        ),
                        padding: const EdgeInsets.all(22),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _TicketDialogHeader(
                                onPrint: () => _openTicketPdfFromDialog(
                                  row: row,
                                  humedadC: humedadC,
                                  basuraC: basuraC,
                                  sobreprecioC: sobreprecioC,
                                  exitOrderNumberC: exitOrderNumberC,
                                  comentarioC: comentarioC,
                                  status: selectedStatus,
                                ),
                                onClose: () =>
                                    Navigator.of(dialogContext).pop(),
                              ),
                              const SizedBox(height: 12),
                              _TicketDetailCard(
                                row: row,
                                rowIndex: currentLotPosition,
                                rowCount: lotEntries.length,
                                counterpartyLabel: _counterpartyLabel,
                                showExitOrderField: _isSales,
                                formatMoney: _money,
                                humedadC: humedadC,
                                basuraC: basuraC,
                                sobreprecioC: sobreprecioC,
                                exitOrderNumberC: exitOrderNumberC,
                                comentarioC: comentarioC,
                                selectedStatus: selectedStatus,
                                onStatusChanged: (value) => setDialogState(
                                  () => selectedStatus = value,
                                ),
                                onDraftChanged: () => setDialogState(() {}),
                                onPreviousRow: goPrevious,
                                onNextRow: goNext,
                                onSave: () async {
                                  final updatedRow = await _saveTicketEdit(
                                    row: row,
                                    humidity: _parseDraftController(humedadC),
                                    trash: _parseDraftController(basuraC),
                                    premium: _parseDraftController(
                                      sobreprecioC,
                                    ),
                                    exitOrderNumber: exitOrderNumberC.text
                                        .trim(),
                                    status: selectedStatus,
                                    comment: comentarioC.text.trim(),
                                  );
                                  if (updatedRow == null || !mounted) return;
                                  setState(() {
                                    _ticketRows[currentIndex] = updatedRow;
                                  });
                                  setDialogState(syncFromCurrentRow);
                                  _toast('Ticket actualizado');
                                },
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
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        humedadC.dispose();
        basuraC.dispose();
        sobreprecioC.dispose();
        exitOrderNumberC.dispose();
        comentarioC.dispose();
      });
    }
  }

  Future<Map<String, dynamic>?> _saveTicketEdit({
    required Map<String, dynamic> row,
    required double humidity,
    required double trash,
    required double premium,
    required String exitOrderNumber,
    required String status,
    required String comment,
  }) async {
    final updatedRow = <String, dynamic>{
      ...row,
      'humidity': humidity,
      'trash': trash,
      'premium': premium,
      'exit_order_number': exitOrderNumber,
      'status': status,
      'comment': comment,
    };
    final id = row['id'];
    if (id == null) {
      return updatedRow;
    }
    try {
      await _supa
          .from('men_tickets')
          .update(<String, dynamic>{
            'humidity_percent': humidity,
            'trash_weight': trash,
            'premium_per_kg': premium,
            'exit_order_number': exitOrderNumber.isEmpty
                ? null
                : exitOrderNumber,
            'status': status,
            'comment': comment.isEmpty ? null : comment,
          })
          .eq('id', id);
      return updatedRow;
    } on PostgrestException catch (e) {
      _toast('No se pudo actualizar el ticket: ${e.message}');
      return null;
    }
  }

  Future<Uint8List> _buildTicketPrintPdfBytes({
    required Map<String, dynamic> row,
    required double humidity,
    required double trash,
    required double premium,
    required String exitOrderNumber,
    required String status,
    required String comment,
  }) async {
    final doc = pw.Document();
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo_dicsa.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final bruto = ((row['gross'] as num?) ?? 0).toDouble();
    final tara = ((row['tare'] as num?) ?? 0).toDouble();
    final neto = bruto - tara;
    final precio = ((row['price'] as num?) ?? 0).toDouble();
    final peso = (neto * (1 - (humidity / 100))) - trash;
    final importe = peso * (precio + premium);
    final printedAt = DateTime.now();
    final printedTime =
        '${printedAt.hour.toString().padLeft(2, '0')}:${printedAt.minute.toString().padLeft(2, '0')}';
    final ticketPageFormat = PdfPageFormat(
      _kTicketPrintWidthMm * PdfPageFormat.mm,
      _kTicketPrintHeightMm * PdfPageFormat.mm,
      marginLeft: 2.5 * PdfPageFormat.mm,
      marginRight: 2.5 * PdfPageFormat.mm,
      marginTop: 3 * PdfPageFormat.mm,
      marginBottom: 3.5 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: ticketPageFormat,
        margin: const pw.EdgeInsets.fromLTRB(4, 5, 4, 6),
        build: (context) {
          pw.Widget divider({double spacing = 5}) {
            return pw.Padding(
              padding: pw.EdgeInsets.symmetric(vertical: spacing),
              child: pw.Container(
                width: double.infinity,
                height: 1,
                color: PdfColors.grey500,
              ),
            );
          }

          pw.Widget buildPairRow(
            String leftLabel,
            String leftValue,
            String rightLabel,
            String rightValue,
          ) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(
                          width: 28,
                          child: pw.Text(
                            leftLabel,
                            style: pw.TextStyle(
                              fontSize: 8.2,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 4),
                        pw.Expanded(
                          child: pw.Text(
                            leftValue.isEmpty ? ' ' : leftValue,
                            style: const pw.TextStyle(fontSize: 8.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(
                          width: 24,
                          child: pw.Text(
                            rightLabel,
                            style: pw.TextStyle(
                              fontSize: 8.2,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 4),
                        pw.Expanded(
                          child: pw.Text(
                            rightValue.isEmpty ? ' ' : rightValue,
                            style: const pw.TextStyle(fontSize: 8.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          pw.Widget buildRow(String label, String value) {
            final emphasized = label == 'Importe';
            final labelWidth = emphasized
                ? 40.0
                : label.length >= 10
                ? 54.0
                : label.length >= 8
                ? 48.0
                : 36.0;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: labelWidth,
                    child: pw.Text(
                      label,
                      style: pw.TextStyle(
                        fontSize: emphasized ? 9.6 : 8.4,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: emphasized ? 6 : 5),
                  if (emphasized)
                    pw.Expanded(
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                          value.isEmpty ? ' ' : value,
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 15.2,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else
                    pw.Expanded(
                      child: pw.Text(
                        value.isEmpty ? ' ' : value,
                        style: pw.TextStyle(
                          fontSize: 8.6,
                          fontWeight: pw.FontWeight.normal,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }

          return pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColors.grey600, width: 1),
            ),
            padding: const pw.EdgeInsets.fromLTRB(8, 8, 8, 9),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Spacer(),
                    if (logoImage != null)
                      pw.SizedBox(
                        width: 38,
                        height: 18,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                    if (logoImage != null) pw.SizedBox(width: 4),
                    pw.Text(
                      'DICSA',
                      style: pw.TextStyle(
                        fontSize: 12.8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Spacer(),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    'Desperdicios Industriales Celaya SA de CV',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 7.7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Center(
                  child: pw.Text(
                    'Calle Bernal #7 Col. Rancho Seco Celaya, Gto.',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 7.0),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'Tel: 461-616-7310 ext. 102',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 7.0),
                  ),
                ),
                divider(spacing: 5),
                pw.Center(
                  child: pw.Text(
                    _isSales ? 'COMPROBANTE DE VENTA' : 'COMPROBANTE DE COMPRA',
                    style: pw.TextStyle(
                      fontSize: 8.9,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                divider(spacing: 5),
                buildPairRow(
                  'Fecha',
                  (row['date'] ?? '').toString(),
                  'Hora',
                  printedTime,
                ),
                buildRow('Ticket', (row['ticket'] ?? '').toString()),
                buildRow(
                  _counterpartyLabel,
                  (row['provider'] ?? '').toString(),
                ),
                if (_isSales && exitOrderNumber.trim().isNotEmpty)
                  buildRow('Orden salida', exitOrderNumber.trim()),
                buildRow('Material', (row['material'] ?? '').toString()),
                divider(spacing: 4),
                buildPairRow(
                  'Bruto',
                  '${bruto.toStringAsFixed(2)} kg',
                  'Tara',
                  '${tara.toStringAsFixed(2)} kg',
                ),
                buildPairRow(
                  'Neto',
                  '${neto.toStringAsFixed(2)} kg',
                  'Peso',
                  '${peso.toStringAsFixed(2)} kg',
                ),
                divider(spacing: 4),
                buildPairRow(
                  'Hum.',
                  '${humidity.toStringAsFixed(2)} %',
                  'Bas.',
                  '${trash.toStringAsFixed(2)} kg',
                ),
                buildPairRow(
                  'Precio',
                  '${_money(precio)} /kg',
                  'Sobre',
                  '${_money(premium)} /kg',
                ),
                divider(spacing: 4),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.fromLTRB(7, 7, 7, 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey500, width: 1),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: buildRow('Importe', _money(importe)),
                ),
                pw.Spacer(),
                pw.Row(
                  children: [
                    pw.Text(
                      'Firma:',
                      style: pw.TextStyle(
                        fontSize: 9.8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      child: pw.Container(
                        height: 10,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(
                              color: PdfColors.black,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    '¡GRACIAS!',
                    style: pw.TextStyle(
                      fontSize: 9.4,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    return doc.save();
  }

  Future<void> _openTicketPdfFromDialog({
    required Map<String, dynamic> row,
    required TextEditingController humedadC,
    required TextEditingController basuraC,
    required TextEditingController sobreprecioC,
    required TextEditingController exitOrderNumberC,
    required TextEditingController comentarioC,
    required String status,
  }) async {
    try {
      final pdfBytes = await _buildTicketPrintPdfBytes(
        row: row,
        humidity: _parseDraftController(humedadC),
        trash: _parseDraftController(basuraC),
        premium: _parseDraftController(sobreprecioC),
        exitOrderNumber: exitOrderNumberC.text.trim(),
        status: status,
        comment: comentarioC.text.trim(),
      );
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final ticket = (row['ticket'] ?? 'ticket').toString().replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '_',
      );
      final file = File(
        '${Directory.systemTemp.path}/menudeo_ticket_${ticket}_$stamp.pdf',
      );
      await file.writeAsBytes(pdfBytes, flush: true);
      await _openPdfFile(file.path);
    } catch (e) {
      _toast('No se pudo abrir el ticket en PDF: $e');
    }
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
    final filteredEntries = _filteredTicketEntries;
    final visibleEntries = _pageEntries(filteredEntries);
    final totalPages = _totalPagesFor(filteredEntries.length);
    final currentPage = _effectiveCurrentPageFor(filteredEntries.length);
    final activeVisibleIndex = visibleEntries.indexWhere(
      (entry) => entry.index == _activeRowIndex,
    );
    return AreaThemeScope(
      tokens: menudeoAreaTokens,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (isEscapeKey(event.logicalKey) && _menuOpen) {
            setState(() => _menuOpen = false);
            return KeyEventResult.handled;
          }
          if (isEscapeKey(event.logicalKey) && _selectedRowIndexes.isNotEmpty) {
            setState(_clearSelection);
            return KeyEventResult.handled;
          }
          if (_isShortcutModifierPressed() &&
              event.logicalKey == LogicalKeyboardKey.keyA &&
              visibleEntries.isNotEmpty) {
            setState(() => _selectAllVisibleRows(visibleEntries));
            return KeyEventResult.handled;
          }
          if (visibleEntries.isNotEmpty &&
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            final current = activeVisibleIndex < 0 ? 0 : activeVisibleIndex;
            final next = (current + 1).clamp(0, visibleEntries.length - 1);
            final nextIndex = visibleEntries[next].index;
            setState(() {
              if (_isShiftPressed()) {
                _extendSelectionTo(nextIndex, visibleEntries);
              } else {
                _selectSingleRow(nextIndex, visibleEntries);
              }
            });
            _ensureRowVisible(nextIndex);
            return KeyEventResult.handled;
          }
          if (visibleEntries.isNotEmpty &&
              event.logicalKey == LogicalKeyboardKey.arrowUp) {
            final current = activeVisibleIndex < 0 ? 0 : activeVisibleIndex;
            final next = (current - 1).clamp(0, visibleEntries.length - 1);
            final nextIndex = visibleEntries[next].index;
            setState(() {
              if (_isShiftPressed()) {
                _extendSelectionTo(nextIndex, visibleEntries);
              } else {
                _selectSingleRow(nextIndex, visibleEntries);
              }
            });
            _ensureRowVisible(nextIndex);
            return KeyEventResult.handled;
          }
          if (visibleEntries.isNotEmpty &&
              event.logicalKey == LogicalKeyboardKey.space) {
            final current = activeVisibleIndex < 0 ? 0 : activeVisibleIndex;
            setState(() => _toggleRowSelection(visibleEntries[current].index));
            return KeyEventResult.handled;
          }
          if (visibleEntries.isNotEmpty && isEnterKey(event.logicalKey)) {
            unawaited(_openActiveTicketLot());
            return KeyEventResult.handled;
          }
          if (visibleEntries.isNotEmpty && isDeleteKey(event.logicalKey)) {
            unawaited(_deleteSelectedRows());
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AppShell(
          background: const _MenudeoTicketsBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 6,
          padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
          leadingBuilder: (_, _) => _TicketsHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, animation) =>
              MenudeoHeaderBrand(contentAnim: animation, title: _headerTitle),
          trailingBuilder: (_, _) => _TicketsHeaderButton(
            label: 'Cerrar sesión',
            icon: Icons.logout_rounded,
            onTap: _logout,
          ),
          child: Stack(
            children: [
              _TicketsBody(
                moduleTitle: _moduleTitle,
                counterpartyLabel: _counterpartyLabel,
                newTicketButtonLabel: _newTicketButtonLabel,
                emptyGridLabel: _emptyGridLabel,
                onShowNewTicket: _showNewTicketDialog,
                onExportCsv: _exportFilteredTicketsCsv,
                formatMoney: _money,
                exportingCsv: _exportingCsv,
                entries: visibleEntries,
                filteredEntryCount: filteredEntries.length,
                activeRowIndex: _activeRowIndex,
                selectedRowIndexes: _selectedRowIndexes,
                rowsScrollController: _ticketsRowsScrollController,
                rowsViewportKey: _ticketsRowsViewportKey,
                activeFilterCount:
                    (_ticketDateFilter != null ? 1 : 0) +
                    (_ticketNumberGridFilter.isNotEmpty ? 1 : 0) +
                    (_providerGridFilter.isNotEmpty ? 1 : 0) +
                    (_materialGridFilter.isNotEmpty ? 1 : 0) +
                    (_statusGridFilter.isNotEmpty ? 1 : 0),
                onOpenRow: _showTicketDetailDialog,
                onRowTap: (index) => _handleRowTap(index, visibleEntries),
                onRowActionMenuOpen: _alignSelectionForContextMenu,
                onRowMenuAction: _handleRowMenuAction,
                rowKeyForIndex: _ticketRowItemKey,
                onRowDragEnter: (index) =>
                    _handleRowDragEnter(index, visibleEntries),
                onRowPointerEnd: _handleRowPointerEnd,
                onRowsPointerDown: (event) =>
                    _handleRowsPointerDown(event, visibleEntries),
                onRowsPointerMove: (event) =>
                    _handleRowsPointerMove(event, visibleEntries),
                onRowsPointerEnd: _handleRowPointerEnd,
                onRowDoubleTap: _showTicketDetailDialog,
                onRowSecondaryTapDown: (context, index, offset) =>
                    _handleRowSecondaryTap(
                      context,
                      rowIndex: index,
                      globalPosition: offset,
                    ),
                onOpenDateFilter: _openTicketDateFilter,
                onOpenTicketFilter: () => _openValueFilter(
                  label: 'TICKET',
                  current: _ticketNumberGridFilter,
                  options:
                      _ticketRows
                          .map((row) => (row['ticket'] ?? '').toString())
                          .where((value) => value.trim().isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort(),
                  onApply: (next) => _ticketNumberGridFilter = next,
                ),
                onOpenProviderFilter: () => _openValueFilter(
                  label: _counterpartyLabelUpper,
                  current: _providerGridFilter,
                  options:
                      _ticketRows
                          .map((row) => (row['provider'] ?? '').toString())
                          .where((value) => value.trim().isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort(),
                  onApply: (next) => _providerGridFilter = next,
                ),
                onOpenMaterialFilter: () => _openValueFilter(
                  label: 'MATERIAL',
                  current: _materialGridFilter,
                  options:
                      _ticketRows
                          .map((row) => (row['material'] ?? '').toString())
                          .where((value) => value.trim().isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort(),
                  onApply: (next) => _materialGridFilter = next,
                ),
                onOpenStatusFilter: () => _openValueFilter(
                  label: 'ESTADO',
                  current: _statusGridFilter,
                  options:
                      _ticketRows
                          .map((row) => (row['status'] ?? '').toString())
                          .where((value) => value.trim().isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort(),
                  onApply: (next) => _statusGridFilter = next,
                ),
                hasDateFilter: _ticketDateFilter != null,
                hasTicketFilter: _ticketNumberGridFilter.isNotEmpty,
                hasProviderFilter: _providerGridFilter.isNotEmpty,
                hasMaterialFilter: _materialGridFilter.isNotEmpty,
                hasStatusFilter: _statusGridFilter.isNotEmpty,
                onClearFilters: _hasGridFilters() ? _clearGridFilters : null,
                currentPage: currentPage,
                totalPages: totalPages,
                pageSize: _pageSize,
                onPreviousPage: currentPage > 0
                    ? () => setState(() => _currentPage = currentPage - 1)
                    : null,
                onNextPage: currentPage < totalPages - 1
                    ? () => setState(() => _currentPage = currentPage + 1)
                    : null,
                onPageSizeChanged: (value) {
                  setState(() {
                    _pageSize = value;
                    _currentPage = 0;
                  });
                },
                onTapOutsideSelection: _selectedRowIndexes.isNotEmpty
                    ? () => setState(_clearSelection)
                    : null,
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
                  child: _TicketsSidePanel(
                    isSales: _isSales,
                    onNavigate: _handleNavigationAction,
                    onBack: _goBack,
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

class _TicketsBody extends StatelessWidget {
  final String moduleTitle;
  final String counterpartyLabel;
  final String newTicketButtonLabel;
  final String emptyGridLabel;
  final Future<void> Function() onShowNewTicket;
  final Future<void> Function() onExportCsv;
  final String Function(num value) formatMoney;
  final bool exportingCsv;
  final List<_TicketGridEntry> entries;
  final int filteredEntryCount;
  final int activeRowIndex;
  final Set<int> selectedRowIndexes;
  final ScrollController rowsScrollController;
  final Key rowsViewportKey;
  final int activeFilterCount;
  final Future<void> Function(int index) onOpenRow;
  final void Function(int index) onRowTap;
  final void Function(int index) onRowActionMenuOpen;
  final Future<void> Function(int index, _TicketGridMenuAction action)
  onRowMenuAction;
  final GlobalKey Function(int index) rowKeyForIndex;
  final void Function(int index) onRowDragEnter;
  final VoidCallback onRowPointerEnd;
  final void Function(PointerDownEvent event) onRowsPointerDown;
  final void Function(PointerMoveEvent event) onRowsPointerMove;
  final VoidCallback onRowsPointerEnd;
  final Future<void> Function(int index) onRowDoubleTap;
  final Future<void> Function(
    BuildContext context,
    int index,
    Offset globalPosition,
  )
  onRowSecondaryTapDown;
  final Future<void> Function() onOpenDateFilter;
  final Future<void> Function() onOpenTicketFilter;
  final Future<void> Function() onOpenProviderFilter;
  final Future<void> Function() onOpenMaterialFilter;
  final Future<void> Function() onOpenStatusFilter;
  final bool hasDateFilter;
  final bool hasTicketFilter;
  final bool hasProviderFilter;
  final bool hasMaterialFilter;
  final bool hasStatusFilter;
  final VoidCallback? onClearFilters;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<int> onPageSizeChanged;
  final VoidCallback? onTapOutsideSelection;

  const _TicketsBody({
    required this.moduleTitle,
    required this.counterpartyLabel,
    required this.newTicketButtonLabel,
    required this.emptyGridLabel,
    required this.onShowNewTicket,
    required this.onExportCsv,
    required this.formatMoney,
    required this.exportingCsv,
    required this.entries,
    required this.filteredEntryCount,
    required this.activeRowIndex,
    required this.selectedRowIndexes,
    required this.rowsScrollController,
    required this.rowsViewportKey,
    required this.activeFilterCount,
    required this.onOpenRow,
    required this.onRowTap,
    required this.onRowActionMenuOpen,
    required this.onRowMenuAction,
    required this.rowKeyForIndex,
    required this.onRowDragEnter,
    required this.onRowPointerEnd,
    required this.onRowsPointerDown,
    required this.onRowsPointerMove,
    required this.onRowsPointerEnd,
    required this.onRowDoubleTap,
    required this.onRowSecondaryTapDown,
    required this.onOpenDateFilter,
    required this.onOpenTicketFilter,
    required this.onOpenProviderFilter,
    required this.onOpenMaterialFilter,
    required this.onOpenStatusFilter,
    required this.hasDateFilter,
    required this.hasTicketFilter,
    required this.hasProviderFilter,
    required this.hasMaterialFilter,
    required this.hasStatusFilter,
    required this.onClearFilters,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPageSizeChanged,
    required this.onTapOutsideSelection,
  });

  @override
  Widget build(BuildContext context) {
    double rowNeto(Map<String, dynamic> row) =>
        ((row['gross'] as num).toDouble() - (row['tare'] as num).toDouble());

    double rowPeso(Map<String, dynamic> row) =>
        (rowNeto(row) * (1 - ((row['humidity'] as num).toDouble() / 100))) -
        (row['trash'] as num).toDouble();

    double rowImporte(Map<String, dynamic> row) =>
        rowPeso(row) *
        ((row['price'] as num).toDouble() + (row['premium'] as num).toDouble());

    final visibleNetoTotal = entries.fold<double>(
      0,
      (sum, entry) => sum + rowNeto(entry.row),
    );
    final visibleImporteTotal = entries.fold<double>(
      0,
      (sum, entry) => sum + rowImporte(entry.row),
    );
    final selectedEntries = entries
        .where((entry) => selectedRowIndexes.contains(entry.index))
        .toList(growable: false);
    final selectedNetoTotal = selectedEntries.fold<double>(
      0,
      (sum, entry) => sum + rowNeto(entry.row),
    );
    final selectedImporteTotal = selectedEntries.fold<double>(
      0,
      (sum, entry) => sum + rowImporte(entry.row),
    );
    final selectedNetoAvg = selectedEntries.isEmpty
        ? 0.0
        : selectedNetoTotal / selectedEntries.length;
    final selectedImporteAvg = selectedEntries.isEmpty
        ? 0.0
        : selectedImporteTotal / selectedEntries.length;

    return TapRegion(
      groupId: _kTicketsSelectionTapRegionGroup,
      onTapOutside: (_) => onTapOutsideSelection?.call(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 1440,
                minHeight: constraints.maxHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 56, right: 2, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TicketsModuleTopBar(
                      moduleTitle: moduleTitle,
                      newTicketButtonLabel: newTicketButtonLabel,
                      visibleCount: entries.length,
                      filteredCount: filteredEntryCount,
                      selectedCount: selectedRowIndexes.length,
                      activeFilterCount: activeFilterCount,
                      visibleNetoTotal: visibleNetoTotal,
                      visibleImporteTotal: visibleImporteTotal,
                      selectedNetoTotal: selectedNetoTotal,
                      selectedImporteTotal: selectedImporteTotal,
                      selectedNetoAvg: selectedNetoAvg,
                      selectedImporteAvg: selectedImporteAvg,
                      formatMoney: formatMoney,
                      exportingCsv: exportingCsv,
                      onExportCsv: onExportCsv,
                      onShowNewTicket: onShowNewTicket,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _TicketsGridCard(
                        counterpartyLabel: counterpartyLabel,
                        emptyGridLabel: emptyGridLabel,
                        entries: entries,
                        activeRowIndex: activeRowIndex,
                        selectedRowIndexes: selectedRowIndexes,
                        rowsScrollController: rowsScrollController,
                        rowsViewportKey: rowsViewportKey,
                        activeFilterCount: activeFilterCount,
                        formatMoney: formatMoney,
                        onOpenRow: onOpenRow,
                        onRowTap: onRowTap,
                        onRowActionMenuOpen: onRowActionMenuOpen,
                        onRowMenuAction: onRowMenuAction,
                        rowKeyForIndex: rowKeyForIndex,
                        onRowDragEnter: onRowDragEnter,
                        onRowPointerEnd: onRowPointerEnd,
                        onRowsPointerDown: onRowsPointerDown,
                        onRowsPointerMove: onRowsPointerMove,
                        onRowsPointerEnd: onRowsPointerEnd,
                        onRowDoubleTap: onRowDoubleTap,
                        onRowSecondaryTapDown: onRowSecondaryTapDown,
                        onOpenDateFilter: onOpenDateFilter,
                        onOpenTicketFilter: onOpenTicketFilter,
                        onOpenProviderFilter: onOpenProviderFilter,
                        onOpenMaterialFilter: onOpenMaterialFilter,
                        onOpenStatusFilter: onOpenStatusFilter,
                        hasDateFilter: hasDateFilter,
                        hasTicketFilter: hasTicketFilter,
                        hasProviderFilter: hasProviderFilter,
                        hasMaterialFilter: hasMaterialFilter,
                        hasStatusFilter: hasStatusFilter,
                        onClearFilters: onClearFilters,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: MenudeoGridPager(
                        currentPage: currentPage,
                        totalPages: totalPages,
                        pageSize: pageSize,
                        totalRows: filteredEntryCount,
                        onPrevious: onPreviousPage,
                        onNext: onNextPage,
                        onPageSizeChanged: onPageSizeChanged,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TicketsModuleTopBar extends StatelessWidget {
  final String moduleTitle;
  final String newTicketButtonLabel;
  final int visibleCount;
  final int filteredCount;
  final int selectedCount;
  final int activeFilterCount;
  final double visibleNetoTotal;
  final double visibleImporteTotal;
  final double selectedNetoTotal;
  final double selectedImporteTotal;
  final double selectedNetoAvg;
  final double selectedImporteAvg;
  final String Function(num value) formatMoney;
  final bool exportingCsv;
  final Future<void> Function() onExportCsv;
  final Future<void> Function() onShowNewTicket;

  const _TicketsModuleTopBar({
    required this.moduleTitle,
    required this.newTicketButtonLabel,
    required this.visibleCount,
    required this.filteredCount,
    required this.selectedCount,
    required this.activeFilterCount,
    required this.visibleNetoTotal,
    required this.visibleImporteTotal,
    required this.selectedNetoTotal,
    required this.selectedImporteTotal,
    required this.selectedNetoAvg,
    required this.selectedImporteAvg,
    required this.formatMoney,
    required this.exportingCsv,
    required this.onExportCsv,
    required this.onShowNewTicket,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            moduleTitle,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        AppGlassToolbarPanel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rightInfo = _TicketsSelectionInfo(
                selectedCount: selectedCount,
                activeFilterCount: activeFilterCount,
                netoTotalLabel: selectedCount > 0
                    ? selectedNetoTotal.toStringAsFixed(2)
                    : null,
                netoAvgLabel: selectedCount > 0
                    ? selectedNetoAvg.toStringAsFixed(2)
                    : null,
                importeAvgLabel: selectedCount > 0
                    ? formatMoney(selectedImporteAvg)
                    : null,
                importeTotalLabel: selectedCount > 0
                    ? formatMoney(selectedImporteTotal)
                    : null,
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: _ticketsGlassToolbarActionStyle(),
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
                    style: contractPrimaryButtonStyle(context),
                    onPressed: onShowNewTicket,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: Text(newTicketButtonLabel),
                  ),
                ],
              );
              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    actions,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: rightInfo),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: actions),
                  const SizedBox(width: 10),
                  rightInfo,
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
              MenudeoMetricCard(
                icon: Icons.scale_rounded,
                title: 'NETO',
                value: visibleNetoTotal.toStringAsFixed(2),
                detail: '$filteredCount registros filtrados',
                accent: menudeoAreaTokens.primaryStrong,
              ),
              MenudeoMetricCard(
                icon: Icons.payments_rounded,
                title: 'IMPORTE',
                value: formatMoney(visibleImporteTotal),
                detail: activeFilterCount > 0
                    ? 'Con $activeFilterCount filtros activos'
                    : 'Sin filtros activos',
                accent: menudeoAreaTokens.accent,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TicketsSelectionInfo extends StatelessWidget {
  final int selectedCount;
  final int activeFilterCount;
  final String? netoTotalLabel;
  final String? netoAvgLabel;
  final String? importeTotalLabel;
  final String? importeAvgLabel;

  const _TicketsSelectionInfo({
    required this.selectedCount,
    required this.activeFilterCount,
    this.netoTotalLabel,
    this.netoAvgLabel,
    this.importeTotalLabel,
    this.importeAvgLabel,
  });

  @override
  Widget build(BuildContext context) {
    final summary = <String>[
      if (netoTotalLabel != null) 'Neto: $netoTotalLabel',
      if (importeTotalLabel != null) 'Importe: $importeTotalLabel',
      if (netoAvgLabel != null) 'Promedio Neto: $netoAvgLabel',
      if (importeAvgLabel != null) 'Promedio Importe: $importeAvgLabel',
    ];
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
            color: kMenudeoMutedText,
          ),
          textAlign: TextAlign.right,
        ),
        if (summary.isNotEmpty)
          Text(
            summary.join(' · '),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kMenudeoMutedText,
            ),
            textAlign: TextAlign.right,
          ),
        if (activeFilterCount > 0)
          Text(
            '$activeFilterCount filtros activos',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kMenudeoMutedText,
            ),
            textAlign: TextAlign.right,
          ),
      ],
    );
  }
}

class _TicketDialogHeader extends StatelessWidget {
  final Future<void> Function()? onPrint;
  final VoidCallback onClose;

  const _TicketDialogHeader({this.onPrint, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.54),
            tokens.surfaceTint.withValues(alpha: 0.42),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.38),
            blurRadius: 16,
            offset: const Offset(-2, -2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DicsaLogoD(size: 32),
              const SizedBox(width: 10),
              Text(
                'DICSA',
                style: TextStyle(
                  color: tokens.primaryStrong,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
          Positioned(
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onPrint != null) ...[
                  _TicketDialogActionButton(
                    icon: Icons.print_rounded,
                    onTap: () => unawaited(onPrint!()),
                  ),
                  const SizedBox(width: 8),
                ],
                _TicketDialogActionButton(
                  icon: Icons.close_rounded,
                  onTap: onClose,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketDialogActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _TicketDialogActionButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.96),
                tokens.surfaceTint.withValues(alpha: 0.90),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: tokens.primarySoft.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.46),
                blurRadius: 10,
                offset: const Offset(-2, -2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, size: 22, color: tokens.primaryStrong),
        ),
      ),
    );
  }
}

class _NewTicketCard extends StatelessWidget {
  final String counterpartyLabel;
  final bool showExitOrderField;
  final String dateLabel;
  final Future<void> Function() onPickDate;
  final TextEditingController ticketC;
  final TextEditingController brutoC;
  final TextEditingController taraC;
  final TextEditingController humedadC;
  final TextEditingController basuraC;
  final TextEditingController precioC;
  final TextEditingController sobreprecioC;
  final TextEditingController exitOrderNumberC;
  final TextEditingController comentarioC;
  final List<String> providerOptions;
  final List<String> materialOptions;
  final String selectedProvider;
  final String selectedMaterial;
  final String selectedStatus;
  final bool splitEnabled;
  final int splitCount;
  final List<_SplitDraft> splitDrafts;
  final String Function(num value) formatMoney;
  final double? Function(String material) catalogPriceForMaterial;
  final bool loadingCatalogPrice;
  final bool creatingTicketDraft;
  final bool hasCatalogPrice;
  final ValueChanged<String> onProviderChanged;
  final ValueChanged<String> onMaterialChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<bool> onSplitChanged;
  final ValueChanged<int> onSplitCountChanged;
  final void Function(int index, String value) onSplitMaterialChanged;
  final VoidCallback onCreateTicket;

  const _NewTicketCard({
    required this.counterpartyLabel,
    required this.showExitOrderField,
    required this.dateLabel,
    required this.onPickDate,
    required this.ticketC,
    required this.brutoC,
    required this.taraC,
    required this.humedadC,
    required this.basuraC,
    required this.precioC,
    required this.sobreprecioC,
    required this.exitOrderNumberC,
    required this.comentarioC,
    required this.providerOptions,
    required this.materialOptions,
    required this.selectedProvider,
    required this.selectedMaterial,
    required this.selectedStatus,
    required this.splitEnabled,
    required this.splitCount,
    required this.splitDrafts,
    required this.formatMoney,
    required this.catalogPriceForMaterial,
    required this.loadingCatalogPrice,
    required this.creatingTicketDraft,
    required this.hasCatalogPrice,
    required this.onProviderChanged,
    required this.onMaterialChanged,
    required this.onStatusChanged,
    required this.onSplitChanged,
    required this.onSplitCountChanged,
    required this.onSplitMaterialChanged,
    required this.onCreateTicket,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        ticketC,
        brutoC,
        taraC,
        humedadC,
        basuraC,
        precioC,
        sobreprecioC,
        exitOrderNumberC,
        comentarioC,
      ]),
      builder: (context, _) {
        final bruto = _parse(brutoC);
        final tara = _parse(taraC);
        final humedad = _parse(humedadC);
        final basura = _parse(basuraC);
        final precio = _parse(precioC);
        final sobreprecio = _parse(sobreprecioC);
        final neto = bruto - tara;
        final pesoPagable = (neto * (1 - (humedad / 100))) - basura;
        final importe = pesoPagable * (precio + sobreprecio);
        return ContractGlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: tokens.primarySoft.withValues(alpha: 0.28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.primaryStrong.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loadingCatalogPrice
                            ? 'Cargando precio vigente desde catálogo...'
                            : hasCatalogPrice
                            ? 'Precio tomado en automático según ${counterpartyLabel.toLowerCase()} y material.'
                            : 'No se encontró precio vigente para esa combinación en catálogo.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tokens.badgeText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _TicketSheetRow(
                        label: 'Fecha',
                        child: _TicketSheetFieldFrame(
                          child: InkWell(
                            onTap: onPickDate,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dateLabel,
                                    style: _sheetValueStyle(tokens),
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
                      _TicketSheetRow(
                        label: 'Ticket',
                        child: _TicketSheetFieldFrame(
                          child: _sheetTextField(
                            ticketC,
                            tokens,
                            numeric: false,
                          ),
                        ),
                      ),
                      _TicketSheetRow(
                        label: counterpartyLabel,
                        child: _TicketSheetFieldFrame(
                          child: _sheetDropdown(
                            tokens,
                            label: counterpartyLabel.toUpperCase(),
                            value: selectedProvider,
                            values: providerOptions,
                            onChanged: onProviderChanged,
                          ),
                        ),
                      ),
                      _TicketSheetRow(
                        label: 'Material',
                        child: _TicketSheetFieldFrame(
                          child: _sheetDropdown(
                            tokens,
                            label: 'MATERIAL',
                            value: selectedMaterial,
                            values: materialOptions,
                            onChanged: onMaterialChanged,
                          ),
                        ),
                      ),
                      _TicketSheetRow(
                        label: 'Bruto',
                        child: _TicketSheetFieldFrame(
                          child: _sheetTextField(brutoC, tokens),
                        ),
                      ),
                      _TicketSheetRow(
                        label: 'Tara',
                        child: _TicketSheetFieldFrame(
                          child: _sheetTextField(taraC, tokens),
                        ),
                      ),
                      _TicketSheetRow(
                        label: 'Neto',
                        child: _TicketSheetFieldFrame(
                          child: Text(
                            neto.toStringAsFixed(2),
                            style: _sheetValueStyle(tokens),
                          ),
                        ),
                      ),
                      _TicketSheetRow(
                        label: 'Humedad',
                        child: _TicketSheetFieldFrame(
                          trailing: Text(
                            '%',
                            style: TextStyle(
                              color: tokens.badgeText,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          child: _sheetTextField(humedadC, tokens),
                        ),
                      ),
                      _TicketSheetRow(
                        label: 'Basura',
                        child: _TicketSheetFieldFrame(
                          child: _sheetTextField(basuraC, tokens),
                        ),
                      ),
                      _TicketSheetRow(
                        label: 'Peso',
                        child: _TicketSheetFieldFrame(
                          child: Text(
                            pesoPagable.toStringAsFixed(2),
                            style: _sheetValueStyle(tokens),
                          ),
                        ),
                      ),
                      _TicketSheetRow(
                        label: 'Precio',
                        child: _TicketSheetFieldFrame(
                          child: Text(
                            formatMoney(double.tryParse(precioC.text) ?? 0),
                            style: _sheetValueStyle(tokens),
                          ),
                        ),
                      ),
                      _TicketSheetRow(
                        label: 'Sobreprecio',
                        child: _TicketSheetFieldFrame(
                          child: _sheetTextField(sobreprecioC, tokens),
                        ),
                      ),
                      _TicketSheetRow(
                        label: 'Importe',
                        child: _TicketSheetFieldFrame(
                          emphasized: true,
                          child: Text(
                            formatMoney(importe),
                            style: _sheetValueStyle(tokens, emphasized: true),
                          ),
                        ),
                      ),
                      _TicketSheetRow(
                        label: 'Estado',
                        child: _TicketSheetFieldFrame(
                          child: _sheetDropdown(
                            tokens,
                            label: 'ESTADO',
                            value: selectedStatus,
                            values: const <String>['PENDIENTE', 'PAGADO'],
                            onChanged: onStatusChanged,
                          ),
                        ),
                      ),
                      if (showExitOrderField)
                        _TicketSheetRow(
                          label: 'Orden de salida',
                          child: _TicketSheetFieldFrame(
                            child: _sheetTextField(
                              exitOrderNumberC,
                              tokens,
                              numeric: false,
                            ),
                          ),
                        ),
                      _TicketSheetRow(
                        label: 'Comentario',
                        alignTop: true,
                        child: _TicketSheetFieldFrame(
                          child: TextField(
                            controller: comentarioC,
                            maxLines: 2,
                            decoration: const InputDecoration.collapsed(
                              hintText: 'Comentario / observación',
                            ),
                            style: _sheetValueStyle(tokens),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: tokens.badgeBackground.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: tokens.primaryStrong.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Dividir ticket',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: tokens.primaryStrong,
                                    ),
                                  ),
                                ),
                                Switch.adaptive(
                                  value: splitEnabled,
                                  onChanged: onSplitChanged,
                                ),
                              ],
                            ),
                            Text(
                              'El ticket principal se guarda como ${ticketC.text.isEmpty ? '56048' : ticketC.text}-A y aquí completas las partes adicionales.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: tokens.badgeText,
                              ),
                            ),
                            if (splitEnabled) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(
                                    'Partes:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: tokens.primaryStrong,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SegmentedButton<int>(
                                    segments: const <ButtonSegment<int>>[
                                      ButtonSegment(value: 2, label: Text('2')),
                                      ButtonSegment(value: 3, label: Text('3')),
                                      ButtonSegment(value: 4, label: Text('4')),
                                    ],
                                    selected: <int>{splitCount},
                                    onSelectionChanged: (value) =>
                                        onSplitCountChanged(value.first),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List<Widget>.generate(splitCount, (
                                  index,
                                ) {
                                  final suffix = String.fromCharCode(
                                    65 + index,
                                  );
                                  return _SplitPreviewChip(
                                    label: '${ticketC.text}-$suffix',
                                  );
                                }),
                              ),
                              const SizedBox(height: 14),
                              _SplitTicketCard(
                                suffix: 'A',
                                ticketBase: ticketC.text.trim(),
                                materialOptions: materialOptions,
                                selectedMaterial: selectedMaterial,
                                brutoC: brutoC,
                                taraC: taraC,
                                humedadC: humedadC,
                                basuraC: basuraC,
                                sobreprecioC: sobreprecioC,
                                comentarioC: comentarioC,
                                onMaterialChanged: onMaterialChanged,
                                formatMoney: formatMoney,
                                catalogPriceForMaterial:
                                    catalogPriceForMaterial,
                                helperText: 'Ticket principal ya capturado',
                              ),
                              if (splitDrafts.isNotEmpty)
                                const SizedBox(height: 12),
                              ...List<Widget>.generate(splitDrafts.length, (
                                index,
                              ) {
                                final suffix = String.fromCharCode(66 + index);
                                final draft = splitDrafts[index];
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index == splitDrafts.length - 1
                                        ? 0
                                        : 12,
                                  ),
                                  child: _SplitTicketCard(
                                    suffix: suffix,
                                    ticketBase: ticketC.text.trim(),
                                    materialOptions: materialOptions,
                                    selectedMaterial: draft.selectedMaterial,
                                    brutoC: draft.brutoC,
                                    taraC: draft.taraC,
                                    humedadC: draft.humedadC,
                                    basuraC: draft.basuraC,
                                    sobreprecioC: draft.sobreprecioC,
                                    comentarioC: draft.comentarioC,
                                    onMaterialChanged: (value) =>
                                        onSplitMaterialChanged(index, value),
                                    formatMoney: formatMoney,
                                    catalogPriceForMaterial:
                                        catalogPriceForMaterial,
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            style: contractPrimaryButtonStyle(context),
                            onPressed: creatingTicketDraft
                                ? null
                                : splitEnabled
                                ? onCreateTicket
                                : hasCatalogPrice
                                ? onCreateTicket
                                : null,
                            icon: creatingTicketDraft
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add_circle_outline_rounded),
                            label: Text(
                              creatingTicketDraft
                                  ? 'Guardando...'
                                  : splitEnabled
                                  ? 'Crear split'
                                  : 'Crear ticket',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _parse(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;

  TextStyle _sheetValueStyle(
    ContractAreaTokens tokens, {
    bool emphasized = false,
  }) {
    return TextStyle(
      color: tokens.primaryStrong,
      fontSize: emphasized ? 18 : 16,
      fontWeight: emphasized ? FontWeight.w900 : FontWeight.w800,
    );
  }

  Widget _sheetTextField(
    TextEditingController controller,
    ContractAreaTokens tokens, {
    bool numeric = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: const InputDecoration.collapsed(hintText: ''),
      style: _sheetValueStyle(tokens),
    );
  }

  Widget _sheetDropdown(
    ContractAreaTokens tokens, {
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    if (values.isEmpty) {
      return Text(
        'Sin opciones',
        style: TextStyle(
          color: tokens.badgeText,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return _TicketCompactPickerField(
      label: label,
      value: values.contains(value) ? value : null,
      items: values,
      onChanged: onChanged,
    );
  }
}

class _SplitDraft {
  final TextEditingController brutoC = TextEditingController();
  final TextEditingController taraC = TextEditingController();
  final TextEditingController humedadC = TextEditingController();
  final TextEditingController basuraC = TextEditingController();
  final TextEditingController sobreprecioC = TextEditingController();
  final TextEditingController comentarioC = TextEditingController();
  String selectedMaterial = '';

  void dispose() {
    brutoC.dispose();
    taraC.dispose();
    humedadC.dispose();
    basuraC.dispose();
    sobreprecioC.dispose();
    comentarioC.dispose();
  }
}

class _SplitTicketCard extends StatelessWidget {
  final String suffix;
  final String ticketBase;
  final List<String> materialOptions;
  final String selectedMaterial;
  final TextEditingController brutoC;
  final TextEditingController taraC;
  final TextEditingController humedadC;
  final TextEditingController basuraC;
  final TextEditingController sobreprecioC;
  final TextEditingController comentarioC;
  final ValueChanged<String> onMaterialChanged;
  final String Function(num value) formatMoney;
  final double? Function(String material) catalogPriceForMaterial;
  final String? helperText;

  const _SplitTicketCard({
    required this.suffix,
    required this.ticketBase,
    required this.materialOptions,
    required this.selectedMaterial,
    required this.brutoC,
    required this.taraC,
    required this.humedadC,
    required this.basuraC,
    required this.sobreprecioC,
    required this.comentarioC,
    required this.onMaterialChanged,
    required this.formatMoney,
    required this.catalogPriceForMaterial,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        brutoC,
        taraC,
        humedadC,
        basuraC,
        sobreprecioC,
        comentarioC,
      ]),
      builder: (context, _) {
        final bruto = _parse(brutoC);
        final tara = _parse(taraC);
        final humedad = _parse(humedadC);
        final basura = _parse(basuraC);
        final sobreprecio = _parse(sobreprecioC);
        final precio = catalogPriceForMaterial(selectedMaterial) ?? 0;
        final neto = bruto - tara;
        final peso = (neto * (1 - (humedad / 100))) - basura;
        final importe = peso * (precio + sobreprecio);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tokens.primarySoft.withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${ticketBase.isEmpty ? 'TICKET' : ticketBase}-$suffix',
                style: TextStyle(
                  color: tokens.primaryStrong,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              if (helperText != null) ...[
                const SizedBox(height: 4),
                Text(
                  helperText!,
                  style: TextStyle(
                    color: tokens.badgeText,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _TicketSheetRow(
                label: 'Material',
                child: _TicketSheetFieldFrame(
                  child: _SplitDropdown(
                    label: 'MATERIAL',
                    value: selectedMaterial,
                    values: materialOptions,
                    onChanged: onMaterialChanged,
                  ),
                ),
              ),
              _TicketSheetRow(
                label: 'Bruto',
                child: _TicketSheetFieldFrame(
                  child: _SplitTextField(controller: brutoC),
                ),
              ),
              _TicketSheetRow(
                label: 'Tara',
                child: _TicketSheetFieldFrame(
                  child: _SplitTextField(controller: taraC),
                ),
              ),
              _TicketSheetRow(
                label: 'Neto',
                child: _TicketSheetFieldFrame(
                  child: Text(neto.toStringAsFixed(2)),
                ),
              ),
              _TicketSheetRow(
                label: 'Humedad',
                child: _TicketSheetFieldFrame(
                  trailing: const Text('%'),
                  child: _SplitTextField(controller: humedadC),
                ),
              ),
              _TicketSheetRow(
                label: 'Basura',
                child: _TicketSheetFieldFrame(
                  child: _SplitTextField(controller: basuraC),
                ),
              ),
              _TicketSheetRow(
                label: 'Precio',
                child: _TicketSheetFieldFrame(child: Text(formatMoney(precio))),
              ),
              _TicketSheetRow(
                label: 'Sobreprecio',
                child: _TicketSheetFieldFrame(
                  child: _SplitTextField(controller: sobreprecioC),
                ),
              ),
              _TicketSheetRow(
                label: 'Importe',
                child: _TicketSheetFieldFrame(
                  emphasized: true,
                  child: Text(
                    formatMoney(importe),
                    style: TextStyle(
                      color: tokens.primaryStrong,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              _TicketSheetRow(
                label: 'Comentario',
                alignTop: true,
                child: _TicketSheetFieldFrame(
                  child: TextField(
                    controller: comentarioC,
                    maxLines: 2,
                    decoration: const InputDecoration.collapsed(hintText: ''),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _parse(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;
}

class _SplitTextField extends StatelessWidget {
  final TextEditingController controller;

  const _SplitTextField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration.collapsed(hintText: ''),
    );
  }
}

class _SplitDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _SplitDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const Text('Sin opciones');
    return _TicketCompactPickerField(
      label: label,
      value: values.contains(value) ? value : null,
      items: values,
      onChanged: onChanged,
    );
  }
}

class _TicketSheetRow extends StatelessWidget {
  final String label;
  final Widget child;
  final bool alignTop;

  const _TicketSheetRow({
    required this.label,
    required this.child,
    this.alignTop = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: alignTop
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 102,
            child: Padding(
              padding: EdgeInsets.only(top: alignTop ? 12 : 0),
              child: Text(
                label,
                style: TextStyle(
                  color: tokens.badgeText,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _TicketSheetFieldFrame extends StatelessWidget {
  final Widget child;
  final Widget? trailing;
  final bool emphasized;

  const _TicketSheetFieldFrame({
    required this.child,
    this.trailing,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: emphasized
            ? tokens.badgeBackground.withValues(alpha: 0.74)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          bottom: BorderSide(
            color: emphasized
                ? tokens.primaryStrong.withValues(alpha: 0.28)
                : tokens.primarySoft.withValues(alpha: 0.34),
            width: emphasized ? 1.6 : 1.2,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: child),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class _TicketsGridCard extends StatelessWidget {
  final String counterpartyLabel;
  final String emptyGridLabel;
  final List<_TicketGridEntry> entries;
  final int activeRowIndex;
  final Set<int> selectedRowIndexes;
  final ScrollController rowsScrollController;
  final Key rowsViewportKey;
  final int activeFilterCount;
  final String Function(num value) formatMoney;
  final Future<void> Function(int index) onOpenRow;
  final void Function(int index) onRowTap;
  final void Function(int index) onRowActionMenuOpen;
  final Future<void> Function(int index, _TicketGridMenuAction action)
  onRowMenuAction;
  final GlobalKey Function(int index) rowKeyForIndex;
  final void Function(int index) onRowDragEnter;
  final VoidCallback onRowPointerEnd;
  final void Function(PointerDownEvent event) onRowsPointerDown;
  final void Function(PointerMoveEvent event) onRowsPointerMove;
  final VoidCallback onRowsPointerEnd;
  final Future<void> Function(int index) onRowDoubleTap;
  final Future<void> Function(
    BuildContext context,
    int index,
    Offset globalPosition,
  )
  onRowSecondaryTapDown;
  final Future<void> Function() onOpenDateFilter;
  final Future<void> Function() onOpenTicketFilter;
  final Future<void> Function() onOpenProviderFilter;
  final Future<void> Function() onOpenMaterialFilter;
  final Future<void> Function() onOpenStatusFilter;
  final bool hasDateFilter;
  final bool hasTicketFilter;
  final bool hasProviderFilter;
  final bool hasMaterialFilter;
  final bool hasStatusFilter;
  final VoidCallback? onClearFilters;

  const _TicketsGridCard({
    required this.counterpartyLabel,
    required this.emptyGridLabel,
    required this.entries,
    required this.activeRowIndex,
    required this.selectedRowIndexes,
    required this.rowsScrollController,
    required this.rowsViewportKey,
    required this.activeFilterCount,
    required this.formatMoney,
    required this.onOpenRow,
    required this.onRowTap,
    required this.onRowActionMenuOpen,
    required this.onRowMenuAction,
    required this.rowKeyForIndex,
    required this.onRowDragEnter,
    required this.onRowPointerEnd,
    required this.onRowsPointerDown,
    required this.onRowsPointerMove,
    required this.onRowsPointerEnd,
    required this.onRowDoubleTap,
    required this.onRowSecondaryTapDown,
    required this.onOpenDateFilter,
    required this.onOpenTicketFilter,
    required this.onOpenProviderFilter,
    required this.onOpenMaterialFilter,
    required this.onOpenStatusFilter,
    required this.hasDateFilter,
    required this.hasTicketFilter,
    required this.hasProviderFilter,
    required this.hasMaterialFilter,
    required this.hasStatusFilter,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onClearFilters != null) ...[
            Row(
              children: [
                if (selectedRowIndexes.isNotEmpty)
                  FilledButton.icon(
                    style: contractPrimaryButtonStyle(context),
                    onPressed: () => unawaited(
                      onRowMenuAction(
                        selectedRowIndexes.first,
                        _TicketGridMenuAction.deleteSelection,
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text('Eliminar (${selectedRowIndexes.length})'),
                  ),
                if (selectedRowIndexes.isNotEmpty) const SizedBox(width: 8),
                const Spacer(),
                OutlinedButton(
                  style: contractSecondaryButtonStyle(context),
                  onPressed: onClearFilters,
                  child: const Text('Limpiar filtros'),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          _GridHeaderRow(
            counterpartyLabel: counterpartyLabel,
            hasDateFilter: hasDateFilter,
            hasTicketFilter: hasTicketFilter,
            hasProviderFilter: hasProviderFilter,
            hasMaterialFilter: hasMaterialFilter,
            hasStatusFilter: hasStatusFilter,
            onOpenDateFilter: onOpenDateFilter,
            onOpenTicketFilter: onOpenTicketFilter,
            onOpenProviderFilter: onOpenProviderFilter,
            onOpenMaterialFilter: onOpenMaterialFilter,
            onOpenStatusFilter: onOpenStatusFilter,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: onRowsPointerDown,
              onPointerMove: onRowsPointerMove,
              onPointerUp: (_) => onRowsPointerEnd(),
              onPointerCancel: (_) => onRowsPointerEnd(),
              child: _TicketsTableList(
                emptyLabel: emptyGridLabel,
                controller: rowsScrollController,
                viewportKey: rowsViewportKey,
                rows: List<Widget>.generate(entries.length, (visibleIndex) {
                  final entry = entries[visibleIndex];
                  final row = entry.row;
                  final highlighted = entry.index == activeRowIndex;
                  final neto =
                      ((row['gross'] as num).toDouble() -
                      (row['tare'] as num).toDouble());
                  final peso =
                      (neto *
                          (1 - ((row['humidity'] as num).toDouble() / 100))) -
                      (row['trash'] as num).toDouble();
                  final importe =
                      peso *
                      ((row['price'] as num).toDouble() +
                          (row['premium'] as num).toDouble());
                  return KeyedSubtree(
                    key: rowKeyForIndex(entry.index),
                    child: _GridDataRow(
                      highlighted: highlighted,
                      selected: selectedRowIndexes.contains(entry.index),
                      date: row['date'].toString(),
                      ticket: row['ticket'].toString(),
                      provider: row['provider'].toString(),
                      material: row['material'].toString(),
                      neto: neto.toStringAsFixed(2),
                      importe: formatMoney(importe),
                      status: row['status'].toString(),
                      onOpen: () => onOpenRow(entry.index),
                      onTapRow: () => onRowTap(entry.index),
                      onActionMenuOpen: () => onRowActionMenuOpen(entry.index),
                      onMenuAction: (action) =>
                          onRowMenuAction(entry.index, action),
                      onDragEnter: () => onRowDragEnter(entry.index),
                      onPointerEnd: onRowPointerEnd,
                      onDoubleTap: () => onRowDoubleTap(entry.index),
                      onSecondaryTapDown: (context, offset) =>
                          onRowSecondaryTapDown(context, entry.index, offset),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketsTableList extends StatelessWidget {
  final String emptyLabel;
  final List<Widget> rows;
  final ScrollController controller;
  final Key viewportKey;

  const _TicketsTableList({
    required this.emptyLabel,
    required this.rows,
    required this.controller,
    required this.viewportKey,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Container(
        key: viewportKey,
        alignment: Alignment.center,
        child: Text(
          emptyLabel,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    return Container(
      key: viewportKey,
      child: ListView.separated(
        controller: controller,
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) => rows[index],
      ),
    );
  }
}

class _TicketDetailCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final int rowIndex;
  final int rowCount;
  final String counterpartyLabel;
  final bool showExitOrderField;
  final String Function(num value) formatMoney;
  final TextEditingController humedadC;
  final TextEditingController basuraC;
  final TextEditingController sobreprecioC;
  final TextEditingController exitOrderNumberC;
  final TextEditingController comentarioC;
  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onDraftChanged;
  final VoidCallback? onPreviousRow;
  final VoidCallback? onNextRow;
  final Future<void> Function() onSave;

  const _TicketDetailCard({
    required this.row,
    required this.rowIndex,
    required this.rowCount,
    required this.counterpartyLabel,
    required this.showExitOrderField,
    required this.formatMoney,
    required this.humedadC,
    required this.basuraC,
    required this.sobreprecioC,
    required this.exitOrderNumberC,
    required this.comentarioC,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.onDraftChanged,
    required this.onPreviousRow,
    required this.onNextRow,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final bruto = (row['gross'] as num).toDouble();
    final tara = (row['tare'] as num).toDouble();
    final humedad =
        double.tryParse(humedadC.text.trim().replaceAll(',', '.')) ?? 0;
    final basura =
        double.tryParse(basuraC.text.trim().replaceAll(',', '.')) ?? 0;
    final sobreprecio =
        double.tryParse(sobreprecioC.text.trim().replaceAll(',', '.')) ?? 0;
    final precio = (row['price'] as num).toDouble();
    final neto = bruto - tara;
    final peso = (neto * (1 - (humedad / 100))) - basura;
    final importe = peso * (precio + sobreprecio);
    final amountTone = tokens.primaryStrong;
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.72),
              tokens.surfaceTint.withValues(alpha: 0.70),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.58),
              blurRadius: 28,
              offset: const Offset(-6, -6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _TicketDetailTopChip(
                          label: 'Fecha',
                          value: row['date'].toString(),
                        ),
                        _TicketDetailTopChip(
                          label: 'Ticket',
                          value: row['ticket'].toString(),
                        ),
                        if (showExitOrderField &&
                            exitOrderNumberC.text.trim().isNotEmpty)
                          _TicketDetailTopChip(
                            label: 'Orden salida',
                            value: exitOrderNumberC.text.trim(),
                          ),
                        _TicketStatusTopChip(
                          value: selectedStatus,
                          onChanged: onStatusChanged,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _TicketRowNavigator(
                    onPrevious: onPreviousRow,
                    onNext: onNextRow,
                    positionLabel: '${rowIndex + 1} de $rowCount',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _TicketDetailSection(
                child: Column(
                  children: [
                    _TicketDetailRow(
                      leftLabel: counterpartyLabel,
                      leftValue: row['provider'].toString(),
                      rightLabel: 'Material',
                      rightValue: row['material'].toString(),
                    ),
                    const SizedBox(height: 12),
                    _TicketMetricGrid(
                      leftChildren: [
                        _TicketMetricLine(
                          label: 'Bruto',
                          value: bruto.toStringAsFixed(2),
                          unit: 'kg',
                        ),
                        _TicketMetricLine(
                          label: 'Tara',
                          value: tara.toStringAsFixed(2),
                          unit: 'kg',
                        ),
                        _TicketMetricLine(
                          label: 'Neto',
                          value: neto.toStringAsFixed(2),
                          unit: 'kg',
                          strong: true,
                        ),
                      ],
                      rightChildren: [
                        _TicketMetricLine(
                          label: 'Precio',
                          value: formatMoney(precio),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TicketInlineInputChip(
                      label: 'Humedad',
                      controller: humedadC,
                      suffix: '%',
                      onChanged: onDraftChanged,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TicketInlineInputChip(
                      label: 'Basura',
                      controller: basuraC,
                      suffix: 'kg',
                      onChanged: onDraftChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _TicketInlineInputChip(
                label: 'Sobreprecio',
                controller: sobreprecioC,
                suffix: '',
                onChanged: onDraftChanged,
              ),
              if (showExitOrderField) ...[
                const SizedBox(height: 14),
                Text(
                  'Orden de salida',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: tokens.primaryStrong,
                  ),
                ),
                const SizedBox(height: 8),
                _TicketSingleLineBox(
                  controller: exitOrderNumberC,
                  hintText: 'Capturar número de orden de salida',
                  onChanged: onDraftChanged,
                ),
              ],
              const SizedBox(height: 14),
              _TicketDetailSection(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                stronger: true,
                child: Row(
                  children: [
                    Expanded(
                      child: _TicketSummaryBlock(
                        label: 'Peso',
                        value: peso.toStringAsFixed(0),
                        unit: 'kg',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 74,
                      color: tokens.primarySoft.withValues(alpha: 0.24),
                    ),
                    Expanded(
                      child: _TicketSummaryBlock(
                        label: 'IMPORTE',
                        value: formatMoney(importe),
                        tone: amountTone,
                        emphasized: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Comentarios:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 8),
              _TicketCommentBox(
                controller: comentarioC,
                onChanged: onDraftChanged,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: contractPrimaryButtonStyle(context),
                  onPressed: onSave,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Guardar cambios'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketDetailTopChip extends StatelessWidget {
  final String label;
  final String value;

  const _TicketDetailTopChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 146),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      decoration: BoxDecoration(
        color: tokens.badgeBackground.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.52),
            blurRadius: 18,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketStatusTopChip extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _TicketStatusTopChip({required this.value, required this.onChanged});

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showDialog<String?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (dialogContext) {
        return _showTicketSingleSelectDialog(
          dialogContext,
          title: 'Filtro: ESTADO',
          options: const <String>['PENDIENTE', 'PAGADO'],
          initialValue: value,
        );
      },
    );
    if (selected == null || selected == value) return;
    onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openPicker(context),
      child: Container(
        constraints: const BoxConstraints(minWidth: 160),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [menudeoAreaTokens.accent, menudeoAreaTokens.primary],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.24),
              blurRadius: 14,
              offset: const Offset(-2, -2),
            ),
            BoxShadow(
              color: menudeoAreaTokens.primaryStrong.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estado',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketRowNavigator extends StatelessWidget {
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final String positionLabel;

  const _TicketRowNavigator({
    this.onPrevious,
    this.onNext,
    required this.positionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.44),
            blurRadius: 14,
            offset: const Offset(-2, -2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Text(
              positionLabel,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: kMenudeoMutedText,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TicketNavButton(
                icon: Icons.arrow_back_rounded,
                onPressed: onPrevious,
              ),
              const SizedBox(width: 6),
              _TicketNavButton(
                icon: Icons.arrow_forward_rounded,
                onPressed: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TicketNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _TicketNavButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 44,
      child: OutlinedButton(
        style: contractSecondaryButtonStyle(context),
        onPressed: onPressed,
        child: Icon(icon),
      ),
    );
  }
}

class _TicketDetailSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool stronger;

  const _TicketDetailSection({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 14),
    this.stronger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: stronger ? 0.72 : 0.62),
            menudeoAreaTokens.primarySoft.withValues(
              alpha: stronger ? 0.58 : 0.42,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.44),
            blurRadius: 16,
            offset: const Offset(-2, -2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: stronger ? 0.10 : 0.06),
            blurRadius: stronger ? 24 : 18,
            offset: Offset(0, stronger ? 12 : 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TicketDetailRow extends StatelessWidget {
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  const _TicketDetailRow({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    Widget cell(String label, String value) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: tokens.primaryStrong,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            cell(leftLabel, leftValue),
            const SizedBox(width: 18),
            cell(rightLabel, rightValue),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 1,
          color: tokens.primarySoft.withValues(alpha: 0.24),
        ),
      ],
    );
  }
}

class _TicketMetricGrid extends StatelessWidget {
  final List<Widget> leftChildren;
  final List<Widget> rightChildren;

  const _TicketMetricGrid({
    required this.leftChildren,
    required this.rightChildren,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: leftChildren)),
        Container(
          width: 1,
          height: 104,
          color: tokens.primarySoft.withValues(alpha: 0.24),
        ),
        const SizedBox(width: 18),
        Expanded(child: Column(children: rightChildren)),
      ],
    );
  }
}

class _TicketMetricLine extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final bool strong;

  const _TicketMetricLine({
    required this.label,
    required this.value,
    this.unit,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: strong ? 17 : 15,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                color: tokens.primaryStrong,
              ),
            ),
          ),
          Flexible(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: strong ? 18 : 16,
                  fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
                  color: tokens.primaryStrong,
                ),
                children: [
                  TextSpan(text: value),
                  if (unit != null && unit!.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        fontSize: strong ? 15 : 14,
                        fontWeight: FontWeight.w700,
                        color: tokens.badgeText,
                      ),
                    ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketInlineInputChip extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String suffix;
  final VoidCallback onChanged;

  const _TicketInlineInputChip({
    required this.label,
    required this.controller,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.84),
            const Color(0xFFF2E5DD).withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.42),
            blurRadius: 12,
            offset: const Offset(-2, -2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: tokens.primarySoft.withValues(alpha: 0.28),
              ),
            ),
            child: Icon(
              Icons.edit_outlined,
              size: 12,
              color: tokens.primaryStrong,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: tokens.primaryStrong,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                suffixText: suffix.isEmpty ? null : suffix,
                suffixStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tokens.badgeText,
                ),
              ),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketSummaryBlock extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color? tone;
  final bool emphasized;

  const _TicketSummaryBlock({
    required this.label,
    required this.value,
    this.unit,
    this.tone,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final textTone = tone ?? tokens.primaryStrong;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: textTone.withValues(alpha: 0.82),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: emphasized ? 26 : 24,
                fontWeight: FontWeight.w900,
                color: textTone,
              ),
              children: [
                TextSpan(text: value),
                if (unit != null && unit!.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textTone.withValues(alpha: 0.9),
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

class _TicketCommentBox extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _TicketCommentBox({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.82),
            tokens.surfaceTint.withValues(alpha: 0.76),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.primarySoft.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.42),
            blurRadius: 12,
            offset: const Offset(-2, -2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: 2,
        onChanged: (_) => onChanged(),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Agregar comentario',
        ),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: tokens.primaryStrong,
        ),
      ),
    );
  }
}

class _TicketSingleLineBox extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String hintText;

  const _TicketSingleLineBox({
    required this.controller,
    required this.onChanged,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.82),
            tokens.surfaceTint.withValues(alpha: 0.76),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.primarySoft.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.42),
            blurRadius: 12,
            offset: const Offset(-2, -2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: 1,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
        ),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: tokens.primaryStrong,
        ),
      ),
    );
  }
}

class _TicketCompactPickerField extends StatefulWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _TicketCompactPickerField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_TicketCompactPickerField> createState() =>
      _TicketCompactPickerFieldState();
}

class _TicketCompactPickerFieldState extends State<_TicketCompactPickerField> {
  Future<void> _openPicker() async {
    final selected = await showDialog<String?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (dialogContext) {
        return _showTicketSingleSelectDialog(
          dialogContext,
          title: 'Seleccionar ${widget.label.toLowerCase()}',
          options: widget.items,
          initialValue: widget.value,
        );
      },
    );
    if (!mounted || selected == null || selected == widget.value) return;
    widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openPicker,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.82),
                tokens.surfaceTint.withValues(alpha: 0.78),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tokens.primarySoft.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.32),
                blurRadius: 10,
                offset: const Offset(-1, -1),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.value == null || widget.value!.isEmpty
                      ? 'Seleccionar'
                      : widget.value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: (widget.value == null || widget.value!.isEmpty)
                        ? tokens.badgeText.withValues(alpha: 0.72)
                        : tokens.primaryStrong,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: tokens.badgeBackground.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: tokens.primarySoft.withValues(alpha: 0.26),
                  ),
                ),
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 20,
                  color: tokens.primaryStrong,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketPickerOption extends StatelessWidget {
  final String label;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;
  final ValueChanged<bool>? onHover;
  final Widget? trailing;

  const _TicketPickerOption({
    required this.label,
    required this.selected,
    this.highlighted = false,
    required this.onTap,
    this.onHover,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return MouseRegion(
      onEnter: (_) => onHover?.call(true),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? tokens.primarySoft.withValues(alpha: 0.58)
                : highlighted
                ? tokens.badgeBackground.withValues(alpha: 0.78)
                : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? tokens.primaryStrong.withValues(alpha: 0.36)
                  : highlighted
                  ? tokens.primaryStrong.withValues(alpha: 0.22)
                  : tokens.primarySoft.withValues(alpha: 0.72),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? tokens.primaryStrong
                        : const Color(0xFF1C2326),
                  ),
                ),
              ),
              ...?trailing == null ? null : <Widget>[trailing!],
              if (trailing == null && selected)
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
  }
}

class _TicketsValueFilterResult {
  final Set<String> selectedValues;

  const _TicketsValueFilterResult({required this.selectedValues});
}

class _TicketsDateFilterResult {
  final DateTimeRange? range;
  final bool clear;

  const _TicketsDateFilterResult({this.range, this.clear = false});
}

Widget _showTicketSingleSelectDialog(
  BuildContext dialogContext, {
  required String title,
  required List<String> options,
  required String? initialValue,
}) {
  final searchC = TextEditingController();
  final searchFocus = FocusNode();
  final itemFocusNodes = <FocusNode>[];
  String q = '';
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
          .where((o) => o.toLowerCase().contains(q.toLowerCase()))
          .toList(growable: false);
      syncNodes(filtered.length);
      return AreaThemeScope(
        tokens: menudeoAreaTokens,
        child: Builder(
          builder: (context) {
            final tokens = AreaThemeScope.of(context);
            return Focus(
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
                  Navigator.of(dialogContext).pop(filtered[index]);
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
                            decoration: _ticketsFieldDecoration(
                              context,
                              hintText: 'Buscar',
                              prefixIcon: const Icon(Icons.search_rounded),
                            ),
                            onChanged: (value) =>
                                setLocalState(() => q = value),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Text(
                                    'Sin resultados',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: tokens.badgeText,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, i) {
                                    final option = filtered[i];
                                    final selected = option == initialValue;
                                    final highlighted = focusedIndex == i;
                                    return Focus(
                                      focusNode: itemFocusNodes[i],
                                      onFocusChange: (hasFocus) {
                                        if (!hasFocus && focusedIndex == i) {
                                          setLocalState(
                                            () => focusedIndex = null,
                                          );
                                        } else if (hasFocus) {
                                          setLocalState(() => focusedIndex = i);
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
                                          ).pop(option);
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.ignored;
                                      },
                                      child: _TicketPickerOption(
                                        label: option,
                                        selected: selected,
                                        highlighted: highlighted,
                                        onTap: () => Navigator.of(
                                          dialogContext,
                                        ).pop(option),
                                        onHover: (value) {
                                          if (value) {
                                            setLocalState(
                                              () => focusedIndex = i,
                                            );
                                          }
                                        },
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
            );
          },
        ),
      );
    },
  );
}

// ignore: unused_element
Widget _showTicketMultiSelectDialog(
  BuildContext dialogContext, {
  required String title,
  required List<String> options,
  required Set<String> initialValues,
}) {
  final searchC = TextEditingController();
  final searchFocus = FocusNode();
  final itemFocusNodes = <FocusNode>[];
  final selected = <String>{...initialValues};
  String q = '';
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
          .where((o) => o.toLowerCase().contains(q.toLowerCase()))
          .toList(growable: false);
      syncNodes(filtered.length);
      return AreaThemeScope(
        tokens: menudeoAreaTokens,
        child: Builder(
          builder: (context) {
            final tokens = AreaThemeScope.of(context);
            return Focus(
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.of(dialogContext).pop();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                  Navigator.of(
                    dialogContext,
                  ).pop(_TicketsValueFilterResult(selectedValues: selected));
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
                            decoration: _ticketsFieldDecoration(
                              context,
                              hintText: 'Buscar',
                              prefixIcon: const Icon(Icons.search_rounded),
                            ),
                            onChanged: (value) =>
                                setLocalState(() => q = value),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Text(
                                    'Sin resultados',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: tokens.badgeText,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, i) {
                                    final option = filtered[i];
                                    final checked = selected.contains(option);
                                    final highlighted = focusedIndex == i;
                                    return Focus(
                                      focusNode: itemFocusNodes[i],
                                      onFocusChange: (hasFocus) {
                                        if (!hasFocus && focusedIndex == i) {
                                          setLocalState(
                                            () => focusedIndex = null,
                                          );
                                        } else if (hasFocus) {
                                          setLocalState(() => focusedIndex = i);
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
                                          setLocalState(() {
                                            if (checked) {
                                              selected.remove(option);
                                            } else {
                                              selected.add(option);
                                            }
                                          });
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.ignored;
                                      },
                                      child: _TicketPickerOption(
                                        label: option,
                                        selected: checked,
                                        highlighted: highlighted,
                                        onTap: () {
                                          setLocalState(() {
                                            if (checked) {
                                              selected.remove(option);
                                            } else {
                                              selected.add(option);
                                            }
                                          });
                                        },
                                        onHover: (value) {
                                          if (value) {
                                            setLocalState(
                                              () => focusedIndex = i,
                                            );
                                          }
                                        },
                                        trailing: Checkbox(
                                          value: checked,
                                          onChanged: (value) {
                                            setLocalState(() {
                                              if (value == true) {
                                                selected.add(option);
                                              } else {
                                                selected.remove(option);
                                              }
                                            });
                                          },
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                          activeColor: tokens.primaryStrong,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              style: contractSecondaryButtonStyle(
                                dialogContext,
                              ),
                              onPressed: () => Navigator.pop(
                                dialogContext,
                                const _TicketsValueFilterResult(
                                  selectedValues: <String>{},
                                ),
                              ),
                              child: const Text('Limpiar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: contractPrimaryButtonStyle(dialogContext),
                              onPressed: () => Navigator.pop(
                                dialogContext,
                                _TicketsValueFilterResult(
                                  selectedValues: selected,
                                ),
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
            );
          },
        ),
      );
    },
  );
}

Future<DateTime?> _showTicketsSingleDateDialog(
  BuildContext context, {
  required DateTimeRange bounds,
  DateTime? initialDate,
}) {
  return showDialog<DateTime?>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      DateTime displayMonth = DateTime(
        (initialDate ?? bounds.end).year,
        (initialDate ?? bounds.end).month,
      );
      DateTime? selected = initialDate;

      bool isSameDay(DateTime a, DateTime b) =>
          a.year == b.year && a.month == b.month && a.day == b.day;
      DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
      bool withinBounds(DateTime day) {
        final d = dateOnly(day);
        return !d.isBefore(dateOnly(bounds.start)) &&
            !d.isAfter(dateOnly(bounds.end));
      }

      return AreaThemeScope(
        tokens: menudeoAreaTokens,
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
                      'Filtro: FECHA',
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
                          onPressed: () {
                            setLocalState(() {
                              displayMonth = DateTime(
                                displayMonth.year,
                                displayMonth.month - 1,
                              );
                            });
                          },
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${_ticketsMonthNameLabel(monthFirst.month)} ${monthFirst.year}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
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
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (final label in ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  label,
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
                        final enabled = withinBounds(day);
                        final isSelected =
                            selected != null && isSameDay(day, selected!);
                        return GestureDetector(
                          onTap: !enabled
                              ? null
                              : () => setLocalState(() {
                                  selected = dateOnly(day);
                                }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? tokens.primaryStrong.withValues(alpha: 0.18)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
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
                                  fontWeight: isSelected
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  color: !enabled
                                      ? tokens.badgeText.withValues(alpha: 0.28)
                                      : inMonth
                                      ? tokens.primaryStrong
                                      : tokens.badgeText.withValues(
                                          alpha: 0.55,
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
                      selected == null
                          ? 'Selecciona una fecha'
                          : _ticketsFormatDate(selected!),
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
                          style: contractSecondaryButtonStyle(dialogContext),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: contractPrimaryButtonStyle(dialogContext),
                          onPressed: selected == null
                              ? null
                              : () => Navigator.of(dialogContext).pop(selected),
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

String _ticketsMonthNameLabel(int month) {
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

String _ticketsFormatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}

Future<_TicketsValueFilterResult?> _showTicketsValueFilterDialog(
  BuildContext context, {
  required String label,
  required List<String> options,
  required Set<String> initialSelected,
}) async {
  final selected = await showMenudeoValueFilterDialog(
    context,
    title: 'Filtrar ${label.toLowerCase()}',
    options: options,
    initialValues: initialSelected,
  );
  if (selected == null) return null;
  return _TicketsValueFilterResult(selectedValues: selected);
}

Future<_TicketsDateFilterResult?> _showTicketsDateRangeFilterDialog(
  BuildContext context, {
  required String label,
  required DateTimeRange bounds,
  DateTimeRange? initialRange,
}) {
  return showMenudeoDateRangeFilterDialog(
    context,
    label: label,
    bounds: bounds,
    initialRange: initialRange,
  ).then((result) {
    if (result == null) return null;
    return _TicketsDateFilterResult(range: result.range, clear: result.clear);
  });
}

InputDecoration _ticketsFieldDecoration(
  BuildContext context, {
  required String hintText,
  Widget? prefixIcon,
}) {
  final tokens = AreaThemeScope.of(context);
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    isDense: true,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.82),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    hintStyle: TextStyle(
      color: tokens.badgeText.withValues(alpha: 0.7),
      fontWeight: FontWeight.w700,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: tokens.primarySoft.withValues(alpha: 0.9)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: tokens.primaryStrong.withValues(alpha: 0.42),
        width: 1.4,
      ),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: tokens.primarySoft.withValues(alpha: 0.9)),
    ),
  );
}

class _SplitPreviewChip extends StatelessWidget {
  final String label;

  const _SplitPreviewChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.primarySoft.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tokens.primaryStrong,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GridHeaderRow extends StatelessWidget {
  final String counterpartyLabel;
  final bool hasDateFilter;
  final bool hasTicketFilter;
  final bool hasProviderFilter;
  final bool hasMaterialFilter;
  final bool hasStatusFilter;
  final Future<void> Function() onOpenDateFilter;
  final Future<void> Function() onOpenTicketFilter;
  final Future<void> Function() onOpenProviderFilter;
  final Future<void> Function() onOpenMaterialFilter;
  final Future<void> Function() onOpenStatusFilter;

  const _GridHeaderRow({
    required this.counterpartyLabel,
    required this.hasDateFilter,
    required this.hasTicketFilter,
    required this.hasProviderFilter,
    required this.hasMaterialFilter,
    required this.hasStatusFilter,
    required this.onOpenDateFilter,
    required this.onOpenTicketFilter,
    required this.onOpenProviderFilter,
    required this.onOpenMaterialFilter,
    required this.onOpenStatusFilter,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    const style = TextStyle(fontSize: 12, fontWeight: FontWeight.w900);
    const totalWidth =
        _kTicketsDateW +
        _kTicketsTicketW +
        _kTicketsProviderW +
        _kTicketsMaterialW +
        _kTicketsNetoW +
        _kTicketsImporteW +
        _kTicketsActionsW;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.70),
            tokens.surfaceTint.withValues(alpha: 0.74),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.44),
            blurRadius: 16,
            offset: const Offset(-2, -2),
          ),
          BoxShadow(
            color: tokens.primaryStrong.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              child: ContractGridScaledRow(
                child: SizedBox(
                  width: totalWidth,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: _kTicketsDateW,
                        child: MenudeoGridHeaderFilterCell(
                          label: 'Fecha',
                          style: style,
                          active: hasDateFilter,
                          onTap: onOpenDateFilter,
                        ),
                      ),
                      SizedBox(
                        width: _kTicketsTicketW,
                        child: MenudeoGridHeaderFilterCell(
                          label: 'Ticket',
                          style: style,
                          active: hasTicketFilter,
                          onTap: onOpenTicketFilter,
                        ),
                      ),
                      SizedBox(
                        width: _kTicketsProviderW,
                        child: MenudeoGridHeaderFilterCell(
                          label: counterpartyLabel,
                          style: style,
                          active: hasProviderFilter,
                          onTap: onOpenProviderFilter,
                        ),
                      ),
                      SizedBox(
                        width: _kTicketsMaterialW,
                        child: MenudeoGridHeaderFilterCell(
                          label: 'Material',
                          style: style,
                          active: hasMaterialFilter,
                          onTap: onOpenMaterialFilter,
                        ),
                      ),
                      const SizedBox(
                        width: _kTicketsNetoW,
                        child: Text('Neto', style: style),
                      ),
                      const SizedBox(
                        width: _kTicketsImporteW,
                        child: Text('Importe', style: style),
                      ),
                      SizedBox(
                        width: _kTicketsActionsW,
                        child: MenudeoGridHeaderFilterCell(
                          label: 'Estado',
                          style: style,
                          active: hasStatusFilter,
                          onTap: onOpenStatusFilter,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GridDataRow extends StatefulWidget {
  final bool highlighted;
  final bool selected;
  final String date;
  final String ticket;
  final String provider;
  final String material;
  final String neto;
  final String importe;
  final String status;
  final VoidCallback onOpen;
  final VoidCallback onTapRow;
  final VoidCallback onActionMenuOpen;
  final Future<void> Function(_TicketGridMenuAction action) onMenuAction;
  final VoidCallback? onDragEnter;
  final VoidCallback? onPointerEnd;
  final VoidCallback? onDoubleTap;
  final Future<void> Function(BuildContext context, Offset globalPosition)?
  onSecondaryTapDown;

  const _GridDataRow({
    required this.highlighted,
    required this.selected,
    required this.date,
    required this.ticket,
    required this.provider,
    required this.material,
    required this.neto,
    required this.importe,
    required this.status,
    required this.onOpen,
    required this.onTapRow,
    required this.onActionMenuOpen,
    required this.onMenuAction,
    this.onDragEnter,
    this.onPointerEnd,
    this.onDoubleTap,
    this.onSecondaryTapDown,
  });

  @override
  State<_GridDataRow> createState() => _GridDataRowState();
}

class _GridDataRowState extends State<_GridDataRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final selectedContext = widget.highlighted || widget.selected;
    final rowContentWidth =
        _kTicketsDateW +
        _kTicketsTicketW +
        _kTicketsProviderW +
        _kTicketsMaterialW +
        _kTicketsNetoW +
        _kTicketsImporteW +
        _kTicketsActionsW;
    final backgroundGradient = selectedContext
        ? <Color>[
            tokens.badgeBackground.withValues(alpha: 0.96),
            tokens.primarySoft.withValues(alpha: 0.92),
          ]
        : _hovering
        ? <Color>[
            Colors.white.withValues(alpha: 0.90),
            tokens.surfaceTint.withValues(alpha: 0.84),
          ]
        : <Color>[
            Colors.white.withValues(alpha: 0.74),
            tokens.surfaceTint.withValues(alpha: 0.72),
          ];

    Widget buildDivider() {
      return Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: tokens.border.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    Widget buildCell({
      required double width,
      required Widget child,
      bool includeDivider = true,
    }) {
      return SizedBox(
        width: width,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(child: child),
            if (includeDivider) buildDivider(),
          ],
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovering = true);
        widget.onDragEnter?.call();
      },
      onExit: (_) => setState(() => _hovering = false),
      child: Listener(
        onPointerUp: (_) => widget.onPointerEnd?.call(),
        onPointerCancel: (_) => widget.onPointerEnd?.call(),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          scale: _hovering ? 1.003 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: backgroundGradient,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selectedContext
                    ? tokens.primaryStrong.withValues(alpha: 0.48)
                    : _hovering
                    ? tokens.primarySoft.withValues(alpha: 0.30)
                    : tokens.border.withValues(alpha: 0.64),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.42),
                  blurRadius: 18,
                  offset: const Offset(-2, -2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: selectedContext
                        ? 0.12
                        : _hovering
                        ? 0.10
                        : 0.06,
                  ),
                  blurRadius: _hovering ? 20 : 14,
                  offset: Offset(0, _hovering ? 12 : 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    width: constraints.maxWidth,
                    child: ContractGridScaledRow(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onSecondaryTapDown: widget.onSecondaryTapDown == null
                            ? null
                            : (details) => unawaited(
                                widget.onSecondaryTapDown!(
                                  context,
                                  details.globalPosition,
                                ),
                              ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: widget.onTapRow,
                            onDoubleTap: widget.onDoubleTap,
                            child: SizedBox(
                              width: rowContentWidth,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  buildCell(
                                    width: _kTicketsDateW,
                                    child: Text(
                                      widget.date,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2D2A28),
                                      ),
                                    ),
                                  ),
                                  buildCell(
                                    width: _kTicketsTicketW,
                                    child: TextButton(
                                      onPressed: widget.onOpen,
                                      style: TextButton.styleFrom(
                                        foregroundColor: tokens.primaryStrong,
                                        padding: EdgeInsets.zero,
                                        alignment: Alignment.centerLeft,
                                        minimumSize: Size.zero,
                                      ),
                                      child: Text(
                                        widget.ticket,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: tokens.primaryStrong,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                  buildCell(
                                    width: _kTicketsProviderW,
                                    child: Text(
                                      widget.provider,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2D2A28),
                                      ),
                                    ),
                                  ),
                                  buildCell(
                                    width: _kTicketsMaterialW,
                                    child: Text(
                                      widget.material,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2D2A28),
                                      ),
                                    ),
                                  ),
                                  buildCell(
                                    width: _kTicketsNetoW,
                                    child: Text(
                                      widget.neto,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2D2A28),
                                      ),
                                    ),
                                  ),
                                  buildCell(
                                    width: _kTicketsImporteW,
                                    child: Text(
                                      widget.importe,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: tokens.primaryStrong,
                                      ),
                                    ),
                                  ),
                                  AnchoredActionSlot(
                                    width: _kTicketsActionsW,
                                    trailingWidth: 36,
                                    gap: 8,
                                    leading: Align(
                                      alignment: Alignment.centerLeft,
                                      child: _TicketStatusChip(
                                        status: widget.status,
                                        activeContext:
                                            widget.highlighted ||
                                            widget.selected ||
                                            _hovering,
                                      ),
                                    ),
                                    trailing:
                                        PopupMenuButton<_TicketGridMenuAction>(
                                          tooltip: 'Acciones',
                                          padding: EdgeInsets.zero,
                                          color: tokens.surfaceTint.withValues(
                                            alpha: 0.98,
                                          ),
                                          elevation: 8,
                                          shadowColor: Colors.black.withValues(
                                            alpha: 0.12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            side: BorderSide(
                                              color: tokens.primarySoft
                                                  .withValues(alpha: 0.58),
                                            ),
                                          ),
                                          onOpened: widget.onActionMenuOpen,
                                          onSelected: (action) => unawaited(
                                            widget.onMenuAction(action),
                                          ),
                                          itemBuilder: (_) =>
                                              _buildTicketMenuItems(
                                                selectedCount: 1,
                                              ),
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.white.withValues(
                                                    alpha: 0.82,
                                                  ),
                                                  tokens.surfaceTint.withValues(
                                                    alpha: 0.78,
                                                  ),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.78,
                                                ),
                                              ),
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.more_horiz_rounded,
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
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketStatusChip extends StatelessWidget {
  final String status;
  final bool activeContext;

  const _TicketStatusChip({required this.status, this.activeContext = false});

  @override
  Widget build(BuildContext context) {
    final paid = status == 'PAGADO';
    final tone = paid ? const Color(0xFF3E7B4A) : menudeoAreaTokens.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: activeContext ? 0.74 : 0.62),
            tone.withValues(alpha: activeContext ? 0.16 : 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: tone.withValues(alpha: activeContext ? 0.28 : 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.34),
            blurRadius: 10,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: tone,
        ),
      ),
    );
  }
}

class _TicketGridEntry {
  final int index;
  final Map<String, dynamic> row;

  const _TicketGridEntry({required this.index, required this.row});
}

class _TicketsHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _TicketsHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_TicketsHeaderButton> createState() => _TicketsHeaderButtonState();
}

class _TicketsHeaderButtonState extends State<_TicketsHeaderButton> {
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                  Icon(widget.icon, color: tokens.primaryStrong),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: tokens.primaryStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
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

class _TicketsSidePanel extends StatelessWidget {
  final bool isSales;
  final Future<void> Function() onBack;
  final ValueChanged<String> onNavigate;

  const _TicketsSidePanel({
    required this.isSales,
    required this.onBack,
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
                'Menudeo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              const _SidePanelSectionHeader(label: 'MENÚ'),
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
                    _SidePanelItem(
                      icon: Icons.receipt_long_rounded,
                      title: 'Compras',
                      subtitle: 'Tickets virtuales de compra',
                      highlighted: !isSales,
                      onTapSync: () => onNavigate('Tickets de menudeo'),
                    ),
                    const SizedBox(height: 8),
                    _SidePanelItem(
                      icon: Icons.point_of_sale_rounded,
                      title: 'Ventas',
                      subtitle: 'Tickets virtuales de venta',
                      highlighted: isSales,
                      onTapSync: () => onNavigate('Ventas menudeo'),
                    ),
                    const SizedBox(height: 8),
                    _SidePanelItem(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Depósitos y gastos',
                      subtitle: 'Vouchers de caja y egresos',
                      onTapSync: () => onNavigate('Depósitos y gastos'),
                    ),
                    const SizedBox(height: 8),
                    _SidePanelItem(
                      icon: Icons.auto_graph_rounded,
                      title: 'Ajuste de precios',
                      subtitle: 'Cambios e historial',
                      onTapSync: () => onNavigate('Ajuste de precios'),
                    ),
                    const SizedBox(height: 8),
                    _SidePanelItem(
                      icon: Icons.price_check_rounded,
                      title: 'Catálogo',
                      subtitle: 'Materiales, grupos y precios',
                      onTapSync: () => onNavigate('Catálogo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _SidePanelSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              _SidePanelItem(
                icon: Icons.space_dashboard_rounded,
                title: 'Dashboard Menudeo',
                subtitle: 'Vista general del área',
                accented: true,
                onTap: onBack,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidePanelSectionHeader extends StatelessWidget {
  final String label;

  const _SidePanelSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
            color: tokens.badgeText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: tokens.primarySoft.withValues(alpha: 0.32),
          ),
        ),
      ],
    );
  }
}

class _SidePanelItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final bool highlighted;
  final bool accented;

  const _SidePanelItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.onTapSync,
    this.highlighted = false,
    this.accented = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final enabled = onTap != null || onTapSync != null;
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: !enabled
            ? null
            : () async {
                if (onTap != null) {
                  await onTap!();
                } else {
                  onTapSync?.call();
                }
              },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              gradient: accented
                  ? kMenudeoPanelAccentGradient
                  : highlighted
                  ? kMenudeoPanelHighlightGradient
                  : kMenudeoPanelGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accented
                    ? Colors.white.withValues(alpha: 0.72)
                    : highlighted
                    ? tokens.primaryStrong.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.58),
              ),
              boxShadow: accented
                  ? [
                      BoxShadow(
                        color: kMenudeoPanelShadow.withValues(alpha: 0.24),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : highlighted
                  ? [
                      BoxShadow(
                        color: kMenudeoPanelShadow.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: kMenudeoPanelShadow.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white),
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
                      if (hasSubtitle) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: tokens.badgeText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (highlighted && !accented) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle_rounded,
                    color: tokens.primarySoft,
                    size: 22,
                  ),
                ] else ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenudeoTicketsBackground extends StatelessWidget {
  const _MenudeoTicketsBackground();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    Widget blurCircle(double size, Gradient gradient) {
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              blurRadius: size * 0.12,
              spreadRadius: size * 0.02,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ],
        ),
        child: SizedBox(width: size, height: size),
      );
    }

    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.surfaceTint,
                tokens.primarySoft.withValues(alpha: 0.9),
                tokens.accent.withValues(alpha: 0.38),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: -260,
          top: -110,
          child: blurCircle(
            760,
            LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.92),
                tokens.primarySoft.withValues(alpha: 0.94),
              ],
            ),
          ),
        ),
        Positioned(
          right: -210,
          top: -70,
          child: blurCircle(
            620,
            LinearGradient(
              colors: [
                tokens.accent.withValues(alpha: 0.82),
                tokens.glow.withValues(alpha: 0.44),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          bottom: -250,
          child: blurCircle(
            620,
            LinearGradient(
              colors: [
                tokens.primary.withValues(alpha: 0.32),
                tokens.primarySoft.withValues(alpha: 0.92),
              ],
            ),
          ),
        ),
        Positioned(
          right: -110,
          bottom: -120,
          child: Container(
            width: 320,
            height: 500,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(220),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tokens.accent.withValues(alpha: 0.95),
                  tokens.primaryStrong.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
