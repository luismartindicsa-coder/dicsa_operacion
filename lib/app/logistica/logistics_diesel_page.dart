import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../services/services_shell.dart';
import '../services/services_visual_mode.dart';
import '../shared/archetypes/auxiliary_surfaces/searchable_picker.dart'
    as shared_picker;
import '../shared/archetypes/grid_editable/filters/grid_filter_dialog.dart';
import '../shared/archetypes/grid_editable/filters/grid_filter_state.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/confirm_dialog_key_handler.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_tokens.dart';
import '../shared/ui_contract_core/theme/editable_hover_capsule.dart';
import '../shared/utils/csv_file_save.dart';
import 'logistics_area_chrome.dart';
import 'logistics_catalog_page.dart';
import 'logistics_control_daily_page.dart';
import 'logistics_dashboard_page.dart';
import 'logistics_diesel_store.dart';
import 'logistics_theme.dart';

const double _kDieselDateColW = 108;
const double _kDieselOperatorColW = 228;
const double _kDieselVehicleColW = 170;
const double _kDieselPurchasedColW = 150;
const double _kDieselRequestedColW = 150;
const double _kDieselBalanceColW = 142;
const double _kDieselActionsGapW = 10;
const double _kDieselActionsW = 114;
const Color _kDieselFocusBlue = Color(0xFF0B72FF);
const Color _kDieselFocusBlueSoft = Color(0xFFD9E8FF);
const double _kDieselTableContentW =
    _kDieselDateColW +
    _kDieselOperatorColW +
    _kDieselVehicleColW +
    _kDieselPurchasedColW +
    _kDieselRequestedColW +
    _kDieselBalanceColW +
    _kDieselActionsGapW +
    _kDieselActionsW;

class _DieselGridLayout {
  final double dateWidth;
  final double operatorWidth;
  final double vehicleWidth;
  final double purchasedWidth;
  final double requestedWidth;
  final double balanceWidth;
  final double actionsGapWidth;
  final double actionsWidth;
  final double scale;

  const _DieselGridLayout({
    required this.dateWidth,
    required this.operatorWidth,
    required this.vehicleWidth,
    required this.purchasedWidth,
    required this.requestedWidth,
    required this.balanceWidth,
    required this.actionsGapWidth,
    required this.actionsWidth,
    required this.scale,
  });

  double get contentWidth =>
      dateWidth +
      operatorWidth +
      vehicleWidth +
      purchasedWidth +
      requestedWidth +
      balanceWidth +
      actionsGapWidth +
      actionsWidth;
}

_DieselGridLayout _resolveDieselGridLayout(double availableWidth) {
  if (!availableWidth.isFinite || availableWidth <= 0) {
    return const _DieselGridLayout(
      dateWidth: _kDieselDateColW,
      operatorWidth: _kDieselOperatorColW,
      vehicleWidth: _kDieselVehicleColW,
      purchasedWidth: _kDieselPurchasedColW,
      requestedWidth: _kDieselRequestedColW,
      balanceWidth: _kDieselBalanceColW,
      actionsGapWidth: _kDieselActionsGapW,
      actionsWidth: _kDieselActionsW,
      scale: 1,
    );
  }

  final scale = math.min(1.0, availableWidth / _kDieselTableContentW);
  final scaledDate = _kDieselDateColW * scale;
  final scaledOperator = _kDieselOperatorColW * scale;
  final scaledVehicle = _kDieselVehicleColW * scale;
  final scaledPurchased = _kDieselPurchasedColW * scale;
  final scaledRequested = _kDieselRequestedColW * scale;
  final scaledBalance = _kDieselBalanceColW * scale;
  final scaledActionsGap = _kDieselActionsGapW * scale;
  final scaledActions = _kDieselActionsW * scale;

  if (scale < 1) {
    return _DieselGridLayout(
      dateWidth: scaledDate,
      operatorWidth: scaledOperator,
      vehicleWidth: scaledVehicle,
      purchasedWidth: scaledPurchased,
      requestedWidth: scaledRequested,
      balanceWidth: scaledBalance,
      actionsGapWidth: scaledActionsGap,
      actionsWidth: scaledActions,
      scale: scale,
    );
  }

  final extraWidth = availableWidth - _kDieselTableContentW;
  const dateWeight = 0.45;
  const operatorWeight = 2.1;
  const vehicleWeight = 1.6;
  const purchasedWeight = 1.0;
  const requestedWeight = 1.0;
  const balanceWeight = 0.85;
  const totalWeight =
      dateWeight +
      operatorWeight +
      vehicleWeight +
      purchasedWeight +
      requestedWeight +
      balanceWeight;

  double share(double weight) => extraWidth * (weight / totalWeight);

  return _DieselGridLayout(
    dateWidth: scaledDate + share(dateWeight),
    operatorWidth: scaledOperator + share(operatorWeight),
    vehicleWidth: scaledVehicle + share(vehicleWeight),
    purchasedWidth: scaledPurchased + share(purchasedWeight),
    requestedWidth: scaledRequested + share(requestedWeight),
    balanceWidth: scaledBalance + share(balanceWeight),
    actionsGapWidth: scaledActionsGap,
    actionsWidth: scaledActions,
    scale: scale,
  );
}

class LogisticsDieselPage extends StatefulWidget {
  const LogisticsDieselPage({super.key});

  @override
  State<LogisticsDieselPage> createState() => _LogisticsDieselPageState();
}

class _LogisticsDieselPageState extends State<LogisticsDieselPage> {
  final TextEditingController _purchasedController = TextEditingController();
  final TextEditingController _requestedController = TextEditingController();
  final FocusNode _insertFocusNode = FocusNode(debugLabel: 'diesel_insert');
  final FocusNode _rowsFocusNode = FocusNode(debugLabel: 'diesel_rows');
  final FocusNode _purchasedFocusNode = FocusNode(
    debugLabel: 'diesel_purchased',
  );
  final FocusNode _requestedFocusNode = FocusNode(
    debugLabel: 'diesel_requested',
  );
  final ScrollController _rowsScrollController = ScrollController();
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};

  bool _canReturnToDirection = false;
  bool _loading = true;
  bool _saving = false;
  bool _exportingCsv = false;
  bool _bulkDeleting = false;
  String? _loadError;

  List<LogisticsDieselConsumptionRecord> _entries =
      <LogisticsDieselConsumptionRecord>[];
  List<_DieselOption> _operators = <_DieselOption>[];
  List<_DieselOption> _vehicles = <_DieselOption>[];

  final Set<String> _selectedIds = <String>{};
  final Map<String, Set<String>> _columnValueFilters = <String, Set<String>>{};
  final Map<String, DateTimeRange> _columnDateRangeFilters =
      <String, DateTimeRange>{};

  LogisticsDieselConsumptionRecord? _editingRecord;
  String? _primarySelectedId;
  DateTime _draftDate = DateUtils.dateOnly(DateTime.now());
  String? _draftOperatorId;
  String? _draftVehicleId;
  int _activeInsertColumn = 0;

  int _currentPage = 0;
  int _pageSize = 40;

  @override
  void initState() {
    super.initState();
    _purchasedFocusNode.addListener(_handleInlineFieldFocusChange);
    _requestedFocusNode.addListener(_handleInlineFieldFocusChange);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _purchasedFocusNode.removeListener(_handleInlineFieldFocusChange);
    _requestedFocusNode.removeListener(_handleInlineFieldFocusChange);
    _purchasedController.dispose();
    _requestedController.dispose();
    _insertFocusNode.dispose();
    _rowsFocusNode.dispose();
    _purchasedFocusNode.dispose();
    _requestedFocusNode.dispose();
    _rowsScrollController.dispose();
    super.dispose();
  }

  void _handleInlineFieldFocusChange() {
    if (!mounted) return;
    if (_purchasedFocusNode.hasFocus) {
      setState(() => _activeInsertColumn = 3);
      return;
    }
    if (_requestedFocusNode.hasFocus) {
      setState(() => _activeInsertColumn = 4);
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      await Future.wait<void>([
        _resolveNavigationAccess(),
        _loadCatalogs(),
        _loadEntries(),
      ]);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'No se pudo abrir Consumo de Diesel: $error';
      });
    }
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
    });
  }

  Future<void> _loadCatalogs() async {
    final results = await Future.wait<dynamic>([
      _loadOperators(),
      _loadVehicles(),
    ]);
    if (!mounted) return;
    setState(() {
      _operators = results[0] as List<_DieselOption>;
      _vehicles = results[1] as List<_DieselOption>;
    });
  }

  Future<void> _loadEntries() async {
    final rows = await LogisticsDieselConsumptionStore.loadEntries();
    if (!mounted) return;
    setState(() {
      _entries = rows;
      _loadError = null;
      _syncSelectionAndPagination();
    });
  }

  Future<List<_DieselOption>> _loadOperators() async {
    final rows = await Supabase.instance.client
        .from('employees')
        .select('id,full_name')
        .eq('is_driver', true)
        .eq('is_active', true)
        .order('full_name');
    return (rows as List)
        .map(
          (raw) => _DieselOption(
            id: (raw['id'] ?? '').toString(),
            label: (raw['full_name'] ?? '').toString().trim(),
          ),
        )
        .where((row) => row.id.isNotEmpty && row.label.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<_DieselOption>> _loadVehicles() async {
    final rows = await Supabase.instance.client
        .from('vehicles')
        .select('id,code,status')
        .eq('status', 'activo')
        .order('code');
    return (rows as List)
        .map(
          (raw) => _DieselOption(
            id: (raw['id'] ?? '').toString(),
            label: (raw['code'] ?? '').toString().trim(),
          ),
        )
        .where((row) => row.id.isNotEmpty && row.label.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _openLogisticsDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const LogisticsDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _openControlDaily() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const LogisticsControlDailyPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _openCatalogs() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const LogisticsCatalogPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const GeneralDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  void _showPhaseSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case kLogisticsNavDashboardLabel:
        unawaited(_openLogisticsDashboard());
        return;
      case kLogisticsNavControlDailyLabel:
        unawaited(_openControlDaily());
        return;
      case kLogisticsNavCatalogsLabel:
        unawaited(_openCatalogs());
        return;
      case kLogisticsNavDieselLabel:
        return;
      case kLogisticsNavFleetStatusLabel:
        _showPhaseSnack(
          'Estado de Unidades se abrirá en la siguiente fase del área.',
        );
        return;
      case kLogisticsNavIncidentsLabel:
        _showPhaseSnack(
          'Incidencias se habilitará cuando quede validado el flujo base.',
        );
        return;
      case kLogisticsNavSavingsLabel:
        _showPhaseSnack(
          'Ahorro y Planeación seguirá después de consolidar diesel, zonas y programación.',
        );
        return;
      case kLogisticsNavDirectionDashboardLabel:
        unawaited(_openDirectionDashboard());
        return;
    }
  }

  double get _draftPurchased => _tryParseDouble(_purchasedController.text) ?? 0;
  double get _draftRequested => _tryParseDouble(_requestedController.text) ?? 0;
  double get _draftBalance => _draftPurchased - _draftRequested;

  double get _totalPurchased =>
      _entries.fold(0.0, (sum, row) => sum + row.litersPurchased);

  double get _totalRequested =>
      _entries.fold(0.0, (sum, row) => sum + row.litersRequested);

  double get _totalBalance =>
      _entries.fold(0.0, (sum, row) => sum + row.balanceLiters);

  ContractAreaTokens get _dieselFocusTokens => const ContractAreaTokens(
    primary: _kDieselFocusBlue,
    primaryStrong: _kDieselFocusBlue,
    primarySoft: _kDieselFocusBlueSoft,
    accent: _kDieselFocusBlueSoft,
    surfaceTint: kLogisticsSilverSurfaceMiddle,
    border: kLogisticsSilverBorder,
    badgeBackground: _kDieselFocusBlueSoft,
    badgeText: _kDieselFocusBlue,
    glow: _kDieselFocusBlue,
    glassSurface: Color(0xF7F4F5F7),
    fieldSurface: Color(0xFFF4F5F7),
    onGlass: kLogisticsSilverTextPrimary,
  );

  _DieselTankStatus get _tankStatus {
    final balance = _totalBalance;
    if (balance > 600) {
      return const _DieselTankStatus(
        label: 'Suficiente',
        helper: 'Arriba de 600 L disponibles',
        icon: Icons.check_circle_rounded,
        topColor: Color(0xFFE4F3E6),
        bottomColor: Color(0xFFCBE8CF),
        borderColor: Color(0xFF98C99F),
        textColor: Color(0xFF1F6A33),
      );
    }
    if (balance >= 300) {
      return const _DieselTankStatus(
        label: 'Solicitar',
        helper: 'Entre 300 L y 600 L',
        icon: Icons.warning_amber_rounded,
        topColor: Color(0xFFF8F0D8),
        bottomColor: Color(0xFFF0E0A6),
        borderColor: Color(0xFFD8C06B),
        textColor: Color(0xFF886100),
      );
    }
    return const _DieselTankStatus(
      label: 'Crítico',
      helper: 'Abajo de 300 L',
      icon: Icons.error_rounded,
      topColor: Color(0xFFF6DFDD),
      bottomColor: Color(0xFFEAC0BC),
      borderColor: Color(0xFFD39892),
      textColor: Color(0xFF8C2922),
    );
  }

  List<LogisticsDieselConsumptionRecord> get _filteredEntries {
    Iterable<LogisticsDieselConsumptionRecord> rows = _entries;
    final dateRange = _columnDateRangeFilters['fecha'];
    if (dateRange != null) {
      final start = DateUtils.dateOnly(dateRange.start);
      final end = DateUtils.dateOnly(dateRange.end);
      rows = rows.where((row) {
        final day = DateUtils.dateOnly(row.entryDate);
        return !day.isBefore(start) && !day.isAfter(end);
      });
    }
    for (final entry in _columnValueFilters.entries) {
      final selected = entry.value;
      if (selected.isEmpty) continue;
      rows = rows.where(
        (row) => selected.contains(_columnFilterValue(row, entry.key)),
      );
    }
    return rows.toList(growable: false);
  }

  List<LogisticsDieselConsumptionRecord> get _visibleEntries {
    final filtered = _filteredEntries;
    if (filtered.isEmpty) return const <LogisticsDieselConsumptionRecord>[];
    final start = _currentPage * _pageSize;
    if (start >= filtered.length) {
      return const <LogisticsDieselConsumptionRecord>[];
    }
    final end = math.min(start + _pageSize, filtered.length);
    return filtered.sublist(start, end);
  }

  int get _totalPages {
    final total = _filteredEntries.length;
    if (total <= 0) return 1;
    return ((total - 1) ~/ _pageSize) + 1;
  }

  int get _selectedCount => _selectedIds.length;

  List<LogisticsDieselConsumptionRecord> get _selectedEntries {
    return _entries
        .where((row) => row.id != null && _selectedIds.contains(row.id))
        .toList(growable: false);
  }

  double get _selectedPurchasedSum =>
      _selectedEntries.fold(0.0, (sum, row) => sum + row.litersPurchased);

  double get _selectedRequestedSum =>
      _selectedEntries.fold(0.0, (sum, row) => sum + row.litersRequested);

  double get _selectedBalanceSum =>
      _selectedEntries.fold(0.0, (sum, row) => sum + row.balanceLiters);

  LogisticsDieselConsumptionRecord? _findEntryById(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    for (final row in _entries) {
      if (row.id == id) return row;
    }
    return null;
  }

  bool get _isPurchasedCaretAtStart {
    final selection = _purchasedController.selection;
    return _purchasedFocusNode.hasFocus &&
        selection.isValid &&
        selection.isCollapsed &&
        selection.baseOffset == 0 &&
        selection.extentOffset == 0;
  }

  bool get _isPurchasedCaretAtEnd {
    final selection = _purchasedController.selection;
    final end = _purchasedController.text.length;
    return _purchasedFocusNode.hasFocus &&
        selection.isValid &&
        selection.isCollapsed &&
        selection.baseOffset == end &&
        selection.extentOffset == end;
  }

  bool get _isRequestedCaretAtStart {
    final selection = _requestedController.selection;
    return _requestedFocusNode.hasFocus &&
        selection.isValid &&
        selection.isCollapsed &&
        selection.baseOffset == 0 &&
        selection.extentOffset == 0;
  }

  bool get _isRequestedCaretAtEnd {
    final selection = _requestedController.selection;
    final end = _requestedController.text.length;
    return _requestedFocusNode.hasFocus &&
        selection.isValid &&
        selection.isCollapsed &&
        selection.baseOffset == end &&
        selection.extentOffset == end;
  }

  GlobalKey _rowKeyFor(String id) {
    return _rowKeys.putIfAbsent(id, GlobalKey.new);
  }

  void _syncSelectionAndPagination() {
    final visibleIds = _filteredEntries
        .map((row) => row.id)
        .whereType<String>()
        .toSet();
    _selectedIds.removeWhere((id) => !visibleIds.contains(id));
    if (_primarySelectedId != null &&
        !visibleIds.contains(_primarySelectedId)) {
      _primarySelectedId = _selectedIds.isEmpty ? null : _selectedIds.first;
    }
    _clampCurrentPage();
  }

  void _clampCurrentPage() {
    final maxPage = math.max(0, _totalPages - 1);
    if (_currentPage > maxPage) _currentPage = maxPage;
    if (_currentPage < 0) _currentPage = 0;
  }

  String? _labelOf(List<_DieselOption> options, String? id) {
    if (id == null || id.trim().isEmpty) return null;
    for (final option in options) {
      if (option.id == id) return option.label;
    }
    return null;
  }

  Future<void> _pickDraftDate() async {
    final palette = ServicesVisualPalette.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _draftDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: palette.filterAccent,
            onPrimary: palette.buttonFillForeground,
            surface: palette.surfaceElevated,
            onSurface: palette.textPrimary,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: palette.surfaceBase,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: palette.borderStrong),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (!mounted || picked == null) return;
    setState(() => _draftDate = DateUtils.dateOnly(picked));
  }

  Future<void> _pickDraftOperator() async {
    if (_operators.isEmpty) {
      _showPhaseSnack('Todavía no hay operadores disponibles.');
      return;
    }
    final selected = await _showSearchablePickerDialog<String>(
      context,
      title: 'Operador',
      initialValue: _draftOperatorId,
      options: _operators
          .map((row) => _PickerOption<String>(value: row.id, label: row.label))
          .toList(growable: false),
    );
    if (!mounted || selected == null) return;
    setState(() => _draftOperatorId = selected);
  }

  Future<void> _pickDraftVehicle() async {
    if (_vehicles.isEmpty) {
      _showPhaseSnack('Todavía no hay unidades activas disponibles.');
      return;
    }
    final selected = await _showSearchablePickerDialog<String>(
      context,
      title: 'Unidad o Vehículo',
      initialValue: _draftVehicleId,
      options: _vehicles
          .map((row) => _PickerOption<String>(value: row.id, label: row.label))
          .toList(growable: false),
    );
    if (!mounted || selected == null) return;
    setState(() => _draftVehicleId = selected);
  }

  void _startEditing(LogisticsDieselConsumptionRecord record) {
    setState(() {
      _editingRecord = record;
      _draftDate = DateUtils.dateOnly(record.entryDate);
      _draftOperatorId = record.operatorEmployeeId;
      _draftVehicleId = record.vehicleId;
      _activeInsertColumn = 0;
      _purchasedController.text = _formatLitersInput(record.litersPurchased);
      _requestedController.text = _formatLitersInput(record.litersRequested);
      if (record.id != null) {
        _selectedIds
          ..clear()
          ..add(record.id!);
        _primarySelectedId = record.id;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _insertFocusNode.requestFocus();
    });
  }

  void _resetDraft() {
    setState(() {
      _editingRecord = null;
      _draftDate = DateUtils.dateOnly(DateTime.now());
      _draftOperatorId = null;
      _draftVehicleId = null;
      _activeInsertColumn = 0;
      _purchasedController.clear();
      _requestedController.clear();
    });
  }

  Future<void> _saveDraft() async {
    final operatorId = _draftOperatorId;
    final vehicleId = _draftVehicleId;
    final operatorName = _labelOf(_operators, operatorId) ?? '';
    final vehicleLabel = _labelOf(_vehicles, vehicleId) ?? '';
    final purchased = _tryParseDouble(_purchasedController.text);
    final requested = _tryParseDouble(_requestedController.text);

    final missing = <String>[];
    if (operatorId == null || operatorName.isEmpty) missing.add('Operador');
    if (vehicleId == null || vehicleLabel.isEmpty) {
      missing.add('Unidad o Vehículo');
    }
    if (purchased == null) missing.add('Litros Comprados');
    if (requested == null) missing.add('Litros Solicitados');

    if (missing.isNotEmpty) {
      _showPhaseSnack('Completa primero: ${missing.join(', ')}.');
      return;
    }

    final purchasedValue = purchased!;
    final requestedValue = requested!;
    if (purchasedValue < 0 || requestedValue < 0) {
      _showPhaseSnack('Los litros no pueden ser negativos.');
      return;
    }

    setState(() => _saving = true);
    try {
      final record = LogisticsDieselConsumptionRecord(
        id: _editingRecord?.id,
        entryDate: _draftDate,
        operatorEmployeeId: operatorId,
        operatorName: operatorName,
        vehicleId: vehicleId,
        vehicleLabel: vehicleLabel,
        litersPurchased: purchasedValue,
        litersRequested: requestedValue,
        balanceLiters: purchasedValue - requestedValue,
        createdAt: _editingRecord?.createdAt,
        updatedAt: _editingRecord?.updatedAt,
      );
      final saved = await LogisticsDieselConsumptionStore.saveEntry(record);
      await _loadEntries();
      if (!mounted) return;
      setState(() {
        if (saved.id != null) {
          _selectedIds
            ..clear()
            ..add(saved.id!);
          _primarySelectedId = saved.id;
        }
      });
      _showPhaseSnack(
        _editingRecord == null
            ? 'Registro de diesel guardado.'
            : 'Registro de diesel actualizado.',
      );
      _resetDraft();
      _insertFocusNode.requestFocus();
    } catch (error) {
      if (!mounted) return;
      _showPhaseSnack('No se pudo guardar el registro: $error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteEntry(LogisticsDieselConsumptionRecord record) async {
    if (record.id == null) return;
    final ok = await _showGlassConfirmDialog(
      context,
      title: 'Eliminar registro',
      content:
          'Se eliminará el registro de ${record.operatorName} del ${_fmtUiDate(record.entryDate)}.',
      confirmText: 'Eliminar',
    );
    if (!mounted || ok != true) return;

    try {
      await LogisticsDieselConsumptionStore.deleteEntry(record.id!);
      await _loadEntries();
      if (!mounted) return;
      setState(() {
        _selectedIds.remove(record.id);
        if (_primarySelectedId == record.id) {
          _primarySelectedId = _selectedIds.isEmpty ? null : _selectedIds.last;
        }
      });
      if (_editingRecord?.id == record.id) {
        _resetDraft();
      }
      _showPhaseSnack('Registro eliminado.');
    } catch (error) {
      if (!mounted) return;
      _showPhaseSnack('No se pudo eliminar el registro: $error');
    }
  }

  Future<void> _deleteSelectedRows() async {
    final ids = _selectedIds.toList(growable: false);
    if (ids.isEmpty) {
      _showPhaseSnack('Selecciona al menos un registro.');
      return;
    }
    final ok = await _showGlassConfirmDialog(
      context,
      title: 'Eliminar registros',
      content:
          '¿Seguro que deseas eliminar ${_fmtCountInt(ids.length)} registro(s) de diesel?',
      confirmText: 'Eliminar',
    );
    if (!mounted || ok != true) return;

    setState(() => _bulkDeleting = true);
    try {
      await Future.wait<void>(
        ids.map((id) => LogisticsDieselConsumptionStore.deleteEntry(id)),
      );
      await _loadEntries();
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _primarySelectedId = null;
      });
      if (_editingRecord != null && ids.contains(_editingRecord!.id)) {
        _resetDraft();
      }
      _showPhaseSnack('Registros eliminados.');
    } catch (error) {
      if (!mounted) return;
      _showPhaseSnack('No se pudieron eliminar los registros: $error');
    } finally {
      if (mounted) {
        setState(() => _bulkDeleting = false);
      }
    }
  }

  bool _hasActiveFilter(String columnId) {
    final values = _columnValueFilters[columnId];
    if (values != null && values.isNotEmpty) return true;
    return _columnDateRangeFilters.containsKey(columnId);
  }

  Future<void> _openColumnFilter(String columnId, String label) async {
    if (columnId == 'fecha') {
      final bounds = _dateBoundsForFilters();
      final result = await _showDateRangeFilterDialog(
        context,
        label: label,
        bounds: bounds,
        initialRange: _columnDateRangeFilters[columnId],
      );
      if (!mounted || result == null) return;
      setState(() {
        if (result.clear) {
          _columnDateRangeFilters.remove(columnId);
        } else if (result.range != null) {
          _columnDateRangeFilters[columnId] = result.range!;
        }
        _syncSelectionAndPagination();
      });
      return;
    }

    final options = _buildValueFilterOptions(columnId);
    if (options.isEmpty) {
      _showPhaseSnack('No hay valores disponibles para filtrar $label.');
      return;
    }
    final result = await showDialog<GridFilterState>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (_) => GridFilterDialog(
        title: 'Filtro: $label',
        initialState: GridFilterState(options: options),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      final selected = result.selectedValues;
      if (selected.isEmpty) {
        _columnValueFilters.remove(columnId);
      } else {
        _columnValueFilters[columnId] = selected;
      }
      _syncSelectionAndPagination();
    });
  }

  DateTimeRange _dateBoundsForFilters() {
    if (_entries.isEmpty) {
      final today = DateUtils.dateOnly(DateTime.now());
      return DateTimeRange(
        start: today.subtract(const Duration(days: 365)),
        end: today.add(const Duration(days: 365)),
      );
    }
    DateTime min = DateUtils.dateOnly(_entries.first.entryDate);
    DateTime max = min;
    for (final row in _entries.skip(1)) {
      final day = DateUtils.dateOnly(row.entryDate);
      if (day.isBefore(min)) min = day;
      if (day.isAfter(max)) max = day;
    }
    return DateTimeRange(start: min, end: max);
  }

  List<GridFilterOption> _buildValueFilterOptions(String columnId) {
    final selected = _columnValueFilters[columnId] ?? const <String>{};
    final labels = <String, String>{};
    for (final row in _entries) {
      final value = _columnFilterValue(row, columnId);
      final label = _columnFilterLabel(row, columnId);
      if (value.isEmpty || label.isEmpty) continue;
      labels[value] = label;
    }
    final entries = labels.entries.toList(growable: false);
    entries.sort((a, b) {
      if (_isNumericFilterColumn(columnId)) {
        final aValue = double.tryParse(a.key) ?? double.negativeInfinity;
        final bValue = double.tryParse(b.key) ?? double.negativeInfinity;
        return aValue.compareTo(bValue);
      }
      return a.value.compareTo(b.value);
    });
    return entries
        .map(
          (entry) => GridFilterOption(
            value: entry.key,
            label: entry.value,
            selected: selected.contains(entry.key),
          ),
        )
        .toList(growable: false);
  }

  bool _isNumericFilterColumn(String columnId) {
    return columnId == 'comprados' ||
        columnId == 'solicitados' ||
        columnId == 'saldo';
  }

  String _columnFilterValue(
    LogisticsDieselConsumptionRecord row,
    String columnId,
  ) {
    switch (columnId) {
      case 'fecha':
        return _fmtUiDate(row.entryDate);
      case 'operador':
        return row.operatorName.trim();
      case 'unidad':
        return row.vehicleLabel.trim();
      case 'comprados':
        return _fmtLiters(row.litersPurchased);
      case 'solicitados':
        return _fmtLiters(row.litersRequested);
      case 'saldo':
        return _fmtLiters(row.balanceLiters);
      default:
        return '';
    }
  }

  String _columnFilterLabel(
    LogisticsDieselConsumptionRecord row,
    String columnId,
  ) {
    final value = _columnFilterValue(row, columnId);
    if (_isNumericFilterColumn(columnId) && value.isNotEmpty) {
      return '$value L';
    }
    return value;
  }

  bool _isAdditiveSelectionPressed() {
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
    return _isAdditiveSelectionPressed() || _isShiftPressed();
  }

  bool _isEditableTextFocused() {
    final primary = FocusManager.instance.primaryFocus;
    final context = primary?.context;
    if (context == null) return false;
    if (context.widget is EditableText) return true;
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _setActiveInsertColumn(int column, {bool requestFocus = true}) {
    setState(() => _activeInsertColumn = column);
    if (requestFocus) {
      _insertFocusNode.requestFocus();
    }
  }

  void _moveInsertColumn(int delta) {
    setState(() {
      final raw = _activeInsertColumn + delta;
      _activeInsertColumn = ((raw % 7) + 7) % 7;
    });
  }

  void _focusPurchasedField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _purchasedFocusNode.requestFocus();
      _purchasedController.selection = TextSelection.collapsed(
        offset: _purchasedController.text.length,
      );
    });
  }

  void _focusRequestedField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestedFocusNode.requestFocus();
      _requestedController.selection = TextSelection.collapsed(
        offset: _requestedController.text.length,
      );
    });
  }

  void _focusInsertRowFromGrid() {
    _insertFocusNode.requestFocus();
  }

  void _focusGridFromInsert() {
    if (_visibleEntries.isNotEmpty && _primarySelectedId == null) {
      final firstId = _visibleEntries.first.id;
      if (firstId != null) {
        _selectRow(firstId, allowToggle: false, ensureVisible: true);
      }
    }
    _rowsFocusNode.requestFocus();
  }

  void _ensureRowVisible(String id) {
    final context = _rowKeyFor(id).currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  void _selectRow(
    String id, {
    bool allowToggle = true,
    bool additive = false,
    bool additiveToggle = true,
    bool focusTable = false,
    bool ensureVisible = false,
  }) {
    if (additive) {
      setState(() {
        if (_selectedIds.contains(id) && additiveToggle) {
          _selectedIds.remove(id);
          if (_primarySelectedId == id) {
            _primarySelectedId = _selectedIds.isEmpty
                ? null
                : _selectedIds.last;
          }
        } else {
          _selectedIds.add(id);
          _primarySelectedId = id;
        }
      });
      if (focusTable) _rowsFocusNode.requestFocus();
      if (ensureVisible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _ensureRowVisible(id);
        });
      }
      return;
    }

    if (allowToggle && _primarySelectedId == id && _selectedIds.length == 1) {
      setState(() {
        _selectedIds.clear();
        _primarySelectedId = null;
      });
      if (focusTable) _rowsFocusNode.requestFocus();
      return;
    }

    setState(() {
      _selectedIds
        ..clear()
        ..add(id);
      _primarySelectedId = id;
    });
    if (focusTable) _rowsFocusNode.requestFocus();
    if (ensureVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureRowVisible(id);
      });
    }
  }

  void _moveSelectedRow(int delta) {
    final rows = _visibleEntries;
    if (rows.isEmpty) return;

    final currentIndex = _primarySelectedId == null
        ? -1
        : rows.indexWhere((row) => row.id == _primarySelectedId);
    int nextIndex;
    if (currentIndex == -1) {
      nextIndex = delta >= 0 ? 0 : rows.length - 1;
    } else {
      final rawIndex = currentIndex + delta;
      nextIndex = ((rawIndex % rows.length) + rows.length) % rows.length;
    }
    final id = rows[nextIndex].id;
    if (id == null) return;
    _selectRow(id, allowToggle: false, focusTable: false, ensureVisible: true);
  }

  void _extendSelectionWithArrow(int delta) {
    final rows = _visibleEntries;
    if (rows.isEmpty) return;
    final currentIndex = _primarySelectedId == null
        ? -1
        : rows.indexWhere((row) => row.id == _primarySelectedId);
    if (currentIndex != -1) {
      final currentId = rows[currentIndex].id;
      if (currentId != null) {
        _selectedIds.add(currentId);
      }
    }
    int nextIndex;
    if (currentIndex == -1) {
      nextIndex = delta >= 0 ? 0 : rows.length - 1;
    } else {
      final rawIndex = currentIndex + delta;
      nextIndex = ((rawIndex % rows.length) + rows.length) % rows.length;
    }
    final nextId = rows[nextIndex].id;
    if (nextId == null) return;
    _selectRow(
      nextId,
      allowToggle: false,
      additive: true,
      additiveToggle: false,
      focusTable: false,
      ensureVisible: true,
    );
  }

  Future<void> _activateInsertCellFromKeyboard() async {
    switch (_activeInsertColumn) {
      case 0:
        await _pickDraftDate();
        return;
      case 1:
        await _pickDraftOperator();
        return;
      case 2:
        await _pickDraftVehicle();
        return;
      case 3:
        _focusPurchasedField();
        return;
      case 4:
        _focusRequestedField();
        return;
      case 6:
        await _saveDraft();
        return;
      default:
        return;
    }
  }

  void _clearActiveInsertCell() {
    setState(() {
      switch (_activeInsertColumn) {
        case 0:
          _draftDate = DateUtils.dateOnly(DateTime.now());
          break;
        case 1:
          _draftOperatorId = null;
          break;
        case 2:
          _draftVehicleId = null;
          break;
        case 3:
          _purchasedController.clear();
          break;
        case 4:
          _requestedController.clear();
          break;
        default:
          break;
      }
    });
  }

  Future<void> _handleEnterOnSelectedRow() async {
    if (_primarySelectedId == null) {
      _focusGridFromInsert();
      return;
    }
    final selected = _findEntryById(_primarySelectedId);
    if (selected == null) return;
    _startEditing(selected);
  }

  void _handleEscapeOnSelectedRow() {
    if (_editingRecord?.id != null &&
        _selectedIds.contains(_editingRecord!.id)) {
      _resetDraft();
      _rowsFocusNode.requestFocus();
      return;
    }
    setState(() {
      _selectedIds.clear();
      _primarySelectedId = null;
    });
  }

  void _handleDeleteOnSelectedRow() {
    if (_selectedIds.length > 1) {
      unawaited(_deleteSelectedRows());
      return;
    }
    final selected = _findEntryById(_primarySelectedId);
    if (selected == null) return;
    unawaited(_deleteEntry(selected));
  }

  void _handleRowTap(LogisticsDieselConsumptionRecord record) {
    final id = record.id;
    if (id == null) return;
    _selectRow(id, additive: _isAdditiveSelectionPressed(), focusTable: true);
  }

  List<MapEntry<String, String>> _rowContextActions() {
    final editingCurrent =
        _editingRecord?.id != null && _editingRecord!.id == _primarySelectedId;
    if (_selectedIds.length > 1) {
      return const <MapEntry<String, String>>[
        MapEntry<String, String>('delete', 'ELIMINAR SELECCIÓN'),
      ];
    }
    return <MapEntry<String, String>>[
      MapEntry<String, String>(
        editingCurrent ? 'cancel' : 'edit',
        editingCurrent ? 'CANCELAR EDICIÓN' : 'EDITAR',
      ),
      const MapEntry<String, String>('delete', 'ELIMINAR'),
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
      color: const Color(0xE6EAF2F9),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
      ),
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
    if (rowId != null && !_selectedIds.contains(rowId)) {
      _selectRow(rowId, allowToggle: false, additive: false, focusTable: true);
    }
    final choice = await _showRowsContextMenu(globalPosition);
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'edit':
        await _handleEnterOnSelectedRow();
        return;
      case 'cancel':
        _resetDraft();
        _rowsFocusNode.requestFocus();
        return;
      case 'delete':
        _handleDeleteOnSelectedRow();
        return;
      default:
        return;
    }
  }

  Future<void> _exportCsv() async {
    final rows = _filteredEntries;
    if (rows.isEmpty) {
      _showPhaseSnack('No hay registros para exportar con el filtro actual.');
      return;
    }
    setState(() => _exportingCsv = true);
    try {
      final content = _buildCsvContent(rows);
      final saved = await saveCsvFile(
        fileName: 'consumo_diesel_${_fmtCompactDate(DateTime.now())}.csv',
        content: content,
        dialogTitle: 'Guardar CSV de consumo de diesel',
      );
      if (!mounted) return;
      if (saved == null) {
        _showPhaseSnack('La exportación se canceló.');
      } else {
        _showPhaseSnack('CSV exportado correctamente.');
      }
    } catch (error) {
      if (!mounted) return;
      _showPhaseSnack('No se pudo exportar el CSV: $error');
    } finally {
      if (mounted) {
        setState(() => _exportingCsv = false);
      }
    }
  }

  String _buildCsvContent(List<LogisticsDieselConsumptionRecord> rows) {
    final buffer = StringBuffer()
      ..writeln(
        'Fecha,Operador,Unidad o Vehiculo,Litros Comprados,Litros Solicitados,Saldo',
      );
    for (final row in rows) {
      buffer.writeln(
        [
          _csvCell(_fmtUiDate(row.entryDate)),
          _csvCell(row.operatorName),
          _csvCell(row.vehicleLabel),
          _csvCell(_fmtLiters(row.litersPurchased)),
          _csvCell(_fmtLiters(row.litersRequested)),
          _csvCell(_fmtLiters(row.balanceLiters)),
        ].join(','),
      );
    }
    return buffer.toString();
  }

  String _csvCell(String raw) {
    final normalized = raw.replaceAll('"', '""');
    return '"$normalized"';
  }

  Widget _buildTopActionsBar() {
    final palette = ServicesVisualPalette.of(context);
    final actions = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          OutlinedButton.icon(
            style: _actionOutlinedButtonStyle(context),
            onPressed: _exportingCsv ? null : _exportCsv,
            icon: Icon(
              _exportingCsv ? Icons.hourglass_top : Icons.download_rounded,
            ),
            label: const Text('Descargar CSV'),
          ),
          if (_editingRecord != null) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: _actionOutlinedButtonStyle(context),
              onPressed: _saving ? null : _resetDraft,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancelar edición'),
            ),
          ],
          if (_selectedCount > 0) ...[
            const SizedBox(width: 8),
            FilledButton.icon(
              style: _actionFilledButtonStyle(context),
              onPressed: _bulkDeleting ? null : _deleteSelectedRows,
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text('Eliminar (${_fmtCountInt(_selectedCount)})'),
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
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        Text(
          _selectedCount > 0
              ? 'Comprados: ${_fmtLiters(_selectedPurchasedSum)} L · Solicitados: ${_fmtLiters(_selectedRequestedSum)} L · Saldo: ${_fmtLiters(_selectedBalanceSum)} L'
              : 'Visibles: ${_fmtCountInt(_filteredEntries.length)} · Comprados: ${_fmtLiters(_totalPurchased)} L · Solicitados: ${_fmtLiters(_totalRequested)} L · Saldo: ${_fmtLiters(_totalBalance)} L',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: palette.textSecondary,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = constraints.maxWidth < 980
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: actions),
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.centerRight, child: info),
                  ],
                )
              : Row(
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
          return Container(
            decoration: BoxDecoration(
              color: palette.surfaceElevated,
              gradient: palette.glassCardGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  blurRadius: 16,
                  color: palette.shadow.withValues(alpha: 0.12),
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: content,
          );
        },
      ),
    );
  }

  Widget _buildSummaryStrip() {
    final status = _tankStatus;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;
          final cards = <Widget>[
            _DieselStatusCard(
              title: 'Saldo actual',
              value: '${_fmtLiters(_totalBalance)} L',
              helper: 'Balance neto entre litros comprados y solicitados',
              icon: Icons.local_gas_station_rounded,
              topColor: const Color(0xFFE7ECF2),
              bottomColor: const Color(0xFFD8E0EA),
              borderColor: const Color(0xFFB7C4D3),
              textColor: kLogisticsSilverTextPrimary,
            ),
            _DieselStatusCard(
              title: 'Estatus del tanque',
              value: status.label,
              helper: status.helper,
              icon: status.icon,
              topColor: status.topColor,
              bottomColor: status.bottomColor,
              borderColor: status.borderColor,
              textColor: status.textColor,
            ),
          ];

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  cards[i],
                  if (i != cards.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTableSurface() {
    final palette = ServicesVisualPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        gradient: palette.glassCardGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.borderStrong),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            color: palette.shadow.withValues(alpha: 0.14),
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            blurRadius: 36,
            color: palette.glow.withValues(alpha: 0.10),
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: constraints.maxHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: _DieselHeaderRow(
                          hasActiveFilter: _hasActiveFilter,
                          onOpenFilter: _openColumnFilter,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        child: _buildInsertRow(),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          child: _buildRowsBody(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
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
                      style: _actionOutlinedButtonStyle(context),
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
                      style: _actionOutlinedButtonStyle(context),
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
                        key: ValueKey<int>(_pageSize),
                        initialValue: _pageSize,
                        isDense: true,
                        decoration: _glassFieldDecoration(context),
                        items: const [40, 80, 120]
                            .map(
                              (size) => DropdownMenuItem<int>(
                                value: size,
                                child: Text('$size'),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _pageSize = value;
                            _currentPage = 0;
                            _syncSelectionAndPagination();
                          });
                        },
                      ),
                    ),
                    Text('Total: ${_fmtCountInt(_filteredEntries.length)}'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsertRow() {
    final palette = ServicesVisualPalette.of(context);
    final editing = _editingRecord != null;
    Widget insertCellFrame(int columnIndex, Widget child) {
      return AreaThemeScope(
        tokens: _dieselFocusTokens,
        child: ContractEditableHoverCapsule(
          active:
              _insertFocusNode.hasFocus && _activeInsertColumn == columnIndex,
          selectedContext: editing,
          borderRadius: BorderRadius.circular(16),
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
        final textEditing = _isEditableTextFocused();
        if (textEditing) {
          if (key == LogicalKeyboardKey.escape) {
            FocusManager.instance.primaryFocus?.unfocus();
            _insertFocusNode.requestFocus();
            if (_editingRecord != null) {
              _resetDraft();
            }
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowLeft &&
              ((_purchasedFocusNode.hasFocus && _isPurchasedCaretAtStart) ||
                  (_requestedFocusNode.hasFocus && _isRequestedCaretAtStart))) {
            FocusManager.instance.primaryFocus?.unfocus();
            _moveInsertColumn(-1);
            _insertFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight &&
              ((_purchasedFocusNode.hasFocus && _isPurchasedCaretAtEnd) ||
                  (_requestedFocusNode.hasFocus && _isRequestedCaretAtEnd))) {
            FocusManager.instance.primaryFocus?.unfocus();
            _moveInsertColumn(1);
            _insertFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter) {
            unawaited(_saveDraft());
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          _moveInsertColumn(-1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
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
          unawaited(_activateInsertCellFromKeyboard());
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.delete ||
            key == LogicalKeyboardKey.backspace) {
          _clearActiveInsertCell();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) {
          unawaited(_saveDraft());
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.escape) {
          if (_editingRecord != null) {
            _resetDraft();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: palette.filterAccentSoft.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: palette.filterAccent.withValues(alpha: 0.38),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              color: palette.glow.withValues(alpha: 0.12),
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _resolveDieselGridLayout(constraints.maxWidth);
            return SizedBox(
              width: constraints.maxWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    insertCellFrame(0, _buildInlineDateCell(layout.dateWidth)),
                    const SizedBox(width: 8),
                    insertCellFrame(
                      1,
                      _buildInlinePickerCell(
                        width: layout.operatorWidth,
                        label: _labelOf(_operators, _draftOperatorId) ?? '—',
                        onTap: _saving ? null : _pickDraftOperator,
                        onTapStart: () => _setActiveInsertColumn(1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    insertCellFrame(
                      2,
                      _buildInlinePickerCell(
                        width: layout.vehicleWidth,
                        label: _labelOf(_vehicles, _draftVehicleId) ?? '—',
                        onTap: _saving ? null : _pickDraftVehicle,
                        onTapStart: () => _setActiveInsertColumn(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    insertCellFrame(
                      3,
                      _buildInlineNumberCell(
                        width: layout.purchasedWidth,
                        controller: _purchasedController,
                        focusNode: _purchasedFocusNode,
                        hintText: '0.00',
                        onTapStart: () =>
                            _setActiveInsertColumn(3, requestFocus: false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    insertCellFrame(
                      4,
                      _buildInlineNumberCell(
                        width: layout.requestedWidth,
                        controller: _requestedController,
                        focusNode: _requestedFocusNode,
                        hintText: '0.00',
                        onTapStart: () =>
                            _setActiveInsertColumn(4, requestFocus: false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    insertCellFrame(
                      5,
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => _setActiveInsertColumn(5),
                        child: _buildInlineBalanceCell(layout.balanceWidth),
                      ),
                    ),
                    SizedBox(width: layout.actionsGapWidth),
                    insertCellFrame(
                      6,
                      AnchoredActionSlot(
                        width: layout.actionsWidth,
                        trailingWidth: math.min(
                          layout.actionsWidth,
                          38 * layout.scale,
                        ),
                        gap: math.min(layout.actionsWidth, 8 * layout.scale),
                        leading: editing
                            ? Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Editando',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.6,
                                    fontWeight: FontWeight.w800,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                        trailing: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) => _setActiveInsertColumn(6),
                          child: _InsertActionButton(
                            saving: _saving,
                            editing: editing,
                            onPressed: _saving ? null : _saveDraft,
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

  Widget _buildInlineDateCell(double width) {
    final palette = ServicesVisualPalette.of(context);
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _saving
            ? null
            : () async {
                _setActiveInsertColumn(0);
                await _pickDraftDate();
              },
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: _inlineFieldDecoration(context),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _fmtUiDate(_draftDate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.4,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.calendar_today_rounded, size: 18, color: palette.icon),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlinePickerCell({
    required double width,
    required String label,
    required VoidCallback? onTap,
    required VoidCallback onTapStart,
  }) {
    final palette = ServicesVisualPalette.of(context);
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          onTapStart();
          onTap?.call();
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: _inlineFieldDecoration(context),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.4,
                    fontWeight: FontWeight.w800,
                    color: label == '—'
                        ? palette.textMuted
                        : palette.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded, size: 18, color: palette.icon),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineNumberCell({
    required double width,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required VoidCallback onTapStart,
  }) {
    final palette = ServicesVisualPalette.of(context);
    return SizedBox(
      width: width,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: _inlineFieldDecoration(context),
        child: Center(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: (_) => setState(() {}),
            onTap: onTapStart,
            onSubmitted: (_) => _saveDraft(),
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 13.4,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: TextStyle(
                color: palette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineBalanceCell(double width) {
    final palette = ServicesVisualPalette.of(context);
    final negative = _draftBalance < 0;
    return SizedBox(
      width: width,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: negative
              ? const Color(0xFFF0E3E0)
              : palette.surfaceInteractive,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: negative ? const Color(0xFFD3B4AF) : palette.borderStrong,
          ),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${_fmtLiters(_draftBalance)} L',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.4,
              fontWeight: FontWeight.w900,
              color: negative ? const Color(0xFF7B3E37) : palette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _inlineFieldDecoration(BuildContext context) {
    final palette = ServicesVisualPalette.of(context);
    return BoxDecoration(
      color: palette.fieldFillStrong,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: _insertFocusNode.hasFocus
            ? _kDieselFocusBlue.withValues(alpha: 0.22)
            : palette.borderStrong,
      ),
      boxShadow: [
        BoxShadow(
          blurRadius: 12,
          color: palette.shadow.withValues(alpha: 0.06),
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _buildRowsBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _entries.isEmpty) {
      return _buildMessageState(
        icon: Icons.error_outline_rounded,
        title: 'No se pudo cargar Consumo de Diesel',
        helper: _loadError!,
        action: OutlinedButton(
          style: _actionOutlinedButtonStyle(context),
          onPressed: () => unawaited(_bootstrap()),
          child: const Text('Reintentar'),
        ),
      );
    }
    if (_filteredEntries.isEmpty) {
      final filtered =
          _columnValueFilters.isNotEmpty || _columnDateRangeFilters.isNotEmpty;
      return _buildMessageState(
        icon: filtered
            ? Icons.filter_alt_off_rounded
            : Icons.local_gas_station_rounded,
        title: filtered
            ? 'No hay registros con el filtro actual'
            : 'Todavía no hay registros de diesel',
        helper: filtered
            ? 'Ajusta o limpia los filtros para recuperar la lectura completa.'
            : 'Empieza capturando fecha, operador, unidad, litros comprados y litros solicitados en la fila superior.',
        action: filtered
            ? OutlinedButton(
                style: _actionOutlinedButtonStyle(context),
                onPressed: () {
                  setState(() {
                    _columnValueFilters.clear();
                    _columnDateRangeFilters.clear();
                    _syncSelectionAndPagination();
                  });
                },
                child: const Text('Limpiar filtros'),
              )
            : null,
      );
    }
    return Focus(
      focusNode: _rowsFocusNode,
      autofocus: false,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        final firstVisibleId = _visibleEntries.isEmpty
            ? null
            : _visibleEntries.first.id;
        final isAtFirstVisibleRow =
            firstVisibleId != null && _primarySelectedId == firstVisibleId;

        if (key == LogicalKeyboardKey.arrowDown) {
          if (_isSelectionExtendPressed()) {
            _extendSelectionWithArrow(1);
          } else {
            _moveSelectedRow(1);
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp) {
          if (_isSelectionExtendPressed()) {
            _extendSelectionWithArrow(-1);
          } else if (_primarySelectedId == null || isAtFirstVisibleRow) {
            _focusInsertRowFromGrid();
          } else {
            _moveSelectedRow(-1);
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) {
          unawaited(_handleEnterOnSelectedRow());
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
        if (key == LogicalKeyboardKey.space) {
          if (_primarySelectedId == null && _visibleEntries.isNotEmpty) {
            final firstId = _visibleEntries.first.id;
            if (firstId != null) {
              _selectRow(firstId, allowToggle: false, focusTable: true);
            }
          } else if (_primarySelectedId != null) {
            _selectRow(
              _primarySelectedId!,
              additive: _isAdditiveSelectionPressed(),
              focusTable: true,
            );
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: (details) {
          if (_selectedCount <= 0) return;
          unawaited(_openRowsContextMenuAt(details.globalPosition));
        },
        child: ListView.separated(
          controller: _rowsScrollController,
          padding: const EdgeInsets.only(bottom: 12),
          itemCount: _visibleEntries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final record = _visibleEntries[index];
            return _DieselDataRow(
              key: record.id == null ? null : _rowKeyFor(record.id!),
              record: record,
              selected: record.id != null && _selectedIds.contains(record.id),
              onTap: () => _handleRowTap(record),
              onEdit: () => _startEditing(record),
              onDelete: () => unawaited(_deleteEntry(record)),
              onOpenContextMenu: record.id == null
                  ? null
                  : (position) => unawaited(
                      _openRowsContextMenuAt(position, rowId: record.id),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String helper,
    Widget? action,
  }) {
    final palette = ServicesVisualPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: palette.icon),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              helper,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.8,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: palette.textSecondary,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 14), action],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ServicesVisualModeScope(
      logisticsSilverMode: true,
      child: AreaThemeScope(
        tokens: logisticsAreaTokens,
        child: ServicesShell(
          headerTitle: 'Consumo de Diesel',
          servicesNavLabel: kLogisticsNavDieselLabel,
          customSideMenuBuilder: (context, closeMenu) => LogisticsAreaSidePanel(
            currentLabel: kLogisticsNavDieselLabel,
            canReturnToDirection: _canReturnToDirection,
            onNavigate: (label) {
              closeMenu();
              _handleNavigationAction(label);
            },
          ),
          sideMenuWidth: kLogisticsSideMenuWidth,
          topContent: Column(
            children: [
              _buildSummaryStrip(),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildTopActionsBar(),
              ),
            ],
          ),
          scrollTopContentWhenNeeded: false,
          minMainContentHeight: 420,
          activeOverlayModule: ServicesOverlayNavModule.servicios,
          onLogout: () async => signOutAndRouteToLogin(context),
          onGoToGeneralDashboard: _openDirectionDashboard,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Expanded(child: _buildTableSurface())],
            ),
          ),
        ),
      ),
    );
  }
}

class _DieselHeaderRow extends StatelessWidget {
  final bool Function(String columnId) hasActiveFilter;
  final void Function(String columnId, String label) onOpenFilter;

  const _DieselHeaderRow({
    required this.hasActiveFilter,
    required this.onOpenFilter,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ServicesVisualPalette.of(context);
    final textStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: palette.textPrimary,
    );
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        gradient: palette.glassCardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _resolveDieselGridLayout(constraints.maxWidth);
          return SizedBox(
            width: constraints.maxWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DieselHeaderCell(
                    label: 'FECHA',
                    width: layout.dateWidth,
                    style: textStyle,
                    active: hasActiveFilter('fecha'),
                    onFilter: () => onOpenFilter('fecha', 'FECHA'),
                  ),
                  _DieselHeaderCell(
                    label: 'OPERADOR',
                    width: layout.operatorWidth,
                    style: textStyle,
                    active: hasActiveFilter('operador'),
                    onFilter: () => onOpenFilter('operador', 'OPERADOR'),
                  ),
                  _DieselHeaderCell(
                    label: 'UNIDAD / VEHÍCULO',
                    width: layout.vehicleWidth,
                    style: textStyle,
                    active: hasActiveFilter('unidad'),
                    onFilter: () => onOpenFilter('unidad', 'UNIDAD / VEHÍCULO'),
                  ),
                  _DieselHeaderCell(
                    label: 'LITROS COMPRADOS',
                    width: layout.purchasedWidth,
                    style: textStyle,
                    active: hasActiveFilter('comprados'),
                    onFilter: () =>
                        onOpenFilter('comprados', 'LITROS COMPRADOS'),
                  ),
                  _DieselHeaderCell(
                    label: 'LITROS SOLICITADOS',
                    width: layout.requestedWidth,
                    style: textStyle,
                    active: hasActiveFilter('solicitados'),
                    onFilter: () =>
                        onOpenFilter('solicitados', 'LITROS SOLICITADOS'),
                  ),
                  _DieselHeaderCell(
                    label: 'SALDO',
                    width: layout.balanceWidth,
                    style: textStyle,
                    active: hasActiveFilter('saldo'),
                    onFilter: () => onOpenFilter('saldo', 'SALDO'),
                  ),
                  SizedBox(width: layout.actionsGapWidth),
                  SizedBox(width: layout.actionsWidth),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DieselHeaderCell extends StatelessWidget {
  final String label;
  final double width;
  final TextStyle style;
  final bool active;
  final VoidCallback onFilter;

  const _DieselHeaderCell({
    required this.label,
    required this.width,
    required this.style,
    required this.active,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ServicesVisualPalette.of(context);
    return SizedBox(
      width: width,
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
                    ? palette.filterAccent
                    : palette.filterAccentSoft.withValues(alpha: 0.52),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active
                      ? palette.filterAccent.withValues(alpha: 0.55)
                      : palette.border.withValues(alpha: 0.85),
                ),
              ),
              child: Icon(
                active ? Icons.filter_alt : Icons.filter_alt_outlined,
                size: 15,
                color: active
                    ? palette.buttonFillForeground
                    : palette.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label, style: style, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _DieselDataRow extends StatefulWidget {
  final LogisticsDieselConsumptionRecord record;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<Offset>? onOpenContextMenu;

  const _DieselDataRow({
    super.key,
    required this.record,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onOpenContextMenu,
  });

  @override
  State<_DieselDataRow> createState() => _DieselDataRowState();
}

class _DieselDataRowState extends State<_DieselDataRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final palette = ServicesVisualPalette.of(context);
    final negative = widget.record.balanceLiters < 0;
    final rowBg = widget.selected
        ? palette.selectedRowFill
        : _hovering
        ? palette.hoverRowFill
        : palette.surfaceBase.withValues(alpha: 0.96);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onTap,
          onDoubleTap: widget.onEdit,
          onSecondaryTapDown: (details) {
            widget.onOpenContextMenu?.call(details.globalPosition);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: rowBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.selected
                    ? _kDieselFocusBlue.withValues(alpha: 0.34)
                    : palette.borderStrong,
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = _resolveDieselGridLayout(constraints.maxWidth);
                return SizedBox(
                  width: constraints.maxWidth,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DieselValueCell(
                          _fmtUiDate(widget.record.entryDate),
                          layout.dateWidth,
                        ),
                        _DieselValueCell(
                          widget.record.operatorName,
                          layout.operatorWidth,
                        ),
                        _DieselValueCell(
                          widget.record.vehicleLabel,
                          layout.vehicleWidth,
                        ),
                        _DieselValueCell(
                          '${_fmtLiters(widget.record.litersPurchased)} L',
                          layout.purchasedWidth,
                        ),
                        _DieselValueCell(
                          '${_fmtLiters(widget.record.litersRequested)} L',
                          layout.requestedWidth,
                        ),
                        SizedBox(
                          width: layout.balanceWidth,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: negative
                                    ? const Color(0xFFF0E3E0)
                                    : palette.surfaceInteractive,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: negative
                                      ? const Color(0xFFD3B4AF)
                                      : palette.borderStrong,
                                ),
                              ),
                              child: Text(
                                '${_fmtLiters(widget.record.balanceLiters)} L',
                                style: TextStyle(
                                  fontSize: 12.4,
                                  fontWeight: FontWeight.w800,
                                  color: negative
                                      ? const Color(0xFF7B3E37)
                                      : palette.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: layout.actionsGapWidth),
                        SizedBox(
                          width: layout.actionsWidth,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                onPressed: widget.onEdit,
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: palette.icon,
                                ),
                              ),
                              PopupMenuButton<_DieselRowAction>(
                                tooltip: 'Más acciones',
                                color: palette.surfaceBase,
                                icon: Icon(
                                  Icons.more_horiz_rounded,
                                  color: palette.icon,
                                ),
                                onSelected: (action) {
                                  switch (action) {
                                    case _DieselRowAction.edit:
                                      widget.onEdit();
                                      return;
                                    case _DieselRowAction.delete:
                                      widget.onDelete();
                                      return;
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem<_DieselRowAction>(
                                    value: _DieselRowAction.edit,
                                    child: Text('Editar'),
                                  ),
                                  PopupMenuItem<_DieselRowAction>(
                                    value: _DieselRowAction.delete,
                                    child: Text('Eliminar'),
                                  ),
                                ],
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
    );
  }
}

enum _DieselRowAction { edit, delete }

class _DieselValueCell extends StatelessWidget {
  final String label;
  final double width;

  const _DieselValueCell(this.label, this.width);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13.2,
          fontWeight: FontWeight.w700,
          color: kLogisticsSilverTextPrimary,
        ),
      ),
    );
  }
}

class _DieselTankStatus {
  final String label;
  final String helper;
  final IconData icon;
  final Color topColor;
  final Color bottomColor;
  final Color borderColor;
  final Color textColor;

  const _DieselTankStatus({
    required this.label,
    required this.helper,
    required this.icon,
    required this.topColor,
    required this.bottomColor,
    required this.borderColor,
    required this.textColor,
  });
}

class _DieselStatusCard extends StatelessWidget {
  final String title;
  final String value;
  final String helper;
  final IconData icon;
  final Color topColor;
  final Color bottomColor;
  final Color borderColor;
  final Color textColor;

  const _DieselStatusCard({
    required this.title,
    required this.value,
    required this.helper,
    required this.icon,
    required this.topColor,
    required this.bottomColor,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ServicesVisualPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [topColor, bottomColor],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            color: palette.shadow.withValues(alpha: 0.10),
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.94)),
            ),
            child: Icon(icon, size: 20, color: textColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: textColor.withValues(alpha: 0.86),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  helper,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: textColor.withValues(alpha: 0.82),
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

class _InsertActionButton extends StatelessWidget {
  final bool saving;
  final bool editing;
  final VoidCallback? onPressed;

  const _InsertActionButton({
    required this.saving,
    required this.editing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Material(
        color: onPressed == null
            ? const Color(0xFF9CCFAF)
            : const Color(0xFF31C67C),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Icon(
            saving
                ? Icons.hourglass_top_rounded
                : editing
                ? Icons.save_outlined
                : Icons.add_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _DieselOption {
  final String id;
  final String label;

  const _DieselOption({required this.id, required this.label});
}

class _PickerOption<T> {
  final T value;
  final String label;

  const _PickerOption({required this.value, required this.label});
}

class _DateFilterDialogResult {
  final DateTimeRange? range;
  final bool clear;

  const _DateFilterDialogResult({this.range, this.clear = false});
}

Future<T?> _showSearchablePickerDialog<T>(
  BuildContext context, {
  required String title,
  required List<_PickerOption<T>> options,
  T? initialValue,
  bool allowClear = false,
}) {
  return shared_picker.showSearchablePickerDialog<T>(
    context,
    title: title,
    initialValue: initialValue,
    allowClear: allowClear,
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

InputDecoration _glassFieldDecoration(
  BuildContext context, {
  String? hintText,
  String? labelText,
  Widget? suffixIcon,
}) {
  final palette = ServicesVisualPalette.of(context);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: palette.borderStrong, width: 1),
  );

  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    suffixIcon: suffixIcon,
    isDense: true,
    filled: true,
    fillColor: palette.fieldFill,
    labelStyle: TextStyle(
      color: palette.textSecondary,
      fontWeight: FontWeight.w700,
    ),
    floatingLabelStyle: TextStyle(
      color: palette.filterAccent,
      fontWeight: FontWeight.w800,
    ),
    hintStyle: TextStyle(color: palette.textMuted, fontWeight: FontWeight.w600),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: _kDieselFocusBlue, width: 1.35),
    ),
  );
}

BoxDecoration _filterDialogDecoration(BuildContext context) {
  final palette = ServicesVisualPalette.of(context);
  return BoxDecoration(
    color: palette.surfaceBase,
    gradient: palette.glassCardGradient,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: palette.borderStrong),
  );
}

ButtonStyle _filterOutlinedButtonStyle(BuildContext context) {
  final palette = ServicesVisualPalette.of(context);
  return OutlinedButton.styleFrom(
    foregroundColor: palette.textSecondary,
    side: BorderSide(color: palette.border),
    backgroundColor: palette.surfaceElevated,
  );
}

ButtonStyle _filterFilledButtonStyle(BuildContext context) {
  final palette = ServicesVisualPalette.of(context);
  return FilledButton.styleFrom(
    backgroundColor: palette.buttonFill,
    foregroundColor: palette.buttonFillForeground,
  );
}

ButtonStyle _actionOutlinedButtonStyle(BuildContext context) {
  final palette = ServicesVisualPalette.of(context);
  return OutlinedButton.styleFrom(
    foregroundColor: palette.textPrimary,
    backgroundColor: palette.surfaceElevated,
    side: BorderSide(color: palette.borderStrong),
    surfaceTintColor: Colors.transparent,
    shadowColor: palette.deepShadow,
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

ButtonStyle _actionFilledButtonStyle(BuildContext context) {
  final palette = ServicesVisualPalette.of(context);
  return FilledButton.styleFrom(
    foregroundColor: palette.buttonFillForeground,
    backgroundColor: palette.buttonFill,
    disabledBackgroundColor: palette.surfaceHover,
    disabledForegroundColor: palette.textMuted,
  ).copyWith(
    overlayColor: WidgetStateProperty.all(Colors.transparent),
    elevation: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return 0;
      if (states.contains(WidgetState.pressed)) return 1.5;
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
  final palette = ServicesVisualPalette.of(context);
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) => ContractConfirmDialogKeyHandler(
      onCancel: () => Navigator.pop(dialogContext, false),
      onConfirm: () => Navigator.pop(dialogContext, true),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                decoration: BoxDecoration(
                  color: palette.surfaceBase,
                  gradient: palette.glassCardGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: palette.borderStrong),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.16),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: palette.textSecondary,
                          ),
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: _filterFilledButtonStyle(context),
                          autofocus: true,
                          onPressed: () => Navigator.pop(dialogContext, true),
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

Future<_DateFilterDialogResult?> _showDateRangeFilterDialog(
  BuildContext context, {
  required String label,
  required DateTimeRange bounds,
  DateTimeRange? initialRange,
}) {
  final palette = ServicesVisualPalette.of(context);
  return showDialog<_DateFilterDialogResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      DateTime displayMonth = initialRange?.start ?? bounds.start;
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
                final result = buildApplyResult();
                if (result != null) {
                  Navigator.pop(dialogContext, result);
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
                      decoration: _filterDialogDecoration(context),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtro: $label',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: palette.textPrimary,
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
                                icon: Icon(
                                  Icons.chevron_left,
                                  color: palette.icon,
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '${_monthNameEs(monthFirst.month)[0].toUpperCase()}${_monthNameEs(monthFirst.month).substring(1)} ${monthFirst.year}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: palette.textPrimary,
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
                                icon: Icon(
                                  Icons.chevron_right,
                                  color: palette.icon,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: const [
                              _WeekdayHeaderCell('L'),
                              _WeekdayHeaderCell('M'),
                              _WeekdayHeaderCell('M'),
                              _WeekdayHeaderCell('J'),
                              _WeekdayHeaderCell('V'),
                              _WeekdayHeaderCell('S'),
                              _WeekdayHeaderCell('D'),
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
                                          ? palette.filterAccent
                                          : inRange
                                          ? palette.filterAccentSoft.withValues(
                                              alpha: 0.8,
                                            )
                                          : Colors.transparent;

                                      final txtColor = active
                                          ? palette.buttonFillForeground
                                          : !allowed
                                          ? Colors.black38
                                          : inMonth
                                          ? palette.textPrimary
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
                                                        color: palette
                                                            .filterAccent
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
                                : '${_fmtUiDate(start!)} - ${_fmtUiDate(end!)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                style: _filterOutlinedButtonStyle(context),
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton(
                                style: _filterOutlinedButtonStyle(context),
                                onPressed: () => Navigator.pop(
                                  dialogContext,
                                  const _DateFilterDialogResult(clear: true),
                                ),
                                child: const Text('Limpiar'),
                              ),
                              const SizedBox(width: 6),
                              FilledButton(
                                style: _filterFilledButtonStyle(context),
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

class _WeekdayHeaderCell extends StatelessWidget {
  final String label;

  const _WeekdayHeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    final palette = ServicesVisualPalette.of(context);
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: palette.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
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

String _fmtCountInt(int value) => value.toString();

String _fmtCompactDate(DateTime value) {
  final mm = value.month.toString().padLeft(2, '0');
  final dd = value.day.toString().padLeft(2, '0');
  return '${value.year}$mm$dd';
}

double? _tryParseDouble(String raw) {
  final normalized = raw.trim().replaceAll(',', '');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

String _fmtUiDate(DateTime value) {
  final yy = (value.year % 100).toString().padLeft(2, '0');
  final mm = value.month.toString().padLeft(2, '0');
  final dd = value.day.toString().padLeft(2, '0');
  return '$dd/$mm/$yy';
}

String _fmtLiters(double value) {
  return value.toStringAsFixed(2);
}

String _formatLitersInput(double value) {
  if (value == value.truncateToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}
