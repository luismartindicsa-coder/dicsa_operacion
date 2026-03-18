import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kPrimaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const double _kInvActionsW = 150;
const double _kInvKgColW = 110;
const double _kInvGrossColW = 110;
const double _kInvTareColW = 110;
const double _kInvHumidityColW = 110;
const double _kInvTrashColW = 110;
const double _kInvAmountColW = 120;
const double _kInvCounterpartyColW = 220;
const double _kInvRefColW = 180;
const double _kInvNotesColW = 240;
const double _kInvTableContentW =
    90 +
    190 +
    _kInvCounterpartyColW +
    190 +
    140 +
    _kInvRefColW +
    _kInvGrossColW +
    _kInvTareColW +
    _kInvKgColW +
    _kInvHumidityColW +
    _kInvTrashColW +
    _kInvAmountColW +
    _kInvNotesColW +
    10 +
    _kInvActionsW;

const Color _kInvFilterAccent = Color(0xFF5D7F9E);
const Color _kInvFilterAccentSoft = Color(0xFFDCE7F2);

class InventoryGridTopBarData {
  final IconData metricIcon;
  final String metricLabel;
  final String metricValue;
  final String metricSubtitle;
  final bool exportingCsv;
  final bool gridEditMode;
  final bool canToggleGridEdit;
  final bool canDeleteSelection;
  final bool deletingSelection;
  final int selectedCount;
  final String? selectedKgSumLabel;
  final String? selectedKgAvgLabel;
  final String? activeCellLabel;
  final VoidCallback? onExportCsv;
  final VoidCallback? onToggleGridEdit;
  final VoidCallback? onSaveGridEdit;
  final VoidCallback? onCancelGridEdit;
  final Future<void> Function()? onDeleteSelection;

  const InventoryGridTopBarData({
    required this.metricIcon,
    required this.metricLabel,
    required this.metricValue,
    required this.metricSubtitle,
    required this.exportingCsv,
    required this.gridEditMode,
    required this.canToggleGridEdit,
    required this.canDeleteSelection,
    required this.deletingSelection,
    required this.selectedCount,
    this.selectedKgSumLabel,
    this.selectedKgAvgLabel,
    this.activeCellLabel,
    this.onExportCsv,
    this.onToggleGridEdit,
    this.onSaveGridEdit,
    this.onCancelGridEdit,
    this.onDeleteSelection,
  });
}

class InventoryGridTopBar extends StatelessWidget {
  final InventoryGridTopBarData data;
  final bool showActions;
  final bool showMetric;

  const InventoryGridTopBar({
    super.key,
    required this.data,
    this.showActions = true,
    this.showMetric = true,
  });

  @override
  Widget build(BuildContext context) {
    final actionButtons = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          style: _invActionFilledButtonStyle(),
          onPressed: data.exportingCsv ? null : data.onExportCsv,
          icon: const Icon(Icons.download_rounded),
          label: Text(data.exportingCsv ? 'Exportando...' : 'Descargar CSV'),
        ),
        if (data.onToggleGridEdit != null)
          OutlinedButton.icon(
            style: _invActionOutlinedButtonStyle(),
            onPressed: data.canToggleGridEdit ? data.onToggleGridEdit : null,
            icon: Icon(
              data.gridEditMode
                  ? Icons.grid_off_rounded
                  : Icons.edit_note_rounded,
            ),
            label: Text(
              data.gridEditMode ? 'Salir edición' : 'Edición cuadricula',
            ),
          ),
        if (data.gridEditMode &&
            data.onSaveGridEdit != null &&
            data.onCancelGridEdit != null) ...[
          FilledButton.icon(
            style: _invActionFilledButtonStyle(),
            onPressed: data.onSaveGridEdit,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar'),
          ),
          OutlinedButton.icon(
            style: _invActionOutlinedButtonStyle(),
            onPressed: data.onCancelGridEdit,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Cancelar'),
          ),
        ],
        if (data.canDeleteSelection)
          FilledButton.icon(
            style: _invActionFilledButtonStyle(),
            onPressed: data.deletingSelection || data.onDeleteSelection == null
                ? null
                : () => unawaited(data.onDeleteSelection!.call()),
            icon: const Icon(Icons.delete_outline),
            label: Text('Eliminar (${_fmtInvInt(data.selectedCount)})'),
          ),
      ],
    );

    final actionsPanel = _InvToolbarPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rightInfo = Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_fmtInvInt(data.selectedCount)} seleccionadas',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.right,
              ),
              if (data.selectedKgSumLabel != null ||
                  data.selectedKgAvgLabel != null)
                Text(
                  [
                    if (data.selectedKgSumLabel != null)
                      'Suma: ${data.selectedKgSumLabel}',
                    if (data.selectedKgAvgLabel != null)
                      'Prom: ${data.selectedKgAvgLabel}',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2A4B49),
                  ),
                  textAlign: TextAlign.right,
                ),
              if (data.activeCellLabel != null)
                Text(
                  'Celda: ${data.activeCellLabel} · Space',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2A4B49),
                  ),
                  textAlign: TextAlign.right,
                ),
            ],
          );

          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                actionButtons,
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: rightInfo),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: actionButtons),
              const SizedBox(width: 10),
              rightInfo,
            ],
          );
        },
      ),
    );

    final metricWidget = Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: _InvTopMetricCard(
          icon: data.metricIcon,
          label: data.metricLabel,
          value: data.metricValue,
          subtitle: data.metricSubtitle,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showActions) actionsPanel,
        if (showActions && showMetric) const SizedBox(height: 10),
        if (showMetric) metricWidget,
      ],
    );
  }
}

class InventoryMovementsGrid extends StatefulWidget {
  final String flow; // IN | OUT
  final Future<void> Function()? onChanged;
  final bool showTopBarChrome;
  final ValueChanged<InventoryGridTopBarData>? onTopBarChanged;

  const InventoryMovementsGrid({
    super.key,
    required this.flow,
    this.onChanged,
    this.showTopBarChrome = true,
    this.onTopBarChanged,
  });

  @override
  State<InventoryMovementsGrid> createState() => _InventoryMovementsGridState();
}

class _InventoryMovementsGridState extends State<InventoryMovementsGrid>
    with WidgetsBindingObserver {
  final supa = Supabase.instance.client;
  final FocusNode _insertFocusNode = FocusNode(
    debugLabel: 'inv_insert_row_focus',
  );
  final FocusNode _rowsFocusNode = FocusNode(debugLabel: 'inv_rows_focus');
  final FocusNode _insertGrossFocusNode = FocusNode(
    debugLabel: 'inv_insert_gross',
  );
  final FocusNode _insertTareFocusNode = FocusNode(
    debugLabel: 'inv_insert_tare',
  );
  final FocusNode _insertHumidityFocusNode = FocusNode(
    debugLabel: 'inv_insert_humidity',
  );
  final FocusNode _insertTrashFocusNode = FocusNode(
    debugLabel: 'inv_insert_trash',
  );
  final FocusNode _insertReferenceFocusNode = FocusNode(
    debugLabel: 'inv_insert_ref',
  );
  final FocusNode _insertNotesFocusNode = FocusNode(
    debugLabel: 'inv_insert_notes',
  );
  final ScrollController _rowsScrollController = ScrollController();
  final GlobalKey _rowsViewportKey = GlobalKey(debugLabel: 'inv_rows_viewport');
  final GlobalKey _insertRowKey = GlobalKey(debugLabel: 'inv_insert_row');

  final TextEditingController _draftWeightC = TextEditingController();
  final TextEditingController _draftGrossC = TextEditingController();
  final TextEditingController _draftTareC = TextEditingController();
  final TextEditingController _draftHumidityC = TextEditingController();
  final TextEditingController _draftTrashC = TextEditingController();
  final TextEditingController _draftReferenceC = TextEditingController();
  final TextEditingController _draftNotesC = TextEditingController();

  final Map<String, GlobalKey<_MovementDataRowState>> _rowKeys =
      <String, GlobalKey<_MovementDataRowState>>{};
  final Map<String, Set<String>> _columnValueFilters = <String, Set<String>>{};
  final Map<String, DateTimeRange> _columnDateRangeFilters =
      <String, DateTimeRange>{};

  Timer? _autoRefreshTimer;
  Timer? _deferredRefreshTimer;
  RealtimeChannel? _realtimeChannel;
  DateTime? _lastBackgroundRefreshAt;
  String _rowsSnapshotSignature = '';
  static const Duration _backgroundRefreshMinGap = Duration(seconds: 10);
  static const Duration _backgroundRefreshRetryDelay = Duration(seconds: 6);

  bool _loadingCats = true;
  bool _loadingRows = true;
  bool _refreshingRows = false;
  bool _pendingReload = false;
  bool _inserting = false;
  bool _bulkDeleting = false;
  bool _exportingCsv = false;
  bool _insertRowActive = false;
  bool _hoverInsertExtrasButton = false;
  bool _hoverInsertAddButton = false;
  bool _marqueeActive = false;
  Offset? _marqueeStartLocal;
  Offset? _marqueePointerLocal;
  Offset? _marqueeStartContent;
  Offset? _marqueeCurrentContent;
  bool _marqueeAdditive = false;
  Set<String> _marqueeBaseSelection = <String>{};
  Timer? _marqueeAutoScrollTimer;
  double _marqueeAutoScrollVelocity = 0;

  List<_InvOpt> _counterparties = [];
  List<_InvOpt> _drivers = [];
  List<_InvOpt> _vehicles = [];
  List<_InvMaterialOpt> _materials = [];
  List<_CommercialMaterialOpt> _commercialMaterials = [];
  List<Map<String, dynamic>> _rows = [];

  String? _selectedRowId;
  String? _selectionAnchorRowId;
  final Set<String> _bulkSelectedRowIds = <String>{};
  int _activeInsertColumn = 0;
  int _activeGridColumn = 0;
  int _currentPage = 0;
  int _pageSize = 40;
  bool _topBarSyncScheduled = false;

  static const int _insertColumnCount = 14;
  static const int _gridColumnCount = 14;
  static const List<String> _gridColumnLabels = <String>[
    'FECHA',
    'TICKET',
    'MATERIAL',
    'CONTRAPARTE',
    'CHOFER',
    'UNIDAD',
    'BRUTO KG',
    'TARA KG',
    'NETO KG',
    'HUMEDAD %',
    'BASURA KG',
    'IMPORTE KG',
    'COMENTARIO',
    'ACCIONES',
  ];

  late _MovementDraft _draft;

  bool get _isIn => widget.flow == 'IN';
  String get _counterpartyLabel => _isIn ? 'PROVEEDOR' : 'CLIENTE';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _insertFocusNode.addListener(_syncInsertRowFocusState);
    _insertGrossFocusNode.addListener(_syncInsertRowFocusState);
    _insertTareFocusNode.addListener(_syncInsertRowFocusState);
    _insertHumidityFocusNode.addListener(_syncInsertRowFocusState);
    _insertTrashFocusNode.addListener(_syncInsertRowFocusState);
    _insertReferenceFocusNode.addListener(_syncInsertRowFocusState);
    _insertNotesFocusNode.addListener(_syncInsertRowFocusState);
    _initDraftDefaults();
    _bootstrap();
    _setupAutoRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyTopBarChanged());
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _scheduleTopBarSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _deferredRefreshTimer?.cancel();
    _marqueeAutoScrollTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    _insertFocusNode.removeListener(_syncInsertRowFocusState);
    _insertGrossFocusNode.removeListener(_syncInsertRowFocusState);
    _insertTareFocusNode.removeListener(_syncInsertRowFocusState);
    _insertHumidityFocusNode.removeListener(_syncInsertRowFocusState);
    _insertTrashFocusNode.removeListener(_syncInsertRowFocusState);
    _insertReferenceFocusNode.removeListener(_syncInsertRowFocusState);
    _insertNotesFocusNode.removeListener(_syncInsertRowFocusState);
    _insertFocusNode.dispose();
    _rowsFocusNode.dispose();
    _insertGrossFocusNode.dispose();
    _insertTareFocusNode.dispose();
    _insertHumidityFocusNode.dispose();
    _insertTrashFocusNode.dispose();
    _insertReferenceFocusNode.dispose();
    _insertNotesFocusNode.dispose();
    _rowsScrollController.dispose();
    _draftWeightC.dispose();
    _draftGrossC.dispose();
    _draftTareC.dispose();
    _draftHumidityC.dispose();
    _draftTrashC.dispose();
    _draftReferenceC.dispose();
    _draftNotesC.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestReload(force: true);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _friendlyPostgrestMessage(
    PostgrestException error, {
    required String fallbackAction,
  }) {
    final message = error.message.trim();
    final details = (error.details ?? '').toString().trim();
    final hint = (error.hint ?? '').toString().trim();
    if (error.code == 'P0001' && message.isNotEmpty) {
      return message;
    }
    if (message.contains('Inventario insuficiente')) {
      return message;
    }
    if (message.contains('material_target_chk')) {
      return 'El movimiento no coincide con el nivel de inventario configurado.';
    }
    if (message.contains('weight_chk')) {
      return 'El peso capturado no es válido para este movimiento.';
    }
    if (message.contains('foreign key') ||
        message.contains('violates foreign key')) {
      return 'Hay un material, cliente, chofer o unidad inválidos en la captura.';
    }
    if (message.contains('duplicate') || message.contains('unique')) {
      return 'Ya existe un registro conflictivo con esos datos.';
    }
    final raw = <String>[
      message,
      details,
      hint,
    ].where((part) => part.isNotEmpty).join(' ');
    return raw.isEmpty ? fallbackAction : raw;
  }

  Future<void> _bootstrap() async {
    await _loadCatalogs();
    await _loadRows();
  }

  void _initDraftDefaults() {
    _draft = _MovementDraft(
      opDate: DateUtils.dateOnly(DateTime.now()),
      materialId: null,
      grossKg: null,
      tareKg: null,
      netKg: null,
      humidityPercent: null,
      trashKg: null,
      totalAmountKg: null,
      counterpartySiteId: null,
      driverEmployeeId: null,
      vehicleId: null,
      reference: '',
      notes: '',
      commercialMaterialCode: null,
      movementReason: null,
      scaleTicket: '',
    );
    _draftWeightC.clear();
    _draftGrossC.clear();
    _draftTareC.clear();
    _draftHumidityC.clear();
    _draftTrashC.clear();
    _draftReferenceC.clear();
    _draftNotesC.clear();
    _activeInsertColumn = 0;
  }

  void _syncInsertRowFocusState() {
    final next =
        _insertFocusNode.hasFocus ||
        _insertGrossFocusNode.hasFocus ||
        _insertTareFocusNode.hasFocus ||
        _insertHumidityFocusNode.hasFocus ||
        _insertTrashFocusNode.hasFocus ||
        _insertReferenceFocusNode.hasFocus ||
        _insertNotesFocusNode.hasFocus;
    if (_insertRowActive == next || !mounted) return;
    setState(() => _insertRowActive = next);
  }

  void _setupAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _requestReload();
    });

    _realtimeChannel?.unsubscribe();
    _realtimeChannel = supa
        .channel('inventory-movements-${widget.flow.toLowerCase()}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_movements_v2',
          callback: (_) => _requestReload(),
        )
        .subscribe();
  }

  bool get _hasDraftChanges =>
      _draftWeightC.text.trim().isNotEmpty ||
      _draftGrossC.text.trim().isNotEmpty ||
      _draftTareC.text.trim().isNotEmpty ||
      _draftHumidityC.text.trim().isNotEmpty ||
      _draftTrashC.text.trim().isNotEmpty ||
      _draftReferenceC.text.trim().isNotEmpty ||
      _draftNotesC.text.trim().isNotEmpty ||
      (_draft.scaleTicket.trim().isNotEmpty) ||
      _draft.counterpartySiteId != null ||
      _draft.driverEmployeeId != null ||
      _draft.vehicleId != null ||
      _draft.commercialMaterialCode != null ||
      _draft.movementReason != null;

  bool get _shouldDeferBackgroundReload =>
      _refreshingRows ||
      _loadingRows ||
      _inserting ||
      _bulkDeleting ||
      _insertRowActive ||
      (_selectedRowState()?.isEditing ?? false) ||
      _hasDraftChanges ||
      _isEditableTextFocused();

  String _rowsSignature(List<Map<String, dynamic>> rows) => jsonEncode(rows);

  void _queueDeferredReload([Duration? delay]) {
    if (!mounted) return;
    _pendingReload = true;
    _deferredRefreshTimer?.cancel();
    _deferredRefreshTimer = Timer(delay ?? _backgroundRefreshRetryDelay, () {
      _deferredRefreshTimer = null;
      _requestReload();
    });
  }

  void _requestReload({bool force = false}) {
    if (!mounted) return;
    if (!force && _shouldDeferBackgroundReload) {
      _queueDeferredReload();
      return;
    }
    if (!force && _lastBackgroundRefreshAt != null) {
      final elapsed = DateTime.now().difference(_lastBackgroundRefreshAt!);
      if (elapsed < _backgroundRefreshMinGap) {
        _queueDeferredReload(_backgroundRefreshMinGap - elapsed);
        return;
      }
    }
    if (_refreshingRows) {
      _queueDeferredReload();
      return;
    }
    unawaited(_refreshRowsIfIdle(force: force));
  }

  Future<void> _refreshRowsIfIdle({bool force = false}) async {
    if (!mounted || _refreshingRows) return;
    _refreshingRows = true;
    try {
      await _loadRows(showLoader: false, onlyApplyIfChanged: true);
      _lastBackgroundRefreshAt = DateTime.now();
    } finally {
      _refreshingRows = false;
      if (_pendingReload) {
        if (force || !_shouldDeferBackgroundReload) {
          _pendingReload = false;
          _requestReload();
        } else {
          _queueDeferredReload();
        }
      }
    }
  }

  Future<void> _loadCatalogs() async {
    if (mounted) setState(() => _loadingCats = true);
    try {
      final results = await Future.wait<dynamic>([
        supa
            .from('sites')
            .select('id,name,type')
            .eq('is_active', true)
            .order('name'),
        supa
            .from('employees')
            .select('id,full_name')
            .eq('is_driver', true)
            .eq('is_active', true)
            .order('full_name'),
        supa
            .from('vehicles')
            .select('id,code,status')
            .eq('status', 'activo')
            .order('code'),
        supa
            .from('material_commercial_catalog_v2')
            .select('id,code,name,family,general_material_id')
            .eq('is_active', true)
            .eq(_isIn ? 'allows_direct_entry' : 'allows_sale', true)
            .order('sort_order')
            .order('name'),
        supa
            .from('material_general_catalog_v2')
            .select('id,code,name')
            .eq('is_active', true)
            .order('sort_order')
            .order('name'),
      ]);
      final sites = (results[0] as List).cast<Map<String, dynamic>>();
      final drivers = (results[1] as List).cast<Map<String, dynamic>>();
      final vehicles = (results[2] as List).cast<Map<String, dynamic>>();
      final commercials = (results[3] as List).cast<Map<String, dynamic>>();
      final materialsCatalog = (results[4] as List)
          .cast<Map<String, dynamic>>();

      if (!mounted) return;
      setState(() {
        _counterparties = sites
            .map(
              (e) => _InvOpt(
                id: e['id'] as String,
                label: ((e['name'] ?? '') as String).trim(),
                type: (e['type'] ?? '').toString(),
              ),
            )
            .where((e) => e.label.isNotEmpty)
            .toList();
        _drivers = drivers
            .map(
              (e) => _InvOpt(
                id: e['id'] as String,
                label: ((e['full_name'] ?? '') as String).trim(),
              ),
            )
            .toList();
        _vehicles = vehicles
            .map(
              (e) => _InvOpt(
                id: e['id'] as String,
                label: ((e['code'] ?? '') as String).trim(),
              ),
            )
            .toList();
        _materials = materialsCatalog
            .map(
              (e) => _InvMaterialOpt(
                id: (e['id'] ?? '').toString(),
                name: ((e['name'] ?? '') as String).trim(),
                inventoryMaterialCode: e['code']?.toString(),
                inventoryGeneralCode: e['code']?.toString(),
              ),
            )
            .where((e) => e.id.isNotEmpty && e.name.isNotEmpty)
            .toList();
        _commercialMaterials = commercials
            .map(
              (e) => _CommercialMaterialOpt(
                id: (e['id'] ?? '').toString(),
                code: (e['code'] ?? '').toString(),
                name: (e['name'] ?? '').toString(),
                family: (e['family'] ?? '').toString(),
                inventoryMaterial: null,
                materialId: e['general_material_id']?.toString(),
              ),
            )
            .where(
              (e) => e.id.isNotEmpty && e.code.isNotEmpty && e.name.isNotEmpty,
            )
            .toList();
        if (!_materials.any((m) => m.id == _draft.materialId)) {
          _draft = _draft.copyWith(materialId: null);
        }
        _loadingCats = false;
      });
    } catch (e) {
      _toast('No se pudieron cargar catálogos: $e');
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  bool _isEditableTextFocused() {
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  Future<bool> _loadRows({
    bool showLoader = true,
    bool onlyApplyIfChanged = false,
  }) async {
    if (showLoader && mounted) {
      setState(() => _loadingRows = true);
    }

    try {
      final nextRows = await _loadRowsFromV2();
      final nextSignature = _rowsSignature(nextRows);
      if (onlyApplyIfChanged && nextSignature == _rowsSnapshotSignature) {
        if (showLoader && mounted) setState(() => _loadingRows = false);
        return false;
      }
      final ids = nextRows.map((r) => r['id'] as String).toSet();
      final visibleIds = nextRows
          .where((r) => _matchesFilters(r))
          .map((r) => r['id'] as String)
          .toSet();
      final nextSelected =
          ids.contains(_selectedRowId) && visibleIds.contains(_selectedRowId)
          ? _selectedRowId
          : null;
      _rowKeys.removeWhere((id, _) => !ids.contains(id));

      if (!mounted) return false;
      setState(() {
        _rows = nextRows;
        _rowsSnapshotSignature = nextSignature;
        _selectedRowId = nextSelected;
        _bulkSelectedRowIds.removeWhere((id) => !ids.contains(id));
        _clampCurrentPage();
        if (showLoader) _loadingRows = false;
      });
      if (_selectedRowId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _activeInsertColumn = 0;
          _insertFocusNode.requestFocus();
        });
      }
      return true;
    } catch (e) {
      _toast('No se pudieron cargar movimientos: $e');
      if (mounted && showLoader) setState(() => _loadingRows = false);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> _loadRowsFromV2() async {
    final data = await supa
        .from('inventory_movements_v2')
        .select(
          '*,general_material:general_material_id(id,code,name),'
          'commercial_material:commercial_material_id(id,code,name,general_material_id),'
          'source_commercial:source_commercial_material_id(id,code,name)',
        )
        .eq('flow', widget.flow)
        .eq('inventory_level', _isIn ? 'GENERAL' : 'COMMERCIAL')
        .order('op_date', ascending: false)
        .order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>().map((row) {
      final general = (row['general_material'] as Map?)
          ?.cast<String, dynamic>();
      final commercialMaterial = (row['commercial_material'] as Map?)
          ?.cast<String, dynamic>();
      final sourceCommercial = (row['source_commercial'] as Map?)
          ?.cast<String, dynamic>();
      return <String, dynamic>{
        ...row,
        'material_id': _isIn
            ? row['general_material_id']
            : (commercialMaterial == null
                  ? null
                  : commercialMaterial['general_material_id']),
        'material': _isIn
            ? (general == null ? null : general['code'])
            : (commercialMaterial == null ? null : commercialMaterial['code']),
        'commercial_material_code': _isIn
            ? (sourceCommercial == null ? null : sourceCommercial['code'])
            : (commercialMaterial == null ? null : commercialMaterial['code']),
        'net_kg': row['net_kg'] ?? row['weight_kg'],
        'movement_origin': 'MANUAL',
      };
    }).toList();
  }

  Future<void> _insertDraft() async {
    _draft = _draftWithComputed();
    final grossKg = _parseNum(_draftGrossC.text);
    final tareKg = _parseNum(_draftTareC.text);
    final netKg = grossKg == null || grossKg <= 0
        ? null
        : math.max(0, grossKg - (tareKg ?? 0)).toDouble();
    final commercial = _commercialByCode(_draft.commercialMaterialCode);
    final resolvedMaterialId = commercial?.materialId ?? _draft.materialId;
    final missingFields = <String>[];
    if (_draft.opDate == null) missingFields.add('Fecha');
    if (resolvedMaterialId == null) missingFields.add('Material general');
    if (_draftReferenceC.text.trim().isEmpty) {
      missingFields.add('Ticket / folio');
    }
    if (_draft.counterpartySiteId == null) {
      missingFields.add(
        _counterpartyLabel == 'PROVEEDOR' ? 'Proveedor' : 'Cliente',
      );
    }
    if (grossKg == null || grossKg <= 0) missingFields.add('Bruto (kg)');
    if (netKg == null || netKg <= 0) missingFields.add('Neto calculado (kg)');
    if ((_draft.commercialMaterialCode ?? '').trim().isEmpty) {
      missingFields.add('Material comercial (Extras)');
    }
    if (missingFields.isNotEmpty) {
      await _showInsertValidationDialog(missingFields);
      return;
    }
    if (_inserting) return;

    setState(() => _inserting = true);
    try {
      final materialOpt = _materialById(resolvedMaterialId);
      if (materialOpt == null) {
        _toast('Selecciona un material general válido');
        return;
      }
      final extrasError = _movementExtrasRequiredError(
        flow: widget.flow,
        inventoryGeneralCode: materialOpt.inventoryGeneralCode,
        commercialMaterialCode: _draft.commercialMaterialCode,
        movementReason: _draft.movementReason,
      );
      if (extrasError != null) {
        _toast(extrasError);
        return;
      }
      final totalAmountKg = _totalAmountKg(
        netKg: netKg!,
        humidityPercent: _parseNum(_draftHumidityC.text),
        trashKg: _parseNum(_draftTrashC.text),
      );
      final siteName = _labelOf(_counterparties, _draft.counterpartySiteId);
      if (commercial == null || commercial.id.isEmpty) {
        _toast('Selecciona un material comercial válido');
        return;
      }
      await supa
          .from('inventory_movements_v2')
          .insert(
            _isIn
                ? {
                    'op_date': _fmtDbDate(_draft.opDate!),
                    'inventory_level': 'GENERAL',
                    'flow': 'IN',
                    'general_material_id': resolvedMaterialId,
                    'source_commercial_material_id': commercial.id,
                    'origin_type': _draft.movementReason == 'SCRAP_SEPARATION'
                        ? 'TRANSFORMATION'
                        : 'DIRECT_PURCHASE',
                    'weight_kg': netKg,
                    'gross_kg': grossKg,
                    'tare_kg': tareKg,
                    'net_kg': netKg,
                    'humidity_percent': _parseNum(_draftHumidityC.text),
                    'trash_kg': _parseNum(_draftTrashC.text),
                    'total_amount_kg': totalAmountKg,
                    'movement_reason': _draft.movementReason,
                    'scale_ticket': _draft.scaleTicket.trim().isEmpty
                        ? null
                        : _draft.scaleTicket.trim(),
                    'counterparty_site_id': _draft.counterpartySiteId,
                    'driver_employee_id': _draft.driverEmployeeId,
                    'vehicle_id': _draft.vehicleId,
                    'counterparty': siteName,
                    'reference': _draftReferenceC.text.trim().isEmpty
                        ? null
                        : _draftReferenceC.text.trim(),
                    'notes': _draftNotesC.text.trim().isEmpty
                        ? null
                        : _draftNotesC.text.trim(),
                  }
                : {
                    'op_date': _fmtDbDate(_draft.opDate!),
                    'inventory_level': 'COMMERCIAL',
                    'flow': 'OUT',
                    'commercial_material_id': commercial.id,
                    'origin_type': 'SALE',
                    'weight_kg': netKg,
                    'gross_kg': grossKg,
                    'tare_kg': tareKg,
                    'net_kg': netKg,
                    'humidity_percent': _parseNum(_draftHumidityC.text),
                    'trash_kg': _parseNum(_draftTrashC.text),
                    'total_amount_kg': totalAmountKg,
                    'scale_ticket': _draft.scaleTicket.trim().isEmpty
                        ? null
                        : _draft.scaleTicket.trim(),
                    'counterparty_site_id': _draft.counterpartySiteId,
                    'driver_employee_id': _draft.driverEmployeeId,
                    'vehicle_id': _draft.vehicleId,
                    'counterparty': siteName,
                    'reference': _draftReferenceC.text.trim().isEmpty
                        ? null
                        : _draftReferenceC.text.trim(),
                    'notes': _draftNotesC.text.trim().isEmpty
                        ? null
                        : _draftNotesC.text.trim(),
                  },
          );
      _toast('${_isIn ? 'Entrada' : 'Salida'} agregada');
      _initDraftDefaults();
      await _loadRows(showLoader: false);
      await widget.onChanged?.call();
      if (!mounted) return;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _insertFocusNode.requestFocus();
      });
    } on PostgrestException catch (e) {
      _toast(
        _friendlyPostgrestMessage(
          e,
          fallbackAction: 'No se pudo guardar el movimiento.',
        ),
      );
    } catch (e) {
      _toast('No se pudo insertar: $e');
    } finally {
      if (mounted) setState(() => _inserting = false);
    }
  }

  Future<void> _showInsertValidationDialog(List<String> missingFields) async {
    if (!mounted) return;
    final details = missingFields.map((f) => '• $f').join('\n');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            Navigator.of(dialogContext).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AlertDialog(
          backgroundColor: const Color(0xFFEAF2F9).withValues(alpha: 0.98),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: const Color(0xFF8AA9C2).withValues(alpha: 0.42),
            ),
          ),
          title: const Text('No se puede agregar'),
          content: Text('Completa estos campos antes de agregar:\n\n$details'),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6A99C7),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRow(String id) async {
    try {
      await supa.from('inventory_movements_v2').delete().eq('id', id);
      _bulkSelectedRowIds.remove(id);
      _toast('Eliminado');
      await _loadRows(showLoader: false);
      await widget.onChanged?.call();
    } on PostgrestException catch (e) {
      _toast(
        _friendlyPostgrestMessage(
          e,
          fallbackAction: 'No se pudo eliminar el movimiento.',
        ),
      );
    } catch (e) {
      _toast('No se pudo eliminar movimiento: $e');
    }
  }

  Future<void> _updateRow(String id, Map<String, dynamic> patch) async {
    try {
      final commercial = _commercialByCode(
        patch['commercial_material_code']?.toString(),
      );
      final resolvedMaterialId =
          patch['material_id']?.toString() ?? commercial?.materialId;
      if (commercial == null || resolvedMaterialId == null) {
        _toast('Material comercial o general inválido');
        return;
      }
      final mappedPatch = _isIn
          ? <String, dynamic>{
              'op_date': patch['op_date'],
              'general_material_id': resolvedMaterialId,
              'source_commercial_material_id': commercial.id,
              'origin_type': patch['movement_reason'] == 'SCRAP_SEPARATION'
                  ? 'TRANSFORMATION'
                  : 'DIRECT_PURCHASE',
              'weight_kg': patch['weight_kg'] ?? patch['net_kg'],
              'gross_kg': patch['gross_kg'],
              'tare_kg': patch['tare_kg'],
              'net_kg': patch['net_kg'] ?? patch['weight_kg'],
              'humidity_percent': patch['humidity_percent'],
              'trash_kg': patch['trash_kg'],
              'total_amount_kg': patch['total_amount_kg'],
              'counterparty_site_id': patch['counterparty_site_id'],
              'driver_employee_id': patch['driver_employee_id'],
              'vehicle_id': patch['vehicle_id'],
              'counterparty': patch['counterparty'],
              'movement_reason': patch['movement_reason'],
              'scale_ticket': patch['scale_ticket'],
              'reference': patch['reference'],
              'notes': patch['notes'],
            }
          : <String, dynamic>{
              'op_date': patch['op_date'],
              'commercial_material_id': commercial.id,
              'origin_type': 'SALE',
              'weight_kg': patch['weight_kg'] ?? patch['net_kg'],
              'gross_kg': patch['gross_kg'],
              'tare_kg': patch['tare_kg'],
              'net_kg': patch['net_kg'] ?? patch['weight_kg'],
              'humidity_percent': patch['humidity_percent'],
              'trash_kg': patch['trash_kg'],
              'total_amount_kg': patch['total_amount_kg'],
              'counterparty_site_id': patch['counterparty_site_id'],
              'driver_employee_id': patch['driver_employee_id'],
              'vehicle_id': patch['vehicle_id'],
              'counterparty': patch['counterparty'],
              'scale_ticket': patch['scale_ticket'],
              'reference': patch['reference'],
              'notes': patch['notes'],
            };
      await supa
          .from('inventory_movements_v2')
          .update(mappedPatch)
          .eq('id', id);
      final idx = _rows.indexWhere((r) => r['id'] == id);
      if (idx != -1) {
        setState(() => _rows[idx] = {..._rows[idx], ...patch});
      } else {
        await _loadRows(showLoader: false);
      }
      await widget.onChanged?.call();
    } on PostgrestException catch (e) {
      _toast(
        _friendlyPostgrestMessage(
          e,
          fallbackAction: 'No se pudo actualizar el movimiento.',
        ),
      );
    } catch (e) {
      _toast('No se pudo actualizar movimiento: $e');
    }
  }

  Future<void> _deleteSelectedRows() async {
    if (_bulkSelectedRowIds.isEmpty || _bulkDeleting) return;
    final ok = await _showConfirmDialog(
      context,
      title: 'Eliminar seleccionados',
      content: '¿Eliminar ${_bulkSelectedRowIds.length} movimiento(s)?',
      confirmText: 'Eliminar',
    );
    if (ok != true) return;
    setState(() => _bulkDeleting = true);
    try {
      final ids = _bulkSelectedRowIds.toList();
      await supa.from('inventory_movements_v2').delete().inFilter('id', ids);
      _bulkSelectedRowIds.clear();
      _toast('Eliminados ${ids.length} movimientos');
      await _loadRows(showLoader: false);
      await widget.onChanged?.call();
    } on PostgrestException catch (e) {
      _toast(
        _friendlyPostgrestMessage(
          e,
          fallbackAction:
              'No se pudieron eliminar los movimientos seleccionados.',
        ),
      );
    } catch (e) {
      _toast('No se pudieron eliminar movimientos: $e');
    } finally {
      if (mounted) setState(() => _bulkDeleting = false);
    }
  }

  String _csvEscape(dynamic value) {
    if (value == null) return '';
    final text = value.toString();
    final escaped = text.replaceAll('"', '""');
    final needsQuotes =
        escaped.contains(',') ||
        escaped.contains('\n') ||
        escaped.contains('"');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  Future<void> _exportCsv() async {
    if (_exportingCsv) return;
    setState(() => _exportingCsv = true);
    try {
      final rows = await _loadRowsFromV2ForExport();
      const headers = <String>[
        'id',
        'created_at',
        'op_date',
        'flow',
        'material',
        'weight_kg',
        'gross_kg',
        'tare_kg',
        'net_kg',
        'humidity_percent',
        'trash_kg',
        'total_amount_kg',
        'counterparty_site_id',
        'driver_employee_id',
        'vehicle_id',
        'counterparty',
        'commercial_material_code',
        'movement_reason',
        'scale_ticket',
        'reference',
        'notes',
        'site',
      ];
      final sb = StringBuffer()
        ..write('\uFEFF')
        ..writeln(headers.join(','));
      for (final row in rows) {
        sb.writeln(headers.map((h) => _csvEscape(row[h])).join(','));
      }
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'movements_${widget.flow.toLowerCase()}_$stamp.csv';
      final savedPath = await _writeDownloadsFile(fileName, sb.toString());
      _toast(
        savedPath == null
            ? 'No se pudo guardar CSV en Descargas'
            : 'CSV exportado en: $savedPath',
      );
    } catch (e) {
      _toast('No se pudo exportar CSV: $e');
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadRowsFromV2ForExport() async {
    final rows = await _loadRowsFromV2();
    return rows
        .map((row) => <String, dynamic>{...row, 'flow': widget.flow})
        .toList();
  }

  Future<String?> _writeDownloadsFile(String fileName, String content) async {
    final env = Platform.environment;
    final dirs = <Directory>[];
    if (Platform.isWindows) {
      final userProfile = env['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        dirs.add(Directory('$userProfile\\Downloads'));
      }
    } else {
      final home = env['HOME'];
      if (home != null && home.isNotEmpty) {
        dirs.add(Directory('$home/Downloads'));
        dirs.add(Directory('$home/Descargas'));
      }
    }
    for (final dir in dirs) {
      try {
        if (!dir.existsSync()) dir.createSync(recursive: true);
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(content, encoding: utf8);
        return file.path;
      } catch (_) {}
    }
    return null;
  }

  String? _labelOf(List<_InvOpt> list, String? id) {
    if (id == null) return null;
    for (final o in list) {
      if (o.id == id) return o.label;
    }
    return null;
  }

  bool get _draftHasExtras =>
      (_draft.commercialMaterialCode?.isNotEmpty ?? false) ||
      (_draft.movementReason?.isNotEmpty ?? false);

  Future<void> _editDraftExtras() async {
    final result = await _showMovementExtrasDialog(
      context,
      flow: widget.flow,
      materialLabel: _materialLabel(_draft.materialId),
      inventoryMaterialCode: _inventoryMaterialCodeForMaterialId(
        _draft.materialId,
      ),
      inventoryGeneralCode: _inventoryGeneralCodeForMaterialId(
        _draft.materialId,
      ),
      commercialOptions: _commercialOptionsForMaterial(_draft.materialId),
      initialCommercialMaterialCode: _draft.commercialMaterialCode,
      initialMovementReason: _draft.movementReason,
      initialGrossKg: null,
      initialTareKg: null,
      initialNetKg: null,
      initialHumidityPercent: null,
      initialTrashKg: null,
    );
    if (!mounted || result == null) return;
    setState(() {
      _draft = _draft.copyWith(
        commercialMaterialCode: result.commercialMaterialCode,
        movementReason: result.movementReason,
      );
    });
  }

  List<_CommercialMaterialOpt> _commercialOptionsForMaterial(
    String? materialId,
  ) {
    if (materialId == null || materialId.isEmpty) return _commercialMaterials;
    final filtered = _commercialMaterials
        .where((opt) => _commercialMatchesMaterial(opt, materialId, null))
        .toList();
    return filtered.isEmpty ? _commercialMaterials : filtered;
  }

  bool _commercialMatchesMaterial(
    _CommercialMaterialOpt opt,
    String? materialId,
    String? sourceCode,
  ) {
    sourceCode;
    return opt.materialId == null || opt.materialId == materialId;
  }

  String _fmtUiDate(DateTime d) {
    final yy = (d.year % 100).toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd/$mm/$yy';
  }

  String _fmtDbDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  DateTime _parseDate(dynamic v) {
    if (v is String && v.length >= 10) {
      final y = int.tryParse(v.substring(0, 4));
      final m = int.tryParse(v.substring(5, 7));
      final d = int.tryParse(v.substring(8, 10));
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return DateUtils.dateOnly(DateTime.now());
  }

  double? _parseNum(String raw) {
    final c = raw.trim().replaceAll(',', '');
    if (c.isEmpty) return null;
    return double.tryParse(c);
  }

  double? _effectiveNetKgFromValues({
    required double? netKg,
    required double? grossKg,
    required double? tareKg,
  }) {
    if (netKg != null && netKg > 0) return netKg;
    if (grossKg == null || grossKg <= 0) return null;
    final tare = tareKg == null || tareKg < 0 ? 0 : tareKg;
    return math.max(0, grossKg - tare);
  }

  double? _effectiveNetKgFromRow(Map<String, dynamic> row) {
    return _effectiveNetKgFromValues(
      netKg: _toDouble(row['net_kg']) ?? _toDouble(row['weight_kg']),
      grossKg: _toDouble(row['gross_kg']),
      tareKg: _toDouble(row['tare_kg']),
    );
  }

  double _totalAmountKg({
    required double netKg,
    required double? humidityPercent,
    required double? trashKg,
  }) {
    final humidity = humidityPercent == null || humidityPercent < 0
        ? 0.0
        : humidityPercent;
    final trash = trashKg == null || trashKg < 0 ? 0.0 : trashKg;
    final humidityDiscount = netKg * (humidity / 100.0);
    return math.max(0, netKg - humidityDiscount - trash);
  }

  _MovementDraft _draftWithComputed() {
    final grossKg = _parseNum(_draftGrossC.text);
    final tareKg = _parseNum(_draftTareC.text);
    final humidityPercent = _parseNum(_draftHumidityC.text);
    final trashKg = _parseNum(_draftTrashC.text);
    final netKg = grossKg == null || grossKg <= 0
        ? null
        : math.max(0, grossKg - (tareKg ?? 0)).toDouble();
    final netText = netKg == null ? '' : netKg.toStringAsFixed(2);
    if (_draftWeightC.text != netText) {
      _draftWeightC.text = netText;
    }
    final totalAmountKg = netKg == null
        ? null
        : _totalAmountKg(
            netKg: netKg,
            humidityPercent: humidityPercent,
            trashKg: trashKg,
          );
    return _draft.copyWith(
      grossKg: grossKg,
      tareKg: tareKg,
      netKg: netKg,
      humidityPercent: humidityPercent,
      trashKg: trashKg,
      totalAmountKg: totalAmountKg,
    );
  }

  _InvMaterialOpt? _materialById(String? id) {
    if (id == null) return null;
    for (final m in _materials) {
      if (m.id == id) return m;
    }
    return null;
  }

  _CommercialMaterialOpt? _commercialByCode(String? code) {
    if (code == null) return null;
    final key = code.trim();
    if (key.isEmpty) return null;
    for (final c in _commercialMaterials) {
      if (c.code == key) return c;
    }
    return null;
  }

  String? _inventoryMaterialCodeForMaterialId(String? id) =>
      _materialById(id)?.inventoryMaterialCode;

  String? _inventoryGeneralCodeForMaterialId(String? id) =>
      _materialById(id)?.inventoryGeneralCode;

  String _materialLabel(String? materialId) =>
      _materialById(materialId)?.name ?? '—';

  String _commercialLabel(String? commercialCode) {
    final commercial = _commercialByCode(commercialCode);
    if (commercial == null) return '';
    return commercial.name.trim();
  }

  String _cellTextForColumn(Map<String, dynamic> row, String columnId) {
    switch (columnId) {
      case 'fecha':
        return _fmtUiDate(_parseDate(row['op_date']));
      case 'material':
        final commercialCode = row['commercial_material_code']?.toString();
        final commercialLabel = _commercialLabel(commercialCode);
        if (commercialLabel.isNotEmpty) {
          return commercialLabel;
        }
        final materialId = row['material_id']?.toString();
        if (materialId != null && materialId.isNotEmpty) {
          return _materialLabel(materialId);
        }
        return _invMaterialLabel(row['material']?.toString());
      case 'kg':
        final n = _effectiveNetKgFromRow(row);
        return n == null ? '' : n.toStringAsFixed(2);
      case 'bruto':
        final n = _toDouble(row['gross_kg']);
        return n == null ? '' : n.toStringAsFixed(2);
      case 'tara':
        final n = _toDouble(row['tare_kg']);
        return n == null ? '' : n.toStringAsFixed(2);
      case 'humedad':
        final n = _toDouble(row['humidity_percent']);
        return n == null ? '' : n.toStringAsFixed(2);
      case 'basura':
        final n = _toDouble(row['trash_kg']);
        return n == null ? '' : n.toStringAsFixed(2);
      case 'importe':
        final n = _toDouble(row['total_amount_kg']);
        return n == null ? '' : n.toStringAsFixed(2);
      case 'counterparty':
        return (_labelOf(
                  _counterparties,
                  row['counterparty_site_id'] as String?,
                ) ??
                (row['counterparty'] ?? '').toString())
            .trim();
      case 'chofer':
        return (_labelOf(_drivers, row['driver_employee_id'] as String?) ?? '')
            .trim();
      case 'unidad':
        return (_labelOf(_vehicles, row['vehicle_id'] as String?) ?? '').trim();
      case 'reference':
        return (row['reference'] ?? '').toString().trim();
      case 'notes':
        return (row['notes'] ?? '').toString().trim();
      default:
        return '';
    }
  }

  DateTime? _dateValueForColumn(Map<String, dynamic> row, String columnId) {
    if (columnId != 'fecha') return null;
    return _parseDate(row['op_date']);
  }

  bool _matchesFilters(Map<String, dynamic> row, {String? excludeColumn}) {
    for (final entry in _columnDateRangeFilters.entries) {
      if (entry.key == excludeColumn) continue;
      final value = _dateValueForColumn(row, entry.key);
      if (value == null) return false;
      final d = DateUtils.dateOnly(value);
      final start = DateUtils.dateOnly(entry.value.start);
      final end = DateUtils.dateOnly(entry.value.end);
      if (d.isBefore(start) || d.isAfter(end)) return false;
    }
    for (final entry in _columnValueFilters.entries) {
      if (entry.key == excludeColumn || entry.value.isEmpty) continue;
      final value = _cellTextForColumn(row, entry.key);
      if (!entry.value.contains(value)) return false;
    }
    return true;
  }

  List<Map<String, dynamic>> get _filteredRows =>
      _rows.where((r) => _matchesFilters(r)).toList();

  List<Map<String, dynamic>> get _visibleRows {
    final filtered = _filteredRows;
    final start = _currentPage * _pageSize;
    if (start >= filtered.length) return <Map<String, dynamic>>[];
    final end = (start + _pageSize < filtered.length)
        ? start + _pageSize
        : filtered.length;
    return filtered.sublist(start, end);
  }

  int get _totalPages {
    final total = _filteredRows.length;
    if (total == 0) return 1;
    return ((total - 1) ~/ _pageSize) + 1;
  }

  void _clampCurrentPage() {
    final maxPage = _totalPages - 1;
    if (_currentPage > maxPage) _currentPage = maxPage;
    if (_currentPage < 0) _currentPage = 0;
  }

  bool _hasActiveFilter(String columnId) {
    return (_columnValueFilters[columnId]?.isNotEmpty ?? false) ||
        _columnDateRangeFilters.containsKey(columnId);
  }

  bool _isDateFilterColumn(String columnId) => columnId == 'fecha';

  DateTimeRange _dateBoundsForColumn(String columnId) {
    DateTime? minDate;
    DateTime? maxDate;
    for (final row in _rows) {
      final d = _dateValueForColumn(row, columnId);
      if (d == null) continue;
      final dateOnly = DateUtils.dateOnly(d);
      if (minDate == null || dateOnly.isBefore(minDate)) minDate = dateOnly;
      if (maxDate == null || dateOnly.isAfter(maxDate)) maxDate = dateOnly;
    }
    final now = DateUtils.dateOnly(DateTime.now());
    return DateTimeRange(
      start: minDate ?? DateTime(now.year - 3, 1, 1),
      end: maxDate ?? DateTime(now.year + 3, 12, 31),
    );
  }

  List<String> _columnDistinctValues(String columnId, {String search = ''}) {
    final values = <String>{};
    final q = search.trim().toLowerCase();
    for (final row in _rows) {
      if (!_matchesFilters(row, excludeColumn: columnId)) continue;
      final v = _cellTextForColumn(row, columnId);
      if (v.isEmpty) continue;
      if (q.isNotEmpty && !v.toLowerCase().contains(q)) continue;
      values.add(v);
    }
    final list = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  Future<void> _openColumnFilter(String columnId, String label) async {
    if (_isDateFilterColumn(columnId)) {
      final result = await _showInvDateRangeFilterDialog(
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
        _columnValueFilters.remove(columnId);
        _clampCurrentPage();
        final visibleIds = _filteredRows.map((r) => r['id'] as String).toSet();
        _bulkSelectedRowIds.removeWhere((id) => !visibleIds.contains(id));
        if (!visibleIds.contains(_selectedRowId)) _selectedRowId = null;
      });
      return;
    }

    final initialSelected = {...(_columnValueFilters[columnId] ?? <String>{})};
    final result = await showDialog<_InvFilterDialogResult>(
      context: context,
      builder: (dialogContext) {
        final localSelected = <String>{...initialSelected};
        String localSearch = '';
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final options = _columnDistinctValues(
              columnId,
              search: localSearch,
            );
            final allVisibleSelected =
                options.isNotEmpty && options.every(localSelected.contains);
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 420,
                    constraints: const BoxConstraints(maxHeight: 560),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    decoration: _invFilterDialogDecoration(),
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
                          decoration: _invGlassFieldDecoration(
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
                              style: _invFilterOutlinedButtonStyle(),
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: _invFilterOutlinedButtonStyle(),
                              onPressed: () => Navigator.pop(
                                dialogContext,
                                const _InvFilterDialogResult(
                                  selectedValues: <String>{},
                                ),
                              ),
                              child: const Text('Limpiar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: _invFilterFilledButtonStyle(),
                              onPressed: () => Navigator.pop(
                                dialogContext,
                                _InvFilterDialogResult(
                                  selectedValues: localSelected,
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
        );
      },
    );

    if (result == null) return;
    setState(() {
      if (result.selectedValues.isEmpty) {
        _columnValueFilters.remove(columnId);
      } else {
        _columnValueFilters[columnId] = result.selectedValues;
      }
      _columnDateRangeFilters.remove(columnId);
      _clampCurrentPage();
    });
  }

  void _setActiveInsertColumn(int value, {bool requestFocus = true}) {
    setState(() {
      _activeInsertColumn =
          ((value % _insertColumnCount) + _insertColumnCount) %
          _insertColumnCount;
      _selectedRowId = null;
      _selectionAnchorRowId = null;
      _bulkSelectedRowIds.clear();
    });
    if (!requestFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (_activeInsertColumn) {
        case 1:
          FocusScope.of(context).requestFocus(_insertReferenceFocusNode);
          break;
        case 6:
          FocusScope.of(context).requestFocus(_insertGrossFocusNode);
          break;
        case 7:
          FocusScope.of(context).requestFocus(_insertTareFocusNode);
          break;
        case 9:
          FocusScope.of(context).requestFocus(_insertHumidityFocusNode);
          break;
        case 10:
          FocusScope.of(context).requestFocus(_insertTrashFocusNode);
          break;
        case 12:
          FocusScope.of(context).requestFocus(_insertNotesFocusNode);
          break;
        default:
          FocusManager.instance.primaryFocus?.unfocus();
          _insertFocusNode.requestFocus();
      }
    });
  }

  void _moveInsertColumn(int delta) =>
      _setActiveInsertColumn(_activeInsertColumn + delta);

  bool get _isInsertTextFocused =>
      _insertGrossFocusNode.hasFocus ||
      _insertTareFocusNode.hasFocus ||
      _insertHumidityFocusNode.hasFocus ||
      _insertTrashFocusNode.hasFocus ||
      _insertReferenceFocusNode.hasFocus ||
      _insertNotesFocusNode.hasFocus;

  bool _caretAtStart(TextEditingController c, FocusNode f) {
    if (!f.hasFocus) return false;
    final s = c.selection;
    return s.isValid &&
        s.isCollapsed &&
        s.baseOffset == 0 &&
        s.extentOffset == 0;
  }

  bool _caretAtEnd(TextEditingController c, FocusNode f) {
    if (!f.hasFocus) return false;
    final s = c.selection;
    final end = c.text.length;
    return s.isValid &&
        s.isCollapsed &&
        s.baseOffset == end &&
        s.extentOffset == end;
  }

  Future<void> _activateInsertCellFromKeyboard() async {
    switch (_activeInsertColumn) {
      case 0:
        final d = await _pickDate(_draft.opDate);
        if (!mounted || d == null) return;
        setState(() => _draft = _draft.copyWith(opDate: d));
        return;
      case 2:
        final v = await _pickStringOption(
          title: 'Material',
          options: _materials.map((m) => m.id).toList(),
          current: _draft.materialId,
          format: _materialLabel,
        );
        if (!mounted || v == null) return;
        setState(() => _draft = _draft.copyWith(materialId: v));
        return;
      case 3:
        final id = await _pickOptId(
          title: _isIn ? 'Proveedor' : 'Cliente',
          options: _counterparties,
          currentId: _draft.counterpartySiteId,
        );
        if (!mounted) return;
        setState(() => _draft = _draft.copyWith(counterpartySiteId: id));
        return;
      case 4:
        final id = await _pickOptId(
          title: 'Chofer',
          options: _drivers,
          currentId: _draft.driverEmployeeId,
        );
        if (!mounted) return;
        setState(() => _draft = _draft.copyWith(driverEmployeeId: id));
        return;
      case 5:
        final id = await _pickOptId(
          title: 'Unidad',
          options: _vehicles,
          currentId: _draft.vehicleId,
        );
        if (!mounted) return;
        setState(() => _draft = _draft.copyWith(vehicleId: id));
        return;
      case 13:
        await _editDraftExtras();
        return;
      default:
        return;
    }
  }

  void _clearActiveInsertCell() {
    switch (_activeInsertColumn) {
      case 0:
        setState(() => _draft = _draft.copyWith(opDate: null));
        return;
      case 1:
        _draftReferenceC.clear();
        setState(() => _draft = _draft.copyWith(reference: ''));
        return;
      case 2:
        setState(() => _draft = _draft.copyWith(materialId: null));
        return;
      case 6:
        _draftGrossC.clear();
        setState(() => _draft = _draftWithComputed());
        return;
      case 7:
        _draftTareC.clear();
        setState(() => _draft = _draftWithComputed());
        return;
      case 8:
        setState(() => _draft = _draftWithComputed());
        return;
      case 9:
        _draftHumidityC.clear();
        setState(() => _draft = _draftWithComputed());
        return;
      case 10:
        _draftTrashC.clear();
        setState(() => _draft = _draftWithComputed());
        return;
      case 3:
        setState(() => _draft = _draft.copyWith(counterpartySiteId: null));
        return;
      case 4:
        setState(() => _draft = _draft.copyWith(driverEmployeeId: null));
        return;
      case 5:
        setState(() => _draft = _draft.copyWith(vehicleId: null));
        return;
      case 12:
        _draftNotesC.clear();
        setState(() => _draft = _draft.copyWith(notes: ''));
        return;
      default:
        return;
    }
  }

  void _focusGridFromInsert() {
    final firstVisibleId = _visibleRows.isEmpty
        ? null
        : _visibleRows.first['id'] as String;
    setState(() {
      _activeGridColumn = _activeInsertColumn > 13 ? 13 : _activeInsertColumn;
      if (firstVisibleId != null) {
        _selectedRowId = firstVisibleId;
        _selectionAnchorRowId = firstVisibleId;
        _bulkSelectedRowIds.clear();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rowsFocusNode.requestFocus();
      if (firstVisibleId != null) _ensureRowVisible(firstVisibleId);
    });
  }

  void _requestRowsFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rowsFocusNode.requestFocus();
    });
  }

  void _focusInsertFromGrid() {
    setState(() {
      _activeInsertColumn = _activeGridColumn > 13 ? 13 : _activeGridColumn;
      _selectedRowId = null;
      _selectionAnchorRowId = null;
      _bulkSelectedRowIds.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setActiveInsertColumn(_activeInsertColumn);
    });
  }

  Future<DateTime?> _pickDate(DateTime? current) async {
    final initial = DateUtils.dateOnly(current ?? DateTime.now());
    return _showInvKeyboardDatePickerDialog(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2035, 12, 31),
    );
  }

  Future<String?> _pickOptId({
    required String title,
    required List<_InvOpt> options,
    required String? currentId,
  }) {
    return _showInvSearchablePickerDialog<String>(
      context,
      title: title,
      initialValue: currentId,
      options: options
          .map((o) => _InvPickerOption<String>(value: o.id, label: o.label))
          .toList(),
    );
  }

  Future<String?> _pickStringOption({
    required String title,
    required List<String> options,
    required String? current,
    required String Function(String?) format,
  }) {
    return _showInvSearchablePickerDialog<String>(
      context,
      title: title,
      initialValue: current,
      options: options
          .map((o) => _InvPickerOption<String>(value: o, label: format(o)))
          .toList(),
    );
  }

  GlobalKey<_MovementDataRowState> _rowKeyFor(String id) =>
      _rowKeys.putIfAbsent(id, () => GlobalKey<_MovementDataRowState>());

  void _ensureRowVisible(String id, {int? moveDelta}) {
    final rowContext = _rowKeyFor(id).currentContext;
    if (rowContext != null) {
      final policy = moveDelta == null
          ? ScrollPositionAlignmentPolicy.explicit
          : (moveDelta >= 0
                ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
                : ScrollPositionAlignmentPolicy.keepVisibleAtStart);
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
        alignmentPolicy: policy,
      );
      return;
    }
    final rowIndex = _visibleRows.indexWhere((r) => r['id'] == id);
    if (rowIndex == -1 || !_rowsScrollController.hasClients) return;
    const estimatedRowExtent = 78.0;
    final viewport = _rowsScrollController.position.viewportDimension;
    final current = _rowsScrollController.offset;
    final target = rowIndex * estimatedRowExtent;
    final minVisible = current;
    final maxVisible = current + viewport - estimatedRowExtent;
    if (target < minVisible) {
      _rowsScrollController.animateTo(
        target.clamp(0.0, _rowsScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (target > maxVisible) {
      final nextOffset = target - (viewport - estimatedRowExtent);
      _rowsScrollController.animateTo(
        nextOffset.clamp(0.0, _rowsScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _selectRow(
    String id, {
    bool additive = false,
    bool allowToggle = false,
  }) {
    if (!additive && !allowToggle) {
      final alreadySelectedOnly =
          _selectedRowId == id &&
          _bulkSelectedRowIds.isEmpty &&
          _selectionAnchorRowId == id;
      if (alreadySelectedOnly) return;
    }
    setState(() {
      if (additive) {
        if (_bulkSelectedRowIds.contains(id)) {
          _bulkSelectedRowIds.remove(id);
          if (_selectedRowId == id) {
            _selectedRowId = _bulkSelectedRowIds.isEmpty
                ? null
                : _bulkSelectedRowIds.last;
          }
        } else {
          if (_selectedRowId != null) _bulkSelectedRowIds.add(_selectedRowId!);
          _bulkSelectedRowIds.add(id);
          _selectedRowId = id;
          _selectionAnchorRowId ??= id;
        }
        return;
      }
      if (allowToggle && _selectedRowId == id) {
        _selectedRowId = null;
        _bulkSelectedRowIds.clear();
        return;
      }
      _selectedRowId = id;
      _selectionAnchorRowId = id;
      _bulkSelectedRowIds.clear();
    });
  }

  void _selectRowRangeTo(String id) {
    final rows = _visibleRows;
    if (rows.isEmpty) return;
    final anchorId = _selectionAnchorRowId ?? _selectedRowId ?? id;
    final anchorIndex = rows.indexWhere((r) => r['id'] == anchorId);
    final targetIndex = rows.indexWhere((r) => r['id'] == id);
    if (anchorIndex == -1 || targetIndex == -1) {
      _selectRow(id);
      return;
    }
    final from = anchorIndex <= targetIndex ? anchorIndex : targetIndex;
    final to = anchorIndex <= targetIndex ? targetIndex : anchorIndex;
    final ids = rows
        .sublist(from, to + 1)
        .map((r) => r['id'] as String)
        .toSet();
    setState(() {
      _selectionAnchorRowId = anchorId;
      _selectedRowId = id;
      _bulkSelectedRowIds
        ..clear()
        ..addAll(ids);
    });
  }

  Set<String> _currentSelectionIds() {
    final ids = <String>{..._bulkSelectedRowIds};
    if (_selectedRowId != null) ids.add(_selectedRowId!);
    return ids;
  }

  double get _rowsScrollOffset =>
      _rowsScrollController.hasClients ? _rowsScrollController.offset : 0.0;

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
    final box =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return rectViewport;
    final size = box.size;
    final left = rectViewport.left.clamp(0.0, size.width);
    final top = rectViewport.top.clamp(0.0, size.height);
    final right = rectViewport.right.clamp(0.0, size.width);
    final bottom = rectViewport.bottom.clamp(0.0, size.height);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  double _effectiveRowExtent() {
    for (final row in _visibleRows) {
      final id = row['id'] as String;
      final rowContext = _rowKeys[id]?.currentContext;
      final rowBox = rowContext?.findRenderObject() as RenderBox?;
      if (rowBox != null && rowBox.hasSize && rowBox.size.height > 0) {
        return rowBox.size.height;
      }
    }
    return 78.0;
  }

  Set<String> _marqueeIntersectedIds(Rect rectContent) {
    final viewportContext = _rowsViewportKey.currentContext;
    if (viewportContext == null) return const <String>{};
    final viewportBox = viewportContext.findRenderObject() as RenderBox?;
    if (viewportBox == null) return const <String>{};
    if (rectContent.right <= 0 || rectContent.left >= viewportBox.size.width) {
      return const <String>{};
    }
    final rows = _visibleRows;
    if (rows.isEmpty) return const <String>{};
    final rowExtent = _effectiveRowExtent();
    final top = rectContent.top.clamp(0.0, double.infinity);
    final bottom = rectContent.bottom.clamp(0.0, double.infinity);
    final from = (top / rowExtent).floor().clamp(0, rows.length - 1);
    final to = (bottom / rowExtent).floor().clamp(0, rows.length - 1);
    if (to < from) return const <String>{};
    return rows.sublist(from, to + 1).map((r) => r['id'] as String).toSet();
  }

  void _applyMarqueeSelection() {
    if (!_marqueeActive) return;
    final rect = _marqueeRectContent();
    final hit = _marqueeIntersectedIds(rect);
    final next = _marqueeAdditive ? ({..._marqueeBaseSelection, ...hit}) : hit;
    String? nextPrimary;
    for (final row in _visibleRows) {
      final id = row['id'] as String;
      if (hit.contains(id)) nextPrimary = id;
    }
    nextPrimary ??= next.isNotEmpty ? next.last : null;
    setState(() {
      _bulkSelectedRowIds
        ..clear()
        ..addAll(next);
      _selectedRowId = nextPrimary;
      _selectionAnchorRowId = nextPrimary;
    });
  }

  Offset? _globalToRowsLocal(Offset globalPosition) {
    final box =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.globalToLocal(globalPosition);
  }

  bool _isGlobalPointInsideKey(GlobalKey key, Offset globalPosition) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final local = box.globalToLocal(globalPosition);
    return local.dx >= 0 &&
        local.dy >= 0 &&
        local.dx <= box.size.width &&
        local.dy <= box.size.height;
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

  void _onRowsPointerDown(PointerDownEvent event) {
    if (_anyRowEditing) return;
    if (_visibleRows.isEmpty) return;
    if (event.kind != PointerDeviceKind.mouse) return;
    if ((event.buttons & kPrimaryMouseButton) == 0) return;
    if (_isGlobalPointInsideKey(_insertRowKey, event.position)) return;
    final local = _globalToRowsLocal(event.position);
    if (local == null) return;
    _marqueeStartLocal = local;
    _marqueePointerLocal = local;
    _marqueeStartContent = _localToContent(local);
    _marqueeCurrentContent = _marqueeStartContent;
    _marqueeAdditive = _isCtrlOrCmdPressed();
    _marqueeBaseSelection = _currentSelectionIds();
    _marqueeActive = false;
  }

  void _onRowsPointerMove(PointerMoveEvent event) {
    if (_marqueeStartLocal == null) return;
    final local = _globalToRowsLocal(event.position);
    if (local == null) return;
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

  void _finishRowsMarqueeSelection() {
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

  void _moveSelectedRow(int delta, {bool extendSelection = false}) {
    final rows = _visibleRows;
    if (rows.isEmpty) return;
    final currentIndex = _selectedRowId == null
        ? -1
        : rows.indexWhere((r) => r['id'] == _selectedRowId);
    final nextIndex = currentIndex == -1
        ? (delta >= 0 ? 0 : rows.length - 1)
        : (((currentIndex + delta) % rows.length) + rows.length) % rows.length;
    final id = rows[nextIndex]['id'] as String;
    if (extendSelection) {
      _selectRowRangeTo(id);
    } else {
      _selectRow(id);
    }
    _ensureRowVisible(id, moveDelta: delta);
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

  bool _isSelectionExtendPressed() {
    return _isCtrlOrCmdPressed() || _isShiftPressed();
  }

  _MovementDataRowState? _selectedRowState() {
    final id = _selectedRowId;
    if (id == null) return null;
    return _rowKeys[id]?.currentState;
  }

  bool get _anyRowEditing {
    for (final key in _rowKeys.values) {
      if (key.currentState?.isEditing ?? false) return true;
    }
    return false;
  }

  bool get _anyEditingRowTextFocused {
    for (final state in _editingRowStates()) {
      if (state.isAnyTextFocused) return true;
    }
    return false;
  }

  List<_MovementDataRowState> _selectedRowStates() {
    if (_bulkSelectedRowIds.isEmpty) {
      final s = _selectedRowState();
      return s == null ? const [] : [s];
    }
    final ids = <String>[];
    if (_selectedRowId != null) ids.add(_selectedRowId!);
    for (final id in _bulkSelectedRowIds) {
      if (!ids.contains(id)) ids.add(id);
    }
    return ids
        .map((id) => _rowKeys[id]?.currentState)
        .whereType<_MovementDataRowState>()
        .toList();
  }

  List<_MovementDataRowState> _editingRowStates() {
    return _rowKeys.values
        .map((k) => k.currentState)
        .whereType<_MovementDataRowState>()
        .where((s) => s.isEditing)
        .toList();
  }

  int get _selectedCount {
    final ids = <String>{..._bulkSelectedRowIds};
    if (_selectedRowId != null) ids.add(_selectedRowId!);
    return ids.length;
  }

  Set<String> get _selectedIds {
    final ids = <String>{..._bulkSelectedRowIds};
    if (_selectedRowId != null) ids.add(_selectedRowId!);
    return ids;
  }

  double get _selectedWeightKgSum {
    final ids = _selectedIds;
    if (ids.isEmpty) return 0;
    double total = 0;
    for (final row in _rows) {
      final id = row['id'] as String?;
      if (id == null || !ids.contains(id)) continue;
      total += _effectiveNetKgFromRow(row) ?? 0;
    }
    return total;
  }

  double get _selectedWeightKgAvg {
    final count = _selectedCount;
    if (count == 0) return 0;
    return _selectedWeightKgSum / count;
  }

  double get _filteredWeightKg {
    double total = 0;
    for (final row in _filteredRows) {
      total += _effectiveNetKgFromRow(row) ?? 0;
    }
    return total;
  }

  void _scheduleTopBarSync() {
    if (_topBarSyncScheduled || widget.onTopBarChanged == null) return;
    _topBarSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _topBarSyncScheduled = false;
      _notifyTopBarChanged();
    });
  }

  void _notifyTopBarChanged() {
    if (!mounted || widget.onTopBarChanged == null) return;
    widget.onTopBarChanged!(_buildTopBarData());
  }

  InventoryGridTopBarData _buildTopBarData() {
    final activeCell = (_selectedRowState()?.isEditing ?? false)
        ? _activeGridColumnLabel
        : null;
    return InventoryGridTopBarData(
      metricIcon: _isIn ? Icons.download_rounded : Icons.local_shipping_rounded,
      metricLabel: _isIn ? 'NETO ENTRADAS' : 'NETO SALIDAS',
      metricValue: '${_fmtInvCount(_filteredWeightKg)} kg',
      metricSubtitle:
          'Filtrado (${_fmtInvInt(_filteredRows.length)} registros)',
      exportingCsv: _exportingCsv,
      gridEditMode: false,
      canToggleGridEdit: _visibleRows.isNotEmpty,
      canDeleteSelection: _bulkSelectedRowIds.isNotEmpty,
      deletingSelection: _bulkDeleting,
      selectedCount: _selectedCount,
      selectedKgSumLabel: _selectedCount > 0
          ? '${_fmtInvCount(_selectedWeightKgSum)} kg'
          : null,
      selectedKgAvgLabel: _selectedCount > 0
          ? '${_fmtInvCount(_selectedWeightKgAvg)} kg'
          : null,
      activeCellLabel: activeCell,
      onExportCsv: _exportingCsv ? null : _exportCsv,
      onToggleGridEdit: null,
      onSaveGridEdit: null,
      onCancelGridEdit: null,
      onDeleteSelection: _bulkDeleting ? null : _deleteSelectedRows,
    );
  }

  void _handleEnterOnSelectedRow() {
    final editingStates = _editingRowStates();
    final states = editingStates.length > 1
        ? editingStates
        : _selectedRowStates();
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
    final editingStates = _editingRowStates();
    if (editingStates.isNotEmpty) {
      for (final s in editingStates) {
        s.cancelEditingFromKeyboard();
      }
      setState(() {});
      return;
    }
    final states = _selectedRowStates();
    if (states.any((s) => s.isEditing)) {
      for (final s in states) {
        s.cancelEditingFromKeyboard();
      }
      setState(() {});
      return;
    }
    setState(() {
      _selectedRowId = null;
      _selectionAnchorRowId = null;
      _bulkSelectedRowIds.clear();
    });
  }

  void _handleDeleteOnSelectedRow() {
    if (_bulkSelectedRowIds.length > 1) {
      unawaited(_deleteSelectedRows());
      return;
    }
    final s = _selectedRowState();
    if (s != null) unawaited(s.deleteWithConfirmation());
  }

  void _startEditingSelectedRows() {
    final states = _selectedRowStates();
    if (states.isEmpty) return;
    setState(() => _activeGridColumn = 0);
    for (final state in states) {
      state.startEditingFromKeyboard();
    }
    _requestRowsFocus();
  }

  Future<void> _saveSelectedRows() async {
    final states = _selectedRowStates();
    if (states.isEmpty) return;
    await Future.wait(states.map((s) => s.saveFromKeyboard()));
    if (mounted) setState(() {});
    _requestRowsFocus();
  }

  void _cancelSelectedRowsEditing() {
    final states = _selectedRowStates();
    for (final state in states) {
      state.cancelEditingFromKeyboard();
    }
    if (mounted) setState(() {});
    _requestRowsFocus();
  }

  void _moveGridColumn(int delta) {
    setState(() {
      _activeGridColumn =
          ((_activeGridColumn + delta) % _gridColumnCount + _gridColumnCount) %
          _gridColumnCount;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectedRowState()?.focusTextIfNeeded(_activeGridColumn);
    });
  }

  void _moveGridRow(int delta, {bool extendSelection = false}) {
    _moveSelectedRow(delta, extendSelection: extendSelection);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectedRowState()?.focusTextIfNeeded(_activeGridColumn);
    });
  }

  void _activateGridCellFromKeyboard() {
    final state = _selectedRowState();
    if (state == null) return;
    if (!state.isEditing) {
      state.startEditingFromKeyboard();
    }
    unawaited(state.activateGridCell(_activeGridColumn));
  }

  String get _activeGridColumnLabel =>
      (_activeGridColumn >= 0 && _activeGridColumn < _gridColumnLabels.length)
      ? _gridColumnLabels[_activeGridColumn]
      : 'CELDA';

  @override
  Widget build(BuildContext context) {
    if (_loadingCats || _loadingRows) {
      return const Center(child: CircularProgressIndicator());
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onRowsPointerDown,
      onPointerMove: _onRowsPointerMove,
      onPointerUp: (_) => _finishRowsMarqueeSelection(),
      onPointerCancel: (_) => _finishRowsMarqueeSelection(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showTopBarChrome)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
              child: InventoryGridTopBar(data: _buildTopBarData()),
            ),
          _InvHeaderRow(
            counterpartyLabel: _counterpartyLabel,
            hasActiveFilter: _hasActiveFilter,
            onOpenFilter: _openColumnFilter,
          ),
          const SizedBox(height: 8),
          _buildInlineInsertRow(),
          const SizedBox(height: 8),
          Expanded(
            child: Focus(
              focusNode: _rowsFocusNode,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                  return KeyEventResult.ignored;
                }
                final key = event.logicalKey;
                final extendSelection = _isSelectionExtendPressed();
                final selectedState = _selectedRowState();
                final editingAnyRow = _anyRowEditing;
                final keyboardCellMode = editingAnyRow;
                final inTextEditing =
                    selectedState?.isTextCellFocused(_activeGridColumn) ??
                    false;
                final anyTextEditing = _anyEditingRowTextFocused;

                if (keyboardCellMode) {
                  if (key == LogicalKeyboardKey.arrowLeft) {
                    if (inTextEditing &&
                        !(selectedState?.activeTextCaretAtStart(
                              _activeGridColumn,
                            ) ??
                            false)) {
                      return KeyEventResult.ignored;
                    }
                    _moveGridColumn(-1);
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.arrowRight) {
                    if (inTextEditing &&
                        !(selectedState?.activeTextCaretAtEnd(
                              _activeGridColumn,
                            ) ??
                            false)) {
                      return KeyEventResult.ignored;
                    }
                    _moveGridColumn(1);
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.arrowDown) {
                    _moveGridRow(1, extendSelection: extendSelection);
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.arrowUp) {
                    final firstVisible = _visibleRows.isNotEmpty
                        ? _visibleRows.first['id'] as String
                        : null;
                    if (firstVisible != null &&
                        _selectedRowId == firstVisible) {
                      if (extendSelection) {
                        return KeyEventResult.handled;
                      }
                      _focusInsertFromGrid();
                    } else {
                      _moveGridRow(-1, extendSelection: extendSelection);
                    }
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.space) {
                    if (inTextEditing) return KeyEventResult.ignored;
                    _activateGridCellFromKeyboard();
                    return KeyEventResult.handled;
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
                    return anyTextEditing
                        ? KeyEventResult.ignored
                        : KeyEventResult.handled;
                  }
                }

                if (key == LogicalKeyboardKey.arrowDown) {
                  _moveSelectedRow(1, extendSelection: extendSelection);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowUp) {
                  final firstVisible = _visibleRows.isNotEmpty
                      ? _visibleRows.first['id'] as String
                      : null;
                  if (firstVisible == null ||
                      _selectedRowId == null ||
                      _selectedRowId == firstVisible) {
                    if (extendSelection) return KeyEventResult.handled;
                    _focusInsertFromGrid();
                  } else {
                    _moveSelectedRow(-1, extendSelection: extendSelection);
                  }
                  return KeyEventResult.handled;
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
                  if (keyboardCellMode || anyTextEditing || _anyRowEditing) {
                    return KeyEventResult.ignored;
                  }
                  _handleDeleteOnSelectedRow();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: _visibleRows.isEmpty
                  ? const Center(child: Text('No hay movimientos'))
                  : Container(
                      key: _rowsViewportKey,
                      child: ClipRect(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AbsorbPointer(
                              absorbing: _marqueeActive,
                              child: Builder(
                                builder: (_) {
                                  final anySelectedEditing =
                                      _selectedRowStates().any(
                                        (s) => s.isEditing,
                                      );
                                  return ListView.builder(
                                    controller: _rowsScrollController,
                                    padding: const EdgeInsets.only(bottom: 12),
                                    itemCount: _visibleRows.length,
                                    itemBuilder: (_, i) {
                                      final row = _visibleRows[i];
                                      final rowId = row['id'] as String;
                                      return _MovementDataRow(
                                        key: _rowKeyFor(rowId),
                                        row: row,
                                        flow: widget.flow,
                                        counterpartyLabel: _counterpartyLabel,
                                        counterparties: _counterparties,
                                        drivers: _drivers,
                                        vehicles: _vehicles,
                                        commercialMaterialOptions:
                                            _commercialMaterials,
                                        materialsById: {
                                          for (final m in _materials) m.id: m,
                                        },
                                        materialLabel: _materialLabel,
                                        commercialMatchesMaterial:
                                            _commercialMatchesMaterial,
                                        materialOptions: _materials
                                            .map((m) => m.id)
                                            .toList(),
                                        isSelected: _selectedRowId == rowId,
                                        isChecked: _bulkSelectedRowIds.contains(
                                          rowId,
                                        ),
                                        selectedCount: _selectedCount,
                                        anySelectedEditing: anySelectedEditing,
                                        activeGridColumn: _activeGridColumn,
                                        onDelete: _deleteRow,
                                        onUpdate: _updateRow,
                                        onMultiEdit: _startEditingSelectedRows,
                                        onMultiSave: _saveSelectedRows,
                                        onMultiCancel:
                                            _cancelSelectedRowsEditing,
                                        onMultiDelete: _deleteSelectedRows,
                                        onRequestRowsFocus: _requestRowsFocus,
                                        onSelect: (additive) {
                                          _selectRow(
                                            rowId,
                                            additive: additive,
                                            allowToggle: false,
                                          );
                                          _requestRowsFocus();
                                        },
                                        onActivateColumn: (col) {
                                          final rowNeedsSelection =
                                              _selectedRowId != rowId ||
                                              _bulkSelectedRowIds.isNotEmpty;
                                          if (rowNeedsSelection) {
                                            _selectRow(rowId);
                                          }
                                          if (_activeGridColumn != col) {
                                            setState(
                                              () => _activeGridColumn = col,
                                            );
                                          }
                                          if (col != 1 &&
                                              col != 6 &&
                                              col != 7 &&
                                              col != 8 &&
                                              col != 9 &&
                                              col != 10 &&
                                              col != 12) {
                                            _requestRowsFocus();
                                          }
                                        },
                                      );
                                    },
                                  );
                                },
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
            padding: const EdgeInsets.only(top: 8),
            child: Card(
              elevation: 0,
              color: Colors.white.withValues(alpha: 0.30),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: _invActionOutlinedButtonStyle(),
                      onPressed: _currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Anterior'),
                    ),
                    Text(
                      'Página ${_fmtInvInt(_currentPage + 1)} de ${_fmtInvInt(_totalPages)}',
                    ),
                    OutlinedButton.icon(
                      style: _invActionOutlinedButtonStyle(),
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
                        decoration: _invGlassFieldDecoration(),
                        items: const [40, 80, 120]
                            .map(
                              (e) => DropdownMenuItem<int>(
                                value: e,
                                child: Text('$e'),
                              ),
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
                    Text('Total: ${_fmtInvInt(_filteredRows.length)}'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineInsertRow() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: _insertRowActive
            ? [
                BoxShadow(
                  color: const Color(0xFF7FAFD3).withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Card(
        key: _insertRowKey,
        elevation: 0.4,
        color: _insertRowActive
            ? const Color(0xFFD6E9FB)
            : const Color(0xFFD8EAFB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _insertRowActive
                ? const Color(0xFF4E86B5).withValues(alpha: 0.70)
                : const Color(0xFF6F93B3).withValues(alpha: 0.55),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              Widget frame(int col, Widget child) {
                final active = _activeInsertColumn == col;
                return DecoratedBox(
                  position: DecorationPosition.background,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: active
                        ? const Color(0xFFDCEAF7).withValues(alpha: 0.72)
                        : Colors.transparent,
                  ),
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active
                            ? const Color(0xFF0B72FF).withValues(alpha: 0.86)
                            : Colors.transparent,
                        width: active ? 1.1 : 1.0,
                      ),
                    ),
                    child: child,
                  ),
                );
              }

              return Focus(
                focusNode: _insertFocusNode,
                autofocus: false,
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  final key = event.logicalKey;
                  if (key == LogicalKeyboardKey.arrowLeft) {
                    if (_insertGrossFocusNode.hasFocus &&
                        !_caretAtStart(_draftGrossC, _insertGrossFocusNode)) {
                      return KeyEventResult.ignored;
                    }
                    if (_insertTareFocusNode.hasFocus &&
                        !_caretAtStart(_draftTareC, _insertTareFocusNode)) {
                      return KeyEventResult.ignored;
                    }
                    if (_insertHumidityFocusNode.hasFocus &&
                        !_caretAtStart(
                          _draftHumidityC,
                          _insertHumidityFocusNode,
                        )) {
                      return KeyEventResult.ignored;
                    }
                    if (_insertTrashFocusNode.hasFocus &&
                        !_caretAtStart(_draftTrashC, _insertTrashFocusNode)) {
                      return KeyEventResult.ignored;
                    }
                    if (_insertReferenceFocusNode.hasFocus &&
                        !_caretAtStart(
                          _draftReferenceC,
                          _insertReferenceFocusNode,
                        )) {
                      return KeyEventResult.ignored;
                    }
                    if (_insertNotesFocusNode.hasFocus &&
                        !_caretAtStart(_draftNotesC, _insertNotesFocusNode)) {
                      return KeyEventResult.ignored;
                    }
                    _moveInsertColumn(-1);
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.arrowRight) {
                    if (_insertGrossFocusNode.hasFocus &&
                        !_caretAtEnd(_draftGrossC, _insertGrossFocusNode)) {
                      return KeyEventResult.ignored;
                    }
                    if (_insertTareFocusNode.hasFocus &&
                        !_caretAtEnd(_draftTareC, _insertTareFocusNode)) {
                      return KeyEventResult.ignored;
                    }
                    if (_insertHumidityFocusNode.hasFocus &&
                        !_caretAtEnd(
                          _draftHumidityC,
                          _insertHumidityFocusNode,
                        )) {
                      return KeyEventResult.ignored;
                    }
                    if (_insertTrashFocusNode.hasFocus &&
                        !_caretAtEnd(_draftTrashC, _insertTrashFocusNode)) {
                      return KeyEventResult.ignored;
                    }
                    if (_insertReferenceFocusNode.hasFocus &&
                        !_caretAtEnd(
                          _draftReferenceC,
                          _insertReferenceFocusNode,
                        )) {
                      return KeyEventResult.ignored;
                    }
                    if (_insertNotesFocusNode.hasFocus &&
                        !_caretAtEnd(_draftNotesC, _insertNotesFocusNode)) {
                      return KeyEventResult.ignored;
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
                    if (_isInsertTextFocused) return KeyEventResult.ignored;
                    unawaited(_activateInsertCellFromKeyboard());
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.delete ||
                      key == LogicalKeyboardKey.backspace) {
                    if (_isInsertTextFocused) return KeyEventResult.ignored;
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
                    unawaited(_insertDraft());
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: _kInvTableContentW,
                      child: Row(
                        children: [
                          frame(
                            0,
                            SizedBox(
                              width: 90,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  _setActiveInsertColumn(0);
                                  final d = await _pickDate(_draft.opDate);
                                  if (!mounted || d == null) return;
                                  setState(
                                    () => _draft = _draft.copyWith(
                                      opDate: DateUtils.dateOnly(d),
                                    ),
                                  );
                                },
                                child: InputDecorator(
                                  decoration: _invGlassFieldDecoration(),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _draft.opDate == null
                                                ? '—'
                                                : _fmtUiDate(_draft.opDate!),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.calendar_month,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          frame(
                            1,
                            SizedBox(
                              width: _kInvRefColW,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: TextField(
                                  controller: _draftReferenceC,
                                  focusNode: _insertReferenceFocusNode,
                                  decoration: _invGlassFieldDecoration(
                                    hintText: 'Ticket / folio',
                                    suppressFocusedBorder: true,
                                    hideBorder: _activeInsertColumn == 1,
                                  ),
                                  onTap: () => _setActiveInsertColumn(
                                    1,
                                    requestFocus: false,
                                  ),
                                  onChanged: (t) => setState(
                                    () =>
                                        _draft = _draft.copyWith(reference: t),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          frame(
                            2,
                            SizedBox(
                              width: 190,
                              child: _InvDropOptInline(
                                valueId: _draft.materialId,
                                items: _materials
                                    .map(
                                      (m) => _InvOpt(id: m.id, label: m.name),
                                    )
                                    .toList(),
                                onTapStart: () => _setActiveInsertColumn(2),
                                onChanged: (v) => setState(
                                  () => _draft = _draft.copyWith(materialId: v),
                                ),
                              ),
                            ),
                          ),
                          frame(
                            3,
                            SizedBox(
                              width: _kInvCounterpartyColW,
                              child: _InvDropOptInline(
                                valueId: _draft.counterpartySiteId,
                                items: _counterparties,
                                onTapStart: () => _setActiveInsertColumn(3),
                                onChanged: (v) => setState(
                                  () => _draft = _draft.copyWith(
                                    counterpartySiteId: v,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          frame(
                            4,
                            SizedBox(
                              width: 190,
                              child: _InvDropOptInline(
                                valueId: _draft.driverEmployeeId,
                                items: _drivers,
                                onTapStart: () => _setActiveInsertColumn(4),
                                onChanged: (v) => setState(
                                  () => _draft = _draft.copyWith(
                                    driverEmployeeId: v,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          frame(
                            5,
                            SizedBox(
                              width: 140,
                              child: _InvDropOptInline(
                                valueId: _draft.vehicleId,
                                items: _vehicles,
                                onTapStart: () => _setActiveInsertColumn(5),
                                onChanged: (v) => setState(
                                  () => _draft = _draft.copyWith(vehicleId: v),
                                ),
                              ),
                            ),
                          ),
                          frame(
                            6,
                            SizedBox(
                              width: _kInvGrossColW,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: TextField(
                                  controller: _draftGrossC,
                                  focusNode: _insertGrossFocusNode,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _invGlassFieldDecoration(
                                    hintText: 'Bruto kg',
                                    suppressFocusedBorder: true,
                                    hideBorder: _activeInsertColumn == 6,
                                  ),
                                  onTap: () => _setActiveInsertColumn(
                                    6,
                                    requestFocus: false,
                                  ),
                                  onChanged: (_) => setState(
                                    () => _draft = _draftWithComputed(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          frame(
                            7,
                            SizedBox(
                              width: _kInvTareColW,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: TextField(
                                  controller: _draftTareC,
                                  focusNode: _insertTareFocusNode,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _invGlassFieldDecoration(
                                    hintText: 'Tara kg',
                                    suppressFocusedBorder: true,
                                    hideBorder: _activeInsertColumn == 7,
                                  ),
                                  onTap: () => _setActiveInsertColumn(
                                    7,
                                    requestFocus: false,
                                  ),
                                  onChanged: (_) => setState(
                                    () => _draft = _draftWithComputed(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          frame(
                            8,
                            SizedBox(
                              width: _kInvKgColW,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _draft.netKg == null
                                        ? '—'
                                        : '${_fmtInvCount(_draft.netKg!)} kg',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          frame(
                            9,
                            SizedBox(
                              width: _kInvHumidityColW,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: TextField(
                                  controller: _draftHumidityC,
                                  focusNode: _insertHumidityFocusNode,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _invGlassFieldDecoration(
                                    hintText: 'Humedad %',
                                    suppressFocusedBorder: true,
                                    hideBorder: _activeInsertColumn == 9,
                                  ),
                                  onTap: () => _setActiveInsertColumn(
                                    9,
                                    requestFocus: false,
                                  ),
                                  onChanged: (_) => setState(
                                    () => _draft = _draftWithComputed(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          frame(
                            10,
                            SizedBox(
                              width: _kInvTrashColW,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: TextField(
                                  controller: _draftTrashC,
                                  focusNode: _insertTrashFocusNode,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _invGlassFieldDecoration(
                                    hintText: 'Basura kg',
                                    suppressFocusedBorder: true,
                                    hideBorder: _activeInsertColumn == 10,
                                  ),
                                  onTap: () => _setActiveInsertColumn(
                                    10,
                                    requestFocus: false,
                                  ),
                                  onChanged: (_) => setState(
                                    () => _draft = _draftWithComputed(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          frame(
                            11,
                            SizedBox(
                              width: _kInvAmountColW,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _draft.totalAmountKg == null
                                        ? '—'
                                        : _fmtInvCount(_draft.totalAmountKg!),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          frame(
                            12,
                            SizedBox(
                              width: _kInvNotesColW,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: TextField(
                                  controller: _draftNotesC,
                                  focusNode: _insertNotesFocusNode,
                                  decoration: _invGlassFieldDecoration(
                                    hintText: 'Comentario / notas',
                                    suppressFocusedBorder: true,
                                    hideBorder: _activeInsertColumn == 12,
                                  ),
                                  onTap: () => _setActiveInsertColumn(
                                    12,
                                    requestFocus: false,
                                  ),
                                  onChanged: (t) => setState(
                                    () => _draft = _draft.copyWith(notes: t),
                                  ),
                                  onSubmitted: (_) {
                                    _insertDraft();
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          frame(
                            13,
                            SizedBox(
                              width: _kInvActionsW,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Tooltip(
                                    message: _draftHasExtras
                                        ? 'EXTRAS configurados'
                                        : 'Agregar calidad y origen',
                                    child: MouseRegion(
                                      onEnter: (_) => setState(
                                        () => _hoverInsertExtrasButton = true,
                                      ),
                                      onExit: (_) => setState(
                                        () => _hoverInsertExtrasButton = false,
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: _editDraftExtras,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 120,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          width: 98,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: _draftHasExtras
                                                ? const Color(
                                                    0xFFD7F2E6,
                                                  ).withValues(alpha: 0.88)
                                                : Colors.white.withValues(
                                                    alpha: 0.40,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.62,
                                              ),
                                            ),
                                            boxShadow: _hoverInsertExtrasButton
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.16,
                                                          ),
                                                      blurRadius: 14,
                                                      offset: const Offset(
                                                        0,
                                                        7,
                                                      ),
                                                    ),
                                                  ]
                                                : [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.08,
                                                          ),
                                                      blurRadius: 8,
                                                      offset: const Offset(
                                                        0,
                                                        4,
                                                      ),
                                                    ),
                                                  ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              'EXTRAS',
                                              style: TextStyle(
                                                fontSize: 11,
                                                letterSpacing: 0.2,
                                                fontWeight: FontWeight.w900,
                                                color: _draftHasExtras
                                                    ? const Color(0xFF1A4F36)
                                                    : const Color(0xFF274A63),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: 'AGREGAR',
                                    child: MouseRegion(
                                      onEnter: (_) => setState(
                                        () => _hoverInsertAddButton = true,
                                      ),
                                      onExit: (_) => setState(
                                        () => _hoverInsertAddButton = false,
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: _inserting ? null : _insertDraft,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 120,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: _inserting
                                                ? Colors.white.withValues(
                                                    alpha: 0.35,
                                                  )
                                                : const Color(
                                                    0xFF19C37D,
                                                  ).withValues(alpha: 0.92),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.52,
                                              ),
                                            ),
                                            boxShadow:
                                                _hoverInsertAddButton &&
                                                    !_inserting
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.16,
                                                          ),
                                                      blurRadius: 14,
                                                      offset: const Offset(
                                                        0,
                                                        7,
                                                      ),
                                                    ),
                                                  ]
                                                : [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.08,
                                                          ),
                                                      blurRadius: 8,
                                                      offset: const Offset(
                                                        0,
                                                        4,
                                                      ),
                                                    ),
                                                  ],
                                          ),
                                          child: _inserting
                                              ? const Padding(
                                                  padding: EdgeInsets.all(8.0),
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.add,
                                                  size: 18,
                                                  color: Colors.white,
                                                ),
                                        ),
                                      ),
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InvHeaderRow extends StatelessWidget {
  final String counterpartyLabel;
  final bool Function(String) hasActiveFilter;
  final void Function(String columnId, String label) onOpenFilter;

  const _InvHeaderRow({
    required this.counterpartyLabel,
    required this.hasActiveFilter,
    required this.onOpenFilter,
  });

  @override
  Widget build(BuildContext context) {
    const s = TextStyle(fontSize: 12, fontWeight: FontWeight.w800);
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
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: _kInvTableContentW,
                  child: Row(
                    children: [
                      _InvHCell(
                        'FECHA',
                        90,
                        s,
                        active: hasActiveFilter('fecha'),
                        onFilter: () => onOpenFilter('fecha', 'FECHA'),
                      ),
                      _InvHCell(
                        'TICKET',
                        _kInvRefColW,
                        s,
                        active: hasActiveFilter('reference'),
                        onFilter: () => onOpenFilter('reference', 'TICKET'),
                      ),
                      _InvHCell(
                        'MATERIAL',
                        190,
                        s,
                        active: hasActiveFilter('material'),
                        onFilter: () => onOpenFilter('material', 'MATERIAL'),
                      ),
                      _InvHCell(
                        counterpartyLabel,
                        _kInvCounterpartyColW,
                        s,
                        active: hasActiveFilter('counterparty'),
                        onFilter: () =>
                            onOpenFilter('counterparty', counterpartyLabel),
                      ),
                      _InvHCell(
                        'CHOFER',
                        190,
                        s,
                        active: hasActiveFilter('chofer'),
                        onFilter: () => onOpenFilter('chofer', 'CHOFER'),
                      ),
                      _InvHCell(
                        'UNIDAD',
                        140,
                        s,
                        active: hasActiveFilter('unidad'),
                        onFilter: () => onOpenFilter('unidad', 'UNIDAD'),
                      ),
                      _InvHCell(
                        'BRUTO',
                        _kInvGrossColW,
                        s,
                        active: hasActiveFilter('bruto'),
                        onFilter: () => onOpenFilter('bruto', 'BRUTO'),
                      ),
                      _InvHCell(
                        'TARA',
                        _kInvTareColW,
                        s,
                        active: hasActiveFilter('tara'),
                        onFilter: () => onOpenFilter('tara', 'TARA'),
                      ),
                      _InvHCell(
                        'NETO KG',
                        _kInvKgColW,
                        s,
                        active: hasActiveFilter('kg'),
                        onFilter: () => onOpenFilter('kg', 'NETO KG'),
                      ),
                      _InvHCell(
                        'HUMEDAD %',
                        _kInvHumidityColW,
                        s,
                        active: hasActiveFilter('humedad'),
                        onFilter: () => onOpenFilter('humedad', 'HUMEDAD %'),
                      ),
                      _InvHCell(
                        'BASURA',
                        _kInvTrashColW,
                        s,
                        active: hasActiveFilter('basura'),
                        onFilter: () => onOpenFilter('basura', 'BASURA'),
                      ),
                      _InvHCell(
                        'IMPORTE',
                        _kInvAmountColW,
                        s,
                        active: hasActiveFilter('importe'),
                        onFilter: () => onOpenFilter('importe', 'IMPORTE'),
                      ),
                      SizedBox(
                        width: _kInvNotesColW,
                        child: _InvHCellExpand(
                          'COMENTARIO',
                          s,
                          active: hasActiveFilter('notes'),
                          onFilter: () => onOpenFilter('notes', 'COMENTARIO'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const SizedBox(width: _kInvActionsW),
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

class _InvHCell extends StatelessWidget {
  final String t;
  final double w;
  final TextStyle s;
  final bool active;
  final VoidCallback onFilter;
  const _InvHCell(
    this.t,
    this.w,
    this.s, {
    required this.active,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: w,
      child: _InvHCellExpand(t, s, active: active, onFilter: onFilter),
    );
  }
}

class _InvHCellExpand extends StatelessWidget {
  final String t;
  final TextStyle s;
  final bool active;
  final VoidCallback onFilter;
  const _InvHCellExpand(
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
                  ? _kInvFilterAccent
                  : _kInvFilterAccentSoft.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active
                    ? _kInvFilterAccent.withValues(alpha: 0.55)
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

class _MarqueeSelectionPainter extends CustomPainter {
  final Rect rect;

  const _MarqueeSelectionPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    if (rect.isEmpty) return;
    final fill = Paint()
      ..color = const Color(0xFF4B8DBD).withValues(alpha: 0.18);
    final stroke = Paint()
      ..color = const Color(0xFF3C7FB0).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
  }

  @override
  bool shouldRepaint(covariant _MarqueeSelectionPainter oldDelegate) =>
      oldDelegate.rect != rect;
}

class _MovementDataRow extends StatefulWidget {
  final Map<String, dynamic> row;
  final String flow;
  final String counterpartyLabel;
  final List<_InvOpt> counterparties;
  final List<_InvOpt> drivers;
  final List<_InvOpt> vehicles;
  final List<_CommercialMaterialOpt> commercialMaterialOptions;
  final Map<String, _InvMaterialOpt> materialsById;
  final String Function(String?) materialLabel;
  final bool Function(_CommercialMaterialOpt, String?, String?)
  commercialMatchesMaterial;
  final List<String> materialOptions;
  final bool isSelected;
  final bool isChecked;
  final int selectedCount;
  final bool anySelectedEditing;
  final int activeGridColumn;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(String id, Map<String, dynamic> patch) onUpdate;
  final VoidCallback? onMultiEdit;
  final Future<void> Function()? onMultiSave;
  final VoidCallback? onMultiCancel;
  final Future<void> Function()? onMultiDelete;
  final VoidCallback onRequestRowsFocus;
  final ValueChanged<bool> onSelect;
  final ValueChanged<int> onActivateColumn;

  const _MovementDataRow({
    super.key,
    required this.row,
    required this.flow,
    required this.counterpartyLabel,
    required this.counterparties,
    required this.drivers,
    required this.vehicles,
    required this.commercialMaterialOptions,
    required this.materialsById,
    required this.materialLabel,
    required this.commercialMatchesMaterial,
    required this.materialOptions,
    required this.isSelected,
    required this.isChecked,
    required this.selectedCount,
    required this.anySelectedEditing,
    required this.activeGridColumn,
    required this.onDelete,
    required this.onUpdate,
    this.onMultiEdit,
    this.onMultiSave,
    this.onMultiCancel,
    this.onMultiDelete,
    required this.onRequestRowsFocus,
    required this.onSelect,
    required this.onActivateColumn,
  });

  @override
  State<_MovementDataRow> createState() => _MovementDataRowState();
}

class _MovementDataRowState extends State<_MovementDataRow> {
  bool _editing = false;
  bool _hovering = false;
  int? _hoveredEditableColumn;
  bool _hoverActionsButton = false;

  late DateTime _opDate;
  String? _material;
  String? _counterpartySiteId;
  String? _driverId;
  String? _vehicleId;
  String? _commercialMaterialCode;
  String? _movementReason;
  double? _grossKg;
  double? _tareKg;
  double? _humidityPercent;
  double? _trashKg;

  final TextEditingController _weightC = TextEditingController();
  final TextEditingController _grossC = TextEditingController();
  final TextEditingController _tareC = TextEditingController();
  final TextEditingController _humidityC = TextEditingController();
  final TextEditingController _trashC = TextEditingController();
  final TextEditingController _referenceC = TextEditingController();
  final TextEditingController _notesC = TextEditingController();
  final TextEditingController _scaleTicketC = TextEditingController();

  final FocusNode _grossFocusNode = FocusNode(debugLabel: 'row_gross');
  final FocusNode _tareFocusNode = FocusNode(debugLabel: 'row_tare');
  final FocusNode _humidityFocusNode = FocusNode(debugLabel: 'row_humidity');
  final FocusNode _trashFocusNode = FocusNode(debugLabel: 'row_trash');
  final FocusNode _referenceFocusNode = FocusNode(debugLabel: 'row_ref');
  final FocusNode _notesFocusNode = FocusNode(debugLabel: 'row_notes');

  String get id => widget.row['id'] as String;
  bool get isEditing => _editing;

  @override
  void initState() {
    super.initState();
    _syncFromRow();
  }

  @override
  void didUpdateWidget(covariant _MovementDataRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.row != oldWidget.row && !_editing) {
      _syncFromRow();
    }
  }

  @override
  void dispose() {
    _weightC.dispose();
    _grossC.dispose();
    _tareC.dispose();
    _humidityC.dispose();
    _trashC.dispose();
    _referenceC.dispose();
    _notesC.dispose();
    _scaleTicketC.dispose();
    _grossFocusNode.dispose();
    _tareFocusNode.dispose();
    _humidityFocusNode.dispose();
    _trashFocusNode.dispose();
    _referenceFocusNode.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  void _syncFromRow() {
    final r = widget.row;
    _opDate = _parseDate(r['op_date']);
    _material = (r['material_id'] ?? '').toString();
    if (_material != null && _material!.isEmpty) {
      _material = null;
    }
    _counterpartySiteId = r['counterparty_site_id'] as String?;
    _driverId = r['driver_employee_id'] as String?;
    _vehicleId = r['vehicle_id'] as String?;
    _commercialMaterialCode = r['commercial_material_code'] as String?;
    _movementReason = r['movement_reason'] as String?;
    _grossKg = _toDouble(r['gross_kg']);
    _tareKg = _toDouble(r['tare_kg']);
    final storedNetKg = _toDouble(r['net_kg']) ?? _toDouble(r['weight_kg']);
    _humidityPercent = _toDouble(r['humidity_percent']);
    _trashKg = _toDouble(r['trash_kg']);
    _grossC.text = _grossKg?.toStringAsFixed(2) ?? '';
    _tareC.text = _tareKg?.toStringAsFixed(2) ?? '';
    _humidityC.text = _humidityPercent?.toStringAsFixed(2) ?? '';
    _trashC.text = _trashKg?.toStringAsFixed(2) ?? '';
    final computedNetFromGross = (_grossKg == null || _grossKg! <= 0)
        ? null
        : math.max(0, _grossKg! - (_tareKg ?? 0)).toDouble();
    final effectiveNet = computedNetFromGross ?? storedNetKg;
    _weightC.text = effectiveNet?.toStringAsFixed(2) ?? '';
    _referenceC.text = (r['reference'] ?? '').toString();
    _notesC.text = (r['notes'] ?? '').toString();
    _scaleTicketC.text = (r['scale_ticket'] ?? '').toString();
  }

  DateTime _parseDate(dynamic v) {
    if (v is String && v.length >= 10) {
      final y = int.tryParse(v.substring(0, 4));
      final m = int.tryParse(v.substring(5, 7));
      final d = int.tryParse(v.substring(8, 10));
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return DateUtils.dateOnly(DateTime.now());
  }

  double? _rowEffectiveNetKg({
    required double? netKg,
    required double? grossKg,
    required double? tareKg,
  }) {
    if (netKg != null && netKg > 0) return netKg;
    if (grossKg == null || grossKg <= 0) return null;
    final tare = tareKg == null || tareKg < 0 ? 0 : tareKg;
    return math.max(0, grossKg - tare).toDouble();
  }

  double _rowTotalAmountKg({
    required double netKg,
    required double? humidityPercent,
    required double? trashKg,
  }) {
    final humidity = humidityPercent == null || humidityPercent < 0
        ? 0.0
        : humidityPercent;
    final trash = trashKg == null || trashKg < 0 ? 0.0 : trashKg;
    final humidityDiscount = netKg * (humidity / 100.0);
    return math.max(0, netKg - humidityDiscount - trash).toDouble();
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

  void startEditingFromKeyboard() {
    if (_editing) return;
    setState(() => _editing = true);
  }

  void cancelEditingFromKeyboard() {
    if (!_editing) return;
    _syncFromRow();
    setState(() => _editing = false);
  }

  Future<void> saveFromKeyboard() async {
    if (!_editing) return;
    await _save();
  }

  Future<void> deleteWithConfirmation() async {
    final ok = await _showConfirmDialog(
      context,
      title: 'Eliminar movimiento',
      content: '¿Seguro que quieres eliminarlo?',
      confirmText: 'Eliminar',
    );
    if (ok == true) {
      await widget.onDelete(id);
    }
  }

  bool isTextCellFocused(int col) {
    if (!_editing) return false;
    return switch (col) {
      1 => _referenceFocusNode.hasFocus,
      6 => _grossFocusNode.hasFocus,
      7 => _tareFocusNode.hasFocus,
      9 => _humidityFocusNode.hasFocus,
      10 => _trashFocusNode.hasFocus,
      12 => _notesFocusNode.hasFocus,
      _ => false,
    };
  }

  bool get isAnyTextFocused =>
      _referenceFocusNode.hasFocus ||
      _grossFocusNode.hasFocus ||
      _tareFocusNode.hasFocus ||
      _humidityFocusNode.hasFocus ||
      _trashFocusNode.hasFocus ||
      _notesFocusNode.hasFocus;

  bool activeTextCaretAtStart(int col) {
    return switch (col) {
      1 => _caretAtStart(_referenceC, _referenceFocusNode),
      6 => _caretAtStart(_grossC, _grossFocusNode),
      7 => _caretAtStart(_tareC, _tareFocusNode),
      9 => _caretAtStart(_humidityC, _humidityFocusNode),
      10 => _caretAtStart(_trashC, _trashFocusNode),
      12 => _caretAtStart(_notesC, _notesFocusNode),
      _ => true,
    };
  }

  bool activeTextCaretAtEnd(int col) {
    return switch (col) {
      1 => _caretAtEnd(_referenceC, _referenceFocusNode),
      6 => _caretAtEnd(_grossC, _grossFocusNode),
      7 => _caretAtEnd(_tareC, _tareFocusNode),
      9 => _caretAtEnd(_humidityC, _humidityFocusNode),
      10 => _caretAtEnd(_trashC, _trashFocusNode),
      12 => _caretAtEnd(_notesC, _notesFocusNode),
      _ => true,
    };
  }

  bool _caretAtStart(TextEditingController c, FocusNode f) {
    if (!f.hasFocus) return false;
    final s = c.selection;
    return s.isValid &&
        s.isCollapsed &&
        s.baseOffset == 0 &&
        s.extentOffset == 0;
  }

  bool _caretAtEnd(TextEditingController c, FocusNode f) {
    if (!f.hasFocus) return false;
    final s = c.selection;
    final end = c.text.length;
    return s.isValid &&
        s.isCollapsed &&
        s.baseOffset == end &&
        s.extentOffset == end;
  }

  void focusTextIfNeeded(int col) {
    if (!_editing) return;
    if (col == 12) {
      focusCommentField();
    }
  }

  void focusCommentField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_notesFocusNode);
      _notesC.selection = TextSelection.collapsed(offset: _notesC.text.length);
    });
  }

  Future<void> activateGridCell(int col) async {
    if (!_editing) return;
    switch (col) {
      case 0:
        final d = await _showInvKeyboardDatePickerDialog(
          context: context,
          initialDate: _opDate,
          firstDate: DateTime(2024, 1, 1),
          lastDate: DateTime(2035, 12, 31),
        );
        if (d != null) setState(() => _opDate = DateUtils.dateOnly(d));
        return;
      case 1:
        FocusScope.of(context).requestFocus(_referenceFocusNode);
        return;
      case 2:
        final mat = await _showInvSearchablePickerDialog<String>(
          context,
          title: 'Material',
          initialValue: _material,
          options: widget.materialOptions
              .map(
                (m) => _InvPickerOption<String>(
                  value: m,
                  label: widget.materialLabel(m),
                ),
              )
              .toList(),
        );
        if (mat != null) setState(() => _material = mat);
        return;
      case 3:
        final cp = await _showInvSearchablePickerDialog<String>(
          context,
          title: widget.counterpartyLabel,
          initialValue: _counterpartySiteId,
          options: widget.counterparties
              .map((o) => _InvPickerOption<String>(value: o.id, label: o.label))
              .toList(),
        );
        if (!mounted) return;
        setState(() => _counterpartySiteId = cp);
        return;
      case 4:
        final dr = await _showInvSearchablePickerDialog<String>(
          context,
          title: 'Chofer',
          initialValue: _driverId,
          options: widget.drivers
              .map((o) => _InvPickerOption<String>(value: o.id, label: o.label))
              .toList(),
        );
        if (!mounted) return;
        setState(() => _driverId = dr);
        return;
      case 5:
        final vh = await _showInvSearchablePickerDialog<String>(
          context,
          title: 'Unidad',
          initialValue: _vehicleId,
          options: widget.vehicles
              .map((o) => _InvPickerOption<String>(value: o.id, label: o.label))
              .toList(),
        );
        if (!mounted) return;
        setState(() => _vehicleId = vh);
        return;
      case 6:
        FocusScope.of(context).requestFocus(_grossFocusNode);
        return;
      case 7:
        FocusScope.of(context).requestFocus(_tareFocusNode);
        return;
      case 9:
        FocusScope.of(context).requestFocus(_humidityFocusNode);
        return;
      case 10:
        FocusScope.of(context).requestFocus(_trashFocusNode);
        return;
      case 12:
        focusCommentField();
        return;
      case 13:
        await _editExtras();
        return;
      default:
        return;
    }
  }

  void _enterEditingFromPointer(int col) {
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

  void _previewEditableCellTap(int col) {
    if (_isAdditiveSelectionPressed()) {
      widget.onSelect(true);
      return;
    }
    widget.onSelect(false);
    widget.onActivateColumn(col);
  }

  ({Color bg, Color fg}) _materialChipColors(String label) {
    final key = label.trim().toUpperCase();
    if (key.contains('METAL')) {
      return (bg: const Color(0xFFD9E6F7), fg: const Color(0xFF24435E));
    }
    if (key.contains('CARTON')) {
      return (bg: const Color(0xFFD2EEE9), fg: const Color(0xFF1F4F4B));
    }
    if (key.contains('CHATARRA')) {
      return (bg: const Color(0xFFE0DCF7), fg: const Color(0xFF3F3A6C));
    }
    return (bg: const Color(0xFFE2E8F2), fg: const Color(0xFF31475F));
  }

  Future<void> _handleRowAction(String v) async {
    final multiContext =
        widget.selectedCount > 1 && (widget.isSelected || widget.isChecked);
    if (v == 'edit') {
      if (multiContext && widget.onMultiEdit != null) {
        widget.onMultiEdit!.call();
        return;
      }
      setState(() => _editing = true);
      return;
    }
    if (v == 'extras') {
      await _editExtras();
      return;
    }
    if (v == 'save') {
      if (multiContext && widget.onMultiSave != null) {
        await widget.onMultiSave!.call();
        return;
      }
      await _save();
      return;
    }
    if (v == 'cancel') {
      if (multiContext && widget.onMultiCancel != null) {
        widget.onMultiCancel!.call();
        return;
      }
      cancelEditingFromKeyboard();
      return;
    }
    if (v == 'delete') {
      if (multiContext && widget.onMultiDelete != null) {
        await widget.onMultiDelete!.call();
        return;
      }
      await deleteWithConfirmation();
    }
  }

  List<MapEntry<String, String>> _rowContextActions() {
    final multiContext =
        widget.selectedCount > 1 && (widget.isSelected || widget.isChecked);
    if (multiContext) {
      return <MapEntry<String, String>>[
        if (!widget.anySelectedEditing)
          const MapEntry('edit', 'EDITAR SELECCION'),
        if (widget.anySelectedEditing) ...const [
          MapEntry('save', 'GUARDAR SELECCION'),
          MapEntry('cancel', 'CANCELAR SELECCION'),
        ],
        const MapEntry('delete', 'ELIMINAR SELECCION'),
      ];
    }
    return <MapEntry<String, String>>[
      if (!_editing) const MapEntry('edit', 'EDITAR'),
      const MapEntry('extras', 'EXTRAS'),
      if (_editing) ...const [
        MapEntry('save', 'ACTUALIZAR'),
        MapEntry('cancel', 'CANCELAR'),
      ],
      const MapEntry('delete', 'ELIMINAR'),
    ];
  }

  Future<String?> _showKeyboardContextMenu(Offset globalPosition) {
    final actions = _rowContextActions();
    final mediaSize = MediaQuery.of(context).size;
    const menuWidth = 200.0;
    final left = globalPosition.dx.clamp(
      8.0,
      mediaSize.width - menuWidth - 8.0,
    );
    final top = globalPosition.dy.clamp(8.0, mediaSize.height - 8.0);
    return showGeneralDialog<String>(
      context: context,
      barrierLabel: 'context_menu',
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 90),
      pageBuilder: (dialogContext, _, _) {
        int? hoveredIndex;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.of(dialogContext).pop(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: menuWidth,
              child: StatefulBuilder(
                builder: (context, setMenuState) {
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
                        if (actions.isEmpty) return KeyEventResult.handled;
                        final activeIndex = (hoveredIndex ?? 0).clamp(
                          0,
                          actions.length - 1,
                        );
                        Navigator.of(
                          dialogContext,
                        ).pop(actions[activeIndex].key);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Material(
                      color: Colors.transparent,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF9FC8E7).withValues(alpha: 0.78),
                              const Color(0xFFB9CCE8).withValues(alpha: 0.72),
                              const Color(0xFF9ED7D6).withValues(alpha: 0.70),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(
                              0xFFE5F1FB,
                            ).withValues(alpha: 0.78),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF76A6C2,
                              ).withValues(alpha: 0.22),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 6,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < actions.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color:
                                      (actions[i].key == 'delete'
                                              ? const Color(0xFF87AFC9)
                                              : const Color(0xFFE5F1FB))
                                          .withValues(alpha: 0.62),
                                ),
                              MouseRegion(
                                onEnter: (_) =>
                                    setMenuState(() => hoveredIndex = i),
                                onExit: (_) => setMenuState(() {
                                  if (hoveredIndex == i) hoveredIndex = null;
                                }),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  splashColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  onTap: () => Navigator.of(
                                    dialogContext,
                                  ).pop(actions[i].key),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 1),
                                    curve: Curves.linear,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: hoveredIndex == i
                                          ? const Color(
                                              0xFFE9F7EE,
                                            ).withValues(alpha: 0.95)
                                          : Colors.transparent,
                                      border: hoveredIndex == i
                                          ? Border.all(
                                              color: const Color(
                                                0xFFBFD8D3,
                                              ).withValues(alpha: 0.62),
                                            )
                                          : null,
                                      boxShadow: hoveredIndex == i
                                          ? [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFFBFD8D3,
                                                ).withValues(alpha: 0.48),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        actions[i].value,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: hoveredIndex == i
                                              ? const Color(0xFF215A56)
                                              : const Color(0xFF173248),
                                        ),
                                      ),
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
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openContextMenuAt(Offset globalPosition) async {
    if (!mounted) return;
    final keepMultiSelection =
        widget.selectedCount > 1 && (widget.isSelected || widget.isChecked);
    if (!keepMultiSelection) {
      widget.onSelect(false);
    }
    final selected = await _showKeyboardContextMenu(globalPosition);
    if (!mounted) return;
    if (selected != null) {
      await _handleRowAction(selected);
    }
    widget.onRequestRowsFocus();
  }

  String? _labelOf(List<_InvOpt> list, String? id) {
    if (id == null) return null;
    for (final o in list) {
      if (o.id == id) return o.label;
    }
    return null;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  _CommercialMaterialOpt? _commercialByCode(String? code) {
    if (code == null) return null;
    final key = code.trim();
    if (key.isEmpty) return null;
    for (final c in widget.commercialMaterialOptions) {
      if (c.code == key) return c;
    }
    return null;
  }

  Future<void> _save({bool keepEditing = false}) async {
    final grossText = _grossC.text.trim();
    final tareText = _tareC.text.trim();
    final humidityText = _humidityC.text.trim();
    final trashText = _trashC.text.trim();
    final grossKg = _toDouble(grossText);
    final tareKg = _toDouble(tareText);
    final humidityPercent = _toDouble(humidityText);
    final trashKg = _toDouble(trashText);

    if (grossText.isNotEmpty && (grossKg == null || grossKg <= 0)) {
      _toast('Bruto debe ser mayor a 0');
      return;
    }
    if (tareText.isNotEmpty && tareKg == null) {
      _toast('Tara inválida');
      return;
    }
    if (humidityText.isNotEmpty && humidityPercent == null) {
      _toast('Humedad inválida');
      return;
    }
    if (trashText.isNotEmpty && trashKg == null) {
      _toast('Basura inválida');
      return;
    }

    final storedNetKg =
        _toDouble(widget.row['net_kg']) ?? _toDouble(widget.row['weight_kg']);
    final netKg = (grossKg == null || grossKg <= 0)
        ? storedNetKg
        : math.max(0, grossKg - (tareKg ?? 0)).toDouble();
    if (_material == null) {
      _toast('Material es obligatorio');
      return;
    }
    if (netKg == null || netKg <= 0) {
      _toast('Peso neto debe ser mayor a 0');
      return;
    }
    final selectedMaterial = widget.materialsById[_material!];
    if (selectedMaterial == null) {
      _toast('Material no válido para actualizar');
      return;
    }
    final extrasError = _movementExtrasRequiredError(
      flow: widget.flow,
      inventoryGeneralCode: selectedMaterial.inventoryGeneralCode,
      commercialMaterialCode: _commercialMaterialCode,
      movementReason: _movementReason,
    );
    if (extrasError != null) {
      _toast(extrasError);
      return;
    }
    final commercial = _commercialByCode(_commercialMaterialCode);
    final invCode = (commercial?.inventoryMaterial ?? '').trim().toUpperCase();
    if (commercial == null || invCode.isEmpty) {
      _toast(
        'El material comercial seleccionado no tiene material operativo configurado en catálogo.',
      );
      return;
    }
    final totalAmountKg = _rowTotalAmountKg(
      netKg: netKg,
      humidityPercent: humidityPercent,
      trashKg: trashKg,
    );
    final patch = <String, dynamic>{
      'op_date': _fmtDbDate(_opDate),
      'material_id': _material,
      'material': invCode,
      'weight_kg': netKg,
      'gross_kg': grossKg,
      'tare_kg': tareKg,
      'net_kg': netKg,
      'humidity_percent': humidityPercent,
      'trash_kg': trashKg,
      'total_amount_kg': totalAmountKg,
      'counterparty_site_id': _counterpartySiteId,
      'driver_employee_id': _driverId,
      'vehicle_id': _vehicleId,
      'counterparty': _labelOf(widget.counterparties, _counterpartySiteId),
      'commercial_material_code': _commercialMaterialCode,
      'movement_reason': _isInFlow(widget.flow) ? _movementReason : null,
      'scale_ticket': _scaleTicketC.text.trim().isEmpty
          ? null
          : _scaleTicketC.text.trim(),
      'reference': _referenceC.text.trim().isEmpty
          ? null
          : _referenceC.text.trim(),
      'notes': _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
    };
    await widget.onUpdate(id, patch);
    if (mounted) setState(() => _editing = keepEditing);
  }

  Future<void> _editExtras() async {
    final sourceCode = _material == null
        ? null
        : widget.materialsById[_material!]?.inventoryMaterialCode ??
              widget.materialsById[_material!]?.inventoryGeneralCode;
    final filteredCommercials = _material == null
        ? widget.commercialMaterialOptions
        : widget.commercialMaterialOptions
              .where(
                (o) =>
                    widget.commercialMatchesMaterial(o, _material, sourceCode),
              )
              .toList();
    final result = await _showMovementExtrasDialog(
      context,
      flow: widget.flow,
      materialLabel: widget.materialLabel(_material),
      inventoryMaterialCode: _material == null
          ? null
          : widget.materialsById[_material!]?.inventoryMaterialCode,
      inventoryGeneralCode: _material == null
          ? null
          : widget.materialsById[_material!]?.inventoryGeneralCode,
      commercialOptions: filteredCommercials.isEmpty
          ? widget.commercialMaterialOptions
          : filteredCommercials,
      initialCommercialMaterialCode: _commercialMaterialCode,
      initialMovementReason: _movementReason,
      initialGrossKg: null,
      initialTareKg: null,
      initialNetKg: null,
      initialHumidityPercent: null,
      initialTrashKg: null,
    );
    if (!mounted || result == null) return;
    setState(() {
      _commercialMaterialCode = result.commercialMaterialCode;
      _movementReason = result.movementReason;
    });
  }

  String _fmtDbDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _fmtUiDate(DateTime d) {
    final yy = (d.year % 100).toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd/$mm/$yy';
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = widget.isSelected || widget.isChecked;
    final hoverOnly = _hovering && !hasSelection;
    final rowBg = _editing
        ? const Color(0xFFDCECF9)
        : hasSelection
        ? const Color(
            0xFF00A3FF,
          ).withValues(alpha: widget.isSelected ? 0.16 : 0.13)
        : hoverOnly
        ? const Color(0xFFE9F7EE)
        : Colors.white;
    final hoverLift = hasSelection
        ? -1.4
        : _hovering
        ? -1.15
        : 0.0;
    final hoverElevation = hasSelection
        ? 3.2
        : _hovering
        ? 2.7
        : 0.5;

    Widget gridFrame(int col, Widget child) {
      final active =
          _editing && widget.isSelected && widget.activeGridColumn == col;
      final hoveredEditable = !_editing && _hoveredEditableColumn == col;
      final hoverTop = hasSelection
          ? const Color(0xFFD9E8F6).withValues(alpha: 0.78)
          : const Color(0xFFE5F2EC).withValues(alpha: 0.80);
      final hoverBottom = hasSelection
          ? const Color(0xFFCCE0F2).withValues(alpha: 0.62)
          : const Color(0xFFD4E7DE).withValues(alpha: 0.66);
      return DecoratedBox(
        position: DecorationPosition.background,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: hoveredEditable
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [hoverTop, hoverBottom],
                )
              : null,
          color: active
              ? const Color(0xFFDCEAF7).withValues(alpha: 0.72)
              : Colors.transparent,
          border: Border.all(
            color: active
                ? const Color(0xFF0B72FF).withValues(alpha: 0.84)
                : Colors.transparent,
            width: active ? 1.05 : 1.0,
          ),
          boxShadow: hoveredEditable
              ? [
                  BoxShadow(
                    color:
                        (hasSelection
                                ? const Color(0xFF6A8FAE)
                                : const Color(0xFF6C8F84))
                            .withValues(alpha: 0.18),
                    blurRadius: 2.2,
                    spreadRadius: -3.0,
                    offset: const Offset(0, 0.8),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.22),
                    blurRadius: 1.1,
                    spreadRadius: -3.1,
                    offset: const Offset(0, -0.5),
                  ),
                ]
              : null,
        ),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? const Color(0xFF0B72FF).withValues(alpha: 0.84)
                  : Colors.transparent,
              width: active ? 1.05 : 1.0,
            ),
          ),
          child: child,
        ),
      );
    }

    Widget previewEditableCell({required int col, required Widget child}) {
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
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _previewEditableCellTap(col),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () => _enterEditingFromPointer(col),
            child: child,
          ),
        ),
      );
    }

    Widget readonlyCell({
      required Widget child,
      bool showDivider = true,
      EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 4),
    }) {
      return Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(child: child),
            if (showDivider)
              Container(
                width: 1,
                height: 30,
                margin: const EdgeInsets.only(left: 8, right: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9D5E2).withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
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
            unawaited(_openContextMenuAt(details.globalPosition));
          },
          onTapDown: (_) {
            if (_editing) return;
            widget.onSelect(_isAdditiveSelectionPressed());
          },
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
                  color: widget.isSelected
                      ? const Color(0xFF00A3FF).withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.0),
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
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: _kInvTableContentW,
                          child: Row(
                            children: [
                              gridFrame(
                                0,
                                SizedBox(
                                  width: 90,
                                  child: _editing
                                      ? InkWell(
                                          onTap: () {
                                            widget.onActivateColumn(0);
                                            activateGridCell(0);
                                          },
                                          child: _InvCellBox(
                                            text: _fmtUiDate(_opDate),
                                            icon: Icons.calendar_month,
                                          ),
                                        )
                                      : previewEditableCell(
                                          col: 0,
                                          child: readonlyCell(
                                            child: _InvFitText(
                                              _fmtUiDate(_opDate),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              gridFrame(
                                1,
                                SizedBox(
                                  width: _kInvRefColW,
                                  child: _editing
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: TextField(
                                            controller: _referenceC,
                                            focusNode: _referenceFocusNode,
                                            decoration:
                                                _invGlassFieldDecoration(
                                                  hintText: 'Ticket',
                                                  suppressFocusedBorder: true,
                                                  hideBorder:
                                                      widget.isSelected &&
                                                      widget.activeGridColumn ==
                                                          1,
                                                ),
                                            onTap: () =>
                                                widget.onActivateColumn(1),
                                          ),
                                        )
                                      : previewEditableCell(
                                          col: 1,
                                          child: readonlyCell(
                                            child: _InvFitText(
                                              (widget.row['reference'] ?? '')
                                                  .toString(),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              gridFrame(
                                2,
                                SizedBox(
                                  width: 190,
                                  child: _editing
                                      ? _InvDropStrInline(
                                          value:
                                              _material ??
                                              widget.materialOptions.first,
                                          items: widget.materialOptions,
                                          format: widget.materialLabel,
                                          onTapStart: () =>
                                              widget.onActivateColumn(2),
                                          onChanged: (v) =>
                                              setState(() => _material = v),
                                        )
                                      : previewEditableCell(
                                          col: 2,
                                          child: Builder(
                                            builder: (_) {
                                              final label = widget
                                                  .materialLabel(_material);
                                              final palette =
                                                  _materialChipColors(label);
                                              return readonlyCell(
                                                child: _InvPillTag(
                                                  label: label,
                                                  background: palette.bg,
                                                  foreground: palette.fg,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                ),
                              ),
                              gridFrame(
                                3,
                                SizedBox(
                                  width: _kInvCounterpartyColW,
                                  child: _editing
                                      ? _InvDropOptInline(
                                          valueId: _counterpartySiteId,
                                          items: widget.counterparties,
                                          onTapStart: () =>
                                              widget.onActivateColumn(3),
                                          onChanged: (v) => setState(
                                            () => _counterpartySiteId = v,
                                          ),
                                        )
                                      : previewEditableCell(
                                          col: 3,
                                          child: readonlyCell(
                                            child: _InvFitText(
                                              _labelOf(
                                                    widget.counterparties,
                                                    _counterpartySiteId,
                                                  ) ??
                                                  (widget.row['counterparty'] ??
                                                          '—')
                                                      .toString(),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              gridFrame(
                                4,
                                SizedBox(
                                  width: 190,
                                  child: _editing
                                      ? _InvDropOptInline(
                                          valueId: _driverId,
                                          items: widget.drivers,
                                          onTapStart: () =>
                                              widget.onActivateColumn(4),
                                          onChanged: (v) =>
                                              setState(() => _driverId = v),
                                        )
                                      : previewEditableCell(
                                          col: 4,
                                          child: readonlyCell(
                                            child: _InvFitText(
                                              _labelOf(
                                                    widget.drivers,
                                                    _driverId,
                                                  ) ??
                                                  '—',
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              gridFrame(
                                5,
                                SizedBox(
                                  width: 140,
                                  child: _editing
                                      ? _InvDropOptInline(
                                          valueId: _vehicleId,
                                          items: widget.vehicles,
                                          onTapStart: () =>
                                              widget.onActivateColumn(5),
                                          onChanged: (v) =>
                                              setState(() => _vehicleId = v),
                                        )
                                      : previewEditableCell(
                                          col: 5,
                                          child: readonlyCell(
                                            child: _InvUnitBadge(
                                              label:
                                                  _labelOf(
                                                    widget.vehicles,
                                                    _vehicleId,
                                                  ) ??
                                                  '—',
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              gridFrame(
                                6,
                                SizedBox(
                                  width: _kInvGrossColW,
                                  child: _editing
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: TextField(
                                            controller: _grossC,
                                            focusNode: _grossFocusNode,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration:
                                                _invGlassFieldDecoration(
                                                  hintText: 'Bruto kg',
                                                  suppressFocusedBorder: true,
                                                  hideBorder:
                                                      widget.isSelected &&
                                                      widget.activeGridColumn ==
                                                          6,
                                                ),
                                            onTap: () =>
                                                widget.onActivateColumn(6),
                                          ),
                                        )
                                      : previewEditableCell(
                                          col: 6,
                                          child: readonlyCell(
                                            child: _InvFitText(
                                              _grossC.text.isEmpty
                                                  ? '—'
                                                  : '${_fmtInvCount(_toDouble(_grossC.text) ?? 0)} kg',
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              gridFrame(
                                7,
                                SizedBox(
                                  width: _kInvTareColW,
                                  child: _editing
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: TextField(
                                            controller: _tareC,
                                            focusNode: _tareFocusNode,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration:
                                                _invGlassFieldDecoration(
                                                  hintText: 'Tara kg',
                                                  suppressFocusedBorder: true,
                                                  hideBorder:
                                                      widget.isSelected &&
                                                      widget.activeGridColumn ==
                                                          7,
                                                ),
                                            onTap: () =>
                                                widget.onActivateColumn(7),
                                          ),
                                        )
                                      : previewEditableCell(
                                          col: 7,
                                          child: readonlyCell(
                                            child: _InvFitText(
                                              _tareC.text.isEmpty
                                                  ? '—'
                                                  : '${_fmtInvCount(_toDouble(_tareC.text) ?? 0)} kg',
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              gridFrame(
                                8,
                                SizedBox(
                                  width: _kInvKgColW,
                                  child: readonlyCell(
                                    child: Builder(
                                      builder: (_) {
                                        final gross = _toDouble(_grossC.text);
                                        final tare = _toDouble(_tareC.text);
                                        final computedNet =
                                            (gross == null || gross <= 0)
                                            ? (_toDouble(
                                                    widget.row['net_kg'],
                                                  ) ??
                                                  _toDouble(
                                                    widget.row['weight_kg'],
                                                  ))
                                            : math
                                                  .max(0, gross - (tare ?? 0))
                                                  .toDouble();
                                        return _InvFitText(
                                          computedNet == null
                                              ? '—'
                                              : '${_fmtInvCount(computedNet)} kg',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              gridFrame(
                                9,
                                SizedBox(
                                  width: _kInvHumidityColW,
                                  child: _editing
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: TextField(
                                            controller: _humidityC,
                                            focusNode: _humidityFocusNode,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration:
                                                _invGlassFieldDecoration(
                                                  hintText: 'Humedad %',
                                                  suppressFocusedBorder: true,
                                                  hideBorder:
                                                      widget.isSelected &&
                                                      widget.activeGridColumn ==
                                                          9,
                                                ),
                                            onTap: () =>
                                                widget.onActivateColumn(9),
                                          ),
                                        )
                                      : previewEditableCell(
                                          col: 9,
                                          child: readonlyCell(
                                            child: _InvFitText(
                                              _humidityC.text.isEmpty
                                                  ? '—'
                                                  : '${_fmtInvCount(_toDouble(_humidityC.text) ?? 0)} %',
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              gridFrame(
                                10,
                                SizedBox(
                                  width: _kInvTrashColW,
                                  child: _editing
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: TextField(
                                            controller: _trashC,
                                            focusNode: _trashFocusNode,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration:
                                                _invGlassFieldDecoration(
                                                  hintText: 'Basura kg',
                                                  suppressFocusedBorder: true,
                                                  hideBorder:
                                                      widget.isSelected &&
                                                      widget.activeGridColumn ==
                                                          10,
                                                ),
                                            onTap: () =>
                                                widget.onActivateColumn(10),
                                          ),
                                        )
                                      : previewEditableCell(
                                          col: 10,
                                          child: readonlyCell(
                                            child: _InvFitText(
                                              _trashC.text.isEmpty
                                                  ? '—'
                                                  : '${_fmtInvCount(_toDouble(_trashC.text) ?? 0)} kg',
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              gridFrame(
                                11,
                                SizedBox(
                                  width: _kInvAmountColW,
                                  child: readonlyCell(
                                    child: Builder(
                                      builder: (_) {
                                        final netKg = _rowEffectiveNetKg(
                                          netKg: null,
                                          grossKg: _toDouble(_grossC.text),
                                          tareKg: _toDouble(_tareC.text),
                                        );
                                        final amount = netKg == null
                                            ? null
                                            : _rowTotalAmountKg(
                                                netKg: netKg,
                                                humidityPercent: _toDouble(
                                                  _humidityC.text,
                                                ),
                                                trashKg: _toDouble(
                                                  _trashC.text,
                                                ),
                                              );
                                        return _InvFitText(
                                          amount == null
                                              ? '—'
                                              : _fmtInvCount(amount),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              gridFrame(
                                12,
                                SizedBox(
                                  width: _kInvNotesColW,
                                  child: _editing
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: TextField(
                                            controller: _notesC,
                                            focusNode: _notesFocusNode,
                                            decoration:
                                                _invGlassFieldDecoration(
                                                  hintText:
                                                      'Comentario / notas',
                                                  suppressFocusedBorder: true,
                                                  hideBorder:
                                                      widget.isSelected &&
                                                      widget.activeGridColumn ==
                                                          12,
                                                ),
                                            onTap: () =>
                                                widget.onActivateColumn(12),
                                          ),
                                        )
                                      : previewEditableCell(
                                          col: 12,
                                          child: readonlyCell(
                                            showDivider: true,
                                            child: _InvFitText(
                                              (widget.row['notes'] ?? '')
                                                  .toString(),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              gridFrame(
                                13,
                                SizedBox(
                                  width: _kInvActionsW,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (_editing)
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF6A99C7,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            textStyle: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          onPressed: () => _save(),
                                          child: const Text('ACTUALIZAR'),
                                        )
                                      else
                                        _InvPillTag(
                                          label: widget.flow,
                                          background: _isInFlow(widget.flow)
                                              ? const Color(0xFFD8FBF3)
                                              : const Color(0xFFD9E8FF),
                                          foreground: const Color(0xFF1D3C58),
                                          minWidth: 0,
                                          horizontalPadding: 9,
                                        ),
                                      const SizedBox(width: 4),
                                      Builder(
                                        builder: (menuContext) {
                                          return Tooltip(
                                            message: 'Acciones',
                                            child: MouseRegion(
                                              onEnter: (_) => setState(
                                                () =>
                                                    _hoverActionsButton = true,
                                              ),
                                              onExit: (_) => setState(
                                                () =>
                                                    _hoverActionsButton = false,
                                              ),
                                              child: GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTapDown: (_) {
                                                  final box =
                                                      menuContext
                                                              .findRenderObject()
                                                          as RenderBox?;
                                                  if (box == null) return;
                                                  final origin = box
                                                      .localToGlobal(
                                                        Offset.zero,
                                                      );
                                                  final target = Offset(
                                                    origin.dx,
                                                    origin.dy +
                                                        box.size.height +
                                                        4,
                                                  );
                                                  unawaited(
                                                    _openContextMenuAt(target),
                                                  );
                                                },
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 120,
                                                  ),
                                                  curve: Curves.easeOutCubic,
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: _hoverActionsButton
                                                        ? Colors.white
                                                              .withValues(
                                                                alpha: 0.62,
                                                              )
                                                        : Colors.white
                                                              .withValues(
                                                                alpha: 0.42,
                                                              ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.72,
                                                          ),
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha:
                                                                  _hoverActionsButton
                                                                  ? 0.15
                                                                  : 0.08,
                                                            ),
                                                        blurRadius:
                                                            _hoverActionsButton
                                                            ? 14
                                                            : 8,
                                                        offset: Offset(
                                                          0,
                                                          _hoverActionsButton
                                                              ? 7
                                                              : 4,
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
                                          );
                                        },
                                      ),
                                    ],
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _isInFlow(String flow) => flow == 'IN';

String? _movementExtrasRequiredError({
  required String flow,
  required String? inventoryGeneralCode,
  required String? commercialMaterialCode,
  required String? movementReason,
}) {
  final commercial = (commercialMaterialCode ?? '').trim();
  if (commercial.isEmpty) {
    return 'En extras, el material comercial es obligatorio.';
  }
  final generalCode = (inventoryGeneralCode ?? '').trim().toUpperCase();
  final reason = (movementReason ?? '').trim();
  if (_isInFlow(flow) && generalCode == 'METAL' && reason.isEmpty) {
    return 'En entradas de metal, el origen es obligatorio en extras.';
  }
  return null;
}

class _InvCellBox extends StatelessWidget {
  final String text;
  final IconData icon;
  const _InvCellBox({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InputDecorator(
        decoration: _invGlassFieldDecoration(
          suppressFocusedBorder: true,
          hideBorder: true,
        ),
        child: Row(
          children: [
            Expanded(child: Text(text, overflow: TextOverflow.ellipsis)),
            Icon(icon, size: 16),
          ],
        ),
      ),
    );
  }
}

class _InvDropOptInline extends StatelessWidget {
  final String? valueId;
  final List<_InvOpt> items;
  final VoidCallback? onTapStart;
  final ValueChanged<String?> onChanged;

  const _InvDropOptInline({
    required this.valueId,
    required this.items,
    this.onTapStart,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safe = items.any((e) => e.id == valueId) ? valueId : null;
    final selectedLabel = safe == null
        ? '—'
        : (items.firstWhere((e) => e.id == safe).label);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          onTapStart?.call();
          final selected = await _showInvSearchablePickerDialog<String>(
            context,
            title: 'Seleccionar',
            initialValue: safe,
            options: items
                .map(
                  (e) => _InvPickerOption<String>(value: e.id, label: e.label),
                )
                .toList(),
          );
          if (selected == null) return;
          onChanged(selected);
        },
        child: InputDecorator(
          decoration: _invGlassFieldDecoration(
            suppressFocusedBorder: true,
            hideBorder: true,
            fillColorOverride: const Color(0xFFF2F7FC),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvDropStrInline extends StatelessWidget {
  final String? value;
  final List<String> items;
  final String Function(String?) format;
  final VoidCallback? onTapStart;
  final ValueChanged<String?> onChanged;

  const _InvDropStrInline({
    required this.value,
    required this.items,
    required this.format,
    this.onTapStart,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safe = value != null && items.contains(value) ? value : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          onTapStart?.call();
          final selected = await _showInvSearchablePickerDialog<String>(
            context,
            title: 'Seleccionar',
            initialValue: safe,
            options: items
                .map(
                  (e) => _InvPickerOption<String>(value: e, label: format(e)),
                )
                .toList(),
          );
          if (selected != null) onChanged(selected);
        },
        child: InputDecorator(
          decoration: _invGlassFieldDecoration(
            suppressFocusedBorder: true,
            hideBorder: true,
            fillColorOverride: const Color(0xFFF2F7FC),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  safe == null ? '—' : format(safe),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvPillTag extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final double minWidth;
  final double horizontalPadding;

  const _InvPillTag({
    required this.label,
    required this.background,
    required this.foreground,
    this.minWidth = 70,
    this.horizontalPadding = 14,
  });

  @override
  Widget build(BuildContext context) {
    final text = label.trim().isEmpty ? '—' : label.trim();
    return SizedBox(
      height: 34,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(minWidth: minWidth),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.22,
              fontWeight: FontWeight.w900,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _InvUnitBadge extends StatelessWidget {
  final String label;

  const _InvUnitBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final text = label.trim().isEmpty ? '—' : label.trim();
    return SizedBox(
      height: 34,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(minWidth: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE6EAF0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF30445D),
            ),
          ),
        ),
      ),
    );
  }
}

class _InvFitText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const _InvFitText(this.text, {this.style});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text.isEmpty ? '—' : text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
  }
}

class _InvOpt {
  final String id;
  final String label;
  final String? type;
  const _InvOpt({required this.id, required this.label, this.type});
}

class _InvMaterialOpt {
  final String id;
  final String name;
  final String? inventoryMaterialCode;
  final String? inventoryGeneralCode;

  const _InvMaterialOpt({
    required this.id,
    required this.name,
    required this.inventoryMaterialCode,
    required this.inventoryGeneralCode,
  });
}

class _CommercialMaterialOpt {
  final String id;
  final String code;
  final String name;
  final String family;
  final String? inventoryMaterial;
  final String? materialId;

  const _CommercialMaterialOpt({
    required this.id,
    required this.code,
    required this.name,
    required this.family,
    required this.inventoryMaterial,
    required this.materialId,
  });

  String get label => name;
}

class _MovementExtrasResult {
  final String? commercialMaterialCode;
  final String? movementReason;
  final double? grossKg;
  final double? tareKg;
  final double? netKg;
  final double? humidityPercent;
  final double? trashKg;
  final double? totalAmountKg;

  const _MovementExtrasResult({
    required this.commercialMaterialCode,
    required this.movementReason,
    required this.grossKg,
    required this.tareKg,
    required this.netKg,
    required this.humidityPercent,
    required this.trashKg,
    required this.totalAmountKg,
  });
}

const List<String> _kMovementInReasons = <String>[
  'DIRECT_PURCHASE',
  'SCRAP_SEPARATION',
];

Future<_MovementExtrasResult?> _showMovementExtrasDialog(
  BuildContext context, {
  required String flow,
  required String materialLabel,
  required String? inventoryMaterialCode,
  required String? inventoryGeneralCode,
  required List<_CommercialMaterialOpt> commercialOptions,
  required String? initialCommercialMaterialCode,
  required String? initialMovementReason,
  required double? initialGrossKg,
  required double? initialTareKg,
  required double? initialNetKg,
  required double? initialHumidityPercent,
  required double? initialTrashKg,
}) async {
  String? selectedCommercial = initialCommercialMaterialCode;
  String? selectedReason = initialMovementReason;
  double? grossKg = initialGrossKg;
  double? tareKg = initialTareKg;
  double? netKg = initialNetKg;
  double? humidityPercent = initialHumidityPercent;
  double? trashKg = initialTrashKg;
  final isInFlow = flow == 'IN';
  final generalCode = (inventoryGeneralCode ?? '').trim().toUpperCase();
  final showReason = isInFlow && generalCode == 'METAL';

  if (!showReason) selectedReason = null;
  if (selectedCommercial != null &&
      !commercialOptions.any((o) => o.code == selectedCommercial)) {
    selectedCommercial = null;
  }
  if (selectedReason != null && !_kMovementInReasons.contains(selectedReason)) {
    selectedReason = null;
  }

  final result = await showDialog<_MovementExtrasResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocalState) {
        double sanitize(double? v) => (v == null || v < 0) ? 0 : v;
        final effectiveNetKg = (netKg != null && netKg > 0)
            ? netKg
            : (grossKg != null && grossKg > 0)
            ? math.max(0, grossKg - sanitize(tareKg)).toDouble()
            : null;
        final totalAmountKg = effectiveNetKg == null
            ? null
            : math
                  .max(
                    0,
                    effectiveNetKg -
                        (effectiveNetKg * (sanitize(humidityPercent) / 100.0)) -
                        sanitize(trashKg),
                  )
                  .toDouble();
        _MovementExtrasResult buildResult() => _MovementExtrasResult(
          commercialMaterialCode: selectedCommercial,
          movementReason: showReason ? selectedReason : null,
          grossKg: grossKg,
          tareKg: tareKg,
          netKg: netKg,
          humidityPercent: humidityPercent,
          trashKg: trashKg,
          totalAmountKg: totalAmountKg,
        );

        Widget pickerField({
          required String label,
          required String valueText,
          required VoidCallback? onTap,
        }) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4B6378),
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCEBFA).withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF8AA9C2).withValues(alpha: 0.62),
                    ),
                  ),
                  child: InputDecorator(
                    decoration: _invGlassFieldDecoration(
                      suppressFocusedBorder: true,
                      hideBorder: true,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            valueText,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: onTap == null
                                  ? const Color(0xFF637D92)
                                  : const Color(0xFF0B2B2B),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 20,
                          color: onTap == null
                              ? const Color(0xFF7D95A8)
                              : const Color(0xFF2E597E),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
              Navigator.pop(dialogContext, buildResult());
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: AlertDialog(
            backgroundColor: const Color(0xFFEAF2F9).withValues(alpha: 0.98),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: const Color(0xFF8AA9C2).withValues(alpha: 0.42),
              ),
            ),
            title: const Text('Extras de Movimiento'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  pickerField(
                    label: 'Material comercial',
                    valueText: selectedCommercial == null
                        ? 'Sin clasificar'
                        : (() {
                            for (final o in commercialOptions) {
                              if (o.code == selectedCommercial) {
                                return o.label;
                              }
                            }
                            return selectedCommercial!;
                          })(),
                    onTap: () async {
                      final picked =
                          await _showInvSearchablePickerDialog<String>(
                            context,
                            title: 'Material comercial',
                            initialValue: selectedCommercial,
                            allowClear: true,
                            options: commercialOptions
                                .map(
                                  (o) => _InvPickerOption<String>(
                                    value: o.code,
                                    label: o.label,
                                  ),
                                )
                                .toList(),
                          );
                      setLocalState(() => selectedCommercial = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  pickerField(
                    label: 'Origen',
                    valueText: showReason
                        ? switch (selectedReason) {
                            'DIRECT_PURCHASE' => 'Compra directa',
                            'SCRAP_SEPARATION' => 'Separacion de chatarra',
                            _ => 'Sin especificar',
                          }
                        : 'No aplica',
                    onTap: showReason
                        ? () async {
                            final picked =
                                await _showInvSearchablePickerDialog<String>(
                                  context,
                                  title: 'Origen',
                                  initialValue: selectedReason,
                                  allowClear: true,
                                  options: const [
                                    _InvPickerOption<String>(
                                      value: 'DIRECT_PURCHASE',
                                      label: 'Compra directa',
                                    ),
                                    _InvPickerOption<String>(
                                      value: 'SCRAP_SEPARATION',
                                      label: 'Separacion de chatarra',
                                    ),
                                  ],
                                );
                            setLocalState(() => selectedReason = picked);
                          }
                        : null,
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2D5478),
                ),
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2D5478),
                ),
                onPressed: () {
                  setLocalState(() {
                    selectedCommercial = null;
                    selectedReason = null;
                  });
                },
                child: const Text('Limpiar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6A99C7),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(dialogContext, buildResult()),
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    ),
  );

  return result;
}

class _MovementDraft {
  static const Object _unset = Object();

  final DateTime? opDate;
  final String? materialId;
  final double? grossKg;
  final double? tareKg;
  final double? netKg;
  final double? humidityPercent;
  final double? trashKg;
  final double? totalAmountKg;
  final String? counterpartySiteId;
  final String? driverEmployeeId;
  final String? vehicleId;
  final String? commercialMaterialCode;
  final String? movementReason;
  final String scaleTicket;
  final String reference;
  final String notes;

  const _MovementDraft({
    required this.opDate,
    required this.materialId,
    required this.grossKg,
    required this.tareKg,
    required this.netKg,
    required this.humidityPercent,
    required this.trashKg,
    required this.totalAmountKg,
    required this.counterpartySiteId,
    required this.driverEmployeeId,
    required this.vehicleId,
    required this.commercialMaterialCode,
    required this.movementReason,
    required this.scaleTicket,
    required this.reference,
    required this.notes,
  });

  _MovementDraft copyWith({
    Object? opDate = _unset,
    Object? materialId = _unset,
    Object? grossKg = _unset,
    Object? tareKg = _unset,
    Object? netKg = _unset,
    Object? humidityPercent = _unset,
    Object? trashKg = _unset,
    Object? totalAmountKg = _unset,
    Object? counterpartySiteId = _unset,
    Object? driverEmployeeId = _unset,
    Object? vehicleId = _unset,
    Object? commercialMaterialCode = _unset,
    Object? movementReason = _unset,
    String? scaleTicket,
    String? reference,
    String? notes,
  }) {
    return _MovementDraft(
      opDate: identical(opDate, _unset) ? this.opDate : opDate as DateTime?,
      materialId: identical(materialId, _unset)
          ? this.materialId
          : materialId as String?,
      grossKg: identical(grossKg, _unset) ? this.grossKg : grossKg as double?,
      tareKg: identical(tareKg, _unset) ? this.tareKg : tareKg as double?,
      netKg: identical(netKg, _unset) ? this.netKg : netKg as double?,
      humidityPercent: identical(humidityPercent, _unset)
          ? this.humidityPercent
          : humidityPercent as double?,
      trashKg: identical(trashKg, _unset) ? this.trashKg : trashKg as double?,
      totalAmountKg: identical(totalAmountKg, _unset)
          ? this.totalAmountKg
          : totalAmountKg as double?,
      counterpartySiteId: identical(counterpartySiteId, _unset)
          ? this.counterpartySiteId
          : counterpartySiteId as String?,
      driverEmployeeId: identical(driverEmployeeId, _unset)
          ? this.driverEmployeeId
          : driverEmployeeId as String?,
      vehicleId: identical(vehicleId, _unset)
          ? this.vehicleId
          : vehicleId as String?,
      commercialMaterialCode: identical(commercialMaterialCode, _unset)
          ? this.commercialMaterialCode
          : commercialMaterialCode as String?,
      movementReason: identical(movementReason, _unset)
          ? this.movementReason
          : movementReason as String?,
      scaleTicket: scaleTicket ?? this.scaleTicket,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
    );
  }
}

class _InvPickerOption<T> {
  final T value;
  final String label;
  const _InvPickerOption({required this.value, required this.label});
}

class _InvFilterDialogResult {
  final Set<String> selectedValues;
  const _InvFilterDialogResult({required this.selectedValues});
}

class _InvDateFilterDialogResult {
  final DateTimeRange? range;
  final bool clear;
  const _InvDateFilterDialogResult({this.range, this.clear = false});
}

Future<T?> _showInvSearchablePickerDialog<T>(
  BuildContext context, {
  required String title,
  required List<_InvPickerOption<T>> options,
  T? initialValue,
  bool allowClear = false,
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) {
      final searchC = TextEditingController();
      final searchFocus = FocusNode();
      final itemFocusNodes = <FocusNode>[];
      final itemKeys = <GlobalKey>[];
      final listScrollController = ScrollController();
      String q = '';
      int? hoveredIndex;
      int? focusedIndex;

      void syncNodes(int count) {
        while (itemFocusNodes.length < count) {
          itemFocusNodes.add(FocusNode());
        }
        while (itemFocusNodes.length > count) {
          itemFocusNodes.removeLast().dispose();
        }
        while (itemKeys.length < count) {
          itemKeys.add(GlobalKey());
        }
        while (itemKeys.length > count) {
          itemKeys.removeLast();
        }
      }

      return StatefulBuilder(
        builder: (context, setLocalState) {
          final filtered = options
              .where((o) => o.label.toLowerCase().contains(q.toLowerCase()))
              .toList();
          syncNodes(filtered.length);
          return Focus(
            autofocus: false,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.of(dialogContext).pop();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                if (filtered.isEmpty) return KeyEventResult.handled;
                final activeIndex = (focusedIndex ?? 0).clamp(
                  0,
                  filtered.length - 1,
                );
                Navigator.of(dialogContext).pop(filtered[activeIndex].value);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 420,
                    constraints: const BoxConstraints(maxHeight: 560),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF9FC8E7).withValues(alpha: 0.78),
                          const Color(0xFFB9CCE8).withValues(alpha: 0.72),
                          const Color(0xFF9ED7D6).withValues(alpha: 0.70),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE5F1FB).withValues(alpha: 0.78),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF76A6C2,
                          ).withValues(alpha: 0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                            decoration: _invGlassFieldDecoration(
                              hintText: 'Buscar',
                              fillColorOverride: const Color(
                                0xFFEAF3FC,
                              ).withValues(alpha: 0.86),
                            ),
                            onChanged: (v) => setLocalState(() => q = v),
                          ),
                        ),
                        if (allowClear) ...[
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(null),
                              child: const Text('Limpiar selección'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(child: Text('Sin resultados'))
                              : ListView.builder(
                                  controller: listScrollController,
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) {
                                    final option = filtered[i];
                                    final selected =
                                        option.value == initialValue;
                                    final hovered = hoveredIndex == i;
                                    final focused = focusedIndex == i;
                                    return Column(
                                      children: [
                                        Focus(
                                          focusNode: itemFocusNodes[i],
                                          onFocusChange: (hasFocus) {
                                            setLocalState(() {
                                              if (hasFocus) {
                                                focusedIndex = i;
                                              } else if (focusedIndex == i) {
                                                focusedIndex = null;
                                              }
                                            });
                                            if (hasFocus) {
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                    final itemContext =
                                                        itemKeys[i]
                                                            .currentContext;
                                                    if (itemContext == null) {
                                                      return;
                                                    }
                                                    Scrollable.ensureVisible(
                                                      itemContext,
                                                      alignment: 0.5,
                                                      duration: const Duration(
                                                        milliseconds: 90,
                                                      ),
                                                      curve:
                                                          Curves.easeOutCubic,
                                                    );
                                                  });
                                            }
                                          },
                                          onKeyEvent: (_, event) {
                                            if (event is! KeyDownEvent) {
                                              return KeyEventResult.ignored;
                                            }
                                            final key = event.logicalKey;
                                            if (key ==
                                                LogicalKeyboardKey.arrowUp) {
                                              if (i == 0) {
                                                searchFocus.requestFocus();
                                              } else {
                                                itemFocusNodes[i - 1]
                                                    .requestFocus();
                                              }
                                              return KeyEventResult.handled;
                                            }
                                            if (key ==
                                                    LogicalKeyboardKey
                                                        .arrowDown &&
                                                i < itemFocusNodes.length - 1) {
                                              itemFocusNodes[i + 1]
                                                  .requestFocus();
                                              return KeyEventResult.handled;
                                            }
                                            if (key ==
                                                    LogicalKeyboardKey.enter ||
                                                key ==
                                                    LogicalKeyboardKey
                                                        .numpadEnter ||
                                                key ==
                                                    LogicalKeyboardKey.space) {
                                              Navigator.of(
                                                dialogContext,
                                              ).pop(option.value);
                                              return KeyEventResult.handled;
                                            }
                                            return KeyEventResult.ignored;
                                          },
                                          child: MouseRegion(
                                            onEnter: (_) => setLocalState(
                                              () => hoveredIndex = i,
                                            ),
                                            onExit: (_) {
                                              if (hoveredIndex == i) {
                                                setLocalState(
                                                  () => hoveredIndex = null,
                                                );
                                              }
                                            },
                                            child: AnimatedContainer(
                                              key: itemKeys[i],
                                              duration: const Duration(
                                                milliseconds: 1,
                                              ),
                                              curve: Curves.linear,
                                              margin: EdgeInsets.zero,
                                              decoration: BoxDecoration(
                                                color: focused
                                                    ? const Color(
                                                        0xFFE3F0FC,
                                                      ).withValues(alpha: 0.92)
                                                    : hovered
                                                    ? const Color(
                                                        0xFFE9F7EE,
                                                      ).withValues(alpha: 0.98)
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: focused
                                                      ? const Color(
                                                          0xFF4E92D1,
                                                        ).withValues(
                                                          alpha: 0.88,
                                                        )
                                                      : hovered
                                                      ? const Color(
                                                          0xFFBFD8D3,
                                                        ).withValues(
                                                          alpha: 0.62,
                                                        )
                                                      : Colors.transparent,
                                                  width: focused
                                                      ? 1.25
                                                      : hovered
                                                      ? 1.0
                                                      : 0.0,
                                                ),
                                                boxShadow: hovered
                                                    ? [
                                                        BoxShadow(
                                                          color:
                                                              const Color(
                                                                0xFFBFD8D3,
                                                              ).withValues(
                                                                alpha: 0.46,
                                                              ),
                                                          blurRadius: 8,
                                                          offset: const Offset(
                                                            0,
                                                            2,
                                                          ),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                              child: ListTile(
                                                dense: true,
                                                selected: selected,
                                                hoverColor: Colors.transparent,
                                                splashColor: Colors.transparent,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 2,
                                                    ),
                                                title: Text(
                                                  option.label,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Color(0xFF2D4661),
                                                    fontWeight: FontWeight.w500,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                                trailing: selected
                                                    ? Icon(
                                                        Icons.check,
                                                        size: 18,
                                                        color: const Color(
                                                          0xFF2D7A73,
                                                        ),
                                                      )
                                                    : null,
                                                onTap: () => Navigator.of(
                                                  dialogContext,
                                                ).pop(option.value),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (i < filtered.length - 1)
                                          Divider(
                                            height: 1,
                                            thickness: 1,
                                            color: const Color(
                                              0xFFE5F1FB,
                                            ).withValues(alpha: 0.56),
                                          ),
                                      ],
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

Future<_InvDateFilterDialogResult?> _showInvDateRangeFilterDialog(
  BuildContext context, {
  required String label,
  required DateTimeRange bounds,
  DateTimeRange? initialRange,
}) {
  return showDialog<_InvDateFilterDialogResult>(
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

          bool inPreviewRange(DateTime day) {
            if (start == null || rangePreviewEnd == null) return false;
            final a = dateOnly(start!);
            final b = dateOnly(rangePreviewEnd);
            final from = a.isBefore(b) ? a : b;
            final to = a.isBefore(b) ? b : a;
            final d = dateOnly(day);
            return !d.isBefore(from) && !d.isAfter(to);
          }

          _InvDateFilterDialogResult? buildApplyResult() {
            if (start == null) return null;
            final s = dateOnly(start!);
            final e = dateOnly(end ?? start!);
            final from = s.isBefore(e) ? s : e;
            final to = s.isBefore(e) ? e : s;
            return _InvDateFilterDialogResult(
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
                      decoration: _invFilterDialogDecoration(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtro: $label',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF0B2B2B),
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
                                onPressed: () => setLocalState(
                                  () => displayMonth = DateTime(
                                    displayMonth.year,
                                    displayMonth.month + 1,
                                  ),
                                ),
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
                                          ? _kInvFilterAccent
                                          : inRange
                                          ? _kInvFilterAccentSoft.withValues(
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
                                                        color: _kInvFilterAccent
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
                                style: _invFilterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: _invFilterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(
                                  dialogContext,
                                  const _InvDateFilterDialogResult(clear: true),
                                ),
                                child: const Text('Limpiar'),
                              ),
                              const SizedBox(width: 6),
                              FilledButton(
                                style: _invFilterFilledButtonStyle(),
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

String _fmtDateLabel(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

String _monthNameEs(int month) {
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

Future<DateTime?> _showInvKeyboardDatePickerDialog({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
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
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (innerContext, setInnerState) {
          return FocusScope(
            autofocus: true,
            child: Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
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

Future<bool?> _showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmText,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.pop(dialogContext, false);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          Navigator.pop(dialogContext, true);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmText),
          ),
        ],
      ),
    ),
  );
}

InputDecoration _invGlassFieldDecoration({
  String? hintText,
  String? labelText,
  bool suppressFocusedBorder = false,
  bool hideBorder = false,
  Color? fillColorOverride,
}) {
  final baseSide = hideBorder
      ? BorderSide(color: Colors.transparent, width: 0.9)
      : BorderSide(
          color: const Color(0xFF90AFC8).withValues(alpha: 0.55),
          width: 1,
        );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: baseSide,
  );
  final focused = suppressFocusedBorder
      ? border
      : border.copyWith(
          borderSide: BorderSide(
            color: const Color(0xFF00A3FF).withValues(alpha: 0.8),
            width: 1.2,
          ),
        );

  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    hintStyle: TextStyle(
      color: const Color(0xFF0B2B2B).withValues(alpha: 0.42),
      fontWeight: FontWeight.w400,
    ),
    isDense: true,
    filled: true,
    fillColor:
        fillColorOverride ?? const Color(0xFFEAF2F9).withValues(alpha: 0.90),
    border: border,
    enabledBorder: border,
    focusedBorder: focused,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  );
}

BoxDecoration _invFilterDialogDecoration() {
  return BoxDecoration(
    color: const Color(0xFFE8F0F7).withValues(alpha: 0.92),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: const Color(0xFF92ABC1).withValues(alpha: 0.50)),
  );
}

ButtonStyle _invFilterOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF1E3C5A),
    side: BorderSide(color: const Color(0xFF6E8CAA).withValues(alpha: 0.35)),
    backgroundColor: const Color(0xFFDDE9F4).withValues(alpha: 0.70),
  );
}

ButtonStyle _invFilterFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: _kInvFilterAccent,
    foregroundColor: Colors.white,
  );
}

ButtonStyle _invActionOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF0B2B2B),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
    backgroundColor: Colors.white.withValues(alpha: 0.26),
  );
}

ButtonStyle _invActionFilledButtonStyle() {
  return FilledButton.styleFrom(
    foregroundColor: const Color(0xFF0B2B2B),
    backgroundColor: Colors.white.withValues(alpha: 0.36),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.74)),
  );
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final text = v.toString().trim();
  if (text.isEmpty) return null;
  final normalized = text.replaceAll(',', '.');
  return double.tryParse(normalized);
}

class _InvTopMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  const _InvTopMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFBFD8D3).withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.74),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _kInvFilterAccent.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: _kInvFilterAccent.withValues(alpha: 0.34),
                width: 1,
              ),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF0B2B2B)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFF2A4B49),
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
                    color: Color(0xFF0B2B2B),
                    height: 1.0,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2A4B49),
                      height: 1.0,
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

class _InvToolbarPanel extends StatelessWidget {
  final Widget child;

  const _InvToolbarPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.64),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

String _fmtInvInt(int value) {
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

String _fmtInvCount(double value, {int decimals = 2}) {
  final negative = value < 0;
  final absValue = value.abs();
  final fixed = absValue.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = _fmtInvInt(int.tryParse(parts.first) ?? 0);
  if (decimals <= 0) return negative ? '-$whole' : whole;
  final fraction = parts.length > 1 ? parts[1] : ''.padRight(decimals, '0');
  return negative ? '-$whole.$fraction' : '$whole.$fraction';
}

String _invMaterialLabel(String? material) {
  switch (material) {
    case 'CARDBOARD_BULK_NATIONAL':
      return 'Carton granel';
    case 'CARDBOARD_BULK_AMERICAN':
      return 'Carton granel';
    case 'BALE_NATIONAL':
      return 'Paca nacional';
    case 'BALE_AMERICAN':
      return 'Paca americana';
    case 'BALE_CLEAN':
      return 'Paca limpia';
    case 'BALE_TRASH':
      return 'Paca basura';
    case 'CAPLE':
      return 'Caple';
    case 'SCRAP':
      return 'Chatarra';
    case 'METAL':
      return 'Metal';
    case 'WOOD':
      return 'Madera';
    case 'PAPER':
      return 'Papel';
    case 'PLASTIC':
      return 'Plástico';
    case 'METAL_ALUMINUM':
    case 'METAL_STEEL':
    case 'METAL_COPPER':
    case 'METAL_BRASS':
    case 'METAL_OTHER':
      return 'Metal';
    default:
      return material ?? '—';
  }
}

/*
Legacy production/separation module archived in place.
The active operation flow uses InventoryTransformationGrid on v2.
class InventoryProductionGrid extends StatefulWidget {
  final Future<void> Function()? onChanged;
  final bool showTopBarChrome;
  final ValueChanged<InventoryGridTopBarData>? onTopBarChanged;
  const InventoryProductionGrid({
    super.key,
    this.onChanged,
    this.showTopBarChrome = true,
    this.onTopBarChanged,
  });

  @override
  State<InventoryProductionGrid> createState() =>
      _InventoryProductionGridState();
}

class _InventoryProductionGridState extends State<InventoryProductionGrid>
    with WidgetsBindingObserver {
  final supa = Supabase.instance.client;

  final FocusNode _insertFocusNode = FocusNode(
    debugLabel: 'prod_insert_row_focus',
  );
  final FocusNode _rowsFocusNode = FocusNode(debugLabel: 'prod_rows_focus');
  final FocusNode _insertCountFocusNode = FocusNode(
    debugLabel: 'prod_insert_count',
  );
  final FocusNode _insertAvgFocusNode = FocusNode(
    debugLabel: 'prod_insert_avg',
  );
  final FocusNode _insertNotesFocusNode = FocusNode(
    debugLabel: 'prod_insert_notes',
  );
  final GlobalKey _insertRowKey = GlobalKey(debugLabel: 'prod_insert_row');
  final GlobalKey _rowsViewportKey = GlobalKey(
    debugLabel: 'prod_rows_viewport',
  );
  final ScrollController _rowsScrollController = ScrollController();

  final TextEditingController _draftCountC = TextEditingController();
  final TextEditingController _draftAvgC = TextEditingController(text: '850');
  final TextEditingController _draftNotesC = TextEditingController();

  final Map<String, GlobalKey<_ProductionDataRowState>> _rowKeys =
      <String, GlobalKey<_ProductionDataRowState>>{};
  final Map<String, Set<String>> _columnValueFilters = <String, Set<String>>{};
  final Map<String, DateTimeRange> _columnDateRangeFilters =
      <String, DateTimeRange>{};

  Timer? _autoRefreshTimer;
  RealtimeChannel? _realtimeChannel;

  bool _loadingRows = true;
  bool _refreshingRows = false;
  bool _pendingReload = false;
  bool _inserting = false;
  bool _bulkDeleting = false;
  bool _exportingCsv = false;
  bool _insertRowActive = false;
  bool _hoverInsertAddButton = false;
  bool _marqueeActive = false;
  Offset? _marqueeStartLocal;
  Offset? _marqueePointerLocal;
  Offset? _marqueeStartContent;
  Offset? _marqueeCurrentContent;
  bool _marqueeAdditive = false;
  Set<String> _marqueeBaseSelection = <String>{};
  Timer? _marqueeAutoScrollTimer;
  double _marqueeAutoScrollVelocity = 0;

  List<Map<String, dynamic>> _rows = [];
  String? _selectedRowId;
  String? _selectionAnchorRowId;
  final Set<String> _bulkSelectedRowIds = <String>{};
  int _activeInsertColumn = 0;
  int _activeGridColumn = 0;
  int _currentPage = 0;
  int _pageSize = 40;
  bool _topBarSyncScheduled = false;

  static const int _insertColumnCount = 8;
  static const int _gridColumnCount = 8;
  static const List<String> _gridColumnLabels = <String>[
    'FECHA',
    'TURNO',
    'TIPO PACA',
    'PACAS',
    'PROM KG',
    'ORIGEN',
    'COMENTARIO',
    'ACCIONES',
  ];

  late _ProductionDraft _draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _insertFocusNode.addListener(_syncInsertRowFocusState);
    _insertCountFocusNode.addListener(_syncInsertRowFocusState);
    _insertAvgFocusNode.addListener(_syncInsertRowFocusState);
    _insertNotesFocusNode.addListener(_syncInsertRowFocusState);
    _initDraftDefaults();
    _loadRows();
    _setupAutoRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyTopBarChanged());
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _scheduleTopBarSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    _insertFocusNode.removeListener(_syncInsertRowFocusState);
    _insertCountFocusNode.removeListener(_syncInsertRowFocusState);
    _insertAvgFocusNode.removeListener(_syncInsertRowFocusState);
    _insertNotesFocusNode.removeListener(_syncInsertRowFocusState);
    _insertFocusNode.dispose();
    _rowsFocusNode.dispose();
    _insertCountFocusNode.dispose();
    _insertAvgFocusNode.dispose();
    _insertNotesFocusNode.dispose();
    _rowsScrollController.dispose();
    _marqueeAutoScrollTimer?.cancel();
    _draftCountC.dispose();
    _draftAvgC.dispose();
    _draftNotesC.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _requestReload();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _initDraftDefaults() {
    _draft = _ProductionDraft(
      opDate: null,
      shift: null,
      baleMaterial: null,
      sourceBulk: null,
      baleCount: null,
      avgBaleWeightKg: null,
      notes: '',
    );
    _draftCountC.clear();
    _draftAvgC.clear();
    _draftNotesC.clear();
    _activeInsertColumn = 0;
  }

  bool get _canInsert {
    final count = int.tryParse(_draftCountC.text.trim());
    final avg = _toDouble(_draftAvgC.text);
    return _draft.opDate != null &&
        _draft.shift != null &&
        _draft.baleMaterial != null &&
        _draft.sourceBulk != null &&
        _draft.sourceBulk!.trim().isNotEmpty &&
        count != null &&
        count > 0 &&
        avg != null &&
        avg > 0;
  }

  void _syncInsertRowFocusState() {
    final next =
        _insertFocusNode.hasFocus ||
        _insertCountFocusNode.hasFocus ||
        _insertAvgFocusNode.hasFocus ||
        _insertNotesFocusNode.hasFocus;
    if (_insertRowActive == next || !mounted) return;
    setState(() => _insertRowActive = next);
  }

  void _setupAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _requestReload();
    });
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = supa
        .channel('inventory-production-grid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'production_runs',
          callback: (_) => _requestReload(),
        )
        .subscribe();
  }

  void _requestReload() {
    if (!mounted) return;
    if (_refreshingRows ||
        _loadingRows ||
        _inserting ||
        _bulkDeleting ||
        _insertRowActive ||
        (_selectedRowState()?.isEditing ?? false) ||
        _isEditableTextFocused()) {
      _pendingReload = true;
      return;
    }
    unawaited(_refreshRowsIfIdle());
  }

  Future<void> _refreshRowsIfIdle() async {
    if (!mounted || _refreshingRows) return;
    _refreshingRows = true;
    try {
      await _loadRows(showLoader: false);
    } finally {
      _refreshingRows = false;
      if (_pendingReload) {
        _pendingReload = false;
        _requestReload();
      }
    }
  }

  bool _isEditableTextFocused() {
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  Future<void> _loadRows({bool showLoader = true}) async {
    if (showLoader && mounted) setState(() => _loadingRows = true);
    try {
      final data = await supa
          .from('production_runs')
          .select('*')
          .order('op_date', ascending: false)
          .order('created_at', ascending: false);
      final nextRows = (data as List).cast<Map<String, dynamic>>();
      final ids = nextRows.map((r) => r['id'] as String).toSet();
      final visibleIds = nextRows
          .where((r) => _matchesFilters(r))
          .map((r) => r['id'] as String)
          .toSet();
      final nextSelected =
          ids.contains(_selectedRowId) && visibleIds.contains(_selectedRowId)
          ? _selectedRowId
          : null;
      _rowKeys.removeWhere((id, _) => !ids.contains(id));
      if (!mounted) return;
      setState(() {
        _rows = nextRows;
        _selectedRowId = nextSelected;
        _bulkSelectedRowIds.removeWhere((id) => !ids.contains(id));
        _clampCurrentPage();
        if (showLoader) _loadingRows = false;
      });
      if (_selectedRowId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _activeInsertColumn = 0;
          _insertFocusNode.requestFocus();
        });
      }
    } catch (e) {
      _toast('No se pudo cargar producción: $e');
      if (mounted && showLoader) setState(() => _loadingRows = false);
    }
  }

  Future<void> _insertDraft() async {
    if (_inserting) return;
    if (!_canInsert) {
      await _showInsertMissingFieldsDialog();
      return;
    }
    final count = int.tryParse(_draftCountC.text.trim())!;
    final avg = _toDouble(_draftAvgC.text)!;
    final sourceBulk = _sourceBulkForBaleMaterial(
      _draft.baleMaterial,
      selectedSourceBulk: _draft.sourceBulk,
    );
    setState(() => _inserting = true);
    try {
      await supa.from('production_runs').insert({
        'op_date': _fmtDbDate(_draft.opDate!),
        'shift': _draft.shift,
        'site': 'DICSA_CELAYA',
        'bale_material': _draft.baleMaterial,
        'source_bulk': sourceBulk,
        'bale_count': count,
        'avg_bale_weight_kg': avg,
        'notes': _draftNotesC.text.trim().isEmpty
            ? null
            : _draftNotesC.text.trim(),
      });
      _toast('Producción agregada');
      _initDraftDefaults();
      await _loadRows(showLoader: false);
      await widget.onChanged?.call();
      if (!mounted) return;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _insertFocusNode.requestFocus();
      });
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('No se pudo insertar producción: $e');
    } finally {
      if (mounted) setState(() => _inserting = false);
    }
  }

  Future<void> _showInsertMissingFieldsDialog() async {
    final missing = <String>[];
    if (_draft.opDate == null) missing.add('Fecha');
    if (_draft.shift == null || _draft.shift!.trim().isEmpty) {
      missing.add('Turno');
    }
    if (_draft.baleMaterial == null || _draft.baleMaterial!.trim().isEmpty) {
      missing.add('Tipo de paca');
    }
    if ((_draft.sourceBulk ?? '').trim().isEmpty) {
      missing.add('Origen');
    }
    final count = int.tryParse(_draftCountC.text.trim());
    if (count == null || count <= 0) missing.add('Pacas');
    final avg = _toDouble(_draftAvgC.text);
    if (avg == null || avg <= 0) missing.add('Promedio kg');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFEAF2F9).withValues(alpha: 0.98),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFF8AA9C2).withValues(alpha: 0.42),
          ),
        ),
        title: const Text('No se puede agregar'),
        content: Text(
          missing.isEmpty
              ? 'Completa los campos obligatorios.'
              : 'Completa estos campos antes de agregar:\n• ${missing.join('\n• ')}',
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6A99C7),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRow(String id) async {
    try {
      await supa.from('production_runs').delete().eq('id', id);
      _bulkSelectedRowIds.remove(id);
      _toast('Eliminado');
      await _loadRows(showLoader: false);
      await widget.onChanged?.call();
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('No se pudo eliminar producción: $e');
    }
  }

  Future<void> _updateRow(String id, Map<String, dynamic> patch) async {
    try {
      await supa.from('production_runs').update(patch).eq('id', id);
      final idx = _rows.indexWhere((r) => r['id'] == id);
      if (idx != -1) {
        setState(() => _rows[idx] = {..._rows[idx], ...patch});
      } else {
        await _loadRows(showLoader: false);
      }
      await widget.onChanged?.call();
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('No se pudo actualizar producción: $e');
    }
  }

  Future<void> _deleteSelectedRows() async {
    if (_bulkSelectedRowIds.isEmpty || _bulkDeleting) return;
    final ok = await _showConfirmDialog(
      context,
      title: 'Eliminar seleccionados',
      content:
          '¿Eliminar ${_bulkSelectedRowIds.length} registro(s) de producción?',
      confirmText: 'Eliminar',
    );
    if (ok != true) return;
    setState(() => _bulkDeleting = true);
    try {
      final ids = _bulkSelectedRowIds.toList();
      await supa.from('production_runs').delete().inFilter('id', ids);
      _bulkSelectedRowIds.clear();
      _toast('Eliminados ${ids.length} registros');
      await _loadRows(showLoader: false);
      await widget.onChanged?.call();
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('No se pudieron eliminar registros de producción: $e');
    } finally {
      if (mounted) setState(() => _bulkDeleting = false);
    }
  }

  Future<void> _exportCsv() async {
    if (_exportingCsv) return;
    setState(() => _exportingCsv = true);
    try {
      final data = await supa
          .from('production_runs')
          .select('*')
          .order('op_date')
          .order('created_at');
      final rows = (data as List).cast<Map<String, dynamic>>();
      const headers = <String>[
        'id',
        'created_at',
        'op_date',
        'shift',
        'bale_material',
        'bale_count',
        'avg_bale_weight_kg',
        'produced_weight_kg',
        'source_bulk',
        'notes',
        'site',
      ];
      final sb = StringBuffer()
        ..write('\uFEFF')
        ..writeln(headers.join(','));
      for (final r in rows) {
        sb.writeln(headers.map((h) => _csvEscape(r[h])).join(','));
      }
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'production_runs_$stamp.csv';
      final path = await _writeDownloadsFile(fileName, sb.toString());
      _toast(
        path == null
            ? 'No se pudo guardar CSV en Descargas'
            : 'CSV exportado en: $path',
      );
    } catch (e) {
      _toast('No se pudo exportar CSV: $e');
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Future<String?> _writeDownloadsFile(String fileName, String content) async {
    final env = Platform.environment;
    final dirs = <Directory>[];
    if (Platform.isWindows) {
      final userProfile = env['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        dirs.add(Directory('$userProfile\\Downloads'));
      }
    } else {
      final home = env['HOME'];
      if (home != null && home.isNotEmpty) {
        dirs.add(Directory('$home/Downloads'));
        dirs.add(Directory('$home/Descargas'));
      }
    }
    for (final dir in dirs) {
      try {
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(content, encoding: utf8);
        return file.path;
      } catch (_) {}
    }
    return null;
  }

  String _csvEscape(dynamic value) {
    if (value == null) return '';
    final text = value.toString();
    final escaped = text.replaceAll('"', '""');
    final needsQuotes =
        escaped.contains(',') ||
        escaped.contains('\n') ||
        escaped.contains('"');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  List<String> _sourceBulkOptionsForBaleMaterial(String? baleMaterial) {
    return _productionSourceBulkOptionsForBaleMaterial(baleMaterial);
  }

  String? _sourceBulkForBaleMaterial(
    String? baleMaterial, {
    String? selectedSourceBulk,
  }) {
    return _productionSourceBulkForBaleMaterial(
      baleMaterial,
      selectedSourceBulk: selectedSourceBulk,
    );
  }

  String _cellTextForColumn(Map<String, dynamic> row, String columnId) {
    switch (columnId) {
      case 'fecha':
        return _fmtUiDate(_parseDate(row['op_date']));
      case 'turno':
        return _prodShiftLabel(row['shift']?.toString());
      case 'bale_material':
        return _prodBaleMaterialLabel(row['bale_material']?.toString());
      case 'pacas':
        return (row['bale_count'] ?? '').toString();
      case 'prom_kg':
        final n = _toDouble(row['avg_bale_weight_kg']);
        return n == null ? '' : n.toStringAsFixed(2);
      case 'origen':
        return _invMaterialLabel(row['source_bulk']?.toString());
      case 'notes':
        return (row['notes'] ?? '').toString().trim();
      default:
        return '';
    }
  }

  DateTime? _dateValueForColumn(Map<String, dynamic> row, String columnId) {
    if (columnId != 'fecha') return null;
    return _parseDate(row['op_date']);
  }

  bool _matchesFilters(Map<String, dynamic> row, {String? excludeColumn}) {
    for (final entry in _columnDateRangeFilters.entries) {
      if (entry.key == excludeColumn) continue;
      final value = _dateValueForColumn(row, entry.key);
      if (value == null) return false;
      final d = DateUtils.dateOnly(value);
      final s = DateUtils.dateOnly(entry.value.start);
      final e = DateUtils.dateOnly(entry.value.end);
      if (d.isBefore(s) || d.isAfter(e)) return false;
    }
    for (final entry in _columnValueFilters.entries) {
      if (entry.key == excludeColumn || entry.value.isEmpty) continue;
      if (!entry.value.contains(_cellTextForColumn(row, entry.key))) {
        return false;
      }
    }
    return true;
  }

  List<Map<String, dynamic>> get _filteredRows =>
      _rows.where((r) => _matchesFilters(r)).toList();
  List<Map<String, dynamic>> get _visibleRows {
    final filtered = _filteredRows;
    final start = _currentPage * _pageSize;
    if (start >= filtered.length) return <Map<String, dynamic>>[];
    final end = (start + _pageSize < filtered.length)
        ? start + _pageSize
        : filtered.length;
    return filtered.sublist(start, end);
  }

  int get _totalPages {
    final total = _filteredRows.length;
    if (total == 0) return 1;
    return ((total - 1) ~/ _pageSize) + 1;
  }

  void _clampCurrentPage() {
    final maxPage = _totalPages - 1;
    if (_currentPage > maxPage) _currentPage = maxPage;
    if (_currentPage < 0) _currentPage = 0;
  }

  bool _hasActiveFilter(String c) =>
      (_columnValueFilters[c]?.isNotEmpty ?? false) ||
      _columnDateRangeFilters.containsKey(c);
  bool _isDateFilterColumn(String c) => c == 'fecha';

  DateTimeRange _dateBoundsForColumn(String c) {
    DateTime? minDate;
    DateTime? maxDate;
    for (final row in _rows) {
      final d = _dateValueForColumn(row, c);
      if (d == null) continue;
      final x = DateUtils.dateOnly(d);
      if (minDate == null || x.isBefore(minDate)) minDate = x;
      if (maxDate == null || x.isAfter(maxDate)) maxDate = x;
    }
    final now = DateUtils.dateOnly(DateTime.now());
    return DateTimeRange(
      start: minDate ?? DateTime(now.year - 3, 1, 1),
      end: maxDate ?? DateTime(now.year + 3, 12, 31),
    );
  }

  List<String> _columnDistinctValues(String c, {String search = ''}) {
    final q = search.toLowerCase().trim();
    final values = <String>{};
    for (final row in _rows) {
      if (!_matchesFilters(row, excludeColumn: c)) continue;
      final v = _cellTextForColumn(row, c);
      if (v.isEmpty) continue;
      if (q.isNotEmpty && !v.toLowerCase().contains(q)) continue;
      values.add(v);
    }
    final list = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  Future<void> _openColumnFilter(String columnId, String label) async {
    if (_isDateFilterColumn(columnId)) {
      final result = await _showInvDateRangeFilterDialog(
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
        _columnValueFilters.remove(columnId);
        _clampCurrentPage();
      });
      return;
    }

    final initialSelected = {...(_columnValueFilters[columnId] ?? <String>{})};
    final result = await showDialog<_InvFilterDialogResult>(
      context: context,
      builder: (dialogContext) {
        final localSelected = <String>{...initialSelected};
        String localSearch = '';
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final options = _columnDistinctValues(
              columnId,
              search: localSearch,
            );
            final allVisibleSelected =
                options.isNotEmpty && options.every(localSelected.contains);
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 420,
                    constraints: const BoxConstraints(maxHeight: 560),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    decoration: _invFilterDialogDecoration(),
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
                          decoration: _invGlassFieldDecoration(
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
                        Expanded(
                          child: options.isEmpty
                              ? const Center(
                                  child: Text('Sin valores para mostrar'),
                                )
                              : ListView.builder(
                                  itemCount: options.length,
                                  itemBuilder: (context, i) {
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
                              style: _invFilterOutlinedButtonStyle(),
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: _invFilterOutlinedButtonStyle(),
                              onPressed: () => Navigator.pop(
                                dialogContext,
                                const _InvFilterDialogResult(
                                  selectedValues: <String>{},
                                ),
                              ),
                              child: const Text('Limpiar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: _invFilterFilledButtonStyle(),
                              onPressed: () => Navigator.pop(
                                dialogContext,
                                _InvFilterDialogResult(
                                  selectedValues: localSelected,
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
        );
      },
    );
    if (result == null) return;
    setState(() {
      if (result.selectedValues.isEmpty) {
        _columnValueFilters.remove(columnId);
      } else {
        _columnValueFilters[columnId] = result.selectedValues;
      }
      _columnDateRangeFilters.remove(columnId);
      _clampCurrentPage();
    });
  }

  String _fmtUiDate(DateTime d) {
    final yy = (d.year % 100).toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd/$mm/$yy';
  }

  String _fmtDbDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  DateTime _parseDate(dynamic v) {
    if (v is String && v.length >= 10) {
      final y = int.tryParse(v.substring(0, 4));
      final m = int.tryParse(v.substring(5, 7));
      final d = int.tryParse(v.substring(8, 10));
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return DateUtils.dateOnly(DateTime.now());
  }

  void _setActiveInsertColumn(int value, {bool requestFocus = true}) {
    setState(() {
      _activeInsertColumn =
          ((value % _insertColumnCount) + _insertColumnCount) %
          _insertColumnCount;
      _selectedRowId = null;
      _selectionAnchorRowId = null;
      _bulkSelectedRowIds.clear();
    });
    if (!requestFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (_activeInsertColumn) {
        case 3:
          FocusScope.of(context).requestFocus(_insertCountFocusNode);
          break;
        case 4:
          FocusScope.of(context).requestFocus(_insertAvgFocusNode);
          break;
        case 6:
          FocusScope.of(context).requestFocus(_insertNotesFocusNode);
          break;
        default:
          FocusManager.instance.primaryFocus?.unfocus();
          _insertFocusNode.requestFocus();
      }
    });
  }

  void _moveInsertColumn(int delta) =>
      _setActiveInsertColumn(_activeInsertColumn + delta);

  bool _caretAtStart(TextEditingController c, FocusNode f) {
    if (!f.hasFocus) return false;
    final s = c.selection;
    return s.isValid &&
        s.isCollapsed &&
        s.baseOffset == 0 &&
        s.extentOffset == 0;
  }

  bool _caretAtEnd(TextEditingController c, FocusNode f) {
    if (!f.hasFocus) return false;
    final s = c.selection;
    final end = c.text.length;
    return s.isValid &&
        s.isCollapsed &&
        s.baseOffset == end &&
        s.extentOffset == end;
  }

  Future<void> _activateInsertCellFromKeyboard() async {
    switch (_activeInsertColumn) {
      case 0:
        final d = await _showInvKeyboardDatePickerDialog(
          context: context,
          initialDate: _draft.opDate ?? DateTime.now(),
          firstDate: DateTime(2024, 1, 1),
          lastDate: DateTime(2035, 12, 31),
        );
        if (d != null && mounted) {
          setState(
            () => _draft = _draft.copyWith(opDate: DateUtils.dateOnly(d)),
          );
        }
        return;
      case 1:
        final shift = await _showInvSearchablePickerDialog<String>(
          context,
          title: 'Turno',
          initialValue: _draft.shift,
          options: const [
            _InvPickerOption<String>(value: 'DAY', label: 'Día'),
            _InvPickerOption<String>(value: 'NIGHT', label: 'Noche'),
          ],
        );
        if (shift != null && mounted) {
          setState(() => _draft = _draft.copyWith(shift: shift));
        }
        return;
      case 2:
        final material = await _showInvSearchablePickerDialog<String>(
          context,
          title: 'Tipo de paca',
          initialValue: _draft.baleMaterial,
          options: const [
            _InvPickerOption<String>(
              value: 'BALE_NATIONAL',
              label: 'Paca nacional',
            ),
            _InvPickerOption<String>(
              value: 'BALE_AMERICAN',
              label: 'Paca americana',
            ),
            _InvPickerOption<String>(value: 'BALE_CLEAN', label: 'Paca limpia'),
            _InvPickerOption<String>(value: 'BALE_TRASH', label: 'Paca basura'),
            _InvPickerOption<String>(value: 'CAPLE', label: 'Paca caple'),
          ],
        );
        if (material != null && mounted) {
          final options = _sourceBulkOptionsForBaleMaterial(material);
          setState(
            () => _draft = _draft.copyWith(
              baleMaterial: material,
              sourceBulk: options.isEmpty ? null : options.first,
            ),
          );
        }
        return;
      case 5:
        final options = _sourceBulkOptionsForBaleMaterial(_draft.baleMaterial);
        if (options.isEmpty) return;
        final source = await _showInvSearchablePickerDialog<String>(
          context,
          title: 'Origen',
          initialValue: _sourceBulkForBaleMaterial(
            _draft.baleMaterial,
            selectedSourceBulk: _draft.sourceBulk,
          ),
          options: options
              .map(
                (value) => _InvPickerOption<String>(
                  value: value,
                  label: _invMaterialLabel(value),
                ),
              )
              .toList(),
        );
        if (source != null && mounted) {
          setState(() => _draft = _draft.copyWith(sourceBulk: source));
        }
        return;
      case 7:
        await _insertDraft();
        return;
      default:
        return;
    }
  }

  void _clearActiveInsertCell() {
    switch (_activeInsertColumn) {
      case 0:
        setState(() => _draft = _draft.copyWith(opDate: null));
        return;
      case 1:
        setState(() => _draft = _draft.copyWith(shift: null));
        return;
      case 2:
        setState(
          () => _draft = _draft.copyWith(baleMaterial: null, sourceBulk: null),
        );
        return;
      case 5:
        setState(() => _draft = _draft.copyWith(sourceBulk: null));
        return;
      case 3:
        _draftCountC.clear();
        setState(() => _draft = _draft.copyWith(baleCount: null));
        return;
      case 4:
        _draftAvgC.clear();
        setState(() => _draft = _draft.copyWith(avgBaleWeightKg: null));
        return;
      case 6:
        _draftNotesC.clear();
        setState(() => _draft = _draft.copyWith(notes: ''));
        return;
      default:
        return;
    }
  }

  void _focusGridFromInsert() {
    final firstVisibleId = _visibleRows.isEmpty
        ? null
        : _visibleRows.first['id'] as String;
    setState(() {
      _activeGridColumn = _activeInsertColumn > 7 ? 7 : _activeInsertColumn;
      if (firstVisibleId != null) {
        _selectedRowId = firstVisibleId;
        _selectionAnchorRowId = firstVisibleId;
        _bulkSelectedRowIds.clear();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rowsFocusNode.requestFocus();
    });
  }

  void _requestRowsFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rowsFocusNode.requestFocus();
    });
  }

  void _focusInsertFromGrid() {
    setState(() {
      _activeInsertColumn = _activeGridColumn > 7 ? 7 : _activeGridColumn;
      _selectedRowId = null;
      _selectionAnchorRowId = null;
      _bulkSelectedRowIds.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setActiveInsertColumn(_activeInsertColumn);
    });
  }

  void _selectRow(
    String id, {
    bool additive = false,
    bool allowToggle = false,
  }) {
    setState(() {
      if (additive) {
        if (_bulkSelectedRowIds.contains(id)) {
          _bulkSelectedRowIds.remove(id);
          if (_selectedRowId == id) {
            _selectedRowId = _bulkSelectedRowIds.isEmpty
                ? null
                : _bulkSelectedRowIds.last;
          }
        } else {
          if (_selectedRowId != null) _bulkSelectedRowIds.add(_selectedRowId!);
          _bulkSelectedRowIds.add(id);
          _selectedRowId = id;
          _selectionAnchorRowId ??= id;
        }
        return;
      }
      if (allowToggle && _selectedRowId == id) {
        _selectedRowId = null;
        _bulkSelectedRowIds.clear();
        return;
      }
      _selectedRowId = id;
      _selectionAnchorRowId = id;
      _bulkSelectedRowIds.clear();
    });
  }

  void _selectRowRangeTo(String id) {
    final rows = _visibleRows;
    if (rows.isEmpty) return;
    final anchorId = _selectionAnchorRowId ?? _selectedRowId ?? id;
    final anchorIndex = rows.indexWhere((r) => r['id'] == anchorId);
    final targetIndex = rows.indexWhere((r) => r['id'] == id);
    if (anchorIndex == -1 || targetIndex == -1) {
      _selectRow(id);
      return;
    }
    final from = anchorIndex <= targetIndex ? anchorIndex : targetIndex;
    final to = anchorIndex <= targetIndex ? targetIndex : anchorIndex;
    final ids = rows
        .sublist(from, to + 1)
        .map((r) => r['id'] as String)
        .toSet();
    setState(() {
      _selectionAnchorRowId = anchorId;
      _selectedRowId = id;
      _bulkSelectedRowIds
        ..clear()
        ..addAll(ids);
    });
  }

  void _moveSelectedRow(int delta, {bool extendSelection = false}) {
    final rows = _visibleRows;
    if (rows.isEmpty) return;
    final currentIndex = _selectedRowId == null
        ? -1
        : rows.indexWhere((r) => r['id'] == _selectedRowId);
    final nextIndex = currentIndex == -1
        ? (delta >= 0 ? 0 : rows.length - 1)
        : (((currentIndex + delta) % rows.length) + rows.length) % rows.length;
    final id = rows[nextIndex]['id'] as String;
    if (extendSelection) {
      _selectRowRangeTo(id);
    } else {
      _selectRow(id);
    }
    if (_rowsScrollController.hasClients) {
      _rowsScrollController.animateTo(
        (nextIndex * 78.0)
            .clamp(0.0, _rowsScrollController.position.maxScrollExtent)
            .toDouble(),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
      );
    }
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

  bool _isSelectionExtendPressed() {
    return _isCtrlOrCmdPressed() || _isShiftPressed();
  }

  _ProductionDataRowState? _selectedRowState() {
    final id = _selectedRowId;
    if (id == null) return null;
    return _rowKeys[id]?.currentState;
  }

  List<_ProductionDataRowState> _selectedRowStates() {
    if (_bulkSelectedRowIds.isEmpty) {
      final s = _selectedRowState();
      return s == null ? const [] : [s];
    }
    final ids = <String>[];
    if (_selectedRowId != null) ids.add(_selectedRowId!);
    for (final id in _bulkSelectedRowIds) {
      if (!ids.contains(id)) ids.add(id);
    }
    return ids
        .map((id) => _rowKeys[id]?.currentState)
        .whereType<_ProductionDataRowState>()
        .toList();
  }

  int get _selectedCount {
    final ids = <String>{..._bulkSelectedRowIds};
    if (_selectedRowId != null) ids.add(_selectedRowId!);
    return ids.length;
  }

  Set<String> _prodCurrentSelectionIds() {
    final ids = <String>{..._bulkSelectedRowIds};
    if (_selectedRowId != null) ids.add(_selectedRowId!);
    return ids;
  }

  bool get _prodHasExplicitMultiSelection =>
      _prodCurrentSelectionIds().length > 1;

  bool get _prodAnyRowEditing => _rowKeys.values
      .map((k) => k.currentState)
      .whereType<_ProductionDataRowState>()
      .any((s) => s.isEditing);

  bool get _prodAnyEditingRowTextFocused => _rowKeys.values
      .map((k) => k.currentState)
      .whereType<_ProductionDataRowState>()
      .any((s) => s.isAnyEditableTextFocused);

  double get _prodRowsScrollOffset =>
      _rowsScrollController.hasClients ? _rowsScrollController.offset : 0.0;

  Offset _prodLocalToContent(Offset local) =>
      Offset(local.dx, local.dy + _prodRowsScrollOffset);

  Rect _prodMarqueeRectContent() {
    final start = _marqueeStartContent ?? Offset.zero;
    final current = _marqueeCurrentContent ?? start;
    return Rect.fromPoints(start, current);
  }

  Rect _prodMarqueeRectForPaint() =>
      _prodMarqueeRectContent().shift(Offset(0, -_prodRowsScrollOffset));

  Rect _prodClampRectToViewport(Rect rectViewport) {
    final box =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return rectViewport;
    final size = box.size;
    final left = rectViewport.left.clamp(0.0, size.width);
    final top = rectViewport.top.clamp(0.0, size.height);
    final right = rectViewport.right.clamp(0.0, size.width);
    final bottom = rectViewport.bottom.clamp(0.0, size.height);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  double _prodEffectiveRowExtent() {
    for (final row in _visibleRows) {
      final id = row['id'] as String;
      final rowContext = _rowKeys[id]?.currentContext;
      final rowBox = rowContext?.findRenderObject() as RenderBox?;
      if (rowBox != null && rowBox.hasSize && rowBox.size.height > 0) {
        return rowBox.size.height;
      }
    }
    return 78.0;
  }

  Set<String> _prodMarqueeIntersectedIds(Rect rectContent) {
    final viewportContext = _rowsViewportKey.currentContext;
    if (viewportContext == null) return const <String>{};
    final viewportBox = viewportContext.findRenderObject() as RenderBox?;
    if (viewportBox == null) return const <String>{};
    if (rectContent.right <= 0 || rectContent.left >= viewportBox.size.width) {
      return const <String>{};
    }
    final rows = _visibleRows;
    if (rows.isEmpty) return const <String>{};
    final rowExtent = _prodEffectiveRowExtent();
    final top = rectContent.top.clamp(0.0, double.infinity);
    final bottom = rectContent.bottom.clamp(0.0, double.infinity);
    final from = (top / rowExtent).floor().clamp(0, rows.length - 1);
    final to = (bottom / rowExtent).floor().clamp(0, rows.length - 1);
    if (to < from) return const <String>{};
    return rows.sublist(from, to + 1).map((r) => r['id'] as String).toSet();
  }

  void _prodApplyMarqueeSelection() {
    if (!_marqueeActive) return;
    final rect = _prodMarqueeRectContent();
    final hit = _prodMarqueeIntersectedIds(rect);
    final next = _marqueeAdditive ? ({..._marqueeBaseSelection, ...hit}) : hit;
    String? nextPrimary;
    for (final row in _visibleRows) {
      final id = row['id'] as String;
      if (hit.contains(id)) nextPrimary = id;
    }
    nextPrimary ??= next.isNotEmpty ? next.last : null;
    setState(() {
      _bulkSelectedRowIds
        ..clear()
        ..addAll(next);
      _selectedRowId = nextPrimary;
      _selectionAnchorRowId = nextPrimary;
    });
  }

  Offset? _prodGlobalToRowsLocal(Offset globalPosition) {
    final box =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.globalToLocal(globalPosition);
  }

  bool _prodIsGlobalPointInsideKey(GlobalKey key, Offset globalPosition) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final local = box.globalToLocal(globalPosition);
    return local.dx >= 0 &&
        local.dy >= 0 &&
        local.dx <= box.size.width &&
        local.dy <= box.size.height;
  }

  void _prodUpdateMarqueeAutoScroll() {
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
      (_) => _prodTickMarqueeAutoScroll(),
    );
  }

  void _prodTickMarqueeAutoScroll() {
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
      _marqueeCurrentContent = _prodLocalToContent(_marqueePointerLocal!);
    }
    _prodApplyMarqueeSelection();
  }

  void _prodOnRowsPointerDown(PointerDownEvent event) {
    if (_prodAnyRowEditing) return;
    if (_visibleRows.isEmpty) return;
    if (event.kind != PointerDeviceKind.mouse) return;
    if ((event.buttons & kPrimaryMouseButton) == 0) return;
    if (_prodIsGlobalPointInsideKey(_insertRowKey, event.position)) return;
    final local = _prodGlobalToRowsLocal(event.position);
    if (local == null) return;
    _marqueeStartLocal = local;
    _marqueePointerLocal = local;
    _marqueeStartContent = _prodLocalToContent(local);
    _marqueeCurrentContent = _marqueeStartContent;
    _marqueeAdditive = _isSelectionExtendPressed();
    _marqueeBaseSelection = _prodCurrentSelectionIds();
    _marqueeActive = false;
  }

  void _prodOnRowsPointerMove(PointerMoveEvent event) {
    if (_marqueeStartLocal == null) return;
    final local = _prodGlobalToRowsLocal(event.position);
    if (local == null) return;
    _marqueePointerLocal = local;
    _marqueeCurrentContent = _prodLocalToContent(local);
    final shouldActivate = (local - _marqueeStartLocal!).distance > 6;
    if (!shouldActivate && !_marqueeActive) return;
    if (!_marqueeActive && mounted) {
      setState(() => _marqueeActive = true);
    }
    _prodApplyMarqueeSelection();
    _prodUpdateMarqueeAutoScroll();
  }

  void _prodFinishRowsMarqueeSelection() {
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

  void _prodStartEditingSelectedRows() {
    final states = _selectedRowStates();
    if (states.isEmpty) return;
    setState(() => _activeGridColumn = 0);
    for (final state in states) {
      state.startEditingFromKeyboard();
    }
    _requestRowsFocus();
  }

  Future<void> _prodSaveSelectedRows() async {
    final states = _selectedRowStates();
    if (states.isEmpty) return;
    await Future.wait(states.map((s) => s.saveFromKeyboard()));
    if (mounted) setState(() {});
    _requestRowsFocus();
  }

  void _prodCancelSelectedRowsEditing() {
    final states = _selectedRowStates();
    for (final state in states) {
      state.cancelEditingFromKeyboard();
    }
    if (mounted) setState(() {});
    _requestRowsFocus();
  }

  Future<void> _prodOpenRowsContextMenuAt(Offset globalPosition) async {
    final selectedStates = _selectedRowStates();
    final anyEditing = selectedStates.any((s) => s.isEditing);
    final multiContext = _prodHasExplicitMultiSelection;
    const menuTextStyle = TextStyle(
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
      color: Color(0xFF223D5A),
    );
    final media = MediaQuery.of(context).size;
    final action = await showMenu<String>(
      context: context,
      color: _kInvGlassMenuBg,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        media.width - globalPosition.dx,
        media.height - globalPosition.dy,
      ),
      items: [
        if (multiContext && !anyEditing)
          const PopupMenuItem(
            value: 'multi_edit',
            child: Text('EDITAR SELECCIÓN', style: menuTextStyle),
          ),
        if (multiContext && anyEditing)
          const PopupMenuItem(
            value: 'multi_save',
            child: Text('GUARDAR SELECCIÓN', style: menuTextStyle),
          ),
        if (multiContext && anyEditing)
          const PopupMenuItem(
            value: 'multi_cancel',
            child: Text('CANCELAR EDICIÓN', style: menuTextStyle),
          ),
        if (!multiContext && !anyEditing)
          const PopupMenuItem(
            value: 'edit',
            child: Text('EDITAR', style: menuTextStyle),
          ),
        if (!multiContext && anyEditing)
          const PopupMenuItem(
            value: 'save',
            child: Text('GUARDAR', style: menuTextStyle),
          ),
        if (!multiContext && anyEditing)
          const PopupMenuItem(
            value: 'cancel',
            child: Text('CANCELAR', style: menuTextStyle),
          ),
        const PopupMenuDivider(),
        if (multiContext)
          const PopupMenuItem(
            value: 'multi_delete',
            child: Text('ELIMINAR SELECCIÓN', style: menuTextStyle),
          ),
        if (!multiContext)
          const PopupMenuItem(
            value: 'delete',
            child: Text('ELIMINAR', style: menuTextStyle),
          ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        _handleEnterOnSelectedRow();
        break;
      case 'save':
        await _prodSaveSelectedRows();
        break;
      case 'cancel':
        _prodCancelSelectedRowsEditing();
        break;
      case 'delete':
        _handleDeleteOnSelectedRow();
        break;
      case 'multi_edit':
        _prodStartEditingSelectedRows();
        break;
      case 'multi_save':
        await _prodSaveSelectedRows();
        break;
      case 'multi_cancel':
        _prodCancelSelectedRowsEditing();
        break;
      case 'multi_delete':
        await _deleteSelectedRows();
        break;
    }
  }

  int get _filteredBaleCount {
    int total = 0;
    for (final row in _filteredRows) {
      final raw = row['bale_count'];
      if (raw is num) {
        total += raw.toInt();
      } else {
        total += int.tryParse((raw ?? '').toString()) ?? 0;
      }
    }
    return total;
  }

  double _rowProducedKg(Map<String, dynamic> row) {
    final countRaw = row['bale_count'];
    final avgRaw = row['avg_bale_weight_kg'];
    final count = countRaw is num
        ? countRaw.toDouble()
        : double.tryParse((countRaw ?? '').toString()) ?? 0;
    final avg = avgRaw is num
        ? avgRaw.toDouble()
        : double.tryParse((avgRaw ?? '').toString()) ?? 0;
    return count * avg;
  }

  ({double sum, double avg}) _selectedProducedStats() {
    final ids = _prodCurrentSelectionIds();
    if (ids.isEmpty) return (sum: 0, avg: 0);
    final byId = <String, Map<String, dynamic>>{
      for (final row in _visibleRows) row['id'] as String: row,
    };
    double sum = 0;
    var count = 0;
    for (final id in ids) {
      final row = byId[id];
      if (row == null) continue;
      sum += _rowProducedKg(row);
      count++;
    }
    final avg = count == 0 ? 0.0 : sum / count;
    return (sum: sum, avg: avg);
  }

  void _scheduleTopBarSync() {
    if (_topBarSyncScheduled || widget.onTopBarChanged == null) return;
    _topBarSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _topBarSyncScheduled = false;
      _notifyTopBarChanged();
    });
  }

  void _notifyTopBarChanged() {
    if (!mounted || widget.onTopBarChanged == null) return;
    widget.onTopBarChanged!(_buildTopBarData());
  }

  InventoryGridTopBarData _buildTopBarData() {
    final activeCell = (_selectedRowState()?.isEditing ?? false)
        ? _activeGridColumnLabel
        : null;
    final selectedStats = _selectedProducedStats();
    return InventoryGridTopBarData(
      metricIcon: Icons.view_in_ar_rounded,
      metricLabel: 'PACAS PRODUCIDAS',
      metricValue: _fmtInvInt(_filteredBaleCount),
      metricSubtitle:
          'Filtrado (${_fmtInvInt(_filteredRows.length)} registros)',
      exportingCsv: _exportingCsv,
      gridEditMode: false,
      canToggleGridEdit: _visibleRows.isNotEmpty,
      canDeleteSelection: _bulkSelectedRowIds.isNotEmpty,
      deletingSelection: _bulkDeleting,
      selectedCount: _selectedCount,
      selectedKgSumLabel: _selectedCount > 0
          ? '${_fmtInvCount(selectedStats.sum, decimals: 2)} kg'
          : null,
      selectedKgAvgLabel: _selectedCount > 0
          ? '${_fmtInvCount(selectedStats.avg, decimals: 2)} kg'
          : null,
      activeCellLabel: activeCell,
      onExportCsv: _exportingCsv ? null : _exportCsv,
      onToggleGridEdit: null,
      onSaveGridEdit: null,
      onCancelGridEdit: null,
      onDeleteSelection: _bulkDeleting ? null : _deleteSelectedRows,
    );
  }

  void _handleEnterOnSelectedRow() {
    final states = _selectedRowStates();
    if (states.isEmpty) return;
    if (states.any((s) => !s.isEditing)) {
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
    if (states.any((s) => s.isEditing)) {
      for (final s in states) {
        s.cancelEditingFromKeyboard();
      }
      return;
    }
    setState(() {
      _selectedRowId = null;
      _selectionAnchorRowId = null;
      _bulkSelectedRowIds.clear();
    });
  }

  void _handleDeleteOnSelectedRow() {
    if (_bulkSelectedRowIds.length > 1) {
      unawaited(_deleteSelectedRows());
      return;
    }
    final s = _selectedRowState();
    if (s != null) unawaited(s.deleteWithConfirmation());
  }

  void _moveGridColumn(int delta) {
    setState(() {
      _activeGridColumn =
          ((_activeGridColumn + delta) % _gridColumnCount + _gridColumnCount) %
          _gridColumnCount;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectedRowState()?.focusTextIfNeeded(_activeGridColumn);
    });
  }

  void _moveGridRow(int delta, {bool extendSelection = false}) {
    _moveSelectedRow(delta, extendSelection: extendSelection);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectedRowState()?.focusTextIfNeeded(_activeGridColumn);
    });
  }

  void _activateGridCellFromKeyboard() {
    final s = _selectedRowState();
    if (s == null) return;
    if (!s.isEditing) s.startEditingFromKeyboard();
    unawaited(s.activateGridCell(_activeGridColumn));
  }

  String get _activeGridColumnLabel => _gridColumnLabels[_activeGridColumn];

  @override
  Widget build(BuildContext context) {
    if (_loadingRows) return const Center(child: CircularProgressIndicator());

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _prodOnRowsPointerDown,
      onPointerMove: _prodOnRowsPointerMove,
      onPointerUp: (_) => _prodFinishRowsMarqueeSelection(),
      onPointerCancel: (_) => _prodFinishRowsMarqueeSelection(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showTopBarChrome)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
              child: InventoryGridTopBar(data: _buildTopBarData()),
            ),
          _ProductionHeaderRow(
            hasActiveFilter: _hasActiveFilter,
            onOpenFilter: _openColumnFilter,
          ),
          const SizedBox(height: 8),
          _buildInlineInsertRow(),
          const SizedBox(height: 8),
          Expanded(
            child: Focus(
              focusNode: _rowsFocusNode,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                  return KeyEventResult.ignored;
                }
                final key = event.logicalKey;
                final selectedState = _selectedRowState();
                final keyboardCellMode = _prodAnyRowEditing;
                final inTextEditing =
                    selectedState?.isTextCellFocused(_activeGridColumn) ??
                    false;
                final anyTextEditing = _prodAnyEditingRowTextFocused;
                if (keyboardCellMode) {
                  if (key == LogicalKeyboardKey.arrowLeft) {
                    if (inTextEditing &&
                        !(selectedState?.activeTextCaretAtStart(
                              _activeGridColumn,
                            ) ??
                            false)) {
                      return KeyEventResult.ignored;
                    }
                    _moveGridColumn(-1);
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.arrowRight) {
                    if (inTextEditing &&
                        !(selectedState?.activeTextCaretAtEnd(
                              _activeGridColumn,
                            ) ??
                            false)) {
                      return KeyEventResult.ignored;
                    }
                    _moveGridColumn(1);
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.arrowDown) {
                    _moveGridRow(
                      1,
                      extendSelection: _isSelectionExtendPressed(),
                    );
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.arrowUp) {
                    final firstVisible = _visibleRows.isNotEmpty
                        ? _visibleRows.first['id'] as String
                        : null;
                    if (firstVisible != null &&
                        _selectedRowId == firstVisible) {
                      if (_isSelectionExtendPressed()) {
                        return KeyEventResult.handled;
                      }
                      _focusInsertFromGrid();
                    } else {
                      _moveGridRow(
                        -1,
                        extendSelection: _isSelectionExtendPressed(),
                      );
                    }
                    return KeyEventResult.handled;
                  }
                  if (key == LogicalKeyboardKey.space) {
                    if (inTextEditing) return KeyEventResult.ignored;
                    _activateGridCellFromKeyboard();
                    return KeyEventResult.handled;
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
                    return anyTextEditing
                        ? KeyEventResult.ignored
                        : KeyEventResult.handled;
                  }
                }
                if (key == LogicalKeyboardKey.arrowDown) {
                  _moveSelectedRow(
                    1,
                    extendSelection: _isSelectionExtendPressed(),
                  );
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowUp) {
                  final firstVisible = _visibleRows.isNotEmpty
                      ? _visibleRows.first['id'] as String
                      : null;
                  if (firstVisible == null ||
                      _selectedRowId == null ||
                      _selectedRowId == firstVisible) {
                    if (_isSelectionExtendPressed()) {
                      return KeyEventResult.handled;
                    }
                    _focusInsertFromGrid();
                  } else {
                    _moveSelectedRow(
                      -1,
                      extendSelection: _isSelectionExtendPressed(),
                    );
                  }
                  return KeyEventResult.handled;
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
                  if (keyboardCellMode ||
                      anyTextEditing ||
                      _prodAnyRowEditing) {
                    return KeyEventResult.ignored;
                  }
                  _handleDeleteOnSelectedRow();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: _visibleRows.isEmpty
                  ? const Center(child: Text('Sin producción registrada'))
                  : Container(
                      key: _rowsViewportKey,
                      child: ClipRect(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AbsorbPointer(
                              absorbing: _marqueeActive,
                              child: ListView.builder(
                                controller: _rowsScrollController,
                                padding: const EdgeInsets.only(bottom: 12),
                                itemCount: _visibleRows.length,
                                itemBuilder: (_, i) {
                                  final row = _visibleRows[i];
                                  final id = row['id'] as String;
                                  return _ProductionDataRow(
                                    key: _rowKeys.putIfAbsent(
                                      id,
                                      () =>
                                          GlobalKey<_ProductionDataRowState>(),
                                    ),
                                    row: row,
                                    isSelected: _selectedRowId == id,
                                    isChecked: _bulkSelectedRowIds.contains(id),
                                    selectedCount: _selectedCount,
                                    activeGridColumn: _activeGridColumn,
                                    onDelete: _deleteRow,
                                    onUpdate: _updateRow,
                                    onOpenContextMenu:
                                        _prodOpenRowsContextMenuAt,
                                    onMultiEdit: _prodStartEditingSelectedRows,
                                    onSelect: (additive) {
                                      _selectRow(
                                        id,
                                        additive: additive,
                                        allowToggle: false,
                                      );
                                      _requestRowsFocus();
                                    },
                                    onActivateColumn: (col) {
                                      final rowNeedsSelection =
                                          _selectedRowId != id ||
                                          _bulkSelectedRowIds.isNotEmpty;
                                      if (rowNeedsSelection) {
                                        _selectRow(id);
                                      }
                                      if (_activeGridColumn != col) {
                                        setState(() => _activeGridColumn = col);
                                      }
                                      _requestRowsFocus();
                                    },
                                  );
                                },
                              ),
                            ),
                            if (_marqueeActive)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _MarqueeSelectionPainter(
                                      rect: _prodClampRectToViewport(
                                        _prodMarqueeRectForPaint(),
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
            padding: const EdgeInsets.only(top: 8),
            child: Card(
              elevation: 0,
              color: Colors.white.withValues(alpha: 0.30),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: _invActionOutlinedButtonStyle(),
                      onPressed: _currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Anterior'),
                    ),
                    Text(
                      'Página ${_fmtInvInt(_currentPage + 1)} de ${_fmtInvInt(_totalPages)}',
                    ),
                    OutlinedButton.icon(
                      style: _invActionOutlinedButtonStyle(),
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
                        decoration: _invGlassFieldDecoration(),
                        items: const [40, 80, 120]
                            .map(
                              (e) => DropdownMenuItem<int>(
                                value: e,
                                child: Text('$e'),
                              ),
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
                    Text('Total: ${_fmtInvInt(_filteredRows.length)}'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineInsertRow() {
    final produced =
        (int.tryParse(_draftCountC.text.trim()) ?? 0) *
        (_toDouble(_draftAvgC.text) ?? 0);
    return Card(
      key: _insertRowKey,
      elevation: 0.4,
      color: _insertRowActive
          ? const Color(0xFFD9ECFA)
          : const Color(0xFFE7F1F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _insertRowActive
              ? const Color(0xFF3C8DCC).withValues(alpha: 0.55)
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            Widget frame(int col, Widget child) {
              final active = _activeInsertColumn == col;
              return DecoratedBox(
                position: DecorationPosition.background,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: active
                      ? const Color(0xFFDCEAF7).withValues(alpha: 0.72)
                      : Colors.transparent,
                ),
                child: DecoratedBox(
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
                ),
              );
            }

            Widget control(Widget child) {
              return SizedBox(height: 34, child: child);
            }

            return Focus(
              focusNode: _insertFocusNode,
              autofocus: false,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                final key = event.logicalKey;
                if (key == LogicalKeyboardKey.arrowLeft) {
                  if (_insertCountFocusNode.hasFocus &&
                      !_caretAtStart(_draftCountC, _insertCountFocusNode)) {
                    return KeyEventResult.ignored;
                  }
                  if (_insertAvgFocusNode.hasFocus &&
                      !_caretAtStart(_draftAvgC, _insertAvgFocusNode)) {
                    return KeyEventResult.ignored;
                  }
                  if (_insertNotesFocusNode.hasFocus &&
                      !_caretAtStart(_draftNotesC, _insertNotesFocusNode)) {
                    return KeyEventResult.ignored;
                  }
                  _moveInsertColumn(-1);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowRight) {
                  if (_insertCountFocusNode.hasFocus &&
                      !_caretAtEnd(_draftCountC, _insertCountFocusNode)) {
                    return KeyEventResult.ignored;
                  }
                  if (_insertAvgFocusNode.hasFocus &&
                      !_caretAtEnd(_draftAvgC, _insertAvgFocusNode)) {
                    return KeyEventResult.ignored;
                  }
                  if (_insertNotesFocusNode.hasFocus &&
                      !_caretAtEnd(_draftNotesC, _insertNotesFocusNode)) {
                    return KeyEventResult.ignored;
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
                  if (_insertCountFocusNode.hasFocus ||
                      _insertAvgFocusNode.hasFocus ||
                      _insertNotesFocusNode.hasFocus) {
                    return KeyEventResult.ignored;
                  }
                  unawaited(_activateInsertCellFromKeyboard());
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.delete ||
                    key == LogicalKeyboardKey.backspace) {
                  if (_insertCountFocusNode.hasFocus ||
                      _insertAvgFocusNode.hasFocus ||
                      _insertNotesFocusNode.hasFocus) {
                    return KeyEventResult.ignored;
                  }
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
                  unawaited(_insertDraft());
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: SizedBox(
                width: constraints.maxWidth,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _prodTableContentWFor(constraints.maxWidth),
                    child: Row(
                      children: [
                        frame(
                          0,
                          SizedBox(
                            width: _kProdDateColW,
                            child: control(
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  _setActiveInsertColumn(0);
                                  final d =
                                      await _showInvKeyboardDatePickerDialog(
                                        context: context,
                                        initialDate:
                                            _draft.opDate ?? DateTime.now(),
                                        firstDate: DateTime(2024, 1, 1),
                                        lastDate: DateTime(2035, 12, 31),
                                      );
                                  if (d != null && mounted) {
                                    setState(
                                      () => _draft = _draft.copyWith(
                                        opDate: DateUtils.dateOnly(d),
                                      ),
                                    );
                                  }
                                },
                                child: InputDecorator(
                                  decoration: _invGlassFieldDecoration(),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _InvFitText(
                                          _draft.opDate == null
                                              ? '—'
                                              : _fmtUiDate(_draft.opDate!),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.calendar_month,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        frame(
                          1,
                          SizedBox(
                            width: _kProdShiftColW,
                            child: control(
                              _InvDropStrInline(
                                value: _draft.shift,
                                items: const ['DAY', 'NIGHT'],
                                format: (v) => _prodShiftLabel(v),
                                onTapStart: () => _setActiveInsertColumn(1),
                                onChanged: (v) => setState(
                                  () => _draft = _draft.copyWith(shift: v),
                                ),
                              ),
                            ),
                          ),
                        ),
                        frame(
                          2,
                          SizedBox(
                            width: _kProdBaleTypeColW,
                            child: control(
                              _InvDropStrInline(
                                value: _draft.baleMaterial,
                                items: _kProductionBaleMaterials,
                                format: (v) => _prodBaleMaterialLabel(v),
                                onTapStart: () => _setActiveInsertColumn(2),
                                onChanged: (v) {
                                  final sourceOptions =
                                      _sourceBulkOptionsForBaleMaterial(v);
                                  setState(
                                    () => _draft = _draft.copyWith(
                                      baleMaterial: v,
                                      sourceBulk: sourceOptions.isEmpty
                                          ? null
                                          : sourceOptions.contains(
                                              _draft.sourceBulk,
                                            )
                                          ? _draft.sourceBulk
                                          : sourceOptions.first,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        frame(
                          3,
                          SizedBox(
                            width: _kProdBalesColW,
                            child: control(
                              TextField(
                                controller: _draftCountC,
                                focusNode: _insertCountFocusNode,
                                keyboardType: TextInputType.number,
                                decoration: _invGlassFieldDecoration(
                                  hintText: 'Pacas',
                                ),
                                onTap: () => _setActiveInsertColumn(
                                  3,
                                  requestFocus: false,
                                ),
                                onChanged: (t) => setState(
                                  () => _draft = _draft.copyWith(
                                    baleCount: int.tryParse(t.trim()),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        frame(
                          4,
                          SizedBox(
                            width: _kProdAvgColW,
                            child: control(
                              TextField(
                                controller: _draftAvgC,
                                focusNode: _insertAvgFocusNode,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _invGlassFieldDecoration(
                                  hintText: 'Prom kg',
                                ),
                                onTap: () => _setActiveInsertColumn(
                                  4,
                                  requestFocus: false,
                                ),
                                onChanged: (t) => setState(
                                  () => _draft = _draft.copyWith(
                                    avgBaleWeightKg: _toDouble(t),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        frame(
                          5,
                          SizedBox(
                            width: _kProdOriginColW,
                            child: control(
                              _InvDropStrInline(
                                value: _sourceBulkForBaleMaterial(
                                  _draft.baleMaterial,
                                  selectedSourceBulk: _draft.sourceBulk,
                                ),
                                items: _sourceBulkOptionsForBaleMaterial(
                                  _draft.baleMaterial,
                                ),
                                format: (v) => _invMaterialLabel(v),
                                onTapStart: () => _setActiveInsertColumn(5),
                                onChanged: (v) => setState(
                                  () => _draft = _draft.copyWith(sourceBulk: v),
                                ),
                              ),
                            ),
                          ),
                        ),
                        frame(
                          6,
                          SizedBox(
                            width: _prodCommentColW(constraints.maxWidth),
                            child: control(
                              TextField(
                                controller: _draftNotesC,
                                focusNode: _insertNotesFocusNode,
                                decoration: _invGlassFieldDecoration(
                                  hintText: 'Comentario',
                                ),
                                onTap: () => _setActiveInsertColumn(
                                  6,
                                  requestFocus: false,
                                ),
                                onChanged: (t) => setState(
                                  () => _draft = _draft.copyWith(notes: t),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        frame(
                          7,
                          SizedBox(
                            width: _kProdActionsW,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.42),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${_fmtInvCount(produced.toDouble(), decimals: 1)} kg',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: 'AGREGAR',
                                  child: MouseRegion(
                                    onEnter: (_) => setState(
                                      () => _hoverInsertAddButton = true,
                                    ),
                                    onExit: (_) => setState(
                                      () => _hoverInsertAddButton = false,
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: _inserting ? null : _insertDraft,
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: _inserting
                                              ? Colors.white.withValues(
                                                  alpha: 0.35,
                                                )
                                              : const Color(
                                                  0xFF19C37D,
                                                ).withValues(alpha: 0.92),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.52,
                                            ),
                                          ),
                                          boxShadow:
                                              _hoverInsertAddButton &&
                                                  !_inserting
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.20,
                                                        ),
                                                    blurRadius: 16,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                ]
                                              : [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.10,
                                                        ),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                        ),
                                        child: _inserting
                                            ? const Padding(
                                                padding: EdgeInsets.all(8),
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.add,
                                                size: 18,
                                                color: Colors.white,
                                              ),
                                      ),
                                    ),
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
              ),
            );
          },
        ),
      ),
    );
  }
}

const double _kProdActionsW = 180;
const double _kProdDateColW = 90;
const double _kProdShiftColW = 120;
const double _kProdBaleTypeColW = 190;
const double _kProdBalesColW = 90;
const double _kProdAvgColW = 110;
const double _kProdOriginColW = 190;
const double _kProdMinCommentColW = 240;
const double _kProdFixedColsW =
    _kProdDateColW +
    _kProdShiftColW +
    _kProdBaleTypeColW +
    _kProdBalesColW +
    _kProdAvgColW +
    _kProdOriginColW +
    10 +
    _kProdActionsW;

const List<String> _kProductionBaleMaterials = <String>[
  'BALE_NATIONAL',
  'BALE_AMERICAN',
  'BALE_CLEAN',
  'BALE_TRASH',
  'CAPLE',
];

List<String> _productionSourceBulkOptionsForBaleMaterial(String? baleMaterial) {
  switch ((baleMaterial ?? '').trim().toUpperCase()) {
    case 'CAPLE':
      return const <String>['CAPLE'];
    case 'BALE_AMERICAN':
    case 'BALE_NATIONAL':
    case 'BALE_CLEAN':
    case 'BALE_TRASH':
      return const <String>['CARDBOARD_BULK_NATIONAL'];
    default:
      return const <String>['CARDBOARD_BULK_NATIONAL'];
  }
}

String _productionSourceBulkForBaleMaterial(
  String? baleMaterial, {
  String? selectedSourceBulk,
}) {
  final options = _productionSourceBulkOptionsForBaleMaterial(baleMaterial);
  final selected = (selectedSourceBulk ?? '').trim().toUpperCase();
  if (selected.isNotEmpty && options.contains(selected)) {
    return selected;
  }
  return options.first;
}

String _prodBaleMaterialLabel(String? material) {
  if ((material ?? '').trim().toUpperCase() == 'CAPLE') return 'Paca caple';
  return _invMaterialLabel(material);
}

double _prodCommentColW(double availableWidth) =>
    math.max(_kProdMinCommentColW, availableWidth - _kProdFixedColsW);

double _prodTableContentWFor(double availableWidth) =>
    _kProdFixedColsW + _prodCommentColW(availableWidth);

class _ProductionHeaderRow extends StatelessWidget {
  final bool Function(String columnId) hasActiveFilter;
  final void Function(String columnId, String label) onOpenFilter;
  const _ProductionHeaderRow({
    required this.hasActiveFilter,
    required this.onOpenFilter,
  });

  @override
  Widget build(BuildContext context) {
    const s = TextStyle(fontSize: 12, fontWeight: FontWeight.w800);
    return Card(
      elevation: 0,
      color: Colors.black.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentW = _prodTableContentWFor(constraints.maxWidth);
            final commentW = _prodCommentColW(constraints.maxWidth);
            return SizedBox(
              width: constraints.maxWidth,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: contentW,
                  child: Row(
                    children: [
                      _InvHCell(
                        'FECHA',
                        _kProdDateColW,
                        s,
                        active: hasActiveFilter('fecha'),
                        onFilter: () => onOpenFilter('fecha', 'FECHA'),
                      ),
                      _InvHCell(
                        'TURNO',
                        _kProdShiftColW,
                        s,
                        active: hasActiveFilter('turno'),
                        onFilter: () => onOpenFilter('turno', 'TURNO'),
                      ),
                      _InvHCell(
                        'TIPO PACA',
                        _kProdBaleTypeColW,
                        s,
                        active: hasActiveFilter('bale_material'),
                        onFilter: () =>
                            onOpenFilter('bale_material', 'TIPO PACA'),
                      ),
                      _InvHCell(
                        'PACAS',
                        _kProdBalesColW,
                        s,
                        active: hasActiveFilter('pacas'),
                        onFilter: () => onOpenFilter('pacas', 'PACAS'),
                      ),
                      _InvHCell(
                        'PROM KG',
                        _kProdAvgColW,
                        s,
                        active: hasActiveFilter('prom_kg'),
                        onFilter: () => onOpenFilter('prom_kg', 'PROM KG'),
                      ),
                      _InvHCell(
                        'ORIGEN',
                        _kProdOriginColW,
                        s,
                        active: hasActiveFilter('origen'),
                        onFilter: () => onOpenFilter('origen', 'ORIGEN'),
                      ),
                      SizedBox(
                        width: commentW,
                        child: _InvHCellExpand(
                          'COMENTARIO',
                          s,
                          active: hasActiveFilter('notes'),
                          onFilter: () => onOpenFilter('notes', 'COMENTARIO'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const SizedBox(width: _kProdActionsW),
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

class _ProductionDataRow extends StatefulWidget {
  final Map<String, dynamic> row;
  final bool isSelected;
  final bool isChecked;
  final int selectedCount;
  final int activeGridColumn;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(String id, Map<String, dynamic> patch) onUpdate;
  final ValueChanged<bool> onSelect;
  final ValueChanged<int> onActivateColumn;
  final ValueChanged<Offset> onOpenContextMenu;
  final VoidCallback onMultiEdit;

  const _ProductionDataRow({
    super.key,
    required this.row,
    required this.isSelected,
    required this.isChecked,
    required this.selectedCount,
    required this.activeGridColumn,
    required this.onDelete,
    required this.onUpdate,
    required this.onSelect,
    required this.onActivateColumn,
    required this.onOpenContextMenu,
    required this.onMultiEdit,
  });

  @override
  State<_ProductionDataRow> createState() => _ProductionDataRowState();
}

class _ProductionDataRowState extends State<_ProductionDataRow> {
  bool _editing = false;
  bool _hovering = false;
  bool _hoverActionsButton = false;
  int? _hoveredEditableColumn;
  late DateTime _opDate;
  String _shift = 'DAY';
  String _baleMaterial = 'BALE_NATIONAL';
  String? _sourceBulk;
  final TextEditingController _countC = TextEditingController();
  final TextEditingController _avgC = TextEditingController();
  final TextEditingController _notesC = TextEditingController();
  final FocusNode _countFocusNode = FocusNode();
  final FocusNode _avgFocusNode = FocusNode();
  final FocusNode _notesFocusNode = FocusNode();

  String get id => widget.row['id'] as String;
  bool get isEditing => _editing;
  bool get isAnyEditableTextFocused => _isEditableTextFocused();

  @override
  void initState() {
    super.initState();
    _syncFromRow();
  }

  @override
  void didUpdateWidget(covariant _ProductionDataRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.row != oldWidget.row && !_editing) _syncFromRow();
  }

  @override
  void dispose() {
    _countC.dispose();
    _avgC.dispose();
    _notesC.dispose();
    _countFocusNode.dispose();
    _avgFocusNode.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  void _syncFromRow() {
    _opDate = _parseDate(widget.row['op_date']);
    _shift = (widget.row['shift'] ?? 'DAY').toString();
    _baleMaterial = (widget.row['bale_material'] ?? 'BALE_NATIONAL').toString();
    _sourceBulk = (widget.row['source_bulk'] ?? '').toString().trim().isEmpty
        ? _productionSourceBulkForBaleMaterial(_baleMaterial)
        : (widget.row['source_bulk'] ?? '').toString();
    _countC.text = (widget.row['bale_count'] ?? '').toString();
    _avgC.text =
        _toDouble(widget.row['avg_bale_weight_kg'])?.toStringAsFixed(2) ??
        '850';
    _notesC.text = (widget.row['notes'] ?? '').toString();
  }

  DateTime _parseDate(dynamic v) {
    if (v is String && v.length >= 10) {
      final y = int.tryParse(v.substring(0, 4));
      final m = int.tryParse(v.substring(5, 7));
      final d = int.tryParse(v.substring(8, 10));
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return DateUtils.dateOnly(DateTime.now());
  }

  String _fmtDbDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _fmtUiDate(DateTime d) {
    final yy = (d.year % 100).toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd/$mm/$yy';
  }

  bool _isAdditiveSelectionPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  void startEditingFromKeyboard() {
    if (!_editing) setState(() => _editing = true);
  }

  void cancelEditingFromKeyboard() {
    if (!_editing) return;
    _syncFromRow();
    setState(() => _editing = false);
  }

  Future<void> saveFromKeyboard() async {
    if (_editing) await _save();
  }

  Future<void> deleteWithConfirmation() async {
    final ok = await _showConfirmDialog(
      context,
      title: 'Eliminar producción',
      content: '¿Seguro que quieres eliminarlo?',
      confirmText: 'Eliminar',
    );
    if (ok == true) await widget.onDelete(id);
  }

  bool isTextCellFocused(int col) => switch (col) {
    3 => _countFocusNode.hasFocus,
    4 => _avgFocusNode.hasFocus,
    6 => _notesFocusNode.hasFocus,
    _ => false,
  };
  bool activeTextCaretAtStart(int col) => switch (col) {
    3 => _caretAtStart(_countC, _countFocusNode),
    4 => _caretAtStart(_avgC, _avgFocusNode),
    6 => _caretAtStart(_notesC, _notesFocusNode),
    _ => true,
  };
  bool activeTextCaretAtEnd(int col) => switch (col) {
    3 => _caretAtEnd(_countC, _countFocusNode),
    4 => _caretAtEnd(_avgC, _avgFocusNode),
    6 => _caretAtEnd(_notesC, _notesFocusNode),
    _ => true,
  };
  bool _caretAtStart(TextEditingController c, FocusNode f) {
    if (!f.hasFocus) return false;
    final s = c.selection;
    return s.isValid &&
        s.isCollapsed &&
        s.baseOffset == 0 &&
        s.extentOffset == 0;
  }

  bool _caretAtEnd(TextEditingController c, FocusNode f) {
    if (!f.hasFocus) return false;
    final s = c.selection;
    final e = c.text.length;
    return s.isValid &&
        s.isCollapsed &&
        s.baseOffset == e &&
        s.extentOffset == e;
  }

  bool _isEditableTextFocused() {
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void focusTextIfNeeded(int col) {
    if (_editing && col == 6) focusCommentField();
  }

  void focusCommentField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_notesFocusNode);
      _notesC.selection = TextSelection.collapsed(offset: _notesC.text.length);
    });
  }

  Future<void> activateGridCell(int col) async {
    if (!_editing) return;
    switch (col) {
      case 0:
        final d = await _showInvKeyboardDatePickerDialog(
          context: context,
          initialDate: _opDate,
          firstDate: DateTime(2024, 1, 1),
          lastDate: DateTime(2035, 12, 31),
        );
        if (d != null) setState(() => _opDate = DateUtils.dateOnly(d));
        return;
      case 1:
        final shift = await _showInvSearchablePickerDialog<String>(
          context,
          title: 'Turno',
          initialValue: _shift,
          options: const [
            _InvPickerOption<String>(value: 'DAY', label: 'Día'),
            _InvPickerOption<String>(value: 'NIGHT', label: 'Noche'),
          ],
        );
        if (shift != null) setState(() => _shift = shift);
        return;
      case 2:
        final mat = await _showInvSearchablePickerDialog<String>(
          context,
          title: 'Tipo de paca',
          initialValue: _baleMaterial,
          options: const [
            _InvPickerOption<String>(
              value: 'BALE_NATIONAL',
              label: 'Paca nacional',
            ),
            _InvPickerOption<String>(
              value: 'BALE_AMERICAN',
              label: 'Paca americana',
            ),
            _InvPickerOption<String>(value: 'BALE_CLEAN', label: 'Paca limpia'),
            _InvPickerOption<String>(value: 'BALE_TRASH', label: 'Paca basura'),
            _InvPickerOption<String>(value: 'CAPLE', label: 'Paca caple'),
          ],
        );
        if (mat != null) {
          final options = _productionSourceBulkOptionsForBaleMaterial(mat);
          setState(() {
            _baleMaterial = mat;
            _sourceBulk = options.isEmpty
                ? null
                : options.contains(_sourceBulk)
                ? _sourceBulk
                : options.first;
          });
        }
        return;
      case 5:
        final source = await _showInvSearchablePickerDialog<String>(
          context,
          title: 'Origen',
          initialValue: _productionSourceBulkForBaleMaterial(
            _baleMaterial,
            selectedSourceBulk: _sourceBulk,
          ),
          options: _productionSourceBulkOptionsForBaleMaterial(_baleMaterial)
              .map(
                (value) => _InvPickerOption<String>(
                  value: value,
                  label: _invMaterialLabel(value),
                ),
              )
              .toList(),
        );
        if (source != null) setState(() => _sourceBulk = source);
        return;
      case 3:
        FocusScope.of(context).requestFocus(_countFocusNode);
        return;
      case 4:
        FocusScope.of(context).requestFocus(_avgFocusNode);
        return;
      case 6:
        focusCommentField();
        return;
      default:
        return;
    }
  }

  void _enterEditingFromPointer(int col) {
    if (_isAdditiveSelectionPressed()) {
      widget.onSelect(true);
      return;
    }
    final multiContext =
        widget.selectedCount > 1 && (widget.isSelected || widget.isChecked);
    if (multiContext) {
      widget.onMultiEdit();
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

  void _previewEditableCellTap(int col) {
    if (_isAdditiveSelectionPressed()) {
      widget.onSelect(true);
      return;
    }
    widget.onSelect(false);
    widget.onActivateColumn(col);
  }

  Future<void> _save({bool keepEditing = false}) async {
    final count = int.tryParse(_countC.text.trim());
    final avg = _toDouble(_avgC.text);
    if (count == null || count <= 0 || avg == null || avg <= 0) return;
    final sourceBulk = _productionSourceBulkForBaleMaterial(
      _baleMaterial,
      selectedSourceBulk: _sourceBulk,
    );
    final patch = <String, dynamic>{
      'op_date': _fmtDbDate(_opDate),
      'shift': _shift,
      'bale_material': _baleMaterial,
      'source_bulk': sourceBulk,
      'bale_count': count,
      'avg_bale_weight_kg': avg,
      'notes': _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
    };
    await widget.onUpdate(id, patch);
    if (mounted) setState(() => _editing = keepEditing);
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = widget.isSelected || widget.isChecked;
    final hoverOnly = _hovering && !hasSelection;
    final rowBg = _editing
        ? const Color(0xFFE2EEF8)
        : hasSelection
        ? const Color(
            0xFF00A3FF,
          ).withValues(alpha: widget.isSelected ? 0.16 : 0.13)
        : hoverOnly
        ? const Color(0xFFE9F7EE)
        : Colors.white;
    final hoverLift = hasSelection
        ? -1.4
        : _hovering
        ? -1.15
        : 0.0;
    final hoverElevation = hasSelection
        ? 3.2
        : _hovering
        ? 2.7
        : 0.5;

    Widget frame(int col, Widget child) {
      final active =
          _editing && widget.isSelected && widget.activeGridColumn == col;
      return DecoratedBox(
        position: DecorationPosition.background,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: !_editing && _hoveredEditableColumn == col
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (hasSelection
                            ? const Color(0xFFD9E8F6)
                            : const Color(0xFFE5F2EC))
                        .withValues(alpha: 0.78),
                    (hasSelection
                            ? const Color(0xFFCCE0F2)
                            : const Color(0xFFD4E7DE))
                        .withValues(alpha: 0.64),
                  ],
                )
              : null,
          color: active
              ? const Color(0xFFDCEAF7).withValues(alpha: 0.72)
              : Colors.transparent,
          border: Border.all(
            color: active
                ? const Color(0xFF0B72FF).withValues(alpha: 0.84)
                : Colors.transparent,
            width: active ? 1.05 : 1.0,
          ),
          boxShadow: !_editing && _hoveredEditableColumn == col
              ? [
                  BoxShadow(
                    color:
                        (hasSelection
                                ? const Color(0xFF6A8FAE)
                                : const Color(0xFF6C8F84))
                            .withValues(alpha: 0.18),
                    blurRadius: 2.2,
                    spreadRadius: -3.0,
                    offset: const Offset(0, 0.8),
                  ),
                ]
              : null,
        ),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? const Color(0xFF0B72FF).withValues(alpha: 0.84)
                  : Colors.transparent,
              width: active ? 1.05 : 1.0,
            ),
          ),
          child: child,
        ),
      );
    }

    Widget previewEditableCell({required int col, required Widget child}) {
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
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _previewEditableCellTap(col),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () => _enterEditingFromPointer(col),
            child: child,
          ),
        ),
      );
    }

    Widget readonlyCell({
      required Widget child,
      bool showDivider = true,
      EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 4),
    }) {
      return Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(child: child),
            if (showDivider)
              Container(
                width: 1,
                height: 30,
                margin: const EdgeInsets.only(left: 8, right: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9D5E2).withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      );
    }

    final sourceBulk = _productionSourceBulkForBaleMaterial(
      _baleMaterial,
      selectedSourceBulk: _sourceBulk,
    );
    final producedWeight =
        ((int.tryParse(_countC.text.trim()) ?? 0) *
        (_toDouble(_avgC.text) ?? 0));

    final multiContext = widget.selectedCount > 1 && hasSelection;
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
          onTapDown: (_) {
            if (_editing) return;
            widget.onSelect(_isAdditiveSelectionPressed());
          },
          onDoubleTap: () => _enterEditingFromPointer(0),
          onSecondaryTapDown: (details) {
            if (!hasSelection) {
              widget.onSelect(false);
            }
            widget.onOpenContextMenu(details.globalPosition);
          },
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
                  color: widget.isSelected
                      ? const Color(0xFF00A3FF).withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.0),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final commentW = _prodCommentColW(constraints.maxWidth);
                    return SizedBox(
                      width: constraints.maxWidth,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: _prodTableContentWFor(constraints.maxWidth),
                          child: Row(
                            children: [
                              frame(
                                0,
                                SizedBox(
                                  width: _kProdDateColW,
                                  child: _editing
                                      ? InkWell(
                                          onTap: () {
                                            widget.onActivateColumn(0);
                                            activateGridCell(0);
                                          },
                                          child: _InvCellBox(
                                            text: _fmtUiDate(_opDate),
                                            icon: Icons.calendar_month,
                                          ),
                                        )
                                      : previewEditableCell(
                                          col: 0,
                                          child: readonlyCell(
                                            child: _InvFitText(
                                              _fmtUiDate(_opDate),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              frame(
                                1,
                                SizedBox(
                                  width: _kProdShiftColW,
                                  child: _editing
                                      ? _InvDropStrInline(
                                          value: _shift,
                                          items: const ['DAY', 'NIGHT'],
                                          format: (v) => _prodShiftLabel(v),
                                          onTapStart: () =>
                                              widget.onActivateColumn(1),
                                          onChanged: (v) {
                                            if (v == null) return;
                                            setState(() => _shift = v);
                                          },
                                        )
                                      : previewEditableCell(
                                          col: 1,
                                          child: readonlyCell(
                                            child: Builder(
                                              builder: (_) {
                                                final palette =
                                                    _prodShiftChipColors(
                                                      _shift,
                                                    );
                                                return _InvPillTag(
                                                  label: _prodShiftLabel(
                                                    _shift,
                                                  ),
                                                  background: palette.bg,
                                                  foreground: palette.fg,
                                                  minWidth: 0,
                                                  horizontalPadding: 10,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              frame(
                                2,
                                SizedBox(
                                  width: _kProdBaleTypeColW,
                                  child: _editing
                                      ? _InvDropStrInline(
                                          value: _baleMaterial,
                                          items: _kProductionBaleMaterials,
                                          format: (v) =>
                                              _prodBaleMaterialLabel(v),
                                          onTapStart: () =>
                                              widget.onActivateColumn(2),
                                          onChanged: (v) {
                                            if (v == null) return;
                                            final options =
                                                _productionSourceBulkOptionsForBaleMaterial(
                                                  v,
                                                );
                                            setState(() {
                                              _baleMaterial = v;
                                              _sourceBulk = options.isEmpty
                                                  ? null
                                                  : options.contains(
                                                      _sourceBulk,
                                                    )
                                                  ? _sourceBulk
                                                  : options.first;
                                            });
                                          },
                                        )
                                      : previewEditableCell(
                                          col: 2,
                                          child: readonlyCell(
                                            child: Builder(
                                              builder: (_) {
                                                final label =
                                                    _prodBaleMaterialLabel(
                                                      _baleMaterial,
                                                    );
                                                final palette =
                                                    _prodBaleChipColors(
                                                      _baleMaterial,
                                                    );
                                                return _InvPillTag(
                                                  label: label,
                                                  background: palette.bg,
                                                  foreground: palette.fg,
                                                  minWidth: 0,
                                                  horizontalPadding: 10,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              frame(
                                3,
                                SizedBox(
                                  width: _kProdBalesColW,
                                  child: _editing
                                      ? TextField(
                                          controller: _countC,
                                          focusNode: _countFocusNode,
                                          keyboardType: TextInputType.number,
                                          decoration:
                                              _invGlassFieldDecoration(),
                                          onTap: () =>
                                              widget.onActivateColumn(3),
                                        )
                                      : previewEditableCell(
                                          col: 3,
                                          child: readonlyCell(
                                            child: _InvFitText(_countC.text),
                                          ),
                                        ),
                                ),
                              ),
                              frame(
                                4,
                                SizedBox(
                                  width: _kProdAvgColW,
                                  child: _editing
                                      ? TextField(
                                          controller: _avgC,
                                          focusNode: _avgFocusNode,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          decoration:
                                              _invGlassFieldDecoration(),
                                          onTap: () =>
                                              widget.onActivateColumn(4),
                                        )
                                      : previewEditableCell(
                                          col: 4,
                                          child: readonlyCell(
                                            child: _InvFitText(
                                              _fmtInvCount(
                                                _toDouble(_avgC.text) ?? 0,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              frame(
                                5,
                                SizedBox(
                                  width: _kProdOriginColW,
                                  child: _editing
                                      ? _InvDropStrInline(
                                          value: sourceBulk,
                                          items:
                                              _productionSourceBulkOptionsForBaleMaterial(
                                                _baleMaterial,
                                              ),
                                          format: (v) => _invMaterialLabel(v),
                                          onTapStart: () =>
                                              widget.onActivateColumn(5),
                                          onChanged: (v) {
                                            if (v == null) return;
                                            setState(() => _sourceBulk = v);
                                          },
                                        )
                                      : readonlyCell(
                                          child: Builder(
                                            builder: (_) {
                                              final label = _invMaterialLabel(
                                                sourceBulk,
                                              );
                                              return _InvUnitBadge(
                                                label: label,
                                              );
                                            },
                                          ),
                                        ),
                                ),
                              ),
                              frame(
                                6,
                                SizedBox(
                                  width: commentW,
                                  child: _editing
                                      ? TextField(
                                          controller: _notesC,
                                          focusNode: _notesFocusNode,
                                          decoration:
                                              _invGlassFieldDecoration(),
                                          onTap: () =>
                                              widget.onActivateColumn(6),
                                        )
                                      : previewEditableCell(
                                          col: 6,
                                          child: readonlyCell(
                                            showDivider: false,
                                            child: _InvFitText(_notesC.text),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              frame(
                                7,
                                SizedBox(
                                  width: _kProdActionsW,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.42,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          '${_fmtInvCount(producedWeight.toDouble(), decimals: 1)} kg',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Tooltip(
                                        message: 'Acciones',
                                        child: MouseRegion(
                                          onEnter: (_) => setState(
                                            () => _hoverActionsButton = true,
                                          ),
                                          onExit: (_) => setState(
                                            () => _hoverActionsButton = false,
                                          ),
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTapDown: (details) {
                                              if (!hasSelection) {
                                                widget.onSelect(false);
                                              }
                                              widget.onOpenContextMenu(
                                                details.globalPosition,
                                              );
                                            },
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
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.72),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha:
                                                              _hoverActionsButton
                                                              ? 0.15
                                                              : 0.08,
                                                        ),
                                                    blurRadius:
                                                        _hoverActionsButton
                                                        ? 14
                                                        : 8,
                                                    offset: Offset(
                                                      0,
                                                      _hoverActionsButton
                                                          ? 7
                                                          : 4,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.more_horiz,
                                                size: 20,
                                                color: multiContext
                                                    ? const Color(0xFF2D5478)
                                                    : const Color(0xFF20364E),
                                              ),
                                            ),
                                          ),
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

class _ProductionDraft {
  static const Object _unset = Object();
  final DateTime? opDate;
  final String? shift;
  final String? baleMaterial;
  final String? sourceBulk;
  final int? baleCount;
  final double? avgBaleWeightKg;
  final String notes;

  const _ProductionDraft({
    required this.opDate,
    required this.shift,
    required this.baleMaterial,
    required this.sourceBulk,
    required this.baleCount,
    required this.avgBaleWeightKg,
    required this.notes,
  });

  _ProductionDraft copyWith({
    Object? opDate = _unset,
    Object? shift = _unset,
    Object? baleMaterial = _unset,
    Object? sourceBulk = _unset,
    Object? baleCount = _unset,
    Object? avgBaleWeightKg = _unset,
    String? notes,
  }) {
    return _ProductionDraft(
      opDate: identical(opDate, _unset) ? this.opDate : opDate as DateTime?,
      shift: identical(shift, _unset) ? this.shift : shift as String?,
      baleMaterial: identical(baleMaterial, _unset)
          ? this.baleMaterial
          : baleMaterial as String?,
      sourceBulk: identical(sourceBulk, _unset)
          ? this.sourceBulk
          : sourceBulk as String?,
      baleCount: identical(baleCount, _unset)
          ? this.baleCount
          : baleCount as int?,
      avgBaleWeightKg: identical(avgBaleWeightKg, _unset)
          ? this.avgBaleWeightKg
          : avgBaleWeightKg as double?,
      notes: notes ?? this.notes,
    );
  }
}

String _prodShiftLabel(String? shift) {
  switch (shift) {
    case 'DAY':
      return 'Día';
    case 'NIGHT':
      return 'Noche';
    default:
      return shift ?? '—';
  }
}

({Color bg, Color fg}) _prodShiftChipColors(String? shift) {
  switch ((shift ?? '').toUpperCase()) {
    case 'DAY':
      return (bg: const Color(0xFFD7F2E6), fg: const Color(0xFF1A4F36));
    case 'NIGHT':
      return (bg: const Color(0xFFDCE6F6), fg: const Color(0xFF24435E));
    default:
      return (bg: const Color(0xFFE2E8F2), fg: const Color(0xFF31475F));
  }
}

({Color bg, Color fg}) _prodBaleChipColors(String? baleMaterial) {
  switch ((baleMaterial ?? '').toUpperCase()) {
    case 'BALE_NATIONAL':
      return (bg: const Color(0xFFD9F0F3), fg: const Color(0xFF1F5960));
    case 'BALE_AMERICAN':
      return (bg: const Color(0xFFF8E0D1), fg: const Color(0xFF7A3D1B));
    case 'BALE_CLEAN':
      return (bg: const Color(0xFFE6F2CF), fg: const Color(0xFF3F5A17));
    case 'BALE_TRASH':
      return (bg: const Color(0xFFEBD7E8), fg: const Color(0xFF6B2F63));
    case 'CAPLE':
      return (bg: const Color(0xFFE8F4FF), fg: const Color(0xFF1B5B9C));
    default:
      return (bg: const Color(0xFFE2E8F2), fg: const Color(0xFF31475F));
  }
}

const double _kSepDateColW = 118;
const double _kSepShiftColW = 108;
const double _kSepModeColW = 132;
const double _kSepCommercialColW = 240;
const double _kSepKgColW = 130;
const double _kSepNotesColW = 240;
const double _kSepActionsColW = 120;

double _sepTableContentWFor(double availableWidth) {
  final base =
      _kSepDateColW +
      _kSepShiftColW +
      _kSepModeColW +
      _kSepCommercialColW +
      _kSepKgColW +
      _kSepNotesColW +
      _kSepActionsColW +
      10;
  return math.max(base, availableWidth);
}

// Legacy widget retained temporarily to avoid breaking local references while
// the new v2 transformation flow finishes replacing old code paths.
class InventoryMaterialSeparationGrid extends StatefulWidget {
  final String sourceMaterial;
  final Future<void> Function()? onChanged;
  final bool showTopBarChrome;
  final ValueChanged<InventoryGridTopBarData>? onTopBarChanged;

  const InventoryMaterialSeparationGrid({
    super.key,
    required this.sourceMaterial,
    this.onChanged,
    this.showTopBarChrome = true,
    this.onTopBarChanged,
  });

  @override
  State<InventoryMaterialSeparationGrid> createState() =>
      _InventoryMaterialSeparationGridState();
}

class _InventoryMaterialSeparationGridState
    extends State<InventoryMaterialSeparationGrid>
    with WidgetsBindingObserver {
  final supa = Supabase.instance.client;

  final FocusNode _insertFocusNode = FocusNode(
    debugLabel: 'sep_insert_row_focus',
  );
  final FocusNode _rowsFocusNode = FocusNode(debugLabel: 'sep_rows_focus');
  final FocusNode _insertKgFocusNode = FocusNode(debugLabel: 'sep_insert_kg');
  final FocusNode _insertNotesFocusNode = FocusNode(
    debugLabel: 'sep_insert_notes',
  );

  final TextEditingController _draftKgC = TextEditingController();
  final TextEditingController _draftNotesC = TextEditingController();

  final Map<String, GlobalKey<_SeparationDataRowState>> _rowKeys =
      <String, GlobalKey<_SeparationDataRowState>>{};
  final Map<String, Set<String>> _columnValueFilters = <String, Set<String>>{};
  final Map<String, DateTimeRange> _columnDateRangeFilters =
      <String, DateTimeRange>{};
  final ScrollController _rowsScrollController = ScrollController();

  Timer? _autoRefreshTimer;
  RealtimeChannel? _realtimeChannel;

  bool _loadingRows = true;
  bool _loadingCommercials = true;
  bool _refreshingRows = false;
  bool _pendingReload = false;
  bool _inserting = false;
  bool _bulkDeleting = false;
  bool _exportingCsv = false;
  bool _insertRowActive = false;
  bool _hoverInsertAddButton = false;
  final bool _gridEditMode = false;
  bool _topBarSyncScheduled = false;

  List<Map<String, dynamic>> _rows = [];
  List<_SeparationCommercialOption> _commercialOptions =
      <_SeparationCommercialOption>[];
  String? _selectedRowId;
  String? _selectionAnchorRowId;
  final Set<String> _bulkSelectedRowIds = <String>{};
  int _activeInsertColumn = 0;
  int _activeGridColumn = 0;
  final int _gridSaveSignal = 0;
  final int _gridCancelSignal = 0;
  int _currentPage = 0;
  final int _pageSize = 40;

  static const int _insertColumnCount = 7;
  static const int _gridColumnCount = 7;
  static const List<String> _gridColumnLabels = <String>[
    'FECHA',
    'TURNO',
    'ORIGEN',
    'MATERIAL COMERCIAL',
    'KG',
    'COMENTARIO',
    'ACCIONES',
  ];

  late _SeparationDraft _draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _insertFocusNode.addListener(_syncInsertRowFocusState);
    _insertKgFocusNode.addListener(_syncInsertRowFocusState);
    _insertNotesFocusNode.addListener(_syncInsertRowFocusState);
    _initDraftDefaults();
    unawaited(_loadInitialData());
    _setupAutoRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyTopBarChanged());
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _scheduleTopBarSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    _insertFocusNode.removeListener(_syncInsertRowFocusState);
    _insertKgFocusNode.removeListener(_syncInsertRowFocusState);
    _insertNotesFocusNode.removeListener(_syncInsertRowFocusState);
    _insertFocusNode.dispose();
    _rowsFocusNode.dispose();
    _insertKgFocusNode.dispose();
    _insertNotesFocusNode.dispose();
    _draftKgC.dispose();
    _draftNotesC.dispose();
    _rowsScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _requestReload();
  }

  String get _sourceMaterial => widget.sourceMaterial.toUpperCase();
  bool get _isScrap => _sourceMaterial == 'SCRAP';

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadCommercialOptions(), _loadRows()]);
  }

  void _initDraftDefaults() {
    _draft = _SeparationDraft(
      opDate: DateUtils.dateOnly(DateTime.now()),
      shift: 'DAY',
      sourceMode: 'MIXED',
      commercialMaterialCode: null,
      weightKg: null,
      notes: '',
    );
    _draftKgC.clear();
    _draftNotesC.clear();
    _activeInsertColumn = 0;
  }

  bool get _canInsert {
    final kg = _toDouble(_draftKgC.text);
    return _draft.opDate != null &&
        _draft.shift != null &&
        _draft.sourceMode != null &&
        (_draft.commercialMaterialCode ?? '').trim().isNotEmpty &&
        kg != null &&
        kg > 0;
  }

  Future<void> _loadCommercialOptions() async {
    setState(() => _loadingCommercials = true);
    try {
      final rows = await supa
          .from('commercial_material_catalog')
          .select('code,name,inventory_material')
          .eq('active', true)
          .eq('inventory_material', _sourceMaterial)
          .order('name');
      final options =
          (rows as List)
              .cast<Map<String, dynamic>>()
              .map(
                (row) => _SeparationCommercialOption(
                  code: (row['code'] ?? '').toString().trim(),
                  name: (row['name'] ?? '').toString().trim(),
                ),
              )
              .where((row) => row.code.isNotEmpty && row.name.isNotEmpty)
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
      if (!mounted) return;
      setState(() {
        _commercialOptions = options;
        _loadingCommercials = false;
      });
    } catch (e) {
      _toast('No se pudo cargar materiales comerciales: $e');
      if (mounted) setState(() => _loadingCommercials = false);
    }
  }

  void _syncInsertRowFocusState() {
    final next =
        _insertFocusNode.hasFocus ||
        _insertKgFocusNode.hasFocus ||
        _insertNotesFocusNode.hasFocus;
    if (_insertRowActive == next || !mounted) return;
    setState(() => _insertRowActive = next);
  }

  void _setupAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _requestReload();
    });
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = supa
        .channel(
          'inventory-material-separation-grid-${_sourceMaterial.toLowerCase()}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'material_separation_runs',
          callback: (_) => _requestReload(),
        )
        .subscribe();
  }

  void _requestReload() {
    if (!mounted) return;
    if (_refreshingRows ||
        _loadingRows ||
        _inserting ||
        _bulkDeleting ||
        _insertRowActive ||
        _gridEditMode ||
        (_selectedRowState()?.isEditing ?? false) ||
        _isEditableTextFocused()) {
      _pendingReload = true;
      return;
    }
    unawaited(_refreshRowsIfIdle());
  }

  bool _isEditableTextFocused() {
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  Future<void> _refreshRowsIfIdle() async {
    if (!mounted || _refreshingRows) return;
    _refreshingRows = true;
    try {
      await _loadRows(showLoader: false);
    } finally {
      _refreshingRows = false;
      if (_pendingReload) {
        _pendingReload = false;
        _requestReload();
      }
    }
  }

  Future<void> _loadRows({bool showLoader = true}) async {
    if (showLoader && mounted) setState(() => _loadingRows = true);
    try {
      final data = await supa
          .from('material_separation_runs')
          .select('*')
          .eq('source_material', _sourceMaterial)
          .order('op_date', ascending: false)
          .order('created_at', ascending: false);
      final nextRows = (data as List).cast<Map<String, dynamic>>();
      final ids = nextRows.map((r) => r['id'] as String).toSet();
      final visibleIds = nextRows
          .where((r) => _matchesFilters(r))
          .map((r) => r['id'] as String)
          .toSet();
      final nextSelected =
          ids.contains(_selectedRowId) && visibleIds.contains(_selectedRowId)
          ? _selectedRowId
          : null;
      _rowKeys.removeWhere((id, _) => !ids.contains(id));
      if (!mounted) return;
      setState(() {
        _rows = nextRows;
        _selectedRowId = nextSelected;
        _bulkSelectedRowIds.removeWhere((id) => !ids.contains(id));
        _clampCurrentPage();
        if (showLoader) _loadingRows = false;
      });
      if (_selectedRowId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _activeInsertColumn = 0;
          _insertFocusNode.requestFocus();
        });
      }
    } catch (e) {
      _toast('No se pudo cargar separaciones: $e');
      if (mounted && showLoader) setState(() => _loadingRows = false);
    }
  }

  Future<void> _insertDraft() async {
    if (_inserting) return;
    if (!_canInsert) {
      _toast('Completa fecha, turno, origen, material comercial y kg.');
      return;
    }
    final kg = _toDouble(_draftKgC.text)!;
    setState(() => _inserting = true);
    try {
      await supa.from('material_separation_runs').insert({
        'op_date': _fmtDbDate(_draft.opDate!),
        'shift': _draft.shift,
        'site': 'DICSA_CELAYA',
        'source_material': _sourceMaterial,
        'source_mode': _draft.sourceMode,
        'commercial_material_code': _draft.commercialMaterialCode,
        'weight_kg': kg,
        'notes': _draftNotesC.text.trim().isEmpty
            ? null
            : _draftNotesC.text.trim(),
      });
      _toast('${_sourceMaterial == 'SCRAP' ? 'Chatarra' : 'Papel'} agregado');
      _initDraftDefaults();
      await _loadRows(showLoader: false);
      await widget.onChanged?.call();
      if (!mounted) return;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _insertFocusNode.requestFocus();
      });
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('No se pudo insertar separación: $e');
    } finally {
      if (mounted) setState(() => _inserting = false);
    }
  }

  Future<void> _deleteRow(String id) async {
    try {
      await supa.from('material_separation_runs').delete().eq('id', id);
      _bulkSelectedRowIds.remove(id);
      _toast('Eliminado');
      await _loadRows(showLoader: false);
      await widget.onChanged?.call();
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('No se pudo eliminar separación: $e');
    }
  }

  Future<void> _updateRow(String id, Map<String, dynamic> patch) async {
    try {
      await supa.from('material_separation_runs').update(patch).eq('id', id);
      final idx = _rows.indexWhere((r) => r['id'] == id);
      if (idx != -1) {
        setState(() => _rows[idx] = {..._rows[idx], ...patch});
      } else {
        await _loadRows(showLoader: false);
      }
      await widget.onChanged?.call();
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('No se pudo actualizar separación: $e');
    }
  }

  Future<void> _deleteSelectedRows() async {
    if (_bulkSelectedRowIds.isEmpty || _bulkDeleting) return;
    final ok = await _showConfirmDialog(
      context,
      title: 'Eliminar seleccionados',
      content:
          '¿Eliminar ${_bulkSelectedRowIds.length} registro(s) de separación?',
      confirmText: 'Eliminar',
    );
    if (ok != true) return;
    setState(() => _bulkDeleting = true);
    try {
      final ids = _bulkSelectedRowIds.toList();
      await supa.from('material_separation_runs').delete().inFilter('id', ids);
      _bulkSelectedRowIds.clear();
      _toast('Eliminados ${ids.length} registros');
      await _loadRows(showLoader: false);
      await widget.onChanged?.call();
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('No se pudieron eliminar registros de separación: $e');
    } finally {
      if (mounted) setState(() => _bulkDeleting = false);
    }
  }

  Future<void> _exportCsv() async {
    if (_exportingCsv) return;
    setState(() => _exportingCsv = true);
    try {
      final data = await supa
          .from('material_separation_runs')
          .select('*')
          .eq('source_material', _sourceMaterial)
          .order('op_date')
          .order('created_at');
      final rows = (data as List).cast<Map<String, dynamic>>();
      const headers = <String>[
        'id',
        'created_at',
        'op_date',
        'shift',
        'source_material',
        'source_mode',
        'commercial_material_code',
        'weight_kg',
        'notes',
      ];
      final sb = StringBuffer()
        ..write('\uFEFF')
        ..writeln(headers.join(','));
      for (final r in rows) {
        sb.writeln(headers.map((h) => _csvEscape(r[h])).join(','));
      }
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName =
          'material_separation_${_sourceMaterial.toLowerCase()}_$stamp.csv';
      final path = await _writeDownloadsFile(fileName, sb.toString());
      _toast(
        path == null
            ? 'No se pudo guardar CSV en Descargas'
            : 'CSV exportado en: $path',
      );
    } catch (e) {
      _toast('No se pudo exportar CSV: $e');
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Future<String?> _writeDownloadsFile(String fileName, String content) async {
    final env = Platform.environment;
    final dirs = <Directory>[];
    final home = env['HOME'];
    if (home != null && home.isNotEmpty) {
      dirs.add(Directory('$home/Downloads'));
      dirs.add(Directory('$home/Descargas'));
    }
    for (final dir in dirs) {
      try {
        if (!dir.existsSync()) dir.createSync(recursive: true);
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(content, encoding: utf8);
        return file.path;
      } catch (_) {}
    }
    return null;
  }

  String _csvEscape(dynamic value) {
    if (value == null) return '';
    final text = value.toString();
    final escaped = text.replaceAll('"', '""');
    final needsQuotes =
        escaped.contains(',') ||
        escaped.contains('\n') ||
        escaped.contains('"');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  String _commercialLabel(String? code) {
    final normalized = (code ?? '').trim();
    if (normalized.isEmpty) return '';
    final match = _commercialOptions.where((o) => o.code == normalized);
    if (match.isEmpty) return normalized;
    return match.first.name;
  }

  String _cellTextForColumn(Map<String, dynamic> row, String columnId) {
    switch (columnId) {
      case 'fecha':
        return _fmtUiDate(_parseDate(row['op_date']));
      case 'turno':
        return _prodShiftLabel(row['shift']?.toString());
      case 'origen':
        return _separationSourceModeLabel(row['source_mode']?.toString());
      case 'commercial':
        return _commercialLabel(row['commercial_material_code']?.toString());
      case 'kg':
        final n = _toDouble(row['weight_kg']);
        return n == null ? '' : n.toStringAsFixed(2);
      case 'notes':
        return (row['notes'] ?? '').toString().trim();
      default:
        return '';
    }
  }

  DateTime? _dateValueForColumn(Map<String, dynamic> row, String columnId) {
    if (columnId != 'fecha') return null;
    return _parseDate(row['op_date']);
  }

  bool _matchesFilters(Map<String, dynamic> row, {String? excludeColumn}) {
    for (final entry in _columnDateRangeFilters.entries) {
      if (entry.key == excludeColumn) continue;
      final value = _dateValueForColumn(row, entry.key);
      if (value == null) return false;
      final d = DateUtils.dateOnly(value);
      final s = DateUtils.dateOnly(entry.value.start);
      final e = DateUtils.dateOnly(entry.value.end);
      if (d.isBefore(s) || d.isAfter(e)) return false;
    }
    for (final entry in _columnValueFilters.entries) {
      if (entry.key == excludeColumn || entry.value.isEmpty) continue;
      if (!entry.value.contains(_cellTextForColumn(row, entry.key))) {
        return false;
      }
    }
    return true;
  }

  List<Map<String, dynamic>> get _filteredRows =>
      _rows.where((r) => _matchesFilters(r)).toList();

  List<Map<String, dynamic>> get _visibleRows {
    final filtered = _filteredRows;
    final start = _currentPage * _pageSize;
    if (start >= filtered.length) return <Map<String, dynamic>>[];
    final end = math.min(start + _pageSize, filtered.length);
    return filtered.sublist(start, end);
  }

  int get _totalPages {
    final total = _filteredRows.length;
    if (total == 0) return 1;
    return ((total - 1) ~/ _pageSize) + 1;
  }

  void _clampCurrentPage() {
    final maxPage = _totalPages - 1;
    if (_currentPage > maxPage) _currentPage = maxPage;
    if (_currentPage < 0) _currentPage = 0;
  }

  bool _hasActiveFilter(String c) =>
      (_columnValueFilters[c]?.isNotEmpty ?? false) ||
      _columnDateRangeFilters.containsKey(c);

  bool _isDateFilterColumn(String c) => c == 'fecha';

  DateTimeRange _dateBoundsForColumn(String c) {
    DateTime? minDate;
    DateTime? maxDate;
    for (final row in _rows) {
      final d = _dateValueForColumn(row, c);
      if (d == null) continue;
      final x = DateUtils.dateOnly(d);
      if (minDate == null || x.isBefore(minDate)) minDate = x;
      if (maxDate == null || x.isAfter(maxDate)) maxDate = x;
    }
    final now = DateUtils.dateOnly(DateTime.now());
    return DateTimeRange(
      start: minDate ?? DateTime(now.year - 3, 1, 1),
      end: maxDate ?? DateTime(now.year + 3, 12, 31),
    );
  }

  List<String> _columnDistinctValues(String c, {String search = ''}) {
    final q = search.toLowerCase().trim();
    final values = <String>{};
    for (final row in _rows) {
      if (!_matchesFilters(row, excludeColumn: c)) continue;
      final v = _cellTextForColumn(row, c);
      if (v.isEmpty) continue;
      if (q.isNotEmpty && !v.toLowerCase().contains(q)) continue;
      values.add(v);
    }
    final list = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  Future<void> _openColumnFilter(String columnId, String label) async {
    if (_isDateFilterColumn(columnId)) {
      final result = await _showInvDateRangeFilterDialog(
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
        _columnValueFilters.remove(columnId);
        _clampCurrentPage();
      });
      return;
    }

    final initialSelected = {...(_columnValueFilters[columnId] ?? <String>{})};
    final result = await showDialog<_InvFilterDialogResult>(
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
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 420,
                    constraints: const BoxConstraints(maxHeight: 560),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    decoration: _invFilterDialogDecoration(),
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
                          decoration: _invGlassFieldDecoration(
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
                              style: _invFilterOutlinedButtonStyle(),
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: _invFilterOutlinedButtonStyle(),
                              onPressed: () => Navigator.pop(
                                dialogContext,
                                const _InvFilterDialogResult(
                                  selectedValues: <String>{},
                                ),
                              ),
                              child: const Text('Limpiar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: _invFilterFilledButtonStyle(),
                              onPressed: () => Navigator.pop(
                                dialogContext,
                                _InvFilterDialogResult(
                                  selectedValues: localSelected,
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
        );
      },
    );
    if (result == null) return;
    setState(() {
      if (result.selectedValues.isEmpty) {
        _columnValueFilters.remove(columnId);
      } else {
        _columnValueFilters[columnId] = result.selectedValues;
      }
      _columnDateRangeFilters.remove(columnId);
      _clampCurrentPage();
    });
  }

  String _fmtUiDate(DateTime d) {
    final yy = (d.year % 100).toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd/$mm/$yy';
  }

  String _fmtDbDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  DateTime _parseDate(dynamic v) {
    if (v is String && v.length >= 10) {
      final y = int.tryParse(v.substring(0, 4));
      final m = int.tryParse(v.substring(5, 7));
      final d = int.tryParse(v.substring(8, 10));
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return DateUtils.dateOnly(DateTime.now());
  }

  void _setActiveInsertColumn(int value, {bool requestFocus = true}) {
    setState(() {
      _activeInsertColumn =
          ((value % _insertColumnCount) + _insertColumnCount) %
          _insertColumnCount;
      _selectedRowId = null;
      _selectionAnchorRowId = null;
      _bulkSelectedRowIds.clear();
    });
    if (!requestFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (_activeInsertColumn) {
        case 4:
          FocusScope.of(context).requestFocus(_insertKgFocusNode);
          break;
        case 5:
          FocusScope.of(context).requestFocus(_insertNotesFocusNode);
          break;
        default:
          FocusManager.instance.primaryFocus?.unfocus();
          _insertFocusNode.requestFocus();
      }
    });
  }

  void _moveInsertColumn(int delta) =>
      _setActiveInsertColumn(_activeInsertColumn + delta);

  bool _caretAtStart(TextEditingController c, FocusNode f) {
    if (!f.hasFocus) return false;
    final s = c.selection;
    return s.isValid &&
        s.isCollapsed &&
        s.baseOffset == 0 &&
        s.extentOffset == 0;
  }

  bool _caretAtEnd(TextEditingController c, FocusNode f) {
    if (!f.hasFocus) return false;
    final s = c.selection;
    final end = c.text.length;
    return s.isValid &&
        s.isCollapsed &&
        s.baseOffset == end &&
        s.extentOffset == end;
  }

  Future<void> _activateInsertCellFromKeyboard() async {
    switch (_activeInsertColumn) {
      case 0:
        final d = await _showInvKeyboardDatePickerDialog(
          context: context,
          initialDate: _draft.opDate ?? DateTime.now(),
          firstDate: DateTime(2024, 1, 1),
          lastDate: DateTime(2035, 12, 31),
        );
        if (d != null && mounted) {
          setState(
            () => _draft = _draft.copyWith(opDate: DateUtils.dateOnly(d)),
          );
        }
        return;
      case 1:
        final shift = await _showInvSearchablePickerDialog<String>(
          context,
          title: 'Turno',
          initialValue: _draft.shift,
          options: const [
            _InvPickerOption<String>(value: 'DAY', label: 'Día'),
            _InvPickerOption<String>(value: 'NIGHT', label: 'Noche'),
          ],
        );
        if (shift != null && mounted) {
          setState(() => _draft = _draft.copyWith(shift: shift));
        }
        return;
      case 2:
        final mode = await _showInvSearchablePickerDialog<String>(
          context,
          title: 'Origen',
          initialValue: _draft.sourceMode,
          options: const [
            _InvPickerOption<String>(value: 'MIXED', label: 'Compra revuelta'),
            _InvPickerOption<String>(
              value: 'DIRECT',
              label: 'Compra clasificada',
            ),
          ],
        );
        if (mode != null && mounted) {
          setState(() => _draft = _draft.copyWith(sourceMode: mode));
        }
        return;
      case 3:
        await _pickCommercialMaterialForDraft();
        return;
      case 6:
        await _insertDraft();
        return;
      default:
        return;
    }
  }

  Future<void> _pickCommercialMaterialForDraft() async {
    final selected = await _showInvSearchablePickerDialog<String>(
      context,
      title: _isScrap
          ? 'Material comercial de chatarra'
          : 'Material comercial de papel',
      initialValue: _draft.commercialMaterialCode,
      options: _commercialOptions
          .map(
            (option) => _InvPickerOption<String>(
              value: option.code,
              label: option.name,
            ),
          )
          .toList(),
    );
    if (selected != null && mounted) {
      setState(
        () => _draft = _draft.copyWith(commercialMaterialCode: selected),
      );
    }
  }

  void _clearActiveInsertCell() {
    switch (_activeInsertColumn) {
      case 0:
        setState(() => _draft = _draft.copyWith(opDate: null));
        return;
      case 1:
        setState(() => _draft = _draft.copyWith(shift: 'DAY'));
        return;
      case 2:
        setState(() => _draft = _draft.copyWith(sourceMode: 'MIXED'));
        return;
      case 3:
        setState(() => _draft = _draft.copyWith(commercialMaterialCode: null));
        return;
      case 4:
        _draftKgC.clear();
        setState(() => _draft = _draft.copyWith(weightKg: null));
        return;
      case 5:
        _draftNotesC.clear();
        setState(() => _draft = _draft.copyWith(notes: ''));
        return;
      default:
        return;
    }
  }

  void _focusGridFromInsert() {
    final firstVisibleId = _visibleRows.isEmpty
        ? null
        : _visibleRows.first['id'] as String;
    setState(() {
      _activeGridColumn = _activeInsertColumn > 6 ? 6 : _activeInsertColumn;
      if (firstVisibleId != null) {
        _selectedRowId = firstVisibleId;
        _selectionAnchorRowId = firstVisibleId;
        _bulkSelectedRowIds.clear();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rowsFocusNode.requestFocus();
    });
  }

  void _focusInsertFromGrid() {
    setState(() {
      _activeInsertColumn = _activeGridColumn > 6 ? 6 : _activeGridColumn;
      _selectedRowId = null;
      _selectionAnchorRowId = null;
      _bulkSelectedRowIds.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setActiveInsertColumn(_activeInsertColumn);
    });
  }

  void _selectRow(
    String id, {
    bool additive = false,
    bool allowToggle = false,
  }) {
    setState(() {
      if (additive) {
        if (_bulkSelectedRowIds.contains(id)) {
          _bulkSelectedRowIds.remove(id);
          if (_selectedRowId == id) {
            _selectedRowId = _bulkSelectedRowIds.isEmpty
                ? null
                : _bulkSelectedRowIds.last;
          }
        } else {
          if (_selectedRowId != null) _bulkSelectedRowIds.add(_selectedRowId!);
          _bulkSelectedRowIds.add(id);
          _selectedRowId = id;
          _selectionAnchorRowId ??= id;
        }
        return;
      }
      if (allowToggle && _selectedRowId == id) {
        _selectedRowId = null;
        _bulkSelectedRowIds.clear();
        return;
      }
      _selectedRowId = id;
      _selectionAnchorRowId = id;
      _bulkSelectedRowIds.clear();
    });
  }

  void _moveSelectedRow(int delta, {bool extendSelection = false}) {
    final rows = _visibleRows;
    if (rows.isEmpty) return;
    final currentIndex = _selectedRowId == null
        ? -1
        : rows.indexWhere((r) => r['id'] == _selectedRowId);
    final nextIndex = currentIndex == -1
        ? (delta >= 0 ? 0 : rows.length - 1)
        : (((currentIndex + delta) % rows.length) + rows.length) % rows.length;
    final id = rows[nextIndex]['id'] as String;
    _selectRow(id, additive: extendSelection);
    if (_rowsScrollController.hasClients) {
      _rowsScrollController.animateTo(
        (nextIndex * 78.0)
            .clamp(0.0, _rowsScrollController.position.maxScrollExtent)
            .toDouble(),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool _isShiftPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
  }

  _SeparationDataRowState? _selectedRowState() {
    final id = _selectedRowId;
    if (id == null) return null;
    return _rowKeys[id]?.currentState;
  }

  List<_SeparationDataRowState> _selectedRowStates() {
    if (_bulkSelectedRowIds.isEmpty) {
      final s = _selectedRowState();
      return s == null ? const [] : [s];
    }
    final ids = <String>[];
    if (_selectedRowId != null) ids.add(_selectedRowId!);
    for (final id in _bulkSelectedRowIds) {
      if (!ids.contains(id)) ids.add(id);
    }
    return ids
        .map((id) => _rowKeys[id]?.currentState)
        .whereType<_SeparationDataRowState>()
        .toList();
  }

  int get _selectedCount {
    final ids = <String>{..._bulkSelectedRowIds};
    if (_selectedRowId != null) ids.add(_selectedRowId!);
    return ids.length;
  }

  Set<String> _currentSelectionIds() {
    final ids = <String>{..._bulkSelectedRowIds};
    if (_selectedRowId != null) ids.add(_selectedRowId!);
    return ids;
  }

  double get _filteredKgTotal {
    double total = 0;
    for (final row in _filteredRows) {
      total += _toDouble(row['weight_kg']) ?? 0;
    }
    return total;
  }

  ({double sum, double avg}) _selectedKgStats() {
    final ids = _currentSelectionIds();
    if (ids.isEmpty) return (sum: 0, avg: 0);
    final byId = <String, Map<String, dynamic>>{
      for (final row in _visibleRows) row['id'] as String: row,
    };
    double sum = 0;
    var count = 0;
    for (final id in ids) {
      final row = byId[id];
      if (row == null) continue;
      sum += _toDouble(row['weight_kg']) ?? 0;
      count++;
    }
    final avg = count == 0 ? 0.0 : sum / count;
    return (sum: sum, avg: avg);
  }

  void _scheduleTopBarSync() {
    if (_topBarSyncScheduled || widget.onTopBarChanged == null) return;
    _topBarSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _topBarSyncScheduled = false;
      _notifyTopBarChanged();
    });
  }

  void _notifyTopBarChanged() {
    if (!mounted || widget.onTopBarChanged == null) return;
    widget.onTopBarChanged!(_buildTopBarData());
  }

  InventoryGridTopBarData _buildTopBarData() {
    final activeCell =
        (_gridEditMode || (_selectedRowState()?.isEditing ?? false))
        ? _gridColumnLabels[_activeGridColumn]
        : null;
    final selectedStats = _selectedKgStats();
    return InventoryGridTopBarData(
      metricIcon: _isScrap
          ? Icons.construction_rounded
          : Icons.description_rounded,
      metricLabel: _isScrap
          ? 'KG CHATARRA CLASIFICADA'
          : 'KG PAPEL CLASIFICADO',
      metricValue: _fmtInvCount(_filteredKgTotal, decimals: 2),
      metricSubtitle:
          'Filtrado (${_fmtInvInt(_filteredRows.length)} registros)',
      exportingCsv: _exportingCsv,
      gridEditMode: _gridEditMode,
      canToggleGridEdit: _visibleRows.isNotEmpty,
      canDeleteSelection: _bulkSelectedRowIds.isNotEmpty,
      deletingSelection: _bulkDeleting,
      selectedCount: _selectedCount,
      selectedKgSumLabel: _selectedCount > 0
          ? '${_fmtInvCount(selectedStats.sum, decimals: 2)} kg'
          : null,
      selectedKgAvgLabel: _selectedCount > 0
          ? '${_fmtInvCount(selectedStats.avg, decimals: 2)} kg'
          : null,
      activeCellLabel: activeCell,
      onExportCsv: _exportingCsv ? null : _exportCsv,
      onToggleGridEdit: null,
      onSaveGridEdit: null,
      onCancelGridEdit: null,
      onDeleteSelection: _bulkDeleting ? null : _deleteSelectedRows,
    );
  }

  void _handleEnterOnSelectedRow() {
    final states = _selectedRowStates();
    if (states.isEmpty) return;
    if (states.any((s) => !s.isEditing)) {
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
    if (states.any((s) => s.isEditing)) {
      for (final s in states) {
        s.cancelEditingFromKeyboard();
      }
      return;
    }
    setState(() {
      _selectedRowId = null;
      _selectionAnchorRowId = null;
      _bulkSelectedRowIds.clear();
    });
  }

  void _handleDeleteOnSelectedRow() {
    if (_bulkSelectedRowIds.length > 1) {
      unawaited(_deleteSelectedRows());
      return;
    }
    final s = _selectedRowState();
    if (s != null) unawaited(s.deleteWithConfirmation());
  }

  void _moveGridColumn(int delta) {
    setState(() {
      _activeGridColumn =
          ((_activeGridColumn + delta) % _gridColumnCount + _gridColumnCount) %
          _gridColumnCount;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectedRowState()?.focusTextIfNeeded(_activeGridColumn);
    });
  }

  void _moveGridRow(int delta, {bool extendSelection = false}) {
    _moveSelectedRow(delta, extendSelection: extendSelection);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectedRowState()?.focusTextIfNeeded(_activeGridColumn);
    });
  }

  void _activateGridCellFromKeyboard() {
    final s = _selectedRowState();
    if (s == null) return;
    if (!s.isEditing) s.startEditingFromKeyboard();
    unawaited(s.activateGridCell(_activeGridColumn));
  }

  Future<void> _openRowsContextMenuAt(Offset globalPosition) async {
    final selectedStates = _selectedRowStates();
    final anyEditing = selectedStates.any((s) => s.isEditing);
    final multiContext = _currentSelectionIds().length > 1;
    const menuTextStyle = TextStyle(
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
      color: Color(0xFF223D5A),
    );
    final media = MediaQuery.of(context).size;
    final action = await showMenu<String>(
      context: context,
      color: _kInvGlassMenuBg,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        media.width - globalPosition.dx,
        media.height - globalPosition.dy,
      ),
      items: [
        if (multiContext && !anyEditing)
          const PopupMenuItem(
            value: 'multi_edit',
            child: Text('EDITAR SELECCIÓN', style: menuTextStyle),
          ),
        if (multiContext && anyEditing)
          const PopupMenuItem(
            value: 'multi_save',
            child: Text('GUARDAR SELECCIÓN', style: menuTextStyle),
          ),
        if (multiContext && anyEditing)
          const PopupMenuItem(
            value: 'multi_cancel',
            child: Text('CANCELAR EDICIÓN', style: menuTextStyle),
          ),
        if (!multiContext && !anyEditing)
          const PopupMenuItem(
            value: 'edit',
            child: Text('EDITAR', style: menuTextStyle),
          ),
        if (!multiContext && anyEditing)
          const PopupMenuItem(
            value: 'save',
            child: Text('GUARDAR', style: menuTextStyle),
          ),
        if (!multiContext && anyEditing)
          const PopupMenuItem(
            value: 'cancel',
            child: Text('CANCELAR', style: menuTextStyle),
          ),
        const PopupMenuDivider(),
        if (multiContext)
          const PopupMenuItem(
            value: 'multi_delete',
            child: Text('ELIMINAR SELECCIÓN', style: menuTextStyle),
          ),
        if (!multiContext)
          const PopupMenuItem(
            value: 'delete',
            child: Text('ELIMINAR', style: menuTextStyle),
          ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        _handleEnterOnSelectedRow();
        break;
      case 'save':
        await Future.wait(
          _selectedRowStates().map((s) => s.saveFromKeyboard()),
        );
        break;
      case 'cancel':
        for (final s in _selectedRowStates()) {
          s.cancelEditingFromKeyboard();
        }
        break;
      case 'delete':
        _handleDeleteOnSelectedRow();
        break;
      case 'multi_edit':
        for (final s in _selectedRowStates()) {
          s.startEditingFromKeyboard();
        }
        break;
      case 'multi_save':
        await Future.wait(
          _selectedRowStates().map((s) => s.saveFromKeyboard()),
        );
        break;
      case 'multi_cancel':
        for (final s in _selectedRowStates()) {
          s.cancelEditingFromKeyboard();
        }
        break;
      case 'multi_delete':
        await _deleteSelectedRows();
        break;
    }
  }

  Widget _buildInlineInsertRow() {
    final commercialItems = _commercialOptions.map((o) => o.code).toList();
    final draftKg = _toDouble(_draftKgC.text) ?? 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget frame(int colIndex, Widget child) {
          final active = _activeInsertColumn == colIndex;
          return DecoratedBox(
            position: DecorationPosition.background,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: active
                  ? const Color(0xFFDCEAF7).withValues(alpha: 0.72)
                  : Colors.transparent,
            ),
            child: DecoratedBox(
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
            ),
          );
        }

        Widget control(Widget child) => SizedBox(height: 34, child: child);

        return Focus(
          focusNode: _insertFocusNode,
          autofocus: false,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.arrowLeft) {
              if (_insertKgFocusNode.hasFocus &&
                  !_caretAtStart(_draftKgC, _insertKgFocusNode)) {
                return KeyEventResult.ignored;
              }
              if (_insertNotesFocusNode.hasFocus &&
                  !_caretAtStart(_draftNotesC, _insertNotesFocusNode)) {
                return KeyEventResult.ignored;
              }
              _moveInsertColumn(-1);
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowRight) {
              if (_insertKgFocusNode.hasFocus &&
                  !_caretAtEnd(_draftKgC, _insertKgFocusNode)) {
                return KeyEventResult.ignored;
              }
              if (_insertNotesFocusNode.hasFocus &&
                  !_caretAtEnd(_draftNotesC, _insertNotesFocusNode)) {
                return KeyEventResult.ignored;
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
              if (_insertKgFocusNode.hasFocus ||
                  _insertNotesFocusNode.hasFocus) {
                return KeyEventResult.ignored;
              }
              unawaited(_activateInsertCellFromKeyboard());
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.delete ||
                key == LogicalKeyboardKey.backspace) {
              if (_insertKgFocusNode.hasFocus ||
                  _insertNotesFocusNode.hasFocus) {
                return KeyEventResult.ignored;
              }
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
              unawaited(_insertDraft());
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Card(
            elevation: 0.4,
            color: _insertRowActive
                ? const Color(0xFFD9ECFA)
                : const Color(0xFFE7F1F8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: _insertRowActive
                    ? const Color(0xFF3C8DCC).withValues(alpha: 0.55)
                    : Colors.transparent,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: SizedBox(
                width: constraints.maxWidth,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _sepTableContentWFor(constraints.maxWidth),
                    child: Row(
                      children: [
                        frame(
                          0,
                          SizedBox(
                            width: _kSepDateColW,
                            child: control(
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  _setActiveInsertColumn(0);
                                  final d =
                                      await _showInvKeyboardDatePickerDialog(
                                        context: context,
                                        initialDate:
                                            _draft.opDate ?? DateTime.now(),
                                        firstDate: DateTime(2024, 1, 1),
                                        lastDate: DateTime(2035, 12, 31),
                                      );
                                  if (d != null && mounted) {
                                    setState(
                                      () => _draft = _draft.copyWith(
                                        opDate: DateUtils.dateOnly(d),
                                      ),
                                    );
                                  }
                                },
                                child: InputDecorator(
                                  decoration: _invGlassFieldDecoration(),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _InvFitText(
                                          _draft.opDate == null
                                              ? '—'
                                              : _fmtUiDate(_draft.opDate!),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.calendar_month,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        frame(
                          1,
                          SizedBox(
                            width: _kSepShiftColW,
                            child: control(
                              _InvDropStrInline(
                                value: _draft.shift ?? 'DAY',
                                items: const ['DAY', 'NIGHT'],
                                format: _prodShiftLabel,
                                onTapStart: () => _setActiveInsertColumn(1),
                                onChanged: (v) => setState(
                                  () => _draft = _draft.copyWith(shift: v),
                                ),
                              ),
                            ),
                          ),
                        ),
                        frame(
                          2,
                          SizedBox(
                            width: _kSepModeColW,
                            child: control(
                              _InvDropStrInline(
                                value: _draft.sourceMode ?? 'MIXED',
                                items: const ['MIXED', 'DIRECT'],
                                format: _separationSourceModeLabel,
                                onTapStart: () => _setActiveInsertColumn(2),
                                onChanged: (v) => setState(
                                  () => _draft = _draft.copyWith(sourceMode: v),
                                ),
                              ),
                            ),
                          ),
                        ),
                        frame(
                          3,
                          SizedBox(
                            width: _kSepCommercialColW,
                            child: control(
                              commercialItems.isEmpty
                                  ? InputDecorator(
                                      decoration: _invGlassFieldDecoration(
                                        hintText: 'Material comercial',
                                      ),
                                      child: const _InvFitText('Sin opciones'),
                                    )
                                  : _InvDropStrInline(
                                      value:
                                          (_draft.commercialMaterialCode !=
                                                  null &&
                                              commercialItems.contains(
                                                _draft.commercialMaterialCode,
                                              ))
                                          ? _draft.commercialMaterialCode!
                                          : commercialItems.first,
                                      items: commercialItems,
                                      format: _commercialLabel,
                                      onTapStart: () =>
                                          _setActiveInsertColumn(3),
                                      onChanged: (v) => setState(
                                        () => _draft = _draft.copyWith(
                                          commercialMaterialCode: v,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        frame(
                          4,
                          SizedBox(
                            width: _kSepKgColW,
                            child: control(
                              TextField(
                                controller: _draftKgC,
                                focusNode: _insertKgFocusNode,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _invGlassFieldDecoration(
                                  hintText: 'Kg',
                                ),
                                onTap: () => _setActiveInsertColumn(
                                  4,
                                  requestFocus: false,
                                ),
                                onChanged: (_) => setState(
                                  () => _draft = _draft.copyWith(
                                    weightKg: _toDouble(_draftKgC.text),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        frame(
                          5,
                          SizedBox(
                            width: _kSepNotesColW,
                            child: control(
                              TextField(
                                controller: _draftNotesC,
                                focusNode: _insertNotesFocusNode,
                                decoration: _invGlassFieldDecoration(
                                  hintText: 'Comentario',
                                ),
                                onTap: () => _setActiveInsertColumn(
                                  5,
                                  requestFocus: false,
                                ),
                                onChanged: (_) => setState(
                                  () => _draft = _draft.copyWith(
                                    notes: _draftNotesC.text,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        frame(
                          6,
                          SizedBox(
                            width: _kSepActionsColW,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.42,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '${_fmtInvCount(draftKg, decimals: 1)} kg',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'AGREGAR',
                                  child: MouseRegion(
                                    onEnter: (_) => setState(
                                      () => _hoverInsertAddButton = true,
                                    ),
                                    onExit: (_) => setState(
                                      () => _hoverInsertAddButton = false,
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: _inserting ? null : _insertDraft,
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: _inserting
                                              ? Colors.white.withValues(
                                                  alpha: 0.35,
                                                )
                                              : const Color(
                                                  0xFF19C37D,
                                                ).withValues(alpha: 0.92),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.52,
                                            ),
                                          ),
                                          boxShadow:
                                              _hoverInsertAddButton &&
                                                  !_inserting
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.20,
                                                        ),
                                                    blurRadius: 16,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                ]
                                              : [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.10,
                                                        ),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                        ),
                                        child: _inserting
                                            ? const Padding(
                                                padding: EdgeInsets.all(8),
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.add,
                                                size: 18,
                                                color: Colors.white,
                                              ),
                                      ),
                                    ),
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
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingRows || _loadingCommercials) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTopBarChrome)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
            child: InventoryGridTopBar(data: _buildTopBarData()),
          ),
        _SeparationHeaderRow(
          hasActiveFilter: _hasActiveFilter,
          onOpenFilter: _openColumnFilter,
        ),
        const SizedBox(height: 8),
        _buildInlineInsertRow(),
        const SizedBox(height: 8),
        Expanded(
          child: Focus(
            focusNode: _rowsFocusNode,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                return KeyEventResult.ignored;
              }
              final key = event.logicalKey;
              final selectedState = _selectedRowState();
              final inTextEditing =
                  selectedState?.isTextCellFocused(_activeGridColumn) ?? false;
              if (key == LogicalKeyboardKey.arrowDown) {
                if (_isShiftPressed()) {
                  _moveGridRow(1, extendSelection: true);
                } else {
                  _moveGridRow(1);
                }
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowUp) {
                if (_isShiftPressed()) {
                  _moveGridRow(-1, extendSelection: true);
                } else {
                  _moveGridRow(-1);
                }
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowRight) {
                if (inTextEditing &&
                    !selectedState!.activeTextCaretAtEnd(_activeGridColumn)) {
                  return KeyEventResult.ignored;
                }
                _moveGridColumn(1);
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowLeft) {
                if (inTextEditing &&
                    !selectedState!.activeTextCaretAtStart(_activeGridColumn)) {
                  return KeyEventResult.ignored;
                }
                _moveGridColumn(-1);
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.enter ||
                  key == LogicalKeyboardKey.numpadEnter) {
                _handleEnterOnSelectedRow();
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.space) {
                _activateGridCellFromKeyboard();
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.escape) {
                _handleEscapeOnSelectedRow();
                return KeyEventResult.handled;
              }
              if ((key == LogicalKeyboardKey.delete ||
                      key == LogicalKeyboardKey.backspace) &&
                  !inTextEditing) {
                _handleDeleteOnSelectedRow();
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.tab && event is KeyDownEvent) {
                _focusInsertFromGrid();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: _visibleRows.isEmpty
                ? const Center(child: Text('Sin registros'))
                : ListView.separated(
                    controller: _rowsScrollController,
                    itemCount: _visibleRows.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final row = _visibleRows[i];
                      final id = row['id'] as String;
                      final key = _rowKeys.putIfAbsent(
                        id,
                        () => GlobalKey<_SeparationDataRowState>(
                          debugLabel: 'sep_row_$id',
                        ),
                      );
                      return _SeparationDataRow(
                        key: key,
                        row: row,
                        commercialOptions: _commercialOptions,
                        selectedCount: _selectedCount,
                        isSelected: _selectedRowId == id,
                        isChecked: _bulkSelectedRowIds.contains(id),
                        activeGridColumn: _activeGridColumn,
                        gridSaveSignal: _gridSaveSignal,
                        gridCancelSignal: _gridCancelSignal,
                        onActivateColumn: (col) =>
                            setState(() => _activeGridColumn = col),
                        onSelect: (additive) =>
                            _selectRow(id, additive: additive),
                        onOpenContextMenu: (position) {
                          unawaited(_openRowsContextMenuAt(position));
                        },
                        onDelete: _deleteRow,
                        onUpdate: _updateRow,
                        onMultiEdit: () {
                          for (final state in _selectedRowStates()) {
                            state.startEditingFromKeyboard();
                          }
                        },
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Página ${_currentPage + 1} de $_totalPages',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: _currentPage <= 0
                  ? null
                  : () => setState(() => _currentPage--),
              child: const Text('Anterior'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _currentPage >= _totalPages - 1
                  ? null
                  : () => setState(() => _currentPage++),
              child: const Text('Siguiente'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SeparationHeaderRow extends StatelessWidget {
  final bool Function(String columnId) hasActiveFilter;
  final Future<void> Function(String columnId, String label) onOpenFilter;

  const _SeparationHeaderRow({
    required this.hasActiveFilter,
    required this.onOpenFilter,
  });

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12, fontWeight: FontWeight.w800);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Card(
          elevation: 0,
          color: Colors.black.withValues(alpha: 0.03),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _sepTableContentWFor(constraints.maxWidth),
                child: Row(
                  children: [
                    _InvHCell(
                      'FECHA',
                      _kSepDateColW,
                      style,
                      active: hasActiveFilter('fecha'),
                      onFilter: () => onOpenFilter('fecha', 'FECHA'),
                    ),
                    _InvHCell(
                      'TURNO',
                      _kSepShiftColW,
                      style,
                      active: hasActiveFilter('turno'),
                      onFilter: () => onOpenFilter('turno', 'TURNO'),
                    ),
                    _InvHCell(
                      'ORIGEN',
                      _kSepModeColW,
                      style,
                      active: hasActiveFilter('origen'),
                      onFilter: () => onOpenFilter('origen', 'ORIGEN'),
                    ),
                    _InvHCell(
                      'MATERIAL COMERCIAL',
                      _kSepCommercialColW,
                      style,
                      active: hasActiveFilter('commercial'),
                      onFilter: () =>
                          onOpenFilter('commercial', 'MATERIAL COMERCIAL'),
                    ),
                    _InvHCell(
                      'KG',
                      _kSepKgColW,
                      style,
                      active: hasActiveFilter('kg'),
                      onFilter: () => onOpenFilter('kg', 'KG'),
                    ),
                    SizedBox(
                      width: _kSepNotesColW,
                      child: _InvHCellExpand(
                        'COMENTARIO',
                        style,
                        active: hasActiveFilter('notes'),
                        onFilter: () => onOpenFilter('notes', 'COMENTARIO'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const SizedBox(width: _kSepActionsColW),
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

class _SeparationDataRow extends StatefulWidget {
  final Map<String, dynamic> row;
  final List<_SeparationCommercialOption> commercialOptions;
  final bool isSelected;
  final bool isChecked;
  final int selectedCount;
  final int activeGridColumn;
  final int gridSaveSignal;
  final int gridCancelSignal;
  final void Function(int col) onActivateColumn;
  final void Function(bool additive) onSelect;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(String id, Map<String, dynamic> patch) onUpdate;
  final void Function(Offset globalPosition) onOpenContextMenu;
  final VoidCallback onMultiEdit;

  const _SeparationDataRow({
    super.key,
    required this.row,
    required this.commercialOptions,
    required this.isSelected,
    required this.isChecked,
    required this.selectedCount,
    required this.activeGridColumn,
    required this.gridSaveSignal,
    required this.gridCancelSignal,
    required this.onActivateColumn,
    required this.onSelect,
    required this.onDelete,
    required this.onUpdate,
    required this.onOpenContextMenu,
    required this.onMultiEdit,
  });

  @override
  State<_SeparationDataRow> createState() => _SeparationDataRowState();
}

class _SeparationDataRowState extends State<_SeparationDataRow> {
  late DateTime _opDate;
  late String? _shift;
  late String? _sourceMode;
  late String? _commercialMaterialCode;
  final TextEditingController _kgC = TextEditingController();
  final TextEditingController _notesC = TextEditingController();
  final FocusNode _kgFocusNode = FocusNode(debugLabel: 'sep_row_kg');
  final FocusNode _notesFocusNode = FocusNode(debugLabel: 'sep_row_notes');
  bool _editing = false;
  bool _hovering = false;
  int? _hoveredEditableColumn;
  int _lastGridSaveSignal = 0;
  int _lastGridCancelSignal = 0;

  String get id => widget.row['id'] as String;
  bool get isEditing => _editing;
  bool get isAnyEditableTextFocused => _isEditableTextFocused();

  @override
  void initState() {
    super.initState();
    _hydrateFromRow();
    _lastGridSaveSignal = widget.gridSaveSignal;
    _lastGridCancelSignal = widget.gridCancelSignal;
  }

  @override
  void didUpdateWidget(covariant _SeparationDataRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row != widget.row && !_editing) {
      _hydrateFromRow();
    }
    if (widget.gridSaveSignal != _lastGridSaveSignal) {
      _lastGridSaveSignal = widget.gridSaveSignal;
      unawaited(saveFromKeyboard());
    }
    if (widget.gridCancelSignal != _lastGridCancelSignal) {
      _lastGridCancelSignal = widget.gridCancelSignal;
      cancelEditingFromKeyboard();
    }
  }

  @override
  void dispose() {
    _kgC.dispose();
    _notesC.dispose();
    _kgFocusNode.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  void _hydrateFromRow() {
    _opDate = _sepParseDate(widget.row['op_date']);
    _shift = widget.row['shift']?.toString();
    _sourceMode = widget.row['source_mode']?.toString();
    _commercialMaterialCode = widget.row['commercial_material_code']
        ?.toString();
    _kgC.text = ((_toDouble(widget.row['weight_kg']) ?? 0) == 0)
        ? ''
        : (_toDouble(widget.row['weight_kg']) ?? 0).toStringAsFixed(2);
    _notesC.text = (widget.row['notes'] ?? '').toString();
  }

  bool isTextCellFocused(int col) => switch (col) {
    4 => _kgFocusNode.hasFocus,
    5 => _notesFocusNode.hasFocus,
    _ => false,
  };

  bool activeTextCaretAtStart(int col) => switch (col) {
    4 => _caretAtStart(_kgC, _kgFocusNode),
    5 => _caretAtStart(_notesC, _notesFocusNode),
    _ => true,
  };

  bool activeTextCaretAtEnd(int col) => switch (col) {
    4 => _caretAtEnd(_kgC, _kgFocusNode),
    5 => _caretAtEnd(_notesC, _notesFocusNode),
    _ => true,
  };

  bool _caretAtStart(TextEditingController c, FocusNode f) {
    if (!f.hasFocus) return false;
    final s = c.selection;
    return s.isValid &&
        s.isCollapsed &&
        s.baseOffset == 0 &&
        s.extentOffset == 0;
  }

  bool _caretAtEnd(TextEditingController c, FocusNode f) {
    if (!f.hasFocus) return false;
    final s = c.selection;
    final e = c.text.length;
    return s.isValid &&
        s.isCollapsed &&
        s.baseOffset == e &&
        s.extentOffset == e;
  }

  bool _isEditableTextFocused() {
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void focusTextIfNeeded(int col) {
    if (!_editing) return;
    switch (col) {
      case 4:
        FocusScope.of(context).requestFocus(_kgFocusNode);
        return;
      case 5:
        FocusScope.of(context).requestFocus(_notesFocusNode);
        return;
    }
  }

  void startEditingFromKeyboard() {
    if (!_editing) setState(() => _editing = true);
  }

  void cancelEditingFromKeyboard() {
    _hydrateFromRow();
    if (mounted) setState(() => _editing = false);
  }

  Future<void> deleteWithConfirmation() async {
    final ok = await _showConfirmDialog(
      context,
      title: 'Eliminar registro',
      content: '¿Eliminar este registro de separación?',
      confirmText: 'Eliminar',
    );
    if (ok == true) await widget.onDelete(id);
  }

  Future<void> activateGridCell(int col) async {
    if (!_editing) return;
    switch (col) {
      case 0:
        final d = await _showInvKeyboardDatePickerDialog(
          context: context,
          initialDate: _opDate,
          firstDate: DateTime(2024, 1, 1),
          lastDate: DateTime(2035, 12, 31),
        );
        if (d != null) setState(() => _opDate = DateUtils.dateOnly(d));
        return;
      case 1:
        final shift = await _showInvSearchablePickerDialog<String>(
          context,
          title: 'Turno',
          initialValue: _shift,
          options: const [
            _InvPickerOption<String>(value: 'DAY', label: 'Día'),
            _InvPickerOption<String>(value: 'NIGHT', label: 'Noche'),
          ],
        );
        if (shift != null) setState(() => _shift = shift);
        return;
      case 2:
        final mode = await _showInvSearchablePickerDialog<String>(
          context,
          title: 'Origen',
          initialValue: _sourceMode,
          options: const [
            _InvPickerOption<String>(value: 'MIXED', label: 'Compra revuelta'),
            _InvPickerOption<String>(
              value: 'DIRECT',
              label: 'Compra clasificada',
            ),
          ],
        );
        if (mode != null) setState(() => _sourceMode = mode);
        return;
      case 3:
        final selected = await _showInvSearchablePickerDialog<String>(
          context,
          title: 'Material comercial',
          initialValue: _commercialMaterialCode,
          options: widget.commercialOptions
              .map(
                (option) => _InvPickerOption<String>(
                  value: option.code,
                  label: option.name,
                ),
              )
              .toList(),
        );
        if (selected != null) {
          setState(() => _commercialMaterialCode = selected);
        }
        return;
      case 4:
        FocusScope.of(context).requestFocus(_kgFocusNode);
        return;
      case 5:
        FocusScope.of(context).requestFocus(_notesFocusNode);
        return;
      default:
        return;
    }
  }

  void _enterEditingFromPointer(int col) {
    if (_isAdditiveSelectionPressed()) {
      widget.onSelect(true);
      return;
    }
    final multiContext =
        widget.selectedCount > 1 && (widget.isSelected || widget.isChecked);
    if (multiContext) {
      widget.onMultiEdit();
      return;
    }
    widget.onSelect(false);
    widget.onActivateColumn(col);
    if (!_editing) setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(activateGridCell(col));
    });
  }

  void _previewEditableCellTap(int col) {
    if (_isAdditiveSelectionPressed()) {
      widget.onSelect(true);
      return;
    }
    widget.onSelect(false);
    widget.onActivateColumn(col);
  }

  bool _isAdditiveSelectionPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  Future<void> saveFromKeyboard() async {
    final kg = _toDouble(_kgC.text);
    if ((_commercialMaterialCode ?? '').trim().isEmpty ||
        kg == null ||
        kg <= 0) {
      return;
    }
    await widget.onUpdate(id, {
      'op_date': _sepFmtDbDate(_opDate),
      'shift': _shift,
      'source_mode': _sourceMode,
      'commercial_material_code': _commercialMaterialCode,
      'weight_kg': kg,
      'notes': _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
    });
    if (mounted) setState(() => _editing = false);
  }

  String _commercialLabel(String? code) {
    final normalized = (code ?? '').trim();
    if (normalized.isEmpty) return '';
    for (final option in widget.commercialOptions) {
      if (option.code == normalized) return option.name;
    }
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = widget.isSelected || widget.isChecked;
    final hoverOnly = _hovering && !hasSelection;
    final rowBg = _editing
        ? const Color(0xFFE2EEF8)
        : hasSelection
        ? const Color(
            0xFF00A3FF,
          ).withValues(alpha: widget.isSelected ? 0.16 : 0.13)
        : hoverOnly
        ? const Color(0xFFE9F7EE)
        : Colors.white;

    Widget frame(int col, Widget child) {
      final active =
          _editing && widget.isSelected && widget.activeGridColumn == col;
      return DecoratedBox(
        position: DecorationPosition.background,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: !_editing && _hoveredEditableColumn == col
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (hasSelection
                            ? const Color(0xFFD9E8F6)
                            : const Color(0xFFE5F2EC))
                        .withValues(alpha: 0.78),
                    (hasSelection
                            ? const Color(0xFFCCE0F2)
                            : const Color(0xFFD4E7DE))
                        .withValues(alpha: 0.64),
                  ],
                )
              : null,
          color: active
              ? const Color(0xFFDCEAF7).withValues(alpha: 0.72)
              : Colors.transparent,
          border: Border.all(
            color: active
                ? const Color(0xFF0B72FF).withValues(alpha: 0.84)
                : Colors.transparent,
          ),
        ),
        child: child,
      );
    }

    Widget previewEditableCell({required int col, required Widget child}) {
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
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _previewEditableCellTap(col),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () => _enterEditingFromPointer(col),
            child: child,
          ),
        ),
      );
    }

    Widget readonlyCell({
      required Widget child,
      bool showDivider = true,
      EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 4),
    }) {
      return Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(child: child),
            if (showDivider)
              Container(
                width: 1,
                height: 30,
                margin: const EdgeInsets.only(left: 8, right: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9D5E2).withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      );
    }

    return TapRegion(
      onTapOutside: (_) {
        if (_editing) cancelEditingFromKeyboard();
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (_) {
            if (_editing) return;
            widget.onSelect(_isAdditiveSelectionPressed());
          },
          onDoubleTap: () => _enterEditingFromPointer(0),
          onSecondaryTapDown: (details) {
            if (!hasSelection) widget.onSelect(false);
            widget.onOpenContextMenu(details.globalPosition);
          },
          child: Card(
            elevation: hasSelection
                ? 3.2
                : _hovering
                ? 2.7
                : 0.5,
            color: rowBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: widget.isSelected
                    ? const Color(0xFF00A3FF).withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.0),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: _sepTableContentWFor(constraints.maxWidth),
                      child: Row(
                        children: [
                          frame(
                            0,
                            SizedBox(
                              width: _kSepDateColW,
                              child: _editing
                                  ? InkWell(
                                      onTap: () {
                                        widget.onActivateColumn(0);
                                        activateGridCell(0);
                                      },
                                      child: _InvCellBox(
                                        text: _sepFmtUiDate(_opDate),
                                        icon: Icons.calendar_month,
                                      ),
                                    )
                                  : previewEditableCell(
                                      col: 0,
                                      child: readonlyCell(
                                        child: _InvFitText(
                                          _sepFmtUiDate(_opDate),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          frame(
                            1,
                            SizedBox(
                              width: _kSepShiftColW,
                              child: _editing
                                  ? _InvDropStrInline(
                                      value: _shift ?? 'DAY',
                                      items: const ['DAY', 'NIGHT'],
                                      format: _prodShiftLabel,
                                      onTapStart: () =>
                                          widget.onActivateColumn(1),
                                      onChanged: (v) =>
                                          setState(() => _shift = v),
                                    )
                                  : previewEditableCell(
                                      col: 1,
                                      child: readonlyCell(
                                        child: _InvPillTag(
                                          label: _prodShiftLabel(_shift),
                                          background: _prodShiftChipColors(
                                            _shift,
                                          ).bg,
                                          foreground: _prodShiftChipColors(
                                            _shift,
                                          ).fg,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          frame(
                            2,
                            SizedBox(
                              width: _kSepModeColW,
                              child: _editing
                                  ? _InvDropStrInline(
                                      value: _sourceMode ?? 'MIXED',
                                      items: const ['MIXED', 'DIRECT'],
                                      format: _separationSourceModeLabel,
                                      onTapStart: () =>
                                          widget.onActivateColumn(2),
                                      onChanged: (v) =>
                                          setState(() => _sourceMode = v),
                                    )
                                  : previewEditableCell(
                                      col: 2,
                                      child: readonlyCell(
                                        child: _InvPillTag(
                                          label: _separationSourceModeLabel(
                                            _sourceMode,
                                          ),
                                          background:
                                              _separationSourceModeColors(
                                                _sourceMode,
                                              ).bg,
                                          foreground:
                                              _separationSourceModeColors(
                                                _sourceMode,
                                              ).fg,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          frame(
                            3,
                            SizedBox(
                              width: _kSepCommercialColW,
                              child: _editing
                                  ? InkWell(
                                      onTap: () {
                                        widget.onActivateColumn(3);
                                        activateGridCell(3);
                                      },
                                      child: _InvCellBox(
                                        text: _commercialLabel(
                                          _commercialMaterialCode,
                                        ),
                                        icon: Icons.category_rounded,
                                      ),
                                    )
                                  : previewEditableCell(
                                      col: 3,
                                      child: readonlyCell(
                                        child: _InvFitText(
                                          _commercialLabel(
                                            _commercialMaterialCode,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          frame(
                            4,
                            SizedBox(
                              width: _kSepKgColW,
                              child: _editing
                                  ? _InvTextInline(
                                      controller: _kgC,
                                      focusNode: _kgFocusNode,
                                      hint: 'Kg',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      onTapStart: () =>
                                          widget.onActivateColumn(4),
                                    )
                                  : previewEditableCell(
                                      col: 4,
                                      child: readonlyCell(
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: _InvFitText(
                                            _kgC.text.isEmpty
                                                ? '0.00'
                                                : _kgC.text,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          frame(
                            5,
                            SizedBox(
                              width: _kSepNotesColW,
                              child: _editing
                                  ? _InvTextInline(
                                      controller: _notesC,
                                      focusNode: _notesFocusNode,
                                      hint: 'Comentario',
                                      onTapStart: () =>
                                          widget.onActivateColumn(5),
                                    )
                                  : previewEditableCell(
                                      col: 5,
                                      child: readonlyCell(
                                        showDivider: false,
                                        child: _InvFitText(
                                          _notesC.text.trim().isEmpty
                                              ? '—'
                                              : _notesC.text.trim(),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: _kSepActionsColW,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  tooltip: _editing ? 'Guardar' : 'Editar',
                                  onPressed: _editing
                                      ? saveFromKeyboard
                                      : () => _enterEditingFromPointer(0),
                                  icon: Icon(
                                    _editing
                                        ? Icons.save_rounded
                                        : Icons.more_horiz_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

class _SeparationDraft {
  static const Object _unset = Object();
  final DateTime? opDate;
  final String? shift;
  final String? sourceMode;
  final String? commercialMaterialCode;
  final double? weightKg;
  final String notes;

  const _SeparationDraft({
    required this.opDate,
    required this.shift,
    required this.sourceMode,
    required this.commercialMaterialCode,
    required this.weightKg,
    required this.notes,
  });

  _SeparationDraft copyWith({
    Object? opDate = _unset,
    Object? shift = _unset,
    Object? sourceMode = _unset,
    Object? commercialMaterialCode = _unset,
    Object? weightKg = _unset,
    String? notes,
  }) {
    return _SeparationDraft(
      opDate: identical(opDate, _unset) ? this.opDate : opDate as DateTime?,
      shift: identical(shift, _unset) ? this.shift : shift as String?,
      sourceMode: identical(sourceMode, _unset)
          ? this.sourceMode
          : sourceMode as String?,
      commercialMaterialCode: identical(commercialMaterialCode, _unset)
          ? this.commercialMaterialCode
          : commercialMaterialCode as String?,
      weightKg: identical(weightKg, _unset)
          ? this.weightKg
          : weightKg as double?,
      notes: notes ?? this.notes,
    );
  }
}

class _SeparationCommercialOption {
  final String code;
  final String name;

  const _SeparationCommercialOption({required this.code, required this.name});
}

String _separationSourceModeLabel(String? mode) {
  switch ((mode ?? '').toUpperCase()) {
    case 'MIXED':
      return 'Compra revuelta';
    case 'DIRECT':
      return 'Compra clasificada';
    default:
      return mode ?? '—';
  }
}

({Color bg, Color fg}) _separationSourceModeColors(String? mode) {
  switch ((mode ?? '').toUpperCase()) {
    case 'MIXED':
      return (bg: const Color(0xFFF5E5D5), fg: const Color(0xFF7A4A21));
    case 'DIRECT':
      return (bg: const Color(0xFFD8EEF6), fg: const Color(0xFF22536B));
    default:
      return (bg: const Color(0xFFE2E8F2), fg: const Color(0xFF31475F));
  }
}

String _sepFmtUiDate(DateTime d) {
  final yy = (d.year % 100).toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$dd/$mm/$yy';
}

String _sepFmtDbDate(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

DateTime _sepParseDate(dynamic v) {
  if (v is String && v.length >= 10) {
    final y = int.tryParse(v.substring(0, 4));
    final m = int.tryParse(v.substring(5, 7));
    final d = int.tryParse(v.substring(8, 10));
    if (y != null && m != null && d != null) return DateTime(y, m, d);
  }
  return DateUtils.dateOnly(DateTime.now());
}
*/
