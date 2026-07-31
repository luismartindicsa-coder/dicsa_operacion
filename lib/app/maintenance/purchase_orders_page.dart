import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/dashboard_page.dart';
import '../dashboard/general_dashboard_page.dart';
import '../services/inventory_page.dart';
import '../services/operation_directory_page.dart';
import '../services/services_page.dart';
import '../services/services_shell.dart';
import '../services/warehouse_page.dart';
import '../services/weighings_page.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/archetypes/auxiliary_surfaces/searchable_picker.dart'
    as shared_picker;
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/confirm_dialog_key_handler.dart';
import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/utils/date_picker_defaults.dart';
import '../shared/utils/number_formatters.dart';
import 'maintenance_ot_purchase_link_service.dart';
import 'maintenance_page.dart';
import 'maintenance_statuses.dart';

const List<String> _kPurchaseOrderFixedTargets = <String>[
  'ALMACEN',
  'CARTON',
  'CHATARRA',
  'TALLER',
  'OFICINA',
  'PATIO',
];

const List<String> _kPurchaseOrderProviderTypes = <String>[
  'Empresa',
  'Tienda',
  'Mecanico',
  'Proveedor',
  'Otro',
];

const Map<String, String> _kPurchaseOrderStatusLabel = <String, String>{
  'draft': 'Borrador',
  'pending_direction': 'Pendiente dirección',
  'authorized': 'Autorizada',
  'purchased': 'Comprada',
  'rejected': 'Rechazada',
};

const Map<String, String> _kPurchaseOrderLineTypeLabel = <String, String>{
  'material': 'Material',
  'mano_obra': 'Mano de obra',
  'refaccion': 'Refacción',
};

const double _kPoFolioColW = 150;
const double _kPoDateColW = 96;
const double _kPoTargetColW = 142;
const double _kPoOtColW = 126;
const double _kPoVendorColW = 250;
const double _kPoStatusColW = 156;
const double _kPoCashColW = 126;
const double _kPoPurchaseColW = 126;
const double _kPoEstimatedTotalColW = 116;
const double _kPoActualTotalColW = 116;
const double _kPoActionsColW = 172;

class PurchaseOrdersPage extends StatefulWidget {
  final String? initialOrderId;

  const PurchaseOrdersPage({super.key, this.initialOrderId});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  final SupabaseClient _supa = Supabase.instance.client;
  late final MaintenanceOtPurchaseLinkService _otPurchaseLinkService =
      MaintenanceOtPurchaseLinkService(_supa);
  final FocusNode _rowsFocusNode = FocusNode(
    debugLabel: 'purchase-orders-rows',
  );
  final ScrollController _rowsScrollController = ScrollController();
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  final GlobalKey _rowsViewportKey = GlobalKey(
    debugLabel: 'purchase-orders-viewport',
  );

  bool _loading = true;
  bool _saving = false;
  bool _runningAction = false;
  bool _purchaseOrdersSchemaReady = true;
  String? _purchaseOrdersSchemaMessage;
  List<Map<String, dynamic>> _orders = <Map<String, dynamic>>[];
  final Map<String, List<Map<String, dynamic>>> _linesByOrderId =
      <String, List<Map<String, dynamic>>>{};
  List<String> _targetOptions = <String>[];
  List<Map<String, dynamic>> _directoryContacts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _maintenanceOrders = <Map<String, dynamic>>[];
  final Map<String, Map<String, dynamic>> _maintenanceOrdersById =
      <String, Map<String, dynamic>>{};
  final Map<String, Set<String>> _columnValueFilters = <String, Set<String>>{};
  String? _selectedOrderId;
  String? _selectionAnchorOrderId;
  final Set<String> _selectedOrderIds = <String>{};
  AuthResolvedProfile? _profile;
  bool _consumedInitialOrderSelection = false;
  Offset? _marqueeStartLocal;
  Offset? _marqueePointerLocal;
  Offset? _marqueeStartContent;
  Offset? _marqueeCurrentContent;
  bool _marqueeActive = false;
  bool _marqueeAdditive = false;
  Set<String> _marqueeBaseSelection = <String>{};
  Timer? _marqueeAutoScrollTimer;
  double _marqueeAutoScrollVelocity = 0;

  bool get _isDirection => AuthAccess.isDirectionRole(_profile);

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _marqueeAutoScrollTimer?.cancel();
    _rowsFocusNode.dispose();
    _rowsScrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      _profile = await AuthAccess.resolveCurrentProfile();
      await Future.wait<void>([
        _loadTargetOptions(),
        _loadDirectoryContacts(),
        _loadMaintenanceOrders(),
        _loadOrders(),
      ]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTargetOptions() async {
    final rows = await _supa.from('vehicles').select('code').order('code');
    final unitCodes = _normalizePurchaseOrderNames(
      (rows as List)
          .map((row) => (row as Map<String, dynamic>)['code']?.toString() ?? '')
          .map((code) => code.trim().toUpperCase()),
    );
    final directoryAreas = await _loadDirectoryAreaNames();
    final merged = <String>{
      ...unitCodes,
      ..._kPurchaseOrderFixedTargets,
      ...directoryAreas.map((value) => value.trim().toUpperCase()),
    };
    _targetOptions = merged.toList()..sort();
  }

  Future<List<String>> _loadDirectoryAreaNames() async {
    try {
      final rows = await _supa
          .from('operation_directory_areas')
          .select('name')
          .eq('active', true)
          .order('name');
      return _normalizePurchaseOrderNames(
        (rows as List).map(
          (row) => (row as Map<String, dynamic>)['name']?.toString() ?? '',
        ),
      );
    } on PostgrestException catch (e) {
      if (!_isMissingDirectoryTaxonomyError(e)) rethrow;
      final contacts = await _supa
          .from('operation_directory_contacts')
          .select('area')
          .order('name');
      return _normalizePurchaseOrderNames(
        (contacts as List)
            .expand(
              (row) => _splitPurchaseOrderValues(
                (row as Map<String, dynamic>)['area'],
              ),
            )
            .map((value) => value.toUpperCase()),
      );
    }
  }

  Future<void> _loadDirectoryContacts() async {
    try {
      final rows = await _supa
          .from('operation_directory_contacts')
          .select('id,name,contact,active')
          .eq('active', true)
          .order('name');
      _directoryContacts = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      if (!_isMissingOperationDirectoryContactsError(e)) rethrow;
      _directoryContacts = <Map<String, dynamic>>[];
    }
  }

  Future<void> _loadMaintenanceOrders() async {
    final rows = await _supa
        .from('maintenance_orders')
        .select('id,ot_folio,equipment_label,area_label,status,requested_at')
        .order('requested_at', ascending: false)
        .order('created_at', ascending: false);
    _maintenanceOrders = (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map<String, dynamic>))
        .toList();
    _maintenanceOrdersById
      ..clear()
      ..addEntries(
        _maintenanceOrders.map(
          (row) => MapEntry((row['id'] ?? '').toString(), row),
        ),
      );
  }

  Future<void> _loadOrders() async {
    try {
      final targetInitialOrderId = widget.initialOrderId?.trim() ?? '';
      final orders = await _supa
          .from('maintenance_purchase_orders')
          .select('*')
          .order('order_date', ascending: false)
          .order('created_at', ascending: false);

      final orderList = (orders as List)
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      if (!_consumedInitialOrderSelection &&
          targetInitialOrderId.isNotEmpty &&
          !orderList.any(
            (row) => (row['id'] ?? '').toString() == targetInitialOrderId,
          )) {
        final exactOrderRows = await _supa
            .from('maintenance_purchase_orders')
            .select('*')
            .eq('id', targetInitialOrderId)
            .limit(1);
        final exactList = (exactOrderRows as List)
            .map(
              (row) => Map<String, dynamic>.from(row as Map<String, dynamic>),
            )
            .toList(growable: false);
        if (exactList.isNotEmpty) {
          orderList.insert(0, exactList.first);
        }
      }
      final linkedOtIds = orderList
          .map((row) => (row['linked_ot_id'] ?? '').toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      final linkedOtStatusById = <String, Map<String, dynamic>>{};
      if (linkedOtIds.isNotEmpty) {
        final linkedOtRows = await _supa
            .from('maintenance_orders')
            .select('id,ot_folio,status,equipment_label,area_label')
            .inFilter('id', linkedOtIds);
        for (final raw in linkedOtRows as List) {
          final row = Map<String, dynamic>.from(raw as Map<String, dynamic>);
          final id = (row['id'] ?? '').toString().trim();
          if (id.isEmpty) continue;
          linkedOtStatusById[id] = row;
          _maintenanceOrdersById[id] = row;
        }
      }

      _orders = orderList.map((order) {
        final linkedOtId = (order['linked_ot_id'] ?? '').toString().trim();
        final linkedOt =
            linkedOtStatusById[linkedOtId] ??
            _maintenanceOrdersById[linkedOtId];
        final linkedOtFolio = (order['linked_ot_folio'] ?? '')
            .toString()
            .trim();
        return {
          ...order,
          if (linkedOt != null) 'linked_ot_status': linkedOt['status'],
          if (linkedOtFolio.isEmpty && linkedOt != null)
            'linked_ot_folio': linkedOt['ot_folio'],
        };
      }).toList();

      final ids = orderList
          .map((row) => row['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      _linesByOrderId.clear();
      if (ids.isNotEmpty) {
        final lines = await _supa
            .from('maintenance_purchase_order_lines')
            .select('*')
            .inFilter('purchase_order_id', ids)
            .order('line_no');
        for (final raw in lines as List) {
          final row = Map<String, dynamic>.from(raw as Map<String, dynamic>);
          final orderId = row['purchase_order_id']?.toString() ?? '';
          _linesByOrderId.putIfAbsent(orderId, () => <Map<String, dynamic>>[]);
          _linesByOrderId[orderId]!.add(row);
        }
      }
      _selectedOrderId = _sanitizeSelectedOrderId(_selectedOrderId, orderList);
      if (!_consumedInitialOrderSelection &&
          targetInitialOrderId.isNotEmpty &&
          orderList.any(
            (row) => (row['id'] ?? '').toString() == targetInitialOrderId,
          )) {
        _selectedOrderId = targetInitialOrderId;
        _consumedInitialOrderSelection = true;
      }
      _purchaseOrdersSchemaReady = true;
      _purchaseOrdersSchemaMessage = null;
    } on PostgrestException catch (e) {
      if (!_isMissingPurchaseOrdersSchemaError(e)) rethrow;
      _orders = <Map<String, dynamic>>[];
      _linesByOrderId.clear();
      _selectedOrderId = null;
      _purchaseOrdersSchemaReady = false;
      _purchaseOrdersSchemaMessage =
          'Compras OT necesita la migración nueva en Supabase. Aplica `supabase db push` y vuelve a cargar.';
    }
    if (mounted) setState(() {});
    if (_consumedInitialOrderSelection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureOrderVisible(_selectedOrderId);
      });
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    return _orders.where((order) {
      for (final entry in _columnValueFilters.entries) {
        if (entry.value.isEmpty) continue;
        final value = _filterValueForOrder(order, entry.key);
        if (!entry.value.contains(value)) return false;
      }
      return true;
    }).toList();
  }

  int _countByStatus(String status) =>
      _orders.where((order) => order['status'] == status).length;

  bool _isSentToCash(Map<String, dynamic> order) =>
      _dateFromAny(order['sent_to_cash_at']) != null;

  bool get _hasActiveFilters => _columnValueFilters.isNotEmpty;

  int get _activeFiltersCount => _columnValueFilters.length;

  bool _hasColumnFilter(String columnId) =>
      (_columnValueFilters[columnId] ?? const <String>{}).isNotEmpty;

  String _linkedOtFolio(Map<String, dynamic> order) {
    final explicit = (order['linked_ot_folio'] ?? '').toString().trim();
    if (explicit.isNotEmpty) return explicit;
    final linkedOtId = (order['linked_ot_id'] ?? '').toString().trim();
    final ot = _maintenanceOrdersById[linkedOtId];
    return (ot?['ot_folio'] ?? '').toString().trim();
  }

  String _purchaseOrderConceptLabel(Map<String, dynamic> order) {
    final linkedConcept = (order['linked_material_label'] ?? '')
        .toString()
        .trim();
    if (linkedConcept.isNotEmpty) return linkedConcept;
    final vendorName = (order['quote_vendor_name'] ?? '').toString().trim();
    if (vendorName.isNotEmpty) return vendorName;
    return 'Sin nombre';
  }

  String _filterValueForOrder(Map<String, dynamic> order, String columnId) {
    switch (columnId) {
      case 'folio':
        return (order['folio'] ?? '').toString().trim();
      case 'fecha':
        return _fmtDateLabel(
          _dateFromAny(order['order_date']) ?? DateTime.now(),
        );
      case 'unidad_area':
        return (order['target_label'] ?? '').toString().trim();
      case 'ot':
        return _linkedOtFolio(order);
      case 'cotizacion':
        return _purchaseOrderConceptLabel(order);
      case 'estatus':
        final status = (order['status'] ?? 'draft').toString();
        return _kPurchaseOrderStatusLabel[status] ?? status;
      case 'caja':
        if ((order['status'] ?? '').toString() == 'purchased') {
          return 'Atendida';
        }
        return _isSentToCash(order) ? 'Mandada a caja' : 'Pendiente';
      default:
        return '';
    }
  }

  List<String> _columnDistinctValues(String columnId, {String search = ''}) {
    final query = search.trim().toLowerCase();
    final values =
        _orders
            .map((order) => _filterValueForOrder(order, columnId))
            .where((value) => value.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (query.isEmpty) return values;
    return values
        .where((value) => value.toLowerCase().contains(query))
        .toList();
  }

  String? _sanitizeSelectedOrderId(
    String? current,
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) return null;
    final ids = rows
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    if (current != null && ids.contains(current)) return current;
    return rows.first['id']?.toString();
  }

  int _selectedIndexIn(List<Map<String, dynamic>> rows) {
    if (_selectedOrderId == null) return rows.isEmpty ? -1 : 0;
    return rows.indexWhere((row) => row['id']?.toString() == _selectedOrderId);
  }

  Set<String> _currentSelectionIds() {
    if (_selectedOrderIds.isNotEmpty) return {..._selectedOrderIds};
    final id = _selectedOrderId;
    if (id == null || id.isEmpty) return <String>{};
    return <String>{id};
  }

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

  GlobalKey _rowKeyFor(String orderId) =>
      _rowKeys.putIfAbsent(orderId, () => GlobalKey(debugLabel: orderId));

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
    for (final row in _filteredOrders) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final rowContext = _rowKeyFor(id).currentContext;
      final rowBox = rowContext?.findRenderObject() as RenderBox?;
      if (rowBox == null || !rowBox.hasSize) continue;
      final topLeftGlobal = rowBox.localToGlobal(Offset.zero);
      final topLeftViewport = viewportBox.globalToLocal(topLeftGlobal);
      final viewportRect = Rect.fromLTWH(
        topLeftViewport.dx,
        topLeftViewport.dy,
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
      _selectedOrderIds
        ..clear()
        ..addAll(next);
      if (next.isEmpty) {
        _selectedOrderId = null;
        return;
      }
      if (_selectedOrderId != null && next.contains(_selectedOrderId)) return;
      for (final row in _filteredOrders) {
        final id = row['id']?.toString() ?? '';
        if (next.contains(id)) {
          _selectedOrderId = id;
          _selectionAnchorOrderId ??= id;
          return;
        }
      }
    });
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

  void _updateMarqueeAutoScroll() {
    if (!_marqueeActive || _marqueePointerLocal == null) {
      _marqueeAutoScrollVelocity = 0;
      _marqueeAutoScrollTimer?.cancel();
      _marqueeAutoScrollTimer = null;
      return;
    }
    final box =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _marqueeAutoScrollVelocity = 0;
      return;
    }
    const edge = 36.0;
    const maxStep = 18.0;
    final y = _marqueePointerLocal!.dy;
    if (y < edge) {
      _marqueeAutoScrollVelocity =
          -((edge - y) / edge).clamp(0.0, 1.0) * maxStep;
    } else if (y > box.size.height - edge) {
      _marqueeAutoScrollVelocity =
          ((y - (box.size.height - edge)) / edge).clamp(0.0, 1.0) * maxStep;
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
    _rowsScrollController.jumpTo(next);
    if (_marqueePointerLocal != null) {
      _marqueeCurrentContent = _localToContent(_marqueePointerLocal!);
    }
    _applyMarqueeSelection();
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
    _updateMarqueeAutoScroll();
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

  void _ensureOrderVisible(String? orderId, {int? moveDelta}) {
    if (orderId == null) return;
    final rows = _filteredOrders;
    final index = rows.indexWhere((row) => row['id']?.toString() == orderId);
    if (index < 0) return;
    final alignmentPolicy = moveDelta == null
        ? ScrollPositionAlignmentPolicy.explicit
        : moveDelta < 0
        ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
        : ScrollPositionAlignmentPolicy.keepVisibleAtEnd;
    final rowContext = _rowKeys[orderId]?.currentContext;
    if (rowContext != null) {
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        alignmentPolicy: alignmentPolicy,
      );
      return;
    }

    if (_rowsScrollController.hasClients) {
      const rowExtentEstimate = 88.0;
      final target = index * rowExtentEstimate;
      final viewport = _rowsScrollController.position.viewportDimension;
      final current = _rowsScrollController.offset;
      final maxVisible = current + viewport - rowExtentEstimate;
      if (target < current) {
        _rowsScrollController.jumpTo(
          target.clamp(0, _rowsScrollController.position.maxScrollExtent),
        );
      } else if (target > maxVisible) {
        _rowsScrollController.jumpTo(
          (target - (viewport - rowExtentEstimate)).clamp(
            0,
            _rowsScrollController.position.maxScrollExtent,
          ),
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _rowKeys[orderId]?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        alignmentPolicy: alignmentPolicy,
      );
    });
  }

  void _selectOrder(
    String? orderId, {
    bool requestFocus = true,
    bool ensureVisible = true,
    int? moveDelta,
    bool additive = false,
    bool additiveToggle = true,
    bool allowToggle = true,
  }) {
    if (!mounted) return;
    final normalized = orderId?.trim();
    setState(() {
      if (normalized == null || normalized.isEmpty) {
        _selectedOrderId = null;
        _selectionAnchorOrderId = null;
        _selectedOrderIds.clear();
      } else if (additive) {
        final next = {..._currentSelectionIds()};
        if (additiveToggle && next.contains(normalized)) {
          next.remove(normalized);
        } else {
          next.add(normalized);
        }
        _selectedOrderIds
          ..clear()
          ..addAll(next);
        if (next.isEmpty) {
          _selectedOrderId = null;
          _selectionAnchorOrderId = null;
        } else {
          _selectedOrderId = normalized;
          _selectionAnchorOrderId ??= normalized;
        }
      } else {
        if (allowToggle &&
            _selectedOrderId == normalized &&
            _selectedOrderIds.length <= 1) {
          _selectedOrderId = null;
          _selectionAnchorOrderId = null;
          _selectedOrderIds.clear();
        } else {
          _selectedOrderId = normalized;
          _selectionAnchorOrderId = normalized;
          _selectedOrderIds
            ..clear()
            ..add(normalized);
        }
      }
    });
    if (requestFocus) _rowsFocusNode.requestFocus();
    if (ensureVisible) _ensureOrderVisible(normalized, moveDelta: moveDelta);
  }

  void _extendSelectionTo(String orderId, List<Map<String, dynamic>> rows) {
    if (rows.isEmpty || orderId.trim().isEmpty) return;
    final anchorId = (_selectionAnchorOrderId?.isNotEmpty ?? false)
        ? _selectionAnchorOrderId!
        : (_selectedOrderId?.isNotEmpty ?? false)
        ? _selectedOrderId!
        : orderId;
    final anchorIndex = rows.indexWhere(
      (row) => row['id']?.toString() == anchorId,
    );
    final currentIndex = rows.indexWhere(
      (row) => row['id']?.toString() == orderId,
    );
    if (anchorIndex < 0 || currentIndex < 0) {
      _selectOrder(
        orderId,
        requestFocus: true,
        ensureVisible: false,
        allowToggle: false,
      );
      return;
    }
    final start = math.min(anchorIndex, currentIndex);
    final end = math.max(anchorIndex, currentIndex);
    final ids = <String>{};
    for (var i = start; i <= end; i++) {
      final id = rows[i]['id']?.toString() ?? '';
      if (id.isNotEmpty) ids.add(id);
    }
    setState(() {
      _selectedOrderId = orderId;
      _selectionAnchorOrderId = anchorId;
      _selectedOrderIds
        ..clear()
        ..addAll(ids);
    });
    _rowsFocusNode.requestFocus();
  }

  void _moveSelection(int delta) {
    final rows = _filteredOrders;
    if (rows.isEmpty) return;
    final currentIndex = _selectedIndexIn(rows);
    final safeIndex = currentIndex < 0 ? 0 : currentIndex;
    final nextIndex = (safeIndex + delta).clamp(0, rows.length - 1);
    _selectOrder(
      rows[nextIndex]['id']?.toString(),
      requestFocus: true,
      moveDelta: delta,
    );
  }

  Map<String, dynamic>? get _selectedOrderRow {
    final selectedId = _selectedOrderId;
    if (selectedId == null || selectedId.isEmpty) return null;
    for (final row in _filteredOrders) {
      if (row['id']?.toString() == selectedId) return row;
    }
    return null;
  }

  bool _canDeleteOrder(Map<String, dynamic> order) {
    final status = (order['status'] ?? 'draft').toString();
    return status == 'draft' || status == 'rejected';
  }

  Future<void> _openSelectedActionsMenu() async {
    final row = _selectedOrderRow;
    if (row == null) return;
    final rowContext = _rowKeys[_selectedOrderId]?.currentContext;
    await _showOrderActionsMenu(row, anchorContext: rowContext);
  }

  Future<bool> _showPurchaseOrderConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return ContractConfirmDialogKeyHandler(
          onConfirm: () => Navigator.of(dialogContext).pop(true),
          onCancel: () => Navigator.of(dialogContext).pop(false),
          child: ContractDialogShell(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF17324A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: Color(0xFF35526A),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
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
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    if (!_purchaseOrdersSchemaReady) {
      _toast(_purchaseOrdersSchemaMessage ?? 'Falta aplicar la migración.');
      return;
    }
    if (_runningAction) return;
    if (!_canDeleteOrder(order)) {
      _toast('Solo puedes eliminar órdenes en borrador o rechazadas.');
      return;
    }
    final orderId = (order['id'] ?? '').toString();
    if (orderId.isEmpty) return;
    final folio = (order['folio'] ?? '').toString().trim();
    final ok = await _showPurchaseOrderConfirmDialog(
      title: 'Eliminar orden permanentemente',
      message:
          'La orden ${folio.isEmpty ? '' : '$folio '}y sus renglones se eliminarán permanentemente.',
      confirmText: 'Eliminar',
    );
    if (!ok) return;
    setState(() => _runningAction = true);
    try {
      await _supa
          .from('maintenance_purchase_orders')
          .delete()
          .eq('id', orderId);
      await _loadOrders();
      _toast('Orden eliminada');
    } catch (e) {
      _toast('No se pudo eliminar la orden: $e');
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  KeyEventResult _handleRowsKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final rows = _filteredOrders;
    if (rows.isEmpty) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_isShiftPressed()) {
        final currentIndex = _selectedIndexIn(rows);
        final safeIndex = currentIndex < 0 ? 0 : currentIndex;
        final nextIndex = (safeIndex + 1).clamp(0, rows.length - 1);
        final nextId = rows[nextIndex]['id']?.toString();
        if (nextId != null && nextId.isNotEmpty) {
          _extendSelectionTo(nextId, rows);
          _ensureOrderVisible(nextId, moveDelta: 1);
        }
      } else {
        _moveSelection(1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_isShiftPressed()) {
        final currentIndex = _selectedIndexIn(rows);
        final safeIndex = currentIndex < 0 ? 0 : currentIndex;
        final nextIndex = (safeIndex - 1).clamp(0, rows.length - 1);
        final nextId = rows[nextIndex]['id']?.toString();
        if (nextId != null && nextId.isNotEmpty) {
          _extendSelectionTo(nextId, rows);
          _ensureOrderVisible(nextId, moveDelta: -1);
        }
      } else {
        _moveSelection(-1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f2 ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final selected = rows
          .where((row) => row['id']?.toString() == _selectedOrderId)
          .cast<Map<String, dynamic>?>()
          .firstWhere((row) => row != null, orElse: () => null);
      if (selected != null) {
        unawaited(_openOrderPrimaryAction(selected));
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.contextMenu ||
        key == LogicalKeyboardKey.f10) {
      unawaited(_openSelectedActionsMenu());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      final selected = _selectedOrderRow;
      if (selected != null && _canDeleteOrder(selected)) {
        unawaited(_deleteOrder(selected));
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_selectedOrderId != null) {
        _selectOrder(null, requestFocus: true);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  double _orderTotal(String orderId) {
    return (_linesByOrderId[orderId] ?? const <Map<String, dynamic>>[])
        .fold<double>(0, (sum, row) => sum + _lineTotal(row));
  }

  int _countSentToCashPending() {
    return _orders
        .where(
          (order) =>
              order['status'] == 'authorized' &&
              _dateFromAny(order['sent_to_cash_at']) != null,
        )
        .length;
  }

  double _sentToCashPendingTotal() {
    return _orders
        .where(
          (order) =>
              order['status'] == 'authorized' &&
              _dateFromAny(order['sent_to_cash_at']) != null,
        )
        .fold<double>(
          0,
          (sum, order) => sum + _orderTotal(order['id']?.toString() ?? ''),
        );
  }

  double _lineTotal(Map<String, dynamic> row) {
    final explicit = _toDouble(row['line_total']);
    if (explicit != null && explicit > 0) return explicit;
    final qty = _toDouble(row['qty']) ?? 0;
    final amount = _toDouble(row['amount']) ?? 0;
    return qty * amount;
  }

  double _estimatedOrderTotal(Map<String, dynamic> order) {
    final explicit = _toDouble(order['estimated_total']);
    if (explicit != null && explicit > 0) return explicit;
    return _orderTotal(order['id']?.toString() ?? '');
  }

  double? _actualOrderTotal(Map<String, dynamic> order) {
    final explicit = _toDouble(order['actual_total']);
    if (explicit == null || explicit <= 0) return null;
    return explicit;
  }

  Future<void> _createOrder() async {
    await _showOrderDialog();
  }

  Future<void> _openOrderPrimaryAction(Map<String, dynamic> order) async {
    final status = (order['status'] ?? '').toString();
    if (status == 'authorized' || status == 'purchased') {
      await _showOrderSummary(order);
      return;
    }
    await _showOrderDialog(initial: order);
  }

  Future<void> _showOrderSummary(Map<String, dynamic> order) async {
    final lines = List<Map<String, dynamic>>.from(
      (_linesByOrderId[(order['id'] ?? '').toString()] ?? const []).map(
        (row) => Map<String, dynamic>.from(row),
      ),
    );
    await _showPurchaseOrdersDialog<void>(
      context: context,
      builder: (dialogContext) => _PurchaseOrderSummaryDialog(
        order: order,
        lines: lines,
        estimatedTotal: _estimatedOrderTotal(order),
        actualTotal: _actualOrderTotal(order),
      ),
    );
  }

  Future<void> _editActualTotal(Map<String, dynamic> order) async {
    final actualTotal = await _showPurchaseOrdersDialog<double?>(
      context: context,
      builder: (dialogContext) {
        return _PurchaseOrderActualTotalDialog(
          folio: (order['folio'] ?? '').toString(),
          estimatedTotal: _estimatedOrderTotal(order),
          initialActualTotal: _actualOrderTotal(order),
        );
      },
    );
    if (actualTotal == null) return;
    await _updateStatus(
      order,
      status: (order['status'] ?? 'authorized').toString(),
      extra: <String, dynamic>{
        'actual_total': actualTotal,
        'actual_total_by': _supa.auth.currentUser?.id,
        'actual_total_by_name':
            _profile?.email ?? _supa.auth.currentUser?.email,
        'actual_total_at': DateTime.now().toIso8601String(),
      },
      toast: 'Total real actualizado',
    );
  }

  Future<void> _showOrderDialog({Map<String, dynamic>? initial}) async {
    final draft = await _showPurchaseOrdersDialog<_PurchaseOrderDraft>(
      context: context,
      builder: (dialogContext) {
        return _PurchaseOrderDialog(
          initial: initial,
          targetOptions: _targetOptions,
          directoryContacts: _directoryContacts,
          maintenanceOrders: _maintenanceOrders,
          initialLines: List<Map<String, dynamic>>.from(
            (_linesByOrderId[initial?['id']?.toString() ?? ''] ?? const []).map(
              (row) => Map<String, dynamic>.from(row),
            ),
          ),
          onShowLineDialog: _showLineDialog,
        );
      },
    );
    if (draft == null) return;
    if (draft.targetLabel.trim().isEmpty) {
      _toast('Selecciona la unidad o área.');
      return;
    }
    if (draft.lines.isEmpty) {
      _toast('Agrega al menos un renglón.');
      return;
    }
    await _saveOrder(
      initial: initial,
      orderDate: draft.orderDate,
      targetLabel: draft.targetLabel,
      linkedOtId: draft.linkedOtId,
      linkedOtFolio: draft.linkedOtFolio,
      providerType: draft.providerType,
      vendorName: draft.vendorName,
      contact: draft.contact,
      notes: draft.notes,
      lines: draft.lines,
    );
  }

  Future<Map<String, dynamic>?> _showLineDialog({
    Map<String, dynamic>? initial,
  }) async {
    return _showPurchaseOrdersDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => _PurchaseOrderLineDialog(initial: initial),
    );
  }

  Future<void> _saveOrder({
    required Map<String, dynamic>? initial,
    required DateTime orderDate,
    required String targetLabel,
    required String linkedOtId,
    required String linkedOtFolio,
    required String providerType,
    required String vendorName,
    required String contact,
    required String notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    if (!_purchaseOrdersSchemaReady) {
      _toast(_purchaseOrdersSchemaMessage ?? 'Falta aplicar la migración.');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final normalizedLinkedOtId = linkedOtId.trim();
      final firstLineDescription = lines
          .map((line) => (line['description'] ?? '').toString().trim())
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      final payload = <String, dynamic>{
        'order_date': _fmtDbDate(orderDate),
        'target_label': targetLabel.trim(),
        'linked_ot_id': normalizedLinkedOtId.isEmpty
            ? null
            : normalizedLinkedOtId,
        'linked_ot_folio': linkedOtFolio.trim().isEmpty
            ? null
            : linkedOtFolio.trim(),
        'linked_material_label':
            normalizedLinkedOtId.isEmpty || firstLineDescription.isEmpty
            ? null
            : firstLineDescription,
        'quote_vendor_name': vendorName.isEmpty ? null : vendorName,
        'quote_vendor_type': providerType,
        'quote_contact': contact.isEmpty ? null : contact,
        'notes': notes.isEmpty ? null : notes,
        'estimated_total': lines.fold<double>(
          0,
          (sum, line) => sum + _lineTotal(line),
        ),
        if (initial == null ||
            ((initial['status'] ?? '').toString() != 'authorized' &&
                (initial['status'] ?? '').toString() != 'purchased'))
          'actual_total': null,
        if (initial == null ||
            ((initial['status'] ?? '').toString() != 'authorized' &&
                (initial['status'] ?? '').toString() != 'purchased'))
          'actual_total_by': null,
        if (initial == null ||
            ((initial['status'] ?? '').toString() != 'authorized' &&
                (initial['status'] ?? '').toString() != 'purchased'))
          'actual_total_by_name': null,
        if (initial == null ||
            ((initial['status'] ?? '').toString() != 'authorized' &&
                (initial['status'] ?? '').toString() != 'purchased'))
          'actual_total_at': null,
        if (initial == null) 'requested_by': _supa.auth.currentUser?.id,
        if (initial == null) 'generated_from_ot': false,
        if (initial == null)
          'requested_by_name': _profile?.email ?? _supa.auth.currentUser?.email,
      };

      late final String orderId;
      if (initial == null) {
        final inserted = await _supa
            .from('maintenance_purchase_orders')
            .insert(payload)
            .select('id')
            .single();
        orderId = (inserted['id'] ?? '').toString();
      } else {
        orderId = (initial['id'] ?? '').toString();
        await _supa
            .from('maintenance_purchase_orders')
            .update(payload)
            .eq('id', orderId);
      }

      final currentLineIds = initial == null
          ? <String>{}
          : ((_linesByOrderId[orderId] ?? const <Map<String, dynamic>>[])
                .map((line) => (line['id'] ?? '').toString().trim())
                .where((id) => id.isNotEmpty)
                .toSet());
      final retainedLineIds = <String>{};
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final description = (line['description'] ?? '').toString().trim();
        if (description.isEmpty) continue;
        final linePayload = <String, dynamic>{
          'purchase_order_id': orderId,
          'line_no': i + 1,
          'line_type': (line['line_type'] ?? 'material').toString(),
          'qty': _toDouble(line['qty']),
          'unit': _emptyAsNull(line['unit']),
          'description': description,
          'amount': _toDouble(line['amount']),
          'line_total': _lineTotal(line),
          'notes': _emptyAsNull(line['notes']),
        };
        final lineId = (line['id'] ?? '').toString().trim();
        if (lineId.isNotEmpty && currentLineIds.contains(lineId)) {
          retainedLineIds.add(lineId);
          await _supa
              .from('maintenance_purchase_order_lines')
              .update(linePayload)
              .eq('id', lineId);
          continue;
        }
        final inserted = await _supa
            .from('maintenance_purchase_order_lines')
            .insert(linePayload)
            .select('id')
            .single();
        line['id'] = inserted['id'];
      }

      final lineIdsToDelete = currentLineIds
          .difference(retainedLineIds)
          .toList();
      if (lineIdsToDelete.isNotEmpty) {
        await _supa
            .from('maintenance_purchase_order_lines')
            .delete()
            .inFilter('id', lineIdsToDelete);
      }

      if (normalizedLinkedOtId.isNotEmpty) {
        await _otPurchaseLinkService.syncLinkedPurchaseOrderIntoOtMaterials(
          purchaseOrderId: orderId,
        );
      }
      final status = (initial?['status'] ?? 'draft').toString();
      if ((status == 'authorized' || status == 'purchased') &&
          normalizedLinkedOtId.isNotEmpty) {
        await _otPurchaseLinkService.syncOtStatusFromLinkedPurchaseOrder(
          purchaseOrderId: orderId,
          actorUserId: _supa.auth.currentUser?.id,
          actorName: _profile?.email ?? _supa.auth.currentUser?.email,
        );
      }

      await _loadOrders();
      _toast(initial == null ? 'Orden creada' : 'Orden actualizada');
    } on PostgrestException catch (e) {
      if (_isMissingPurchaseOrdersSchemaError(e)) {
        setState(() {
          _purchaseOrdersSchemaReady = false;
          _purchaseOrdersSchemaMessage =
              'Compras OT necesita aplicar la migración de vínculo OT/OC en Supabase. Aplica `supabase db push` y vuelve a cargar.';
        });
      }
      _toast('No se pudo guardar la orden: $e');
    } catch (e) {
      _toast('No se pudo guardar la orden: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendToDirection(Map<String, dynamic> order) async {
    await _updateStatus(
      order,
      status: 'pending_direction',
      extra: const <String, dynamic>{
        'sent_to_cash_by': null,
        'sent_to_cash_by_name': null,
        'sent_to_cash_at': null,
      },
      toast: 'Orden enviada a Dirección',
    );
  }

  Future<void> _authorizeOrder(Map<String, dynamic> order) async {
    if (!_isDirection) {
      _toast('Solo Dirección puede autorizar.');
      return;
    }
    await _updateStatus(
      order,
      status: 'authorized',
      extra: <String, dynamic>{
        'direction_authorized_by': _supa.auth.currentUser?.id,
        'direction_authorized_by_name':
            _profile?.email ?? _supa.auth.currentUser?.email,
        'direction_authorized_at': DateTime.now().toIso8601String(),
        'direction_rejected_at': null,
      },
      toast: 'Orden autorizada',
    );
  }

  Future<void> _rejectOrder(Map<String, dynamic> order) async {
    if (!_isDirection) {
      _toast('Solo Dirección puede rechazar.');
      return;
    }
    final comment = await _showCommentDialog(
      title: 'Rechazar orden',
      label: 'Motivo del rechazo',
    );
    if (comment == null) return;
    await _updateStatus(
      order,
      status: 'rejected',
      extra: <String, dynamic>{
        'direction_rejected_at': DateTime.now().toIso8601String(),
        'direction_comment': comment.isEmpty ? null : comment,
        'sent_to_cash_by': null,
        'sent_to_cash_by_name': null,
        'sent_to_cash_at': null,
      },
      toast: 'Orden rechazada',
    );
  }

  Future<void> _sendToCash(Map<String, dynamic> order) async {
    await _updateStatus(
      order,
      status: 'authorized',
      extra: <String, dynamic>{
        'sent_to_cash_by': _supa.auth.currentUser?.id,
        'sent_to_cash_by_name':
            _profile?.email ?? _supa.auth.currentUser?.email,
        'sent_to_cash_at': DateTime.now().toIso8601String(),
      },
      toast: 'Orden enviada a caja',
    );
  }

  Future<void> _removeFromCash(Map<String, dynamic> order) async {
    await _updateStatus(
      order,
      status: 'authorized',
      extra: const <String, dynamic>{
        'sent_to_cash_by': null,
        'sent_to_cash_by_name': null,
        'sent_to_cash_at': null,
      },
      toast: 'Orden retirada de caja',
    );
  }

  Future<void> _markAsPurchased(Map<String, dynamic> order) async {
    if (_actualOrderTotal(order) == null) {
      await _editActualTotal(order);
      final refreshed = _orders
          .where(
            (row) =>
                (row['id'] ?? '').toString() == (order['id'] ?? '').toString(),
          )
          .cast<Map<String, dynamic>?>()
          .firstWhere((row) => row != null, orElse: () => null);
      if (refreshed == null || _actualOrderTotal(refreshed) == null) {
        _toast('Captura el total real antes de marcar como comprada.');
        return;
      }
      order = refreshed;
    }
    await _updateStatus(
      order,
      status: 'purchased',
      extra: <String, dynamic>{
        'purchased_by': _supa.auth.currentUser?.id,
        'purchased_by_name': _profile?.email ?? _supa.auth.currentUser?.email,
        'purchased_at': DateTime.now().toIso8601String(),
        'sent_to_cash_by': null,
        'sent_to_cash_by_name': null,
        'sent_to_cash_at': null,
      },
      toast: 'Orden marcada como comprada',
    );
  }

  Future<void> _reopenPurchasedOrder(Map<String, dynamic> order) async {
    await _updateStatus(
      order,
      status: 'authorized',
      extra: <String, dynamic>{
        'purchased_by': null,
        'purchased_by_name': null,
        'purchased_at': null,
      },
      toast: 'Orden regresada a pendiente de compra',
    );
  }

  Future<void> _showOrderActionsMenu(
    Map<String, dynamic> order, {
    Offset? globalPosition,
    BuildContext? anchorContext,
  }) async {
    final orderId = order['id']?.toString();
    if (orderId == null || orderId.isEmpty) return;
    _selectOrder(orderId, requestFocus: true, ensureVisible: false);

    final status = (order['status'] ?? 'draft').toString();
    final canEdit = true;
    final canSend = status == 'draft' || status == 'rejected';
    final canAuthorize =
        _isDirection && status != 'authorized' && status != 'purchased';
    final canReject =
        _isDirection && status != 'rejected' && status != 'purchased';
    final sentToCash = _dateFromAny(order['sent_to_cash_at']) != null;
    final canSendToCash = status == 'authorized' && !sentToCash;
    final canRemoveFromCash = status == 'authorized' && sentToCash;
    final canMarkPurchased = status == 'authorized';
    final canReopenPurchase = status == 'purchased';
    final canCaptureActualTotal =
        status == 'authorized' || status == 'purchased';
    final canDelete = _canDeleteOrder(order);
    final overlay = Overlay.of(context).context.findRenderObject();
    RelativeRect position = const RelativeRect.fromLTRB(0, 0, 0, 0);
    if (globalPosition != null && overlay is RenderBox) {
      position = RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      );
    } else if (anchorContext != null && overlay is RenderBox) {
      final box = anchorContext.findRenderObject();
      if (box is RenderBox) {
        final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
        position = RelativeRect.fromRect(
          Rect.fromLTWH(
            origin.dx,
            origin.dy + box.size.height,
            box.size.width,
            0,
          ),
          Offset.zero & overlay.size,
        );
      }
    }

    final action = await showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFFF6FBF9),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
      ),
      items: [
        if (canEdit)
          PopupMenuItem<String>(
            value: 'edit',
            child: _PurchaseOrderActionMenuLabel(
              icon: status == 'authorized' || status == 'purchased'
                  ? Icons.receipt_long_rounded
                  : Icons.edit_outlined,
              title: status == 'authorized' || status == 'purchased'
                  ? 'Ver resumen'
                  : 'Editar',
              subtitle: status == 'authorized' || status == 'purchased'
                  ? 'Consultar datos y renglones de la orden'
                  : 'Abrir la captura de la orden',
            ),
          ),
        if (canCaptureActualTotal)
          const PopupMenuItem<String>(
            value: 'actual_total',
            child: _PurchaseOrderActionMenuLabel(
              icon: Icons.attach_money_rounded,
              title: 'Total real',
              subtitle: 'Registrar el gasto real de la compra',
            ),
          ),
        if (canSend)
          const PopupMenuItem<String>(
            value: 'send',
            child: _PurchaseOrderActionMenuLabel(
              icon: Icons.forward_to_inbox_rounded,
              title: 'Enviar a Dirección',
              subtitle: 'Solicitar autorización formal',
            ),
          ),
        if (canAuthorize)
          const PopupMenuItem<String>(
            value: 'authorize',
            child: _PurchaseOrderActionMenuLabel(
              icon: Icons.verified_rounded,
              title: 'Autorizar',
              subtitle: 'Liberar la orden para OT',
            ),
          ),
        if (canSendToCash)
          const PopupMenuItem<String>(
            value: 'send_to_cash',
            child: _PurchaseOrderActionMenuLabel(
              icon: Icons.point_of_sale_rounded,
              title: 'Mandar a caja',
              subtitle: 'Avisar a caja que ya puede entregar efectivo',
            ),
          ),
        if (canRemoveFromCash)
          const PopupMenuItem<String>(
            value: 'remove_from_cash',
            child: _PurchaseOrderActionMenuLabel(
              icon: Icons.remove_shopping_cart_rounded,
              title: 'Quitar de caja',
              subtitle: 'Regresar la orden a autorización sin caja',
            ),
          ),
        if (canMarkPurchased)
          const PopupMenuItem<String>(
            value: 'purchase',
            child: _PurchaseOrderActionMenuLabel(
              icon: Icons.shopping_cart_checkout_rounded,
              title: 'Marcar como comprada',
              subtitle: 'Confirmar compra física realizada',
            ),
          ),
        if (canReopenPurchase)
          const PopupMenuItem<String>(
            value: 'reopen_purchase',
            child: _PurchaseOrderActionMenuLabel(
              icon: Icons.undo_rounded,
              title: 'Regresar a autorizada',
              subtitle: 'Volver a pendiente de compra',
            ),
          ),
        if (canReject)
          const PopupMenuItem<String>(
            value: 'reject',
            child: _PurchaseOrderActionMenuLabel(
              icon: Icons.cancel_outlined,
              title: 'Rechazar',
              subtitle: 'Regresar para corrección',
            ),
          ),
        if (canDelete)
          const PopupMenuItem<String>(
            value: 'delete',
            child: _PurchaseOrderActionMenuLabel(
              icon: Icons.delete_forever_outlined,
              title: 'Eliminar permanentemente',
              subtitle: 'Borrar la orden y sus renglones',
            ),
          ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        await _openOrderPrimaryAction(order);
        break;
      case 'actual_total':
        await _editActualTotal(order);
        break;
      case 'send':
        await _sendToDirection(order);
        break;
      case 'authorize':
        await _authorizeOrder(order);
        break;
      case 'send_to_cash':
        await _sendToCash(order);
        break;
      case 'remove_from_cash':
        await _removeFromCash(order);
        break;
      case 'reject':
        await _rejectOrder(order);
        break;
      case 'purchase':
        await _markAsPurchased(order);
        break;
      case 'reopen_purchase':
        await _reopenPurchasedOrder(order);
        break;
      case 'delete':
        await _deleteOrder(order);
        break;
    }
  }

  Future<void> _updateStatus(
    Map<String, dynamic> order, {
    required String status,
    Map<String, dynamic>? extra,
    required String toast,
  }) async {
    if (!_purchaseOrdersSchemaReady) {
      _toast(_purchaseOrdersSchemaMessage ?? 'Falta aplicar la migración.');
      return;
    }
    if (_runningAction) return;
    final id = (order['id'] ?? '').toString();
    if (id.isEmpty) return;
    setState(() => _runningAction = true);
    try {
      await _supa
          .from('maintenance_purchase_orders')
          .update({'status': status, ...?extra})
          .eq('id', id);
      await _otPurchaseLinkService.syncLinkedPurchaseOrderIntoOtMaterials(
        purchaseOrderId: id,
      );
      if (status == 'authorized' || status == 'purchased') {
        await _otPurchaseLinkService.syncOtStatusFromLinkedPurchaseOrder(
          purchaseOrderId: id,
          actorUserId: _supa.auth.currentUser?.id,
          actorName: _profile?.email ?? _supa.auth.currentUser?.email,
        );
      }
      await _loadOrders();
      _toast(toast);
    } catch (e) {
      if (e is PostgrestException && _isMissingPurchaseOrdersSchemaError(e)) {
        setState(() {
          _purchaseOrdersSchemaReady = false;
          _purchaseOrdersSchemaMessage =
              'Compras OT necesita aplicar la migración de vínculo OT/OC en Supabase. Aplica `supabase db push` y vuelve a cargar.';
        });
      }
      if (e is PostgrestException &&
          _isMissingPurchasedPurchaseOrderSchemaError(e)) {
        setState(() {
          _purchaseOrdersSchemaReady = false;
          _purchaseOrdersSchemaMessage =
              'Compras OT necesita aplicar la migración de compra física / caja en Supabase. Aplica `supabase db push` y vuelve a cargar.';
        });
      }
      _toast('No se pudo actualizar la orden: $e');
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  Future<String?> _showCommentDialog({
    required String title,
    required String label,
  }) async {
    return _showPurchaseOrdersDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _PurchaseOrderCommentDialog(title: title, label: label);
      },
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _logout() => signOutAndRouteToLogin(context);

  Future<void> _goToDashboard() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const DashboardPage()));
  }

  Future<void> _goToGeneralDashboard() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const GeneralDashboardPage()));
  }

  Future<void> _goToEntriesAndOutputs() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const InventoryPage()));
  }

  Future<void> _goToProduction() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const InventoryProductionPage()));
  }

  Future<void> _goToInventory() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const InventoryStockPage()));
  }

  Future<void> _goToServices() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const ServicesPage()));
  }

  Future<void> _goToWeighings() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const WeighingsPage()));
  }

  Future<void> _goToMaintenance() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const MaintenancePage()));
  }

  Future<void> _goToWarehouse() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const WarehousePage()));
  }

  Future<void> _goToOperationDirectory() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const OperationDirectoryPage()));
  }

  void _clearFilters() {
    setState(() => _columnValueFilters.clear());
  }

  Future<void> _openColumnFilterDialog(String columnId, String label) async {
    final initialSelected = {...(_columnValueFilters[columnId] ?? <String>{})};
    final scrollController = ScrollController();

    try {
      final result = await showDialog<_PurchaseOrderFilterDialogResult>(
        context: context,
        builder: (dialogContext) {
          final localSelected = <String>{...initialSelected};
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
                  _PurchaseOrderFilterDialogResult(
                    selectedValues: localSelected,
                  ),
                );
              }

              return Focus(
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  final key = event.logicalKey;
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
                        decoration: _purchaseOrderFilterDialogDecoration(),
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
                                decoration: _poInputDecoration(
                                  labelText: 'Buscar',
                                  prefixIcon: const Icon(Icons.search_rounded),
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
                                    : ScrollConfiguration(
                                        behavior: const MaterialScrollBehavior()
                                            .copyWith(
                                              dragDevices: <PointerDeviceKind>{
                                                PointerDeviceKind.touch,
                                                PointerDeviceKind.mouse,
                                                PointerDeviceKind.stylus,
                                                PointerDeviceKind
                                                    .invertedStylus,
                                                PointerDeviceKind.unknown,
                                              },
                                            ),
                                        child: Scrollbar(
                                          controller: scrollController,
                                          thumbVisibility: true,
                                          trackVisibility: true,
                                          interactive: true,
                                          child: ListView.builder(
                                            controller: scrollController,
                                            primary: false,
                                            dragStartBehavior:
                                                DragStartBehavior.down,
                                            itemCount: options.length,
                                            itemBuilder: (_, i) {
                                              final value = options[i];
                                              final checked = localSelected
                                                  .contains(value);
                                              return _PurchaseOrderFilterValueTile(
                                                label: value,
                                                selected: checked,
                                                onTap: () {
                                                  setLocalState(() {
                                                    if (checked) {
                                                      localSelected.remove(
                                                        value,
                                                      );
                                                    } else {
                                                      localSelected.add(value);
                                                    }
                                                  });
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    style:
                                        _purchaseOrderFilterOutlinedButtonStyle(),
                                    onPressed: () =>
                                        Navigator.pop(dialogContext),
                                    child: const Text('Cancelar'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    style:
                                        _purchaseOrderFilterOutlinedButtonStyle(),
                                    onPressed: () {
                                      Navigator.pop(
                                        dialogContext,
                                        const _PurchaseOrderFilterDialogResult(
                                          selectedValues: <String>{},
                                        ),
                                      );
                                    },
                                    child: const Text('Limpiar'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    style:
                                        _purchaseOrderFilterFilledButtonStyle(),
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
      if (!mounted) return;
      if (result == null) return;
      setState(() {
        if (result.selectedValues.isEmpty) {
          _columnValueFilters.remove(columnId);
        } else {
          _columnValueFilters[columnId] = result.selectedValues;
        }
      });
    } finally {
      scrollController.dispose();
    }
  }

  ButtonStyle _purchaseOrdersActionFilledButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: const Color(0xFF6C8E87),
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xFF6C8E87).withValues(alpha: 0.38),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    );
  }

  ButtonStyle _purchaseOrdersActionOutlinedButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF17324A),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
      backgroundColor: Colors.white.withValues(alpha: 0.52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    );
  }

  Widget _buildTopActionsBar() {
    final visibleCount = _filteredOrders.length;
    final selected = _filteredOrders.where(
      (row) => row['id']?.toString() == _selectedOrderId,
    );
    final selectedOrder = selected.isEmpty ? null : selected.first;
    final selectedFolio = (selectedOrder?['folio'] ?? '').toString().trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      child: Card(
        elevation: 0,
        color: Colors.white.withValues(alpha: 0.34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final actions = FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      style: _purchaseOrdersActionFilledButtonStyle(),
                      onPressed: _saving || !_purchaseOrdersSchemaReady
                          ? null
                          : _createOrder,
                      icon: const Icon(Icons.add_box_rounded),
                      label: const Text('Nueva orden'),
                    ),
                    OutlinedButton.icon(
                      style: _purchaseOrdersActionOutlinedButtonStyle(),
                      onPressed: _hasActiveFilters ? _clearFilters : null,
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Limpiar filtros'),
                    ),
                  ],
                ),
              );

              final info = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$visibleCount visibles · ${_orders.length} totales',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _hasActiveFilters
                        ? '$_activeFiltersCount filtros activos'
                        : 'Sin filtros activos',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2A4B49),
                    ),
                  ),
                  const Text(
                    'Tab recorre toolbar y filtros · Enter/Space abre el control enfocado',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5A7287),
                    ),
                  ),
                  if (selectedFolio.isNotEmpty)
                    const Text(
                      'Enter/F2 edita · Space abre acciones · Delete elimina borrador',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5A7287),
                      ),
                    ),
                  if (selectedFolio.isNotEmpty)
                    Text(
                      'Selección: $selectedFolio',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF35526A),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ServicesShell(
      headerTitle: 'Compras OT',
      activeOverlayModule: ServicesOverlayNavModule.comprasOt,
      onLogout: _logout,
      onGoToGeneralDashboard: _goToGeneralDashboard,
      onGoToOperacion: _goToDashboard,
      onGoToEntriesAndOutputs: _goToEntriesAndOutputs,
      onGoToProduction: _goToProduction,
      onGoToInventory: _goToInventory,
      onGoToServices: _goToServices,
      onGoToWeighings: _goToWeighings,
      onGoToMaintenance: _goToMaintenance,
      onGoToPurchaseOrders: () async {},
      onGoToOperationDirectory: _goToOperationDirectory,
      onGoToWarehouse: _goToWarehouse,
      topContent: OperationalGlassToolbarPanel(child: _buildTopActionsBar()),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_purchaseOrdersSchemaReady &&
                    _purchaseOrdersSchemaMessage != null) ...[
                  _SchemaWarningCard(message: _purchaseOrdersSchemaMessage!),
                  const SizedBox(height: 12),
                ],
                _buildMetricStrip(),
                const SizedBox(height: 12),
                Expanded(child: _buildOrdersGrid()),
              ],
            ),
    );
  }

  Widget _buildMetricStrip() {
    return Row(
      children: [
        _metricCard(
          'Borrador',
          '${_countByStatus('draft')}',
          Icons.edit_note_rounded,
        ),
        const SizedBox(width: 8),
        _metricCard(
          'Pendientes',
          '${_countByStatus('pending_direction')}',
          Icons.pending_actions_rounded,
        ),
        const SizedBox(width: 8),
        _metricCard(
          'Pend. compra',
          '${_countByStatus('authorized')}',
          Icons.verified_rounded,
        ),
        const SizedBox(width: 8),
        _metricCard(
          'En caja',
          '${_countSentToCashPending()}',
          Icons.point_of_sale_rounded,
        ),
        const SizedBox(width: 8),
        _metricCard(
          'Compradas',
          '${_countByStatus('purchased')}',
          Icons.shopping_cart_checkout_rounded,
        ),
        const SizedBox(width: 8),
        _metricCard(
          'Monto en caja',
          _fmtMoney(_sentToCashPendingTotal()),
          Icons.attach_money_rounded,
        ),
      ],
    );
  }

  Widget _metricCard(String title, String value, IconData icon) {
    return Expanded(
      child: OperationalMetricCard(
        icon: icon,
        label: title,
        value: value,
        width: double.infinity,
        margin: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildOrdersGrid() {
    final rows = _filteredOrders;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
      ),
      child: rows.isEmpty
          ? const Center(
              child: Text('No hay órdenes de compra con ese filtro.'),
            )
          : Focus(
              focusNode: _rowsFocusNode,
              autofocus: true,
              onKeyEvent: (_, event) => _handleRowsKeyEvent(event),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Card(
                      elevation: 0.2,
                      color: const Color(0xFFE7F1F8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: ContractGridScaledRow(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PurchaseOrderHeaderCell(
                                label: 'FOLIO',
                                width: _kPoFolioColW,
                                active: _hasColumnFilter('folio'),
                                onFilter: () =>
                                    _openColumnFilterDialog('folio', 'FOLIO'),
                              ),
                              const _PurchaseOrderGridColumnDivider(),
                              _PurchaseOrderHeaderCell(
                                label: 'FECHA',
                                width: _kPoDateColW,
                                active: _hasColumnFilter('fecha'),
                                onFilter: () =>
                                    _openColumnFilterDialog('fecha', 'FECHA'),
                              ),
                              const _PurchaseOrderGridColumnDivider(),
                              _PurchaseOrderHeaderCell(
                                label: 'UNIDAD/AREA',
                                width: _kPoTargetColW,
                                active: _hasColumnFilter('unidad_area'),
                                onFilter: () => _openColumnFilterDialog(
                                  'unidad_area',
                                  'UNIDAD/AREA',
                                ),
                              ),
                              const _PurchaseOrderGridColumnDivider(),
                              _PurchaseOrderHeaderCell(
                                label: 'ID OT',
                                width: _kPoOtColW,
                                active: _hasColumnFilter('ot'),
                                onFilter: () =>
                                    _openColumnFilterDialog('ot', 'ID OT'),
                              ),
                              const _PurchaseOrderGridColumnDivider(),
                              _PurchaseOrderHeaderCell(
                                label: 'COTIZACION',
                                width: _kPoVendorColW,
                                active: _hasColumnFilter('cotizacion'),
                                onFilter: () => _openColumnFilterDialog(
                                  'cotizacion',
                                  'COTIZACION',
                                ),
                              ),
                              const _PurchaseOrderGridColumnDivider(),
                              _PurchaseOrderHeaderCell(
                                label: 'ESTATUS',
                                width: _kPoStatusColW,
                                active: _hasColumnFilter('estatus'),
                                onFilter: () => _openColumnFilterDialog(
                                  'estatus',
                                  'ESTATUS',
                                ),
                              ),
                              const _PurchaseOrderGridColumnDivider(),
                              _PurchaseOrderHeaderCell(
                                label: 'CAJA',
                                width: _kPoCashColW,
                                active: _hasColumnFilter('caja'),
                                onFilter: () =>
                                    _openColumnFilterDialog('caja', 'CAJA'),
                              ),
                              const _PurchaseOrderGridColumnDivider(),
                              const _OrderHeaderCell(
                                label: 'COMPRA',
                                width: _kPoPurchaseColW,
                              ),
                              const _PurchaseOrderGridColumnDivider(),
                              const _OrderHeaderCell(
                                label: 'TOTAL EST.',
                                width: _kPoEstimatedTotalColW,
                              ),
                              const _PurchaseOrderGridColumnDivider(),
                              const _OrderHeaderCell(
                                label: 'TOTAL REAL',
                                width: _kPoActualTotalColW,
                              ),
                              const _PurchaseOrderGridColumnDivider(),
                              const _OrderHeaderCell(
                                label: 'ACCIONES',
                                width: _kPoActionsColW,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Scrollbar(
                        controller: _rowsScrollController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        interactive: true,
                        child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: (event) {
                            if (event.kind != PointerDeviceKind.mouse &&
                                event.kind != PointerDeviceKind.stylus &&
                                event.kind != PointerDeviceKind.unknown) {
                              return;
                            }
                            if (event.buttons != kPrimaryMouseButton) return;
                            _startMarqueeSelection(event.localPosition);
                          },
                          onPointerMove: (event) {
                            if (event.buttons != kPrimaryMouseButton) return;
                            _updateMarqueeSelection(event.localPosition);
                          },
                          onPointerUp: (_) => _endMarqueeSelection(),
                          onPointerCancel: (_) => _endMarqueeSelection(),
                          child: Container(
                            key: _rowsViewportKey,
                            child: ClipRect(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AbsorbPointer(
                                    absorbing: _marqueeActive,
                                    child: ListView.builder(
                                      controller: _rowsScrollController,
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      itemCount: rows.length,
                                      itemBuilder: (context, index) {
                                        final order = rows[index];
                                        final orderId = order['id']?.toString();
                                        final isSelected =
                                            orderId != null &&
                                            _currentSelectionIds().contains(
                                              orderId,
                                            );
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            bottom: index == rows.length - 1
                                                ? 0
                                                : 6,
                                          ),
                                          child: _PurchaseOrderRowCard(
                                            key: orderId == null
                                                ? ValueKey(index)
                                                : _rowKeyFor(orderId),
                                            order: order,
                                            estimatedTotal:
                                                _estimatedOrderTotal(order),
                                            actualTotal: _actualOrderTotal(
                                              order,
                                            ),
                                            selected: isSelected,
                                            onTap: () {
                                              final normalized =
                                                  orderId?.trim() ?? '';
                                              if (normalized.isEmpty) return;
                                              if (_isShiftPressed()) {
                                                _extendSelectionTo(
                                                  normalized,
                                                  rows,
                                                );
                                                return;
                                              }
                                              _selectOrder(
                                                normalized,
                                                requestFocus: true,
                                                ensureVisible: false,
                                                additive: _isCtrlOrCmdPressed(),
                                                additiveToggle: true,
                                                allowToggle: false,
                                              );
                                            },
                                            onDoubleTap: () =>
                                                _openOrderPrimaryAction(order),
                                            onSecondaryTapDown: (details) {
                                              final normalized =
                                                  orderId?.trim() ?? '';
                                              if (normalized.isNotEmpty &&
                                                  !_currentSelectionIds()
                                                      .contains(normalized)) {
                                                _selectOrder(
                                                  normalized,
                                                  requestFocus: true,
                                                  ensureVisible: false,
                                                  allowToggle: false,
                                                );
                                              }
                                              unawaited(
                                                _showOrderActionsMenu(
                                                  order,
                                                  globalPosition:
                                                      details.globalPosition,
                                                ),
                                              );
                                            },
                                            onOpenActions: (buttonContext) =>
                                                _showOrderActionsMenu(
                                                  order,
                                                  anchorContext: buttonContext,
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (_marqueeActive)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: CustomPaint(
                                          painter:
                                              _PurchaseOrderMarqueeSelectionPainter(
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
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

Future<T?> _showPurchaseOrdersDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      return Theme(
        data: Theme.of(dialogContext).copyWith(
          dialogTheme: DialogThemeData(
            backgroundColor: const Color(0xFFF4FAF8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
            ),
          ),
        ),
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey != LogicalKeyboardKey.escape) {
              return KeyEventResult.ignored;
            }
            Navigator.of(dialogContext).maybePop();
            return KeyEventResult.handled;
          },
          child: builder(dialogContext),
        ),
      );
    },
  );
}

class _OrderHeaderCell extends StatelessWidget {
  final String label;
  final double width;

  const _OrderHeaderCell({required this.label, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF35526A),
        ),
      ),
    );
  }
}

class _PurchaseOrderPickerOption<T> {
  final T value;
  final String label;
  final String? subtitle;

  const _PurchaseOrderPickerOption({
    required this.value,
    required this.label,
    this.subtitle,
  });
}

class _PurchaseOrderSelectField<T> extends StatelessWidget {
  final String label;
  final T value;
  final String displayValue;
  final List<_PurchaseOrderPickerOption<T>> options;
  final ValueChanged<T> onChanged;

  const _PurchaseOrderSelectField({
    required this.label,
    required this.value,
    required this.displayValue,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Future<void> openPicker() async {
      final picked = await _showPurchaseOrderSearchablePickerDialog<T>(
        context: context,
        title: label,
        selectedValue: value,
        options: options,
      );
      if (picked == null) return;
      onChanged(picked);
    }

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            openPicker();
            return null;
          },
        ),
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: openPicker,
        child: InputDecorator(
          decoration: _poInputDecoration(labelText: label),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.unfold_more_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseOrderFilterValueTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PurchaseOrderFilterValueTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onTap();
              return null;
            },
          ),
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFDDF0E8)
                  : Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFF6C8E87).withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: selected
                      ? const Color(0xFF0D5C46)
                      : const Color(0xFF5A7287),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF17324A),
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

Future<T?> _showPurchaseOrderSearchablePickerDialog<T>({
  required BuildContext context,
  required String title,
  required T selectedValue,
  required List<_PurchaseOrderPickerOption<T>> options,
}) {
  return shared_picker.showSearchablePickerDialog<T>(
    context,
    title: title,
    initialValue: selectedValue,
    options: options
        .map(
          (option) => shared_picker.SearchablePickerOption<T>(
            value: option.value,
            label: option.label,
          ),
        )
        .toList(growable: false),
  );
}

class _PurchaseOrderFilterDialogResult {
  final Set<String> selectedValues;
  const _PurchaseOrderFilterDialogResult({required this.selectedValues});
}

class _PurchaseOrderHeaderCell extends StatelessWidget {
  final String label;
  final double width;
  final bool active;
  final VoidCallback onFilter;

  const _PurchaseOrderHeaderCell({
    required this.label,
    required this.width,
    required this.active,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _PurchaseOrderHeaderExpandCell(
        label: label,
        active: active,
        onFilter: onFilter,
      ),
    );
  }
}

class _PurchaseOrderHeaderExpandCell extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onFilter;

  const _PurchaseOrderHeaderExpandCell({
    required this.label,
    required this.active,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return _PurchaseOrderKeyboardGridAction(
      onActivate: onFilter,
      builder: (context, focused) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: focused ? const Color(0xFFD8EAF6) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: focused
                ? Border.all(
                    color: const Color(0xFF3C8DCC).withValues(alpha: 0.72),
                  )
                : null,
          ),
          child: Row(
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
                        ? const Color(0xFF6C8E87)
                        : const Color(0xFFE7F1F8).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active
                          ? const Color(0xFF6C8E87).withValues(alpha: 0.55)
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
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF35526A),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PurchaseOrderKeyboardGridAction extends StatefulWidget {
  final VoidCallback onActivate;
  final Widget Function(BuildContext context, bool focused) builder;

  const _PurchaseOrderKeyboardGridAction({
    required this.onActivate,
    required this.builder,
  });

  @override
  State<_PurchaseOrderKeyboardGridAction> createState() =>
      _PurchaseOrderKeyboardGridActionState();
}

class _PurchaseOrderKeyboardGridActionState
    extends State<_PurchaseOrderKeyboardGridAction> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (value) {
        if (_focused == value) return;
        setState(() => _focused = value);
      },
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.contextMenu): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.f10): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onActivate();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onActivate,
        child: widget.builder(context, _focused),
      ),
    );
  }
}

class _PurchaseOrderActionMenuLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PurchaseOrderActionMenuLabel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: const Color(0xFF17324A)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF17324A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5A7287),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PurchaseOrderRowCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final double estimatedTotal;
  final double? actualTotal;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  final Future<void> Function(BuildContext buttonContext) onOpenActions;

  const _PurchaseOrderRowCard({
    super.key,
    required this.order,
    required this.estimatedTotal,
    required this.actualTotal,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
    required this.onSecondaryTapDown,
    required this.onOpenActions,
  });

  @override
  Widget build(BuildContext context) {
    final status = (order['status'] ?? 'draft').toString();
    final linkedOtId = (order['linked_ot_id'] ?? '').toString().trim();
    final linkedOtFolio = (order['linked_ot_folio'] ?? '').toString().trim();
    final linkedOtStatus = normalizeMaintenanceStatus(
      order['linked_ot_status'],
    );
    final linkedOtStatusLabel = linkedOtStatus.isEmpty
        ? ''
        : maintenanceStatusShortLabel(linkedOtStatus);
    final conceptLabel =
        (order['linked_material_label'] ?? '').toString().trim().isNotEmpty
        ? (order['linked_material_label'] ?? '').toString().trim()
        : (order['quote_vendor_name'] ?? 'Sin nombre').toString().trim();
    final highlightOtCotizacion =
        linkedOtId.isNotEmpty && linkedOtStatus == 'cotizacion';
    final requestLabel = switch (status) {
      'authorized' => 'Pendiente de compra física',
      'purchased' => 'Compra verificada',
      'pending_direction' => 'Pendiente de Dirección',
      'rejected' => 'Requiere corrección',
      _ => 'Lista para captura',
    };
    final cardColor = selected
        ? const Color(0xFFD9ECFA)
        : highlightOtCotizacion
        ? const Color(0xFFFFE4E4).withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.86);
    final borderColor = selected
        ? const Color(0xFF3C8DCC).withValues(alpha: 0.55)
        : highlightOtCotizacion
        ? const Color(0xFFE2A4A4).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.35);
    final hoverColor = highlightOtCotizacion
        ? const Color(0xFFFFF0F0)
        : const Color(0xFFEFF7FD);

    return Card(
      elevation: selected ? 2.8 : 0.9,
      shadowColor: const Color(
        0xFF17324A,
      ).withValues(alpha: selected ? 0.18 : 0.08),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        mouseCursor: SystemMouseCursors.click,
        hoverColor: hoverColor,
        onTapDown: (_) => onTap(),
        onDoubleTap: onDoubleTap,
        onSecondaryTapDown: onSecondaryTapDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: ContractGridScaledRow(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: _kPoFolioColW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (order['folio'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF17324A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (order['requested_by_name'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5A7287),
                        ),
                      ),
                    ],
                  ),
                ),
                const _PurchaseOrderGridColumnDivider(),
                SizedBox(
                  width: _kPoDateColW,
                  child: Text(
                    _fmtDateLabel(
                      _dateFromAny(order['order_date']) ?? DateTime.now(),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const _PurchaseOrderGridColumnDivider(),
                SizedBox(
                  width: _kPoTargetColW,
                  child: Text(
                    (order['target_label'] ?? '').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const _PurchaseOrderGridColumnDivider(),
                SizedBox(
                  width: _kPoOtColW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        linkedOtFolio.isEmpty ? 'Sin OT' : linkedOtFolio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: linkedOtFolio.isEmpty
                              ? const Color(0xFF5A7287)
                              : const Color(0xFF17324A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        linkedOtStatusLabel.isEmpty
                            ? 'Sin relacion'
                            : linkedOtStatusLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: highlightOtCotizacion
                              ? const Color(0xFF9A2B2B)
                              : const Color(0xFF5A7287),
                          fontWeight: highlightOtCotizacion
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const _PurchaseOrderGridColumnDivider(),
                SizedBox(
                  width: _kPoVendorColW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conceptLabel.isEmpty ? 'Sin nombre' : conceptLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        linkedOtId.isNotEmpty
                            ? ((order['quote_vendor_name'] ?? '')
                                      .toString()
                                      .trim()
                                      .isEmpty
                                  ? 'Ligada a OT'
                                  : (order['quote_vendor_name'] ?? '')
                                        .toString()
                                        .trim())
                            : (order['quote_vendor_type'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5A7287),
                        ),
                      ),
                    ],
                  ),
                ),
                const _PurchaseOrderGridColumnDivider(),
                SizedBox(
                  width: _kPoStatusColW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusPill(
                        label: _kPurchaseOrderStatusLabel[status] ?? status,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        requestLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5A7287),
                        ),
                      ),
                    ],
                  ),
                ),
                const _PurchaseOrderGridColumnDivider(),
                SizedBox(
                  width: _kPoCashColW,
                  child: Builder(
                    builder: (_) {
                      final sentToCashAt = _dateFromAny(
                        order['sent_to_cash_at'],
                      );
                      final purchased = status == 'purchased';
                      final sentToCash = sentToCashAt != null;
                      final label = purchased
                          ? 'Atendida'
                          : sentToCash
                          ? _fmtDateLabel(sentToCashAt)
                          : 'Pendiente';
                      final color = purchased
                          ? const Color(0xFF1F4C8F)
                          : sentToCash
                          ? const Color(0xFF146356)
                          : const Color(0xFF7C5A00);
                      final subtitle = purchased
                          ? 'Compra ya registrada'
                          : sentToCash
                          ? 'Mandada a caja'
                          : 'Sin pasar a caja';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF5A7287),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const _PurchaseOrderGridColumnDivider(),
                SizedBox(
                  width: _kPoPurchaseColW,
                  child: Builder(
                    builder: (_) {
                      final purchasedAt = _dateFromAny(order['purchased_at']);
                      final purchased = status == 'purchased';
                      final label = purchased
                          ? (purchasedAt == null
                                ? 'Comprada'
                                : _fmtDateLabel(purchasedAt))
                          : 'Pendiente';
                      final color = purchased
                          ? const Color(0xFF1F4C8F)
                          : const Color(0xFF7C5A00);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            purchased ? 'Compra física hecha' : 'Por comprar',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF5A7287),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const _PurchaseOrderGridColumnDivider(),
                SizedBox(
                  width: _kPoEstimatedTotalColW,
                  child: Text(
                    _fmtMoney(estimatedTotal),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF17324A),
                    ),
                  ),
                ),
                const _PurchaseOrderGridColumnDivider(),
                SizedBox(
                  width: _kPoActualTotalColW,
                  child: Text(
                    actualTotal == null ? 'Pendiente' : _fmtMoney(actualTotal!),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF17324A),
                    ),
                  ),
                ),
                const _PurchaseOrderGridColumnDivider(),
                AnchoredActionSlot(
                  width: _kPoActionsColW,
                  trailingWidth: _kPoActionsColW,
                  leading: const SizedBox.shrink(),
                  trailing: Builder(
                    builder: (buttonContext) {
                      return IconButton(
                        tooltip: 'Acciones',
                        onPressed: () => onOpenActions(buttonContext),
                        icon: const Icon(Icons.more_horiz_rounded),
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
  }
}

class _PurchaseOrderMarqueeSelectionPainter extends CustomPainter {
  final Rect rect;

  const _PurchaseOrderMarqueeSelectionPainter({required this.rect});

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
  bool shouldRepaint(
    covariant _PurchaseOrderMarqueeSelectionPainter oldDelegate,
  ) => oldDelegate.rect != rect;
}

class _PurchaseOrderGridColumnDivider extends StatelessWidget {
  const _PurchaseOrderGridColumnDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(width: 1, height: 34, color: const Color(0xFFBFD5E3)),
    );
  }
}

class _OrderLineCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> line;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  final Future<void> Function(BuildContext buttonContext) onOpenActions;

  const _OrderLineCard({
    super.key,
    required this.index,
    required this.line,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
    required this.onSecondaryTapDown,
    required this.onOpenActions,
  });

  @override
  Widget build(BuildContext context) {
    final qty = _toDouble(line['qty']) ?? 0;
    final amount = _toDouble(line['amount']) ?? 0;
    final total = (_toDouble(line['line_total']) ?? 0) > 0
        ? (_toDouble(line['line_total']) ?? 0)
        : qty * amount;
    final notes = (line['notes'] ?? '').toString().trim();
    final lineType =
        _kPurchaseOrderLineTypeLabel[(line['line_type'] ?? 'material')
            .toString()] ??
        'Concepto';
    final qtyLabel = qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 3);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: selected ? 2.2 : 0.3,
      color: selected
          ? const Color(0xFFDFF0FB)
          : Colors.white.withValues(alpha: 0.86),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? const Color(0xFF3C8DCC).withValues(alpha: 0.5)
              : const Color(0xFFD8E8E5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onSecondaryTapDown: onSecondaryTapDown,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F1F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF35526A),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$lineType · ${(line['description'] ?? '').toString()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF17324A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Cantidad: $qtyLabel ${(line['unit'] ?? '').toString()}',
                        ),
                        Text('Monto: ${_fmtMoney(amount)}'),
                        Text(
                          'Total: ${_fmtMoney(total)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notes,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5A7287),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnchoredActionSlot(
                width: 128,
                trailingWidth: 128,
                leading: const SizedBox.shrink(),
                trailing: Builder(
                  builder: (buttonContext) {
                    return IconButton(
                      onPressed: () => onOpenActions(buttonContext),
                      tooltip: 'Acciones del renglón',
                      icon: const Icon(Icons.more_horiz_rounded),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseOrderDraft {
  final DateTime orderDate;
  final String targetLabel;
  final String linkedOtId;
  final String linkedOtFolio;
  final String providerType;
  final String vendorName;
  final String contact;
  final String notes;
  final List<Map<String, dynamic>> lines;

  const _PurchaseOrderDraft({
    required this.orderDate,
    required this.targetLabel,
    required this.linkedOtId,
    required this.linkedOtFolio,
    required this.providerType,
    required this.vendorName,
    required this.contact,
    required this.notes,
    required this.lines,
  });
}

class _PurchaseOrderDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final List<String> targetOptions;
  final List<Map<String, dynamic>> directoryContacts;
  final List<Map<String, dynamic>> maintenanceOrders;
  final List<Map<String, dynamic>> initialLines;
  final Future<Map<String, dynamic>?> Function({Map<String, dynamic>? initial})
  onShowLineDialog;

  const _PurchaseOrderDialog({
    required this.initial,
    required this.targetOptions,
    required this.directoryContacts,
    required this.maintenanceOrders,
    required this.initialLines,
    required this.onShowLineDialog,
  });

  @override
  State<_PurchaseOrderDialog> createState() => _PurchaseOrderDialogState();
}

class _PurchaseOrderDialogState extends State<_PurchaseOrderDialog> {
  final FocusNode _linesFocusNode = FocusNode(
    debugLabel: 'purchase-order-dialog-lines',
  );
  final Map<int, GlobalKey> _lineKeys = <int, GlobalKey>{};
  late DateTime _date;
  String? _target;
  late String _linkedOtId;
  late String _linkedOtFolio;
  late String _providerType;
  String _selectedDirectoryContactId = '';
  late final TextEditingController _vendorNameC;
  late final TextEditingController _contactC;
  late final TextEditingController _notesC;
  late List<Map<String, dynamic>> _lines;
  int? _selectedLineIndex;
  late final bool _linkedOtLocked;

  @override
  void initState() {
    super.initState();
    _date = _dateFromAny(widget.initial?['order_date']) ?? DateTime.now();
    final targetValue = (widget.initial?['target_label'] ?? '')
        .toString()
        .trim();
    _target = targetValue.isEmpty ? null : targetValue;
    _linkedOtId = (widget.initial?['linked_ot_id'] ?? '').toString().trim();
    _linkedOtFolio = (widget.initial?['linked_ot_folio'] ?? '')
        .toString()
        .trim();
    _linkedOtLocked =
        widget.initial?['generated_from_ot'] == true || _linkedOtId.isNotEmpty;
    final provider = (widget.initial?['quote_vendor_type'] ?? 'Empresa')
        .toString();
    _providerType = _kPurchaseOrderProviderTypes.contains(provider)
        ? provider
        : _kPurchaseOrderProviderTypes.first;
    _vendorNameC = TextEditingController(
      text: (widget.initial?['quote_vendor_name'] ?? '').toString(),
    );
    _contactC = TextEditingController(
      text: (widget.initial?['quote_contact'] ?? '').toString(),
    );
    _notesC = TextEditingController(
      text: (widget.initial?['notes'] ?? '').toString(),
    );
    _selectedDirectoryContactId = _findInitialDirectoryContactId();
    _lines = List<Map<String, dynamic>>.from(
      widget.initialLines.map((row) => Map<String, dynamic>.from(row)),
    );
  }

  bool get _canEditLinkedOt => !_linkedOtLocked;

  Map<String, dynamic>? get _selectedMaintenanceOrder {
    if (_linkedOtId.isEmpty) return null;
    return widget.maintenanceOrders.cast<Map<String, dynamic>?>().firstWhere(
      (row) => (row?['id'] ?? '').toString() == _linkedOtId,
      orElse: () => null,
    );
  }

  String get _linkedOtDisplayLabel {
    final selected = _selectedMaintenanceOrder;
    if (selected != null) return _maintenanceOrderDialogLabel(selected);
    if (_linkedOtFolio.isNotEmpty) return _linkedOtFolio;
    return 'Sin OT ligada';
  }

  @override
  void dispose() {
    _linesFocusNode.dispose();
    _vendorNameC.dispose();
    _contactC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  double get _total =>
      _lines.fold<double>(0, (sum, row) => sum + _dialogLineTotal(row));

  double _dialogLineTotal(Map<String, dynamic> row) {
    final explicit = _toDouble(row['line_total']);
    if (explicit != null && explicit > 0) return explicit;
    final qty = _toDouble(row['qty']) ?? 0;
    final amount = _toDouble(row['amount']) ?? 0;
    return qty * amount;
  }

  String _findInitialDirectoryContactId() {
    final vendorName = _vendorNameC.text.trim().toLowerCase();
    if (vendorName.isEmpty) return '';
    for (final row in widget.directoryContacts) {
      final name = (row['name'] ?? '').toString().trim().toLowerCase();
      if (name == vendorName) return (row['id'] ?? '').toString();
    }
    return '';
  }

  void _applyDirectoryContact(String contactId) {
    setState(() {
      _selectedDirectoryContactId = contactId;
      final selected = widget.directoryContacts
          .cast<Map<String, dynamic>?>()
          .firstWhere(
            (row) => (row?['id'] ?? '').toString() == contactId,
            orElse: () => null,
          );
      if (selected == null) return;
      _vendorNameC.text = (selected['name'] ?? '').toString();
      final contact = (selected['contact'] ?? '').toString().trim();
      if (contact.isNotEmpty) {
        _contactC.text = contact;
      }
    });
  }

  void _applyMaintenanceOrder(String maintenanceOrderId) {
    setState(() {
      _linkedOtId = maintenanceOrderId.trim();
      final row = _selectedMaintenanceOrder;
      _linkedOtFolio = (row?['ot_folio'] ?? '').toString().trim();
      if ((_target ?? '').trim().isEmpty) {
        final suggestedTarget = _maintenanceOrderTargetLabel(row);
        if (suggestedTarget.isNotEmpty) {
          _target = suggestedTarget;
        }
      }
    });
  }

  bool _isEditableFocused() {
    final focused = FocusManager.instance.primaryFocus;
    final widget = focused?.context?.widget;
    return widget is EditableText;
  }

  GlobalKey _lineKeyFor(int index) => _lineKeys.putIfAbsent(
    index,
    () => GlobalKey(debugLabel: 'po-line-$index'),
  );

  void _ensureLineVisible(int index, {int? moveDelta}) {
    final rowContext = _lineKeys[index]?.currentContext;
    final alignmentPolicy = moveDelta == null
        ? ScrollPositionAlignmentPolicy.explicit
        : moveDelta < 0
        ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
        : ScrollPositionAlignmentPolicy.keepVisibleAtEnd;
    if (rowContext == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final context = _lineKeys[index]?.currentContext;
        if (context == null) return;
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          alignmentPolicy: alignmentPolicy,
        );
      });
      return;
    }
    Scrollable.ensureVisible(
      rowContext,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      alignmentPolicy: alignmentPolicy,
    );
  }

  void _selectLine(int index, {bool requestFocus = true, int? moveDelta}) {
    if (index < 0 || index >= _lines.length) return;
    setState(() => _selectedLineIndex = index);
    if (requestFocus) _linesFocusNode.requestFocus();
    _ensureLineVisible(index, moveDelta: moveDelta);
  }

  void _moveLineSelection(int delta) {
    if (_lines.isEmpty) return;
    final current = _selectedLineIndex ?? 0;
    final next = (current + delta).clamp(0, _lines.length - 1);
    _selectLine(next, moveDelta: delta);
  }

  KeyEventResult _handleLinesKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isEditableFocused()) return KeyEventResult.ignored;
    if (_lines.isEmpty) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveLineSelection(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveLineSelection(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final index = _selectedLineIndex ?? 0;
      unawaited(_editLine(index));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f2) {
      final index = _selectedLineIndex ?? 0;
      unawaited(_editLine(index));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.contextMenu ||
        key == LogicalKeyboardKey.f10) {
      unawaited(_openSelectedLineActionsMenu());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      final index = _selectedLineIndex ?? 0;
      _deleteLine(index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && _selectedLineIndex != null) {
      setState(() => _selectedLineIndex = null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _addLine() async {
    final newLine = await widget.onShowLineDialog();
    if (newLine == null || !mounted) return;
    setState(() {
      _lines = [..._lines, newLine];
      _selectedLineIndex = _lines.length - 1;
    });
    _linesFocusNode.requestFocus();
    _ensureLineVisible(_lines.length - 1);
  }

  Future<void> _editLine(int index) async {
    final edited = await widget.onShowLineDialog(initial: _lines[index]);
    if (edited == null || !mounted) return;
    final copy = List<Map<String, dynamic>>.from(_lines);
    copy[index] = edited;
    setState(() {
      _lines = copy;
      _selectedLineIndex = index;
    });
  }

  void _deleteLine(int index) {
    final copy = List<Map<String, dynamic>>.from(_lines);
    copy.removeAt(index);
    final nextSelected = copy.isEmpty
        ? null
        : (_selectedLineIndex == null
              ? index.clamp(0, copy.length - 1)
              : _selectedLineIndex == index
              ? index.clamp(0, copy.length - 1)
              : _selectedLineIndex! > index
              ? _selectedLineIndex! - 1
              : _selectedLineIndex);
    setState(() {
      _lines = copy;
      _selectedLineIndex = nextSelected;
    });
    if (nextSelected != null) {
      _linesFocusNode.requestFocus();
      _ensureLineVisible(nextSelected);
    }
  }

  Future<void> _openSelectedLineActionsMenu() async {
    final index = _selectedLineIndex;
    if (index == null || index < 0 || index >= _lines.length) return;
    await _showLineActionsMenu(
      index,
      anchorContext: _lineKeys[index]?.currentContext,
    );
  }

  Future<void> _showLineActionsMenu(
    int index, {
    Offset? globalPosition,
    BuildContext? anchorContext,
  }) async {
    if (index < 0 || index >= _lines.length) return;
    setState(() => _selectedLineIndex = index);
    _linesFocusNode.requestFocus();
    final overlay = Overlay.of(context).context.findRenderObject();
    RelativeRect position = const RelativeRect.fromLTRB(0, 0, 0, 0);
    if (globalPosition != null && overlay is RenderBox) {
      position = RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      );
    } else if (anchorContext != null && overlay is RenderBox) {
      final box = anchorContext.findRenderObject();
      if (box is RenderBox) {
        final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
        position = RelativeRect.fromRect(
          Rect.fromLTWH(
            origin.dx,
            origin.dy + box.size.height,
            box.size.width,
            0,
          ),
          Offset.zero & overlay.size,
        );
      }
    }
    final action = await showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFFF6FBF9),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'edit',
          child: Text('Editar', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(
            'Eliminar',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        await _editLine(index);
        break;
      case 'delete':
        _deleteLine(index);
        break;
    }
  }

  void _submit() {
    Navigator.of(context).pop(
      _PurchaseOrderDraft(
        orderDate: _date,
        targetLabel: (_target ?? '').trim(),
        linkedOtId: _linkedOtId.trim(),
        linkedOtFolio: _linkedOtFolio.trim(),
        providerType: _providerType,
        vendorName: _vendorNameC.text.trim(),
        contact: _contactC.text.trim(),
        notes: _notesC.text.trim(),
        lines: List<Map<String, dynamic>>.from(_lines),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folio = (widget.initial?['folio'] ?? '').toString().trim();
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    widget.initial == null
                        ? 'Nueva orden de compra'
                        : 'Editar orden de compra',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF17324A),
                    ),
                  ),
                  if (folio.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F1F8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        folio,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF35526A),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF0FBF8), Color(0xFFE8F4FB)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFB7D7D2)),
                ),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Total: ${_fmtMoney(_total)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF17324A),
                      ),
                    ),
                    Text(
                      '${_lines.length} renglones',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF35526A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PurchaseOrderDialogSection(
                        title: 'Datos generales',
                        child: Column(
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: 190,
                                  child: _DateFieldButton(
                                    label: 'Fecha',
                                    value: _date,
                                    onChanged: (picked) {
                                      if (picked == null) return;
                                      setState(() => _date = picked);
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 260,
                                  child: _PurchaseOrderSelectField<String>(
                                    label: 'Unidad o área',
                                    value: _target ?? '',
                                    displayValue: (_target ?? '').isEmpty
                                        ? 'Seleccionar'
                                        : _target!,
                                    options: widget.targetOptions
                                        .map(
                                          (value) => _PurchaseOrderPickerOption(
                                            value: value,
                                            label: value,
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) =>
                                        setState(() => _target = value),
                                  ),
                                ),
                                SizedBox(
                                  width: 220,
                                  child: _PurchaseOrderSelectField<String>(
                                    label: 'Cotización con',
                                    value: _providerType,
                                    displayValue: _providerType,
                                    options: _kPurchaseOrderProviderTypes
                                        .map(
                                          (value) => _PurchaseOrderPickerOption(
                                            value: value,
                                            label: value,
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() => _providerType = value);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_canEditLinkedOt)
                              SizedBox(
                                width: double.infinity,
                                child: _PurchaseOrderSelectField<String>(
                                  label: 'OT ligada',
                                  value: _linkedOtId,
                                  displayValue: _linkedOtId.isEmpty
                                      ? 'Sin OT ligada'
                                      : _linkedOtDisplayLabel,
                                  options: [
                                    const _PurchaseOrderPickerOption(
                                      value: '',
                                      label: 'Sin OT ligada',
                                    ),
                                    ...widget.maintenanceOrders.map(
                                      (row) =>
                                          _PurchaseOrderPickerOption<String>(
                                            value: (row['id'] ?? '').toString(),
                                            label: _maintenanceOrderDialogLabel(
                                              row,
                                            ),
                                          ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value.trim().isEmpty) {
                                      setState(() {
                                        _linkedOtId = '';
                                        _linkedOtFolio = '';
                                      });
                                      return;
                                    }
                                    _applyMaintenanceOrder(value);
                                  },
                                ),
                              )
                            else
                              InputDecorator(
                                decoration: _poInputDecoration(
                                  labelText: 'OT ligada',
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _linkedOtId.isEmpty
                                          ? 'Sin OT ligada'
                                          : _linkedOtDisplayLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (_linkedOtId.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      const Text(
                                        'En esta etapa la OT ligada se conserva para no perder la relación histórica.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF5A7287),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            if (widget.directoryContacts.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _PurchaseOrderSelectField<String>(
                                label: 'Proveedor del directorio',
                                value: _selectedDirectoryContactId,
                                displayValue:
                                    _selectedDirectoryContactId.isEmpty
                                    ? 'Seleccionar'
                                    : widget.directoryContacts
                                              .cast<Map<String, dynamic>?>()
                                              .firstWhere(
                                                (row) =>
                                                    (row?['id'] ?? '')
                                                        .toString() ==
                                                    _selectedDirectoryContactId,
                                                orElse: () => null,
                                              )?['name']
                                              ?.toString() ??
                                          'Seleccionar',
                                options: [
                                  const _PurchaseOrderPickerOption(
                                    value: '',
                                    label: 'Sin seleccionar',
                                  ),
                                  ...widget.directoryContacts.map(
                                    (row) => _PurchaseOrderPickerOption<String>(
                                      value: (row['id'] ?? '').toString(),
                                      label:
                                          '${(row['name'] ?? '').toString()}${(row['contact'] ?? '').toString().trim().isEmpty ? '' : ' · ${(row['contact'] ?? '').toString()}'}',
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value.isEmpty) {
                                    setState(
                                      () => _selectedDirectoryContactId = '',
                                    );
                                    return;
                                  }
                                  _applyDirectoryContact(value);
                                },
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextField(
                              controller: _vendorNameC,
                              decoration: _poInputDecoration(
                                labelText:
                                    'Empresa, tienda, mecánico o proveedor',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _contactC,
                              decoration: _poInputDecoration(
                                labelText: 'Contacto',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _notesC,
                              minLines: 2,
                              maxLines: 3,
                              decoration: _poInputDecoration(
                                labelText: 'Notas generales',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _PurchaseOrderDialogSection(
                        title: 'Renglones de la orden',
                        trailing: FilledButton.icon(
                          onPressed: _addLine,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Agregar renglón'),
                        ),
                        child: Focus(
                          focusNode: _linesFocusNode,
                          onKeyEvent: (_, event) => _handleLinesKeyEvent(event),
                          child: _lines.isEmpty
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.86),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFD8E8E5),
                                    ),
                                  ),
                                  child: const Text(
                                    'Agrega materiales, mano de obra o refacciones.',
                                  ),
                                )
                              : Column(
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'ArrowUp/ArrowDown selecciona, Enter/F2 edita, Space abre acciones, Delete elimina.',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF5A7287),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    for (
                                      var index = 0;
                                      index < _lines.length;
                                      index++
                                    )
                                      _OrderLineCard(
                                        key: _lineKeyFor(index),
                                        index: index,
                                        line: _lines[index],
                                        selected: _selectedLineIndex == index,
                                        onTap: () => _selectLine(index),
                                        onDoubleTap: () => _editLine(index),
                                        onSecondaryTapDown: (details) {
                                          unawaited(
                                            _showLineActionsMenu(
                                              index,
                                              globalPosition:
                                                  details.globalPosition,
                                            ),
                                          );
                                        },
                                        onOpenActions: (buttonContext) =>
                                            _showLineActionsMenu(
                                              index,
                                              anchorContext: buttonContext,
                                            ),
                                      ),
                                  ],
                                ),
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
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _submit,
                    child: Text(
                      widget.initial == null ? 'Crear orden' : 'Guardar',
                    ),
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

class _PurchaseOrderDialogSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _PurchaseOrderDialogSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF17324A),
                  ),
                ),
              ),
              ...(trailing == null ? const <Widget>[] : <Widget>[trailing!]),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PurchaseOrderSummaryDialog extends StatelessWidget {
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> lines;
  final double estimatedTotal;
  final double? actualTotal;

  const _PurchaseOrderSummaryDialog({
    required this.order,
    required this.lines,
    required this.estimatedTotal,
    required this.actualTotal,
  });

  @override
  Widget build(BuildContext context) {
    final folio = (order['folio'] ?? '').toString().trim();
    final target = (order['target_label'] ?? '').toString().trim();
    final linkedOtFolio = (order['linked_ot_folio'] ?? '').toString().trim();
    final vendor = (order['quote_vendor_name'] ?? '').toString().trim();
    final contact = (order['quote_contact'] ?? '').toString().trim();
    final notes = (order['notes'] ?? '').toString().trim();
    final date = _dateFromAny(order['order_date']);
    return ContractDialogShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Resumen de orden de compra',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF17324A),
                    ),
                  ),
                  if (folio.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F1F8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        folio,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF35526A),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF0FBF8), Color(0xFFE8F4FB)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFB7D7D2)),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    Text(
                      'Estimado: ${_fmtMoney(estimatedTotal)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF17324A),
                      ),
                    ),
                    Text(
                      'Real: ${actualTotal == null ? 'Pendiente' : _fmtMoney(actualTotal!)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF35526A),
                      ),
                    ),
                    Text(
                      '${lines.length} renglones',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF35526A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PurchaseOrderDialogSection(
                        title: 'Datos generales',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 14,
                              runSpacing: 10,
                              children: [
                                _SummaryField(
                                  label: 'Fecha',
                                  value: date == null
                                      ? '-'
                                      : _fmtDateLabel(date),
                                ),
                                _SummaryField(
                                  label: 'Unidad o área',
                                  value: target.isEmpty ? '-' : target,
                                ),
                                _SummaryField(
                                  label: 'ID OT',
                                  value: linkedOtFolio.isEmpty
                                      ? '-'
                                      : linkedOtFolio,
                                ),
                                _SummaryField(
                                  label: 'Proveedor',
                                  value: vendor.isEmpty ? '-' : vendor,
                                ),
                                _SummaryField(
                                  label: 'Contacto',
                                  value: contact.isEmpty ? '-' : contact,
                                ),
                              ],
                            ),
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _SummaryField(label: 'Notas', value: notes),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _PurchaseOrderDialogSection(
                        title: 'Renglones de la orden',
                        child: lines.isEmpty
                            ? const Text('Sin renglones.')
                            : Column(
                                children: [
                                  for (
                                    var index = 0;
                                    index < lines.length;
                                    index++
                                  )
                                    _PurchaseOrderSummaryLineCard(
                                      index: index,
                                      line: lines[index],
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
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
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

class _SummaryField extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 170, maxWidth: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF5A7287),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF17324A),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseOrderSummaryLineCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> line;

  const _PurchaseOrderSummaryLineCard({
    required this.index,
    required this.line,
  });

  @override
  Widget build(BuildContext context) {
    final qty = _toDouble(line['qty']) ?? 0;
    final amount = _toDouble(line['amount']) ?? 0;
    final total = (_toDouble(line['line_total']) ?? 0) > 0
        ? (_toDouble(line['line_total']) ?? 0)
        : qty * amount;
    final notes = (line['notes'] ?? '').toString().trim();
    final lineType =
        _kPurchaseOrderLineTypeLabel[(line['line_type'] ?? 'material')
            .toString()] ??
        'Concepto';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E8E5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F1F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF35526A),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$lineType · ${(line['description'] ?? '').toString()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17324A),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Cantidad: ${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 3)} ${(line['unit'] ?? '').toString()}',
                    ),
                    Text('Monto: ${_fmtMoney(amount)}'),
                    Text(
                      'Total: ${_fmtMoney(total)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notes,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5A7287),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseOrderActualTotalDialog extends StatefulWidget {
  final String folio;
  final double estimatedTotal;
  final double? initialActualTotal;

  const _PurchaseOrderActualTotalDialog({
    required this.folio,
    required this.estimatedTotal,
    required this.initialActualTotal,
  });

  @override
  State<_PurchaseOrderActualTotalDialog> createState() =>
      _PurchaseOrderActualTotalDialogState();
}

class _PurchaseOrderActualTotalDialogState
    extends State<_PurchaseOrderActualTotalDialog> {
  late final TextEditingController _actualTotalC;

  @override
  void initState() {
    super.initState();
    _actualTotalC = TextEditingController(
      text: widget.initialActualTotal?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _actualTotalC.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _toDouble(_actualTotalC.text);
    if (value == null || value <= 0) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return ContractDialogShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Capturar total real',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF17324A),
                ),
              ),
              const SizedBox(height: 10),
              if (widget.folio.trim().isNotEmpty)
                Text(
                  widget.folio,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF35526A),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                'Total estimado: ${_fmtMoney(widget.estimatedTotal)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF35526A),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _actualTotalC,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _poInputDecoration(labelText: 'Total real'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 10),
              const Text(
                'Este total real será el gasto final de la compra, sin reabrir la cotización autorizada.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5A7287),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Guardar'),
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

class _PurchaseOrderCommentDialog extends StatefulWidget {
  final String title;
  final String label;

  const _PurchaseOrderCommentDialog({required this.title, required this.label});

  @override
  State<_PurchaseOrderCommentDialog> createState() =>
      _PurchaseOrderCommentDialogState();
}

class _PurchaseOrderCommentDialogState
    extends State<_PurchaseOrderCommentDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContractDialogShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF17324A),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                decoration: _poInputDecoration(labelText: widget.label),
                onSubmitted: (_) =>
                    Navigator.pop(context, _controller.text.trim()),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, _controller.text.trim()),
                    child: const Text('Guardar'),
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

class _PurchaseOrderLineDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;

  const _PurchaseOrderLineDialog({this.initial});

  @override
  State<_PurchaseOrderLineDialog> createState() =>
      _PurchaseOrderLineDialogState();
}

class _PurchaseOrderLineDialogState extends State<_PurchaseOrderLineDialog> {
  late final TextEditingController _qtyC;
  late final TextEditingController _unitC;
  late final TextEditingController _descriptionC;
  late final TextEditingController _amountC;
  late final TextEditingController _notesC;
  late String _lineType;

  @override
  void initState() {
    super.initState();
    _qtyC = TextEditingController(
      text: (widget.initial?['qty'] ?? '').toString(),
    );
    _unitC = TextEditingController(
      text: (widget.initial?['unit'] ?? '').toString(),
    );
    _descriptionC = TextEditingController(
      text: (widget.initial?['description'] ?? '').toString(),
    );
    _amountC = TextEditingController(
      text: (widget.initial?['amount'] ?? '').toString(),
    );
    _notesC = TextEditingController(
      text: (widget.initial?['notes'] ?? '').toString(),
    );
    _lineType = (widget.initial?['line_type'] ?? 'material').toString();
  }

  @override
  void dispose() {
    _qtyC.dispose();
    _unitC.dispose();
    _descriptionC.dispose();
    _amountC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qty = _toDouble(_qtyC.text) ?? 0;
    final amount = _toDouble(_amountC.text) ?? 0;
    final total = qty * amount;

    return ContractDialogShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initial == null ? 'Nuevo renglón' : 'Editar renglón',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF17324A),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PurchaseOrderSelectField<String>(
                      label: 'Tipo',
                      value: _lineType,
                      displayValue:
                          _kPurchaseOrderLineTypeLabel[_lineType] ?? _lineType,
                      options: _kPurchaseOrderLineTypeLabel.entries
                          .map(
                            (entry) => _PurchaseOrderPickerOption(
                              value: entry.key,
                              label: entry.value,
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _lineType = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _qtyC,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _poInputDecoration(labelText: 'Cantidad'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _unitC,
                      decoration: _poInputDecoration(labelText: 'Unidad'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionC,
                minLines: 2,
                maxLines: 3,
                decoration: _poInputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountC,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _poInputDecoration(
                        labelText: 'Monto unitario',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InputDecorator(
                      decoration: _poInputDecoration(labelText: 'Total'),
                      child: Text(
                        _fmtMoney(total),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesC,
                minLines: 2,
                maxLines: 3,
                decoration: _poInputDecoration(labelText: 'Notas'),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () {
                      if (_descriptionC.text.trim().isEmpty) return;
                      Navigator.pop(context, {
                        'id': widget.initial?['id'],
                        'line_type': _lineType,
                        'qty': _toDouble(_qtyC.text),
                        'unit': _unitC.text.trim(),
                        'description': _descriptionC.text.trim(),
                        'amount': _toDouble(_amountC.text),
                        'line_total': total,
                        'notes': _notesC.text.trim(),
                      });
                    },
                    child: const Text('Guardar'),
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

class _DateFieldButton extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime?> onChanged;

  const _DateFieldButton({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: defaultDatePickerOpenDate(
            firstDate: DateTime(2024),
            lastDate: DateTime(2035),
          ),
          firstDate: DateTime(2024),
          lastDate: DateTime(2035),
          currentDate: defaultDatePickerOpenDate(
            firstDate: DateTime(2024),
            lastDate: DateTime(2035),
          ),
          locale: const Locale('es', 'MX'),
        );
        onChanged(picked);
      },
      child: InputDecorator(
        decoration: _poInputDecoration(labelText: label),
        child: Row(
          children: [
            Expanded(child: Text(_fmtDateLabel(value))),
            const Icon(Icons.calendar_month_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;

  const _StatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    Color background = const Color(0xFFE7EDF3);
    Color foreground = const Color(0xFF23425E);
    switch (label) {
      case 'Autorizada':
        background = const Color(0xFFDDF4EC);
        foreground = const Color(0xFF0D5C46);
        break;
      case 'Comprada':
        background = const Color(0xFFDDEBFF);
        foreground = const Color(0xFF1F4C8F);
        break;
      case 'Pendiente dirección':
        background = const Color(0xFFFFF0C7);
        foreground = const Color(0xFF7C5A00);
        break;
      case 'Rechazada':
        background = const Color(0xFFFFD9D5);
        foreground = const Color(0xFF8A1F1F);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w800, color: foreground),
      ),
    );
  }
}

class _SchemaWarningCard extends StatelessWidget {
  final String message;

  const _SchemaWarningCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9CA6B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF7A5A00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF7A5A00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _purchaseOrderFilterDialogDecoration() {
  return BoxDecoration(
    color: const Color(0xFFF4FAF8).withValues(alpha: 0.96),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

ButtonStyle _purchaseOrderFilterOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF2A4B49),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
    backgroundColor: Colors.white.withValues(alpha: 0.6),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontWeight: FontWeight.w700),
  );
}

ButtonStyle _purchaseOrderFilterFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF6C8E87),
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

InputDecoration _poInputDecoration({String? labelText, Widget? prefixIcon}) {
  return InputDecoration(
    labelText: labelText,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.9),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD8E8E5)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD8E8E5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF5AA890), width: 1.4),
    ),
  );
}

String _fmtDateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _fmtMoney(num value) => formatMoney(value);

String _maintenanceOrderTargetLabel(Map<String, dynamic>? row) {
  if (row == null) return '';
  final equipment = (row['equipment_label'] ?? '').toString().trim();
  if (equipment.isNotEmpty) return equipment;
  return (row['area_label'] ?? '').toString().trim();
}

String _maintenanceOrderDialogLabel(Map<String, dynamic>? row) {
  if (row == null) return 'Sin OT ligada';
  final folio = (row['ot_folio'] ?? '').toString().trim();
  final target = _maintenanceOrderTargetLabel(row);
  final status = maintenanceStatusShortLabel(row['status']);
  return [
    if (folio.isNotEmpty) folio,
    if (target.isNotEmpty) target,
    if (status.isNotEmpty) status,
  ].join(' · ');
}

bool _isMissingPurchaseOrdersSchemaError(PostgrestException error) {
  final message = error.message.toLowerCase();
  return message.contains('maintenance_purchase_orders') ||
      message.contains('maintenance_purchase_order_lines') ||
      message.contains('linked_ot_id') ||
      message.contains('linked_ot_folio') ||
      message.contains('linked_material_label') ||
      message.contains('generated_from_ot');
}

bool _isMissingPurchasedPurchaseOrderSchemaError(PostgrestException error) {
  final message = error.message.toLowerCase();
  return message.contains('purchased_at') ||
      message.contains('purchased_by') ||
      message.contains('purchased_by_name') ||
      message.contains('actual_total') ||
      message.contains('actual_total_by') ||
      message.contains('actual_total_by_name') ||
      message.contains('actual_total_at') ||
      message.contains('sent_to_cash_at') ||
      message.contains('sent_to_cash_by') ||
      message.contains('sent_to_cash_by_name') ||
      (message.contains('invalid input value for enum') &&
          message.contains('purchased'));
}

bool _isMissingOperationDirectoryContactsError(PostgrestException error) {
  return error.message.toLowerCase().contains('operation_directory_contacts');
}

String _fmtDbDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

DateTime? _dateFromAny(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  final value = raw.toString().trim();
  if (value.isEmpty) return null;
  return DateTime.tryParse(value);
}

double? _toDouble(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  final normalized = raw.toString().trim().replaceAll(',', '');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

String? _emptyAsNull(dynamic raw) {
  final value = (raw ?? '').toString().trim();
  return value.isEmpty ? null : value;
}

List<String> _splitPurchaseOrderValues(dynamic raw) {
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty) return const <String>[];
  return _normalizePurchaseOrderNames(text.split(RegExp(r'[,;/\n\r]+')));
}

List<String> _normalizePurchaseOrderNames(Iterable<String> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final raw in values) {
    final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) continue;
    final key = value.toLowerCase();
    if (!seen.add(key)) continue;
    normalized.add(value);
  }
  normalized.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return normalized;
}

bool _isMissingDirectoryTaxonomyError(PostgrestException error) {
  final message = error.message.toLowerCase();
  return message.contains('operation_directory_areas') ||
      message.contains('operation_directory_specialties') ||
      message.contains('operation_directory_contact_areas') ||
      message.contains('operation_directory_contact_specialties');
}
